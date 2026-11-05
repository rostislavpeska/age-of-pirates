"""Blender verification scene for the damaged Treasure Ship rig (built from dmg_extract.py's JSON + the clean 8-sail
rig blend). Shows exactly what the Granny build will contain: the damaged model's pieces as vertex groups on the
armature, the sail cloth/bars cut out of the mast pieces as their own objects on the rig's sail bones, and the sail
bones re-parented under their mast pieces (Blender keeps the rest offset, which is what the animtrans bone does in
the gr2). Actions: zptreasureship_idle (furled), zptreasureship_walk (hoisted), demo_mast_fall (two masts tipped
over - the sails must follow).

usage: blender -b --python dmg_blender.py -- rig8_clean.blend dmg.json out.blend
"""
import bpy, sys, json, math, collections
import numpy as np
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index('--') + 1:]
rig, jpath, outp = args[0], args[1], args[2]
J = json.load(open(jpath)); M = np.array(J['map'])            # engine = M . blender  ->  blender = M.T . engine
def to_b(v): return (M.T @ np.array(v)).tolist()

bpy.ops.wm.open_mainfile(filepath=rig)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for o in [o for o in bpy.data.objects if o.type == 'MESH']: bpy.data.objects.remove(o, do_unlink=True)   # intact geometry out
for c in [c for c in bpy.data.collections if c.name.startswith(('sail_', 'Sails', 'Hull'))]: bpy.data.collections.remove(c)
root_col = bpy.context.scene.collection
cols = {n: bpy.data.collections.new(n) for n in ('Rig', 'Hull pieces', 'Sails')}
for c in cols.values(): root_col.children.link(c)
for uc in list(arm.users_collection): uc.objects.unlink(arm)
cols['Rig'].objects.link(arm)

# --- damaged pieces' bones (positions = piece pivots, engine -> blender frame), root maps onto Object02
existing = {b.name for b in arm.data.bones}
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT'); eb = arm.data.edit_bones
name_of = {i: b['name'] for i, b in enumerate(J['bones'])}
added = []
for i, b in enumerate(J['bones']):
    if b['parent'] < 0 or b['name'] in existing: continue
    e = eb.new(b['name']); W = np.array(b['world']); head = Vector(to_b(W[:3, 3]))
    e.head = head; e.tail = head + Vector((0, 0.6, 0)); e.roll = 0
    par = name_of[b['parent']]; e.parent = eb['Object02'] if J['bones'][b['parent']]['parent'] < 0 else eb[par]
    added.append(b['name'])
# --- sail bones under their mast pieces (rest offset kept: Blender's equivalent of the animtrans bone)
for sail, mast in J['sail_mast'].items():
    letter = J['rig_mb'][sail + '_cloth'].replace('bone_sail', '').replace('_bottom', '')
    for e in eb:
        if e.name == f'bone_sail{letter}_rot' or e.name.startswith(f'bone_sail{letter}mast_'):
            e.parent = eb[mast]; e.use_connect = False
bpy.ops.object.mode_set(mode='OBJECT')
print('BONES', len(arm.data.bones), 'added pieces', len(added), '| sail -> mast:', J['sail_mast'])

# --- meshes: hull objects (one per Combined mesh, vertex groups per piece) and sail objects
def make(name, verts, faces, col, colour):
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
    o = bpy.data.objects.new(name, me); col.objects.link(o)
    mat = bpy.data.materials.get('m_' + name[:6]) or bpy.data.materials.new('m_' + name[:6]); mat.diffuse_color = colour; me.materials.append(mat)
    o.modifiers.new('Armature', 'ARMATURE').object = arm; o.parent = arm; o.color = colour
    return o

palette = [(1,0,0,1),(0,0.9,0,1),(0.1,0.4,1,1),(1,0.85,0,1),(1,0,1,1),(0,1,1,1),(1,0.5,0,1),(0.6,0,1,1)]
sails = sorted(J['sail_mast']); report = collections.Counter()
for mi, m in enumerate(J['meshes']):
    P = [to_b(p) for p in m['positions']]; L = m['label']
    sail_tris = collections.defaultdict(list); hull_tris = []
    for t in m['tris']:
        ls = {L[i] for i in t}
        (sail_tris[ls.pop()] if len(ls) == 1 and None not in ls else hull_tris).append(t)
    # hull object: all vertices, remaining triangles, vertex group per piece
    o = make(f"{m['name']}_{mi}", P, hull_tris, cols['Hull pieces'], (0.55, 0.55, 0.55, 1))
    by_piece = collections.defaultdict(list)
    for i, pc in enumerate(m['piece']): by_piece[pc].append(i)
    for pc, idx in by_piece.items(): o.vertex_groups.new(name=pc).add(idx, 1.0, 'REPLACE')
    # sail objects: subset vertices, bound to the rig bone
    for name, tris in sail_tris.items():
        used = []; remap = {}
        for i in np.array(tris).flatten():
            if i not in remap: remap[i] = len(used); used.append(int(i))
        sail = name.split('_cloth')[0].split('_bar')[0]; colour = palette[sails.index(sail) % 8]
        if '_bar_' in name: colour = tuple(0.35 * c for c in colour[:3]) + (1,)
        so = make(name, [P[i] for i in used], [[remap[i] for i in t] for t in tris], cols['Sails'], colour)
        so.vertex_groups.new(name=J['rig_mb'][name]).add(list(range(len(used))), 1.0, 'REPLACE')
        report['cloth' if name.endswith('_cloth') else 'bars'] += 1
print('MESHES', dict(report), 'hull objects', len(J['meshes']))

# --- demo action: two masts tipped over; the sails hanging under them must follow
sc = bpy.context.scene; sc.frame_start, sc.frame_end = 1, 2
for pb in arm.pose.bones: pb.rotation_mode = 'QUATERNION'
idle = bpy.data.actions['zptreasureship_idle']; walk = bpy.data.actions['zptreasureship_walk']
demo = bpy.data.actions.new('demo_mast_fall'); demo.use_fake_user = True
arm.animation_data.action = demo
for pb in arm.pose.bones: pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.scale = (1, 1, 1)
for mast, ang in (('mast_wood_solid_4', 55), ('mast_wood_solid_1', -50)):
    if mast in arm.pose.bones:
        pb = arm.pose.bones[mast]; pb.rotation_mode = 'XYZ'; pb.rotation_euler = (math.radians(ang), 0, 0)
        for f in (1, 2): pb.keyframe_insert('rotation_euler', frame=f)
for mast, ang in (('mast_wood_solid_4', 55), ('mast_wood_solid_1', -50)):   # unkeyed pose values survive an action switch
    if mast in arm.pose.bones: arm.pose.bones[mast].rotation_euler = (0, 0, 0)
idle.use_fake_user = walk.use_fake_user = True
arm.animation_data.action = idle; sc.frame_set(1)
arm.data.display_type = 'STICK'; arm.show_in_front = True
bpy.ops.wm.save_as_mainfile(filepath=outp); print('SAVED', outp)
