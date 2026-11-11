"""aoe3de-anim-viewer tactics and timing (scripts/tactics.py): actions, tactics, transitions, speedmodifier, ROF from
the protoactions.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_tactics.py -q

Synthetic and CI-safe: tactics XML written in the test (shaped like vanilla handcavalrysplash.tactics and
cannon.tactics), read from a fake mod (plain, CRLF) and a fake archive (XMB).
"""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402
import av_fixtures as F  # noqa: E402
import tactics as T  # noqa: E402
import vfs as V  # noqa: E402

TACTICS = '''<tactics>
  <action>
    <name stringid="38135">MeleeHandAttack</name><type>Attack</type><maxrange>1.75</maxrange>
    <rate type="Unit">1.0 </rate><rate type="Building">0.5</rate>
    <anim>Attack_melee</anim><idleanim>Idle</idleanim>
  </action>
  <action>
    <name stringid="38118">BuildingAttack</name><type>Attack</type><anim>Raze_attack</anim><idleanim>Raze_idle</idleanim>
    <typedanim type="Wall">Raze_wall</typedanim>
  </action>
  <action>
    <name stringid="38142">TrampleHandAttack</name><type>Attack</type><anim>Attack_melee</anim>
    <rof>1.0</rof><animationrate>0.46875</animationrate>
  </action>
  <action><name>Limber</name><type>Limber</type><rof>2.5</rof></action>
  <tactic>Melee<action priority="100">BuildingAttack</action><action priority="25">MeleeHandAttack</action>
    <idleanim>Idle</idleanim><boredanim>Bored</boredanim><deathanim>Death_by_melee</deathanim>
    <walkanim>Walk</walkanim><joganim>Jog</joganim><runanim>Run</runanim>
  </tactic>
  <tactic stringid="7">Trample<speedmodifier>0.5</speedmodifier><action priority="25">TrampleHandAttack</action>
    <idleanim>Idle</idleanim><moveanim>Charge_walk</moveanim>
    <transition><tactic>Melee</tactic><length>0.25</length><exit>1</exit></transition>
    <transition><tactic>Bombard</tactic><action>Limber</action><anim>Bombard_unlimber</anim><length>2</length>
      <exit>1</exit><commandautomatic>1</commandautomatic><automatic>1</automatic></transition>
  </tactic>
  <dbaction stringid="1">Something</dbaction>
</tactics>'''

PROTO = {'name': 'ypIronFlail', 'maxvelocity': 6.5, 'maxrunvelocity': 8.5,
         'protoactions': [{'name': 'MeleeHandAttack', 'rof': 1.5}, {'name': 'BuildingAttack', 'rof': 3.0},
                          {'name': 'TrampleHandAttack', 'rof': 2.0}, {'name': 'OnlyInProto', 'rof': 4.0}]}


def animfile_record():
    def var(i, clip):
        return {'index': i, 'clip': clip}
    return {'anims': {'Attack_melee': {'variants': [var(0, 'a.gr2'), var(1, 'b.gr2'), var(2, None)]},
                      'Raze_attack': {'variants': [var(0, 'raze.gr2')]},
                      'Idle': {'variants': [var(0, 'idle.gr2')]}, 'Walk': {'variants': []},
                      'Attack_trample': {'variants': [var(0, 'trample.gr2')]}, 'Highstep': {'variants': []}}}


@pytest.fixture(autouse=True)
def cache_in_tmp(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))


def test_parse_actions_tactics_transitions():
    t = T.parse_tactics(ET.fromstring(TACTICS))
    a = t['actions'][0]
    assert (a['name'], a['stringid'], a['type'], a['anim'], a['idleanim'], a['reloadanim']) == \
        ('MeleeHandAttack', '38135', 'Attack', 'Attack_melee', 'Idle', None)
    assert a['rate'] == [{'type': 'Unit', 'value': 1.0}, {'type': 'Building', 'value': 0.5}] and a['rof'] is None
    assert a['fields'][2] == {'tag': 'maxrange', 'attrs': {}, 'text': '1.75'}
    assert t['actions'][2]['rof'] == 1.0 and t['actions'][2]['animationrate'] == 0.46875
    melee, trample = t['tactics']
    assert melee['name'] == 'Melee' and melee['speedmodifier'] is None
    assert melee['actions'] == [{'name': 'BuildingAttack', 'priority': 100}, {'name': 'MeleeHandAttack', 'priority': 25}]
    assert melee['anims'] == {'idle': 'Idle', 'bored': 'Bored', 'death': 'Death_by_melee', 'walk': 'Walk',
                              'jog': 'Jog', 'run': 'Run'}
    assert trample['speedmodifier'] == 0.5 and trample['stringid'] == '7'
    assert trample['anims'] == {'idle': 'Idle', 'move': 'Charge_walk'}
    t0, t1 = trample['transitions']
    assert (t0['tactic'], t0['length'], t0['exit'], t0['anim'], t0['action']) == ('Melee', 0.25, True, None, None)
    assert (t1['tactic'], t1['length'], t1['anim'], t1['action'], t1['automatic'], t1['commandautomatic']) == \
        ('Bombard', 2.0, 'Bombard_unlimber', 'Limber', True, True)
    assert t['other'] == [{'tag': 'dbaction', 'attrs': {'stringid': '1'}, 'text': 'Something'}]


