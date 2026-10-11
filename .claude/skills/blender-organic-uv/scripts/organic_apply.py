"""Write a finished organic layout into a COPY of the .blend (background Blender; the source file is never saved).

    blender -b SOURCE.blend --factory-startup --python-exit-code 2 --python organic_apply.py -- \
            --layout ABS_LAYOUT.json --out ABS_COPY.blend --report ABS_REPORT.json [--layer UV_ORGANIC]
            [--remove-uv-layer UVMap ...] [--seams ABS_SEAMS.json] [--no-mark-seams] [--replace]

1 fingerprint every mesh object (positions, polygons, edges, weights, vertex groups, modifiers, matrix, parent,
  materials, attributes, seams);
2 a new UV layer --layer on every layout object, written per polygon corner, made active and active-render
  (--replace overwrites an existing layer of that name, otherwise refused);
3 --remove-uv-layer removes a named layer (a placeholder) from the layout objects: an exporter that writes the first
  or every layer would otherwise ship it, and the GPU vertex count includes it (one placeholder pushed a rider from
  1001 to 1065 vertices, over a 1,050 ceiling);
4 seams := the borders of the new layer's islands (so the file carries them), compared with the planned seams when
  --seams is given;
5 fingerprint again: everything but UV layers and seam flags must be identical (exit 3 otherwise, nothing saved);
  save_as_mainfile(copy=True) to --out.
OUT and REPORT must be absolute and outside every git work tree. Exit 0 = saved, 2 = setup error, 3 = geometry changed.
"""
import argparse
import collections
import hashlib
import json
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import uvenv  # noqa: E402

GEOM_KEYS = ['counts', 'positions', 'polygons', 'edges', 'weights', 'vertex_groups', 'modifiers', 'matrix', 'parent',
             'materials', 'attributes']


def parse(argv):
    ap = argparse.ArgumentParser(prog='organic_apply.py', description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--layout', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--report', required=True)
    ap.add_argument('--layer', default='UV_ORGANIC')
    ap.add_argument('--remove-uv-layer', action='append', default=[])
    ap.add_argument('--seams', help='seam plan to compare the marked seams with')
    ap.add_argument('--no-mark-seams', action='store_true')
    ap.add_argument('--replace', action='store_true')
    return ap.parse_args(argv)


def ekey(a, b):
    return (a, b) if a < b else (b, a)


def fingerprint(ob):
    me = ob.data
    co = np.zeros(len(me.vertices) * 3, np.float64)
    me.vertices.foreach_get('co', co)
    h = lambda b: hashlib.sha256(b).hexdigest()[:16]  # noqa: E731
    polys = repr([tuple(p.vertices) for p in me.polygons]).encode()
    edges = repr(sorted(tuple(sorted(e.vertices)) for e in me.edges)).encode()
    gn = {g.index: g.name for g in ob.vertex_groups}
    w = repr([sorted((gn[g.group], round(g.weight, 7)) for g in v.groups) for v in me.vertices]).encode()
    sm = np.zeros(len(me.edges), bool)
    me.edges.foreach_get('use_seam', sm)
    uvn = [u.name for u in me.uv_layers]
    return {'counts': [len(me.vertices), len(me.edges), len(me.polygons), len(me.loops)], 'positions': h(co.tobytes()),
            'polygons': h(polys), 'edges': h(edges), 'weights': h(w), 'vertex_groups': [g.name for g in ob.vertex_groups],
            'modifiers': [(m.name, m.type, getattr(getattr(m, 'object', None), 'name', None)) for m in ob.modifiers],
            'matrix': h(np.array([list(r) for r in ob.matrix_world]).tobytes()),
            'parent': ob.parent.name if ob.parent else None,
            'materials': [s.material.name if s.material else None for s in ob.material_slots],
            'attributes': sorted(a.name for a in me.attributes if a.name not in uvn and 'seam' not in a.name
                                 and not a.name.startswith(('.select', '.uv_select', '.pin', '.vs.', '.es.'))),
            'seams': h(sm.tobytes()), 'n_seams': int(sm.sum()), 'uv_layers': uvn,
            'active_uv': me.uv_layers.active.name if me.uv_layers.active else None,
            'active_render': [u.name for u in me.uv_layers if u.active_render]}


def uv_border_edges(me, layer):
    uvl = me.uv_layers[layer].data
    corner = {}
    for p in me.polygons:
        for li in p.loop_indices:
            corner[(p.index, me.loops[li].vertex_index)] = tuple(round(c, 6) for c in uvl[li].uv)
    ef = collections.defaultdict(list)
    for p in me.polygons:
        for k in p.edge_keys:
            ef[ekey(*k)].append(p.index)
    return {e for e, fs in ef.items() if len(fs) == 2 and any(corner[(fs[0], v)] != corner[(fs[1], v)] for v in e)}


