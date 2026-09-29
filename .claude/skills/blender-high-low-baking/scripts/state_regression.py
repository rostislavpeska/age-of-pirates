"""State regression gate for textured low-poly page maps: catch what a later state LOST against an accepted one.

Owner (Korean TC, 2026-09-29): "Tests should catch regressions from previous model states" - the v15 eave alpha
scallops were silently lost in later states and he found it by eye. Every compose, UV-version switch and export
fingerprints the new state and compares it with the accepted baselines; a FAIL blocks promotion unless the owner
waived that exact property (waivers.json, same idea as the vanilla bar's bench_exceptions.json).

  python state_regression.py fingerprint STATE_DIR --plan PLAN.json --geometry FACES.json [--sources Obj=Prefix,..]
                             [--low LOW.blend --uv-layer UV_Final] [--map PAGE_Kind=path ..] [--export DIR]
                             [--export-alias P2048=mata,P1024=matb] [--name NAME] -o NAME.fp.json
  python state_regression.py compare BASE.fp.json NEW.fp.json [--waivers waivers.json] [--only "alpha.*,eave.*"]
                             [-o report.json] -> exit 0 PASS, 3 FAIL (each regressed property with both numbers)
  python state_regression.py plan-from-geometry FACES.json --page ATLAS=2048 --material SUBSTR=CLASS ..
                             [--vertical-as ROOF_TILE=EAVE_CUTOUT] --out-plan PLAN.json
                             (a layout without a UV plan, e.g. the v15 roof atlas: one plan face per dumped face,
                             charts = UV-connected islands, every face an owner)

Inputs. PLAN = {"faces": {key: {page, uv [[u,v]..], family, owner, material}}} (the UV_Factory plan). FACES = a
face dump {object: {"faces": [{i, n, v, c, ...}]}} (ridge_faces.json) or {"objects": {...}} (this script's
--dump-geometry, run inside background Blender for --low and cached as <out>.geometry.json; Blender is launched only
after the machine gate exits 0: env STATE_REG_GATE = path of blender_gate.py, STATE_REG_BLENDER = blender.exe; the
dumped object names usually differ from the plan key prefixes -> --sources, a geometry covering < 50 % of the plan
faces stops with the object list). Maps: STATE_DIR/
<page>_<Kind>.png for Kind in KINDS, overridden per --map. Pure numpy + OpenCV/PIL otherwise.

Fingerprint (per element class = plan material, EAVE_CUTOUT split by role FRONT/UNDER/BACK/TOP from geometry;
per chart = plan family (+ role)); owner texels = texel centres inside owner face polygons:
  maps       per class and map kind: mean/std, empty (black) fraction, normal presence (slope > 0.03) and strength,
             content fraction (texel share of charts whose signal std exceeds the flat floor), ClassID purity;
             per chart: empty (black) share of every EMPTY_KIND and flat share of BaseColor / Normal (texels whose
             5x5 window is constant: a flat fill, a blanked normal, a hole) - partial holes in one chart;
             per class: flat patches in world m2 (share inside patches >= 0.05 m2, largest patch) - across layouts
  density    texels per world unit per class (plan UVs vs geometry)
  alpha      cut fraction (opacity < 0.5) per class/role; eave FRONT runs (all FRONT faces, members included,
             sampled through their own UVs in world s/z): the silhouette (lowest opaque z per 1 cm column),
             band-passed so a straight cut edge of any slope reads ~0: scallops per metre, amplitude and rms,
             disc phase: silhouette vs the FRONT normal pattern and FRONT pattern vs the roof rolls above;
             the eave gate itself is qa_detectors.eave_alpha_check (called, not duplicated): per role cut, UNDER
             hanging cut, BACK/UNDER opaque behind a cut FRONT (-> back_agreement), alpha edge on the baked outline
  registration  members on owner texels of their own class and eave role (NO_OWNER / WRONG_CLASS / WRONG_ROLE)
  seams      per class, every 3D edge between two faces whose UVs split there: colour / normal jump across it
             (the joint continuity of ridge runs, eave strips and roof banks)
  export     agreement of the exported page alpha (DDT DXT5 / PNG / TGA) with the page Opacity
Comparison (compare() below): per element class also across UV layouts (v15 atlas vs S18 pages); per chart, per
member, seam identity and eave phase only where the layout is the same (>= 90 % of the baseline chart texels unchanged).
Not compared across layouts: geometry-derived maps (AO, Masks, EdgeWear, Dirt - neighbourhood and bake convention)
and the textures of a class whose texels are borrowed from another class (v15 backing reads the FRONT's texels).
Rules are one-sided where the direction is known (entering the eave gate's FRONT band passes; a solid chart may not
gain cut). SKIP rows say what was not compared and why. references/texturing-qa.md "Regression gate" (item 7).
Specimen proof: test_state_regression.py. Real baselines (Korean TC): Texturing_11/Claude_CP2/regression.
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

KINDS = ('BaseColor', 'Normal', 'AO', 'Masks', 'Roughness', 'Metallic', 'EdgeWear', 'Dirt', 'Opacity', 'ClassID')
EMPTY_KINDS = ('BaseColor', 'Normal', 'AO', 'Masks', 'Roughness')     # black there = never written
CONTENT_KINDS = ('BaseColor', 'Normal', 'AO', 'Roughness', 'EdgeWear', 'Dirt')
GEO_KINDS = ('AO', 'Masks', 'EdgeWear', 'Dirt')   # derived from the neighbourhood geometry and its bake convention (v15 AO
                                                  # spans 0.5-1, S18 0-1): compared only within one layout
EAVE = 'EAVE_CUTOUT'
FLAT_FLOOR = {'Normal': 0.01}      # std of the signal below which a chart is a flat fill
FLAT_FLOOR_DEFAULT = 0.006
FLAT_KINDS = ('BaseColor', 'Normal')   # locally constant patches (flat fill, blanked normal, black hole) are measured
FLAT_WIN, FLAT_STD = 5, 0.002      # a texel is flat when its 5x5 window std (per channel, rms) is below 0.002
FLAT_BLOB_M2 = 0.05                # class level: flat patches of at least 0.05 m2 (layout independent)
BIN = 0.01                         # eave profile bin along the run (m)
SCALLOP_BAND = (1.0, 5.0)          # silhouette band-pass, gaussian sigmas in bins (cm): keeps the 10-25 cm disc period,
                                   # removes straight edges of any slope, per-face kinks and the eave sweep
SCALLOP_PROM = 0.015               # a scallop = band-passed silhouette minimum with >= 15 mm prominence (1.6 texels at 107 tpu)
SCHEMA = 2


# ------------------------------------------------------------------------------------------------ IO
def read_map(path):
    """float32 HxWxC top-down, 0..1 (PNG/TIF 8/16 bit, EXR/NPY through qa_detectors)."""
    import qa_detectors as Q
    return Q.read_map(path)


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def load_plan(path):
    return json.load(open(path, encoding='utf-8-sig'))['faces']


def load_geometry(path, sources=None):
    """face dump -> {plan_key: face}. sources {object: key prefix}; None = the object names are the prefixes."""
    F = json.load(open(path, encoding='utf-8-sig'))
    objs = F['objects'] if isinstance(F.get('objects'), dict) and 'summary' in F else F
    sources = sources or {ob: ob for ob in objs}
    geo = {}
    for ob, prefix in sources.items():
        for f in objs[ob]['faces']:
            geo[f'{prefix}:{f["i"]}'] = f
    return geo


def parse_pairs(items, sep='='):
    out = {}
    for it in items or []:
        for part in it.split(','):
            if part.strip():
                k, v = part.split(sep, 1); out[k.strip()] = v.strip()
    return out


# ------------------------------------------------------------------------------------------------ rasters
def poly_texels(uv, size):
    """texel centres inside the UV polygon: rows (top-down), cols, and texel-space x, y (y up)."""
    p = np.asarray(uv, np.float64) * size
    x0, y0 = np.floor(p.min(0)).astype(int); x1, y1 = np.ceil(p.max(0)).astype(int) + 1
    x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, size), min(y1, size)
    if x1 <= x0 or y1 <= y0:
        e = np.zeros(0, int); return e, e, np.zeros(0), np.zeros(0)
    xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
    inside = np.zeros(xs.shape, bool)
    for i in range(len(p)):
        (ax, ay), (bx, by) = p[i], p[(i + 1) % len(p)]
        dy = by - ay
        inside ^= ((ay > ys) != (by > ys)) & (xs < (bx - ax) * (ys - ay) / (dy if dy != 0 else 1e-12) + ax)
    vy, vx = np.nonzero(inside)
    return size - 1 - (vy + y0), vx + x0, xs[inside], ys[inside]


def texel_world(uv, verts, size, tx, ty):
    """3D positions of texel-space points (tx, ty) through the face's fan triangles (barycentric)."""
    p = np.asarray(uv, np.float64) * size; V = np.asarray(verts, np.float64)
    pts = np.stack([tx, ty], -1); P = np.zeros((len(pts), 3)); best = np.full(len(pts), np.inf)
    for i in range(1, len(p) - 1):
        a, b, c = p[0], p[i], p[i + 1]
        T = np.array([[b[0] - a[0], c[0] - a[0]], [b[1] - a[1], c[1] - a[1]]])
        if abs(np.linalg.det(T)) < 1e-9:
            continue
        l = np.linalg.solve(T, (pts - a).T).T; l1, l2 = l[:, 0], l[:, 1]; l0 = 1 - l1 - l2
        d = np.maximum.reduce([-l0, -l1, -l2, np.zeros_like(l0)])
        m = d < best
        P[m] = (l0[:, None] * V[0] + l1[:, None] * V[i] + l2[:, None] * V[i + 1])[m]
        best = np.minimum(best, d)
    return P


def world_area(verts):
    V = np.asarray(verts, np.float64)
    return float(sum(np.linalg.norm(np.cross(V[i] - V[0], V[i + 1] - V[0])) for i in range(1, len(V) - 1)) / 2)


