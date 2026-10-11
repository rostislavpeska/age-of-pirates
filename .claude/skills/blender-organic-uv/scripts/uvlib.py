"""uvlib - UV cleanness metrics in pure numpy (no bpy), shared by the Blender stage and the host tools.

Conventions
- Triangles: F (T,3) vertex ids into P (V,3) (3D, model units), UV (T,3,2) per-corner UVs (Blender convention: V up,
  page = [0,1]^2). A face is "not flipped" when its UV winding is counter-clockwise for the triangle's own corner
  order (Blender's convention: the mesh face normal follows the corner order, so CCW in UV = same orientation).
- Stretch follows Sander, Snyder, Gortler, Hoppe, "Texture Mapping Progressive Meshes", SIGGRAPH 2001
  (https://hhoppe.com/tmpm.pdf): the Jacobian of the UV -> surface map has singular values Gamma >= gamma;
  L2(T) = sqrt((Gamma^2 + gamma^2) / 2), Linf(T) = Gamma; mesh L2 = sqrt(sum L2(T)^2 A3d(T) / sum A3d(T)), mesh
  Linf = max Gamma. Both are normalised by sqrt(sum A_uv / sum A3d) so that 1.0 is the optimum (a uniformly scaled
  isometry); > 1 = texels stretched (under-sampled), per-face < 1 = more texels than the page average. Intended
  density differences (a head priority) therefore raise the page L2: judge per-island stretch separately.
- Angular distortion: Gamma / gamma (1 = conformal) and the mean absolute difference between the triangle's 3D and
  UV corner angles (degrees).
- Area distortion: r = (A_uv / sum A_uv) / (A3d / sum A3d); log2 r = 0 ideal, +1 = twice its share of texels.
- Texel density: page * sqrt(A_uv / A3d) texels per model unit (the density-floor formula); per metre = / metres
  per unit.
- Bone regions (the estimator of the reference unit benchmark): every triangle belongs to the region of its dominant
  bone (largest sum of its three corners' weights), the region comes from the first matching name rule, and a
  region's density is page * sqrt(sum A_uv / sum A3d) over its triangles. Head priority is read on this estimator.
"""
from __future__ import annotations

import math

import numpy as np

EPS_UV = 1e-12      # |2 * signed UV area| below this = collapsed face
EPS_3D = 1e-14


# ---------------------------------------------------------------- weighted statistics
def wquantile(x, w, qs):
    x = np.asarray(x, float)
    w = np.asarray(w, float)
    m = np.isfinite(x) & (w > 0)
    if not m.any():
        return [None for _ in qs]
    x, w = x[m], w[m]
    o = np.argsort(x)
    x, w = x[o], w[o]
    c = np.cumsum(w) - 0.5 * w
    c /= w.sum()
    return [float(np.interp(q, c, x)) for q in qs]


def wmean(x, w):
    x = np.asarray(x, float)
    w = np.asarray(w, float)
    m = np.isfinite(x) & (w > 0)
    return float((x[m] * w[m]).sum() / w[m].sum()) if m.any() else None


def r(x, n=4):
    if x is None:
        return None
    if isinstance(x, (float, np.floating)):
        if not math.isfinite(x):
            return None if math.isnan(x) else ('inf' if x > 0 else '-inf')
        return round(float(x), n) + 0.0          # + 0.0 turns -0.0 into 0.0
    return x


# ---------------------------------------------------------------- per-triangle geometry
def tri_corner_angles(X):
    """X (T,3,d) -> (T,3) corner angles in degrees."""
    out = np.zeros(X.shape[:2])
    for k in range(3):
        a = X[:, (k + 1) % 3] - X[:, k]
        b = X[:, (k + 2) % 3] - X[:, k]
        na = np.linalg.norm(a, axis=1)
        nb = np.linalg.norm(b, axis=1)
        c = (a * b).sum(1) / np.maximum(na * nb, 1e-30)
        out[:, k] = np.degrees(np.arccos(np.clip(c, -1, 1)))
    return out


