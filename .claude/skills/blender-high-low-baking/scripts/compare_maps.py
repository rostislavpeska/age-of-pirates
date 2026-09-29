"""Derived maps vs direct bakes: acceptance metrics (host Python) and side-by-side renders (background Blender).

python compare_maps.py compare config.json      -> report JSON, exit 3 when any acceptance fails
config = {"pairs": [{"id": "S18c_normal", "derived": "derived/S18c_normal", "direct": "roof_v2/R2/bake",
                     "maps": ["NORMAL"], "pages": ["P2048", "P1024"]}],
          "erode": 2, "out": "proof/compare.json", "heat_dir": "proof/heat",     # heat: per-texel angle PNGs
          "gate": ["python", ".../blender_gate.py"]}   # run before the ONE Blender launch that converts EXRs
The texel set = the derive's owner raster (owners_<page>.npz: target plan UVs rasterised at Blender's texel
centres), eroded `erode` texels from its own borders. Per page, per class, per face:
  NORMAL  angle between decoded tangent normals: all interior (mean < 2, p95 < 6 deg), the smooth subset (direct
          4-neighbour max angle < 10 deg: mean < 1, p95 < 3), per-face median < 1 deg on faces with >= 20
          interior texels (a frame error is face-wide, a sampling error local); share > 20 deg reported.
  AO      mean |d| < 0.03; after a 3x3 box on both < 0.015; per-face mean < 0.05.
  OPACITY agreement > 99 % >= 1 texel from a direct edge, > 97 % overall; solid classes 100 % opaque.
  EMIT    R agreement (|d| < 1e-3) > 99 % on ID-interior texels (8 direct neighbours share the ID); G mean |d|
          < 0.02 there; B agreement > 99 % away from B edges.
  Coverage 0 texels without master data (derive_report summary).
  MARGIN  (NORMAL, EMIT, whole page) the margin must follow Blender's rule (IMB_filter_extend: 4-neighbour gate,
          L1 growth, per receiver pass). (a) The written set (texels that differ from START) must be an L1 opening
          of radius `margin`, i.e. an L1 dilation of some hit set - in the derived map, and in the direct one as a
          check of the rule itself. (b) Where every owner texel of the direct bake is written (an all-hit page),
          replaying derive_maps.replay_margin on the direct bake's own owner values with the receivers and bake
          order in derive_report.json must reproduce the direct margin (max |d| < 1e-5).
  GUTTER  reported, not pass/fail: written-set agreement outside the owners, the angle (NORMAL) or R agreement
          (EMIT) where both wrote, next to the angle on the owners' outermost ring the margin is filled from.
          Gutter values copy that ring, and the ring sits outside the eroded interior on purpose (sampling phase at
          chart edges), so a gutter difference that tracks the ring is not a margin error.
A failure is reported with its diagnosis, never by loosening a threshold (references/bake-master.md).
Uncompressed scanline EXRs (what Blender's bakes write) are read on the host without Blender; anything else goes
through qa_detectors.read_map (a gated Blender conversion).

python compare_maps.py render config.json       -> proof PNGs + contact sheet (background Blender, never saves)
config = {"low": "LOW.blend", "sources": {...}, "faces": [...], "out": "proof", "samples": 16,
          "resolution": [800, 600], "gate": [...], "blender": "blender.exe",
          "variants": [{"id": "direct", "uv_name": "UV_Final", "plan": "plan.json", "uv_from_plan": false,
                        "maps": {"NORMAL": {"P2048": "N.exr"}, "AO": {...}, "OPACITY": {...}}, "cutout": ["EAVE_CUTOUT"]},
                       {"id": "error", "uv_name": "UV_Final", "plan": "plan.json", "heat": {"P2048": "heat.png"}}]}
Grey clay with tangent normal (+ AO, + cutout alpha), two opposing grazing suns, one RTS 3/4 camera framed on
the faces; every variant rendered alone with the same camera, luminance difference vs the first variant.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import qa_detectors as Q  # noqa: E402

THRESH = dict(normal_mean=2.0, normal_p95=6.0, smooth_mean=1.0, smooth_p95=3.0, face_median=1.0, face_min_texels=20,
              ao_mean=0.03, ao_box=0.015, ao_face=0.05, op_interior=0.99, op_all=0.97,
              emit_r=0.99, emit_g=0.02, emit_b=0.99, id_tol=1e-3)
START = {'NORMAL': (.5, .5, 1.), 'EMIT': (0., 0., 0.)}


def written(img, kind):
    """texels a bake wrote: anything but the image's START colour (NORMAL, EMIT; AO/OPACITY START is a value)"""
    return np.abs(np.asarray(img, np.float64)[..., :3] - START[kind]).max(-1) > 1e-6


