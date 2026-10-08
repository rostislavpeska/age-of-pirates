"""The playable Koreans civ (zpKoreans): the links that make it load, play as Japan and look Korean.

Repo-only checks run everywhere; the vanilla-byte check of the merged animfiles needs the Steam install.
"""
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
BS = chr(92)


def xml(path):
    return ET.fromstring((REPO / path).read_bytes().decode('utf-8-sig'))


def korean_civ():
    civs = [c for c in xml('data/civmods.xml').findall('civ') if c.findtext('name') == 'zpKoreans']
    assert len(civs) == 1
    return civs[0]


def test_civ_is_playable_and_starts_with_the_korean_age0_tech():
    civ = korean_civ()
    assert civ.findtext('main') == '1' and civ.find('visible') is None  # main civ, lobby and editor
    ages = {a.findtext('age'): a.findtext('tech') for a in civ.findall('agetech')}
    assert ages['Age0'] == 'zpAge0Korean'
    assert ages['Age1'] == 'YPColonializeJapanese' and ages['Age4'] == 'YPImperializeJapanese'
    assert civ.findtext('culture') == 'Japanese'


def test_age0_tech_activates_japan_and_the_marker_at_the_top_of_the_file():
    techs = xml('data/techtreemods.xml').findall('tech')
    names = [t.get('name') for t in techs]
    # techs near the bottom of techtreemods silently do not apply (see zpNeutralCathedralSelectableP1)
    assert names.index('zpKoreanVisuals') < 5 and names.index('zpAge0Korean') < 5
    age0 = techs[names.index('zpAge0Korean')]
    active = [e.text for e in age0.iter('effect') if e.get('type') == 'TechStatus' and e.get('status') == 'active']
    assert active == ['YPAge0Japanese', 'zpKoreanVisuals']


def test_flags_strings_home_city_and_personality_exist():
    civ = korean_civ()
    assert (REPO / 'art' / 'objects' / 'flags' / 'zpkoreans.ddt').stat().st_size == 174856  # vanilla flag profile
    for field in ('homecityflagiconwpf', 'homecityflagbuttonwpf', 'postgameflagiconwpf'):
        rel = civ.findtext(field).replace(BS, '/')
        assert (REPO / 'data' / 'wpfg' / rel).is_file(), rel
    for name in ('flag_hc_legacy_zpkoreans.png', 'flag_thin_right_zpkoreans.png', 'Techtree_zpKoreans.png'):
        assert (REPO / 'data/wpfg/resources/images/icons/flags' / name).is_file(), name
    strings = (REPO / 'data/strings/english/stringmods.xml').read_text(encoding='utf-8')
    for sid in ('600000', '600001', '600002', '600003', '600004', '600005'):
        assert '_locid="%s"' % sid in strings
    hc = xml('data/' + civ.findtext('homecityfilename'))
    assert hc.findtext('civ') == 'zpKoreans' and hc.findtext('name') == '$$600002$$'
    assert (REPO / ('data/' + civ.findtext('homecityfilename') + '.xmb')).is_file()
    pers = xml('game/ai/personalities/zpmyeongseong.personality')
    assert pers.findtext('forcedciv') == 'zpKoreans' and pers.findtext('nameID') == '600004'
    assert 'zpMyeongseong' in [p.text for p in xml('game/ai/personalities.xml').findall('Personality')]


@pytest.mark.parametrize('path', ['art/buildings/town_center/town_center.xml',
                                  'art/buildings/asian_civs/bansho/bansho.xml',
                                  'art/buildings/asian_civs/stable/stable.xml'])
def test_korean_branch_is_the_last_japanese_tech_child(path):
    root = xml(path)
    tech = root.find('component/logic/japanese/logic')
    assert tech.get('type') == 'Tech'
    assert [c.tag for c in tech][-1] == 'zpkoreanvisuals'
    names = {(s.text or '').strip().lower() for s in root.iter('submodel')}
    refs = {r.get('ref').lower() for r in tech.find('zpkoreanvisuals').iter('submodelref')}
    assert refs and refs <= names


@pytest.mark.local('steam')
def test_merged_animfiles_keep_every_vanilla_byte():
    r = subprocess.run([sys.executable, str(REPO / 'scripts/tools/korean_visuals.py'), '--check'],
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr
