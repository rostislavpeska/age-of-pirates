"""Round-trip calibration: import the converter's FBX and export it again unchanged with two
candidate FBX settings, so the gr2 made from each can be compared with the vanilla GXO
(scale / axes). Also prints the old base's armature (bone heads in Blender space) so the
extra bones can be re-created with the same conventions.

usage: blender -b --python sails_roundtrip.py -- vanilla_intact.fbx old_base.fbx out_dir
"""
import bpy, sys, os
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
fbx, oldfbx, out = args[0], args[1], args[2]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
for o in bpy.data.objects:
    print('OBJ', o.name, o.type, 'parent', o.parent.name if o.parent else None, o.parent_type, o.parent_bone,
          'loc', tuple(round(x, 4) for x in o.matrix_world.translation), 'scale', tuple(round(x, 4) for x in o.matrix_world.to_scale()),
          'modifiers', [m.type for m in o.modifiers], 'vgroups', [g.name for g in o.vertex_groups][:5])
bpy.ops.object.select_all(action='SELECT')
common = dict(use_selection=True, object_types={'ARMATURE', 'MESH'}, add_leaf_bones=False, bake_anim=False,
              mesh_smooth_type='FACE', axis_forward='-Z', axis_up='Y')
bpy.ops.export_scene.fbx(filepath=os.path.join(out, 'rt_A.fbx'), global_scale=1.0, apply_unit_scale=True,
                         apply_scale_options='FBX_SCALE_NONE', bake_space_transform=False, **common)
bpy.ops.export_scene.fbx(filepath=os.path.join(out, 'rt_B.fbx'), global_scale=0.01, bake_space_transform=True, **common)
print('EXPORTED rt_A.fbx rt_B.fbx')

# the old base: how do its bones look in Blender space?
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=oldfbx)
for o in bpy.data.objects:
    if o.type == 'ARMATURE':
        print('OLD armature', o.name, 'matrix_world loc', tuple(round(x, 4) for x in o.matrix_world.translation),
              'rot', tuple(round(x, 3) for x in o.matrix_world.to_euler()), 'scale', tuple(round(x, 4) for x in o.matrix_world.to_scale()))
        for b in o.data.bones:
            h = o.matrix_world @ b.head_local; t = o.matrix_world @ b.tail_local
            if b.name.endswith('_end'): continue
            print(f'OLDBONE {b.name:22} parent={str(b.parent.name if b.parent else None):18} head=({h.x:.4f},{h.y:.4f},{h.z:.4f}) tail=({t.x:.4f},{t.y:.4f},{t.z:.4f}) roll={b.matrix_local.to_euler().z:.3f}')
    elif o.type == 'MESH':
        print('OLD mesh', o.name, len(o.data.vertices), 'parent', o.parent.name if o.parent else None, o.parent_type, o.parent_bone,
              'modifiers', [m.type for m in o.modifiers], 'vgroups', [g.name for g in o.vertex_groups])
