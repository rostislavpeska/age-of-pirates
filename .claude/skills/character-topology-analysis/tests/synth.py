"""Synthetic meshes with known answers for the character-topology-analysis tests (pure numpy, no third-party data).

Every builder returns (V, faces) with V as float (n, 3) and faces as lists of vertex ids, Z up.
"""
import math

import numpy as np


def grid(nx=4, ny=3, size=1.0):
    """an open nx x ny quad grid in the XZ plane (facing -Y). Known: (nx)(ny) quads, 1 boundary loop of 2(nx+ny)
    vertices, every inner vertex valence 4, no pole."""
    V = np.array([[i * size / nx, 0.0, j * size / ny] for j in range(ny + 1) for i in range(nx + 1)], float)
    F = []
    for j in range(ny):
        for i in range(nx):
            a = j * (nx + 1) + i
            F.append([a, a + 1, a + nx + 2, a + nx + 1])
    return V, F


def cube(size=1.0):
    """a closed cube of 6 quads. Known: 8 vertices of valence 3 (8 poles), 3 closed face rings of 4, closed manifold."""
    s = size / 2
    V = np.array([[x, y, z] for z in (-s, s) for y in (-s, s) for x in (-s, s)], float)
    F = [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
    return V, F


def tube(n=8, rows=6, radius=0.1, length=1.0, axis=(0, 0, 1), origin=(0, 0, 0), caps=None):
    """an open tube along axis: n sides, rows face rows, rows+1 vertex rings. Known: n x rows quads, 2 boundary loops of
    n, rows-1 inner closed edge rings of n sides, n closed... face rings: rows closed strips of n faces.
    caps='ngon' closes both ends with one n-gon each, caps='fan' with a triangle fan around a centre vertex."""
    a = np.asarray(axis, float)
    a = a / np.linalg.norm(a)
    ref = np.array([1.0, 0, 0]) if abs(a[0]) < 0.9 else np.array([0, 1.0, 0])
    u = np.cross(a, ref)
    u /= np.linalg.norm(u)
    w = np.cross(a, u)
    o = np.asarray(origin, float)
    V = []
    for j in range(rows + 1):
        for i in range(n):
            th = 2 * math.pi * i / n
            V.append(o + a * length * j / rows + radius * (math.cos(th) * u + math.sin(th) * w))
    F = []
    for j in range(rows):
        for i in range(n):
            a0 = j * n + i
            a1 = j * n + (i + 1) % n
            F.append([a0, a1, a1 + n, a0 + n])
    V = np.array(V, float)
    if caps == 'ngon':
        F.append(list(range(n))[::-1])
        F.append([rows * n + i for i in range(n)])
    elif caps == 'fan':
        c0 = len(V)
        c1 = c0 + 1
        V = np.vstack([V, o, o + a * length])
        for i in range(n):
            F.append([c0, (i + 1) % n, i])
            F.append([c1, rows * n + i, rows * n + (i + 1) % n])
    return V, F


def quad_sphere(div=3, radius=1.0, centre=(0, 0, 0)):
    """a cube subdivided div x div per side and pushed onto a sphere. Known: all quads, closed, exactly 8 valence-3
    poles (the cube corners), every other vertex valence 4."""
    pts, idx, F = [], {}, []

    def vid(p):
        k = tuple(np.round(p, 9))
        if k not in idx:
            idx[k] = len(pts)
            pts.append(p)
        return idx[k]
    for axis in range(3):
        for sgn in (-1, 1):
            for i in range(div):
                for j in range(div):
                    quad = []
                    for di, dj in ((0, 0), (1, 0), (1, 1), (0, 1)):
                        uu = -1 + 2 * (i + di) / div
                        vv = -1 + 2 * (j + dj) / div
                        p = np.zeros(3)
                        p[axis] = sgn
                        p[(axis + 1) % 3] = uu
                        p[(axis + 2) % 3] = vv
                        quad.append(vid(p))
                    if sgn < 0:
                        quad = quad[::-1]
                    F.append(quad)
    V = np.array(pts, float)
    V = V / np.linalg.norm(V, axis=1)[:, None] * radius + np.asarray(centre, float)
    return V, F


def uv_sphere(n=12, rings=8, radius=1.0, centre=(0, 0, 0)):
    """a UV sphere with triangle fans at both poles. Known: 2 vertices of valence n (6+ poles when n >= 6)."""
    c = np.asarray(centre, float)
    V = [c + [0, 0, radius]]
    for j in range(1, rings):
        ph = math.pi * j / rings
        for i in range(n):
            th = 2 * math.pi * i / n
            V.append(c + radius * np.array([math.sin(ph) * math.cos(th), math.sin(ph) * math.sin(th), math.cos(ph)]))
    V.append(c + [0, 0, -radius])
    V = np.array(V, float)
    F = []
    for i in range(n):
        F.append([0, 1 + i, 1 + (i + 1) % n])
    for j in range(rings - 2):
        for i in range(n):
            a0 = 1 + j * n + i
            a1 = 1 + j * n + (i + 1) % n
            F.append([a0, a0 + n, a1 + n, a1])
    last = len(V) - 1
    base = 1 + (rings - 2) * n
    for i in range(n):
        F.append([last, base + (i + 1) % n, base + i])
    return V, F


def bowtie():
    """two triangles sharing one vertex only. Known: 1 bow-tie vertex, 2 boundary loops through it (open chains)."""
    V = np.array([[0, 0, 0], [1, 0, 0], [0.5, 0, 1], [-1, 0, 0], [-0.5, 0, -1]], float)
    return V, [[0, 1, 2], [0, 3, 4]]


def fin():
    """three quads sharing one edge. Known: 1 non-manifold edge (3 faces)."""
    V = np.array([[0, 0, 0], [0, 0, 1], [1, 0, 0], [1, 0, 1], [-1, 0, 0], [-1, 0, 1], [0, 1, 0], [0, 1, 1]], float)
    return V, [[0, 2, 3, 1], [1, 5, 4, 0], [0, 1, 7, 6]]


def flipped_pair():
    """two quads sharing an edge with opposite winding. Known: 1 flipped edge."""
    V = np.array([[0, 0, 0], [1, 0, 0], [1, 0, 1], [0, 0, 1], [2, 0, 0], [2, 0, 1]], float)
    return V, [[0, 1, 2, 3], [1, 2, 5, 4]]


def concave_quad():
    """one dart (arrowhead) quad: the corner at (0.5, 0, 0.3) is reflex. Known: 1 concave quad."""
    V = np.array([[0, 0, 0], [0.5, 0, 0.3], [1, 0, 0], [0.5, 0, 1]], float)
    return V, [[0, 1, 2, 3]]


def mirrored_grid(nx=4, ny=3):
    """a grid centred on x = 0 with a centre column: mirror-exact. Known: partner share 1, centre vertices exact."""
    V, F = grid(nx, ny)
    V[:, 0] -= 0.5
    return V, F


def stacked_cards(gap=1e-3):
    """two parallel quads gap apart (x bbox diagonal ~ 1.4): the weld rule (1e-6 x diagonal) must not fuse them."""
    V = np.array([[0, 0, 0], [1, 0, 0], [1, 0, 1], [0, 0, 1]], float)
    W = V + [0, gap, 0]
    return np.vstack([V, W]), [[0, 1, 2, 3], [4, 5, 6, 7]]


def split_grid(nx=3, ny=2):
    """a grid exported with every face owning its own vertices (a UV-split export). Known: the weld recovers the
    (nx+1)(ny+1) shared vertices."""
    V, F = grid(nx, ny)
    NV, NF = [], []
    for f in F:
        NF.append(list(range(len(NV), len(NV) + len(f))))
        NV.extend(V[f])
    return np.array(NV, float), NF


def triangulate_fan(faces):
    """fan-triangulate each polygon from its first corner, in face order (the glTF export order D14 reads back)."""
    T = []
    for f in faces:
        for k in range(1, len(f) - 1):
            T.append([f[0], f[k], f[k + 1]])
    return np.array(T, np.int64)


def two_segment_limb(n=8, rows=10, radius=0.08, length=1.0):
    """an open tube along +Z from z = 0 to z = length, rows face rows, with a given two-segment skeleton (upper 0-0.5,
    lower 0.5-1.0). Returns V, F, joints {'a': [0,0,0], 'b': [0,0,0.5], 'c': [0,0,1]}."""
    V, F = tube(n=n, rows=rows, radius=radius, length=length)
    return V, F, dict(a=[0, 0, 0.0], b=[0, 0, 0.5 * length], c=[0, 0, length])


def permute(V, F, seed=0, faces_too=True):
    """the same mesh with renumbered vertices (and shuffled face order and rotated face starts when faces_too)."""
    rng = np.random.default_rng(seed)
    perm = rng.permutation(len(V))
    inv = np.empty_like(perm)
    inv[perm] = np.arange(len(V))
    NV = V[perm]
    NF = [[int(inv[v]) for v in f] for f in F]
    if faces_too:
        order = rng.permutation(len(NF))
        NF = [NF[k] for k in order]
        NF = [f[k:] + f[:k] for f, k in zip(NF, rng.integers(0, 4, len(NF)))]
    return NV, NF
