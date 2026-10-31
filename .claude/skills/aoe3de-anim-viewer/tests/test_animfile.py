"""aoe3de-anim-viewer animfile resolver (scripts/animfile.py): parse, logic trees, attach resolution, audits,
composition.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_animfile.py -q

Synthetic and CI-safe: a small horse + rider + torch + whip unit shaped like the vanilla Iron Flail (an include
attachment, an inline attachment body, a declared-but-unattached whip, a torch on R HAND, Tech x LowPoly logic,
weights, tags past the clip end) is compiled to XMB into a fake archive; bone names come from a dict provider.
"""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
sys.path.insert(0, str(HERE))
import animfile as A  # noqa: E402
import av_common as C  # noqa: E402
import av_fixtures as F  # noqa: E402
import vfs as V  # noqa: E402


def bs(text):
    """'|' -> backslash: animfile references are written with backslashes, as the game writes them."""
    return text.replace('|', chr(92))


HORSE = bs('''<animfile>
  <definebone>HS Bone Hoof Frnt Lt</definebone>
  <attachment>RiderAttachment<include>units|t|rider.xml</include></attachment>
  <component>ModelComp<logic type="Tech">
      <none><logic type="LowPoly">
          <normal><assetreference type="GrannyModel"><file>units|t|horse_0</file></assetreference></normal>
          <lowpoly><assetreference type="GrannyModel"><file>units|t|horse_0</file></assetreference></lowpoly>
      </logic></none>
      <yptech><logic type="LowPoly">
          <normal><assetreference type="GrannyModel"><file>units|t|horse_1</file></assetreference></normal>
          <lowpoly><assetreference type="GrannyModel"><file>units|t|horse_1</file></assetreference></lowpoly>
      </logic></yptech>
    </logic>
    <decal><effecttype>default</effecttype><texture isfakeshadow="1">shadows_selections|shadow_circle_128x128</texture>
      <selectedtexture>shadows_selections|selection_oval_32x64</selectedtexture><width>1.50</width><height>3.00</height>
    </decal>
    <attach a="RiderAttachment" frombone="hotspot" tobone="ATTACHPOINT" syncanims="1" />
  </component>
  <anim>Walk<assetreference type="GrannyAnim"><file>animation_library|t|horse_walk</file>
      <tag type="FootstepLeft" footprinttype="Horse" footprintbone="HS BONE HOOF FRNT LT">1.00</tag>
      <tag type="FootstepRight" footprinttype="Horse">0.70</tag></assetreference>
    <component>ModelComp</component></anim>
  <anim>Idle
    <assetreference type="GrannyAnim"><file>animation_library|t|horse_idle_a</file><weight>40</weight></assetreference>
    <assetreference type="GrannyAnim"><file>animation_library|t|horse_idle_b</file><weight>10</weight></assetreference>
    <assetreference type="GrannyAnim"><file>animation_library|t|horse_idle_c</file><weight>10</weight></assetreference>
    <component>ModelComp</component></anim>
  <anim>Bored
    <assetreference type="GrannyAnim"><file>animation_library|t|horse_bored_a</file><weight>10</weight></assetreference>
    <assetreference type="GrannyAnim"><file>animation_library|t|horse_idle_a</file></assetreference>
    <component>ModelComp</component></anim>
  <anim>Attack
    <assetreference type="GrannyAnim"><file>animation_library|t|horse_attack_a</file><weight>40</weight>
      <tag type="Attack">0.54</tag><tag type="SpecificSoundSet" checkvisible="1" set="Swoosh">0.40</tag></assetreference>
    <assetreference type="GrannyAnim"><file>animation_library|t|horse_attack_b</file><weight>10</weight>
      <tag type="Attack">0.49</tag><tag type="SpecificSoundSet" checkvisible="1" set="Late">1.20</tag></assetreference>
    <component>ModelComp</component></anim>
  <anim>Highstep<assetreference type="GrannyAnim"><file>animation_library|t|horse_highstep</file></assetreference>
    <component>ModelComp</component></anim>
  <anim>Death_by_havoc
    <assetreference type="GrannyAnim"><file>animation_library|t|horse_death_1</file></assetreference>
    <assetreference type="GrannyAnim"><file>animation_library|t|horse_death_2</file></assetreference>
    <assetreference type="GrannyAnim"><file>animation_library|t|horse_death_3</file></assetreference>
    <component>ModelComp</component></anim>
  <anim animlengthoverride="3.333">Cheer<assetreference type="GrannyAnim"><file>animation_library|t|horse_idle_b</file>
    </assetreference><component>ModelComp</component></anim>
</animfile>''')

RIDER = bs('''<animfile>
  <definebone>Bip01 Prop1</definebone>
  <attachment>torch<include>effects|t|torch.xml</include></attachment>
  <attachment>attachment_whip<include>units|t|whip.xml</include></attachment>
  <component>ModelComp<logic type="Tech">
      <none><assetreference type="GrannyModel"><file>units|t|rider_0</file></assetreference></none>
      <yptech><assetreference type="GrannyModel"><file>units|t|rider_2</file></assetreference></yptech>
  </logic></component>
  <anim>Walk<assetreference type="GrannyAnim"><file>animation_library|t|rider_walk</file>
    <tag type="FootstepLeft" footprinttype="Horse">1.00</tag></assetreference><component>ModelComp</component></anim>
  <anim>Idle
    <assetreference type="GrannyAnim"><file>animation_library|t|rider_idle_1</file><weight>40</weight></assetreference>
    <assetreference type="GrannyAnim"><file>animation_library|t|rider_idle_missing</file><weight>10</weight>
    </assetreference><component>ModelComp</component></anim>
  <anim>Attack
    <assetreference type="GrannyAnim"><file>animation_library|t|rider_attack_a</file></assetreference>
    <assetreference type="GrannyAnim"><file>animation_library|t|rider_attack_b</file></assetreference>
    <component>ModelComp</component></anim>
  <anim>Death_by_havoc<assetreference type="GrannyAnim"><file>animation_library|t|rider_death</file></assetreference>
    <component>ModelComp</component></anim>
  <anim>Raze_idle<assetreference type="GrannyAnim"><file>animation_library|t|rider_raze_idle</file></assetreference>
    <component>ModelComp</component>
    <attach a="torch" frombone="ATTACHPOINT" tobone="R HAND" syncanims="0" /></anim>
  <anim>Raze_attack<assetreference type="GrannyAnim"><file>animation_library|t|rider_raze_attack</file></assetreference>
    <component>ModelComp</component>
    <attach a="torch" frombone="ATTACHPOINT" tobone="R HAND" syncanims="0" /></anim>
  <anim>Wave<assetreference type="GrannyAnim"><file>animation_library|t|rider_wave</file></assetreference>
    <component>ModelComp</component></anim>
</animfile>''')

TORCH = bs('''<animfile>
  <definebone>bone_fire</definebone>
  <attachment>fire<component>fire emitter<assetreference type="popcornFx"><file>fire|fire_torch_b.pkfx</file>
      </assetreference></component>
    <anim>Idle<component>fire emitter</component></anim>
  </attachment>
  <component>ModelComp<assetreference type="GrannyModel"><file>effects|t|torch</file></assetreference></component>
  <anim>Idle<component>ModelComp</component>
    <attach a="fire" frombone="bone_fire" tobone="bone_fire" syncanims="0" /></anim>
</animfile>''')

WHIP = bs('''<animfile><definebone>bip01_attach_rt</definebone>
  <component>whip<assetreference type="GrannyModel"><file>units|t|whip</file></assetreference></component>
  <anim>Idle<assetreference type="GrannyAnim"><file>units|t|whip_idle</file></assetreference>
    <component>whip</component></anim>
</animfile>''')

MODELS = ['units/t/horse_0', 'units/t/horse_1', 'units/t/rider_0', 'units/t/rider_2', 'effects/t/torch',
          'units/t/whip']
CLIPS = ['horse_walk', 'horse_idle_a', 'horse_idle_b', 'horse_idle_c', 'horse_bored_a', 'horse_attack_a',
         'horse_attack_b', 'horse_highstep', 'horse_death_1', 'horse_death_2', 'horse_death_3', 'rider_walk',
         'rider_idle_1', 'rider_attack_a', 'rider_attack_b', 'rider_death', 'rider_raze_idle', 'rider_raze_attack',
         'rider_wave']
