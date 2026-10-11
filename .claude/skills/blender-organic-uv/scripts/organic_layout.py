"""Organic page layout (host Python: numpy, scipy, Pillow): mirror-exact unique islands, upright, island-scale
priority, pair-aware raster packing with a texel gutter.

    python organic_layout.py MESH_DUMP.json RAW_UNWRAP.json CONFIG.json --out ABS_LAYOUT.json

Steps per page (the measured organic recipe, references/method.md):
  1 islands from the raw unwrap (UV-continuous faces);
  2 mirror objects (mirror-exact across local x = 0): a centre island whose faces mirror inside it is made exactly
    symmetric about a vertical axis; every -X island is rewritten as the reflection of its +X twin, as its OWN island
    (unique texels, never stacked); an island whose mirror does not close is left as solved (upright only, reported);
  3 upright: the projected 3D up of each island points to +V (a weak up falls back to front-at-bottom or the long
    axis); the packer never rotates;
  4 every island normalised to 1 UV unit = 1 m of surface, then scaled by its priority multiplier
    (island_priority.py); optional calibration of the head islands on the bone-region estimator;
  5 raster bottom-left packer (FFT collision test, mirrored pairs placed side by side), one shared texel density
    found by bisection, gutter = dilation halo (gutter/2 + halo_extra px: 0.75 gave a 7.76 px gap against an 8 px
    contract, 1.25 held). Verify the gutter with uv_eval, never trust the halo.

CONFIG (schema blender-organic-uv/layout/1):
  {"schema": "blender-organic-uv/layout/1",
   "pages": [{"name": "body", "size": 1024, "gutter_px": 16, "objects": ["Body", "Weapon"]},
             {"name": "hat", "size": 512, "gutter_px": 8, "objects": ["Hat"]}],
   "mirror_objects": ["Body"],
   "priority": {"factors": {"face": 1.5, "hand": 1.15}, "face_factors": "ABS.json", "hidden_cap": 0.75,
                "never_visible": "ABS uv_eval run folder or JSON {object: [bool per polygon]}"},
   "head_target": {"ratio": 1.3, "objects": ["Body"], "num": "head", "den": "torso",
                   "exclude_never_visible": false, "bone_regions": null},
   "halo_extra_px": 1.25, "search": {"lo": null, "hi": null, "iters": 14}}
Every key but "pages" is optional. Output (schema blender-organic-uv/layout-result/1): per object its page, page size
and per-polygon corner UVs in the mesh's corner order; the report lists every island group, its kind, multiplier and
density, the head calibration and the packing. OUT must be absolute and outside every git work tree.
Exit 0 = written, 1 = a page could not be packed or a mirror pair failed, 2 = setup error.
"""
import argparse
import collections
import math
import os
import sys
import time

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage, signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import island_priority as IP  # noqa: E402
import uvenv  # noqa: E402

SCHEMA_CONFIG = 'blender-organic-uv/layout/1'
SCHEMA_OUT = 'blender-organic-uv/layout-result/1'
UP = np.array([0, 0, 1.0])
FRONT_Y_SIGN = -1.0                    # the character faces -Y (Blender front view)


def ekey(a, b):
    return (a, b) if a < b else (b, a)


class MeshData:
    def __init__(self, name, d):
        self.name = name
        self.P = np.array(d['co'], float).reshape(-1, 3)
        self.F = [list(map(int, f)) for f in d['polys']]
        self.part = list(d['parts']) if d.get('parts') else ['(none)'] * len(self.F)
        self.mm = list(d.get('mirror_map') or [-1] * len(self.P))
        self.E = collections.defaultdict(list)
        for fi, f in enumerate(self.F):
            for k in range(len(f)):
                self.E[ekey(f[k], f[(k + 1) % len(f)])].append(fi)
        self.a3 = np.array([IP.poly_area3d(self.P, f) for f in self.F])

    def face_mirror(self):
        idx = {frozenset(f): i for i, f in enumerate(self.F)}
        return [idx.get(frozenset(self.mm[v] for v in f), -1) if all(self.mm[v] >= 0 for v in f) else -1
                for f in self.F]


