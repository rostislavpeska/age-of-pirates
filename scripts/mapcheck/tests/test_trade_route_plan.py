"""The trade-route plan (owner 2026-09-24): no post offers a route upgrade (zpDisableAllTradeRouteUpgrades); London starts both
routes at level 1 on the capture map type (the capture tech turns the ferries to resources); St Paul's researches London Deptford
Station (the road -> trains), the Minster the East India Trading Company (the river lane -> level 2) - triggers raise the route
and take the tech from everyone else; Istanbul starts both naval routes at level 1, not improvable."""
from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
LONDON = REPO / "randmaps/zplondon.xs"
ISTANBUL = REPO / "randmaps/zpistanbulb.xs"
UPG = ["TradeRouteUpgrade1", "TradeRouteUpgrade2", "ypTradeRouteUpgrade1", "ypTradeRouteUpgrade2", "ypTradeRouteUpgradeIndia1",
       "ypTradeRouteUpgradeIndia2", "TradeRouteUpgradeCapturable1", "TradeRouteUpgradeCapturable2", "DETradeRouteUpgradeAll1",
       "DETradeRouteUpgradeAll2", "deTradeRouteUpgradeAmerica1", "deTradeRouteUpgradeAmerica2", "DETradeRouteUpgradeMaghreb1",
       "DETradeRouteUpgradeMaghreb2", "DETradeRouteUpgradeAfrica1", "DETradeRouteUpgradeAfrica2", "DETradeRouteUpgradeAfricaRailroad2",
       "DETradeRouteUpgradeWater1", "DETradeRouteUpgradeWater2", "DETradeRouteUpgradeRiver1", "DETradeRouteUpgradeRiver2",
       "DETradeRouteUpgradeEurope1", "DETradeRouteUpgradeEurope2", "DETradeRouteUpgradeRiverAll1", "DETradeRouteUpgradeRiverAll2",
       "DETradeRouteUpgradeEuropeAll1", "DETradeRouteUpgradeEuropeAll2", "DETradeRouteUpgradeWaterAll1", "DETradeRouteUpgradeWaterAll2",
       "DETradeRouteUpgradeArctic1", "DETradeRouteUpgradeArctic2", "DETradeRouteUpgradeArcticWater1", "DETradeRouteUpgradeArcticWater2"]


def _text(p: Path) -> str:
    return p.read_bytes().decode("utf-8").replace(chr(13), "")


def _tech(name: str) -> str:
    t = _text(REPO / "data/techtreemods.xml")
    m = re.search(r'<tech name="%s" type="Normal">.*?</tech>' % name, t, re.S)
    assert m, name
    return m.group(0)


def _proto_techs(name: str) -> list:
    p = _text(REPO / "data/protomods.xml")
    m = re.search(r'<unit[^>]*name="%s"[^>]*>(.*?)</unit>' % name, p, re.S)
    return re.findall(r"<tech[^>]*>([^<]+)</tech>", m.group(1))


def test_no_post_offers_an_upgrade(xmb_current):
    b = _tech("zpDisableAllTradeRouteUpgrades")
    assert "<flag>Shadow</flag>" in b and "<dbid>50073</dbid>" in b
    for u in UPG:
        assert ('<effect type="TechStatus" status="unobtainable">%s</effect>' % u) in b, u
    for proto in ("zpOrientalFerry", "zpTradingPostCaptureNaval"):
        listed = [u for u in _proto_techs(proto) if u in UPG]
        assert len(listed) == 22, proto
        for u in listed:
            assert ('<effect type="CommandRemove" tech="%s">\n        <target type="ProtoUnit">%s</target>' % (u, proto)) in b, (proto, u)
    assert b.count('<target type="ProtoUnit">TradingPost</target>') == 31
    for keep in ("deTradeRouteCaptureableEuropean", "ypTradeRouteCaptureable", "deTradeRouteCaptureableAfrican"):
        assert keep not in b.split("-->", 1)[1], keep                    # the capture (resource) techs stay
    xmb_current("data/techtreemods.xml")


def test_st_pauls_and_minster_route_techs(xmb_current):
    for name, dbid, icon, proto in (("zpLondonDeptfordStation", 50074, "trains" + chr(92) + "train_europe_icon.png", "zpSPCLondonBasilica"),
                                    ("zpLondonEastIndiaCompany", 50075, "trade" + chr(92) + "trade_fluyt_icon.png", "zpSPCMinster")):
        b = _tech(name)
        for line in ("<dbid>%d</dbid>" % dbid, '<cost resourcetype="Wood">300.0000</cost>', '<cost resourcetype="Gold">400.0000</cost>',
                     "<researchpoints>60.0000</researchpoints>", "<status>OBTAINABLE</status>", '<techstatus status="Active">Industrialize</techstatus>'):
            assert line in b, (name, line)
        assert b.count(icon) == 1 and "<effects>" not in b, name              # no effect of its own: the triggers raise the route
        assert name in _proto_techs(proto), (proto, name)
    s = _text(REPO / "data/strings/english/stringmods.xml")
    assert '<string _locid="503594">London Deptford Station</string>' in s and '<string _locid="503596">East India Trading Company</string>' in s
    xmb_current("data/protomods.xml")


def test_london_capture_type_levels_and_route_triggers(steam_twin):
    t = _text(LONDON)
    assert 'rmSetMapType("euroTradeRouteCapture");' in t and 'rmSetMapType("euroTradeRouteUpgradeAll")' not in t
    assert t.count('rmSetTriggerEffectParam("TechID", "cTechzpDisableAllTradeRouteUpgrades");') == 1
    for trig, tech, route in (("London_Deptford_Plr", "cTechzpLondonDeptfordStation", 2), ("London_EastIndia_Plr", "cTechzpLondonEastIndiaCompany", 1)):
        i = t.index('rmSwitchToTrigger(rmTriggerID("%s" + k));' % trig)
        b = t[i:t.index("rmSetTriggerLoop(false);", i)]
        for line in ('rmSetTriggerConditionParam("TechID", "%s");' % tech, 'rmSetTriggerEffectParamInt("TradeRoute", %d);' % route,
                     'rmSetTriggerEffectParamInt("Level", 2);', "if (i != k)", 'rmSetTriggerEffectParamInt("Status", 0);',
                     'rmSetTriggerEffectParamInt("EventID", rmTriggerID("%s" + i));' % trig):
            assert line in b, (trig, line)
        assert ('rmCreateTrigger("%s" + k);' % trig) in t and t.index('rmCreateTrigger("%s" + k);' % trig) < i
    steam_twin(LONDON, "00000_zplondon.xs")


def test_istanbul_naval_routes_level_one_not_improvable(steam_twin):
    t = _text(ISTANBUL)
    a = t.index('rmCreateTrigger("Starting Techs");')
    b = t[a:t.index("rmSetTriggerLoop(false);", a)]
    assert 'rmSetTriggerEffectParam("TechID", "cTechzpDisableAllTradeRouteUpgrades");' in b
    for r in (1, 2):
        assert ('rmAddTriggerEffect("Trade Route Set Level");\n\trmSetTriggerEffectParamInt("TradeRoute", %d);\n\trmSetTriggerEffectParamInt("Level", 1);' % r) in b
    assert t.count("rmCreateTradeRoute()") == 2 and t.index("int tradeRouteN = rmCreateTradeRoute();") < t.index("int tradeRouteS = rmCreateTradeRoute();")
    steam_twin(ISTANBUL, "000_istanbul.xs")