def uv_area(uv, size):
    p = np.asarray(uv, np.float64) * size
    return abs(0.5 * float(np.dot(p[:, 0], np.roll(p[:, 1], -1)) - np.dot(p[:, 1], np.roll(p[:, 0], -1))))


def signal(kind, a):
    if kind == 'Normal':
        n = a[:, :2] * 2 - 1; return np.hypot(n[:, 0], n[:, 1])
    if kind == 'Opacity' or a.shape[1] < 3:
        return a[:, 0]
    return a[:, 0] * .2126 + a[:, 1] * .7152 + a[:, 2] * .0722


def empty_texels(kind, a):
    """black = never written (rows of an N x C array)."""
    return a[:, :3].max(1) < (0.02 if kind == 'Normal' else 0.004)


def flat_mask(kind, a):
    """HxW bool: texels whose FLAT_WIN window is constant (rms of the per-channel std < FLAT_STD) - a flat fill, a
    blanked normal, a black hole. Normal: the x/y slope channels; else RGB."""
    import cv2
    ch = a[..., :2] if kind == 'Normal' else a[..., :min(3, a.shape[-1])]
    var = np.zeros(a.shape[:2])
    for c in range(ch.shape[-1]):
        x = np.ascontiguousarray(ch[..., c], np.float64)
        m = cv2.blur(x, (FLAT_WIN, FLAT_WIN), borderType=cv2.BORDER_REPLICATE)
        var += np.maximum(cv2.blur(x * x, (FLAT_WIN, FLAT_WIN), borderType=cv2.BORDER_REPLICATE) - m * m, 0)
    return np.sqrt(var / ch.shape[-1]) < FLAT_STD


# ------------------------------------------------------------------------------------------------ model
class State:
    """plan + geometry + page maps with per-face texel sets."""

    def __init__(self, plan, geo, maps, pages=None):
        self.plan, self.geo = plan, geo
        self.maps = maps                                  # {page: {kind: array}}
        self.pages = pages or {}
        for pg, kinds in maps.items():
            for a in kinds.values():
                self.pages.setdefault(pg, a.shape[0])
        self.faces = {}
        for k, x in plan.items():
            if x['page'] not in self.pages:
                continue
            g = geo.get(k)
            f = dict(key=k, page=x['page'], size=self.pages[x['page']], uv=np.asarray(x['uv'], float),
                     mat=x.get('material', '?'), owner=bool(x.get('owner', True)), family=x.get('family', k),
                     v=None if g is None else np.asarray(g['v'], float), n=None if g is None else np.asarray(g['n'], float),
                     c=None if g is None else np.asarray(g.get('c', np.mean(g['v'], 0)), float), role=None, out=None)
            f['rows'], f['cols'], f['tx'], f['ty'] = poly_texels(f['uv'], f['size'])
            self.faces[k] = f
        self._roles()
        for f in self.faces.values():
            f['cls'] = f'{EAVE}.{f["role"]}' if f['mat'] == EAVE and f['role'] else f['mat']
            f['chart'] = f['family'] + (f'|{f["role"]}' if f['role'] else '')

    def _roles(self):
        """eave_geom.roles: UNDER n.z < -0.2, TOP n.z > 0.2, else FRONT/BACK by the horizontal normal of the nearest
        UNDER face (the outward direction)."""
        eave = [f for f in self.faces.values() if f['mat'] == EAVE and f['n'] is not None]
        unders = [f for f in eave if f['n'][2] < -0.2]
        UC = np.array([u['c'] for u in unders]) if unders else None
        for f in eave:
            n = f['n']
            if n[2] < -0.2:
                h = n.copy(); h[2] = 0; f['role'] = 'UNDER'; f['out'] = h / max(np.linalg.norm(h), 1e-9); continue
            if n[2] > 0.2:
                f['role'] = 'TOP'; continue
            if UC is not None:
                u = unders[int(np.argmin(np.linalg.norm(UC - f['c'], axis=1)))]; h = u['n'].copy()
            else:
                h = n.copy()
            h[2] = 0; h /= max(np.linalg.norm(h), 1e-9); f['out'] = h
            f['role'] = 'FRONT' if float(np.dot(n, h)) > 0 else 'BACK'

    def values(self, f, kind):
        a = self.maps.get(f['page'], {}).get(kind)
        return None if a is None or not len(f['rows']) else a[f['rows'], f['cols']]

    def flat(self, pg, kind):
        """cached flat_mask of a page map (None when the map is absent)."""
        cache = self.__dict__.setdefault('_flat', {})
        if (pg, kind) not in cache:
            a = self.maps.get(pg, {}).get(kind)
            cache[(pg, kind)] = None if a is None else flat_mask(kind, a)
        return cache[(pg, kind)]


# ------------------------------------------------------------------------------------------------ metrics
def class_metrics(st):
    by_cls = defaultdict(list)
    for f in st.faces.values():
        by_cls[f['cls']].append(f)
    names = sorted(by_cls); bit = {c: np.uint64(1) << np.uint64(i) for i, c in enumerate(names)}
    claim = {pg: np.zeros(sz * sz, np.uint64) for pg, sz in st.pages.items()}
    for f in st.faces.values():
        if f['owner'] and len(f['rows']):
            claim[f['page']][f['rows'] * f['size'] + f['cols']] |= bit[f['cls']]
    out = {}
    for cls, fl in sorted(by_cls.items()):
        owners = [f for f in fl if f['owner']]
        rec = dict(faces=len(fl), owners=len(owners), members=len(fl) - len(owners), maps={}, content={})
        if not owners:
            out[cls] = rec; continue
        page_idx = defaultdict(list)
        for f in owners:
            page_idx[f['page']].append(f['rows'] * f['size'] + f['cols'])
        rec['texels'] = int(sum(len(np.unique(np.concatenate(v))) for v in page_idx.values()))
        # texels this class shares with owners of ANOTHER class (v15: the eave backing reads the FRONT's texels) -
        # such a class shows borrowed content, so its texture rules are not compared across layouts
        sh = sum(int(((claim[pg][np.unique(np.concatenate(v))] & ~bit[cls]) != 0).sum()) for pg, v in page_idx.items())
        rec['borrowed'] = round(sh / max(rec['texels'], 1), 4)
        # density: texels per world unit (texel-weighted median over owner faces)
        d, w = [], []
        for f in owners:
            if f['v'] is None:
                continue
            wa = world_area(f['v'])
            if wa > 1e-6:
                d.append(np.sqrt(uv_area(f['uv'], f['size']) / wa)); w.append(max(len(f['rows']), 1))
        if d:
            o = np.argsort(d); d, w = np.array(d)[o], np.array(w, float)[o]; cw = np.cumsum(w) / w.sum()
            rec['density'] = dict(median=round(float(d[np.searchsorted(cw, 0.5)]), 2),
                                  p10=round(float(d[np.searchsorted(cw, 0.1)]), 2))
        rec['flat'] = flat_patches(st, page_idx, rec.get('density', {}).get('median'))
        for kind in KINDS:
            vals = []
            for pg, idx in page_idx.items():
                a = st.maps.get(pg, {}).get(kind)
                if a is not None:
                    u = np.unique(np.concatenate(idx)); vals.append(a.reshape(-1, a.shape[-1])[u])
            if not vals:
                continue
            a = np.concatenate(vals); s = signal(kind, a); m = dict(mean=round(float(s.mean()), 4), std=round(float(s.std()), 4))
            if kind in EMPTY_KINDS:
                m['empty'] = round(float(empty_texels(kind, a).mean()), 4)
            if kind == 'Normal':
                m['presence'] = round(float((s > 0.03).mean()), 4); m['strength'] = m.pop('mean')
                m['p90'] = round(float(np.percentile(s, 90)), 4)
            if kind == 'Opacity':
                m['cut'] = round(float((s < 0.5).mean()), 4)
            if kind == 'ClassID':
                q = np.rint(a[:, :3] * 255).astype(np.int64); code = q[:, 0] * 65536 + q[:, 1] * 256 + q[:, 2]
                c = Counter(code.tolist()); m = dict(purity=round(c.most_common(1)[0][1] / len(code), 4),
                                                     dominant='%06X' % c.most_common(1)[0][0])
            rec['maps'][kind] = m
        out[cls] = rec
    return out


def flat_patches(st, page_idx, tpu):
    """per FLAT_KIND: share of the class's owner texels that are locally constant (frac), share inside connected flat
    patches of >= FLAT_BLOB_M2 world area (big_frac) and the largest patch (max_m2) - comparable across UV layouts."""
    import cv2
    out = {}
    for kind in FLAT_KINDS:
        tot = flat = big = 0; mx = 0.0; have = False
        for pg, idx in page_idx.items():
            F = st.flat(pg, kind)
            if F is None:
                continue
            have = True; size = st.pages[pg]; u = np.unique(np.concatenate(idx))
            M = np.zeros(size * size, np.uint8); M[u[F.reshape(-1)[u]]] = 1
            _, _, stats, _ = cv2.connectedComponentsWithStats(M.reshape(size, size), connectivity=8)
            areas = stats[1:, cv2.CC_STAT_AREA].astype(np.int64)
            m2 = areas / float(tpu) ** 2 if tpu else areas / 1e4
            tot += len(u); flat += int(areas.sum()); big += int(areas[m2 >= FLAT_BLOB_M2].sum())
            mx = max(mx, float(m2.max()) if len(m2) else 0.0)
        if have and tot:
            out[kind] = dict(frac=round(flat / tot, 4), big_frac=round(big / tot, 4), max_m2=round(mx, 3))
    return out


def chart_metrics(st):
    """per chart (family + role): owner texels, a texel-set hash (identity across states), per-kind signal stats."""
    ch = defaultdict(list)
    for f in st.faces.values():
        if f['owner'] and len(f['rows']):
            ch[f['chart']].append(f)
    out = {}
    for c, fl in ch.items():
        pg = fl[0]['page']; size = fl[0]['size']
        idx = np.unique(np.concatenate([f['rows'] * size + f['cols'] for f in fl if f['page'] == pg]))
        h = hashlib.sha1(pg.encode() + idx.astype(np.int64).tobytes()).hexdigest()[:16]
        rec = dict(cls=Counter(f['cls'] for f in fl).most_common(1)[0][0], page=pg, texels=int(len(idx)), hash=h)
        for kind in EMPTY_KINDS:                    # a partial hole: black share of THIS chart
            a = st.maps.get(pg, {}).get(kind)
            if a is not None:
                rec.setdefault('empty', {})[kind] = round(float(empty_texels(kind, a.reshape(-1, a.shape[-1])[idx]).mean()), 4)
        for kind in FLAT_KINDS:                     # a partial flat fill / blanked normal patch of THIS chart
            F = st.flat(pg, kind)
            if F is not None:
                rec.setdefault('flat', {})[kind] = round(float(F.reshape(-1)[idx].mean()), 4)
        for kind in CONTENT_KINDS + ('Opacity',):
            a = st.maps.get(pg, {}).get(kind)
            if a is None:
                continue
            s = signal(kind, a.reshape(-1, a.shape[-1])[idx])
            if kind == 'Opacity':
                rec['cut'] = round(float((s < 0.5).mean()), 4)
            else:
                rec[kind] = round(float(s.std()), 4)
                if kind == 'Normal':
                    rec['presence'] = round(float((s > 0.03).mean()), 4)
        out[c] = rec
    return out


def content_fractions(charts, classes):
    """texel share of each class's charts that carry a signal (std above the flat floor)."""
    for cls, rec in classes.items():
        cs = [c for c in charts.values() if c['cls'] == cls and c['texels'] >= 16]
        tot = sum(c['texels'] for c in cs)
        for kind in CONTENT_KINDS:
            have = [c for c in cs if kind in c]
            if have and tot:
                fl = FLAT_FLOOR.get(kind, FLAT_FLOOR_DEFAULT)
                rec['content'][kind] = round(sum(c['texels'] for c in have if c[kind] > fl) / tot, 4)


def registration(st, min_texels=6, min_share=0.8):
    lab, owners = {}, []
    for f in st.faces.values():
        if f['owner'] and len(f['rows']):
            L = lab.setdefault(f['page'], np.zeros((f['size'], f['size']), np.int32))
            owners.append(f); L[f['rows'], f['cols']] = len(owners)
    res = defaultdict(lambda: dict(members=0, checked=0, NO_OWNER=0, WRONG_CLASS=0, WRONG_ROLE=0, flagged={}, keys=[]))
    for f in st.faces.values():
        if f['owner']:
            continue
        r = res[f['cls']]; r['members'] += 1
        if len(f['rows']) < min_texels or f['page'] not in lab:
            continue
        r['checked'] += 1; r['keys'].append(f['key'])
        ids = lab[f['page']][f['rows'], f['cols']]; on = ids > 0
        flags, info = [], dict(on_owner=round(float(on.mean()), 3))
        if on.mean() < 0.5:
            flags.append('NO_OWNER')
        else:
            oc = [owners[i - 1] for i in ids[on]]
            same_cls = np.mean([o['mat'] == f['mat'] for o in oc]); info['same_class'] = round(float(same_cls), 3)
            if same_cls < min_share:
                flags.append('WRONG_CLASS')
            elif f['mat'] == EAVE and f['role']:
                same_role = np.mean([o['role'] == f['role'] for o in oc]); info['same_role'] = round(float(same_role), 3)
                info['owner_roles'] = dict(Counter(o['role'] for o in oc))
                if same_role < min_share:
                    flags.append('WRONG_ROLE')
        for fl in flags:
            r[fl] += 1
        if flags:
            info['flags'] = flags; r['flagged'][f['key']] = info
    return {k: dict(v) for k, v in res.items()}


def _edge_samples(f, i, offset=1.5, n=7):
    p = f['uv'] * f['size']; a, b = p[i], p[(i + 1) % len(p)]; d = b - a; L = np.linalg.norm(d)
    if L < 1.5:
        return None
    nn = np.array([-d[1], d[0]]) / L
    if np.dot(p.mean(0) - a, nn) < 0:
        nn = -nn
    t = np.linspace(0.2, 0.8, n)[:, None]
    q = a + t * d + offset * nn
    col = np.clip(q[:, 0].astype(int), 0, f['size'] - 1); row = np.clip(f['size'] - 1 - q[:, 1].astype(int), 0, f['size'] - 1)
    return row, col


def seams(st, luma_jump=0.08, normal_jump=0.12):
    """per class: 3D edges shared by two faces of the class whose UVs split there -> mean colour / slope jump."""
    edges = defaultdict(list)
    for f in st.faces.values():
        if f['v'] is None or len(f['v']) != len(f['uv']):
            continue
        vk = [tuple(np.round(p, 4)) for p in f['v']]
        for i in range(len(vk)):
            edges[frozenset((vk[i], vk[(i + 1) % len(vk)]))].append((f, i, vk[i]))
    out = defaultdict(lambda: dict(n=0, luma=[], normal=[], bad=[]))
    for e, lst in edges.items():
        if len(lst) != 2:
            continue
        (fa, ia, va), (fb, ib, vb) = lst
        if fa['cls'] != fb['cls']:
            continue
        if fa['page'] == fb['page']:
            pa = fa['uv'] * fa['size']; pb = fb['uv'] * fb['size']
            a0, a1 = pa[ia], pa[(ia + 1) % len(pa)]; b0, b1 = pb[ib], pb[(ib + 1) % len(pb)]
            if va != vb:
                b0, b1 = b1, b0
            if max(np.linalg.norm(a0 - b0), np.linalg.norm(a1 - b1)) <= 0.75:
                continue                       # continuous UVs: not a seam
        sa, sb = _edge_samples(fa, ia), _edge_samples(fb, ib)
        if sa is None or sb is None:
            continue
        if va != vb:
            sb = (sb[0][::-1], sb[1][::-1])
        r = out[fa['cls']]; r['n'] += 1
        key = '|'.join(sorted((fa['key'], fb['key'])))
        bad = False
        for kind, lst2, thr in (('BaseColor', r['luma'], luma_jump), ('Normal', r['normal'], normal_jump)):
            A, B = st.maps.get(fa['page'], {}).get(kind), st.maps.get(fb['page'], {}).get(kind)
            if A is None or B is None:
                continue
            j = abs(float(signal(kind, A[sa]).mean() - signal(kind, B[sb]).mean())); lst2.append(j)
            bad |= j > thr
        if bad:
            r['bad'].append(key)
    res = {}
    for cls, r in out.items():
        d = dict(n=r['n'], bad_edges=sorted(r['bad']))
        for k, thr in (('luma', luma_jump), ('normal', normal_jump)):
            if r[k]:
                a = np.array(r[k]); d[f'{k}_bad_frac'] = round(float((a > thr).mean()), 4)
                d[f'{k}_p90'] = round(float(np.percentile(a, 90)), 4)
        res[cls] = d
    return res


# ------------------------------------------------------------------------------------------------ eave alpha
def _face_samples(st, f, kind):
    if f['v'] is None or not len(f['rows']):
        return None
    a = st.maps.get(f['page'], {}).get(kind)
    if a is None:
        return None
    P = texel_world(f['uv'], f['v'], f['size'], f['tx'], f['ty'])
    wa = world_area(f['v']); tpu = np.sqrt(uv_area(f['uv'], f['size']) / wa) if wa > 1e-9 else 100.0
    return P, signal(kind, a[f['rows'], f['cols']]), tpu


def _binned(s, vals, lo, nb, how='mean'):
    b = np.clip(((s - lo) / BIN).astype(int), 0, nb - 1)
    n = np.bincount(b, minlength=nb).astype(float)
    if how == 'mean':
        return np.where(n > 0, np.bincount(b, vals, nb) / np.maximum(n, 1), np.nan), n
    red = np.full(nb, np.inf if how == 'min' else -np.inf)
    (np.minimum if how == 'min' else np.maximum).at(red, b, vals)
    return np.where(n > 0, red, np.nan), n


def _fill(x):
    ok = ~np.isnan(x)
    if ok.sum() < 2:
        return np.where(ok, x, 0.0)
    i = np.arange(len(x)); return np.interp(i, i[ok], x[ok])


def _silhouette(S, Z, A, T, lo, nb):
    """lowest opaque z per 1 cm column of a run: in each bin the alpha 0.5 crossing between the highest cut texel and
    the lowest opaque texel (linear in alpha); robust to texel columns split across bins (a bin missing the texels
    near the edge is nan and later interpolated). No cut in the bin: the band bottom. Only cut: nan."""
    b = np.clip(((S - lo) / BIN).astype(int), 0, nb - 1)
    cut = A < 0.5
    zc = np.full(nb, -np.inf); np.maximum.at(zc, b[cut], Z[cut])
    zo = np.full(nb, np.inf); np.minimum.at(zo, b[~cut], Z[~cut])
    ac = np.zeros(nb); m = cut & (Z == zc[b]); np.maximum.at(ac, b[m], A[m])
    ao = np.ones(nb); m = ~cut & (Z == zo[b]); np.minimum.at(ao, b[m], A[m])
    zall = np.full(nb, np.inf); np.minimum.at(zall, b, Z)
    dz = np.bincount(b, T, nb) / np.maximum(np.bincount(b, minlength=nb), 1)
    zb = np.minimum(np.minimum(zall, np.r_[np.inf, zall[:-1]]), np.r_[zall[1:], np.inf])
    e = np.full(nb, np.nan)
    both = np.isfinite(zc) & np.isfinite(zo)
    with np.errstate(invalid='ignore'):
        t = np.clip((0.5 - ac) / np.maximum(ao - ac, 1e-6), 0, 1)
        e[both] = np.where(zo[both] > zc[both], zc[both] + t[both] * (zo[both] - zc[both]), (zo[both] + zc[both]) / 2)
        e[both & (zo - zc > 1.6 * dz)] = np.nan
        nocut = ~np.isfinite(zc) & np.isfinite(zo) & (zo <= zb + 0.75 * dz)
    e[nocut] = zo[nocut] - dz[nocut] / 2
    return e