class UVObj:
    """per-polygon corner UVs of one object, in the dump's corner order."""

    def __init__(self, mesh, polys):
        self.m = mesh
        if len(polys) != len(mesh.F):
            raise uvenv.SetupError('%s: raw unwrap has %d polygons, dump %d' % (mesh.name, len(polys), len(mesh.F)))
        self.uv, self.V = [], []
        for i, p in enumerate(polys):
            if sorted(p['v']) != sorted(mesh.F[i]):
                raise uvenv.SetupError('%s: polygon %d differs between raw unwrap and dump' % (mesh.name, i))
            order = [p['v'].index(v) for v in mesh.F[i]]
            self.uv.append(np.array(p['uv'], float)[order])
            self.V.append(list(mesh.F[i]))
        self.nf = len(polys)

    def corner(self, f, v):
        return self.V[f].index(v)

    def get(self, f, v):
        return self.uv[f][self.corner(f, v)]

    def set(self, f, v, uv):
        self.uv[f][self.corner(f, v)] = uv

    def auv(self, f):
        return IP.poly_area_uv(self.uv[f])

    def islands(self, tol=1e-6):
        par = list(range(self.nf))

        def find(x):
            while par[x] != x:
                par[x] = par[par[x]]
                x = par[x]
            return x
        for e, fs in self.m.E.items():
            if len(fs) != 2:
                continue
            f0, f1 = fs
            if all(np.linalg.norm(self.get(f0, v) - self.get(f1, v)) < tol for v in e):
                par[find(f0)] = find(f1)
        g = collections.defaultdict(list)
        for f in range(self.nf):
            g[find(f)].append(f)
        return sorted(g.values(), key=lambda fs: (-len(fs), fs[0]))


def side_of(m, fs):
    xs = np.concatenate([m.P[m.F[f]][:, 0] for f in fs])
    if xs.min() < -1e-5 and xs.max() > 1e-5:
        return 0
    return 1 if xs.max() > 1e-5 else -1


def reflect_fit(A, Bp):
    """best reflection + translation mapping UV points A onto Bp (least squares): (R, t, rms)."""
    ca, cb = A.mean(0), Bp.mean(0)
    A0, B0 = A - ca, Bp - cb
    Fl = np.diag([-1.0, 1.0])
    H = (A0 @ Fl).T @ B0
    U, S, Vt = np.linalg.svd(H)
    Rr = (U @ Vt).T
    if np.linalg.det(Rr) < 0:
        Vt[-1] *= -1
        Rr = (U @ Vt).T
    R = Rr @ Fl
    t = cb - R @ ca
    res = (A @ R.T + t) - Bp
    return R, t, float(np.sqrt((res ** 2).sum(1).mean()))


def face_up_uv(o, f):
    """UV direction of 3D up on polygon f (fan), weight = 3D area x in-plane share of up."""
    v = o.V[f]
    s, w = np.zeros(2), 0.0
    for k in range(1, len(v) - 1):
        P = o.m.P[[v[0], v[k], v[k + 1]]]
        U = o.uv[f][[0, k, k + 1]]
        e1, e2 = P[1] - P[0], P[2] - P[0]
        n = np.cross(e1, e2)
        a3 = np.linalg.norm(n) / 2
        if a3 < 1e-12:
            continue
        nn = n / (2 * a3)
        upp = UP - (UP @ nn) * nn
        share = np.linalg.norm(upp)
        if share < 1e-6:
            continue
        ab, *_ = np.linalg.lstsq(np.c_[e1, e2], upp, rcond=None)
        q = ab[0] * (U[1] - U[0]) + ab[1] * (U[2] - U[0])
        ln = np.linalg.norm(q)
        if ln < 1e-12:
            continue
        s += q / ln * a3 * share
        w += a3 * share
    return s, w


def island_up(o, fs):
    s, w = np.zeros(2), 0.0
    for f in fs:
        d, ww = face_up_uv(o, f)
        s += d
        w += ww
    return s, w


def rot(theta):
    c, s = np.cos(theta), np.sin(theta)
    return np.array([[c, -s], [s, c]])


