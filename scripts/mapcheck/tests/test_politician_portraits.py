"""Every politician a consulate set offers has its portrait entry (owner 2026-09-25: 'Beauregard not appearing ... that's
heavy regression'). data/politicianmods.xml registers a politician by an element named after its tech, lowercased; without
it the Choose-a-Foreign-Ally dialog silently leaves the card out. Commit 920c5d51 (2025-10-12, 'Added Cossack Politician
(unfinished)') pasted the three Cossack entries over Captain Beauregard's, so the Baltic pirate set (Iceland, Elbe) showed
two captains for a year."""
from __future__ import annotations

import re
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]


def _text(p: Path) -> str:
    return p.read_bytes().decode("utf-8").replace(chr(13), "")


def _offered() -> dict:
    """politician tech (zpConsulate*) -> the zpTurnConsulate* sets that make it obtainable"""
    t = _text(REPO / "data/techtreemods.xml")
    out = {}
    for m in re.finditer(r'<tech name="(zpTurnConsulate\w+)"[^>]*>(.*?)</tech>', t, re.S):
        for tech in re.findall(r'status="obtainable">(zpConsulate\w+)<', m.group(2)):
            out.setdefault(tech, []).append(m.group(1))
    return out


def _big_offered() -> dict:
    """Asian flag card (zpBigConsulate*) -> the turn-on sets that make it obtainable.

    These are not zpConsulate* politicians. The Choose an Ally dialog still omits a card
    with no politicianmods element (Korea 2026-10-13: USA missing, vanilla SPC China shown).
    """
    t = _text(REPO / "data/techtreemods.xml")
    out = {}
    for m in re.finditer(r'<tech name="(zpTurnConsulateOn\w+)"[^>]*>(.*?)</tech>', t, re.S):
        for tech in re.findall(r'status="obtainable">(zpBigConsulate\w+)<', m.group(2)):
            out.setdefault(tech, []).append(m.group(1))
    return out


def _tech_body(name: str) -> str:
    t = _text(REPO / "data/techtreemods.xml")
    m = re.search(r'<tech name="%s" type="Normal">(.*?)</tech>' % name, t, re.S)
    assert m, name
    return m.group(1)


def _portraits() -> dict:
    p = _text(REPO / "data/politicianmods.xml")
    return {m.group(1).lower(): m.group(2) for m in re.finditer(r'<(\w+) portraitfilename="[^"]*" portraitfilenamewpf="([^"]+)">', p)}


OFFERED = _offered()


def test_the_sets_offer_politicians():
    assert len(OFFERED) > 50 and "zpConsulatePiratesBeauregard" in OFFERED


@pytest.mark.parametrize("tech", sorted(OFFERED), ids=str)
def test_offered_politician_has_a_portrait(tech):
    portraits = _portraits()
    assert tech.lower() in portraits, "%s is offered by %s but has no politicianmods entry" % (tech, OFFERED[tech][:3])
    png = REPO / "data/wpfg" / portraits[tech.lower()]
    assert png.is_file(), "%s: %s missing" % (tech, png)


def test_beauregard_is_back():
    assert _portraits()["zpconsulatepiratesbeauregard"] == "resources/images/icons/politicians/beauregard.png"


def test_politicianmods_xmb_current(xmb_current):
    xmb_current("data/politicianmods.xml")


BIG = _big_offered()


@pytest.mark.parametrize("tech", sorted(BIG), ids=str)
def test_asian_clone_has_a_portrait(tech):
    portraits = _portraits()
    assert tech.lower() in portraits, "%s is offered by %s but has no politicianmods entry" % (tech, BIG[tech][:3])


def test_korean_china_is_the_dance_clone():
    allies = _tech_body("zpKoreanConsulateAllies")
    pirate = _tech_body("zpIsPirateMap")
    turn_on = _tech_body("zpTurnConsulateOnKorean")
    clone = _tech_body("zpBigConsulateSPCChinaClone")
    assert 'obtainable">ypBigConsulateSPCChina<' not in allies
    assert 'obtainable">zpBigConsulateSPCChina<' in allies
    assert 'unobtainable">ypBigConsulateSPCChina<' in pirate
    assert 'unobtainable">zpBigConsulateSPCChina<' in pirate
    assert 'obtainable">zpBigConsulateSPCChinaClone<' in pirate
    assert 'unobtainable">zpBigConsulateAmericans<' in pirate
    assert 'obtainable">zpBigConsulateSPCChinaClone<' in turn_on
    assert 'unobtainable">ypBigConsulateSPCChina<' in turn_on
    assert "<flag>NativeDance</flag>" in clone
    assert "zpPickConsulateTechAvailable" in clone


def test_korean_china_is_not_the_campaign_mercenaries():
    for name in ("zpBigConsulateSPCChina", "zpBigConsulateSPCChinaClone"):
        body = _tech_body(name)
        assert "<displaynameid>68623</displaynameid>" not in body
        assert "<rollovertextid>68622</rollovertextid>" not in body
        assert "ypConsulateArmySPCChinese" not in body
        assert "ypConsulateRelationsSPCChina" not in body
        assert "YPUseBigButton2" not in body
        assert "zpConsulateArmyChinese1" in body
        assert "zpConsulateChineseRicePaddy" in body
        assert "zpConsulateChineseBattery" in body
    sequester = _tech_body("zpBigSequesterSPCChinaClone")
    assert "Clone2" not in sequester
    assert "<flag>YPSequesterTech</flag>" in sequester
    assert "YPInfiniteTech" in _tech_body("zpTurnConsulateOnKorean")


def test_consulate_ally_second_accept_researches():
    """The ally button researches again, and rearms its end-relations tech.

    The sequestertech element re-enables the undo tech and skips the ally
    effects, so the consulate big button stays. A used end-relations tech
    also ignores a plain obtainable, so every accept clears it and arms it
    again.
    """
    tree = _text(REPO / "data/techtreemods.xml")
    for name in (
        "zpBigConsulateRussiansClone",
        "zpBigConsulateJapaneseClone",
        "zpBigConsulateAmericansClone",
        "zpBigConsulateSPCChina",
        "zpBigConsulateSPCChinaClone",
    ):
        body = _tech_body(name)
        assert "<sequestertech>" not in body
        assert "<flag>YPSequesterTech</flag>" not in body
        sequester = {
            "zpBigConsulateRussiansClone": "zpBigSequesterRussiansClone",
            "zpBigConsulateJapaneseClone": "zpBigSequesterJapaneseClone",
            "zpBigConsulateAmericansClone": "zpBigSequesterAmericansClone",
            "zpBigConsulateSPCChina": "zpBigSequesterSPCChina",
            "zpBigConsulateSPCChinaClone": "zpBigSequesterSPCChinaClone",
        }[name]
        assert body.index('unobtainable">%s<' % sequester) < body.index('obtainable">%s<' % sequester)
        assert "<researchlimit>99</researchlimit>" in _tech_body(sequester)
    for name in (
        "zpBigConsulateRussiansClone",
        "zpBigConsulateJapaneseClone",
        "zpBigConsulateAmericansClone",
        "zpBigConsulateSPCChinaClone",
    ):
        assert 'unobtainable">zpPickConsulateTechAvailable<' in _tech_body(name)
    for copy in (
        "zpBigConsulateSPCChinaClone2",
        "zpBigConsulateAmericansClone2",
        "zpBigConsulateSPCChinaClone3",
        "zpBigConsulateAmericansClone3",
    ):
        assert copy not in tree
    assert "<flag>YPSequesterTech</flag>" in _tech_body("zpBigSequesterRussiansClone")
