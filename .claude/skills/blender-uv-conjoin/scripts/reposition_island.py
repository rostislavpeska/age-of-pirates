"""Quick UV reposition - "the texture does not sit": move a few faces' UV islands onto texels that ALREADY hold the
right content, with no new texels and no bake. Each face becomes a MEMBER of a congruent owner of the right class and
role (corner for corner, or an exact 1:1 window inside a larger owner), or - when no owner passes - moves onto free
texels whose baked class is right. Generalises the Korean TC fixes S18i (12 eave faces, corner for corner), S18j (a sill
face, exact containment) and S18k (12 wooden frames the plan carried as plaster).

  python reposition_island.py plan    --config cfg.json --faces KEY,KEY --version S18k --out DIR
                                      [--target-family FAMILY | --target-owner KEY] [--target-class WOOD] [--allow-free]
                                      [--accept-ao] [--pin FACE=OWNER,..]      (apply/low/run: [--gated])
  python reposition_island.py apply   --config cfg.json --out DIR    background Blender: base factory blend -> new file
  python reposition_island.py low     --config cfg.json --out DIR    background Blender: base texturing LOW -> new LOW + freeze
  python reposition_island.py verify  --config cfg.json --out DIR    host: saved blends vs plan, fingerprint chain
  python reposition_island.py handoff --config cfg.json --out DIR    HANDOFF.json (blender-architecture-texturing handoff.py;
                                                                     DIR/handoff_extra.json adds pictures, regression, issues)
  python reposition_island.py run     (plan .. handoff in one go; same flags as plan)
Every Blender launch runs cfg["gate"] first (e.g. the machine memory gate) and launches only on its exit 0; --gated
says the caller ran the gate itself right before.

plan (host Python, numpy + shapely + PIL):
  candidates  every owner on the face's page whose class is the face's class (--target-class, else cfg expected[key],
              else the plan material; cfg equivalent groups count as one class) and whose texels pass class + plain
  registrations (proper rotations only: det +1, normal onto normal, up onto up for vertical faces, never mirrored)
    corner    same vertex count, sides within 12 %: member UV = the owner's UV at the corresponding corners; density
              per axis = owner side / member side
    contain   any polygons: a 1:1 window inside a larger owner at the owner's density (owner short side at most
              (1 + cfg contain_slack, 0.5) x the member's), slid for the best AO, ties to the owner's bottom edge
  gates       geometry, density per axis 1 +- density_tol (0.03), same UV handedness, class (owner texels >= 95 % of the
              class in the ClassID map), plain (owner texels identical in every decorated/base map pair: no decor paint
              is inherited), AO point to point (S14 samples: p95 |dAO| <= 0.08, max <= 0.20), inside the owner footprint
  choice      --target-owner / --target-family / --pin restrict; corner before contain, then AO p95, then density;
              --accept-ao takes the best AO among registrations failing ONLY the AO gate (reported: ao_gate_waived,
              an owner decision) and final_ao_read (cfg final_ao) says what the move does to the baked AO the face reads
  free        (--allow-free) no owner passes: the face keeps its own UV shape and density and moves onto texels no plan
              face uses whose ClassID is the class (and plain); it becomes the owner of a new family
  book-keeping  the moved face takes the owner's family and material (owner false); a moved OWNER whose texels other
              members still read hands the ownership to the member that covers its footprint (same handedness), else
              the plan stops; family_size keeps each family's convention (charts or faces, cfg charts map)
  gates after the build  UV changes only on the moved faces; no new cross-family overlap; role registration
              (qa_detectors.uv_registration_check, default + directional classes): no new or changed flag anywhere and
              every moved face registered (share >= 0.9); class_mismatch (qa_detectors): every moved face clean, no new flag
  writes      plan_final_pages_<ver>.json (same schema + report.<ver>_fix), candidates_<ver>.json, fix_report.json,
              detector_<ver>.json, live_patch_<ver>.json ({object_hint, uv_layer, faces {i: {from, to}}}; cfg
              live_patch_chain: earlier patches of the same batch -> "from" is the state the live scene still has)
Rules: one batched UV switch per checkpoint (build the next version on the last unswitched one and chain its live patch);
never overwrite a file (every output path must be new); the base files are only read.

Config (JSON; paths absolute or relative to the config file):
  base_version, base_plan, geometry (ridge_faces-style dump {obj: {faces: [{i, v, n}]}}), sources {obj: key prefix},
  pages {P2048: 2048}, classes [..], classmap {path ".../{page}_ClassID.png", palette {CLASS: [r,g,b] sRGB 0-1} | scale},
  equivalent [[..]], expected (path | {key: CLASS}), ao_samples (S14 ao_samples_v2.json), charts (final_faces.json),
  plain_pairs [[decorated_dir, base_dir], ..], plain_kinds, directional [WOOD], density_tol, uv_layer, view_prefix,
  follow_owner_slot [view object prefixes whose slot = family colour], factory_blend, factory_out, low_blend, low_out,
  base_freeze, freeze_out, page_objects, live_patch_chain [..], blender, gate [argv], handoff {model, phase, producer,
  inputs [..], why}. Templates {version} and {out} are filled in.
Specimen proof: test_reposition_island.py (pytest, no Blender).
"""
import argparse
import copy
import hashlib
import json
import os
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SKILLS = HERE.parent.parent
QA = SKILLS / 'blender-high-low-baking' / 'scripts'
HANDOFF_PY = SKILLS / 'blender-architecture-texturing' / 'scripts' / 'handoff.py'
Z = np.array([0.0, 0.0, 1.0])
AO_P95, AO_MAX = 0.08, 0.20


def _qa():
    sys.path.insert(0, str(QA))
    import qa_detectors
    return qa_detectors


# ----------------------------------------------------------------------------------------------- config
PATH_KEYS = ('base_plan', 'geometry', 'expected', 'ao_samples', 'charts', 'final_ao', 'factory_blend', 'factory_out', 'low_blend',
             'low_out', 'base_freeze', 'freeze_out', 'plain_pairs', 'live_patch_chain', 'classmap', 'inputs')


def load_config(path, version=None, out=None):
    """paths (PATH_KEYS, classmap.path, handoff.inputs) resolve against the config's folder; {version} and {out} fill"""
    path = Path(path); cfg = json.loads(path.read_text(encoding='utf-8-sig')); root = path.parent

    def fill(v, is_path):
        if isinstance(v, str):
            v = v.replace('{version}', version or '{version}').replace('{out}', str(out) if out else '{out}')
            return str((root / v).resolve()) if is_path and not os.path.isabs(v) and not v.startswith('{') else v
        if isinstance(v, list):
            return [fill(x, is_path) for x in v]
        if isinstance(v, dict):                 # inside a dict only its "path" entry is a path (classmap)
            return {k: (fill(x, k == 'path') if k != 'palette' else x) for k, x in v.items()}
        return v
    cfg = {k: fill(v, k in PATH_KEYS) if k not in ('gate', 'blender', 'handoff') else v for k, v in cfg.items()}
    if 'handoff' in cfg:
        cfg['handoff'] = dict(cfg['handoff'], inputs=fill(cfg['handoff'].get('inputs', []), True))
    cfg.setdefault('density_tol', 0.03); cfg.setdefault('uv_layer', 'UV_Final'); cfg.setdefault('directional', [])
    cfg.setdefault('equivalent', []); cfg.setdefault('plain_kinds', ['BaseColor', 'Masks', 'Roughness', 'Normal'])
    return cfg


def load_json(p):
    return json.loads(Path(p).read_text(encoding='utf-8-sig'))


