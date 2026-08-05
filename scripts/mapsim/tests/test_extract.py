"""WP4 tests: one micro-case per extraction hazard (normative list:
docs/mapsim_xs_extraction_evidence.json) plus the golden gate — the extractor's
output must diff empty against the curated Independence War scene for every
scenario key — and the bias-guard runs on genuinely stock maps."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapsim.scene import Scenario, Scene  # noqa: E402
from scripts.mapsim.xs_extract import Extractor, Tainted, diff_vs_scene, extract  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\Game\RandMaps")


def run_src(src: str, sc: Scenario = Scenario(2, 2)):
    return Extractor(sc).run(src)


HEADER = "void main(void){ rmSetMapSize(400, 400);\n"


class TestHazardMicrocases:
    def test_h1_reassignment_ladder(self):
        src = ("void main(void){ int size = 400;\n"
               "if (cNumberNonGaiaPlayers >= 3)\n\tsize = 500;\n"
               "if (cNumberNonGaiaPlayers >= 5)\n\tsize = 600;\n"
               "rmSetMapSize(size, size); }")
        assert run_src(src, Scenario(2, 2)).map_size_x == 400
        assert run_src(src, Scenario(4, 2)).map_size_x == 500
        assert run_src(src, Scenario(6, 3)).map_size_x == 600

    def test_h2_player_count_aliases(self):
        src = ("int PlayerNum = cNumberNonGaiaPlayers;\n"
               "void main(void){ int size = 400;\n"
               "if (PlayerNum >= 3) size = 500;\n"
               "rmSetMapSize(size, size); }")
        assert run_src(src, Scenario(5, 2)).map_size_x == 500

    def test_h3_set_area_size_overwrite_last_wins(self):
        src = (HEADER +
               'int a = rmCreateArea("x");\n'
               "rmSetAreaSize(a, rmAreaTilesToFraction(2700), rmAreaTilesToFraction(2700));\n"
               "if (cNumberNonGaiaPlayers >= 3)\n"
               "\trmSetAreaSize(a, rmAreaTilesToFraction(3500), rmAreaTilesToFraction(3500));\n"
               "}")
        ex = run_src(src, Scenario(4, 2))
        area = next(iter(ex.areas.values()))
        assert area.size_max_frac == pytest.approx(3500 / 40000)

    def test_h4_comment_stripping(self):
        src = (HEADER +
               'int a = rmCreateArea("real");//rmCreateArea("fake")\n'
               "/* rmCreateArea(\"dead\");\n   rmSetMapSize(999, 999); */\n"
               "rmSetAreaLocation(a, 0.5, 0.5);// glued//comment\n}")
        ex = run_src(src)
        assert len(ex.areas) == 1
        assert ex.map_size_x == 400

    def test_h5_loop_forms_break_and_leak(self):
        src = (HEADER +
               "int total = 0;\n"
               "for (i = 1; <4) { total = total + 1; }\n"          # 3 iterations
               "for (k = 1; <= 4) { total = total + 1; }\n"        # 4
               "for (j = 0; j < 5; j++) { if (j == 2) break; total = total + 1; }\n"  # 2
               'int probe = rmCreateObjectDef("count "+total+" i "+i);\n}')
        ex = run_src(src)
        d = next(iter(ex.defs.values()))
        # loop variable i leaks its exit value (4) into later names
        assert d.name == "count 9 i 4"

    def test_h6_taint_propagation(self):
        src = (HEADER +
               'int d = rmCreateObjectDef("probe");\n'
               "vector v = rmGetTradeRouteWayPoint(0, 0.5);\n"
               "rmPlaceObjectDefAtLoc(d, 0, rmXMetersToFraction(xsVectorGetX(v)), 0.5);\n}")
        ex = run_src(src)
        p = ex.placements[0]
        assert isinstance(p.x, Tainted)
        assert not isinstance(p.z, Tainted)

    def test_h7_conversions_use_folded_map_size(self):
        src = ("void main(void){ int size = 400;\n"
               "if (cNumberNonGaiaPlayers >= 7) size = 660;\n"
               "rmSetMapSize(size, size);\n"
               'int a = rmCreateArea("x");\n'
               "rmSetAreaLocation(a, 0.5 + rmXTilesToFraction(22), 0.5);\n}")
        assert next(iter(run_src(src, Scenario(2, 2)).areas.values())).x == pytest.approx(0.61)
        assert next(iter(run_src(src, Scenario(8, 4)).areas.values())).x == pytest.approx(0.5 + 44 / 660)

    def test_h8_trailing_comma_tolerated(self):
        src = HEADER + 'rmSetTriggerEffectParamInt("Player2", 3,);\n}'
        assert run_src(src).warnings == []

    def test_h9_two_statements_one_line_duplicate_setter(self):
        src = (HEADER +
               'int d = rmCreateObjectDef("s");\trmSetObjectDefMaxDistance(d, 5.0);\n'
               "\trmSetObjectDefMaxDistance(d, 9.0);\n}")
        assert next(iter(run_src(src).defs.values())).max_dist == 9.0

    def test_h10_raw_backslash_strings(self):
        src = HEADER + 'rmAddAreaTerrainLayer(1, "new_england\\shoreline3_ne", 0, 1);\n}'
        assert run_src(src).warnings == []

    def test_h11_branch_sensitive_waypoints(self):
        src = (HEADER +
               "int tr = rmCreateTradeRoute();\n"
               "if (cNumberNonGaiaPlayers < 3){ rmAddTradeRouteWaypoint(tr, 0.41, 0.3); }\n"
               "else { rmAddTradeRouteWaypoint(tr, 0.4, 0.3); }\n}")
        assert run_src(src, Scenario(2, 2)).waypoints == [(0.41, 0.3)]
        assert run_src(src, Scenario(5, 2)).waypoints == [(0.4, 0.3)]

    def test_h12_tainted_condition_forks_variants(self):
        src = (HEADER +
               "float t = rmRandFloat(0.0, 1.0);\n"
               "if (t > 0.5){ rmPlacePlayer(1, 0.85, 0.55); }\n"
               "else { rmPlacePlayer(1, 0.15, 0.55); }\n}")
        ex = run_src(src)
        events = [e for e in ex.player_events if e["call"] == "rmPlacePlayer"]
        assert len(events) == 2
        assert {e["x"] for e in events} == {0.85, 0.15}
        assert all(e["variant"] for e in events)
        assert events[0]["variant"] != events[1]["variant"]

    def test_h13_function_level_scoping(self):
        src = (HEADER +
               "if (cNumberNonGaiaPlayers < 5)\n"
               "\tint riverID = 7;\n"
               "else\n"
               "\triverID = 9;\n"
               'int d = rmCreateObjectDef("river "+riverID);\n}')
        assert next(iter(run_src(src, Scenario(2, 2)).defs.values())).name == "river 7"
        assert next(iter(run_src(src, Scenario(6, 3)).defs.values())).name == "river 9"


class TestGoldenGate:
    """Plan WP4 mechanical gate: golden diff empty for every scenario key."""

    SCENARIOS = [Scenario(2, 2), Scenario(3, 2), Scenario(5, 2), Scenario(7, 2),
                 Scenario(8, 4), Scenario(8, 8), Scenario(2, 2, koth=True),
                 Scenario(2, 2, nomad=True)]

    @pytest.fixture(scope="class")
    def scene(self):
        return Scene.load(FIXTURES / "independence_war.scene.json")

    @pytest.mark.parametrize("sc", SCENARIOS, ids=lambda s: f"P{s.players}T{s.teams}"
                             + ("k" if s.koth else "") + ("n" if s.nomad else ""))
    def test_golden_diff_empty(self, scene, sc):
        ex = extract(FIXTURES / "independence_war.snapshot.xs", sc)
        assert ex.warnings == []
        assert diff_vs_scene(ex, scene, sc) == []


class TestBiasGuard:
    """Genuinely stock maps (never touched by this mod) must extract."""

    @pytest.mark.skipif(not (GAME / "amazonia.xs").is_file(), reason="game not installed")
    def test_amazonia_extracts(self):
        ex = extract(GAME / "amazonia.xs", Scenario(4, 2))
        # size = 2.0*sqrt(players*playerTiles): the classic stock formula.
        assert ex.map_size_x == pytest.approx(2.0 * (4 * 11000) ** 0.5, rel=1e-6)
        assert len(ex.defs) > 30
        assert len(ex.warnings) <= 2

    @pytest.mark.skipif(not (GAME / "Cascade Range.xs").is_file(), reason="game not installed")
    def test_cascade_range_extracts(self):
        ex = extract(GAME / "Cascade Range.xs", Scenario(4, 2))
        assert ex.map_size_x > 300
        assert len(ex.areas) > 10

    @pytest.mark.skipif(not (GAME / "000_Elbe.xs").is_file(), reason="Elbe not deployed")
    def test_elbe_extracts_warning_free(self):
        ex = extract(GAME / "000_Elbe.xs", Scenario(4, 2))
        assert ex.warnings == []
        assert ex.map_size_x == 500
        assert len(ex.waypoints) == 16
