"""aoe3de-anim-viewer M4 on the owner's machine: the full viewer UI (3D view, timeline dock, clip picker, data panels)
of the vanilla Iron Flail, captured headless by scripts/ui_shot.py.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_timeline_local.py -q

Local only (the `local` marker; skipped without the game or Chrome). No window: Chrome runs --headless=new with a
throwaway profile; the bundle, the profile and the screenshots go to pytest's temp folder (never a repository,
AGENTS.md rules 3 and 8). Shots:
- Attack_melee paused on its Attack tag (0.54 x 1.5 s) with the Attack tooltip pinned and the Timing panel;
- Walk paused on a FootstepLeft with the Bones panel (the hoof footprint bones exist only as <definebone>: dots at the
  model origin, labelled as an assumption).
Then the page's own interaction checks: tag stepping, key stepping on the 192 fps grid, the tactics-rate preset (the
TrampleHandAttack ROF fit 1.5 / 2.0), the seeded roll.
"""
import sys
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import av_common as C  # noqa: E402

pytestmark = pytest.mark.local
TIMELINE_STAGES = ('key_grid', 'tag_timing', 'tag_overflow', 'variant_choice', 'tactics_rate', 'footprint')


@pytest.fixture(scope='module')
def env(tmp_path_factory):
    mp = pytest.MonkeyPatch()
    root = tmp_path_factory.mktemp('m4ui')
    mp.setenv(C.CACHE_ENV, str(root / 'cache'))
    try:
        import gr2_model  # noqa: F401
        import bundle as B
        import headless as H
        import ui_shot as S
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
    rec = S.run_ui_shots(res.bundle_id, [
        {'name': 'iron_flail_attack_melee_ui', 'anim': 'Attack_melee', 'tag': 'Attack', 'tab': 'timing', 'tip': 'Attack'},
        {'name': 'iron_flail_walk_ui', 'anim': 'Walk', 'tag': 'FootstepLeft', 'tab': 'bones', 'tip': 'FootstepLeft'},
    ], out_dir=root / 'uishot', timeout=180, log=lambda m: None)
    yield {'res': res, 'rec': rec, 'root': root}
    mp.undo()


def test_the_run_is_clean_and_outside_every_repository(env):
    rec = env['rec']
    assert rec['status'] == 'done', (rec.get('error'), rec.get('shot_errors'))
    assert rec['result']['status'] == 'ok' and not rec['shot_errors'] and not rec['rejected']
    assert rec['profile_deleted'] is True and not rec['profile_holders']
    assert [s['name'] for s in rec['shots']] == ['iron_flail_attack_melee_ui', 'iron_flail_walk_ui']
    for s in rec['shots']:
        assert not C.is_repo_path(s['png'])


def test_attack_melee_screenshot_and_page_state(env):
    from PIL import Image
    rec = env['rec']
    shot = rec['result']['shots'][0]
    ui = shot['ui']
    png = Image.open(rec['shots'][0]['png']).convert('RGB')
    assert png.size == tuple(ui['viewport'])
    a = np.asarray(png).astype(int)
    h = a.shape[0]
    dock, view = a[h - 300:], a[: h - 340, : a.shape[1] - 470]
    assert a.std() > 20 and dock.std() > 10 and view.std() > 10, 'blank screenshot or region'
    assert (np.abs(view - view[5, 5]).max(axis=2) > 24).mean() > 0.02, 'the unit is drawn in the 3D view'
    assert shot['anim'] == 'Attack_melee' and shot['variant'] == 0 and shot['tab'] == 'timing'
    assert shot['t'] == pytest.approx(0.54 * 1.5, abs=1e-9)
    assert 'Attack @ 0.540' in shot['tip'] and '0.8100' in shot['tip']
    tags = {(t['type'], t['role']): t for t in ui['tags']}
    assert tags[('Attack', 'main')]['times'] == pytest.approx([0.81]) and tags[('Attack', 'main')]['lane'] == 'Attack'
    assert tags[('SpecificSoundSet', 'main')]['times'] == pytest.approx([0.6])
    assert tags[('SpecificSoundSet', 'main')]['attrs'] == {'checkvisible': '1', 'set': 'Swoosh'}
    sides = {s['role']: s for s in ui['sides']}
    assert sides['main']['rounded'] == 192 and sides['main']['keys'] == 289 and not sides['main']['nonInteger']
    assert sides['child']['clock'] == 'absolute' and 'oprichnik_attack_a' in sides['child']['clip']
    assert [u['name'] for u in ui['unattached']] == ['attachment_whip']
    assert ui['actions'] == ['MeleeHandAttack', 'GuardianAttack', 'TrampleHandAttack', 'DefendHandAttack']
    assert {k: v for k, v in ui['fidelity']['stages'].items() if k in TIMELINE_STAGES} == {
        'key_grid': 'M', 'tag_timing': 'H', 'tag_overflow': 'U', 'variant_choice': 'H', 'tactics_rate': 'H',
        'footprint': 'A'}
    p = ui['panels']
    assert p['timing']['actions'] == 5 and p['clips']['clips'] == 2 and p['bones']['bones'] == 64
    assert p['materials']['materials'] >= 2 and p['provenance']['provenance'] >= 10 and p['audit']['warnings'] >= 1
    assert 'declared-not-attached' in ui['audit']
    assert ui['rows'] >= 12 and ui['markers'] == 2


def test_walk_footprints_are_labelled_assumptions(env):
    ui = env['rec']['result']['shots'][1]['ui']
    lanes = {l['name']: l['n'] for l in ui['lanes']}
    assert (lanes['FootstepLeft'], lanes['FootstepRight']) == (3, 3)
    fp = ui['footprints']
    assert sorted(d['status'] for d in fp) == ['no-footprintbone'] * 2 + ['origin-assumed'] * 4
    assert all(d['position'] == [0, 0, 0] for d in fp if d['status'] == 'origin-assumed')
    assert {d['bone'] for d in fp if d['bone']} == {'HS BONE HOOF FRNT LT', 'HS BONE HOOF BACK LT', 'HS BONE HOOF FRNT RT',
                                                     'HS BONE HOOF BACK RT'}


def test_interaction_checks(env):
    c = env['rec']['result']['checks']
    assert c['next_tag'] == pytest.approx([0.6, 0.81]) and c['prev_tag'] == pytest.approx(0.6)
    assert c['key3_t'] == pytest.approx(3 / 192, abs=1e-12)
    assert c['trate']['action'] == 'TrampleHandAttack' and c['trate']['speed'] == pytest.approx(1.5 / 2.0)
    assert c['trate']['speed_off'] == 1
    assert all(0 <= i < 4 for i in c['roll']) and c['roll_msg'].startswith('rolled v')
