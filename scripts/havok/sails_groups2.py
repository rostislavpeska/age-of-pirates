"""Phase 1b''' - group the high parts by SHARED VERTEX POSITIONS (the loose-part split cut the
mesh where vertices are duplicated along seams; parts of one sail share seam positions, sails
of different masts do not). Prints the groups with their material mix and renders them.

usage: blender -b --python sails_groups2.py -- split.blend out_dir
"""
import bpy, sys, os, json, collections
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
blend, out = args[0], args[1]
bpy.ops.wm.open_mainfile(filepath=blend)
parts = [o for o in bpy.data.objects if o.type == 'MESH']
st = {}; pos = {}
for o in parts:
    P = np.array([o.matrix_world @ v.co for v in o.data.vertices])
    if len(P) < 3: continue
    st[o.name] = dict(mat=o.data.materials[0].name if o.data.materials and o.data.materials[0] else '', nv=len(P), lo=P.min(0), hi=P.max(0), c=P.mean(0))
    pos[o.name] = P
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
rows = []
for names in groups.values():
    lo = np.min([st[n]['lo'] for n in names], 0); hi = np.max([st[n]['hi'] for n in names], 0)
    mats = collections.Counter(st[n]['mat'] for n in names)
    rows.append(dict(names=names, nv=sum(st[n]['nv'] for n in names), lo=lo, hi=hi, d=hi - lo, c=(lo + hi) / 2, mats=dict(mats)))
rows.sort(key=lambda r: -r['nv'])
print(f'{len(cand)} high parts -> {len(rows)} shared-vertex groups')
for r in rows[:30]:
    print(f"GROUP n={len(r['names']):3d} nv={r['nv']:5d} mats={r['mats']} c=({r['c'][0]:.4f},{r['c'][1]:.4f},{r['c'][2]:.4f}) d=({r['d'][0]:.4f},{r['d'][1]:.4f},{r['d'][2]:.4f}) z {r['lo'][2]:.4f}..{r['hi'][2]:.4f}")
json.dump([dict(names=r['names'], lo=r['lo'].tolist(), hi=r['hi'].tolist(), mats=r['mats']) for r in rows], open(os.path.join(out, 'groups2.json'), 'w'), indent=1)

palette = [(1,0,0,1),(0,0.9,0,1),(0.1,0.4,1,1),(1,0.85,0,1),(1,0,1,1),(0,1,1,1),(1,0.5,0,1),(0.6,0,1,1),(0.5,1,0.5,1),(0.6,0.3,0,1)]
for o in parts: o.color = (0.6, 0.6, 0.6, 1)
big = [r for r in rows if r['nv'] >= 30]
for i, r in enumerate(big):
    for n in r['names']: bpy.data.objects[n].color = palette[i % len(palette)]
print('LEGEND', [(i, r['nv'], palette[i % len(palette)][:3]) for i, r in enumerate(big)])
sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'FLAT'; sc.display.shading.color_type = 'OBJECT'
camobj = bpy.data.objects['cam']; sc.camera = camobj
allP = np.concatenate(list(pos.values())); lo, hi = allP.min(0), allP.max(0)
centre = Vector(((lo + hi) / 2).tolist()); size = float(np.linalg.norm(hi - lo))
for name, d in [('groups2_side.png', (-1, 0, 0)), ('groups2_top.png', (0, 0, -1))]:
    d = Vector(d).normalized(); camobj.location = centre - d * size * 2; camobj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(out, name); bpy.ops.render.render(write_still=True); print('RENDER', name)
