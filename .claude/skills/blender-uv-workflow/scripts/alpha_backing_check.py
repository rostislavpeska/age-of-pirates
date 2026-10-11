"""What shows THROUGH an alpha cut-out? (background Blender; read-only). Owner 2026-10-11 (Tower skirt eave): "the alpha cut is
improper, maybe needs hardening" - the eave fronts' scallop gaps showed the eave's own back / under faces, which the UV step
had classified hidden and put on the opaque shared r65 page: lit grey filled every gap, so the cut read as a solid band.

    blender -b UV.blend --python alpha_backing_check.py -- --page 5 --size 1024 --basecolor P5_BaseColor.png
        --pages 0=P0_BaseColor.png,4=r65_BaseColor.png,5=P5_BaseColor.png --objects-prefix Market.Roof --max-lum .32
        --report BACKING.json [--samples 4000]

For every OWNED face on the alpha page whose texels are cut (BaseColor A < .5), sample cut texels, lift each to its 3D point
(barycentric through the face's UV triangle) and cast a ray from just in front of the face into the model (-normal). The
first hit within --reach (0.6 m) is what a viewer sees through the hole: its page and texel colour are looked up. FAIL when
the hit is the SAME roof's opaque surface within --own-depth (it plugs the silhouette: the gap reads as a band), or a
surface lighter than --max-lum, unless that texel is itself cut. A cut must open onto sky, the building behind, or another cut.
Writes the backing faces (object:face) for the repair.
"""
import argparse, json, sys
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ap = argparse.ArgumentParser(); ap.add_argument('--page', type=int, default=5); ap.add_argument('--size', type=int, default=1024)
ap.add_argument('--basecolor', required=True); ap.add_argument('--pages', required=True); ap.add_argument('--objects-prefix', default='')
ap.add_argument('--reach', type=float, default=.6); ap.add_argument('--own-depth', type=float, default=.35); ap.add_argument('--max-lum', type=float, default=.32); ap.add_argument('--samples', type=int, default=4000)
ap.add_argument('--report', required=True); ap.add_argument('--uv', default='UV_Provisional_r2'); ap.add_argument('--seed', type=int, default=3)
ap.add_argument('--collection', default='Market | LOW geometry'); ap.add_argument('--resource-attr', default='uv_resource_r2'); ap.add_argument('--role-attr', default='share_role_r2')
ap.add_argument('--group-depth', type=int, default=3, help='name segments that identify one assembly (Market.Roof.<Roof> = 3)')
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])
for s in bpy.data.scenes:
    for vl in s.view_layers:
        vl.update()


def load_png(path):
    im = bpy.data.images.load(path, check_existing=False); w, h = im.size; px = np.array(im.pixels[:], np.float32).reshape(h, w, im.channels)[::-1]
    bpy.data.images.remove(im); return px                                                   # rows top-down, linear->display: PNG is sRGB bytes/255


BC = load_png(a.basecolor); PG = {int(k): load_png(v) for k, v in (x.split('=', 1) for x in a.pages.split(','))}
LOW = [o for o in bpy.data.collections[a.collection].objects if o.type == 'MESH']
# world BVH of every LOW face with a back-reference
verts, polys, ref = [], [], []
for o in LOW:
    M = o.matrix_world; base = len(verts); verts += [M @ v.co for v in o.data.vertices]
    for p in o.data.polygons:
        polys.append([base + i for i in p.vertices]); ref.append((o, p.index))
bvh = BVHTree.FromPolygons(verts, polys)
rng = np.random.default_rng(a.seed); N = a.size; hits = {}; rows = []; light = 0; total = 0


def texel(o, fi, loc):
    """page and colour of the texel a world point on face fi of o maps to"""
    me = o.data; p = me.polygons[fi]; res = me.attributes[a.resource_attr].data[fi].value
    if res not in PG:
        return res, None
    M = o.matrix_world; ul = me.uv_layers[a.uv].data; L = list(p.loop_indices)
    P3 = [M @ me.vertices[me.loops[l].vertex_index].co for l in L]; UVs = [Vector(tuple(ul[l].uv)) for l in L]
    for i in range(1, len(L) - 1):                                                        # fan triangles: barycentric in 3D
        from mathutils.geometry import barycentric_transform, intersect_point_tri
        if intersect_point_tri(loc, P3[0], P3[i], P3[i + 1]) is not None or i == len(L) - 2:
            uv = barycentric_transform(loc, P3[0], P3[i], P3[i + 1], UVs[0].to_3d(), UVs[i].to_3d(), UVs[i + 1].to_3d())
            img = PG[res]; S = img.shape[0]; x = int(np.clip(uv.x * S, 0, S - 1)); y = int(np.clip((1 - uv.y) * S, 0, S - 1))
            return res, img[y, x]
    return res, None


