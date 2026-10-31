"""aoe3de-anim-viewer M4: the timeline, footprint dots and data panels (viewer/timeline, viewer/panels) on a bundle that
bundle.py writes from the synthetic mounted unit, checked under Node's built-in test runner against Python references.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_timeline_panels.py -q

CI-safe (no game bytes: tests/av_unit_fixture.py builds the unit in pytest's temp folder; skipped without Node 18+):
- tag times on the main, absolute and own clocks, the overflow lane (a SpecificSoundSet at 1.20), tag stops;
- the footprint dot of the horse's FootstepLeft (footprintbone horse_neck at 0.25 x 2.0 s) equals the bone's world
  position from gr2_model + gr2_curves within 1e-9; the bone readout of the seat bone likewise;
- the rider's declared weights (3 / 1), the horse-only Highstep with the rider's Idle fallback (assumption);
- curve formats per clip and the B-spline vs knots deviation against gr2_curves.evaluate;
- provenance (every file from the synthetic mod layer), the rider's material slots and parameters, the audit.
The pure JS suites (tests/js/timeline.test.mjs, panels.test.mjs) run in tests/test_viewer_js.py.
"""
import math
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402
try:
    import gr2_model as GM  # noqa: E402
    import gr2_curves as GC  # noqa: E402
except ImportError as e:                       # no consumer GR2 reader (a public export)
    pytest.skip(str(e), allow_module_level=True)
import bundle as B  # noqa: E402
import unit_gr2 as U  # noqa: E402
import av_unit_fixture as UF  # noqa: E402

NODE = shutil.which('node')
JS = HERE / 'js' / 'm4' / 'bundle_m4.test.mjs'
pytestmark = pytest.mark.skipif(not NODE, reason='node not on PATH')


def node_major():
    try:
        out = subprocess.run([NODE, '--version'], capture_output=True, text=True, timeout=30).stdout
        return int(out.strip().lstrip('v').split('.')[0])
    except (OSError, ValueError, subprocess.SubprocessError):
        return 0


def world(model, clip, t):
    """gr2_model + gr2_curves: tracks by the engine name rule, rest locals elsewhere (the rig's Newton rule)."""
    by = {U.nm(tr.bone): tr for tr in clip.tracks} if clip else {}
    L = model.rest_local()
    for i, b in enumerate(model.bones):
        tr = by.get(U.nm(b['name']))
        if tr is not None:
            L[i] = GC.track_matrix(tr.curves, min(max(t, 0.0), clip.duration))
    return GM.compose_world(L, model.parents)


def deviation(clip):
    """B-spline against the knots-linear view at every key of the clip_decode grid (panels/data.js curveDeviation)."""
    fps = round(clip.fps_declared)
    times = [min(k / fps, clip.duration) for k in range(clip.key_count)]
    out = {'position': 0.0, 'orientation': 0.0, 'scale_shear': 0.0}
    for _tr, key, c in clip.curves():
        if c.kind != 'bspline' or c.degree <= 1:
            continue
        for t in times:
            a = np.asarray(GC.evaluate(c, t, 'bspline'), float)
            b = np.asarray(GC.evaluate(c, t, 'knots'), float)
            if key == 'orientation':
                la, lb = np.linalg.norm(a) or 1.0, np.linalg.norm(b) or 1.0
                d = math.degrees(2 * math.acos(min(1.0, abs(float(a @ b)) / (la * lb))))
            else:
                d = float(np.abs(a - b).max())
            out[key] = max(out[key], d)
    return out


