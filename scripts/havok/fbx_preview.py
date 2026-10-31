"""Render an FBX (e.g. the converter's export of a built gr2) with one colour per mesh object -
a visual check of what the converter actually wrote. usage: blender -b --python fbx_preview.py -- model.fbx out_prefix"""
import bpy, sys, os
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
fbx, prefix = args[0], args[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
print('MESHES', [(o.name, len(o.data.vertices), [g.name for g in o.vertex_groups]) for o in meshes])
print('BONES', [(a.name, len(a.data.bones)) for a in arms])
palette = [(1,0,0,1),(0,0.9,0,1),(0.1,0.4,1,1),(1,0.85,0,1),(1,0,1,1),(0,1,1,1),(1,0.5,0,1),(0.6,0,1,1),(0.5,1,0.5,1),(0.6,0.3,0,1),(0,0.5,0.5,1),(1,0.6,0.8,1)]
for i, o in enumerate(sorted(meshes, key=lambda o: o.name)):
    o.color = (0.6, 0.6, 0.6, 1) if o.name.startswith('spc_') else palette[i % len(palette)]
sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'FLAT'; sc.display.shading.color_type = 'OBJECT'
sc.render.resolution_x = 1600; sc.render.resolution_y = 900
cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; camobj = bpy.data.objects.new('cam', cam); sc.collection.objects.link(camobj); sc.camera = camobj
allP = np.array([o.matrix_world @ v.co for o in meshes for v in o.data.vertices]); lo, hi = allP.min(0), allP.max(0)
centre = Vector(((lo + hi) / 2).tolist()); size = float(np.linalg.norm(hi - lo)); cam.ortho_scale = size * 1.05
print('BBOX world', lo.round(4).tolist(), hi.round(4).tolist())
for name, d in [('side', (-1, 0, 0)), ('top', (0, 0, -1)), ('quarter', (-1, 1, -0.6))]:
    d = Vector(d).normalized(); camobj.location = centre - d * size * 2; camobj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = f'{prefix}_{name}.png'; bpy.ops.render.render(write_still=True); print('RENDER', sc.render.filepath)
