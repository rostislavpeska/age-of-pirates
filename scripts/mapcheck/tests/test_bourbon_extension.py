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

# G1: Strip verification (Package D, WP7 D1-D3 applied, owner 2026-10-26 "yes"). Any case and the cTech / cUnitType
# forms count (owner 2026-10-26: "NO Zombie Bourbons!!!!!" - a case-sensitive match had missed "SPCbourbon" in
# performance_test.xs and <zpnatroyalmusketeer> in abilitymods.xml); comments may keep the history.
def test_g1_no_deleted_names_remain():
    package_d_names = [
        "zpSPCNativeBourbon", "zpSPCNativeBourbonColonialize", "zpVeteranBourbon", "zpGuardBourbon",
        "zpNatBourbonReforms", "zpNatBourbonRoyalTax", "zpNatBourbonChouannerie", "zpNatBourbonMaisonDuRoi",
        "zpNativeTreatyBourbon", "zpIndianFriendshipBourbon", "zpNativeTradeTreatyBourbon",
        "zpUnknownAllianceBourbon", "zpUnknownAllianceBourbonEnabler", "zpNatRoyalMusketeer",
        "zpNatRoyalDragoon", "zpNatRoyalHorsemanBourbonProxy", "zpSocketSPCBourbon", "SPCBourbon"
    ]
    roots = [REPO / d for d in ("data", "game", "randmaps", "sound")]
    found = []
    pat = re.compile(r"(?<![A-Za-z0-9_])(?:cTech|cUnitType)?(?:%s)(?![A-Za-z0-9_])" % "|".join(package_d_names), re.I)
    for root in roots:
        for dp, dn, fn in os.walk(root):
            for f in fn:
                if f.endswith((".xml", ".xs")):
                    p = Path(dp) / f
                    txt = p.read_text(encoding="utf-8", errors="replace")
                    txt = re.sub(r"<!--.*?-->", "", txt, flags=re.S) if f.endswith(".xml") else re.sub(r"//[^\n]*", "", txt)
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

# G8: Ancien Regime runs vanilla (WP6, owner 2026-10-26: "C1-C3 - strip", "Paris embassy - keep")
VANILLA_BOURBON_TECHS = ("DEVeteranBourbon", "DEGuardBourbon", "DENatBourbonReforms", "DENatBourbonRoyalTax",
                         "DENatBourbonFencingSchool")

def test_g8_ancien_regime_is_vanilla():
    s = _read("data/techtreemods.xml")
    T = _techs()
    assert "DEHCAncienRegime" not in T and "zpAncienRegimeAddTechsToEmbassy" not in s
    for t in VANILLA_BOURBON_TECHS:        # the Normalizer once switched the Trading Post techs off
        assert 'status="unobtainable">%s<' % t not in s, t
    n = T["zpAncienRegimeNormalizer"]       # what is left: the Paris reward embassy content only
    assert re.findall(r'<techstatus status="Active">(\w+)</techstatus>', n) == ["zpBonusBourbon", "DEHCAncienRegime"]
    effects = re.findall(r'<effect type="CommandAdd" (proto|tech)="(\w+)" page="(\d)" column="(\d)">\s*'
                         r'<target type="ProtoUnit">(\w+)</target>', n)
    assert n.count("<effect ") == len(effects) == 6
    assert {e[4] for e in effects} == {"zpNativeEmbassyParisReward"}
    assert [e[1] for e in effects] == ["deNatMercRoyalMusketeer", "deNatMercRoyalDragoon", "DEVeteranBourbon",
                                       "DEGuardBourbon", "DENatBourbonReforms", "DENatBourbonRoyalTax"]

# G9: hero musketeers buffed once, through shadows, vanilla tooltips untouched (owner 2026-10-26)
def test_g9_hero_musketeers():
    T = _techs()
    for vanilla in ("DEVeteranBourbon", "DEGuardBourbon"):   # WP7 D1: the zp copies are gone, the Napoleonic Era uses vanilla
        assert vanilla not in T, "%s override would change the vanilla tooltip" % vanilla
        assert '<effect type="TechStatus" status="active">%s</effect>' % vanilla in T["zpNapoleonicEraIcons"]
        assert '<techstatus status="Active">%s</techstatus>' % vanilla in T["zpNapoleonicEraNames"]
    for name, dbid, vanilla, amount in (("zpBourbonHeroVeteranShadow", "408215", "DEVeteranBourbon", "1.20"),
                                        ("zpBourbonHeroGuardShadow", "408216", "DEGuardBourbon", "1.40")):
        b = T[name]
        assert _c(b, "dbid") == dbid and "<status>OBTAINABLE</status>" in b and "<flag>Shadow</flag>" in b
        assert re.findall(r'<techstatus status="Active">(\w+)</techstatus>', b) == [vanilla]
        assert re.findall(r'amount="([\d.]+)" subtype="(\w+)"[^>]*>\s*<target type="ProtoUnit">zpAbstractHeroMusketeer<', b) \
            == [(amount, "Hitpoints"), (amount, "Damage")]
    assert sum(t.count("zpAbstractHeroMusketeer") for n, t in T.items() if "Bourbon" in n) == 4

