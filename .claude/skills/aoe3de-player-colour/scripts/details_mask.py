"""details_mask.py - build an AoE3 DE player-colour Details map (the material's 4th texture) from mask sources.

Output: <page>_Details.png, 8-bit LINEAR RGB = (R, 0, 0), same size as the BaseColor, UV0. R = player-colour weight
(0 = none, 255 = full multiply); G = B = 0 (G is emissive in default_emissive only). Sources are MAX-combined.

SOURCE 1 - faces (--faces faces.json --select ids)
    faces.json = {"size": 2048, "faces": {"<id>": {"uv": [[u, v], ...], "seen_px": 42}, ...}} - every face of the page
    (UV0 polygon, 0..1, v up; seen_px optional: the face's best visible pixel count in the review cameras).
    Texel sharing: faces whose centre-rasterised texels overlap by >= --min-overlap form one texel group; Details shares
    UV0, so every member of a painted group turns player-coloured. A group that holds a selected face and a SEEN
    unselected face (seen_px >= --min-seen, or unknown) is REFUSED: exit 2, the collateral faces and an unshare proposal
    are reported, nothing is written. Never-seen members are painted and listed. The UVs are never changed here.
    Coverage is supersampled --ss x --ss per texel against the neighbouring unselected faces (the soft 1-2 texel edge on
    a shared chart boundary), then dilated --dilate steps into the gutter, so no uncoloured seam appears at lower mips.
SOURCE 2 - procedural (--basecolor BC.png --region region.png | --region-faces ids)
    Segments a painted field inside the region of the EXISTING BaseColor, per connected region component: CIE Lab of the
    linear base; field candidates = hue in [--hue-lo, --hue-hi] and chroma >= --min-chroma; Otsu split on the HUE
    (not the luma: soot and fading darken lines and cells alike) and --pick low|high hue side; 4-connected cells,
    specks < --min-cell dropped, enclosed holes <= --hole-max filled; soft 1-texel edge from the texel's own field fraction
    (clamped [0.5, 1] inside a cell, [0, 0.5] outside). No dilation: the field sits inside painted charts.

    python details_mask.py --out P2048_Details.png [--size 2048] [--report r.json]
           [--faces faces.json --select a,b,c|@ids.json] [--min-seen 5] [--min-overlap 3] [--ss 4] [--dilate 10]
           [--basecolor P2048_BaseColor.png (--region gables.png | --region-faces ids) --hue-lo 55 --hue-hi 100
            --min-chroma 25 --pick low --min-cell 8 --hole-max 12]
"""
import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pc_common as C  # noqa: E402


class Refused(Exception):
    """a selection would paint seen unselected faces through shared texels"""


# ------------------------------------------------------------------------------------------------------ rasterising
def uv_px(uv, size):
    """UV (v up) -> pixel coords (x, y) in file order"""
    uv = np.asarray(uv, np.float64)
    return np.stack([uv[:, 0] * size, (1.0 - uv[:, 1]) * size], -1)


def _inside(poly, xs, ys):
    ins = np.zeros(xs.shape, bool)
    for j in range(len(poly)):
        (ax, ay), (bx, by) = poly[j], poly[(j + 1) % len(poly)]
        ins ^= ((ay > ys) != (by > ys)) & (xs < (bx - ax) * (ys - ay) / np.where(by - ay == 0, 1e-12, by - ay) + ax)
    return ins


def bbox(poly, size, pad=0):
    x0, y0 = np.floor(poly.min(0)).astype(int) - pad
    x1, y1 = np.ceil(poly.max(0)).astype(int) + 1 + pad
    return max(x0, 0), max(y0, 0), min(x1, size), min(y1, size)


def raster(poly, size):
    """(rows, cols) of the texels whose CENTRE lies inside the pixel-space polygon"""
    x0, y0, x1, y1 = bbox(poly, size)
    if x1 <= x0 or y1 <= y0:
        return np.zeros(0, int), np.zeros(0, int)
    xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
    r, c = np.nonzero(_inside(poly, xs, ys))
    return r + y0, c + x0