def _gauss(x, sig):
    r = int(np.ceil(4 * sig)); k = np.exp(-0.5 * (np.arange(-r, r + 1) / sig) ** 2)
    return np.convolve(np.pad(x, r, mode='edge'), k / k.sum(), mode='valid')


def _minima(r, win=4, prom_win=10, prom=SCALLOP_PROM):
    idx = []
    for i in range(len(r)):
        lo, hi = max(0, i - win), min(len(r), i + win + 1)
        if r[i] > r[lo:hi].min() or (i > 0 and r[i - 1] == r[i]):
            continue
        left, right = r[max(0, i - prom_win):i], r[i + 1:i + 1 + prom_win]
        if len(left) and len(right) and min(left.max(), right.max()) - r[i] >= prom:
            idx.append(i)
    return idx


def _lag(a, b, max_lag=15):
    """normalised cross-correlation lag (bins) of b against a; both 1-D, nan-free."""
    a = a - a.mean(); b = b - b.mean(); best = (0, -2.0)
    for L in range(-max_lag, max_lag + 1):
        x, y = (a[L:], b[:len(b) - L]) if L >= 0 else (a[:L], b[-L:])
        if len(x) < 20 or x.std() < 1e-9 or y.std() < 1e-9:
            continue
        c = float(np.corrcoef(x, y)[0, 1])
        if c > best[1]:
            best = (L, c)
    return best


def eave_profile(st, opacity='Opacity'):
    """What eave_alpha_check does not measure: the scallop silhouette ALONG each eave and its phase.
    FRONT runs = straight stretches (outward direction within 5 deg, plane within 3 cm, height within 0.4 m; members
    included, each face sampled through its own UVs in world s/z). Per run the SILHOUETTE along s (1 cm bins: the
    alpha 0.5 crossing between the highest cut and the lowest opaque texel, _silhouette), band-passed (gaussian 1 cm
    minus 5 cm): a straight cut edge of any slope, the kink where a horizontal cut meets a sloping face bottom and the
    eave sweep all fall out; the 10-25 cm disc arcs stay. scallops = band-passed minima with >= SCALLOP_PROM
    prominence (disc bottoms), amplitude = p95 - p5, rms. Measured on the Korean TC (2026-09-29): 7.2/m (S18i alpha
    candidate) and 7.1/m (v15) against 0/m for straight bands that keep the same cut per face (horizontal, or parallel
    to each face bottom) and for the opaque final/; rms 0.65 / 0.75 cm against 0.19-0.20 cm.
    Phase: lag of the silhouette against the FRONT normal pattern (disc_alpha) and of the FRONT pattern against the
    roof rolls above the run (roll_disc)."""
    fronts = [f for f in st.faces.values() if f['mat'] == EAVE and f['role'] == 'FRONT' and f['v'] is not None]
    if not fronts or not any(opacity in st.maps.get(f['page'], {}) for f in fronts):
        return dict(verdict='SKIP', reasons=['no FRONT eave faces with an opacity map'])
    runs = []
    for f in sorted(fronts, key=lambda f: (not f['owner'], f['key'])):
        for r in runs:
            if np.dot(r['out'], f['out']) > 0.996 and abs(np.dot(f['c'] - r['c0'], r['out'])) < 0.03 and abs(f['c'][2] - r['c0'][2]) < 0.4:
                r['faces'].append(f); break
        else:
            runs.append(dict(out=f['out'], c0=f['c'], faces=[f]))
    run_out, tot_min, tot_len, amps, lags_disc, lags_roll, sq = [], 0, 0.0, [], [], [], [0.0, 0]
    tiles = [f for f in st.faces.values() if f['mat'] == 'ROOF_TILE' and f['v'] is not None]
    for ri, r in enumerate(runs):
        a = np.cross([0, 0, 1.0], r['out']); a /= np.linalg.norm(a)
        S, Z, A, D, T = [], [], [], [], []
        for f in r['faces']:
            sm = _face_samples(st, f, opacity)
            if sm is None:
                continue
            P, al, tpu = sm; S.append(P @ a); Z.append(P[:, 2]); A.append(al); T.append(np.full(len(al), 1 / tpu))
            nm = st.values(f, 'Normal'); D.append(signal('Normal', nm) if nm is not None else np.full(len(al), np.nan))
        if not S:
            continue
        S, Z, A, D, T = (np.concatenate(x) for x in (S, Z, A, D, T))
        lo = S.min(); nb = int((S.max() - lo) / BIN) + 1
        if nb < 24:
            continue
        zmax, _ = _binned(S, Z, lo, nb, 'max')
        sil = _silhouette(S, Z, A, T, lo, nb); ok = ~np.isnan(sil)
        res = _gauss(_fill(sil), SCALLOP_BAND[0]) - _gauss(_fill(sil), SCALLOP_BAND[1])
        core = np.zeros(nb, bool); core[8:nb - 8] = True; core &= ok
        if core.sum() < 10:
            continue
        mins = [i for i in _minima(res) if core[i]]
        length = float(core.sum() * BIN)
        amp = float(np.percentile(res[core], 95) - np.percentile(res[core], 5))
        sq[0] += float((res[core] ** 2).sum()); sq[1] += int(core.sum())
        rec = dict(run=ri, faces=len(r['faces']), owners=sum(f['owner'] for f in r['faces']), length_m=round(length, 3),
                   s0=round(float(lo), 3), out=[round(float(x), 3) for x in r['out']], z=round(float(r['c0'][2]), 3),
                   cut=round(float((A < 0.5).mean()), 4), scallops=len(mins), amplitude_m=round(amp, 4),
                   rms_m=round(float(np.sqrt((res[core] ** 2).mean())), 5),
                   minima_s=[round(float(lo + (i + 0.5) * BIN), 3) for i in mins])
        good = ~np.isnan(D)
        Dm = _binned(S[good], D[good], lo, nb)[0] if good.any() else None
        if Dm is not None and amp > 0.004 and core.sum() > 40:
            L, c = _lag(_fill(Dm)[core], -res[core]); rec['disc_alpha'] = dict(lag_m=round(L * BIN, 3), corr=round(c, 3))
            lags_disc.append((L * BIN, c, core.sum()))
        if Dm is not None and tiles:
            top = float(np.nanmax(zmax)); RS, RD = [], []
            for t in tiles:
                off = float(np.dot(t['c'] - r['c0'], r['out']))
                if not (-0.9 < off < 0.15 and top - 0.05 < t['c'][2] < top + 0.6):
                    continue
                hn = t['n'].copy(); hn[2] = 0
                if np.linalg.norm(hn) < 1e-6 or np.dot(hn / np.linalg.norm(hn), r['out']) < 0.5:
                    continue
                sm = _face_samples(st, t, 'Normal')
                if sm is None:
                    continue
                P, sl, _ = sm; keep = P[:, 2] < top + 0.35
                RS.append(P[keep] @ a); RD.append(sl[keep])
            if RS:
                RS, RD = np.concatenate(RS), np.concatenate(RD)
                Rm, rn = _binned(RS, RD, lo, nb)
                both = core & (rn > 0) & ~np.isnan(Dm)
                if both.sum() > 40:
                    L, c = _lag(_fill(Dm)[both], _fill(Rm)[both]); rec['roll_disc'] = dict(lag_m=round(L * BIN, 3), corr=round(c, 3))
                    lags_roll.append((L * BIN, c, both.sum()))
        tot_min += len(mins); tot_len += length; amps.append((amp, length)); run_out.append(rec)
    if not run_out:
        return dict(verdict='SKIP', reasons=['no FRONT run long enough'])
    wamp = sum(x * l for x, l in amps) / max(sum(l for _, l in amps), 1e-9)

    def wmed(lst):
        if not lst:
            return None
        lst = sorted(lst); w = np.cumsum([x[2] for x in lst]); i = int(np.searchsorted(w, w[-1] / 2))
        return dict(lag_m=round(lst[i][0], 3), corr=round(float(np.average([x[1] for x in lst], weights=[x[2] for x in lst])), 3),
                    runs=len(lst))
    front = dict(runs=len(run_out), length_m=round(tot_len, 2), scallops=tot_min,
                 scallops_per_m=round(tot_min / max(tot_len, 1e-9), 3), amplitude_m=round(wamp, 4),
                 rms_m=round(float(np.sqrt(sq[0] / max(sq[1], 1))), 5),
                 cut_visible=round(float(np.average([r['cut'] for r in run_out], weights=[r['length_m'] + 1e-9 for r in run_out])), 4))
    return dict(verdict='INFO', FRONT=front, disc_alpha=wmed(lags_disc), roll_disc=wmed(lags_roll), runs=run_out)


