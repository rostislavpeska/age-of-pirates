#!/usr/bin/env python
"""Welded mesh statistics of a generated model: parts, fragments and where the fragments sit.

    python mesh_stats.py --model MODEL.glb [--out SCRATCH/stats.json] [--weld 1e-5] [--bands 10] [--blender-exe EXE]
    blender -b --factory-startup --python-exit-code 2 --python mesh_stats.py -- --model MODEL.glb --out FILE.json

glTF splits vertices wherever a UV seam or a hard normal runs, so loose-part counts on the imported mesh are
meaningless (a flat-shaded cube is six parts). This tool welds vertices by position first (--weld, model units,
default 1e-5) and then reports per mesh: raw and welded vertices, triangles, unique edges, open (boundary) and
non-manifold edges, loose parts, the largest part's vertex share, the fragments (every part but the largest), how
many have fewer than 50 vertices, the fragment count per height band from the lowest point (--bands, default
tenths: band 0 = feet, the last band = top of the head or plume) and the 20 largest fragments of 200+ vertices with
their height fraction and extent. It also lists the texture sizes. The model is only read.
Output JSON goes to --out (outside any git work tree) and a summary line per mesh to stdout.
Exit 0 = measured, 2 = setup error (missing model, refused path, no Blender) or an exception.
"""
import argparse
import json
import sys
import traceback
from pathlib import Path

sys.dont_write_bytecode = True      # Blender ignores -B; keep __pycache__ out of the skill folder
HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE), str(HERE.parents[1] / 'blender-organic-modeling' / 'scripts')]
try:
    import blender_env as E  # noqa: E402
except ImportError:
    sys.exit('SETUP ERROR: companion skill blender-organic-modeling (scripts/blender_env.py) not found')

try:
    import bpy
except ImportError:  # host Python: relaunch in Blender
    bpy = None
if bpy is not None and not hasattr(bpy, 'app'):
    bpy = None
if bpy is not None:
    import numpy as np  # noqa: E402
    import glb_scene as G  # noqa: E402


def build_parser():
    ap = argparse.ArgumentParser(prog='mesh_stats.py', description=__doc__.splitlines()[0])
    ap.add_argument('--model', '--glb', dest='model', required=True, help='generated model (.glb/.gltf/.obj/.fbx)')
    ap.add_argument('--out', help='result JSON, outside any git work tree (default: stdout only)')
    ap.add_argument('--weld', type=float, default=1e-5, help='weld distance in model units (default 1e-5)')
    ap.add_argument('--bands', type=int, default=10, help='height bands for the fragment census (default 10)')
    E.add_blender_args(ap)
    return ap


def components(ea, eb, n):
    """Connected-component label per welded vertex (min-label propagation with pointer jumping)."""
    lab = np.arange(n)
    converged = False
    for _ in range(10000):
        m = np.minimum(lab[ea], lab[eb])
        old = lab.copy()
        np.minimum.at(lab, ea, m)
        np.minimum.at(lab, eb, m)
        lab = lab[lab]
        if np.array_equal(lab, old):
            converged = True
            break
    return lab, converged


