"""Aggressive UV conjoinment: merge similar charts onto shared texels, then repack.

Input  (faces JSON, from blender_export_faces.py or any tool): a list of faces
    {"id": int, "chart": str, "material": str, "uv": [[u, v], ...]}   uv in texels
    at measured working densities; explicit exporter normalize=True makes them uniform.
    Optional per face: "protect": true  -> its chart never merges (fallback areas).
Output (plan JSON): per face new UV in [0,1] of the packed page, family id,
    owner flag, and per-member axis scale factors; plus stats.

Rule (greedy, largest chart first). A chart joins an existing owner when
  1. same single material (mixed-material charts are rejected),
  2. minimum-area-rectangle length and width each within +/- tol of the owner's,
  3. outline IoU >= iou after mapping the member rectangle onto the owner's
     rectangle (identity or rotate 180; reflections require a channel-safe method).
Members take the owner's texels through that rect-to-rect affine map, so their
texel density changes by the axis scale factors (reported). Owners are packed with
the validated MaxRects packer (pack_rects.py) at fixed density with a gutter.

Presets: T3 tol .40 iou .60 (explicit approximation), T2 .25/.75,
T1 .10/.85 (conservative). Exact containment for sensitive areas: labeled_fit.py.

CLI:  python conjoin.py faces.json plan.json --preset T3 [--gutter 16]
"""
import argparse, collections, json, math, sys
from pathlib import Path
import numpy as np
from shapely.geometry import Polygon
from shapely.ops import unary_union
from shapely.affinity import affine_transform

sys.path.insert(0, str(Path(__file__).parent))
from pack_rects import maxrects, min_side
from audit import split_hollow, audit, GATES

PRESETS = {'T1': (.10, .85), 'T2': (.25, .75), 'T3': (.40, .60)}
FLIPS = [np.diag([1., 1.]), np.diag([-1., -1.])]  # proper rotations; reflection needs a separate channel-safe method


def _poly(q):
    p = Polygon(q)
    return p if p.is_valid else p.buffer(0)


def prepare(faces):
    """Group faces into charts; normalise each chart to its min-area rectangle frame."""
    by = collections.defaultdict(list)
    ids = [str(f['id']) for f in faces]
    if not faces or len(set(ids)) != len(ids):
        raise ValueError('faces must be nonempty with globally unique face IDs (namespace by part)')
    for f in faces:
        q = np.asarray(f['uv'], float)
        if q.ndim != 2 or q.shape[1] != 2 or len(q) < 3 or not np.isfinite(q).all():
            raise ValueError(f"invalid UV coordinates: {f['id']}")
        raw = Polygon(q)
        if not raw.is_valid or raw.area <= 1e-12:
            raise ValueError(f"degenerate/self-intersecting UV face: {f['id']}")
        by[f['chart']].append(f)
    charts = []
    for cid, fs in by.items():
        if len({f['material'] for f in fs}) != 1:
            raise ValueError(f'mixed-material chart: {cid}')
        shp = unary_union([_poly(f['uv']) for f in fs])
        if shp.is_empty or shp.area <= 0:
            raise ValueError(f'empty chart: {cid}')
        wmat = collections.Counter()
        for f in fs:
            wmat[f['material']] += _poly(f['uv']).area
        r = np.asarray(shp.minimum_rotated_rectangle.exterior.coords)[:4]
        e1, e2 = r[1] - r[0], r[2] - r[1]
        if np.linalg.norm(e1) < np.linalg.norm(e2):
            e1 = e2
        a = -math.atan2(e1[1], e1[0])
        R = np.array([[math.cos(a), -math.sin(a)], [math.sin(a), math.cos(a)]])
        rot = affine_transform(shp, [R[0, 0], R[0, 1], R[1, 0], R[1, 1], 0, 0])
        b = rot.bounds
        N = np.array([[R[0, 0], R[0, 1], -b[0]], [R[1, 0], R[1, 1], -b[1]]])
        norm = affine_transform(shp, [N[0, 0], N[0, 1], N[1, 0], N[1, 1], N[0, 2], N[1, 2]])
        charts.append(dict(id=cid, faces=fs, mat=wmat.most_common(1)[0][0], N=N,
                           L=max(b[2] - b[0], 1e-6), W=max(b[3] - b[1], 1e-6), shape=norm, area=shp.area,
                           protect=any(f.get('protect') for f in fs)))
    return charts