def apply_affine(o, fs, M, t):
    for f in fs:
        o.uv[f] = o.uv[f] @ M.T + t


def island_corners(o, fs):
    return np.concatenate([o.uv[f] for f in fs])


def axis_front_rule(o, fs, a):
    cy = np.array([o.m.P[o.V[f]].mean(0)[1] for f in fs])
    cu = np.array([o.uv[f].mean(0) @ a for f in fs])
    ymid = np.median(cy)
    front = cu[cy < ymid].mean() if np.any(cy < ymid) else 0
    back = cu[cy >= ymid].mean() if np.any(cy >= ymid) else 0
    return a if front < back else -a


def make_upright(o, fs, axis=None):
    """rotate the island so 3D up maps to +V; with a symmetry axis, align that axis to V instead."""
    s, w = island_up(o, fs)
    if axis is not None:
        a = axis / np.linalg.norm(axis)
        if s @ a < 0:
            a = -a
        if np.linalg.norm(s) < 0.25 * max(w, 1e-12):
            a = axis_front_rule(o, fs, a)          # horizontal surface: the front goes to the bottom
        target = a
    elif np.linalg.norm(s) >= 0.25 * max(w, 1e-12):
        target = s / np.linalg.norm(s)
    else:
        C = island_corners(o, fs)
        C = C - C.mean(0)
        target = np.linalg.svd(C, full_matrices=False)[2][0]     # long axis vertical
    ang = np.arctan2(target[1], target[0])
    apply_affine(o, fs, rot(np.pi / 2 - ang), np.zeros(2))


def island_size(o, fs):
    return math.sqrt(sum(abs(o.auv(f)) for f in fs))


def symmetrise(o, fs, fm, tol_rel=2e-3):
    """make a centre island exactly mirror-symmetric about a vertical axis. Returns (u0, max correction, native
    asymmetry), both relative to the island size."""
    A, Bp = [], []
    for f in fs:
        for v in o.V[f]:
            A.append(o.get(f, v))
            Bp.append(o.get(fm[f], o.m.mm[v]))
    A, Bp = np.array(A), np.array(Bp)
    R, t, rms = reflect_fit(A, Bp)
    w, Vv = np.linalg.eigh((R + R.T) / 2)
    axis = Vv[:, np.argmax(w)]
    size = island_size(o, fs)
    make_upright(o, fs, axis=axis)
    A, Bp = [], []
    for f in fs:
        for v in o.V[f]:
            A.append(o.get(f, v))
            Bp.append(o.get(fm[f], o.m.mm[v]))
    A, Bp = np.array(A), np.array(Bp)
    u0 = float(np.mean((A[:, 0] + Bp[:, 0]) / 2))
    before = {(f, v): o.get(f, v).copy() for f in fs for v in o.V[f]}
    plus = [f for f in fs if o.m.P[o.V[f]].mean(0)[0] > 0]
    for f in plus:                              # join centre-plane vertices whose +X and -X corners coincide
        for v in o.V[f]:
            if abs(o.m.P[v][0]) > 1e-5:
                continue
            uvf = o.get(f, v)
            joined = any(np.linalg.norm(o.get(g, v) - uvf) < tol_rel * size
                         for g in fs if v in o.V[g] and o.m.P[o.V[g]].mean(0)[0] < 0)
            if joined:
                o.set(f, v, np.array([u0, uvf[1]]))
    for f in plus:                              # average +X with the reflection of -X
        g = fm[f]
        for v in o.V[f]:
            p = o.get(f, v)
            q = o.get(g, o.m.mm[v])
            qr = np.array([2 * u0 - q[0], q[1]])
            if abs(o.m.P[v][0]) <= 1e-5 and abs(p[0] - u0) < 1e-12:
                new = np.array([u0, (p[1] + q[1]) / 2])
            else:
                new = (p + qr) / 2
            o.set(f, v, new)
    for f in plus:                              # write the reflection into -X
        g = fm[f]
        for v in o.V[f]:
            p = o.get(f, v)
            o.set(g, o.m.mm[v], np.array([2 * u0 - p[0], p[1]]))
    corr = max(np.linalg.norm(o.get(f, v) - before[(f, v)]) for f in fs for v in o.V[f]) / size
    return u0, corr, rms / size


