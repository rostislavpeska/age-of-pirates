"""Fuchuan-style sail poses for the Treasure Ship.
Separation as in sails_separate.py (whole sail cloth = one object, every batten bar = one object), then a rig
copied from the Fuchuan: one root bone per sail (bone_saila..f, at the sail's BOTTOM centre - the Fuchuan bunches
at the top, a junk sail drops onto its boom) that scales the cloth as a whole, and one bone per bar
(bone_sailamast_01.., top bar first) pivoting where the bar crosses the mast. Two static poses like
fuchuan_idle/fuchuan_walk: idle = furled (cloth compressed to ~0.2 of its height, bars stacked the same way and
tilted individually), walk = hoisted (rest). The old base's bones (garrison flag, 24 muzzles, 8 impacts) and the
banner/civ-flag bones on the mast tops are added so the model is complete for the game.
Exports the model FBX (rest pose) and one FBX per pose (armature only, 2 frames), renders both poses, saves rig.blend.

usage: blender -b --python sails_rig.py -- split.blend old_base.fbx out_dir
"""
import bpy, sys, os, json, math, collections
import numpy as np
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index('--') + 1:]
blend, oldfbx, out = args[0], args[1], args[2]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=blend)
arm = bpy.data.objects['Armature']
if 'cam' in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects['cam'], do_unlink=True)

# ---------------------------------------------------------------- separation (sails_separate.py)
parts = [o for o in bpy.data.objects if o.type == 'MESH']
st = {}; pos = {}
for o in parts:
    P = np.array([o.matrix_world @ v.co for v in o.data.vertices])
    if len(P) < 3: continue
    st[o.name] = dict(mat=o.data.materials[0].name if o.data.materials and o.data.materials[0] else '', nv=len(P), lo=P.min(0), hi=P.max(0), c=P.mean(0))
    pos[o.name] = P
cand = [n for n, s in st.items() if s['c'][2] > 0.008 and abs(s['c'][0]) < 0.03]
parent = {n: n for n in cand}
def find(a):
    while parent[a] != a: parent[a] = parent[parent[a]]; a = parent[a]
    return a
key2part = collections.defaultdict(set)
for n in cand:
    for p in pos[n]: key2part[tuple(np.round(p / 2e-5).astype(int))].add(n)
for names in key2part.values():
    names = list(names)
    for b in names[1:]: parent[find(names[0])] = find(b)
groups = collections.defaultdict(list)
for n in cand: groups[find(n)].append(n)
G = []
for names in groups.values():
    lo = np.min([st[n]['lo'] for n in names], 0); hi = np.max([st[n]['hi'] for n in names], 0)
    G.append(dict(names=names, nv=sum(st[n]['nv'] for n in names), lo=lo, hi=hi, d=hi - lo, c=(lo + hi) / 2, mats=set(st[n]['mat'] for n in names)))
cloth = [g for g in G if g['mats'] == {'matb'} and g['nv'] >= 60 and g['c'][2] > 0.02 and g['hi'][2] > 0.028]
cloth.sort(key=lambda g: g['c'][1])
sails = []
for g in cloth:                                             # every sheet is its own sail: the twin sail's halves sit on two masts
    sails.append(dict(groups=[g], cy=g['c'][1]))
sails.sort(key=lambda s: (round(s['cy'], 3), s['groups'][0]['c'][0]))
used = set()
for i, s in enumerate(sails):
    s['name'] = f'sail_{i+1:02d}'; s['letter'] = 'abcdefgh'[i]
    s['cloth'] = [n for g in s['groups'] for n in g['names']]
    lo = np.min([g['lo'] for g in s['groups']], 0); hi = np.max([g['hi'] for g in s['groups']], 0); s['lo'], s['hi'] = lo, hi
    blo = lo - np.array([0.002, 0.002, 0.003]); bhi = hi + np.array([0.002, 0.002, 0.003])
    s['batten_groups'] = [g for g in G if g['mats'] == {'mata'} and g['d'][2] < 0.015 and np.all(g['c'] >= blo) and np.all(g['c'] <= bhi)
                          and g['lo'][2] >= lo[2] - 0.004 and not any(n in used for n in g['names'])]
    s['batten_groups'].sort(key=lambda g: -g['c'][2])
    used.update(s['cloth']); used.update(n for g in s['batten_groups'] for n in g['names'])