BONES = {'units/t/horse_0.gr2': ['root_x', 'bone_attachpoint', 'foot_l'],
         'units/t/horse_1.gr2': ['root_x', 'bone_attachpoint', 'foot_l'],
         'units/t/rider_0.gr2': ['Bip01_Root', 'Bip01_Prop1', 'Bip01_R_Hand', 'bip01_attach_rt'],
         'units/t/rider_2.gr2': None,                                   # e.g. an Oodle-compressed model
         'effects/t/torch.gr2': ['Bone01', 'bone_fire'],
         'units/t/whip.gr2': ['bip01_attach_rt']}
HORSE_ID, RIDER_ID, TORCH_ID, WHIP_ID = ('units/t/horse.xml', 'units/t/rider.xml', 'effects/t/torch.xml',
                                         'units/t/whip.xml')


class DictBones:
    def __init__(self, table):
        self.table, self.reasons = table, {k: 'gr2-unreadable: oodle1' for k, v in table.items() if v is None}

    def __call__(self, model):
        return self.table.get(model)


@pytest.fixture(autouse=True)
def cache_in_tmp(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))


def build(tmp_path, rider_override=None):
    g = F.Game(tmp_path / 'game')
    for afid, text in ((HORSE_ID, HORSE), (RIDER_ID, RIDER), (TORCH_ID, TORCH), (WHIP_ID, WHIP)):
        g.add('Art', afid, text, xmb=True)
    for m in MODELS:
        g.add('Art', m + '.gr2', b'gr2', compress=False)
    for c in CLIPS:
        g.add('Art', 'animation_library/t/%s.gr2' % c, b'gr2', compress=False)
    g.add('Art', 'units/t/whip_idle.gr2', b'gr2', compress=False)
    g.write()
    p = F.Profile(tmp_path / 'profile')
    aop = p.mod('age-of-pirates', priority=1)
    p.write()
    if rider_override:
        aop.write('art/units/t/rider.xml', rider_override, eol='lf')
    return V.VFS(profile=tmp_path / 'profile', game_dir=tmp_path / 'game')


def codes(fs):
    return [w['code'] for w in fs.warnings]


# ---------------------------------------------------------------- pure parsing
def test_parse_tags_weights_and_overrides():
    recs = A.parse_animfile(ET.fromstring(HORSE), HORSE_ID)
    assert list(recs) == [HORSE_ID]
    rec = recs[HORSE_ID]
    assert rec['definebones'] == ['HS Bone Hoof Frnt Lt']
    assert rec['attachments'] == [{'name': 'RiderAttachment', 'include': RIDER_ID, 'body': None, 'used_by': [],
                                   'audit': []}]
    assert rec['includes'] == [RIDER_ID]
    assert list(rec['anims']) == ['Walk', 'Idle', 'Bored', 'Attack', 'Highstep', 'Death_by_havoc', 'Cheer']
    att = rec['anims']['Attack']
    assert att['components'] == ['ModelComp'] and att['weights']['rule'] == 'declared'
    assert att['weights']['normalized'] == pytest.approx([0.8, 0.2])
    v0, v1 = att['variants']
    assert v0['clip'] == 'animation_library/t/horse_attack_a.gr2' and v0['file'] == bs('animation_library|t|horse_attack_a')
    assert v0['weight'] == 40 and v0['index'] == 0 and v0['animlengthoverride'] is None
    assert v0['tags'] == [{'type': 'Attack', 'fraction': 0.54, 'attrs': {}, 'overflow': False},
                          {'type': 'SpecificSoundSet', 'fraction': 0.4, 'attrs': {'checkvisible': '1', 'set': 'Swoosh'},
                           'overflow': False}]
    assert v1['tags'][1]['overflow'] is True and v1['tags'][1]['fraction'] == 1.2
    walk = rec['anims']['Walk']['variants'][0]['tags'][0]
    assert walk['attrs'] == {'footprinttype': 'Horse', 'footprintbone': 'HS BONE HOOF FRNT LT'}
    assert rec['anims']['Bored']['weights'] == {'rule': 'mixed', 'normalized': pytest.approx([10 / 11, 1 / 11])}
    assert rec['anims']['Death_by_havoc']['weights']['rule'] == 'uniform-hypothesis'
    assert rec['anims']['Death_by_havoc']['weights']['normalized'] == pytest.approx([1 / 3] * 3)
    cheer = rec['anims']['Cheer']
    assert cheer['animlengthoverride'] == 3.333 and cheer['variants'][0]['animlengthoverride'] == 3.333


