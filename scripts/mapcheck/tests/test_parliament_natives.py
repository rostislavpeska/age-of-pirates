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
        # the Lord is a veterancy unit: he lives in the top veterancy section next to the Eclaireur (2026-09-19)
        assert s.index('name="zpNatEclaireur">') < s.index('name="zpNatLord">') < s.index('name="zpNatHanseaticLegion">')

    def test_lord_veterancy_passive_ability_and_random_names(self):
        b = _units()[LORD]
        v = re.search(r"<veterancybonus>.*?</veterancybonus>", b, re.S).group(0)
        assert re.findall(r'modifytype="(\w+)">([\d.]+)<', v) == [("MaxHP", "1.1500"), ("Damage", "1.1500"), ("MaxHP", "1.2250"), ("Damage", "1.2250"), ("MaxHP", "1.3500"), ("Damage", "1.3500")]
        assert "<flag>ExperienceUnit</flag>" in b and "<flag>HeroName1</flag>" in b and '<command page="11" column="0">Abilities</command>' in b
        a = _read("data/abilities/abilitymods.xml")
        assert re.search(r"<zpnatlord>\s*<ability>dePromotionHpDMG<alwaysdisabledingrid>true</alwaysdisabledingrid><forceshowrollover>true</forceshowrollover></ability>\s*</zpnatlord>", a)
        r = _read("data/randomnamemods.xml")
        m = re.search(r"<protounit>zpNatLord<civ>Default((?:<title>\d+</title>)+)</civ></protounit>", r)
        ids = [int(x) for x in re.findall(r"\d+", m.group(1))]
        assert ids == list(range(503503, 503528))
        s = _read("data/strings/english/stringmods.xml")
        for i in ids:
            assert re.search(r'<string _locid="%d">[^<]*[A-Z][^<]*</string>' % i, s), i
        for sid, name in ((503452, "Lord Commander"), (503453, "Lord Lieutenant"), (503454, "Lord General")):
            assert '<string _locid="%d">%s</string>' % (sid, name) in s, name
        assert "builds Trading Posts" in re.search(r'<string _locid="503451">([^<]*)</string>', s).group(1)

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
        assert _c(b, "maxhitpoints") == "650.0000" and _c(b, "buildlimit") == "2" and _c(b, "allowedage") == "1"  # 2026-09-18: 800/3 was too few Lords; 2026-09-24: 2 per post - three posts = 6 Lords, not 15
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
        # owner 2026-09-25: 'can we swap Redcoat and Lord in Trading post?' - Redcoat first, then the Lord
        assert '<train row="0" page="0" column="1">zpNatRedcoat</train>' in tp and '<train row="0" page="0" column="3">%s</train>' % LORD in tp
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

    def test_hc_card_shadows_ship_merc_redcoats_and_grant_the_upgrades(self):
        t = _techs()     # 2026-09-24 (user): Merc Redcoats, not Lords - the vanilla Stuart counts (treaty 4, friendship 6)
        assert re.search(r'amount="4\.00" subtype="FreeHomeCityUnit" unittype="zpNatMercRedcoat"', t["zpNativeTreatyParliament"])
        f = t["zpIndianFriendshipParliament"]
        assert re.search(r'amount="6\.00" subtype="FreeHomeCityUnit" unittype="zpNatMercRedcoat"', f) and LORD not in f
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
        levy = t["zpParliamentIronsideLevy"]     # 2026-09-20: land-only, so no hull and no water gather point
        assert re.search(r'amount="12\.00" subtype="FreeHomeCityUnit" unittype="%s"' % IRON, levy)
        assert re.search(r'amount="2\.00" subtype="BuildLimit" relativity="Absolute">\s*<target type="ProtoUnit">%s<' % IRON, levy)
        assert "FreeHomeCityUnitShipped" not in levy and "zpSPCRegalShip" not in levy
        assert "CheckWaterHCGatherPoint" not in levy and levy.count("<effect ") == 2
        nma = t["zpParliamentNewModelArmy"]  # 2026-09-24 (user): a full rework - no team tech, no Embassy; Redcoats +30 % hp and attack,
        assert "TeamTech" not in nma and "Embassy" not in nma and LORD not in nma and IRON not in nma and nma.count("<effect ") == 8   # 25 % faster, limit +10; Musketeers +10 %; the Merc Redcoat too
        assert re.search(r'amount="10\.00" subtype="BuildLimit" relativity="Absolute">\s*<target type="ProtoUnit">zpNatRedcoat<', nma)
        assert re.search(r'amount="0\.75" subtype="TrainPoints"[^>]*>\s*<target type="ProtoUnit">zpNatRedcoat<', nma)
        for sub in ("Hitpoints", "Damage"):
            assert re.search(r'amount="1\.30" subtype="%s"[^>]*>\s*<target type="ProtoUnit">zpNatRedcoat<' % sub, nma)
            assert re.search(r'amount="1\.10" subtype="%s"[^>]*>\s*<target type="ProtoUnit">Musketeer<' % sub, nma)
        mun = t["zpParliamentMunsterLevies"]     # the Armed Merchantman, not the French Regal Ship
        assert re.search(r'amount2="12\.00" subtype="FreeHomeCityUnitShipped" unittype="zpSPCOstindedr" unittype2="%s"' % BON, mun)
        assert re.search(r'amount="5\.00" subtype="BuildLimit" relativity="Absolute">\s*<target type="ProtoUnit">%s<' % BON, mun)
        assert "CheckWaterHCGatherPoint" in mun and "zpSPCRegalShip" not in mun
        assert '<cost resourcetype="Food">350.0000</cost>' in mun and '<cost resourcetype="Wood">150.0000</cost>' in mun
        st = _read("data/strings/english/stringmods.xml")
        assert '<string _locid="503487">Ships 12 Ironsides. Ironside build limit +2.</string>' in st
        assert '<string _locid="503491">Ships an Armed Merchantman carrying 12 Bonaght Soldiers. Bonaght build limit +5.</string>' in st
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
        for i in [i for i in range(503446, 503532) if i != 503450]:  # 503450 was the merc Lord editor name, stripped
            assert re.search(r'<string _locid="%d">[^\n<]+</string>' % i, s), i
        for name in ("Lord Commander", "Lord Lieutenant", "Lord General", "Lifeguard Ironside", "The Grand Remonstrance",
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
            assert _c(b, "modelattachment") == "effects" + chr(92) + "ypack_auras" + chr(92) + "american_power.xml"  # the US General's star ring (2026-09-19)
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
        p = REPO / "randmaps/zplondon.mods.xml"
        assert p.exists() and _crlf(p), p
        # HARD RULE (2026-09-19): a .mods.xml lives in the repo only - a root copy crashes the game
        assert not list(STEAM.glob("*.mods.xml")), "per-map .mods.xml files in the Steam Game root crash the game"
        t = p.read_bytes().decode("utf-8")
        for w in ("WallConnector", "WallStraight1", "WallStraight2", "WallStraight3", "WallStraight4", "WallStraight5"):
            assert '<unit name="%s">' % w in t, w
        assert t.count("400.0000") == 6 and t.count("550.0000") == 6 and "600.0000" not in t and "800.0000" not in t
        assert r"buildings\wall\barricade\wall_1x2.xml" in t
        # the owner's own edit (2026-09-24): the ferry in the mod's city market look (art/buildings/market/city_market.xml)
        assert re.search(r'<unit name="zpOrientalFerry">\s*<animfile>buildings\\market\\city_market.xml</animfile>', t)
        assert (REPO / "art/buildings/market/city_market.xml").is_file()

    def test_map_switched_to_the_new_subciv_with_the_trigger_chain_root_equals_repo(self, steam_twin):
        repo = (REPO / "randmaps/zplondon.xs").read_bytes()
        t = repo.decode("utf-8")
        assert 'rmSetSubCiv(0, "zpParliament")' in t and "zpSansculottes" not in t
        for s in ('"cTechzpLondonAttackerSetup"', '"cTechzpLondonDefenderSetup"', '"cTechzpParliamentRemonstrance"',
                  '"cTechzpTurnConsulateOffParliament"', 'rmAddTriggerEffect("ZP Pick Consulate Tech")',
                  'rmCreateTrigger("ZP_Execute_Revolution" + k)'):     # 2026-09-22: Paris's AI chain replaced the Colonial roll
            assert s in t, s
        assert '<effect type="TechStatus" status="active">zpForbidRevolutions</effect>' in _techs()["zpLondonSetup"]     # 2026-09-24: the shared setup
        # the Paris idiom names the trigger with a space and asks for it with an underscore (engine-normalised)
        assert 'rmCreateTrigger("Activate Parliament" + k)' in t and 'rmCreateTrigger("Human Check Plr" + k)' in t
        for c in CARDS:
            assert '"cTech%s"' % c in t, c
        # every trigger is created before anything asks for its id
        assert t.index('rmCreateTrigger("Activate Parliament" + k)') < t.index('rmTriggerID("Activate_Parliament" + k)')
        steam_twin(REPO / "randmaps/zplondon.xs", "00000_zplondon.xs")

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
        assert "<workonassingleunit>1</workonassingleunit>" in t and t.count("<unit ") > 100      # the user's export (2026-09-21 21:47: 187 units)
        t = (REPO / "game/randmaps/groupings/EU_Native_Block_Stuart_01.xml").read_text(encoding="utf-8")
        assert "<selectassingleunit>1</selectassingleunit>" in t and "<workonassingleunit>1</workonassingleunit>" in t
        assert ">zpSPCSocketStuart</unit>" in (REPO / "game/randmaps/groupings/EU_Native_Block_Stuart_01.xml").read_text(encoding="utf-8")

    def test_grouping_carries_the_new_socket_in_both_copies(self):
        a = (REPO / "game/randmaps/groupings/EU_Native_Block_Parlam_01.xml").read_bytes()   # 2026-09-22: the Steam root groupings are vanilla-only, the mod folder is the live copy
        t = a.decode("utf-8")
        assert t.count(">%s</unit>" % SOCKET) == 1 and "zpSocketSansculottes" not in t

    def test_twins_are_fresh(self, xmb_current, language_twins_current):
        for f in ("protomods", "techtreemods", "civmods", "politicianmods", "strings/english/stringmods"):
            xmb_current("data/%s.xml" % f)
        language_twins_current()   # the 14 other languages ship the .xmb alone: stringsync.py's audit, not an mtime

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

    def test_stuart_carries_the_london_flag_and_gaia_is_the_city_of_london(self, steam_twin):
        c = _read("data/civmods.xml")
        m = re.search(r"<civ>\s*<name>Stuart</name>.*?</civ>", c, re.S)
        assert m and "flags" + chr(92) + "zplondon" in m.group(0)
        assert "zpRevParliament" not in c and "zpRevRoyalist" not in c  # the aborted per-side flag civs stay gone
        s = _read("data/strings/english/stringmods.xml")
        assert '<string _locid="503502">City of London</string>' in s and "Commonwealth of England" not in s  # 503503 is a Lord name now
        t = (REPO / "randmaps/zplondon.xs").read_text(encoding="utf-8")
        steam_twin(REPO / "randmaps/zplondon.xs", "00000_zplondon.xs")
        i = t.index('rmCreateTrigger("LondonStartingTechs")'); seg = t[i:t.index('rmCreateTrigger("Italian Vilager Balance"', i)]
        assert 'rmAddTriggerEffect("Player : Override Civilization for Flag")' in seg and 'rmSetTriggerEffectParam("Civilization", "Stuart")' in seg
        assert 'rmAddTriggerEffect("Player : Override Civilization Name")' in seg and 'rmSetTriggerEffectParam("StringID", "503502")' in seg
        assert seg.count('rmSetTriggerEffectParamInt("Player", 0)') == 2

# ------------------------------------------------------------------- Team New Model Army: the Cataphract embassy chain (2026-09-19)
class TestTeamIronsides:
    def test_merc_ironside_is_the_cataphract_merc_shape(self):
        u = _units(); b, base, cat, mcat = u["zpNatMercIronside"], u[IRON], u["zpNatCataphract"], u["zpNatMercCataphract"]
        assert _c(b, "dbid") == "21189" and "<subciv>" not in b and "<subciv>zpParliament</subciv>" in base
        assert _c(b, "sharedbuildlimitunit") == IRON and _c(mcat, "sharedbuildlimitunit") == "zpNatCataphract"
        for x in (b, base):
            assert re.search(r"<sharedbuildlimitunittypes>\s*<unittype>%s</unittype>\s*<unittype>zpNatMercIronside</unittype>\s*</sharedbuildlimitunittypes>" % IRON, x)
            assert "<flag>UseSharedBuildLimit</flag>" in x and _c(x, "buildlimit") == "10"
        assert "<unittype>MercType1</unittype>" in b and "<unittype>MercType1</unittype>" in mcat and "MercType1" not in base
        for tag in ("maxhitpoints", "tactics", "animfile", "displaynameid", "cost", "allowedage"):
            assert _c(b, tag) == _c(base, tag), tag
        assert _c(b, "editornameid") == "503528"

    def test_embassy_row_civ_block_and_upgrades_follow_the_cataphract(self):
        s = _read("data/protomods.xml")
        emb = re.search(r'<unit name="NativeEmbassy">.*?</unit>', s, re.S).group(0)
        assert '<train row="0" page="0" column="96">zpNatCataphract</train>' in emb and '<train row="0" page="0" column="137">%s</train>' % IRON in emb
        rew = re.search(r'<unit[^>]*name="zpNativeEmbassyParisReward"[^>]*>.*?</unit>', s, re.S).group(0)   # the embassy reward
        for col, u in ((137, IRON), (138, BON), (139, BOW), (140, LORD), (141, "zpNatRedcoat")):  # every Parliament unit, own column
            assert '<train row="0" page="0" column="%d">%s</train>' % (col, u) in emb, u
            assert '<train row="0" page="0" column="%d">%s</train>' % (col, u) in rew, u     # owner 2026-09-25
        c = _read("data/civmods.xml"); i = c.index("<name>zpParliament</name>"); blk = c[i:c.index("</civ>", i)]
        assert re.search(r"<multipleblocktrain>\s*<building>NativeEmbassy</building>\s*<multipleblockunit>zpNatMercIronside</multipleblockunit>\s*<units>\s*<unit>%s</unit>\s*</units>\s*<unitcounts>\s*<count>1</count>" % IRON, blk)
        t = _techs()
        assert re.search(r'mergemode="add" type="Data" amount="1\.20" subtype="Hitpoints"[^>]*>\s*<target type="ProtoUnit">zpNatMercIronside<', t["DEVeteranNativesShadow"])
        g = t[GUARD]
        assert 'proto="zpNatMercIronside" culture="none" newname="503457"' in g and 'proto="zpNatMercIronside" culture="none" newname="503458" reqtech="ImpLegendaryNativesShadow"' in g
        assert 'mergemode="add" type="SetName" proto="zpNatMercIronside" culture="none" newname="503458"' in t["ImpLegendaryNativesShadow"]
        st = _read("data/strings/english/stringmods.xml")
        assert '<string _locid="503488">New Model Army</string>' in st and "Ironside Levy, New Model Army" in st     # 2026-09-24: no longer a team tech
        assert (REPO / "sound/zpnatmercironside_snds.xml").exists()

# ------------------------------------------------------------------- the Commonwealth soft revolution (2026-09-19)
class TestCommonwealth:
    CIV, SHADOW = "zpRevCommonwealth", "zpCommonwealthRevolutionShadow"

    def test_flag_civ_is_the_paris_republic_shape_on_the_parliamentarian_flag(self):
        c = _read("data/civmods.xml")
        m = re.search(r"<civ>\s*<name>%s</name>.*?</civ>" % self.CIV, c, re.S); b = m.group(0)
        assert "<displaynameid>503531</displaynameid>" in b and "<revolutionhomecityname>503531</revolutionhomecityname>" in b
        assert "<displayrevolutionflag>0</displayrevolutionflag>" in b
        assert "<homecityflagtexture>objects" + chr(92) + "flags" + chr(92) + "zpparlamentarian</homecityflagtexture>" in b
        for tag, png in (("postgameflagiconwpf", "postgame_flag_parlamentarian.png"), ("homecityflagiconwpf", "Flag_parlamentarian.png"),
                         ("homecityflagbuttonwpf", "flag_hc_parlamentarian.png")):   # the user's own PNGs (2026-09-19)
            assert "<%s>resources/images/icons/flags/%s</%s>" % (tag, png, tag) in b, tag
            assert (REPO / "data/wpfg" / re.search(r"<%s>([^<]+)</%s>" % (tag, tag), b).group(1)).exists(), tag

    def test_message_shadow_next_to_the_french_one(self):
        s = _read("data/techtreemods.xml"); t = _techs()[self.SHADOW]
        assert s.index('name="zpFrenchRevolutionShadow"') < s.index('name="%s"' % self.SHADOW) < s.index("<!--TEST TECHS-->")
        assert _c(t, "dbid") == "41544" and "<status>OBTAINABLE</status>" in t and "<flag>OrPrereqs</flag>" in t and "<flag>Shadow</flag>" in t
        for card in CARDS:
            assert '<techstatus status="Active">%s</techstatus>' % card in t, card
        assert '<effect type="TextEffectOutput" reason="Revolution" selfmsg="503529" playermsg="503530">' in t
        st = _read("data/strings/english/stringmods.xml")
        assert '<string _locid="503531">British Commonwealth</string>' in st and "%s has declared" in st

    def test_london_flag_triggers_follow_independence_war(self, steam_twin):
        t = (REPO / "randmaps/zplondon.xs").read_text(encoding="utf-8")
        steam_twin(REPO / "randmaps/zplondon.xs", "00000_zplondon.xs")
        assert t.index('rmCreateTrigger("Revolution_MusicEnd" + k)') < t.index('rmTriggerID("Revolution_MusicEnd" + k)')
        for tag, card in zip(("Cromwell", "Inchiquin", "Myddelton"), CARDS):   # CARDS is a dict keyed by card name
            i = t.index('rmCreateTrigger("Flag %s" + k)' % tag); seg = t[i:i + 1300]
            assert '"cTech%s"' % card in seg and '"%s"' % card not in seg   # the trigger wants the XS constant, never the bare name
            assert 'rmSetTriggerEffectParam("Civilization", "%s")' % self.CIV in seg and 'rmSetTriggerEffectParam("StringID", "503531")' in seg
            assert 'Revolootin.mp3' in seg and 'rmSetTriggerEffectParamInt("Time", 61000)' in seg and '"UI_Strategywarning"' in seg
        assert "TransformUnit" not in t and "zpRevolutionFrance" not in t   # soft: no settler transform


# ------------------------------------------------------------------- extended House of Stuart, step 1: the small Highland Charge (2026-09-19)
class TestExtendedStuart:
    BIG, SMALL, TECH, SHADOW = "zpStuartAbilityBig", "zpStuartAbilitySmall", "zpNatStuartHighlandCharge", "zpExtendedStuart"
    CMD, POWER = "zpNatStuartHighlandChargeSmall", "zpNatPowerHighlandCharge"

    def test_power_clone_is_the_vanilla_record(self):
        s = _read("data/abilities/powermods.xml")
        m = re.search(r'<power name="%s" type="GeneralEffect">.*?</power>' % self.POWER, s, re.S); b = m.group(0)
        assert "<displaynameid>130625</displaynameid>" in b and "<rolloverid>130787</rolloverid>" in b and "<activetime>20</activetime>" in b
        assert 'amount="1.30"' in b and 'type="CannotSnare"' in b and ">DENatPowerStuart<" in b
        assert (REPO / "data/abilities/powermods.xml").read_bytes().count(b"\r\n") > 0

    def test_ability_big_keeps_its_size_and_the_small_twin_drops_size_and_cooldown_start(self):
        s = _read("data/abilities/abilitymods.xml")
        tp = s[s.index("<tradingpost>"):s.index("</tradingpost>")]
        big = [l for l in tp.splitlines() if "deNatPowerHighlandCharge<tech>" in l]; small = [l for l in tp.splitlines() if self.POWER + "<tech>" in l]
        assert len(big) == 1 and len(small) == 1
        assert 'mergemode="replace"' in big[0] and "<tech>%s</tech>" % self.BIG in big[0] and "usebigabilitybutton3" in big[0] and "subcivstartincooldown" in big[0]
        assert "<tech>%s</tech>" % self.SMALL in small[0] and "usebigabilitybutton3" not in small[0] and "subcivstartincooldown" not in small[0]
        for tag in ("<subciv>Stuart</subciv>", "<activetimecooldown>true</activetimecooldown>", "<rof>235</rof>", "<castonself>true</castonself>"):
            assert tag in small[0], tag

    def test_small_command_has_no_medium_flag(self):
        s = _read("data/protounitcommandmods.xml")
        b = re.search(r"<protounitcommand>\s*<name>%s</name>.*?</protounitcommand>" % self.CMD, s, re.S).group(0)
        assert "<associatedtech>%s</associatedtech>" % self.TECH in b and "<associatedpower>%s</associatedpower>" % self.POWER in b
        assert "<subciv>Stuart</subciv>" in b and "usemediumbutton3" not in b and "ability_highland_charge.png" in b
        assert s.index(self.CMD) < s.index("<!--")   # above the commented block, after the last real record

    def test_gates_tech_and_overrides(self):
        T = _techs(); s = _read("data/techtreemods.xml")
        assert _c(T[self.BIG], "dbid") == "41545" and "<status>OBTAINABLE</status>" in T[self.BIG] and "<flag>Shadow</flag>" in T[self.BIG]
        assert _c(T[self.SMALL], "dbid") == "41546" and "<status>UNOBTAINABLE</status>" in T[self.SMALL]
        assert _c(T[self.TECH], "dbid") == "41547" and "DEUseMediumButton3" not in T[self.TECH] and "<displaynameid>130625</displaynameid>" in T[self.TECH]
        for n in (self.BIG, self.SMALL, self.TECH):
            assert ">Colonialize</techstatus>" in T[n] and s.index('name="%s"' % n) < s.index("<!--TEST TECHS-->"), n
        hub, col = T["DENativeStuart"], T["DENativeStuartColonialize"]
        assert '<effect mergemode="add" type="TechStatus" status="obtainable">%s</effect>' % self.TECH in hub
        assert 'subtype="GrantsPowerDuration" protopower="%s" relativity="Assign"' % self.POWER in hub   # Royal House: the clone must be granted
        assert '<effect mergemode="add" type="TechStatus" status="active">%s</effect>' % self.TECH in col
        assert '<effect type="CommandRemove" tech="%s">' % self.TECH in col
        assert "mergeMode" not in hub + col

    def test_shadow_sits_at_the_top_and_swaps_the_paired_entry(self):
        s = _read("data/techtreemods.xml"); b = _techs()[self.SHADOW]
        assert s.index('name="zpExtendedPhanar"') < s.index('name="%s"' % self.SHADOW) < 30000   # beside the other extension shadows
        assert _c(b, "dbid") == "41548" and "<status>UNOBTAINABLE</status>" in b and "<flag>Shadow</flag>" in b
        assert '<effect type="CommandRemove" command="deNatStuartHighlandCharge">' in b and '<effect type="CommandRemove" tech="deNatStuartHighlandCharge">' in b
        assert '<effect type="CommandAdd" command="%s" page="0" column="4">' % self.CMD in b
        assert '<effect type="CommandAdd" tech="%s" page="0" column="4">' % self.TECH in b
        assert '<effect type="TechStatus" status="unobtainable">%s</effect>' % self.BIG in b and '<effect type="TechStatus" status="obtainable">%s</effect>' % self.SMALL in b
        assert '<effect type="CommandAdd" tech="zpStuartExpansion" page="1" column="1">' in b
        assert b.count("<effect ") == 7

    def test_london_flips_the_shadow_for_every_player(self, steam_twin):
        t = (REPO / "randmaps/zplondon.xs").read_text(encoding="utf-8")
        steam_twin(REPO / "randmaps/zplondon.xs", "00000_zplondon.xs")
        # 2026-09-24 (no duplicities): the London extension (zpExtendedStuartLondon, the SPC big button) sits in zpLondonSetup, which both
        # side techs activate BEFORE they strip the other side's button; the generic zpExtendedStuart stays for other maps
        T_ = _techs()
        assert '<effect type="TechStatus" status="active">zpExtendedStuartLondon</effect>' in T_["zpLondonSetup"]
        for side, strip in (("zpLondonAttackerSetup", "zpNatParliamentBigbuttonDisableShadow"), ("zpLondonDefenderSetup", "zpNatStuartBigbuttonDisableShadow")):
            b = T_[side]; assert b.index(">zpLondonSetup<") < b.index(">%s<" % strip), side
        i = t.index('rmCreateTrigger("LondonStartingTechs")')
        assert '"cTechzpExtendedStuart"' not in t and 'rmCreateTrigger("ExtendedStuart"' not in t and i < t.index('rmCreateTrigger("Activate Parliament" + k)')


# ------------------------------------------------------------------- the Armed Merchantman (Ostinder promoted, 2026-09-20)
class TestArmedMerchantman:
    PROTO, UID = "zpSPCOstindedr", "21190"
    JONES, PLAIN = "ostinder_sails_jones_matb_BaseColor", "ostinder_sails_matb_BaseColor"
    BS = chr(92)

    def test_proto_left_the_test_block_with_a_real_id(self):
        s = _read("data/protomods.xml")
        m = re.search(r'<unit id="%s" name="%s">.*?</unit>' % (self.UID, self.PROTO), s, re.S)
        assert m and m.start() < s.index("<!--TEST AND TEMPORARY CONTENT-->")
        b = m.group(0)
        BS = chr(92)
        icon = "resources" + BS + "art" + BS + "units" + BS + "trade" + BS + "zptradefluyt_unit_icon.png"
        assert _c(b, "icon") == icon and (REPO / "data/wpfg" / icon.replace(BS, "/")).exists()
        # the portrait is the vanilla trade fluyt's, referenced from the archive - never copied in
        assert _c(b, "portraiticon") == "resources" + BS + "art" + BS + "units" + BS + "trade" + BS + "trade_fluyt_portrait.png"
        assert not (REPO / "data/wpfg/resources/art/units/trade/trade_fluyt_portrait.png").exists()
        assert "frigate_icon" not in b
        assert _c(b, "dbid") == self.UID and _c(b, "displaynameid") == "503312" and _c(b, "rollovertextid") == "503314"
        assert _c(b, "animfile") == "units" + self.BS + "naval" + self.BS + "ostinder" + self.BS + "ostinder_merchant.xml"
        assert _c(b, "initialhitpoints") == "2100.0000" and _c(b, "buildlimit") == "3"

    def test_voices_and_names_fall_back_to_british(self):
        s = (REPO / "sound/zpspcostindedr_snds.xml").read_bytes().decode("utf-8").replace(chr(13), "")
        assert '<protounit name="%s">' % self.PROTO in s and s.count("<civlogic>") == 2
        for civ in ("zpRevCommonwealth", "DERevFrance", "Stuart", "Bourbon", "zpCivPirate", "Inuit"):
            assert '<choice name="%s">' % civ in s, civ
        assert not re.search(r'<choice name="\w+" />', s)          # no branch left silent
        assert s.count("BritishFrigateSelect") > 100 and "FrenchFrigateSelect" in s   # French civ keeps French
        n = _read("data/randomnamemods.xml")
        line = [l for l in n.splitlines() if "<protounit>%s<" % self.PROTO in l][0]
        default = re.search(r"<civ>Default((?:(?!</civ>).)*)</civ>", line).group(1)
        brit = re.search(r"<civ>British((?:(?!</civ>).)*)</civ>", line).group(1)
        assert re.findall(r"<title>(\d+)</title>", default) == re.findall(r"<title>(\d+)</title>", brit)

    def test_the_jones_flagship_keeps_the_original_animfile_and_sails(self):
        u = _units()
        for n in ("zpSPCBonhommeRichard", "zpSPCSerapis"):
            assert _c(u[n], "animfile") == "units" + self.BS + "naval" + self.BS + "ostinder" + self.BS + "ostinder.xml", n
        for f in ("ostinder_ship_model.material", "ostinder_ship_deathmodel.material"):
            s = (REPO / "art/units/naval/ostinder" / f).read_text(encoding="utf-8")
            matb = re.search(r'<submaterial name="matb">.*?</submaterial>', s, re.S).group(0)
            default, variant = matb.split('<parameters variant="1">')
            assert self.JONES in default and self.PLAIN not in default, f      # index 0 = Jones, untouched
            assert self.PLAIN in variant and self.JONES not in variant, f      # index 1 = the plain East-Indiaman sails
            assert s.count('<parameters variant="1">') == s.count("<submaterial "), f   # vanilla never ships a partial variant

    def test_merchant_animfile_selects_variant_one_and_is_crlf(self):
        p = REPO / "art/units/naval/ostinder/ostinder_merchant.xml"
        b = p.read_bytes()
        assert b.count(b"\r\n") == b.count(b"\n") > 0                          # runtime XML is CRLF or the engine ignores it
        s = b.decode("utf-8")
        assert s.count('<materialvariant index="1">') == 2                     # the model and the death model
        assert s.count('<assetreference type="GrannyModel">') == 2

    def test_voices_and_names_are_the_vanilla_per_civ_tables(self):
        b = (REPO / "sound/zpspcostindedr_snds.xml").read_bytes()
        assert b.count(b"\r\n") == b.count(b"\n") > 0
        s = b.decode("utf-8")
        assert '<protounit name="%s">' % self.PROTO in s and "<civlogic>" in s
        assert '<choice name="British">' in s and "BritishFrigateSelect" in s and "FrenchFrigateSelect" in s
        n = _read("data/randomnamemods.xml")
        line = [l for l in n.splitlines() if self.PROTO in l]
        assert len(line) == 1 and line[0].count("<civ>") >= 20                 # one line (XMB text whitespace trap), vanilla Galleon pools
        assert "<civ>British" in line[0] and "<civ>Default" in line[0]


# ------------------------------------------------------------------- Sovereign of the Seas: the Stuart naval tech (2026-09-20)
class TestSovereignOfTheSeas:
    TECH, SHIP, UID = "zpStuartSovereignSeas", "zpSPCRegalShip", "21191"

    def test_regal_ship_left_the_test_block(self):
        s = _read("data/protomods.xml")
        m = re.search(r'<unit id="%s" name="%s">.*?</unit>' % (self.UID, self.SHIP), s, re.S)
        assert m and m.start() < s.index("<!--TEST AND TEMPORARY CONTENT-->")
        assert _c(m.group(0), "dbid") == self.UID and _c(m.group(0), "buildlimit") == "2"   # 3 -> 2 (user 2026-09-24)
        assert _c(m.group(0), "maxhitpoints") == "2350.0000" == _c(m.group(0), "initialhitpoints")   # 2100 -> 2350 = the Dispatch Vessel (user 2026-09-24)
        b = m.group(0)
        BS = chr(92)
        icon = "resources" + BS + "art" + BS + "units" + BS + "naval" + BS + "spc" + BS + "regal_ship_icon.png"
        port = "resources" + BS + "art" + BS + "units" + BS + "naval" + BS + "spc" + BS + "regal_ship.png"
        assert _c(b, "icon") == icon and _c(b, "portraiticon") == port and "frigate_icon" not in b
        for f in (icon, port):
            assert (REPO / "data/wpfg" / f.replace(BS, "/")).exists(), f
        assert s.count('name="%s"' % self.SHIP) == 1

    def test_the_tech(self):
        T = _techs(); b = T[self.TECH]; s = _read("data/techtreemods.xml")
        assert _c(b, "dbid") == "41549" and _c(b, "displaynameid") == "503532" and _c(b, "rollovertextid") == "503533"
        assert "<status>UNOBTAINABLE</status>" in b and ">Industrialize</techstatus>" in b
        assert "<flag>YPNativeImprovement</flag>" in b and "<flag>CountsTowardMilitaryScore</flag>" in b
        assert '<cost resourcetype="Wood">800.0000</cost>' in b and '<cost resourcetype="Gold">600.0000</cost>' in b
        COAT = "deSPCHMWhitecoat"
        # 2026-09-24 (user, the split): the flagship sails alone (the vanilla HCShipFrigates shape), every dock builds
        # Regal Ships from then on, and the ship raises vanilla Whitecoats; Rupert and the Cavaliers moved to The Last Cavalier
        assert 'amount="1.00" subtype="FreeHomeCityUnit" unittype="%s"' % self.SHIP in b and "FreeHomeCityUnitShipped" not in b
        assert re.search(r'subtype="Enable"[^>]*>\s*<target type="ProtoUnit">%s<' % self.SHIP, b)
        # AbstractDock = Dock, YPDockAsian, dePort, deSPCSupplyDepot, deDryDock and the mod's zpDrydock; column 9 is free on all
        assert '<effect type="CommandAdd" proto="%s" page="0" column="9">\n        <target type="ProtoUnit">AbstractDock</target>' % self.SHIP in b.replace(chr(13), "")
        assert re.search(r'subtype="Enable"[^>]*>\s*<target type="ProtoUnit">%s<' % COAT, b)
        assert '<effect type="CommandAdd" proto="%s" page="0" column="1">' % COAT in b          # ships train land units on page 0
        assert re.search(r'amount="20.00" subtype="BuildLimit"[^>]*>\s*<target type="ProtoUnit">%s<' % COAT, b)
        assert "Rupert" not in b and "Cavalier" not in b and "Hitpoints" not in b
        assert "<flag>CheckWaterHCGatherPoint</flag>" in b          # it ships a warship
        icon = "resources" + chr(92) + "images" + chr(92) + "icons" + chr(92) + "techs" + chr(92) + "stuart" + chr(92) + "sovereign_seas.png"
        assert "<icon>" + icon + "</icon>" in b                    # the crown-and-anchor, forged from the user's art
        assert (REPO / "data/wpfg" / icon.replace(chr(92), "/")).exists()
        assert b.count("<effect ") == 6 and s.index('name="%s"' % self.TECH) < s.index("<!--TEST TECHS-->")
        assert '<effect mergemode="add" type="TechStatus" status="obtainable">%s</effect>' % self.TECH in T["DENativeStuart"]
        for dock in ("Dock", "YPDockAsian", "dePort", "deDryDock", "zpDrydock"):
            u = _units().get(dock, "")
            assert '<train row="0" page="0" column="9">' not in u, dock

    def test_battleship_voice_for_each_civ(self):
        """User 2026-09-24: the vanilla Battleship's lines (deMercBattleship_snds), each civ its own; no tech flip.
        Where vanilla parks a civ on the French placeholder, the civ's own-language warship voice; revolution civs
        have no branch (vanilla lists none in any _snds - the engine voices them by the parent civ)."""
        b = (REPO / "sound/zpspcregalship_snds.xml").read_bytes()
        assert b.count(b"\r\n") == b.count(b"\n") > 0
        s = b.decode("utf-8").replace(chr(13), "")
        assert '<protounit name="%s">' % self.SHIP in s and s.count("<civlogic>") == 2 and "techlogic" not in s
        assert not re.search(r'<choice name="\w+" />', s) and not re.search(r'<choice name="(DERev|zpRev)\w*">', s)
        for st, ss in (("Death", "ShipDeath"), ("Creation", "ShipBirth"), ("Exists", "AmbienceShip")):
            assert '<soundtype name="%s">\n      <soundset name="%s" />' % (st, ss) in s, st
        sel = s[s.index('<soundtype name="Select">'):s.index('<soundtype name="Death">')]
        ack = s[s.index('<soundtype name="Acknowledge">'):s.index('<soundtype name="Exists">')]
        def one(block, civ):
            return re.search(r'<choice name="%s">\n(.*?)\n        </choice>' % civ, block, re.S).group(1)
        for civ, se, ac in (("British", "BritishRocketSelect", "BritishBattleshipAcknowledge"),       # vanilla verbatim
                            ("Spanish", "SpanishMonitorSelect", "SpanishMonitorAcknowledge"),
                            ("DEDanish", "DanishBattleshipSelect", "DanishBattleshipAcknowledge"),
                            ("DEItalians", "DEItalianMortarSelect", "DEItalianMonitorAcknowledge"),
                            ("DEPolish", "PolishHeavyMilitarySelect", "PolishHeavyWarshipAttack"),
                            ("Japanese", "JapaneseShipsSelect", "JapaneseShipsAttack"),                 # own language
                            ("XPSioux", "SiouxWarCanoeSelect", "SiouxWarCanoeAcknowlegde"),
                            ("DEHausa", "DEHausaCannonBoatSelect", "DEHausaCannonBoatAcknowledge"),
                            ("DEMexicans", "DEMexicanIroncladSelect", "DEMexicanIroncladAcknowledge"),
                            ("zpCivPirate", "BritishRocketSelect", "BritishBattleshipAcknowledge"),
                            ("Stuart", "FrenchMonitorSelect", "FrenchMonitorAcknowledge")):
            assert se in one(sel, civ) and ac in one(ack, civ), civ
        assert "Frigate" not in s.replace("DEAmericanFrigate", "")        # only the Americans keep a frigate voice (no warship set exists)

    def test_british_name_pool(self):
        n = _read("data/randomnamemods.xml")
        line = [l for l in n.splitlines() if "<protounit>%s<" % self.SHIP in l]
        assert len(line) == 1
        brit = line[0].split("<civ>British")[1]
        ids = re.findall(r"<title>(\d+)</title>", brit.split("</civ>")[0])
        assert ids == [str(i) for i in range(503534, 503549)]                                # the one authored exception
        assert line[0].count("<civ>") == 25 and "<civ>French" in line[0] and "<civ>DEDanish" in line[0]
        default = re.search(r"<civ>Default((?:(?!</civ>).)*)</civ>", line[0]).group(1)
        assert re.findall(r"<title>(\d+)</title>", default) == ["54339", "50444"] + [str(i) for i in range(50359, 50368)]
        # Default is the fallback branch: any civ without its own block sails under French names
        assert "<title>50359</title>" in line[0].split("<civ>French")[1].split("</civ>")[0]  # vanilla Frigate pools, per civ
        st = _read("data/strings/english/stringmods.xml")
        assert '<string _locid="503532">Sovereign of the Seas</string>' in st
        roll = re.search(r'<string _locid="503533">([^<]*)</string>', st).group(1)
        assert "Every Dock builds Regal Ships from now on (up to 2)" in roll and "Whitecoats (up to 20)" in roll and "Rupert" not in roll
        assert '<string _locid="503534">Sovereign of the Seas</string>' in st and '<string _locid="503548">Merhonour</string>' in st

    def test_royal_burgh(self):
        """The Scottish land tech: the charter (a Covered Wagon = a free Town Center) plus walls and guns on every
        Town Center - 6500 -> 9100 hp, above FortFrontier's 9000, cannon 30 -> 75. Off the Trading Post since
        2026-09-24: The Last Cavalier took its p2 c5 slot (user); the record stays."""
        T = _techs(); b = T["zpStuartRoyalBurgh"]; s = _read("data/techtreemods.xml")
        assert _c(b, "dbid") == "41551" and _c(b, "displaynameid") == "503552" and _c(b, "rollovertextid") == "503553"
        assert "<status>UNOBTAINABLE</status>" in b and ">Fortressize</techstatus>" in b
        assert '<cost resourcetype="Food">500.0000</cost>' in b and '<cost resourcetype="Gold">500.0000</cost>' in b
        assert 'subtype="FreeHomeCityUnit" unittype="CoveredWagon"' in b
        assert re.search(r'amount="1.00" subtype="BuildLimit"[^>]*>\s*<target type="ProtoUnit">TownCenter<', b)
        for amount, sub in (("1.40", "Hitpoints"), ("2.50", "Damage")):
            assert re.search(r'amount="%s" subtype="%s"[^>]*>\s*<target type="ProtoUnit">AbstractTownCenter<' % (amount, sub), b), sub
        for proto in ("zpSPCCivilWarCommandery", "zpSPCCivilWarCommanderyCon", "deSPCCommandPost"):   # the player HQ on Paris / Versailles / Istanbul / London carries neither AbstractTownCenter nor AbstractFort
            assert re.search(r'amount="1.40" subtype="Hitpoints"[^>]*>\s*<target type="ProtoUnit">%s<' % proto, b), proto
            assert re.search(r'amount="2.50" subtype="Damage"[^>]*>\s*<target type="ProtoUnit">%s<' % proto, b), proto
        assert b.count("<effect ") == 10
        icon = "resources" + chr(92) + "images" + chr(92) + "icons" + chr(92) + "techs" + chr(92) + "stuart" + chr(92) + "royal_burgh.png"
        assert "<icon>" + icon + "</icon>" in b and (REPO / "data/wpfg" / icon.replace(chr(92), "/")).exists()
        assert s.index('name="zpStuartRoyalBurgh"') < s.index("<!--TEST TECHS-->")
        for n in ("DENativeStuart", "zpStuartExpansion", "zpStuartExpansionSPC"):
            assert "zpStuartRoyalBurgh" not in T[n], n
        st = _read("data/strings/english/stringmods.xml")
        assert '<string _locid="503552">Royal Burgh</string>' in st
        roll = re.search(r'<string _locid="503553">([^<]*)</string>', st).group(1)
        assert "Covered Wagon" in roll and "royal burgh" in roll

    def test_expansion_big_button(self):
        T = _techs(); s = _read("data/techtreemods.xml"); b = T["zpStuartExpansion"]
        assert _c(b, "dbid") == "41550" and _c(b, "displaynameid") == "503549" and _c(b, "rollovertextid") == "503550"
        assert "<status>UNOBTAINABLE</status>" in b and ">Fortressize</techstatus>" in b
        for flag in ("YPNativeImprovement", "CountsTowardEconomicScore", "NativeDance"):
            assert "<flag>%s</flag>" % flag in b, flag
        big = "resources" + chr(92) + "images" + chr(92) + "icons" + chr(92) + "techs" + chr(92) + "stuartextend_big.png"
        assert "<iconwpf>" + big + "</iconwpf>" in b and "<icontexturecoords>" in b   # the Phanar / Habsburg big-button shape
        assert (REPO / "data/wpfg" / big.replace(chr(92), "/")).exists()
        assert b.count("<effect ") == 2                                    # nothing but CommandAdds for the new techs
        assert '<effect type="CommandAdd" tech="%s" page="2" column="6">' % self.TECH in b
        assert '<effect type="CommandAdd" tech="zpStuartLastCavalier" page="2" column="5">' in b
        assert '<effect mergemode="add" type="TechStatus" status="obtainable">zpStuartExpansion</effect>' in T["DENativeStuart"]
        assert s.index('name ="zpStuartExpansion"') < s.index("<!--TEST TECHS-->")
        st = _read("data/strings/english/stringmods.xml")
        assert '<string _locid="503549">Divine Right of Kings</string>' in st


# ------------------------------------------------------------------- Whitecoats vs Redcoats (2026-09-24)
class TestCoats:
    """User 2026-09-24: the Redcoat is Parliament's base unit (vanilla HM stats, from the start), the London Stuart
    button turns the Lowlanders into Whitecoats (stronger), each side's Veteran / Guard names them."""

    def test_both_are_natives_with_the_standard_circle(self):
        u = _units()
        for n, subciv, anim, limit in (("zpNatWhitecoat", "Stuart", "units@stuart@whitecoat.xml", "15"), ("zpNatRedcoat", "zpParliament", "units@parliament@redcoat.xml", "13")):
            b = u[n]     # Redcoat 13 (user 2026-09-24: 15 was too strong beside 2 Lords and the leader's unit)
            assert _c(b, "subciv") == subciv and _c(b, "populationcount") == "0" and _c(b, "buildlimit") == limit, n
            assert _c(b, "animfile") == anim.replace("@", chr(92)) and "Consulate" not in b and "<unittype>AbstractNativeWarrior</unittype>" in b, n
            art = (REPO / "art" / anim.replace("@", "/")).read_bytes()
            assert b"shadow_circle_32x32" in art and b"consulate" not in art and art.count(b"\r\n") == art.count(b"\n"), n
            assert (REPO / ("sound/%s_snds.xml" % n.lower())).exists(), n
        w, r = u["zpNatWhitecoat"], u["zpNatRedcoat"]
        assert _c(w, "maxhitpoints") == "170.0000" and float(_c(w, "maxhitpoints")) > 135     # the Lowlander: 135 hp, 19 ranged
        assert re.search(r"<name>VolleyRangedAttack</name>\s*<damage>23\.0", w)
        assert _c(r, "maxhitpoints") == "160.0000" and re.search(r"<name>VolleyRangedAttack</name>\s*<damage>25\.0", r)   # vanilla deSPCHMRedcoat

    def test_redcoat_from_the_start_on_its_own_slot(self):
        t = _techs()
        assert re.search(r'subtype="Enable"[^>]*>\s*<target type="ProtoUnit">zpNatRedcoat<', t["zpNativeParliament"])
        pm = (REPO / "data/protomods.xml").read_text(encoding="utf-8")
        assert '<train row="0" page="0" column="1">zpNatRedcoat</train>' in pm     # before the Lord (owner 2026-09-25 swap)
        for tech, amt, name in (("zpNatVeteranParliament", "1.20", "503579"), ("zpNatGuardParliament", "1.40", "503580")):
            b = t[tech]
            assert re.search(r'amount="%s" subtype="Hitpoints"[^>]*>\s*<target type="ProtoUnit">zpNatRedcoat<' % re.escape(amt), b), tech
            assert 'proto="zpNatRedcoat" culture="none" newname="%s">' % name in b and 'proto="zpNatRedcoat" culture="none" newname="503581" reqtech="ImpLegendaryNativesShadow">' in b, tech

    def test_london_button_turns_lowlanders_into_whitecoats(self):
        t = _techs(); b = t["zpStuartExpansionSPC"]
        for f, to in (("deNatLowlanderInfantry", "zpNatWhitecoat"), ("deNatLowlanderRider", "zpNatWhitecoat")):
            assert '<effect type="TransformUnit" fromprotoid="%s" toprotoid="%s" />' % (f, to) in b
        assert re.search(r'amount="0\.00" subtype="Enable" relativity="Assign">\s*<target type="ProtoUnit">deNatLowlanderInfantry<', b)
        assert re.search(r'amount="1\.00" subtype="Enable"[^>]*>\s*<target type="ProtoUnit">zpNatWhitecoat<', b)
        assert '<effect type="CommandRemove" proto="deNatLowlanderInfantry">' in b and '<effect type="CommandAdd" proto="zpNatWhitecoat" page="0" column="2">' in b
        assert "zpNatWhitecoat" not in t["zpStuartExpansion"]     # the Unknown map's button stays the vanilla-unit one

    def test_merc_redcoat_is_the_ironside_merc_shape_and_gets_every_upgrade(self):
        u = _units(); base, merc = u["zpNatRedcoat"], u["zpNatMercRedcoat"]
        assert _c(merc, "dbid") == "21203" and "<subciv>" not in merc and _c(merc, "sharedbuildlimitunit") == "zpNatRedcoat"
        assert "<unittype>MercType1</unittype>" in merc and "MercType1" not in base and "<flag>UseSharedBuildLimit</flag>" in base
        for tag in ("maxhitpoints", "tactics", "animfile", "displaynameid", "cost", "buildlimit"):
            assert _c(merc, tag) == _c(base, tag), tag
        t = _techs()
        for tech in ("zpNatVeteranParliament", "zpNatGuardParliament", "zpParliamentNewModelArmy"):
            assert re.search(r'subtype="Hitpoints"[^>]*>@s*<target type="ProtoUnit">zpNatMercRedcoat<'.replace("@", chr(92)), t[tech]), tech
        assert 'proto="zpNatMercRedcoat" culture="none" newname="503581">' in t["ImpLegendaryNativesShadow"]
        assert (REPO / "sound/zpnatmercredcoat_snds.xml").exists()

    def test_whitecoat_ranks_ride_on_the_stuart_upgrades(self):
        t = _techs()
        for tech, pre, amt, name in (("zpVeteranWhitecoat", "DEVeteranStuart", "1.20", "503574"), ("zpGuardWhitecoat", "DEGuardStuart", "1.40", "503575")):
            b = t[tech]
            assert "<flag>Shadow</flag>" in b and "<status>OBTAINABLE</status>" in b, tech
            assert '<techstatus status="Active">%s</techstatus>' % pre in b and '<techstatus status="Active">zpStuartExpansionSPC</techstatus>' in b, tech
            assert re.search(r'amount="%s" subtype="Damage"[^>]*>\s*<target type="ProtoUnit">zpNatWhitecoat<' % re.escape(amt), b), tech
            assert 'newname="%s">' % name in b and 'newname="503576" reqtech="ImpLegendaryNativesShadow">' in b, tech
        leg = t["ImpLegendaryNativesShadow"]
        assert 'proto="zpNatWhitecoat" culture="none" newname="503576">' in leg and 'proto="zpNatRedcoat" culture="none" newname="503581">' in leg


# ------------------------------------------------------------------- Prince Rupert of the Rhine (2026-09-24)
class TestPrinceRupert:
    """User 2026-09-24: the Royalist cavalry hero The Last Cavalier brings - the vanilla Cavalier's design with the
    hero circle, builds Trading Posts, collects treasures, trains Cavaliers, respawns (the mod's hero pattern)."""
    HERO = "zpNatPrinceRupert"

    def test_the_hero_record(self):
        b = _units()[self.HERO]
        assert _c(b, "dbid") == "21202" and _c(b, "subciv") == "Stuart" and _c(b, "populationcount") == "0" and _c(b, "buildlimit") == "1"
        for tag in ("<unittype>Hero</unittype>", "<unittype>ExcludeFromRansom</unittype>", "<flag>KnockoutDeath</flag>", "<flag>NotDeleteable</flag>",
                    '<train row="0" page="0" column="0">TradingPost</train>', '<train row="0" page="0" column="1">deSPCHMCavalier</train>',
                    '<command page="11" column="0">Abilities</command>', "<name>SwashbucklerAttack</name>"):
            assert tag in b, tag
        assert re.search(r'<name>Build</name>\s*<rate type="TradingPost">', b) and "Consulate" not in b
        # stronger with the split (user 2026-09-24): 1200 hp, pistol 28, sabre 40, trample 32 (cap 120), charge 260
        assert _c(b, "maxhitpoints") == "1200.0000" and _c(b, "tactics") == "zpprincerupert.tactics"
        for name, dmg in (("DefendRangedAttack", "28"), ("MeleeHandAttack", "40"), ("TrampleHandAttack", "32"), ("SwashbucklerAttack", "260")):
            assert re.search(r"<name>%s</name>\s*<damage>%s\.0" % (name, dmg), b), name

    def test_respawns_builds_and_collects_in_every_tactic(self):
        t = (REPO / "data/tactics/zpprincerupert.tactics").read_bytes()
        assert t.count(b"\r\n") == t.count(b"\n")
        s = t.decode("utf-8")
        assert '<rate type="%s">1.0</rate>' % self.HERO in s and "<restricttoknockout>1</restricttoknockout>" in s
        assert "<modifyabstracttype>AbstractCavalry</modifyabstracttype>" in s and "<modifymultiplier>1.15</modifymultiplier>" in s
        for a in ("HeroRespawn", "Build", "Discover", "RupertsHorse", "RecruitGuardian"):
            assert s.count("<action>%s</action>" % a) == 5, a
        assert s.count("<tactic>") == 5 and '<action priority="1">SwashbucklerAttack</action>' in s

    def test_cavalier_design_with_the_hero_circle(self):
        h = (REPO / "art/units/stuart/prince_rupert_horse.xml").read_bytes()
        r = (REPO / "art/units/stuart/prince_rupert_rider.xml").read_bytes()
        for f in (h, r):
            assert f.count(b"\r\n") == f.count(b"\n")
            for anim in (b"<anim>Pickup", b"<anim>Build", b"<anim>BuildLifting", b"<anim>BuildSaw", b"<anim>BuildStaking"):
                assert anim in f, anim
        assert b"selection_hero_64x64" in h and b"consulate" not in h and b"prince_rupert_rider.xml" in h
        assert b"rieter_age4_rider" in r and b'<materialvariant index="1" />' in r     # the vanilla Cavalier look, by path
        s = (REPO / "sound/zpnatprincerupert_snds.xml").read_text(encoding="utf-8")
        # the British Skirmisher's voice (user 2026-09-24), the cavalry grunt kept; no Skirmisher revive line exists
        assert '<protounit name="%s">' % self.HERO in s and "Explorer" not in s and '<soundset name="CavalryGrunt" />' in s
        for ss in ("BritishSkirmisherSelect", "BritishSkirmisherAcknowledge", "BritishSkirmisherAttack"):
            assert '<soundset name="%s" />' % ss in s, ss

    def test_abilities_age_scaling_and_names(self):
        a = _read("data/abilities/abilitymods.xml"); p = _read("data/abilities/powermods.xml")
        blk = a[a.index("<zpnatprincerupert>"):a.index("</zpnatprincerupert>")]
        for ab in ("PowerSwashbuckler<rof>45</rof>", "zpPassiveRupertsHorse", "PowerRecruitGuardian<rof>90</rof>", "deUnitHealthRegen"):
            assert ab in blk, ab
        assert re.search(r'<power name="zpPassiveRupertsHorse" type="UnitAction">.*?<displaynameid>503586</displaynameid>', p, re.S)
        T = _techs()
        for tech, amt in (("zHeroIndustrializeShadow", "1.20"), ("zpHeroImperializeShadow", "1.30")):
            for sub in ("Hitpoints", "Damage"):
                assert re.search(r'amount="%s" subtype="%s"[^>]*>\s*<target type="ProtoUnit">%s<' % (re.escape(amt), sub, self.HERO), T[tech]), (tech, sub)
        st = _read("data/strings/english/stringmods.xml")
        assert '<string _locid="503583">Prince Rupert of the Rhine</string>' in st


# ------------------------------------------------------------------- The Last Cavalier (2026-09-24)
class TestLastCavalier:
    """User 2026-09-24: Rupert split off the Sovereign of the Seas - he arrives with 10 Cavaliers instead of alone on a
    ship, at p2 c5 of the Stuart Trading Post (the Royal Burgh's slot); the icon is his portrait in the tech frame."""
    TECH = "zpStuartLastCavalier"

    def test_the_tech(self):
        T = _techs(); b = T[self.TECH]; s = _read("data/techtreemods.xml")
        assert _c(b, "dbid") == "41563" and _c(b, "displaynameid") == "503589" and _c(b, "rollovertextid") == "503590"
        assert "<status>UNOBTAINABLE</status>" in b and ">Fortressize</techstatus>" in b
        assert '<cost resourcetype="Food">1000.0000</cost>' in b and '<cost resourcetype="Gold">1000.0000</cost>' in b
        assert 'amount="1.00" subtype="FreeHomeCityUnit" unittype="zpNatPrinceRupert"' in b
        assert 'amount="10.00" subtype="FreeHomeCityUnit" unittype="deSPCHMCavalier"' in b
        assert re.search(r'subtype="Enable"[^>]*>\s*<target type="ProtoUnit">deSPCHMCavalier<', b)
        assert re.search(r'amount="10.00" subtype="BuildLimit"[^>]*>\s*<target type="ProtoUnit">deSPCHMCavalier<', b)
        assert b.count("<effect ") == 4 and "Shipped" not in b and "CheckWaterHCGatherPoint" not in b    # overland, no ship
        assert s.index('name="zpGuardWhitecoat"') < s.index('name="%s"' % self.TECH) < s.index("<!--TEST TECHS-->")
        assert '<effect mergemode="add" type="TechStatus" status="obtainable">%s</effect>' % self.TECH in T["DENativeStuart"]
        for ext in ("zpStuartExpansion", "zpStuartExpansionSPC"):
            assert '<effect type="CommandAdd" tech="%s" page="2" column="5">' % self.TECH in T[ext], ext

    def test_icon_is_the_portrait_in_the_tech_frame(self):
        Image = pytest.importorskip("PIL.Image")      # CI may lack PIL
        icon = "resources" + chr(92) + "images" + chr(92) + "icons" + chr(92) + "techs" + chr(92) + "stuart" + chr(92) + "last_cavalier.png"
        assert "<icon>" + icon + "</icon>" in _techs()[self.TECH]
        a = Image.open(REPO / "data/wpfg" / icon.replace(chr(92), "/")).convert("RGBA")
        frame = Image.open(REPO / "data/wpfg/resources/images/icons/techs/stuart/sovereign_seas.png").convert("RGBA")
        assert a.size == (128, 128)
        assert a.getpixel((2, 64)) == frame.getpixel((2, 64)) and a.getpixel((64, 2)) == frame.getpixel((64, 2))   # the same gold border

    def test_strings(self):
        st = _read("data/strings/english/stringmods.xml")
        assert '<string _locid="503589">The Last Cavalier</string>' in st
        roll = re.search(r'<string _locid="503590">([^<]*)</string>', st).group(1)
        assert "Prince Rupert" in roll and "10 Cavaliers" in roll and "up to 10" in roll
        for sid in ("503582", "503566"):
            line = re.search(r'<string _locid="%s">([^<]*)</string>' % sid, st).group(1)
            assert "Unlocks The Last Cavalier" in line and "Royal Burgh" not in line, sid
        assert "The Last Cavalier" in re.search(r'<string _locid="503550">([^<]*)</string>', st).group(1)

    def test_cavalier_speaks_like_the_british_dragoon(self):
        """User 2026-09-24: vanilla's deSPCHMCavalier sends attack orders to BritishDragoonAttack, a soundset no vanilla
        file defines (silent); the override is vanilla dragoon_snds with only its British branch, flattened."""
        b = (REPO / "sound/despchmcavalier_snds.xml").read_bytes()
        assert b.count(b"\r\n") == b.count(b"\n") > 0
        s = b.decode("utf-8").replace(chr(13), "")
        assert '<protounit name="deSPCHMCavalier">' in s and "civlogic" not in s and "BritishDragoonAttack" not in s
        assert s.count('<soundset name="BritishDragoonAcknowledge" />') == 2 and '<soundset name="BritishDragoonSelect" />' in s
        for ss in ("CavalryGrunt", "GenericMaleDeath", "MilitaryBirth"):
            assert '<soundset name="%s" />' % ss in s, ss
