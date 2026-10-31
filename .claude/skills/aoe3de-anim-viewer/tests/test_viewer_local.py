"""aoe3de-anim-viewer M2 page in headless Chrome on the owner's machine: the vanilla Iron Flail rider on its horse.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_viewer_local.py -q

Local only (the `local` marker; skipped without the game or Chrome). No window: headless.py runs Chrome with
--headless=new and a throwaway profile, both under the cache, which this test redirects into pytest's temp folder
together with the bundle and the PNGs (never a repository, AGENTS.md rules 3 and 8).
- job mode: the rider's oprichnik idle key 0 and oprichnik attack key 133 (192 fps; the horse at the same time, its
  own key reported), PNGs plus the bone world matrices the page computed, which must equal the Python composition
  (gr2_model + gr2_curves) within 1e-9 - the browser runs the same skeleton.js the node parity tests check;
- interactive mode: the page's self-test drives the controls (anim, variant, key steps, bones, sync, logic, curve
  method, export) and posts the state.
"""
import sys
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import av_common as C  # noqa: E402

pytestmark = pytest.mark.local


@pytest.fixture(scope='module')
def env(tmp_path_factory):
    mp = pytest.MonkeyPatch()
    root = tmp_path_factory.mktemp('viewer')
    mp.setenv(C.CACHE_ENV, str(root / 'cache'))
    try:
        import gr2_model  # noqa: F401
        import bundle as B
        import headless as H
        import vfs as V
    except ImportError as e:
        mp.undo()
        pytest.skip(str(e))
    if not H.select_browsers():
        mp.undo()
        pytest.skip('no Chrome (config tools.chrome.path, AOP_ANIM_VIEWER_BROWSER or PATH)')
    fs = V.VFS()
    if not any(lay.kind == 'game' for lay in fs.layers):
        mp.undo()
        pytest.skip('no AoE3 DE install found')
    res = B.build_bundle(proto='ypIronFlail', fs=fs, log=lambda m: None)
    yield {'fs': fs, 'res': res, 'root': root, 'H': H}
    mp.undo()


def test_job_renders_the_rider_on_the_horse_at_idle_0_and_attack_133(env):
    import gr2_curves as GC
    import gr2_model as GM
    import unit_gr2 as U
    from PIL import Image
    H, res, fs = env['H'], env['res'], env['fs']
    job = {'width': 640, 'height': 640, 'readback': True, 'frames': [
        {'name': 'idle_k0', 'anim': 'Idle', 'variant': 0, 'key': 0, 'key_of': 'child'},
        {'name': 'attack_k133', 'anim': 'Attack_melee', 'variant': 0, 'key': 133, 'key_of': 'child'},
        {'name': 'attack_k133_side', 'anim': 'Attack_melee', 'variant': 0, 'key': 133, 'key_of': 'child',
         'camera': {'mode': 'ortho', 'az': 90, 'el': 0.05}, 'bones': True}]}
    rec = H.run_job(res.bundle_id, job, out_dir=env['root'] / 'out', timeout=120, log=lambda m: None)
    assert rec['status'] == 'done', rec.get('error')
    r = rec['result']
    assert r['status'] == 'ok' and r['extensions']['s3tc'] and all(t['path'] == 's3tc' and not t['errors']
                                                                   for t in r['textures'])
    out = Path(rec['out_dir'])
    assert not C.is_repo_path(out)
    m = res.manifest
    horse_af, rider_af = m['composition']['main'], m['composition']['pairing']['child']
    for f in r['frames']:
        png = Image.open(out / f['png']).convert('RGB')
        a = np.asarray(png).astype(int)
        assert png.size == (640, 640) and (np.abs(a - a[2, 2]).max(axis=2) > 12).mean() > 0.03, f['name']
        roles = {i['role']: i for i in f['instances']}
        rider, horse = roles['child'], roles['main']
        assert 'oprichnik' in rider['clip'] and rider['time'] == horse['time'] == f['t']
        rclip = m['clips'][rider['clip']]
        key = 0 if f['name'].startswith('idle') else 133
        assert f['t'] == pytest.approx(min(key / round(rclip['fps_declared']), rclip['duration']), abs=1e-12)
        horse_key = f['t'] * round(m['clips'][horse['clip']]['fps_declared'])       # the equivalent horse key
        assert abs(horse_key - round(horse_key)) < 1e-6, (f['name'], horse_key)     # both clips run at 192 fps
    # the page's own world matrices against the Python composition
    import json
    for name in ('idle_k0', 'attack_k133'):
        back = json.loads((out / ('%s.json' % name)).read_text())
        f = next(x for x in r['frames'] if x['name'] == name)
        roles = {i['role']: i for i in f['instances']}
        hm = GM.read_model(fs.read(roles['main']['model']).data)
        rm = GM.read_model(fs.read(roles['child']['model']).data)
        hc = GC.read_clip(fs.read(roles['main']['clip']).data)
        rc = GC.read_clip(fs.read(roles['child']['clip']).data)

        def world(model, clip, t, place=None):
            by = {U.nm(tr.bone): tr for tr in clip.tracks}
            L = model.rest_local()
            for i, b in enumerate(model.bones):
                if U.nm(b['name']) in by:
                    L[i] = GC.track_matrix(by[U.nm(b['name'])].curves, t)
            W = GM.compose_world(L, model.parents)
            return W if place is None else np.array([w @ place for w in W])
        Wh = world(hm, hc, min(back['t'], hc.duration))
        seat = hm.bone_index('bone_attachpoint')
        Wr = world(rm, rc, back['t'], Wh[seat])
        page = {w['role']: np.array(w['worlds']).reshape(-1, 4, 4) for w in back['worlds']}
        assert np.abs(page['main'] - Wh).max() < 1e-9 and np.abs(page['child'] - Wr).max() < 1e-9, name


def test_interactive_page_self_test(env):
    H = env['H']
    b = H.select_browsers()[0]
    rec = H.run_page('app/index.html', query={'bundle': env['res'].bundle_id, 'selftest': 1}, browser=b, timeout=90,
                     bundle_root=C.cache_root(), out_dir=env['root'] / 'selftest', log=lambda m: None, label='selftest')
    assert rec['status'] == 'done', rec.get('error')
    r = rec['result']
    steps = {s['step']: s for s in r['steps']}
    assert r['status'] == 'ok' and steps['playing']['advanced']
    a = steps['attack v1 +3 keys']
    assert (a['anim'], a['variant'], a['key'], a['playing']) == ('Attack_melee', 1, 3, False)
    logic = steps['bones, phase, logic, knots']
    assert logic['sync'] == 'phase' and logic['method'] == 'knots' and logic['logic']['LowPoly'] == 'lowpoly'
    assert [i[3] for i in logic['instances']] == ['main', 'phase']
    assert steps['export']['message'].startswith('saved ') and 'selftest.png' in rec['files']
    exported = [f for f in Path(rec['out_dir']).iterdir() if f.name.startswith('ypIronFlail_Attack_melee_v1')]
    assert exported and not C.is_repo_path(exported[0])
