"""The Koreans add-on (koreans/ -> scripts/tools/export_koreans.py): its wiring, and that AoP stays Korean-free.

Repo-only checks run everywhere; building the export needs the Steam install (vanilla animfiles).
"""
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
K = REPO / 'koreans'
BS = chr(92)


def xml(path):
    return ET.fromstring(path.read_bytes().decode('utf-8-sig'))


def test_one_playable_civ_on_the_korean_age0_tech():
    civs = xml(K / 'data/civmods.xml').findall('civ')
    assert [c.findtext('name') for c in civs] == ['zpKoreans']
    civ = civs[0]
    assert civ.findtext('main') == '1' and civ.find('visible') is None
    ages = {a.findtext('age'): a.findtext('tech') for a in civ.findall('agetech')}
    assert ages['Age0'] == 'zpAge0Korean' and ages['Age1'] == 'YPColonializeJapanese'
    assert civ.findtext('culture') == 'Japanese'
    assert (K / 'data' / civ.findtext('homecityfilename')).is_file()


def test_techs_activate_japan_and_the_visual_marker():
    techs = xml(K / 'data/techtreemods.xml').findall('tech')
    assert [t.get('name') for t in techs] == ['zpKoreanVisuals', 'zpAge0Korean']
    active = [e.text for e in techs[1].iter('effect') if e.get('type') == 'TechStatus' and e.get('status') == 'active']
    assert active == ['YPAge0Japanese', 'zpKoreanVisuals']
    assert all(60000 <= int(t.findtext('dbid')) < 61000 for t in techs)


def test_strings_flags_personality_and_sounds():
    ids = re.findall(r'_locid="(\d+)"', (K / 'data/strings/english/stringmods.xml').read_text(encoding='utf-8'))
    assert ids == ['600000', '600001', '600002', '600003', '600004', '600005']
    civ = xml(K / 'data/civmods.xml').find('civ')
    for field in ('homecityflagiconwpf', 'homecityflagbuttonwpf', 'postgameflagiconwpf'):
        assert (K / 'data/wpfg' / civ.findtext(field).replace(BS, '/')).is_file(), field
    assert (K / 'art/objects/flags/zpkoreans.ddt').stat().st_size == 174856        # vanilla flag profile
    pers = xml(K / 'game/ai/personalities/zpmyeongseong.personality')
    assert pers.findtext('forcedciv') == 'zpKoreans' and pers.findtext('nameID') == '600004'
    assert 'zpMyeongseong' in [p.text for p in xml(K / 'game/ai/personalities.xml').findall('Personality')]
    for s in xml(K / 'sound/soundsetsde.mods.xml').iter('sound'):
        assert (K / 'sound' / s.get('filename').replace(BS, '/')).is_file(), s.get('filename')


def test_aop_itself_carries_no_korean_civ_record():
    """The add-on owns these; AoP stays playable without it (the 3D benches zpKoreanTownCenterTest etc. stay)."""
    for rel in ('data/civmods.xml', 'data/techtreemods.xml', 'data/strings/english/stringmods.xml',
                'sound/soundsetsde.mods.xml'):
        text = (REPO / rel).read_text(encoding='utf-8')
        for word in ('zpKoreans', 'zpAge0Korean', 'zpKoreanVisuals', '_locid="60000', 'zpKoreanVillager'):
            assert word not in text, (rel, word)
    for rel in ('art/buildings/town_center/town_center.xml', 'art/buildings/asian_civs/bansho/bansho.xml',
                'art/buildings/asian_civs/stable/stable.xml', 'data/homecityzpkoreans.xml'):
        assert not (REPO / rel).exists(), rel   # generated into the add-on only


@pytest.mark.local('steam')
def test_export_builds_and_every_building_switches_at_the_first_upgrade():
    sys.path.insert(0, str(REPO / 'scripts/tools'))
    import export_koreans
    files = export_koreans.build()
    for rel in ('art/buildings/town_center/town_center.xml', 'art/buildings/asian_civs/bansho/bansho.xml',
                'art/buildings/asian_civs/stable/stable.xml'):
        root = ET.fromstring(files[rel].decode('utf-8'))
        tech = root.find('component/logic/japanese/logic')
        branch = tech.find('zpkoreanvisuals/logic')
        assert [c.tag for c in tech][-1] == 'zpkoreanvisuals' and [c.tag for c in branch][-1] == 'colonialize'
    for lang in export_koreans.languages():
        assert 'data/strings/%s/stringmods.xml.xmb' % lang in files
    for rel in ('data/civmods.xml.xmb', 'data/techtreemods.xml.xmb', 'data/homecityzpkoreans.xml.xmb'):
        assert files[rel][:4] == b'alz4', rel
