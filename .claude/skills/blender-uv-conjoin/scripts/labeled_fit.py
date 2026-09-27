"""Labeled containment matcher for UV reuse (S13 experiment, not yet a canonical skill).

Definition. A chart is a set of UV polygons in working texels, each carrying a
material label and an optional orientation vector (wood grain or world-up,
expressed in UV space). Member M may reuse owner O's texels under a planar
isometry g(x) = L x + t (L orthogonal; det -1 only when reflection is allowed)
iff, for every label k,

    g(M_k)  is a subset of  O_k (+) B_eps                                (1)

i.e. the directed Hausdorff distance from each transformed member label region
to the owner region of the same label is at most eps texels (Huttenlocher,
Klanderman and Rucklidge 1993). Oriented materials carry their direction in the
label: a member face only counts as label k if L maps its orientation onto an
owner direction of the same material within ang_tol degrees.

Search. Oriented content fixes L exactly (dominant member direction onto each
owner direction); unoriented charts try edge-pair and rectangle-axis alignments.
For each L, (1) over translations is a morphological erosion. A pixel-grid
necessary condition is evaluated for all translations at once by FFT correlation
(Lewis 1995): member pixel centres inside M_k must land on owner pixels within
eps + half a pixel diagonal of O_k. This never rejects a true fit. Surviving
translations are refined by pattern search on the exact outside area and then
certified on polygons with Shapely: area(g(M_k) - (O_k (+) B_eps)) <= area_tol.
Only certified fits are returned; verify() re-checks them by dense sampling.

Containment is transitive (compose transforms), so for pure containment the
minimal owner set is exactly the set of maximal charts (minimal_owners).
"""
import math
import numpy as np
from shapely import contains_xy, distance as sdistance, points as spoints
from shapely.affinity import affine_transform
from shapely.geometry import Polygon
from shapely.ops import unary_union

SQ2 = math.sqrt(2.) / 2.
F = np.array([[1., 0.], [0., -1.]])


def _poly(uv):
    p = Polygon(uv)
    return p if p.is_valid else p.buffer(0)


def _rot(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s], [s, c]])


def _period(kind):
    return math.pi if kind == 'axis' else 2 * math.pi


def _adiff(a, b, kind):
    p = _period(kind)
    d = (a - b) % p
    return min(d, p - d)


def owner_directions(chart, orientation_classes, ang_tol=3.):
    """Clusters of owner orientation angles per material: {material: [angle,...]}."""
    out = {}
    for f in chart['faces']:
        v = f.get('orient')
        kind = (orientation_classes or {}).get(f['material'])
        if v is None or kind is None or np.hypot(*v) < 1e-9:
            continue
        a = math.atan2(v[1], v[0])
        lst = out.setdefault(f['material'], [])
        if not any(_adiff(a, b, kind) < math.radians(ang_tol) for b in lst):
            lst.append(a)
    return out


def face_label(face, L, dirs, orientation_classes, ang_tol=3.):
    """material [#semantic tag] [|owner direction index]."""
    base = face['material'] + ('#' + face['tag'] if face.get('tag') else '')
    kind = (orientation_classes or {}).get(face['material'])
    v = face.get('orient')
    if kind is None or v is None or np.hypot(*v) < 1e-9:
        return base
    w = L @ np.asarray(v, float)
    a = math.atan2(w[1], w[0])
    for i, b in enumerate(dirs.get(face['material'], [])):
        if _adiff(a, b, kind) < math.radians(ang_tol):
            return f"{base}|d{i}"
    return f"{base}|unmatched"


def regions(chart, L, dirs, orientation_classes, ang_tol=3.):
    out = {}
    for f in chart['faces']:
        out.setdefault(face_label(f, L, dirs, orientation_classes, ang_tol), []).append(_poly(f['uv']))
    m = [L[0, 0], L[0, 1], L[1, 0], L[1, 1], 0., 0.]
    return {k: affine_transform(unary_union(v), m) for k, v in out.items()}


