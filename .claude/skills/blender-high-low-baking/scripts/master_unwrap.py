"""Bake master layout: every LOW face gets UNIQUE texels on a stable UV_Master at >= 2x the runtime density.

blender -b LOW.blend --factory-startup --python master_unwrap.py -- unwrap.json      (read-only, never saves)
config = {
  "sources": {"S12_Groups_A": "Claude_S18_Pages_A"},        # plan key prefix -> LOW object
  "input_contract": "low_contract.json",                     # REQUIRED LOW geometry contract (bake_contract.py)
  "groups": [{"id": "R2", "faces": ["S12_Groups_A:1645"]}],  # explicit; a face at most once; list = packing order
  "reference_plans": ["plan_S18c.json", "plan_S18f.json"],   # the layouts that will be derived (density, classes)
  "reference_page_sizes": {"P2048": 2048},                   # optional (default: the digits of the page id)
  "density": null, "factor": 2.0, "round_to": 10,            # null = factor x p99 owner density, rounded up
  "class_factor": {"EAVE_CUTOUT": 1.0},                      # optional per material class
  "parametrize": "unfold",                                   # or "seed": shapes from "seed_uv" (a unique layer),
  "seed_uv": null, "max_distortion": 1.25,                   #   rescaled; unfold where distortion > max_distortion
  "split_angle_deg": 30, "page_size": 2048, "tight_last_page": true,
  "margin": 4, "min_face_texels": 3,                         # gutter = margin + 1 texels per chart side
  "out": ".../bake_master",                                  # writes <out>/<geo12>/ (geo12 = contract[:12])
  "extend": false                                            # append-only: old charts never move
}
Charts: loop triangles joined across edges inside the group that are smooth (equal corner normals, 1e-4),
below split_angle and of one density class; parametrised by per-triangle unfolding (an exact isometry: every
master texel has exactly the master density), growth stopped before any positive-area overlap; rotated to the
minimum-area rectangle (the stored quantities do not depend on UV orientation); deterministic skyline packing;
validated at Blender's texel centres (0 texels claimed twice, every face >= min_face_texels^2 and that wide).
Writes master.json, master_uv.npz, master_plan.json, master_freeze.json, low_contract.json, charts_M<k>.npz
(int32 face/chart rasters + ambiguous-border mask, rows bottom-up), unwrap_report.json. Method:
references/bake-master.md. The numpy core imports without bpy (test_master_derive.py).
"""
import importlib.util
import json
import math
import os
import re
import shutil
import sys
import time
from collections import deque
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location('derive_maps', HERE / 'derive_maps.py')
D = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(D)
UV_MASTER = 'UV_Master'


# ============================================================================================ numpy core
def place_third(a3, b3, c3, a2, b2, scale, side_ref=None):
    """2D position of c: the triangle (a,b,c) rotated about a-b into the plane (exact edge lengths x scale), on
    the far side of side_ref (the neighbour's third corner), or counter-clockwise when side_ref is None."""
    e = b3 - a3; L2 = float(e @ e)
    t = float((c3 - a3) @ e) / L2
    h = float(np.linalg.norm(c3 - a3 - t * e))
    e2 = b2 - a2; l2 = float(np.linalg.norm(e2))
    perp = np.array([-e2[1], e2[0]]) / l2
    side = 1.0
    if side_ref is not None:
        cr = e2[0] * (side_ref[1] - a2[1]) - e2[1] * (side_ref[0] - a2[0])
        side = -1.0 if cr > 0 else 1.0
    return a2 + t * e2 + side * h * scale * perp


def tri_area3(P, t):
    return 0.5 * float(np.linalg.norm(np.cross(P[t[1]] - P[t[0]], P[t[2]] - P[t[0]])))


def unfold_face(P3, tris, scale, fixed=None, start=None, other=None):
    """Isometric per-triangle unfolding of ONE polygon (its loop triangles form a tree).
    P3 (n,3) corner positions, tris (m,3) local corners in Blender loop-triangle order, scale texels per metre.
    fixed {corner: 2D}: two corners of triangle `start` already placed by a neighbour; `other` the neighbour's
    third corner on that edge (the face unfolds to the far side). Returns (n,2) texel coordinates or None."""
    n = len(P3); uv = np.full((n, 2), np.nan); tris = [tuple(int(c) for c in t) for t in tris]
    if not tris:
        return None
    if fixed is None:
        start = int(np.argmax([tri_area3(P3, t) for t in tris]))
        i, j, k = tris[start]
        L = float(np.linalg.norm(P3[j] - P3[i])) * scale
        if L <= 0:
            return None
        uv[i] = (0.0, 0.0); uv[j] = (L, 0.0)
        uv[k] = place_third(P3[i], P3[j], P3[k], uv[i], uv[j], scale)
    else:
        for c, p in fixed.items():
            uv[c] = p
        cyc = tris[start]
        u = [c for c in cyc if c not in fixed]
        if len(u) != 1:
            return None
        u = u[0]; pos = cyc.index(u); a, b = cyc[(pos + 1) % 3], cyc[(pos + 2) % 3]
        uv[u] = place_third(P3[a], P3[b], P3[u], uv[a], uv[b], scale, side_ref=other)
    done = {start}; queue = deque([start])
    while queue:
        t = queue.popleft(); st = set(tris[t])
        for q, tri in enumerate(tris):
            if q in done:
                continue
            sh = st & set(tri)
            if len(sh) != 2:
                continue
            u = (set(tri) - sh).pop(); third = (st - sh).pop()
            pos = tri.index(u); a, b = tri[(pos + 1) % 3], tri[(pos + 2) % 3]
            if np.isnan(uv[u]).any():
                uv[u] = place_third(P3[a], P3[b], P3[u], uv[a], uv[b], scale, side_ref=uv[third])
            done.add(q); queue.append(q)
    return None if np.isnan(uv).any() else uv


