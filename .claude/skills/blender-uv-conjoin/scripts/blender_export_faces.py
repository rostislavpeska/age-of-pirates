"""Inside Blender: export faces for conjoin.py.

    import runpy; runpy.run_path(path, init_globals=dict(ARGS=dict(
        objects=['House_A'], uv_layer='UVMap', out='C:/.../faces.json',
        target_density=256.0, page_texels=8192, chart_attribute=None)))

Charts are UV islands: faces joined across an edge whose two loops carry identical
UV coordinates (or, if chart_attribute names an INT face attribute, faces sharing
that value). Each chart's UVs are rescaled to target_density texels per world unit
(its own area density), so charts authored at different densities compare fairly.
Material = slot material name without the numeric .### suffix.
Face ids are "<object>:<polygon index>".
"""
import bpy, bmesh, json, math, re

A = globals().get('ARGS') or {}
objects = A['objects']; layer = A.get('uv_layer', 'UVMap'); out = A['out']
target = float(A.get('target_density', 256.)); page = float(A.get('page_texels', 8192))
normalize = bool(A.get('normalize', False))   # False: keep every chart's original UV size
attr_name = A.get('chart_attribute')


def area2(q):
    s = 0.
    for i in range(len(q)):
        x1, y1 = q[i]; x2, y2 = q[(i + 1) % len(q)]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2


faces = []
for name in objects:
    ob = bpy.data.objects[name]
    me = ob.data
    uvl = me.uv_layers[layer]
    mw = ob.matrix_world
    parent = list(range(len(me.polygons)))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]; x = parent[x]
        return x
    if attr_name:
        vals = [a.value for a in me.attributes[attr_name].data]
        first = {}
        for i, v in enumerate(vals):
            parent[i] = first.setdefault(v, i)
    else:
        bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
        lay = bm.loops.layers.uv[layer]
        for e in bm.edges:
            if len(e.link_faces) != 2:
                continue
            f1, f2 = e.link_faces
            def uv_at(f, v):
                for l in f.loops:
                    if l.vert == v:
                        return l[lay].uv
            same = all((uv_at(f1, v) - uv_at(f2, v)).length < 1e-6 for v in e.verts)
            if same:
                a, b = find(f1.index), find(f2.index)
                if a != b:
                    parent[a] = b
        bm.free()
    charts = {}
    for p in me.polygons:
        uv = [tuple(uvl.data[l].uv) for l in p.loop_indices]
        pts = [mw @ me.vertices[v].co for v in p.vertices]
        a3 = 0.
        for i in range(1, len(pts) - 1):
            a3 += ((pts[i] - pts[0]).cross(pts[i + 1] - pts[0])).length / 2
        mat = ob.material_slots[p.material_index].material.name if ob.material_slots and ob.material_slots[p.material_index].material else 'NONE'
        c = charts.setdefault(find(p.index), dict(uv=0., a3=0., faces=[]))
        c['uv'] += area2([(u * page, v * page) for u, v in uv]); c['a3'] += a3
        c['faces'].append((p.index, uv, re.sub(r'\.\d+$', '', mat)))
    for root, c in charts.items():
        dens = math.sqrt(c['uv'] / c['a3']) if c['a3'] > 1e-12 and c['uv'] > 0 else target
        k = target / dens if normalize else 1.
        for idx, uv, mat in c['faces']:
            faces.append(dict(id=f'{name}:{idx}', chart=f'{name}:{root}', material=mat,
                              uv=[[u * page * k, v * page * k] for u, v in uv], density=dens,
                              uv0=[list(t) for t in uv]))
json.dump(faces, open(out, 'w'))
print('exported', len(faces), 'faces', len({f['chart'] for f in faces}), 'charts')
