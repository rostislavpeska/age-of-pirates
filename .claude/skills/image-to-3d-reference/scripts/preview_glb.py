#!/usr/bin/env python
"""Preview renders of a generated model with its own textures, optionally beside a reference body.

    python preview_glb.py --model MODEL.glb --out-dir SCRATCH/preview [--prefix NAME]
                          [--reference-blend BODY.blend --reference-object NAME]
                          [--views front,threequarter,side,back] [--res 900x1000] [--engine EEVEE|WORKBENCH|CYCLES]
    blender -b --factory-startup --python-exit-code 2 --python preview_glb.py -- --model MODEL.glb --out-dir DIR

Imports the model read-only (.glb, .gltf, .obj, .fbx) and renders perspective views (50 mm) on a light-grey world:
  PREFIX_solo_<view>.png  the model alone;
  PREFIX_pair_<view>.png  with --reference-blend/--reference-object: the reference mesh (appended from the .blend,
                          armature modifiers removed so it shows its rest shape) on the left and the model on the
                          right, the model scaled to the reference's bounding-box height, both standing on z = 0.
Views: front (from -Y, the glTF forward side), threequarter, side (from +X), back. Writes PREFIX_stats.json (model
sha256, meshes, vertices, triangles, texture sizes, raw bounding box, height, the scale used for the pair).
The pair scale is a PREVIEW scale only: a bounding box includes a plume or a hat, so the body comes out short. Fit a
generated figure by eye on landmarks (references/fitting.md). The reference object is named explicitly: no name is
guessed. Output is refused inside a git work tree; relative paths are made absolute first.
Exit 0 = written, 2 = setup error (missing model or reference object, refused path, no Blender) or an exception.
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

VIEWS = {'front': (0, -1, 0.12), 'threequarter': (0.7, -0.9, 0.2), 'side': (1, 0, 0.12), 'back': (0, 1, 0.12)}


def build_parser():
    ap = argparse.ArgumentParser(prog='preview_glb.py', description=__doc__.splitlines()[0])
    ap.add_argument('--model', '--glb', dest='model', required=True, help='generated model (.glb/.gltf/.obj/.fbx)')
    ap.add_argument('--out-dir', required=True, help='output folder outside any git work tree')
    ap.add_argument('--prefix', help='file name prefix (default: the model file stem)')
    ap.add_argument('--reference-blend', help='.blend holding a reference body (e.g. the target mannequin)')
    ap.add_argument('--reference-object', help='exact name of the reference mesh object in --reference-blend')
    ap.add_argument('--views', default='front,threequarter,side,back',
                    help='comma list of %s (default all)' % ', '.join(VIEWS))
    ap.add_argument('--res', default='900x1000', help='WIDTHxHEIGHT in pixels (default 900x1000)')
    ap.add_argument('--engine', default='EEVEE', choices=('EEVEE', 'WORKBENCH', 'CYCLES'),
                    help='render engine (default EEVEE; WORKBENCH is fastest)')
    E.add_blender_args(ap)
    return ap


def load_reference(blend, name):
    blend = str(Path(blend).resolve())
    if not Path(blend).is_file():
        raise G.SetupError('--reference-blend not found: %s' % blend)
    with bpy.data.libraries.load(blend, link=False) as (src, dst):
        if name not in src.objects:
            raise G.SetupError('object %r not in %s (objects: %s)' % (name, blend, ', '.join(sorted(src.objects))))
        dst.objects = [name]
    ref = dst.objects[0]
    if ref is None or ref.type != 'MESH':
        raise G.SetupError('reference object %r is not a mesh' % name)
    for m in [m for m in ref.modifiers if m.type == 'ARMATURE']:
        ref.modifiers.remove(m)
    ref.parent = None
    bpy.context.scene.collection.objects.link(ref)
    bpy.context.view_layer.update()
    return ref, blend


def shoot(cam, obs, tag, views, out_dir, prefix, aspect, factor):
    lo, hi = G.bounds(obs)
    centre = (lo + hi) / 2
    size = max(hi[2] - lo[2], (hi[0] - lo[0]) / aspect)
    paths = []
    for view in views:
        G.aim(cam, centre, VIEWS[view], size * factor)
        paths.append(G.render(str(Path(out_dir) / ('%s_%s_%s.png' % (prefix, tag, view)))))
    return paths


def run(a):
    if bool(a.reference_blend) != bool(a.reference_object):
        raise G.SetupError('--reference-blend and --reference-object go together')
    views = [v.strip() for v in a.views.split(',') if v.strip()]
    bad = [v for v in views if v not in VIEWS]
    if bad or not views:
        raise G.SetupError('unknown view(s) %s; use %s' % (', '.join(bad) or '(none)', ', '.join(VIEWS)))
    try:
        rx, ry = (int(v) for v in a.res.lower().split('x'))
    except ValueError:
        raise G.SetupError('--res must look like 900x1000')
    model = str(Path(a.model).resolve())
    out_dir = G.out_path(a.out_dir, '--out-dir')
    prefix = a.prefix or Path(model).stem
    G.clear_scene()
    ref = ref_blend = None
    if a.reference_blend:
        ref, ref_blend = load_reference(a.reference_blend, a.reference_object)
    added, meshes = G.import_model(model)
    lo, hi = G.bounds(meshes)
    h = float(hi[2] - lo[2])
    if h <= 0:
        raise G.SetupError('model has no height')
    stats = dict(tool='preview_glb', blender=bpy.app.version_string, model=model, model_sha256=G.sha256(model),
                 meshes=len(meshes), vertices=sum(len(o.data.vertices) for o in meshes),
                 triangles=sum(G.triangles(o) for o in meshes), images=G.images(), height_raw=round(h, 5),
                 bbox_raw=[lo.round(5).tolist(), hi.round(5).tolist()], views=views, renders=[])
    scale = 1.0
    if ref is not None:
        rlo, rhi = G.bounds([ref])
        rh = float(rhi[2] - rlo[2])
        scale = rh / h
        gap = 0.05 * rh
        ref.location.x += -gap - rhi[0]                  # reference ends just left of x = 0, feet on z = 0
        ref.location.y += -(rlo[1] + rhi[1]) / 2
        ref.location.z += -rlo[2]
        width = float(hi[0] - lo[0]) * scale
        G.place(added, meshes, scale, centre_xy=(gap + width / 2, 0.0))
        stats.update(reference_blend=ref_blend, reference_object=a.reference_object, reference_height=round(rh, 5),
                     scale_to_reference=round(scale, 6), scale_note='bounding-box preview scale, not a fit')
    else:
        G.place(added, meshes, scale)
    G.setup_render(a.engine, rx, ry, transparent=False, background=0.9)
    cam = G.camera(lens=50.0)
    if ref is not None:
        stats['renders'] += shoot(cam, meshes + [ref], 'pair', views, out_dir, prefix, rx / ry, 2.1)
        ref.hide_render = True
    stats['renders'] += shoot(cam, meshes, 'solo', views, out_dir, prefix, rx / ry, 1.75)
    target = str(Path(out_dir) / ('%s_stats.json' % prefix))
    Path(target).write_text(json.dumps(stats, indent=1), encoding='utf-8')
    print('PREVIEW %s (%d renders)' % (target, len(stats['renders'])))
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
        print('SETUP ERROR: preview_glb could not run: %s: %s' % (type(exc).__name__, exc), file=sys.stderr)
        return 2


if __name__ == '__main__':
    if bpy is None:
        if '-h' in sys.argv[1:] or '--help' in sys.argv[1:]:
            build_parser().print_help()
            sys.exit(0)
        sys.exit(E.relaunch_in_blender(Path(__file__).resolve(), sys.argv[1:]))
    sys.exit(main_blender(G.blender_args(sys.argv)))
