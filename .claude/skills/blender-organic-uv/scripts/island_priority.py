"""Island-scale density priority and the bone-region head estimator (host Python, numpy only).

Priority acts on whole islands, after every island is normalised to 1 UV unit = 1 metre: island multiplier =
3D-area-weighted mean of the face factors over the island's VISIBLE faces (all faces when none is visible; a mirrored
pair uses both twins). A face factor comes from a per-part table (`factors`), or from a per-polygon list
(`face_factors`), capped at `hidden_cap` on faces never visible at the game camera. The packer then multiplies the
island's density by its multiplier (organic_layout.py). SLIM importance weights cannot do this: Blender rescales every
island to its own 3D area, so weights only move texels inside an island.

Head priority is READ on the bone-region estimator of the reference unit benchmark (uvlib.bone_region rules: dominant
bone per face, density = sqrt(sum UV area / sum 3D area) per region). A part-label ratio can read 1.29 where the bone
estimator reads 1.12 on the same layout (hidden scalp shrunk into the head region, hood faces weighted to the spine):
calibrate() therefore solves one factor s for the head islands so that the bone-region ratio meets the target.

    python island_priority.py ratio MESH_DUMP.json LAYOUT.json [--objects Body] [--never-visible RUN_DIR|JSON]
                                    [--bone-regions RULES.json]

prints the bone-region densities (relative and t/m at the layout's page) of a finished layout, with and without the
never-visible faces. Exit 0, 2 = setup error.
"""
import argparse
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import uvenv  # noqa: E402
import uvlib as UL  # noqa: E402


def poly_area3d(P, poly):
    Q = P[list(poly)]
    n = np.zeros(3)
    for k in range(1, len(Q) - 1):
        n += np.cross(Q[k] - Q[0], Q[k + 1] - Q[0])
    return 0.5 * float(np.linalg.norm(n))


def poly_area_uv(uvs):
    """signed UV area (counter-clockwise positive) of one polygon's corner UVs."""
    U = np.asarray(uvs, float)
    x, y = U[:, 0], U[:, 1]
    return 0.5 * float((x * np.roll(y, -1) - np.roll(x, -1) * y).sum())


def tris_by_poly(obj):
    """{polygon: [(a, b, c), ...]}: Blender's loop triangles from the dump ('tris'), else a fan per polygon (a quad's
    diagonal may then differ from the one uv_eval measures)."""
    out = {}
    if obj.get('tris'):
        for a, b, c, p in obj['tris']:
            out.setdefault(int(p), []).append((int(a), int(b), int(c)))
    else:
        for p, poly in enumerate(obj['polys']):
            out[p] = [(poly[0], poly[k], poly[k + 1]) for k in range(1, len(poly) - 1)]
    return out


def tri_regions(obj, rules=None):
    """{(polygon, k): bone region} of every triangle: dominant bone over its three corners (uv_eval's rule)."""
    W = obj.get('weights') or [[] for _ in obj['co']]
    return {(p, k): UL.bone_region(UL.dominant_bone(t, W), rules)
            for p, ts in tris_by_poly(obj).items() for k, t in enumerate(ts)}


def tri_area3d(P, t):
    return 0.5 * float(np.linalg.norm(np.cross(P[t[1]] - P[t[0]], P[t[2]] - P[t[0]])))


def load_never_visible(source, dump):
    """{object: bool array per polygon} from a uv_eval run folder (data.npz: a polygon is never visible when none of
    its triangles is visible in any heading), a JSON file {object: [bool per polygon]} or that mapping itself."""
    if not source:
        return {}
    if isinstance(source, dict):
        return {k: np.asarray(v, bool) for k, v in source.items() if k in dump['objects']}
    if os.path.isdir(source):
        Z = np.load(os.path.join(source, 'data.npz'))
        if 'poly' not in Z.files or 'objects' not in Z.files:
            raise uvenv.SetupError('%s/data.npz has no poly/objects arrays (run uv_eval of this package)' % source)
        names = [str(x) for x in Z['objects']]
        vis_any = Z['vis'].max(0) > 0
        out = {}
        for i, n in enumerate(names):
            if n not in dump['objects']:
                continue
            npoly = len(dump['objects'][n]['polys'])
            seen = np.zeros(npoly, bool)
            m = Z['objid'] == i
            np.logical_or.at(seen, Z['poly'][m], vis_any[m])
            out[n] = ~seen
        return out
    data = uvenv.read_json(source)
    return {k: np.asarray(v, bool) for k, v in data.items() if k in dump['objects']}


def face_factors(dump, name, prio, never):
    """factor per polygon of one object (before the island mean)."""
    obj = dump['objects'][name]
    n = len(obj['polys'])
    ff = None
    src = prio.get('face_factors')
    if src:
        table = src if isinstance(src, dict) else uvenv.read_json(src)
        if name in table:
            ff = np.asarray(table[name], float)
            if len(ff) != n:
                raise uvenv.SetupError('face_factors for %s: %d values, %d polygons' % (name, len(ff), n))
    if ff is None:
        table = prio.get('factors', {})
        parts = obj.get('parts') or ['(none)'] * n
        ff = np.array([float(table.get(p, 1.0)) for p in parts])
    cap = prio.get('hidden_cap')
    nv = never.get(name)
    if cap is not None and nv is not None:
        ff = np.where(nv, np.minimum(ff, float(cap)), ff)
    return ff


