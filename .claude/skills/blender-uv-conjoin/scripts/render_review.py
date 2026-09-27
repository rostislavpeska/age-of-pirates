"""Background Blender: flat colour renders of review scenes from 4 sides.

blender -b file.blend --python render_review.py -- OUT_DIR SceneA [SceneB ...]
Writes OUT_DIR/<scene>_<angle>.png (Workbench, flat material colour, ortho camera
framing the whole scene). Use it instead of live viewport captures, which can be
stale when the interactive window is not redrawing.
"""
import bpy, math, sys
import numpy as np
from mathutils import Vector
from pathlib import Path

args = sys.argv[sys.argv.index('--') + 1:]
out = Path(args[0]); out.mkdir(parents=True, exist_ok=True)
for name in args[1:]:
    sc = bpy.data.scenes[name]
    bpy.context.window.scene = sc
    sc.render.engine = 'BLENDER_WORKBENCH'; sc.render.resolution_x = 900; sc.render.resolution_y = 840
    sc.render.image_settings.file_format = 'PNG'; sc.view_settings.view_transform = 'Standard'
    sh = sc.display.shading; sh.light = 'FLAT'
    sh.color_type = 'TEXTURE' if sh.color_type == 'TEXTURE' else 'MATERIAL'   # density checker scenes keep textures
    sh.show_shadows = sh.show_cavity = sh.show_object_outline = sh.show_backface_culling = False
    cam = bpy.data.objects.new('Cam_' + name, bpy.data.cameras.new('Cam_' + name)); sc.collection.objects.link(cam)
    sc.camera = cam; cam.data.type = 'ORTHO'; cam.data.clip_start = .001
    pts = np.array([list(o.matrix_world @ v.co) for o in sc.objects if o.type == 'MESH' for v in o.data.vertices])
    size = float(np.ptp(pts, axis=0).max())
    for a in (45, 135, 225, 315):
        d = Vector((2 * size * math.cos(math.radians(a)), 2 * size * math.sin(math.radians(a)), 1.4 * size))
        cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
        basis = np.asarray(cam.rotation_euler.to_matrix()); pr = pts @ basis; lo = pr.min(0); hi = pr.max(0)
        cam.location = Vector(basis @ ((lo + hi) * .5)) + d
        cam.data.ortho_scale = max(hi[0] - lo[0], (hi[1] - lo[1]) * 900 / 840) * 1.08
        sc.render.filepath = str(out / f'{name}_{a}.png')
        bpy.ops.render.render(write_still=True)
print('RENDERED', args[1:])