def face_metrics(P, F, UV, page):
    """per-triangle metrics (unnormalised and normalised) for one page. Returns a dict of arrays + globals."""
    Q = P[F]                                   # (T,3,3)
    q1, q2, q3 = Q[:, 0], Q[:, 1], Q[:, 2]
    s1, t1 = UV[:, 0, 0], UV[:, 0, 1]
    s2, t2 = UV[:, 1, 0], UV[:, 1, 1]
    s3, t3 = UV[:, 2, 0], UV[:, 2, 1]
    A2 = (s2 - s1) * (t3 - t1) - (s3 - s1) * (t2 - t1)          # 2 * signed UV area
    a3 = 0.5 * np.linalg.norm(np.cross(q2 - q1, q3 - q1), axis=1)
    auv = 0.5 * np.abs(A2)
    collapsed = (np.abs(A2) <= EPS_UV) & (a3 > EPS_3D)
    degenerate3d = a3 <= EPS_3D
    ok = ~collapsed & ~degenerate3d
    den = np.where(ok, A2, 1.0)[:, None]
    Ss = (q1 * (t2 - t3)[:, None] + q2 * (t3 - t1)[:, None] + q3 * (t1 - t2)[:, None]) / den
    St = (q1 * (s3 - s2)[:, None] + q2 * (s1 - s3)[:, None] + q3 * (s2 - s1)[:, None]) / den
    a = (Ss * Ss).sum(1)
    b = (Ss * St).sum(1)
    c = (St * St).sum(1)
    disc = np.sqrt(np.maximum((a - c) ** 2 + 4 * b * b, 0))
    G = np.sqrt(np.maximum((a + c + disc) / 2, 0))
    g = np.sqrt(np.maximum((a + c - disc) / 2, 0))
    L2 = np.sqrt((a + c) / 2)
    sum3, sumuv = a3[ok].sum(), auv[ok].sum()
    k = math.sqrt(sumuv / sum3) if sum3 > 0 and sumuv > 0 else float('nan')
    G_n, g_n, L2_n = G * k, g * k, L2 * k
    G_n[~ok] = np.inf
    L2_n[~ok] = np.inf
    g_n[~ok] = 0.0
    with np.errstate(divide='ignore', invalid='ignore'):
        aniso = np.where(ok, G / np.maximum(g, 1e-300), np.inf)
        area_ratio = np.where(ok, (auv / sumuv) / (a3 / sum3), 0.0)
        dens = page * np.sqrt(np.where(a3 > EPS_3D, auv / np.maximum(a3, 1e-300), 0.0))
    ang3 = tri_corner_angles(Q)
    anguv = tri_corner_angles(UV)
    angdev = np.abs(ang3 - anguv).mean(1)
    angdev_max = np.abs(ang3 - anguv).max(1)
    angdev[~ok] = np.nan
    angdev_max[~ok] = np.nan
    return dict(A2=A2, area3d=a3, area_uv=auv, ok=ok, collapsed=collapsed, degenerate3d=degenerate3d,
                Gamma=G, gamma=g, L2=L2, Gamma_n=G_n, gamma_n=g_n, L2_n=L2_n, aniso=aniso, area_ratio=area_ratio,
                density=dens, angdev=angdev, angdev_max=angdev_max, k=k, flipped=(A2 < 0) & ok)


# ---------------------------------------------------------------- topology: edges, seams, islands
class UF:
    def __init__(self, n):
        self.p = list(range(n))

    def find(self, x):
        p = self.p
        while p[x] != x:
            p[x] = p[p[x]]
            x = p[x]
        return x

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.p[max(ra, rb)] = min(ra, rb)


