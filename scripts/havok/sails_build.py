"""Phase 1 - build the Treasure Ship with separate sails (battleship pattern).
Starts from split.blend (vanilla intact model, every mesh split into loose parts; armature scale 0.01).
Parts high above the deck are grouped by SHARED VERTEX POSITIONS (seams of one sail share positions):
  cloth   = pure-matb groups (>= 60 verts); groups with the same y are the two halves of one V-shaped sail
  battens = pure-mata thin groups lying inside a sail's box (the fanned bars)
  masts   = tall vertical mata parts -> banner bones on the three tallest, civ flag on the stern one
Every sail becomes two objects (cloth = matb, battens = mata) bound to its own bone bone_sail_NN (bow first,
pivot at the sail's top centre); everything else is joined back into the three vanilla meshes. The old base's
extra bones (garrison flag, 24 muzzles, 8 impact points) are copied from old_base.fbx. Exports FBX with the
settings proven by the round trip (scale 1, unit scale, no space bake), renders previews, saves build.blend.

usage: blender -b --python sails_build.py -- split.blend old_base.fbx out_dir
"""
import bpy, sys, os, json, collections
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
blend, oldfbx, out = args[0], args[1], args[2]
os.makedirs(os.path.join(out, 'tex'), exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=blend)
arm = bpy.data.objects['Armature']
if 'cam' in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects['cam'], do_unlink=True)

parts = [o for o in bpy.data.objects if o.type == 'MESH']
st = {}; pos = {}
for o in parts:
    P = np.array([o.matrix_world @ v.co for v in o.data.vertices])
    if len(P) < 3: continue
    st[o.name] = dict(mat=o.data.materials[0].name if o.data.materials and o.data.materials[0] else '', nv=len(P), lo=P.min(0), hi=P.max(0), c=P.mean(0))
    pos[o.name] = P

# --- shared-vertex groups among the high parts
cand = [n for n, s in st.items() if s['c'][2] > 0.02 and s['hi'][2] > 0.028 and abs(s['c'][0]) < 0.03]
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
cloth = [g for g in G if g['mats'] == {'matb'} and g['nv'] >= 60]
cloth.sort(key=lambda g: g['c'][1])
sails = []
for g in cloth:                                             # merge the V halves (same y)
    if sails and abs(g['c'][1] - sails[-1]['cy']) < 0.004:
        s = sails[-1]; s['groups'].append(g); s['cy'] = np.mean([x['c'][1] for x in s['groups']])
    else: sails.append(dict(groups=[g], cy=g['c'][1]))
used = set()
for i, s in enumerate(sails):
    s['name'] = f'sail_{i+1:02d}'
    s['cloth'] = [n for g in s['groups'] for n in g['names']]
    lo = np.min([g['lo'] for g in s['groups']], 0); hi = np.max([g['hi'] for g in s['groups']], 0)
    s['lo'], s['hi'] = lo, hi
    blo = lo - np.array([0.002, 0.002, 0.003]); bhi = hi + np.array([0.002, 0.002, 0.003])
    s['batten_groups'] = [g for g in G if g['mats'] == {'mata'} and g['d'][2] < 0.015 and np.all(g['c'] >= blo) and np.all(g['c'] <= bhi)
                          and g['lo'][2] >= lo[2] - 0.004 and not any(n in used for n in g['names'])]
    s['battens'] = [n for g in s['batten_groups'] for n in g['names']]
    s['pivot'] = np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, hi[2]])
    used.update(s['cloth']); used.update(s['battens'])
    print(f"SAIL {s['name']}: {len(s['groups'])} cloth sheet(s) {len(s['cloth'])} parts {sum(st[n]['nv'] for n in s['cloth'])} verts; "
          f"{len(s['batten_groups'])} batten groups {len(s['battens'])} parts {sum(st[n]['nv'] for n in s['battens'])} verts; "
          f"x {lo[0]:.4f}..{hi[0]:.4f} y {lo[1]:.4f}..{hi[1]:.4f} z {lo[2]:.4f}..{hi[2]:.4f}; pivot engine=({s['pivot'][0]*254:.2f},{s['pivot'][2]*254:.2f},{s['pivot'][1]*254:.2f})")
masts = [n for n, s in st.items() if s['mat'] == 'mata' and s['hi'][2] - s['lo'][2] > 0.012 and s['hi'][0] - s['lo'][0] < 0.004 and s['hi'][1] - s['lo'][1] < 0.004 and abs(s['c'][0]) < 0.012]
print('MASTS', [(n[-5:], round(st[n]['c'][1], 4), round(st[n]['hi'][2], 4)) for n in masts])

def join(names, newname):
    objs = [bpy.data.objects[n] for n in names]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1: bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active; o.name = newname; o.data.name = newname
    return o

sail_objs = []
for s in sails:
    s['obj_cloth'] = join(s['cloth'], s['name'] + '_cloth'); sail_objs.append(s['obj_cloth'])
    if s['battens']: s['obj_battens'] = join(s['battens'], s['name'] + '_battens'); sail_objs.append(s['obj_battens'])
rest = collections.defaultdict(list)
for o in bpy.data.objects:
    if o.type == 'MESH' and o not in sail_objs:
        rest[o.data.materials[0].name if o.data.materials and o.data.materials[0] else ''].append(o.name)
hull = {}
base = {'mata': ('spc_treasure_ship_stage_finalShape', 'spc_treasure_ship_stage_final'),
        'matb': ('spc_treasure_ship_stage_final_matbShape', 'spc_treasure_ship_stage_final_matb'),
        'matc': ('spc_treasure_ship_stage_final_matcShape', 'spc_treasure_ship_stage_final_matc')}
