"""Inside Blender (background is fine): per-face ray-cast AO on the shared UV texel grid.

blender -b file.blend --python ao_sample.py -- config.json
config = {
  "targets": [{"object": "House_A", "key": "House_A", "uv": "UV_T3", "page": 8192}, ...],
  "occluders": ["House_A", "House_B", "House_H"],     # whole assembly, each face once
  "radius": 0.5, "rays": 256, "grid": 12, "lattice": 3, "out": "C:/.../ao.json"
}
Samples: (1) centres of `grid`-texel cells of the target UV layer, so faces stacked on
the same texels are measured at the same spots; (2) a barycentric lattice of `lattice`
steps on EVERY triangle, so small faces (beam ends, trims, dots) always get about ten
points. Rays: stratified cosine-weighted hemisphere, random rotation per sample.
Output per face: key, samples [corner indices, barycentric weights, cell, ao (1 = open)].
"""
import bpy, json, math, random, sys
from mathutils.bvhtree import BVHTree

cfg = json.load(open(sys.argv[sys.argv.index('--') + 1]))
R = float(cfg.get('radius', .5)); NR = int(cfg.get('rays', 256)); G = float(cfg.get('grid', 12)); NL = int(cfg.get('lattice', 3))
verts, polys = [], []
for n in cfg['occluders']:
    ob = bpy.data.objects[n]; mw = ob.matrix_world; base = len(verts)
    verts += [mw @ v.co for v in ob.data.vertices]
    # A second implicit triangulation can put ray origins inside a warped quad
    # (INC-091). Use the same explicit mesh tessellation as the receiver below.
    ob.data.calc_loop_triangles()
    polys += [[base + i for i in tri.vertices] for tri in ob.data.loop_triangles]
bvh = BVHTree.FromPolygons(verts, polys, all_triangles=True, epsilon=0.0)
k = int(math.sqrt(NR)); dirs = []
for a in range(k):
    for b in range(NR // k):
        u = (a + .5) / k; v = (b + .5) / (NR // k); r = math.sqrt(u); t = 2 * math.pi * v
        dirs.append((r * math.cos(t), r * math.sin(t), math.sqrt(max(0., 1 - u))))
rng = random.Random(7); out = []; total = 0
for tg in cfg['targets']:
    ob = bpy.data.objects[tg['object']]; me = ob.data; mw = ob.matrix_world; nm = mw.to_3x3(); S = float(tg['page'])
    me.calc_loop_triangles(); uvl = me.uv_layers[tg['uv']].data
    tris = {}
    for lt in me.loop_triangles:
        tris.setdefault(lt.polygon_index, []).append(lt)
    for poly in me.polygons:
        n = (nm @ poly.normal).normalized(); t1 = n.orthogonal().normalized(); t2 = n.cross(t1)
        samples = []
        for lt in tris.get(poly.index, []):
            L = list(lt.loops); uv = [uvl[l].uv * S for l in L]
            co = [mw @ me.vertices[me.loops[l].vertex_index].co for l in L]; corner = [l - poly.loop_start for l in L]
            (ax, ay), (bx, by), (cx, cy) = uv[0], uv[1], uv[2]
            den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(den) > 1e-12:
                x0, x1 = min(q.x for q in uv), max(q.x for q in uv); y0, y1 = min(q.y for q in uv), max(q.y for q in uv)
                for i in range(int(math.floor(x0 / G)), int(math.ceil(x1 / G)) + 1):
                    for j in range(int(math.floor(y0 / G)), int(math.ceil(y1 / G)) + 1):
                        px, py = (i + .5) * G, (j + .5) * G
                        w0 = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / den
                        w1 = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / den
                        if min(w0, w1, 1 - w0 - w1) >= -1e-9:
                            samples.append((corner, (w0, w1, 1 - w0 - w1), co, (i, j)))
            for a in range(NL + 1):
                for b in range(NL + 1 - a):
                    w0 = (a + 1 / 3) / (NL + 1); w1 = (b + 1 / 3) / (NL + 1); w2 = 1 - w0 - w1
                    if w2 >= 0:
                        c = uv[0] * w0 + uv[1] * w1 + uv[2] * w2
                        samples.append((corner, (w0, w1, w2), co, (int(c.x // G), int(c.y // G))))
        rows = []
        for corner, w, co, cell in samples:
            pos = co[0] * w[0] + co[1] * w[1] + co[2] * w[2] + n * 1e-3
            rot = rng.random() * 2 * math.pi; cr, sr = math.cos(rot), math.sin(rot); hits = 0
            for dx, dy, dz in dirs:
                d = t1 * (dx * cr - dy * sr) + t2 * (dx * sr + dy * cr) + n * dz
                if bvh.ray_cast(pos, d, R)[0] is not None:
                    hits += 1
            rows.append([corner, [round(x, 5) for x in w], list(cell), round(1 - hits / len(dirs), 4)])
        total += len(rows)
        out.append(dict(face=f"{tg.get('key', tg['object'])}:{poly.index}", page=tg.get('key', tg['object']), samples=rows))
json.dump(dict(radius=R, rays=len(dirs), grid=G, faces=out), open(cfg['out'], 'w'))
print('AO_DONE faces', len(out), 'samples', total)
