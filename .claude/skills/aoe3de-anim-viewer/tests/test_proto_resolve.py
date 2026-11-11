"""aoe3de-anim-viewer proto resolution (scripts/proto_resolve.py): protoy + every enabled mod's protomods.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_proto_resolve.py -q

Synthetic and CI-safe: a fake Data.bar holds protoy as XMB; two fake mods hold protomods (one with an .xmb twin).
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
import proto_resolve as P  # noqa: E402
import vfs as V  # noqa: E402

PROTOY = '''<proto version="7">
  <unit id="915" name="ypIronFlail">
    <dbid>1339</dbid>
    <maxvelocity>6.5000</maxvelocity>
    <maxrunvelocity>8.5000</maxrunvelocity>
    <movementtype>land</movementtype>
    <animfile>units\\asians\\chinese\\iron_flail\\iron_flail.xml</animfile>
    <unittype>AbstractCavalry</unittype>
    <contain indelay="1.5" outdelay="0.0">AbstractArtillery</contain>
    <tactics>handCavalrySplash.tactics</tactics>
    <protoaction><name>MeleeHandAttack</name><damage>19.000000</damage><rof>1.500000</rof>
      <damagebonus type="AbstractInfantry">1.500000</damagebonus></protoaction>
    <protoaction><name>TrampleHandAttack</name><damage>17.000000</damage><rof>2.000000</rof></protoaction>
  </unit>
  <unit id="1" name="Settler"><dbid>1</dbid><animfile>units\\settler\\settler.xml</animfile></unit>
</proto>'''


@pytest.fixture(autouse=True)
def cache_in_tmp(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))


def build(tmp_path, aop_mods=None, kor_mods=None, aop_twin=True):
    F.Game(tmp_path / 'game').add('Data', 'protoy.xml', PROTOY, xmb=True).write()
    p = F.Profile(tmp_path / 'profile')
    aop = p.mod('age-of-pirates', priority=1)
    kor = p.mod('age-of-pirates-koreans', priority=2)
    p.write()
    if aop_mods:
        aop.write('data/protomods.xml', aop_mods)
        if aop_twin:
            aop.write('data/protomods.xml.xmb', F.alz4(F.to_xmb(aop_mods)))
    if kor_mods:
        kor.write('data/protomods.xml', kor_mods)
    return V.VFS(profile=tmp_path / 'profile', game_dir=tmp_path / 'game')


def test_tactics_id():
    assert P.tactics_id('handCavalrySplash.tactics') == 'data/tactics/handcavalrysplash.tactics'
    assert P.tactics_id('data/tactics/x.tactics') == 'data/tactics/x.tactics'


def test_vanilla_proto_record(tmp_path):
    fs = build(tmp_path)
    rec = P.resolve_proto(fs, 'ypIronFlail')
    assert rec['name'] == 'ypIronFlail' and rec['dbid'] == 1339
    assert rec['animfile'] == 'units/asians/chinese/iron_flail/iron_flail.xml'
    assert rec['tactics_file'] == 'data/tactics/handcavalrysplash.tactics'
    assert (rec['maxvelocity'], rec['maxrunvelocity'], rec['movementtype']) == (6.5, 8.5, 'land')
    assert [(a['name'], a['rof'], a['damage']) for a in rec['protoactions']] == \
        [('MeleeHandAttack', 1.5, 19.0), ('TrampleHandAttack', 2.0, 17.0)]
    assert rec['protoactions'][0]['fields'][-1] == {'tag': 'damagebonus', 'attrs': {'type': 'AbstractInfantry'},
                                                    'text': '1.500000'}
    assert rec['techs_applied'] == [] and rec['sources'] == [{'layer': 'game', 'provenance': 0, 'rule': 'base'}]
    assert fs.provenance.records[0]['path'] == 'data/protoy.xml.xmb'
    assert fs.provenance.records[0]['container'] == 'Data.bar'
    assert P.resolve_proto(fs, 'ypironflail')['notes'] == ['name matched case-insensitively: ypIronFlail']


def test_a_missing_proto_warns(tmp_path):
    fs = build(tmp_path)
    assert P.resolve_proto(fs, 'zpNothing') is None
    assert fs.warnings[-1]['code'] == 'proto-missing'


def test_child_merge_rules(tmp_path):
    mods = '''<protomods>
      <unit id="915" name="ypIronFlail">
        <contain mergeMode='remove' indelay="1.5" outdelay="0.0">AbstractArtillery</contain>
        <maxvelocity>7.0000</maxvelocity>
        <unittype>AbstractCavalry</unittype>
        <unittype>LogicalTypeNew</unittype>
        <protoaction><name>MeleeHandAttack</name><damage>20</damage><rof>1.250000</rof></protoaction>
        <protoaction><name>NewAttack</name><rof>4.0</rof></protoaction>
        <flag mergemode="add">Tracked</flag>
      </unit>
    </protomods>'''
    fs = build(tmp_path, aop_mods=mods)
    rec = P.resolve_proto(fs, 'ypIronFlail')
    assert rec['maxvelocity'] == 7.0 and rec['maxrunvelocity'] == 8.5
    assert [(a['name'], a['rof']) for a in rec['protoactions']] == \
        [('MeleeHandAttack', 1.25), ('TrampleHandAttack', 2.0), ('NewAttack', 4.0)]
    el, _, _ = P.protodb(fs).merged('ypIronFlail')
    assert [V.text(u) for u in V.kids(el, 'unittype')] == ['AbstractCavalry', 'LogicalTypeNew']
    assert V.kids(el, 'contain') == [] and [V.text(f) for f in V.kids(el, 'flag')] == ['Tracked']
    assert all(V.attr(c, 'mergemode') is None for c in V.kids(el))
    assert rec['sources'][-1]['rule'] == 'merge' and rec['sources'][-1]['layer'] == 'mod:age-of-pirates'
    assert P.MERGE_HYPOTHESIS in rec['notes']
    assert fs.provenance.records[rec['sources'][-1]['provenance']]['path'] == 'data/protomods.xml.xmb'


def test_priority_order_aop_applies_last(tmp_path):
    aop = '<protomods><unit name="ypIronFlail" mergeMode="replace"><dbid>1339</dbid>' \
          '<animfile>units\\aop\\flail.xml</animfile><maxvelocity>9</maxvelocity></unit></protomods>'
    kor = '<protomods><unit name="ypIronFlail"><maxvelocity>3</maxvelocity></unit>' \
          '<unit id="21500" name="zpKoreanThing"><dbid>21500</dbid><animfile>units\\k\\k.xml</animfile>' \
          '<tactics>k.tactics</tactics></unit></protomods>'
    fs = build(tmp_path, aop_mods=aop, kor_mods=kor, aop_twin=False)
    rec = P.resolve_proto(fs, 'ypIronFlail')
    assert [s['rule'] for s in rec['sources']] == ['base', 'merge', 'replace']
    assert [s['layer'] for s in rec['sources']] == ['game', 'mod:age-of-pirates-koreans', 'mod:age-of-pirates']
    assert rec['maxvelocity'] == 9.0 and rec['animfile'] == 'units/aop/flail.xml' and rec['protoactions'] == []
    new = P.resolve_proto(fs, 'zpKoreanThing')
    assert new['sources'][0]['rule'] == 'add' and new['tactics_file'] == 'data/tactics/k.tactics'
    assert 'zpkoreanthing' in P.protodb(fs).names()


def test_merge_unit_remove_and_replace_pure():
    base = ET.fromstring('<unit name="A"><dbid>1</dbid><flag>X</flag></unit>')
    assert P.merge_unit(base, ET.fromstring('<unit name="A" mergeMode="remove"/>')) == (None, 'remove')
    out, rule = P.merge_unit(base, ET.fromstring('<unit name="A" mergeMode="replace"><dbid>2</dbid></unit>'))
    assert rule == 'replace' and V.kid_text(out, 'dbid') == '2' and V.kid(out, 'flag') is None
    out, rule = P.merge_unit(None, ET.fromstring('<unit name="B"><dbid>3</dbid></unit>'))
    assert rule == 'add' and V.kid_text(out, 'dbid') == '3'
    out, rule = P.merge_unit(base, ET.fromstring('<unit name="A"><flag>X</flag><flag>Y</flag></unit>'))
    assert rule == 'merge' and [V.text(f) for f in V.kids(out, 'flag')] == ['X', 'Y']   # no duplicate X
    assert V.kid_text(base, 'dbid') == '1' and len(V.kids(base, 'flag')) == 1             # the base is not touched


def test_subject(tmp_path):
    fs = build(tmp_path)
    assert P.subject(fs, proto='ypIronFlail') == {'kind': 'proto', 'proto': 'ypIronFlail',
                                                  'animfile': 'units/asians/chinese/iron_flail/iron_flail.xml'}
    assert P.subject(fs, animfile='Units' + chr(92) + 'X' + chr(92) + 'x.xml') == \
        {'kind': 'animfile', 'proto': None, 'animfile': 'units/x/x.xml'}
    with pytest.raises(ValueError):
        P.subject(fs)