def main():
    a = parse(uvenv.blender_argv())
    for p, what in ((a.out, 'blend copy'), (a.report, 'apply report')):
        if not os.path.isabs(p):
            raise SystemExit('SETUP ERROR: %s path must be absolute' % what)
        why = uvenv.refuse_in_worktree(p, what)
        if why:
            raise SystemExit('SETUP ERROR: ' + why)
    if os.path.abspath(a.out) == os.path.abspath(bpy.data.filepath):
        raise SystemExit('SETUP ERROR: --out is the source file; write a copy')
    if a.layer in a.remove_uv_layer:
        raise SystemExit('SETUP ERROR: --remove-uv-layer names the new layer')
    LY = json.load(open(a.layout, encoding='utf-8'))
    names = list(LY['objects'])
    for n in names:
        ob = bpy.data.objects.get(n)
        if ob is None or ob.type != 'MESH':
            raise SystemExit('SETUP ERROR: mesh object not found: %s' % n)
        if a.layer in ob.data.uv_layers and not a.replace:
            raise SystemExit('SETUP ERROR: %s already has a layer %s (pass --replace)' % (n, a.layer))
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    rep = {'source': bpy.data.filepath, 'out': a.out, 'layer': a.layer, 'layout': a.layout,
           'blender': bpy.app.version_string, 'before': {o.name: fingerprint(o) for o in meshes}, 'write': {}}
    for n in names:
        me = bpy.data.objects[n].data
        if a.layer in me.uv_layers:
            me.uv_layers.remove(me.uv_layers[a.layer])
        uvl = me.uv_layers.new(name=a.layer)
        if uvl is None:
            raise SystemExit('SETUP ERROR: %s: Blender refused a new UV layer (limit of 8 reached?)' % n)
        uvs, verts = LY['objects'][n]['polys'], LY['objects'][n]['verts']
        if len(uvs) != len(me.polygons):
            raise SystemExit('SETUP ERROR: %s: layout has %d polygons, mesh %d' % (n, len(uvs), len(me.polygons)))
        for p in me.polygons:
            vl = verts[p.index]
            if sorted(vl) != sorted(p.vertices):
                raise SystemExit('SETUP ERROR: %s: polygon %d differs from the layout' % (n, p.index))
            for li in p.loop_indices:
                uvl.data[li].uv = uvs[p.index][vl.index(me.loops[li].vertex_index)]
        me.uv_layers.active = uvl
        uvl.active_render = True
        rep['write'][n] = {'page': LY['objects'][n].get('page'), 'page_size': LY['objects'][n].get('page_size')}
    rep['removed_layers'] = {}
    for n in names:
        me = bpy.data.objects[n].data
        gone = []
        for lname in a.remove_uv_layer:
            if lname in me.uv_layers:
                me.uv_layers.remove(me.uv_layers[lname])
                gone.append(lname)
        me.uv_layers.active = me.uv_layers[a.layer]
        me.uv_layers[a.layer].active_render = True
        rep['removed_layers'][n] = gone
    plan = None
    if a.seams:
        plan = {k: set(ekey(*e) for e in v['seams']) for k, v in json.load(open(a.seams))['objects'].items()}
    rep['seams'] = {}
    if not a.no_mark_seams:
        for n in names:
            me = bpy.data.objects[n].data
            se = uv_border_edges(me, a.layer)
            me.edges.foreach_set('use_seam', [ekey(*e.vertices) in se for e in me.edges])
            me.update()
            row = {'marked': len(se)}
            if plan is not None and n in plan:
                row.update(planned=len(plan[n]), planned_not_uv_border=len(plan[n] - se),
                           uv_border_not_planned=len(se - plan[n]), examples_extra=sorted(se - plan[n])[:12],
                           examples_missing=sorted(plan[n] - se)[:12])
            rep['seams'][n] = row
    rep['after'] = {o.name: fingerprint(o) for o in meshes}
    diff = {}
    for o in meshes:
        b, af = rep['before'][o.name], rep['after'][o.name]
        d = [k for k in GEOM_KEYS if b[k] != af[k]]
        if o.name not in names and (b['seams'] != af['seams'] or b['uv_layers'] != af['uv_layers']):
            d.append('object outside the layout touched')
        if d:
            diff[o.name] = d
    rep['geometry_diff'] = diff
    rep['geometry_unchanged'] = not diff
    text = json.dumps(rep, indent=1)
    with open(a.report, 'w', encoding='utf-8') as f:
        f.write(text)
    if diff:
        print('GEOMETRY CHANGED', diff)
        sys.exit(3)
    bpy.ops.wm.save_as_mainfile(filepath=a.out, copy=True)
    print('APPLY_OK', a.out, {n: (rep['after'][n]['uv_layers'], rep['after'][n]['n_seams']) for n in names})


if __name__ == '__main__':
    main()