def mesh_record(ob, weld, nbands):
    me = ob.data
    n = len(me.vertices)
    co = np.empty(n * 3)
    me.vertices.foreach_get('co', co)
    co = co.reshape(-1, 3)
    mw = np.array(ob.matrix_world)
    co = co @ mw[:3, :3].T + mw[:3, 3]
    q = np.round(co / weld).astype(np.int64)
    _, wid = np.unique(q, axis=0, return_inverse=True)
    wid = wid.ravel()
    nw = int(wid.max()) + 1
    wco = np.zeros((nw, 3))
    wco[wid] = co
    lv = np.empty(len(me.loops), dtype=np.int64)
    me.loops.foreach_get('vertex_index', lv)
    ls = np.empty(len(me.polygons), dtype=np.int64)
    me.polygons.foreach_get('loop_start', ls)
    lt = np.empty(len(me.polygons), dtype=np.int64)
    me.polygons.foreach_get('loop_total', lt)
    nxt = np.arange(len(lv)) + 1                     # next loop in the same polygon
    nxt[ls + lt - 1] = ls
    a, b = wid[lv], wid[lv[nxt]]
    lo, hi = np.minimum(a, b), np.maximum(a, b)
    keep = lo != hi
    key = lo[keep] * nw + hi[keep]
    uk, cnt = np.unique(key, return_counts=True)
    ea, eb = uk // nw, uk % nw
    lab, converged = components(ea, eb, nw)
    roots, inv, counts = np.unique(lab, return_inverse=True, return_counts=True)
    inv = inv.ravel()
    order = np.argsort(counts)[::-1]
    zmin, zmax = float(wco[:, 2].min()), float(wco[:, 2].max())
    span = (zmax - zmin) or 1.0
    bands = np.zeros(max(1, nbands), dtype=int)
    big = []
    for r in order[1:]:
        c = wco[inv == r]
        zc = (float(c[:, 2].mean()) - zmin) / span
        bands[min(int(zc * len(bands)), len(bands) - 1)] += 1
        if counts[r] >= 200:
            big.append(dict(verts=int(counts[r]), z_frac=round(zc, 3),
                            extent=round(float((c.max(0) - c.min(0)).max()) / span, 4)))
    frag_counts = counts[order[1:]]
    return dict(
        name=ob.name, raw_vertices=n, welded_vertices=nw, triangles=int((lt - 2).sum()), edges=int(len(uk)),
        open_edges=int((cnt == 1).sum()), nonmanifold_edges=int((cnt > 2).sum()), loose_parts=int(len(roots)),
        largest_part_share=round(float(counts[order[0]]) / nw, 4), fragments=int(len(frag_counts)),
        fragment_vertices=int(frag_counts.sum()), fragments_under_50_verts=int((frag_counts < 50).sum()),
        fragment_count_by_height_band=bands.tolist(), fragments_200plus_verts=big[:20],
        height_model_units=round(span, 6), components_converged=converged)


def run(a):
    model = str(Path(a.model).resolve())
    target = G.out_path(a.out, '--out') if a.out else None
    if a.weld <= 0 or a.bands < 1:
        raise G.SetupError('--weld must be > 0 and --bands >= 1')
    G.clear_scene()
    _added, meshes = G.import_model(model)
    res = dict(tool='mesh_stats', blender=bpy.app.version_string, model=model, model_sha256=G.sha256(model),
               weld=a.weld, bands=a.bands, images=G.images(), meshes=[])
    for ob in meshes:
        rec = mesh_record(ob, a.weld, a.bands)
        res['meshes'].append(rec)
        print('MESH %s: %d tris, %d welded verts, %d parts (largest %.1f %%), %d fragments, open %d, non-manifold %d'
              % (rec['name'], rec['triangles'], rec['welded_vertices'], rec['loose_parts'],
                 100 * rec['largest_part_share'], rec['fragments'], rec['open_edges'], rec['nonmanifold_edges']))
    if target:
        Path(target).parent.mkdir(parents=True, exist_ok=True)
        Path(target).write_text(json.dumps(res, indent=1), encoding='utf-8')
        print('MESHSTATS %s' % target)
    else:
        print(json.dumps(res, indent=1))
    return 0


def main_blender(argv):
    try:
        a = build_parser().parse_args(argv)
    except SystemExit as exc:
        return 2 if exc.code else 0
    try:
        return run(a)
    except G.SetupError as exc:
        print('SETUP ERROR: %s' % exc, file=sys.stderr)
        return 2
    except Exception as exc:  # never let a crash read as a pass
        traceback.print_exc()
        print('SETUP ERROR: mesh_stats could not run: %s: %s' % (type(exc).__name__, exc), file=sys.stderr)
        return 2


if __name__ == '__main__':
    if bpy is None:
        if '-h' in sys.argv[1:] or '--help' in sys.argv[1:]:
            build_parser().print_help()
            sys.exit(0)
        sys.exit(E.relaunch_in_blender(Path(__file__).resolve(), sys.argv[1:]))
    sys.exit(main_blender(G.blender_args(sys.argv)))