def test_component_logic_tree_and_flattening():
    rec = A.parse_animfile(ET.fromstring(HORSE), HORSE_ID)[HORSE_ID]
    comp = rec['components'][0]
    assert comp['name'] == 'ModelComp' and comp['tree']['logic'] == 'Tech'
    assert [b['state'] for b in comp['tree']['branches']] == ['none', 'yptech']
    leaf = comp['tree']['branches'][0]['node']['branches'][0]['node']
    assert leaf['assets'] == [{'type': 'GrannyModel', 'file': bs('units|t|horse_0'), 'model': 'units/t/horse_0.gr2',
                               'materialvariant': None, 'attrs': {}}]
    assert [(r['state'], r['models']) for r in comp['resolved']] == [
        ({'Tech': 'none', 'LowPoly': 'normal'}, ['units/t/horse_0.gr2']),
        ({'Tech': 'none', 'LowPoly': 'lowpoly'}, ['units/t/horse_0.gr2']),
        ({'Tech': 'yptech', 'LowPoly': 'normal'}, ['units/t/horse_1.gr2']),
        ({'Tech': 'yptech', 'LowPoly': 'lowpoly'}, ['units/t/horse_1.gr2'])]
    d = comp['decals'][0]
    assert (d['effecttype'], d['width'], d['height'], d['isfakeshadow']) == ('default', 1.5, 3.0, True)
    assert d['texture'] == bs('shadows_selections|shadow_circle_128x128')
    at = comp['attach'][0]
    assert (at['a'], at['frombone'], at['tobone'], at['syncanims'], at['allowrotation']) == \
        ('RiderAttachment', 'hotspot', 'ATTACHPOINT', True, None)


def test_variation_branches_branch_attach_and_unknown_elements_are_kept():
    text = bs('''<animfile>
      <attachment>flag<component>f<assetreference type="ClothFlag"><flag><width>2</width></flag></assetreference>
        </component><anim>Idle<component>f</component></anim></attachment>
      <component>ModelComp<logic type="Variation">
          <data weight="3"><assetreference type="GrannyModel" shape="x"><file>b|v1</file>
            <materialvariant index="1"></materialvariant></assetreference>
            <attach a="flag" frombone="b1" tobone="b1" syncanims="0" allowrotation="1" xoffset="0.5"/></data>
          <data><assetreference type="GrannyModel"><file>b|v2</file></assetreference></data>
        </logic><watersplash>1</watersplash></component>
      <anim>Idle<component>ModelComp</component><simskeleton><model>b|damaged</model></simskeleton></anim>
      <anim>Idle<component>Ghost</component><attach a="nothing" frombone="x" tobone="y"/></anim>
      <usescaletounit>1</usescaletounit>
    </animfile>''')
    recs = A.parse_animfile(ET.fromstring(text), 'b/v.xml')
    rec = recs['b/v.xml']
    assert list(recs) == ['b/v.xml', 'b/v.xml#flag'] and recs['b/v.xml#flag']['inline'] is True
    assert recs['b/v.xml#flag']['parent'] == 'b/v.xml' and rec['attachments'][0]['body'] == 'b/v.xml#flag'
    comp = rec['components'][0]
    assert [b['state'] for b in comp['tree']['branches']] == ['data#0', 'data#1']
    assert comp['tree']['branches'][0]['attrs'] == {'weight': '3'}
    a0 = comp['tree']['branches'][0]['node']['assets'][0]
    assert a0['materialvariant'] == 1 and a0['attrs'] == {'shape': 'x'}
    branch_attach = comp['tree']['branches'][0]['node']['attach'][0]
    assert branch_attach['allowrotation'] is True and branch_attach['attrs'] == {'xoffset': '0.5'}
    assert comp['resolved'][0]['attach'] == [branch_attach] and comp['resolved'][1]['attach'] == []
    assert comp['other'] == [{'tag': 'watersplash', 'attrs': {}, 'text': '1'}]
    assert list(rec['anims']) == ['Idle', 'Idle#2'] and rec['audit'][0]['code'] == 'anim-duplicate-name'
    assert rec['anims']['Idle']['other'][0]['tag'] == 'simskeleton'
    assert rec['anims']['Idle#2']['attach'][0]['resolved']['notes'] == ['syncanims-missing']
    assert rec['other'] == [{'tag': 'usescaletounit', 'attrs': {}, 'text': '1'}]
    assert recs['b/v.xml#flag']['components'][0]['tree']['assets'][0]['type'] == 'ClothFlag'


