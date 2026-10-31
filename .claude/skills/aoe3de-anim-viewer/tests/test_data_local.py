"""aoe3de-anim-viewer data modules on the live install: the vanilla Iron Flail (ypIronFlail), read-only.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_data_local.py -q

Owner's machine only: every case carries the consumer's bare `local` marker (the Steam install and the profile; CI
deselects them with -m "not local") and also skips where the game archives or the profile cannot be found. Nothing is
written into a repository: archive copies for the gr2 reader go to the cache, redirected into pytest's temp folder.
Expected values are the design's MVP facts (design 2026-10-11, critic P1-5/P1-6): horse animfile iron_flail.xml with
14 anims / 32 clips, rider iron_flail_rider.xml with 12 anims / 30 clips, the torch on R HAND for the Raze anims, the
whip declared but never attached, MeleeHandAttack ROF 1.5 from the protoactions.
"""
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import animfile as A  # noqa: E402
import av_common as C  # noqa: E402
import proto_resolve as P  # noqa: E402
import tactics as T  # noqa: E402
import vfs as V  # noqa: E402

pytestmark = pytest.mark.local

HORSE = 'units/asians/chinese/iron_flail/iron_flail.xml'
RIDER = 'units/asians/chinese/iron_flail/iron_flail_rider.xml'
WHIP = 'units/asians/chinese/iron_flail/iron_flail_whip.xml'
TORCH = 'effects/projectiles/torch_cavalry.xml'


@pytest.fixture(scope='module')
def live(tmp_path_factory):
    mp = pytest.MonkeyPatch()
    mp.setenv(C.CACHE_ENV, str(tmp_path_factory.mktemp('cache')))
    fs = V.VFS()
    if not any(lay.kind == 'game' for lay in fs.layers):
        mp.undo()
        pytest.skip('no AoE3 DE install found (bartool.find_game_dir / AOE3DE_GAME)')
    if fs.profile is None:
        mp.undo()
        pytest.skip('this checkout does not sit inside an AoE3 profile')
    proto = P.resolve_proto(fs, 'ypIronFlail')
    s = A.AnimfileSet(fs, proto['animfile'], bones=A.Gr2Bones(fs))
    yield fs, proto, s
    mp.undo()


def test_layers_come_from_the_mod_status_file(live):
    fs, _, _ = live
    status = C.read_json(fs.profile / 'mods' / V.MOD_STATUS)
    enabled = sorted((m for m in status['Mods'] if m.get('Enabled')), key=lambda m: m['Priority'])
    ids = [lay.id for lay in fs.layers]
    assert ids[-1] == 'game' and ids[:-1] == ['mod:' + m['Title'] for m in enabled
                                             if (fs.profile / 'mods' / m['Path'].replace(chr(92), '/')).is_dir()]
    repo = HERE.parents[3]
    aop = [lay for lay in fs.layers if lay.kind == 'mod' and lay.root.resolve() == repo.resolve()]
    if aop:                                                  # this checkout is the live mod folder
        assert aop[0].priority == min(m['Priority'] for m in enabled)
    kor = [lay for lay in fs.layers if lay.title == 'age-of-pirates-koreans']
    if kor:                                                  # the add-on is the sibling folder, not AOP_KOREAN_REPO
        assert kor[0].root.parent.name == 'local' and kor[0].root.name == 'age-of-pirates-koreans'


def test_proto_from_the_live_protoy(live):
    fs, proto, _ = live
    assert proto['animfile'] == HORSE and proto['tactics_file'] == 'data/tactics/handcavalrysplash.tactics'
    assert (proto['maxvelocity'], proto['maxrunvelocity'], proto['movementtype']) == (6.5, 8.5, 'land')
    rofs = {a['name']: a['rof'] for a in proto['protoactions']}
    assert rofs['MeleeHandAttack'] == 1.5 and rofs['BuildingAttack'] == 3.0 and rofs['TrampleHandAttack'] == 2.0
    base = fs.provenance.records[proto['sources'][0]['provenance']]
    assert base['path'] == 'data/protoy.xml.xmb' and base['container'] == 'Data.bar'


def test_horse_and_rider_counts(live):
    _, _, s = live
    assert len(s.animfiles[HORSE]['anims']) == 14 and len(s.clips_of(HORSE)) == 32
    assert len(s.animfiles[RIDER]['anims']) == 12 and len(s.clips_of(RIDER)) == 30
    assert sum(len(a['variants']) for a in s.animfiles[HORSE]['anims'].values()) == 48
    assert all(v['clip'] for rec in (s.animfiles[HORSE], s.animfiles[RIDER])
               for a in rec['anims'].values() for v in a['variants'])
    assert s.logic['types']['LowPoly'] == ['normal', 'lowpoly']
    assert s.logic['types']['Tech'][:2] == ['none', 'yphonoredironflail']
    states = [r['state'] for r in s.animfiles[RIDER]['components'][0]['resolved']]
    assert {'Tech': 'none', 'LowPoly': 'lowpoly'} in states
    models = s.animfiles[RIDER]['components'][0]['resolved'][1]['models']
    assert models == ['units/asians/chinese/iron_flail/iron_rider_0_lp.gr2']


