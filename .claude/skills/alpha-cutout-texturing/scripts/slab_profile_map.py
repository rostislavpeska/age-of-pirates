"""Profile map of an extruded alpha slab (background Blender, read-only): per-face page px -> 3D maps, the profile outline
in slab coordinates and the shared edges, for slab_fold.py (one folded parameterisation, seam QA).

    blender -b MODEL.blend --python slab_profile_map.py -- --object OBJECT --out PROFILE_MAP.json [--uv UVMAP] [--size 1024]

The object must be ONE profile extruded straight along the eave: the largest upward face is the top, the two faces whose
normals run along the eave are the end caps, the rest are side faces (underside, back, nose facets). Slab frame: U along
the eave (the top's horizontal edge), Vv up the slope in the top plane, nt the top normal, origin c0 = the top's lower-left
corner (u = 0, s = 0 at the eave lip). Outline: an end cap's points in (s, t), ordered lip -> along the top -> back ->
underside -> nose -> lip (a rounded nose must end at the lip, vertex 0). Worked example: Korean Market stall thatch
(18 vertices, 11 faces: top, back, underside, six 2 cm bullnose facets, two 9-gon caps).
"""
import argparse, json, sys
import bpy
import numpy as np
from mathutils import Vector
ap = argparse.ArgumentParser(); ap.add_argument('--out', required=True); ap.add_argument('--object', required=True)
ap.add_argument('--size', type=int, default=1024); ap.add_argument('--uv', default=None, help='UV map name (default: the active one)')
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])
for s_ in bpy.data.scenes:
    for vl in s_.view_layers:
        vl.update()
o = bpy.data.objects[a.object]; me = o.data; M = o.matrix_world; R3 = M.to_3x3(); ul = (me.uv_layers[a.uv] if a.uv else me.uv_layers.active).data; N = a.size
top = max(me.polygons, key=lambda p: p.area if (R3 @ p.normal).z > .5 else 0)
nt = (R3 @ top.normal).normalized(); U = Vector((0, 0, 1)).cross(nt).normalized(); Vv = nt.cross(U).normalized()
PT = [M @ me.vertices[i].co for i in top.vertices]
c0 = min(PT, key=lambda q: (q.dot(Vv), q.dot(U)))                                       # lower-left corner of the top
u0 = min((q - c0).dot(U) for q in PT); u_len = max((q - c0).dot(U) for q in PT) - u0


def slab(q):
    d = q - c0; return d.dot(U) - u0, d.dot(Vv), d.dot(nt)


faces = []
for p in me.polygons:
    P = [M @ me.vertices[i].co for i in p.vertices]; Y = np.array([(ul[l].uv.x * N, (1 - ul[l].uv.y) * N) for l in p.loop_indices])
    X3 = np.array([tuple(q) for q in P])
    T, *_ = np.linalg.lstsq(np.c_[Y, np.ones(len(Y))], X3, rcond=None); fit = float(np.abs(np.c_[Y, np.ones(len(Y))] @ T - X3).max())
    n = (R3 @ p.normal).normalized(); kind = ('end' if abs(n.dot(U)) > .9 else 'top' if p.index == top.index else
                                           'under' if n.dot(nt) < -.9 else 'back' if n.dot(Vv) > .5 else 'nose')
    faces.append({'face': p.index, 'kind': kind, 'normal': list(n), 'area': p.area, 'uv_px': Y.tolist(), 'px_to_3d': T.tolist(),
                  'fit_m': fit, 'slab': [list(slab(q)) for q in P]})
# profile outline from one end cap, ordered from the lip (s = 0, t = 0) going up the top
end = next(f for f in faces if f['kind'] == 'end'); pts = [(st[1], st[2]) for st in end['slab']]
k0 = min(range(len(pts)), key=lambda i: pts[i][0] ** 2 + pts[i][1] ** 2)
pts = pts[k0:] + pts[:k0]
if pts[1][0] < pts[-1][0]:                                                               # walk towards the back along the top first
    pts = [pts[0]] + pts[1:][::-1]
cum = [0.]
for i in range(1, len(pts) + 1):
    a_, b_ = np.array(pts[i - 1]), np.array(pts[i % len(pts)]); cum.append(cum[-1] + float(np.linalg.norm(b_ - a_)))
edges = {}
for p in me.polygons:
    for e in p.edge_keys:
        edges.setdefault(e, []).append(p.index)
shared = [{'faces': v, 'a': list(M @ me.vertices[e[0]].co), 'b': list(M @ me.vertices[e[1]].co)} for e, v in edges.items() if len(v) == 2]
json.dump({'object': a.object, 'size': N, 'c0': list(c0), 'U': list(U), 'Vv': list(Vv), 'nt': list(nt), 'u0': u0, 'u_len': u_len,
           'outline_st': pts, 'outline_cum': cum, 'faces': faces, 'shared_edges': shared}, open(a.out, 'w'), indent=1)
print('PROFILE_MAP faces', len(faces), {k: sum(1 for f in faces if f['kind'] == k) for k in ('top', 'under', 'back', 'nose', 'end')},
      'u_len %.3f' % u_len, 'perimeter %.3f' % cum[-1], 'shared edges', len(shared), 'max fit %.1e' % max(f['fit_m'] for f in faces))
