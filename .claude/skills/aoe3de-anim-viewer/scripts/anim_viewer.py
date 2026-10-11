#!/usr/bin/env python
"""AoE3 DE animation viewer: one command line for the bundle, the local viewer, headless renders, sheets and videos.

    python anim_viewer.py build   --proto ypIronFlail [--lgt "Tantalus Viewer"] [--json]
    python anim_viewer.py serve   --proto ypIronFlail [--port 8765]     # builds, then prints the URL for YOUR browser
    python anim_viewer.py render  --proto ypIronFlail --anim Attack_melee [--variant 0|all] [--at tags|keys|fps=N]
                                  [--key 133 --key-of child | --time 0.69] [--cam game|close|ortho3|side,...]
                                  [--lgt NewEngland_Skirmish] [--transparent] [--metrics] [--size 640] [--out DIR]
    python anim_viewer.py video   --proto ypIronFlail --anim Attack_melee --variant 0 --fps 30 --loops 3
                                  [--side-by-side OTHER] [--timeline-overlay] [--webp] [--cam game|close] [--out DIR]
    python anim_viewer.py compare --proto ypIronFlail --other OTHER --anim Attack_melee [--at tags] [--cam game]
    python anim_viewer.py crosscheck [--proto ypIronFlail] [--frame NAME:ANIM:VARIANT:KEY ...]   # vs pose_sim+Blender

build    reads the game and the enabled mods read-only and writes the unit bundle into the viewer cache
         (%TEMP%/aop-anim-viewer/<bundle id>, references/bundle-schema.md); prints the summary.
serve    starts the local server (127.0.0.1, a free port unless --port, a token per run) and prints the viewer URL;
         open it in your own browser. Ctrl+C stops it. Nothing is driven on the screen.
render   headless Chrome (no window, throwaway profile) renders PNGs at exact main-clock times: --at tags (every tag
         stop of the main and child clips), keys (every key of the main clip) or fps=N (t = i / N); or one --key /
         --time. --anim all and --variant all batch every anim / variant; --cam takes a comma list (ortho3 = front,
         side and top orthographic). Writes the PNGs, a <png>.cell.json per cell (anim, variant, clip, key, time, tag,
         fidelity), one sheet per anim (sheet_<anim>.png + .json) and report.json. --metrics adds the geometry dumps
         and the rider-horse penetration and hoof heights (metrics.py) per cell.
video    renders every frame of fps x loops x the clip at its exact time (deterministic, not a real-time capture),
         burns in the timeline (--timeline-overlay: clip, time, key, tag markers, a flash on tag frames), and encodes
         an MP4 (H.264 yuv420p, faststart) through ffmpeg from config/tool-paths.local.json tools.ffmpeg.path (or
         --ffmpeg); --webp adds an animated WebP (Pillow). --side-by-side OTHER puts a second unit (proto name or bundle
         id) on the same clock. Writes video.json beside the video.
compare  two units on one clock (a vanilla unit and a mod unit, or one unit's two variants when --other is left out):
         a sheet with both at every tag stop of either, the rider-horse penetration per cell and the hoof height at
         each unit's footstep tags (compare.json).
crosscheck  the same keys through the viewer and through pose_sim + background Blender, side by side (crosscheck.py).

Lighting: --lgt names an lgt set; a preset (lighting.PRESETS: Tantalus Viewer, NewEngland_Skirmish) is drawn from its
lighting pack with the default bundle, any other set rebuilds the bundle with it. Every output folder is outside every
repository (default <cache>/out/<command>-<time>). Fidelity: every report, sidecar, sheet header and video overlay
carries the bundle's M/A/U/H flags (bundle.py FIDELITY_STAGES, TIMELINE_STAGES, EXPORT_STAGES; lighting.py
SHADING_FIDELITY).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402

CAMS = {'side': (90, 0.05), 'threequarter': (35, 0.2), 'otherside': (270, 0.05)}
# ortho views (render_obj camera: eye along (sin az, -cos az, el) in the gxo frame). Measured on the Iron Flail horse
# (head bone at engine +Z, _l bones on -X): az 0 looks at its front, az 90 at its left side.
ORTHO3 = (('front', 0, 0.05), ('side', 90, 0.05), ('top', 90, 6.0))
CAM_NAMES = ('game', 'close', 'ortho3') + tuple(CAMS)
BUNDLE_ID = re.compile(r'^[0-9a-f]{16}$')


# ---------------------------------------------------------------------------------------------------- subjects
def _lgt_plan(lgt):
    """(bundle lgt, shading lighting): a preset is drawn from its lighting pack with the default bundle; any other
    lgt set rebuilds the bundle with it as the bundle's own lighting."""
    import bundle as B
    import lighting as L
    if not lgt:
        return B.DEFAULT_LGT, None
    if lgt in {p['name'] for p in L.PRESETS}:
        return B.DEFAULT_LGT, lgt
    return lgt, None