def _cross(a, grow, outside=False):
    """one 4-neighbour step: dilate (grow) or erode; `outside` = the value of texels beyond the page"""
    p = np.pad(a, 1, constant_values=outside); H, W = a.shape
    n = [p[1 + dy:1 + dy + H, 1 + dx:1 + dx + W] for dy, dx in ((0, -1), (0, 1), (-1, 0), (1, 0))]
    return (a | n[0] | n[1] | n[2] | n[3]) if grow else (a & n[0] & n[1] & n[2] & n[3])


def l1_open(w, r):
    """is w an L1 dilation of radius r of some set, cut at the page edge? (w == L1 opening of w; the erosion
    counts beyond-page texels as set, because Blender's fill stops at the page edge)"""
    e = w.copy()
    for _ in range(r):
        e = _cross(e, False, outside=True)
    d = e.copy()
    for _ in range(r):
        d = _cross(d, True)
    return bool((d == w).all()), int((w & ~d).sum())


def gutter_metrics(direct, derived, owners, kind):
    """the margin outside the owner raster (reported): written-set agreement and values where both wrote, and the
    same on the owners' outermost ring, which the margin is filled from"""
    wa, wb = written(direct, kind), written(derived, kind); g = ~owners
    union, both = (wa | wb) & g, wa & wb & g
    ring = owners & ~_cross(owners, False)
    res = dict(direct=int((wa & g).sum()), derived=int((wb & g).sum()), only_direct=int((wa & ~wb & g).sum()),
               only_derived=int((wb & ~wa & g).sum()), set_agree=float(both.sum() / max(union.sum(), 1)),
               owner_only_direct=int((wa & ~wb & owners).sum()), owner_only_derived=int((wb & ~wa & owners).sum()))
    if kind == 'NORMAL':
        ang = angle_deg(direct, derived)
        res['angle'] = _stats(ang[both]); res['angle_ring'] = _stats(ang[ring & wa & wb])
    else:
        agree = np.abs(direct[..., 0] - derived[..., 0]) < THRESH['id_tol']
        res['r_agree'] = float(agree[both].mean()) if both.any() else 1.0
        res['r_agree_ring'] = float(agree[ring & wa & wb].mean()) if (ring & wa & wb).any() else 1.0
    return res


def margin_checks(direct, derived, owners, face, keys, rep, pg, kind):
    """(a) written sets are L1 openings of radius margin; (b) exact replay on all-hit pages (see the docstring)"""
    import importlib.util
    margin = int(rep['recipe'].get('margin', 4))
    wa, wb = written(direct, kind), written(derived, kind)
    oa, na = l1_open(wa, margin); ob, nb = l1_open(wb, margin)
    res = dict(margin=margin, direct_l1_open=oa, direct_not_explained=na, derived_l1_open=ob, derived_not_explained=nb)
    res['pass'] = dict(margin_rule_direct=oa, margin_rule_derived=ob)
    if not wa[owners].all():
        res['replay'] = 'not applicable: the direct bake has unwritten (missed) owner texels'
        return res
    spec = importlib.util.spec_from_file_location('derive_maps', HERE / 'derive_maps.py')
    Dm = importlib.util.module_from_spec(spec); spec.loader.exec_module(Dm)
    recv = rep['preflight']['receivers']; tg = rep['targets'][pg]
    order = sorted(tg, key=lambda t: tg[t].get('bake_order', list(tg).index(t)))
    kidx = {k: i for i, k in enumerate(keys)}; passes = []
    for t in order:
        pre = t[2:].rsplit(f'_{pg}_', 1)[0]
        fs = [kidx[f'{pre}:{f}'] for f in recv[t]['face_ids'] if f'{pre}:{f}' in kidx]
        ys, xs = np.nonzero(np.isin(face, fs)); passes.append((ys, xs, direct[ys, xs, :3]))
    H, W = owners.shape
    img = Dm.replay_margin(np.broadcast_to(np.array(START[kind], np.float64), (H, W, 3)), passes, margin)
    d = np.abs(img - np.asarray(direct, np.float64)[..., :3]).max(-1)[~owners]
    res['replay'] = dict(receivers=len(passes), max_abs=float(d.max()), texels_off=int((d > 1e-5).sum()))
    res['pass']['margin_replay_exact'] = res['replay']['max_abs'] < 1e-5
    return res