def sha256(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


# ----------------------------------------------------------------------------------------------- geometry
def newell(P):
    P = np.asarray(P, float); n = np.cross(P, np.roll(P, -1, 0)).sum(0); L = np.linalg.norm(n)
    return n / L if L > 1e-12 else n


def procrustes(A, B):
    """similarity s, R, t with s R A + t ~ B (Kabsch, proper rotation)"""
    ca, cb = A.mean(0), B.mean(0); A0, B0 = A - ca, B - cb
    U, Sg, Vt = np.linalg.svd(B0.T @ A0); D = np.diag([1, 1, np.sign(np.linalg.det(U @ Vt))])
    R = U @ D @ Vt; s = np.trace(np.diag(Sg) @ D) / max((A0 ** 2).sum(), 1e-12); t = cb - s * R @ ca
    return s, R, t


def uv_jac(P, uv, size):
    """2x2 map face-plane metres (own normal frame) -> texels, and its sign (UV handedness)"""
    P = np.asarray(P, float); Qp = np.asarray(uv, float) * size; n = newell(P)
    e1 = P[1] - P[0]; e1 = e1 - n * (e1 @ n); e1 /= max(np.linalg.norm(e1), 1e-12); e2 = np.cross(n, e1)
    L = np.c_[(P - P[0]) @ e1, (P - P[0]) @ e2]; X, *_ = np.linalg.lstsq(L, Qp - Qp[0], rcond=None)
    J = X.T; return J, int(np.sign(np.linalg.det(J)))


def edges(P):
    P = np.asarray(P, float); return np.linalg.norm(np.roll(P, -1, 0) - P, axis=1)


def poly_px(uv, size):
    return [(u * size, (1 - v) * size) for u, v in uv]


def texel_rc(uv, size):
    return _qa()._poly_texels(uv, size)


def shp(uv, size):
    from shapely.geometry import Polygon
    p = Polygon(poly_px(uv, size)); return p if p.is_valid else p.buffer(0)


# ----------------------------------------------------------------------------------------------- data
class Data:
    def __init__(self, cfg, plan=None):
        Q = _qa(); self.cfg = cfg; self._target_cls = {}
        self.plan = plan if plan is not None else load_json(cfg['base_plan'])['faces']
        self.geo = cfg['_geo'] if '_geo' in cfg else Q.load_geometry(cfg['geometry'], cfg['sources'])
        self.pages = cfg['pages']; self.classes = cfg['classes']
        eq = {c: {c} for c in self.classes}
        for g in cfg['equivalent']:
            for c in g:
                eq.setdefault(c, {c}).update(g)
        self.eq = eq
        exp = cfg.get('expected') or {}
        self.expected = load_json(exp) if isinstance(exp, str) else exp
        self.classmap = {}
        for pg in self.pages:
            if '_classmap' in cfg:
                self.classmap[pg] = cfg['_classmap'][pg]
            elif cfg.get('classmap'):
                spec = dict(cfg['classmap'], path=cfg['classmap']['path'].format(page=pg))
                self.classmap[pg] = Q.read_palette_classmap(spec, self.classes) if 'palette' in spec else Q.read_classmap(spec)
        self.ao = {}
        if cfg.get('_ao') is not None:
            self.ao = cfg['_ao']
        elif cfg.get('ao_samples'):
            self.ao = {r['face']: r['samples'] for r in load_json(cfg['ao_samples'])['faces']}
        self.painted = cfg.get('_painted')    # {page: bool HxW}: texels a decorated map changed against its base
        if self.painted is None and cfg.get('plain_pairs'):
            self.painted = {}
            for pg in self.pages:
                for dec, base in cfg['plain_pairs']:
                    for k in cfg['plain_kinds']:
                        a, b = Path(dec) / f'{pg}_{k}.png', Path(base) / f'{pg}_{k}.png'
                        if a.exists() and b.exists():
                            d = np.abs(Q.read_map(a)[..., :3] - Q.read_map(b)[..., :3]).max(-1) > 3 / 255
                            self.painted[pg] = d if pg not in self.painted else self.painted[pg] | d
        self.final_ao = cfg.get('_final_ao') or {}                  # {page: HxW} the baked AO the members will read
        if not self.final_ao and cfg.get('final_ao'):
            for pg in self.pages:
                f = Path(cfg['final_ao'].format(page=pg))
                if f.exists():
                    a = Q.read_map(f); self.final_ao[pg] = a[..., 0]
        ch = cfg.get('_charts') if '_charts' in cfg else (load_json(cfg['charts']) if cfg.get('charts') else None)
        self.charts = ({r['id']: r['chart'] for r in ch} if isinstance(ch, list) else ch) or None

    def V(self, k):
        return np.asarray(self.geo[k]['v'], float)

    def N(self, k):
        n = np.asarray(self.geo[k].get('n') or newell(self.V(k)), float); return n / np.linalg.norm(n)

    def cls_of(self, k):
        return self.expected.get(k) or self.plan[k]['material']

    def class_share(self, uv, page, cls):
        cm = self.classmap.get(page)
        if cm is None:
            return None
        r, c = texel_rc(uv, self.pages[page]); v = cm[r, c]
        want = [self.classes.index(x) for x in self.eq.get(cls, {cls}) if x in self.classes]
        return float(np.isin(v, want).mean()) if len(v) else 0.0

    def plain_ok(self, uv, page):
        """no decor paint inherited: none of the footprint's texels changed in any decorated/base pair"""
        if not self.painted or page not in self.painted:
            return None, {}
        r, c = texel_rc(uv, self.pages[page]); n = int(self.painted[page][r, c].sum())
        return n == 0, dict(painted_texels=n, texels=len(r))

    def ao_points(self, k, verts=None):
        s = self.ao.get(k)
        if not s:
            return None, None
        P = self.V(k) if verts is None else verts
        return (np.array([sum(w * P[c] for c, w in zip(cs, ws)) for cs, ws, *_ in s]), np.array([x[-1] for x in s], float))


# ----------------------------------------------------------------------------------------------- registration
def ao_compare(D, m, o, mapped_pts):
    pm, am = D.ao_points(m); po, ao_ = D.ao_points(o)
    if pm is None or po is None:
        return None
    q = mapped_pts(pm); d = np.linalg.norm(q[:, None] - po[None], axis=-1); j = d.argmin(1); dd = np.abs(am - ao_[j])
    return dict(n=len(am), member_mean=round(float(am.mean()), 3), owner_mean=round(float(ao_[j].mean()), 3),
                p95=round(float(np.percentile(dd, 95)), 3), max=round(float(dd.max()), 3),
                ok=bool(np.percentile(dd, 95) <= AO_P95 and dd.max() <= AO_MAX))


def final_ao_read(D, m, uv_new):
    """the baked AO map (cfg final_ao) the face reads at its own surface points (its S14 AO sample barycentrics, else
    its corners and centre) through its old UV and through uv_new: what the move does to its shading"""
    pg = D.plan[m]['page']; A = D.final_ao.get(pg)
    if A is None:
        return None
    S = A.shape[0]; uo, un = np.asarray(D.plan[m]['uv'], float), np.asarray(uv_new, float); s = D.ao.get(m)
    W = [(cs, ws) for cs, ws, *_ in s] if s else [([i], [1.0]) for i in range(len(uo))] + [(list(range(len(uo))), [1 / len(uo)] * len(uo))]

    def samp(U):
        q = np.array([sum(w * U[c] for c, w in zip(cs, ws)) for cs, ws in W]); x = np.clip(q[:, 0] * S - 0.5, 0, S - 1.001)
        y = np.clip((1 - q[:, 1]) * S - 0.5, 0, S - 1.001); x0, y0 = x.astype(int), y.astype(int); fx, fy = x - x0, y - y0
        return (A[y0, x0] * (1 - fx) * (1 - fy) + A[y0, x0 + 1] * fx * (1 - fy) + A[y0 + 1, x0] * (1 - fx) * fy + A[y0 + 1, x0 + 1] * fx * fy)
    a, b = samp(uo), samp(un); d = np.abs(a - b)
    return dict(old_mean=round(float(a.mean()), 3), new_mean=round(float(b.mean()), 3), mean_abs=round(float(d.mean()), 3),
                p95=round(float(np.percentile(d, 95)), 3), max=round(float(d.max()), 3), n=len(d))


def inside_fraction(uv, owner_uv, size, tol_px=0.05):
    """share of a UV polygon inside the owner's (the owner outline widened by tol_px texels: a 1:1 window that
    touches the owner's edge must not fail on float noise)"""
    a = shp(uv, size); return round(a.intersection(shp(owner_uv, size).buffer(tol_px)).area / max(a.area, 1e-9), 5)


def owner_gates(D, o, cls):
    """owner-level gates, cached: its texels hold the class (ClassID >= 95 %) and carry no decor paint (plain pairs)"""
    key = (o, cls); cache = D.__dict__.setdefault('_og', {})
    if key not in cache:
        page = D.plan[o]['page']; rec = dict(gates={})
        cs = D.class_share(D.plan[o]['uv'], page, cls)
        if cs is not None:
            rec['owner_class_share'] = round(cs, 4); rec['gates']['class'] = cs >= 0.95
        pok, worst = D.plain_ok(D.plan[o]['uv'], page)
        if pok is not None:
            rec['plain_max_diff'] = worst; rec['gates']['plain'] = pok
        cache[key] = rec
    return cache[key]


def rot_between(a, b):
    """proper rotation taking direction a onto direction b"""
    a = a / np.linalg.norm(a); b = b / np.linalg.norm(b); v = np.cross(a, b); c = float(a @ b)
    if np.linalg.norm(v) < 1e-9:
        if c > 0:
            return np.eye(3)
        p = np.cross(a, [1.0, 0, 0] if abs(a[0]) < 0.9 else [0, 1.0, 0]); p /= np.linalg.norm(p)
        return 2 * np.outer(p, p) - np.eye(3)
    K = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + K + K @ K / (1 + c)


def plane_axes(P, n):
    """in-plane axes of a face: a1 = its longest edge direction, a2 = n x a1"""
    e = np.roll(P, -1, 0) - P; a1 = e[np.argmax(np.linalg.norm(e, axis=1))]; a1 = a1 - n * (a1 @ n)
    a1 /= np.linalg.norm(a1); return a1, np.cross(n, a1)


def rot_about(k, ang):
    k = k / np.linalg.norm(k); K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + np.sin(ang) * K + (1 - np.cos(ang)) * K @ K


def contain_rotations(Pm, nm, Po, no):
    """proper rotations for the 1:1 window: normal onto normal and, for vertical / tilted faces, up onto up; flat faces
    align their long axes (both ways)"""
    if abs(nm[2]) < 0.2:                               # vertical: a rotation about z
        ang = np.arctan2(no[1], no[0]) - np.arctan2(nm[1], nm[0]); return [rot_about(Z, ang)]
    R1 = rot_between(nm, no)
    ang_to = lambda v, w: np.arctan2(np.cross(v, w) @ no, v @ w)  # noqa: E731
    if abs(nm[2]) < 0.98:                              # tilted: in-plane up onto in-plane up
        v = R1 @ (Z - nm * (Z @ nm)); return [rot_about(no, ang_to(v, Z - no * (Z @ no))) @ R1]
    v = R1 @ plane_axes(Pm, nm)[0]; ang = ang_to(v, plane_axes(Po, no)[0])
    return [rot_about(no, ang) @ R1, rot_about(no, ang + np.pi) @ R1]


def register(D, m, o, tol, prelim=0.12, slack=None):
    """every proper registration of member m onto owner o -> {frame, modes}; None when the shapes do not match.
    corner (same vertex count, sides within `prelim`): the owner's UV at the corresponding corners.
    contain (any polygons): a 1:1 window inside the owner (normal onto normal, up onto up), owner short side at most
    (1 + slack) x the member's, slid for the best AO."""
    Pm, Po = D.V(m), D.V(o); n = len(Pm); slack = D.cfg.get('contain_slack', 0.5) if slack is None else slack
    nm, no = D.N(m), D.N(o); vertical = abs(nm[2]) < 0.2; page = D.plan[o]['page']; S = D.pages[page]
    if nm @ no < 0.0 and abs(nm[2]) > 0.2:
        return None
    Juo, ho = uv_jac(Po, D.plan[o]['uv'], S); so = np.linalg.svd(Juo, compute_uv=False); modes = {}; fr = None
    if len(Po) == n and len(D.plan[o]['uv']) == n and np.all(np.abs(np.sort(edges(Po)) / np.maximum(np.sort(edges(Pm)), 1e-9) - 1) <= prelim):
        best = None
        for sh in range(n):
            B = np.roll(Po, -sh, 0); s, R, t = procrustes(Pm, B)
            rec = dict(sh=sh, det=float(np.linalg.det(R)), normal_map=float((R @ nm) @ no), up_map=float((R @ Z) @ Z),
                       resid=float(np.linalg.norm(s * (R @ Pm.T).T + t - B, axis=1).max()),
                       ratios=(edges(B) / np.maximum(edges(Pm), 1e-9)).tolist())
            rec['geometry'] = rec['det'] > 0.999 and rec['normal_map'] > 0.99 and (rec['up_map'] > 0.99 or not vertical)
            key = (not rec['geometry'], max(abs(r - 1) for r in rec['ratios']))
            if best is None or key < best[0]:
                best = (key, rec)
        fr = best[1]
        if fr['geometry']:
            sh = fr['sh']; B = np.roll(Po, -sh, 0)
            uvc = [list(D.plan[o]['uv'][(sh + j) % n]) for j in range(n)]; r = np.array(fr['ratios'])
            dens = [float((r[0] + r[2]) / 2), float((r[1] + r[3]) / 2)] if n == 4 else [float(r.min()), float(r.max())]
            Jm, hm = uv_jac(Pm, uvc, S); sm = np.linalg.svd(Jm, compute_uv=False)
            X, *_ = np.linalg.lstsq(np.c_[Pm, np.ones(n)], B, rcond=None)
            modes['corner'] = dict(uv_new=uvc, density_ratio_per_axis=[round(x, 4) for x in dens],
                                   anisotropy=round(float(sm[0] / sm[1]), 4), owner_anisotropy=round(float(so[0] / so[1]), 4),
                                   handedness=hm, owner_handedness=ho, inside_owner_footprint=1.0, offset_m=[0.0, 0.0],
                                   ao=ao_compare(D, m, o, lambda p: np.c_[p, np.ones(len(p))] @ X))
    # contain: the member polygon, rotated into the owner's plane, slid inside the owner polygon at 1:1
    from shapely.affinity import translate
    from shapely.geometry import Polygon
    oc = Po.mean(0); a1, a2 = plane_axes(Po, no); op = Polygon(np.c_[(Po - oc) @ a1, (Po - oc) @ a2]).buffer(1e-4)
    cm = Pm.mean(0); ext = lambda q: np.ptp(q, 0)  # noqa: E731
    best = None; o2 = np.c_[(Po - oc) @ a1, (Po - oc) @ a2]; pm_ao, am = D.ao_points(m); po_ao, ao_o = D.ao_points(o)
    for R in contain_rotations(Pm, nm, Po, no):
        if (R @ nm) @ no < 0.99:
            continue
        Pr = (R @ (Pm - cm).T).T; q2 = np.c_[Pr @ a1, Pr @ a2]; me_, oe = ext(q2), ext(o2)
        if np.any(me_ > oe + 1e-4) or min(oe) > (1 + slack) * min(me_) + 1e-3 or np.allclose(me_, oe, atol=1e-4) and 'corner' in modes:
            continue
        mp0 = Polygon(q2); lo = o2.min(0) - q2.min(0); hi = o2.max(0) - q2.max(0)
        T = np.array([(tx, ty) for tx in np.linspace(lo[0], hi[0], 21 if hi[0] - lo[0] > 1e-4 else 1)
                      for ty in np.linspace(lo[1], hi[1], 12 if hi[1] - lo[1] > 1e-4 else 1)
                      if op.contains(translate(mp0, tx, ty))])
        if not len(T):
            continue
        zmin = (oc[2] + (q2[:, 0][None] + T[:, :1]) * a1[2] + (q2[:, 1][None] + T[:, 1:]) * a2[2]).min(1)
        zb = np.abs(zmin - Po[:, 2].min())                    # ties: the window sitting on the owner's bottom edge
        if pm_ao is not None and po_ao is not None:          # AO point to point for every position at once
            r_ = (R @ (pm_ao - cm).T).T; qa = np.c_[r_ @ a1, r_ @ a2]; pa = np.c_[(po_ao - oc) @ a1, (po_ao - oc) @ a2]
            p95, mx = np.empty(len(T)), np.empty(len(T))
            for i0 in range(0, len(T), 16):
                t = T[i0:i0 + 16]; d = ((qa[None, :, None] + t[:, None, None] - pa[None, None]) ** 2).sum(-1)
                dd = np.abs(am[None] - ao_o[d.argmin(2)]); p95[i0:i0 + 16] = np.percentile(dd, 95, axis=1); mx[i0:i0 + 16] = dd.max(1)
        else:
            p95 = mx = np.zeros(len(T))
        i = min(range(len(T)), key=lambda i: (round(p95[i], 3), round(mx[i], 3), round(zb[i], 4), round(T[i, 0], 4), round(T[i, 1], 4)))
        key = (round(p95[i], 3), round(mx[i], 3), round(zb[i], 4))
        if best is None or key < best[0]:
            tx, ty = T[i]
            mp = lambda p, R=R, tx=tx, ty=ty: oc + np.outer(((R @ (p - cm).T).T @ a1) + tx, a1) + np.outer(((R @ (p - cm).T).T @ a2) + ty, a2)  # noqa: E731
            best = (key, ao_compare(D, m, o, mp), mp, tx, ty)
    if best:
        _, a, mp, tx, ty = best
        Xo, *_ = np.linalg.lstsq(np.c_[Po, np.ones(len(Po))], np.asarray(D.plan[o]['uv'], float), rcond=None)
        uvw = (np.c_[mp(Pm), np.ones(n)] @ Xo).tolist(); Jw, hw = uv_jac(Pm, uvw, S); sw = np.linalg.svd(Jw, compute_uv=False)
        modes['contain'] = dict(uv_new=uvw, density_ratio_per_axis=[round(float(sw[0] / so[0]), 4), round(float(sw[1] / so[1]), 4)],
                                anisotropy=round(float(sw[0] / sw[1]), 4), owner_anisotropy=round(float(so[0] / so[1]), 4),
                                handedness=hw, owner_handedness=ho, offset_m=[round(float(tx), 4), round(float(ty), 4)],
                                inside_owner_footprint=inside_fraction(uvw, D.plan[o]['uv'], S), ao=a)
    if not modes and fr is None:
        return None
    og = owner_gates(D, o, D._target_cls.get(m) or D.cls_of(m))
    for md in modes.values():
        g = dict(geometry=True, density=all(abs(x - 1) <= tol for x in md['density_ratio_per_axis']),
                 handedness=md['handedness'] == md['owner_handedness'], inside=md['inside_owner_footprint'] >= 0.999)
        md.update({k: v for k, v in og.items() if k != 'gates'}); g.update(og['gates'])
        if md['ao'] is not None:
            g['ao'] = md['ao']['ok']
        md['gates'] = g; md['verdict'] = 'PASS' if all(g.values()) else 'FAIL'
    return dict(frame=fr, modes=modes)


def free_texels(D, m, cls, page, gutter=2):
    """a position for m's own UV shape on texels no plan face uses whose class is cls (and plain) -> uv or None"""
    import cv2
    from PIL import Image, ImageDraw
    S = D.pages[page]; used = Image.new('L', (S, S), 0); dr = ImageDraw.Draw(used)
    for k, e in D.plan.items():
        if e['page'] == page and k != m:
            dr.polygon(poly_px(e['uv'], S), fill=255)
    used = cv2.dilate(np.asarray(used), np.ones((2 * gutter + 1,) * 2, np.uint8)) > 0
    cm = D.classmap[page]; want = [D.classes.index(x) for x in D.eq.get(cls, {cls}) if x in D.classes]
    ok = np.isin(cm, want) & ~used
    if D.painted and page in D.painted:
        ok &= ~D.painted[page]
    q = np.asarray(poly_px(D.plan[m]['uv'], S)); lo = np.floor(q.min(0)).astype(int) - gutter
    ker = Image.new('L', tuple((np.ceil(q.max(0)).astype(int) - lo + gutter + 1).tolist()), 0)
    ImageDraw.Draw(ker).polygon([tuple(p - lo) for p in q], fill=1)
    ker = np.asarray(ker, np.uint8)
    if ker.sum() == 0:
        return None
    # erode with anchor (0, 0): fit[y, x] = the kernel box placed with its top-left texel at (x, y) lies on allowed texels
    fit = cv2.erode(ok.astype(np.uint8), ker, anchor=(0, 0), borderType=cv2.BORDER_CONSTANT, borderValue=0) > 0
    ys, xs = np.nonzero(fit)
    if not len(ys):
        return None
    cur = lo; d = (ys - cur[1]) ** 2 + (xs - cur[0]) ** 2; i = int(d.argmin())       # the nearest fit to where it was
    shift = np.array([xs[i] - lo[0], ys[i] - lo[1]], float)
    return [[(x + shift[0]) / S, 1 - (y + shift[1]) / S] for x, y in q]


# ----------------------------------------------------------------------------------------------- plan
def choose(D, m, tol, target_family=None, target_owner=None, target_cls=None, moving=()):
    cls = target_cls or D.cls_of(m); page = D.plan[m]['page']; D._target_cls[m] = cls
    pool = [o for o, e in D.plan.items() if e['owner'] and e['page'] == page and o not in moving and o != m and o in D.geo
            and e['material'] in D.eq.get(cls, {cls})]
    if target_owner:
        pool = [o for o in pool if o == target_owner]
    if target_family:
        pool = [o for o in pool if D.plan[o]['family'] == target_family]
    n0 = len(pool); pool = [o for o in pool if all(owner_gates(D, o, cls)['gates'].values())]   # class + plain first
    D.__dict__.setdefault('_pool_stats', {})[m] = dict(owners_of_class=n0, class_and_plain=len(pool))
    cands = {}
    for o in pool:
        r = register(D, m, o, tol)
        if r is not None:
            cands[o] = r
    passing = sorted(((o, md) for o, r in cands.items() for md, x in r['modes'].items() if x['verdict'] == 'PASS'),
                     key=lambda om: (om[1] != 'corner', (cands[om[0]]['modes'][om[1]]['ao'] or {}).get('p95', 0),
                                     max(abs(x - 1) for x in cands[om[0]]['modes'][om[1]]['density_ratio_per_axis']), om[0]))
    near = sorted(((o, md) for o, r in cands.items() for md, x in r['modes'].items()),
                  key=lambda om: (sum(not v for v in cands[om[0]]['modes'][om[1]]['gates'].values()),
                                  (cands[om[0]]['modes'][om[1]]['ao'] or {}).get('p95', 0)))
    return cls, cands, passing, near


def family_sizes(D, plan0, plan1, fams):
    """family_size keeps the convention its old value follows: number of charts (cfg charts map) or of faces"""
    out = {}
    for fm in fams:
        before = [k for k, e in plan0.items() if e['family'] == fm]; after = [k for k, e in plan1.items() if e['family'] == fm]
        if not after:
            out[fm] = dict(convention='gone', before=len(before), after=0); continue
        fs0 = {plan0[k]['family_size'] for k in before if 'family_size' in plan0[k]} or {None}
        fs0 = fs0.pop() if len(fs0) == 1 else None
        count = dict(faces=lambda ks: len(ks))
        if D.charts:
            count['charts'] = lambda ks: len({D.charts.get(k, k) for k in ks})
        conv = [c for c, f in count.items() if fs0 is not None and f(before) == fs0] if before else ['faces']
        if len({count[c](after) for c in conv}) != 1:        # no convention, or two that disagree after the move
            out[fm] = dict(convention=f'unknown {conv} - kept', before=fs0, after=fs0); continue
        na = count[conv[0]](after)
        for k in after:
            plan1[k]['family_size'] = na
        out[fm] = dict(convention=conv[0], before=fs0, after=na, faces_before=len(before), faces_after=len(after))
    return out


def cross_family_overlaps(plan, pages):
    from shapely.ops import unary_union
    from shapely.strtree import STRtree
    res = {}
    for pg, S in pages.items():
        fp = defaultdict(list)
        for k, x in plan.items():
            if x['page'] == pg:
                fp[x['family']].append(shp(x['uv'], S))
        keys = list(fp); geoms = [unary_union(fp[k]) for k in keys]; tree = STRtree(geoms); ov = set()
        for a, k in enumerate(keys):
            for b in tree.query(geoms[a]):
                if b > a and geoms[a].intersection(geoms[b]).area > 1e-3:
                    ov.add((k, keys[b]))
        res[pg] = ov
    return res


def detectors(D, plan):
    Q = _qa(); out = {}
    for pg, S in D.pages.items():
        for dn, dirn in (('default', ()), ('directional', tuple(D.cfg['directional']))):
            out[f'reg_{pg}_{dn}'] = Q.uv_registration_check(plan, D.geo, pg, S, directional=dirn)
        if pg in D.classmap:
            out[f'cls_{pg}'] = Q.class_mismatch_check(plan, D.classmap[pg], D.classes, pg, S, D.expected, D.cfg['equivalent'])
    return out


def build_plan(D, faces, version, tol, target_family=None, target_owner=None, target_cls=None, allow_free=False,
               accept_ao=False, pins=None):
    """-> (new plan, report, candidates, detectors before, after); new plan None when a face finds no placement
    (the candidates say why). accept_ao: a registration failing ONLY the AO gate is accepted (ranked by AO p95) and
    reported as a waived gate for the owner; pins {face: owner} fixes a face's owner (it must pass the other gates)."""
    plan0 = D.plan; D._target_cls = {}; moving = set(faces); chosen, cand_rep, failed = {}, {}, []
    for m in faces:
        assert m in plan0 and m in D.geo, f'{m}: not in the plan / geometry'
        pin = (pins or {}).get(m)
        cls, cands, passing, near = choose(D, m, tol, target_family, pin or target_owner, target_cls, moving)
        if not passing and accept_ao:
            passing = sorted(((o, md) for o, r in cands.items() for md, x in r['modes'].items()
                              if all(v for g, v in x['gates'].items() if g != 'ao')),
                             key=lambda om: (cands[om[0]]['modes'][om[1]]['ao']['p95'], om[1] != 'corner', om[0]))
        slim = {o: dict(frame=r['frame'],
                        modes={md: {k: v for k, v in x.items()} for md, x in r['modes'].items()}) for o, r in cands.items()}
        cand_rep[m] = dict(cls=cls, candidates=len(cands), passing=[list(p) for p in passing[:10]],
                           closest=[dict(owner=o, mode=md, fails=[g for g, v in cands[o]['modes'][md]['gates'].items() if not v],
                                         ao=cands[o]['modes'][md]['ao'], dens=cands[o]['modes'][md]['density_ratio_per_axis'])
                                    for o, md in near[:8]], details=slim)
        if passing:
            o, md = passing[0]; chosen[m] = dict(owner=o, mode=md, cls=cls, **{k: v for k, v in cands[o]['modes'][md].items()})
            chosen[m]['final_ao_read'] = final_ao_read(D, m, chosen[m]['uv_new'])
        elif allow_free and (uv := free_texels(D, m, cls, plan0[m]['page'])) is not None:
            chosen[m] = dict(owner=None, mode='free', cls=cls, uv_new=uv)
        else:
            failed.append(m)
    if failed:
        return None, dict(verdict='NO_PLACEMENT', failed=failed, closest={m: cand_rep[m]['closest'][:3] for m in failed}), cand_rep, None, None
    new = copy.deepcopy(plan0)
    for m, c in chosen.items():
        if c['mode'] == 'free':
            new[m] = dict(plan0[m], uv=c['uv_new'], family=f'{plan0[m]["family"]}|free_{version}_{m}', owner=True, material=c['cls'])
        else:
            o = c['owner']; new[m] = dict(plan0[m], uv=c['uv_new'], family=plan0[o]['family'], owner=False, material=plan0[o]['material'])
    # a moved OWNER whose texels remaining members still read: hand the ownership over
    promoted = {}
    for m in faces:
        if not plan0[m]['owner']:
            continue
        pg = plan0[m]['page']; S = D.pages[pg]; pm = shp(plan0[m]['uv'], S)
        fam = [k for k, e in new.items() if e['family'] == plan0[m]['family'] and k not in moving]
        owners = [shp(new[k]['uv'], S) for k in fam if new[k]['owner']]
        deps = [k for k in fam if not new[k]['owner'] and shp(new[k]['uv'], S).intersection(pm).area > 0.5
                and not any(o_.contains(shp(new[k]['uv'], S).buffer(-0.05)) for o_ in owners)]
        if not deps:
            continue
        hm = uv_jac(D.V(m), plan0[m]['uv'], S)[1]
        opts = sorted(deps, key=lambda k: (shp(new[k]['uv'], S).intersection(pm).area / pm.area < 0.999,
                                           uv_jac(D.V(k), new[k]['uv'], S)[1] != hm, -shp(new[k]['uv'], S).area))
        k = opts[0]; cover = shp(new[k]['uv'], S).intersection(pm).area / pm.area
        if cover < 0.999:
            raise SystemExit(f'{m} is the owner of texels {deps} read and none of them covers its footprint - decide by hand')
        new[k]['owner'] = True; promoted[k] = dict(replaces=m, footprint_cover=round(cover, 5),
                                                  handedness_same=uv_jac(D.V(k), new[k]['uv'], S)[1] == hm)
    touched = {plan0[m]['family'] for m in faces} | {new[m]['family'] for m in faces}
    fs = family_sizes(D, plan0, new, touched)
    # ---- checks
    diff_uv = [k for k in plan0 if k not in moving and new[k]['uv'] != plan0[k]['uv']]
    meta = {k: sorted(f for f in new[k] if new[k][f] != plan0[k].get(f)) for k in plan0 if k not in moving and new[k] != plan0[k]}
    bad_meta = {k: f for k, f in meta.items() if not set(f) <= ({'family_size', 'owner'} if k in promoted else {'family_size'})}
    assert not diff_uv and not bad_meta, (diff_uv[:5], bad_meta)
    ov0, ov1 = cross_family_overlaps(plan0, D.pages), cross_family_overlaps(new, D.pages)
    new_ov = {pg: sorted(ov1[pg] - ov0[pg]) for pg in D.pages}
    det0, det1 = detectors(D, plan0), detectors(D, new)
    diff = {}
    for key in det0:
        a, b = det0[key], det1[key]; fa, fb = set(a['flagged_faces']), set(b['flagged_faces'])
        changed = sorted(k for k in fa & fb if a['faces'][k].get('flags') != b['faces'][k].get('flags'))
        diff[key] = dict(verdict_before=a['verdict'], verdict_after=b['verdict'], flagged_before=len(fa), flagged_after=len(fb),
                         new=sorted(fb - fa), cleared=sorted(fa - fb), flags_changed=changed)
    moved_reg = {}
    for m in faces:
        pg = new[m]['page']
        for dn in ('default', 'directional'):
            f = det1[f'reg_{pg}_{dn}']['faces'].get(m)
            if f is not None and chosen[m]['mode'] != 'free':
                moved_reg[f'{m}|{dn}'] = {k: f.get(k) for k in ('share', 'fold', 'stretch', 'mirrored', 'flags', 'owner', 'verdict')}
    gates = dict(uv_only_on_moved=not diff_uv, no_new_cross_family_overlap=not any(new_ov.values()),
                 role_registration=all(not d['new'] and not d['flags_changed'] for k, d in diff.items() if k.startswith('reg_'))
                 and all(not v['flags'] and (v['share'] or 0) >= 0.9 for v in moved_reg.values()),
                 class_mismatch=all(not d['new'] for k, d in diff.items() if k.startswith('cls_'))
                 and not any(m in det1[f'cls_{new[m]["page"]}']['flagged_faces'] for m in faces if f'cls_{new[m]["page"]}' in det1))
    report = dict(version=version, base=D.cfg.get('base_version'), base_plan=D.cfg.get('base_plan'),
                  method='quick reposition (blender-uv-conjoin reposition_island.py): members of congruent owners of the '
                         'right class, or free texels of that class; no new texels, no bake',
                  moved_faces=len(faces),
                  moved={m: dict(owner=c['owner'], mode=c['mode'], cls=c['cls'], from_family=plan0[m]['family'],
                                 from_material=plan0[m]['material'], was_owner=plan0[m]['owner'], to_family=new[m]['family'],
                                 **{k: c.get(k) for k in ('density_ratio_per_axis', 'anisotropy', 'owner_anisotropy', 'handedness',
                                                          'owner_handedness', 'inside_owner_footprint', 'offset_m', 'ao',
                                                          'owner_class_share', 'plain_max_diff', 'final_ao_read', 'gates')})
                         for m, c in chosen.items()},
                  promoted_owners=promoted, family_size_changes=fs,
                  checks=dict(uv_diff_outside_moved=len(diff_uv), entries_changed_outside_moved=meta,
                              new_cross_family_overlaps={pg: [list(x) for x in v] for pg, v in new_ov.items()},
                              cross_family_overlaps={pg: [len(ov0[pg]), len(ov1[pg])] for pg in D.pages}),
                  detector_diff=diff, moved_registration=moved_reg, gates=gates, verdict='PASS' if all(gates.values()) else 'FAIL')
    ao_miss = {m: c['ao'] for m, c in chosen.items() if c.get('gates', {}).get('ao') is False}
    if ao_miss:
        report['ao_gate_waived'] = dict(faces=ao_miss, rule=f'S14 point to point p95 <= {AO_P95}, max <= {AO_MAX}',
                                        note='accepted with --accept-ao: needs the owner/coordinator acceptance')
    return new, report, cand_rep, det0, det1


def live_patch(D, plan0, new, faces, chain=()):
    """{object_hint, uv_layer, faces {index: {from, to}}} per page object; `from` = the earliest state in the chain"""
    inv = {v: k for k, v in D.cfg['sources'].items()}; per = defaultdict(dict)
    for p in chain:
        P = load_json(p)
        for i, d in P['faces'].items():
            per[P['object_hint']].setdefault(str(i), dict(d))
    for m in faces:
        pre, i = m.rsplit(':', 1); ob = inv[pre]
        per[ob].setdefault(i, dict(**{'from': plan0[m]['uv']}))
    out = []
    for ob, fc in per.items():
        pre = D.cfg['sources'][ob]
        for i, d in fc.items():
            d['to'] = new[f'{pre}:{i}']['uv']
        out.append(dict(object_hint=ob, uv_layer=D.cfg['uv_layer'], faces=dict(sorted(fc.items(), key=lambda kv: int(kv[0])))))
    return out[0] if len(out) == 1 else dict(patches=out)


def stage_plan(cfg, a, out):
    D = Data(cfg); faces = [f.strip() for f in a.faces.split(',') if f.strip()]
    pins = dict(p.split('=') for p in (a.pin or '').split(',') if p.strip())
    new, rep, cand, det0, det1 = build_plan(D, faces, a.version, cfg['density_tol'], a.target_family, a.target_owner,
                                            a.target_class, a.allow_free, a.accept_ao, pins)
    out.mkdir(parents=True, exist_ok=True)
    if new is None:
        (out / f'candidates_{a.version}.json').write_text(json.dumps(cand, indent=1, default=str))
        print(json.dumps(rep, indent=1, default=str)); return 3
    targets = dict(plan=out / f'plan_final_pages_{a.version}.json', cands=out / f'candidates_{a.version}.json',
                   fix=out / 'fix_report.json', det=out / f'detector_{a.version}.json', patch=out / f'live_patch_{a.version}.json')
    for p in targets.values():
        assert a.force_plan or not p.exists(), f'refusing to overwrite {p}'
    src = load_json(cfg['base_plan']); rep0 = src.get('report', {})
    targets['plan'].write_text(json.dumps(dict(faces=new, report=dict(rep0, **{f'{a.version}_fix': rep}))))
    targets['cands'].write_text(json.dumps(cand, indent=1, default=str))
    rep['request'] = dict(faces=faces, target_family=a.target_family, target_owner=a.target_owner, target_class=a.target_class,
                          allow_free=a.allow_free, accept_ao=a.accept_ao, pins=pins, config=str(a.config))
    targets['fix'].write_text(json.dumps(rep, indent=1, default=str))
    slim = lambda d: {k: {kk: vv for kk, vv in v.items() if kk != 'faces'} | {'flagged': {f: v['faces'][f] for f in v['flagged_faces']}}  # noqa: E731
                      for k, v in d.items()}
    targets['det'].write_text(json.dumps(dict(before=slim(det0), after=slim(det1), diff=rep['detector_diff']), indent=1, default=str))
    targets['patch'].write_text(json.dumps(live_patch(D, D.plan, new, faces, cfg.get('live_patch_chain', [])), indent=1))
    print(json.dumps(dict(verdict=rep['verdict'], gates=rep['gates'], moved={m: (v['owner'], v['mode']) for m, v in rep['moved'].items()},
                          promoted=rep['promoted_owners'], family_size=rep['family_size_changes'],
                          detector={k: {kk: v[kk] for kk in ('flagged_before', 'flagged_after', 'new', 'cleared')}
                                    for k, v in rep['detector_diff'].items()}), indent=1, default=str))
    return 0 if rep['verdict'] == 'PASS' else 3


# ----------------------------------------------------------------------------------------------- Blender stages
def launch_blender(cfg, blend, stage, out, config, gated=False):
    if cfg.get('gate') and not gated:
        g = subprocess.run(cfg['gate'])
        if g.returncode != 0:
            raise SystemExit(f'gate exit {g.returncode}: Blender not launched (wait and call again; never bypass)')
    exe = cfg.get('blender') or os.environ.get('QA_BLENDER', r'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe')
    r = subprocess.run([exe, '-b', str(blend), '--factory-startup', '--python', str(Path(__file__).resolve()), '--',
                        '_blender', stage, str(out), str(config)], capture_output=True, text=True)
    log = Path(out) / f'{stage}_run.log'; log.write_text(r.stdout[-20000:] + '\n' + r.stderr[-8000:])
    ok = f'REPOSITION_{stage.upper()}_OK' in r.stdout
    print(stage, 'OK' if ok else 'FAILED', log)
    if not ok:
        raise SystemExit(f'Blender stage {stage} failed - {log}')


def _bl_dump(prefix, uv_name):
    import bpy
    arr = {}
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.name.startswith(prefix) and uv_name in o.data.uv_layers:
            me = o.data; n = len(me.polygons); uv = np.empty(len(me.loops) * 2, np.float32)
            me.uv_layers[uv_name].data.foreach_get('uv', uv)
            st, tt, mi = (np.empty(n, np.int32) for _ in range(3))
            me.polygons.foreach_get('loop_start', st); me.polygons.foreach_get('loop_total', tt); me.polygons.foreach_get('material_index', mi)
            arr[o.name + '|uv'] = uv.reshape(-1, 2); arr[o.name + '|start'] = st; arr[o.name + '|total'] = tt; arr[o.name + '|mat'] = mi
    return arr


def _bl_fix(cfg, out):
    fix = load_json(Path(out) / 'fix_report.json'); ver = fix['version']
    new = load_json(Path(out) / f'plan_final_pages_{ver}.json')['faces']; old = load_json(cfg['base_plan'])['faces']
    moved = {k: v for k, v in fix['moved'].items()}
    FIX = defaultdict(set)
    for k in new:
        if new[k]['uv'] != old[k]['uv']:
            FIX[k.rsplit(':', 1)[0]].add(int(k.rsplit(':', 1)[1]))
    assert {f'{p}:{i}' for p, s in FIX.items() for i in s} == set(moved), 'plan UV changes differ from the fix report'
    return fix, ver, new, moved, FIX


def blender_stage(stage, out, config):
    import bpy
    sys.path.insert(0, str(QA))
    from uv_fingerprint import fingerprint
    cfg = load_config(config, out=out); fix, ver, new, moved, FIX = _bl_fix(cfg, out)
    cfg = load_config(config, ver, out); uvn = cfg['uv_layer']; V = Path(out) / '_verify'; V.mkdir(exist_ok=True)

    def src_of(name):
        return suffix_sources(cfg['sources']).get('_' + name.rsplit('_', 1)[-1])
    pages = cfg['page_objects']
    if stage == 'apply':
        OUT = Path(cfg['factory_out']); assert not OUT.exists(), f'refusing to overwrite {OUT}'
        assert Path(bpy.data.filepath).resolve() == Path(cfg['factory_blend']).resolve(), bpy.data.filepath
        np.savez(V / 'base.npz', **_bl_dump(cfg['view_prefix'], uvn))
        json.dump(fingerprint(pages, uvn), open(V / 'base_fingerprint.json', 'w'), indent=1)
        objs = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith(cfg['view_prefix']) and uvn in o.data.uv_layers]
        written, slots = set(), {}
        for o in objs:
            pre = src_of(o.name); me = o.data
            if pre is None:
                continue
            if me.name not in written:
                ul = me.uv_layers[uvn]
                for fi in FIX.get(pre, ()):
                    x = new[f'{pre}:{fi}']; poly = me.polygons[fi]; assert len(x['uv']) == poly.loop_total
                    for j, li in enumerate(poly.loop_indices):
                        ul.data[li].uv = x['uv'][j]
                written.add(me.name)
            if any(o.name.startswith(p) for p in cfg.get('follow_owner_slot', [])):
                for fi in FIX.get(pre, ()):
                    ow = moved[f'{pre}:{fi}']['owner']
                    if ow:
                        oi = int(ow.rsplit(':', 1)[1]); names = [s.material.name if s.material else None for s in o.material_slots]
                        slots[f'{o.name}:{fi}'] = dict(before=names[me.polygons[fi].material_index], after=names[me.polygons[oi].material_index])
                        me.polygons[fi].material_index = me.polygons[oi].material_index
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT), compress=True)
        bpy.ops.wm.open_mainfile(filepath=str(OUT))                   # dump the SAVED file
        np.savez(V / f'{ver}.npz', **_bl_dump(cfg['view_prefix'], uvn))
        fp = fingerprint(pages, uvn); json.dump(dict(fp, blend=str(OUT)), open(V / f'{ver}_fingerprint.json', 'w'), indent=1)
        json.dump(dict(source=cfg['factory_blend'], saved=str(OUT), fixed={p: sorted(s) for p, s in FIX.items()},
                       families_view_slots=slots), open(Path(out) / 'apply_report.json', 'w'), indent=1)
        print('REPOSITION_APPLY_OK', fp['combined'])
    elif stage == 'low':
        OUT, FRZ = Path(cfg['low_out']), Path(cfg['freeze_out'])
        assert not OUT.exists() and not FRZ.exists(), 'refusing to overwrite'
        assert Path(bpy.data.filepath).resolve() == Path(cfg['low_blend']).resolve(), bpy.data.filepath
        base = load_json(cfg['base_freeze'])
        assert fingerprint(pages, uvn)['combined'] == base['combined'], 'the texturing LOW is not on the base freeze'
        fac = load_json(V / f'{ver}_fingerprint.json')['combined']
        with bpy.data.libraries.load(cfg['factory_out'], link=False) as (s, d):
            d.objects = list(pages)
        rep = {}
        for n, so in zip(pages, d.objects):
            dst = bpy.data.objects[n]; a, b = dst.data, so.data; pre = src_of(n)
            assert len(a.polygons) == len(b.polygons) and all(pa.vertices[:] == pb.vertices[:] for pa, pb in zip(a.polygons, b.polygons)), n
            ua = np.empty(len(a.loops) * 2, np.float32); a.uv_layers[uvn].data.foreach_get('uv', ua)
            ub = np.empty(len(b.loops) * 2, np.float32); b.uv_layers[uvn].data.foreach_get('uv', ub)
            ua, ub = ua.reshape(-1, 2), ub.reshape(-1, 2)
            ch = sorted(p.index for p in a.polygons if not np.array_equal(ua[list(p.loop_indices)].view(np.uint32), ub[list(p.loop_indices)].view(np.uint32)))
            assert set(ch) == FIX.get(pre, set()), (n, ch[:10])
            a.uv_layers[uvn].data.foreach_set('uv', ub.ravel()); a.update(); rep[n] = dict(faces=len(a.polygons), changed=ch)
        for o in d.objects:
            bpy.data.objects.remove(o, do_unlink=True)
        fp = fingerprint(pages, uvn); assert fp['combined'] == fac, ('the LOW does not reproduce the factory fingerprint', fp['combined'], fac)
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT), compress=True)
        bpy.ops.wm.open_mainfile(filepath=str(OUT))
        fp2 = fingerprint(pages, uvn); assert fp2['combined'] == fac, 'the SAVED LOW differs'
        FRZ.write_text(json.dumps(dict(uv_name=uvn, objects=fp2['objects'], combined=fp2['combined'], blend=OUT.name,
                                       note=f'{ver} = {cfg.get("base_version")} + {len(moved)} faces repositioned '
                                            f'(reposition_island.py): {sorted(moved)}', supersedes=cfg.get('base_version')), indent=2))
        json.dump(dict(source=cfg['low_blend'], saved=str(OUT), per_object=rep, fingerprint=fp2['combined']),
                  open(Path(out) / 'low_report.json', 'w'), indent=1)
        print('REPOSITION_LOW_OK', fp2['combined'])


