"""aoe3de-anim-viewer M3: the game shader on the vanilla Iron Flail in headless Chrome (the owner's machine).

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_shading_local.py -q

Local only (the `local` marker; skipped without the game or Chrome). No window: headless.py runs Chrome with
--headless=new and a throwaway profile; bundle, lighting packs and PNGs go to pytest's temp folder (never a repository).
- the bundle carries the M3 fidelity flags, the shader-model version, the EnvBRDF table and both lgt presets as
  lighting packs (Tantalus Viewer, NewEngland_Skirmish) with every reflection-cube level;
- a job renders idle key 0 and attack key 133 with the game shader under both presets and with the M2 placeholder:
  no GL error, the packs are used (no dropped cube levels), the two lgts and the placeholder give different images,
  each frame reports its shading uniforms and its runtime fidelity;
- the front-face convention: with culling off, the fragments the camera sees are front-facing (clockwise, as in D3D)
  and their vertex normals face the camera (>= 95 % of the covered pixels);
- the interactive page mounts the shading panel (the self-test of app.js still passes with the game shader).
"""
import json
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
    root = tmp_path_factory.mktemp('shading-local')
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
    yield {'res': res, 'root': root, 'H': H}
    mp.undo()


def test_bundle_carries_the_shader_model_and_the_presets(env):
    m = env['res'].manifest
    f = m['fidelity']
    assert f['shader_model'] == 'v1' and f['viewer'] == 'm3' and m['tool']['shader_model'] == 'v1'
    assert f['stages']['brdf'] == 'M' and f['stages']['material'] == 'M' and f['stages']['lgt_mapping'] == 'U'
    assert all(v in 'MAUH' for v in f['stages'].values())
    lt = m['lighting']
    assert lt['envbrdf']['status'] == 'measured' and lt['shader']['entries']['sky_cube_normalize']['value'] > 0
    presets = {p['name']: p for p in lt['presets']}
    assert set(presets) == {'Tantalus Viewer', 'NewEngland_Skirmish'}
    for name, p in presets.items():
        assert p['status'] == 'ok', p
        pm = C.read_json(C.cache_root() / p['bundle_id'] / 'manifest.json')
        assert pm['subject'] == {'kind': 'lighting', 'proto': None, 'animfile': None, 'lgt': name}
        refl = pm['lighting']['refl']
        assert refl['levels_skipped'] == [] and len(refl['mips']) == refl['mip_count'] and refl['dtype'] == 'f16'
        assert pm['lighting']['tonemap_lut'] and pm['lighting']['shader']['version'] == 'v1'
    ne = C.read_json(C.cache_root() / presets['NewEngland_Skirmish']['bundle_id'] / 'manifest.json')['lighting']
    assert ne['grade_lut'] and ne['shader']['entries']['grade_enabled']['value'] == 1.0     # its custom .cube LUT


def render(env, frames, name, size=320, **job):
    out = env['root'] / name
    rec = env['H'].run_job(env['res'].bundle_id, dict({'width': size, 'height': size, 'frames': frames}, **job),
                           out_dir=out, timeout=180, log=lambda m: None, label=name)
    assert rec['status'] == 'done', rec.get('error')
    assert rec['profile_deleted'] is not False and not rec.get('leftover_processes')
    r = rec['result']
    assert r['status'] == 'ok' and not r.get('shading_error'), r.get('shading_error')
    return r, Path(rec['out_dir'])


def img(out, name):
    from PIL import Image
    return np.asarray(Image.open(out / (name + '.png')).convert('RGB')).astype(int)


def test_game_shader_frames_under_both_presets(env):
    pose = [('idle', {'anim': 'Idle', 'variant': 0, 'key': 0, 'key_of': 'child'}),
            ('attack', {'anim': 'Attack_melee', 'variant': 0, 'key': 133, 'key_of': 'child'})]
    frames = []
    for pname, p in pose:
        frames.append(dict(p, name=pname + '_tantalus', shading={'lighting': 'Tantalus Viewer'}))
        frames.append(dict(p, name=pname + '_newengland', shading={'lighting': 'NewEngland_Skirmish'}))
        frames.append(dict(p, name=pname + '_placeholder', shading={'renderer': 'placeholder'}))
    r, out = render(env, frames, 'presets', grid=False)
    by = {f['name']: f for f in r['frames']}
    for pname, _ in pose:
        t, n, ph = (by[pname + s] for s in ('_tantalus', '_newengland', '_placeholder'))
        assert t['stats']['renderer'] == n['stats']['renderer'] == 'game' and ph['stats']['renderer'] == 'placeholder'
        assert t['stats']['lighting'] == 'Tantalus Viewer' and n['stats']['lighting'] == 'NewEngland_Skirmish'
        assert t['shading']['uniforms']['envLodOffset'] == 0 and n['shading']['uniforms']['envLodOffset'] == 0
        assert t['stats']['post'] == 'lut' and t['stats']['shadow']['size'] == 2048 and not t['stats']['errors']
        assert t['fidelity']['stages']['brdf'] == 'M' and ph['fidelity']['stages']['brdf'] == 'A'
        a, b, c = img(out, pname + '_tantalus'), img(out, pname + '_newengland'), img(out, pname + '_placeholder')
        cover = np.abs(a - a[2, 2]).max(axis=2) > 10
        assert cover.mean() > 0.05
        assert np.abs(a - b)[cover].mean() > 6 and np.abs(a - c)[cover].mean() > 6     # three different looks
        assert 30 < a[cover].mean() < 220                                                # lit, not black or blown out


def test_front_faces_are_clockwise_like_d3d(env):
    r, out = render(env, [{'name': 'facing', 'anim': 'Idle', 'key': 0, 'shading': {'debug': 'facing'}},
                          {'name': 'facing_side', 'anim': 'Idle', 'key': 0, 'camera': {'yaw': 90},
                           'shading': {'debug': 'facing'}}], 'facing', size=400, grid=False)
    for name in ('facing', 'facing_side'):
        a = img(out, name)
        front, outward = a[..., 0] > 128, a[..., 1] > 128
        covered = front | outward
        agree = (front & outward).sum() / covered.sum()
        print('%s: %d covered px, front and facing the camera %.4f' % (name, covered.sum(), agree))
        assert covered.sum() > 2000 and agree >= 0.95


def test_interactive_page_with_the_game_shader(env):
    H = env['H']
    b = H.select_browsers()[0]
    rec = H.run_page('app/index.html', query={'bundle': env['res'].bundle_id, 'selftest': 1}, browser=b, timeout=120,
                     bundle_root=C.cache_root(), out_dir=env['root'] / 'page', log=lambda m: None, label='page')
    assert rec['status'] == 'done', rec.get('error')
    r = rec['result']
    assert r['status'] == 'ok' and not [e for e in rec.get('events', []) if e['kind'] == 'error'], rec.get('events')
    assert r['stats']['renderer'] == 'game' and not r['stats']['errors']
    assert json.dumps(r['stats']).count('Tantalus Viewer') >= 1