def load_subject(proto=None, animfile=None, bundle_id=None, lgt=None, log=print):
    """(bundle id, manifest, shading lighting or None) from a bundle id or a fresh build of a proto / animfile."""
    if bundle_id:
        if not BUNDLE_ID.match(bundle_id):
            raise ValueError('bad bundle id %r (16 hex digits)' % bundle_id)
        p = C.cache_root() / bundle_id / 'manifest.json'
        if not p.is_file():
            raise FileNotFoundError('no bundle %s under %s: build it first (anim_viewer.py build)' % (bundle_id,
                                                                                                     C.cache_root()))
        m = C.read_json(p)
        shading = None
        if lgt:
            presets = {x['name'] for x in (m.get('lighting') or {}).get('presets') or [] if x.get('bundle_id')}
            own = ((m.get('lighting') or {}).get('lgt') or {}).get('name')
            if lgt in presets:
                shading = lgt
            elif lgt != own:
                raise LookupError('lgt %r is neither this bundle\'s own (%s) nor one of its presets (%s): build with '
                                  '--proto and --lgt' % (lgt, own, ', '.join(sorted(presets)) or 'none'))
        return bundle_id, m, shading
    import bundle as B
    blgt, shading = _lgt_plan(lgt)
    res = B.build_bundle(proto=proto, animfile=animfile, lgt=blgt, log=log)
    return res.bundle_id, res.manifest, shading


def _bundle(a, log=print):
    """(bundle id, manifest) from --bundle or a fresh build of --proto / --animfile (serve)."""
    bid, m, _s = load_subject(getattr(a, 'proto', None), getattr(a, 'animfile', None), getattr(a, 'bundle', None),
                              None if getattr(a, 'bundle', None) else getattr(a, 'lgt', None), log)
    return bid, m


def other_subject(spec, lgt=None, log=print):
    """a second subject from a proto name or a bundle id"""
    if BUNDLE_ID.match(spec or ''):
        return load_subject(bundle_id=spec, lgt=lgt, log=log)
    return load_subject(proto=spec, lgt=lgt, log=log)


def main_anims(m):
    return m['animfiles'][m['composition']['main']]['anims']


def anim_name(m, name):
    """the main animfile's anim of that name (case-insensitive); LookupError listing the anims otherwise."""
    anims = main_anims(m)
    for k in anims:
        if k.lower() == str(name).lower():
            return k
    raise LookupError('anim %s is not in %s (have %s)' % (name, m['composition']['main'], ', '.join(anims)))


def main_duration(m, anim, variant):
    """the main clip's duration of (anim, variant) (variant taken mod the variant count)."""
    a = main_anims(m)[anim_name(m, anim)]
    v = a['variants'][int(variant) % len(a['variants'])]
    return float((m['clips'].get(v['clip']) or {}).get('duration') or 0.0)


def cameras(spec):
    """[(label, camera dict)] of a --cam value: a comma list of game, close, ortho3, side, threequarter, otherside."""
    out = []
    for name in [s.strip() for s in str(spec or 'game').split(',') if s.strip()]:
        if name == 'game':
            out.append(('game', {'mode': 'game'}))
        elif name == 'close':
            out.append(('close', {'mode': 'close'}))
        elif name == 'ortho3':
            out += [(lab, {'mode': 'ortho', 'az': az, 'el': el}) for lab, az, el in ORTHO3]
        elif name in CAMS:
            out.append((name, {'mode': 'ortho', 'az': CAMS[name][0], 'el': CAMS[name][1]}))
        else:
            raise ValueError('camera %r (one of %s, comma separated)' % (name, ', '.join(CAM_NAMES)))
    return out


def parse_at(text):
    """'tags' | 'keys' | 'fps=N' -> the job's `at` value (ValueError otherwise)."""
    s = str(text).strip().lower()
    if s in ('tags', 'keys'):
        return s
    m = re.match(r'^fps\s*=\s*([0-9]*\.?[0-9]+)$', s)
    if m and float(m.group(1)) > 0:
        return 'fps=%g' % float(m.group(1))
    raise ValueError('--at %r: tags, keys or fps=N' % text)


def shading_of(a, lighting):
    s = {}
    if lighting:
        s['lighting'] = lighting
    if getattr(a, 'renderer', None):
        s['renderer'] = a.renderer
    if getattr(a, 'player', None) is not None:
        s['player'] = a.player
    return s


def merged_fidelity(m, frame=None):
    """the bundle block with the renderer's runtime block (frame['fidelity']) on top"""
    fid = dict(m.get('fidelity') or {})
    rf = (frame or {}).get('fidelity') or {}
    if rf.get('stages'):
        fid['stages'] = dict(rf['stages'])
        fid['notes'] = dict(rf.get('notes') or fid.get('notes') or {})
    import bundle as B
    for k, (flag, note) in list(B.TIMELINE_STAGES.items()) + list(B.EXPORT_STAGES.items()):   # an older bundle
        fid.setdefault('stages', {}).setdefault(k, flag)
        fid.setdefault('notes', {}).setdefault(k, note)
    return fid


def _base(p):
    return Path(p).name if p else '-'


def run(bid, job, out, a, log=print):
    import headless as H
    rec = H.run_job(bid, job, out_dir=out, gpu=a.gpu, timeout=a.timeout, browser=a.browser, log=log)
    if rec['status'] != 'done':
        raise RuntimeError('headless run %s: %s (browser log %s)' % (rec['status'], rec.get('error'),
                                                                     rec.get('browser_log')))
    if rec.get('leftover_processes') or rec.get('profile_deleted') is False:
        log('WARNING: browser leftovers %s, profile deleted %s' % (rec.get('leftover_processes'),
                                                                  rec.get('profile_deleted')))
    return rec


