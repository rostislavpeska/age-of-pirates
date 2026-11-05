"""The Prince Elector site ladder (scripts/mapcheck/elector_ladder.py) on every map with electors.

Owner 2026-10-07: "Elector system for increasing build limit needs to be reverse engineered, rebuilt and added to the
test suite (if map has electors and then based on amount of settlements)". mapsim records every trigger the script
executes; the ladder of each player is replayed on walks of the owned count, and a player holding c of the map's N
settlements must have max(0, c - 1) steps of zpElectorSiteIncrease.

The first run found the 4-castle chain (Crownlands, copied into Unknown) and Independence War's 6-house estate chain
wrong when two or more settlements change hands at once: a rung that wakes the next rung of its own direction re-arms
one that already fired in the same tick, and the change is counted again (4 -> 0 ended at -3 steps, 6 -> 0 at -10).
The Danube's zpElectorSiteLadder() is the rebuilt ladder, one independent toggle per threshold; the three production
maps wait for the owner's word (AGENTS.md rule 9: the fix deletes Fire Events from their rungs).
"""
from __future__ import annotations

import math
import re
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))

from scripts.mapcheck import elector_ladder as L  # noqa: E402
from scripts.mapsim.scene import Scenario  # noqa: E402
from scripts.mapsim.xs_extract import extract  # noqa: E402

DANUBE = REPO / "game" / "randmaps" / "zpdanube.xs"
AWAITING_OWNER = {   # production maps whose ladders miscount a multi-settlement loss (module docstring)
    "zpcrownlands": "4-castle chain re-wakes fired Decrease rungs",
    "zpunknown": "4-castle chain re-wakes fired Decrease rungs",
    "zpindependencewar": "6-house estate chain re-wakes fired Decrease rungs",
}


def _rung(name, player, op, count, tech, wakes, active=False, proto=L.CENTER):
    return {"name": name, "line": 0, "priority": 4, "active": active, "run_immediately": True, "loop": False,
            "conditions": [{"name": "Player Unit Count",
                            "params": [("PlayerID", player), ("ProtoUnit", proto), ("Op", op), ("Count", count)]}],
            "effects": [{"name": "ZP Set Tech Status (XS)", "params": [("PlayerID", player), ("TechID", tech),
                                                                       ("Status", 2)]}]
            + [{"name": "Fire Event", "params": [("EventID", {"trigger": w})]} for w in wakes]}


def ladder(n, players=1, chain=False):
    """The rebuilt ladder for n settlements: one toggle per threshold, Increase<r> (all active) waking only
    Decrease<r-1> and back. chain=True is the Crownlands / Unknown chain: Increase<r> also wakes Increase<r+1>,
    Decrease<r> also wakes Decrease<r-1>, and only Increase2 starts active."""
    out = []
    for k in range(1, players + 1):
        for r in range(2, n + 1):
            wakes = ([f"Elector_Increase{r + 1}{k}"] if chain and r < n else []) + [f"Elector_Decrease{r - 1}{k}"]
            out.append(_rung(f"Elector Increase{r}{k}", k, ">=", r, L.UP, wakes, active=(r == 2 or not chain)))
        for r in range(1, n):
            wakes = [f"Elector_Increase{r + 1}{k}"] + ([f"Elector_Decrease{r - 1}{k}"] if chain and r > 1 else [])
            out.append(_rung(f"Elector Decrease{r}{k}", k, "<=", r, L.DOWN, wakes))
    return out


class TestTheSimulator:
    @pytest.mark.parametrize("n", [2, 3, 4, 5, 6])
    def test_the_rebuilt_ladder_counts_every_walk(self, n):
        assert L.check(ladder(n, players=2), 2, n) == []

    def test_the_crownlands_chain_counts_a_double_loss_twice(self):
        problems = L.check(ladder(4, chain=True), 1, 4)
        assert problems and "owning 0 of 4 gives -3 site steps" in problems[0]

    def test_for_two_settlements_the_chain_and_the_toggles_are_one_ladder(self):
        # Elbe's pair (zpelbe.xs 1730-1768) is both
        assert ladder(2, players=3) == ladder(2, players=3, chain=True)

    def test_a_ladder_shorter_than_the_settlements_fails(self):
        problems = L.check(ladder(2), 1, 4)
        assert problems and "owning 3 of 4" in problems[0]

    def test_settlements_without_a_ladder_fail_and_one_settlement_needs_none(self):
        assert L.check([], 2, 2) == ["player 1: 2 elector settlements but no site ladder",
                                     "player 2: 2 elector settlements but no site ladder"]
        assert L.check([], 2, 1) == []

    def test_a_wake_to_a_missing_rung_fails(self):
        rows = ladder(3)
        rows = [r for r in rows if r["name"] != "Elector Decrease21"]
        assert L.check(rows, 1, 3)


def _helper_source():
    src = DANUBE.read_text(encoding="utf-8")
    m = re.search(r"\nvoid zpElectorSiteLadder\(.*?\n}\n", src.replace("\r\n", "\n"), re.S)
    assert m, "zpElectorSiteLadder() not found above main in zpdanube.xs"
    return m.group(0)