def normalise_density(o, fs):
    """scale the island so 1 UV unit = 1 m of surface (area-equivalent), moved to its bbox minimum."""
    a3 = sum(o.m.a3[f] for f in fs)
    auv = sum(abs(o.auv(f)) for f in fs)
    k = math.sqrt(a3 / auv) if auv > 0 else 1.0
    C = island_corners(o, fs)
    apply_affine(o, fs, np.eye(2) * k, -C.min(0) * k)
    return k


# ---------------------------------------------------------------- packing
def raster(polys_px, halo):
    """polys_px: list of (n,2) pixel polygons (x right, y down), offset >= halo+2. Bool mask of texels within `halo`
    of a covered texel."""
    allp = np.concatenate(polys_px)
    W = int(np.ceil(allp[:, 0].max() + halo + 3))
    H = int(np.ceil(allp[:, 1].max() + halo + 3))
    im = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(im)
    for p in polys_px:
        d.polygon([tuple(x) for x in p], fill=255, outline=255)
    m = np.array(im) > 0
    if halo > 0:
        m = ndimage.distance_transform_edt(~m) <= halo
    return m


class Group:
    """a packing unit: one island, or a mirrored pair laid side by side (twin = the -X reflection)."""

    def __init__(self, name, items):
        self.name = name
        self.items = items
        self.twin = None
        self.scale = 1.0

    def polys_m(self):
        return [o.uv[f] * self.scale for o, fs in self.items for f in fs]


def build_group_px(g, D, halo, pair_gap):
    tri = []
    Dg = D * g.scale
    for o, fs in g.items:
        for f in fs:
            p = o.uv[f] * Dg
            tri.append(np.c_[p[:, 0], -p[:, 1]])
    twin_tri, c = [], None
    if g.twin is not None:
        minx = min(t[:, 0].min() for t in tri)
        c = minx - pair_gap / 2.0
        twin_tri = [np.c_[2 * c - t[:, 0], t[:, 1]] for t in tri]
    allt = tri + twin_tri
    off = -np.concatenate(allt).min(0) + halo + 2
    return raster([t + off for t in allt], halo), off, c


def pack(groups, page, D, halo, pair_gap, order, mode='bottom'):
    occ = np.zeros((page, page), bool)
    places = {}
    masks = {g.name: build_group_px(g, D, halo, pair_gap) for g in groups}
    for g in sorted(groups, key=order):
        m, off, c = masks[g.name]
        h, w = m.shape
        if h > page or w > page:
            return None
        if occ.any():
            corr = signal.fftconvolve(occ.astype(np.float32), m[::-1, ::-1].astype(np.float32), mode='valid')
            valid = corr < 0.5
        else:
            valid = np.ones((page - h + 1, page - w + 1), bool)
        ys, xs = np.nonzero(valid)
        if len(ys) == 0:
            return None
        if mode == 'bottom':
            score = -(ys + h) * page * 4 + xs
        elif mode == 'top':
            score = -ys * page * 4 + xs
        else:
            score = xs * page * 4 - (ys + h)
        k = int(np.argmin(score))
        y, x = ys[k], xs[k]
        occ[y:y + h, x:x + w] |= m
        places[g.name] = (x, y, off, c)
    return places, occ


def group_extent(g):
    T_ = g.polys_m()
    w = max(t[:, 0].max() for t in T_) - min(t[:, 0].min() for t in T_)
    h = max(t[:, 1].max() for t in T_) - min(t[:, 1].min() for t in T_)
    return (2 * w if g.twin is not None else w), h


def group_area(g):
    s = 0.0
    for t in g.polys_m():
        s += abs(IP.poly_area_uv(t))
    return s * (2 if g.twin is not None else 1)


ORDERS = {
    'maxdim': lambda g: -max(group_extent(g)),
    'bbox': lambda g: -group_extent(g)[0] * group_extent(g)[1],
    'height': lambda g: -group_extent(g)[1],
    'area': lambda g: -group_area(g),
    'width': lambda g: -group_extent(g)[0],
}


