#!/usr/bin/env python
"""Compare tangents stored in a game vertex buffer with Blender's MikkTSpace tangents, in background Blender.

    python tangent_compare.py --input meshes.json [--out SCRATCH/tangents.json]
    python tangent_compare.py --make-synthetic SCRATCH/sphere.json     # Blender's own tangents, a self-test input
    python tangent_compare.py --blender-exe EXE ...                    # or --local-config FILE (tools.blender.path)
    blender -b --factory-startup --python-exit-code 2 --python tangent_compare.py -- --input meshes.json

Input JSON (written by the project's game-file reader; this package ships none):
    [{"file": "<name>", "meshes": [{"name": "<mesh>", "P": [[x, y, z], ...], "N": [[x, y, z(, w)], ...],
      "T": [[x, y, z, w], ...], "UV": [[u, v], ...], "I": [i0, i1, i2, ...]}]}]
P, N, T and UV are per vertex of the game buffer, any scale (int8 or float, normalized here); the sign of T's w is
the bitangent sign; I is the triangle list (nested one-element lists are flattened, degenerate triangles skipped).

Per mesh and for both UV conventions (v and 1-v) it builds the mesh, sets the stored normals as custom normals,
computes MikkTSpace tangents (Mesh.calc_tangents) and compares per corner: median and 5th percentile of the tangent
dot product, the shares above 0.95 and below -0.95, and the bitangent-sign agreement. A median near 1 with sign
agreement near 1 in one convention means the stored tangents match MikkTSpace in that convention, so a normal map
baked with MikkTSpace in Blender will shade as baked. Output defaults to a new temp folder; a path inside a git
work tree is refused. Exit 0 = written, 2 = setup error (missing or malformed input, refused path, no Blender) or
an unexpected exception; exit 2 writes no result.
"""
import argparse
import json
import math
import sys
import traceback
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import blender_env as E  # noqa: E402

try:
    import bmesh
    import bpy
except ImportError:  # host Python: relaunch in Blender
    bpy = None
if bpy is not None and not hasattr(bpy, 'app'):  # a stub or namespace 'bpy' on the host is not Blender
    bpy = None


class SetupError(Exception):
    pass


def load_input(path):
    """The input JSON, checked: per mesh P/N/T/UV of one length, T with a w component, indices in range."""
    try:
        data = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    except (OSError, ValueError) as exc:
        raise SetupError('--input %s: %s' % (path, exc))
    if not isinstance(data, list) or not data:
        raise SetupError('--input %s: expected a non-empty list of {"file", "meshes"}' % path)
    for f in data:
        meshes = f.get('meshes') if isinstance(f, dict) else None
        if not isinstance(meshes, list) or not meshes:
            raise SetupError('--input %s: every entry needs a non-empty "meshes" list' % path)
        for m in meshes:
            where = '%s / %s' % (f.get('file', '?'), m.get('name', '?') if isinstance(m, dict) else '?')
            try:
                n = len(m['P'])
                ok = (n > 0 and len(m['N']) == n and len(m['T']) == n and len(m['UV']) == n
                      and all(len(p) == 3 for p in m['P']) and all(len(x) >= 3 for x in m['N'])
                      and all(len(x) == 4 for x in m['T']) and all(len(x) == 2 for x in m['UV'])
                      and all(0 <= flat(i) < n for i in m['I']) and len(m['I']) >= 3)
            except (KeyError, TypeError, ValueError, IndexError):
                ok = False
            if not ok:
                raise SetupError('--input %s: mesh %s needs P, N, T (x, y, z, w), UV of one length and a triangle '
                                 'list I within range' % (path, where))
    return data


def flat(x):
    while isinstance(x, (list, tuple)):
        x = x[0]
    return int(x)


def norm(v):
    length = math.sqrt(sum(c * c for c in v)) or 1.0
    return [c / length for c in v]