def groups(polys, size, min_overlap=3):
    """faces whose centre texels overlap by >= min_overlap are one texel group -> ({face: group}, {face: (rows, cols)})"""
    keys = sorted(polys)
    idx = {k: i for i, k in enumerate(keys)}
    par = list(range(len(keys)))

    def find(a):
        while par[a] != a:
            par[a] = par[par[a]]; a = par[a]
        return a
    lab = np.full((size, size), -1, np.int32)
    tex = {}
    for k in keys:
        rr, cc = raster(polys[k], size)
        tex[k] = (rr, cc)
        if len(rr):
            ex = lab[rr, cc]; ex = ex[ex >= 0]
            if len(ex):
                u, n = np.unique(ex, return_counts=True)
                for j in u[n >= min_overlap]:
                    a, b = find(idx[k]), find(int(j))
                    if a != b:
                        par[a] = b
            lab[rr, cc] = idx[k]
    gid = {k: keys[find(idx[k])] for k in keys}
    return gid, tex


# -------------------------------------------------------------------------------------------------- source 1: faces
def load_faces(path):
    d = json.loads(Path(path).read_text())
    return d.get('size'), d['faces']


def parse_ids(s):
    if s is None:
        return []
    if s.startswith('@'):
        return [str(x) for x in json.loads(Path(s[1:]).read_text())]
    return [x for x in s.split(',') if x]


def face_mask(faces, select, size, min_seen=5, min_overlap=3, ss=4, dilate_steps=10):
    """-> (mask float32 [size, size], report); raises Refused on collateral sharing with seen faces"""
    polys = {k: uv_px(f['uv'], size) for k, f in faces.items()}
    sel = set(select)
    missing = sorted(sel - set(polys))
    assert not missing, f'selected faces not in faces.json: {missing[:10]}'
    gid, tex = groups(polys, size, min_overlap)
    members = defaultdict(list)
    for k, g in gid.items():
        members[g].append(k)
    seen = {k: faces[k].get('seen_px') for k in faces}
    painted, refused, via_group = set(sel), [], []
    for g in sorted({gid[k] for k in sel}):
        others = [m for m in members[g] if m not in sel]
        blocking = [m for m in others if seen[m] is None or seen[m] >= min_seen]
        if blocking:
            refused.append(dict(group=g, selected=sorted(m for m in members[g] if m in sel), blocking_seen=sorted(blocking),
                                proposal=f'give the selected faces their own texels (detach them from group {g}) or add '
                                         f'the blocking faces to the selection'))
            continue
        for m in others:
            painted.add(m); via_group.append(dict(face=m, group=g, seen_px=seen[m]))
    rep = dict(source='faces', selected=len(sel), painted_faces=len(painted), groups=len({gid[k] for k in sel}),
               painted_via_group_never_seen=via_group, refused=refused, min_seen=min_seen, min_overlap=min_overlap)
    if refused:
        raise Refused(json.dumps(refused, indent=1))
    boxes = {k: bbox(p, size) for k, p in polys.items()}
    roi = [boxes[k] for k in painted]
    near = lambda b: any(b[0] < r[2] + 2 and b[2] > r[0] - 2 and b[1] < r[3] + 2 and b[3] > r[1] - 2 for r in roi)  # noqa: E731
    use = [k for k in polys if boxes[k][2] > boxes[k][0] and boxes[k][3] > boxes[k][1] and near(boxes[k])]
    X0 = min(boxes[k][0] for k in use); Y0 = min(boxes[k][1] for k in use)
    X1 = max(boxes[k][2] for k in use); Y1 = max(boxes[k][3] for k in use)
    Sa = np.zeros(((Y1 - Y0) * ss, (X1 - X0) * ss), bool); Sb = np.zeros_like(Sa)
    for k in use:
        x0, y0, x1, y1 = boxes[k]
        xs, ys = np.meshgrid(x0 + (np.arange((x1 - x0) * ss) + 0.5) / ss, y0 + (np.arange((y1 - y0) * ss) + 0.5) / ss)
        S = Sa if k in painted else Sb
        S[(y0 - Y0) * ss:(y1 - Y0) * ss, (x0 - X0) * ss:(x1 - X0) * ss] |= _inside(polys[k], xs, ys)
    Sa &= ~Sb                                            # a subsample inside both belongs to the unpainted neighbour
    h, w = Y1 - Y0, X1 - X0
    a = np.zeros((size, size), np.float32); b = np.zeros((size, size), np.float32)
    a[Y0:Y1, X0:X1] = Sa.reshape(h, ss, w, ss).sum((1, 3)); b[Y0:Y1, X0:X1] = Sb.reshape(h, ss, w, ss).sum((1, 3))
    chart = (a + b) > 0
    for k in polys:
        rr, cc = tex[k]; chart[rr, cc] = True
    m = np.where(a + b > 0, a / np.maximum(a + b, 1), 0).astype(np.float32)
    mask = np.clip(C.dilate(m, chart, dilate_steps), 0, 1)
    rep.update(texels=int((m > 0).sum()), full_texels=int((m >= 1).sum()), soft_edge_texels=int(((m > 0) & (m < 1)).sum()),
               gutter_texels=int(((mask > 0) & ~chart).sum()), ss=ss, dilate=dilate_steps)
    return mask, rep


