"""Compare a converter-made model (its FBX) against the vanilla one: vertex positions, normals at coincident
positions, UVs; render the model with studio lighting so shading defects show.

usage: blender -b --python fbx_check.py -- new.fbx vanilla.fbx out_dir
"""
import bpy, sys, os, math
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
new, van, out = args[0], args[1], args[2]
os.makedirs(out, exist_ok=True)


def load(path, prefix):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    objs = [o for o in bpy.data.objects if o not in before]
    P, N, U, L = [], [], [], []
    for o in objs:
        if o.type != 'MESH': continue
        me = o.data; uv = me.uv_layers.active
        M = o.matrix_world; R = M.to_3x3().normalized()
        for poly in me.polygons:
            for li in poly.loop_indices:
                l = me.loops[li]
                P.append(M @ me.vertices[l.vertex_index].co); N.append(R @ l.normal)
                U.append(uv.data[li].uv.copy() if uv else Vector((0, 0))); L.append(o.name)
    for o in objs: o.name = prefix + o.name
    return objs, np.array(P), np.array(N), np.array(U), L


bpy.ops.wm.read_factory_settings(use_empty=True)
vobjs, vP, vN, vU, vL = load(van, 'van_')
nobjs, nP, nN, nU, nL = load(new, 'new_')
sv = float(np.linalg.norm(vP.max(0) - vP.min(0))); sn = float(np.linalg.norm(nP.max(0) - nP.min(0)))
print(f'SCALE vanilla bbox diag {sv:.4f}  new bbox diag {sn:.4f}  ratio new/vanilla {sn / sv:.4f}')
# match by position after bringing both to the same scale
k = sv / sn
grid = {}
for i, p in enumerate(vP): grid.setdefault(tuple(np.round(p / 1e-4).astype(int)), []).append(i)
ang = []; uvd = []; miss = 0
for i, p in enumerate(nP * k):
    key = tuple(np.round(p / 1e-4).astype(int)); js = grid.get(key)
    if not js: miss += 1; continue
    best = None
    for j in js:
        a = math.degrees(math.acos(max(-1.0, min(1.0, float(np.dot(nN[i], vN[j]))))))
        if best is None or a < best[0]: best = (a, j)
    ang.append(best[0]); uvd.append(min(float(np.linalg.norm(nU[i] - vU[j])) for j in js))   # seams: several loops share a position
ang = np.array(ang); uvd = np.array(uvd)
print(f'MATCH {len(ang)} of {len(nP)} loops matched a vanilla loop by position; unmatched {miss}')
print(f'NORMALS angle to vanilla: median {np.median(ang):.2f} deg, 95% {np.percentile(ang, 95):.2f}, max {ang.max():.2f}; >5deg: {(ang > 5).sum()}')
print(f'UVS distance to vanilla: median {np.median(uvd):.4f}, max {uvd.max():.4f}; >0.01: {(uvd > 0.01).sum()}')

# renders of the new model only (studio light, per-object colours)
for o in vobjs: o.hide_render = True
sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'MATERIAL'; sc.display.shading.show_shadows = False
sc.render.resolution_x = 1600; sc.render.resolution_y = 900
allP = nP; lo, hi = allP.min(0), allP.max(0); centre = Vector(((lo + hi) / 2).tolist()); size = float(np.linalg.norm(hi - lo))
cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = size * 1.05
camobj = bpy.data.objects.new('cam', cam); sc.collection.objects.link(camobj); sc.camera = camobj
for name, dv in (('new_side.png', (-1, 0, 0)), ('new_quarter.png', (-1, 1, -0.6))):
    d = Vector(dv).normalized(); camobj.location = centre - d * size * 2; camobj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(out, name); bpy.ops.render.render(write_still=True); print('RENDER', name)