def test_rider_seat_and_torch_attach(live):
    _, _, s = live
    seat = s.animfiles[HORSE]['components'][0]['attach'][0]
    assert (seat['a'], seat['frombone'], seat['tobone'], seat['syncanims']) == ('RiderAttachment', 'hotspot',
                                                                                'ATTACHPOINT', True)
    assert seat['resolved']['animfile'] == RIDER and 'engine-bone-assumed' in seat['resolved']['notes']
    to = [c for c in seat['resolved']['checks'] if c['side'] == 'to']
    assert {c['name'] for c in to} == {'bone_attachpoint'}
    for anim in ('Raze_idle', 'Raze_attack'):
        at = s.animfiles[RIDER]['anims'][anim]['attach']
        assert [(a['a'], a['tobone'], a['syncanims']) for a in at] == [('torch', 'R HAND', False)]
        r = at[0]['resolved']
        assert r['animfile'] == TORCH and r['tobone'] is not None
        rider0 = [c for c in r['checks'] if c['side'] == 'to'
                  and c['model'] == 'units/asians/chinese/iron_flail/iron_rider_0.gr2'][0]
        assert rider0['name'] == 'Bip01_R_Hand' and rider0['index'] == r['tobone']
    torch = [a for a in s.animfiles[RIDER]['attachments'] if a['name'] == 'torch'][0]
    assert torch['used_by'] == ['Raze_idle', 'Raze_attack'] and torch['include'] == TORCH


def test_whip_is_declared_but_never_attached(live):
    fs, _, s = live
    whip = [a for a in s.animfiles[RIDER]['attachments'] if a['name'] == 'attachment_whip'][0]
    assert whip['include'] == WHIP and whip['audit'] == ['declared-not-attached'] and whip['used_by'] == []
    assert any(w['code'] == 'attachment-declared-not-attached' and w['path'] == RIDER and 'attachment_whip' in
               w['message'] for w in fs.warnings)
    assert any(w['code'] == 'attachment-effect-not-rendered' and w['path'] == TORCH for w in fs.warnings)


def test_tactics_timing_rof_from_the_protoactions(live):
    fs, proto, s = live
    tac = T.load_tactics(fs, proto['tactics_file'])
    assert [t['name'] for t in tac['tactics']] == ['Melee', 'Trample', 'Defend', 'StandGround']
    trample = [t for t in tac['tactics'] if t['name'] == 'Trample'][0]
    assert trample['speedmodifier'] == 0.5 and trample['anims']['walk'] == 'Walk'
    tim = T.timing(proto, tac, s.animfiles[HORSE])
    rows = {r['action']: r for r in tim['actions']}
    assert rows['MeleeHandAttack']['rof_effective'] == 1.5 and rows['MeleeHandAttack']['rof_source'] == 'protoaction'
    assert rows['MeleeHandAttack']['anim'] == 'Attack_melee'
    assert rows['TrampleHandAttack']['rof_effective'] == 2.0 and rows['TrampleHandAttack']['rof_tactics'] == 1.0
    assert rows['BuildingAttack']['anim'] == 'Raze_attack' and rows['BuildingAttack']['rof_effective'] == 3.0
    assert {'Highstep', 'Attack_trample'} <= set(tim['anims_unreferenced']) and tim['anims_missing'] == []


def test_composition_with_live_durations(live):
    fs, _, s = live
    unit_dir = HERE.parents[1] / 'aoe3de-unit-model' / 'scripts'
    sys.path.insert(0, str(unit_dir))
    import unit_gr2
    durations = {}
    for clip in s.clips_of(HORSE) + s.clips_of(RIDER):
        g = unit_gr2.Gr2(str(fs.materialize(clip)))
        an = [a for a, _ in unit_gr2.refs(g, g.root().get('Animations'))][0]
        durations[clip] = float(an['Duration'][0])
    comp = s.composition(durations)
    p = comp['pairing']
    assert p['child'] == RIDER and p['status'] == 'hypothesis'
    assert sorted((o['anim'], o['side']) for o in p['one_sided']) == [('Attack_trample', 'main'), ('Highstep', 'main')]
    assert len(p['pairs']) == 48 - 3                         # the horse-only variants have no rider pair
    idle7 = [m for m in p['mismatches'] if m['anim'] == 'Idle' and m['variant'] == 6]
    assert idle7 and idle7[0]['main_duration'] == pytest.approx(3.667, abs=1e-3)
    assert idle7[0]['child_duration'] == pytest.approx(4.0, abs=1e-3)
    assert 'Death_by_havoc' in p['ragdoll']
    havoc = [(x['main_variant'], x['child_variant']) for x in p['pairs'] if x['anim'] == 'Death_by_havoc']
    assert havoc == [(0, 0), (1, 1), (2, 0), (3, 1), (4, 0)]
