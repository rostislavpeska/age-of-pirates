"""Read-only probes on saved triangle geometry, independent of UV adjacency.

Audit: 2026-10-13-roof-consulate-valley-03 (KTC-377).
This is a bounded probe helper, not automatic ridge/valley discovery or a release
gate. Triangles and corner normals must already share one physical frame.
Pixel sampling belongs to texture-corner-seams/seam_monitor.py.

Declared boundary registration: audit 2026-10-13-codex-roof-pattern-104.
This adds geometric correspondence, not atlas painting or automatic discovery.
"""
from collections import defaultdict
import numpy as np


def register_boundary(path, edges, edge_uv, *, tolerance):
    """Register one side of a declared seam to a shared 3D polyline.

    Inputs are path[M,3], physical edges[N,2,3], and their UVs[N,2,2].
    Top and end-strip callers use the SAME path and units, independently.
    Split vertices, reversed edges and unequal subdivisions are supported.
    Every physical edge must lie on the path and the side must cover it once.
    Tolerance is a caller-declared physical distance, not a UV snap radius.
    No nearest-surface fallback: ambiguous projection, gaps and overlaps fail.
    Page/material identities remain the consuming adapter's responsibility.
    """
    path, edges, edge_uv = (np.asarray(v, dtype=float) for v in (path, edges, edge_uv))
    if (path.ndim != 2 or path.shape[1:] != (3,) or len(path) < 2
            or edges.ndim != 3 or edges.shape[1:] != (2, 3) or not len(edges)
            or edge_uv.shape != (len(edges), 2, 2)
            or not all(np.isfinite(v).all() for v in (path, edges, edge_uv))
            or not np.isfinite(tolerance) or tolerance <= 0):
        raise ValueError('Invalid boundary arrays or physical tolerance')
    delta = np.diff(path, axis=0)
    length = np.linalg.norm(delta, axis=1)
    if np.any(length <= tolerance):
        raise ValueError('Degenerate or unresolved path segment')
    path_s = np.r_[0., np.cumsum(length)]
    edge_s = np.empty((len(edges), 2))
    worst = 0.
    for ei, edge in enumerate(edges):
        for vi, point in enumerate(edge):
            t = np.clip(np.sum((point - path[:-1]) * delta, axis=1) / length**2, 0, 1)
            distance = np.linalg.norm(path[:-1] + t[:, None] * delta - point, axis=1)
            near = distance <= tolerance
            if not near.any():
                raise ValueError('Boundary endpoint is off the declared path')
            candidates = path_s[:-1][near] + t[near] * length[near]
            if np.ptp(candidates) > 2 * tolerance:
                raise ValueError('Ambiguous boundary projection')
            best = np.argmin(distance)
            edge_s[ei, vi] = path_s[best] + t[best] * length[best]
            worst = max(worst, float(distance[best]))
        a, b = sorted(edge_s[ei])
        physical_length = np.linalg.norm(edge[1] - edge[0])
        if b - a <= tolerance or physical_length <= tolerance:
            raise ValueError('Degenerate boundary edge')
        # Endpoint agreement alone would admit a straight chord across a bend.
        inside = path[(path_s > a) & (path_s < b)]
        if len(inside):
            v = edge[1] - edge[0]
            t = np.clip((inside - edge[0]) @ v / (v @ v), 0, 1)
            error = np.linalg.norm(inside - edge[0] - t[:, None] * v, axis=1)
            if np.max(error) > tolerance:
                raise ValueError('Boundary edge cuts across a path bend')
            worst = max(worst, float(np.max(error)))
        if abs((b - a) - physical_length) > 2 * tolerance:
            raise ValueError('Boundary arclength and physical length disagree')
        if np.linalg.norm(edge_uv[ei, 1] - edge_uv[ei, 0]) < 1e-12:
            raise ValueError('Collapsed boundary UV edge')
    spans = np.sort(edge_s, axis=1)
    order = np.argsort(spans[:, 0])
    spans = spans[order]
    if abs(spans[0, 0]) > tolerance or abs(spans[-1, 1] - path_s[-1]) > tolerance:
        raise ValueError('Boundary does not cover both path endpoints')
    joins = spans[1:, 0] - spans[:-1, 1]
    if np.any(joins > tolerance):
        raise ValueError('Gap in boundary coverage')
    if np.any(joins < -tolerance):
        raise ValueError('Overlapping boundary coverage')
    return dict(path=path.copy(), path_s=path_s, edge_s=edge_s,
                edge_uv=edge_uv.copy(), tolerance=float(tolerance),
                maximum_residual=worst)