def pack_search(groups, page, halo, pair_gap, lo, hi, iters=14, log=None):
    best = None
    tried = []
    for oname, order in ORDERS.items():
        for mode in ('bottom', 'top', 'left'):
            a, b, ok = lo, hi, None
            for _ in range(iters):
                mid = (a + b) / 2
                r = pack(groups, page, mid, halo, pair_gap, order, mode)
                if r is None:
                    b = mid
                else:
                    a = mid
                    ok = (mid, r)
            tried.append((oname + '/' + mode, ok[0] if ok else None))
            if log:
                log('  order %-6s %-6s D=%s' % (oname, mode, '%.1f' % ok[0] if ok else '-'))
            if ok and (best is None or ok[0] > best[0]):
                best = (ok[0], ok[1], oname + '/' + mode)
    return best, tried


def place_groups(groups, places, D, page):
    for g in groups:
        x, y, off, pair_c = places[g.name]
        Dg = D * g.scale
        for o, fs in g.items:
            for f in fs:
                p = o.uv[f] * Dg
                px = np.c_[p[:, 0], -p[:, 1]] + off + np.array([x, y])
                o.uv[f] = np.c_[px[:, 0] / page, 1 - px[:, 1] / page]
        if g.twin is not None:
            o, fs_minus, fm, fs_plus = g.twin
            c_px = pair_c + off[0] + x
            for f in fs_plus:
                gg = fm[f]
                for v in o.V[f]:
                    p = o.get(f, v)
                    o.set(gg, o.m.mm[v], np.array([(2 * c_px - p[0] * page) / page, p[1]]))


# ---------------------------------------------------------------- driver
def build_groups(name, o, mirror, rep):
    groups = []
    isl = o.islands()
    if not mirror:
        for i, fs in enumerate(isl):
            make_upright(o, fs)
            normalise_density(o, fs)
            g = Group('%s:%d' % (name, i), [(o, fs)])
            g.info = {'group': g.name, 'kind': 'unique', 'faces': len(fs), 'parts': sorted(set(o.m.part[f] for f in fs))}
            groups.append(g)
            rep.append(g.info)
        return groups, []
    fm = o.m.face_mirror()
    side = {i: side_of(o.m, fs) for i, fs in enumerate(isl)}
    face_isl = {f: i for i, fs in enumerate(isl) for f in fs}
    paired_minus, problems = set(), []
    for i, fs in enumerate(isl):
        parts = sorted(set(o.m.part[f] for f in fs))
        info = {'faces': len(fs), 'parts': parts}
        if side[i] == 0:
            fset = set(fs)
            if all(fm[f] in fset and fm[f] != f for f in fs):
                u0, corr, asym = symmetrise(o, fs, fm)
                info.update(kind='centre_symmetric', native_asym_rms_rel=asym, symmetrise_max_correction_rel=corr)
            else:
                make_upright(o, fs)
                info.update(kind='centre_asymmetric')
                problems.append('%s island %s: mirror does not close inside the centre island, or faces straddle '
                                'x = 0 without a centre edge loop (left as solved)' % (name, parts))
            normalise_density(o, fs)
            g = Group('%s:c%d' % (name, i), [(o, fs)])
        elif side[i] > 0:
            tw = face_isl.get(fm[fs[0]]) if fm[fs[0]] >= 0 else None
            fs_minus = isl[tw] if tw is not None else None
            make_upright(o, fs)
            normalise_density(o, fs)
            g = Group('%s:p%d' % (name, i), [(o, fs)])
            if fs_minus is not None and sorted(fm[f] for f in fs) == sorted(fs_minus):
                g.twin = (o, fs_minus, fm, fs)
                paired_minus.add(tw)
                info.update(kind='lateral_pair_unique', twin_faces=len(fs_minus))
            else:
                info.update(kind='unique')
                problems.append('%s island %s: no exact -X twin (packed alone)' % (name, parts))
        else:
            continue
        info['group'] = g.name
        g.info = info
        groups.append(g)
        rep.append(info)
    for i, fs in enumerate(isl):                 # -X islands without a +X twin are packed alone
        if side[i] < 0 and i not in paired_minus:
            make_upright(o, fs)
            normalise_density(o, fs)
            g = Group('%s:m%d' % (name, i), [(o, fs)])
            g.info = {'group': g.name, 'kind': 'unique', 'faces': len(fs), 'parts': sorted(set(o.m.part[f] for f in fs))}
            groups.append(g)
            rep.append(g.info)
            problems.append('%s island %s: -X island without a +X twin' % (name, g.info['parts']))
    return groups, problems