def test_timing_takes_rof_from_the_protoactions():
    tac = T.parse_tactics(ET.fromstring(TACTICS))
    tim = T.timing(PROTO, tac, animfile_record(), durations={'a.gr2': 1.5, 'b.gr2': 1.5, 'raze.gr2': 1.0})
    rows = {r['action']: r for r in tim['actions']}
    assert tim['status'] == 'hypothesis' and T.RULES['H1'] in tim['rules'] and T.RULES['H3'] in tim['rules']
    m = rows['MeleeHandAttack']
    assert (m['rof_effective'], m['rof_source'], m['rof_tactics'], m['rof_protoaction']) == (1.5, 'protoaction', None,
                                                                                           1.5)
    assert m['clip_durations'] == [1.5, 1.5, None] and m['tactics'] == [{'tactic': 'Melee', 'priority': 25}]
    assert m['notes'] == []
    tr = rows['TrampleHandAttack']
    assert (tr['rof_effective'], tr['rof_source'], tr['rof_tactics']) == (2.0, 'protoaction', 1.0)
    assert tr['animationrate'] == 0.46875 and T.RULES['H3'] in tr['rules']
    assert any('differs from the tactics ROF' in n for n in tr['notes'])
    b = rows['BuildingAttack']
    assert b['rof_effective'] == 3.0 and b['clip_durations'] == [1.0]
    assert any('clip shorter than ROF (1.000 s < 3 s)' in n for n in b['notes'])
    lim = rows['Limber']
    assert (lim['rof_effective'], lim['rof_source']) == (2.5, 'tactics')
    only = rows['OnlyInProto']
    assert (only['anim'], only['rof_effective'], only['rof_source']) == (None, 4.0, 'protoaction')
    assert only['notes'] == ['protoaction without a tactics action: no anim is known']
    mv = {x['tactic']: x for x in tim['movement']['tactics']}
    assert mv['Trample']['maxvelocity_effective'] == 3.25 and mv['Trample']['maxrunvelocity_effective'] == 4.25
    assert mv['Melee']['maxvelocity_effective'] == 6.5 and mv['Melee']['rule'] is None
    assert mv['Trample']['rule'] == T.RULES['H4'] and len(mv['Trample']['transitions']) == 2
    assert sorted(tim['anims_unreferenced']) == ['Attack_trample', 'Highstep']
    assert tim['anims_missing'] == sorted(['bored', 'death_by_melee', 'jog', 'run', 'raze_idle', 'raze_wall',
                                           'charge_walk', 'bombard_unlimber'])


def test_timing_without_proto_or_durations():
    tac = T.parse_tactics(ET.fromstring(TACTICS))
    tim = T.timing(None, tac)
    rows = {r['action']: r for r in tim['actions']}
    assert rows['MeleeHandAttack']['rof_source'] == 'none' and rows['MeleeHandAttack']['clip_durations'] == []
    assert rows['TrampleHandAttack']['rof_source'] == 'tactics'
    assert 'anims_unreferenced' not in tim and tim['movement']['maxvelocity'] is None


def test_load_tactics_from_a_mod_and_from_the_archive(tmp_path):
    F.Game(tmp_path / 'game').add('Data', 'tactics/handcavalrysplash.tactics', TACTICS, xmb=True).write()
    p = F.Profile(tmp_path / 'profile')
    aop = p.mod('age-of-pirates', priority=1)
    p.write()
    fs = V.VFS(profile=tmp_path / 'profile', game_dir=tmp_path / 'game')
    rec = T.load_tactics(fs, 'data/tactics/handcavalrysplash.tactics')
    assert (rec['layer'], rec['source_form'], rec['eol']) == ('game', 'xmb', 'xmb')
    assert [t['name'] for t in rec['tactics']] == ['Melee', 'Trample'] and len(rec['actions']) == 4
    assert fs.provenance.records[rec['provenance']]['container'] == 'Data.bar'
    aop.write('data/tactics/HandCavalrySplash.tactics', TACTICS.replace('Melee<', 'ModMelee<'), eol='lf')
    fs = V.VFS(profile=tmp_path / 'profile', game_dir=tmp_path / 'game')
    rec = T.load_tactics(fs, 'data/tactics/handcavalrysplash.tactics')
    assert rec['layer'] == 'mod:age-of-pirates' and rec['tactics'][0]['name'] == 'ModMelee'
    assert rec['engine_ignored'] is True and [w['code'] for w in fs.warnings] == ['lf-only-runtime-xml']
    assert T.load_tactics(fs, 'data/tactics/none.tactics') is None and fs.warnings[-1]['code'] == 'file-missing'
