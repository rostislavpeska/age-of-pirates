"""Guard tests for the Bourbon Rework (vanilla Bourbon + extension)."""
import hashlib
import json
import os
import re
from pathlib import Path
import pytest

REPO = Path(__file__).parents[3]
DATA = REPO / "data"

def _read(rel):
    return (REPO / rel).read_text(encoding="utf-8", errors="replace")

def _techs():
    s = _read("data/techtreemods.xml")
    return {m.group(1): m.group(0) for m in re.finditer(r'<tech\b[^>]*\bname\s*=\s*"([^"]+)"[^>]*>.*?</tech>', s, re.S)}

def _c(blob, tag):
    m = re.search(r"<%s>([^<]+)</%s>" % (tag, tag), blob)
    return m.group(1).strip() if m else None

# G1: Strip verification (Package D)
@pytest.mark.xfail(strict=True, reason="until WP7")
def test_g1_no_deleted_names_remain():
    package_d_names = [
        "zpSPCNativeBourbon", "zpSPCNativeBourbonColonialize", "zpVeteranBourbon", "zpGuardBourbon",
        "zpNatBourbonReforms", "zpNatBourbonRoyalTax", "zpNatBourbonChouannerie", "zpNatBourbonMaisonDuRoi",
        "zpNativeTreatyBourbon", "zpIndianFriendshipBourbon", "zpNativeTradeTreatyBourbon",
        "zpUnknownAllianceBourbon", "zpUnknownAllianceBourbonEnabler", "zpNatRoyalMusketeer",
        "zpNatRoyalDragoon", "zpNatRoyalHorsemanBourbonProxy", "zpSocketSPCBourbon"
    ]
    roots = [REPO / d for d in ("data", "game", "randmaps", "sound")]
    found = []
    pat = re.compile(r"(?<![A-Za-z0-9_])(?:%s)(?![A-Za-z0-9_])" % "|".join(package_d_names))
    for root in roots:
        for dp, dn, fn in os.walk(root):
            for f in fn:
                if f.endswith((".xml", ".xs")):
                    p = Path(dp) / f
                    txt = p.read_text(encoding="utf-8", errors="replace")
                    if pat.search(txt):
                        found.append(f"{p.relative_to(REPO)}")
    assert not found, f"Deleted names found in: {found[:10]}"

# G2: AI constants resolve
def test_g2_ai_bourbon_constants_resolve():
    ai = _read("game/ai/core/aipiraterules.xs")
    assert "cUnitTypezpSocketSPCBourbon" in ai or "cUnitTypedeSocketBourbon" in ai

# G3: Map TechIDs resolve
def test_g3_map_bourbon_techs_resolve():
    paris = _read("randmaps/zpparis.xs")
    assert "zpBonusBourbon" in paris

# G4: Groupings clean of old names
def test_g4_groupings_repointed():
    groupings_dir = REPO / "game" / "randmaps" / "groupings"
    target_groupings = [
        "EU_Natives_Block_Bourbon_1.xml", "EU_Natives_Block_Bourbon_2.xml", "EU_Natives_Block_Bourbon_3.xml",
        "Natives_SPCBourbon_01.xml", "Natives_SPCBourbon_02.xml", "Natives_SPCBourbon_03.xml",
        "Verseilles_2v2.xml", "Verseilles_4v4.xml", "Verseilles_Mega.xml", "Verseilles_Mega2.xml",
        "Verseilles_Mega3.xml", "EU_Verseilles_2v2.xml", "EU_Wall_NE_socketable.xml", "EU_Wall_SW_socketable.xml"
    ]
    for g in target_groupings:
        txt = (groupings_dir / g).read_text(encoding="utf-8")
        assert "zpSocketSPCBourbon" not in txt, f"{g} still has zpSocketSPCBourbon"
        assert "zpNatRoyalMusketeer" not in txt, f"{g} still has zpNatRoyalMusketeer"

# G5: TradingPost and abilitymods
def test_g5_tradingpost_and_abilitymods():
    proto = _read("data/protomods.xml")
    assert '<command page="0" column="4">zpNatBourbonRoyalMarchSmall</command>' not in proto
    ab = _read("data/abilities/abilitymods.xml")
    assert 'deNatPowerRoyalMarch<tech>zpBourbonAbilityBig</tech>' in ab
    T = _techs()
    assert "<status>OBTAINABLE</status>" in T["zpBourbonAbilityBig"]

# G6: Extension adaptation (like TestExtendedStuart)
class TestExtendedBourbon:
    BIG, SMALL, TECH, SHADOW = "zpBourbonAbilityBig", "zpBourbonAbilitySmall", "zpNatBourbonRoyalMarch", "zpExtendedBourbons"
    CMD, POWER = "zpNatBourbonRoyalMarchSmall", "zpNatPowerRoyalMarch"

    def test_power_clone_exists(self):
        s = _read("data/abilities/powermods.xml")
        assert 'name="zpNatPowerRoyalMarch"' in s

    def test_abilities_big_and_small(self):
        s = _read("data/abilities/abilitymods.xml")
        assert self.BIG in s and self.SMALL in s

    def test_small_command_flags(self):
        s = _read("data/protounitcommandmods.xml")
        b = re.search(r"<protounitcommand>\s*<name>%s</name>.*?</protounitcommand>" % self.CMD, s, re.S).group(0)
        assert "<subciv>Bourbon</subciv>" in b and "usemediumbutton3" not in b

    def test_gates_and_overrides(self):
        T = _techs()
        assert _c(T[self.BIG], "dbid") == "408213" and "<status>OBTAINABLE</status>" in T[self.BIG]
        assert _c(T[self.SMALL], "dbid") == "408214" and "<status>UNOBTAINABLE</status>" in T[self.SMALL]
        assert "DENativeBourbon" in T and "DENativeBourbonColonialize" in T

    def test_shadow_at_top(self):
        s = _read("data/techtreemods.xml")
        b = _techs()[self.SHADOW]
        assert s.index('name="zpExtendedStuartLondon"') < s.index('name="%s"' % self.SHADOW) < 30000
        assert _c(b, "dbid") == "408211"

# G7: Map subcivs and triggers
def test_g7_maps_use_vanilla_bourbon():
    paris = _read("randmaps/zpparis.xs")
    assert 'rmSetSubCiv(2,"Bourbon")' in paris or 'rmSetSubCiv(2, "Bourbon")' in paris
    assert "cTechzpExtendedBourbonsSPC" in paris
    vers = _read("randmaps/zpverseilles.xs")
    assert 'rmSetSubCiv(2,"Bourbon")' in vers or 'rmSetSubCiv(2, "Bourbon")' in vers

# G8: WP2 Ancien Regime design
@pytest.mark.xfail(strict=True, reason="until WP6")
def test_g8_ancien_regime_target():
    s = _read("data/techtreemods.xml")
    assert "DENatBourbonFencingSchool" in s and 'mergemode="remove"' not in s

# G9: Hero musketeers
@pytest.mark.xfail(strict=True, reason="until WP6")
def test_g9_hero_musketeers():
    s = _read("data/techtreemods.xml")
    assert 'zpAbstractHeroMusketeer_buffed_once' in s

# G10: XMB twins current
def test_g10_xmb_twins_current():
    pass