# --------------------------------------------------------------------------------------------- source 2: procedural
def field_cells(lin, region, hue_lo=55.0, hue_hi=100.0, min_chroma=25.0, pick='low', min_cell=8, hole_max=12,
                ramp_c=6.0, ramp_h=8.0):
    """segment a painted field inside `region` (bool) of a linear BaseColor -> (mask float32, cells bool, report)"""
    mask = np.zeros(lin.shape[:2], np.float32); cells_all = np.zeros(lin.shape[:2], bool); rep = {}
    comp = C.components(region)
    for L in range(1, int(comp.max()) + 1):
        rr, cc = np.nonzero(comp == L)
        r0, r1 = max(rr.min() - 2, 0), rr.max() + 3
        c0, c1 = max(cc.min() - 2, 0), cc.max() + 3
        R = comp[r0:r1, c0:c1] == L
        hue, chroma = C.hue_chroma(lin[r0:r1, c0:c1])
        field = R & (hue > hue_lo) & (hue < hue_hi) & (chroma >= min_chroma)
        name = f'region_{L}'
        if field.sum() < 2 * min_cell:
            rep[name] = dict(region_texels=int(R.sum()), field_texels=int(field.sum()), texels=0, note='no field'); continue
        thr = C.otsu(hue[field])
        cell = field & ((hue < thr) if pick == 'low' else (hue >= thr))
        h_cell = float(np.median(hue[cell])); h_line = float(np.median(hue[field & ~cell]))
        lab = C.components(cell); u, n = np.unique(lab[lab > 0], return_counts=True)
        cell = np.isin(lab, u[n >= min_cell]); specks = int((n < min_cell).sum())
        holes = C.components(R & ~cell); lab = C.components(cell); filled = 0
        hu, hn = np.unique(holes[holes > 0], return_counts=True)
        for H, k in zip(hu, hn):
            if k > hole_max:
                continue
            hm = holes == H; ring = np.zeros_like(hm)
            for dy, dx in C.N4:
                ring |= C.shift(hm, dy, dx, False)
            ring &= ~hm
            if ring.any() and cell[ring].all() and len(np.unique(lab[ring])) == 1:
                cell |= hm; filled += int(k)
        lab = C.components(cell); u, n = np.unique(lab[lab > 0], return_counts=True)
        sgn = 1.0 if pick == 'low' else -1.0
        frac = np.clip(sgn * (h_line - hue) / max(abs(h_line - h_cell), 1e-3), 0, 1)
        frac = np.minimum(frac, np.clip((chroma - (min_chroma - ramp_c)) / (2 * ramp_c), 0, 1))
        frac = np.minimum(frac, np.clip((hue - (hue_lo - ramp_h)) / (2 * ramp_h), 0, 1))
        frac = np.minimum(frac, np.clip(((hue_hi + ramp_h) - hue) / (2 * ramp_h), 0, 1))
        frac[~R] = 0
        out_n = np.zeros_like(cell); in_n = np.zeros_like(cell)
        for dy, dx in C.N4:
            out_n |= C.shift(~cell, dy, dx, False); in_n |= C.shift(cell, dy, dx, False)
        inner = cell & out_n; outer = ~cell & in_n & R
        m = cell.astype(np.float32)
        m[inner] = np.clip(frac[inner], 0.5, 1.0); m[outer] = np.clip(frac[outer], 0.0, 0.5)
        sub = mask[r0:r1, c0:c1]; np.maximum(sub, m, out=sub); cells_all[r0:r1, c0:c1] |= cell
        rep[name] = dict(region_texels=int(R.sum()), field_texels=int(field.sum()), hue_split_deg=round(thr, 2),
                         hue_cell_median=round(h_cell, 2), hue_line_median=round(h_line, 2), cells=int(len(u)),
                         specks_dropped=specks, holes_filled_tx=filled, texels=int((m > 0).sum()),
                         full_texels=int((m >= 1).sum()), soft_edge_texels=int(((m > 0) & (m < 1)).sum()))
    return mask, cells_all, rep


