"""Derive runtime maps from a bake master: master texels -> any target UV layout, owners only, no HIGH loaded.

blender -b LOW.blend --factory-startup --python derive_maps.py -- recipe.json [recipe2.json ...]   (same LOW)
recipe = the ordinary bake_owner_maps.py recipe (plan, sources, pages, maps, uv_name, scope, only, opacity_classes,
         freeze, input_contract, highs, margin, out_dir) plus
  "master": ".../bake_master/<geo12>/master.json",
  "derive": {                                   # all optional
    "filters": {"NORMAL": "auto", "AO": "auto", "OPACITY": "point", "EMIT": "nearest"},
                                                # point = partition-constrained bilinear at the texel centre,
                                                # footprint = S x S stratified samples over the texel (S = ceil ratio),
                                                # auto = point up to AUTO_POINT_MAX master texels per target texel,
                                                #        footprint above (per face, by its density ratio),
                                                # nearest = one master texel (IDs), soft = unconstrained (alpha mips)
    "margin_mode": "baker",                     # baker = replay the direct bake's per-receiver EXTEND passes (a
                                                # later receiver's margin overwrites an earlier one's texels in reach);
                                                # owners = one EXTEND over every hit, no hit ever overwritten
    "emit_g": "nearest",                        # or "bilinear_id": G bilinear inside the same tile ID
    "id_partition": {"map": "EMIT", "channel": 0, "maps": ["NORMAL", "AO"]},   # also split by tile ID
    "uv_from_plan": false,                      # build uv_name in session from the plan's "uv" lists (candidate layout)
    "accept": [],                               # explicitly accepted differences: "samples", "blender"
    "receiver_normal_tolerance": null,          # keep_faces corner-normal tolerance (custom-normal quantization)
    "debug_flip_sign": false                    # tests only: a wrong bitangent sign must fail the comparison
  }
One recipe, two executors: bake_owner_maps.py bakes it, derive_maps.py derives it. The guards are NOT copied:
the unchanged bake_owner_maps.py source runs with preflight_only (scope, input contract, UV freeze of the target
layer, modifiers, exact owner receivers via keep_faces); then the master guards (LOW contract, npz hash, master data
for every scope face x map, HIGH names/file hashes, ray parameters, density ratio) refuse with "rebake master run X".
Per target texel: rasterise the target UV triangle at Blender's texel centres ((x+0.501)/W, (y+0.502)/H), same
surface point in the master, partition-constrained sample (chart, hit, optional ID), NORMAL converted with the
baker's own MikkTSpace frame of that receiver (RE_bake_normal_world_to_tangent), owners only, then the target
margin as IMB_filter_extend: a texel fills only next to an assigned EDGE neighbour (L1 growth), out-of-page texels
are unassigned, misses stay unassigned exactly as in a direct bake, and by default the passes replay the baker's
receiver order (margin_mode "baker"). Checked against the Blender 5.0.1 source (imbuf/intern/filter.cc,
render/intern/bake.cc, editors/object/object_bake_api.cc).
Writes <MAP>_<page>.exr/.png + owners_<page>.npz + derive_report.json (bake_report keys, so uv_fingerprint.py
check, compose and the QA tools consume it unchanged). The .blend is never saved.
The numpy core below imports without bpy (tests: test_master_derive.py). Method: references/bake-master.md.
"""
import hashlib
import json
import math
import os
import sys
import time
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
PIX_OFF = np.array([0.501, 0.502])        # Blender bake texel centre: uv = (x + 0.501) / W, (y + 0.502) / H
NORMAL_BIAS = 1e-5                        # normal_compress bias
START = {'NORMAL': (.5, .5, 1.), 'EMIT': (0., 0., 0.), 'AO': (1., 1., 1.), 'OPACITY': (0., 0., 0.)}
MAP_ORDER = ('NORMAL', 'EMIT', 'AO', 'OPACITY')
RAY_PARAMS = ('extrusion', 'max_ray_distance', 'samples', 'ao_distance')


# ============================================================================================ numpy core
def rasterize(tris_px, W, H, chunk=1_500_000):
    """Texels whose centre (x+0.501, y+0.502) lies in a triangle; rows bottom-up (Blender pixel order).

    tris_px (n,3,2): triangle corners in pixel units (u*W, v*H). Shared edges go to exactly one triangle
    (orientation tie rule); centres outside the page never exist, so faces placed outside 0..1 produce no
    texels (the UV-skip trick). Returns tri (k,), x (k,), y (k,), bary (k,3) with bary[:, i] = weight of corner i.
    """
    t = np.asarray(tris_px, np.float64).reshape(-1, 3, 2)
    empty = (np.zeros(0, np.int64), np.zeros(0, np.int64), np.zeros(0, np.int64), np.zeros((0, 3)))
    if not len(t):
        return empty
    p0, p1, p2 = t[:, 0], t[:, 1], t[:, 2]
    area = (p1[:, 0] - p0[:, 0]) * (p2[:, 1] - p0[:, 1]) - (p1[:, 1] - p0[:, 1]) * (p2[:, 0] - p0[:, 0])
    lo = np.floor(t.min(1) - PIX_OFF).astype(np.int64); hi = np.ceil(t.max(1) - PIX_OFF).astype(np.int64)
    lo = np.maximum(lo, 0); hi[:, 0] = np.minimum(hi[:, 0], W - 1); hi[:, 1] = np.minimum(hi[:, 1], H - 1)
    nx = hi[:, 0] - lo[:, 0] + 1; ny = hi[:, 1] - lo[:, 1] + 1
    cnt = np.where((np.abs(area) > 1e-12) & (nx > 0) & (ny > 0), nx * ny, 0)
    out, start = [], 0
    csum = np.cumsum(cnt)
    while start < len(t):
        base = csum[start - 1] if start else 0
        stop = max(int(np.searchsorted(csum, base + chunk, side='right')), start + 1)
        ids = np.arange(start, min(stop, len(t)))
        c = cnt[ids]; ids = ids[c > 0]; c = c[c > 0]
        start = min(stop, len(t))
        if not len(ids):
            continue
        tri = np.repeat(ids, c)
        loc = np.arange(len(tri)) - np.repeat(np.cumsum(c) - c, c)
        x = lo[tri, 0] + loc % nx[tri]; y = lo[tri, 1] + loc // nx[tri]
        cx = x + PIX_OFF[0]; cy = y + PIX_OFF[1]
        sg = np.sign(area[tri])
        E, keep = [], np.ones(len(tri), bool)
        for a, b in ((0, 1), (1, 2), (2, 0)):       # edge a->b; its function weighs the opposite corner
            ax, ay = t[tri, a, 0], t[tri, a, 1]; dx = (t[tri, b, 0] - ax) * sg; dy = (t[tri, b, 1] - ay) * sg
            e = dx * (cy - ay) - dy * (cx - ax)
            tie = (dy > 0) | ((dy == 0) & (dx < 0))  # reversed edge of the neighbour gets the other side
            keep &= (e > 0) | ((e == 0) & tie)
            E.append(e)
        if not keep.any():
            continue
        tri, x, y = tri[keep], x[keep], y[keep]
        e01, e12, e20 = (e[keep] for e in E)
        A = np.abs(area[tri])
        bary = np.stack([e12 / A, e20 / A, e01 / A], 1)
        out.append((tri, x, y, bary))
    if not out:
        return empty
    return tuple(np.concatenate(v) for v in zip(*out))


