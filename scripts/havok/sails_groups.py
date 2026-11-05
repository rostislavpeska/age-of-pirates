"""Phase 1b'' - group the matb parts spatially (bbox-overlap union-find) and pick the sails:
big groups high on the centre line. Renders the groups colour-coded for a visual check.

usage: blender -b --python sails_groups.py -- split.blend out_dir
"""
import bpy, sys, os, json
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
blend, out = args[0], args[1]
bpy.ops.wm.open_mainfile(filepath=blend)
parts = [o for o in bpy.data.objects if o.type == 'MESH']
st = {}
for o in parts:
    P = np.array([o.matrix_world @ v.co for v in o.data.vertices])
    if len(P) < 3: continue
    st[o.name] = dict(mat=o.data.materials[0].name if o.data.materials and o.data.materials[0] else '', nv=len(P), lo=P.min(0), hi=P.max(0), c=P.mean(0))

cand = [n for n, s in st.items() if s['mat'] == 'matb' and s['c'][2] > 0.015 and abs(s['c'][0]) < 0.012]
tol = 0.0015
parent = {n: n for n in cand}
def find(a):
    while parent[a] != a: parent[a] = parent[parent[a]]; a = parent[a]
    return a
for i, a in enumerate(cand):
    for b in cand[i + 1:]:
        if np.all(st[a]['lo'] - tol <= st[b]['hi']) and np.all(st[b]['lo'] - tol <= st[a]['hi']):
            parent[find(a)] = find(b)
groups = {}
for n in cand: groups.setdefault(find(n), []).append(n)
rows = []
for names in groups.values():
    lo = np.min([st[n]['lo'] for n in names], 0); hi = np.max([st[n]['hi'] for n in names], 0)
    rows.append(dict(names=names, nv=sum(st[n]['nv'] for n in names), lo=lo, hi=hi, d=hi - lo, c=(lo + hi) / 2))
rows.sort(key=lambda r: -r['nv'])
print(f'{len(cand)} matb parts -> {len(rows)} groups')
for r in rows[:25]:
    print(f"GROUP n={len(r['names']):3d} nv={r['nv']:5d} c=({r['c'][0]:.4f},{r['c'][1]:.4f},{r['c'][2]:.4f}) d=({r['d'][0]:.4f},{r['d'][1]:.4f},{r['d'][2]:.4f}) z {r['lo'][2]:.4f}..{r['hi'][2]:.4f}")
sails = [r for r in rows if r['d'][1] > 0.006 and r['d'][2] > 0.006 and r['hi'][2] > 0.03]
sails.sort(key=lambda r: -r['c'][1])
print('SAILS:', len(sails))
for i, r in enumerate(sails):
    print(f"SAIL {i+1}: n={len(r['names'])} nv={r['nv']} y {r['lo'][1]:.4f}..{r['hi'][1]:.4f} z {r['lo'][2]:.4f}..{r['hi'][2]:.4f} x {r['lo'][0]:.4f}..{r['hi'][0]:.4f}")
json.dump([dict(names=r['names'], lo=r['lo'].tolist(), hi=r['hi'].tolist()) for r in sails], open(os.path.join(out, 'groups.json'), 'w'), indent=1)

palette = [(1,0,0,1),(0,0.9,0,1),(0.1,0.4,1,1),(1,0.85,0,1),(1,0,1,1),(0,1,1,1),(1,0.5,0,1),(0.6,0,1,1)]
for o in parts: o.color = (0.6, 0.6, 0.6, 1)
for i, r in enumerate(sails):
    for n in r['names']: bpy.data.objects[n].color = palette[i % 8]
sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'FLAT'; sc.display.shading.color_type = 'OBJECT'
camobj = bpy.data.objects['cam']; sc.camera = camobj
allP = np.array([o.matrix_world @ v.co for o in parts for v in o.data.vertices]); lo, hi = allP.min(0), allP.max(0)
centre = Vector(((lo + hi) / 2).tolist()); size = float(np.linalg.norm(hi - lo))
for name, d in [('groups_side.png', (-1, 0, 0)), ('groups_top.png', (0, 0, -1))]:
    d = Vector(d).normalized(); camobj.location = centre - d * size * 2; camobj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(out, name); bpy.ops.render.render(write_still=True); print('RENDER', name)
