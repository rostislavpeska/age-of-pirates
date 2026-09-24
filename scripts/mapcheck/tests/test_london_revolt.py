"""London's revolt / setup system (user 2026-09-22): Paris's shapes.
  - starting techs by team (zpparis.xs 1984-2047): attackers (team 0, Stuart) get zpLondonAttackerSetup and the Parliament big
    button greyed (DisableShadow strips it, offShadow lights the fake), defenders (team 1, Parliament) get zpLondonDefenderSetup and
    the Stuart pair; everyone zpForbidRevolutions + zpExtendedStuartLondon (the London big button zpStuartExpansionSPC); players 0..N
    zpTollstation + deEUMapUpdateVisuals (Paris 2024-2033, gaia included);
  - the AI Commonwealth: Paris's Iniciate / Timer / Execute chain (3393-3466) for the defenders only, gated twice on holding a
    Parliament post (cTechzpNativeParliament, zpParliament's Age0 agetech);
  - the fake-button trio per side (tech pair + power + ability + protounitcommand on the TradingPost), Paris's records as the mould;
  - zplondon.mods.xml: Paris's placement rules, the Waterloo prop off the minimap, the instant gate."""
from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
STEAM = Path(r"C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\Game\RandMaps")
LONDON = REPO / "randmaps/zplondon.xs"


def _text(p: Path) -> str:
    return p.read_bytes().decode("utf-8").replace(chr(13), "")


def _code(t: str) -> str:
    return chr(10).join(l for l in t.split(chr(10)) if not l.strip().startswith("//"))


def _tech(name: str) -> str:
    s = _text(REPO / "data/techtreemods.xml")
    m = re.search(r'<tech name ?= ?"%s"[^>]*>.*?</tech>' % name, s, re.S); assert m, name
    return m.group(0)


def _set(pl: str, tech: str, ind: int) -> str:
    T = chr(9) * ind
    return chr(10).join([T + 'rmAddTriggerEffect("ZP Set Tech Status (XS)");', T + 'rmSetTriggerEffectParamInt("PlayerID", %s);' % pl,
                         T + 'rmSetTriggerEffectParam("TechID", "%s");' % tech, T + 'rmSetTriggerEffectParamInt("Status", 2);'])


class TestStartingTechsByTeam:
    def test_paris_shape(self):
        t = _code(_text(LONDON)); s = t[t.index('rmCreateTrigger("LondonStartingTechs");'):t.index('rmAddTriggerEffect("Player : Override Civilization for Flag");')]
        loop = s[s.index("for (k=1; <= cNumberNonGaiaPlayers)"):s.index("for (i = 0; <= cNumberNonGaiaPlayers)")]
        assert _set("k", "cTechzpForbidRevolutions", 2) in loop and _set("k", "cTechzpExtendedStuartLondon", 2) in loop
        att = loop[loop.index("if (rmGetPlayerTeam(k) == 0)"):loop.index("else")]; dfd = loop[loop.index("else"):]
        for tech in ("cTechzpLondonAttackerSetup", "cTechzpNatParliamentBigbuttonDisableShadow", "cTechzpNatParliamentoffShadow"):
            assert _set("k", tech, 3) in att and tech not in dfd, tech
        for tech in ("cTechzpLondonDefenderSetup", "cTechzpNatStuartBigbuttonDisableShadow", "cTechzpNatStuartoffShadow"):
            assert _set("k", tech, 3) in dfd and tech not in att, tech
        assert loop.index('"cTechzpExtendedStuartLondon"') < loop.index("if (rmGetPlayerTeam(k) == 0)")
        gaia = s[s.index("for (i = 0; <= cNumberNonGaiaPlayers)"):]
        assert _set("i", "cTechzpTollstation", 2) in gaia and _set("i", "cTechdeEUMapUpdateVisuals", 2) in gaia
        assert _set("0", "cTechzpConverGate", 1) in gaia and "cTechzpLondonSetup" not in t and "cTechzpExtendedStuart\"" not in t
        assert 'rmCreateTrigger("ExtendedStuart"' not in t and s.count("rmCreateTrigger(") == 1

    def test_setup_techs(self):
        for n in ("zpLondonAttackerSetup", "zpLondonDefenderSetup"):
            b = _tech(n)
            assert "<status>UNOBTAINABLE</status>" in b and "<flag>Shadow</flag>" in b
            assert re.search(r'subtype="Enable"[^>]*>\s*<target type="ProtoUnit">zpMilitaryCamp<', b) and 'proto="zpMilitaryCamp" page="6" column="2"' in b
            assert '<effect type="Data" amount="250.00" subtype="PopulationCap" relativity="Absolute">' in b     # Istanbul's zpBosporusMapSetup
            assert '<effect type="TechStatus" status="active">zpSPCDisableHousesShadow</effect>' in b
            for tech in ("DESPCPapalLegate", "DESPCExcommunication", "DESPCBankLoan", "DESPCMercenaryBounties"):     # Versailles / Paris: the Metropolitan cathedral and the bank techs
                assert ('<effect type="TechStatus" status="obtainable">%s</effect>' % tech) in b, tech
        s = _text(REPO / "data/techtreemods.xml")
        assert s.index('name="zpLondonDefenderSetup"') < s.index("<!--TEST TECHS-->") and 'name="zpLondonSetup"' in s     # the old setup stays, unreferenced


