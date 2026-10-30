"""A consulate picker shows only its own cards (owner 2026-10-30: "Can we have something like consulate_validation.py
test covering no such issue ever happens?").

The Danube reports of 2026-10-29: an Ottoman player who had revolted to Romania saw vanilla "Russian Allies" among the
Hussite leaders, and a Korean player with the add-on saw the add-on's Japanese Allies in a native picker. The analysis
is docs/consulate-system.md, "Why a foreign card appears in a picker"; this file guards it.

The model, read from the data:
- `ZP Pick Consulate Tech` (uiConsulateUIInSelected) lists every tech the player holds that has the YPConsulateTech
  flag and is obtainable. The list does not belong to a building.
- A map switcher sets one zpTurnConsulate* set active, then opens the picker. A set changes only the techs it names.
- YPInfiniteTech puts a researched or activated card back to obtainable: a card armed once stays in the pool.
- So a picker is clean when its set names every card that can be obtainable at that moment:
  * the cards another set of the same player, on the same map, makes obtainable;
  * the cards a tech outside the sets arms during play (a revolution), or at Age 0 when zpIsPirateMap leaves them on.
Every tech outside the sets that arms a card is listed in ARMED_BY; a new one fails until someone records when it runs.
The Koreans add-on is a separate repository (AGENTS.md rule 15): its cards are pinned in ADDON_*, and the pin is
compared with ../age-of-pirates-koreans where that checkout exists.
"""
from __future__ import annotations

import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from functools import lru_cache
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
ADDON_TECHTREE = REPO.parent / "age-of-pirates-koreans" / "data" / "techtreemods.xml"
BARTOOL = REPO / ".claude" / "skills" / "aoe3de-bar-archives" / "scripts" / "bartool.py"
MAPS = sorted(list((REPO / "randmaps").glob("*.xs")) + list((REPO / "game" / "randmaps").glob("*.xs")))

# The Koreans add-on: its picker cards, and the cards its techs outside the sets arm.
ADDON_CARDS = {"zpBigConsulateJapaneseAllies", "zpBigConsulateAmericans", "zpBigConsulateSPCChina"}
ADDON_ARMS = {"zpKoreanConsulateAllies": {"zpBigConsulateJapaneseAllies", "zpBigConsulateAmericans",
                                          "zpBigConsulateSPCChina", "ypBigConsulateRussians"}}

# Every tech outside the sets that makes a picker card obtainable or active, and when it runs for a human on an AoP map:
#   age0   before zpIsPirateMap: its cards are in the pool unless zpIsPirateMap turns them off
#   play      during the match: its cards can be in the pool when any native picker opens
#   replaced  a revolution whose card an AoP shadow (prereq: the revolution; made obtainable by zpIsPirateMap) turns
#             off on an AoP map, turning the AoP clone on instead
#   never     not on an AoP map (campaign civs and techs); AoP never names it
ARMED_BY = {
    "YPAge0ChineseConsulate": "age0", "YPAge0ChineseClone6": "age0", "ypAge0IndiansConsulate": "age0",
    "YPAge0JapaneseConsulate": "age0",
    "zpKoreanConsulateAllies": "age0",                      # the add-on, from zpAge0Korean
    "DERevolutionRomania": "replaced",                      # ypBigConsulateRussians active: Ottomans, Russians
    "DERevolutionChile": "replaced",                        # ypBigConsulateGermans active: Spanish
    "zpRevolutionRomaniaPirateMap": "play",                 # their AoP-map swaps: the clone active
    "zpRevolutionChilePirateMap": "play",
    "YPAge0ChineseSPCConsulate": "never", "YPAge0JapaneseSPCConsulate": "never", "ypAge0IndiansSPCConsulate": "never",
    "ypBigSequester": "never",                              # reached only from campaign techs
}
ARMING = ("obtainable", "active")


def _parse(root) -> dict:
    """tech name -> (flags, [(status lowercased, target)]) of every TechStatus effect"""
    out = {}
    for t in root.iter("tech"):
        name = t.get("name")
        if name:
            flags = {f.text.strip() for f in t.findall("flag") if f.text}
            effects = [((e.get("status") or "").lower(), e.text.strip()) for e in t.iter("effect")
                       if e.get("type") == "TechStatus" and e.text and e.text.strip()]
            out[name] = (flags, effects)
    return out


VANILLA = _parse(ET.parse(REPO / "scripts" / "source" / "techtreey.xml").getroot())   # the Oct-2025 snapshot; the
AOP_ROOT = ET.parse(REPO / "data" / "techtreemods.xml").getroot()                      # local test compares it to live
AOP = _parse(AOP_ROOT)
SETS = {n: eff for n, (_, eff) in AOP.items() if n.startswith("zpTurnConsulate")}