def master_px(uv, W, H):
    """master UV -> master pixel coordinates in which texel (i, j) sits exactly at (i, j)"""
    uv = np.asarray(uv, np.float64)
    return uv[..., 0] * W - PIX_OFF[0], uv[..., 1] * H - PIX_OFF[1]


def decode_normal(c):
    return (np.asarray(c, np.float64)[..., :3] - 0.5 - NORMAL_BIAS) * 2.0


def encode_normal(x):
    return np.asarray(x, np.float64) * 0.5 + 0.5 + NORMAL_BIAS


def to_tangent(n_obj, T, N, sign, G=None):
    """RE_bake_normal_world_to_tangent on the baker's frame, fed from an OBJECT-space master.

    n_obj (k,3) sum/mean of decoded master normals (normalize(M3^-1 n_world)); T, N (k,3) the barycentric
    interpolated (NOT normalised) loop tangent and normal; sign (k,) +-1. G = M3^T M3 (identity for rigid LOWs):
    the baker applies M3^T to n_world before the frame, and n_world ~ M3 n_obj. Solves [T | B | N] x = G n with
    B = sign * cross(N, T) (full inverse like invert_m3, frame not assumed orthonormal), normalises, returns x
    and a mask of solvable frames.
    """
    n = np.asarray(n_obj, np.float64)
    if G is not None:
        n = n @ np.asarray(G, np.float64).T
    T = np.asarray(T, np.float64); N = np.asarray(N, np.float64)
    B = np.asarray(sign, np.float64)[:, None] * np.cross(N, T)
    M = np.stack([T, B, N], axis=2)                       # columns T, B, N
    det = np.linalg.det(M) if len(M) else np.zeros(0)
    ok = np.abs(det) > 1e-12
    x = np.zeros_like(n); x[:, 2] = 1.0
    if ok.any():
        x[ok] = np.linalg.solve(M[ok], n[ok][..., None])[..., 0]
    ln = np.linalg.norm(x, axis=1); ok &= ln > 1e-12
    x[ok] /= ln[ok, None]
    return x, ok


_SEARCH = sorted(((dx, dy) for dx in range(-2, 3) for dy in range(-2, 3)), key=lambda d: (max(abs(d[0]), abs(d[1])), d[0] ** 2 + d[1] ** 2, d))


def sample_master(px, py, chart_id, chart_raster, usable, status, values, mode='bilinear', ids=None, id_tol=1e-3):
    """Partition-constrained resampling of ONE master page (rows bottom-up, texel (i, j) at (i, j)).

    A master texel is usable for a sample only inside the sample's chart (chart_raster == chart_id, usable = in a
    chart and off an ambiguous chart border), with the hit status (status, bool) of the nearest usable texel and,
    if ids is given, among hits the same ID (|id - id_nearest| < id_tol). Bilinear weights of unusable texels are
    zeroed and renormalised; with none of the four usable the nearest usable texel in 3x3 then 5x5 is taken.
    mode 'bilinear' | 'nearest' | 'soft' (bilinear, chart constraint only).
    Returns vals (k,C) weighted mean, hit (k,) bool, found (k,) bool.
    """
    px = np.asarray(px, np.float64); py = np.asarray(py, np.float64); chart_id = np.asarray(chart_id)
    k = len(px); Hh, Ww = chart_raster.shape; C = values.shape[2]
    vals = np.zeros((k, C)); hit = np.zeros(k, bool); found = np.zeros(k, bool)
    if not k:
        return vals, hit, found
    x0 = np.floor(px).astype(np.int64); y0 = np.floor(py).astype(np.int64); fx = px - x0; fy = py - y0
    cx = np.stack([x0, x0 + 1, x0, x0 + 1], 1); cy = np.stack([y0, y0, y0 + 1, y0 + 1], 1)
    w = np.stack([(1 - fx) * (1 - fy), fx * (1 - fy), (1 - fx) * fy, fx * fy], 1)
    inb = (cx >= 0) & (cx < Ww) & (cy >= 0) & (cy < Hh)
    cxc = np.clip(cx, 0, Ww - 1); cyc = np.clip(cy, 0, Hh - 1)
    ok = inb & usable[cyc, cxc] & (chart_raster[cyc, cxc] == chart_id[:, None])
    d2 = np.where(ok, (cx - px[:, None]) ** 2 + (cy - py[:, None]) ** 2, np.inf)
    j = np.argmin(d2, 1); ar = np.arange(k)
    found = np.isfinite(d2[ar, j]); nx = cx[ar, j]; ny = cy[ar, j]
    lost = np.nonzero(~found)[0]
    if len(lost):                                          # no usable corner: nearest usable within 3x3, 5x5
        rx = np.rint(px[lost]).astype(np.int64); ry = np.rint(py[lost]).astype(np.int64)
        best = np.full(len(lost), np.inf); bx = np.zeros(len(lost), np.int64); by = np.zeros(len(lost), np.int64)
        for dx, dy in _SEARCH:
            qx, qy = rx + dx, ry + dy
            inside = (qx >= 0) & (qx < Ww) & (qy >= 0) & (qy < Hh)
            qxc, qyc = np.clip(qx, 0, Ww - 1), np.clip(qy, 0, Hh - 1)
            good = inside & usable[qyc, qxc] & (chart_raster[qyc, qxc] == chart_id[lost])
            dd = np.where(good, (qx - px[lost]) ** 2 + (qy - py[lost]) ** 2, np.inf)
            better = dd < best
            best[better] = dd[better]; bx[better] = qx[better]; by[better] = qy[better]
        got = np.isfinite(best)
        nx[lost[got]] = bx[got]; ny[lost[got]] = by[got]; found[lost[got]] = True
    f = found
    nxf, nyf = nx[f], ny[f]
    hit[f] = status[nyf, nxf]
    if mode == 'nearest':
        vals[f] = values[nyf, nxf]
        return vals, hit, found
    use = ok[f].copy()
    if mode != 'soft':
        use &= status[cyc[f], cxc[f]] == hit[f][:, None]
        if ids is not None:
            same = np.abs(ids[cyc[f], cxc[f]] - ids[nyf, nxf][:, None]) < id_tol
            use &= same | ~hit[f][:, None]
    ww = w[f] * use; sw = ww.sum(1)
    v = (ww[..., None] * values[cyc[f], cxc[f]]).sum(1)
    good = sw > 0
    v[good] /= sw[good, None]
    v[~good] = values[nyf[~good], nxf[~good]]
    vals[f] = v
    return vals, hit, found