class TestBigButtonsGreyed:
    SIDES = {"Parliament": ("zpParliamentRemonstrance", "parliament_hm_big.png", "zpParliament", "zpPowerParliamentRemonstrance", "zpParliamentRemonstranceFake", "503478", "503565"),
             "Stuart": ("zpStuartExpansion", "stuartextend_big.png", "Stuart", "zpPowerStuartExpansion", "zpStuartExpansionFake", "503549", "503566")}

    def test_tech_pairs_paris_shape(self):
        for side, (button, icon, subciv, power, fake, disp, roll) in self.SIDES.items():
            off = _tech("zpNat%soffShadow" % side); dis = _tech("zpNat%sBigbuttonDisableShadow" % side)
            assert "<researchpoints>0.5000</researchpoints>" in off and "<flag>YPInfiniteTech</flag>" in off and "<status>UNOBTAINABLE</status>" in off and "<effects>" not in off
            assert '<effect type="CommandRemove" tech="%s">' % button in dis and '<target type="ProtoUnit">TradingPost</target>' in dis
            assert '<effect type="TechStatus" status="unobtainable">zpNat%sBigbuttonDisableShadow</effect>' % side in dis
        assert '<effect type="CommandRemove" tech="zpStuartExpansionSPC">' in _tech("zpNatStuartBigbuttonDisableShadow")
        p = _tech("zpNatBourbonBigbuttonDisableShadow"); assert '<effect type="CommandRemove" tech="zpBourbonExpansion">' in p    # the mould

    def test_power_ability_command_trio(self):
        pw = _text(REPO / "data/abilities/powermods.xml"); ab = _text(REPO / "data/abilities/abilitymods.xml"); cm = _text(REPO / "data/protounitcommandmods.xml"); pm = _text(REPO / "data/protomods.xml")
        tp = ab[ab.index("<tradingpost>"):ab.index("</tradingpost>")]
        for side, (button, icon, subciv, power, fake, disp, roll) in self.SIDES.items():
            m = re.search(r'<power name="%s" type="UnitAction">.*?</power>' % power, pw, re.S); assert m, power
            b = m.group(0); assert ("<displaynameid>%s</displaynameid>" % disp) in b and ("<rolloverid>%s</rolloverid>" % roll) in b and icon in b and "SpawnArmoredTrain" in b
            assert ("<ability>%s<tech>zpNat%sBigbuttonDisableShadow</tech><subciv>%s</subciv><rof>70</rof><castifnotselected>true</castifnotselected></ability>" % (power, side, subciv)) in tp
            c = re.search(r"<protounitcommand>\s*<name>%s</name>.*?</protounitcommand>" % fake, cm, re.S); assert c, fake
            c = c.group(0)
            for tag in ("<icon>resources\\images\\icons\\techs\\%s</icon>" % icon, "<associatedtech>zpNat%soffShadow</associatedtech>" % side, "<associatedpower>%s</associatedpower>" % power, "<subciv>%s</subciv>" % subciv, "<usebigbutton>"):
                assert tag in c, (fake, tag)
            assert cm.index(fake) < cm.index("<!--") and ('<command page="1" column="1">%s</command>' % fake) in pm
        st = _text(REPO / "data/strings/english/stringmods.xml")     # Paris 501944 / 501945: the description, then the red team block
        for i, team in ((503565, "DEFENDERS"), (503566, "ATTACKERS")):
            s = st[st.index('_locid="%d"' % i):st.index("</string>", st.index('_locid="%d"' % i))]
            assert "&lt;color=1.0, 0.0, 0.0&gt;" in s and ('Available only for the team "%s".&lt;/color&gt;' % team) in s and s.count(chr(0x2022)) >= 3, i
        i = pm.index('<command page="1" column="1">zpSansculottexpansionFake</command>'); assert pm.index("zpParliamentRemonstranceFake</command>") > i and pm.index("zpStuartExpansionFake</command>") > i