def run_summary(rec):
    return {k: rec.get(k) for k in ('status', 'error', 'elapsed_s', 'out_dir', 'leftover_processes', 'profile_deleted',
                                    'profile_holders', 'gpu_mode')}


def cell_record(fr, m, cam_label=None, extra=None):
    """the sidecar of one rendered cell: anim, variant, clip, key, time, tag, fidelity and where it came from."""
    import sheets as S
    cell = fr.get('cell') or {}
    fid = merged_fidelity(m, fr)
    rec = {'png': fr['png'], 'subject': fr.get('subject', 'a'), 'bundle_id': fr.get('bundle_id') or m['bundle_id'],
           'proto': m['subject'].get('proto'), 'animfile': m['subject'].get('animfile'),
           'anim': cell.get('anim', fr.get('anim')), 'variant': cell.get('variant', fr.get('variant')),
           'clip': cell.get('clip'), 'key': cell.get('key'), 'keys_of': cell.get('keys_of'),
           'time': cell.get('time', fr.get('t')), 'D': cell.get('D'), 'tag': cell.get('tag'),
           'tags': cell.get('tags') or [], 'keys': cell.get('keys') or [], 'camera': cam_label,
           'camera_record': fr.get('camera'), 'framing': fr.get('framing'), 'expand': fr.get('expand'),
           'lighting': (fr.get('shading') or {}).get('lighting'), 'renderer': (fr.get('shading') or {}).get('mode'),
           'fidelity': dict(S.fidelity_summary(fid), notes=fid.get('notes') or {})}
    if fr.get('clock'):
        rec['clock'] = fr['clock']
    rec.update(extra or {})
    return rec


def caption(rec, metrics=None):
    """the 2-4 caption lines of a sheet cell"""
    kof = (rec.get('keys_of') or 1) - 1
    lines = ['v%s  t %.4f s  key %s/%s' % (rec['variant'], rec['time'] or 0, rec.get('key'), kof),
             (rec.get('tag') or '-') + ('   [%s]' % rec['camera'] if rec.get('camera') else '')]
    for k in rec.get('keys') or []:
        if k['role'] != 'main':
            lines.append('%s %s k%d/%d' % (k['role'], Path(k['clip']).stem, k['key'], k['of'] - 1))
            break
    if metrics:
        lines.append(metrics)
    return lines


def metrics_of(out, fr):
    """{penetration, footsteps} of a frame's geometry dump (metrics.py)."""
    import metrics as MX
    if not fr.get('geom'):
        return None
    g = MX.read_geom(Path(out) / fr['geom'])
    tags = (fr.get('cell') or {}).get('tags') or []
    return {'penetration': MX.penetration(g), 'hooves': MX.hoof_heights(g), 'footsteps': MX.footstep_report(g, tags)}


def metrics_line(mx):
    if not mx:
        return None
    p = mx['penetration']
    s = 'pen n/a' if p.get('status') != 'ok' else 'pen max %.3f m, %.1f %% in' % (p['max_depth'], 100 * p['frac_inside'])
    if mx.get('footsteps'):
        s += '  ' + ' '.join('%s %s' % ('/'.join(f['legs']), '-' if f['height'] is None else '%.3f' % f['height'])
                             for f in mx['footsteps'])
    return s


# ---------------------------------------------------------------------------------------------------- build / serve
def cmd_build(a):
    import bundle as B
    res = B.build_bundle(proto=a.proto, animfile=a.animfile, lgt=a.lgt)
    s = res.summary()
    if a.json:
        sys.stdout.write(C.json_text(s))
    else:
        for k, v in s.items():
            print('%-14s %s' % (k, v))
    return 0


def cmd_serve(a):
    from server import Backend, ViewerServer
    bid, m = _bundle(a)
    root = C.cache_root()
    srv = ViewerServer(a.out, bundle_root=root, port=a.port, backend=Backend(root, log=print),
                       on_event=lambda ev: print('[%7.3f] %s %s' % (ev['t'], ev['kind'], json.dumps(ev['data'])[:300]),
                                                 flush=True) if ev['kind'] not in ('log',) else None)
    srv.start()
    print('bundle  %s  (%s, %d warnings)' % (bid, m['subject'].get('proto') or m['subject']['animfile'],
                                              len(m['warnings'])))
    print('exports %s' % srv.out_dir)
    print('\nOpen in your browser:\n  %s\n' % srv.url('/viewer/app/index.html', bundle=bid), flush=True)
    print('Ctrl+C stops the server.', flush=True)
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        srv.stop()
    return 0


# ---------------------------------------------------------------------------------------------------- render
def render_job(m, a, lighting):
    """the job dict of a render command: one frame spec per (anim, variant, camera); `at` expands in the page."""
    anims = list(main_anims(m)) if a.anim == 'all' else [anim_name(m, a.anim)]
    cams = cameras(a.cam)
    at = parse_at(a.at) if a.at else ({'all': 'keys', 'tags': 'tags'}[a.keys] if a.keys else None)
    frames = []
    for anim in anims:
        n = len(main_anims(m)[anim]['variants'])
        variants = range(n) if a.variant == 'all' else [int(a.variant) % n]
        for vi in variants:
            for lab, cam in cams:
                f = {'name': C.safe_stem('%s_v%d_%s' % (anim, vi, lab)), 'anim': anim, 'variant': vi, 'camera': cam,
                     'bones': a.bones, '_cam': lab}
                if at:
                    f['at'] = at
                elif a.time is not None:
                    f['time'] = a.time
                    f['name'] = C.safe_stem('%s_t%.4f' % (f['name'], a.time))
                else:
                    f['key'], f['key_of'] = a.key, a.key_of
                    f['name'] = C.safe_stem('%s_%s_k%d' % (f['name'], a.key_of, a.key))
                if a.metrics and lab == cams[0][0]:
                    f['geometry'] = True
                frames.append(f)
    job = {'width': a.size, 'height': a.size, 'readback': a.readback, 'frames': frames, 'timeline': True,
           'bounds': 'clip' if (at or a.framing == 'clip') and a.framing != 'frame' else 'frame',
           'background': [0, 0, 0, 0] if a.transparent else None, 'grid': not a.transparent,
           'shading': shading_of(a, lighting) or None}
    return {k: v for k, v in job.items() if v is not None}, at, cams