def principal_axes(chart):
    shape = unary_union([_poly(f['uv']) for f in chart['faces']])
    rect = np.asarray(shape.minimum_rotated_rectangle.exterior.coords)[:4]
    e = rect[1] - rect[0]
    return math.atan2(e[1], e[0]), shape


def _edge_angles(chart, k=6, reflect=False):
    shape = unary_union([_poly(f['uv']) for f in chart['faces']]).simplify(1e-3)
    edges = []
    for poly in getattr(shape, 'geoms', [shape]):
        q = np.asarray(poly.exterior.coords)
        for a, b in zip(q[:-1], q[1:]):
            d = b - a
            if reflect:
                d = F @ d
            edges.append((float(np.hypot(*d)), math.atan2(d[1], d[0])))
    edges.sort(reverse=True)
    return [a for _, a in edges[:k]]


def candidate_rotations(owner, member, allow_reflection, orientation_classes=None, ang_tol=3.):
    """Linear parts L of g. Oriented content fixes L; otherwise align edges/axes."""
    out = []
    odirs = owner_directions(owner, orientation_classes, ang_tol)
    for reflect in ((False, True) if allow_reflection else (False,)):
        # dominant member direction (area weighted) among oriented faces
        best = {}
        for f in member['faces']:
            kind = (orientation_classes or {}).get(f['material'])
            v = f.get('orient')
            if kind is None or v is None or np.hypot(*v) < 1e-9:
                continue
            v = np.asarray(v, float)
            if reflect:
                v = F @ v
            a = math.atan2(v[1], v[0])
            w = _poly(f['uv']).area
            key = None
            for (mat, b) in best:
                if mat == f['material'] and _adiff(a, b, kind) < math.radians(ang_tol):
                    key = (mat, b)
                    break
            key = key or (f['material'], a)
            best[key] = best.get(key, 0.) + w
        angles = []
        if best:
            (mat, am), _ = max(best.items(), key=lambda kv: kv[1])
            kind = orientation_classes[mat]
            for ao in odirs.get(mat, []):
                angles.append(ao - am)
                if kind == 'axis':
                    angles.append(ao - am + math.pi)
        else:
            ao_axis, _ = principal_axes(owner)
            am_axis, _ = principal_axes(member)
            if reflect:
                am_axis = -am_axis
            angles += [ao_axis - am_axis + k * math.pi / 2 for k in range(4)]
            for ea in _edge_angles(owner):
                for eb in _edge_angles(member, reflect=reflect):
                    angles += [ea - eb, ea - eb + math.pi]
        seen = []
        for a in angles:
            a = a % (2 * math.pi)
            if any(min(abs(a - b), 2 * math.pi - abs(a - b)) < 1e-7 for b in seen):
                continue
            seen.append(a)
            out.append((_rot(a) @ F if reflect else _rot(a), reflect))
    return out, odirs


def _grid_mask(geom, x0, y0, nx, ny, pix, grow=0.):
    g = geom.buffer(grow, quad_segs=16) if grow > 0 else geom
    xs = x0 + (np.arange(nx) + .5) * pix
    ys = y0 + (np.arange(ny) + .5) * pix
    return contains_xy(g, xs[None, :], ys[:, None])


def _fft_corr(member, owner):
    """C[t] = sum_x member[x] * owner[x + t] for member placed at owner pixel t."""
    my, mx = member.shape
    oy, ox = owner.shape
    sy, sx = oy + my, ox + mx
    Fm = np.fft.rfft2(member[::-1, ::-1].astype(np.float64), s=(sy, sx))
    Fo = np.fft.rfft2(owner.astype(np.float64), s=(sy, sx))
    c = np.fft.irfft2(Fm * Fo, s=(sy, sx))
    return c[my - 1:oy, mx - 1:ox]