def _cards(*techtrees) -> set:
    return {n.lower() for d in techtrees for n, (flags, _) in d.items() if "YPConsulateTech" in flags}


CARDS = _cards(VANILLA, AOP) | {c.lower() for c in ADDON_CARDS}


def _arms(techtrees, cards) -> dict:
    """tech outside the sets -> the cards it makes obtainable or active. A file's record adds to a vanilla record of
    the same name (mergeMode), so the effects of every file count."""
    out = {}
    for d in techtrees:
        for n, (_, eff) in d.items():
            if not n.startswith("zpTurnConsulate"):
                for status, target in eff:
                    if status in ARMING and target.lower() in cards:
                        out.setdefault(n, set()).add(target.lower())
    return out


ARMS = _arms((VANILLA, AOP), CARDS)
for _n, _c in ADDON_ARMS.items():
    ARMS.setdefault(_n, set()).update(c.lower() for c in _c)
PIRATE_MAP_OFF = {t.lower() for st, t in AOP["zpIsPirateMap"][1] if st == "unobtainable"}


def _outside() -> dict:
    """card -> the techs outside the sets that can leave it obtainable when a picker opens"""
    out = {}
    for tech, cards in ARMS.items():
        when = ARMED_BY.get(tech)
        for c in cards:
            if when == "play" or (when == "age0" and c not in PIRATE_MAP_OFF):
                out.setdefault(c, []).append(tech)
    return out


OUTSIDE = _outside()


def _named(s) -> set:
    return {t.lower() for _, t in SETS[s]}


def _gives(s) -> set:
    return {t.lower() for st, t in SETS[s] if st in ARMING and t.lower() in CARDS}


# ---- the map side ---------------------------------------------------------------------------------------------------

TRIGGER = re.compile(r'rm(?:CreateTrigger|SwitchToTrigger)\s*\((?:\s*rmTriggerID\s*\()?\s*(?:"([^"]+)")?')
SET_ON = re.compile(r'"cTech(zpTurnConsulate\w+)"\s*\)\s*;\s*rmSetTriggerEffectParamInt\(\s*"Status"\s*,\s*2\s*\)')
SET_REF = re.compile(r'"cTech(zpTurnConsulate\w+)"')
TEAM_GATE = re.compile(r"if\s*\(\s*rmGetPlayerTeam\(\s*k\s*\)\s*==\s*(\d+)\s*\)\s*\{\s*$")
CIV = re.compile(r'"Civilization"\s*,\s*"(\w+)"')
TECH_GATE = re.compile(r'"ZP Tech Status Equals \(XS\)"\s*\)\s*;(?:(?!rmAddTrigger).)*?"TechID"\s*,\s*"cTech(\w+)"', re.S)
FIRES = re.compile(r'"Fire Event"\s*\)\s*;\s*rmSetTriggerEffectParamInt\(\s*"EventID"\s*,\s*rmTriggerID\(\s*"([^"]+)"')
PICK = '"ZP Pick Consulate Tech"'
COMMENT = re.compile(r'"(?:\\.|[^"\\\n])*"|//[^\n]*|/\*.*?\*/', re.S)   # strings kept, line and block comments dropped
# a shadow tech whose one prereq is Age0<civ> marks that civ (zpAotWKhmers: Age0Khmers, the Khmer gate on Blue Mountains)
CIV_MARKERS = {t.get("name"): req[0][4:] for t in AOP_ROOT.iter("tech") for req in
               [[p.text.strip() for p in t.iter("techstatus") if p.text and (p.get("status") or "").lower() == "active"]]
               if t.get("name") and len(req) == 1 and req[0].startswith("Age0")}


def _rel(p: Path) -> str:
    return p.relative_to(REPO).as_posix()