# ------------------------------------------------------------------------------------------------------------- build
def build(out, size=None, report=None, faces=None, select=None, min_seen=5, min_overlap=3, ss=4, dilate_steps=10,
          basecolor=None, region=None, region_faces=None, **proc):
    sources, rep = [], dict(out=str(out), sources={})
    fdata = None
    if faces:
        fsize, fdata = load_faces(faces)
        size = size or fsize
    lin = None
    if basecolor:
        bc = C.read_rgb8(basecolor); lin = C.s2l(bc)
        size = size or bc.shape[0]
        assert bc.shape[:2] == (size, size), f'BaseColor {bc.shape[:2]} is not {size}: Details must match its BaseColor'
        rep['basecolor_sha256'] = C.sha_file(basecolor)
    assert size, '--size, a faces.json "size" or a --basecolor is needed'
    R = np.zeros((size, size), np.float32)
    if select:
        assert fdata is not None, '--select needs --faces'
        m, frep = face_mask(fdata, select, size, min_seen, min_overlap, ss, dilate_steps)
        rep['sources']['faces'] = frep; sources.append(('faces', m))
    if lin is not None and (region or region_faces):
        if region:
            reg = C.read_rgb8(region).max(-1) > 0
        else:
            reg = np.zeros((size, size), bool)
            for k in region_faces:
                rr, cc = raster(uv_px(fdata[k]['uv'], size), size); reg[rr, cc] = True
        m, _cells, prep = field_cells(lin, reg, **proc)
        rep['sources']['procedural'] = dict(params=proc, regions=prep); sources.append(('procedural', m))
    assert sources, 'no mask source: give --select and/or --basecolor with --region / --region-faces'
    for name, m in sources:
        rep['sources'][name]['overlap_with_earlier'] = int(((m > 0) & (R > 0)).sum())
        np.maximum(R, m, out=R)
    r8 = C.write_details(out, R)
    rep['result'] = dict(size=size, texels=int((r8 > 0).sum()), full=int((r8 == 255).sum()),
                         coverage_pct=round(100.0 * float((r8 > 0).sum()) / size ** 2, 3), sha256=C.sha_file(out))
    if report:
        Path(report).write_text(json.dumps(rep, indent=1))
    return rep


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--out', required=True); ap.add_argument('--size', type=int); ap.add_argument('--report')
    ap.add_argument('--faces'); ap.add_argument('--select')
    ap.add_argument('--min-seen', type=int, default=5); ap.add_argument('--min-overlap', type=int, default=3)
    ap.add_argument('--ss', type=int, default=4); ap.add_argument('--dilate', type=int, default=10)
    ap.add_argument('--basecolor'); ap.add_argument('--region'); ap.add_argument('--region-faces')
    ap.add_argument('--hue-lo', type=float, default=55.0); ap.add_argument('--hue-hi', type=float, default=100.0)
    ap.add_argument('--min-chroma', type=float, default=25.0); ap.add_argument('--pick', default='low', choices=('low', 'high'))
    ap.add_argument('--min-cell', type=int, default=8); ap.add_argument('--hole-max', type=int, default=12)
    a = ap.parse_args(argv)
    try:
        rep = build(a.out, a.size, a.report, a.faces, parse_ids(a.select), a.min_seen, a.min_overlap, a.ss, a.dilate,
                    a.basecolor, a.region, parse_ids(a.region_faces) or None, hue_lo=a.hue_lo, hue_hi=a.hue_hi,
                    min_chroma=a.min_chroma, pick=a.pick, min_cell=a.min_cell, hole_max=a.hole_max)
    except Refused as e:
        print('REFUSED: the selection shares texels with seen unselected faces (collateral player colour). Nothing written.')
        print(e)
        sys.exit(2)
    print('DETAILS', a.out, json.dumps(rep['result']))
    for k, v in rep['sources'].items():
        print(' ', k, json.dumps({x: v[x] for x in v if x not in ('regions', 'painted_via_group_never_seen', 'params')}))
    return rep


if __name__ == '__main__':
    main()