def mirror_clamp(u, mx):
    """Cycles bake_clamp_mirror_repeat: fold a barycentric back into 0..mx"""
    mx = np.where(mx > 0, mx, 1e-12); q = u / mx; fq = np.floor(q); r = q - fq
    return np.where(fq.astype(np.int64) & 1, 1.0 - r, r) * mx


def footprint_offsets(S):
    g = (np.arange(S) + 0.5) / S - 0.5
    ox, oy = np.meshgrid(g, g)
    return np.stack([ox.ravel(), oy.ravel()], 1)


def extend_fill(img, assigned, passes):
    """Blender's EXTEND margin, IMB_filter_extend (imbuf/intern/filter.cc, Blender 5.0.1) with the bake mask.
    Per pass, an unassigned texel is filled only when one of its 4 EDGE neighbours is assigned (so the front
    grows an L1 diamond, one texel per pass); its value is the weighted mean of its assigned 8-neighbours (edge 2,
    diagonal 1). Texels outside the page are unassigned (filter_make_index returns -1; nothing clamps or wraps).
    Filled texels count as assigned in the next pass. Assigned texels are never touched; every other texel in
    reach is overwritten, whatever it held. img (H,W,C). Returns (img, assigned)."""
    img = np.array(img, np.float64, copy=True); a = np.array(assigned, bool, copy=True)
    H, W = a.shape
    for _ in range(int(passes)):
        pa = np.pad(a, 1, mode='constant', constant_values=False)
        pi = np.pad(img, ((1, 1), (1, 1), (0, 0)), mode='constant')
        gate = np.zeros((H, W), bool)
        for dy, dx in ((0, -1), (0, 1), (-1, 0), (1, 0)):
            gate |= pa[1 + dy:1 + dy + H, 1 + dx:1 + dx + W]
        new = ~a & gate
        if not new.any():
            break
        acc = np.zeros_like(img); ws = np.zeros((H, W))
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                wt = 1.0 if dx and dy else 2.0
                m = pa[1 + dy:1 + dy + H, 1 + dx:1 + dx + W]
                acc += (wt * m)[..., None] * pi[1 + dy:1 + dy + H, 1 + dx:1 + dx + W]
                ws += wt * m
        img[new] = acc[new] / ws[new, None]
        a |= new
    return img, a


def replay_margin(start, passes, margin):
    """The margin of a direct bake_owner_maps bake, replayed. The baker bakes one receiver at a time into the
    same image (use_clear=False): it writes that receiver's hit texels (its bake mask) and then runs EXTEND with
    that mask only, which overwrites every texel within `margin` of those hits that is not in the mask - misses,
    gutters AND texels an earlier receiver wrote. passes = [(ys, xs, vals (k,C))] in bake order.
    start (H,W,C) = the image's generated colour. One pass holding every hit = the order-free 'owners' mode."""
    img = np.array(start, np.float64, copy=True); H, W = img.shape[:2]; r = int(margin) + 1
    for ys, xs, vals in passes:
        if not len(ys):
            continue
        img[ys, xs] = vals
        if int(margin) <= 0:
            continue
        # exact crop: a pass fills only within `margin` of its mask, so texels farther than margin + 1 are
        # never assigned in it and treating them as outside changes nothing
        y0, y1 = max(int(ys.min()) - r, 0), min(int(ys.max()) + r + 1, H)
        x0, x1 = max(int(xs.min()) - r, 0), min(int(xs.max()) + r + 1, W)
        m = np.zeros((y1 - y0, x1 - x0), bool); m[ys - y0, xs - x0] = True
        img[y0:y1, x0:x1], _ = extend_fill(img[y0:y1, x0:x1], m, margin)
    return img


AUTO_POINT_MAX = 4.0     # 'auto': above this master/target ratio a bilinear point sample reads < 1/4 of the footprint


def choose_filter(mode, ratio):
    """per-texel filter: 'auto' -> 'point' where ratio <= AUTO_POINT_MAX, else 'footprint'; any other mode as is"""
    ratio = np.asarray(ratio, np.float64)
    if mode != 'auto':
        return np.full(ratio.shape, mode, object)
    return np.where(ratio > AUTO_POINT_MAX, 'footprint', 'point').astype(object)


def shoelace(p):
    p = np.asarray(p, np.float64)
    return 0.5 * abs(np.dot(p[:, 0], np.roll(p[:, 1], -1)) - np.dot(p[:, 1], np.roll(p[:, 0], -1)))


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 22), b''):
            h.update(b)
    return h.hexdigest()


def write_json_atomic(path, data):
    path = Path(path); tmp = path.with_suffix(path.suffix + '.tmp')
    tmp.write_text(json.dumps(data, indent=1)); os.replace(tmp, path)


def page_size(pages, pg):
    v = pages[pg]
    return (int(v), int(v)) if not isinstance(v, (list, tuple)) else (int(v[0]), int(v[1]))


# ============================================================================================ Blender side
def exec_bake_owner_maps(recipe_path, overrides=(), receiver_normal_tolerance=None, argv_extra=()):
    """Run the UNCHANGED bake_owner_maps.py source (the ridge_v2/run_bake.py exec pattern). overrides: [(old, new)]
    source replacements whose anchor must occur exactly once. Returns the script's globals."""
    src_path = HERE / 'bake_owner_maps.py'
    src = src_path.read_text(encoding='utf-8')
    for old, new in overrides:
        assert src.count(old) == 1, f'bake_owner_maps.py changed ({old!r} x{src.count(old)}) - review the override'
        src = src.replace(old, new)
    if receiver_normal_tolerance is not None:
        anchor = "fp_mod, pair, contract = _load('uv_fingerprint'), _load('bake_pair'), _load('bake_contract')"
        assert src.count(anchor) == 1, 'bake_owner_maps.py changed - review the tolerance override'
        src = src.replace(anchor, anchor + (
            "\n_keep = contract.keep_faces\n"
            f"contract.keep_faces = lambda ob, idx: _keep(ob, idx, normal_tolerance={float(receiver_normal_tolerance)!r})"))
    g = {'__name__': '__main__', '__file__': str(src_path)}
    old_argv = list(sys.argv)
    sys.argv = [old_argv[0], '--', str(recipe_path), *argv_extra]
    try:
        exec(compile(src, str(src_path), 'exec'), g)
    except SystemExit as e:
        if e.code not in (0, None):
            raise
    finally:
        sys.argv = old_argv
    return g