def test_bone_matching_rules():
    bones = ['Bip01_Root', 'bone_attachpoint', 'Bip01_R_Hand', 'HS Bone Hoof']
    assert A.match_bone('bip01 r hand', bones) == (2, 'exact')
    assert A.match_bone('R HAND', bones) == (2, 'alias')
    assert A.match_bone('ATTACHPOINT', bones) == (1, 'alias')
    assert A.match_bone('hs_bone_hoof', bones) == (3, 'exact')
    assert A.match_bone('hotspot', bones) == (None, None)
    assert A.match_bone('ROOT', ['Bip01_Root', 'bone_root']) == (0, 'alias-ambiguous')


# ---------------------------------------------------------------- the resolved set
def test_set_counts_references_and_missing_files(tmp_path):
    fs = build(tmp_path)
    s = A.AnimfileSet(fs, HORSE_ID, bones=DictBones(BONES))
    assert list(s.animfiles) == [HORSE_ID, RIDER_ID, TORCH_ID, TORCH_ID + '#fire', WHIP_ID]
    horse, rider = s.animfiles[HORSE_ID], s.animfiles[RIDER_ID]
    assert (len(horse['anims']), len(s.clips_of(HORSE_ID))) == (7, 11)
    assert (len(rider['anims']), len(s.clips_of(RIDER_ID))) == (7, 8)
    assert rider['anims']['Idle']['variants'][1]['clip'] is None
    assert {'code': 'file-missing', 'clip': 'animation_library/t/rider_idle_missing.gr2', 'anim': 'Idle',
            'variant': 1} in rider['audit']
    assert any(w['code'] == 'file-missing' and 'rider_idle_missing' in w['message'] for w in fs.warnings)
    assert horse['layer'] == 'game' and horse['source_form'] == 'xmb' and horse['eol'] == 'xmb'
    assert fs.provenance.records[horse['provenance']]['path'] == 'units/t/horse.xml.xmb'
    assert s.references['animfiles'] == [HORSE_ID, RIDER_ID, TORCH_ID, WHIP_ID]
    assert 'units/t/rider_2.gr2' in s.references['models'] and len(s.references['clips']) == 11 + 8 + 1
    assert s.logic == {'types': {'Tech': ['none', 'yptech'], 'LowPoly': ['normal', 'lowpoly']},
                       'default': {'Tech': 'none', 'LowPoly': 'normal'},
                       'default_rule': 'first branch of each logic type (a UI default, not an engine claim)'}


def test_attach_resolution_and_bone_audits(tmp_path):
    fs = build(tmp_path)
    s = A.AnimfileSet(fs, HORSE_ID, bones=DictBones(BONES))
    horse, rider, torch = s.animfiles[HORSE_ID], s.animfiles[RIDER_ID], s.animfiles[TORCH_ID]
    r = horse['components'][0]['attach'][0]['resolved']
    assert r['animfile'] == RIDER_ID and r['tobone'] == 1 and r['frombone'] is None
    assert r['notes'] == ['bone-alias-assumed', 'engine-bone-assumed']
    froms = [(c['model'], c['match']) for c in r['checks'] if c['side'] == 'from']
    assert froms == [('units/t/rider_0.gr2', 'unresolved'), ('units/t/rider_2.gr2', 'model-unreadable')]
    assert [c['reason'] for c in r['checks'] if c['match'] == 'model-unreadable'] == ['gr2-unreadable: oodle1']
    for anim in ('Raze_idle', 'Raze_attack'):
        t = rider['anims'][anim]['attach'][0]
        assert (t['a'], t['tobone'], t['syncanims']) == ('torch', 'R HAND', False)
        assert t['resolved']['animfile'] == TORCH_ID and t['resolved']['tobone'] == 2
        to = [c for c in t['resolved']['checks'] if c['side'] == 'to' and c['model'] == 'units/t/rider_0.gr2'][0]
        assert (to['name'], to['match']) == ('Bip01_R_Hand', 'alias')
        assert 'engine-bone-assumed' in t['resolved']['notes']           # the torch has no ATTACHPOINT bone
    fire = torch['anims']['Idle']['attach'][0]['resolved']
    assert fire['animfile'] == TORCH_ID + '#fire' and fire['tobone'] == 1 and fire['notes'] == []
    whip, tor = rider['attachments'][1], rider['attachments'][0]
    assert whip['name'] == 'attachment_whip' and whip['audit'] == ['declared-not-attached'] and whip['used_by'] == []
    assert tor['used_by'] == ['Raze_idle', 'Raze_attack'] and tor['audit'] == []
    assert horse['attachments'][0]['used_by'] == list(horse['anims'])
    w = [x for x in fs.warnings if x['code'] == 'attachment-declared-not-attached']
    assert len(w) == 1 and w[0]['path'] == RIDER_ID and 'attachment_whip' in w[0]['message']
    unresolved = [a for a in horse['audit'] if a['code'] == 'bone-unresolved']
    assert unresolved == [{'code': 'bone-unresolved', 'bone': 'HS Bone Hoof Frnt Lt',
                           'uses': ['definebone', 'tag FootstepLeft@footprintbone'],
                           'models': ['units/t/horse_0.gr2', 'units/t/horse_1.gr2']}]
    assert not [a for a in rider['audit'] if a['code'] == 'bone-unresolved']     # Bip01 Prop1 = Bip01_Prop1
    assert codes(fs).count('engine-bone-assumed') == 2 and codes(fs).count('bone-unresolved') == 1
    eff = [x for x in fs.warnings if x['code'] == 'attachment-effect-not-rendered']
    assert len(eff) == 1 and eff[0]['path'] == TORCH_ID and 'popcornFx' in eff[0]['message']
    over = [x for x in fs.warnings if x['code'] == 'tag-overflow']
    assert len(over) == 1 and over[0]['path'] == HORSE_ID and 'Attack[1] SpecificSoundSet 1.200' in over[0]['message']