# ----------------------------------------------------------------------------------------------- verify / handoff
def suffix_sources(sources):
    """view objects map to a plan key prefix by the suffix of their page object: Claude_S18_Families_A -> _A -> S12_Groups_A"""
    return {'_' + ob.rsplit('_', 1)[-1]: pre for ob, pre in sources.items()}


def verify_arrays(base, new, FIX, plan, sources, follow=()):
    """per-face byte identity of two dumps: UV + material index change only on FIX faces (material index only in
    follow-owner-slot views), page objects equal the plan"""
    out = {}; suffix_src = suffix_sources(sources)
    for o in sorted({k.split('|')[0] for k in base}):
        pre = suffix_src.get('_' + o.rsplit('_', 1)[-1]); fx = FIX.get(pre, set()); uf, ug = base[o + '|uv'], new[o + '|uv']
        st, tt = base[o + '|start'], base[o + '|total']
        assert np.array_equal(st, new[o + '|start']) and np.array_equal(tt, new[o + '|total']), f'{o}: topology differs'
        ch = [i for i in range(len(st)) if not np.array_equal(uf[st[i]:st[i] + tt[i]].view(np.uint32), ug[st[i]:st[i] + tt[i]].view(np.uint32))]
        mat = np.nonzero(base[o + '|mat'] != new[o + '|mat'])[0].tolist()
        rec = dict(faces=len(st), changed=len(ch), changed_outside_fix=sorted(set(ch) - fx), fix_not_changed=sorted(fx - set(ch)),
                   material_index_changed=len(mat), material_index_changed_outside=sorted(set(mat) - (fx if any(o.startswith(f) for f in follow) else set())))
        if o in sources:
            rec['max_uv_diff_vs_plan'] = max(float(np.abs(ug[st[i]:st[i] + tt[i]] - np.asarray(plan[f'{pre}:{i}']['uv'], np.float32)).max()) for i in range(len(st)))
        out[o] = rec
    ok = all(not r['changed_outside_fix'] and not r['fix_not_changed'] and not r['material_index_changed_outside']
             and r.get('max_uv_diff_vs_plan', 0) < 1e-6 for r in out.values())
    return ok, out