# G11: the Napoleonic Era treats the vanilla royal units like the mercenaries (owner 2026-10-26: the vanilla Bourbon
# units "stayed unaffected - no ability change, nothing even no name change"; D2 had dropped the clones' lines)
def test_g11_napoleonic_era_covers_vanilla_royals():
    T = _techs()
    for n in ("zpRevolutionFranceNE", "zpNapoleonicEraNames", "zpNapoleonicEraNamesLegendary"):
        eff = [" ".join(e.split()) for e in re.findall(r'<effect\s[^>]*?(?:/>|>.*?</effect>)', T[n], re.S)]
        merc = [e.replace("deNatMercRoyal", "deNatRoyal") for e in eff if "deNatMercRoyal" in e]
        native = [e for e in eff if re.search(r'deNatRoyal(?:Musketeer|Dragoon)\b', e)]
        assert merc and merc == native, n
    for unit, icon in (("deNatRoyalMusketeer", "deIconNatFootCarabinier"), ("deNatRoyalDragoon", "deIconNatHorseCarabinier")):
        assert re.search(r'unittype="%s"[^>]*>\s*<target type="ProtoUnit">%s<' % (unit, icon), T["zpNapoleonicEraIcons"]), unit
    # the mortar button (owner 2026-10-26: "vanilla royal musketeers don't have the rocket ability after the napoleonic
    # paris upgrade"): vanilla binds it to DERevolutionFranceNE on the mercenary only, the mod's tech is zpRevolutionFranceNE
    A = _read("data/abilities/abilitymods.xml")
    for unit in ("denatmercroyalmusketeer", "denatroyalmusketeer"):
        assert re.search(r'<%s>\s*<ability mergemode="add">zpPassiveAbilityMortar<tech>zpRevolutionFranceNE</tech>'
                         r'<bindtochargeaction>true</bindtochargeaction>' % unit, A), unit

# G12: the embassy wagon looks European whenever a tech gives it the European name (owner 2026-10-26: "create a special
# embassy travois xml and redirect the anim file"; "all these except the one on the Aztec city map should change the design")
VANILLA_EURO_NAME_TECHS = ("deEUMapUpdateVisuals", "DEEnableSPCCityStateTechs", "DEHCAncienRegime", "DEHCPrinceElectors",
                           "DEHCREVPrinceElectors", "DEHCRoyalUnion", "DEHCOldenburgKings")

def test_g12_embassy_wagon_follows_european_name():
    assert re.search(r'<unit name="deEmbassyTravois">\s*<animfile>units\\trade\\zpembassy_travois\\zpembassy_travois\.xml'
                     r'</animfile>\s*</unit>', _read("data/protomods.xml"))
    raw = (REPO / "art/units/trade/zpembassy_travois/zpembassy_travois.xml").read_bytes()
    assert raw.count(b"\r\n") == raw.count(b"\n")
    a = raw.decode("utf-8")
    none, keys = a[a.index('<component>native_travois<logic type="Tech">'):].split("</none>", 1)
    euro = re.findall(r'<(\w+)>\s*<submodelref ref="euro_wagon" />\s*</\1>', keys.split("<watersplash>")[0])
    mod = [n for n, t in _techs().items() if 'proto="deEmbassyTravois" culture="none" newname="80597"' in t]
    assert sorted(euro) == sorted(t.lower() for t in VANILLA_EURO_NAME_TECHS + tuple(mod))
    assert re.findall(r'<(\w+)>\s*<submodelref ref="(\w+)" />\s*</\1>', none) == [   # the vanilla Culture logic
        ("aztec", "az_travois"), ("iroquois", "iro_travois"), ("sioux", "sio_travois"), ("inca", "inc_travois"),
        ("westerneurope", "euro_wagon"), ("easterneurope", "euro_wagon"), ("africaeast", "african_travois"),
        ("africawest", "african_travois")]

# G10: the game loads the compiled .xmb, not the .xml: every data file the rework edits has a twin with the same content
# (owner 2026-10-26: "do it"; the test used to be an empty stub)
def test_g10_xmb_twins_current(xmb_current):
    for rel in ("data/protomods.xml", "data/techtreemods.xml", "data/civmods.xml", "data/nuggetmods.xml",
                "data/protounitcommandmods.xml", "data/abilities/abilitymods.xml"):
        xmb_current(rel)
