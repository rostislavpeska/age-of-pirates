"""Upgrade buttons stay visible: no mod button tech is chained to a shadow tech that an age-up fires.

A building shows a tech button only once the tech's prereqs other than its age are met. Chained to such a shadow the
button hides until the age-up (Koreans add-on 2026-10-10: the Honored Jangchang required its free Disciplined shadow
and was missing from the Barracks until Fortress; owner: "These techs should be visible permanently", "That's off
pattern!!!! Check other civs. tests should cover that"). Vanilla: every unit whose Disciplined is a free shadow has an
Honored that needs only Industrialize (YPHonoredArquebusier, -Changdao, -IronFlail, -MeteorHammer, -Howdah, -Mahout,
-Yabusame). Vanilla chains 73 buttons to an age-gated shadow: 72 of those shadows carry a DEDisplayAsAge<N>Prereq
flag, an age proxy the UI shows as the age (DEItalianAge1PreReq, DETradeRouteUpgrade1Enable ...); the one other is
DEImperialBersaglieri (hidden until its free Guard shadow).

    python -m pytest scripts/tools/tests/test_upgrade_buttons.py -q
"""
import re
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
AGES = {'Colonialize', 'Fortressize', 'Industrialize', 'Imperialize'}
VANILLA_TECHS = {t.get('name'): t for t in ET.parse(REPO / 'scripts/source/techtreey.xml').getroot().findall('tech')}
MOD_TECHS = {t.get('name'): t for t in ET.parse(REPO / 'data/techtreemods.xml').getroot().findall('tech')}


def _slots():
    """tech -> {(building, page, column)}: vanilla and mod building <tech> lists plus every CommandAdd tech=."""
    slots = {}
    for f in (REPO / 'scripts/source/protoy.xml', REPO / 'data/protomods.xml'):
        for u in ET.parse(f).getroot().iter('unit'):
            for t in u.findall('tech'):
                slots.setdefault(t.text, set()).add((u.get('name'), t.get('page'), t.get('column')))
    for t in list(VANILLA_TECHS.values()) + list(MOD_TECHS.values()):
        for e in t.iter('effect'):
            if e.get('type') == 'CommandAdd' and e.get('tech'):
                slots.setdefault(e.get('tech'), set()).add((e.findtext('target'), e.get('page'), e.get('column')))
    return slots


def test_vanilla_free_disciplined_units_have_an_age_only_honored():
    low = {n.lower(): n for n in VANILLA_TECHS}
    pattern = []
    for n in VANILLA_TECHS:
        m = re.fullmatch(r'ypDisciplined(\w+)Shadow', n, re.I)
        honored = low.get(('ypHonored' + m.group(1)).lower()) if m else None
        if honored:
            assert [p.text for p in VANILLA_TECHS[honored].iter('techstatus')] == ['Industrialize'], honored
            pattern.append(honored)
    assert len(pattern) >= 7


def _hidden_buttons(scope, techs, slots):
    """(button tech, shadow) pairs: a button tech chained to an age-gated shadow that is no DEDisplayAsAge proxy."""
    bad = []
    for name, t in scope.items():
        if name not in slots:
            continue
        for p in t.iter('techstatus'):
            if p.text in AGES or slots.get(p.text, set()) & slots[name]:
                continue
            gate = techs.get(p.text)
            if gate is None or 'Shadow' not in [f.text for f in gate.findall('flag')]:
                continue
            if not AGES & {q.text for q in gate.iter('techstatus')}:
                continue                                       # not fired by an age-up
            if any((f.text or '').startswith('DEDisplayAsAge') for f in gate.findall('flag')):
                continue                                       # vanilla age proxy, shown as the age
            bad.append((name, p.text))
    return bad


def test_vanilla_hides_one_button_behind_a_shadow():
    """The evidence: vanilla's only such button is the Italian Imperial Bersaglieri."""
    assert _hidden_buttons(VANILLA_TECHS, VANILLA_TECHS, _slots()) == [('DEImperialBersaglieri', 'DEGuardBersaglieriShadow')]


def test_no_mod_button_is_chained_to_an_age_gated_shadow():
    assert _hidden_buttons(MOD_TECHS, dict(VANILLA_TECHS, **MOD_TECHS), _slots()) == []
