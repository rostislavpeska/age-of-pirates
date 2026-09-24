"""Spec for the John Paul Jones pirate captain (Independence War only).

Written BEFORE the data was built (2026-09-07). Every assertion is a convention
read out of the existing Blackbeard / Grace / Wokou chains:

  ships     zpSPCBonhommeRichard (Black Pearl clone, ostinder model, no pirate
            training), zpSPCBonhommeRichardProxy (600 gold / 200 wood ticket),
            zpSPCSerapis (PrauB-style second ship, no proxy)
  pool      all three in every shared build-limit list; the pool holder stays
            zpSPCQueenAnne
  captain   zpConsulatePiratesJones consulate tech + politicianmods portrait
  set       zpTurnConsulateOffPiratesIndependence offers him; every other
            zpTurnConsulate* tech turns him off; only the IW map fires the set
  prize     zpPrizeOfFlamboroughHead: pool +1, ships the Serapis
"""
from __future__ import annotations

import os
import re
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
D = REPO / "data"
MAP = REPO / "randmaps" / "zpindependencewar.xs"
ROOT_MAP = Path(r"C:/Program Files (x86)/Steam/steamapps/common/AoE3DE/Game/RandMaps/000_independence_war.xs")

SHIP, PROXY, SHIP2 = "zpSPCBonhommeRichard", "zpSPCBonhommeRichardProxy", "zpSPCSerapis"
CAPTAIN, PRIZE, SET = "zpConsulatePiratesJones", "zpPrizeOfFlamboroughHead", "zpTurnConsulateOffPiratesIndependence"
STR = {503408: "Jones Flagship", 503409: "ZP SPC Bonhomme Richard", 503410: "ZP SPC Serapis",
       503411: "Pirate flagship with a powerful broadside attack ability.", 503412: "John Paul Jones (Map Bonus)",
       503414: "Bonhomme Richard", 503415: "Serapis", 503416: "Prize of Flamborough Head"}
ICON = r"resources\art\units\naval\spc\jones_flagship_icon.png"
PORTRAIT = r"resources\art\units\naval\spc\jones_flagship.png"
TECH_ICON = r"resources\images\icons\techs\johnes_second_flagship_tech.png"
POL_ICON = "resources/images/icons/politicians/johnpauljones.png"


def _read(p):
    return (D / p).read_text(encoding="utf-8", errors="replace")


def _units():
    s = _read("protomods.xml")
    return {m.group(1): m.group(0) for m in re.finditer(r'<unit id="\d*" name="([^"]+)".*?</unit>', s, re.S)}


def _techs():
    s = _read("techtreemods.xml")
    return {m.group(1): m.group(0) for m in re.finditer(r'<tech\s+name\s*=\s*"([^"]+)"[^>]*>.*?</tech>', s, re.S)}


def _c(b, tag):
    m = re.search(r"<%s>([^<]*)</%s>" % (tag, tag), b)
    return m.group(1).strip() if m else None