def outside_area(oreg_eps, mreg, t):
    tot = 0.
    for k, g in mreg.items():
        o = oreg_eps.get(k)
        moved = affine_transform(g, [1, 0, 0, 1, t[0], t[1]])
        tot += moved.area if o is None else moved.difference(o).area
    return tot


def _refine(oreg_eps, mreg, t0, step, eps, area_tol):
    """Pattern search on the exact outside area (zero on the feasible set)."""
    t = np.asarray(t0, float)
    f = outside_area(oreg_eps, mreg, t)
    while f > area_tol and step > eps / 16:
        moved = False
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            tt = t + step * np.asarray(d, float)
            ff = outside_area(oreg_eps, mreg, tt)
            if ff < f - 1e-12:
                t, f, moved = tt, ff, True
                break
        if not moved:
            step /= 2
    return t, f


def _clearance_peaks(ok, limit=6):
    """Most interior feasible grid cells (iterated 4-neighbour erosion)."""
    cur = ok.copy()
    last = cur
    while cur.any():
        last = cur
        e = cur.copy()
        e[1:, :] &= cur[:-1, :]; e[:-1, :] &= cur[1:, :]
        e[:, 1:] &= cur[:, :-1]; e[:, :-1] &= cur[:, 1:]
        e[0, :] = e[-1, :] = False; e[:, 0] = e[:, -1] = False
        cur = e
    ys, xs = np.nonzero(last)
    pts = list(zip(ys.tolist(), xs.tolist()))
    if len(pts) > limit:
        idx = np.linspace(0, len(pts) - 1, limit).astype(int)
        pts = [pts[i] for i in idx]
    return pts


def fit(owner, member, eps=.5, allow_reflection=False, orientation_classes=None,
        pix=None, max_raster=700, area_tol=1e-7, ang_tol=3.):
    """Best certified fit of member inside owner (rigid preferred), or None.

    eps / area_tol in working texels / texels^2.
    """
    _, oshape = principal_axes(owner)
    _, mshape = principal_axes(member)
    if mshape.area > oshape.area + eps * oshape.length + 1e-6:
        return None
    ob = oshape.bounds
    ow, oh = ob[2] - ob[0], ob[3] - ob[1]
    if pix is None:
        pix = max(eps, max(ow, oh) / max_raster)
    cands, odirs = candidate_rotations(owner, member, allow_reflection, orientation_classes, ang_tol)
    oreg = regions(owner, np.eye(2), odirs, orientation_classes, ang_tol)
    oreg_eps = {k: g.buffer(eps, quad_segs=16) for k, g in oreg.items()}
    results = []
    for L, reflected in cands:
        mreg = regions(member, L, odirs, orientation_classes, ang_tol)
        if any(k not in oreg for k in mreg):
            continue
        if any(mreg[k].area > oreg_eps[k].area + 1e-6 for k in mreg):
            continue
        mb = unary_union(list(mreg.values())).bounds
        mw, mh = mb[2] - mb[0], mb[3] - mb[1]
        pad = eps + 2 * pix
        ox0, oy0 = ob[0] - pad, ob[1] - pad
        onx = int(math.ceil((ow + 2 * pad) / pix)) + 1
        ony = int(math.ceil((oh + 2 * pad) / pix)) + 1
        mnx = int(math.ceil(mw / pix)) + 1
        mny = int(math.ceil(mh / pix)) + 1
        if mnx > onx or mny > ony:
            continue
        bad = None
        for k, mg in mreg.items():
            mm = _grid_mask(mg, mb[0], mb[1], mnx, mny, pix)
            if not mm.any():
                continue
            om = _grid_mask(oreg[k], ox0, oy0, onx, ony, pix, grow=eps + SQ2 * pix)
            miss = mm.sum() - _fft_corr(mm, om)
            bad = miss if bad is None else bad + miss
        if bad is None:
            continue
        ok = bad < .5
        if not ok.any():
            continue
        for iy, ix in _clearance_peaks(ok):
            t0 = (ox0 + (ix + .5) * pix - (mb[0] + .5 * pix), oy0 + (iy + .5) * pix - (mb[1] + .5 * pix))
            t, f = _refine(oreg_eps, mreg, t0, pix, eps, area_tol)
            if f <= area_tol:
                # centre the fit: shrink eps while the exact test still passes
                bound = eps
                for e in (eps / 2, eps / 4, eps / 8, eps / 16, eps / 64):
                    oe = {k: g.buffer(e, quad_segs=16) for k, g in oreg.items()}
                    t2, f2 = _refine(oe, mreg, t, e, e, area_tol)
                    if f2 > area_tol:
                        break
                    t, bound = t2, e
                results.append(dict(L=L.tolist(), t=t.tolist(), reflected=reflected, hausdorff_bound=bound,
                                    determinant=float(np.linalg.det(L)), outside_area=float(f),
                                    coverage=mshape.area / oshape.area, member_area=mshape.area,
                                    owner_area=oshape.area, pix=pix, eps=eps))
                break
        if results and not results[-1]['reflected'] and results[-1]['hausdorff_bound'] <= eps / 64:
            break
    if not results:
        return None
    return min(results, key=lambda r: (r['reflected'], r['hausdorff_bound'], r['outside_area']))