def edge_table(F, UV, uv_tol=1e-6, real_edges=None):
    """edges of the triangle set. Returns list of dicts {v:(a,b), faces:[t..], uvs:[(ua,ub)..], kind}, kind one of
    'inner' (2 faces, UV continuous), 'seam' (2 faces, UV split), 'border' (1 face), 'nonmanifold' (>2 faces).
    real_edges: optional set of (min,max) vertex pairs that are real polygon edges (loop-triangle diagonals of a quad
    are then 'diagonal' and never seams)."""
    E = {}
    for t in range(len(F)):
        for k in range(3):
            a, b = int(F[t, k]), int(F[t, (k + 1) % 3])
            ua, ub = UV[t, k], UV[t, (k + 1) % 3]
            if a > b:
                a, b, ua, ub = b, a, ub, ua
            e = E.setdefault((a, b), {'v': (a, b), 'faces': [], 'uvs': [], 'corner': []})
            e['faces'].append(t)
            e['uvs'].append((ua, ub))
            e['corner'].append(k)
    out = []
    for key, e in E.items():
        n = len(e['faces'])
        if n == 1:
            kind = 'border'
        elif n == 2:
            (ua1, ub1), (ua2, ub2) = e['uvs']
            split = (np.abs(ua1 - ua2).max() > uv_tol) or (np.abs(ub1 - ub2).max() > uv_tol)
            kind = 'seam' if split else 'inner'
            if real_edges is not None and key not in real_edges:
                kind = 'diagonal'
        else:
            kind = 'nonmanifold'
        e['kind'] = kind
        out.append(e)
    return out


def islands(n_faces, edges):
    uf = UF(n_faces)
    for e in edges:
        if e['kind'] in ('inner', 'diagonal'):
            uf.union(e['faces'][0], e['faces'][1])
    roots = [uf.find(t) for t in range(n_faces)]
    remap = {}
    lab = np.array([remap.setdefault(x, len(remap)) for x in roots], int)
    return lab


def outline_segments(edges, lab):
    """UV segments on island outlines: (N,2,2) points and (N,) island ids."""
    seg, ids = [], []
    for e in edges:
        if e['kind'] in ('seam', 'border', 'nonmanifold'):
            for t, (ua, ub) in zip(e['faces'], e['uvs']):
                seg.append((ua, ub))
                ids.append(lab[t])
        elif e['kind'] == 'inner':
            pass
    if not seg:
        return np.zeros((0, 2, 2)), np.zeros(0, int)
    return np.array(seg, float), np.array(ids, int)


# ---------------------------------------------------------------- 2D geometry
def _pt_seg_d2(p, a, b):
    ab = b - a
    t = np.clip(((p - a) * ab).sum(-1) / np.maximum((ab * ab).sum(-1), 1e-30), 0, 1)
    d = p - (a + t[..., None] * ab)
    return (d * d).sum(-1), a + t[..., None] * ab


def _cross2(u, v):
    return u[..., 0] * v[..., 1] - u[..., 1] * v[..., 0]


def seg_seg_dist(A0, A1, B0, B1):
    """vectorised 2D segment distances and closest point pairs."""
    A0, A1, B0, B1 = np.broadcast_arrays(A0, A1, B0, B1)
    r_ = A1 - A0
    s_ = B1 - B0
    den = _cross2(r_, s_)
    qp = B0 - A0
    with np.errstate(divide='ignore', invalid='ignore'):
        t = _cross2(qp, s_) / den
        u = _cross2(qp, r_) / den
    inter = (np.abs(den) > 1e-30) & (t >= 0) & (t <= 1) & (u >= 0) & (u <= 1)
    cands = []
    d1, c1 = _pt_seg_d2(A0, B0, B1)
    cands.append((d1, A0, c1))
    d2, c2 = _pt_seg_d2(A1, B0, B1)
    cands.append((d2, A1, c2))
    d3, c3 = _pt_seg_d2(B0, A0, A1)
    cands.append((d3, c3, B0))
    d4, c4 = _pt_seg_d2(B1, A0, A1)
    cands.append((d4, c4, B1))
    D = np.stack([c[0] for c in cands], -1)
    i = D.argmin(-1)
    dmin = np.take_along_axis(D, i[..., None], -1)[..., 0]
    PA = np.stack([c[1] for c in cands], -2)
    PB = np.stack([c[2] for c in cands], -2)
    pa = np.take_along_axis(PA, i[..., None, None].repeat(2, -1), -2)[..., 0, :]
    pb = np.take_along_axis(PB, i[..., None, None].repeat(2, -1), -2)[..., 0, :]
    dmin = np.where(inter, 0.0, np.sqrt(dmin))
    return dmin, pa, pb