def test_without_a_bone_provider_nothing_is_guessed(tmp_path):
    fs = build(tmp_path)
    s = A.AnimfileSet(fs, HORSE_ID)
    r = s.animfiles[HORSE_ID]['components'][0]['attach'][0]['resolved']
    assert r['notes'] == ['bones-not-checked'] and r['tobone'] is None
    assert all(c['match'] == 'not-checked' for c in r['checks'])
    assert 'bone-unresolved' not in codes(fs) and 'engine-bone-assumed' not in codes(fs)
    out = s.to_json()
    assert set(out) == {'animfiles', 'logic'} and "'_done'" not in str(out)
    C.json_text(out)                                                     # serialisable


def test_composition_pairing_hypothesis(tmp_path):
    fs = build(tmp_path)
    s = A.AnimfileSet(fs, HORSE_ID, bones=DictBones(BONES))
    comp = s.composition()
    assert comp['main'] == HORSE_ID
    rider_child = comp['children'][0]
    assert rider_child == {'animfile': RIDER_ID, 'attachment': 'RiderAttachment', 'scope': 'component',
                           'attach': {'a': 'RiderAttachment', 'frombone': 'hotspot', 'tobone': 'ATTACHPOINT',
                                      'syncanims': True},
                           'declared_in': {'animfile': HORSE_ID, 'component': 'ModelComp'}}
    torch_child = [c for c in comp['children'] if c['attachment'] == 'torch'][0]
    assert torch_child['declared_in'] == {'animfile': RIDER_ID, 'anims': ['Raze_idle', 'Raze_attack']}
    p = comp['pairing']
    assert p['child'] == RIDER_ID and p['status'] == 'hypothesis' and p['rule'] == A.PAIRING_RULE
    assert p['sync_modes'] == ['absolute-time', 'normalised-phase'] and p['durations_known'] is False
    assert p['mismatches'] == [] and p['ragdoll'] == []
    assert sorted((o['anim'], o['side']) for o in p['one_sided']) == sorted(
        [('Bored', 'main'), ('Highstep', 'main'), ('Cheer', 'main'), ('Raze_idle', 'child'), ('Raze_attack', 'child'),
         ('Wave', 'child')])
    idle = [(x['main_variant'], x['child_variant'], x['rule']) for x in p['pairs'] if x['anim'] == 'Idle']
    assert idle == [(0, 0, 'index-mod-2'), (1, 1, 'index-mod-2'), (2, 0, 'index-mod-2')]
    assert len(p['pairs']) == 1 + 3 + 2 + 3
    assert codes(fs).count('anim-one-sided') == 6