# ------------------------------------------------------------------- protos
class TestProtos:
    def test_three_new_protos_exist_with_unique_ids(self):
        u = _units()
        for n in (SHIP, PROXY, SHIP2):
            assert n in u, n
        s = _read("protomods.xml")
        ids = re.findall(r'<unit id="(\d+)"', s)
        # the file already carries six pre-existing duplicate ids (20212, 20317,
        # 20318, 20330, 20654, 20513); only the NEW ids are held to uniqueness
        for n in (SHIP, PROXY, SHIP2):
            uid = re.search(r'<unit id="(\d+)" name="%s"' % n, s).group(1)
            assert ids.count(uid) == 1, (n, uid)
            assert _c(u[n], "dbid") == uid

    def test_flagship_is_a_black_pearl_on_the_ostinder_hull_without_pirate_training(self):
        u = _units(); b = u[SHIP]; bp = u["zpSPCBlackPearl"]
        assert _c(b, "animfile") == r"units\naval\ostinder\ostinder.xml"
        assert _c(b, "tactics") == _c(bp, "tactics") == "frigate.tactics"
        for tag in ("maxhitpoints", "maxvelocity", "los", "bounty", "buildlimit", "obstructionradiusx", "sharedbuildlimitunit"):
            assert _c(b, tag) == _c(bp, tag), tag
        # 31344a7d: none of the Black Pearl's pirate crews - the Pirate Gunboat only, trained on the water
        assert re.findall(r"<train [^>]*>([^<]+)</train>", b) == ["zpPirateGunboat"] and "<train " in bp and "<flag>AllowTrainingOnWater</flag>" in b
        assert _c(b, "displaynameid") == "503408" and _c(b, "editornameid") == "503409"
        assert _c(b, "rollovertextid") == "503411" and _c(b, "shortrollovertextid") == "500005"
        assert _c(b, "icon") == ICON and _c(b, "portraiticon") == PORTRAIT
        assert re.findall(r"<name>([^<]+)</name>", b) == re.findall(r"<name>([^<]+)</name>", bp), "same protoactions"
        for t in ("AbstractPirateShip", "AbstractLegendaryShip", "AbstractWarShip"):
            assert f"<unittype>{t}</unittype>" in b
        assert "<flag>UseSharedBuildLimit</flag>" in b and 'column="0">Abilities</command>' in b

    def test_proxy_is_the_black_pearl_ticket_at_prau_cost(self):
        u = _units(); b = u[PROXY]; bp = u["zpSPCBlackPearlProxy"]
        assert re.findall(r'<cost resourcetype="(\w+)">([^<]+)</cost>', b) == [("Gold", "600.0000"), ("Wood", "200.0000")]
        assert _c(b, "trainpoints") == _c(bp, "trainpoints") == "40.0000"
        assert "<flag>NotPlayerPlaceable</flag>" in b and "<flag>UseSharedBuildLimit</flag>" in b
        assert _c(b, "displaynameid") == "503408" and _c(b, "rollovertextid") == "503411"
        assert _c(b, "icon") == ICON and _c(b, "portraiticon") == PORTRAIT
        assert _c(b, "sharedbuildlimitunit") == "zpSPCQueenAnne"

    @pytest.mark.parametrize("ship", [SHIP, SHIP2])
    def test_both_flagships_select_together(self, ship):
        b = _units()[ship]
        m = re.search(r"<sharedselectionunittypes>(.*?)</sharedselectionunittypes>", b, re.S)
        assert m and re.findall(r"<unittype>([^<]+)</unittype>", m.group(1)) == [SHIP, SHIP2]
        assert "sharedselectionunittypes" not in _units()[PROXY]

    def test_serapis_follows_the_prau_b_pattern(self):
        u = _units(); b = u[SHIP2]; a = u[SHIP]
        assert _c(b, "editornameid") == "503410" and _c(b, "displaynameid") == "503408"
        assert _c(b, "animfile") == _c(a, "animfile") and _c(b, "tactics") == _c(a, "tactics")
        assert _c(b, "buildlimit") == "1" and re.findall(r"<train [^>]*>([^<]+)</train>", b) == ["zpPirateGunboat"]   # 31344a7d
        assert "<unittype>AbstractLegendaryShip</unittype>" not in b, "PrauB drops AbstractLegendaryShip"
        assert "<unittype>AbstractPirateShip</unittype>" in b
        assert SHIP2 + "Proxy" not in u

    def test_shared_pool_lists_are_identical_and_include_the_three(self):
        s = _read("protomods.xml")
        lists = re.findall(r"<sharedbuildlimitunittypes>(.*?)</sharedbuildlimitunittypes>", s, re.S)
        pool = [re.findall(r"<unittype>([^<]+)</unittype>", l) for l in lists if "zpSPCPirateDestroyerProxy" in l]
        assert len(pool) == 19, f"expected 16 old + 3 new carriers, got {len(pool)}"
        assert all(p == pool[0] for p in pool), "every carrier must hold the identical list"
        for n in (SHIP, PROXY, SHIP2, "zpSPCQueenAnne", "zpSPCBlackPearlProxy"):
            assert n in pool[0]
        assert len(pool[0]) == 19 == len(set(pool[0]))