def cmd_render(a):
    import sheets as S
    bid, m, lighting = load_subject(a.proto, a.animfile, a.bundle, a.lgt)
    job, at, cams = render_job(m, a, lighting)
    cam_of = {}
    for f in job['frames']:
        cam_of[f['name']] = f.pop('_cam')
    out = C.output_dir(a.out, 'render')
    C.write_json(out / 'job.json', job)
    rec = run(bid, job, out, a)
    res = rec['result'] or {}
    frames = res.get('frames') or []
    cells, by_anim = [], {}
    for fr in frames:
        spec = next((n for n in cam_of if fr['name'] == n or fr['name'].startswith(n + '_')), None)
        lab = cam_of.get(spec)
        mx = metrics_of(out, fr) if a.metrics else None
        crec = cell_record(fr, m, lab, {'metrics': mx} if mx else None)
        S.write_cell_sidecar(out / fr['png'], crec)
        cells.append(crec)
        label = (fr.get('expand') or {}).get('label') or ('t%.4f' % crec['time'])
        by_anim.setdefault(crec['anim'], []).append({'png': out / fr['png'], 'row': 'v%s %s' % (crec['variant'], label),
                                                     'col': lab, 'caption': caption(crec, metrics_line(mx)),
                                                     'record': crec})
    sheets = []
    fid = merged_fidelity(m, frames[0] if frames else None)
    for anim, items in by_anim.items():
        if len(cams) == 1:                                     # one camera: wrap the cells into rows
            cols = a.sheet_cols or (6 if at in ('keys',) or (at or '').startswith('fps') else 4)
            for i, it in enumerate(items):
                it['row'], it['col'] = i // cols, i % cols
        title = '%s  %s  %s' % (m['subject'].get('proto') or _base(m['subject']['animfile']), anim,
                                'at its tags' if at == 'tags' else 'at every key' if at == 'keys' else
                                ('at %s' % at) if at else 'frames')
        sub = 'bundle %s   lighting %s   renderer %s   cameras %s   framing %s   %d cells' % (
            bid, (frames[0].get('shading') or {}).get('lighting') if frames else '-',
            (frames[0].get('shading') or {}).get('mode') if frames else '-', ','.join(c[0] for c in cams),
            job['bounds'], len(items))
        notes = ['skipped: %s %s %.2f (%s)' % (s.get('role'), s['type'], s['fraction'], s['reason'])
                 for s in res.get('skipped') or [] if s.get('frame', '').startswith(C.safe_stem(anim))][:6]
        side = S.make_sheet(items, out / ('sheet_%s.png' % C.safe_stem(anim)), title=title, subtitle=sub,
                            fidelity=fid, notes=notes, cell_width=a.cell_width,
                            columns=None if len(cams) == 1 else [c[0] for c in cams])
        sheets.append(side['sheet'])
    report = {'command': 'render', 'bundle_id': bid, 'subject': m['subject'], 'at': at, 'cameras': [c[0] for c in cams],
              'fidelity': fid, 'run': run_summary(rec), 'renderer': res.get('renderer'), 'gpu_path': res.get('gpu_path'),
              'skipped': res.get('skipped'), 'sheets': sheets, 'cells': cells, 'timelines': res.get('timelines'),
              'frames': frames}
    C.write_json(out / 'report.json', report)
    for c in cells:
        print('%-44s t=%.4f  key %s/%s  %s' % (c['png'], c['time'], c['key'], (c['keys_of'] or 1) - 1, c['tag'] or ''))
    print('sheets: %s' % ', '.join(str(out / s) for s in sheets))
    print('status %s, %d cell(s) in %s' % (rec['status'], len(cells), out))
    return 0


# ---------------------------------------------------------------------------------------------------- video
def _timeline(res, subject, anim, variant):
    for k, v in (res.get('timelines') or {}).items():
        if v.get('subject') == subject and v.get('anim', '').lower() == anim.lower() and v.get('variant') == variant:
            return v
    return None


