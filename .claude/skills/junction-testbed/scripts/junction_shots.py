"""Close-up renders of the failing junctions in a junction_check.py report (Workbench, background Blender).

    blender -b FILE.blend --factory-startup --python junction_shots.py -- --report REPORT.json --out DIR [--max 2] [--all]

Per failing member (first --max per junction; --all also shoots passing ones): the `a` part red, the `b` parts it was
measured against blue, every other part within 3 m grey, the rest hidden. Three views aimed at the report's `at`
point (deepest clash, else closest gap, else the pair's centre): an RTS-like view from above, a grazing view, and the
pair alone from above (covers such as tile rolls and ridges hide sheet seams).
The caption (junction, part, verdict, numbers) is stamped into the image. Writes PNGs only; the scene is not saved.
Whole-building views miss small joints (2026-10-10: 8 of 8 inspectors on 16 views missed a dock gable); these are
the per-junction close-ups.
"""
import fnmatch
import json
import math
import re
import sys
from pathlib import Path

import bpy
from mathutils import Vector

RED, BLUE, GREY = (0.85, 0.12, 0.1, 1), (0.15, 0.35, 0.9, 1), (0.72, 0.72, 0.7, 1)


def world_box(o):
    ws = [o.matrix_world @ Vector(c) for c in o.bound_box]
    return Vector([min(v[i] for v in ws) for i in range(3)]), Vector([max(v[i] for v in ws) for i in range(3)])


def setup(scene):
    scene.render.engine = 'BLENDER_WORKBENCH'
    sh = scene.display.shading
    sh.light = 'STUDIO'; sh.color_type = 'OBJECT'; sh.show_cavity = True; sh.show_object_outline = True
    sh.show_backface_culling = True                                # what the game draws
    scene.render.resolution_x, scene.render.resolution_y = 1200, 900
    scene.render.use_stamp = True; scene.render.use_stamp_note = True
    for k in ('date', 'time', 'render_time', 'frame', 'camera', 'scene', 'filename', 'memory', 'lens', 'marker', 'sequencer_strip'):
        setattr(scene.render, 'use_stamp_' + k, False)
    scene.render.stamp_font_size = 22
    cam = bpy.data.objects.new('JunctionCam', bpy.data.cameras.new('JunctionCam'))
    scene.collection.objects.link(cam); scene.camera = cam
    cam.data.lens = 40; cam.data.clip_start = .01
    return cam


def seg_hits_box(p, q, lo, hi, pad=.02):
    """Does segment p-q pass through the box (slab test)?"""
    t0, t1 = 0.0, 1.0
    for i in range(3):
        d = q[i] - p[i]
        if abs(d) < 1e-12:
            if p[i] < lo[i] - pad or p[i] > hi[i] + pad:
                return False
            continue
        a, b = (lo[i] - pad - p[i]) / d, (hi[i] + pad - p[i]) / d
        t0, t1 = max(t0, min(a, b)), min(t1, max(a, b))
        if t0 > t1:
            return False
    return True


def shoot(scene, cam, target, size, outward, path, note, views=(('rts', 50), ('graze', 15)), unblock=None):
    for tag, elev in views:
        d = max(1.2, 2.5 * size)
        h = Vector((outward.x, outward.y, 0)); h = h.normalized() if h.length > 1e-6 else Vector((0, -1, 0))
        e = math.radians(elev)
        cam.location = target + (h * math.cos(e) + Vector((0, 0, math.sin(e)))) * d
        cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
        if unblock:
            unblock(cam.location, target)
        scene.render.stamp_note_text = note
        scene.render.filepath = str(path) + '_' + tag + '.png'
        bpy.ops.render.render(write_still=True)


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--report', required=True); ap.add_argument('--out', required=True)
    ap.add_argument('--max', type=int, default=2); ap.add_argument('--all', action='store_true')
    a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    rep = json.load(open(a.report, encoding='utf-8'))
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene; cam = setup(scene)
    meshes = [o for o in scene.objects if o.type in ('MESH', 'CURVE')]
    scope = rep.get('scope') or {}
    if scope.get('collection'):                                    # the checked parts only (a file may hold blockout copies)
        inside = set(bpy.data.collections[scope['collection']].all_objects.keys())
        for o in meshes:
            if o.name not in inside:
                o.hide_render = True
        meshes = [o for o in meshes if o.name in inside]
    meshes = [o for o in meshes if not any(fnmatch.fnmatchcase(o.name, p) for p in scope.get('exclude', []))]
    boxes = {o.name: world_box(o) for o in meshes}
    centre = sum(((lo + hi) / 2 for lo, hi in boxes.values()), Vector()) / max(len(boxes), 1)
    shots = []
    for j in rep.get('junctions', []):
        members = [m for m in j.get('members', []) if a.all or m['status'] != 'PASS'][:a.max]
        for m in members:
            bnames = [n for n in boxes if fnmatch.fnmatchcase(n, j['b']) and n != m['a']]
            lo, hi = boxes[m['a']]
            if m.get('nearest') in boxes:
                lo2, hi2 = boxes[m['nearest']]; lo = Vector(map(min, lo, lo2)); hi = Vector(map(max, hi, hi2))
            target = Vector(m['at']) if m.get('at') else (lo + hi) / 2
            size = min((hi - lo).length, 4.0)
            context = set()
            for o in meshes:
                bl, bh = boxes[o.name]
                near = all(bl[i] - 3 <= target[i] <= bh[i] + 3 for i in range(3))
                o.color = RED if o.name == m['a'] else BLUE if o.name in bnames else GREY
                if near and o.name != m['a'] and o.name not in bnames:
                    context.add(o.name)

            def unblock(cam_at, aim, context=context, a_=m['a'], b_=set(bnames)):
                # grey context between the camera and the junction is hidden for this view (walls, eaves, decks)
                for o in meshes:
                    if o.name == a_ or o.name in b_:
                        o.hide_render = False
                    elif o.name in context:
                        o.hide_render = seg_hits_box(cam_at, aim, *boxes[o.name])
                    else:
                        o.hide_render = True
            nums = ' '.join('%s %.3f' % (k, m[k]) for k in ('gap', 'pen', 'proud', 'cover') if m.get(k) is not None)
            note = '%s | %s | %s %s | %s' % (j['id'], m['a'], m['status'], nums, m.get('reason', ''))
            stem = out / re.sub(r'[^A-Za-z0-9._-]+', '_', '%s__%s' % (j['id'], m['a']))
            shoot(scene, cam, target, size, target - centre, stem, note, unblock=unblock)
            for o in meshes:                                       # the pair alone: covers (tile rolls, ridges) hide sheet seams
                o.hide_render = not (o.name == m['a'] or o.name in bnames)
            shoot(scene, cam, target, size, target - centre, stem, note + ' | pair only', (('pair', 50),))
            shots.append({'junction': j['id'], 'part': m['a'], 'status': m['status'],
                          'files': [str(stem) + s for s in ('_rts.png', '_graze.png', '_pair.png')]})
    json.dump(shots, open(out / 'SHOTS.json', 'w', encoding='utf-8'), indent=1)
    print('JUNCTION_SHOTS', len(shots), 'members,', 3 * len(shots), 'images ->', out)


if __name__ == '__main__':
    main()