def read_exr_host(path):
    """uncompressed scanline EXR (FLOAT or HALF channels) -> (H,W,C) float32 rows bottom-up in R,G,B(,A) order,
    or None when the file is anything else (then qa_detectors.read_map converts it through Blender)"""
    b = Path(path).read_bytes()
    if b[:4] != b'\x76\x2f\x31\x01' or b[5] & 0x1A:           # magic; tiled / deep / multipart -> not handled here
        return None
    i, attrs = 8, {}
    while b[i] != 0:
        n_end = b.index(b'\x00', i); t_end = b.index(b'\x00', n_end + 1)
        name, typ = b[i:n_end].decode(), b[n_end + 1:t_end].decode()
        size = int.from_bytes(b[t_end + 1:t_end + 5], 'little'); attrs[name] = (typ, b[t_end + 5:t_end + 5 + size])
        i = t_end + 5 + size
    i += 1
    if attrs.get('compression', ('', b'\x01'))[1][0] != 0:
        return None
    raw = attrs['channels'][1]; chans, j = [], 0
    while raw[j] != 0:
        e = raw.index(b'\x00', j); chans.append((raw[j:e].decode(), int.from_bytes(raw[e + 1:e + 5], 'little'))); j = e + 17
    dw = np.frombuffer(attrs['dataWindow'][1], '<i4'); W, H = int(dw[2] - dw[0] + 1), int(dw[3] - dw[1] + 1)
    if any(pt not in (1, 2) for _, pt in chans):
        return None
    dt = [('y', '<i4'), ('n', '<i4')] + [(c, ('<f4' if pt == 2 else '<f2'), (W,)) for c, pt in chans]
    offs = np.frombuffer(b, '<u8', H, i)
    rows = np.frombuffer(b, np.dtype(dt), H, int(offs[0]))
    if not (np.diff(offs) == np.dtype(dt).itemsize).all():
        return None
    order = [c for c in ('R', 'G', 'B', 'A') if c in dict(chans)]
    img = np.stack([rows[c].astype(np.float32) for c in order], -1)          # row k = data window line y0 + k (top)
    img = img[np.argsort(rows['y'])]
    return img[::-1].copy()


# ============================================================================================ metrics core
def decode(c):
    v = np.asarray(c, np.float64)[..., :3] * 2.0 - 1.0
    return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-12)


def angle_deg(a, b):
    """angle between two ENCODED normal maps (..., 3)"""
    return np.degrees(np.arccos(np.clip((decode(a) * decode(b)).sum(-1), -1, 1)))


def neighbour_max_angle(n):
    """per texel: max angle (deg) to its 4 neighbours in an encoded normal map (edges clamp)"""
    v = decode(n); p = np.pad(v, ((1, 1), (1, 1), (0, 0)), mode='edge'); H, W = v.shape[:2]
    out = np.zeros((H, W))
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        q = p[1 + dy:1 + dy + H, 1 + dx:1 + dx + W]
        out = np.maximum(out, np.degrees(np.arccos(np.clip((v * q).sum(-1), -1, 1))))
    return out