def island_multiplier(faces, factors, never, area3d):
    """area-weighted mean factor over the visible faces of the island (all faces when none is visible)."""
    faces = list(faces)
    vis = [f for f in faces if never is None or not never[f]] or faces
    a = np.array([area3d[f] for f in vis])
    if a.sum() <= 0:
        return 1.0
    return float((a * np.array([factors[f] for f in vis])).sum() / a.sum())


def region_density(entries, num='head', den='torso'):
    """entries: iterable of (region, area3d, uv_area_at_density_1, multiplier). Returns ({region: relative density},
    ratio num/den). Relative density = sqrt(sum m^2 A_uv / sum A_3d): multiply by the page density D for t/m."""
    acc = {}
    for rg, a3, au, m in entries:
        s = acc.setdefault(rg, [0.0, 0.0])
        s[0] += a3
        s[1] += au * m * m
    dens = {rg: math.sqrt(u / a) if a > 0 else None for rg, (a, u) in acc.items()}
    ratio = dens[num] / dens[den] if dens.get(num) and dens.get(den) else None
    return dens, ratio


def calibrate(entries_fn, target, lo=0.25, hi=4.0, tol=1e-5, iters=80):
    """bisection on the head-group factor s: entries_fn(s) -> (dens, ratio). Returns (s, ratio(s)) or (None, why)."""
    r_lo, r_hi = entries_fn(lo)[1], entries_fn(hi)[1]
    if r_lo is None or r_hi is None:
        return None, 'a region of the ratio is missing'
    if not (min(r_lo, r_hi) <= target <= max(r_lo, r_hi)):
        return None, 'target %.3f outside the reachable range %.3f..%.3f' % (target, min(r_lo, r_hi), max(r_lo, r_hi))
    inc = r_hi > r_lo
    a, b = lo, hi
    for _ in range(iters):
        mid = 0.5 * (a + b)
        r = entries_fn(mid)[1]
        if abs(r - target) <= tol:
            return mid, r
        if (r < target) == inc:
            a = mid
        else:
            b = mid
    mid = 0.5 * (a + b)
    return mid, entries_fn(mid)[1]


def layout_ratio(dump, layout, objects=None, never=None, rules=None, num='head', den='torso'):
    """bone-region densities of a finished layout (t/m at each object's page), all faces and visible faces only."""
    out = {}
    for name, ol in layout['objects'].items():
        if objects and name not in objects:
            continue
        obj = dump['objects'][name]
        P = np.array(obj['co'], float)
        page = int(ol['page_size'])
        reg = tri_regions(obj, rules)
        nv = (never or {}).get(name)
        ent_all, ent_vis = [], []
        for f, ts in sorted(tris_by_poly(obj).items()):
            poly, uvs = ol['verts'][f], ol['polys'][f]
            for k, t in enumerate(ts):
                tuv = [uvs[poly.index(v)] for v in t]
                e = (reg[(f, k)], tri_area3d(P, t), abs(poly_area_uv(tuv)) * page * page, 1.0)
                ent_all.append(e)
                if nv is None or not nv[f]:
                    ent_vis.append(e)
        d_all, r_all = region_density(ent_all, num, den)
        d_vis, r_vis = region_density(ent_vis, num, den)
        out[name] = {'page': page, 'density_t_per_m': d_all, 'ratio': r_all,
                     'visible_density_t_per_m': d_vis, 'visible_ratio': r_vis}
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(prog='island_priority.py', description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    r = sub.add_parser('ratio')
    r.add_argument('dump')
    r.add_argument('layout')
    r.add_argument('--objects', default='')
    r.add_argument('--never-visible')
    r.add_argument('--bone-regions')
    r.add_argument('--num', default='head')
    r.add_argument('--den', default='torso')
    a = ap.parse_args(argv)
    dump, layout = uvenv.read_json(a.dump), uvenv.read_json(a.layout)
    rules = uvenv.read_json(a.bone_regions) if a.bone_regions else None
    never = load_never_visible(a.never_visible, dump)
    res = layout_ratio(dump, layout, [n for n in a.objects.split(',') if n] or None, never, rules, a.num, a.den)
    for n, v in res.items():
        dd = ', '.join('%s %.1f' % (k, x) for k, x in sorted(v['density_t_per_m'].items()) if x)
        print('%s (page %d): %s/%s %s | visible faces only %s | %s' % (
            n, v['page'], a.num, a.den, None if v['ratio'] is None else round(v['ratio'], 4),
            None if v['visible_ratio'] is None else round(v['visible_ratio'], 4), dd))
    return 0


if __name__ == '__main__':
    sys.exit(main())
