#!/usr/bin/env python
"""Side-by-side: the viewer (headless Chrome) against the existing pose_sim + Blender route, same unit, same keys.

    python crosscheck.py --proto ypIronFlail --frame idle_k0:Idle:0:0 --frame attack_k133:Attack_melee:0:133
           [--views side,threequarter,otherside] [--out DIR] [--bundle ID] [--blender PATH] [--no-blender]

A frame is NAME:ANIM:VARIANT:KEY, KEY being a key of the rider's (the synced child's) clip; the horse plays the same
time (its clip is decoded at the rider's key rate). For each frame:
1. pose_sim route (aoe3de-unit-animation): the rider and horse models written as converter-style GXO text from the
   bundle's own gr2 reads (rest from the stored InverseWorld, frame A = unit_gr2.to_gxo_*, faces reversed, V flipped;
   a rigid mesh - the horse's head piece - gets weight 1 on its single bone binding, the viewer's rule), the clips
   decoded by aoe3de-unit-model clip_decode (exact quaternion normalisation), posed and seated by pose_sim.py
   (--mount, seat bone *attachpoint), rendered by render_obj.py in a BACKGROUND Blender (`blender -b`, no window:
   not screen control) with each OBJ's BaseColor PNG (Workbench, studio light, orthographic).
2. viewer route: the same keys in the viewer page (headless.py run_job), with render_obj.py's cameras rebuilt from
   the pose_sim OBJ bounds (camera.renderObjCamera), transparent background, no grid.
3. a sheet PNG (rows = frames, columns = view x route) and crosscheck.json: per view the silhouette IoU of the two
   renders (viewer alpha > 0 against Blender pixels unlike its background corner), the clip times and keys, the bundle
   id and fidelity block. The lighting differs on purpose (Blender Workbench vs the viewer's M2 placeholder); the
   silhouettes test the pose, the seat and the camera rebuild.
Everything is written under the output folder (default <cache>/out/crosscheck-<time>; a repository is refused).
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402

ANIM_SCRIPTS = HERE.parents[1] / 'aoe3de-unit-animation' / 'scripts'
VIEWS = {'side': (90, 0.05), 'threequarter': (35, 0.2), 'otherside': (270, 0.05)}     # render_obj.py's three
CELL = 400


def parse_frame(spec):
    parts = spec.split(':')
    if len(parts) != 4:
        raise ValueError('frame %r: NAME:ANIM:VARIANT:KEY' % spec)
    name, anim, variant, key = parts
    C.safe_stem(name)
    return {'name': C.safe_stem(name), 'anim': anim, 'variant': int(variant), 'key': int(key)}


# ---------------------------------------------------------------------------------------------- GXO text for pose_sim
def gxo_model_text(model):
    """converter-style GXO text of a gr2_model.Gr2Model, as pose_sim.parse_model reads it."""
    import numpy as np
    import unit_gr2 as U
    lines = []
    for b in model.bones:
        W0 = U.to_gxo_matrix(np.linalg.inv(np.array(b['inverse_world']).reshape(4, 4)))
        vals = list(W0[:3, :3].ravel()) + list(W0[3, :3])
        lines.append('b "%s" %d %s' % (b['name'], b['parent'] + 1, ' '.join('%.9g' % v for v in vals)))
    for me in model.meshes:
        P = me.streams.get('Position')
        if P is None or not me.vertex_count:
            continue
        lines.append('m "%s"' % me.name)
        for name in me.bone_names:                      # pose_sim matches mb names exactly: use the skeleton's
            i = model.bone_index(name)                  # spelling (engine rule: space = underscore, any case)
            lines.append('mb "%s"' % (model.bones[i]['name'] if i >= 0 else name))
        for p in U.to_gxo_point(P[:, :3].astype(np.float64)):
            lines.append('v %.9g %.9g %.9g' % tuple(p))
        uv = me.streams.get('TextureCoordinates0')
        for t in (uv.astype(np.float64) if uv is not None else np.zeros((me.vertex_count, 2))):
            lines.append('vt %.9g %.9g' % (t[0], 1.0 - t[1]))
        W, I = me.streams.get('BoneWeights'), me.streams.get('BoneIndices')
        for v in range(me.vertex_count):
            if W is not None and I is not None:
                w = [int(x) / 255.0 for x in W[v][:4]]
                i = [int(x) + 1 for x in I[v][:4]]
            else:                                           # rigid: weight 1 on the first binding (viewer rule)
                w, i = [1.0, 0, 0, 0], [1, 1, 1, 1]
            lines.append('vw %s %s' % (' '.join('%.9g' % x for x in w), ' '.join(str(x) for x in i)))
        tri = np.asarray(me.indices).reshape(-1, 3)
        for a, b, c in tri:
            lines.append('f %d %d %d' % (a + 1, c + 1, b + 1))
    return '\n'.join(lines) + '\n'


def obj_bounds(paths):
    import numpy as np
    pts = []
    for p in paths:
        with open(p, encoding='utf-8') as f:
            for line in f:
                if line.startswith('v '):
                    pts.append([float(x) for x in line.split()[1:4]])
    P = np.array(pts)
    return P.min(0).tolist(), P.max(0).tolist()


def side_textures(manifest, model_id):
    """the BaseColor texture id of the model's first group's material, or None."""
    m = manifest['models'].get(model_id) or {}
    for me in m.get('meshes', []):
        for g in me['groups']:
            mat = manifest['materials'].get(g['material'] or '')
            s = (mat or {}).get('slots', {}).get('BaseColor') or {}
            if s.get('texture'):
                return s['texture']
    return None


# ---------------------------------------------------------------------------------------------- the two routes
def pose_sim_route(fs, manifest, frame, work, blender, log):
    import gr2_model as GM                             # first: puts aoe3de-unit-model's scripts on sys.path
    import gr2_curves as GC
    import clip_decode as CD
    import ddt as D
    comp = manifest['composition']
    main_af, child_af = comp['main'], comp['pairing']['child']

    def side(afid, variant):
        rec = manifest['animfiles'][afid]
        model = rec['components'][0]['resolved'][0]['models'][0]
        vs = rec['anims'][frame['anim']]['variants']
        return model, vs[variant % len(vs)]['clip']
    hmodel, hclip = side(main_af, frame['variant'])
    rmodel, rclip = side(child_af, frame['variant'])
    rc = GC.read_clip(fs.read(rclip).data)
    fps = round(rc.fps_declared)
    t = min(frame['key'] / fps, rc.duration)
    out = {'horse_model': hmodel, 'rider_model': rmodel, 'horse_clip': hclip, 'rider_clip': rclip, 'fps': fps, 't': t}
    d = work / frame['name']
    d.mkdir(parents=True, exist_ok=True)
    for tag, mid, cid in (('rider', rmodel, rclip), ('horse', hmodel, hclip)):
        C.write_bytes(d / ('%s.gxo' % tag), gxo_model_text(GM.read_model(fs.read(mid).data)).encode('utf-8'),
                      'pose_sim inputs')
        res = CD.decode(fs.materialize(cid), fps=fps)
        C.write_bytes(d / ('%s_clip.gxo' % tag), CD.gxo_text(res).encode('utf-8'), 'pose_sim inputs')
        tex = side_textures(manifest, mid)
        got = fs.read(tex) if tex else None
        if got is not None:
            D.write_png(got.data, d / ('%s.png' % tag), level=1)
    obj = d / 'posed.obj'
    cmd = [sys.executable, str(ANIM_SCRIPTS / 'pose_sim.py'), '--model', str(d / 'rider.gxo'),
           '--anim', str(d / 'rider_clip.gxo'), '--frame', str(frame['key']), '--mount', str(d / 'horse.gxo'),
           '--mount-anim', str(d / 'horse_clip.gxo'), '--out', str(obj), '--det-tol', '100']
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    log('pose_sim %s: %s' % (frame['name'], (r.stdout or r.stderr).strip().splitlines()[-1:]))
    if r.returncode:
        raise RuntimeError('pose_sim failed: %s' % r.stderr[-2000:])
    out['objs'] = [str(obj), str(d / 'posed_mount.obj')]
    out['bounds_gxo'] = obj_bounds(out['objs'])
    out['blender'] = None
    if blender:
        prefix = d / 'blender'
        args = [str(prefix), out['objs'][0], str(d / 'rider.png'), out['objs'][1], str(d / 'horse.png')]
        cmd = [blender, '-b', '--factory-startup', '--python', str(ANIM_SCRIPTS / 'render_obj.py'), '--', *args]
        t0 = time.monotonic()
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=900,
                           creationflags=0x08000000 if os.name == 'nt' else 0)
        ok = r.returncode == 0 and all((d / ('blender_%s.png' % v)).is_file() for v in VIEWS)
        log('blender -b %s: %s in %.1f s' % (frame['name'], 'ok' if ok else 'FAILED', time.monotonic() - t0))
        if not ok:
            raise RuntimeError('background Blender failed: %s' % (r.stdout + r.stderr)[-2000:])
        out['blender'] = {v: str(d / ('blender_%s.png' % v)) for v in VIEWS}
    return out


def mask_alpha(img):
    import numpy as np
    return np.asarray(img.convert('RGBA'))[:, :, 3] > 0


def mask_background(img, tol=6):
    import numpy as np
    a = np.asarray(img.convert('RGB')).astype(int)
    bg = a[2, 2]
    return np.abs(a - bg).max(axis=2) > tol


def iou(a, b):
    import numpy as np
    inter, union = np.logical_and(a, b).sum(), np.logical_or(a, b).sum()
    return float(inter) / float(union) if union else None


def make_sheet(rows, views, out_png):
    from PIL import Image, ImageDraw
    cols = [(v, route) for v in views for route in ('viewer', 'blender')]
    head = 22
    sheet = Image.new('RGB', (CELL * len(cols), (CELL + head) * len(rows)), (24, 26, 30))
    draw = ImageDraw.Draw(sheet)
    for r, row in enumerate(rows):
        for c, (v, route) in enumerate(cols):
            x, y = c * CELL, r * (CELL + head)
            p = row['images'].get((v, route))
            label = '%s  %s  %s' % (row['name'], v, route)
            if v in row.get('iou', {}) and route == 'blender' and row['iou'][v] is not None:
                label += '  IoU %.3f' % row['iou'][v]
            draw.text((x + 6, y + 4), label, fill=(220, 220, 220))
            if p and Path(p).is_file():
                im = Image.open(p).convert('RGBA').resize((CELL, CELL))
                bgc = Image.new('RGBA', im.size, (60, 63, 70, 255))
                sheet.paste(Image.alpha_composite(bgc, im).convert('RGB'), (x, y + head))
            else:
                draw.text((x + 10, y + head + CELL // 2), 'not rendered', fill=(255, 120, 100))
    out_png = C.refuse_repo_path(out_png, 'a crosscheck sheet')
    sheet.save(out_png)
    return out_png


def crosscheck(proto, frames, *, views=tuple(VIEWS), out_dir=None, bundle_id=None, blender=None, use_blender=True,
               log=print, timeout=180.0):
    import bundle as B
    import headless as H
    import vfs as V
    out = C.output_dir(out_dir, 'crosscheck')
    fs = V.VFS()
    if bundle_id:
        manifest = C.read_json(C.cache_root() / bundle_id / 'manifest.json')
    else:
        res = B.build_bundle(proto=proto, fs=fs, log=log)
        bundle_id, manifest = res.bundle_id, res.manifest
        fs = V.VFS()                                   # a fresh VFS: the build's provenance stays in its bundle
    blender = (blender or C.local_tool_path('blender')) if use_blender else None
    if use_blender and not (blender and Path(blender).is_file()):
        log('no Blender (config tools.blender.path or --blender): the pose_sim route is posed but not rendered')
        blender = None
    report = {'tool': C.TOOL_NAME, 'version': C.TOOL_VERSION, 'bundle_id': bundle_id, 'subject': manifest['subject'],
              'fidelity': manifest['fidelity'], 'out_dir': str(out), 'frames': []}
    work = out / 'pose_sim'
    job = {'width': 800, 'height': 800, 'background': [0, 0, 0, 0], 'grid': False, 'readback': False, 'frames': []}
    for f in frames:
        ps = pose_sim_route(fs, manifest, f, work, blender, log)
        f['pose_sim'] = ps
        lo, hi = ps['bounds_gxo']
        for v in views:
            az, el = VIEWS[v]
            job['frames'].append({'name': '%s_%s' % (f['name'], v), 'anim': f['anim'], 'variant': f['variant'],
                                  'key': f['key'], 'key_of': 'child',
                                  'camera': {'mode': 'render_obj', 'lo': lo, 'hi': hi, 'az': az, 'el': el,
                                             'units': 1 / 2.54}})
    rec = H.run_job(bundle_id, job, out_dir=out / 'viewer', timeout=timeout, log=log)
    report['viewer_run'] = {k: rec.get(k) for k in ('status', 'error', 'elapsed_s', 'out_dir', 'leftover_processes')}
    if rec['status'] != 'done':
        raise RuntimeError('viewer job %s: %s' % (rec['status'], rec.get('error')))
    page = {fr['name']: fr for fr in rec['result']['frames']}
    from PIL import Image
    rows = []
    for f in frames:
        ps = f['pose_sim']
        row = {'name': f['name'], 'images': {}, 'iou': {}}
        entry = {'name': f['name'], 'anim': f['anim'], 'variant': f['variant'], 'rider_key': f['key'],
                 'time': ps['t'], 'fps': ps['fps'], 'clips': {'horse': ps['horse_clip'], 'rider': ps['rider_clip']},
                 'models': {'horse': ps['horse_model'], 'rider': ps['rider_model']}, 'views': {}}
        for v in views:
            vp = Path(rec['out_dir']) / ('%s_%s.png' % (f['name'], v))
            row['images'][(v, 'viewer')] = str(vp)
            pf = page.get('%s_%s' % (f['name'], v)) or {}
            view = {'viewer_png': str(vp), 'viewer_instances': pf.get('instances')}
            if ps['blender']:
                bp = ps['blender'][v]
                row['images'][(v, 'blender')] = bp
                row['iou'][v] = iou(mask_alpha(Image.open(vp)), mask_background(Image.open(bp)))
                view.update(blender_png=bp, silhouette_iou=row['iou'][v])
            entry['views'][v] = view
        rows.append(row)
        report['frames'].append(entry)
    report['sheet'] = str(make_sheet(rows, views, out / 'crosscheck_sheet.png'))
    C.write_json(out / 'crosscheck.json', report)
    log('sheet %s' % report['sheet'])
    return report


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--proto', default='ypIronFlail')
    ap.add_argument('--frame', action='append', help='NAME:ANIM:VARIANT:KEY (rider key); repeatable')
    ap.add_argument('--views', default=','.join(VIEWS))
    ap.add_argument('--out', help='output folder (default: a new folder in the cache; a repository is refused)')
    ap.add_argument('--bundle', help='use this cached bundle id instead of building')
    ap.add_argument('--blender', help='blender executable (default: config tools.blender.path)')
    ap.add_argument('--no-blender', action='store_true', help='pose with pose_sim but render the viewer only')
    a = ap.parse_args(argv)
    frames = [parse_frame(s) for s in (a.frame or ['idle_k0:Idle:0:0', 'attack_k133:Attack_melee:0:133'])]
    views = [v for v in a.views.split(',') if v]
    bad = [v for v in views if v not in VIEWS]
    if bad:
        ap.error('unknown view(s) %s (one of %s)' % (bad, ', '.join(VIEWS)))
    try:
        rep = crosscheck(a.proto, frames, views=views, out_dir=a.out, bundle_id=a.bundle, blender=a.blender,
                         use_blender=not a.no_blender)
    except (C.RepoPathError, RuntimeError, LookupError) as e:
        print('error: %s' % e, file=sys.stderr)
        return 2
    for f in rep['frames']:
        print('%-14s t=%.5f  %s' % (f['name'], f['time'], '  '.join(
            '%s IoU %s' % (v, '%.3f' % x['silhouette_iou'] if x.get('silhouette_iou') is not None else '-')
            for v, x in f['views'].items())))
    print('sheet:', rep['sheet'])
    return 0


if __name__ == '__main__':
    sys.exit(main())
