"""Separation only: the vanilla intact Treasure Ship with every sail section and every batten bar as its own
mesh object. No animation, no new bones - the rig stays the vanilla 4-bone armature and every object keeps its
vanilla bone binding. Starts from split.blend (sails_analyze.py output: every mesh split into loose parts).

Grouping is the same as sails_build.py: high parts that share vertex positions form one sheet; pure-matb sheets
are sail cloth (two sheets at the same y = the two halves of a V-sail), pure-mata flat groups inside a sail's box
are its battens. The whole cloth of a sail is one object sail_NN_cloth, batten groups sail_NN_bar_MM (top to
bottom); everything else is joined back into the three vanilla meshes.

usage: blender -b --python sails_separate.py -- split.blend out.blend
"""
import bpy, sys, os, collections
import numpy as np
from mathutils import Matrix

args = sys.argv[sys.argv.index('--') + 1:]
blend, dst = args[0], args[1]
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

# --- shared-vertex groups among the high parts (identical to sails_build.py)
cand = [n for n, s in st.items() if s['c'][2] > 0.008 and abs(s['c'][0]) < 0.03]      # low enough to catch a sail's bottom strip/bar
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
cloth = [g for g in G if g['mats'] == {'matb'} and g['nv'] >= 60 and g['c'][2] > 0.02 and g['hi'][2] > 0.028]   # sail sheets sit high
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
    blo = lo - np.array([0.002, 0.002, 0.003]); bhi = hi + np.array([0.002, 0.002, 0.003])
    s['batten_groups'] = [g for g in G if g['mats'] == {'mata'} and g['d'][2] < 0.015 and np.all(g['c'] >= blo) and np.all(g['c'] <= bhi)
                          and g['lo'][2] >= lo[2] - 0.004 and not any(n in used for n in g['names'])]
    s['batten_groups'].sort(key=lambda g: -g['c'][2])                    # top bar first
    used.update(s['cloth']); used.update(n for g in s['batten_groups'] for n in g['names'])

def join(names, newname):
    objs = [bpy.data.objects[n] for n in names]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1: bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active; o.name = newname; o.data.name = newname
    return o

# --- collections
root = bpy.context.scene.collection
for c in list(root.children): root.children.unlink(c)
col = {n: bpy.data.collections.new(n) for n in ('Rig', 'Hull', 'Sails')}
for c in col.values(): root.children.link(c)
def move(o, c):
    for uc in list(o.users_collection): uc.objects.unlink(o)
    c.objects.link(o)

# --- sails: one object per cloth island and per batten bar
report = []
for s in sails:
    sc_col = bpy.data.collections.new(s['name']); col['Sails'].children.link(sc_col)
    o = join(s['cloth'], f"{s['name']}_cloth"); move(o, sc_col); cloth_objs = [o]     # the whole sail cloth is one object
    bar_objs = []
    for k, g in enumerate(s['batten_groups']):
        o = join(g['names'], f"{s['name']}_bar_{k+1:02d}"); move(o, sc_col); bar_objs.append(o)
    report.append((s['name'], len(cloth_objs), sum(len(o.data.vertices) for o in cloth_objs), len(bar_objs), sum(len(o.data.vertices) for o in bar_objs)))
    print(f"SAIL {s['name']}: cloth {len(cloth_objs[0].data.vertices)} verts, {len(bar_objs)} bars ({sum(len(o.data.vertices) for o in bar_objs)} verts)")

# --- hull: everything else back into the three vanilla meshes
rest = collections.defaultdict(list)
for o in bpy.data.objects:
    if o.type == 'MESH' and not o.name.startswith('sail_'):
        rest[o.data.materials[0].name if o.data.materials and o.data.materials[0] else ''].append(o.name)
base = {'mata': 'spc_treasure_ship_stage_finalShape', 'matb': 'spc_treasure_ship_stage_final_matbShape', 'matc': 'spc_treasure_ship_stage_final_matcShape'}
for mat, names in rest.items():
    o = join(names, base[mat]); move(o, col['Hull']); print(f'HULL {mat}: {len(names)} parts -> {o.name} ({len(o.data.vertices)} verts)')
move(arm, col['Rig']); arm.name = 'zptreasureship'; arm.data.display_type = 'STICK'; arm.show_in_front = True

# --- units: same convention as the built/clean files (armature scale 0.01, data in engine units)
SCALE = 2.54
for o in [o for o in bpy.data.objects if o.type == 'MESH']: o.data.transform(Matrix.Scale(SCALE, 4))
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
for b in arm.data.edit_bones: b.head = b.head * SCALE; b.tail = b.tail * SCALE
bpy.ops.object.mode_set(mode='OBJECT')

# --- materials: flat colours with packed placeholder images, nothing missing on disk
colours = {'mata': (0.55, 0.42, 0.28, 1), 'matb': (0.80, 0.72, 0.50, 1), 'matc': (0.75, 0.15, 0.10, 1)}
for m in bpy.data.materials:
    m.use_nodes = True; nt = m.node_tree
    bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None) or nt.nodes.new('ShaderNodeBsdfPrincipled')
    col_ = colours.get(m.name, (0.6, 0.6, 0.6, 1))
    img = bpy.data.images.new(m.name + '_placeholder', 4, 4); img.pixels[:] = list(col_) * 16; img.pack()
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = img; nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Base Color'].default_value = col_; m.diffuse_color = col_

bpy.ops.object.select_all(action='DESELECT')
bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
print('BONES', [b.name for b in arm.data.bones])
print('BINDINGS', sorted({(o.vertex_groups[0].name if o.vertex_groups else None) for o in bpy.data.objects if o.type == 'MESH'}))
print('OBJECTS', len([o for o in bpy.data.objects if o.type == 'MESH']), 'meshes;', [(c.name, len(c.objects)) for c in col['Sails'].children])
bpy.ops.wm.save_as_mainfile(filepath=dst); print('SAVED', dst)