def uv_layer_from_plan(sources, plan, uv_name):
    """Candidate layouts as data: create uv_name in session from the plan's per-face "uv" lists.
    Faces without an entry go to (-2, -2) (never baked, never derived). Refuses an existing layer."""
    import bpy
    for key, name in sources.items():
        me = bpy.data.objects[name].data
        if me.uv_layers.get(uv_name):
            raise ValueError(f'{name}: {uv_name} already exists; uv_from_plan never overwrites a real layer')
        n = len(me.polygons)
        ls = np.empty(n, np.int32); me.polygons.foreach_get('loop_start', ls)
        lt = np.empty(n, np.int32); me.polygons.foreach_get('loop_total', lt)
        a = np.full((len(me.loops), 2), -2.0)
        for fk, e in plan.items():
            pre, idx = fk.rsplit(':', 1)
            if pre != key or 'uv' not in e:
                continue
            i = int(idx); uv = np.asarray(e['uv'], np.float64)
            assert uv.shape == (lt[i], 2), f'{fk}: plan uv has {uv.shape[0]} corners, mesh {lt[i]}'
            a[ls[i]:ls[i] + lt[i]] = uv
        uvl = me.uv_layers.new(name=uv_name)
        uvl.data.foreach_set('uv', a.astype(np.float32).ravel())


def mesh_arrays(ob, uv_name):
    me = ob.data; me.calc_loop_triangles()
    nl, npo, nt = len(me.loops), len(me.polygons), len(me.loop_triangles)
    co = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get('co', co)
    lv = np.empty(nl, np.int32); me.loops.foreach_get('vertex_index', lv)
    cn = np.empty(nl * 3, np.float32); me.corner_normals.foreach_get('vector', cn)
    uv = np.empty(nl * 2, np.float32); me.uv_layers[uv_name].data.foreach_get('uv', uv)
    ls = np.empty(npo, np.int32); me.polygons.foreach_get('loop_start', ls)
    lt = np.empty(npo, np.int32); me.polygons.foreach_get('loop_total', lt)
    sm = np.zeros(npo, bool); me.polygons.foreach_get('use_smooth', sm)
    pn = np.empty(npo * 3, np.float32); me.polygons.foreach_get('normal', pn)
    tl = np.empty(nt * 3, np.int32); me.loop_triangles.foreach_get('loops', tl)
    tp = np.empty(nt, np.int32); me.loop_triangles.foreach_get('polygon_index', tp)
    return dict(pos=co.reshape(-1, 3)[lv].astype(np.float64), cn=cn.reshape(-1, 3).astype(np.float64),
                uv=uv.reshape(-1, 2).astype(np.float64), ls=ls, lt=lt, smooth=sm, pn=pn.reshape(-1, 3).astype(np.float64),
                tl=tl.reshape(-1, 3), tp=tp)


def receiver_tangents(R):
    """MikkTSpace frames as the baker builds them on this receiver: quads as quads, ngons as their loop
    triangles (Mesh.calc_tangents refuses ngons), the receiver's corner normals as exact input (free float
    custom normals). -> T (nt,3,3) unit tangents per loop-triangle corner, S (nt,3) bitangent signs, info."""
    import bpy
    nt, npo = len(R['tl']), len(R['ls'])
    big = R['lt'] > 4
    polys = [np.arange(R['ls'][p], R['ls'][p] + R['lt'][p]) for p in range(npo) if not big[p]]
    ngon_tris = np.nonzero(big[R['tp']])[0]
    first_tri = len(polys)
    polys += [R['tl'][k] for k in ngon_tris]
    corners = np.concatenate(polys) if polys else np.zeros(0, np.int64)
    sizes = [len(p) for p in polys]; starts = np.concatenate([[0], np.cumsum(sizes)[:-1]]).astype(np.int64)
    me = bpy.data.meshes.new('__derive_tangent_scratch')
    try:
        faces, s = [], 0
        for n in sizes:
            faces.append(list(range(s, s + n))); s += n
        me.from_pydata(R['pos'][corners].tolist(), [], faces)
        uvl = me.uv_layers.new(name='UV'); uvl.data.foreach_set('uv', R['uv'][corners].astype(np.float32).ravel())
        me.polygons.foreach_set('use_smooth', np.ones(len(faces), bool))
        cnat = me.attributes.new('custom_normal', 'FLOAT_VECTOR', 'CORNER')
        cnat.data.foreach_set('vector', R['cn'][corners].astype(np.float32).ravel())
        me.update()
        got = np.empty(len(corners) * 3, np.float32); me.corner_normals.foreach_get('vector', got)
        normal_err = float(np.abs(got.reshape(-1, 3) - R['cn'][corners]).max()) if len(corners) else 0.0
        me.calc_tangents(uvmap='UV')
        tan = np.empty(len(corners) * 3, np.float32); me.loops.foreach_get('tangent', tan); tan = tan.reshape(-1, 3)
        sgn = np.empty(len(corners), np.float32); me.loops.foreach_get('bitangent_sign', sgn)
    finally:
        bpy.data.meshes.remove(me)
    loop_t = np.zeros((len(R['cn']), 3)); loop_s = np.ones(len(R['cn']))
    for q in range(first_tri):                                # tris and quads: 1:1 loops
        idx = polys[q]; loop_t[idx] = tan[starts[q]:starts[q] + len(idx)]; loop_s[idx] = sgn[starts[q]:starts[q] + len(idx)]
    spread = 0.0
    for q in range(first_tri, len(polys)):                   # ngons: the loop keeps the LAST triangle's value
        idx = polys[q]; v = tan[starts[q]:starts[q] + 3]
        prev = loop_t[idx]; seen = np.linalg.norm(prev, axis=1) > 0
        if seen.any():
            spread = max(spread, float(np.degrees(np.arccos(np.clip((prev[seen] * v[seen]).sum(1), -1, 1))).max()))
        loop_t[idx] = v; loop_s[idx] = sgn[starts[q]:starts[q] + 3]
    T = loop_t[R['tl']]; S = loop_s[R['tl']]
    return T, S, dict(ngon_triangles=int(len(ngon_tris)), ngon_tangent_spread_deg=spread, input_normal_error=normal_err)


