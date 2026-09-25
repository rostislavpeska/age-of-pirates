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


@pytest.mark.local("steam")
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


class TestKingsHillHelpers:
    """ypKOTHInclude.xs (vanilla, Game/RandMaps): ypKingsHillPlacer(x, y, walk, extra) builds object def 'KingsHill'
    (item ypKingsHill; max distance rmXFractionToMeters(walk); 8 constraints incl. 'kings hill avoids impassable
    land' Land 4 m, 'kings hill avoids TCs' 45 m, the trade route 6 m) and places it at (x, y) for gaia;
    ypKingsHillLandfill(x, y, size, height, mix, extra) builds area 'hill placer' (coherence 0.9, base height,
    mix, smooth 5). mapsim listed the placer as a no-op and did not know the landfill (2026-09-25 feedback item 2:
    the hill was never drawn or checked)."""

    SRC = HEADER + ('rmTerrainInitialize("water", 0.0); rmSetSeaLevel(1.0);\n'
                    'ypKingsHillLandfill(0.4, 0.6, 0.01, 2.0, "borneo_sand_a", 0);\n'
                    'ypKingsHillPlacer(0.4, 0.6, 0.05, 0); }')

    def test_placer_places_the_hill(self):
        ex = run_src(self.SRC, Scenario(2, 2, koth=True))
        defs = [d for d in ex.defs.values() if d.name == "KingsHill"]
        assert len(defs) == 1 and [p for p, _ in defs[0].items] == ["ypKingsHill"]
        assert defs[0].max_dist == pytest.approx(0.05 * 400)
        assert "kings hill avoids TCs" in defs[0].constraints and len(defs[0].constraints) == 8
        pl = [p for p in ex.placements if p.name == "KingsHill"]
        assert len(pl) == 1 and (pl[0].x, pl[0].z) == (0.4, 0.6)
        assert not [w for w in ex.warnings if "ypKingsHill" in w]

    def test_landfill_builds_the_hill_placer_area(self):
        ex = run_src(self.SRC, Scenario(2, 2, koth=True))
        a = [a for a in ex.areas.values() if a.name == "hill placer"]
        assert len(a) == 1
        assert (a[0].x, a[0].z, a[0].base_height, a[0].coherence) == (0.4, 0.6, 2.0, 0.9)
        assert a[0].size_max_frac == pytest.approx(0.01) and a[0].has_paint


class TestKnownEngineCalls:
    """Feedback 2026-09-25 item 3: calls the extractor skipped with an 'unknown function' warning. Each is now
    known: no-ops with a reason, opaque constraints, deterministic reads, arrays and vectors."""

    def test_noops_and_opaque_constraints_warn_nothing(self):
        src = HEADER + ('int a = rmCreateArea("a"); rmSetAreaSize(a, 0.1, 0.1); rmSetAreaLocation(a, 0.5, 0.5);\n'
                        'rmEnableOutlaw("SaloonOutlawPistol"); rmSetAllMapReveal(true);\n'
                        'rmSetAreaTerrainLayerVariance(a, false); rmAddAreaCliffEdgeAvoidClass(a, 1, 5.0);\n'
                        'int d = rmCreateObjectDef("d"); rmSetObjectDefGarrisonStartingUnits(d, true);\n'
                        'rmSetObjectDefGarrisonSecondaryUnits(d, true); rmAddPlayerResource(1, "Food", 100);\n'
                        'rmSetPlayerResource(1, "Wood", 50); rmSetNumberInitialColonies(2);\n'
                        'int ramp = rmCreateCliffRampDistanceConstraint("ramp", a, 10.0);\n'
                        'int low = rmCreateMaxHeightConstraint("low", 4.0);\n'
                        'rmAddObjectDefConstraint(d, ramp); rmAddObjectDefConstraint(d, low);\n'
                        'int t = rmGetTechID("deEUMapSaxony"); }')
        ex = run_src(src)
        assert ex.warnings == []
        assert ex.constraints["ramp"]["kind"] == ex.constraints["low"]["kind"] == "opaque"

    def test_bool_and_vector_arrays_and_normalize(self):
        src = HEADER + ('int b = xsArrayCreateBool(3, false); xsArraySetBool(b, 2, true);\n'
                        'int v = xsArrayCreateVector(2, cOriginVector);\n'
                        'xsArraySetVector(v, 1, xsVectorNormalize(xsVectorSet(3.0, 0.0, 4.0)));\n'
                        'int d = rmCreateObjectDef("d"); rmAddObjectDefItem(d, "Deer", 1, 0);\n'
                        'if (xsArrayGetBool(b, 2)) rmPlaceObjectDefAtLoc(d, 0,\n'
                        '    xsVectorGetX(xsArrayGetVector(v, 1)), xsVectorGetZ(xsArrayGetVector(v, 1)), 1);\n'
                        'if (xsArrayGetSize(v) == 2) rmPlaceObjectDefAtLoc(d, 0, 0.1, 0.1, 1); }')
        ex = run_src(src)
        assert ex.warnings == []
        pl = sorted((round(p.x, 3), round(p.z, 3)) for p in ex.placements)
        assert pl == [(0.1, 0.1), (0.6, 0.8)]

    def test_ffa_closer_area_and_place_at_area_loc(self):
        src = HEADER + ('int a1 = rmCreateArea("near"); rmSetAreaSize(a1, 0.05, 0.05); rmSetAreaLocation(a1, 0.2, 0.2);\n'
                        'int a2 = rmCreateArea("far"); rmSetAreaSize(a2, 0.05, 0.05); rmSetAreaLocation(a2, 0.8, 0.8);\n'
                        'int d = rmCreateObjectDef("d"); rmAddObjectDefItem(d, "Deer", 1, 0);\n'
                        'rmPlaceObjectDefAtAreaLoc(d, 0, rmFindCloserArea(0.3, 0.3, a1, a2), 1);\n'
                        'if (rmGetIsFFA()) rmPlaceObjectDefAtLoc(d, 0, 0.9, 0.1, 1); }')
        ex = run_src(src, Scenario(3, 3))
        assert ex.warnings == []
        assert sorted((p.x, p.z) for p in ex.placements) == [(0.2, 0.2), (0.9, 0.1)]
        assert [(p.x, p.z) for p in run_src(src, Scenario(4, 2)).placements] == [(0.2, 0.2)]