def transformed_uv(member, res):
    L, t = np.asarray(res['L']), np.asarray(res['t'])
    return {f['id']: (np.asarray(f['uv']) @ L.T + t).tolist() for f in member['faces']}


def verify(owner, member, res, orientation_classes=None, spacing=None, ang_tol=3.):
    """Independent check by dense sampling: every member sample point, mapped by g,
    lies within eps of the owner region carrying the same label. Returns max distance."""
    L, t, eps = np.asarray(res['L']), np.asarray(res['t']), res['eps']
    odirs = owner_directions(owner, orientation_classes, ang_tol)
    owner_by_label = {}
    for f in owner['faces']:
        owner_by_label.setdefault(face_label(f, np.eye(2), odirs, orientation_classes, ang_tol), []).append(_poly(f['uv']))
    owner_by_label = {k: unary_union(v) for k, v in owner_by_label.items()}
    worst = 0.
    for f in member['faces']:
        k = face_label(f, L, odirs, orientation_classes, ang_tol)
        uv = np.asarray(f['uv'], float) @ L.T + t
        poly = _poly(uv)
        b = poly.bounds
        h = spacing or max(.25, max(b[2] - b[0], b[3] - b[1]) / 60)
        xs, ys = np.meshgrid(np.arange(b[0], b[2] + h, h), np.arange(b[1], b[3] + h, h))
        grid = np.column_stack([xs.ravel(), ys.ravel()])
        inside = grid[contains_xy(poly, grid[:, 0], grid[:, 1])]
        # boundary samples, including every corner
        ring = []
        for a, c in zip(uv, np.roll(uv, -1, axis=0)):
            n = max(2, int(np.hypot(*(c - a)) / h) + 1)
            ring.append(a + np.linspace(0, 1, n)[:, None] * (c - a))
        pts = np.vstack([inside] + ring)
        target = owner_by_label.get(k)
        if target is None:
            return float('inf')
        d = sdistance(target, spoints(pts))
        worst = max(worst, float(np.max(d)))
    return worst


def minimal_owners(ids, contains):
    """contains[(o, m)] -> fit.  Owners are the maximal charts under containment.

    Mutual containment keeps the lowest id. Each other chart goes to the smallest
    maximal owner that contains it directly.
    """
    ids = list(ids)

    def inside(m, o):
        return (o, m) in contains
    maximal = [c for c in ids
               if not any(inside(c, o) and (not inside(o, c) or o < c) for o in ids if o != c)]
    assign = {}
    for c in ids:
        if c in maximal:
            continue
        hosts = [o for o in maximal if inside(c, o)]
        assign[c] = min(hosts, key=lambda o: contains[(o, c)]['owner_area']) if hosts else None
    return maximal, assign