def load_page(path, cache):
    """float32 (H,W,3) rows bottom-up from an EXR through Blender; one page kept per path."""
    import bpy
    path = str(path)
    if path in cache:
        return cache[path]
    im = bpy.data.images.load(path, check_existing=False); im.colorspace_settings.name = 'Non-Color'
    w, h = im.size; ch = im.channels
    a = np.empty(w * h * ch, np.float32); im.pixels.foreach_get(a)
    bpy.data.images.remove(im)
    arr = a.reshape(h, w, ch)[..., :3].copy()
    cache.clear(); cache[path] = arr
    return arr


def save_map(bs, pair, kind, stem, arr, out):
    import bpy
    H, W = arr.shape[:2]
    img = bpy.data.images.new(stem, W, H, alpha=False, float_buffer=True); img.colorspace_settings.name = 'Non-Color'
    rgba = np.ones((H, W, 4), np.float32); rgba[..., :3] = arr
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = str(out / f'{stem}.exr'); img.file_format = 'OPEN_EXR'; img.save()
    s = bs.render.image_settings
    s.file_format = 'PNG'; s.color_mode = 'RGB' if kind in ('NORMAL', 'EMIT') else 'BW'; s.color_depth = '16'
    bs.view_settings.view_transform = 'Raw'
    img.save_render(str(out / f'{stem}.png'), scene=bs)
    stats = pair.image_statistics(img, kind if kind == 'NORMAL' else 'AO')
    bpy.data.images.remove(img)
    return dict(stats=stats, master=str(out / f'{stem}.exr'), preview=str(out / f'{stem}.png'))


class Refuse(RuntimeError):
    pass


def run_regions(run):
    return {f: rid for rid, r in run['regions'].items() for f in r['faces']}


def master_guards(cfg, g, man, mdir, maps):
    """Everything that must hold before a derive may stand in for a direct bake. Raises Refuse."""
    import bpy
    dcfg = cfg.get('derive', {}) or {}; accept = set(dcfg.get('accept', []))
    try:
        g['contract'].check_contract({'input_contract': str(mdir / 'low_contract.json')}, g['input_fp'])
    except ValueError:
        raise Refuse('LOW contract differs from the master (geometry changed): make a new master geo directory '
                     'and rebake its runs') from None
    if sha256_file(mdir / 'master_uv.npz') != man['npz_sha256']:
        raise Refuse('master_uv.npz differs from master.json (layout drift): restore it, never rebuild in place')
    if man.get('blender') != bpy.app.version_string and 'blender' not in accept:
        raise Refuse(f'master made in Blender {man.get("blender")}, this is {bpy.app.version_string}: rerun the '
                     'fixture proof (test_master_derive.py) and accept "blender" explicitly')
    scope = g['scope']; face_region = scope['face_region']; allowed = scope['allowed_highs']
    files = {n: h.get('file') for h in cfg['highs'] for n in h['objects']}
    file_sha, problems, runs_used, regions = {}, [], {}, {}
    for face in scope['required']:
        e = man['faces'].get(face)
        if e is None:
            problems.append(f'{face}: not in the master layout (extend the master, then bake it)'); continue
        want = sorted(allowed[face_region[face]])
        for m in maps:
            run = e['maps'].get(m)
            if run is None:
                problems.append(f'{face}: no master {m} (no HIGH covered it or it was never baked)'); continue
            r = man['runs'][run]; runs_used.setdefault(run, set()).add(m)
            if run not in regions:
                regions[run] = run_regions(r)
            hn = sorted(r['regions'][regions[run][face]]['highs'])
            if hn != want:
                problems.append(f'{face}: {m} came from HIGH {hn}, the region wants {want} - rebake master run {run}')
                continue
            for h in r['highs']:
                f = files.get(h['name'])
                if h['name'] in want and f:
                    if f not in file_sha:
                        file_sha[f] = sha256_file(f)
                    if file_sha[f] != h['sha256']:
                        problems.append(f'HIGH {h["name"]} ({f}) changed since run {run} - rebake master run {run}')
    defaults = {'extrusion': .05, 'max_ray_distance': .25, 'samples': 16, 'ao_distance': .15}
    for run, used in runs_used.items():
        p = man['runs'][run]['params']
        for k in RAY_PARAMS:
            if k == 'ao_distance' and 'AO' not in used:
                continue
            want = cfg.get(k, defaults[k])
            if abs(float(p[k]) - float(want)) > 1e-9 and k not in accept:
                problems.append(f'{k}: master run {run} used {p[k]}, the recipe wants {want} - rebake master run {run}')
    if problems:
        raise Refuse('derive refused:\n  ' + '\n  '.join(sorted(set(problems))[:60]))
    return sorted(runs_used)


def footprint_sample(cat, sel, values, args, ids, S_of):
    """S x S stratified samples over the target texel (1 px box) mapped through the target triangle, folded back
    into it like Cycles' bake_clamp_mirror_repeat; per texel the majority hit status and the mean of that
    partition. S_of (k,) samples per axis for the selected texels (max(2, ceil(ratio))).
    cat: x, y, chart per texel, tri per texel indexing tri_tt / tri_tm (target / master pixel corners)."""
    k = len(sel); C = values.shape[2]
    vals = np.zeros((k, C)); hit = np.zeros(k, bool); found = np.zeros(k, bool)
    for S in np.unique(S_of):
        part = np.nonzero(S_of == S)[0]; idx = sel[part]
        off = footprint_offsets(int(S)); m = len(off)
        P = np.stack([cat['x'][idx] + PIX_OFF[0], cat['y'][idx] + PIX_OFF[1]], 1)[:, None, :] + off[None]
        tt = cat['tri_tt'][cat['tri'][idx]]; tm = cat['tri_tm'][cat['tri'][idx]]
        v0 = tt[:, 1] - tt[:, 0]; v1 = tt[:, 2] - tt[:, 0]
        d = v0[:, 0] * v1[:, 1] - v0[:, 1] * v1[:, 0]
        q = P - tt[:, None, 0]
        b1 = (q[..., 0] * v1[:, None, 1] - q[..., 1] * v1[:, None, 0]) / d[:, None]
        b2 = (v0[:, None, 0] * q[..., 1] - v0[:, None, 1] * q[..., 0]) / d[:, None]
        b0 = 1 - b1 - b2
        u = mirror_clamp(b0, np.ones_like(b0)); v = mirror_clamp(b1, 1 - u); w = 1 - u - v
        M = u[..., None] * tm[:, None, 0] + v[..., None] * tm[:, None, 1] + w[..., None] * tm[:, None, 2]
        vv, hh, ff = sample_master(M[..., 0].ravel(), M[..., 1].ravel(), np.repeat(cat['chart'][idx], m), *args,
                                   values, mode='bilinear', ids=ids)
        vv = vv.reshape(len(idx), m, C); hh = hh.reshape(len(idx), m); ff = ff.reshape(len(idx), m)
        maj = (hh & ff).sum(1) * 2 >= ff.sum(1)
        use = ff & (hh == maj[:, None])
        sw = use.sum(1)
        vals[part] = (vv * use[..., None]).sum(1) / np.maximum(sw, 1)[:, None]
        hit[part] = maj & (sw > 0); found[part] = ff.any(1)
    return vals, hit, found