def test_timeline_footprints_and_panels_on_the_synthetic_bundle(tmp_path, monkeypatch):
    if node_major() < 18:
        pytest.skip('node --test needs Node 18 or newer')
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))
    u = UF.write_unit(tmp_path)
    res = B.build_bundle(animfile=u['horse'], fs=UF.vfs(u), out_root=tmp_path / 'bundles', lighting=False,
                         log=lambda m: None)
    m = res.manifest
    art = Path(u['mod']) / 'art'
    horse = GM.read_model(art / u['horse_model'])
    clips = {k: GC.read_clip(art / v) for k, v in u['clips'].items()}
    cid = u['clips']
    d_idle, d_attack, d_ridle = clips['horse_idle'].duration, clips['horse_attack'].duration, clips['rider_idle'].duration
    neck, seat = horse.bone_index('horse_neck'), horse.bone_index('bone_attachpoint')
    t_step = 0.25 * d_idle
    cases = [
        {'anim': 'Idle', 'D': d_idle,
         'sides': [['main', cid['horse_idle'], 'main'], ['child', cid['rider_idle'], 'absolute']],
         'side_flags': [{'role': 'child', 'pastMainEnd': d_ridle > d_idle, 'rounded': 60,
                         'keys': clips['rider_idle'].key_count}],
         'tags': [{'type': 'FootstepLeft', 'role': 'main', 'lane': 'FootstepLeft', 'times': [t_step], 'reached': 1}],
         'lanes': ['FootstepLeft'], 'stops': [t_step],
         'footprints': [{'bone': 'horse_neck', 'status': 'bone', 'index': neck, 'time': t_step,
                         'position': [float(x) for x in world(horse, clips['horse_idle'], t_step)[neck][3, :3]]}],
         'bones': {'name': 'bone_attachpoint', 't': 0.3,
                   'world': [float(x) for x in world(horse, clips['horse_idle'], 0.3)[seat][3, :3]]}},
        {'anim': 'Attack', 'D': d_attack,
         'sides': [['main', cid['horse_attack'], 'main'], ['child', cid['rider_attack'], 'absolute'],
                   ['attachment', None, 'own']],
         'side_flags': [{'role': 'main', 'pastMainEnd': False, 'rounded': 192, 'keys': clips['horse_attack'].key_count}],
         'tags': [{'type': 'Attack', 'role': 'main', 'lane': 'Attack', 'times': [0.54 * d_attack], 'reached': 1},
                  {'type': 'SpecificSoundSet', 'role': 'main', 'lane': 'overflow', 'times': [1.2 * d_attack],
                   'reached': 0}],
         'lanes': ['Attack', 'overflow'], 'stops': [0.54 * d_attack], 'footprints': []},
        {'anim': 'Highstep', 'D': d_attack,
         'sides': [['main', cid['horse_attack'], 'main'], ['child', cid['rider_idle'], 'absolute']],
         'side_flags': [{'role': 'child', 'pastMainEnd': d_ridle > d_attack}],
         'tags': [], 'lanes': [], 'stops': [], 'footprints': [],
         'pairing': {'one_sided': {'anim': 'Highstep', 'side': 'main'}, 'note': 'fallback Idle \\(assumption\\)'}},
    ]
    clip_exp = {}
    for key in ('horse_idle', 'horse_attack', 'rider_idle'):
        c = clips[key]
        clip_exp[cid[key]] = {'formats': sorted({x.format for _, _, x in c.curves()}), 'key_count': c.key_count,
                              'curves': 3 * len(c.tracks), 'deviation': deviation(c)}
    assert clip_exp[cid['horse_idle']]['deviation']['orientation'] > 0, 'the fixture has degree 2/3 curves'
    mats = m['materials']
    rider_mat = next(v for k, v in mats.items() if k.startswith(u['rider_model'][:-4]))
    srgb = {'BaseColor': True, 'Details': False}                # the fixture's materialdef
    slots = [[name, 'BC1', [16, 16], 3, srgb[name]] for name, s in rider_mat['slots'].items() if s.get('texture')]
    assert [s[0] for s in slots] == ['BaseColor', 'Details']
    layer = next(lay['id'] for lay in m['layers'] if lay['kind'] == 'mod')
    fx = C.write_json(tmp_path / 'm4.json', {
        'bundle_dir': str(res.folder), 'cases': cases, 'clips': clip_exp, 'rider': u['rider'],
        'rider_model': u['rider_model'], 'rider_idle_weights': [0.75, 0.25], 'rider_slots': slots,
        'rider_floats': [{'name': 'AO Intensity', 'value': 1.0, 'source': 'materialdef'}], 'layer': layer}, indent=None)
    r = subprocess.run([NODE, '--test', '--test-reporter=tap', str(JS)], capture_output=True, text=True,
                       encoding='utf-8', errors='replace', timeout=600, cwd=str(HERE.parent),
                       env=dict(os.environ, AV_M4_FIXTURE=str(fx)))
    out = r.stdout + r.stderr
    assert r.returncode == 0, out[-8000:]
    assert '# fail 0' in out and '# skipped 0' in out, out[-4000:]
    assert out.count('max |JS - Python|') == 1 and out.count('deviation ') == 9, out[-4000:]
