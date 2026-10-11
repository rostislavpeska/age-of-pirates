"""Flatten a seam plan (background Blender): mark the planned seams, unwrap each object, dump the raw UVs. The .blend
is never saved; the work layer exists only in memory.

    blender -b FILE.blend --factory-startup --python-exit-code 2 --python organic_unwrap.py -- \
            --seams ABS_SEAMS.json --out ABS_RAW.json [--objects A,B] [--method MINIMUM_STRETCH] [--iterations 50]
            [--object-method NAME=ANGLE_BASED ...] [--no-fill-holes] [--allow-flip] [--allow-conformal]

Defaults are the measured organic recipe: SLIM (MINIMUM_STRETCH) with no_flip, fill_holes and 50 iterations (10 gave
angle-stretch p90 1.36, 50 gave 1.31 on a rider body, for < 0.1 s). ANGLE_BASED (ABF++) is the per-object fallback
only; CONFORMAL (LSCM) is refused unless --allow-conformal (it collapses closed ends and drifts in scale along bands).
The method is always passed explicitly: the operator's RNA default in Blender 5.1 is CONFORMAL.

Output (schema blender-organic-uv/raw-unwrap/1): per object the method, the polygons in mesh order with their vertex
ids and per-corner UVs, the marked seam count and the faces flipped by the solver. OUT must be absolute and outside
every git work tree. Exit 0 = written, 1 = a solver left flipped faces (written anyway), 2 = setup error.
"""
import argparse
import json
import os
import sys

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import uvenv  # noqa: E402

SCHEMA = 'blender-organic-uv/raw-unwrap/1'
LAYER = 'UV_ORGANIC_WORK'
METHODS = ('MINIMUM_STRETCH', 'ANGLE_BASED', 'CONFORMAL')


def parse(argv):
    ap = argparse.ArgumentParser(prog='organic_unwrap.py', description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--seams', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--objects', default='', help='comma list (default: every object in the seam plan)')
    ap.add_argument('--method', default='MINIMUM_STRETCH', choices=METHODS)
    ap.add_argument('--iterations', type=int, default=50, help='SLIM iterations (default 50)')
    ap.add_argument('--object-method', action='append', default=[], metavar='NAME=METHOD',
                    help='per-object solver override, e.g. Helmet=ANGLE_BASED (repeatable)')
    ap.add_argument('--no-fill-holes', action='store_true')
    ap.add_argument('--allow-flip', action='store_true', help='SLIM without no_flip (experiments only)')
    ap.add_argument('--allow-conformal', action='store_true', help='permit CONFORMAL (experiments only)')
    return ap.parse_args(argv)


def signed_area(uvs):
    s = 0.0
    for i in range(len(uvs)):
        (x0, y0), (x1, y1) = uvs[i], uvs[(i + 1) % len(uvs)]
        s += x0 * y1 - x1 * y0
    return 0.5 * s


def main():
    a = parse(uvenv.blender_argv())
    for p, what in ((a.out, 'raw unwrap'),):
        if not os.path.isabs(p):
            raise SystemExit('SETUP ERROR: --out must be absolute')
        why = uvenv.refuse_in_worktree(p, what)
        if why:
            raise SystemExit('SETUP ERROR: ' + why)
    per = {}
    for item in a.object_method:
        if '=' not in item:
            raise SystemExit('SETUP ERROR: --object-method NAME=METHOD, got %r' % item)
        n, m = item.split('=', 1)
        if m not in METHODS:
            raise SystemExit('SETUP ERROR: unknown method %s' % m)
        per[n] = m
    if not a.allow_conformal and ('CONFORMAL' in per.values() or a.method == 'CONFORMAL'):
        raise SystemExit('SETUP ERROR: CONFORMAL (LSCM) refused for organic meshes; pass --allow-conformal for an '
                         'experiment')
    plan = json.load(open(a.seams, encoding='utf-8'))
    names = [n for n in a.objects.split(',') if n] or list(plan['objects'])
    res = {'schema': SCHEMA, 'blender': bpy.app.version_string, 'blend': bpy.data.filepath, 'seams_file': a.seams,
           'defaults': {'method': a.method, 'iterations': a.iterations, 'no_flip': not a.allow_flip,
                        'fill_holes': not a.no_fill_holes}, 'objects': {}}
    for o in bpy.data.objects:
        o.hide_set(False)
        o.hide_viewport = False
    flipped_total = 0
    for name in names:
        ob = bpy.data.objects.get(name)
        if ob is None or ob.type != 'MESH':
            raise SystemExit('SETUP ERROR: mesh object not found: %s' % name)
        if name not in plan['objects']:
            raise SystemExit('SETUP ERROR: %s has no seam plan' % name)
        me = ob.data
        if bpy.context.object and bpy.context.object.mode != 'OBJECT':
            bpy.ops.object.mode_set(mode='OBJECT')
        uvl = me.uv_layers.get(LAYER) or me.uv_layers.new(name=LAYER)
        me.uv_layers.active = uvl
        seam_set = set(tuple(sorted(e)) for e in plan['objects'][name]['seams'])
        edge_keys = set(tuple(sorted(e.vertices)) for e in me.edges)
        unknown = seam_set - edge_keys
        if unknown:
            raise SystemExit('SETUP ERROR: %s: %d planned seams are not edges of this mesh (wrong object or vertex '
                             'order), e.g. %s' % (name, len(unknown), sorted(unknown)[:3]))
        for e in me.edges:
            e.use_seam = tuple(sorted(e.vertices)) in seam_set
        bpy.ops.object.select_all(action='DESELECT')
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.mode_set(mode='EDIT')
        bm = bmesh.from_edit_mesh(me)
        for f in bm.faces:
            f.select_set(True)
        bmesh.update_edit_mesh(me)
        method = per.get(name, a.method)
        kw = dict(method=method, fill_holes=not a.no_fill_holes, correct_aspect=True, margin=0.0)
        if method == 'MINIMUM_STRETCH':
            kw.update(iterations=a.iterations, no_flip=not a.allow_flip)
        r = bpy.ops.uv.unwrap(**kw)
        bm = bmesh.from_edit_mesh(me)
        uvb = bm.loops.layers.uv[LAYER]
        bm.faces.ensure_lookup_table()
        polys, flipped = [], 0
        for f in bm.faces:
            uvs = [list(l[uvb].uv) for l in f.loops]
            polys.append({'v': [l.vert.index for l in f.loops], 'uv': uvs})
            flipped += signed_area(uvs) < 0
        bpy.ops.object.mode_set(mode='OBJECT')
        flipped_total += flipped
        res['objects'][name] = {'method': method, 'unwrap': list(r), 'kwargs': kw, 'polys': polys,
                                'seams': len(seam_set), 'flipped_faces': flipped}
    text = json.dumps(res)
    with open(a.out, 'w', encoding='utf-8') as f:
        f.write(text)
    print('UNWRAP_OK', a.out, {n: (v['method'], len(v['polys']), v['flipped_faces']) for n, v in res['objects'].items()})
    sys.exit(1 if flipped_total else 0)


if __name__ == '__main__':
    main()