def not_uniform(mask_or_val, tol=None):
    """texels whose 3x3 neighbourhood is not uniform (an edge band); tol for float values"""
    a = np.asarray(mask_or_val); H, W = a.shape; p = np.pad(a, 1, mode='edge'); out = np.zeros((H, W), bool)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            q = p[1 + dy:1 + dy + H, 1 + dx:1 + dx + W]
            out |= (q != a) if tol is None else (np.abs(q - a) >= tol)
    return out


def _stats(x):
    x = np.asarray(x, np.float64)
    if not len(x):
        return dict(n=0)
    return dict(n=int(len(x)), mean=float(x.mean()), p50=float(np.median(x)), p95=float(np.percentile(x, 95)),
                max=float(x.max()))


def per_face(values, faces, keys, fn=np.median, min_n=1):
    out = {}
    if not len(values):
        return out
    order = np.argsort(faces, kind='stable'); f = faces[order]; v = values[order]
    cut = np.nonzero(np.diff(f))[0] + 1
    for grp_f, grp_v in zip(np.split(f, cut), np.split(v, cut)):
        if len(grp_v) >= min_n:
            out[keys[grp_f[0]]] = (float(fn(grp_v)), int(len(grp_v)))
    return out


def normal_metrics(direct, derived, interior, face, keys, classes=None):
    ang = angle_deg(direct, derived); nb = neighbour_max_angle(direct)
    m = interior; a = ang[m]; smooth = m & (nb < 10.0)
    faces_med = per_face(ang[m], face[m], keys, np.median, THRESH['face_min_texels'])
    worst = sorted(faces_med.items(), key=lambda kv: -kv[1][0])[:10]
    res = dict(all=_stats(a), smooth=_stats(ang[smooth]), frac_over_20=float((a > 20).mean()) if len(a) else 0.0,
               smooth_share=float(smooth.sum() / max(m.sum(), 1)),
               face_median_max=max((v[0] for v in faces_med.values()), default=0.0), faces_checked=len(faces_med),
               worst_faces=[(k, round(v[0], 3), v[1]) for k, v in worst])
    if classes is not None:
        res['by_class'] = {c: dict(all=_stats(ang[m & (classes == c)]), smooth=_stats(ang[smooth & (classes == c)]))
                           for c in sorted(set(classes[m].tolist())) if c}
    res['pass'] = dict(all_mean=res['all'].get('mean', 0) < THRESH['normal_mean'],
                       all_p95=res['all'].get('p95', 0) < THRESH['normal_p95'],
                       smooth_mean=res['smooth'].get('mean', 0) < THRESH['smooth_mean'],
                       smooth_p95=res['smooth'].get('p95', 0) < THRESH['smooth_p95'],
                       face_median=res['face_median_max'] < THRESH['face_median'])
    return res, ang


def ao_metrics(direct, derived, interior, face, keys):
    d = np.abs(direct[..., 0] - derived[..., 0]); m = interior
    bd = np.abs(Q.box_blur(direct[..., 0], 1) - Q.box_blur(derived[..., 0], 1))
    inner = Q.erode(m, 1)
    fm = per_face(d[m], face[m], keys, np.mean)
    res = dict(mean=float(d[m].mean()) if m.any() else 0.0, box3_mean=float(bd[inner].mean()) if inner.any() else 0.0,
               face_mean_max=max((v[0] for v in fm.values()), default=0.0),
               worst_faces=sorted(((k, round(v[0], 4)) for k, v in fm.items()), key=lambda kv: -kv[1])[:10])
    res['pass'] = dict(mean=res['mean'] < THRESH['ao_mean'], box3=res['box3_mean'] < THRESH['ao_box'],
                       face=res['face_mean_max'] < THRESH['ao_face'])
    return res