class TestLondonExtension:
    def test_extended_stuart_london_is_the_generic_one_with_the_spc_button(self):
        g = _tech("zpExtendedStuart"); l = _tech("zpExtendedStuartLondon")
        norm = lambda b: re.sub(r"<dbid>\d+</dbid>", "", b).replace("zpExtendedStuartLondon", "zpExtendedStuart").replace("zpStuartExpansionSPC", "zpStuartExpansion")
        assert norm(g) == norm(l) and '<effect type="CommandAdd" tech="zpStuartExpansionSPC" page="1" column="1">' in l and "zpStuartExpansionSPC" not in g
        s = _text(REPO / "data/techtreemods.xml"); assert s.index('name="zpExtendedStuart"') < s.index('name="zpExtendedStuartLondon"') < s.index('name="zpChateauRoyalShadow"')

    def test_spc_button_is_a_clone(self):
        hub = _tech("DENativeStuart")     # Paris 19804-19805: the hub grants the generic AND the SPC button (2026-09-22: without it the button never shows)
        assert '<effect mergemode="add" type="TechStatus" status="obtainable">zpStuartExpansion</effect>' in hub and '<effect mergemode="add" type="TechStatus" status="obtainable">zpStuartExpansionSPC</effect>' in hub
        st = _text(REPO / "data/strings/english/stringmods.xml")
        assert 'Available only for the team "DEFENDERS"' in st[st.index('_locid="503565"'):st.index('_locid="503566"')] and 'Available only for the team "ATTACKERS"' in st[st.index('_locid="503566"'):]
        g = _tech("zpStuartExpansion"); l = _tech("zpStuartExpansionSPC")
        def core(b):     # 2026-09-24 (user): the London button = the generic one + Lowlanders -> Whitecoats, with its own rollover
            b = re.sub(r"<dbid>\d+</dbid>|<rollovertextid>\d+</rollovertextid>", "", b).replace("zpStuartExpansionSPC", "zpStuartExpansion")
            for e in re.findall(r"<effect .*?(?:/>|</effect>)", b, re.S):
                if "Lowlander" in e or "Whitecoat" in e:
                    b = b.replace(e, "")
            return re.sub(r"\s+", " ", b)
        assert core(g) == core(l) and "<displaynameid>503549</displaynameid>" in l and "stuartextend_big.png" in l
        assert "<rollovertextid>503582</rollovertextid>" in l and "<rollovertextid>503550</rollovertextid>" in g and "Whitecoat" not in g
        assert not any(("cTech%s" % n) in _text(LONDON) for n in ("zpStuartExpansion", "zpStuartExpansionSPC"))     # the buttons come through the extension, not the map


