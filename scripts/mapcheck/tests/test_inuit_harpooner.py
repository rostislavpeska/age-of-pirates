"""The Harpooner replaces the Inuit Hunter (2026-09-20).

The Inuit Expansion (`zpNatInuitInfluence`) takes the Hunter's Trading Post button and its 12 slots and converts
everything already on the map with `TransformUnit`. Shipments stay vanilla: the marker-gate layer that tried to
make the Home City cards deliver Harpooners shipped Hunters anyway in game, so it was removed - the cards ship
Hunters, and the transform converts merc ones that are already standing when the tech lands.

The unit's edge is the harpoon, not the body: 150 hp against the Hunter's 130, but 30 damage at rof 2.0 (15.0 dps
against 8.67). It promotes by hunting exactly as the Hunter does - ExperienceUnit plus a RangeAbsolute
veterancybonus - and carries the passive promotion icon through `dePromotionRange`.
"""
from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]

HARP, MERC = "zpNatInuitHarpooner", "zpNatMercInuitHarpooner"
HUNT, MHUNT = "deNatInuitHunter", "deNatMercInuitHunter"
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
    def test_the_weapon_carries_the_difference_not_the_body(self):
        b = _unit(HARP).group(0)
        assert _c(b, "initialhitpoints") == "150.0000" and _c(b, "maxhitpoints") == "150.0000"   # Hunter has 130
        assert _c(b, "buildlimit") == "12" and _c(b, "trainpoints") == "35.0000"
        ranged = [a for a in re.findall(r"<protoaction>.*?</protoaction>", b, re.S)
                  if re.search(r"<name>\w+RangedAttack</name>", a)]
        assert len(ranged) == 3
        for a in ranged:                                   # 30 dmg at rof 2.0 = 15.0 dps, against the Hunter's 8.67
            assert re.search(r"<damage>30\.000000</damage>", a)
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

    def test_both_promote_by_hunting_like_the_hunter(self):
        ab = _read("data/abilities/abilitymods.xml")
        for name in (HARP, MERC):
            b = _unit(name).group(0)
            assert "<flag>ExperienceUnit</flag>" in b, name
            ranks = re.findall(r'<rank id="(\d)">\s*<veterancymodify modifytype="RangeAbsolute">([\d.]+)</veterancymodify>', b, re.S)
            assert ranks == [("0", "1.0000"), ("1", "2.0000"), ("2", "4.0000")], (name, ranks)
            assert '<command page="11" column="0">Abilities</command>' in b, name
            entry = re.search(r"<%s>(.*?)</%s>" % (name.lower(), name.lower()), ab, re.S)
            assert entry and "dePromotionRange" in entry.group(1), name
            assert "<alwaysdisabledingrid>true</alwaysdisabledingrid>" in entry.group(1)
            assert "<forceshowrollover>true</forceshowrollover>" in entry.group(1)

    def test_both_sit_with_the_other_veterancy_units_at_the_top(self):
        s = _read("data/protomods.xml")
        lord = s.index('name="zpNatLord">')
        for name in (HARP, MERC):
            assert lord < s.index('name="%s">' % name) < s.index('name="zpNatHanseaticLegion">'), name

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
        s = (REPO / "sound/zpnatmercinuitharpooner_snds.xml").read_bytes()
        assert s.count(b"\r\n") == s.count(b"\n") > 0 and MERC.encode() in s

    def test_the_harpooner_took_the_hunter_s_trading_post_cell(self):
        s = _read("data/protomods.xml")
        assert '<train row="0" page="0" column="1">%s</train>' % HARP in s
        assert '<train row="0" page="0" column="3">%s</train>' % HARP not in s   # no longer shares the Husky's cell
        assert 'page="0" column="1"' in _tech("zpIncaTamboShadowHarpooner")      # the Tambo relocation follows

    def test_stand_ground_exists(self):
        p = REPO / "data/tactics/zpharpooner.tactics"
        b = p.read_bytes()
        assert b.count(b"\r\n") == b.count(b"\n") > 0                            # runtime XML is CRLF
        s = b.decode("utf-8")
        for stance in ("Volley", "Defend", "Stagger", "Melee", "StandGround"):
            assert "<tactic>%s<action" % stance in s, stance
        stand = re.search(r"<tactic>StandGround.*?</tactic>", s, re.S).group(0)
        assert "DefendRangedAttack" in stand and "<runaway>0</runaway>" in stand


class TestReplacement:
    def test_expansion_swaps_the_button_and_converts_what_is_on_the_map(self):
        b = _tech(EXP)
        assert '<effect type="CommandRemove" proto="%s">' % HUNT in b
        assert '<effect type="CommandAdd" proto="%s" page="0" column="1">' % HARP in b
        assert '<effect type="TransformUnit" toprotoid="%s" fromprotoid="%s">' % (HARP, HUNT) in b
        assert '<effect type="TransformUnit" toprotoid="%s" fromprotoid="%s">' % (MERC, MHUNT) in b
        assert b.count("<effect ") == 8

    def test_shipments_were_left_vanilla(self):
        """The marker-gate layer shipped Hunters anyway in game, so every trace of it is gone: no marker techs,
        no overrides of the three cards, no conditional shipment lines."""
        s = _read("data/techtreemods.xml")
        for gone in ("zpInuitHunterShipments", "zpInuitHarpoonerShipments", "FreeHomeCityUnitIfTechObtainable"):
            assert gone not in s, gone
        for card in ("DENativeTreatyInuit", "DEIndianFriendshipInuit", "DEHCIniuitAllies1"):
            assert '<tech name="%s">' % card not in s, card

    def test_both_harpooners_walk_the_hunter_s_upgrade_ladder(self):
        """x1.25 + Elite at DEWarriorSocietyInuit, x1.35 + Champion at DEChampionInuit, legendary rename at the
        shadow, and no free x1.20 from DEVeteranNativesShadow on top."""
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