masts = [n for n, s in st.items() if s['mat'] == 'mata' and s['hi'][2] - s['lo'][2] > 0.012 and s['hi'][0] - s['lo'][0] < 0.004 and s['hi'][1] - s['lo'][1] < 0.004 and abs(s['c'][0]) < 0.012]

def join(names, newname):
    objs = [bpy.data.objects[n] for n in names]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1: bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active; o.name = newname; o.data.name = newname
    return o

root_col = bpy.context.scene.collection
for c in list(root_col.children): root_col.children.unlink(c)
col = {n: bpy.data.collections.new(n) for n in ('Rig', 'Hull', 'Sails')}
for c in col.values(): root_col.children.link(c)
def move(o, c):
    for uc in list(o.users_collection): uc.objects.unlink(o)
    c.objects.link(o)

for s in sails:
    sc_col = bpy.data.collections.new(s['name']); col['Sails'].children.link(sc_col)
    s['obj_cloth'] = join(s['cloth'], f"{s['name']}_cloth"); move(s['obj_cloth'], sc_col)
    s['obj_bars'] = []
    for k, g in enumerate(s['batten_groups']):
        o = join(g['names'], f"{s['name']}_bar_{k+1:02d}"); move(o, sc_col); s['obj_bars'].append(o)
    # the mast this sail hangs on: the tall vertical part nearest the sail's centre along the ship
    ms = [m for m in masts if s['lo'][1] - 0.003 <= st[m]['c'][1] <= s['hi'][1] + 0.003]
    s['mast_y'] = st[min(ms, key=lambda m: abs(st[m]['c'][1] - (s['lo'][1] + s['hi'][1]) / 2))]['c'][1] if ms else None
    print(f"SAIL {s['name']} ({s['letter']}): cloth {len(s['obj_cloth'].data.vertices)} verts, {len(s['obj_bars'])} bars, mast y={s['mast_y']}")
rest = collections.defaultdict(list)
for o in bpy.data.objects:
    if o.type == 'MESH' and not o.name.startswith('sail_'):
        rest[o.data.materials[0].name if o.data.materials and o.data.materials[0] else ''].append(o.name)
base = {'mata': ('spc_treasure_ship_stage_finalShape', 'spc_treasure_ship_stage_final'),
        'matb': ('spc_treasure_ship_stage_final_matbShape', 'spc_treasure_ship_stage_final_matb'),
        'matc': ('spc_treasure_ship_stage_final_matcShape', 'spc_treasure_ship_stage_final_matc')}
hull = {}
for mat, names in rest.items():
    hull[mat] = join(names, base[mat][0]); move(hull[mat], col['Hull']); print(f'HULL {mat}: {len(names)} parts -> {hull[mat].name}')
move(arm, col['Rig']); arm.name = 'zptreasureship'; arm.data.display_type = 'STICK'; arm.show_in_front = True

# world-space geometry of the sails BEFORE the unit change (bone heads are placed from these)
for s in sails:
    P = np.array([s['obj_cloth'].matrix_world @ v.co for v in s['obj_cloth'].data.vertices])
    s['clo'], s['chi'] = P.min(0), P.max(0)
    s['root_world'] = np.array([(s['clo'][0] + s['chi'][0]) / 2, (s['clo'][1] + s['chi'][1]) / 2, s['clo'][2]])
    s['bar_world'] = []; s['bar_dir'] = []
    for o in s['obj_bars']:
        B = np.array([o.matrix_world @ v.co for v in o.data.vertices]); c = B.mean(0)
        v = np.linalg.svd(B - c, full_matrices=False)[2][0]                     # the bar's long axis
        if v[1] < 0: v = -v                                                      # pointing towards the stern (+Y)
        if s['mast_y'] is not None and B[:, 1].min() - 0.001 <= s['mast_y'] <= B[:, 1].max() + 0.001 and abs(v[1]) > 0.5:
            c = c + v * (s['mast_y'] - c[1]) / v[1]                              # pivot ON the bar where it crosses the mast
        s['bar_world'].append(c); s['bar_dir'].append(v)