def island_gaps(seg, ids, chunk=1500):
    """min UV distance between every pair of islands that come within reach: {(i,j): (d, pa, pb)} for all pairs
    (only pairs with a finite distance are listed; all pairs are evaluated)."""
    n = len(seg)
    best = {}
    if n == 0:
        return best
    A0, A1 = seg[:, 0], seg[:, 1]
    for s in range(0, n, chunk):
        e = min(n, s + chunk)
        d, pa, pb = seg_seg_dist(A0[s:e, None], A1[s:e, None], A0[None], A1[None])
        I = ids[s:e, None]
        J = ids[None, :]
        mask = I < J
        d = np.where(mask, d, np.inf)
        ii, jj = np.nonzero(np.isfinite(d))
        if not len(ii):
            continue
        key = ids[s:e][ii] * (ids.max() + 1) + ids[jj]
        o = np.lexsort((d[ii, jj], key))
        key_s = key[o]
        first = np.r_[True, key_s[1:] != key_s[:-1]]
        for q in o[first]:
            a_, b_ = int(ids[s + ii[q]]), int(ids[jj[q]])
            dv = float(d[ii[q], jj[q]])
            if (a_, b_) not in best or dv < best[(a_, b_)][0]:
                best[(a_, b_)] = (dv, pa[ii[q], jj[q]].copy(), pb[ii[q], jj[q]].copy())
    return best


def tri_ccw(T):
    """(3,2) -> CCW copy"""
    if _cross2(T[1] - T[0], T[2] - T[0]) < 0:
        return T[[0, 2, 1]]
    return T


def clip_poly(subject, clipper):
    """Sutherland-Hodgman: subject polygon (list of 2D) clipped by convex CCW clipper (array (n,2))."""
    out = [np.asarray(p, float) for p in subject]
    n = len(clipper)
    for i in range(n):
        a, b = clipper[i], clipper[(i + 1) % n]
        inp = out
        out = []
        if not inp:
            break
        ab = b - a

        def inside(p):
            return _cross2(ab, p - a) >= -1e-15
        s = inp[-1]
        for p in inp:
            if inside(p):
                if not inside(s):
                    out.append(_isect(s, p, a, b))
                out.append(p)
            elif inside(s):
                out.append(_isect(s, p, a, b))
            s = p
    return out


def _isect(p1, p2, a, b):
    d1 = p2 - p1
    d2 = b - a
    den = _cross2(d1, d2)
    if abs(den) < 1e-30:
        return p2
    t = _cross2(a - p1, d2) / den
    return p1 + t * d1


def poly_area(pts):
    if len(pts) < 3:
        return 0.0
    P_ = np.array(pts)
    x, y = P_[:, 0], P_[:, 1]
    return 0.5 * abs(float((x * np.roll(y, -1) - np.roll(x, -1) * y).sum()))


def tri_overlaps(UV, min_area):
    """exact pairwise UV triangle overlaps: [(t1, t2, area)] with area > min_area (UV units^2)."""
    T = len(UV)
    lo = UV.min(1)
    hi = UV.max(1)
    order = np.argsort(lo[:, 0])
    res = []
    active = []
    for t in order:
        x0 = lo[t, 0]
        active = [u for u in active if hi[u, 0] > x0]
        for u in active:
            if hi[u, 1] <= lo[t, 1] or hi[t, 1] <= lo[u, 1]:
                continue
            A = tri_ccw(UV[t])
            B = tri_ccw(UV[u])
            poly = clip_poly(list(A), B)
            ar = poly_area(poly)
            if ar > min_area:
                res.append((int(min(t, u)), int(max(t, u)), ar))
        active.append(t)
    return res


