"""Tests for the scene model and the curated Independence War golden scene.

WP1 gate (docs/plan_map_spawn_simulator.md section 4): scene loads, counts
match the inventory (22 areas / 42 object defs), and branch resolution picks
the right values — riverArea1's four rmSetAreaSize overwrites, TC MaxDistance
by team count, waypoint branches per player count.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapsim.scene import Scenario, Scene, resolve_branch  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"


@pytest.fixture(scope="module")
def scene() -> Scene:
    return Scene.load(FIXTURES / "independence_war.scene.json")


class TestSnapshot:
    def test_snapshot_hash_matches_recorded(self, scene):
        meta = scene.data["snapshot"]
        snapshot = FIXTURES / meta["file"]
        digest = hashlib.sha256(snapshot.read_bytes()).hexdigest()
        assert digest == meta["sha256"], (
            "vendored snapshot changed - re-baseline the scene (plan section 1.3)"
        )

    def test_inventory_fixture_present(self):
        inv = json.loads((FIXTURES / "independence_war.inventory.json").read_text(encoding="utf-8"))
        assert len(inv["areas"]) == 22
        assert len(inv["object_defs"]) == 54


class TestCounts:
    def test_counts_match_inventory(self, scene):
        # 54 extracted defs; curated placements collapse per-player def
        # families (colony ships) and pseudo-entries, plus the fort table
        # entry and six Haudenosaunee villages -> 49.
        assert len(scene.data["areas"]) == 22
        assert len(scene.data["placements"]) == 49

    def test_land_area_count(self, scene):
        resolved = scene.resolve(Scenario(2, 2))
        assert len(resolved.land_areas()) == 18  # 22 minus 2 markers, 2 forest loops


class TestScenario:
    def test_validation(self):
        with pytest.raises(ValueError):
            Scenario(0, 1)
        with pytest.raises(ValueError):
            Scenario(4, 5)
        with pytest.raises(ValueError):
            Scenario(4, 0)


class TestBranchResolution:
    @pytest.mark.parametrize(
        ("players", "tiles"),
        [(2, 2700), (3, 3500), (4, 3500), (5, 4500), (6, 4500), (7, 6000), (8, 6000)],
    )
    def test_riverarea1_size_ladder(self, scene, players, tiles):
        # The four sequential rmSetAreaSize overwrites (snapshot lines 364-371).
        resolved = scene.resolve(Scenario(players, 2))
        river = next(a for a in resolved.areas if a.name == "riverArea1")
        grid = resolved.grid
        assert river.radius_m == pytest.approx(grid.area_tiles_to_radius_m(tiles), rel=1e-12)

    def test_tc_max_distance_branches_on_teams_not_players(self, scene):
        # snapshot lines 896-900: TCfloat = 20 if cNumberTeams == 2 else 60.
        tc_2teams = next(p for p in scene.resolve(Scenario(4, 2)).placements if p.name == "player TC")
        tc_ffa = next(p for p in scene.resolve(Scenario(4, 4)).placements if p.name == "player TC")
        assert tc_2teams.max_dist_m == 20.0
        assert tc_ffa.max_dist_m == 60.0

    def test_fish_max_distance_branches_on_koth(self, scene):
        fish = next(p for p in scene.resolve(Scenario(2, 2)).placements if p.name == "fish")
        fish_koth = next(p for p in scene.resolve(Scenario(2, 2, koth=True)).placements if p.name == "fish")
        assert fish.max_dist_m == pytest.approx(0.45 * 480.0)
        assert fish_koth.max_dist_m == pytest.approx(0.4 * 480.0)

    def test_king_hill_gated_on_koth(self, scene):
        hill = next(p for p in scene.resolve(Scenario(4, 2)).placements if p.name == "king hill")
        hill_koth = next(p for p in scene.resolve(Scenario(4, 2, koth=True)).placements if p.name == "king hill")
        assert not hill.active
        assert hill_koth.active

    def test_frac_derived_distance_scales_with_map(self, scene):
        # max_dist {"frac_x": 0.45} is rmXFractionToMeters: 216 m at 2p, 356.4 m at 8p.
        mine_2p = next(p for p in scene.resolve(Scenario(2, 2)).placements if p.name == "random mine")
        mine_8p = next(p for p in scene.resolve(Scenario(8, 4)).placements if p.name == "random mine")
        assert mine_2p.max_dist_m == pytest.approx(0.45 * 480.0)
        assert mine_8p.max_dist_m == pytest.approx(0.45 * 792.0)


class TestCoordinates:
    def test_bridge_dock_tile_offset_scales(self, scene):
        east_2p = next(a for a in scene.resolve(Scenario(2, 2)).areas if a.name == "bridgeDockEast")
        east_8p = next(a for a in scene.resolve(Scenario(8, 4)).areas if a.name == "bridgeDockEast")
        west_2p = next(a for a in scene.resolve(Scenario(2, 2)).areas if a.name == "bridgeDockWest")
        assert east_2p.x == pytest.approx(0.5 + 44.0 / 480.0)
        assert east_8p.x == pytest.approx(0.5 + 44.0 / 792.0)
        assert west_2p.x == pytest.approx(0.5 - 44.0 / 480.0)
        assert east_2p.z == pytest.approx(0.88)

    def test_estate_ring_positions(self, scene):
        resolved = scene.resolve(Scenario(2, 2))
        v1 = next(a for a in resolved.areas if a.name == "estateValley1")
        v6 = next(a for a in resolved.areas if a.name == "estateValley6")
        # spread outer arc (near-bridge north / west / southwest + mirrors)
        assert (v1.x, v1.z) == (0.29, 0.85)
        assert (v6.x, v6.z) == (0.87, 0.375)

    def test_estate_valley_radius_map_size_invariant(self, scene):
        r2 = next(a for a in scene.resolve(Scenario(2, 2)).areas if a.name == "estateValley1").radius_m
        r8 = next(a for a in scene.resolve(Scenario(8, 4)).areas if a.name == "estateValley1").radius_m
        assert r2 == pytest.approx(29.854, abs=5e-3)
        assert r2 == pytest.approx(r8, rel=1e-12)

    def test_bridge_stopper_approx_is_route_midpoint(self, scene):
        # rmGetTradeRouteWayPoint(id, 0.5) takes a route-length FRACTION,
        # not a waypoint index. The uniform there-and-back loop is length-
        # symmetric, so its midpoint is exactly the southern tip (0.5,0.36)
        # at EVERY player count.
        stopper_2p = next(p for p in scene.resolve(Scenario(2, 2)).placements if p.name == "bridge stopper")
        stopper_7p = next(p for p in scene.resolve(Scenario(7, 4)).placements if p.name == "bridge stopper")
        assert stopper_2p.approx and (stopper_2p.x, stopper_2p.z) == (0.5, 0.36)
        assert (stopper_7p.x, stopper_7p.z) == (0.5, 0.36)

    def test_pirate_sites_literal_anchor(self, scene):
        resolved = scene.resolve(Scenario(2, 2))
        site1 = next(a for a in resolved.areas if a.name == "pirate_site1")
        assert (site1.x, site1.z) == (0.215, 0.24)
        city1 = next(p for p in resolved.placements if p.name == "pirate city 1")
        assert city1.approx and (city1.x, city1.z) == (0.215, 0.24)
        assert city1.runtime_expr is not None


class TestEnginePlacedAreas:
    def test_forest_loops_have_no_location_and_a_size_range(self, scene):
        resolved = scene.resolve(Scenario(2, 2))
        west = next(a for a in resolved.areas if a.name == "westforest+i")
        assert west.engine_placed and west.x is None
        assert west.radius_min_m < west.radius_m
        assert west.count == 52
        west_8p = next(a for a in scene.resolve(Scenario(8, 4)).areas if a.name == "westforest+i")
        assert west_8p.count == 80

    def test_engine_placed_excluded_from_land_union(self, scene):
        resolved = scene.resolve(Scenario(2, 2))
        assert all(not a.engine_placed for a in resolved.land_areas())


class TestTradeRoute:
    @pytest.mark.parametrize("players", [2, 3, 4, 5, 6, 7, 8])
    def test_waypoints_uniform_full_loop(self, scene, players):
        # Deliberate divergence from Elbe: identical 9-point there-and-back
        # loop at every player count / map size.
        wps = scene.resolve(Scenario(players, 2)).trade_route_waypoints
        assert len(wps) == 9
        assert (0.4, 0.4) in wps
        assert (0.4, 0.5) in wps
        assert wps.count((0.5, 0.84)) == 2   # opener + return tail, always
        assert wps.count((0.5, 0.56)) == 2


class TestPlayerPlacement:
    def test_symmetric_1v1_table(self, scene):
        branches = scene.data["player_placement"]["branches"]
        b2 = next(b for b in branches if b.get("when") == {"players_eq": 2})
        assert b2["kind"] == "fixed"
        assert b2["variants"][0]["positions"] == [[1, 0.652, 0.70], [2, 0.348, 0.70]]

    def test_fort_tables_alternate_shores(self, scene):
        branches = scene.data["player_placement"]["branches"]
        b4 = next(b for b in branches if b.get("when") == {"players_eq": 4})
        pos = b4["variants"][0]["positions"]
        assert pos == [[1, 0.755, 0.53], [2, 0.376, 0.64],
                       [3, 0.62, 0.628], [4, 0.306, 0.559]]
        b8 = next(b for b in branches if b.get("when") == {"players_eq": 8})
        assert [7, 0.684, 0.376] in b8["variants"][0]["positions"]
        assert [8, 0.316, 0.376] in b8["variants"][0]["positions"]


class TestConstraintsCatalog:
    def test_every_referenced_constraint_is_cataloged(self, scene):
        catalog = set(scene.data["constraints"])
        referenced = set()
        for entry in scene.data["areas"] + scene.data["placements"]:
            referenced.update(entry.get("constraints", []))
        missing = referenced - catalog
        assert not missing, f"constraints referenced but not cataloged: {sorted(missing)}"

    def test_edge_tier_pies_resolve_in_meters(self, scene):
        resolved = scene.resolve(Scenario(2, 2))
        sc, grid = resolved.scenario, resolved.grid
        pie = resolved.constraints["circleConstraint2"]
        assert resolve_branch(pie["r_max"], sc, grid) == pytest.approx(0.48 * 480.0)
        player_pie = resolved.constraints["playerEdgeConstraint"]
        assert resolve_branch(player_pie["r_max"], sc, grid) == pytest.approx(0.45 * 480.0)