# --------------------------------------------------------------------- techs
class TestTechs:
    def test_dbids_unique(self):
        ids = re.findall(r"<dbid>(\d+)</dbid>", _read("techtreemods.xml"))
        new = [_c(_techs()[n], "dbid") for n in (CAPTAIN, PRIZE, SET)]
        assert all(ids.count(d) == 1 for d in new), new

    def test_captain_tech(self):
        t = _techs()[CAPTAIN]; g = _techs()["zpConsulatePiratesGrace"]
        for tag in ("cost", "researchpoints", "icon", "status"):
            assert re.search(r"<%s[^>]*>[^<]*</%s>" % (tag, tag), t).group(0) == re.search(r"<%s[^>]*>[^<]*</%s>" % (tag, tag), g).group(0), tag
        assert sorted(re.findall(r"<flag>([^<]+)</flag>", t)) == sorted(re.findall(r"<flag>([^<]+)</flag>", g))
        assert _c(t, "displaynameid") == "503412" and _c(t, "rollovertextid") == "503413"
        assert re.search(r'subtype="Enable"[^>]*>\s*<target type="ProtoUnit">%s</target>' % PROXY, t)
        for bld, col in (("TradingPost", "4"), ("zpSPCPirateDock", "1"), ("zpSPCPirateDockB", "1")):
            assert re.search(r'<effect type="CommandAdd" proto="%s" page="0" column="%s">\s*<target type="ProtoUnit">%s</target>' % (PROXY, col, bld), t), bld
        assert 'status="unobtainable">zpTheBlackFlag</effect>' in t and 'status="obtainable">ypPickConsulateTech</effect>' in t
        assert re.search(r'<effect type="CommandRemove" tech="zpTheBlackFlag">\s*<target type="ProtoUnit">TradingPost</target>', t)
        assert 'status="obtainable">%s</effect>' % PRIZE in t
        assert re.search(r'<effect type="CommandAdd" tech="%s" page="2" column="6">\s*<target type="ProtoUnit">TradingPost</target>' % PRIZE, t)
        assert "zpNatPirate<" not in t and "zpNatPirateEmbassy" not in t, "no pirate training for Jones"
        # map bonus (USA ships only): Ironclads and Steamers +15 % hitpoints
        for ship in ("xpIronclad", "deSteamer"):
            assert re.search(r'<effect type="Data" amount="1.15" subtype="Hitpoints" relativity="BasePercent">\s*<target type="ProtoUnit">%s</target>' % ship, t), ship
        assert "zpWokouSteamer" not in t and "zpSPCPirateSteamer" not in t and "zpHansaSteamer" not in t

    def test_prize_tech_is_the_wokou_second_flagship_pattern(self):
        t = _techs()[PRIZE]; w = _techs()["zpWokouSecondaryFlagship"]
        assert re.findall(r'<cost resourcetype="(\w+)">([^<]+)</cost>', t) == [("Gold", "800.0000")]
        assert _c(t, "researchpoints") == _c(w, "researchpoints") == "30.0000"
        assert sorted(re.findall(r"<flag>([^<]+)</flag>", t)) == sorted(re.findall(r"<flag>([^<]+)</flag>", w) + ["DEHideAdvancedRollover"])
        assert 'status="Active">Industrialize</techstatus>' in t
        assert _c(t, "icon") == TECH_ICON and _c(t, "displaynameid") == "503416" and _c(t, "rollovertextid") == "503417"
        assert re.search(r'<effect type="Data" amount="1.00" subtype="BuildLimit" relativity="Absolute">\s*<target type="ProtoUnit">zpSPCQueenAnne</target>', t)
        assert re.search(r'subtype="FreeHomeCityUnit" unittype="%s" relativity="Absolute">\s*<target type="Player">' % SHIP2, t)

    def test_independence_set_offers_jones_and_is_otherwise_the_pirate_set(self):
        te = _techs(); new = te[SET]; old = te["zpTurnConsulateOffPirates"]
        eff = lambda b: re.findall(r'<effect type="TechStatus" status="(\w+)">([^<]+)</effect>', b)  # noqa: E731
        # Jones REPLACES Grace on Independence War; Blackbeard and Black Caesar stay
        assert ("obtainable", CAPTAIN) in eff(new)
        assert ("unobtainable", "zpConsulatePiratesGrace") in eff(new)
        assert ("obtainable", "zpConsulatePiratesBlackbeard") in eff(new)
        assert ("obtainable", "zpConsulatePiratesBlackCaesar") in eff(new)
        skip = (CAPTAIN, "zpConsulatePiratesGrace")
        assert [e for e in eff(new) if e[1] not in skip] == [e for e in eff(old) if e[1] not in skip]
        assert ("unobtainable", CAPTAIN) in eff(old) and ("obtainable", "zpConsulatePiratesGrace") in eff(old)
        assert "<flag>Shadow</flag>" in new and "<flag>YPInfiniteTech</flag>" in new

    def test_every_other_set_turns_jones_off(self):
        te = _techs()
        sets = [n for n, b in te.items() if "zpConsulatePiratesBlackbeard</effect>" in b and n != SET]
        assert len(sets) == 38, len(sets)  # 2026-09-18: + zpTurnConsulateOffParliament
        for n in sets:
            assert 'status="unobtainable">%s</effect>' % CAPTAIN in te[n], n

    def test_legendary_privateer_and_citystate_locks_cover_the_new_ships(self):
        te = _techs()
        lp = te["zpNatLegendaryPrivateer"]
        for n in (SHIP, SHIP2):
            assert len(re.findall(r'<target type ="ProtoUnit">%s</target>' % n, lp)) == 2, n
        for n in ("zpPirateLockCitystateTechs", "zpPirateUnlockCitystateTechs"):
            assert PROXY in te[n], n