# ---------------------------------------------------------------- units (proven convention: data in engine units, armature scale 0.01)
SCALE = 2.54
for o in [o for o in bpy.data.objects if o.type == 'MESH']: o.data.transform(Matrix.Scale(SCALE, 4))

# ---------------------------------------------------------------- bones
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT'); eb = arm.data.edit_bones; root = eb['Object02']; inv = arm.matrix_world.inverted()
for b in eb: b.head = b.head * SCALE; b.tail = b.tail * SCALE
def newbone(name, head_world, par=None, length=1.0):
    b = eb.new(name); b.head = (inv @ Vector(head_world)) * SCALE; b.tail = b.head + Vector((0, 0, length)); b.parent = par or root; return b
def chainbone(name, head_world, par, length=1.0):
    """bone pointing along armature +Y with zero roll = identity rest rotation relative to a +Y parent (the destroyer's
    sail chain: the scaled bone carries a PURE scale key, rotation+scale in one key is what the engine mishandled)"""
    b = eb.new(name); b.head = (inv @ Vector(head_world)) * SCALE; b.tail = b.head + Vector((0, length, 0)); b.roll = 0; b.parent = par; return b
for s in sails:
    L = s['letter']; p = s['root_world'].tolist()
    rot = chainbone(f'bone_sail{L}_rot', p, root, 1.5)             # destroyer: bone_sail_front_rot (rotation only, unused here)
    scl = chainbone(f'bone_sail{L}', p, rot, 1.0)                  # destroyer: bone_sail_front (pure scale key)
    chainbone(f'bone_sail{L}_bottom', p, scl, 0.5)                 # destroyer: bone_sail_front_bottom (the mesh is bound here)
    for k, c in enumerate(s['bar_world']): newbone(f"bone_sail{L}mast_{k+1:02d}", c.tolist(), length=0.6)
tops = sorted(masts, key=lambda m: -st[m]['hi'][2])
for name, m in zip(['bone_banner_a1', 'bone_banner_a2', 'bone_banner_a3'], tops[:3]):
    newbone(name, (st[m]['c'][0], st[m]['c'][1], st[m]['hi'][2]))
stern = max(masts, key=lambda m: st[m]['c'][1])
newbone('bone_flag_civ', (st[stern]['c'][0], st[stern]['c'][1], st[stern]['hi'][2]))
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.import_scene.fbx(filepath=oldfbx)
old_arm = [o for o in bpy.data.objects if o.type == 'ARMATURE' and o is not arm][0]
old = {b.name: (b.matrix_local.copy(), b.length) for b in old_arm.data.bones if not b.name.endswith('_end') and b.parent is not None}
for o in [o for o in bpy.data.objects if o is not arm and (o.type == 'ARMATURE' or o.parent is old_arm)]: bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT'); eb = arm.data.edit_bones
for name, (M, L) in old.items():
    b = eb.new(name); b.head = (0, 0, 0); b.tail = (0, L, 0); b.matrix = M; b.parent = eb['Object02']
bpy.ops.object.mode_set(mode='OBJECT')
print('BONES', len(arm.data.bones))