def opacity_metrics(direct, derived, interior, classes=None, cutout=()):
    a = direct[..., 0] >= 0.5; b = derived[..., 0] >= 0.5; m = interior
    away = m & ~not_uniform(a)
    res = dict(agree_all=float((a == b)[m].mean()) if m.any() else 1.0,
               agree_interior=float((a == b)[away].mean()) if away.any() else 1.0,
               direct_open_share=float((~a)[m].mean()) if m.any() else 0.0,
               derived_open_share=float((~b)[m].mean()) if m.any() else 0.0)
    ok_solid = True
    if classes is not None and len(cutout):
        solid = m & ~np.isin(classes, list(cutout)) & (classes != None)  # noqa: E711
        res['solid_opaque'] = float(b[solid].mean()) if solid.any() else 1.0
        ok_solid = res['solid_opaque'] == 1.0
    res['pass'] = dict(interior=res['agree_interior'] > THRESH['op_interior'], all=res['agree_all'] > THRESH['op_all'],
                       solid=ok_solid)
    return res


def emit_metrics(direct, derived, interior):
    m = interior; R0, R1 = direct[..., 0], derived[..., 0]
    id_inner = m & ~not_uniform(R0, THRESH['id_tol'])
    agree = np.abs(R0 - R1) < THRESH['id_tol']
    b0, b1 = direct[..., 2] >= 0.5, derived[..., 2] >= 0.5
    b_away = m & ~not_uniform(b0)
    res = dict(r_agree_id_interior=float(agree[id_inner].mean()) if id_inner.any() else 1.0,
               r_agree_all=float(agree[m].mean()) if m.any() else 1.0, id_interior_share=float(id_inner.sum() / max(m.sum(), 1)),
               g_mean_id_interior=float(np.abs(direct[..., 1] - derived[..., 1])[id_inner].mean()) if id_inner.any() else 0.0,
               b_agree_away=float((b0 == b1)[b_away].mean()) if b_away.any() else 1.0,
               ids_direct=int(len(np.unique(np.round(R0[m], 4)))), ids_derived=int(len(np.unique(np.round(R1[m], 4)))))
    res['pass'] = dict(r=res['r_agree_id_interior'] > THRESH['emit_r'], g=res['g_mean_id_interior'] < THRESH['emit_g'],
                       b=res['b_agree_away'] > THRESH['emit_b'])
    return res


def heat_png(ang, mask, path, vmax=20.0):
    """angle map -> 8-bit RGB PNG, rows top-down for viewing; black outside the mask (0 blue .. vmax red)"""
    from PIL import Image
    t = np.clip(ang / vmax, 0, 1)
    rgb = np.stack([t, 1 - np.abs(2 * t - 1), 1 - t], -1)            # blue (0) -> green -> red (vmax)
    rgb[~mask] = 0
    Image.fromarray((rgb[::-1] * 255).astype(np.uint8)).save(path)


# ============================================================================================ compare CLI
def _read(path):
    if Path(path).suffix.lower() == '.exr':
        a = read_exr_host(path)
        if a is not None:
            return a
    return Q.read_map(path)[::-1]                          # qa_detectors reads top-down; rasters are bottom-up


def _find(folder, m, pg):
    """<MAP>_<page> as .exr, else .npy / .png (e.g. a composed direct reference)"""
    for ext in ('.exr', '.npy', '.png'):
        p = Path(folder) / f'{m}_{pg}{ext}'
        if p.exists():
            return p
    raise FileNotFoundError(Path(folder) / f'{m}_{pg}.exr')