def compare_mesh(file_name, m):
    P = [tuple(p) for p in m['P']]
    I = [flat(x) for x in m['I']]
    tris = [tuple(I[k:k + 3]) for k in range(0, len(I) - len(I) % 3, 3)]
    tris = [t for t in tris if len(set(t)) == 3]
    Ns = [norm(n[:3]) for n in m['N']]
    Ts = list(m['T'])
    rec = {'file': file_name, 'mesh': m['name'], 'tris': len(tris)}
    for variant in ('v', '1-v'):
        me = bpy.data.meshes.new('cmp')
        me.from_pydata(P, [], tris)
        me.update()
        uvl = me.uv_layers.new(name='UV')
        for poly in me.polygons:
            for li in poly.loop_indices:
                u, v = m['UV'][me.loops[li].vertex_index]
                uvl.data[li].uv = (u, v if variant == 'v' else 1.0 - v)
        for poly in me.polygons:
            poly.use_smooth = True
        me.normals_split_custom_set([Ns[me.loops[li].vertex_index] for li in range(len(me.loops))])
        me.calc_tangents(uvmap='UV')
        dots, sign_ok, n = [], 0, 0
        for lp in me.loops:
            ts = Ts[lp.vertex_index]
            d = sum(a * b for a, b in zip(norm(ts[:3]), list(lp.tangent)))
            dots.append(d)
            sign_ok += (1 if ts[3] >= 0 else -1) == (1 if lp.bitangent_sign >= 0 else -1)
            n += 1
        dots.sort()
        rec[variant] = {'corners': n, 'tangent_dot_median': round(dots[n // 2], 4),
                        'tangent_dot_p05': round(dots[n // 20], 4),
                        'share_dot_gt_0.95': round(sum(1 for d in dots if d > 0.95) / n, 4),
                        'share_dot_lt_-0.95': round(sum(1 for d in dots if d < -0.95) / n, 4),
                        'sign_agree': round(sign_ok / n, 4)}
        bpy.data.meshes.remove(me)
    return rec


def make_synthetic(path):
    """A UV sphere written in the input format with Blender's MikkTSpace tangents, one vertex per (vertex, UV)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8)
    ob = bpy.context.active_object
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(ob.data)
    bm.free()
    me = ob.data
    for p in me.polygons:
        p.use_smooth = True
    uv = me.uv_layers.active.data
    me.calc_tangents(uvmap=me.uv_layers.active.name)
    normals = me.corner_normals
    index, P, N, T, UV, I = {}, [], [], [], [], []
    for p in me.polygons:
        for li in p.loop_indices:
            lp = me.loops[li]
            key = (lp.vertex_index, round(uv[li].uv.x, 6), round(uv[li].uv.y, 6))
            if key not in index:
                index[key] = len(P)
                P.append(list(me.vertices[lp.vertex_index].co))
                N.append(list(normals[li].vector))
                T.append(list(lp.tangent) + [lp.bitangent_sign])
                UV.append([uv[li].uv.x, uv[li].uv.y])
            I.append(index[key])
    data = [{'file': 'synthetic_uv_sphere', 'meshes': [{'name': 'sphere', 'P': P, 'N': N, 'T': T, 'UV': UV, 'I': I}]}]
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(data), encoding='utf-8')
    print('SYNTHETIC %s: %d vertices, %d triangles' % (path, len(P), len(I) // 3))


def main_blender(argv):
    ap = argparse.ArgumentParser(prog='tangent_compare.py', description=__doc__.splitlines()[0])
    ap.add_argument('--input', help='input JSON (see the module docstring)')
    ap.add_argument('--out', help='result JSON (default: new temp folder)')
    ap.add_argument('--make-synthetic', help='write a synthetic input with Blender tangents here and exit')
    E.add_blender_args(ap)
    try:
        a = ap.parse_args(argv)
    except SystemExit as exc:
        return 2 if exc.code else 0
    try:
        return run(a)
    except SetupError as exc:
        print('SETUP ERROR: %s' % exc, file=sys.stderr)
        return 2
    except Exception as exc:  # last resort: never let a crash read as a pass
        traceback.print_exc()
        print('SETUP ERROR: the comparison could not run: %s: %s' % (type(exc).__name__, exc), file=sys.stderr)
        return 2


def run(a):
    target = a.make_synthetic or a.out or str(Path(E.scratch_dir('tangent_compare_')) / 'tangent_compare.json')
    err = E.refuse_in_worktree(target, 'output')
    if err:
        print('SETUP ERROR: ' + err, file=sys.stderr)
        return 2
    if a.make_synthetic:
        make_synthetic(a.make_synthetic)
        return 0
    if not a.input:
        raise SetupError('--input JSON not given')
    data = load_input(a.input)
    results = [compare_mesh(f.get('file', '?'), m) for f in data for m in f['meshes']]
    for rec in results:
        print(json.dumps(rec))
    out = {'tool': 'tangent_compare', 'blender': bpy.app.version_string, 'input': a.input, 'results': results}
    Path(target).parent.mkdir(parents=True, exist_ok=True)
    Path(target).write_text(json.dumps(out, indent=1), encoding='utf-8')
    print('RESULT %s' % target)
    return 0


if __name__ == '__main__':
    if bpy is None:
        sys.exit(E.relaunch_in_blender(Path(__file__).resolve(), sys.argv[1:]))
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    sys.exit(main_blender(args))