def tris_overlap(A, B, eps=1e-3):
    """True when any triangle of A (p,3,2) overlaps any of B (m,3,2) with positive area (separating axis test;
    touching or overlapping by < eps texels along some axis counts as separate)."""
    if not len(A) or not len(B):
        return False
    Amin, Amax = A.min(1), A.max(1); Bmin, Bmax = B.min(1), B.max(1)
    for a, lo, hi in zip(A, Amin, Amax):
        cand = np.nonzero((Bmin[:, 0] < hi[0] - eps) & (Bmax[:, 0] > lo[0] + eps) &
                          (Bmin[:, 1] < hi[1] - eps) & (Bmax[:, 1] > lo[1] + eps))[0]
        if not len(cand):
            continue
        Bc = B[cand]
        ea = np.roll(a, -1, 0) - a; eb = np.roll(Bc, -1, 1) - Bc
        axes = np.concatenate([np.broadcast_to(np.stack([-ea[:, 1], ea[:, 0]], 1), (len(Bc), 3, 2)),
                               np.stack([-eb[..., 1], eb[..., 0]], 2)], 1)
        axes = axes / np.maximum(np.linalg.norm(axes, axis=2, keepdims=True), 1e-300)
        pa = np.einsum('kxd,vd->kxv', axes, a); pb = np.einsum('kxd,kvd->kxv', axes, Bc)
        sep = (pa.max(2) <= pb.min(2) + eps) | (pb.max(2) <= pa.min(2) + eps)
        if (~sep.any(1)).any():
            return True
    return False


def face_adjacency(faces, smooth_tol=1e-4, split_angle_deg=30.0):
    """faces: dicts with obj, verts (n,), cn (n,3), normal (3,), dens. -> {fi: [(g, my_a, my_b, g_a, g_b)]}
    joinable edges only: inside the group, smooth (corner normals equal on both sides), dihedral < split,
    same density class."""
    edges = {}
    for fi, f in enumerate(faces):
        v = f['verts']; n = len(v)
        for a in range(n):
            b = (a + 1) % n
            edges.setdefault((f['obj'], min(v[a], v[b]), max(v[a], v[b])), []).append((fi, a, b))
    cos_lim = math.cos(math.radians(split_angle_deg)); adj = {i: [] for i in range(len(faces))}
    for lst in edges.values():
        if len(lst) != 2:
            continue
        (f, fa, fb), (g, ga, gb) = lst
        F, Gf = faces[f], faces[g]
        if Gf['verts'][ga] != F['verts'][fa]:
            ga, gb = gb, ga
        if F['dens'] != Gf['dens']:
            continue
        if np.linalg.norm(F['cn'][fa] - Gf['cn'][ga]) > smooth_tol or np.linalg.norm(F['cn'][fb] - Gf['cn'][gb]) > smooth_tol:
            continue
        if float(F['normal'] @ Gf['normal']) < cos_lim:
            continue
        adj[f].append((g, fa, fb, ga, gb)); adj[g].append((f, ga, gb, fa, fb))
    return adj