class TestNoBlockScope:
    """XS has no block scope (skills rm-objects-herds, rm-skeleton): a variable declared in a branch that did not
    run still exists, at zero. zpeyrebasin.xs declares ControllerLoc2 only for 4+ players and builds pirate_site2 at
    it for every player count; the extractor warned 'unknown variable' and lost the area's location."""

    SRC = HEADER + ('if (cNumberNonGaiaPlayers >= 4) {\n'
                    '   vector loc2 = xsVectorSet(200.0, 0.0, 100.0);\n'
                    '   int flag2 = 7;\n'
                    '}\n'
                    'int site = rmCreateArea("site2"); rmSetAreaSize(site, 0.01, 0.01);\n'
                    'rmSetAreaLocation(site, rmXMetersToFraction(xsVectorGetX(loc2)), '
                    'rmZMetersToFraction(xsVectorGetZ(loc2))); rmBuildArea(site); }')

    def test_undeclared_branch_variable_is_zero(self):
        ex = run_src(self.SRC, Scenario(2, 2))
        assert ex.warnings == []
        a = next(a for a in ex.areas.values() if a.name == "site2")
        assert (a.x, a.z) == (0.0, 0.0)

    def test_declared_branch_variable_keeps_its_value(self):
        ex = run_src(self.SRC, Scenario(4, 2))
        a = next(a for a in ex.areas.values() if a.name == "site2")
        assert (a.x, a.z) == (0.5, 0.25)


class TestHalfKnownAnchors:
    """zpnewguinea.xs (every player count) and zplabradorcoast.xs (6 players) crashed mapsim with a TypeError: an
    anchor with a literal x and a runtime z reached the geometry code as (0.5, None)."""

    SRC = HEADER + ('float zr = rmRandFloat(0.3, 0.6);\n'
                    'int c = rmCreateArea("center"); rmSetAreaSize(c, 0.04, 0.04); rmSetAreaLocation(c, 0.5, zr);\n'
                    'rmBuildArea(c);\n'
                    'int d = rmCreateObjectDef("stopper"); rmAddObjectDefItem(d, "Deer", 1, 0);\n'
                    'rmPlaceObjectDefAtLoc(d, 0, 0.29, rmPlayerLocZFraction(3), 1); }')

    def test_random_axis_takes_the_middle_and_unknown_axis_makes_it_runtime(self):
        from scripts.mapsim.bridge import extraction_to_resolved
        from scripts.mapsim.checks import run_checks
        rs = extraction_to_resolved(run_src(self.SRC, Scenario(6, 2)))
        a = next(a for a in rs.areas if a.name == "center")
        assert (a.x, round(a.z, 3), a.approx) == (0.5, 0.45, True)
        p = next(p for p in rs.placements if p.name == "stopper")
        assert (p.x is None) == (p.z is None)
        run_checks(rs)                      # no TypeError