def compare(cfg):
    pairs = cfg['pairs']; er = int(cfg.get('erode', 2))
    exrs = []
    for p in pairs:
        for pg in p['pages']:
            for m in p['maps']:
                exrs += [f for f in (_find(p['derived'], m, pg), _find(p['direct'], m, pg)) if f.suffix == '.exr']
    todo = [e for e in exrs if read_exr_host(e) is None and not Q._cache_path(e).exists()]
    if todo and cfg.get('gate'):
        while subprocess.run(cfg['gate']).returncode != 0:
            pass
    if todo:
        Q.prefetch_exr(todo)
    out = dict(thresholds=THRESH, erode=er, pairs={}); ok_all = True
    heat_dir = Path(cfg['heat_dir']) if cfg.get('heat_dir') else None
    if heat_dir:
        heat_dir.mkdir(parents=True, exist_ok=True)
    for p in pairs:
        rep = json.loads((Path(p['derived']) / 'derive_report.json').read_text())
        plan = json.loads(Path(p.get('plan') or rep['recipe']['plan']).read_text())['faces']
        cut = rep['recipe'].get('opacity_classes') or []
        res = dict(coverage=dict(missing_texels=rep['summary']['missing_texels'], faces_without_master=0), pages={})
        cov_ok = rep['summary']['missing_texels'] == 0
        for pg in p['pages']:
            z = np.load(Path(p['derived']) / f'owners_{pg}.npz'); face = z['face']; keys = [str(k) for k in z['keys']]
            owners = face >= 0; interior = Q.erode(owners, er)
            classes = np.array([None] + [plan[k].get('material') for k in keys], object)[face + 1]
            pr = dict(owner_texels=int(owners.sum()), interior_texels=int(interior.sum()))
            for m in p['maps']:
                A = _read(_find(p['direct'], m, pg)); B = _read(_find(p['derived'], m, pg))
                if m == 'NORMAL':
                    r, ang = normal_metrics(A, B, interior, face, keys, classes)
                    r['gutter'] = gutter_metrics(A, B, owners, 'NORMAL')
                    r['margin'] = margin_checks(A, B, owners, face, keys, rep, pg, 'NORMAL')
                    r['pass'].update(r['margin']['pass'])
                    if heat_dir:
                        heat_png(ang, owners, heat_dir / f'{p["id"]}_{pg}.png'); r['heat'] = str(heat_dir / f'{p["id"]}_{pg}.png')
                    ra, rb = Q.rhythm_check(A, interior), Q.rhythm_check(B, interior)
                    r['rhythm'] = dict(direct=ra['verdict'], derived=rb['verdict'])
                    r['pass']['rhythm_same'] = ra['verdict'] == rb['verdict']
                elif m == 'AO':
                    r = ao_metrics(A, B, interior, face, keys)
                elif m == 'OPACITY':
                    r = opacity_metrics(A, B, interior, classes, cut)
                else:
                    r = emit_metrics(A, B, interior)
                    r['gutter'] = gutter_metrics(A, B, owners, 'EMIT')
                    r['margin'] = margin_checks(A, B, owners, face, keys, rep, pg, 'EMIT')
                    r['pass'].update(r['margin']['pass'])
                pr[m] = r
                ok_all &= all(r['pass'].values())
            res['pages'][pg] = pr
        res['pass'] = dict(coverage=cov_ok); ok_all &= cov_ok
        out['pairs'][p['id']] = res
    out['verdict'] = 'PASS' if ok_all else 'FAIL'
    Path(cfg['out']).parent.mkdir(parents=True, exist_ok=True)
    Path(cfg['out']).write_text(json.dumps(out, indent=1))
    print('COMPARE', out['verdict'], cfg['out'])
    return 0 if ok_all else 3