def eave_gate(st):
    """the eave alpha gate of qa_detectors.eave_alpha_check (FRONT cut band, UNDER hanging part, BACK/UNDER behind a
    cut FRONT, alpha edge on the baked tile outline) - called, never re-implemented - summarised per role; its
    per-chart rows stay in the fingerprint so a chart that passed and now fails is named."""
    try:
        import qa_detectors as Q
        fn = Q.eave_alpha_check
    except (ImportError, AttributeError) as e:
        return dict(verdict='SKIP', reasons=[f'qa_detectors.eave_alpha_check unavailable: {e}'])
    out = dict(verdict='SKIP', reasons=[], charts={}, per_role={})
    for pg, kinds in st.maps.items():
        if 'Opacity' not in kinds or 'Normal' not in kinds:
            continue
        if not any(f['page'] == pg and f['mat'] == EAVE for f in st.faces.values()):
            continue
        r = fn(st.plan, st.geo, kinds['Opacity'], kinds['Normal'], page=pg, size=st.pages[pg], classes=(EAVE,))
        out['verdict'] = r['verdict'] if out['verdict'] != 'FAIL' else 'FAIL'
        out['reasons'] += r['reasons']; out['charts'].update({f'{pg}:{k}': v for k, v in r['charts'].items()})
        out['mismatched_faces'] = r.get('mismatched_faces', [])
    roles = defaultdict(lambda: dict(texels=0, cut=0.0, checked=0, mismatch=0.0, hanging=0, hanging_cut=0.0, edge=[]))
    for k, row in out['charts'].items():
        role = k.rsplit('| ', 1)[-1].strip(); e = roles[role]
        e['texels'] += row['texels']; e['cut'] += row['cut'] * row['texels']
        if 'checked' in row:
            e['checked'] += row['checked']; e['mismatch'] += row['mismatch'] * row['checked']
        if row.get('hanging'):
            e['hanging'] += row['hanging']; e['hanging_cut'] += row['hanging_cut'] * row['hanging']
        if row.get('edge_columns') and row.get('edge_median_texels') == row.get('edge_median_texels'):
            e['edge'].append((row['edge_median_texels'], row['edge_columns']))
    for role, e in roles.items():
        d = dict(texels=e['texels'], cut=round(e['cut'] / max(e['texels'], 1), 4))
        if e['checked']:
            d['checked'] = e['checked']; d['mismatch'] = round(e['mismatch'] / e['checked'], 4)
        if e['hanging']:
            d['hanging'] = e['hanging']; d['hanging_cut'] = round(e['hanging_cut'] / e['hanging'], 4)
        if e['edge']:
            v = sorted(e['edge']); w = np.cumsum([x[1] for x in v]); d['edge_median_texels'] = v[int(np.searchsorted(w, w[-1] / 2))][0]
        out['per_role'][role] = d
    out['n_fail_charts'] = sum(r['verdict'] == 'FAIL' for r in out['charts'].values())
    out['reasons'] = out['reasons'][:30]
    return out


def eave_alpha(st):
    res = eave_profile(st)
    res['gate'] = eave_gate(st)
    beh = [res['gate']['per_role'].get(r, {}) for r in ('BACK', 'UNDER')]
    chk = sum(b.get('checked', 0) for b in beh)
    res['back_agreement'] = round(1 - sum(b.get('mismatch', 0) * b.get('checked', 0) for b in beh) / chk, 4) if chk else None
    return res


# ------------------------------------------------------------------------------------------------ export
def read_ddt_alpha(path):
    """alpha (0..1, top-down) of mip 0 of an AoE3DE .ddt (RTS3, format 9 = DXT5; format 4 DXT1 -> None)."""
    d = open(path, 'rb').read()
    if d[:4] != b'RTS3':
        raise ValueError(f'{path}: not an RTS3 ddt')
    fmt, nm = d[6], d[7]; w, h = np.frombuffer(d[8:16], '<u4')
    if fmt != 9:
        return None
    off, size = np.frombuffer(d[16:24], '<u4')
    b = np.frombuffer(d[off:off + size], np.uint8).reshape(-1, 16)
    a0, a1 = b[:, 0].astype(np.float32), b[:, 1].astype(np.float32)
    bits = sum(b[:, 2 + k].astype(np.uint64) << np.uint64(8 * k) for k in range(6))
    codes = np.stack([((bits >> np.uint64(3 * i)) & np.uint64(7)).astype(np.int64) for i in range(16)], 1)
    pal = np.zeros((len(b), 8), np.float32); pal[:, 0], pal[:, 1] = a0, a1
    big = a0 > a1
    for i in range(1, 7):
        pal[:, i + 1] = np.where(big, ((7 - i) * a0 + i * a1) / 7, 0)
    for i in range(1, 5):
        pal[:, i + 1] = np.where(big, pal[:, i + 1], ((5 - i) * a0 + i * a1) / 5)
    pal[:, 6] = np.where(big, pal[:, 6], 0); pal[:, 7] = np.where(big, pal[:, 7], 255)
    px = np.take_along_axis(pal, codes, 1).reshape(int(h) // 4, int(w) // 4, 4, 4)
    return px.transpose(0, 2, 1, 3).reshape(int(h), int(w)) / 255.0


def read_export_alpha(path):
    p = str(path).lower()
    if p.endswith('.ddt'):
        return read_ddt_alpha(path)
    from PIL import Image
    im = Image.open(path)
    if 'A' not in im.getbands():
        return None
    return np.asarray(im.getchannel('A'), np.float32) / 255.0


def export_agreement(st, export_dir, alias):
    out = {}
    for pg, kinds in st.maps.items():
        if 'Opacity' not in kinds:
            continue
        name = alias.get(pg, pg)
        cand = sorted(Path(export_dir).glob(f'*{name}*BaseColor*')) + sorted(Path(export_dir).glob(f'*{name}*Opacity*'))
        cand = [c for c in cand if c.suffix.lower() in ('.ddt', '.png', '.tga', '.dds', '.tif')]
        if not cand:
            out[pg] = dict(verdict='SKIP', reason=f'no *{name}*BaseColor* export in {export_dir}'); continue
        al = read_export_alpha(cand[0])
        if al is None:
            out[pg] = dict(verdict='SKIP', file=str(cand[0]), reason='export has no alpha'); continue
        size = st.pages[pg]
        if al.shape[0] != size:
            import cv2
            al = cv2.resize(al.astype(np.float32), (size, size), interpolation=cv2.INTER_NEAREST)
        op = kinds['Opacity'][..., 0]
        sel_e = np.zeros((size, size), bool); sel_a = np.zeros((size, size), bool)
        for f in st.faces.values():
            if f['page'] == pg and f['owner'] and len(f['rows']):
                sel_a[f['rows'], f['cols']] = True
                if f['mat'] == EAVE:
                    sel_e[f['rows'], f['cols']] = True
        best = None
        for flip in (False, True):
            A = al[::-1] if flip else al
            ag = dict(eave=round(float(((A < 0.5) == (op < 0.5))[sel_e].mean()), 4) if sel_e.any() else None,
                      all=round(float(((A < 0.5) == (op < 0.5))[sel_a].mean()), 4), flipped=flip)
            if best is None or ag['all'] > best['all']:
                best = ag
        out[pg] = dict(file=str(cand[0]), sha256=sha256(cand[0]), **best)
    return out


# ------------------------------------------------------------------------------------------------ fingerprint
def discover_maps(state_dir, pages, overrides):
    maps, src = defaultdict(dict), {}
    for pg in pages:
        for kind in KINDS:
            for ext in ('.png', '.exr', '.tif', '.npy'):
                p = Path(state_dir) / f'{pg}_{kind}{ext}'
                if p.exists():
                    src[f'{pg}_{kind}'] = p; break
    for k, v in overrides.items():
        if v.lower() in ('none', '-'):
            src.pop(k, None)
        else:
            src[k] = Path(v)
    for k, p in src.items():
        pg, kind = k.rsplit('_', 1); maps[pg][kind] = read_map(p)
    return dict(maps), {k: dict(path=str(p), sha256=sha256(p)) for k, p in src.items()}


def fingerprint(state, name='state', sources=None):
    t0 = time.time()
    classes = class_metrics(state)
    charts = chart_metrics(state)
    content_fractions(charts, classes)
    reg = registration(state)
    for cls, r in reg.items():
        classes.setdefault(cls, dict(maps={}, content={}))['registration'] = r
    for cls, r in seams(state).items():
        classes.setdefault(cls, dict(maps={}, content={}))['seams'] = r
    fp = dict(schema=SCHEMA, name=name, tool='state_regression.py', created=time.strftime('%Y-%m-%d %H:%M:%S'),
              sources=sources or {}, pages=state.pages,
              faces=dict(total=len(state.faces), no_geometry=sum(f['v'] is None for f in state.faces.values())),
              classes=classes, charts=charts, eave=eave_alpha(state), face_keys=sorted(state.faces))
    fp['seconds'] = round(time.time() - t0, 1)
    return fp


def build_state(state_dir, plan_path, geometry=None, sources=None, map_over=None, pages=None):
    plan = load_plan(plan_path)
    geo = load_geometry(geometry, sources) if geometry else {}
    if geometry and sum(k in geo for k in plan) < 0.5 * len(plan):
        F = json.load(open(geometry, encoding='utf-8-sig')); objs = F.get('objects', F)
        raise SystemExit(f'geometry covers {sum(k in geo for k in plan)} of {len(plan)} plan faces: map the dumped objects '
                         f'to the plan key prefixes with --sources Obj=Prefix (objects: {sorted(objs)[:12]}; prefixes: '
                         f'{sorted({k.split(":")[0] for k in plan})})')
    pg = sorted({x['page'] for x in plan.values()}) if not pages else list(pages)
    maps, msrc = discover_maps(state_dir, pg, map_over or {})
    sizes = {p: int(s) for p, s in (pages or {}).items()}
    for p in pg:
        if p not in sizes and p in maps and maps[p]:
            sizes[p] = next(iter(maps[p].values())).shape[0]
    st = State(plan, geo, maps, sizes)
    src = dict(state_dir=str(state_dir), plan=str(plan_path), plan_sha256=sha256(plan_path),
               geometry=str(geometry) if geometry else None, maps=msrc,
               tools={n: sha256(HERE / n)[:16] for n in ('state_regression.py', 'qa_detectors.py') if (HERE / n).exists()})
    return st, src


# ------------------------------------------------------------------------------------------------ elements (added)
# Named ELEMENTS (face selections such as "columns", "tower_top") carry a colour / value fingerprint, compared across
# layouts too. Only the elements a BASELINE marks "protect" are rules (an owner-approved preview protects what he liked);
# a candidate's own fingerprint carries every element unprotected, so comparing it with its base never fails on the
# element the candidate is meant to change. --scope on compare skips named elements (the declared change).
ELEMENT_DE, ELEMENT_PALETTE_SHIFT, ELEMENT_ROUGH, ELEMENT_PALETTE_DE = 5.0, 0.15, 0.08, 25.0


def _lab(rgb):
    """sRGB 0..1 (..., 3) -> CIELAB (D65)"""
    s = np.asarray(rgb, np.float64); L = np.where(s <= 0.04045, s / 12.92, ((s + 0.055) / 1.055) ** 2.4)
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = L @ M.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > (6 / 29) ** 3, np.cbrt(xyz), xyz / (3 * (6 / 29) ** 2) + 4 / 29)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def _palette_shares(rgb, palette):
    """share of texels nearest to each named palette colour (Lab distance <= ELEMENT_PALETTE_DE, else 'other')"""
    if not len(rgb) or not palette:
        return {}
    names = list(palette)
    P = _lab(np.array([[int(palette[n][i:i + 2], 16) / 255.0 for i in (0, 2, 4)] for n in names]))
    lab = _lab(rgb); d = np.linalg.norm(lab[:, None, :] - P[None], axis=-1); j = d.argmin(1)
    ok = d[np.arange(len(j)), j] <= ELEMENT_PALETTE_DE
    out = {n: round(float(((j == i) & ok).mean()), 4) for i, n in enumerate(names)}
    out['other'] = round(float((~ok).mean()), 4)
    return {k: v for k, v in out.items() if v > 0}