def _overlay_info(m, fr, tl, events, plan_i, sched_i, n, a, cam_label, lighting):
    import video as VD  # noqa: F401
    cell = fr.get('cell') or {}
    main = next((s for s in (tl or {}).get('sides') or [] if s['key'] == (tl or {}).get('main')), {})
    sides = ['%s %s  key %d/%d  clip t %.3f' % (k['role'], Path(k['clip']).stem, k['key'], k['of'] - 1, k['clip_time'])
             for k in cell.get('keys') or [] if k['role'] != 'main']
    return {'title': '%s  %s  v%s  %s' % (m['subject'].get('proto') or _base(m['subject']['animfile']), cell.get('anim'),
                                         cell.get('variant'), _base(cell.get('clip'))),
            'subtitle': 'lighting %s  cam %s  %g fps x %d loops  exact times, not a capture' % (
                lighting or (fr.get('shading') or {}).get('lighting'), cam_label, a.fps, a.loops),
            't': sched_i['t'], 'D': (tl or {}).get('D') or cell.get('D'), 'key': cell.get('key'),
            'keys_of': cell.get('keys_of'), 'fps_rounded': main.get('rounded'), 'loop': sched_i['loop'],
            'loops': a.loops, 'frame': sched_i['index'], 'frames': n, 'sides': sides, 'events': events,
            'hits': plan_i['hits'], 'flash': plan_i['flash'], 'flash_events': plan_i['flash_events'],
            'fidelity': merged_fidelity(m, fr)}


def cmd_video(a):
    import video as VD
    from PIL import Image
    ffmpeg = None
    if not a.no_mp4:
        ffmpeg = VD.ffmpeg_path(a.ffmpeg)                     # fail before rendering when it is missing
    bid, m, lighting = load_subject(a.proto, a.animfile, a.bundle, a.lgt)
    anim = anim_name(m, a.anim)
    variant = int(a.variant) % len(main_anims(m)[anim]['variants'])
    D = main_duration(m, anim, variant)
    sched = VD.schedule(D, a.fps, a.loops)
    other = None
    if a.side_by_side:
        bid_b, m_b, _l = other_subject(a.side_by_side, a.lgt)
        try:
            anim_b = anim_name(m_b, a.side_anim or anim)
        except LookupError:
            anim_b = anim_name(m_b, 'Idle')
        variant_b = (int(a.side_variant) if a.side_variant is not None else variant) % len(main_anims(m_b)[anim_b]['variants'])
        D_b = main_duration(m_b, anim_b, variant_b)
        for f in sched:
            f['t_b'], f['loop_b'] = VD.loop_time(f['t_global'], D_b)
        other = {'bundle': bid_b, 'anim': anim_b, 'variant': variant_b, 'manifest': m_b, 'D': D_b}
    times, of = VD.unique_times(sched, ('t', 't_b') if other else 't')
    cam_label, cam = cameras(a.cam)[0]
    spec = {'name': 'p', 'anim': anim, 'variant': variant, 'camera': cam,
            'times': [t[0] if other else t for t in times]}
    if other:
        spec['other_times'] = [t[1] for t in times]
    job = {'width': a.size, 'height': a.size, 'frames': [spec], 'bounds': 'clip', 'timeline': True,
           'background': [0, 0, 0, 0] if a.transparent else None, 'grid': not a.transparent,
           'shading': shading_of(a, lighting) or None}
    if other:
        job['other'] = {'bundle': other['bundle'], 'anim': other['anim'], 'variant': other['variant']}
    job = {k: v for k, v in job.items() if v is not None}
    out = C.output_dir(a.out, 'video')
    C.write_json(out / 'job.json', job)
    a.timeout = max(a.timeout, 60.0 + 0.6 * len(times) * (2 if other else 1))
    print('rendering %d distinct poses for %d frames (%s, %g fps x %d loops, D %.3f s)' % (
        len(times), len(sched), anim, a.fps, a.loops, D), flush=True)
    rec = run(bid, job, out, a)
    res = rec['result'] or {}
    byname = {fr['name']: fr for fr in res.get('frames') or []}
    tl_a = _timeline(res, 'a', anim, variant)
    ev_a = VD.tag_events(tl_a)
    plan_a = VD.flash_plan(sched, ev_a, D, a.fps)
    if other:
        tl_b = _timeline(res, 'b', other['anim'], other['variant'])
        ev_b = VD.tag_events(tl_b)
        plan_b = VD.flash_plan([{'t': f['t_b']} for f in sched], ev_b, other['D'], a.fps)
    fdir = out / 'frames'
    fdir.mkdir(exist_ok=True)
    stem = C.safe_stem('%s_%s_v%d%s' % (m['subject'].get('proto') or 'unit', anim, variant,
                                        '_vs_%s' % (other['manifest']['subject'].get('proto') or other['bundle'])
                                        if other else ''))
    webp_frames = []
    for i, f in enumerate(sched):
        u = of[i]
        fa = byname['p_%05d' % u]
        ia = Image.open(out / fa['png'])
        if a.timeline_overlay:
            ia = VD.overlay(ia, _overlay_info(m, fa, tl_a, ev_a, plan_a[i], f, len(sched), a, cam_label, lighting))
        img = ia
        if other:
            fb = byname['p_%05d__b' % u]
            ib = Image.open(out / fb['png'])
            if a.timeline_overlay:
                fsb = dict(f, t=f['t_b'], loop=f['loop_b'])
                ib = VD.overlay(ib, _overlay_info(other['manifest'], fb, tl_b, ev_b, plan_b[i], fsb, len(sched), a,
                                                  cam_label, lighting))
            img = VD.side_by_side([ia, ib])
        img = VD.even(img.convert('RGB'))
        C.write_bytes(fdir / ('v_%05d.png' % i), _png(img), 'a video frame')
        if a.webp:
            webp_frames.append(img)
    result = {'command': 'video', 'bundle_id': bid, 'subject': m['subject'], 'anim': anim, 'variant': variant,
              'fps': a.fps, 'loops': a.loops, 'D': D, 'frames': len(sched), 'unique_poses': len(times),
              'camera': cam_label, 'lighting': lighting or ((res.get('frames') or [{}])[0].get('shading') or {}).get(
                  'lighting'), 'timeline_overlay': bool(a.timeline_overlay),
              'schedule': [{'index': f['index'], 't': f['t'], 't_global': f['t_global'], 'loop': f['loop'],
                            't_b': f.get('t_b'), 'pose': of[f['index']],
                            'hits': [e['type'] for e in plan_a[f['index']]['hits']]} for f in sched],
              'tag_events': ev_a, 'fidelity': merged_fidelity(m, (res.get('frames') or [None])[0]),
              'run': run_summary(rec), 'gpu_path': res.get('gpu_path'), 'frames_dir': str(fdir)}
    if other:
        result['other'] = {'bundle_id': other['bundle'], 'subject': other['manifest']['subject'], 'anim': other['anim'],
                           'variant': other['variant'], 'D': other['D'], 'tag_events': ev_b,
                           'clock': 'one clock: frame i shows t_b = (i / fps) mod D_b (compare_clock H)'}
    if ffmpeg:
        mp4 = out / (stem + '.mp4')
        enc = VD.encode_mp4(fdir, 'v_%05d.png', a.fps, mp4, ffmpeg, crf=a.crf)
        enc['ffmpeg_version'] = VD.ffmpeg_version(ffmpeg)
        if enc['returncode'] == 0:
            enc['probe'] = VD.probe(mp4, ffmpeg)
        result['mp4'] = enc
        print('mp4 %s (%s, faststart %s)' % (mp4, 'ok' if enc['returncode'] == 0 else 'FAILED: ' + enc['stderr'][-300:],
                                             enc.get('faststart')))
    if a.webp:
        result['webp'] = VD.encode_webp(webp_frames, out / (stem + '.webp'), a.fps)
        print('webp %s' % result['webp']['out'])
    C.write_json(out / 'video.json', result)
    print('video.json %s' % (out / 'video.json'))
    ok = (not ffmpeg or result['mp4']['returncode'] == 0)
    return 0 if ok else 1


