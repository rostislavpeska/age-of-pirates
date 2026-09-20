"""The Harpooner replaces the Inuit Hunter (2026-09-20).

The Inuit Expansion (`zpNatInuitInfluence`) no longer adds a second unit beside the Hunter: it takes the Hunter's
button and its 12 slots, converts everything already on the map with `TransformUnit`, and flips two marker techs so
the three vanilla cards that ship Hunters ship Harpooners instead (the `ypConsulateRelationsJapanese` pattern -
`FreeHomeCityUnitIfTechObtainable`, one line per gate). The merc twin keeps its OWN pool, exactly as
`deNatMercInuitHunter` does, or the nine units the allies card ships would eat the trainable cap.
"""
from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]

HARP, MERC = "zpNatInuitHarpooner", "zpNatMercInuitHarpooner"
HUNT, MHUNT = "deNatInuitHunter", "deNatMercInuitHunter"
GATE_H, GATE_P = "zpInuitHunterShipments", "zpInuitHarpoonerShipments"
EXP = "zpNatInuitInfluence"


def _read(p):
    return (REPO / p).read_text(encoding="utf-8", errors="replace")


def _unit(name):
    s = _read("data/protomods.xml")
    return re.search(r'<unit id="(\d+)" name="%s">.*?</unit>' % name, s, re.S)


def _tech(name):
    s = _read("data/techtreemods.xml")
    m = re.search(r'<tech name ?= ?"%s"[^>]*>.*?</tech>' % name, s, re.S)
    assert m, name
    return m.group(0)


def _c(b, tag):
    m = re.search(r"<%s>([^<]*)</%s>" % (tag, tag), b)
    return m.group(1).strip() if m else None


class TestHarpoonerStats:
    def test_stronger_than_the_hunter_but_on_the_hunter_s_terms(self):
        b = _unit(HARP).group(0)
        assert _c(b, "initialhitpoints") == "250.0000" and _c(b, "maxhitpoints") == "250.0000"
        assert _c(b, "buildlimit") == "12" and _c(b, "trainpoints") == "35.0000"
        assert _c(b, "subciv") == "Inuit"
        ranged = [a for a in re.findall(r"<protoaction>.*?</protoaction>", b, re.S)
                  if re.search(r"<name>\w+RangedAttack</name>", a)]
        assert len(ranged) == 3
        for a in ranged:                                   # 24 dmg at rof 2.0 = 12.0 dps, against the Hunter's 8.67
            assert re.search(r"<damage>24\.000000</damage>", a)
            assert re.search(r"<rof>2\.000000</rof>", a)
            assert re.search(r"<maxrange>16\.000000</maxrange>", a)

    def test_bonus_targets_are_the_hunter_s(self):
        b = _unit(HARP).group(0)
        for gone in ("AbstractHeavyInfantry", "AbstractLightCavalry", "AbstractRangedShockInfantry",
                     "AbstractCavalry", "AbstractCoyoteMan"):
            assert 'damagebonus type="%s"' % gone not in b, gone      # incl. the old anti-cavalry penalty
        for kept, val in (("Mercenary", "2.500000"), ("AbstractOutlaw", "2.500000"),
                          ("AbstractNativeWarrior", "2.500000"), ("AbstractPet", "4.000000")):
            assert b.count('<damagebonus type="%s">%s</damagebonus>' % (kept, val)) == 7, kept

    def test_merc_twin_follows_the_merc_convention(self):
        """vanilla deNatMercInuitHunter / deNatMercClansman and the mod's zpNatMercIronside all differ from their
        parent by exactly: id, dbid, editornameid, no <subciv>, and a trailing <unittype>MercType1</unittype>."""
        s = _read("data/protomods.xml")
        a = re.search(r'<unit id="\d+" name="%s">.*?</unit>' % HARP, s, re.S).group(0)
        b = re.search(r'<unit id="\d+" name="%s">.*?</unit>' % MERC, s, re.S).group(0)
        assert b.count("<unittype>MercType1</unittype>") == 1 and "MercType1" not in a

        def norm(block, extra):
            skip = ("<dbid>", "<editornameid>", "<unit id=") + extra
            return [l for l in block.split(chr(10)) if not any(s in l for s in skip)]

        assert norm(a, ("<subciv>",)) == norm(b, ("MercType1",))

    def test_merc_twin_has_its_own_pool(self):
        m = _unit(MERC)
        assert m and m.group(1) == "21192"
        b = m.group(0)
        assert _c(b, "dbid") == "21192" and _c(b, "buildlimit") == "12"
        assert "<subciv>" not in b                                     # merc natives carry no subciv
        assert "sharedbuildlimit" not in b.lower()                     # a shared pool would let shipments eat the cap
        assert _c(b, "editornameid") == "503551" and _c(b, "displaynameid") == "500567"
        assert (REPO / "sound/zpnatmercinuitharpooner_snds.xml").exists()
        s = (REPO / "sound/zpnatmercinuitharpooner_snds.xml").read_bytes()
        assert s.count(b"\r\n") == s.count(b"\n") > 0 and MERC.encode() in s

    def test_the_harpooner_took_the_hunter_s_trading_post_cell(self):
        s = _read("data/protomods.xml")
        assert '<train row="0" page="0" column="1">%s</train>' % HARP in s
        assert '<train row="0" page="0" column="3">%s</train>' % HARP not in s   # no longer shares the Husky's cell
        assert 'page="0" column="1"' in _tech("zpIncaTamboShadowHarpooner")      # the Tambo relocation follows


