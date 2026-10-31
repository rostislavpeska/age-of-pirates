"""Known-value and property tests for the unit conversion calculator.

Expected values come from docs/plan_map_spawn_simulator.md section 3; each
known-value row was independently recomputed by the plan's citations auditor.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapsim.units import INDEPENDENCE_WAR_LADDER, MapGrid  # noqa: E402


GRID_400 = MapGrid(400.0, 400.0)
GRID_660 = MapGrid(660.0, 660.0)


class TestKnownValues:
    def test_tiles_to_frac_elbe_dock_offset_at_400(self):
        # 000_Elbe.xs:527 places dock cliffs at 0.5 +/- rmXTilesToFraction(22);
        # at the 2p map (400 m) that is exactly 44/400.
        assert GRID_400.x_tiles_to_frac(22) == pytest.approx(0.11, abs=1e-12)

    def test_tiles_to_frac_at_660(self):
        assert GRID_660.x_tiles_to_frac(22) == pytest.approx(44.0 / 660.0, rel=1e-12)
        assert GRID_660.x_tiles_to_frac(22) == pytest.approx(0.066667, abs=5e-7)

    def test_grid_dimensions(self):
        assert GRID_400.tiles_x == 200
        assert GRID_400.total_tiles == 40_000
        assert GRID_660.tiles_x == 330
        assert GRID_660.total_tiles == 108_900

    def test_area_700_tiles_at_2p(self):
        frac = GRID_400.area_tiles_to_frac(700)
        assert frac == pytest.approx(0.0175, abs=1e-12)
        assert GRID_400.area_frac_to_radius_frac_x(frac) == pytest.approx(math.sqrt(0.0175 / math.pi), rel=1e-12)
        assert GRID_400.area_frac_to_radius_frac_x(frac) == pytest.approx(0.0746353, abs=5e-7)
        assert GRID_400.area_frac_to_radius_m(frac) == pytest.approx(29.85, abs=5e-3)

    def test_literal_fraction_islands(self):
        # The 0.33-fraction player islands (000_independence_war.xs:402).
        assert GRID_400.area_frac_to_radius_m(0.33) == pytest.approx(129.64, abs=5e-3)
        assert GRID_660.area_frac_to_radius_m(0.33) == pytest.approx(213.91, abs=5e-3)

    def test_guide_erratum_6620_is_wrong(self):
        # guide:6620 claims 400 area tiles is ~20x20 m; actually 1600 m^2 = 40x40 m.
        area_m2 = GRID_400.area_frac_to_m2(GRID_400.area_tiles_to_frac(400))
        assert area_m2 == pytest.approx(1600.0, rel=1e-12)
        assert math.sqrt(area_m2) == pytest.approx(40.0, rel=1e-12)


class TestInvariants:
    def test_tiles_area_radius_is_map_size_invariant(self):
        for tiles in (300, 700, 1100, 2700):
            r400 = GRID_400.area_frac_to_radius_m(GRID_400.area_tiles_to_frac(tiles))
            r660 = GRID_660.area_frac_to_radius_m(GRID_660.area_tiles_to_frac(tiles))
            direct = GRID_400.area_tiles_to_radius_m(tiles)
            assert r400 == pytest.approx(r660, rel=1e-12)
            assert r400 == pytest.approx(direct, rel=1e-12)

    @pytest.mark.parametrize("grid", [GRID_400, MapGrid(500.0, 500.0), MapGrid(600.0, 600.0), GRID_660])
    def test_round_trip_frac_meters(self, grid):
        # approx, not ==: (f*S)/S != f in IEEE doubles for many f at S=400/660.
        for i in range(0, 101):
            f = i / 100.0
            assert grid.x_m_to_frac(grid.x_frac_to_m(f)) == pytest.approx(f, rel=1e-12, abs=1e-15)
            assert grid.z_m_to_frac(grid.z_frac_to_m(f)) == pytest.approx(f, rel=1e-12, abs=1e-15)

    def test_totals(self):
        for grid in (GRID_400, GRID_660):
            assert grid.area_tiles_to_frac(grid.total_tiles) == pytest.approx(1.0, rel=1e-12)
            assert grid.x_tiles_to_frac(grid.tiles_x) == pytest.approx(1.0, rel=1e-12)
            assert grid.z_tiles_to_frac(grid.tiles_z) == pytest.approx(1.0, rel=1e-12)


class TestLadder:
    @pytest.mark.parametrize(
        ("players", "size_m"),
        [(2, 480.0), (3, 600.0), (4, 600.0), (5, 720.0), (6, 720.0), (7, 792.0), (8, 792.0)],
    )
    def test_independence_war_ladder(self, players, size_m):
        grid = MapGrid.for_players(players)
        assert grid.size_x_m == size_m
        assert grid.size_z_m == size_m

    def test_ladder_is_the_documented_default(self):
        assert MapGrid.for_players(2, INDEPENDENCE_WAR_LADDER).size_x_m == 480.0

    def test_invalid_player_count(self):
        with pytest.raises(ValueError):
            MapGrid.for_players(0)


class TestAnisotropy:
    def test_linear_conversions_use_their_own_axis(self):
        grid = MapGrid(400.0, 800.0)
        assert grid.x_tiles_to_frac(10) == pytest.approx(0.05, rel=1e-12)
        assert grid.z_tiles_to_frac(10) == pytest.approx(0.025, rel=1e-12)
        assert grid.x_frac_to_m(0.5) == pytest.approx(200.0, rel=1e-12)
        assert grid.z_frac_to_m(0.5) == pytest.approx(400.0, rel=1e-12)

    def test_area_radius_uses_both_axes(self):
        # sqrt(f * Sx * Sz / pi), not an X-only formula.
        grid = MapGrid(400.0, 800.0)
        expected = math.sqrt(0.1 * 400.0 * 800.0 / math.pi)
        assert grid.area_frac_to_radius_m(0.1) == pytest.approx(expected, rel=1e-12)
        assert grid.area_frac_to_radius_frac_x(0.1) == pytest.approx(expected / 400.0, rel=1e-12)
        assert grid.area_frac_to_radius_frac_z(0.1) == pytest.approx(expected / 800.0, rel=1e-12)

    def test_frac_dist_scales_each_axis(self):
        grid = MapGrid(400.0, 800.0)
        assert grid.frac_dist_m(0.0, 0.0, 0.1, 0.1) == pytest.approx(math.hypot(40.0, 80.0), rel=1e-12)


class TestSignsAndFailures:
    def test_signed_linear_offsets_allowed(self):
        # The 0.5 - rmXTilesToFraction(22) idiom (000_Elbe.xs:527).
        assert GRID_400.x_tiles_to_frac(-22) == pytest.approx(-0.11, abs=1e-12)
        assert GRID_400.x_m_to_frac(-35.0) == pytest.approx(-0.0875, rel=1e-12)

    @pytest.mark.parametrize("bad", [float("nan"), float("inf"), float("-inf")])
    def test_non_finite_raises_everywhere(self, bad):
        with pytest.raises(ValueError):
            MapGrid(bad, 400.0)
        with pytest.raises(ValueError):
            GRID_400.x_tiles_to_frac(bad)
        with pytest.raises(ValueError):
            GRID_400.area_tiles_to_frac(bad)
        with pytest.raises(ValueError):
            GRID_400.frac_dist_m(0.0, 0.0, bad, 0.0)

    def test_non_positive_map_size_raises(self):
        for bad in (0.0, -400.0):
            with pytest.raises(ValueError):
                MapGrid(bad, 400.0)
            with pytest.raises(ValueError):
                MapGrid(400.0, bad)

    def test_negative_area_raises(self):
        with pytest.raises(ValueError):
            GRID_400.area_tiles_to_frac(-5)
        with pytest.raises(ValueError):
            GRID_400.area_frac_to_radius_m(-0.1)