def _png(img):
    import io
    b = io.BytesIO()
    img.save(b, 'PNG')
    return b.getvalue()


# ---------------------------------------------------------------------------------------------------- compare
def cmd_compare(a):
    import sheets as S
    bid, m, lighting = load_subject(a.proto, a.animfile, a.bundle, a.lgt)
    if a.other:
        bid_b, m_b, _l = other_subject(a.other, a.lgt)
    else:
        bid_b, m_b = bid, m
    anim = anim_name(m, a.anim)
    variant = int(a.variant) % len(main_anims(m)[anim]['variants'])
    try:
        anim_b = anim_name(m_b, a.other_anim or anim)
    except LookupError:
        anim_b = anim_name(m_b, 'Idle')
    if a.other_variant is not None:
        variant_b = int(a.other_variant)
    else:
        variant_b = (variant + 1) if (bid_b == bid and anim_b == anim) else variant
    variant_b %= len(main_anims(m_b)[anim_b]['variants'])
    cams = cameras(a.cam)
    at = parse_at(a.at)
    frames = [{'name': C.safe_stem('cmp_%s' % lab), 'anim': anim, 'variant': variant, 'at': at, 'camera': cam,
               'geometry': i == 0, 'other': {'anim': anim_b, 'variant': variant_b}} for i, (lab, cam) in enumerate(cams)]
    job = {'width': a.size, 'height': a.size, 'frames': frames, 'bounds': 'clip', 'timeline': True,
           'other': {'bundle': bid_b, 'anim': anim_b, 'variant': variant_b},
           'background': [0, 0, 0, 0] if a.transparent else None, 'grid': not a.transparent,
           'shading': shading_of(a, lighting) or None}
    job = {k: v for k, v in job.items() if v is not None}
    out = C.output_dir(a.out, 'compare')
    C.write_json(out / 'job.json', job)
    rec = run(bid, job, out, a)
    res = rec['result'] or {}
    name_a = m['subject'].get('proto') or _base(m['subject']['animfile'])
    name_b = m_b['subject'].get('proto') or _base(m_b['subject']['animfile'])
    rows, items = {}, []
    for fr in res.get('frames') or []:
        lab = next((c[0] for c in cams if fr['name'].startswith(C.safe_stem('cmp_%s' % c[0]) + '_')), cams[0][0])
        sm = m if fr['subject'] == 'a' else m_b
        mx = metrics_of(out, fr)
        crec = cell_record(fr, sm, lab, {'metrics': mx} if mx else None)
        S.write_cell_sidecar(out / fr['png'], crec)
        label = (fr.get('expand') or {}).get('label') or 't%.4f' % fr['t']
        row = rows.setdefault(label, {'label': label, 't': (fr.get('clock') or {}).get('shared_t', fr['t']),
                                      'a': {}, 'b': {}})
        if mx:
            row[fr['subject']] = {'png': fr['png'], 'time': crec['time'], 'tag': crec['tag'], 'key': crec['key'],
                                  'penetration': mx['penetration'], 'footsteps': mx['footsteps'],
                                  'hooves': mx['hooves']['legs'] if mx['hooves'].get('status') == 'ok' else None}
        who = name_a if fr['subject'] == 'a' else name_b
        cap = caption(crec, metrics_line(mx))
        cap[0] = '%s %s  %s' % (fr['subject'].upper(), who, cap[0])
        items.append({'png': out / fr['png'], 'row': label, 'col': '%s %s' % (fr['subject'].upper(), lab), 'caption': cap,
                      'record': crec, 'highlight': (255, 90, 74) if mx and mx['penetration'].get('status') == 'ok'
                      and mx['penetration']['max_depth'] > a.flag_depth else None})
    summary = {}
    for s, who in (('a', name_a), ('b', name_b)):
        pens = [(r['t'], r[s]['penetration']) for r in rows.values() if r[s].get('penetration', {}).get('status') == 'ok']
        steps = [dict(f, row=r['label']) for r in rows.values() for f in (r[s].get('footsteps') or [])]
        worst = max(pens, key=lambda x: x[1]['max_depth']) if pens else None
        summary[s] = {'unit': who, 'max_penetration': worst[1]['max_depth'] if worst else None,
                      'worst_time': worst[0] if worst else None,
                      'worst_bone': (worst[1].get('deepest') or {}).get('bone') if worst else None,
                      'mean_frac_inside': (sum(p['frac_inside'] for _t, p in pens) / len(pens)) if pens else None,
                      'footsteps': [{'type': f['type'], 'time': f['time'], 'legs': f['legs'], 'height': f['height']}
                                    for f in steps]}
    fid = merged_fidelity(m, (res.get('frames') or [None])[0])
    title = 'compare  A %s %s v%d   vs   B %s %s v%d   (one clock, at %s)' % (name_a, anim, variant, name_b, anim_b,
                                                                               variant_b, at)
    notes = ['A max penetration %s (t %s, %s); B max penetration %s (t %s, %s); red frame: deeper than %.2f m' % (
        _fmt(summary['a']['max_penetration']), _fmt(summary['a']['worst_time']), summary['a']['worst_bone'],
        _fmt(summary['b']['max_penetration']), _fmt(summary['b']['worst_time']), summary['b']['worst_bone'],
        a.flag_depth),
        'hoof height (m above y = 0) at each unit\'s own footstep tags; legs FL FR BL BR from the bind pose (A)']
    side = S.make_sheet(sorted(items, key=lambda it: rows[it['row']]['t']), out / 'compare.png', title=title,
                        subtitle='bundles %s / %s   lighting %s   cameras %s   framing: one camera for both' % (
                            bid, bid_b, ((res.get('frames') or [{}])[0].get('shading') or {}).get('lighting'),
                            ','.join(c[0] for c in cams)),
                        fidelity=fid, notes=notes, cell_width=a.cell_width,
                        columns=['%s %s' % (s, c[0]) for c in cams for s in ('A', 'B')])
    report = {'command': 'compare', 'a': {'bundle_id': bid, 'subject': m['subject'], 'anim': anim, 'variant': variant},
              'b': {'bundle_id': bid_b, 'subject': m_b['subject'], 'anim': anim_b, 'variant': variant_b},
              'at': at, 'clock': 'one main clock from t = 0; each unit loops its own main clip (compare_clock H)',
              'rows': sorted(rows.values(), key=lambda r: r['t']), 'summary': summary, 'sheet': side['sheet'],
              'skipped': res.get('skipped'), 'fidelity': fid, 'run': run_summary(rec), 'timelines': res.get('timelines')}
    C.write_json(out / 'compare.json', report)
    for s in ('a', 'b'):
        x = summary[s]
        print('%s %-16s max penetration %s at t %s (%s); footsteps %s' % (
            s.upper(), x['unit'], _fmt(x['max_penetration']), _fmt(x['worst_time']), x['worst_bone'],
            ', '.join('%s %s %s' % (f['type'], '/'.join(f['legs']), _fmt(f['height'])) for f in x['footsteps']) or '-'))
    print('sheet %s' % (out / 'compare.png'))
    print('compare.json %s' % (out / 'compare.json'))
    return 0