def stage_verify(cfg, out):
    fix = load_json(out / 'fix_report.json'); ver = fix['version']; path = cfg['_path']; cfg = load_config(path, ver, out)
    cfg['_path'] = path; new = load_json(out / f'plan_final_pages_{ver}.json')['faces']; FIX = defaultdict(set)
    for k in fix['moved']:
        FIX[k.rsplit(':', 1)[0]].add(int(k.rsplit(':', 1)[1]))
    V = out / '_verify'; a, b = np.load(V / 'base.npz'), np.load(V / f'{ver}.npz')
    ok, per = verify_arrays({k: a[k] for k in a.files}, {k: b[k] for k in b.files}, FIX, new, cfg['sources'], cfg.get('follow_owner_slot', []))
    fpb, fpn = load_json(V / 'base_fingerprint.json'), load_json(V / f'{ver}_fingerprint.json')
    bf, nf = load_json(cfg['base_freeze']), load_json(cfg['freeze_out'])
    res = dict(verdict='PASS' if ok and fpn['combined'] == nf['combined'] and fpb['combined'] == bf['combined'] else 'FAIL',
               fixed={p: sorted(s) for p, s in FIX.items()}, per_object=per, base_factory_fingerprint=fpb['combined'],
               base_freeze=bf['combined'], base_factory_equals_base_freeze=fpb['combined'] == bf['combined'],
               new_factory_fingerprint=fpn['combined'], new_freeze=nf['combined'], new_factory_equals_new_freeze=fpn['combined'] == nf['combined'],
               objects_changed={o: fpn['objects'][o] != fpb['objects'][o] for o in fpn['objects']})
    (out / 'verify_saved_blend.json').write_text(json.dumps(res, indent=1)); print(json.dumps({k: v for k, v in res.items() if k != 'per_object'}, indent=1))
    return 0 if res['verdict'] == 'PASS' else 3