def boundary_uv(binding, arclength):
    """Map shared physical arclengths independently into this side's UVs.

    Returns sample index, local edge index, UV. All endpoint readers are kept:
    a UV split within one side can give TWO results for one physical location.
    Consumers must check both, not average or silently choose one. This is
    mathematical edge correspondence; filtered texel footprints are separate.
    """
    s = np.asarray(arclength, float)
    end = binding['path_s'][-1]
    tol = binding['tolerance']
    if s.ndim != 1 or not len(s) or not np.isfinite(s).all() or np.any(s < 0) or np.any(s > end):
        raise ValueError('Probe arclength outside declared path')
    edge_s = binding['edge_s']
    lo, hi = edge_s.min(1), edge_s.max(1)
    sample, edge = np.nonzero((s[:, None] >= lo - tol) & (s[:, None] <= hi + tol))
    if len(np.unique(sample)) != len(s):
        raise ValueError('Probe falls in an uncovered interval')
    t = np.clip((s[sample] - edge_s[edge, 0]) / np.diff(edge_s, axis=1)[edge, 0], 0, 1)
    uv = binding['edge_uv'][edge]
    return dict(sample=sample, edge=edge, uv=uv[:, 0] * (1-t[:, None]) + uv[:, 1] * t[:, None])


def exact_edge_pairs(co, uv, selected=None, decimals=6):
    """Pair coincident full edges, including duplicated vertices/split objects.

    Output retains triangle and endpoint indices. More than two incident sides
    are ambiguous and returned separately. Partial overlaps are unsupported.
    Rounding is a declared coordinate quantization, not source welding.
    """
    co = np.asarray(co, float); uv = np.asarray(uv, float)
    if co.shape != (len(co), 3, 3) or uv.shape != (len(co), 3, 2):
        raise ValueError('Expected co[N,3,3] and uv[N,3,2]')
    selected = np.ones(len(co), bool) if selected is None else np.asarray(selected, bool)
    edges = defaultdict(list)
    for ti in np.flatnonzero(selected):
        for a, b in ((0, 1), (1, 2), (2, 0)):
            ka, kb = tuple(np.round(co[ti, a], decimals)), tuple(np.round(co[ti, b], decimals))
            if ka == kb:
                continue
            if kb < ka:
                ka, kb, a, b = kb, ka, b, a
            edges[(ka, kb)].append((int(ti), a, b))
    pairs, ambiguous = [], []
    for edge, sides in edges.items():
        if len(sides) > 2:
            ambiguous.append({'edge': edge, 'sides': sides})
        elif len(sides) == 2:
            i, a, b = sides[0]; j, c, d = sides[1]
            pairs.append({'edge': np.asarray(edge), 'sides': sides,
                          'uv': np.array([uv[i, [a, b]], uv[j, [c, d]]]),
                          'uv_gap': float(np.max(np.linalg.norm(uv[i, [a, b]] - uv[j, [c, d]], axis=1)))})
    return pairs, ambiguous


def barycentric(co, points):
    """Least-squares triangle coordinates; also return physical plane residual."""
    co = np.asarray(co, float); points = np.asarray(points, float)
    basis = np.column_stack((co[1] - co[0], co[2] - co[0]))
    if np.linalg.matrix_rank(basis) != 2:
        raise ValueError('Degenerate physical triangle')
    ab = (points - co[0]) @ np.linalg.pinv(basis).T
    w = np.column_stack((1 - ab.sum(1), ab))
    return w, np.linalg.norm(points - w @ co, axis=1)


def edge_probes(co, edge_indices, fractions, depth):
    """Offset paired edge points toward triangle interior by physical metres.

    Returns points and valid barycentric weights. A probe too deep for a narrow
    triangle is invalid; callers must count it, never silently use an exterior.
    """
    a, b = edge_indices; co = np.asarray(co, float)
    e = co[b] - co[a]; e /= np.linalg.norm(e)
    inward = co.mean(0) - (co[a] + co[b]) / 2
    inward -= e * (inward @ e); inward /= np.linalg.norm(inward)
    p = co[a] + np.asarray(fractions)[:, None] * (co[b] - co[a]) + depth * inward
    w, residual = barycentric(co, p)
    return p, w, (w >= -1e-7).all(1) & (residual < 1e-6)


def normal_to_physical(co, uv, corner_normals, weights, encoded):
    """Decode RGB [0,1] tangent normals into the shared physical frame.

    Smooth corner normals are interpolated, U tangent orthogonalized, and
    handedness derives from the V derivative. Handles rotated/mirrored charts.
    Requires standard +Y tangent convention; adapters must decode runtime flips.
    This does not claim a MikkTSpace recalculation for arbitrary smooth meshes.
    """
    co = np.asarray(co, float); uv = np.asarray(uv, float)
    duv = np.array([uv[1] - uv[0], uv[2] - uv[0]])
    if abs(np.linalg.det(duv)) < 1e-12:
        raise ValueError('Degenerate UV triangle')
    dpdu, dpdv = np.linalg.solve(duv, np.array([co[1] - co[0], co[2] - co[0]]))
    n = np.asarray(weights) @ np.asarray(corner_normals, float)
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    t = dpdu - n * (n @ dpdu)[:, None]
    t /= np.maximum(np.linalg.norm(t, axis=1, keepdims=True), 1e-12)
    b = np.cross(n, t); sign = np.where(b @ dpdv < 0, -1, 1)
    b *= sign[:, None]
    v = np.asarray(encoded)[..., :3] * 2 - 1
    result = t * v[:, :1] + b * v[:, 1:2] + n * v[:, 2:3]
    result /= np.maximum(np.linalg.norm(result, axis=1, keepdims=True), 1e-12)
    return result