for o in LOW:
    if a.objects_prefix and not o.name.startswith(a.objects_prefix):
        continue
    me = o.data; A = me.attributes; M = o.matrix_world; R3 = M.to_3x3(); ul = me.uv_layers[a.uv].data
    for p in me.polygons:
        if A[a.resource_attr].data[p.index].value != a.page or A[a.role_attr].data[p.index].value == 2:
            continue
        L = list(p.loop_indices); UV = np.array([(ul[l].uv.x * N, (1 - ul[l].uv.y) * N) for l in L])
        P3 = [M @ me.vertices[me.loops[l].vertex_index].co for l in L]; n = (R3 @ p.normal).normalized()
        x0, y0 = np.floor(UV.min(0)).astype(int); x1, y1 = np.ceil(UV.max(0)).astype(int)
        cand = [(x, y) for y in range(max(y0, 0), min(y1, N)) for x in range(max(x0, 0), min(x1, N)) if BC[y, x, 3] < .5]
        if not cand:
            continue
        for x, y in [cand[i] for i in rng.choice(len(cand), min(len(cand), 24), replace=False)]:
            c = np.array([x + .5, y + .5])
            for i in range(1, len(L) - 1):                                                # 2D barycentric in UV, lift to 3D
                T = UV[[0, i, i + 1]]; d = (T[1, 1] - T[2, 1]) * (T[0, 0] - T[2, 0]) + (T[2, 0] - T[1, 0]) * (T[0, 1] - T[2, 1])
                if abs(d) < 1e-12:
                    continue
                l0 = ((T[1, 1] - T[2, 1]) * (c[0] - T[2, 0]) + (T[2, 0] - T[1, 0]) * (c[1] - T[2, 1])) / d
                l1 = ((T[2, 1] - T[0, 1]) * (c[0] - T[2, 0]) + (T[0, 0] - T[2, 0]) * (c[1] - T[2, 1])) / d; l2 = 1 - l0 - l1
                if min(l0, l1, l2) >= -1e-6:
                    pt = P3[0] * l0 + P3[i] * l1 + P3[i + 1] * l2; break
            else:
                continue
            total += 1; start = pt + n * .003
            loc, nn, idx, dist = bvh.ray_cast(start, -n, a.reach)
            if idx is None:
                rows.append({'sky': True}); continue
            ho, hf = ref[idx]
            if ho == o and hf == p.index:                                                  # the face itself: step through it
                loc2, nn2, idx2, dist2 = bvh.ray_cast(loc - n * .002, -n, a.reach)
                if idx2 is None:
                    rows.append({'sky': True}); continue
                loc, idx = loc2, idx2; ho, hf = ref[idx]
            hn = (ho.matrix_world.to_3x3() @ ho.data.polygons[hf].normal).normalized()
            if hn.dot(-n) > 0:                                                              # seen from behind: a single-sided game
                rows.append({'backface': f'{ho.name}:{hf}'}); continue                       # material culls it (not a plug)
            res, col = texel(ho, hf, loc); dist = (loc - start).length
            cut = col is not None and len(col) > 3 and col[3] < .5
            lum = float(col[:3] @ np.array([.299, .587, .114])) if col is not None else -1.
            roof = lambda nm: '.'.join(nm.split('.')[:a.group_depth])                         # one assembly, e.g. Market.Roof.<Roof>
            own = roof(ho.name) == roof(o.name) and dist < a.own_depth                        # the roof's own surface right behind
            key = f'{ho.name}:{hf}'; h = hits.setdefault(key, {'page': res, 'lum': [], 'cut': 0, 'n': 0, 'from': set(), 'own': 0, 'dist': []})
            h['lum'].append(lum); h['n'] += 1; h['cut'] += int(cut); h['from'].add(o.name); h['own'] += int(own); h['dist'].append(dist)
            if (own and not cut) or (lum > a.max_lum and not cut):
                light += 1
# a backing face: the roof's own opaque surface right behind the cut (it plugs the silhouette), or a light surface
bad = {k: {'page': v['page'], 'samples': v['n'], 'own_hits': v['own'], 'mean_lum': round(float(np.mean(v['lum'])), 3),
           'mean_dist_m': round(float(np.mean(v['dist'])), 3), 'from': sorted(v['from'])}
       for k, v in hits.items() if v['cut'] < v['n'] / 2 and (v['own'] > v['n'] / 2 or np.mean(v['lum']) > a.max_lum)}
rep = {'samples': total, 'plugged_hits': light, 'backface_hits': sum(1 for r in rows if 'backface' in r), 'own_depth_m': a.own_depth, 'sky': sum(1 for r in rows if r.get('sky')), 'max_lum': a.max_lum,
       'backing_faces': sorted(bad), 'detail': bad, 'status': 'PASS' if light <= .02 * max(total, 1) else 'FAIL'}
json.dump(rep, open(a.report, 'w'), indent=1)
print('ALPHA_BACKING', rep['status'], 'samples', total, 'plugged hits', light, 'sky', rep['sky'], 'backing faces', len(bad),
      'pages', sorted({v['page'] for v in bad.values()}))