def raster_cover(UV, lab, page, exclude=None):
    """pixel-centre coverage at the page size: count of triangles and of distinct islands per texel.
    Returns (count uint16 (page,page) with row 0 = V top, island_any int32 first island, multi_island bool)."""
    cnt = np.zeros((page, page), np.uint16)
    first = np.full((page, page), -1, np.int32)
    multi = np.zeros((page, page), bool)
    for t in range(len(UV)):
        if exclude is not None and exclude[t]:
            continue
        X = UV[t] * page                      # pixel units, x right, y up
        x0 = max(0, int(math.floor(X[:, 0].min() - 0.5)))
        x1 = min(page - 1, int(math.ceil(X[:, 0].max() - 0.5)))
        y0 = max(0, int(math.floor(X[:, 1].min() - 0.5)))
        y1 = min(page - 1, int(math.ceil(X[:, 1].max() - 0.5)))
        if x1 < x0 or y1 < y0:
            continue
        xs = np.arange(x0, x1 + 1) + 0.5
        ys = np.arange(y0, y1 + 1) + 0.5
        gx, gy = np.meshgrid(xs, ys)
        p = np.stack([gx, gy], -1)
        A = X[0]
        B = X[1]
        C = X[2]
        w0 = _cross2(B - A, p - A)
        w1 = _cross2(C - B, p - B)
        w2 = _cross2(A - C, p - C)
        e = 1e-9
        ins = ((w0 >= -e) & (w1 >= -e) & (w2 >= -e)) | ((w0 <= e) & (w1 <= e) & (w2 <= e))
        if not ins.any():
            continue
        rows = page - 1 - (np.arange(y0, y1 + 1))        # image row (V up -> row from top)
        R_, C_ = np.meshgrid(rows, np.arange(x0, x1 + 1), indexing='ij')
        rr, cc = R_[ins], C_[ins]
        cnt[rr, cc] += 1
        f = first[rr, cc]
        newm = (f >= 0) & (f != lab[t])
        multi[rr[newm], cc[newm]] = True
        unset = f < 0
        first[rr[unset], cc[unset]] = lab[t]
    return cnt, first, multi


# ---------------------------------------------------------------- orientation
def up_in_uv(P, F, UV, up=(0.0, 0.0, 1.0)):
    """per triangle: UV direction of the 3D up vector projected into the face plane, and its weight (A3d * |proj|)."""
    Q = P[F]
    E = np.stack([Q[:, 1] - Q[:, 0], Q[:, 2] - Q[:, 0]], -1)          # (T,3,2)
    M = np.stack([UV[:, 1] - UV[:, 0], UV[:, 2] - UV[:, 0]], -1)      # (T,2,2)
    up = np.asarray(up, float)
    EtE = np.einsum('tij,tik->tjk', E, E)
    Etu = np.einsum('tij,i->tj', E, up)
    det = EtE[:, 0, 0] * EtE[:, 1, 1] - EtE[:, 0, 1] * EtE[:, 1, 0]
    ok = np.abs(det) > 1e-30
    inv = np.zeros_like(EtE)
    inv[:, 0, 0] = EtE[:, 1, 1]
    inv[:, 1, 1] = EtE[:, 0, 0]
    inv[:, 0, 1] = -EtE[:, 0, 1]
    inv[:, 1, 0] = -EtE[:, 1, 0]
    inv /= np.where(ok, det, 1.0)[:, None, None]
    cc = np.einsum('tjk,tk->tj', inv, Etu)
    proj = np.einsum('tij,tj->ti', E, cc)                                # in-plane projection of up
    plen = np.linalg.norm(proj, axis=1)
    d = np.einsum('tij,tj->ti', M, cc)
    dl = np.linalg.norm(d, axis=1)
    unit = d / np.maximum(dl, 1e-30)[:, None]
    a3 = 0.5 * np.linalg.norm(np.cross(Q[:, 1] - Q[:, 0], Q[:, 2] - Q[:, 0]), axis=1)
    w = np.where(ok & (dl > 0), a3 * plen, 0.0)
    return unit, w


def island_orientation(unit, w, lab, n_isl):
    """per island: angle of 3D-up in UV, degrees from +V (positive = clockwise, i.e. towards +U), coherence 0..1,
    weight."""
    out = []
    for i in range(n_isl):
        m = lab == i
        W = w[m]
        if W.sum() <= 0:
            out.append((None, 0.0, 0.0))
            continue
        v = (unit[m] * W[:, None]).sum(0)
        coh = float(np.linalg.norm(v) / W.sum())
        ang = float(np.degrees(np.arctan2(v[0], v[1])))
        out.append((ang, coh, float(W.sum())))
    return out


