"""Ship capture (owner 2026-09-25: 'the conversion sucks... it converts harbours and on-shore assets'). Since its 2026-09-10
patch the base game gives most ships ConvertsHerds, so any AutoConvert post, fort or harbour flips to a ship in range.
  - zpLockShipCapture (Shadow): ConvertsHerds 0 on Ship; every mod map activates it for players 1..N in its "Starting Techs"
    (Cold War and Labrador Coast got the trigger; London activates it through zpLondonSetup);
  - the naval-KotH maps unlock instead (zpUnlockNavalKotH, now on Ship too - 'enable globally for all ships'): Black Sea,
    Caribbean Wars and the tiny-island KotH maps ('Some of our maps spawn KotH on a really tiny island') with
    if (rmGetIsKOTH()) unlock else lock in one loop ('if / else will be better'), Istanbul always ('Istanbul only unlocks');
  - zpunknown keeps the base game's rule ('keep unknown' - its variants can have a naval KotH)."""
from __future__ import annotations

import re
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
MAPS = sorted(list((REPO / "randmaps").glob("*.xs")) + list((REPO / "game/randmaps").glob("*.xs")))
KEEP = {"zpunknown.xs"}
UNLOCK_ONLY = {"zpistanbulb.xs"}
IFELSE = {"zpblacksea.xs", "zpcaribbeanwars.xs",                  # naval castle
          "zpeyrebasin.xs", "zpburma_b.xs", "zpdeadsea.xs", "zptorresstrait.xs", "zplabradorcoast.xs", "zpbarrierreef.xs",
          "zpcoldwar.xs"}                                          # KotH on a tiny island (owner 2026-09-25)
DATA_SIDE = {"zplondon.xs"}
LOCKED = [m for m in MAPS if m.name not in KEEP | UNLOCK_ONLY | DATA_SIDE]
TWINS = {"randmaps/zpflorence.xs": "00000_zpflorence.xs", "randmaps/zpverseilles.xs": "00000_zpverseilles.xs",
         "randmaps/zpindependencewar.xs": "000_independence_war.xs", "randmaps/zpistanbulb.xs": "000_istanbul.xs",
         "game/randmaps/zpBalearicIslands.xs": "000zpBalearicIslands.xs", "game/randmaps/zpcoldwar.xs": "zp_coldwar.xs",
         "game/randmaps/zpbluemountains.xs": "zp_z_bluemountains.xs", "game/randmaps/zpzealand.xs": "zp_zealand.xs"}
LOCK = '"TechID","cTechzpLockShipCapture")'
UNLOCK = '"cTechzpUnlockNavalKotH")'
LOOP = re.compile(r'for\s*\(\s*(\w+)\s*=\s*(\d+)\s*;\s*<=\s*cNumberNonGaiaPlayers\s*\)')


def _text(p: Path) -> str:
    return p.read_bytes().decode("utf-8").replace(chr(13), "")


def _tech(name: str) -> str:
    t = _text(REPO / "data/techtreemods.xml")
    a = t.index('<tech name="%s"' % name)
    return t[a:t.index("</tech>", a)]


def _effects(block: str):
    return [(m.group(1), re.sub(r"\s+", " ", m.group(0))) for m in
            re.finditer(r'<effect [^>]*>\s*<target type="ProtoUnit">(\w+)</target>\s*</effect>', block)]


def _starting_techs(t: str) -> str:
    assert t.count('rmCreateTrigger("Starting Techs");') == 1
    a = t.index('rmCreateTrigger("Starting Techs");')
    return t[a:t.index("rmSetTriggerPriority", a)]


def _loop_start_before(seg: str, i: int) -> int:
    """the start value of the last player loop opened before position i (the loop the effect at i sits in)"""
    heads = [m for m in LOOP.finditer(seg) if m.start() < i]
    assert heads, "the effect is not inside a player loop"
    return int(heads[-1].group(2))


def test_lock_tech():
    b = _tech("zpLockShipCapture")
    assert "<status>UNOBTAINABLE</status>" in b and "<flag>Shadow</flag>" in b and "<dbid>50076</dbid>" in b
    assert _effects(b) == [("Ship", '<effect type="Data" amount="0.00" subtype="SetUnitType" unittype="ConvertsHerds" '
                                    'relativity="Assign"> <target type="ProtoUnit">Ship</target> </effect>')]   # DESPCDelugeSetup's form
    t = _text(REPO / "data/techtreemods.xml")
    assert t.index('<tech name="zpLockShipCapture"') < t.index("<!--TEST TECHS-->")


def test_unlock_tech_covers_every_ship():
    got = _effects(_tech("zpUnlockNavalKotH"))
    assert [g[0] for g in got] == ["AbstractWarShip", "Ship"], got
    assert all('amount="1.00"' in e and 'unittype="ConvertsHerds"' in e and 'subtype="SetUnitType"' in e for _, e in got)


def test_london_locks_through_its_setup():
    assert '<effect type="TechStatus" status="active">zpLockShipCapture</effect>' in _tech("zpLondonSetup")
    t = _text(REPO / "randmaps/zplondon.xs")
    assert "zpLockShipCapture" not in t and "zpUnlockNavalKotH" not in t


@pytest.mark.parametrize("path", LOCKED, ids=lambda p: p.name)
def test_every_map_locks_its_players(path: Path):
    t = _text(path)
    s = _starting_techs(t)
    assert s.count(LOCK) == 1, "one lock grant in Starting Techs"
    i = s.index(LOCK)
    assert _loop_start_before(s, i) == 1, "players 1..N only - never gaia"
    assert t.count(LOCK) == 1, "the lock is granted only in Starting Techs"
    if path.name in IFELSE:
        u, e = s.index(UNLOCK), s.index("} else {")
        k = s.index("if (rmGetIsKOTH()) {")
        assert k < u < e < i and _loop_start_before(s, u) == 1, "if (KotH) unlock else lock, in one players loop"
        assert t.count(UNLOCK) == 1 and 'rmCreateTrigger("UnlockNavalKotHTech")' not in t
    else:
        assert "zpUnlockNavalKotH" not in t


def test_istanbul_only_unlocks():
    t = _text(REPO / "randmaps/zpistanbulb.xs")
    s = _starting_techs(t)
    assert s.count(UNLOCK) == 1 and _loop_start_before(s, s.index(UNLOCK)) == 1
    assert "cTechzpLockShipCapture" not in t


def test_unknown_keeps_the_base_game_rule():
    t = _text(REPO / "game/randmaps/zpunknown.xs")
    assert "zpLockShipCapture" not in t and "zpUnlockNavalKotH" not in t


def test_no_stale_premise_left():
    """the old premise ('ZERO of the 149 water protos carry ConvertsHerds') is false since the 2026-09-10 patch"""
    for p in [REPO / "data/techtreemods.xml", REPO / "randmaps/zpistanbulb.xs", REPO / "randmaps/zpblacksea.xs",
              REPO / "randmaps/zpcaribbeanwars.xs"]:
        assert not re.search(r"(?i)zero of\s+(//\s*)?the\s+(//\s*)?149", _text(p)), p.name


def test_techtree_xmb_current(xmb_current):
    xmb_current("data/techtreemods.xml")


@pytest.mark.local("steam")
@pytest.mark.parametrize("rel", sorted(TWINS), ids=lambda r: TWINS[r])
def test_steam_twins(rel, steam_twin):
    steam_twin(REPO / rel, TWINS[rel])