# ---------------------------------------------------------------- bindings (rigid: one vertex group, weight 1)
def bind(o, bone):
    for g in list(o.vertex_groups): o.vertex_groups.remove(g)
    vg = o.vertex_groups.new(name=bone); vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    for m in list(o.modifiers): o.modifiers.remove(m)
    o.modifiers.new('Armature', 'ARMATURE').object = arm
    o.parent = arm; o.parent_type = 'OBJECT'
for s in sails:
    bind(s['obj_cloth'], f"bone_sail{s['letter']}_bottom")            # mesh on the child of the scaled bone (destroyer pattern)
    for k, o in enumerate(s['obj_bars']): bind(o, f"bone_sail{s['letter']}mast_{k+1:02d}")
for mat, o in hull.items(): bind(o, base[mat][1])

# ---------------------------------------------------------------- materials (texture node keeps the names through the converter)
colours = {'mata': (0.55, 0.42, 0.28, 1), 'matb': (0.80, 0.72, 0.50, 1), 'matc': (0.75, 0.15, 0.10, 1)}
for m in bpy.data.materials:
    m.use_nodes = True; nt = m.node_tree
    bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None) or nt.nodes.new('ShaderNodeBsdfPrincipled')
    col_ = colours.get(m.name, (0.6, 0.6, 0.6, 1))
    img = bpy.data.images.new(m.name + '_placeholder', 4, 4); img.pixels[:] = list(col_) * 16; img.pack()
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = img; nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Base Color'].default_value = col_; m.diffuse_color = col_

# ---------------------------------------------------------------- poses: walk = hoisted (rest), idle = furled
# The cloth is squashed vertically onto its boom (Fuchuan root scale, 0.197..0.248). The bars are rigid, so each one
# FOLLOWS that squash: its pivot drops with the cloth and its slope flattens to atan(k * tan(slope)) - the affine image
# of the bar's own axis - so every bar stays inside the compressed cloth instead of fanning out.
COMPRESS = [0.20, 0.21, 0.25, 0.22, 0.24, 0.20]                    # per sail, Fuchuan range 0.197..0.248

sc = bpy.context.scene; sc.render.fps = 30; sc.frame_start = 1; sc.frame_end = 2
if not arm.animation_data: arm.animation_data_create()
sail_bones = [b.name for b in arm.data.bones if b.name.startswith('bone_sail')]
for pb in arm.pose.bones: pb.rotation_mode = 'QUATERNION'

def key_all(frame):
    for n in sail_bones:
        pb = arm.pose.bones[n]; pb.keyframe_insert('location', frame=frame); pb.keyframe_insert('rotation_quaternion', frame=frame); pb.keyframe_insert('scale', frame=frame)

walk = bpy.data.actions.new('zptreasureship_walk'); arm.animation_data.action = walk
for n in sail_bones:
    pb = arm.pose.bones[n]; pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.scale = (1, 1, 1)
for f in (1, 2): key_all(f)

idle = bpy.data.actions.new('zptreasureship_idle'); arm.animation_data.action = idle
pose_report = []
for i, s in enumerate(sails):
    k = COMPRESS[i % len(COMPRESS)]
    arm.pose.bones['bone_sail' + s['letter']].scale = (1, 1, k)      # +Y bone, zero roll: local Z = up; pure scale key
    z0 = s['root_world'][2]
    for j, (c, v) in enumerate(zip(s['bar_world'], s['bar_dir'])):
        pb = arm.pose.bones[f"bone_sail{s['letter']}mast_{j+1:02d}"]
        dz = (k - 1) * (c[2] - z0) * 254.0                    # the pivot drops with the cloth; world -> engine units is x254
        w = np.array([v[0], v[1], k * v[2]]); w = w / np.linalg.norm(w)         # the bar's axis after the squash
        axis = np.cross(v, w); sa = np.linalg.norm(axis); ang = math.atan2(sa, float(np.dot(v, w)))
        axis = axis / sa if sa > 1e-9 else np.array([1.0, 0, 0])
        al = (axis[0], axis[2], -axis[1])                       # world -> bone local (bone X = world X, Y = up, Z = -Y)
        pb.location = (0, dz, 0)                               # along the bone (= up), engine units
        pb.rotation_quaternion = (math.cos(ang / 2), *(math.sin(ang / 2) * a for a in al))   # minimal rotation v -> w
        pose_report.append((pb.name, round(float(dz), 2), tuple(round(float(x), 2) for x in v), round(math.degrees(ang), 1)))
