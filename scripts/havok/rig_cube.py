"""Rebuild the test cube's rig for destruction (one bone per piece, 100 % weights) and export FBX.
usage: blender -b test_cube.blend --python rig_cube.py -- out.fbx"""
import bpy, sys
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
out = args[0]
scale = float(args[1]) if len(args) > 1 else 1.0      # uniform model scale (2.0 -> a 4 m cube)
meshes = sorted([o for o in bpy.data.objects if o.type == 'MESH'], key=lambda o: o.name)
for o in [o for o in bpy.data.objects if o.type == 'ARMATURE']:
    bpy.data.objects.remove(o, do_unlink=True)
from mathutils import Matrix
for o in meshes:                                   # bake object transforms (and the scale) into the mesh data
    o.parent = None
    o.data.transform(Matrix.Scale(scale, 4) @ o.matrix_world); o.matrix_world.identity()

arm = bpy.data.armatures.new('test_cube'); armobj = bpy.data.objects.new('test_cube', arm)
bpy.context.scene.collection.objects.link(armobj)
bpy.context.view_layer.objects.active = armobj
bpy.ops.object.mode_set(mode='EDIT')
eb = arm.edit_bones
root = eb.new('bone_main'); root.head = (0, 0, 0); root.tail = (0, 0.25, 0)

def aabb(vs):
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi

def add(name, c):
    b = eb.new(name); b.head = c; b.tail = c + Vector((0, 0.25, 0)); b.parent = root; return b

allv = [v.co.copy() for o in meshes for v in o.data.vertices]
lo, hi = aabb(allv); centre = (lo + hi) / 2
add('base_proxy', centre)                          # intact-building collider (keyframed, type 6)
add('ondeath_0_proxy', centre)                     # group proxy for the death pieces (type 7)
pieces = []
for i, o in enumerate(meshes):
    plo, phi = aabb([v.co for v in o.data.vertices]); c = (plo + phi) / 2
    n = 'wall_wood_solid_ondeath_%d' % i
    add(n, c); pieces.append((o, n))
bpy.ops.object.mode_set(mode='OBJECT')

for o, n in pieces:
    o.name = n; o.data.name = n
    o.vertex_groups.clear()
    vg = o.vertex_groups.new(name=n); vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    for m in list(o.modifiers): o.modifiers.remove(m)
    md = o.modifiers.new('Armature', 'ARMATURE'); md.object = armobj
    o.parent = armobj
print('RIG bones:', [(b.name, tuple(round(x, 3) for x in b.head_local)) for b in arm.bones])
print('RIG pieces:', [(o.name, len(o.data.vertices)) for o, n in pieces])
bpy.ops.object.select_all(action='DESELECT')
for o in [armobj] + [o for o, n in pieces]: o.select_set(True)
bpy.ops.export_scene.fbx(filepath=out, use_selection=True, object_types={'ARMATURE', 'MESH'},
                         add_leaf_bones=False, bake_anim=False, use_armature_deform_only=True,
                         mesh_smooth_type='FACE', axis_forward='-Z', axis_up='Y', global_scale=0.01, bake_space_transform=True)
print('FBX written:', out)
