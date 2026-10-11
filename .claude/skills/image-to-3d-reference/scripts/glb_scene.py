"""Blender-side helpers shared by preview_glb.py, render_ortho.py and mesh_stats.py. Not a command.

Needs bpy, mathutils and numpy (Blender bundles numpy). The host-side helpers (finding Blender, the relaunch, the
scratch-only output rule) come from the companion skill's `blender-organic-modeling/scripts/blender_env.py`; this
module adds what the generated-model tools share: import a model read-only, world bounds, normalise to a height,
lights, camera, engine choice and a render that always writes to an absolute path.
"""
import hashlib
import math
import os
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ORGANIC = HERE.parents[1] / 'blender-organic-modeling' / 'scripts'
for _p in (str(HERE), str(ORGANIC)):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import blender_env as E  # noqa: E402

ENGINES = {'EEVEE': ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'), 'WORKBENCH': ('BLENDER_WORKBENCH',),
           'CYCLES': ('CYCLES',)}


class SetupError(Exception):
    pass


def out_path(path, what='output'):
    """Absolute output path, refused inside any git work tree.

    Blender resolves a relative render path such as renders/x.png against the drive root (C:/renders/x.png on
    Windows), not the working directory (found 2026-10-11), so every path is made absolute here first."""
    p = os.path.abspath(os.path.expanduser(str(path)))
    err = E.refuse_in_worktree(p, what)
    if err:
        raise SetupError(err)
    return p


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as fh:
        for block in iter(lambda: fh.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def clear_scene():
    """Remove every object of the factory scene (default cube, camera, light)."""
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)


def import_model(path):
    """Import a .glb/.gltf/.obj/.fbx into the scene; (added objects, added meshes). The file itself is only read."""
    path = os.path.abspath(str(path))
    if not os.path.isfile(path):
        raise SetupError('model not found: %s' % path)
    ext = os.path.splitext(path)[1].lower()
    before = set(bpy.data.objects)
    if ext in ('.glb', '.gltf'):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == '.obj':
        bpy.ops.wm.obj_import(filepath=path)
    elif ext == '.fbx':
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        raise SetupError('unsupported model type %s (use .glb, .gltf, .obj or .fbx)' % (ext or '(none)'))
    added = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in added if o.type == 'MESH']
    if not meshes:
        raise SetupError('no mesh in %s' % path)
    return added, meshes


def world_points(obs):
    """Evaluated vertex positions of the objects in world space, one (n, 3) array."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in obs:
        me = o.evaluated_get(dg).data
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get('co', co)
        co = co.reshape(-1, 3)
        mw = np.array(o.matrix_world)
        pts.append(co @ mw[:3, :3].T + mw[:3, 3])
    return np.vstack(pts) if pts else np.zeros((0, 3))


def bounds(obs):
    p = world_points(obs)
    if not len(p):
        raise SetupError('no vertices to measure')
    return p.min(0), p.max(0)


def triangles(ob):
    lt = np.empty(len(ob.data.polygons), dtype=np.int64)
    ob.data.polygons.foreach_get('loop_total', lt)
    return int((lt - 2).sum())


def images():
    """(name, [width, height]) of every image with pixels (the model's texture maps; Blender's own viewer and
    render-result images are skipped)."""
    return sorted([im.name, list(im.size)] for im in bpy.data.images if im.type == 'IMAGE' and im.size[0])


def place(added, meshes, scale, centre_xy=(0.0, 0.0), ground=0.0):
    """Parent the imported top-level objects to an empty, scale it uniformly and put the feet (lowest point) at
    `ground` with the bounding-box centre at `centre_xy`. Returns (root, raw_lo, raw_hi)."""
    lo, hi = bounds(meshes)
    root = bpy.data.objects.new('MODEL_root', None)
    bpy.context.scene.collection.objects.link(root)
    for o in added:                                     # glTF nodes: parent the top ancestors, not the meshes
        if o.parent is None:
            o.parent = root
    root.scale = (scale, scale, scale)
    root.location = (centre_xy[0] - (lo[0] + hi[0]) / 2 * scale, centre_xy[1] - (lo[1] + hi[1]) / 2 * scale,
                     ground - lo[2] * scale)
    bpy.context.view_layer.update()
    return root, lo, hi


def set_engine(sc, name):
    """Set the render engine by its short name; the identifiers differ between Blender versions and the RNA enum
    lists only the built-in ones, so each candidate is tried."""
    for ident in ENGINES.get(name.upper(), ()):
        try:
            sc.render.engine = ident
            return ident
        except TypeError:
            continue
    raise SetupError('render engine %s not available in this Blender' % name)


def setup_render(engine, res_x, res_y, transparent, background=0.9):
    """Engine, resolution, a flat grey world, a key and a fill sun, Standard view transform."""
    sc = bpy.context.scene
    set_engine(sc, engine)
    sc.render.resolution_x, sc.render.resolution_y = int(res_x), int(res_y)
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = bool(transparent)
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA' if transparent else 'RGB'
    sc.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.new('preview_world')
    w.use_nodes = True
    bg = w.node_tree.nodes.get('Background')
    if bg is not None:
        bg.inputs[1].default_value = background
    sc.world = w
    if sc.render.engine == 'BLENDER_WORKBENCH':
        sc.display.shading.light = 'STUDIO'
        sc.display.shading.color_type = 'TEXTURE'
    for name, energy, rot in (('key', 3.0, (50, 0, -35)), ('fill', 1.5, (60, 0, 150))):
        sun = bpy.data.objects.new(name, bpy.data.lights.new(name, 'SUN'))
        sun.data.energy = energy
        sun.rotation_euler = tuple(math.radians(a) for a in rot)
        sc.collection.objects.link(sun)
    return sc


def camera(ortho_scale=None, lens=50.0):
    sc = bpy.context.scene
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    sc.camera = cam
    if ortho_scale:
        cam.data.type = 'ORTHO'
        cam.data.ortho_scale = float(ortho_scale)
    else:
        cam.data.lens = lens
    cam.data.clip_start, cam.data.clip_end = 0.01, 1000.0
    return cam


def aim(cam, centre, direction, distance):
    """Put the camera at centre + direction * distance, looking back at the centre with +Z up."""
    d = Vector(direction).normalized()
    cam.location = Vector(centre) + d * distance
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()


def render(path):
    """Render the scene camera to an absolute PNG path and check the file exists."""
    path = out_path(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    if not os.path.isfile(path):
        raise SetupError('render did not write %s' % path)
    return path


def blender_args(argv):
    """Arguments after '--' when running inside Blender."""
    return argv[argv.index('--') + 1:] if '--' in argv else []