class TestAICommonwealthGate:
    def test_paris_chain_for_the_defenders_on_the_post(self):
        t = _code(_text(LONDON)); assert "PickParliamentLeader" not in t
        s = t[t.index('rmCreateTrigger("ZP_Iniciate_Revolution" + k);'):t.index('rmCreateTrigger("PickJewishFraction" + k);')]
        assert t[t.rindex("for (k=1; <= cNumberNonGaiaPlayers)", 0, t.index('rmCreateTrigger("ZP_Iniciate_Revolution" + k);')):].startswith("for (k=1; <= cNumberNonGaiaPlayers)")
        assert "if (rmGetPlayerTeam(k) == 1)" in t[t.index('rmCreateTrigger("ZP_Iniciate_Revolution" + k);') - 80:t.index('rmCreateTrigger("ZP_Iniciate_Revolution" + k);')]
        ini = s[s.index('rmSwitchToTrigger(rmTriggerID("ZP_Iniciate_Revolution" + k));'):s.index('rmSwitchToTrigger(rmTriggerID("ZP_Timer_Revolution" + k));')]
        tim = s[s.index('rmSwitchToTrigger(rmTriggerID("ZP_Timer_Revolution" + k));'):s.index('rmSwitchToTrigger(rmTriggerID("ZP_Execute_Revolution" + k));')]
        exe = s[s.index('rmSwitchToTrigger(rmTriggerID("ZP_Execute_Revolution" + k));'):]
        T3 = chr(9) * 3
        assert chr(10).join([T3 + 'rmAddTriggerCondition("ZP PLAYER Human");', T3 + 'rmSetTriggerConditionParamInt("Player", k);', T3 + 'rmSetTriggerConditionParam("MyBool", "false");']) in ini
        assert chr(10).join([T3 + 'rmSetTriggerConditionParam("TechID", "cTechIndustrialize");', T3 + 'rmSetTriggerConditionParamInt("Status", 2);']) in ini
        assert 'rmTriggerID("ZP_Timer_Revolution" + k)' in ini and ini.count("rmSetTriggerActive(true);") == 1
        post = chr(10).join([T3 + 'rmAddTriggerCondition("ZP Tech Status Equals (XS)");', T3 + 'rmSetTriggerConditionParamInt("PlayerID", k);', T3 + 'rmSetTriggerConditionParam("TechID", "cTechzpNativeParliament");', T3 + 'rmSetTriggerConditionParamInt("Status", 2);'])
        assert post in tim and post in exe and chr(10).join([T3 + 'rmAddTriggerCondition("Timer");', T3 + 'rmSetTriggerConditionParamInt("Param1", 10);']) in tim
        assert 'rmTriggerID("ZP_Execute_Revolution" + k)' in tim and tim.count("rmSetTriggerActive(false);") == 1 and exe.count("rmSetTriggerActive(false);") == 1
        for n, name in ((1, "cTechzpConsulateParliamentCromwell"), (2, "cTechzpConsulateParliamentInchiquin"), (3, "cTechzpConsulateParliamentMyddelton")):
            assert ("if (parliamentLeader == %d)" % n) in exe and _set("k", name, 4) in exe
        assert "TechID\", 586" not in s
        c = _text(REPO / "data/civmods.xml"); i = c.index("<name>zpParliament</name>")
        assert "<age>Age0</age>" in c[i:i + 1200] and "<tech>zpNativeParliament</tech>" in c[i:i + 1200]     # the post-held gate is the Age0 agetech