@lru_cache(maxsize=None)
def _triggers(path: Path) -> tuple:
    """One entry per trigger, its rmCreateTrigger and rmSwitchToTrigger bodies summed (a body runs to the next one):
    the sets it activates, the sets it names at all, the civilizations its conditions require (a "Civilization"
    parameter or a CIV_MARKERS tech), the team an enclosing `if (rmGetPlayerTeam(k) == N) {` gives it, the pickers it
    opens and the triggers it fires. A trigger fired only by gated triggers inherits their gate. Comments are dropped."""
    src = path.read_bytes().decode("utf-8", errors="replace")
    src = COMMENT.sub(lambda m: m.group(0) if m.group(0)[0] == '"' else "", src)   # one pass: "//****" is a line
    heads = list(TRIGGER.finditer(src))
    out = {}
    for i, m in enumerate(heads):
        body = src[m.end():heads[i + 1].start() if i + 1 < len(heads) else len(src)]
        name = (m.group(1) or "#%d" % i).replace(" ", "_")             # rmTriggerID reads spaces as underscores
        t = out.setdefault(name, {"sets": [], "refs": [], "civ": set(), "team": None, "picks": 0, "fires": set()})
        team = TEAM_GATE.search(src[max(0, m.start() - 200):m.start()])
        t["sets"] += SET_ON.findall(body)
        t["refs"] += SET_REF.findall(body)
        t["civ"] |= set(CIV.findall(body)) | {CIV_MARKERS[x] for x in TECH_GATE.findall(body) if x in CIV_MARKERS}
        t["team"] = int(team.group(1)) if team else t["team"]
        t["picks"] += body.count(PICK)
        t["fires"] |= {x.replace(" ", "_") for x in FIRES.findall(body)}
    for _ in range(3):
        for name, t in out.items():
            by = [s for s in out.values() if name in s["fires"]]
            if by and not t["civ"] and all(s["civ"] for s in by):
                t["civ"] = set().union(*(s["civ"] for s in by))
            if by and t["team"] is None and len({s["team"] for s in by}) == 1:
                t["team"] = by[0]["team"]
    return tuple(out.values())


SET_MAPS = [m for m in MAPS if any(t["refs"] for t in _triggers(m))]


def _set_leaks(path: Path) -> list:
    """(civ, team, opening set, card, [sets that left it obtainable]) for every player a map's switchers allow.
    The outside cards are left to test_every_set_turns_off_the_outside_cards."""
    trig = [t for t in _triggers(path) if t["sets"]]
    civs = {c for t in trig for c in t["civ"]} | {None}
    teams = {t["team"] for t in trig} | {None}
    found = []
    for civ in sorted(civs, key=str):
        for team in sorted(teams, key=str):
            mine = [t for t in trig if (not t["civ"] or civ in t["civ"]) and t["team"] in (None, team)]
            fired = {s for t in mine for s in t["sets"] if s in SETS}
            for opening in sorted({s for t in mine if t["picks"] for s in t["sets"] if s in SETS}):
                for card in sorted(set().union(*(_gives(x) for x in fired - {opening})) - _named(opening)):
                    found.append((civ, team, opening, card, sorted(x for x in fired - {opening} if card in _gives(x))))
    return found


# ---- tests ----------------------------------------------------------------------------------------------------------

def test_the_model_sees_the_system():
    assert len(SETS) >= 40 and len(CARDS) >= 119 and len(SET_MAPS) >= 50, (len(SETS), len(CARDS), len(SET_MAPS))
    assert {"ypbigconsulaterussians", "ypbigconsulategermans", "zpbigconsulatejapaneseallies"} <= CARDS
    assert CIV_MARKERS.get("zpAotWKhmers") == "Khmers"


def test_every_tech_that_arms_a_card_is_classified():
    """a new revolution, Age 0 tech or AoP tech that turns a picker card on must say when it runs"""
    assert not set(ARMS) - set(ARMED_BY), "classify in ARMED_BY: %s" % {n: sorted(ARMS[n]) for n in set(ARMS) - set(ARMED_BY)}
    assert not set(ARMED_BY) - set(ARMS), "no longer arms a card, drop from ARMED_BY: %s" % sorted(set(ARMED_BY) - set(ARMS))


def test_never_sources_are_not_used_by_aop():
    aop = (REPO / "data" / "techtreemods.xml").read_bytes().decode("utf-8")
    for tech in sorted(n for n, when in ARMED_BY.items() if when == "never"):
        word = re.compile(r"\b%s\b" % tech)
        assert not word.search(aop), "data/techtreemods.xml names %s" % tech
        assert not [m for m in MAPS if word.search(m.read_bytes().decode("utf-8", errors="replace"))], tech


@pytest.mark.parametrize("tech", sorted(SETS) + ["zpIsPirateMap"], ids=str)
def test_every_name_in_a_set_is_a_real_tech(tech):
    """a misspelt name changes nothing (zpIsPirateMap's ypBigConsulateJapaneseAllies exists nowhere)"""
    known = {n.lower() for n in list(VANILLA) + list(AOP)} | {n.lower() for n in ADDON_CARDS | set(ADDON_ARMS)}
    dead = ["%s %s" % (st, t) for st, t in (SETS.get(tech) or AOP[tech][1]) if t.lower() not in known]
    assert not dead, "%s names techs that do not exist: %s" % (tech, dead)


