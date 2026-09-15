"""Minimal 3D convex hull (incremental) for small point sets - returns hull vertices and
unique face planes (outward unit normal n, offset w with n.p + w = 0 on the plane)."""
import math


def _sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def _cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def _dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def _norm(a):
    l = math.sqrt(_dot(a, a)); return (a[0] / l, a[1] / l, a[2] / l) if l else (0.0, 0.0, 0.0)


def convex_hull(points, eps=1e-6):
    """points: list of (x,y,z). Returns (vertices, planes) with planes as [(nx,ny,nz,w)]"""
    pts = [tuple(map(float, p)) for p in points]
    # initial tetrahedron: extreme points
    p0 = min(pts); p1 = max(pts, key=lambda p: _dot(_sub(p, p0), _sub(p, p0)))
    d = _sub(p1, p0)
    p2 = max(pts, key=lambda p: _dot(_cross(d, _sub(p, p0)), _cross(d, _sub(p, p0))))
    n = _cross(d, _sub(p2, p0))
    p3 = max(pts, key=lambda p: abs(_dot(n, _sub(p, p0))))
    if abs(_dot(n, _sub(p3, p0))) < eps: raise ValueError('degenerate (planar) point set')
    faces = []      # each face: (a, b, c) indices with outward orientation
    idx = {p: i for i, p in enumerate(pts)}
    def add_face(a, b, c, inside):
        nn = _cross(_sub(pts[b], pts[a]), _sub(pts[c], pts[a]))
        if _dot(nn, _sub(inside, pts[a])) > 0: b, c = c, b
        faces.append((a, b, c))
    centroid = tuple(sum(p[i] for p in (p0, p1, p2, p3)) / 4 for i in range(3))
    i0, i1, i2, i3 = idx[p0], idx[p1], idx[p2], idx[p3]
    for tri in ((i0, i1, i2), (i0, i1, i3), (i0, i2, i3), (i1, i2, i3)): add_face(*tri, centroid)
    def normal(f):
        a, b, c = f; return _cross(_sub(pts[b], pts[a]), _sub(pts[c], pts[a]))
    for i, p in enumerate(pts):
        if i in (i0, i1, i2, i3): continue
        visible = [f for f in faces if _dot(normal(f), _sub(p, pts[f[0]])) > eps]
        if not visible: continue
        # horizon edges = edges of visible faces not shared by two visible faces
        edges = {}
        for f in visible:
            for e in ((f[0], f[1]), (f[1], f[2]), (f[2], f[0])):
                key = tuple(sorted(e)); edges[key] = edges.get(key, 0) + 1
        horizon = [e for e, c in edges.items() if c == 1]
        for f in visible: faces.remove(f)
        for e in horizon: add_face(e[0], e[1], i, centroid)
    used = sorted({v for f in faces for v in f})
    verts = [pts[v] for v in used]
    planes = []
    for f in faces:
        nn = _norm(normal(f)); w = -_dot(nn, pts[f[0]])
        if not any(abs(_dot(nn, q[:3]) - 1) < 1e-6 and abs(w - q[3]) < 1e-5 for q in planes):
            planes.append((nn[0], nn[1], nn[2], w))
    return verts, planes