def element_metrics(st, spec, protect=()):
    """spec = {"palette": {name: hex}, "elements": {name: {"faces": [plan keys], "protect": bool}}}: per element the
    union of its faces' own texels per page (owners and members, each texel once) -> texels, mean sRGB, CIELAB, luma,
    palette shares (a deterministic sample of <= 200k texels), roughness mean. Same numbers as state/statelib.py."""
    pal = spec.get('palette') or {}; out = {}
    for name, e in sorted((spec.get('elements') or {}).items()):
        per_page = defaultdict(list)
        for k in e.get('faces', []):
            f = st.faces.get(k)
            if f is not None and len(f['rows']):
                per_page[f['page']].append(f['rows'] * f['size'] + f['cols'])
        rgb, rough, n = [], [], 0
        for pg, parts in per_page.items():
            idx = np.unique(np.concatenate(parts)); n += len(idx); M = st.maps.get(pg, {}); size = st.pages[pg]
            if 'BaseColor' in M:
                rgb.append(M['BaseColor'].reshape(size * size, -1)[idx, :3])
            if 'Roughness' in M:
                rough.append(M['Roughness'].reshape(size * size, -1)[idx, 0])
        m = dict(texels=int(n), protect=bool(e.get('protect')) or name in protect)
        c = np.concatenate(rgb) if rgb else np.zeros((0, 3))
        if len(c):
            lum = c @ np.array([0.2126, 0.7152, 0.0722])
            m.update(srgb_mean=[round(float(x) * 255, 1) for x in c.mean(0)], lab=[round(float(x), 2) for x in _lab(c.mean(0)[None])[0]],
                     luma_mean=round(float(lum.mean()), 4), palette=_palette_shares(c[:: max(1, len(c) // 200000)], pal))
        r = np.concatenate(rough) if rough else np.zeros(0)
        if len(r):
            m['rough_mean'] = round(float(r.mean()), 4)
        out[name] = m
    return out


def _element_rules(base, new, rule, skip, scope):
    for name, b in sorted((base.get('elements') or {}).items()):
        if not b.get('protect') or b.get('texels', 0) < 50:
            continue
        pid = f'element.colour[{name}]'
        n = (new.get('elements') or {}).get(name)
        if scope and any(_match(name, s) for s in scope):
            skip(pid, 'in the declared change scope (--scope)'); continue
        if n is None or not n.get('texels'):
            skip(pid, 'the new fingerprint has no element fingerprints (fingerprint ... --elements FILE)'); continue
        if not b.get('lab') or not n.get('lab'):
            continue
        dE = float(np.linalg.norm(np.array(b['lab']) - np.array(n['lab'])))
        pb, pn = b.get('palette') or {}, n.get('palette') or {}
        moves = {k: round(pn.get(k, 0) - pb.get(k, 0), 3) for k in set(pb) | set(pn)}
        shift = max((abs(v) for v in moves.values()), default=0.0)
        top = ', '.join(f'{k} {v:+.2f}' for k, v in sorted(moves.items(), key=lambda t: -abs(t[1]))[:3] if abs(v) >= 0.02)
        rule(pid, dict(srgb=b['srgb_mean'], palette=pb), dict(srgb=n['srgb_mean'], palette=pn),
             dE <= ELEMENT_DE and shift <= ELEMENT_PALETTE_SHIFT,
             f'protected element (owner-approved baseline): mean colour dE76 {dE:.1f} <= {ELEMENT_DE} and largest palette share '
             f'shift {shift:.2f} <= {ELEMENT_PALETTE_SHIFT}' + (f' ({top})' if top else ''))
        if 'rough_mean' in b and 'rough_mean' in n:
            rule(f'element.roughness[{name}]', b['rough_mean'], n['rough_mean'], abs(n['rough_mean'] - b['rough_mean']) <= ELEMENT_ROUGH,
                 f'protected element: |mean roughness - baseline| <= {ELEMENT_ROUGH}')


# ------------------------------------------------------------------------------------------------ compare
def _num(x):
    return isinstance(x, (int, float)) and not isinstance(x, bool)


def _match(pid, pat):
    """a property id against a waiver / --only pattern: exact, or with * as the only wildcard ([ ] are literal)."""
    return pid == pat or re.fullmatch(re.escape(pat).replace(re.escape("*"), ".*"), pid) is not None


def _front_band():
    """the FRONT cut band of qa_detectors.eave_alpha_check (read from its signature, not re-declared)."""
    try:
        import inspect
        import qa_detectors as Q
        return tuple(inspect.signature(Q.eave_alpha_check).parameters['front_cut'].default)
    except Exception:          # noqa: BLE001
        return (0.15, 0.35)


def compare(base, new, waivers=None, only=None, scope=None):
    """Every rule: (property id, baseline, new, pass?, rule text). Only the owner's waivers turn a FAIL into WAIVED.
    only = patterns (* wildcard) of property ids to evaluate (e.g. ['alpha.*', 'eave.*']); None = all.
    scope = element names (* wildcard) of the declared change: their protected-element rules are skipped."""
    W = (waivers or {}).get('waived', {})
    rows = []
    same = _same_layout(base, new); band = _front_band()

    def rule(pid, b, n, ok, text):
        if only and not any(_match(pid, o) for o in only):
            return
        verdict = 'PASS' if ok else 'FAIL'
        if not ok:
            hit = next((w for w in W if _match(pid, w)), None)
            if hit:
                verdict = 'WAIVED'
        rows.append(dict(id=pid, base=b, new=n, verdict=verdict, rule=text))

    def skip(pid, why):
        if not only or any(_match(pid, o) for o in only):
            rows.append(dict(id=pid, base=None, new=None, verdict='SKIP', rule=why))

    if base.get('schema') != new.get('schema'):          # an older fingerprint lacks newer measures: rules would skip silently
        rule('fingerprint.schema', base.get('schema'), new.get('schema'), False,
             f'both fingerprints must come from the same tool schema ({SCHEMA}): re-fingerprint the baseline '
             '(Korean TC: make_baselines.py baselines)')
    BC, NC = base['classes'], new['classes']
    keys_b, keys_n = set(_face_keys(base)), set(_face_keys(new))
    for cls, b in sorted(BC.items()):
        n = NC.get(cls)
        if b.get('texels', 0) >= 50 and (n is None or n.get('texels', 0) == 0):
            rule(f'class.missing[{cls}]', b.get('texels'), 0, False, 'a class with texels in the baseline must exist'); continue
        if n is None:
            continue
        bd, nd = b.get('density', {}).get('median'), n.get('density', {}).get('median')
        if _num(bd) and _num(nd):
            rule(f'density[{cls}]', bd, nd, nd >= 0.85 * bd, 'texels/unit >= 0.85 x baseline')
        borrowed = not same and max(b.get('borrowed', 0), n.get('borrowed', 0)) > 0.5
        if borrowed:
            skip(f'texture[{cls}]', f'texels shared with another class (borrowed {b.get("borrowed")} -> {n.get("borrowed")}): '
                                    'texture rules only within one layout')
        geo_skip = sorted(k for k in b.get('maps', {}) if k in GEO_KINDS and not same)
        if geo_skip and not borrowed:
            skip(f'geo_maps[{cls}]', f'{geo_skip} depend on the surrounding geometry and bake convention: only within one layout')
        for kind, bm in b.get('maps', {}).items():
            nm = n.get('maps', {}).get(kind)
            if (borrowed and kind != 'Opacity') or kind in geo_skip:
                continue
            if nm is None:
                if kind != 'ClassID':
                    rule(f'map.missing[{cls}.{kind}]', 'present', 'absent', False, 'a map the baseline had must exist')
                continue
            if 'empty' in bm:
                rule(f'map.empty[{cls}.{kind}]', bm['empty'], nm.get('empty'), nm.get('empty', 1) <= bm['empty'] + 0.02,
                     'black (never written) texel share <= baseline + 0.02')
            if kind == 'Normal':
                rule(f'normal.presence[{cls}]', bm['presence'], nm['presence'], nm['presence'] >= 0.7 * bm['presence'] - 0.02,
                     'texel share with slope > 0.03 >= 0.7 x baseline - 0.02')
                rule(f'normal.strength[{cls}]', bm['strength'], nm['strength'], nm['strength'] >= 0.6 * bm['strength'],
                     'mean slope >= 0.6 x baseline')
            if kind == 'Opacity':
                bc, nc = bm['cut'], nm['cut']
                if cls == f'{EAVE}.FRONT':
                    inb = lambda x: band[0] <= x <= band[1]      # noqa: E731
                    rule(f'alpha.cut[{cls}]', bc, nc, abs(nc - bc) <= max(0.08, 0.4 * bc) or (inb(nc) and not inb(bc)),
                         f'|cut - baseline| <= max(0.08, 0.4 x baseline); entering the gate band {band} from outside passes')
                elif cls.startswith(EAVE + '.'):
                    if same:
                        rule(f'alpha.cut[{cls}]', bc, nc, abs(nc - bc) <= max(0.08, 0.4 * bc) or nc > bc,
                             '|cut - baseline| <= max(0.08, 0.4 x baseline) (more cut behind the FRONT passes; '
                             'the eave gate judges what shows)')
                else:
                    rule(f'alpha.cut[{cls}]', bc, nc, nc <= bc + 0.01, 'solid class: cut <= baseline + 0.01')
            if kind == 'ClassID' and 'purity' in bm and 'purity' in nm:
                rule(f'classid.purity[{cls}]', bm['purity'], nm['purity'], nm['purity'] >= bm['purity'] - 0.05,
                     'dominant ClassID share >= baseline - 0.05')
        for kind, bv in b.get('content', {}).items():
            nv = n.get('content', {}).get(kind)
            if nv is not None and not borrowed and (same or kind not in GEO_KINDS):
                rule(f'content[{cls}.{kind}]', bv, nv, nv >= bv - 0.10, 'texel share of charts with content >= baseline - 0.10')
        for kind, bv in b.get('flat', {}).items():         # flat / empty PATCHES in world m2: also across layouts
            nv = n.get('flat', {}).get(kind)
            if nv is None or borrowed:
                continue
            rule(f'flat.area[{cls}.{kind}]', bv['big_frac'], nv['big_frac'], nv['big_frac'] <= bv['big_frac'] + 0.01,
                 f'class share inside locally constant patches >= {FLAT_BLOB_M2} m2 (flat fill, blanked normal, hole) '
                 '<= baseline + 0.01')
            rule(f'flat.max_m2[{cls}.{kind}]', bv['max_m2'], nv['max_m2'], nv['max_m2'] <= max(2 * bv['max_m2'], bv['max_m2'] + 0.25),
                 'largest locally constant patch (m2) <= max(2 x, baseline + 0.25 m2)')
        bs, ns = b.get('seams', {}), n.get('seams', {})
        if bs.get('n', 0) >= 20 and ns.get('n', 0) >= 20:
            for k in ('luma_bad_frac', 'normal_bad_frac'):
                if k in bs and k in ns:
                    rule(f'seams.{k}[{cls}]', bs[k], ns[k], ns[k] <= bs[k] + 0.05, 'share of seam edges with a jump <= baseline + 0.05')
            if _same_layout(base, new):
                newbad = sorted(set(ns.get('bad_edges', [])) - set(bs.get('bad_edges', [])))
                if len(newbad) > max(3, 0.02 * ns['n']):
                    rule(f'seams.new_bad[{cls}]', len(bs.get('bad_edges', [])), len(ns.get('bad_edges', [])), False,
                         f'new jumping seams: {newbad[:6]}')
        br, nr = b.get('registration') or {}, n.get('registration')
        if nr and nr.get('checked'):
            common = keys_b & keys_n            # faces of the same model (v15 vs S18 share none: not compared)
            newflag = {k: v for k, v in nr.get('flagged', {}).items() if k not in br.get('flagged', {}) and k in common}
            if common:
                rule(f'registration[{cls}]', len(br.get('flagged', {})), len(nr.get('flagged', {})), not newflag,
                     'no member newly off its class/role: ' + '; '.join(f'{k} {v.get("flags")} {v.get("owner_roles", "")}'
                                                                        for k, v in list(newflag.items())[:6]))
    # charts (same texel set in both states only)
    for c, b in base.get('charts', {}).items():
        n = new.get('charts', {}).get(c)
        if n is None or n['hash'] != b['hash'] or b['texels'] < 200:
            continue
        if 'presence' in b and 'presence' in n and b['presence'] >= 0.2:
            rule(f'chart.normal.presence[{c}]', b['presence'], n['presence'], n['presence'] >= b['presence'] - 0.05,
                 'chart normal presence >= baseline - 0.05')
        for kind, bv in b.get('empty', {}).items():
            nv = n.get('empty', {}).get(kind)
            if nv is not None:
                rule(f'chart.empty[{c}.{kind}]', bv, nv, nv <= bv + 0.01, 'chart black (never written) share <= baseline + 0.01')
        for kind, bv in b.get('flat', {}).items():
            nv = n.get('flat', {}).get(kind)
            if nv is not None:
                rule(f'chart.flat[{c}.{kind}]', bv, nv, nv <= bv + 0.02,
                     f'chart share of locally constant texels ({FLAT_WIN}x{FLAT_WIN} std < {FLAT_STD}: flat fill, blanked '
                     'normal, hole) <= baseline + 0.02')
        for kind in CONTENT_KINDS:
            if kind in b and kind in n and b[kind] > FLAT_FLOOR.get(kind, FLAT_FLOOR_DEFAULT) * 1.5:
                rule(f'chart.content[{c}.{kind}]', b[kind], n[kind], n[kind] >= 0.3 * b[kind], 'chart signal std >= 0.3 x baseline (no flat fill)')
        if 'cut' in b and 'cut' in n and not b['cls'].startswith(EAVE):
            rule(f'chart.alpha.cut[{c}]', b['cut'], n['cut'], n['cut'] <= b['cut'] + 0.02,
                 'solid chart: cut <= baseline + 0.02 (eave charts: eave.gate.chart)')
    # eave silhouette
    be, ne = base.get('eave', {}), new.get('eave', {})
    bf, nf = be.get('FRONT'), ne.get('FRONT')
    if bf:
        nf = nf or dict(scallops_per_m=0.0, amplitude_m=0.0, rms_m=0.0, cut_visible=0.0)
        if bf['scallops_per_m'] >= 0.5:
            rule('eave.FRONT.scallops_per_m', bf['scallops_per_m'], nf['scallops_per_m'],
                 0.6 * bf['scallops_per_m'] <= nf['scallops_per_m'] <= 1.67 * bf['scallops_per_m'],
                 f'silhouette minima >= {SCALLOP_PROM * 1000:.0f} mm deep per metre within 0.6-1.67 x baseline')
        if bf['amplitude_m'] >= 0.005:
            rule('eave.FRONT.amplitude_m', bf['amplitude_m'], nf['amplitude_m'], nf['amplitude_m'] >= 0.6 * bf['amplitude_m'],
                 'band-passed silhouette p95 - p5 >= 0.6 x baseline')
        if bf.get('rms_m', 0) >= 0.002:
            rule('eave.FRONT.rms_m', bf['rms_m'], nf.get('rms_m', 0.0), nf.get('rms_m', 0.0) >= 0.6 * bf['rms_m'],
                 'band-passed silhouette rms >= 0.6 x baseline')
    if be.get('back_agreement') is not None:
        na = ne.get('back_agreement')
        rule('eave.back_agreement', be['back_agreement'], na, na is not None and na >= be['back_agreement'] - 0.10,
             'BACK cut behind the FRONT cut >= baseline - 0.10 (None = the FRONT is no longer cut)')
    bg, ng = be.get('gate') or {}, ne.get('gate') or {}
    if bg.get('verdict') == 'PASS':
        rule('eave.gate.verdict', 'PASS', ng.get('verdict'), ng.get('verdict') == 'PASS',
             'qa_detectors.eave_alpha_check passed in the baseline: ' + '; '.join(ng.get('reasons', [])[:3]))
    for role, b in (bg.get('per_role') or {}).items():
        n = (ng.get('per_role') or {}).get(role, {})
        if 'mismatch' in b:
            rule(f'eave.gate.mismatch[{role}]', b['mismatch'], n.get('mismatch'), n.get('mismatch', 1.0) <= b['mismatch'] + 0.05,
                 'opaque behind a cut FRONT <= baseline + 0.05')
        if 'hanging_cut' in b:
            rule(f'eave.gate.hanging_cut[{role}]', b['hanging_cut'], n.get('hanging_cut'), n.get('hanging_cut', 0.0) >= b['hanging_cut'] - 0.10,
                 'UNDER part hanging below the FRONT cut >= baseline - 0.10')
        if 'edge_median_texels' in b and _same_layout(base, new):
            rule(f'eave.gate.edge[{role}]', b['edge_median_texels'], n.get('edge_median_texels'),
                 n.get('edge_median_texels', 99.0) <= max(1.5 * b['edge_median_texels'], b['edge_median_texels'] + 0.5),
                 'alpha edge to baked outline (texels) <= max(1.5 x, +0.5) baseline')
    if _same_layout(base, new):
        for c, b in (bg.get('charts') or {}).items():
            n = (ng.get('charts') or {}).get(c)
            if b.get('verdict') == 'PASS' and n is not None and n.get('verdict') != 'PASS':
                rule(f'eave.gate.chart[{c}]', 'PASS', n.get('verdict'), False, 'eave_alpha_check chart passed in the baseline')
        for k in ('disc_alpha', 'roll_disc'):
            bx, nx = be.get(k), ne.get(k)
            if bx and bx['corr'] >= 0.3:
                rule(f'eave.phase.{k}', bx['lag_m'], None if not nx else nx['lag_m'],
                     bool(nx) and abs(nx['lag_m'] - bx['lag_m']) <= 0.025, '|lag - baseline| <= 2.5 cm')
    for pg, n in new.get('export', {}).items():            # absolute: an export must carry its state's alpha
        if n.get('all') is not None:
            b = base.get('export', {}).get(pg, {})
            worst = min(x for x in (n['all'], n.get('eave')) if x is not None)
            rule(f'export.alpha[{pg}]', b.get('all'), n['all'], worst >= 0.98,
                 f'exported alpha == page Opacity on >= 98 % of owner texels (eave {n.get("eave")}) - {Path(n["file"]).name}')
    _element_rules(base, new, rule, skip, scope)          # named elements a baseline protects (added)
    fails = [r for r in rows if r['verdict'] == 'FAIL']
    return dict(verdict='FAIL' if fails else 'PASS', base=base.get('name'), new=new.get('name'), only=only,
                same_layout=same, layout_overlap=_overlap(base, new),
                checked=sum(r['verdict'] != 'SKIP' for r in rows), failed=len(fails),
                waived=sum(r['verdict'] == 'WAIVED' for r in rows), skipped=sum(r['verdict'] == 'SKIP' for r in rows),
                fails=fails, rows=rows)


def _face_keys(fp):
    return fp.get('face_keys') or [k for c in fp['classes'].values() for k in c.get('registration', {}).get('keys', [])]


def _overlap(a, b):
    A, B = a.get('charts', {}), b.get('charts', {})
    tot = sum(c['texels'] for c in A.values())
    same = sum(c['texels'] for k, c in A.items() if k in B and B[k]['hash'] == c['hash'])
    return round(same / tot, 4) if tot else 0.0


def _same_layout(a, b):
    return _overlap(a, b) >= 0.9


# ------------------------------------------------------------------------------------------------ plan from geometry
def plan_from_geometry(geo_path, page, size, materials, vertical_as=None):
    """a UV-less state (e.g. the v15 roof atlas) as a plan: one face per dumped face (key object:index), class from
    the material name, charts = UV-connected islands, every face an owner."""
    F = json.load(open(geo_path, encoding='utf-8-sig'))
    objs = F['objects'] if isinstance(F.get('objects'), dict) and 'summary' in F else F
    plan = {}
    for ob, d in objs.items():
        fl = [f for f in d['faces'] if f.get('uv')]
        par = {}

        def root(x):
            while par.setdefault(x, x) != x:
                par[x] = par[par[x]]; x = par[x]
            return x
        for f in fl:
            ks = [(round(u, 5), round(v, 5)) for u, v in f['uv']]
            for k in ks[1:]:
                par[root(k)] = root(ks[0])
        for f in fl:
            cls = next((c for s, c in materials.items() if s in f.get('mat', '')), None)
            if cls is None:
                continue
            if vertical_as and cls in vertical_as and abs(f['n'][2]) <= 0.2:
                cls = vertical_as[cls]
            isl = root((round(f['uv'][0][0], 5), round(f['uv'][0][1], 5)))
            plan[f'{ob}:{f["i"]}'] = dict(page=page, uv=f['uv'], family=f'{ob}:island_{isl[0]:.4f}_{isl[1]:.4f}',
                                          family_size=1, owner=True, material=cls)
    return dict(faces=plan, report=dict(source=str(geo_path), page=page, size=size, faces=len(plan),
                                        materials=dict(Counter(x['material'] for x in plan.values()))))


# ------------------------------------------------------------------------------------------------ Blender dump
def _blender_dump(job_path):   # runs INSIDE background Blender
    import bpy
    job = json.load(open(job_path, encoding='utf-8-sig'))
    subs = job.get('materials') or []; uvname = job.get('uv')
    out, summary = {}, {}
    for ob in bpy.data.objects:
        if ob.type != 'MESH':
            continue
        me = ob.data; mats = [s.material.name if s.material else '' for s in ob.material_slots]
        summary[ob.name] = dict(mats=mats, faces=len(me.polygons), uv_layers=[u.name for u in me.uv_layers])
        idx = [i for i, m in enumerate(mats) if any(s in m for s in subs)] if subs else list(range(max(len(mats), 1)))
        if not idx:
            continue
        uvl = me.uv_layers.get(uvname) if uvname else me.uv_layers.active
        M = ob.matrix_world; Nm = M.to_3x3().inverted().transposed(); faces = []
        for p in me.polygons:
            if mats and p.material_index not in idx:
                continue
            faces.append(dict(i=p.index, mat=mats[p.material_index] if mats else '', n=list((Nm @ p.normal).normalized()),
                              v=[list(M @ me.vertices[k].co) for k in p.vertices], c=list(M @ p.center),
                              uv=[list(uvl.data[li].uv) for li in p.loop_indices] if uvl else None))
        out[ob.name] = dict(faces=faces, uv_layer=uvl.name if uvl else None)
    json.dump(dict(objects=out, summary=summary, blend=bpy.data.filepath), open(job['out'], 'w'))
    print('DUMPED', {k: len(v['faces']) for k, v in out.items()})


def dump_low(blend, uv_layer, materials, out_json):
    """background Blender face dump of LOW (through the machine gate: exit 0 = go)."""
    gate = os.environ.get('STATE_REG_GATE')
    if gate:
        r = subprocess.run([sys.executable, gate, '--timeout', '540'])
        if r.returncode != 0:
            raise RuntimeError('blender_gate did not give GO - call again later, never bypass')
    blender = os.environ.get('STATE_REG_BLENDER', 'C:/Program Files/Blender Foundation/Blender 5.0/blender.exe')
    with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False) as f:
        json.dump(dict(uv=uv_layer, materials=materials, out=str(out_json)), f); job = f.name
    r = subprocess.run([blender, '-b', str(blend), '--factory-startup', '--python-exit-code', '1', '--python',
                        str(Path(__file__).resolve()), '--', '--dump-geometry', job], capture_output=True, text=True)
    os.unlink(job)
    if not Path(out_json).exists():
        raise RuntimeError(f'dump failed: {r.stdout[-600:]} {r.stderr[-600:]}')
    return out_json


# ------------------------------------------------------------------------------------------------ CLI
def print_report(rep):
    print(f'STATE REGRESSION {rep["verdict"]}: {rep["new"]} vs {rep["base"]} (layout overlap {rep["layout_overlap"]}, '
          f'{rep["checked"]} checks, {rep["failed"]} failed, {rep["waived"]} waived, {rep["skipped"]} skipped'
          + (f', only {rep["only"]}' if rep.get('only') else '') + ')')
    shown = [r for r in rep['rows'] if r['verdict'] != 'PASS']
    for r in shown[:40]:
        print(f'  {r["verdict"]:6} {r["id"]}: baseline {r["base"]} -> new {r["new"]}  ({r["rule"]})')
    if len(shown) > 40:
        print(f'  ... {len(shown) - 40} more (write the report with -o)')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    f = sub.add_parser('fingerprint')
    f.add_argument('state_dir'); f.add_argument('--plan', required=True); f.add_argument('--geometry')
    f.add_argument('--sources', action='append', help='Obj=Prefix,... (plan key prefix per dumped object)')
    f.add_argument('--low', help='low-poly .blend: dump its faces (background Blender, gated) as the geometry')
    f.add_argument('--uv-layer', default='UV_Final'); f.add_argument('--low-materials', default='')
    f.add_argument('--map', action='append', help='PAGE_Kind=path (or =none) overrides STATE_DIR/<page>_<Kind>.png')
    f.add_argument('--page', action='append', help='PAGE=SIZE (default: from the maps)')
    f.add_argument('--export'); f.add_argument('--export-alias', action='append', default=['P2048=mata,P1024=matb'])
    f.add_argument('--name'); f.add_argument('-o', '--out', required=True)
    f.add_argument('--elements', help='JSON {palette, elements: {name: {faces: [plan keys], protect}}}: per-element colour '
                   'fingerprints (Korean TC: state/elements_resolved.json, state.py elements --write)')
    f.add_argument('--protect', default='', help='comma list of element names this fingerprint protects as a baseline')
    c = sub.add_parser('compare')
    c.add_argument('base'); c.add_argument('new'); c.add_argument('--waivers'); c.add_argument('-o', '--out')
    c.add_argument('--only', help='comma-separated property id patterns, e.g. "alpha.*,eave.*"')
    c.add_argument('--scope', help='comma-separated element names of the declared change (their element rules are skipped)')
    p = sub.add_parser('plan-from-geometry')
    p.add_argument('geometry'); p.add_argument('--page', required=True, help='NAME=SIZE')
    p.add_argument('--material', action='append', required=True, help='SUBSTR=CLASS')
    p.add_argument('--vertical-as', action='append', help='FROM=TO: faces of FROM with |n.z| <= 0.2 become TO')
    p.add_argument('--out-plan', required=True)
    a = ap.parse_args(argv)
    if a.cmd == 'fingerprint':
        geometry = a.geometry
        if a.low:
            geometry = str(Path(a.out).with_suffix('.geometry.json'))
            if not Path(geometry).exists() or Path(geometry).stat().st_mtime < Path(a.low).stat().st_mtime:
                dump_low(a.low, a.uv_layer, [m for m in a.low_materials.split(',') if m], geometry)
        st, src = build_state(a.state_dir, a.plan, geometry, parse_pairs(a.sources) or None, parse_pairs(a.map),
                              {k: int(v) for k, v in parse_pairs(a.page).items()} or None)
        name = a.name or Path(a.out).name.replace('.fp.json', '')
        fp = fingerprint(st, name, src)
        if a.elements:
            fp['elements'] = element_metrics(st, json.load(open(a.elements, encoding='utf-8-sig')),
                                             [x for x in a.protect.split(',') if x])
            fp['sources']['elements'] = dict(path=str(a.elements), sha256=sha256(a.elements))
        if a.export:
            fp['export'] = export_agreement(st, a.export, parse_pairs(a.export_alias))
        Path(a.out).write_text(json.dumps(fp, indent=1, default=float))
        e = fp['eave'].get('FRONT') or {}
        print(f'FINGERPRINT {name}: {len(fp["classes"])} classes, {len(fp["charts"])} charts, eave FRONT {e}, '
              f'back_agreement {fp["eave"].get("back_agreement")}, {fp["seconds"]} s -> {a.out}')
        return 0
    if a.cmd == 'compare':
        base = json.load(open(a.base, encoding='utf-8')); new = json.load(open(a.new, encoding='utf-8'))
        W = json.load(open(a.waivers, encoding='utf-8-sig')) if a.waivers else None
        rep = compare(base, new, W, [o for o in (a.only or '').split(',') if o] or None,
                      [s for s in (a.scope or '').split(',') if s] or None)
        print_report(rep)
        if a.out:
            Path(a.out).write_text(json.dumps(rep, indent=1, default=float))
        return 3 if rep['verdict'] == 'FAIL' else 0
    if a.cmd == 'plan-from-geometry':
        pg, size = a.page.split('=')
        plan = plan_from_geometry(a.geometry, pg, int(size), parse_pairs(a.material), parse_pairs(a.vertical_as))
        Path(a.out_plan).write_text(json.dumps(plan))
        print('PLAN', plan['report'])
        return 0


if __name__ == '__main__':
    if '--dump-geometry' in sys.argv:
        _blender_dump(sys.argv[sys.argv.index('--dump-geometry') + 1])
    else:
        sys.exit(main())
