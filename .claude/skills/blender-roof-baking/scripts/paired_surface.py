"""Read-only probes on saved triangle geometry, independent of UV adjacency.

Audit: 2026-10-13-roof-consulate-valley-03 (KTC-377).
This is a bounded probe helper, not automatic ridge/valley discovery or a release
gate. Triangles and corner normals must already share one physical frame.
Pixel sampling belongs to texture-corner-seams/seam_monitor.py.
"""
from collections import defaultdict
import numpy as np


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
