"""Dump the meshes an organic unwrap plans on (background Blender, read only, nothing saved).

    blender -b FILE.blend --factory-startup --python-exit-code 2 --python mesh_dump.py -- --out ABS.json
            [--objects A,B] [--part-attr part] [--part-names NAMES.json] [--part-map PARTS.json]
            [--vertex-attrs ring,slot] [--mirror-tol 1e-4]

Per object: local vertex positions, the world matrix, polygons (corner order), Blender's loop triangles [a, b, c,
polygon] (the triangles uv_eval measures; a quad's diagonal is Blender's choice), edges, part labels per polygon
(INT or STRING face attribute --part-attr, names from --part-names {int: name}; else --part-map {object: [name per
polygon]}), the named INT vertex attributes (ring / slot ids of a ring-built body), every vertex-group weight, the
left/right mirror map across local x = 0 (-1 = no partner within --mirror-tol), UV layer names, materials and the
edges already marked as seams. The seam planner (seam_plan.py) and the layout (organic_layout.py) read this file.
OUT must be absolute and outside every git work tree. Exit 0 = written, 2 = setup error.
"""
import argparse
import json
import os
import sys

import bpy
from mathutils import kdtree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import uvenv  # noqa: E402

SCHEMA = 'blender-organic-uv/mesh-dump/1'


def parse(argv):
    ap = argparse.ArgumentParser(prog='mesh_dump.py', description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--out', required=True)
    ap.add_argument('--objects', default='', help='comma list (default: every mesh object)')
    ap.add_argument('--part-attr', default='part')
    ap.add_argument('--part-names', help='JSON {int: name} for an INT part attribute')
    ap.add_argument('--part-map', help='JSON {object: [part per polygon]} for objects without the attribute')
    ap.add_argument('--vertex-attrs', default='ring,slot', help='INT vertex attributes to dump when present')
    ap.add_argument('--mirror-tol', type=float, default=1e-4, help='mirror partner tolerance in model units')
    return ap.parse_args(argv)


def mirror_map(me, tol):
    n = len(me.vertices)
    kd = kdtree.KDTree(n)
    for v in me.vertices:
        kd.insert(v.co, v.index)
    kd.balance()
    mm, worst, unmatched = [], 0.0, 0
    for v in me.vertices:
        co = v.co.copy()
        co.x = -co.x
        _, i, d = kd.find(co)
        if d is None or d > tol:
            unmatched += 1
            mm.append(-1)
        else:
            mm.append(i)
            worst = max(worst, d)
    return mm, unmatched, worst


def main():
    a = parse(uvenv.blender_argv())
    if not os.path.isabs(a.out):
        raise SystemExit('SETUP ERROR: --out must be absolute')
    why = uvenv.refuse_in_worktree(a.out, 'mesh dump')
    if why:
        raise SystemExit('SETUP ERROR: ' + why)
    names = [n for n in a.objects.split(',') if n] or [o.name for o in bpy.data.objects if o.type == 'MESH']
    part_names = json.load(open(a.part_names)) if a.part_names else {}
    part_map = json.load(open(a.part_map)) if a.part_map else {}
    vattrs = [x for x in a.vertex_attrs.split(',') if x]
    out = {'schema': SCHEMA, 'blend': bpy.data.filepath, 'blender': bpy.app.version_string, 'objects': {}}
    for n in names:
        ob = bpy.data.objects.get(n)
        if ob is None or ob.type != 'MESH':
            raise SystemExit('SETUP ERROR: mesh object not found: %s' % n)
        me = ob.data
        parts, src = None, None
        at = me.attributes.get(a.part_attr)
        if at is not None and at.domain == 'FACE':
            vals = [d.value for d in at.data]
            parts = [v.decode() if isinstance(v, bytes) else str(part_names.get(str(v), v)) for v in vals]
            src = 'face attribute %s' % a.part_attr
        elif n in part_map:
            pm = part_map[n]
            if not isinstance(pm, list) or len(pm) != len(me.polygons):
                raise SystemExit('SETUP ERROR: part map for %s has %s entries, mesh has %d polygons'
                                 % (n, len(pm) if isinstance(pm, list) else type(pm).__name__, len(me.polygons)))
            parts = [str(x) for x in pm]
            src = 'part map'
        va = {}
        for an in vattrs:
            at = me.attributes.get(an)
            if at is not None and at.domain == 'POINT' and at.data_type == 'INT':
                va[an] = [d.value for d in at.data]
        gn = {g.index: g.name for g in ob.vertex_groups}
        weights = [sorted(([gn[g.group], round(g.weight, 7)] for g in v.groups if g.weight > 0 and g.group in gn),
                          key=lambda t: -t[1]) for v in me.vertices]
        mm, unmatched, worst = mirror_map(me, a.mirror_tol)
        me.calc_loop_triangles()
        # Blender's own triangles (the evaluator measures these): a triangle polygon keeps its corner order
        tris = [list(me.polygons[t.polygon_index].vertices) + [t.polygon_index]
                if len(me.polygons[t.polygon_index].vertices) == 3 else list(t.vertices) + [t.polygon_index]
                for t in me.loop_triangles]
        out['objects'][n] = {
            'verts': len(me.vertices), 'polys_count': len(me.polygons),
            'co': [list(v.co) for v in me.vertices],
            'matrix_world': [list(r) for r in ob.matrix_world],
            'polys': [list(p.vertices) for p in me.polygons],
            'tris': tris,
            'edges': [list(e.vertices) for e in me.edges],
            'parts': parts, 'part_source': src, 'vattrs': va, 'weights': weights,
            'vertex_groups': [g.name for g in ob.vertex_groups],
            'mirror_map': mm, 'mirror_unmatched': unmatched, 'mirror_worst': worst,
            'centre_verts': sum(1 for v in me.vertices if abs(v.co.x) <= a.mirror_tol),
            'uv_layers': [u.name for u in me.uv_layers],
            'materials': [s.material.name if s.material else None for s in ob.material_slots],
            'marked_seams': [list(e.vertices) for e in me.edges if e.use_seam],
        }
    text = json.dumps(out)
    with open(a.out, 'w', encoding='utf-8') as f:
        f.write(text)
    print('MESH_DUMP_OK', a.out, {n: (d['verts'], d['polys_count'], d['part_source'], d['mirror_unmatched'])
                                  for n, d in out['objects'].items()})


if __name__ == '__main__':
    main()
