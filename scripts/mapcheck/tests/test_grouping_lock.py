"""The fake grouping lock (owner 2026-09-24): 20 gaia zpSPCWaterSpawnPoint placed RIGHT BEFORE the first player's start
units / start grouping prevents the player-selection bug (the 'auto-grouping TC bug'). Each map below carries it once,
before its first start placement; the repo map and its Steam copy stay byte-identical where one is kept."""
from __future__ import annotations

import re
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
R = REPO / "randmaps"
LOCK = re.compile(r'int (\w+) = rmCreateObjectDef\("fake grouping lock"\);')
FIRST = {                                     # map -> its first player start placement (the lock precedes it)
    "zplondon.xs": "rmPlaceGroupingAtLoc(blockPlayerLondon, i,",
    "zpindependencewar.xs": "rmPlaceGroupingAtLoc(playerFortID, i,",
    "zpelbe.xs": "rmPlaceObjectDefAtLoc(TCID, i,",
    "zpistanbulb.xs": "placeCityBlock(blockStartCity, ",
    "zpparis.xs": "rmPlaceObjectDefAtLoc(startID, i,",
    "zpverseilles.xs": "rmPlaceObjectDefAtLoc(startID, i,",
    "zpblacksea.xs": "rmPlaceObjectDefAtLoc(TCID, i,",
    "zpkingofbohemia.xs": "rmPlaceObjectDefAtLoc(TCID, i,",
    "zpcaribbeanwars.xs": "rmPlaceObjectDefAtLoc(TCID, i,",
    "zpvenicecity.xs": "rmPlaceGroupingAtLoc(playerFortID, i,",
}
TWINS = {"zplondon.xs": "00000_zplondon.xs", "zpindependencewar.xs": "000_independence_war.xs", "zpistanbulb.xs": "000_istanbul.xs"}


def _code(p: Path) -> str:
    t = p.read_bytes().decode("utf-8").replace(chr(13), "")
    return chr(10).join(l for l in t.split(chr(10)) if not l.strip().startswith("//"))


@pytest.mark.parametrize("name", sorted(FIRST))
def test_lock_once_right_before_the_first_start_placement(name, steam_twin):
    t = _code(R / name)
    locks = LOCK.findall(t)
    assert len(locks) == 1, (name, locks)
    v = locks[0]
    place = re.search(r"rmPlaceObjectDefAtLoc\(%s, 0, [^;]+\);" % v, t)
    assert place and ('rmAddObjectDefItem(%s, "zpSPCWaterSpawnPoint", 20, 4.0);' % v) in t, name
    first = t.index(FIRST[name])
    assert place.start() < first, (name, "the lock comes after the first start placement")
    between = t[place.end():first]
    assert not re.search(r"rmPlace(?:GroupingAtLoc|ObjectDefAtLoc)\([A-Za-z0-9_]+, i,", between), name
    if name in TWINS:
        steam_twin(R / name, TWINS[name])
