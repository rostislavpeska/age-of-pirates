"""Background render of pose_sim.py OBJ files (z up) with their BaseColor PNGs: side, three-quarter and other side.

    blender -b --factory-startup --python render_obj.py -- OUT_PREFIX MODEL.obj MODEL.png [MOUNT.obj MOUNT.png ...]

Keep the PNG paths short: Blender on Windows cannot open image paths over 260 characters ("No such file").
"""
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
prefix, pairs = args[0], list(zip(args[1::2], args[2::2]))
bpy.ops.wm.read_factory_settings(use_empty=True)
for obj, png in pairs:
    mat = bpy.data.materials.new(os.path.basename(png))
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(png, check_existing=True)
    mat.node_tree.links.new(tex.outputs['Color'], mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=obj, forward_axis='Y', up_axis='Z')
    for o in set(bpy.data.objects) - before:
        o.data.materials.clear()
        o.data.materials.append(mat)
pts = [o.matrix_world @ v.co for o in bpy.data.objects if o.type == 'MESH' for v in o.data.vertices]
lo = Vector([min(p[i] for p in pts) for i in range(3)])
hi = Vector([max(p[i] for p in pts) for i in range(3)])
c, size = (lo + hi) / 2, max(hi - lo)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'
sc.display.shading.color_type = 'TEXTURE'
sc.view_settings.view_transform = 'Standard'
sc.render.resolution_x = sc.render.resolution_y = 800
sc.world = bpy.data.worlds.new('w')
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = 'ORTHO'
cam.data.ortho_scale = size * 1.05
cam.data.clip_start, cam.data.clip_end = size * 0.01, size * 100
for label, az, el in (('side', 90, 0.05), ('threequarter', 35, 0.2), ('otherside', 270, 0.05)):
    r = math.radians(az)
    cam.location = c + Vector((math.sin(r), -math.cos(r), el)).normalized() * size * 3
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = '%s_%s.png' % (prefix, label)
    bpy.ops.render.render(write_still=True)
print('RENDERED', prefix)