def stage_handoff(cfg, out, extra=None):
    fix = load_json(out / 'fix_report.json'); ver = fix['version']; path = cfg['_path']; cfg = load_config(path, ver, out)
    cfg['_path'] = path; h = cfg.get('handoff', {}); rel = lambda p: os.path.relpath(p, out).replace('\\', '/')  # noqa: E731
    vr = load_json(out / 'verify_saved_blend.json') if (out / 'verify_saved_blend.json').exists() else {}
    spec = {'schema': 1, 'model': h.get('model', 'model'), 'phase': h.get('phase', '03_uv'), 'status': 'review',
            'producer': h.get('producer', 'claude'), 'date': __import__('datetime').date.today().isoformat(),
            'inputs': [{'phase': h.get('phase', '03_uv'), 'handoff': rel(p)} for p in h.get('inputs', [])],
            'canonical': {
                'low_file': {'path': rel(cfg['factory_out']), 'convention': f'{cfg.get("base_version")} factory blend + {cfg["uv_layer"]} changed only on the moved faces (verify_saved_blend.json)'},
                'texturing_low': {'path': rel(cfg['low_out']), 'convention': f'{cfg.get("base_version")} texturing LOW with {cfg["uv_layer"]} of the page objects copied from the new factory blend'},
                'plan': {'path': f'plan_final_pages_{ver}.json', 'convention': 'same schema as the base plan; moved faces are members of their new owners (fix_report.json moved)'},
                'uv_freeze': {'path': rel(cfg['freeze_out']), 'convention': 'uv_fingerprint of the page objects in the texturing LOW = the factory blend'},
                'fix_report': {'path': 'fix_report.json', 'convention': 'moved faces, owners, modes, gates, detector diff, family_size'},
                'detector': {'path': f'detector_{ver}.json', 'convention': 'uv_registration + class_mismatch before/after'},
                'live_patch': {'path': f'live_patch_{ver}.json', 'convention': '{object_hint, uv_layer, faces {i: {from, to}}}; from = the live state (chained)'}},
            'conventions': {'why': h.get('why', ''), 'method': fix['method']},
            'qa': {'result': 'pass' if fix['verdict'] == 'PASS' and vr.get('verdict') == 'PASS' else 'fail',
                   'report': 'fix_report.json', 'gates': fix['gates'], 'verify': vr.get('verdict'), **(extra or {})},
            'open_issues': h.get('open_issues', []), 'next': h.get('next', 'coordinator: owner review, then switch uv_version to this version'),
            'reproduce': [f'python {Path(__file__).name} run --config {cfg["_path"]} --faces {",".join(fix["moved"])} --version {ver} --out {out}']}
    ex = out / 'handoff_extra.json'                  # project additions: pictures, regression, open issues, reproduce
    if ex.exists():
        X = load_json(ex)
        for k in ('qa', 'conventions', 'canonical'):
            spec[k].update(X.get(k, {}))
        for k in ('open_issues', 'reproduce'):
            spec[k] += X.get(k, [])
        spec['next'] = X.get('next', spec['next']); spec['producer_note'] = X.get('producer_note', '')
    (out / 'HANDOFF.spec.json').write_text(json.dumps(spec, indent=1))
    r = subprocess.run([sys.executable, str(HANDOFF_PY), 'write', str(out / 'HANDOFF.spec.json'), '--out', str(out / 'HANDOFF.json')],
                       capture_output=True, text=True)
    print(r.stdout[-2000:], r.stderr[-2000:]); return r.returncode


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv and argv[0] == '_blender':
        return blender_stage(argv[1], Path(argv[2]), argv[3])
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('stage', choices=['plan', 'apply', 'low', 'verify', 'handoff', 'run'])
    ap.add_argument('--config', required=True); ap.add_argument('--out', required=True)
    ap.add_argument('--faces'); ap.add_argument('--version'); ap.add_argument('--target-family'); ap.add_argument('--target-owner')
    ap.add_argument('--target-class'); ap.add_argument('--allow-free', action='store_true')
    ap.add_argument('--accept-ao', action='store_true', help='accept a registration that fails only the AO gate (owner decision)')
    ap.add_argument('--pin', help='FACE=OWNER,.. fix owners (they must still pass the other gates)')
    ap.add_argument('--gated', action='store_true', help='the caller ran cfg gate itself right before (exit 0): launch at once')
    ap.add_argument('--force-plan', action='store_true', help='rewrite this version\'s plan files (never the blends)')
    a = ap.parse_args(argv); out = Path(a.out).resolve()
    cfg = load_config(a.config, a.version, out); cfg['_path'] = str(Path(a.config).resolve())
    if a.stage in ('plan', 'run'):
        code = stage_plan(cfg, a, out)
        if code or a.stage == 'plan':
            return code
    ver = a.version or load_json(out / 'fix_report.json')['version']; cfg = load_config(a.config, ver, out); cfg['_path'] = str(Path(a.config).resolve())
    if a.stage in ('apply', 'run'):
        launch_blender(cfg, cfg['factory_blend'], 'apply', out, cfg['_path'], a.gated)
    if a.stage in ('low', 'run'):
        launch_blender(cfg, cfg['low_blend'], 'low', out, cfg['_path'], a.gated and a.stage != 'run')
    if a.stage in ('verify', 'run'):
        code = stage_verify(cfg, out)
        if code:
            return code
    if a.stage in ('handoff', 'run'):
        return stage_handoff(cfg, out)
    return 0


if __name__ == '__main__':
    if '--' in sys.argv:                                        # inside Blender
        main(sys.argv[sys.argv.index('--') + 1:])
    else:
        sys.exit(main())