def group_faces(g):
    """(object, face, mirror source face or None) for every face the group puts on the page."""
    out = [(o, f, None) for o, fs in g.items for f in fs]
    if g.twin is not None:
        o, fs_minus, fm, fs_plus = g.twin
        out += [(o, fm[f], f) for f in fs_plus]
    return out


def run(dump, raw, cfg, log=print):
    if cfg.get('schema') != SCHEMA_CONFIG:
        raise uvenv.SetupError('layout config schema must be %s' % SCHEMA_CONFIG)
    t0 = time.time()
    mirror_objs = set(cfg.get('mirror_objects', []))
    prio = cfg.get('priority') or {}
    never = IP.load_never_visible(prio.get('never_visible'), dump) if prio else {}
    halo_extra = float(cfg.get('halo_extra_px', 1.25))
    search = cfg.get('search') or {}
    rep = {'pages': [], 'problems': [], 'head_calibration': None}
    uvobjs, ok = {}, True
    seen = set()
    for page in cfg['pages']:
        for n in page['objects']:
            if n in seen:
                raise uvenv.SetupError('object %s is on two pages' % n)
            seen.add(n)
            if n not in dump['objects'] or n not in raw['objects']:
                raise uvenv.SetupError('object %s missing in the dump or the raw unwrap' % n)
    for page in cfg['pages']:
        size, gutter = int(page['size']), float(page.get('gutter_px', 16))
        halo, pair_gap = gutter / 2 + halo_extra, gutter + 0.5
        groups, prep = [], {'name': page.get('name', 'page'), 'size': size, 'gutter_px': gutter, 'halo_px': halo,
                            'groups': []}
        for n in page['objects']:
            o = UVObj(MeshData(n, dump['objects'][n]), raw['objects'][n]['polys'])
            uvobjs[n] = (o, size, prep['name'])
            gs, probs = build_groups(n, o, n in mirror_objs, prep['groups'])
            rep['problems'] += probs
            ff = IP.face_factors(dump, n, prio, never) if prio else np.ones(o.nf)
            for g in gs:
                if prio:
                    faces = [f for oo, f, _ in group_faces(g)]
                    g.scale = IP.island_multiplier(faces, ff, never.get(n), o.m.a3)
                g.info['multiplier'] = round(g.scale, 4)
            groups += gs
        prep['_groups'] = groups
        rep['pages'].append(prep)
    # ---- head calibration on the bone-region estimator (before packing: the ratio does not depend on D)
    ht = cfg.get('head_target')
    if ht:
        rules = ht.get('bone_regions')
        objs = set(ht.get('objects', []))
        num, den = ht.get('num', 'head'), ht.get('den', 'torso')
        excl = bool(ht.get('exclude_never_visible', False))
        regions = {n: IP.tri_regions(dump['objects'][n], rules) for n in objs}
        tris = {n: IP.tris_by_poly(dump['objects'][n]) for n in objs}
        rows, head_groups = [], set()
        for prep in rep['pages']:
            for g in prep['_groups']:
                gf = [(o, f, src) for o, f, src in group_faces(g) if o.m.name in objs]
                if not gf:
                    continue
                area = collections.Counter()
                grows = []
                for o, f, src in gf:
                    n = o.m.name
                    for k, tv in enumerate(tris[n][f]):
                        a3 = IP.tri_area3d(o.m.P, tv)
                        rg = regions[n][(f, k)]
                        area[rg] += a3
                        # a -X twin is written later as the reflection of its +X source: same UV area
                        tuv = [o.get(f, v) for v in tv] if src is None else [o.get(src, o.m.mm[v]) for v in tv]
                        hidden = never.get(n) is not None and never[n][f]
                        grows.append((rg, a3, abs(IP.poly_area_uv(tuv)), hidden))
                nv = never.get(gf[0][0].m.name)
                all_hidden = nv is not None and all(nv[f] for _, f, _ in gf)
                if area and area.most_common(1)[0][0] == num and not all_hidden:
                    head_groups.add(g.name)
                rows += [(g, rg, a3, au) for rg, a3, au, hidden in grows if not (excl and hidden)]

        def entries(s):
            return IP.region_density([(rg, a3, au, g.scale * (s if g.name in head_groups else 1.0))
                                      for g, rg, a3, au in rows], num, den)
        before = entries(1.0)[1]
        s, r = IP.calibrate(entries, float(ht['ratio']))
        cal = {'target': ht['ratio'], 'num': num, 'den': den, 'exclude_never_visible': excl,
               'ratio_before': before, 'head_groups': sorted(head_groups)}
        if s is None:
            cal.update(applied=False, why=r)
            rep['problems'].append('head calibration not applied: %s' % r)
        else:
            for prep in rep['pages']:
                for g in prep['_groups']:
                    if g.name in head_groups:
                        g.scale *= s
                        g.info['multiplier'] = round(g.scale, 4)
            cal.update(applied=True, factor=s, ratio_after=r)
        rep['head_calibration'] = cal
        log('head calibration: %s' % {k: v for k, v in cal.items() if k != 'head_groups'})
    # ---- pack
    for prep in rep['pages']:
        groups, size = prep.pop('_groups'), prep['size']
        halo, pair_gap = prep['halo_px'], prep['gutter_px'] + 0.5
        total = sum(group_area(g) for g in groups)
        d_full = size / math.sqrt(total) if total > 0 else 1.0
        lo = float(search.get('lo') or 0.2 * d_full)
        hi = float(search.get('hi') or 1.01 * d_full)
        best, tried = pack_search(groups, size, halo, pair_gap, lo, hi, int(search.get('iters', 14)),
                                  log=lambda s: log('[%s]%s' % (prep['name'], s)))
        if best is None:
            ok = False
            prep['packed'] = False
            rep['problems'].append('page %s: nothing fits at the lowest density %.1f' % (prep['name'], lo))
            continue
        D, (places, occ), order = best
        place_groups(groups, places, D, size)
        prep.update(packed=True, density_t_per_m=D, order=order, search=[lo, hi], halo_occupancy=float(occ.mean()),
                    tried=tried)
        for g in groups:
            g.info['density_t_per_m'] = round(D * g.scale, 1)
    if any('twin' in p for p in rep['problems']):
        ok = False
    out = {'schema': SCHEMA_OUT, 'config_schema': SCHEMA_CONFIG, 'objects': {}, 'report': rep}
    for n, (o, size, pname) in uvobjs.items():
        out['objects'][n] = {'page': pname, 'page_size': size, 'verts': o.V,
                             'polys': [o.uv[f].tolist() for f in range(o.nf)]}
    rep['seconds'] = round(time.time() - t0, 1)
    return out, ok


def main(argv=None):
    ap = argparse.ArgumentParser(prog='organic_layout.py', description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('dump')
    ap.add_argument('raw')
    ap.add_argument('config')
    ap.add_argument('--out', required=True)
    ap.add_argument('--quiet', action='store_true')
    a = ap.parse_args(argv)
    outp = uvenv.out_path(a.out, 'layout')
    dump, raw, cfg = uvenv.read_json(a.dump), uvenv.read_json(a.raw), uvenv.read_json(a.config)
    out, ok = run(dump, raw, cfg, log=(lambda s: None) if a.quiet else print)
    uvenv.write_json(outp, out, indent=None)
    rep_path = outp.with_name(outp.stem + '_report.json')
    uvenv.write_json(rep_path, out['report'])
    for p in out['report']['pages']:
        print('page %s %d px: D %s t/m, order %s, %d groups' % (p['name'], p['size'], p.get('density_t_per_m'),
                                                              p.get('order'), len(p['groups'])))
    for pr in out['report']['problems']:
        print('PROBLEM', pr)
    print('LAYOUT', outp)
    print('REPORT', rep_path)
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