class TestNominalArmStateWins:
    """zpzealand.xs 479-511: bonusVariation = rmRandInt(1,2); the bonus island's location is set in both arms of
    `if (bonusVariation == 1)` and the KotH hill likewise. The extractor ran both arms with LAST write winning for
    state (the else arm's island at (0.6, 0.0)) but recorded the NOMINAL (then) arm's placements (hill at (0.4,
    0.9)): the hill stood in open sea, KOTH_NO_LAND / CONSTRAINT_UNSAT. The live KotH capture (6p) shows the hill on
    a 2 321-tile island. State now follows the nominal arm too."""

    SRC = HEADER + ('int v = rmRandInt(1, 2);\n'
                    'int isle = rmCreateArea("bonus island"); rmSetAreaSize(isle, 0.02, 0.02);\n'
                    'if (v == 1) rmSetAreaLocation(isle, 0.4, 1.0); else rmSetAreaLocation(isle, 0.6, 0.0);\n'
                    'rmBuildArea(isle);\n'
                    'int d = rmCreateObjectDef("hill"); rmAddObjectDefItem(d, "ypKingsHill", 1, 0);\n'
                    'if (v == 1) rmPlaceObjectDefAtLoc(d, 0, 0.4, 0.9, 1); else rmPlaceObjectDefAtLoc(d, 0, 0.6, 0.1, 1); }')

    def test_area_state_follows_the_nominal_arm(self):
        from scripts.mapsim.bridge import extraction_to_resolved
        rs = extraction_to_resolved(run_src(self.SRC))
        isle = next(a for a in rs.areas if a.name == "bonus island")
        hill = next(p for p in rs.placements if p.name == "hill")
        assert (isle.x, isle.z) == (0.4, 1.0) and (hill.x, hill.z) == (0.4, 0.9)


class TestContinue:
    """`continue` was read as a bare name and ignored; zplondon.xs filler() (`if (taken) continue;`) then placed the
    Academy on the first cell of each range whether taken or not (twin on the live London save: 11 groupings
    MISSING instead of 2)."""

    def test_continue_skips_to_the_next_iteration(self):
        src = HEADER + ('int d = rmCreateObjectDef("d"); rmAddObjectDefItem(d, "Deer", 1, 0);\n'
                        'for (i = 0; < 3) { if (i < 2) continue; rmPlaceObjectDefAtLoc(d, 0, 0.1 * i, 0.5, 1); } }')
        ex = run_src(src)
        assert [(round(p.x, 2), p.z) for p in ex.placements] == [(0.2, 0.5)] and ex.warnings == []


class TestArrayWrittenAtRuntimeIndex:
    """zplondon.xs marks shuffled city cells taken with xsArraySetBool(gCityLocsStatus, <runtime index>, true); the
    extractor dropped writes at runtime indices, so filler() saw every cell free. A write at a runtime index could
    hit any element: every later read of that array is runtime."""

    def test_reads_after_a_runtime_index_write_are_runtime(self):
        src = HEADER + ('int s = xsArrayCreateBool(4, false); xsArraySetBool(s, rmRandInt(0, 3), true);\n'
                        'int d = rmCreateObjectDef("d"); rmAddObjectDefItem(d, "Deer", 1, 0);\n'
                        'if (xsArrayGetBool(s, 0) == false) rmPlaceObjectDefAtLoc(d, 0, 0.1, 0.1, 1); }')
        ex = run_src(src)
        assert [p.nominal for p in ex.placements] == [True] and ex.placements[0].variant != ""


class TestSectionSpacing:
    """rmPlacePlayersCircular inside a placement SECTION spaces the players from end to end. Measured against the
    census of live editor saves (6 players, 2 teams): Dead Sea (0.2-wide team sections) ~35 deg between teammates,
    Eyre Basin (0.25) 43-44 deg, Black Sea (0.182) 33-36 deg; mapsim spaced them width / n (24, 30, 22 deg)."""

    def test_team_section_endpoints_included(self):
        import math
        from scripts.mapsim.xs_extract import ring_positions
        src = HEADER + ('rmSetPlacementTeam(0); rmSetPlacementSection(0.7, 0.9); rmPlacePlayersCircular(0.37, 0.37, 0);\n'
                        'rmSetPlacementTeam(1); rmSetPlacementSection(0.2, 0.4); rmPlacePlayersCircular(0.37, 0.37, 0); }')
        ex = run_src(src, Scenario(6, 2))
        pos = ring_positions(ex.player_events, 6, 2)
        def frac(p):
            return (math.atan2(p[0] - 0.5, p[1] - 0.5) / (2 * math.pi)) % 1.0
        fr = sorted(round(frac(p), 3) for p in pos)
        assert fr == [0.2, 0.3, 0.4, 0.7, 0.8, 0.9]

    def test_full_ring_stays_even(self):
        import math
        from scripts.mapsim.xs_extract import ring_positions
        ex = run_src(HEADER + 'rmPlacePlayersCircular(0.37, 0.37, 0); }', Scenario(4, 2))
        pos = ring_positions(ex.player_events, 4, 2)
        fr = sorted(round((math.atan2(p[0] - 0.5, p[1] - 0.5) / (2 * math.pi)) % 1.0, 3) for p in pos)
        assert fr == [0.0, 0.25, 0.5, 0.75]
