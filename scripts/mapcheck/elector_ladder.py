"""The Prince Elector site ladder, reverse engineered (owner 2026-10-07: "the Elector system for increasing build limit
needs to be reverse engineered, rebuilt and added to the test suite - if a map has electors, then based on the amount
of settlements").

What the maps build (zpelbe.xs 1730-1768 for 2 castles, zpcrownlands.xs 1643-1762 for 4):
- every elector settlement grouping (Elector_<Name>_0x) holds one zpElectorCenter; claiming the settlement gives the
  player that unit;
- zpElectorSiteIncrease / zpElectorSiteDecrease (data/techtreemods.xml, Shadow + YPInfiniteTech) add / take back one
  step of build limit on the 13 elector units (+9 zpNatLandsknecht, +15 deNatLineInfantry, +11
  deNatMountedInfantryRider, ...);
- per player k, a ladder of triggers counts the zpElectorCenter he owns: "Elector Increase<n><k>" (count >= n,
  n = 2..N) researches Increase and wakes Increase<n+1> and Decrease<n-1>; "Elector Decrease<n><k>" (count <= n,
  n = 1..N-1) researches Decrease and wakes Increase<n+1> and Decrease<n-1>. Only Increase2 starts active; none loops.

A player holding c of the map's N settlements should have max(0, c - 1) steps: the first settlement gives the base
limits, each further one a step. The chain gets that right one settlement at a time, but when two or more change hands
in the same tick a rung re-arms a neighbour of its own direction that already fired, and the change counts twice
(Crownlands 4 -> 0: -3 steps; Independence War's estates 6 -> 0: -10).

Rebuilt (zpdanube.xs zpElectorSiteLadder): one independent toggle per threshold n = 2..N - "Elector Increase<n>"
(count >= n, active at start) wakes only "Elector Decrease<n-1>" (count <= n-1), which wakes only Increase<n>. Toggle
n is up exactly when the count is >= n, whatever the jump. For N = 2 the chain and the toggles are the same pair.

check() replays the ladder the script really built (mapsim records every trigger it executes, loops and ifs resolved)
on walks of the owned count and compares the steps with max(0, c - 1). A map with N >= 2 settlements and no ladder, a
ladder shorter than N, a broken wake-up, or a rung that counts twice all fail.
"""
from __future__ import annotations

import random
import re
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, List

from scripts.mapcheck import triggerdsl as dsl

REPO = Path(__file__).resolve().parents[2]
GROUPINGS = REPO / "game" / "randmaps" / "groupings"
CENTER = "zpElectorCenter"
UP, DOWN = "cTechzpElectorSiteIncrease", "cTechzpElectorSiteDecrease"


@lru_cache(maxsize=None)
def holds_center(grouping: str) -> bool:
    """True when the mod grouping places a zpElectorCenter (vanilla groupings never do)."""
    p = GROUPINGS / f"{grouping}.xml"
    return p.is_file() and re.search(r">\s*%s\s*<" % CENTER, p.read_text(encoding="utf-8", errors="replace")) is not None


def settlement_count(ex) -> int:
    """Elector settlements the script places: nominal placements of groupings that hold a zpElectorCenter."""
    n = 0
    for p in ex.placements:
        d = ex.defs.get(p.def_handle)
        if d is not None and d.is_grouping and p.nominal and holds_center(str(d.proto)):
            n += p.count if isinstance(p.count, int) else 1
    return n


def _to_dsl(t: Dict[str, Any]) -> dsl.Trigger:
    def items(rows):
        return [dsl.Item(r["name"], [dsl.Param(k, v, type(v).__name__) for k, v in r["params"]]) for r in rows]
    return dsl.Trigger(t["name"], items(t["conditions"]), items(t["effects"]), t["priority"], t["active"],
                       t["run_immediately"], t["loop"])


