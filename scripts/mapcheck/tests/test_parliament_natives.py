"""Spec for the Parliamentarians native (London, 2026-09-18).

Orthodox pattern: one default unit (the Lord), four base techs, a NativeDance big
button that opens the leader cards, three cards each enabling one unique unit and
two techs (p2 c6 weaker, p2 c7 stronger). Hetman pattern for the mounted builder
and mobile trainer. Every assertion is a convention read out of those chains.
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
D = REPO / "data"
STEAM = Path(r"C:/Program Files (x86)/Steam/steamapps/common/AoE3DE/Game/RandMaps")

SOCKET, LORD, IRON, BON, BOW = ("zpSocketParliament", "zpNatLord", "zpNatIronside", "zpNatBonaght", "zpNatWelshLongbowman")
CARD_UNITS = [IRON, BON, BOW]
HUB, VET, GUARD, BIG, SET, SETUP = ("zpNativeParliament", "zpNatVeteranParliament", "zpNatGuardParliament",
                                    "zpParliamentRemonstrance", "zpTurnConsulateOffParliament", "zpLondonSetup")
BASE = ["zpNatParliamentExcise", "zpNatParliamentTrainedBands", "zpNatParliamentLines", "zpNatParliamentEasternAssociation"]
CARDS = {"zpConsulateParliamentCromwell": (IRON, "zpParliamentIronsideLevy", "zpParliamentNewModelArmy"),
         "zpConsulateParliamentInchiquin": (BON, "zpParliamentMunsterLevies", "zpParliamentAdventurersAct"),
         "zpConsulateParliamentMyddelton": (BOW, "zpParliamentWelshDrovers", "zpParliamentNewRiver")}
TIERS = {LORD: (503452, 503453, 503454), IRON: (None, 503457, 503458),
         BON: (None, 503461, 503462), BOW: (None, 503465, 503466)}
# Eastern Association command aura: (action, vanilla name string, modifytype, multiplier)
AURAS = {"LordCommandDamage": ("48958", "Damage", "1.15"), "LordCommandHitpoints": ("48954", "MaxHP", "1.10")}


def _read(p):
    return (REPO / p).read_text(encoding="utf-8", errors="replace")


def _units():
    s = _read("data/protomods.xml")
    return {m.group(1): m.group(0) for m in re.finditer(r'<unit id="\d*" name="([^"]+)".*?</unit>', s, re.S)}


def _techs():
    s = _read("data/techtreemods.xml")
    return {m.group(1): m.group(0) for m in re.finditer(r'<tech\s+name\s*=\s*"([^"]+)"[^>]*>.*?</tech>', s, re.S)}


def _c(b, tag):
    m = re.search(r"<%s>([^<]*)</%s>" % (tag, tag), b)
    return m.group(1).strip() if m else None


def _crlf(p):
    b = Path(p).read_bytes()
    return b.count(b"\r\n") == b.count(b"\n") and b.count(b"\n") > 0


# ------------------------------------------------------------------- protos
class TestProtos:
    def test_six_protos_continue_the_real_id_sequence_above_the_test_block(self):
        s = _read("data/protomods.xml"); u = _units()
        test_at = s.index("<!--TEST AND TEMPORARY CONTENT-->")
        ids = re.findall(r'<unit id="(\d+)"', s)
        for n, i in ((SOCKET, 21181), (LORD, 21182), (IRON, 21184), (BON, 21185), (BOW, 21186)):  # 21183 (merc Lord) stripped 2026-09-19
            assert n in u, n
            assert _c(u[n], "dbid") == str(i) and ids.count(str(i)) == 1, (n, i)
            assert s.index('name="%s"' % n) < test_at, n

    def test_socket_is_the_stuart_socket_for_the_new_subciv(self):
        u = _units(); b = u[SOCKET]; st = u["zpSPCSocketStuart"]
        assert _c(b, "subciv") == "zpParliament" and _c(st, "subciv") == "Stuart"
        for tag in ("socketbuildprotounit", "socketbuildcommandid", "tactics", "obstructionradiusx"):
            assert _c(b, tag) == _c(st, tag), tag
        assert _c(b, "animfile") == _c(u["zpSocketVenetians"], "animfile") == _c(u["zpSocketHansaKontor"], "animfile")
        assert "<flag>SocketSubCivAlliance</flag>" in b and "<unittype>CapturableSocket</unittype>" in b
        assert "tuart" not in b

    @pytest.mark.parametrize("n", [LORD, IRON, BON, BOW])
    def test_native_unit_types_no_consulate_types(self, n):
        b = _units()[n]
        assert _c(b, "subciv") == "zpParliament" and _c(b, "populationcount") == "0"
        for t in ("AbstractNativeWarrior", "LogicalTypeGarrisonInShips", "ConvertsHerds", "CountsTowardMilitaryScore", "HasBountyValue", "Unit", "Military"):
            assert "<unittype>%s</unittype>" % t in b, (n, t)
        assert "Consulate" not in b, n
        assert "<unittype>Hero</unittype>" not in b and "KnockoutDeath" not in b, n
        for f in ("CollidesWithProjectiles", "ApplyHandicapTraining", "CorpseDecays", "ShowGarrisonButton", "Tracked"):
            assert "<flag>%s</flag>" % f in b, (n, f)

    def test_lord_is_the_agreed_baseline_a_mobile_barracks_and_a_builder(self):
        b = _units()[LORD]
        assert _c(b, "maxhitpoints") == "650.0000" and _c(b, "buildlimit") == "5" and _c(b, "allowedage") == "1"  # 2026-09-18: 800/3 was too few Lords
        assert _c(b, "tactics") == "parliamentlord.tactics" and _c(b, "animfile") == r"units\parliament\lord_horse.xml"
        assert re.search(r"<name>MeleeHandAttack</name>\s*<damage>35\.0", b)
        assert "AbstractCavalry</unittype>" in b and "AbstractHandCavalry" in b and "ConstrainOrientation" in b
        trains = re.findall(r"<train [^>]*>([^<]+)</train>", b)
        assert sorted(trains) == sorted(CARD_UNITS + ["TradingPost"]) and LORD not in trains  # 2026-09-19: Lords build Trading Posts
        assert re.search(r"<name>Build</name>\s*<maxrange>1\.0</maxrange>\s*<active>1</active>", b)

    @pytest.mark.parametrize("n,hp,age,limit,tac", [(IRON, "260.0000", "2", "10", "musketheavycavalry.tactics"),
                                                   (BON, "155.0000", "2", "15", "musketBayonet.tactics"),
                                                   (BOW, "95.0000", "2", "15", "archer.tactics")])
    def test_card_units_keep_vanilla_stats_fortress_age_mod_animfile(self, n, hp, age, limit, tac):
        b = _units()[n]
        assert _c(b, "maxhitpoints") == hp and _c(b, "allowedage") == age and _c(b, "buildlimit") == limit and _c(b, "tactics") == tac
        assert _c(b, "animfile").startswith("units" + chr(92) + "parliament" + chr(92)), n

    @pytest.mark.parametrize("n", [BON, BOW])
    def test_infantry_can_build(self, n):
        assert re.search(r"<name>Build</name>\s*<maxrange>1\.0</maxrange>\s*<active>1</active>", _units()[n])

    def test_trading_post_rows(self):
        s = _read("data/protomods.xml")
        tp = re.search(r'<unit name="TradingPost">.*?</unit>', s, re.S).group(0)
        assert '<train row="0" page="0" column="1">%s</train>' % LORD in tp
        for pg, c, t in ((1, 1, VET), (1, 1, GUARD), (1, 1, BIG), (2, 0, BASE[0]), (2, 1, BASE[1]), (2, 2, BASE[2]), (2, 3, BASE[3])):
            assert '<tech row="0" page="%d" column="%d">%s</tech>' % (pg, c, t) in tp, t


# ------------------------------------------------------------------- techs
class TestTechs:
    def test_dbids_continue_the_real_sequence_above_the_test_block(self):
        s = _read("data/techtreemods.xml"); t = _techs()
        test_at = s.index("<!--TEST TECHS-->")
        new = [HUB, VET, GUARD, "zpNativeTreatyParliament", "zpIndianFriendshipParliament", "zpNativeTradeTreatyParliament"] + BASE + [BIG] + \
              list(CARDS) + [x for c in CARDS.values() for x in c[1:]] + ["zpParliamentNewRiverShadow", SET, SETUP]
        ids = [int(_c(t[n], "dbid")) for n in new]
        assert ids == list(range(41521, 41521 + len(new))), ids
        for n in new:
            assert s.index('name="%s"' % n) < test_at, n
        alld = re.findall(r"<dbid>(\d+)</dbid>", s)
        for i in ids:
            assert alld.count(str(i)) == 1, i

    def test_hub_enables_the_lord_and_makes_everything_obtainable(self):
        b = _techs()[HUB]
        assert "<flag>Shadow</flag>" in b and re.search(r'subtype="Enable"[^>]*>\s*<target type="ProtoUnit">%s<' % LORD, b)
        for n in [VET, GUARD, BIG, "ypNativeEmbassyEnableShadow"] + BASE + [x for c in CARDS.values() for x in c[1:]]:
            assert '<effect type="TechStatus" status="obtainable">%s</effect>' % n in b, n
        for n in CARD_UNITS:
            assert n not in b, "card units are enabled by the cards, not the hub"

    def test_civ_points_at_the_hub(self):
        c = _read("data/civmods.xml")
        m = re.search(r"<civ>\s*<name>zpParliament</name>.*?</civ>", c, re.S)
        assert m and "<tech>%s</tech>" % HUB in m.group(0) and "<age>Age0</age>" in m.group(0)

    def test_veteran_covers_the_lord_only_guard_covers_all_with_tier_names(self):
        t = _techs(); v, g = t[VET], t[GUARD]
        assert "<techstatus status=\"Active\">Fortressize</techstatus>" in v and "Industrialize" in g and VET in g
        for n in CARD_UNITS:
            assert n not in v, n
        for n, (vet, guard, leg) in TIERS.items():
            if vet:
                assert 'proto="%s" culture="none" newname="%d"' % (n, vet) in v
                assert 'proto="%s" culture="none" newname="%d" reqtech="ImpLegendaryNativesShadow"' % (n, leg) in v
                assert re.search(r'amount="1\.20" subtype="Hitpoints"[^>]*>\s*<target type="ProtoUnit">%s<' % n, v)
            assert 'proto="%s" culture="none" newname="%d"' % (n, guard) in g
            assert 'proto="%s" culture="none" newname="%d" reqtech="ImpLegendaryNativesShadow"' % (n, leg) in g
            assert re.search(r'amount="1\.40" subtype="Hitpoints"[^>]*>\s*<target type="ProtoUnit">%s<' % n, g)

    def test_card_units_sit_in_the_automatic_fortress_veteran_shadow(self):
        b = _techs()["DEVeteranNativesShadow"]
        for n in CARD_UNITS:
            assert re.search(r'mergemode="add" type="Data" amount="1\.20" subtype="Hitpoints"[^>]*>\s*<target type="ProtoUnit">%s<' % n, b), n
            assert re.search(r'mergemode="add" type="Data" amount="1\.20" subtype="Damage" allactions="1"[^>]*>\s*<target type="ProtoUnit">%s<' % n, b), n
        assert LORD not in b

    def test_legendary_rename_override_names_every_unit(self):
        b = _techs()["ImpLegendaryNativesShadow"]
        for n, (_, _, leg) in TIERS.items():
            assert 'mergemode="add" type="SetName" proto="%s" culture="none" newname="%d"' % (n, leg) in b, n

    def test_hc_card_shadows_ship_merc_lords_and_grant_the_upgrades(self):
        t = _techs()
        assert re.search(r'amount="1\.00" subtype="FreeHomeCityUnit" unittype="%s"' % LORD, t["zpNativeTreatyParliament"])
        f = t["zpIndianFriendshipParliament"]
        assert re.search(r'amount="2\.00" subtype="FreeHomeCityUnit" unittype="%s"' % LORD, f)
        assert 'status="active">%s<' % VET in f and 'status="active">%s<' % GUARD in f
        assert 'resource="Trade"' in t["zpNativeTradeTreatyParliament"]

    def test_base_techs(self):
        t = _techs()
        assert 'subtype="ResourceTrickleRate" resource="Gold"' in t[BASE[0]]
        tb = t[BASE[1]]
        assert re.search(r'amount="1\.40" subtype="Hitpoints"[^>]*>\s*<target type="ProtoUnit">AbstractVillager<', tb)
        assert re.search(r'amount="1\.40" subtype="Damage" allactions="1"[^>]*>\s*<target type="ProtoUnit">AbstractVillager<', tb)
        lines = t[BASE[2]]
        for w in ("WallConnector", "WallStraight1", "WallStraight2", "WallStraight3", "WallStraight4", "WallStraight5"):
            assert re.search(r'amount="1\.50" subtype="Hitpoints"[^>]*>\s*<target type="ProtoUnit">%s<' % w, lines), w
        for u in (LORD, BON, BOW):  # the Lord's barricade button sits next to his Trading Post button (p0 c1)
            for w, pg, c in (("WallConnector", 0 if u == LORD else 6, 1 if u == LORD else 8), ("WallStraight2", 255, 1), ("WallStraight5", 255, 1)):
                assert 'proto="%s" page="%d" column="%d">\n        <target type="ProtoUnit">%s<' % (w, pg, c, u) in lines, (u, w)
        assert IRON not in lines, "the Ironside does not build"
        ea = t[BASE[3]]
        assert "BuildLimit" not in ea and ea.count("<effect ") == 2  # 2026-09-19: aura only, no build limit
        assert "Fortressize" in ea
        # command aura: the flat +20% on the Lords is gone, the tech switches the two tactics auras on per proto
        assert 'amount="1.20"' not in ea
        for u in (LORD,):
            for a in AURAS:
                assert ('action="%s" amount="1.00" subtype="ActionEnable" relativity="Absolute">\n        <target type="ProtoUnit">%s<'
                        % (a, u)) in ea, (a, u)

    def test_big_button_is_the_orthodox_pick_shape(self):
        b, o = _techs()[BIG], _techs()["zpOrthodoxInfluence"]
        for f in ("YPInfiniteTech", "DENoTextMessageIfFree", "DoNotQueue", "NativeDance", "YPNeverLastInLine", "Shadow"):
            assert "<flag>%s</flag>" % f in b and "<flag>%s</flag>" % f in o, f
        assert re.findall(r"<effect [^>]*>[^<]*</effect>", b) == re.findall(r"<effect [^>]*>[^<]*</effect>", o)
        assert "Fortressize" in b and re.search(r'resourcetype\s*=\s*"Gold">250', b)

    @pytest.mark.parametrize("card", list(CARDS))
    def test_card_enables_one_unit_and_places_two_techs(self, card):
        unit, t6, t7 = CARDS[card]; b = _techs()[card]
        for f in ("YPConsulateTech", "YPSequesterTech", "DoNotQueue", "CountsTowardMilitaryScore"):
            assert "<flag>%s</flag>" % f in b, f
        assert re.search(r'subtype="Enable"[^>]*>\s*<target type="ProtoUnit">%s<' % unit, b)
        assert 'tech="%s" page="2" column="6"' % t6 in b and 'tech="%s" page="2" column="7"' % t7 in b
        assert 'proto="%s" page="0" column="2"' % unit in b
        assert 'status="unobtainable">%s<' % BIG in b and 'status="obtainable">ypPickConsulateTech<' in b
        assert '<effect type="CommandRemove" tech="%s">' % BIG in b
        for other in CARD_UNITS:
            if other != unit:
                assert other not in b, (card, other)

    def test_leader_techs(self):
        t = _techs()
        assert re.search(r'amount2="10\.00" subtype="FreeHomeCityUnitShipped" unittype="zpSPCRegalShip" unittype2="%s"' % IRON, t["zpParliamentIronsideLevy"])
        assert "CheckWaterHCGatherPoint" in t["zpParliamentIronsideLevy"]
        nma = t["zpParliamentNewModelArmy"]
        assert re.search(r'amount="2\.00" subtype="BuildLimit" relativity="Absolute">\s*<target type="ProtoUnit">%s<' % LORD, nma)
        assert re.search(r'amount="0\.75" subtype="TrainPoints"[^>]*>\s*<target type="ProtoUnit">%s<' % IRON, nma)
        assert re.search(r'amount2="12\.00" subtype="FreeHomeCityUnitShipped" unittype="zpSPCRegalShip" unittype2="%s"' % BON, t["zpParliamentMunsterLevies"])
        assert re.search(r'amount="5\.00" subtype="BuildLimit" relativity="Absolute">\s*<target type="ProtoUnit">%s<' % BON, t["zpParliamentMunsterLevies"])
        adv = t["zpParliamentAdventurersAct"]
        assert "<flag>TeamTech</flag>" in adv and 'amount="1.00" subtype="ResourceTrickleRate" resource="Gold"' in adv
        dr = t["zpParliamentWelshDrovers"]
        assert 'amount="8.00" subtype="FreeHomeCityUnit" unittype="Sheep"' in dr and 'action="Gather" unittype="LivestockPen"' in dr
        river = t["zpParliamentNewRiver"]
        assert "<flag>TeamTech</flag>" in river and 'status="active">zpParliamentNewRiverShadow<' in river
        # the shadow is Galerie Lafayette's, effect for effect
        g = re.findall(r"<effect [^>]*>", t["zpGalerieLafayetteShadow"]); r = re.findall(r"<effect [^>]*>", t["zpParliamentNewRiverShadow"])
        assert g == r and len(g) > 5

    def test_own_set_offers_the_three_and_every_other_set_turns_them_off(self):
        t = _techs()
        own = t[SET]
        assert "<flag>YPInfiniteTech</flag>" in own and "<flag>Shadow</flag>" in own
        assert [c for c in CARDS if 'status="obtainable">%s<' % c in own] == list(CARDS)
        assert own.count('status="obtainable"') == 3
        others = [n for n in t if re.match(r"zpTurnConsulateO", n) and n != SET]
        assert len(others) == 38
        for n in others:
            for c in CARDS:
                assert 'status="unobtainable">%s<' % c in t[n], (n, c)
                assert 'status="obtainable">%s<' % c not in t[n], (n, c)

    def test_london_setup_gives_the_military_camp(self):
        b = _techs()[SETUP]
        assert "<flag>Shadow</flag>" in b and re.search(r'subtype="Enable"[^>]*>\s*<target type="ProtoUnit">zpMilitaryCamp<', b)
        assert 'proto="zpMilitaryCamp" page="6" column="2"' in b and "<target type=\"ProtoUnit\">Explorer</target>" in b


# ------------------------------------------------------------------- side records, art, sound, tactics
class TestSideRecords:
    def test_politician_portraits(self):
        p = _read("data/politicianmods.xml")
        for c in CARDS:
            assert re.search(r"<%s portraitfilename=\"[^\"]+\" portraitfilenamewpf=\"resources/images/icons/politicians/[a-z_]+\.png\">" % c.lower(), p), c

    def test_strings_continue_the_sequence_and_are_one_line(self):
        s = _read("data/strings/english/stringmods.xml")
        for i in [i for i in range(503446, 503500) if i != 503450]:  # 503450 was the merc Lord editor name, stripped
            assert re.search(r'<string _locid="%d">[^\n<]+</string>' % i, s), i
        for name in ("Lord Lieutenant", "Lord General", "Lord Protector", "Lifeguard Ironside", "The Grand Remonstrance",
                     "Oliver Cromwell (Commonwealth)", "Lord Inchiquin (Munster Protestants)", "Sir Thomas Myddelton (North Wales)"):
            assert ">%s<" % name in s, name

    @pytest.mark.parametrize("f", ["lord_horse.xml", "lord_rider.xml", "ironside_horse.xml", "bonaght.xml", "longbow.xml"])
    def test_animfiles_are_crlf_and_reference_only_archive_assets(self, f):
        p = REPO / "art/units/parliament" / f
        assert _crlf(p), f
        t = p.read_text(encoding="utf-8")
        assert "_consulate_" not in t, f  # the consulate selection decal is gone (a vanilla effect path may still say consulate)
        for m in re.findall(r"<file>([^<]+)</file>", t):
            assert not (REPO / "art" / (m + ".gr2")).exists(), ("mod copy of a game asset?", m)

    def test_lord_and_infantry_animfiles_carry_build_anims_the_ironside_only_the_decal(self):
        d = REPO / "art/units/parliament"
        for f in ("lord_horse.xml", "lord_rider.xml", "bonaght.xml", "longbow.xml"):
            t = (d / f).read_text(encoding="utf-8")
            for a in ("Build", "BuildLifting", "BuildSaw", "BuildStaking"):
                assert "<anim>%s<" % a in t, (f, a)
        assert r"units\parliament\lord_rider.xml" in (d / "lord_horse.xml").read_text(encoding="utf-8")
        assert 'a="hammer"' in (d / "lord_rider.xml").read_text(encoding="utf-8")
        iron = (d / "ironside_horse.xml").read_text(encoding="utf-8")
        assert "<anim>Build<" not in iron and "selection_oval_32x64" in iron

    def test_sounds_exist_crlf_named_after_the_protos(self):
        for n in (LORD, IRON, BON, BOW):
            p = REPO / "sound" / ("%s_snds.xml" % n.lower())
            assert p.exists() and _crlf(p), n
            assert '<protounit name="%s">' % n in p.read_text(encoding="utf-8")

    def test_lord_tactics_is_hand_cavalry_plus_build(self):
        p = REPO / "data/tactics/parliamentlord.tactics"
        assert _crlf(p)
        t = p.read_text(encoding="utf-8")
        assert t.count("<action>Build</action>") >= 4 and "<type>Build</type>" in t and "<anim>Build</anim>" in t
        # treasures: the handcavalry Discover action switched on (2026-09-19), with the hetman's Pickup anims on the model
        assert re.search(r"<name stringid=\"69148\">Discover</name>\s*<type>Discover</type>\s*<active>1</active>", t)
        for f in ("lord_horse.xml", "lord_rider.xml"):
            assert "<anim>Pickup<" in (REPO / "art/units/parliament" / f).read_text(encoding="utf-8"), f
        assert "MeleeHandAttack" in t and "TrampleHandAttack" in t

    def test_lord_command_auras_are_the_generals_flag_aura_shape_off_until_eastern_association(self):
        """AutoRangedModify x2, active 0, maxrange 14 (never map-wide), nostack + nostackignorepuid, LOS-ranged,
        every unit (UnitClass, no exclusion - Lords included; nostack keeps several Lords from stacking), the war chief
        ring as the glow, listed in every <tactic> line like every vanilla aura."""
        t = (REPO / "data/tactics/parliamentlord.tactics").read_text(encoding="utf-8")
        blocks = {re.search(r"<name[^>]*>([^<]*)</name>", b).group(1): b
                  for b in re.findall(r"<action>.*?</action>", t, re.S) if "<type>" in b}
        for a, (sid, mtype, mult) in AURAS.items():
            b = blocks[a]
            assert '<name stringid="%s">%s</name>' % (sid, a) in b
            assert _c(b, "type") == "AutoRangedModify" and _c(b, "active") == "0" and _c(b, "maxrange") == "14"
            assert _c(b, "modifyabstracttype") == "UnitClass" and "forbid" not in b
            for tag in ("persistent", "nostack", "nostackignorepuid", "modifyrangeuselos"):
                assert _c(b, tag) == "1", tag
            assert _c(b, "modifytype") == mtype and _c(b, "modifymultiplier") == mult
            assert _c(b, "modelattachment") == r"effects\military_aura\military_aura.xml"
            assert _c(b, "modelattachmentbone") == "bonethatdoesntexist"
            assert "modifyself" not in b
        tactics = re.findall(r"<tactic>.*?</tactic>", t, re.S)
        assert len(tactics) == 4
        for line in tactics:
            for a in AURAS:
                assert "<action>%s</action>" % a in line, a


# ------------------------------------------------------------------- London
class TestLondon:
    def test_mods_file_barricades_weaker_than_paris_and_the_european_ferry(self):
        for p in (REPO / "randmaps/zplondon.mods.xml", STEAM / "00000_zplondon.mods.xml"):
            assert p.exists() and _crlf(p), p
        a = (REPO / "randmaps/zplondon.mods.xml").read_bytes(); b = (STEAM / "00000_zplondon.mods.xml").read_bytes()
        assert a == b
        t = a.decode("utf-8")
        for w in ("WallConnector", "WallStraight1", "WallStraight2", "WallStraight3", "WallStraight4", "WallStraight5"):
            assert '<unit name="%s">' % w in t, w
        assert t.count("400.0000") == 6 and t.count("550.0000") == 6 and "600.0000" not in t and "800.0000" not in t
        assert r"buildings\wall\barricade\wall_1x2.xml" in t
        assert re.search(r'<unit name="zpOrientalFerry">\s*<animfile>buildings\\market\\west market standin.xml</animfile>', t)

    def test_map_switched_to_the_new_subciv_with_the_trigger_chain_root_equals_repo(self):
        repo = (REPO / "randmaps/zplondon.xs").read_bytes(); root = (STEAM / "00000_zplondon.xs").read_bytes()
        assert repo == root
        t = repo.decode("utf-8")
        assert 'rmSetSubCiv(0, "zpParliament")' in t and "zpSansculottes" not in t
        for s in ('"cTechzpLondonSetup"', '"cTechzpForbidRevolutions"', '"cTechzpParliamentRemonstrance"',
                  '"cTechzpTurnConsulateOffParliament"', 'rmAddTriggerEffect("ZP Pick Consulate Tech")',
                  'rmCreateTrigger("PickParliamentLeader" + k)'):
            assert s in t, s
        # the Paris idiom names the trigger with a space and asks for it with an underscore (engine-normalised)
        assert 'rmCreateTrigger("Activate Parliament" + k)' in t and 'rmCreateTrigger("Human Check Plr" + k)' in t
        for c in CARDS:
            assert '"cTech%s"' % c in t, c
        # every trigger is created before anything asks for its id
        assert t.index('rmCreateTrigger("Activate Parliament" + k)') < t.index('rmTriggerID("Activate_Parliament" + k)')

    def test_london_allocates_its_own_three_natives_and_the_jewish_chain(self):
        t = (REPO / "randmaps/zplondon.xs").read_text(encoding="utf-8")
        assert "rmAllocateSubCivs(3)" in t
        for i, civ in ((0, "zpParliament"), (1, "Stuart"), (2, "jewish")):
            assert 'rmSetSubCiv(%d, "%s")' % (i, civ) in t, civ
        for s in ("zpSansculottes", "SPCBourbon", "zpBonusBourbon"):
            assert s not in t, s
        for s in ('rmCreateTrigger("Activate Jewish" + k)', '"cTechzpJewishStar"', '"cTechzpTurnConsulateOffJewish"',
                  'rmTriggerID("Activate_Jewish" + k)', 'rmCreateTrigger("PickJewishFraction" + k)',
                  '"cTechzpConsulateJewishAmericans"', '"cTechzpConsulateJewishRussians"', '"cTechzpConsulateJewishGermans"'):
            assert s in t, s
        assert t.index('rmCreateTrigger("Activate Jewish" + k)') < t.index('rmTriggerID("Activate_Jewish" + k)')

    def test_native_blocks_work_as_one_unit_parliament_is_the_users_export(self):
        # Parliament block = the editor export of 2026-09-18 23:25 (select 0 / work 1 as exported); Stuart flipped to 1 / 1
        t = (REPO / "game/randmaps/groupings/EU_Native_Block_Parlam_01.xml").read_text(encoding="utf-8")
        assert "<workonassingleunit>1</workonassingleunit>" in t and t.count("<unit ") == 141
        t = (REPO / "game/randmaps/groupings/EU_Native_Block_Stuart_01.xml").read_text(encoding="utf-8")
        assert "<selectassingleunit>1</selectassingleunit>" in t and "<workonassingleunit>1</workonassingleunit>" in t
        assert ">zpSPCSocketStuart</unit>" in (REPO / "game/randmaps/groupings/EU_Native_Block_Stuart_01.xml").read_text(encoding="utf-8")

    def test_grouping_carries_the_new_socket_in_both_copies(self):
        a = (REPO / "game/randmaps/groupings/EU_Native_Block_Parlam_01.xml").read_bytes()
        b = (STEAM / "groupings/EU_Native_Block_Parlam_01.xml").read_bytes()
        assert a == b
        t = a.decode("utf-8")
        assert t.count(">%s</unit>" % SOCKET) == 1 and "zpSocketSansculottes" not in t

    def test_twins_are_fresh(self):
        for f in ("protomods", "techtreemods", "civmods", "politicianmods"):
            src, xmb = D / ("%s.xml" % f), D / ("%s.xml.xmb" % f)
            assert xmb.exists() and xmb.stat().st_mtime >= src.stat().st_mtime, f
        eng = D / "strings/english/stringmods.xml"
        for lang in D.joinpath("strings").iterdir():
            x = lang / "stringmods.xml.xmb"
            if x.exists():
                assert x.stat().st_mtime >= eng.stat().st_mtime, lang.name

# ------------------------------------------------------------------- flags (2026-09-19)
class TestFlags:
    def test_flag_protos_are_spc_flags_with_the_new_textures(self):
        u = _units()
        for n, i, tex in (("zpParliamentFlag", "21187", "zpparlamentarian"), ("zpStuartFlag", "21188", "zpstuartstandard")):
            b = u[n]
            assert _c(b, "dbid") == i and _c(b, "animfile") == _c(u["zpSansCoulottesFlag"], "animfile")
            assert _c(b, "civflagoverride") == "objects" + chr(92) + "flags" + chr(92) + tex, n
            assert (REPO / "art/objects/flags" / (tex + ".ddt")).exists(), tex
            assert "<flag>NotSelectable</flag>" in b and "<unittype>EmbellishmentClass</unittype>" in b

    def test_native_blocks_fly_their_own_flag_unit(self):
        p = (REPO / "game/randmaps/groupings/EU_Native_Block_Parlam_01.xml").read_text(encoding="utf-8")
        s = (REPO / "game/randmaps/groupings/EU_Native_Block_Stuart_01.xml").read_text(encoding="utf-8")
        assert ">zpParliamentFlag</unit>" in p and ">SPCFlag</unit>" not in p
        assert ">zpStuartFlag</unit>" in s and ">SPCFlag</unit>" not in s
        assert (REPO / "game/randmaps/groupings/EU_Native_Block_Parlam_01.xml").read_bytes() == (STEAM / "groupings/EU_Native_Block_Parlam_01.xml").read_bytes()

    def test_stuart_carries_the_london_flag_and_gaia_is_the_city_of_london(self):
        c = _read("data/civmods.xml")
        m = re.search(r"<civ>\s*<name>Stuart</name>.*?</civ>", c, re.S)
        assert m and "flags" + chr(92) + "zplondon" in m.group(0)
        assert "zpRevParliament" not in c and "zpRevRoyalist" not in c  # no player-flag overrides (2026-09-19)
        s = _read("data/strings/english/stringmods.xml")
        assert '<string _locid="503502">City of London</string>' in s and '_locid="503503"' not in s
        t = (REPO / "randmaps/zplondon.xs").read_text(encoding="utf-8")
        assert (REPO / "randmaps/zplondon.xs").read_bytes() == (STEAM / "00000_zplondon.xs").read_bytes()
        assert 'rmCreateTrigger("Flag ' not in t
        i = t.index('rmCreateTrigger("LondonStartingTechs")'); seg = t[i:i + 2500]
        assert 'rmAddTriggerEffect("Player : Override Civilization for Flag")' in seg and 'rmSetTriggerEffectParam("Civilization", "Stuart")' in seg
        assert 'rmAddTriggerEffect("Player : Override Civilization Name")' in seg and 'rmSetTriggerEffectParam("StringID", "503502")' in seg
        assert seg.count('rmSetTriggerEffectParamInt("Player", 0)') == 2