for mat, names in rest.items():
    hull[mat] = join(names, base[mat][0]); print(f'HULL {mat}: {len(names)} parts -> {hull[mat].name} ({len(hull[mat].data.vertices)} verts)')

# --- units: the converter exports a vanilla (Maya, UnitsPerMeter 1.5625) gr2 divided by 2.54, but imports FBX 1:1
# and the old base (the user's working FBX -> gr2) is in engine units. Scale the vanilla-derived geometry up so the
# FBX is in engine units exactly like the old base's (its bones are copied unscaled below).
from mathutils import Matrix
SCALE = 2.54
for o in [o for o in bpy.data.objects if o.type == 'MESH']: o.data.transform(Matrix.Scale(SCALE, 4))
print(f'SCALED mesh data x{SCALE} (armature-local units are now engine units)')

# --- bones: sail pivots, banner/flag bones on the masts, then the old base's extra bones
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT'); eb = arm.data.edit_bones; root = eb['Object02']; inv = arm.matrix_world.inverted()
for b in eb: b.head = b.head * SCALE; b.tail = b.tail * SCALE
def newbone(name, head_world):
    b = eb.new(name); b.head = (inv @ Vector(head_world)) * SCALE; b.tail = b.head + Vector((0, 0, 1.0)); b.parent = root; return b
for s in sails: newbone('bone_' + s['name'], s['pivot'].tolist())
tops = sorted(masts, key=lambda m: -st[m]['hi'][2])
for name, m in zip(['bone_banner_a1', 'bone_banner_a2', 'bone_banner_a3'], tops[:3]):
    newbone(name, (st[m]['c'][0], st[m]['c'][1], st[m]['hi'][2])); print(f"BANNER {name}: mast y={st[m]['c'][1]:.4f} top engine y={st[m]['hi'][2]*254:.2f}")
stern = max(masts, key=lambda m: st[m]['c'][1])                       # +Y is the stern
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
print('BONES', len(arm.data.bones), [b.name for b in arm.data.bones])

# --- bindings: one vertex group (weight 1) named after the bone, armature modifier, parent = armature
def bind(o, bone):
    for g in list(o.vertex_groups): o.vertex_groups.remove(g)
    vg = o.vertex_groups.new(name=bone); vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    for m in list(o.modifiers): o.modifiers.remove(m)
    o.modifiers.new('Armature', 'ARMATURE').object = arm
    o.parent = arm; o.parent_type = 'OBJECT'
for s in sails:
    bind(s['obj_cloth'], 'bone_' + s['name'])
    if s['battens']: bind(s['obj_battens'], 'bone_' + s['name'])
for mat, o in hull.items(): bind(o, base[mat][1])

# --- materials: a texture on every material so the converter keeps the material names (mata/matb/matc)
for m in bpy.data.materials:
    m.use_nodes = True; nt = m.node_tree
    bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None) or nt.nodes.new('ShaderNodeBsdfPrincipled')
    tex = nt.nodes.new('ShaderNodeTexImage')
    img = bpy.data.images.new(m.name, 4, 4); img.filepath_raw = os.path.join(out, 'tex', m.name + '.png'); img.file_format = 'PNG'; img.save()
    tex.image = img; nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])

meshes = [o for o in bpy.data.objects if o.type == 'MESH']
print('OBJECTS', [(o.name, len(o.data.vertices), o.vertex_groups[0].name, [m.name for m in o.data.materials]) for o in meshes])
json.dump([dict(name=s['name'], cloth_parts=len(s['cloth']), batten_groups=len(s['batten_groups']), lo=s['lo'].tolist(), hi=s['hi'].tolist(), pivot=s['pivot'].tolist()) for s in sails],
          open(os.path.join(out, 'build.json'), 'w'), indent=1)

# --- previews (sails coloured, battens darker)
palette = [(1,0,0,1),(0,0.9,0,1),(0.1,0.4,1,1),(1,0.85,0,1),(1,0,1,1),(0,1,1,1),(1,0.5,0,1),(0.6,0,1,1)]
for o in meshes: o.color = (0.6, 0.6, 0.6, 1)
for i, s in enumerate(sails):
    s['obj_cloth'].color = palette[i % 8]
    if s['battens']: s['obj_battens'].color = tuple(0.45 * c for c in palette[i % 8][:3]) + (1,)
sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'FLAT'; sc.display.shading.color_type = 'OBJECT'
sc.render.resolution_x = 1600; sc.render.resolution_y = 900
cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; camobj = bpy.data.objects.new('cam', cam); sc.collection.objects.link(camobj); sc.camera = camobj
allP = np.array([o.matrix_world @ v.co for o in meshes for v in o.data.vertices]); lo, hi = allP.min(0), allP.max(0)
centre = Vector(((lo + hi) / 2).tolist()); size = float(np.linalg.norm(hi - lo)); cam.ortho_scale = size * 1.05
for name, d in [('build_side.png', (-1, 0, 0)), ('build_top.png', (0, 0, -1))]:
    d = Vector(d).normalized(); camobj.location = centre - d * size * 2; camobj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(out, name); bpy.ops.render.render(write_still=True); print('RENDER', name)
bpy.data.objects.remove(camobj, do_unlink=True)

# --- export (round-trip-proven settings) and save
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True)
for o in meshes: o.select_set(True)
fbx = os.path.join(out, 'zptreasureship.fbx')
bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={'ARMATURE', 'MESH'}, add_leaf_bones=False, bake_anim=False,
                         mesh_smooth_type='FACE', axis_forward='-Z', axis_up='Y', global_scale=1.0, apply_unit_scale=True,
                         apply_scale_options='FBX_SCALE_NONE', bake_space_transform=False, path_mode='COPY', embed_textures=False)
print('EXPORTED', fbx)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, 'build.blend')); print('SAVED build.blend')