# ------------------------------------------------------------ side records
class TestSideRecords:
    def test_politician_portrait(self):
        s = _read("politicianmods.xml")
        assert re.search(r'<zpconsulatepiratesjones portraitfilename="ui\\ingame\\politicians\\consulate_portuguese" portraitfilenamewpf="%s">\s*</zpconsulatepiratesjones>' % re.escape(POL_ICON), s)

    def test_civ_pairing_for_both_pirate_docks(self):
        c = _read("civmods.xml")
        for bld in ("zpSPCPirateDock", "zpSPCPirateDockB"):
            assert re.search(r"<multipleblocktrain>\s*<building>%s</building>\s*<multipleblockunit>%s</multipleblockunit>\s*<units>\s*<unit>%s</unit>\s*</units>\s*<unitcounts>\s*<count>1</count>\s*</unitcounts>\s*</multipleblocktrain>" % (bld, PROXY, SHIP), c), bld

    def test_abilities_and_random_names(self):
        a = _read("abilities/abilitymods.xml")
        for tag in ("zpspcbonhommerichard", "zpspcserapis"):
            assert re.search(r"<%s>\s*<ability>PowerBroadside<rof>60</rof></ability>\s*</%s>" % (tag, tag), a), tag
        r = _read("randomnamemods.xml")
        assert "<protounit>%s<civ>Default<title>503414</title></civ></protounit>" % SHIP in r
        assert "<protounit>%s<civ>Default<title>503415</title></civ></protounit>" % SHIP2 in r

    def test_strings(self):
        s = _read("strings/english/stringmods.xml")
        for i, txt in STR.items():
            assert len(re.findall(r'_locid="%d"' % i, s)) == 1, i
            assert '<string _locid="%d">%s</string>' % (i, txt) in s, i
        for i in (503413, 503417):
            assert len(re.findall(r'_locid="%d"' % i, s)) == 1, i
        pol = re.search(r'<string _locid="503413">(.*?)</string>', s, re.S).group(1)
        # the Barbarossa (Map Bonus) layout of 503391: TRAINING / ship / one green Bonus line / SPECIAL TECH
        Y, G, E = "&lt;color=1.0, 0.9, 0.5&gt;", "&lt;color=0.0, 1.0, 0.0&gt;", "&lt;/color&gt;"
        want = (Y + "TRAINING:" + E + " \\nBonhomme Richard \\n\\n" + G + "Bonus:" + E
                + " Ironclads and Steamers get 15% more hitpoints. \\n\\n" + Y + "SPECIAL TECH:" + E + " \\nPrize of Flamborough Head")
        assert pol == want, pol
        assert "\n" not in pol and "Map Bonus" not in pol and "•" not in pol

    @pytest.mark.parametrize("ship", [SHIP, SHIP2])
    def test_voice_lines_are_the_spc_american_crew(self, ship):
        """sound/<protoname lowercased>_snds.xml, found by name; cloned from the
        Black Pearl's file, voiced with the campaign SPCAmerican crew sets (31344a7d;
        the DE American Frigate voice before)."""
        p = REPO / "sound" / (ship.lower() + "_snds.xml")
        assert p.exists(), p
        s = p.read_text(encoding="utf-8", errors="replace")
        assert '<protounit name="%s">' % ship in s
        pick = lambda t: re.search(r'<soundtype name="%s">\s*<soundset name="([^"]+)">' % t, s).group(1)  # noqa: E731
        assert pick("Select") == "SPCAmericanSelect" and pick("Acknowledge") == "SPCAmericanBoatAcknowledge"
        assert pick("Death") == "ShipDeath" and pick("Creation") == "ShipBirth" and pick("Exists") == "AmbienceShip"
        b = p.read_bytes(); assert b.count(b"\n") == b.count(b"\r\n"), "CRLF like the other _snds files"

    def test_pirate_natives_hub_offers_the_prize(self):
        hub = _techs()["zpNativePirates"]
        assert 'status="obtainable">%s</effect>' % PRIZE in hub
        assert 'status="obtainable">zpNatTreasureGalleon</effect>' in hub, "same hub that hands out Blackbeard's special"

    def test_icons_exist(self):
        for rel in (ICON, PORTRAIT, TECH_ICON, POL_ICON):
            assert (D / "wpfg" / rel.replace("\\", "/")).exists(), rel


