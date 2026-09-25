"""Conservative surface-audit primitives; no mesh mutation or automatic deletion.

Normals are geometric, Z is up, camera directions point toward the viewer.
Convex certificates apply to a verified opaque render shell, never its collision hull.
"""
from collections import defaultdict

import numpy as np


def camera_cone_max_dot(normals, elevation_min=30.0, elevation_max=60.0):
    """Analytic max(n dot view) over ALL azimuths and a closed elevation interval.

    Nonzero normals are normalized; zero normals return NaN (not removable).
    This proves orientation exclusion only, not shadow/AO/damage safety.
    """
    if not -90 <= elevation_min <= elevation_max <= 90:
        raise ValueError("Require -90 <= elevation_min <= elevation_max <= 90")
    n = np.asarray(normals, dtype=float)
    length = np.linalg.norm(n, axis=-1, keepdims=True)
    n = np.divide(n, length, out=np.full_like(n, np.nan), where=length > 0)
    h = np.linalg.norm(n[..., :2], axis=-1)
    lo, hi = np.radians([elevation_min, elevation_max])
    e = np.clip(np.arctan2(n[..., 2], h), lo, hi)
    return h * np.cos(e) + n[..., 2] * np.sin(e)


def triangle_geometry(triangles):
    t = np.asarray(triangles, dtype=float)
    cross = np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0])
    length = np.linalg.norm(cross, axis=1)
    normals = np.divide(cross, length[:, None], out=np.zeros_like(cross),
                        where=length[:, None] > 1e-14)
    return normals, length / 2


def mesh_components(triangles, tolerance=0):
    """Edge-connected components and geometric edge incidence.

    Exact positional weld by default. Nonzero tolerance is a rounded-grid
    diagnostic, NOT proof that gaps are absent. UV/normal splits are ignored.
    Call separately per rigid damage piece.
    """
    t = np.asarray(triangles, dtype=float)
    p = t.reshape(-1, 3)
    keys = np.round(p / tolerance).astype(np.int64) if tolerance else p
    _, inverse = np.unique(keys, axis=0, return_inverse=True)
    ids = inverse.reshape(-1, 3)
    edge_faces = defaultdict(list)
    parents = list(range(len(t)))

    def root(i):
        while parents[i] != i:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i

    for i, f in enumerate(ids):
        for a, b in zip(f, np.roll(f, -1)):
            if a != b:
                edge_faces[tuple(sorted((int(a), int(b))))].append(i)
    for faces in edge_faces.values():
        for j in faces[1:]:
            parents[root(j)] = root(faces[0])
    components = defaultdict(list)
    for i in range(len(t)):
        components[root(i)].append(i)
    return list(components.values()), edge_faces, ids


def convex_render_shell(triangles, numeric_tolerance=1e-8):
    """Validate a connected, exactly welded, outward, convex triangle shell.

    Returns supporting planes or None. Does not repair or take the convex hull
    of a nonconvex mesh. Requires one closed manifold component and positive
    volume. A certificate remains conditional on opaque, persistent geometry.
    """
    t = np.asarray(triangles, dtype=float)
    if len(t) < 4 or not np.isfinite(t).all():
        return None
    comps, edges, ids = mesh_components(t)
    n, area = triangle_geometry(t)
    if len(comps) != 1 or np.any(area <= 1e-14) or any(len(f) != 2 for f in edges.values()):
        return None
    directions = defaultdict(list)
    for f in ids:
        for a, b in zip(f, np.roll(f, -1)):
            directions[tuple(sorted((int(a), int(b))))].append(1 if a < b else -1)
    if any(sum(signs) != 0 for signs in directions.values()):
        return None
    volume = np.einsum('ij,ij->i', t[:, 0], np.cross(t[:, 1], t[:, 2])).sum() / 6
    if volume <= numeric_tolerance ** 3:
        return None
    offsets = -np.einsum('ij,ij->i', n, t[:, 0])
    p = np.unique(t.reshape(-1, 3), axis=0)
    if np.max(p @ n.T + offsets) > numeric_tolerance:
        return None
    return n, offsets


def strictly_inside(triangles, shell_planes, clearance=1e-4):
    """Complete-triangle containment by convexity; excludes touching faces."""
    if clearance <= 0:
        raise ValueError('A positive clearance is required')
    t = np.asarray(triangles, dtype=float)
    if shell_planes is None:
        return np.zeros(len(t), dtype=bool)
    n, offsets = shell_planes
    distances = t.reshape(-1, 3) @ n.T + offsets
    return (distances.max(axis=1).reshape(-1, 3).max(axis=1) < -clearance)


def persistent_burial_mask(triangles, shell_planes, *, opaque,
                           same_rigid_motion, shell_retained, clearance=1e-4):
    """All three semantic preconditions must be established by the caller.

    This guarantees external ray occlusion within the numeric tolerance model,
    not closed fracture-source topology or behavior of volume-dependent shaders.
    """
    if not (opaque and same_rigid_motion and shell_retained):
        return np.zeros(len(triangles), dtype=bool)
    return strictly_inside(triangles, shell_planes, clearance)