def build_charts(faces, adj, max_extent, eps=1e-3):
    """Grow charts BFS from the largest unplaced face; a neighbour joins only when its unfolded triangles do not
    overlap the chart and the chart still fits max_extent. -> [dict(faces=[fi], uv={fi: (n,2)})]"""
    order = sorted(range(len(faces)), key=lambda i: (-faces[i]['area'], faces[i]['key']))
    done, charts = set(), []
    for seed in order:
        if seed in done:
            continue
        f0 = faces[seed]
        uv0 = unfold_face(f0['pos'], f0['tris'], f0['dens'])
        if uv0 is None:
            raise ValueError(f'{f0["key"]}: cannot unfold (degenerate face)')
        ch = dict(faces=[seed], uv={seed: uv0}); tri2d = [uv0[f0['tris']]]
        done.add(seed); queue = deque([seed])
        lo, hi = uv0.min(0), uv0.max(0)
        while queue:
            f = queue.popleft()
            for g, fa, fb, ga, gb in sorted(adj[f], key=lambda e: faces[e[0]]['key']):
                if g in done:
                    continue
                F, Gf = faces[f], faces[g]
                t_f = next(t for t in F['tris'] if fa in t and fb in t)
                other = ch['uv'][f][[c for c in t_f if c not in (fa, fb)][0]]
                t_g = next(q for q, t in enumerate(Gf['tris']) if ga in t and gb in t)
                uvg = unfold_face(Gf['pos'], Gf['tris'], Gf['dens'], fixed={ga: ch['uv'][f][fa], gb: ch['uv'][f][fb]},
                                  start=t_g, other=other)
                if uvg is None:
                    continue
                nlo, nhi = np.minimum(lo, uvg.min(0)), np.maximum(hi, uvg.max(0))
                if (nhi - nlo).max() > max_extent:
                    continue
                new = uvg[Gf['tris']]
                if tris_overlap(new, np.concatenate(tri2d), eps):
                    continue
                ch['faces'].append(g); ch['uv'][g] = uvg; tri2d.append(new); lo, hi = nlo, nhi
                done.add(g); queue.append(g)
        charts.append(ch)
    return charts


def convex_hull(P):
    P = np.unique(np.round(np.asarray(P, np.float64), 12), axis=0)
    if len(P) < 3:
        return P
    P = P[np.lexsort((P[:, 1], P[:, 0]))]

    def half(pts):
        h = []
        for p in pts:
            while len(h) >= 2 and (h[-1][0] - h[-2][0]) * (p[1] - h[-2][1]) - (h[-1][1] - h[-2][1]) * (p[0] - h[-2][0]) <= 0:
                h.pop()
            h.append(p)
        return h
    lower, upper = half(P), half(P[::-1])
    return np.array(lower[:-1] + upper[:-1])


def min_area_rect(P):
    """Rotating calipers: rotation R (2x2, det +1) putting the minimum-area rectangle axis-aligned with width >=
    height. Returns R, angle_deg, (w, h), offset so that (P @ R.T) - offset starts at 0."""
    P = np.asarray(P, np.float64); hull = convex_hull(P)
    best = None
    edges = np.roll(hull, -1, 0) - hull if len(hull) >= 3 else np.array([[1.0, 0.0]])
    for e in edges:
        L = np.linalg.norm(e)
        if L < 1e-12:
            continue
        u = e / L; R = np.array([[u[0], u[1]], [-u[1], u[0]]])
        q = hull @ R.T; ext = q.max(0) - q.min(0); area = ext[0] * ext[1]
        if best is None or area < best[0] - 1e-9:
            best = (area, R)
    R = best[1] if best else np.eye(2)
    q = P @ R.T; ext = q.max(0) - q.min(0)
    if ext[1] > ext[0]:
        R = np.array([[0.0, 1.0], [-1.0, 0.0]]) @ R        # rotate a further -90 deg (still a rotation)
    q = P @ R.T; off = q.min(0); ext = q.max(0) - off
    ang = math.degrees(math.atan2(R[1, 0], R[0, 0]))
    return R, ang, (float(ext[0]), float(ext[1])), off


class Skyline:
    """Deterministic bottom-left skyline packer on one W x H page (integer texels)."""

    def __init__(self, W, H, rects=()):
        self.W, self.H = int(W), int(H)
        h = np.zeros(self.W, np.int64)
        for x, y, w, hh in rects:                         # rebuild from placed boxes (holes below are left)
            h[x:x + w] = np.maximum(h[x:x + w], y + hh)
        self.h = h

    def find(self, w, h):
        if w > self.W or h > self.H:
            return None
        best = None
        xs = [0] + [x for x in range(1, self.W) if self.h[x] != self.h[x - 1]]
        for x in xs:
            if x + w > self.W:
                break
            y = int(self.h[x:x + w].max())
            if y + h <= self.H and (best is None or (y, x) < best):
                best = (y, x)
        return None if best is None else (best[1], best[0])

    def place(self, x, y, w, h):
        self.h[x:x + w] = y + h


