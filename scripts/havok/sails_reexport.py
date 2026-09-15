"""Re-export the Treasure Ship from the Blender rig with the user's fix applied to every object: custom split
normals cleared (Blender recomputes plain smooth normals on export), the inherited banner/civ-flag bones removed,
model + idle/walk poses exported with the proven FBX settings. Saves the scene under a new name.

usage: blender -b --python sails_reexport.py -- rig.blend out_dir
"""
import bpy, sys, os

args = sys.argv[sys.argv.index('--') + 1:]
src, out = args[0], args[1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=src)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
sc = bpy.context.scene
chain = [b.name for b in arm.data.bones if b.name.endswith(('_rot', '_bottom'))]
assert chain, 'this rig has no scale chain (bone_sailX_rot/_bottom) - wrong file'

# --- drop the flag bones (they made the battleship-inherited flag attachments visible)
DROP = [b.name for b in arm.data.bones if b.name.startswith(('bone_banner', 'bone_flag_civ'))]
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
for n in DROP: arm.data.edit_bones.remove(arm.data.edit_bones[n])
bpy.ops.object.mode_set(mode='OBJECT')
for a in bpy.data.actions:                       # and their keys
    for layer in a.layers:
        for strip in layer.strips:
            for slot in a.slots:
                cb = strip.channelbag(slot)
                if not cb: continue
                for fc in [fc for fc in cb.fcurves if any('"%s"' % n in fc.data_path for n in DROP)]: cb.fcurves.remove(fc)
print('DROPPED bones', DROP, '-> bones now', len(arm.data.bones))

# --- clear custom split normals on every mesh (the user's fix for the dark shading)
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
cleared = []
for o in meshes:
    if o.data.has_custom_normals:
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
        bpy.ops.mesh.customdata_custom_splitnormals_clear(); cleared.append(o.name)
    o.data.shade_smooth() if hasattr(o.data, 'shade_smooth') else None
print('CUSTOM NORMALS cleared on', len(cleared), 'of', len(meshes), 'meshes; remaining with custom normals:', [o.name for o in meshes if o.data.has_custom_normals])

# --- exports (settings proven by the round trip / in game)
FBX = dict(add_leaf_bones=False, mesh_smooth_type='FACE', axis_forward='-Z', axis_up='Y', global_scale=1.0, apply_unit_scale=True,
           apply_scale_options='FBX_SCALE_NONE', bake_space_transform=False, path_mode='COPY', embed_textures=False)
idle, walk = bpy.data.actions['zptreasureship_idle'], bpy.data.actions['zptreasureship_walk']
arm.animation_data.action = None
for pb in arm.pose.bones: pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.scale = (1, 1, 1)
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True)
for o in meshes: o.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(out, 'zptreasureship.fbx'), use_selection=True, object_types={'ARMATURE', 'MESH'}, bake_anim=False, **FBX)
print('EXPORTED model')
sc.frame_start, sc.frame_end = 1, 2
for act, fn in ((idle, 'zptreasureship_idle.fbx'), (walk, 'zptreasureship_walk.fbx')):
    arm.animation_data.action = act; sc.frame_set(1)
    bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(out, fn), use_selection=True, object_types={'ARMATURE'}, bake_anim=True, bake_anim_use_all_bones=True,
                             bake_anim_use_nla_strips=False, bake_anim_use_all_actions=False, bake_anim_force_startend_keying=True,
                             bake_anim_step=1.0, bake_anim_simplify_factor=0.0, **FBX)
    print('EXPORTED', fn)
idle.use_fake_user = walk.use_fake_user = True
arm.animation_data.action = idle; sc.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, 'rig_clean.blend')); print('SAVED rig_clean.blend')