def test_composition_with_durations(tmp_path):
    fs = build(tmp_path)
    s = A.AnimfileSet(fs, HORSE_ID, bones=DictBones(BONES))
    lib = 'animation_library/t/%s.gr2'
    d = {lib % 'horse_walk': 1.0, lib % 'rider_walk': 1.0, lib % 'horse_idle_a': 2.0, lib % 'horse_idle_b': 3.667,
         lib % 'horse_idle_c': 4.0, lib % 'rider_idle_1': 2.0, lib % 'horse_death_1': 2.0, lib % 'horse_death_2': 2.5,
         lib % 'horse_death_3': 3.0, lib % 'rider_death': 1.0}
    p = s.composition(durations=d)['pairing']
    assert p['durations_known'] is True
    assert p['mismatches'] == [{'anim': 'Idle', 'variant': 2, 'child_variant': 0, 'main_duration': 4.0,
                                'child_duration': 2.0},
                               {'anim': 'Death_by_havoc', 'variant': 0, 'child_variant': 0, 'main_duration': 2.0,
                                'child_duration': 1.0},
                               {'anim': 'Death_by_havoc', 'variant': 1, 'child_variant': 0, 'main_duration': 2.5,
                                'child_duration': 1.0},
                               {'anim': 'Death_by_havoc', 'variant': 2, 'child_variant': 0, 'main_duration': 3.0,
                                'child_duration': 1.0}]
    assert p['ragdoll'] == ['Death_by_havoc'] and 'ragdoll-not-simulated' in codes(fs)


def test_lf_only_mod_animfile_is_flagged(tmp_path):
    fs = build(tmp_path, rider_override=RIDER.replace('><', '>\n<'))
    s = A.AnimfileSet(fs, HORSE_ID, bones=DictBones(BONES))
    rider = s.animfiles[RIDER_ID]
    assert rider['layer'] == 'mod:age-of-pirates' and rider['eol'] == 'lf' and rider['engine_ignored'] is True
    assert rider['source_form'] == 'xml' and 'lf-only-runtime-xml' in codes(fs)


def test_undeclared_attach_component_and_include_cycle(tmp_path):
    a = bs('''<animfile><attachment>B<include>c|b.xml</include></attachment>
      <component>ModelComp<assetreference type="GrannyModel"><file>c|m</file></assetreference>
        <attach a="B" frombone="x" tobone="y" syncanims="1"/></component>
      <anim>Idle<component>ModelComp</component><component>Ghost</component>
        <attach a="Nobody" frombone="x" tobone="y" syncanims="0"/></anim></animfile>''')
    b = bs('<animfile><attachment>A<include>c|a.xml</include></attachment><anim>Idle</anim></animfile>')
    F.Game(tmp_path / 'game').add('Art', 'c/a.xml', a, xmb=True).add('Art', 'c/b.xml', b, xmb=True).write()
    fs = V.VFS(include_mods=False, game_dir=tmp_path / 'game')
    s = A.AnimfileSet(fs, 'c/a.xml', bones=DictBones({}))
    rec = s.animfiles['c/a.xml']
    assert list(s.animfiles) == ['c/a.xml', 'c/b.xml']
    assert 'include-cycle' in codes(fs) and {'code': 'include-cycle', 'include': 'c/a.xml'} in \
        s.animfiles['c/b.xml']['audit']
    assert 'attach-target-undeclared' in codes(fs) and 'component-undeclared' in codes(fs)
    assert {'code': 'attach-target-undeclared', 'a': 'Nobody', 'anim': 'Idle'} in rec['audit']
    assert {'code': 'file-missing', 'model': 'c/m.gr2', 'component': 'ModelComp'} in rec['audit']
    assert rec['components'][0]['tree']['assets'][0]['missing'] is True
    # b's attachment A is declared but nothing attaches it
    assert s.animfiles['c/b.xml']['attachments'][0]['audit'] == ['declared-not-attached']


def test_a_missing_animfile_is_a_stub_not_an_exception(tmp_path):
    F.Game(tmp_path / 'game').add('Art', 'c/x.gr2', b'x', compress=False).write()
    fs = V.VFS(include_mods=False, game_dir=tmp_path / 'game')
    s = A.AnimfileSet(fs, 'c/none.xml')
    assert s.animfiles['c/none.xml']['unavailable_reason'] == 'file-missing' and codes(fs) == ['file-missing']
    assert s.composition()['pairing'] is None