def circ_stats(angles, weights):
    a = np.radians(np.asarray(angles, float))
    w = np.asarray(weights, float)
    if w.sum() <= 0:
        return None, None
    C = (w * np.cos(a)).sum() / w.sum()
    S = (w * np.sin(a)).sum() / w.sum()
    R = math.hypot(C, S)
    mean = math.degrees(math.atan2(S, C))
    std = math.degrees(math.sqrt(-2 * math.log(max(R, 1e-12))))
    return mean, std


# ---------------------------------------------------------------- bone regions (head priority estimator)
# Default rules: 3ds Max Biped / Bip01-style bone names, in this order (first match wins). The reference unit
# benchmark used exactly these rules; a project with other bone names passes its own list.
DEFAULT_REGION_RULES = [
    ['weapon', r'^bone_|attach|prop'],
    ['head', r'head|neck|ponytail'],
    ['hands', r'hand|finger'],
    ['arms', r'arm|clavicle'],
    ['torso', r'spine|pelvis'],
    ['feet', r'foot|toe'],
    ['legs', r'thigh|calf'],
]


def bone_region(name, rules=None):
    """region name of a bone (lower-cased regex search, first rule wins), 'other' when nothing matches, 'none' for
    None."""
    import re
    if name is None:
        return 'none'
    n = str(name).lower()
    for region, pattern in (rules or DEFAULT_REGION_RULES):
        if re.search(pattern, n):
            return region
    return 'other'


TIE_EPS = 1e-6


def dominant_bone(corners, vweights):
    """bone with the largest weight summed over the corners (vertex ids); None when unweighted. Sums within TIE_EPS
    tie, and a tie goes to the bone met first, walking the corners in order and each vertex's influences heaviest
    first: the rule of the reference benchmark (collections.Counter.most_common). Symmetric blends (0.35/0.65 on two
    corners, 0.8/0.2 on the third) tie, and float32 weights would otherwise break the tie by noise (4e-8)."""
    acc = {}
    for v in corners:
        for b, w in sorted(vweights[int(v)], key=lambda t: -t[1]):
            acc[b] = acc.get(b, 0.0) + float(w)
    if not acc:
        return None
    top = max(acc.values())
    return next(b for b, s in acc.items() if s >= top - TIE_EPS)


def tri_dominant_bones(F, vweights):
    """F (T,3) vertex ids, vweights: list per vertex of (bone name, weight) pairs -> dominant bone per triangle."""
    return [dominant_bone(f, vweights) for f in np.asarray(F)]


def region_densities(P, F, UV, page, regions, metres_per_unit=1.0):
    """per region: triangles, 3D area (m2), UV area (texels2), density (texels per metre) = page * sqrt(sum A_uv /
    sum A3d) / metres_per_unit, UV share and surface share (%)."""
    P = np.asarray(P, float)
    F = np.asarray(F)
    UV = np.asarray(UV, float)
    Q = P[F]
    a3 = 0.5 * np.linalg.norm(np.cross(Q[:, 1] - Q[:, 0], Q[:, 2] - Q[:, 0]), axis=1)
    e1, e2 = UV[:, 1] - UV[:, 0], UV[:, 2] - UV[:, 0]
    au = 0.5 * np.abs(e1[:, 0] * e2[:, 1] - e2[:, 0] * e1[:, 1]) * page * page
    regions = np.asarray(regions)
    tot3, totu = float(a3.sum()), float(au.sum())
    out = {}
    for rg in sorted(set(regions.tolist())):
        m = regions == rg
        A, U = float(a3[m].sum()), float(au[m].sum())
        out[rg] = {'tris': int(m.sum()), 'area3d_m2': A * metres_per_unit ** 2, 'area_uv_px2': U,
                   'density_t_per_m': (math.sqrt(U / A) / metres_per_unit) if A > 0 else None,
                   'uv_share_pct': 100.0 * U / totu if totu else None,
                   'surface_share_pct': 100.0 * A / tot3 if tot3 else None}
    return out


def region_ratio(dens, num='head', den='torso'):
    """density ratio of two regions from region_densities(), None when either is missing."""
    a, b = dens.get(num, {}).get('density_t_per_m'), dens.get(den, {}).get('density_t_per_m')
    return (a / b) if a and b else None