def _fmt(x):
    return '-' if x is None else '%.3f' % x


def cmd_crosscheck(a, rest):
    import crosscheck as X
    return X.main(rest)


# ---------------------------------------------------------------------------------------------------- CLI
def parser():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0], formatter_class=argparse.RawDescriptionHelpFormatter,
                                 epilog=__doc__.split('\n\n', 1)[1])
    sub = ap.add_subparsers(dest='cmd', required=True)

    def subject(p, need=True):
        g = p.add_mutually_exclusive_group(required=need)
        g.add_argument('--proto', help='proto name, e.g. ypIronFlail')
        g.add_argument('--animfile', help='an animfile id instead of a proto')
        g.add_argument('--bundle', help='an already built bundle id (16 hex digits)')
        p.add_argument('--lgt', default=None, help='lighting set (default: the bundle\'s own, Tantalus Viewer)')

    def headless(p, size=640, timeout=240.0):
        p.add_argument('--size', type=int, default=size, help='frame size in px (default %(default)s)')
        p.add_argument('--renderer', choices=('game', 'placeholder'), help='game shader (default) or the M2 placeholder')
        p.add_argument('--player', type=int, help='player colour index')
        p.add_argument('--transparent', action='store_true', help='transparent background, no grid')
        p.add_argument('--out', help='output folder (default <cache>/out/<command>-<time>; a repository is refused)')
        p.add_argument('--gpu', default='auto', choices=('auto', 'd3d11', 'swiftshader'))
        p.add_argument('--browser', help='chrome (default), edge (only when named) or a path')
        p.add_argument('--timeout', type=float, default=timeout)

    b = sub.add_parser('build', help='write the unit bundle into the cache')
    g = b.add_mutually_exclusive_group(required=True)
    g.add_argument('--proto')
    g.add_argument('--animfile')
    b.add_argument('--lgt', default='Tantalus Viewer')
    b.add_argument('--json', action='store_true')
    s = sub.add_parser('serve', help='serve the viewer for your own browser')
    subject(s)
    s.add_argument('--port', type=int, default=0)
    s.add_argument('--out', help='folder for the page\'s PNG exports (default: the cache; a repository is refused)')

    r = sub.add_parser('render', help='headless PNGs at tags / keys / fps, sheets with JSON sidecars per cell')
    subject(r)
    r.add_argument('--anim', required=True, help='an anim of the main animfile, or "all"')
    r.add_argument('--variant', default='0', help='a variant index or "all"')
    r.add_argument('--at', help='tags | keys | fps=N: the times to render (expanded in the page from the M4 timeline)')
    r.add_argument('--keys', choices=('all', 'tags'), help=argparse.SUPPRESS)          # M2 spelling of --at
    r.add_argument('--key', type=int, default=0)
    r.add_argument('--key-of', choices=('main', 'child'), default='main', help='whose clip --key counts (default main)')
    r.add_argument('--time', type=float, help='main-clock time in seconds instead of a key')
    r.add_argument('--cam', default='game', help='comma list of %s (default game)' % ', '.join(CAM_NAMES))
    r.add_argument('--framing', choices=('auto', 'clip', 'frame'), default='auto',
                   help='camera fit: clip (one framing per clip; default with --at) or frame (each pose)')
    r.add_argument('--bones', action='store_true')
    r.add_argument('--readback', action='store_true', help='also write the bone world matrices per frame (JSON)')
    r.add_argument('--metrics', action='store_true', help='geometry dumps + penetration and hoof heights per cell')
    r.add_argument('--sheet-cols', type=int, help='cells per sheet row with one camera')
    r.add_argument('--cell-width', type=int, help='sheet cell width in px (default: the frame size)')
    headless(r, size=640)

    v = sub.add_parser('video', help='MP4 (and WebP) of an anim, frames at exact times, optional timeline overlay')
    subject(v)
    v.add_argument('--anim', required=True)
    v.add_argument('--variant', default='0')
    v.add_argument('--fps', type=float, default=30.0)
    v.add_argument('--loops', type=int, default=3)
    v.add_argument('--side-by-side', metavar='OTHER', help='a second unit (proto name or bundle id) on the same clock')
    v.add_argument('--side-anim', help='its anim (default: the same name, else Idle)')
    v.add_argument('--side-variant', help='its variant (default: the same index)')
    v.add_argument('--timeline-overlay', action='store_true', help='burn in clip, time, key, tag markers, tag flash')
    v.add_argument('--cam', default='game', choices=('game', 'close') + tuple(CAMS))
    v.add_argument('--webp', action='store_true', help='also an animated WebP (Pillow)')
    v.add_argument('--no-mp4', action='store_true', help='frames (and --webp) only, no ffmpeg')
    v.add_argument('--ffmpeg', help='ffmpeg path (default: config tools.ffmpeg.path)')
    v.add_argument('--crf', type=int, default=18, help='x264 quality (default %(default)s)')
    headless(v, size=640, timeout=300.0)

    c = sub.add_parser('compare', help='two units on one clock: sheet, penetration, hoof height at footstep tags')
    subject(c)
    c.add_argument('--other', help='the second unit: proto name or bundle id (default: the same unit, next variant)')
    c.add_argument('--anim', required=True)
    c.add_argument('--variant', default='0')
    c.add_argument('--other-anim', help='its anim (default: the same name, else Idle)')
    c.add_argument('--other-variant', help='its variant (default: the same index; the next one for the same unit)')
    c.add_argument('--at', default='tags', help='tags (default) | keys | fps=N')
    c.add_argument('--cam', default='game', help='comma list of %s' % ', '.join(CAM_NAMES))
    c.add_argument('--flag-depth', type=float, default=0.10, help='frame cells deeper than this in red (m)')
    c.add_argument('--cell-width', type=int, help='sheet cell width in px')
    headless(c, size=480)
    return ap


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    if argv and argv[0] == 'crosscheck':
        return cmd_crosscheck(None, argv[1:])
    a = parser().parse_args(argv)
    try:
        if a.cmd == 'build':
            return cmd_build(a)
        if a.cmd == 'serve':
            return cmd_serve(a)
        if a.cmd == 'video':
            return cmd_video(a)
        if a.cmd == 'compare':
            return cmd_compare(a)
        return cmd_render(a)
    except Exception as e:                                       # noqa: BLE001 - one clear line, exit 2
        import video as VD
        if isinstance(e, (C.RepoPathError, LookupError, ValueError, FileNotFoundError, VD.FfmpegMissing, RuntimeError)):
            print('error: %s' % e, file=sys.stderr)
            return 2
        raise


if __name__ == '__main__':
    sys.exit(main())