# ------------------------------------------------ settlement training (IW)
class TestSettlementTraining:
    """IW trains flagships at captured pirate settlements: proxy near the socket
    -> cTechzpTrain<Ship><s> -> Spawn<Ship> action on zpPirateWaterSpawnFlag<s>."""

    @pytest.mark.parametrize("s", ["1", "2"])
    def test_spawn_tech_mirrors_the_black_pearl_one(self, s):
        te = _techs(); t = te["zpTrainBonhommeRichard" + s]; bp = te["zpTrainBlackPearl" + s]
        norm = lambda b: re.sub(r"<dbid>\d+</dbid>", "", re.sub(r'name="[^"]+"', "", b)).replace("SpawnBonhommeRichard", "SpawnBlackPearl")  # noqa: E731
        assert norm(t) == norm(bp), "identical apart from name, dbid and the spawn action"
        assert 'action="SpawnBonhommeRichard"' in t and 'unittype="zpPirateWaterSpawnFlag%s"' % s in t

    def test_water_flag_tactics_spawn_the_ship(self):
        s = (D / "tactics" / "waterspawnpoint.tactics").read_text(encoding="utf-8", errors="replace")
        m = re.search(r"<action>\s*<name[^>]*>SpawnBonhommeRichard</name>(.*?)</action>", s, re.S)
        assert m and '<rate type="%s">1.0</rate>' % SHIP in m.group(1) and "<singleuse>1</singleuse>" in m.group(1)
        assert "<action>SpawnBonhommeRichard</action>" in re.search(r"<tactic>.*?</tactic>", s, re.S).group(0)
        assert "SpawnBonhommeRichardProxy" not in s, "proxy spawns are unused anywhere; none for Jones"

    def test_map_trains_jones_instead_of_grace_and_ai_may_pick_him(self):
        m = MAP.read_text(encoding="utf-8", errors="replace")
        assert "GraceTrain" not in m and "zpSPCBlackPearlProxy" not in m and "cTechzpTrainBlackPearl" not in m
        assert "cTechzpConsulatePiratesGrace" not in m
        assert m.count('"JonesTrain"+s+"ONPlr"+k') >= 3 and m.count('"JonesTrain"+s+"OFFPlr"+k') >= 3
        assert '"UnitType","%s"' % PROXY in m and '"cTechzpTrainBonhommeRichard"+s' in m
        assert '"cTechzpConsulatePiratesJones"' in m and '"cTechzpConsulatePiratesBlackbeard"' in m and '"cTechzpConsulatePiratesBlackCaesar"' in m


