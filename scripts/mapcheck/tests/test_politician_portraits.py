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
        for tech in re.findall(r'status="obtainable">(zpConsulate\w+)<', m.group(2)):   # the mod's politicians (native-politician
            out.setdefault(tech, []).append(m.group(1))                                  # skill); zpBigConsulate* = the Asian clones
    return out


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