def merge(charts, tol, iou_min, strips=0., trim=(), trim_width_ratio=2., compat=None):
    """Greedy family assignment. Returns owners (indices) and member -> (iou, owner, M, sx, sy).

    strips > 0 enables strip cropping for elongated charts (aspect >= strips on both):
    width must match within tol; the member keeps its aspect (uniform scale = width
    ratio) and maps onto the start of the owner's strip if it is not longer than it.
    IoU is measured against the owner's shape cropped to that length.
    """
    from shapely.geometry import box
    order = sorted(range(len(charts)), key=lambda i: -charts[i]['area'])
    owners = collections.defaultdict(list)
    assign = {}
    trim_owner = {}
    for i in order:
        m = charts[i]
        best = None
        if m['mat'] in trim and not m['protect']:
            # trim sheet: strips share a few width-class strips, compact pieces one patch
            strip = m['L'] / m['W'] >= 2.
            cls = ('strip', int(math.floor(math.log(m['W'], trim_width_ratio)))) if strip else ('patch', 0)
            k = (m['mat'],) + cls
            if k not in trim_owner:
                trim_owner[k] = i
                owners[m['mat']].append(i)
                continue
            j = trim_owner[k]; o = charts[j]
            sy = o['W'] / m['W']
            sx = sy if (strip and m['L'] * sy <= o['L']) else o['L'] / m['L']
            if not strip:
                sx, sy = o['L'] / m['L'], o['W'] / m['W']
            M = np.eye(3); M[:2, :2] = np.diag([sx, sy])
            if compat is not None and not compat(m, o, M):
                m['ao_rejected'] = True
                owners[m['mat']].append(i)
                continue
            assign[i] = (1., j, M, sx, sy)
            continue
        if not m['protect']:
            for j in owners[m['mat']]:
                o = charts[j]
                if o['protect']:
                    continue
                sx, sy = o['L'] / m['L'], o['W'] / m['W']
                crop = None
                if abs(1 / sx - 1) > tol or abs(1 / sy - 1) > tol:
                    if not (strips and m['L'] / m['W'] >= strips and o['L'] / o['W'] >= strips
                            and abs(1 / sy - 1) <= tol and m['L'] * sy <= o['L'] * (1 + 1e-9)):
                        continue
                    sx = sy
                    crop = m['L'] * sy
                cx, cy = (crop if crop else o['L']) / 2, o['W'] / 2
                target = o['shape'] if crop is None else o['shape'].intersection(box(0, 0, crop, o['W']))
                if target.is_empty:
                    continue
                for Fm in FLIPS:
                    M = np.eye(3)
                    M[:2, :2] = Fm @ np.diag([sx, sy])
                    M[:2, 2] = np.array([cx, cy]) - Fm @ np.array([cx, cy])
                    g = affine_transform(m['shape'], [M[0, 0], M[0, 1], M[1, 0], M[1, 1], M[0, 2], M[1, 2]])
                    inter = g.intersection(target).area
                    iou = inter / (g.area + target.area - inter)
                    if iou >= iou_min and (best is None or iou > best[0]):
                        if compat is not None and not compat(m, o, M):
                            m['ao_rejected'] = True      # geometry matched, AO did not
                            continue
                        best = (iou, j, M, sx, sy)
        if best:
            assign[i] = best
        else:
            owners[m['mat']].append(i)
    return [j for v in owners.values() for j in v], assign


def pack(charts, owners, gutter):
    rects = [(charts[j]['L'] + gutter, charts[j]['W'] + gutter) for j in owners]
    side = min_side(rects)
    place = {}
    for k, x, y, rw, rh in maxrects(rects, side, side):
        j = owners[k]
        T = np.eye(3)
        if abs(rw - rects[k][0]) > 1e-6:          # packer rotated it 90 degrees
            T[:2, :2] = [[0, -1], [1, 0]]
            T[:2, 2] = [charts[j]['W'], 0]
        T2 = np.eye(3)
        T2[:2, 2] = [x + gutter / 2, y + gutter / 2]
        place[j] = T2 @ T
    return side, place


def families(faces, tol=.10, iou=.85, strips=0., split_hollow_charts=False, fill=.6, trim=(),
             trim_width_ratio=2., compat=None):
    """Merge only (no packing): charts, owner indices, member assignments, split chart ids.
    Faces are copied first (callers' faces stay untouched)."""
    import copy
    for name, value, low, high in [('tol', tol, 0, 1), ('iou', iou, 0, 1), ('fill', fill, 0, 1),
                                  ('strips', strips, 0, float('inf')), ('trim_width_ratio', trim_width_ratio, 1.000001, float('inf'))]:
        if not math.isfinite(value) or not low <= value <= high:
            raise ValueError(f'invalid {name}: {value}')
    faces = copy.deepcopy(faces)
    split = split_hollow(faces, fill) if split_hollow_charts else []
    charts = prepare(faces)
    owners, assign = merge(charts, tol, iou, strips, set(trim), trim_width_ratio, compat)
    return charts, owners, assign, split


def conjoin(faces, tol=.10, iou=.85, gutter=16., strips=0., split_hollow_charts=False, fill=.6,
            target_density=256., runtime_page=2048., gates=None, trim=(), trim_width_ratio=2., page_texels=None,
            compat=None):
    """Merge + pack. Hollow charts (frames) are split into straight members first
    (split_hollow_charts); the packed page is audited (stats['audit'], verdict PASS/FAIL)."""
    import copy
    for name, value, allow_zero in [('gutter', gutter, True), ('target_density', target_density, False),
                                     ('runtime_page', runtime_page, False), ('page_texels', page_texels, False)]:
        if value is None and name == 'page_texels':
            continue
        if not math.isfinite(value) or value < 0 or (not allow_zero and value == 0):
            raise ValueError(f'invalid {name}: {value}')
    for name, value in (gates or {}).items():
        if name not in GATES or not math.isfinite(value) or value < 0:
            raise ValueError(f'invalid audit threshold {name}: {value}')
    faces = copy.deepcopy(faces)
    charts, owners, assign, split = families(faces, tol, iou, strips, split_hollow_charts, fill, trim,
                                             trim_width_ratio, compat)
    side, place = pack(charts, owners, gutter)
    if page_texels and side > page_texels:
        raise ValueError(f'packed side {side:.0f} exceeds the original page {page_texels:.0f}')
    out = {}
    fam_size = collections.Counter()
    for i in owners:
        fam_size[i] += 1
    for i, (_, j, _, _, _) in assign.items():
        fam_size[j] += 1

    def emit(i, j, M, sx, sy):
        H = np.eye(3)
        H[:2, :] = charts[i]['N']
        A = place[j] @ M @ H
        for f in charts[i]['faces']:
            q = np.c_[np.asarray(f['uv'], float), np.ones(len(f['uv']))] @ A.T
            out[str(f['id'])] = dict(uv=(q[:, :2] / (page_texels or side)).tolist(), family=charts[j]['id'],
                                     family_size=fam_size[j], owner=i == j, scale=[sx, sy],
                                     material=charts[i]['mat'])
    for j in owners:
        emit(j, j, np.eye(3), 1., 1.)
    for i, (_, j, M, sx, sy) in assign.items():
        emit(i, j, M, sx, sy)
    sc = np.array([max(abs(v[3] - 1), abs(v[4] - 1)) for v in assign.values()] or [0.])
    stats = dict(charts=len(charts), owners=len(owners), members=len(assign), page_side_texels=side,
                 filled_owner_texels=float(sum(charts[j]['area'] for j in owners)),
                 all_chart_texels=float(sum(c['area'] for c in charts)),
                 member_density_change_mean=float(sc.mean()), member_density_change_max=float(sc.max()),
                 tol=tol, iou=iou, gutter=gutter, strips=strips, hollow_charts_split=len(split), trim=sorted(trim))
    stats['audit'] = audit(charts, owners, fam_size, side, gutter, target_density, runtime_page, fill, gates,
                           uv_page_texels=page_texels)
    stats['ao_rejected_charts'] = sum(1 for j in owners if charts[j].get('ao_rejected'))
    return out, stats


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('faces'); ap.add_argument('plan')
    ap.add_argument('--preset', required=True, choices=list(PRESETS), help='explicit region policy; no asset-wide automatic preset')
    ap.add_argument('--tol', type=float); ap.add_argument('--iou', type=float)
    ap.add_argument('--gutter', type=float, default=16.)
    ap.add_argument('--strips', type=float, default=2.5, help='strip cropping for charts with aspect >= this (0 = off)')
    split = ap.add_mutually_exclusive_group()
    split.add_argument('--split-hollow', action='store_true', help='explicit chart refinement; revalidate lineage/continuity before applying')
    split.add_argument('--no-split-hollow', action='store_true', help='legacy spelling of the default: preserve charts')
    ap.add_argument('--trim', default='', help='comma list of materials that share a trim sheet (e.g. WOOD)')
    ap.add_argument('--page', type=float, default=0., help='ORIGINAL page size in texels: UVs keep their original scale, freed space stays empty (recommended)')
    ap.add_argument('--runtime-page', type=float, default=2048.)
    ap.add_argument('--target-density', type=float, default=256.)
    ap.add_argument('--min-runtime-density', type=float, default=0.)
    a = ap.parse_args()
    tol, iou = PRESETS[a.preset]
    tol = a.tol if a.tol is not None else tol
    iou = a.iou if a.iou is not None else iou
    faces = json.loads(Path(a.faces).read_text())
    plan, stats = conjoin(faces, tol, iou, a.gutter, a.strips, a.split_hollow,
                          target_density=a.target_density, runtime_page=a.runtime_page,
                          gates=dict(min_runtime_density=a.min_runtime_density),
                          trim=[t for t in a.trim.split(',') if t], page_texels=a.page or None)
    Path(a.plan).write_text(json.dumps(dict(faces=plan, stats=stats)))
    au = stats['audit']
    print(json.dumps({k: v for k, v in stats.items() if k != 'audit'}, indent=1))
    print(f"AUDIT {au['verdict']}: page {au['page_side_texels']:.0f} texels -> {au['runtime_texels_per_unit']:.0f} texels/unit "
          f"on a {au['runtime_page']:.0f} page | hollow {au['hollow_share']:.0%} | unshared {au['unique_share']:.0%} | "
          f"packing {au['packing_efficiency']:.0%}")
    for f in au['fails']:
        print('  FAIL:', f)
    for note in au['advisories']:
        print('  ADVISORY:', note)
    if au['fails']:
        sys.exit(2)


if __name__ == '__main__':
    main()