def pack(boxes, page_size, tight_last=True, existing=None):
    """boxes [(w, h)] in packing order -> ([(page, x, y)], {page: size}). existing = {page: (size, [rects])}
    (extend mode): tried first, never changed. New pages open at page_size; the last NEW page shrinks to the
    smallest power of two holding its boxes."""
    existing = existing or {}
    pages = {p: Skyline(s, s, r) for p, (s, r) in sorted(existing.items())}
    sizes = {p: s for p, (s, r) in existing.items()}
    first_new = max(pages) + 1 if pages else 0
    where = []
    for w, h in boxes:
        for p in sorted(pages):
            pos = pages[p].find(w, h)
            if pos:
                pages[p].place(pos[0], pos[1], w, h); where.append((p, pos[0], pos[1])); break
        else:
            p = max(pages) + 1 if pages else 0
            pages[p] = Skyline(page_size, page_size); sizes[p] = page_size
            pos = pages[p].find(w, h)
            if pos is None:
                raise ValueError(f'box {w}x{h} does not fit a {page_size} page (lower max_extent)')
            pages[p].place(pos[0], pos[1], w, h); where.append((p, pos[0], pos[1]))
    last = max(pages) if pages else None
    if tight_last and last is not None and last >= first_new:
        idx = [i for i, wp in enumerate(where) if wp[0] == last]
        s = page_size // 2
        while s >= 16:
            sk = Skyline(s, s); trial = []
            for i in idx:
                w, h = boxes[i]; pos = sk.find(w, h)
                if pos is None:
                    break
                sk.place(pos[0], pos[1], w, h); trial.append((i, pos))
            if len(trial) != len(idx):
                break
            for i, pos in trial:
                where[i] = (last, pos[0], pos[1])
            sizes[last] = s; s //= 2
    return where, sizes


def border_mask(tris_px, chart_of_tri, W, H, band=0.02):
    """Texels whose centre lies within `band` texels of a chart boundary edge (an edge used once inside its
    chart): Blender's float32 scan conversion may decide them either way, so derive never trusts them."""
    t = np.asarray(tris_px, np.float64); m = np.zeros((H, W), bool)
    cnt = {}
    for ti in range(len(t)):
        for a, b in ((0, 1), (1, 2), (2, 0)):
            pa, pb = tuple(np.round(t[ti, a], 6)), tuple(np.round(t[ti, b], 6))
            key = (chart_of_tri[ti],) + (min(pa, pb), max(pa, pb))
            cnt[key] = cnt.get(key, 0) + 1
    for key, c in cnt.items():
        if c != 1:
            continue
        p, q = np.array(key[1]), np.array(key[2])
        lo = np.floor(np.minimum(p, q) - D.PIX_OFF - band).astype(int); hi = np.ceil(np.maximum(p, q) - D.PIX_OFF + band).astype(int)
        lo = np.maximum(lo, 0); hi = np.minimum(hi, [W - 1, H - 1])
        if (hi < lo).any():
            continue
        ys, xs = np.mgrid[lo[1]:hi[1] + 1, lo[0]:hi[0] + 1]
        c = np.stack([xs + D.PIX_OFF[0], ys + D.PIX_OFF[1]], -1).reshape(-1, 2)
        d = q - p; L2 = float(d @ d)
        s = np.clip(((c - p) @ d) / L2, 0, 1) if L2 > 0 else np.zeros(len(c))
        dist = np.linalg.norm(c - (p + s[:, None] * d), axis=1)
        near = dist < band
        m[ys.ravel()[near], xs.ravel()[near]] = True
    return m


def validate_page(tris_px, face_of_tri, chart_of_tri, W, H, band=0.02):
    """-> dict(face raster, chart raster, border mask, double-claimed texel count, texels per face)"""
    tri, x, y, _ = D.rasterize(tris_px, W, H)
    lin = y * W + x
    uniq, cnt = np.unique(lin, return_counts=True)
    face = np.full((H, W), -1, np.int32); chart = np.full((H, W), -1, np.int32)
    face[y, x] = np.asarray(face_of_tri)[tri]; chart[y, x] = np.asarray(chart_of_tri)[tri]
    per_face = np.bincount(np.asarray(face_of_tri)[tri], minlength=int(max(face_of_tri) + 1) if len(face_of_tri) else 0)
    return dict(face=face, chart=chart, border=border_mask(tris_px, chart_of_tri, W, H, band),
                double=int((cnt > 1).sum()), per_face=per_face)


def density_rule(reference, factor, round_to):
    """factor x p99 owner density (px/m), rounded UP to round_to"""
    d = np.asarray(reference, np.float64)
    p99 = float(np.percentile(d, 99))
    return float(math.ceil(factor * p99 / round_to) * round_to), dict(p50=float(np.percentile(d, 50)), p99=p99,
                                                                      max=float(d.max()), n=int(len(d)))


# ============================================================================================ Blender side
def _load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f'{name}.py')
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    return mod


def apply_master_uv(sources, npz, uv_name=UV_MASTER):
    """Create uv_name on the source objects in session from master_uv.npz (faces outside the master sit at
    (-2, -2): the UV-skip trick, never baked). The file is never saved."""
    import bpy
    for key, name in sources.items():
        me = bpy.data.objects[name].data
        a = np.asarray(npz[f'uv_{key}'], np.float64)
        assert a.shape == (len(me.loops), 2), f'{name}: master uv has {a.shape[0]} loops, mesh {len(me.loops)}'
        if me.uv_layers.get(uv_name):
            me.uv_layers.remove(me.uv_layers[uv_name])
        uvl = me.uv_layers.new(name=uv_name)
        uvl.data.foreach_set('uv', a.astype(np.float32).ravel())


