"""Inventory of every texture seam on a model's geometric edges (background Blender, read-only): each mesh edge whose two
faces meet on DIFFERENT UV positions (a UV seam) or on different pages, with both sides' page px, the 3D edge, the
dihedral angle and each face's role, plus every face's page polygon (for texel ownership). Feeds seam_monitor.py.

    blender -b MODEL.blend --python seam_inventory.py -- --out SEAMS_INV.json --pages 0=2048,5=1024
        [--collection "Market | LOW geometry"] [--uv UV_Provisional_r2] [--resource-attr uv_resource_r2]
        [--role-attr share_role_r2] [--subtype-attr paint_subtype_r2] [--objects-prefix Market.]

Faces whose page (resource attribute) is not listed are ignored (shared hidden pages, collision, etc.). Each side also
records its paint subtype and material slot: a seam between different subtypes / materials is a material BOUNDARY
(ridge against tile field, sill against plaster), not a texture defect.
"""
import argparse, json, math, sys
import bpy
ap = argparse.ArgumentParser(); ap.add_argument('--out', required=True); ap.add_argument('--pages', required=True)
ap.add_argument('--collection', default=None); ap.add_argument('--uv', default=None); ap.add_argument('--resource-attr', default='uv_resource_r2')
ap.add_argument('--role-attr', default='share_role_r2'); ap.add_argument('--subtype-attr', default='paint_subtype_r2'); ap.add_argument('--objects-prefix', default='')
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])
for s in bpy.data.scenes:
    for vl in s.view_layers:
        vl.update()
SIZE = {int(k): int(v) for k, v in (x.split('=') for x in a.pages.split(','))}
objs = bpy.data.collections[a.collection].objects if a.collection else bpy.data.objects
objs = [o for o in objs if o.type == 'MESH' and o.name.startswith(a.objects_prefix)]


def attr(me, name, fi, default=None):
    at = me.attributes.get(name)
    if at is None or at.domain != 'FACE':
        return default
    v = at.data[fi].value
    return v.decode() if isinstance(v, bytes) else v


faces, seams, n_edges = [], [], 0
for o in objs:
    me = o.data; M = o.matrix_world; R3 = M.to_3x3()
    ul = (me.uv_layers[a.uv] if a.uv else me.uv_layers.active)
    if ul is None:
        continue
    ul = ul.data; page = {}; edges = {}
    for p in me.polygons:
        res = attr(me, a.resource_attr, p.index, 0)
        if res not in SIZE:
            continue
        N = SIZE[res]; L = list(p.loop_indices); px = [(ul[l].uv.x * N, (1 - ul[l].uv.y) * N) for l in L]
        page[p.index] = res
        faces.append({'obj': o.name, 'face': p.index, 'page': res, 'role': attr(me, a.role_attr, p.index), 'px': [[round(x, 3), round(y, 3)] for x, y in px]})
        vids = [me.loops[l].vertex_index for l in L]
        for k in range(len(L)):
            v1, v2 = vids[k], vids[(k + 1) % len(L)]; key = (min(v1, v2), max(v1, v2))
            u1, u2 = px[k], px[(k + 1) % len(L)]
            if v1 > v2:
                u1, u2 = u2, u1
            edges.setdefault(key, []).append((p.index, u1, u2))
    for key, sides in edges.items():
        if len(sides) != 2:
            continue
        n_edges += 1
        (fa, a1, a2), (fb, b1, b2) = sides
        pa, pb = page[fa], page[fb]
        same = pa == pb and math.dist(a1, b1) < .02 and math.dist(a2, b2) < .02
        if same:
            continue
        P1, P2 = M @ me.vertices[key[0]].co, M @ me.vertices[key[1]].co
        na = (R3 @ me.polygons[fa].normal).normalized(); nb = (R3 @ me.polygons[fb].normal).normalized()
        ca = me.polygons[fa]; cb = me.polygons[fb]
        cen = lambda f, Nn: [sum((ul[l].uv.x * Nn) for l in f.loop_indices) / len(f.loop_indices), sum((1 - ul[l].uv.y) * Nn for l in f.loop_indices) / len(f.loop_indices)]
        seams.append({'obj': o.name, 'faces': [fa, fb], 'pages': [pa, pb], 'roles': [attr(me, a.role_attr, fa), attr(me, a.role_attr, fb)],
                      'subtypes': [attr(me, a.subtype_attr, fa), attr(me, a.subtype_attr, fb)],
                      'materials': [me.polygons[fa].material_index, me.polygons[fb].material_index],
                      'p3': [list(P1), list(P2)], 'len_m': (P2 - P1).length,
                      'dihedral_deg': math.degrees(math.acos(max(-1., min(1., na.dot(nb))))),
                      'uv_a': [list(a1), list(a2)], 'uv_b': [list(b1), list(b2)], 'cen_a': cen(ca, SIZE[pa]), 'cen_b': cen(cb, SIZE[pb]),
                      'normals': [list(na), list(nb)]})
json.dump({'pages': SIZE, 'objects': len(objs), 'faces': faces, 'seams': seams}, open(a.out, 'w'))
print('SEAM_INVENTORY objects', len(objs), 'faces', len(faces), 'manifold edges', n_edges, 'seam edges', len(seams),
      'metres %.1f' % sum(s_['len_m'] for s_ in seams))
