#!/usr/bin/env python
"""Normalised orthographic front and side renders of a generated model, with the pixel <-> metre mapping.

    python render_ortho.py --model MODEL.glb --out-dir SCRATCH/ortho [--prefix NAME] [--height 2.0] [--res 1200]
                           [--ortho-scale 2.4] [--engine EEVEE|WORKBENCH|CYCLES] [--blender-exe EXE]
    blender -b --factory-startup --python-exit-code 2 --python render_ortho.py -- --model MODEL.glb --out-dir DIR

Imports the model read-only (.glb, .gltf, .obj, .fbx), scales it uniformly to --height metres with the lowest point
at z = 0 and the bounding-box centre at x = y = 0, and renders two orthographic views on a transparent film with
the model's own textures:
  front: camera on -Y looking along +Y; image right = world +X (the figure's LEFT side when it faces -Y, the glTF
         forward direction after import);
  side:  camera on +X looking along -X; image right = world +Y, so a figure facing -Y faces image-left.
Writes OUT_DIR/PREFIX_front.png, PREFIX_side.png and PREFIX_ortho.json (model sha256, raw and normalised bounds,
scale, vertex/triangle counts, texture sizes and the mapping):
  px_per_m = res / ortho_scale; front px = X * px_per_m + res/2; side px = Y * px_per_m + res/2;
  both py = res/2 - (Z - centre_z) * px_per_m, centre_z = height / 2.
Pose measurement reads these images (grid.py, pose_angles.py). Raw loose-part counts are NOT reported here: glTF
splits vertices at UV seams, use mesh_stats.py. Output is refused inside a git work tree; relative paths are made
absolute first. Exit 0 = written, 2 = setup error (missing model, refused path, no Blender) or an exception.
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
    import glb_scene as G  # noqa: E402


def build_parser():
    ap = argparse.ArgumentParser(prog='render_ortho.py', description=__doc__.splitlines()[0],
                                 epilog='See the module docstring for the view conventions and the mapping.')
    ap.add_argument('--model', '--glb', dest='model', required=True, help='generated model (.glb/.gltf/.obj/.fbx)')
    ap.add_argument('--out-dir', required=True, help='output folder outside any git work tree')
    ap.add_argument('--prefix', help='file name prefix (default: the model file stem)')
    ap.add_argument('--height', type=float, default=2.0, help='normalised height in metres (default 2.0)')
    ap.add_argument('--res', type=int, default=1200, help='square render size in pixels (default 1200)')
    ap.add_argument('--ortho-scale', type=float, help='metres across the square (default 1.2 x height)')
    ap.add_argument('--engine', default='EEVEE', choices=('EEVEE', 'WORKBENCH', 'CYCLES'),
                    help='render engine (default EEVEE; WORKBENCH is fastest)')
    E.add_blender_args(ap)
    return ap


def run(a):
    model = str(Path(a.model).resolve())
    out_dir = G.out_path(a.out_dir, '--out-dir')
    prefix = a.prefix or Path(model).stem
    H = float(a.height)
    if H <= 0 or a.res < 16:
        raise G.SetupError('--height must be > 0 and --res >= 16')
    oscale = float(a.ortho_scale or 1.2 * H)
    G.clear_scene()
    added, meshes = G.import_model(model)
    lo, hi = G.bounds(meshes)
    if hi[2] - lo[2] <= 0:
        raise G.SetupError('model has no height')
    s = H / (hi[2] - lo[2])
    G.place(added, meshes, s)
    nlo, nhi = G.bounds(meshes)
    G.setup_render(a.engine, a.res, a.res, transparent=True, background=1.0)
    cam = G.camera(ortho_scale=oscale)
    centre = (0.0, 0.0, H / 2)
    views = {}
    for view, d in (('front', (0, -1, 0)), ('side', (1, 0, 0))):
        G.aim(cam, centre, d, 10.0 * H)
        views[view] = G.render(str(Path(out_dir) / ('%s_%s.png' % (prefix, view))))
    ppm = a.res / oscale
    info = dict(
        tool='render_ortho', blender=bpy.app.version_string, model=model, model_sha256=G.sha256(model),
        meshes=[dict(name=o.name, vertices=len(o.data.vertices), triangles=G.triangles(o)) for o in meshes],
        images=G.images(), raw_bbox=[lo.round(5).tolist(), hi.round(5).tolist()], scale=round(s, 6),
        norm_bbox=[nlo.round(5).tolist(), nhi.round(5).tolist()], height=H, res=a.res, ortho_scale=oscale,
        px_per_m=ppm, centre_z=H / 2, engine=a.engine,
        mapping=dict(front='px = X * px_per_m + res/2; py = res/2 - (Z - centre_z) * px_per_m; image right = +X',
                     side='px = Y * px_per_m + res/2; py = res/2 - (Z - centre_z) * px_per_m; image right = +Y'),
        views=views)
    target = str(Path(out_dir) / ('%s_ortho.json' % prefix))
    Path(target).write_text(json.dumps(info, indent=1), encoding='utf-8')
    print('ORTHO %s' % target)
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
        print('SETUP ERROR: render_ortho could not run: %s: %s' % (type(exc).__name__, exc), file=sys.stderr)
        return 2


if __name__ == '__main__':
    if bpy is None:
        if '-h' in sys.argv[1:] or '--help' in sys.argv[1:]:
            build_parser().print_help()
            sys.exit(0)
        sys.exit(E.relaunch_in_blender(Path(__file__).resolve(), sys.argv[1:]))
    sys.exit(main_blender(G.blender_args(sys.argv)))