def read_objects(sources):
    import bpy
    out = {}
    for key, name in sources.items():
        ob = bpy.data.objects[name]; me = ob.data; me.calc_loop_triangles()
        nl, npo = len(me.loops), len(me.polygons)
        co = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get('co', co); co = co.reshape(-1, 3).astype(np.float64)
        M = np.array(ob.matrix_world, np.float64); cw = co @ M[:3, :3].T + M[:3, 3]
        lv = np.empty(nl, np.int32); me.loops.foreach_get('vertex_index', lv)
        cn = np.empty(nl * 3, np.float32); me.corner_normals.foreach_get('vector', cn)
        ls = np.empty(npo, np.int32); me.polygons.foreach_get('loop_start', ls)
        lt = np.empty(npo, np.int32); me.polygons.foreach_get('loop_total', lt)
        pn = np.empty(npo * 3, np.float32); me.polygons.foreach_get('normal', pn)
        tl = np.empty(len(me.loop_triangles) * 3, np.int32); me.loop_triangles.foreach_get('loops', tl); tl = tl.reshape(-1, 3)
        tp = np.empty(len(me.loop_triangles), np.int32); me.loop_triangles.foreach_get('polygon_index', tp)
        tris_of = [[] for _ in range(npo)]
        for k, p in enumerate(tp):
            tris_of[p].append(k)
        P = cw[lv]
        tri_area = 0.5 * np.linalg.norm(np.cross(P[tl[:, 1]] - P[tl[:, 0]], P[tl[:, 2]] - P[tl[:, 0]]), axis=1)
        area = np.bincount(tp, weights=tri_area, minlength=npo)
        out[key] = dict(name=name, P=P, lv=lv, cn=cn.reshape(-1, 3).astype(np.float64), ls=ls, lt=lt,
                        pn=pn.reshape(-1, 3).astype(np.float64), tl=tl, tris_of=tris_of, area=area, nloops=nl, npoly=npo)
    return out


def face_record(objs, key):
    pre, idx = key.rsplit(':', 1); o = objs[pre]; i = int(idx)
    s, n = int(o['ls'][i]), int(o['lt'][i])
    tris = np.array([o['tl'][k] - s for k in o['tris_of'][i]], np.int64)
    return dict(key=key, obj=pre, poly=i, loops=np.arange(s, s + n), verts=o['lv'][s:s + n].tolist(), pos=o['P'][s:s + n],
                cn=o['cn'][s:s + n], normal=o['pn'][i], tris=tris, area=float(o['area'][i]))


def plan_densities(objs, plans, page_sizes):
    dens, classes = [], {}
    for path in plans:
        faces = json.loads(Path(path).read_text())['faces']
        for key, e in faces.items():
            pre, idx = key.rsplit(':', 1)
            if e.get('material') and key not in classes:
                classes[key] = e['material']
            if pre not in objs or not e.get('owner') or 'uv' not in e:
                continue
            pg = str(e.get('page'))
            size = page_sizes.get(pg) or int(re.sub(r'\D', '', pg) or 0)
            a3 = objs[pre]['area'][int(idx)]
            au = D.shoelace(np.asarray(e['uv'], np.float64) * size)
            if a3 > 1e-9 and au > 0:
                dens.append(math.sqrt(au / a3))
    return dens, classes


