"""Phase 1a - find the sails inside the welded vanilla Treasure Ship mesh.
Imports the converter's FBX, splits the big mesh into loose parts, prints a table of the parts
(size, height, planarity) and renders preview images with the candidate sails highlighted.

usage: blender -b --python sails_analyze.py -- model.fbx out_dir
"""
import bpy, sys, os, math, json
import numpy as np
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index('--') + 1:]
fbx, out = args[0], args[1]
os.makedirs(out, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
objs = [o for o in bpy.data.objects if o.type == 'MESH']
arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
print('IMPORTED meshes:', [(o.name, len(o.data.vertices), [m.name if m else None for m in o.data.materials]) for o in objs])
print('IMPORTED armatures:', [(a.name, [b.name for b in a.data.bones]) for a in arms])
for o in objs:
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    print(f'  {o.name}: world bbox {tuple(round(x,2) for x in lo)} .. {tuple(round(x,2) for x in hi)}  scale {tuple(round(x,3) for x in o.scale)}')

# split every big welded mesh (hull, sails+rigging) into loose parts
main = max(objs, key=lambda o: len(o.data.vertices))
for src in [o for o in objs if len(o.data.vertices) >= 1000]:
    bpy.ops.object.select_all(action='DESELECT')
    src.select_set(True); bpy.context.view_layer.objects.active = src
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.separate(type='LOOSE'); bpy.ops.object.mode_set(mode='OBJECT')
    print('LOOSE parts from', src.name, ':', len([o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith(src.name)]))
parts = [o for o in bpy.data.objects if o.type == 'MESH']

rows = []
for o in parts:
    P = np.array([o.matrix_world @ v.co for v in o.data.vertices])
    if len(P) < 3: continue
    lo, hi = P.min(0), P.max(0); c = P.mean(0)
    # planarity: PCA extents of the point cloud
    Q = P - c; s = np.linalg.svd(Q, compute_uv=False) / math.sqrt(len(P))
    ext = 2 * s                                     # ~ extents along principal axes
    area = 0.0
    for poly in o.data.polygons: area += poly.area
    rows.append(dict(name=o.name, nv=len(P), lo=lo.round(2).tolist(), hi=hi.round(2).tolist(), c=c.round(2).tolist(),
                     ext=ext.round(2).tolist(), thin=float(ext[2] / max(ext[0], 1e-6)), area=round(area, 2), mats=[m.name for m in o.data.materials if m]))
rows.sort(key=lambda r: -r['area'])
zmax = max(r['hi'][2] for r in rows); zmin = min(r['lo'][2] for r in rows)
print(f'Z range of the ship: {zmin:.2f} .. {zmax:.2f}')
print(f"{'part':34} {'nv':>6} {'area':>8} {'thin':>6} {'ext0':>6} {'ext1':>6} {'ext2':>6}  centre               zlo..zhi")
for r in rows[:60]:
    print(f"{r['name']:34} {r['nv']:6d} {r['area']:8.2f} {r['thin']:6.3f} {r['ext'][0]:6.2f} {r['ext'][1]:6.2f} {r['ext'][2]:6.2f}  {str(r['c']):20} {r['lo'][2]:.2f}..{r['hi'][2]:.2f}")

# candidate sails: big, thin, sitting in the upper half of the ship
zmid = zmin + 0.35 * (zmax - zmin)
cands = [r for r in rows if r['thin'] < 0.2 and r['area'] > 0.02 * rows[0]['area'] and r['c'][2] > zmid and r['nv'] >= 20]
print('CANDIDATES:', [(r['name'], r['nv'], r['area']) for r in cands])
json.dump(dict(rows=rows, cands=[r['name'] for r in cands], main=main.name), open(os.path.join(out, 'parts.json'), 'w'), indent=1)

# preview renders: workbench, object colours (candidates coloured, rest grey)
palette = [(1,0,0,1),(0,0.8,0,1),(0,0.3,1,1),(1,0.8,0,1),(1,0,1,1),(0,1,1,1),(1,0.5,0,1),(0.5,0,1,1),(0.5,1,0,1),(1,0.4,0.6,1),(0.2,0.6,0.4,1),(0.7,0.3,0,1)]
for o in bpy.data.objects:
    if o.type == 'MESH': o.color = (0.55, 0.55, 0.55, 1)
legend = []
for i, r in enumerate(cands):
    col = palette[i % len(palette)]; bpy.data.objects[r['name']].color = col; legend.append((r['name'], col[:3]))
print('LEGEND:', legend)

sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'OBJECT'; sc.display.shading.show_shadows = False
sc.render.resolution_x = 1600; sc.render.resolution_y = 900; sc.render.film_transparent = False
allP = np.array([o.matrix_world @ v.co for o in bpy.data.objects if o.type == 'MESH' for v in o.data.vertices])
lo, hi = allP.min(0), allP.max(0); centre = Vector(((lo + hi) / 2).tolist()); size = float(np.linalg.norm(hi - lo))
cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = size * 1.05
camobj = bpy.data.objects.new('cam', cam); sc.collection.objects.link(camobj); sc.camera = camobj

def shot(name, direction, up=Vector((0, 0, 1))):
    d = Vector(direction).normalized()
    camobj.location = centre - d * size * 2
    camobj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(out, name)
    bpy.ops.render.render(write_still=True)
    print('RENDER', sc.render.filepath)

shot('side.png', (-1, 0, 0))            # from -X looking +X
shot('side2.png', (1, 0, 0))
shot('front.png', (0, 1, 0))
shot('quarter.png', (-1, 1, -0.6))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, 'split.blend'))
print('SAVED', os.path.join(out, 'split.blend'))