class TestReplacement:
    def test_expansion_swaps_button_and_converts_what_is_on_the_map(self):
        b = _tech(EXP)
        assert '<effect type="CommandRemove" proto="%s">' % HUNT in b
        assert '<effect type="CommandAdd" proto="%s" page="0" column="1">' % HARP in b
        assert '<effect type="TransformUnit" toprotoid="%s" fromprotoid="%s">' % (HARP, HUNT) in b
        assert '<effect type="TransformUnit" toprotoid="%s" fromprotoid="%s">' % (MERC, MHUNT) in b
        assert '<effect type="TechStatus" status="unobtainable">%s</effect>' % GATE_H in b
        assert '<effect type="TechStatus" status="obtainable">%s</effect>' % GATE_P in b
        assert b.count("<effect ") == 10

    def test_markers_are_empty_shadow_records(self):
        s = _read("data/techtreemods.xml")
        for name, dbid in ((GATE_H, "41551"), (GATE_P, "41552")):
            b = _tech(name)
            assert _c(b, "dbid") == dbid and "<status>UNOBTAINABLE</status>" in b and "<flag>Shadow</flag>" in b
            assert "<effects>" not in b and "<prereqs>" not in b     # the deCardIgnoreBuildLimit shape
            assert s.index('name="%s"' % name) < s.index("<!--TEST TECHS-->")
        hub = _tech("DENativeInuit")
        assert '<effect mergemode="add" type="TechStatus" status="obtainable">%s</effect>' % GATE_H in hub
        assert GATE_P not in hub                                     # only the expansion turns the Harpooner on
        assert re.search(r'subtype="Enable"[^>]*>\s*<target type="ProtoUnit">%s<' % MERC, hub)

    def test_every_card_that_shipped_hunters_now_branches(self):
        for tech, amount, old, new in (("DENativeTreatyInuit", "5.00", HUNT, HARP),
                                       ("DEIndianFriendshipInuit", "10.00", HUNT, HARP),
                                       ("DEHCIniuitAllies1", "9.00", MHUNT, MERC)):
            b = _tech(tech)
            assert 'tech="%s" type="Data" amount="%s" subtype="FreeHomeCityUnitIfTechObtainable" unittype="%s"' % (GATE_H, amount, old) in b, tech
            assert 'tech="%s" type="Data" amount="%s" subtype="FreeHomeCityUnitIfTechObtainable" unittype="%s"' % (GATE_P, amount, new) in b, tech
            assert 'subtype="FreeHomeCityUnit"' not in b, tech       # the unconditional vanilla line must be gone
            assert "mergemode" not in b, tech                        # full override, or both units would ship
        assert '<effect type="TechStatus" status="active">DEWarriorSocietyInuit</effect>' in _tech("DEIndianFriendshipInuit")
        assert "<effect type=\"TextOutputTechName\">110130</effect>" in _tech("DEHCIniuitAllies1")

    def test_both_harpooners_walk_the_hunter_s_upgrade_ladder(self):
        """The Harpooner replaced the Hunter, so it inherits the Hunter's PAID ladder: x1.25 + Elite at
        DEWarriorSocietyInuit, x1.35 + Champion at DEChampionInuit, legendary rename at the shadow. The free
        x1.20 from DEVeteranNativesShadow must be gone, or the pair carries 1.20 x 1.25 where the Hunter has 1.25."""
        vet, champ = _tech("DEWarriorSocietyInuit"), _tech("DEChampionInuit")
        for unit in (HARP, MERC):
            for blk, amount, name in ((vet, "1.25", "500582"), (champ, "1.35", "500583")):
                assert re.search(r'amount="%s" subtype="Hitpoints"[^>]*>\s*<target type="ProtoUnit">%s<' % (amount, unit), blk), (unit, amount)
                assert re.search(r'amount="%s" subtype="Damage" allactions="1"[^>]*>\s*<target type="ProtoUnit">%s<' % (amount, unit), blk), (unit, amount)
                assert '<effect mergemode="add" type="SetName" proto="%s" culture="none" newname="%s">' % (unit, name) in blk
                assert '<effect mergemode="add" type="SetName" proto="%s" culture="none" newname="500584" reqtech="ImpLegendaryNativesShadow">' % unit in blk
            assert '<effect mergemode="add" type="SetName" proto="%s" culture="none" newname="500584">' % unit in _tech("ImpLegendaryNativesShadow")
        free = _tech("DEVeteranNativesShadow")
        assert HARP not in free and MERC not in free
        assert "mergeMode" not in vet and "mergeMode" not in champ

    def test_rollover_tells_the_new_story(self):
        st = _read("data/strings/english/stringmods.xml")
        assert '<string _locid="503551">ZP NAT Merc Inuit Harpooner</string>' in st
        roll = re.search(r'<string _locid="500590">([^<]*)</string>', st).group(1)
        assert "replace" in roll and "12" in roll and "train up to 7" not in roll
