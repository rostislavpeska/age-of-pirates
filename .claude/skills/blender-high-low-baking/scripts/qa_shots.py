"""Fixed-camera QA pictures (background; never saves): blender -b REVIEW.blend --python qa_shots.py -- config.json

config = {"collection": "00 Final",                  # the only collection rendered (others hidden)
          "samples": 16, "resolution": [800, 520],
          "cameras": [{"name": "rts_south", "group": "RTS", "loc": [x,y,z], "target": [x,y,z], "lens": 40}, ...],
          "out_dir": ".../qa_shots", "sheet": ".../qa_sheet.png", "columns": 4,
          "image_remap": {"from": ".../final", "to": ".../variant_out"}}   # optional: render a variant's maps
Same cameras every iteration, so sheets compare 1:1 over time. Lighting: one sun + sky (no viewport).
The sheet labels every tile with group/name - look at every tile (texturing-qa.md pass criteria).

Optional keys (standard camera set, 2026-09-29):
  "camera_set": ".../std_cameras.json", "views": ["rts_000", ...]   # cameras from a set file instead of "cameras"
                                                                   # (+ "extra_cameras": [...] appended, e.g. owner_live)
  camera "rot": [[3x3]] instead of "target": the camera->world rotation (a live viewport / a straight-down view)
  "image_remap": {"from": "*", "to": dir}   # every file image whose basename exists in dir (a HEAD scene whose maps
                                            # load from any folder); the remapped list goes to shots.json
  "stamp": "state a24e70a9 | {name}"         # burnt into every picture (Blender stamp note; {group} {name} filled)
  "hide_prefixes": ["HIGH"]                  # objects hidden from render by name prefix
"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

cfg = json.load(open(sys.argv[sys.argv.index('--') + 1], encoding='utf-8-sig'))   # tolerate a BOM (PowerShell 5.1)
sc = bpy.context.scene; out = Path(cfg['out_dir']); out.mkdir(parents=True, exist_ok=True)
sc.render.engine = 'CYCLES'; sc.cycles.samples = cfg.get('samples', 16); sc.cycles.device = 'CPU'
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = cfg.get('resolution', [800, 520]); sc.view_settings.view_transform = 'Standard'
sc.world = bpy.data.worlds.new('qa world'); bg = sc.world.node_tree.nodes['Background']
bg.inputs['Color'].default_value = (0.6, 0.65, 0.72, 1); bg.inputs['Strength'].default_value = 0.8
sun = bpy.data.objects.new('qa sun', bpy.data.lights.new('qa sun', 'SUN')); sun.data.energy = 3.0; sc.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), 0, math.radians(35))
keep = cfg.get('collection')
# "image_remap": {"from": "<dir the review file's maps load from>", "to": "<experiment's output dir>"} renders the
# same review with an experiment's maps (parallel variants, never touching the review file or final/)
rm = cfg.get('image_remap'); remapped, kept = [], []
if rm:
    any_dir = rm['from'] == '*'
    src_dir, dst_dir = (None if any_dir else Path(rm['from']).resolve()), Path(rm['to']).resolve(); swapped = 0
    for im in bpy.data.images:
        if im.source == 'FILE' and im.filepath:
            fp = Path(bpy.path.abspath(im.filepath)).resolve()
            if (any_dir or fp.parent == src_dir) and (dst_dir / fp.name).exists():
                im.filepath = str(dst_dir / fp.name); im.reload(); swapped += 1; remapped.append([im.name, str(fp)])
            else:
                kept.append([im.name, str(fp)])
    print('QA_SHOTS image_remap', swapped, 'images ->', dst_dir, flush=True)
for o in sc.objects:
    if any(o.name.startswith(p) for p in cfg.get('hide_prefixes', [])):
        o.hide_render = True
if cfg.get('stamp'):                              # burn-in: only the note (state id + view name), no date/host/etc.
    for p in sc.render.bl_rna.properties:
        if p.identifier.startswith('use_stamp_') and p.identifier not in ('use_stamp_note', 'use_stamp_labels'):
            try:
                setattr(sc.render, p.identifier, False)
            except (AttributeError, TypeError):
                pass
    sc.render.use_stamp = True; sc.render.use_stamp_note = True; sc.render.stamp_font_size = cfg.get('stamp_size', 20)
    sc.render.stamp_background = (0, 0, 0, 0.75)
if not cfg.get('cameras'):                        # a camera SET file (std_cameras.json) + the view names to render
    S = json.load(open(cfg['camera_set'], encoding='utf-8-sig')); by = {c['name']: c for c in S['cameras']}
    cfg['cameras'] = [by[n] for n in cfg.get('views') or [c['name'] for c in S['cameras']]]
cfg['cameras'] = list(cfg['cameras']) + list(cfg.get('extra_cameras', []))


def walk(col):
    yield col
    for c in col.children:
        yield from walk(c)


for col in walk(sc.collection):
    if col is not sc.collection:
        col.hide_render = keep is not None and col.name != keep
cam = bpy.data.objects.new('qa cam', bpy.data.cameras.new('qa cam')); sc.collection.objects.link(cam); sc.camera = cam
files = []
cam.data.sensor_width = cfg.get('sensor_width', 36.0); cam.data.sensor_fit = 'AUTO'; cam.data.clip_start = 0.02
for c in cfg['cameras']:
    loc = Vector(c['loc'])
    if 'rot' in c:                                # explicit camera->world rotation (live viewport, top view)
        cam.matrix_world = Matrix.Translation(loc) @ Matrix(c['rot']).to_4x4()
    else:
        tgt = Vector(c['target'])
        cam.matrix_world = Matrix.Translation(loc) @ (tgt - loc).to_track_quat('-Z', 'Y').to_matrix().to_4x4()
    cam.data.lens = c.get('lens', 45)
    if cfg.get('stamp'):
        sc.render.stamp_note_text = cfg['stamp'].format(group=c.get('group', ''), name=c['name'])
    f = out / f"{c.get('group', 'shot')}_{c['name']}.png"; sc.render.filepath = str(f); bpy.ops.render.render(write_still=True)
    files.append((f"{c.get('group', '')} / {c['name']}", f))
# contact sheet with labels (Blender image API only - no PIL inside Blender)
cols = cfg.get('columns', 4); w, h = sc.render.resolution_x, sc.render.resolution_y; rows = (len(files) + cols - 1) // cols
import numpy as np  # noqa: E402
sheet = np.zeros((rows * h, cols * w, 4), np.float32); sheet[..., 3] = 1
for i, (label, f) in enumerate(files):
    im = bpy.data.images.load(str(f)); a = np.empty(w * h * 4, np.float32); im.pixels.foreach_get(a)
    r, cidx = i // cols, i % cols; y0 = (rows - 1 - r) * h
    sheet[y0:y0 + h, cidx * w:(cidx + 1) * w] = a.reshape(h, w, 4); bpy.data.images.remove(im)
simg = bpy.data.images.new('qa sheet', cols * w, rows * h, alpha=False); simg.pixels.foreach_set(sheet.ravel())
simg.filepath_raw = cfg['sheet']; simg.file_format = 'PNG'; simg.save()
shots = [dict(label=l, file=str(f)) for l, f in files]
if cfg.get('camera_set'):                         # the richer record; the plain list stays the default format
    shots = dict(shots=shots, blend=bpy.data.filepath, remapped=remapped, kept=kept, stamp=cfg.get('stamp'))
(out / 'shots.json').write_text(json.dumps(shots, indent=2))
print('QA_SHOTS', len(files), cfg['sheet'])