@pytest.mark.parametrize("n", [2, 3, 4, 5, 6])
def test_the_danube_helper_builds_a_correct_ladder_for_any_count(tmp_path, n):
    # the helper is the reusable block: any map with n elector settlements calls zpElectorSiteLadder(n)
    p = tmp_path / "ladder.xs"
    p.write_text(_helper_source() + "void main(void) {\n   rmSetMapSize(400, 400);\n"
                 f"   zpElectorSiteLadder({n});\n}}\n", encoding="utf-8")
    ex = extract(p, Scenario(players=3, teams=2))
    assert len(ex.triggers) == 3 * 2 * (n - 1)          # per player n-1 toggles of two rungs
    assert L.check(ex.triggers, 3, n) == []


def _elector_maps():
    out = []
    for p in sorted(list((REPO / "randmaps").glob("*.xs")) + list((REPO / "game" / "randmaps").glob("*.xs"))):
        src = p.read_text(encoding="utf-8", errors="replace")
        if L.CENTER in src or re.search(r'"Elector_[A-Z]\w+_0\d"', src):
            out.append(p)
    return out


def _cases():
    for p in _elector_maps():
        for players in (2, 4, 6, 8):
            marks = [pytest.mark.xfail(reason=AWAITING_OWNER[p.stem], strict=True)] if p.stem in AWAITING_OWNER else []
            yield pytest.param(p, players, marks=marks, id=f"{p.stem}-{players}p")


@pytest.mark.parametrize("path,players", list(_cases()))
def test_every_elector_map_ladders_its_settlements(path, players):
    ex = extract(path, Scenario(players=players, teams=2))
    assert L.check(ex.triggers, players, L.settlement_count(ex)) == []


class TestDanubeSettlements:
    """Owner 2026-10-07: electors always two (Bavaria, Austria); 1v1 one Hussite and one Orthodox settlement, never
    side by side; Hussite variants from the whole pool, no repeats."""

    @pytest.fixture(scope="class")
    def by_players(self):
        out = {}
        for players in range(2, 9):
            for teams in (2, players):
                out[(players, teams)] = extract(DANUBE, Scenario(players=players, teams=teams))
        return out

    @staticmethod
    def _groupings(ex, prefix):
        rows = []
        for p in ex.placements:
            d = ex.defs.get(p.def_handle)
            if d is not None and d.is_grouping and d.name.startswith(prefix):
                rows.append((str(d.proto), p.x, p.z))
        return rows

    def test_two_electors_bavaria_and_austria_at_every_size(self, by_players):
        for key, ex in by_players.items():
            castles = sorted(g for g, _, _ in self._groupings(ex, "elector castle"))
            assert castles == ["Elector_Austria_02", "Elector_Bavaria_02"], key
            assert L.settlement_count(ex) == 2, key

    def test_two_bridges_and_five_river_sockets_at_every_size(self, by_players):
        # owner 2026-10-07: "I did NOT approve the large bridge on southwest (the tip of the river) - off pattern"
        for key, ex in by_players.items():
            assert sorted(g for g, _, _ in self._groupings(ex, "bridge")) == ["Bridge_Universal_03"] * 2, key
            river = [p for p in ex.placements if ex.defs.get(p.def_handle) is not None
                     and ex.defs[p.def_handle].name.startswith("harbour ")]
            assert len(river) == 5, (key, len(river))

    def test_one_settlement_of_each_in_1v1(self, by_players):
        ex = by_players[(2, 2)]
        assert len(self._groupings(ex, "hussite camp")) == 1
        assert len(self._groupings(ex, "orthodox monastery")) == 1

    def test_hussites_never_beside_the_orthodox(self, by_players):
        # anchors; each settlement may still move 25 m (rmSetGroupingMaxDistance), so 150 m keeps 100 m between them
        for key, ex in by_players.items():
            size = ex.map_size_x
            hus = self._groupings(ex, "hussite camp")
            ort = self._groupings(ex, "orthodox monastery")
            assert len(hus) == len(ort) >= 1, key
            gap = min(math.hypot((hx - ox) * size, (hz - oz) * size) for _, hx, hz in hus for _, ox, oz in ort)
            assert gap >= 150.0, (key, round(gap))

    def test_hussite_variants_come_from_the_whole_pool_without_repeats(self, by_players):
        src = DANUBE.read_text(encoding="utf-8")
        assert "xsArraySetInt(hussitePool, hv, hv+1);" in src and "rmRandInt(hv, 4)" in src
        assert 'rmCreateGrouping("hussite camp "+h, "Hussite_Camp_0"+hussiteCampType)' in src
        assert "hussiteCampType = xsArrayGetInt(hussitePool, h);" in src
        # the shuffle itself, replayed: every rmRandInt outcome gives a permutation of 1..5
        import itertools
        for picks in itertools.product(*[range(hv, 5) for hv in range(4)]):
            pool = [1, 2, 3, 4, 5]
            for hv, pick in enumerate(picks):
                pool[hv], pool[pick] = pool[pick], pool[hv]
            assert sorted(pool) == [1, 2, 3, 4, 5]