def main():
    import bpy
    t0 = time.time()
    cfg = json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text())
    contract, fp_mod = _load('bake_contract'), _load('uv_fingerprint')
    sources = cfg['sources']
    if not cfg.get('input_contract'):
        raise ValueError('input_contract is required: the master is stored per LOW geometry version')
    low_fp = contract.fingerprint(list(sources.values()))
    contract.check_contract(cfg, low_fp)
    for name in sources.values():
        assert not bpy.data.objects[name].modifiers, f'{name}: apply modifiers first'
    geo = low_fp['combined'][:12]; root = Path(cfg['out']); gdir = root / geo
    extend = bool(cfg.get('extend'))
    old = None
    if gdir.exists():
        if not extend:
            raise ValueError(f'{gdir} exists: a master layout is immutable (set "extend" to append groups)')
        old = json.loads((gdir / 'master.json').read_text())
        if old['low_contract']['combined'] != low_fp['combined']:
            raise ValueError('existing master was made on other LOW geometry')
    objs = read_objects(sources)
    seen = set(old['faces']) if old else set()
    for gr in cfg['groups']:
        for k in gr['faces']:
            pre, _, idx = k.rpartition(':')
            if pre not in objs or not idx.isdigit() or not 0 <= int(idx) < objs[pre]['npoly']:
                raise ValueError(f'{gr["id"]}: invalid face key {k}')
            if k in seen:
                raise ValueError(f'{k}: listed twice (or already in the master)')
            seen.add(k)
    page_sizes = cfg.get('reference_page_sizes', {})
    dens_ref, classes = plan_densities(objs, cfg.get('reference_plans', []), page_sizes)
    if old:
        density = old['density']['px_per_m']; stats = old['density'].get('reference', {})
        rule = old['density']['rule']
    elif cfg.get('density'):
        density, stats, rule = float(cfg['density']), {}, f'fixed {cfg["density"]} px/m'
    else:
        if not dens_ref:
            raise ValueError('density null needs reference_plans with owner faces of these sources')
        density, stats = density_rule(dens_ref, float(cfg.get('factor', 2.0)), float(cfg.get('round_to', 10)))
        rule = (f'{cfg.get("factor", 2.0)} x p99 owner density {stats["p99"]:.1f} px/m of '
                f'{[Path(p).name for p in cfg["reference_plans"]]}, rounded up to {cfg.get("round_to", 10)}')
    cf = cfg.get('class_factor', {})
    margin = int(old['margin'] if old else cfg.get('margin', 4)); gutter = margin + 1
    P = int(old['page_size'] if old else cfg.get('page_size', 2048))
    mft = int(cfg.get('min_face_texels', 3))
    # --- charts per group
    chart_list, gi_of = [], {}
    first_chart = 1 + max([c['id'] for c in old['charts']], default=-1) if old else 0
    group_offset = len(old['groups']) if old else 0
    for g_i, gr in enumerate(cfg['groups']):
        faces = [face_record(objs, k) for k in gr['faces']]
        for f in faces:
            f['cls'] = classes.get(f['key']); f['dens'] = density * float(cf.get(f['cls'], 1.0))
        if cfg.get('parametrize', 'unfold') == 'seed':
            charts = seed_charts(faces, objs, cfg)
        else:
            adj = face_adjacency(faces, 1e-4, float(cfg.get('split_angle_deg', 30)))
            charts = build_charts(faces, adj, max_extent=(P - 2 * gutter - 2) / math.sqrt(2))   # any rotation fits
        for ch in charts:
            pts = np.concatenate([ch['uv'][fi] for fi in ch['faces']])
            R, ang, (w, h), off = min_area_rect(pts)
            ch.update(group=gr['id'], gorder=group_offset + g_i, R=R, angle=ang, w=w, h=h, off=off, faces_rec=faces,
                      box=(int(math.ceil(w + 2 * gutter)), int(math.ceil(h + 2 * gutter))))
            chart_list.append(ch)
    order = sorted(range(len(chart_list)), key=lambda i: (chart_list[i]['gorder'], -chart_list[i]['box'][1],
                                                          -chart_list[i]['box'][0], i))
    for n_, i in enumerate(order):
        chart_list[i]['id'] = first_chart + n_
    existing = {}
    if old:
        for pk, s in old['pages'].items():
            existing[int(pk[1:])] = (int(s), [tuple(c['box']) for c in old['charts'] if c['page'] == pk])
    where, sizes = pack([chart_list[i]['box'][:2] for i in order], P, bool(cfg.get('tight_last_page', True)), existing)
    # --- UVs
    npz_old = dict(np.load(gdir / 'master_uv.npz')) if old else {}
    arrays = {}
    for key, o in objs.items():
        arrays[f'uv_{key}'] = npz_old.get(f'uv_{key}', np.full((o['nloops'], 2), -2.0)).copy()
        arrays[f'page_{key}'] = npz_old.get(f'page_{key}', np.full(o['npoly'], -1, np.int16)).copy()
        arrays[f'chart_{key}'] = npz_old.get(f'chart_{key}', np.full(o['npoly'], -1, np.int32)).copy()
    charts_json = list(old['charts']) if old else []
    faces_json = dict(old['faces']) if old else {}
    for (pg, bx, by), i in zip(where, order):
        ch = chart_list[i]; S = sizes[pg]; recs = ch['faces_rec']
        keys = []
        for fi in ch['faces']:
            f = recs[fi]
            q = ch['uv'][fi] @ ch['R'].T - ch['off'] + [bx + gutter, by + gutter]
            arrays[f'uv_{f["obj"]}'][f['loops']] = q / S
            arrays[f'page_{f["obj"]}'][f['poly']] = pg; arrays[f'chart_{f["obj"]}'][f['poly']] = ch['id']
            faces_json[f['key']] = dict(page=f'M{pg}', chart=ch['id'], group=ch['group'], cls=f['cls'],
                                        density=f['dens'], maps={}, hit_fraction={})
            keys.append(f['key'])
        charts_json.append(dict(id=ch['id'], group=ch['group'], page=f'M{pg}', box=[bx, by, *ch['box']],
                                rotation_deg=round(ch['angle'], 6), size=[ch['w'], ch['h']], density=recs[ch['faces'][0]]['dens'],
                                faces=keys))
    pages = {f'M{p}': int(s) for p, s in sorted(sizes.items())}
    # --- validation rasters at Blender texel centres, over every page
    face_index = sorted(faces_json)
    fidx = {k: i for i, k in enumerate(face_index)}
    report = dict(density=dict(px_per_m=density, rule=rule, reference=stats), pages=pages, gutter=gutter,
                  charts=len(charts_json), faces=len(faces_json), per_page={}, problems=[])
    tris_by_page = {p: ([], [], []) for p in pages}
    for key in face_index:
        pre, idx = key.rsplit(':', 1); o = objs[pre]; i = int(idx)
        pg = int(arrays[f'page_{pre}'][i]); S = pages[f'M{pg}']
        uv = arrays[f'uv_{pre}']
        for k in o['tris_of'][i]:
            tris_by_page[f'M{pg}'][0].append(uv[o['tl'][k]] * S)
            tris_by_page[f'M{pg}'][1].append(fidx[key]); tris_by_page[f'M{pg}'][2].append(int(arrays[f'chart_{pre}'][i]))
    rasters, texels = {}, np.zeros(len(face_index), np.int64)
    for pk, (tr, fo, co) in tris_by_page.items():
        S = pages[pk]
        v = validate_page(np.array(tr), np.array(fo), np.array(co), S, S)
        rasters[pk] = v
        texels[:len(v['per_face'])] += v['per_face']
        occ = float((v['face'] >= 0).mean())
        report['per_page'][pk] = dict(size=S, fill=round(occ, 4), double_claimed=v['double'],
                                      border_texels=int(v['border'].sum()))
        if v['double']:
            report['problems'].append(f'{pk}: {v["double"]} texels claimed by two faces')
    small, dens_err, widths = [], 0.0, []
    for key in face_index:
        pre, idx = key.rsplit(':', 1); o = objs[pre]; i = int(idx)
        S = pages[faces_json[key]['page']]; uv = arrays[f'uv_{pre}'][o['ls'][i]:o['ls'][i] + o['lt'][i]] * S
        _, _, (w, h), _ = min_area_rect(uv); widths.append(h)
        faces_json[key]['texels'] = int(texels[fidx[key]])
        if texels[fidx[key]] < mft * mft or h < mft:
            small.append(key)
        d = faces_json[key]['density']
        for k in o['tris_of'][i]:
            a3 = 0.5 * np.linalg.norm(np.cross(o['P'][o['tl'][k][1]] - o['P'][o['tl'][k][0]], o['P'][o['tl'][k][2]] - o['P'][o['tl'][k][0]]))
            t2 = arrays[f'uv_{pre}'][o['tl'][k]] * S
            a2 = 0.5 * abs((t2[1, 0] - t2[0, 0]) * (t2[2, 1] - t2[0, 1]) - (t2[1, 1] - t2[0, 1]) * (t2[2, 0] - t2[0, 0]))
            if a3 > 1e-10:
                dens_err = max(dens_err, abs(a2 / (a3 * d * d) - 1.0))
    report.update(small_faces=small, min_face_width_texels=float(min(widths)) if widths else None,
                  max_density_error=dens_err, texels_total=int(texels.sum()))
    if small:
        report['problems'].append(f'{len(small)} faces below {mft}x{mft} texels (raise class_factor)')
    if cfg.get('parametrize', 'unfold') == 'unfold' and dens_err > 1e-6:
        report['problems'].append(f'unfold density error {dens_err:g} (expected exact)')
    if report['problems']:
        print('UNWRAP_FAIL', *report['problems'], sep='\n  ')
        sys.exit(3)
    # --- UV_Master in session -> freeze (uv_fingerprint.py's own format)
    work = gdir if old else root / (geo + '.tmp')
    if not old:
        if work.exists():
            shutil.rmtree(work)
        work.mkdir(parents=True)
    np.savez(work / 'master_uv.npz', **arrays)
    apply_master_uv(sources, np.load(work / 'master_uv.npz'))
    fr = fp_mod.fingerprint(list(sources.values()), UV_MASTER)
    D.write_json_atomic(work / 'master_freeze.json', dict(fr, blend=bpy.data.filepath))
    D.write_json_atomic(work / 'low_contract.json', low_fp)
    for pk, v in rasters.items():
        np.savez_compressed(work / f'charts_{pk}.npz', face=v['face'], chart=v['chart'], border=v['border'])
    plan = {'faces': {}}
    for key in face_index:
        pre, idx = key.rsplit(':', 1); o = objs[pre]; i = int(idx)
        plan['faces'][key] = dict(owner=True, page=faces_json[key]['page'], material=faces_json[key]['cls'],
                                  family=f'master:{faces_json[key]["chart"]}',
                                  uv=arrays[f'uv_{pre}'][o['ls'][i]:o['ls'][i] + o['lt'][i]].tolist())
    D.write_json_atomic(work / 'master_plan.json', plan)
    report['seconds'] = round(time.time() - t0, 2)
    D.write_json_atomic(work / 'unwrap_report.json', report)
    groups = dict(old['groups']) if old else {}
    for gr in cfg['groups']:
        groups[gr['id']] = dict(faces=list(gr['faces']),
                                pages=sorted({faces_json[k]['page'] for k in gr['faces']}))
    man = dict(schema=1, geo=geo, low_contract=low_fp, blender=bpy.app.version_string, sources=sources,
               uv_name=UV_MASTER, uv_fingerprint=fr['combined'], npz_sha256=D.sha256_file(work / 'master_uv.npz'),
               density=dict(px_per_m=density, rule=rule, reference=stats, class_factor=cf),
               page_size=P, pages=pages, margin=margin, gutter=gutter, groups=groups, charts=charts_json,
               face_index=face_index, faces=faces_json, runs=old['runs'] if old else {},
               history=(old['history'] if old else []) + [dict(action='extend' if old else 'unwrap', time=time.strftime('%Y-%m-%d %H:%M:%S'),
                                                              groups=[g['id'] for g in cfg['groups']], config=cfg)])
    man['blender_unwrap'] = bpy.app.version_string
    D.write_json_atomic(work / 'master.json', man)
    if not old:
        os.replace(work, gdir)
    print('UNWRAP_PASS', gdir, 'pages', pages, 'charts', len(charts_json), 'faces', len(faces_json),
          'density', density, 'seconds', report['seconds'])


