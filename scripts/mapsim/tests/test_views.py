"""One map, one set of codes (2026-09-25, owner: "sometimes we display cliffs, sometimes not, sometimes players,
sometimes not, sometimes groupings, sometimes not"): the comparison view draws the game's own map and mapsim's with the
same renderer; runtime spots picked from a known set stay drawable; random layout choices are named."""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapsim.scene import Scenario  # noqa: E402
from scripts.mapsim.xs_extract import Extractor, OneOf  # noqa: E402

HEADER = "void main(void){ rmSetMapSize(400, 400);\n"

CITY = HEADER + r"""
int cells = xsArrayCreateVector(3, cInvalidVector, "cells");
xsArraySetVector(cells, 0, xsVectorSet(0.2, 0.0, 0.5));
xsArraySetVector(cells, 1, xsVectorSet(0.5, 0.0, 0.5));
xsArraySetVector(cells, 2, xsVectorSet(0.8, 0.0, 0.5));
int j = rmRandInt(0, 2);
vector temp = xsArrayGetVector(cells, 0);
xsArraySetVector(cells, 0, xsArrayGetVector(cells, j));
xsArraySetVector(cells, j, temp);
int block = rmCreateGrouping("house", "EU_House_Block_1");
vector loc = xsArrayGetVector(cells, 1);
rmPlaceGroupingAtLoc(block, 0, xsVectorGetX(loc), xsVectorGetZ(loc));
}
"""


class TestKnownSetPicks:
    """zplondon.xs shuffles its city cells and places blocks at runtime indices; every block lands on ONE of the
    cells. The placement keeps the candidate spots instead of becoming undrawable."""

    def test_a_shuffled_pick_keeps_its_candidates(self):
        ex = Extractor(Scenario(2, 2)).run(CITY)
        p = next(p for p in ex.placements if p.name == "house")
        assert isinstance(p.x, OneOf) and isinstance(p.z, OneOf)
        assert sorted(p.candidates) == [(0.2, 0.5), (0.5, 0.5), (0.8, 0.5)]

    def test_the_candidates_reach_the_resolved_scene(self):
        from scripts.mapsim.bridge import extraction_to_resolved
        rs = extraction_to_resolved(Extractor(Scenario(2, 2)).run(CITY))
        p = next(p for p in rs.placements if p.name == "house")
        assert p.x is None and len(p.candidates) == 3


class TestRandomChoices:
    """London's defenderBank = rmRandInt(0, 1) decides which bank the defenders get; mapsim draws the low roll and
    must say so (the owner saw the walls on the 'enemy' bank)."""

    def test_a_random_if_is_recorded_with_its_nominal_outcome(self):
        src = HEADER + "int bank = rmRandInt(0, 1);\nint side = 0;\nif (bank == 1) side = 2;\n}"
        ex = Extractor(Scenario(2, 2)).run(src)
        assert list(ex.random_choices.values()) == [("(?rmRandInt(0,1) == 1)", False)]

    def test_the_note_names_it(self):
        from types import SimpleNamespace
        from scripts.mapsim.render import random_choice_note
        rs = SimpleNamespace(random_choices={546: ("(?rmRandInt(0,1) == 1)", False), 702: ("(?x)", True)})
        note = random_choice_note(rs)
        assert "line 546" in note and "-> no" in note and "+1 more" in note


def _toy_game(tmp_path):
    from scripts.mapsim.groundtruth import GameGrid, GameMap
    n = 40
    water = [[(i - 20) ** 2 + (j - 20) ** 2 > 12 ** 2 for i in range(n)] for j in range(n)]
    wwalk = [[False] * n for _ in range(n)]
    cliff = [[(i - 20) ** 2 + (j - 20) ** 2 in (16, 17, 18, 20, 25) for i in range(n)] for j in range(n)]
    cells = [(i, j) for j in range(n) for i in range(n) if cliff[j][i]]
    grid = GameGrid(n, n, 2.0, water, wwalk, cliff, [("cliffs", cells)])
    units = [{"proto": "TownCenter", "fx": 0.45, "fz": 0.5, "player": 1},
             {"proto": "SocketTradeRoute", "fx": 0.6, "fz": 0.5, "player": 0}]
    return GameMap(tmp_path / "toy.age3Yscn", 80.0, 80.0, grid, units)


def test_compare_view_draws_both_maps_with_one_renderer(tmp_path):
    pytest.importorskip("matplotlib")
    from scripts.mapsim.bridge import extraction_to_resolved
    from scripts.mapsim.render import render_compare
    src = ("void main(void){ rmSetMapSize(80, 80); rmSetSeaLevel(1.0); rmTerrainInitialize(\"water\");\n"
           "int a = rmCreateArea(\"isle\"); rmSetAreaSize(a, 0.3, 0.3); rmSetAreaLocation(a, 0.5, 0.5);\n"
           "rmSetAreaBaseHeight(a, 2.0); rmSetAreaCoherence(a, 1.0); rmBuildArea(a);\n"
           "rmPlacePlayersCircular(0.1, 0.1, 0.0); }")
    rs = extraction_to_resolved(Extractor(Scenario(2, 2)).run(src))
    out = tmp_path / "cmp.png"
    stats = render_compare(rs, [], _toy_game(tmp_path), out, title="toy")
    assert out.is_file() and out.stat().st_size > 10000
    assert 0.5 < stats["match"] <= 1.0 and stats["tcs"] == 1


GT_CASE = Path(os.environ.get("TEMP", "/tmp")) / "mapsim_night" / "gt" / "zpriverina_P2T2" / "shot.json"


@pytest.mark.skipif(not GT_CASE.is_file(), reason="ground-truth capture not on this machine")
def test_the_save_reader_finds_riverina_river():
    """The live Riverina 2p editor save: a river of deep water with walkable banks crosses the map; the rest is land."""
    from scripts.mapsim.groundtruth import read_game_map
    shot = json.loads(GT_CASE.read_text(encoding="utf-8"))
    g = read_game_map(shot["save"]).grid
    deep = sum(1 for j in range(g.nz) for i in range(g.nx) if g.is_deep(i, j))
    shallow = sum(1 for j in range(g.nz) for i in range(g.nx) if g.water[j][i] and g.wwalk[j][i])
    total = g.nx * g.nz
    assert 0.03 < deep / total < 0.25 and shallow > 0