# ============================================================================================ render
def render_inside(cfg_path):
    """runs inside background Blender: one copy of the faces per variant, rendered alone with the same camera"""
    import bmesh
    import bpy
    from mathutils import Vector
    import importlib.util
    spec = importlib.util.spec_from_file_location('derive_maps', HERE / 'derive_maps.py')
    Dm = importlib.util.module_from_spec(spec); spec.loader.exec_module(Dm)
    cfg = json.loads(Path(cfg_path).read_text()); out = Path(cfg['out']); out.mkdir(parents=True, exist_ok=True)
    sc = bpy.data.scenes.new('Compare_render'); sc.render.engine = 'CYCLES'; sc.cycles.samples = int(cfg.get('samples', 16))
    sc.cycles.use_denoising = False; sc.render.film_transparent = True
    sc.render.resolution_x, sc.render.resolution_y = cfg.get('resolution', [800, 600]); sc.render.resolution_percentage = 100
    sc.view_settings.view_transform = 'Standard'
    faces = cfg['faces']; by_src = {}
    for f in faces:
        pre, i = f.rsplit(':', 1); by_src.setdefault(pre, set()).add(int(i))
    objs = []

    def image(path):
        im = bpy.data.images.load(str(path), check_existing=True); im.colorspace_settings.name = 'Non-Color'; return im

    for v in cfg['variants']:
        plan = json.loads(Path(v['plan']).read_text())['faces']
        if v.get('uv_from_plan'):
            Dm.uv_layer_from_plan(cfg['sources'], plan, v['uv_name'])
        pages = sorted({plan[f]['page'] for f in faces})
        mats = {}
        for pg in pages:
            m = bpy.data.materials.new(f'{v["id"]}_{pg}'); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
            o = nt.nodes.new('ShaderNodeOutputMaterial'); uvn = nt.nodes.new('ShaderNodeUVMap'); uvn.uv_map = v['uv_name']
            if v.get('heat'):
                tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = bpy.data.images.load(str(v['heat'][pg])); tex.interpolation = 'Closest'
                em = nt.nodes.new('ShaderNodeEmission'); nt.links.new(uvn.outputs['UV'], tex.inputs['Vector'])
                nt.links.new(tex.outputs['Color'], em.inputs['Color']); nt.links.new(em.outputs[0], o.inputs[0])
            else:
                bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled'); bsdf.inputs['Roughness'].default_value = 0.8
                bsdf.inputs['Base Color'].default_value = (.5, .5, .5, 1)
                maps = v.get('maps', {})
                if 'NORMAL' in maps:
                    tn = nt.nodes.new('ShaderNodeTexImage'); tn.image = image(maps['NORMAL'][pg]); tn.interpolation = 'Closest'
                    nm = nt.nodes.new('ShaderNodeNormalMap'); nm.space = 'TANGENT'; nm.uv_map = v['uv_name']
                    nt.links.new(uvn.outputs['UV'], tn.inputs['Vector']); nt.links.new(tn.outputs['Color'], nm.inputs['Color'])
                    nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
                if 'AO' in maps and pg in maps['AO']:
                    ta = nt.nodes.new('ShaderNodeTexImage'); ta.image = image(maps['AO'][pg]); ta.interpolation = 'Closest'
                    mul = nt.nodes.new('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'
                    mul.inputs['Factor'].default_value = 1.0; mul.inputs['A'].default_value = (.5, .5, .5, 1)
                    nt.links.new(uvn.outputs['UV'], ta.inputs['Vector']); nt.links.new(ta.outputs['Color'], mul.inputs['B'])
                    nt.links.new(mul.outputs['Result'], bsdf.inputs['Base Color'])
                if 'OPACITY' in maps and pg in maps['OPACITY']:
                    to = nt.nodes.new('ShaderNodeTexImage'); to.image = image(maps['OPACITY'][pg]); to.interpolation = 'Closest'
                    nt.links.new(uvn.outputs['UV'], to.inputs['Vector']); nt.links.new(to.outputs['Color'], bsdf.inputs['Alpha'])
                nt.links.new(bsdf.outputs[0], o.inputs[0])
            mats[pg] = m
        for pre, idx in by_src.items():
            src = bpy.data.objects[cfg['sources'][pre]]
            me = src.data.copy(); ob = bpy.data.objects.new(f'{v["id"]}_{pre}', me); ob.matrix_world = src.matrix_world
            sc.collection.objects.link(ob)
            bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
            keep_pages = [plan[f'{pre}:{f.index}']['page'] if f.index in idx else None for f in bm.faces]
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in idx], context='FACES')
            bm.to_mesh(me); bm.free()
            kept = [p for p in keep_pages if p is not None]
            me.materials.clear()
            for pg in pages:
                me.materials.append(mats[pg])
            me.polygons.foreach_set('material_index', [pages.index(p) for p in kept])
            ob['variant'] = v['id']; objs.append(ob)
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)])
    ctr = (lo + hi) / 2; rad = (hi - lo).length / 2
    cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam')); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = 50
    d = Vector((1, -1, 1.2)).normalized(); cam.location = ctr + d * rad * 3.2
    cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
    lights = []
    for name, az in (('sunA', 30.0), ('sunB', 210.0)):
        L = bpy.data.objects.new(name, bpy.data.lights.new(name, 'SUN')); L.data.energy = 4.0
        import math
        L.rotation_euler = (math.radians(90 - 18), 0, math.radians(az)); sc.collection.objects.link(L); lights.append(L)
    world = bpy.data.worlds.new('W'); world.use_nodes = True; world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.05
    sc.world = world
    shots = []
    for v in cfg['variants']:
        for o in objs:
            o.hide_render = o['variant'] != v['id']
        for L in lights:
            if v.get('heat') and L is lights[1]:
                continue
            for M in lights:
                M.hide_render = M is not L
            path = out / f'render_{v["id"]}_{L.name}.png'
            sc.render.filepath = str(path); sc.render.image_settings.file_format = 'PNG'
            with bpy.context.temp_override(scene=sc):
                bpy.ops.render.render(write_still=True, scene=sc.name)
            shots.append(str(path)); print('RENDERED', path)
    (out / 'render_shots.json').write_text(json.dumps(shots, indent=1))