def seed_charts(faces, objs, cfg):
    """parametrize "seed": chart shapes copied from an existing unique UV layer (islands = faces whose seed UVs
    coincide on the shared edge), rescaled isotropically to the master density; a chart whose triangles distort
    more than max_distortion (singular-value ratio or scale off by that factor) is unfolded instead."""
    import bpy
    layer = cfg['seed_uv']; lim = float(cfg.get('max_distortion', 1.25))
    seeds = {}
    for key, o in objs.items():
        me = bpy.data.objects[o['name']].data
        a = np.empty(o['nloops'] * 2, np.float32); me.uv_layers[layer].data.foreach_get('uv', a); seeds[key] = a.reshape(-1, 2).astype(np.float64)
    adj = face_adjacency(faces, 1e-4, float(cfg.get('split_angle_deg', 30)))
    comp, charts = {}, []
    for s in range(len(faces)):
        if s in comp:
            continue
        stack, members = [s], []
        comp[s] = s
        while stack:
            f = stack.pop(); members.append(f); F = faces[f]; su = seeds[F['obj']][F['loops']]
            for g, fa, fb, ga, gb in adj[f]:
                Gf = faces[g]; sg = seeds[Gf['obj']][Gf['loops']]
                if g not in comp and np.allclose(su[fa], sg[ga], atol=1e-6) and np.allclose(su[fb], sg[gb], atol=1e-6):
                    comp[g] = s; stack.append(g)
        uv = {f: seeds[faces[f]['obj']][faces[f]['loops']] for f in members}
        a2 = sum(D.shoelace(uv[f][t]) for f in members for t in faces[f]['tris'])
        a3 = sum(tri_area3(faces[f]['pos'], t) for f in members for t in faces[f]['tris'])
        d = faces[members[0]]['dens']
        scale = math.sqrt(a3 * d * d / a2) if a2 > 0 else 0
        worst = np.inf if scale == 0 else 1.0
        for f in members:
            for t in faces[f]['tris']:
                P3 = faces[f]['pos'][t]; e1, e2 = P3[1] - P3[0], P3[2] - P3[0]
                n = np.cross(e1, e2); ln = np.linalg.norm(n)
                if ln < 1e-12:
                    continue
                x = e1 / np.linalg.norm(e1); y = np.cross(n / ln, x)
                A3 = np.array([[e1 @ x, e2 @ x], [e1 @ y, e2 @ y]])
                U = uv[f][t] * scale; A2 = np.array([U[1] - U[0], U[2] - U[0]]).T
                sv = np.linalg.svd(A2 @ np.linalg.inv(A3), compute_uv=False) / d
                worst = max(worst, sv[0] / max(sv[1], 1e-12), sv[0], 1 / max(sv[1], 1e-12))
        if worst <= lim:
            charts.append(dict(faces=members, uv={f: uv[f] * scale for f in members}))
        else:
            sub = [faces[f] for f in members]
            sub_adj = face_adjacency(sub, 1e-4, float(cfg.get('split_angle_deg', 30)))
            for ch in build_charts(sub, sub_adj, max_extent=int(cfg.get('page_size', 2048)) - 2 * (int(cfg.get('margin', 4)) + 1) - 2):
                charts.append(dict(faces=[members[i] for i in ch['faces']], uv={members[i]: ch['uv'][i] for i in ch['faces']}))
    return charts


if __name__ == '__main__' and '--' in sys.argv:
    main()
