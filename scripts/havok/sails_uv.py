"""Phase 1b' - classify the loose parts of split.blend by texture region (mean UV), so the sail
cloth can be told apart from battens, masts and ropes. Renders a preview coloured by UV cluster.

usage: blender -b --python sails_uv.py -- split.blend out_dir [k]
"""
import bpy, sys, os, json
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
blend, out = args[0], args[1]; k = int(args[2]) if len(args) > 2 else 8
bpy.ops.wm.open_mainfile(filepath=blend)

parts = [o for o in bpy.data.objects if o.type == 'MESH']
rows = []
for o in parts:
    me = o.data
    if not me.uv_layers or len(me.vertices) < 3: continue
    uv = np.array([l.uv for l in me.uv_layers[0].data])
    P = np.array([o.matrix_world @ v.co for v in me.vertices]); c = P.mean(0)
    s = np.linalg.svd(P - c, compute_uv=False) / np.sqrt(len(P)); ext = 2 * s
    rows.append(dict(name=o.name, mat=me.materials[0].name if me.materials and me.materials[0] else '', nv=len(P),
                     uv=uv.mean(0).tolist(), uvlo=uv.min(0).tolist(), uvhi=uv.max(0).tolist(),
                     c=c.tolist(), lo=P.min(0).tolist(), hi=P.max(0).tolist(), ext=ext.tolist()))
print('parts with UVs:', len(rows))

# k-means on mean UV, per material
def kmeans(X, k, it=40):
    rng = np.random.default_rng(0); C = X[rng.choice(len(X), k, replace=False)]
    for _ in range(it):
        lab = np.argmin(((X[:, None, :] - C[None]) ** 2).sum(2), 1)
        for j in range(k):
            if np.any(lab == j): C[j] = X[lab == j].mean(0)
    return lab, C

palette = [(1,0,0),(0,0.9,0),(0.1,0.4,1),(1,0.85,0),(1,0,1),(0,1,1),(1,0.5,0),(0.6,0,1),(0.5,1,0.5),(0.6,0.3,0),(0,0.5,0.5),(1,0.6,0.8)]
legend = []
for mat in sorted({r['mat'] for r in rows}):
    R = [r for r in rows if r['mat'] == mat]
    X = np.array([r['uv'] for r in R]); kk = min(k, len(R))
    lab, C = kmeans(X, kk)
    for j in range(kk):
        sel = [r for r, l in zip(R, lab) if l == j]
        if not sel: continue
        nv = sum(r['nv'] for r in sel); ext = np.mean([r['ext'] for r in sel], 0)
        zc = np.mean([r['c'][2] for r in sel]); xs = np.mean([abs(r['c'][0]) for r in sel])
        cid = f'{mat}:{j}'
        for r in sel: r['cluster'] = cid
        print(f"CLUSTER {cid:8} parts={len(sel):4d} verts={nv:5d} uv=({C[j][0]:.2f},{C[j][1]:.2f}) mean ext=({ext[0]:.4f},{ext[1]:.4f},{ext[2]:.4f}) mean z={zc:.4f} mean|x|={xs:.4f}")
        legend.append(cid)
json.dump(rows, open(os.path.join(out, 'uv_parts.json'), 'w'))

sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'FLAT'; sc.display.shading.color_type = 'OBJECT'
camobj = bpy.data.objects['cam']; sc.camera = camobj
allP = np.array([o.matrix_world @ v.co for o in parts for v in o.data.vertices])
lo, hi = allP.min(0), allP.max(0); centre = Vector(((lo + hi) / 2).tolist()); size = float(np.linalg.norm(hi - lo))
def shot(name, direction):
    d = Vector(direction).normalized(); camobj.location = centre - d * size * 2
    camobj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(out, name); bpy.ops.render.render(write_still=True); print('RENDER', name)

# one render per material: its clusters coloured, everything else dark grey
byname = {r['name']: r for r in rows}
for mat in sorted({r['mat'] for r in rows}):
    cids = [c for c in legend if c.startswith(mat + ':')]
    for o in parts:
        r = byname.get(o.name)
        o.color = (0.25, 0.25, 0.25, 1) if not r or r['mat'] != mat else tuple(palette[cids.index(r['cluster']) % len(palette)]) + (1,)
    print('LEGEND', mat, [(c, palette[i % len(palette)]) for i, c in enumerate(cids)])
    shot(f'uv_{mat}.png', (-1, 0, 0))
