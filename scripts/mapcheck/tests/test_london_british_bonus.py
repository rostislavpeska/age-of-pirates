"""London's British compensation (owner 2026-11-11: "I see British on the London map have a bit disadvantage, because their
manor houses are not working... Ones can have +10 max pop, the others can have increased own natives build limits. ...
Civ bonus should use something similar - also green, but should display only to British"; "a tech changing the rollover
instead of inventing new big button techs", "low risk solutions", "triggers just surgically if necessary").

  - the rollover: zpLondonSetup (London only, every player) re-texts the two big buttons with reqtech="Age0British", vanilla's
    civ-gated rename (SetName tech="DEHCREVMilitaryFrontier" newrollover="80925" reqtech="Age0Russian"); the owner's test as
    Spanish showed the plain text;
  - the bonus is NEVER an effect on a visible tech: the owner's test as Spanish (2026-11-11) showed the button's automatic
    effect list printing a reqtech-gated "Player: Adds 10 to Population Cap." to a non-British player. It sits in two
    shadows - zpLondonBritishPopulation (+10 PopulationCapExtra), zpLondonBritishBuildLimits (+50%: Redcoat 13+7, Lord 2+1,
    Ironside 10+5, Bonaght 15+7, Welsh Longbowman 15+7) - fired once by zplondon.xs 14.1d "London British Bonus"+k:
    civ British AND the side's button researched."""
from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
LONDON = REPO / "randmaps/zplondon.xs"
GATE = 'reqtech="Age0British"'
GREEN = "&lt;color=0.0, 1.0, 0.0&gt;Civ Bonus (British):&lt;/color&gt;"
VISIBLE = ("zpStuartExpansionSPC", "zpParliamentRemonstrance", "zpConsulateParliamentCromwell",
           "zpConsulateParliamentInchiquin", "zpConsulateParliamentMyddelton")


def _text(p: Path) -> str:
    return p.read_bytes().decode("utf-8").replace(chr(13), "")


def _techs() -> str:
    return _text(REPO / "data/techtreemods.xml")


def _tech(name: str) -> str:
    m = re.search(r'<tech name ?= ?"%s"[^>]*>.*?</tech>' % name, _techs(), re.S)
    assert m, name
    return m.group(0)


def _string(locid: str) -> str:
    m = re.search(r'<string _locid="%s">(.*?)</string>' % locid, _text(REPO / "data/strings/english/stringmods.xml"))
    assert m, locid
    return m.group(1)


def _code(t: str) -> str:
    return chr(10).join(l for l in t.split(chr(10)) if not l.strip().startswith("//"))


class TestRollover:
    def test_british_rollover_in_the_london_setup_only(self):
        b = _tech("zpLondonSetup")
        assert '<effect type="SetName" tech="zpStuartExpansionSPC" newname="503549" newrollover="503680" %s>' % GATE in b
        assert '<effect type="SetName" tech="zpParliamentRemonstrance" newname="503478" newrollover="503681" %s>' % GATE in b
        assert _techs().count(GATE) == 2 and "<tech>Age0British</tech>" in _text(REPO / "scripts/source/civs.xml")
        assert "<displaynameid>503549</displaynameid>" in _tech("zpStuartExpansionSPC")
        assert "<displaynameid>503478</displaynameid>" in _tech("zpParliamentRemonstrance")

    def test_green_civ_bonus_line_after_the_original_text(self):
        assert _string("503680") == _string("503582") + " \\n" + GREEN + " \\n • +10 maximum population"
        assert _string("503681") == _string("503479") + " \\n" + GREEN + " \\n • Parliamentarian units +50% build limit"
        assert "<rollovertextid>503582</rollovertextid>" in _tech("zpStuartExpansionSPC")
        assert "<rollovertextid>503479</rollovertextid>" in _tech("zpParliamentRemonstrance")


class TestBonusShadows:
    def test_no_bonus_on_a_visible_tech(self):
        for name in VISIBLE:
            b = _tech(name)
            assert "Age0British" not in b and "PopulationCapExtra" not in b and "zpLondonBritish" not in b, name

    def test_shadows(self):
        pop, lim = _tech("zpLondonBritishPopulation"), _tech("zpLondonBritishBuildLimits")
        assert re.search(r'<effect type="Data" amount="10.00" subtype="PopulationCapExtra" relativity="Absolute">\s*<target type="Player">', pop)
        units = _text(REPO / "data/protomods.xml")
        for unit, add in (("zpNatRedcoat", 7), ("zpNatLord", 1), ("zpNatIronside", 5), ("zpNatBonaght", 7), ("zpNatWelshLongbowman", 7)):
            base = int(re.search(r'<unit[^>]*name="%s"[^>]*>.*?<buildlimit>(\d+)</buildlimit>' % unit, units, re.S | re.I).group(1))
            assert base + add == round(base * 1.5), (unit, base, add)
            assert re.search(r'<effect type="Data" amount="%d.00" subtype="BuildLimit" relativity="Absolute">\s*'
                             r'<target type="ProtoUnit">%s</target>' % (add, unit), lim), unit
        for b in (pop, lim):
            assert "<flag>Shadow</flag>" in b and "YPInfiniteTech" not in b and "<displaynameid>" not in b


class TestTrigger:
    def test_one_trigger_civ_british_and_the_sides_button(self, steam_twin):
        t = _code(_text(LONDON))
        i = t.index('rmCreateTrigger("London British Bonus" + k);')
        s = t[i:t.index("rmSetTriggerLoop(false);", i) + len("rmSetTriggerLoop(false);")]
        att, dfd = s[s.index("if (rmGetPlayerTeam(k) == 0)"):s.index("else")], s[s.index("else"):]
        assert 'rmSetTriggerConditionParam("Civilization", "British");' in s and "rmSetTriggerActive(true);" in s
        assert 'rmAddTriggerCondition("ZP Tech Status Equals (XS)");' in att and '"cTechzpStuartExpansionSPC"' in att
        assert '"cTechzpLondonBritishPopulation"' in att and "Parliament" not in att
        # the condition "Activate Parliament" (14.2) uses for the same button
        assert 'rmAddTriggerCondition("ZP Tech Researching (XS)");' in dfd and '"cTechzpParliamentRemonstrance"' in dfd
        assert '"cTechzpLondonBritishBuildLimits"' in dfd and "Stuart" not in dfd
        assert t.count('"cTechzpLondonBritishPopulation"') == 1 and t.count('"cTechzpLondonBritishBuildLimits"') == 1
        steam_twin(LONDON, "00000_zplondon.xs")

    def test_xmb_and_language_twins_current(self, xmb_current, language_twins_current):
        xmb_current("data/techtreemods.xml")
        language_twins_current()