def _rung(t: Dict[str, Any], player: int):
    """(counted proto, tech stem) when the trigger is a site-ladder rung of the player, else None. A rung counts units
    with one "Player Unit Count" and researches a <stem>Increase / <stem>Decrease tech; it belongs to the electors when
    it counts zpElectorCenter (Elbe; Independence War's estates, cTechzpEstateSite*) or researches the elector site
    techs (Crownlands counts its workshops' zpCityStateFlagTeam)."""
    if len(t["conditions"]) != 1 or t["conditions"][0]["name"] != "Player Unit Count":
        return None
    c = dict(t["conditions"][0]["params"])
    techs = [dict(e["params"]).get("TechID") for e in t["effects"] if e["name"] == "ZP Set Tech Status (XS)"
             and dict(e["params"]).get("PlayerID") == player]
    if c.get("PlayerID") != player or len(techs) != 1 or not re.search(r"(Increase|Decrease)$", str(techs[0])):
        return None
    if c.get("ProtoUnit") != CENTER and techs[0] not in (UP, DOWN):
        return None
    return c.get("ProtoUnit"), re.sub(r"(Increase|Decrease)$", "", techs[0])


def ladders(triggers: List[Dict[str, Any]], player: int) -> Dict[tuple, List[dsl.Trigger]]:
    """The player's elector ladders, {(counted proto, tech stem): rungs}. Fire Events to triggers outside the ladder
    are dropped (the simulator models only the ladder); one to a trigger the script never created is kept, so the
    simulation reports it."""
    out: Dict[tuple, List[Dict[str, Any]]] = {}
    for t in triggers:
        key = _rung(t, player)
        if key:
            out.setdefault(key, []).append(t)
    names = {t["name"].replace(" ", "_") for t in triggers}
    res = {}
    for key, rows in out.items():
        mine = {t["name"].replace(" ", "_") for t in rows}
        kept = []
        for t in rows:
            effects = [e for e in t["effects"] if not (e["name"] == "Fire Event" and isinstance(
                dict(e["params"]).get("EventID"), dict) and dict(e["params"])["EventID"]["trigger"] in names - mine)]
            kept.append(_to_dsl(dict(t, effects=effects)))
        res[key] = kept
    return res


def ladder(triggers: List[Dict[str, Any]], player: int) -> List[dsl.Trigger]:
    """Every elector-ladder rung of the player (all ladders together)."""
    return [r for rungs in ladders(triggers, player).values() for r in rungs]


def walks(n: int, seed: int = 7) -> List[List[int]]:
    """Owned-count sequences: climb, fall, jumps both ways, and a seeded random walk."""
    rnd = random.Random(seed)
    out = [list(range(n + 1)), list(range(n, -1, -1)) + [0], [0, n, 0, n], [1, n, 1], [n, 1, n, 0]]
    out.append([rnd.randint(0, n) for _ in range(40)])
    return out


def check(triggers: List[Dict[str, Any]], players: int, settlements: int) -> List[str]:
    """Problems with the ladders of players 1..players for a map with `settlements` elector settlements."""
    if settlements < 2:
        return []
    problems: List[str] = []
    for k in range(1, players + 1):
        found = ladders(triggers, k)
        if not found:
            problems.append(f"player {k}: {settlements} elector settlements but no site ladder")
            continue
        for (proto, stem), rungs in found.items():
            up, down = stem + "Increase", stem + "Decrease"
            for walk in walks(settlements):
                world = dsl.World(units={(k, proto): walk[0]})
                sim = dsl.Sim(rungs, world)
                bad = None
                for step, c in enumerate(walk):
                    world.units[(k, proto)] = c
                    try:
                        sim.settle(2 * settlements + 4)
                    except dsl.DSLError as e:
                        bad = f"player {k} {stem}: {e}"
                        break
                    fired = [t for p, t, s in world.techs if p == k and s == 2]
                    steps = fired.count(up) - fired.count(down)
                    if steps != max(0, c - 1):
                        bad = (f"player {k} {stem} counting {proto}: owning {c} of {settlements} gives {steps} site "
                               f"steps, not {max(0, c - 1)} (owned counts {walk[:step + 1]})")
                        break
                if bad:
                    problems.append(bad)
                    break
    return problems