def test_every_replaced_revolution_has_its_aop_map_swap():
    """on an AoP map a shadow turns the revolution's vanilla card off and its AoP clone on; zpIsPirateMap arms it
    (owner 2026-10-30)"""
    armed = {t for st, t in AOP["zpIsPirateMap"][1] if st == "obtainable"}
    for rev in sorted(n for n, when in ARMED_BY.items() if when == "replaced"):
        swaps = [t for t in AOP_ROOT.iter("tech") if t.get("name") in armed
                 and rev in {(x.text or "").strip() for x in t.findall("prereqs/techstatus") if x.get("status") == "Active"}]
        assert len(swaps) == 1, (rev, [t.get("name") for t in swaps])
        name = swaps[0].get("name")
        off = {t.lower() for st, t in AOP[name][1] if st == "unobtainable"}
        assert ARMS[rev] <= off, "%s leaves %s on" % (name, sorted(ARMS[rev] - off))
        assert ARMED_BY.get(name) == "play" and ARMS.get(name), name


@pytest.mark.parametrize("tech", sorted(s for s in SETS if s.startswith("zpTurnConsulateOff")), ids=str)
def test_every_set_turns_off_the_outside_cards(tech):
    """the revolutions' clones (Romania's Russians, Chile's Germans) are on whatever native picker opens; the On* sets
    fire only for their Asian civ, which never revolts"""
    missing = sorted(set(OUTSIDE) - _named(tech))
    assert not missing, "%s leaves these on: %s" % (tech, {c: OUTSIDE[c] for c in missing})


@pytest.mark.parametrize("path", SET_MAPS, ids=_rel)
def test_no_picker_shows_another_sets_card(path):
    """a card one switcher turned on must be turned off by every other picker the same player can open on that map"""
    leaks = _set_leaks(path)
    assert not leaks, "\n".join("civ %s team %s, %s picker shows %s (from %s)" % (c, t, s, card, ", ".join(src))
                                for c, t, s, card, src in leaks[:20]) + ("\n... %d in all" % len(leaks))


@pytest.mark.parametrize("path", SET_MAPS, ids=_rel)
def test_every_picker_opens_after_a_set(path):
    """a picker opened without a set shows whatever the last one left; a set the data lacks does nothing"""
    for t in _triggers(path):
        assert not t["picks"] or t["sets"], "%s: a ZP Pick Consulate Tech without a set (status 2) in its trigger" % _rel(path)
        assert not set(t["refs"]) - set(SETS), "%s fires unknown sets %s" % (_rel(path), sorted(set(t["refs"]) - set(SETS)))


def test_korea_has_a_switcher_wherever_the_asian_civs_do():
    """with the add-on, a map without `Activate Consulate Korea` gives Korea a consulate button that does nothing
    (Burma's switcher, copied to every map on 2026-10-30)"""
    lacking = [_rel(m) for m in SET_MAPS
               if any(r == "zpTurnConsulateOnJapanese" for t in _triggers(m) for r in t["refs"])
               and not any(r == "zpTurnConsulateOnKorean" for t in _triggers(m) for r in t["refs"])]
    assert not lacking, "%d maps: %s" % (len(lacking), ", ".join(lacking))


def test_the_addon_pin_matches_the_addon():
    """ADDON_CARDS and ADDON_ARMS are what ../age-of-pirates-koreans ships; skipped where that checkout is absent"""
    if not ADDON_TECHTREE.is_file():
        pytest.skip("no %s - the Koreans add-on checkout is on the owner's machine only" % ADDON_TECHTREE)
    addon = _parse(ET.parse(ADDON_TECHTREE).getroot())
    assert {n for n, (flags, _) in addon.items() if "YPConsulateTech" in flags} == ADDON_CARDS
    arms = _arms((addon,), CARDS | _cards(addon))
    assert arms == {n: {c.lower() for c in v} for n, v in ADDON_ARMS.items()}, arms


@pytest.mark.local("steam")
def test_the_vanilla_snapshot_still_matches_the_game():
    """the cards and their arming techs in scripts/source/techtreey.xml are the live game's; after a patch that changes
    them, refresh the snapshot (bar-extract skill, --in-repo) and classify what is new"""
    live = subprocess.run([sys.executable, str(BARTOOL), "cat", "data/techtreey.xml"], capture_output=True, check=True,
                          timeout=120).stdout
    live = _parse(ET.fromstring(live))
    assert _cards(live) == _cards(VANILLA)
    assert _arms((live,), CARDS) == _arms((VANILLA,), CARDS)