def render(cfg_path):
    cfg = json.loads(Path(cfg_path).read_text()); out = Path(cfg['out'])
    if cfg.get('gate'):
        while subprocess.run(cfg['gate']).returncode != 0:
            pass
    r = subprocess.run([cfg.get('blender', Q.BLENDER), '-b', '--factory-startup', cfg['low'], '--python', str(Path(__file__).resolve()),
                        '--', '--render-inside', str(cfg_path)], capture_output=True, text=True)
    if r.returncode != 0 or not (out / 'render_shots.json').exists():
        print(r.stdout[-3000:], r.stderr[-3000:]); return 3
    from PIL import Image, ImageDraw
    shots = json.loads((out / 'render_shots.json').read_text())
    ims = {Path(s).stem: np.asarray(Image.open(s).convert('RGBA'), np.float64) / 255 for s in shots}
    ref = cfg['variants'][0]['id']; diffs = {}
    for name, a in ims.items():
        light = name.rsplit('_', 1)[1]; vid = name[len('render_'):-len(light) - 1]
        base = ims.get(f'render_{ref}_{light}')
        if base is None or vid == ref:
            continue
        mask = (a[..., 3] > .5) & (base[..., 3] > .5)
        la = a[..., :3] @ [.2126, .7152, .0722]; lb = base[..., :3] @ [.2126, .7152, .0722]
        diffs[name] = dict(mean_abs_luma=float(np.abs(la - lb)[mask].mean()), p95=float(np.percentile(np.abs(la - lb)[mask], 95)),
                           pixels=int(mask.sum()))
    names = sorted(ims); w, h = Image.open(shots[0]).size; cols = len({n.rsplit('_', 1)[1] for n in names})
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new('RGB', (w * cols, (h + 24) * rows), (40, 40, 40)); dr = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        im = Image.open(out / f'{n}.png').convert('RGBA'); bg = Image.new('RGBA', im.size, (40, 40, 40, 255)); bg.alpha_composite(im)
        x, y = (i % cols) * w, (i // cols) * (h + 24)
        sheet.paste(bg.convert('RGB'), (x, y + 24)); dr.text((x + 6, y + 5), n + (f"  dL={diffs[n]['mean_abs_luma']:.4f}" if n in diffs else ''), fill=(230, 230, 230))
    sheet.save(out / 'contact_sheet.png')
    (out / 'render_report.json').write_text(json.dumps(dict(shots=shots, diffs=diffs, sheet=str(out / 'contact_sheet.png')), indent=1))
    print('RENDER', out / 'contact_sheet.png', json.dumps(diffs))
    return 0


if __name__ == '__main__':
    if '--render-inside' in sys.argv:
        render_inside(sys.argv[sys.argv.index('--render-inside') + 1])
    elif len(sys.argv) >= 3 and sys.argv[1] in ('compare', 'render'):
        sys.exit(compare(json.loads(Path(sys.argv[2]).read_text())) if sys.argv[1] == 'compare' else render(sys.argv[2]))
    else:
        print(__doc__); sys.exit(2)