def cleanup(g, made_layers):
    """remove what one derive added to the session (several recipes may run in one Blender launch)"""
    import bpy
    for ts in g.get('targets', {}).values():
        for t in ts:
            me, mats = t.data, [m for m in t.data.materials if m]
            bpy.data.objects.remove(t)
            if me.users == 0:
                bpy.data.meshes.remove(me)
            for m in mats:
                if m.users == 0:
                    bpy.data.materials.remove(m)
    if g.get('bs') is not None and g['bs'].name in bpy.data.scenes:
        bpy.data.scenes.remove(g['bs'])
    for name, uv in made_layers:
        me = bpy.data.objects[name].data
        if me.uv_layers.get(uv):
            me.uv_layers.remove(me.uv_layers[uv])


def main():
    """derive_maps.py -- recipe.json [recipe2.json ...]: several recipes on ONE LOW share one Blender launch"""
    paths = [Path(p) for p in sys.argv[sys.argv.index('--') + 1:]]
    missing_any = False
    for p in paths:
        g, made = {}, []
        try:
            missing_any |= derive(p, g, made)
        finally:
            cleanup(g, made)
    if missing_any:
        sys.exit(3)


def derive(recipe_path, g_out, made_layers):
    import bpy
    t0 = time.time()
    cfg = json.loads(Path(recipe_path).read_text())
    dcfg = cfg.get('derive', {}) or {}
    mpath = Path(cfg['master']).resolve(); mdir = mpath.parent
    man = json.loads(mpath.read_text())
    out = Path(cfg['out_dir']).resolve(); out.mkdir(parents=True, exist_ok=True)
    cfg['out_dir'] = str(out)                     # Blender saves EXRs only to absolute paths (master_bake.py)
    maps = [k for k in MAP_ORDER if k in cfg.get('maps', ['NORMAL'])]
    UV = cfg.get('uv_name', 'UV_Final')
    if dcfg.get('uv_from_plan'):
        uv_layer_from_plan(cfg['sources'], json.loads(Path(cfg['plan']).read_text())['faces'], UV)
        made_layers += [(name, UV) for name in cfg['sources'].values()]

    # 1. guards, reused: the unchanged baker in preflight_only mode builds the exact owner receivers
    tmp = out / '_derive_preflight_recipe.json'
    tmp.write_text(json.dumps(dict(cfg, preflight_only=True), indent=1))
    try:
        g = exec_bake_owner_maps(tmp, receiver_normal_tolerance=dcfg.get('receiver_normal_tolerance'))
    finally:
        tmp.unlink()
    g_out.update(g)
    if 'preflight' not in g:
        raise Refuse('bake_owner_maps preflight did not complete')
    # 2. master guards
    runs = master_guards(cfg, g, man, mdir, maps)
    t_guard = time.time() - t0
    npz = np.load(mdir / 'master_uv.npz')
    plan, scope, targets, checks = g['plan'], g['scope'], g['targets'], g['receiver_checks']
    pages = cfg['pages']; margin = int(cfg.get('margin', 4))
    cut = set(cfg['opacity_classes']) if cfg.get('opacity_classes') else None
    filters = dict({'NORMAL': 'auto', 'AO': 'auto', 'OPACITY': 'point', 'EMIT': 'nearest'}, **dcfg.get('filters', {}))
    margin_mode = dcfg.get('margin_mode', 'baker')
    if margin_mode not in ('baker', 'owners'):
        raise Refuse(f'derive.margin_mode {margin_mode!r}: use "baker" or "owners"')
    idp = dcfg.get('id_partition')
    names = {f'T_{key}_{pg}_{rid}': (key, pg, rid) for key in cfg['sources'] for pg in pages for rid in scope['allowed_highs']}
    flip = bool(dcfg.get('debug_flip_sign'))
    master_pages = {k: page_size(man['pages'], k) for k in man['pages']}
    mWH = np.array([master_pages[f'M{p}'] for p in range(len(master_pages))], np.float64)   # pages M0..Mk
    src_arrays, faces_rep, report_targets, images, pages_written = {}, {}, {}, {}, {}
    for pg, ts in targets.items():
        W, H = page_size(pages, pg)
        keys_rec = ['x', 'y', 'face', 'T', 'N', 'S', 'mpage', 'mpx', 'mpy', 'chart', 'recv', 'tri']
        rec = {k: [] for k in keys_rec}
        tri_tt, tri_tm, ntri = [], [], 0                  # per loop triangle: target / master pixel corners
        face_keys, report_targets[pg] = [], {}
        for ti, t in enumerate(ts):                      # ts = the baker's receiver order on this page
            key, _, rid = names[t.name]
            src = cfg['sources'][key]
            if src not in src_arrays:
                src_arrays[src] = mesh_arrays(bpy.data.objects[src], UV)
            S_ = src_arrays[src]; R = mesh_arrays(t, UV)
            fids = list(checks[t.name]['face_ids'])
            r2s = np.zeros(len(R['cn']), np.int64)       # receiver loop -> source loop, verified by positions
            for i, f in enumerate(fids):
                rs, n = int(R['ls'][i]), int(R['lt'][i]); ss = int(S_['ls'][f])
                if S_['lt'][f] != n:
                    raise Refuse(f'{t.name}: receiver face {i} corner count differs from {key}:{f}')
                pr, ps = R['pos'][rs:rs + n], S_['pos'][ss:ss + n]
                for sh in range(n):
                    if np.array_equal(pr, np.roll(ps, -sh, 0)):
                        r2s[rs:rs + n] = ss + (np.arange(n) + sh) % n
                        break
                else:
                    raise Refuse(f'{t.name}: receiver face {i} does not match {key}:{f} by vertex positions')
            Tt, St, tinfo = receiver_tangents(R)
            if flip:
                St = -St
            muv = npz[f'uv_{key}'][r2s]
            fpage = npz[f'page_{key}'][fids].astype(np.int64); fchart = npz[f'chart_{key}'][fids].astype(np.int64)
            if (fpage < 0).any():
                raise Refuse(f'{t.name}: {int((fpage < 0).sum())} faces are outside the master layout')
            gkeys = [f'{key}:{f}' for f in fids]
            base = len(face_keys); face_keys += gkeys
            tri, x, y, bary = rasterize(R['uv'][R['tl']] * [W, H], W, H)
            poly = R['tp'][tri]
            Tx = np.einsum('ki,kij->kj', bary, Tt[tri])
            Nx = np.where(R['smooth'][poly][:, None], np.einsum('ki,kij->kj', bary, R['cn'][R['tl'][tri]]), R['pn'][poly])
            Sx = np.where((bary * St[tri]).sum(1) < 0, -1.0, 1.0)
            mp = fpage[poly]
            ttm = muv[R['tl']] * mWH[fpage[R['tp']]][:, None, :] - PIX_OFF   # master pixel coords per corner
            mxy = np.einsum('ki,kij->kj', bary, ttm[tri])
            vals = dict(x=x, y=y, face=base + poly, T=Tx, N=Nx, S=Sx, mpage=mp, mpx=mxy[:, 0], mpy=mxy[:, 1],
                        chart=fchart[poly], recv=np.full(len(x), ti), tri=ntri + tri)
            tri_tt.append(R['uv'][R['tl']] * [W, H]); tri_tm.append(ttm); ntri += len(R['tl'])
            for k_ in keys_rec:
                rec[k_].append(vals[k_])
            flat = np.nonzero(~R['smooth'])[0]             # the baker's flat-face N is the face normal; report how far
            flat_dev = 0.0                                  # the corner normals of flat faces are from it
            if len(flat):
                li = np.concatenate([np.arange(R['ls'][p], R['ls'][p] + R['lt'][p]) for p in flat])
                lp = np.concatenate([np.full(R['lt'][p], p) for p in flat])
                cn = R['cn'][li] / np.maximum(np.linalg.norm(R['cn'][li], axis=1, keepdims=True), 1e-12)
                pn_ = R['pn'][lp] / np.maximum(np.linalg.norm(R['pn'][lp], axis=1, keepdims=True), 1e-12)
                flat_dev = float(np.degrees(np.arccos(np.clip((cn * pn_).sum(1), -1, 1))).max())
            for i, f in enumerate(fids):                   # linear density ratio master / target per face
                rs, n = int(R['ls'][i]), int(R['lt'][i])
                at = shoelace(R['uv'][rs:rs + n] * [W, H]); am = shoelace(muv[rs:rs + n] * mWH[fpage[i]])
                faces_rep[gkeys[i]] = dict(page=pg, texels=0, ratio=float(math.sqrt(am / at)) if at > 0 else None,
                                           missing=0, misses={}, cls=plan[gkeys[i]].get('material'))
            rc = checks[t.name]
            report_targets[pg][t.name] = dict(faces=len(fids), tangent=tinfo, bake_order=ti,
                                              normal_error_after=rc.get('normal_error_after'),
                                              normal_tolerance=rc.get('normal_tolerance'), flat_faces=int(len(flat)),
                                              flat_corner_vs_face_normal_max_deg=flat_dev)
        cat = {k: np.concatenate(v) for k, v in rec.items()}
        cat['tri_tt'] = np.concatenate(tri_tt); cat['tri_tm'] = np.concatenate(tri_tm)
        n = len(cat['x']); xi = cat['x'].astype(np.int64); yi = cat['y'].astype(np.int64); fi = cat['face'].astype(np.int64)
        double = n - len(np.unique(yi * W + xi))
        cnt = np.bincount(fi, minlength=len(face_keys))
        for i, k in enumerate(face_keys):
            faces_rep[k]['texels'] = int(cnt[i])
        low = [k for k in face_keys if faces_rep[k]['ratio'] is not None and faces_rep[k]['ratio'] < 0.75]
        if low:
            raise Refuse(f'master density below 0.75 x target on {len(low)} faces (e.g. {low[:5]}): the master would '
                         'magnify; make it denser (class_factor) and rebake that run')
        raster = np.full((H, W), -1, np.int32); raster[yi, xi] = fi
        np.savez_compressed(out / f'owners_{pg}.npz', face=raster, keys=np.array(face_keys))
        Gs = []
        for t in ts:
            M3 = np.array(t.matrix_world.to_3x3(), np.float64)
            if abs(np.linalg.det(M3)) < 1e-12:
                raise Refuse(f'{t.name}: non-invertible object matrix')
            Gs.append(M3.T @ M3)
        if any(not np.allclose(v, Gs[0]) for v in Gs):
            raise Refuse('receivers with different object transforms on one page are not supported')
        cls = np.array([plan[k].get('material') for k in face_keys], object)
        ratio_t = np.array([faces_rep[k]['ratio'] or 1.0 for k in face_keys])[fi]
        for kind in maps:
            vals = np.zeros((n, 3)); hit = np.zeros(n, bool); found = np.zeros(n, bool)
            solid = np.zeros(n, bool)
            if kind == 'OPACITY' and cut is not None:
                solid = np.array([c not in cut for c in cls], bool)[fi]
            todo = ~solid
            mode = filters.get(kind, 'point')
            fmode = choose_filter(mode, ratio_t)          # per texel ('auto' resolves by the density ratio)
            for mk in np.unique(cat['mpage'][todo]).astype(int):
                cz = np.load(mdir / f'charts_M{mk}.npz')
                craster = cz['chart']; usable = (craster >= 0) & ~cz['border']
                in_page = np.nonzero(todo & (cat['mpage'] == mk))[0]
                run_of = np.array([man['faces'][face_keys[f]]['maps'][kind] for f in fi[in_page]], object)
                for run in sorted(set(run_of)):
                    sel = in_page[run_of == run]
                    rdir = Path(man['runs'][run]['dir'])
                    status = load_page(rdir / f'OPACITY_M{mk}.exr', {})[..., 0] >= 0.5
                    ids = None
                    if idp and kind in idp.get('maps', []):
                        erun = {man['faces'][face_keys[f]]['maps'].get(idp['map']) for f in fi[sel]}
                        if len(erun) != 1 or None in erun:
                            raise Refuse(f'id_partition needs one {idp["map"]} run for the faces on M{mk}')
                        ids = load_page(Path(man['runs'][erun.pop()]['dir']) / f'{idp["map"]}_M{mk}.exr', {})[..., idp.get('channel', 0)].copy()
                    values = load_page(rdir / f'{kind}_M{mk}.exr', {})
                    if kind == 'NORMAL':
                        values = decode_normal(values)
                    args = (craster, usable, status)
                    for fm in sorted(set(fmode[sel])):
                        s2 = sel[fmode[sel] == fm]
                        if fm == 'footprint':
                            S_of = np.maximum(2, np.ceil(ratio_t[s2])).astype(int)
                            v, h_, f_ = footprint_sample(cat, s2, values, args, ids, S_of)
                        else:
                            v, h_, f_ = sample_master(cat['mpx'][s2], cat['mpy'][s2], cat['chart'][s2], *args, values,
                                                      mode={'point': 'bilinear', 'nearest': 'nearest', 'soft': 'soft'}[fm],
                                                      ids=ids)
                        if kind == 'EMIT' and dcfg.get('emit_g') == 'bilinear_id':
                            vg, _, _ = sample_master(cat['mpx'][s2], cat['mpy'][s2], cat['chart'][s2], *args, values,
                                                     mode='bilinear', ids=values[..., 0].copy())
                            v[:, 1] = vg[:, 1]
                        vals[s2], hit[s2], found[s2] = v, h_, f_
            soft = fmode == 'soft'
            wr = todo & found & (hit | ((kind == 'OPACITY') & soft))
            outv = np.zeros((n, 3)); frame_fail = 0
            if kind == 'NORMAL':
                x, okf = to_tangent(vals[wr], cat['T'][wr], cat['N'][wr], cat['S'][wr], Gs[0])
                enc = encode_normal(x); enc[~okf] = START['NORMAL']; frame_fail = int((~okf).sum())
                outv[wr] = enc
            elif kind == 'OPACITY':
                outv[wr] = np.where(soft[wr][:, None], vals[wr], 1.0)
            else:
                outv[wr] = vals[wr]
            outv[solid] = 1.0
            written = wr | solid
            miss_c = np.bincount(fi[todo & found & ~hit], minlength=len(face_keys))
            lost_c = np.bincount(fi[todo & ~found], minlength=len(face_keys))
            for i in np.nonzero(miss_c)[0]:
                faces_rep[face_keys[i]]['misses'][kind] = int(miss_c[i])
            for i in np.nonzero(lost_c)[0]:
                faces_rep[face_keys[i]]['missing'] += int(lost_c[i])
            # the margin: 'baker' replays the direct bake (one EXTEND per receiver pass, in the baker's order, each
            # overwriting what is in reach and not its own; OPACITY with cutout classes: solid pass, then cut pass);
            # 'owners' = one pass over every hit (no hit is ever overwritten)
            if margin_mode == 'owners':
                pid = np.zeros(n, np.int64)
            else:
                pid = cat['recv'].astype(np.int64) * 2 + (~solid if (kind == 'OPACITY' and cut is not None) else 0)
            passes = [(yi[s], xi[s], outv[s]) for p in np.unique(pid[written]) for s in [written & (pid == p)]]
            img = replay_margin(np.broadcast_to(np.array(START[kind], np.float64), (H, W, 3)), passes, margin)
            stem = f'{kind}_{pg}'
            images[stem] = save_map(g['bs'], g['pair'], kind, stem, img.astype(np.float32), out)
            used = {str(m): int(c) for m, c in zip(*np.unique(fmode[todo].astype(str), return_counts=True))}
            hi_point = sorted({face_keys[f] for f in np.unique(fi[todo & (fmode == 'point') & (ratio_t > AUTO_POINT_MAX)])})
            images[stem].update(owner_texels=int(n), written=int(written.sum()), filter=mode, filter_texels=used,
                                margin_mode=margin_mode, margin_passes=len(passes), frame_failures=frame_fail,
                                point_above_auto_max=hi_point[:50], n_point_above_auto_max=len(hi_point))
            if hi_point:
                print('DERIVE_WARN', stem, len(hi_point), f'faces point-sampled above ratio {AUTO_POINT_MAX} (use auto/footprint)')
            print('DERIVED', stem, int(written.sum()), 'of', n, 'owner texels written', used, margin_mode, len(passes), 'passes')
        pages_written[pg] = dict(owner_texels=int(n), faces=len(face_keys), double_claimed_texels=int(double))
    missing = {k: v['missing'] for k, v in faces_rep.items() if v['missing']}
    ratios = [v['ratio'] for v in faces_rep.values() if v['ratio']]
    warn = sorted(k for k, v in faces_rep.items() if v['ratio'] and v['ratio'] < 1.5)
    fp = g['fp']
    report = dict(recipe=cfg, blender=bpy.app.version_string, uv_fingerprint=fp['combined'], uv_objects=fp['objects'],
                  preflight=g['preflight'], targets=report_targets, images=images,
                  derived_from=dict(master=str(mpath), geo=man['geo'], runs=runs, filters=filters,
                                    partitions=dict(chart=True, hit=True, id=idp), emit_g=dcfg.get('emit_g', 'nearest'),
                                    auto_point_max=AUTO_POINT_MAX, margin_mode=margin_mode,
                                    miss='unassigned, then the target margin as IMB_filter_extend (4-neighbour gate), '
                                         + ('replayed per receiver pass in bake order' if margin_mode == 'baker'
                                            else 'one pass over every hit'), margin=margin,
                                    debug_flip_sign=flip, uv_from_plan=bool(dcfg.get('uv_from_plan'))),
                  faces=faces_rep, pages=pages_written,
                  summary=dict(faces=len(faces_rep), missing_texels=int(sum(missing.values())),
                               faces_with_missing=sorted(missing)[:50],
                               ratio_min=min(ratios) if ratios else None, ratio_max=max(ratios) if ratios else None,
                               ratio_warn_below_1_5=warn[:50], n_ratio_warn=len(warn)),
                  seconds=round(time.time() - t0, 2), seconds_guards=round(t_guard, 2))
    write_json_atomic(out / 'derive_report.json', report)
    print('DERIVE_REPORT', out / 'derive_report.json', 'seconds', report['seconds'])
    if warn:
        print('DERIVE_WARN density ratio < 1.5 on', len(warn), 'faces')
    if missing:
        print('DERIVE_MISSING', len(missing), 'faces have texels without master data')
    return bool(missing)


if __name__ == '__main__' and '--' in sys.argv:
    try:
        main()
    except Refuse as e:
        print('DERIVE_REFUSED', e)
        sys.exit(4)
