"""Phase 1b - classify the loose parts of split.blend into sails.
Panels = thin, roughly vertical, large islands above deck level; sails = clusters of panels along
the ship; every small part fully inside a sail's box (battens, yard) joins that sail.
Prints the sail table, renders a colour-coded preview, saves sails.json + sails.blend.

usage: blender -b --python sails_cluster.py -- split.blend out_dir [z_deck_world]
"""
import bpy, sys, os, json
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
blend, out = args[0], args[1]
zdeck = float(args[2]) if len(args) > 2 else 0.012        # world z above which panels count (~3 engine units)
bpy.ops.wm.open_mainfile(filepath=blend)

parts = [o for o in bpy.data.objects if o.type == 'MESH']
stats = {}
for o in parts:
    P = np.array([o.matrix_world @ v.co for v in o.data.vertices])
    if len(P) < 3: continue
    c = P.mean(0); Q = P - c
    U, s, Vt = np.linalg.svd(Q, full_matrices=False)
    ext = 2 * s / np.sqrt(len(P)); normal = Vt[2]
    stats[o.name] = dict(lo=P.min(0), hi=P.max(0), c=c, ext=ext, normal=normal, nv=len(P))

def is_panel(st):
    e = st['ext']
    return (e[2] / max(e[0], 1e-9) < 0.12 and e[1] / max(e[0], 1e-9) > 0.25       # flat and wide in two directions
            and e[0] > 0.004 and abs(st['normal'][2]) < 0.5 and st['c'][2] > zdeck  # vertical-ish plane, above deck
            and abs(st['c'][0]) < 0.006)                                            # on the centre line (pavilion walls sit at x = +-0.015)

panels = [n for n, st in stats.items() if is_panel(st)]
print(f'PANELS {len(panels)} of {len(stats)} parts')
for n in sorted(panels, key=lambda n: -stats[n]['c'][1]):
    st = stats[n]; print(f"  {n:40} nv={st['nv']:4d} c=({st['c'][0]:.4f},{st['c'][1]:.4f},{st['c'][2]:.4f}) w={st['hi'][1]-st['lo'][1]:.4f} h={st['hi'][2]-st['lo'][2]:.4f}")

# greedy clustering along the ship (y): a panel joins a cluster when its y-span overlaps the cluster's by >= 60 % of its own width
clusters = []
for n in sorted(panels, key=lambda n: -(stats[n]['hi'][1] - stats[n]['lo'][1])):      # widest first
    st = stats[n]; y0, y1 = st['lo'][1], st['hi'][1]
    best = None; bestov = 0
    for cl in clusters:
        ov = min(y1, cl['y1']) - max(y0, cl['y0'])
        if ov > bestov and ov >= 0.6 * (y1 - y0): best, bestov = cl, ov
    if best is None: clusters.append(dict(names=[n], y0=y0, y1=y1))
    else: best['names'].append(n); best['y0'] = min(best['y0'], y0); best['y1'] = max(best['y1'], y1)
clusters.sort(key=lambda cl: -(cl['y0'] + cl['y1']))          # bow (+Y) first

# attach every other part that lies fully inside the sail box (battens, yard, sail edges); masts/stays stick out and stay
sails = []
margin = 0.0015
for i, cl in enumerate(clusters):
    lo = np.min([stats[n]['lo'] for n in cl['names']], 0) - margin; hi = np.max([stats[n]['hi'] for n in cl['names']], 0) + margin
    extra = [n for n, st in stats.items() if n not in cl['names'] and n not in {m for s in sails for m in s['all']}
             and np.all(st['lo'] >= lo) and np.all(st['hi'] <= hi)]
    sails.append(dict(name=f'sail_{i+1:02d}', panels=cl['names'], extra=extra, all=cl['names'] + extra,
                      lo=(lo + margin).round(4).tolist(), hi=(hi - margin).round(4).tolist()))
    nv = sum(stats[n]['nv'] for n in cl['names'] + extra)
    print(f"SAIL {sails[-1]['name']}: {len(cl['names'])} panels + {len(extra)} parts, {nv} verts, y {cl['y0']:.4f}..{cl['y1']:.4f}, z {lo[2]+margin:.4f}..{hi[2]-margin:.4f}")
json.dump(dict(sails=[{k: v for k, v in s.items()} for s in sails]), open(os.path.join(out, 'sails.json'), 'w'), indent=1)

palette = [(1,0,0,1),(0,0.9,0,1),(0.1,0.4,1,1),(1,0.85,0,1),(1,0,1,1),(0,1,1,1),(1,0.5,0,1),(0.6,0,1,1)]
for o in bpy.data.objects:
    if o.type == 'MESH': o.color = (0.6, 0.6, 0.6, 1)
for i, s in enumerate(sails):
    for n in s['panels']: bpy.data.objects[n].color = palette[i % len(palette)]
    for n in s['extra']:  bpy.data.objects[n].color = tuple(0.5 * c for c in palette[i % len(palette)][:3]) + (1,)
print('LEGEND:', [(s['name'], palette[i % len(palette)][:3]) for i, s in enumerate(sails)])

sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'FLAT'; sc.display.shading.color_type = 'OBJECT'
camobj = bpy.data.objects['cam']; sc.camera = camobj
allP = np.array([o.matrix_world @ v.co for o in bpy.data.objects if o.type == 'MESH' for v in o.data.vertices])
lo, hi = allP.min(0), allP.max(0); centre = Vector(((lo + hi) / 2).tolist()); size = float(np.linalg.norm(hi - lo))
def shot(name, direction):
    d = Vector(direction).normalized(); camobj.location = centre - d * size * 2
    camobj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(out, name); bpy.ops.render.render(write_still=True); print('RENDER', name)
shot('sails_side.png', (-1, 0, 0)); shot('sails_quarter.png', (-1, 1, -0.6))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, 'sails.blend')); print('SAVED sails.blend')