class TestMapMods:
    def test_paris_city_look(self):
        lm = _text(REPO / "randmaps/zplondon.mods.xml"); par = _text(REPO / "randmaps/zpparis.mods.xml")
        def rules(s):
            return set(re.findall(r'<unit (?:id="\d+" )?name="([^"]+)">\s*<placementfile>([^<]+)</placementfile>', s))
        assert rules(lm) == rules(par) and len(rules(lm)) == 41
        assert re.search(r'<unit name="deSPCWaterlooHouseProp">\s*<flag>DoNotShowOnMiniMap</flag>\s*<animfile>buildings\\native_settlement\\zp_native_eu_houses_red_nosmoke.xml</animfile>\s*<flag>StartOnNoUpdate</flag>', lm)
        assert re.search(r'<unit name="SPCFortGate">\s*<unittype>ConvertsHerds</unittype>\s*<flag>PlaceAnywhere</flag>\s*<buildpoints>0.0000</buildpoints>', lm)
        assert lm.count('<unit name="FortFrontier">') == 1 and (REPO / "randmaps/zplondon.mods.xml").read_bytes().count(b"\r\n") > 70
        for f in set(v for _, v in rules(lm)):
            assert (REPO / "data/placementrules" / f).is_file(), f

    def test_prop_overrides_paris_shape(self):
        # user 2026-09-22: Paris's prop blocks verbatim for the protos London uses, London's own props in the same shapes
        lm = _text(REPO / "randmaps/zplondon.mods.xml"); par = _text(REPO / "randmaps/zpparis.mods.xml")
        def block(s, n):
            m = re.search(r'<unit name="%s">.*?</unit>' % n, s, re.S); return re.sub(r"\s+", " ", m.group(0)) if m else None
        for n in ("zpSPCEUHouseProp", "zpSPCVillageHouseProp", "deNatEUPropStatue", "deNatEUPropFence", "ypSMJesuitAccessory", "zpNativeStatueVenetian",
                  "zpNativeUnitVenetian", "deNatEUPropVilGuards", "deNatEUPropVilMale", "deNatEUPropVilFemale"):
            assert block(lm, n) == block(par, n), n
        assert block(lm, "zpSPCCityHouse") == '<unit name="zpSPCCityHouse"> <flag>DoNotShowOnMiniMap</flag> <flag>StartOnNoUpdate</flag> </unit>'
        for n in ("zpNatEUPropFencDarkBrickB", "zpNatEUPropFencDarkBrick", "zpPropsColony", "zpNativeHouseOrthodox", "zpPropStatueHomeCity", "zpHCFountainC", "zpNatEUPropObelisk"):
            assert block(lm, n) == '<unit name="%s"> <flag>NoIdleActions</flag> <flag>StartOnNoUpdate</flag> </unit>' % n, n

    def test_no_chimney_smoke(self):
        # user 2026-09-22: Paris's GPU rule - every house proto London places on a smoking animfile gets the no-smoke twin
        lm = _text(REPO / "randmaps/zplondon.mods.xml"); B = chr(92)
        for n, twin in (("zpSPCEUHouseProp", "zp_native_eu_houses_nosmoke.xml"), ("zpSPCCityHouse", "zp_native_eu_houses_nosmoke.xml"),
                        ("deSPCWaterlooHouseProp", "zp_native_eu_houses_red_nosmoke.xml"), ("zpSPCVillageHouseProp", "zp_native_village_houses_nosmoke.xml"), ("zpSPCVillageHousePropB", "zp_native_village_houses_nosmoke.xml")):
            assert ("<animfile>buildings" + B + "native_settlement" + B + twin + "</animfile>") in "".join(re.findall(r'<unit name="%s">.*?</unit>' % n, lm, re.S)), n
            assert (REPO / "art/buildings/native_settlement" / twin).read_bytes().count(b"\r\n") > 0, twin     # runtime XML, CRLF

    def test_twins_built_and_twin_identical(self, steam_twin, xmb_current):
        for f in ("data/techtreemods.xml", "data/protomods.xml", "data/protounitcommandmods.xml", "data/abilities/powermods.xml", "data/abilities/abilitymods.xml"):
            xmb_current(f)
        steam_twin(LONDON, "00000_zplondon.xs")
