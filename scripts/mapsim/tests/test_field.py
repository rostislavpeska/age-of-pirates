"""WP3b tests: evaluable constraints and the deterministic feasibility field.

Mechanical gate from the plan: analytic cases (a disc half-covered by water
must report ~50% allowed) plus field runs on the real scene.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapsim.checks import check_area_feasibility, check_placement  # noqa: E402
from scripts.mapsim.field import (  # noqa: E402
    FieldContext,
    area_allowed_fraction,
    loop_feasibility,
    point_allowed,
    radius_to_tiles,
    split_constraints,
)
from scripts.mapsim.scene import Scenario, Scene  # noqa: E402
from scripts.mapsim.tests.test_checks import area, make_scene, placement  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"
SC = Scenario(2, 2)


class TestPointAllowed:
    def _ctx(self, areas):
        return FieldContext(make_scene(areas=areas).resolve(SC))

    def test_terrain_avoid_land(self):
        # Land disc r=29.85 m at map center (400 m map).
        ctx = self._ctx([area("island", 0.5, 0.5, 700)])
        spec = {"kind": "terrain", "avoid": "land", "distance_m": 11.0}
        assert point_allowed(ctx, (200.0, 200.0 + 29.85 + 11.5), spec) is True
        assert point_allowed(ctx, (200.0, 200.0 + 29.85 + 10.0), spec) is False
        assert point_allowed(ctx, (200.0, 200.0), spec) is False

    def test_terrain_avoid_water(self):
        ctx = self._ctx([area("island", 0.5, 0.5, 700)])
        spec = {"kind": "terrain", "avoid": "water", "distance_m": 10.0}
        assert point_allowed(ctx, (200.0, 200.0), spec) is True          # 29.85 m deep
        assert point_allowed(ctx, (200.0, 200.0 + 25.0), spec) is False  # 4.85 m deep
        assert point_allowed(ctx, (200.0, 300.0), spec) is False         # open water

    def test_class_distance_disc(self):
        scene = make_scene(areas=[dict(area("lake", 0.5, 0.3, 7900, land=False),
                                       classes=["classDeepWater"])])
        ctx = FieldContext(scene.resolve(SC))
        spec = {"kind": "class_distance", "class": "classdeepwater", "distance_m": 20.0}
        r = ctx.class_discs["classdeepwater"][0][2]
        assert point_allowed(ctx, (200.0, 120.0 + r + 21.0), spec) is True
        assert point_allowed(ctx, (200.0, 120.0 + r + 19.0), spec) is False

    def test_class_distance_rect_footprint(self):
        scene = make_scene(placements=[dict(placement("bridge", 0.5, 0.88),
                                            classes=["zpBridgeFace"],
                                            footprint_tiles=[40, 14])])
        ctx = FieldContext(scene.resolve(SC))
        spec = {"kind": "class_distance", "class": "zpbridgeface", "distance_m": 15.0}
        # Footprint: x 160-240 m, z 338-366 m; 15 m margin.
        assert point_allowed(ctx, (200.0, 366.0 + 16.0), spec) is True
        assert point_allowed(ctx, (200.0, 366.0 + 14.0), spec) is False
        assert point_allowed(ctx, (200.0, 352.0), spec) is False

    def test_route_distance(self):
        scene = Scene({
            "config": {"size_ladder": [[1, 400]], "sea_level": 1.0, "world_circle": True},
            "areas": [], "placements": [],
            "trade_route": {"waypoints": [{"point": [0.5, 0.2]}, {"point": [0.5, 0.8]}]},
            "player_placement": {}, "constraints": {},
        })
        ctx = FieldContext(scene.resolve(SC))
        # The constraint measures from the road EDGE: authored distance
        # plus ROUTE_HALF_WIDTH_M (16 m block road / 2).
        spec = {"kind": "route_distance", "distance_m": 10.0}
        assert point_allowed(ctx, (219.0, 200.0), spec) is True
        assert point_allowed(ctx, (217.0, 200.0), spec) is False

    def test_opaque_returns_none(self):
        ctx = self._ctx([])
        assert point_allowed(ctx, (0.0, 0.0), {"kind": "opaque", "desc": "x"}) is None


class TestAnalyticGate:
    def test_half_clipped_disc_reports_half(self):
        # Land edge passes through the test disc's center: a huge land disc
        # (r=1000 m) whose boundary crosses (0.75, 0.5) almost straight.
        land_center_x = 0.75 - 1000.0 / 400.0
        scene = make_scene(areas=[
            dict(area("bigland", land_center_x, 0.5, 0), size={"tiles": radius_to_tiles(1000.0)}),
            # land=False: the patch must not count as land itself, or every
            # cell would trivially satisfy the constraint.
            dict(area("patch", 0.75, 0.5, 700, land=False),
                 constraints=["needLand"]),
        ], constraints={"needLand": {"kind": "terrain", "avoid": "water", "distance_m": 0.0}})
        rs = scene.resolve(SC)
        ctx = FieldContext(rs)
        patch = next(a for a in rs.areas if a.name == "patch")
        af = area_allowed_fraction(ctx, patch, cell_tiles=0.5)
        assert af is not None
        assert af.allowed_fraction == pytest.approx(0.5, abs=0.03)

    def test_unconstrained_area_is_skipped(self):
        rs = make_scene(areas=[area("plain", 0.5, 0.5, 700)]).resolve(SC)
        ctx = FieldContext(rs)
        assert area_allowed_fraction(ctx, rs.areas[0]) is None


class TestPlacementIntegration:
    def test_terrain_constraint_unsat_on_placement(self):
        # A land-avoiding placement pinned (max_dist 0) inside land.
        scene = make_scene(
            areas=[area("island", 0.5, 0.5, 3000)],
            placements=[placement("flag", 0.5, 0.5, affinity="either",
                                  constraints=["flagLand"])],
            constraints={"flagLand": {"kind": "terrain", "avoid": "land", "distance_m": 11.0}},
        )
        rs = scene.resolve(SC)
        p = next(p for p in rs.placements if p.name == "flag")
        f = check_placement(p, rs)
        assert f.verdict == "CONSTRAINT_UNSAT"

    def test_terrain_constraint_sat_with_reach(self):
        # Same, but a 200 m search annulus reaches open water.
        scene = make_scene(
            areas=[area("island", 0.5, 0.5, 3000)],
            placements=[placement("flag", 0.5, 0.5, affinity="either", max_d=200.0,
                                  constraints=["flagLand"])],
            constraints={"flagLand": {"kind": "terrain", "avoid": "land", "distance_m": 11.0}},
        )
        rs = scene.resolve(SC)
        f = check_placement(next(p for p in rs.placements if p.name == "flag"), rs)
        assert f.verdict == "OK"


class TestGrowthLaws:
    """The researched engine model, validated analytically (experiment
    2026-07-30): budget-driven priority flood; the chamfer metric's constant
    ~1.037 free-field distortion cancels in ratios."""

    def _run(self, seeds, budget, allowed):
        from scripts.mapsim.field import priority_flood
        return priority_flood(200, 200, seeds, budget, allowed)

    def _max_r(self, cells, seed):
        import math
        return max(math.hypot(i - seed[0], j - seed[1]) for i, j in cells)

    def test_edge_law_sqrt2(self):
        # The user-observed in-game law: edge-seeded areas grow to sqrt(2) x
        # the free-field radius of the same budget.
        import math
        free = self._max_r(self._run([(100, 100)], 2000, lambda i, j: True), (100, 100))
        edge = self._max_r(self._run([(0, 100)], 2000, lambda i, j: True), (0, 100))
        assert edge / free == pytest.approx(math.sqrt(2), rel=0.02)

    def test_corner_law_2x(self):
        free = self._max_r(self._run([(100, 100)], 2000, lambda i, j: True), (100, 100))
        corner = self._max_r(self._run([(0, 0)], 2000, lambda i, j: True), (0, 0))
        assert corner / free == pytest.approx(2.0, rel=0.02)

    def test_area_conserved_through_gap(self):
        wall = lambda i, j: not (i == 110 and not (95 <= j <= 105))
        cells = self._run([(100, 100)], 2000, wall)
        assert len(cells) == 2000
        assert sum(1 for i, j in cells if i > 110) > 300  # budget flowed through

    def test_keep_partial_on_shortfall(self):
        box = lambda i, j: 90 <= i <= 109 and 90 <= j <= 109
        assert len(self._run([(100, 100)], 2000, box)) == 400

    def test_deterministic(self):
        wall = lambda i, j: not (i == 110 and not (95 <= j <= 105))
        assert self._run([(100, 100)], 2000, wall) == self._run([(100, 100)], 2000, wall)


class TestTerrainGrid:
    """Constraint-derived shapes: the channel and gulf must carve the islands."""

    @pytest.fixture(scope="class")
    def tg(self):
        scene = Scene.load(FIXTURES / "independence_war.scene.json")
        from scripts.mapsim.field import terrain_grid
        return terrain_grid(scene.resolve(SC))

    def test_channel_carves_between_islands(self, tg):
        # (0.5, 0.75) is inside playerIslandNorth's ideal disc but on the
        # river capsule: greatLakesConstraint must carve it to water.
        assert not tg.is_land_frac(0.5, 0.75)
        assert tg.marker[tg.cell_of_frac(0.5, 0.75)[1]][tg.cell_of_frac(0.5, 0.75)[0]]

    def test_island_interiors_are_land(self, tg):
        assert tg.is_land_frac(0.8, 0.85)
        assert tg.is_land_frac(0.2, 0.85)

    def test_estate_valleys_are_land(self, tg):
        assert tg.is_land_frac(0.317, 0.762)

    def test_gulf_is_water(self, tg):
        assert not tg.is_land_frac(0.5, 0.35)

    def test_dock_cliff_is_its_own_area(self, tg):
        # The dock CLIFF RING is the feature (frozen build-time claim);
        # cell OWNERSHIP at the dock may legitimately pass to the later-
        # built playerHills since avoidBridge measures 15 m from the
        # bridge's zpBridgeFace UNITS (type semantics, Part H) — the old
        # ownership assertion relied on a curator shim class the real map
        # never had (rmAddGroupingToClass adds only classPlateau).
        i, j = tg.cell_of_frac(0.61, 0.88)
        assert tg.land[j][i] != 0, "dock site must be land"
        east = next((cells for name, cells in tg.cliff_claims
                     if name == "bridgeDockEast"), None)
        assert east, "bridgeDockEast cliff claim must exist"
        assert any(abs(ci - i) <= 3 and abs(cj - j) <= 3 for ci, cj in east), \
            "dock cliff ring must reach the probe cell's neighborhood"


class TestRealScene:
    @pytest.fixture(scope="class")
    def scene(self):
        return Scene.load(FIXTURES / "independence_war.scene.json")

    def test_forest_loop_feasibility_reports(self, scene):
        rs = scene.resolve(SC)
        ctx = FieldContext(rs)
        west = next(a for a in rs.areas if a.name == "westforest+i")
        lf = loop_feasibility(ctx, west)
        assert lf is not None
        assert lf.feasible_tiles > 0
        assert lf.demand_tiles == pytest.approx(52 * 250, rel=0.02)
        assert len(lf.skipped) == 5  # the runtime-relative constraints stay opaque
        assert 0.1 < lf.ratio < 10.0

    def test_islands_not_squeezed(self, scene):
        rs = scene.resolve(SC)
        ctx = FieldContext(rs)
        island = next(a for a in rs.areas if a.name == "playerIslandNorth")
        af = area_allowed_fraction(ctx, island, cell_tiles=2.0)
        assert af is not None
        assert af.allowed_fraction > 0.7  # docks/lake carve slivers only

    def test_feasibility_check_runs_clean_of_errors(self, scene):
        for sc in (Scenario(2, 2), Scenario(8, 8)):
            findings = check_area_feasibility(scene.resolve(sc))
            assert [f for f in findings if f.severity == "error"] == []

    def test_koth_hill_constraint_suspicion(self, scene):
        # Documented model finding, to be verified in-game (triage): the KOTH
        # hill at (0.5, 0.72) sits only ~5 m inside the ideal island discs,
        # violating avoidWater10 with a zero search annulus.
        rs = scene.resolve(Scenario(2, 2, koth=True))
        hill = next(p for p in rs.placements if p.name == "king hill")
        f = check_placement(hill, rs)
        assert f.verdict == "CONSTRAINT_UNSAT"
        assert "avoidWater10" in f.details["unsat"]