for f in (1, 2): key_all(f)
print('IDLE POSE (bar, drop, axis, turn deg):', pose_report[:8], '...')
json.dump(dict(sails=[dict(name=s['name'], letter=s['letter'], bars=len(s['obj_bars']), root=[float(x) for x in s['root_world']], mast_y=None if s['mast_y'] is None else float(s['mast_y'])) for s in sails],
               pose=pose_report), open(os.path.join(out, 'rig.json'), 'w'), indent=1)

# ---------------------------------------------------------------- previews of both poses
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
palette = [(1,0,0,1),(0,0.9,0,1),(0.1,0.4,1,1),(1,0.85,0,1),(1,0,1,1),(0,1,1,1)]
for o in meshes: o.color = (0.6, 0.6, 0.6, 1)
for i, s in enumerate(sails):
    s['obj_cloth'].color = palette[i % 6]
    for o in s['obj_bars']: o.color = (0.1, 0.1, 0.1, 1)
sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'FLAT'; sc.display.shading.color_type = 'OBJECT'
sc.render.resolution_x = 1600; sc.render.resolution_y = 900
cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; camobj = bpy.data.objects.new('cam', cam); sc.collection.objects.link(camobj); sc.camera = camobj
allP = np.array([o.matrix_world @ v.co for o in meshes for v in o.data.vertices]); lo, hi = allP.min(0), allP.max(0)
centre = Vector(((lo + hi) / 2).tolist()); size = float(np.linalg.norm(hi - lo)); cam.ortho_scale = size * 1.05
for act, name, dv in ((idle, 'idle_side.png', (-1, 0, 0)), (walk, 'walk_side.png', (-1, 0, 0)), (idle, 'idle_quarter.png', (-1, 1, -0.6))):
    d = Vector(dv).normalized(); camobj.location = centre - d * size * 2; camobj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    arm.animation_data.action = act; sc.frame_set(1)
    sc.render.filepath = os.path.join(out, name); bpy.ops.render.render(write_still=True); print('RENDER', name)
bpy.data.objects.remove(camobj, do_unlink=True)

# ---------------------------------------------------------------- exports
FBX = dict(add_leaf_bones=False, mesh_smooth_type='FACE', axis_forward='-Z', axis_up='Y', global_scale=1.0, apply_unit_scale=True,
           apply_scale_options='FBX_SCALE_NONE', bake_space_transform=False, path_mode='COPY', embed_textures=False)
arm.animation_data.action = None
for pb in arm.pose.bones: pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.scale = (1, 1, 1)
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True)
for o in meshes: o.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(out, 'zptreasureship.fbx'), use_selection=True, object_types={'ARMATURE', 'MESH'}, bake_anim=False, **FBX)
print('EXPORTED model')
for act, fn in ((idle, 'zptreasureship_idle.fbx'), (walk, 'zptreasureship_walk.fbx')):
    arm.animation_data.action = act; sc.frame_set(1)
    bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(out, fn), use_selection=True, object_types={'ARMATURE'}, bake_anim=True, bake_anim_use_all_bones=True,
                             bake_anim_use_nla_strips=False, bake_anim_use_all_actions=False, bake_anim_force_startend_keying=True,
                             bake_anim_step=1.0, bake_anim_simplify_factor=0.0, **FBX)
    print('EXPORTED', fn)
idle.use_fake_user = walk.use_fake_user = True                 # keep both poses in the .blend (the inactive one has no user)
arm.animation_data.action = idle; sc.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, 'rig.blend')); print('SAVED rig.blend')