# -------------------------------------------------------------- placement
class TestPlacement:
    """House rule (2026-09-07): new content is APPENDED at the end of a file's
    real content, above its test section - never wedged next to an old record."""

    def test_protos_sit_above_the_test_section_in_id_order(self):
        s = _read("protomods.xml")
        marker = s.find("<!--TEST AND TEMPORARY CONTENT-->")
        pos = [s.find('name="%s"' % n) for n in (SHIP, PROXY, SHIP2)]
        assert all(0 < p < marker for p in pos) and pos == sorted(pos)
        end_of_serapis = s.find("</unit>", pos[2])
        # appended, not wedged: whatever follows before the test section came later (house rule - ids continue)
        jones = [int(re.search(r'<unit id="(\d+)" name="%s"' % n, s).group(1)) for n in (SHIP, PROXY, SHIP2)]
        later = [int(i) for i in re.findall(r'<unit id="(\d+)"', s[end_of_serapis:marker])]
        assert all(i > max(jones) for i in later), "only later (higher-id) units may follow the new protos before the test section"

    def test_techs_sit_above_the_test_techs_and_only_later_ones_follow(self):
        s = _read("techtreemods.xml")
        marker = s.find("<!--TEST TECHS-->")
        pos = [s.find('<tech name="%s"' % n) for n in (CAPTAIN, PRIZE, SET, "zpTrainBonhommeRichard1", "zpTrainBonhommeRichard2")]
        assert all(0 < p < marker for p in pos) and pos == sorted(pos)
        jones = [int(_c(_techs()[n], "dbid")) for n in (CAPTAIN, PRIZE, SET, "zpTrainBonhommeRichard1", "zpTrainBonhommeRichard2")]
        later = [int(d) for d in re.findall(r"<dbid>(\d+)</dbid>", s[s.find("</tech>", pos[-1]):marker])]   # dbid-less vanilla merge records may follow
        assert all(d > max(jones) for d in later), "only later (higher-dbid) techs may follow the new techs before the test marker"

    def test_side_records_are_last(self):
        p = _read("politicianmods.xml")     # 2026-09-24: only later leaders may follow (the Parliament cards, 2026-09-19), not "Jones is last"
        dbid = {n.lower(): int(d) for n, d in re.findall(r'<tech\s+name\s*=\s*"(\w+)"[^>]*>\s*<dbid>(\d+)</dbid>', _read("techtreemods.xml"))}
        cards = re.findall(r"<(zp\w+) portraitfilename", p[p.find("</zpconsulatepiratesjones>"):])
        assert all(dbid.get(c, 0) > dbid["zpconsulatepiratesjones"] for c in cards), cards
        a = _read("abilities/abilitymods.xml")     # 2026-09-24: blocks are appended when an ability is added, not in id order -
        assert "<zpspcserapis>" in a                # older protos' blocks follow Serapis's (Mutineer, Minster, Lord ...), so no "is last" pin
        r = _read("randomnamemods.xml")     # 2026-09-24: only later protos' name lists may follow (Lord, Armed Merchantman), not "Serapis is last"
        ids = {n: int(i) for i, n in re.findall(r'<unit id="(\d+)" name="(\w+)"', _read("protomods.xml"))}
        after = re.findall(r"<protounit>(\w+)<", r[r.find("<protounit>%s<" % SHIP2):].split("</protounit>", 1)[1])
        assert all(ids.get(u, 0) > max(ids[n] for n in (SHIP, PROXY, SHIP2)) for u in after), after
        c = _read("civmods.xml")
        civ = re.search(r"<civ>\s*<name>NatPirates</name>.*?</civ>", c, re.S).group(0)
        for bld in ("zpSPCPirateDock", "zpSPCPirateDockB"):
            grp = re.findall(r"<building>%s</building>\s*<multipleblockunit>([^<]+)" % bld, civ)
            assert grp[-1] == PROXY, (bld, grp)


# ---------------------------------------------------------------- map/deploy
class TestMapAndDeploy:
    def test_only_independence_war_fires_the_new_set(self):
        m = MAP.read_text(encoding="utf-8", errors="replace")
        assert m.count('"cTech%s"' % SET) == 1 and '"cTechzpTurnConsulateOffPirates"' not in m
        for other in (REPO / "randmaps").glob("*.xs"):
            if other.name != MAP.name:
                assert SET not in other.read_text(encoding="utf-8", errors="replace"), other.name

    @pytest.mark.local("steam")
    def test_root_map_mirrors_repo(self):
        if not ROOT_MAP.exists():
            pytest.skip("no Game-root copy here")
        assert ROOT_MAP.read_bytes() == MAP.read_bytes()

    @pytest.mark.parametrize("f", ["protomods.xml", "techtreemods.xml", "civmods.xml", "politicianmods.xml",
                                   "randomnamemods.xml", "abilities/abilitymods.xml", "strings/english/stringmods.xml"])
    def test_twin_fresh(self, f, xmb_current):
        xmb_current("data/" + f)
