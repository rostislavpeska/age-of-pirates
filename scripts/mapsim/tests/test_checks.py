"""Verdict-engine tests, including the three historical regressions from this
project's real bugs (docs/plan_map_spawn_simulator.md section 3)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapsim.checks import check_placement, check_area_overlaps, check_trade_route, check_player_ring, run_checks  # noqa: E402
from scripts.mapsim.scene import Scenario, Scene  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"
SC = Scenario(2, 2)


def make_scene(areas=(), placements=(), constraints=None, world_circle=True):
    return Scene({
        "config": {"size_ladder": [[1, 400]], "sea_level": 1.0, "world_circle": world_circle},
        "areas": list(areas),
        "placements": list(placements),
        "trade_route": {"waypoints": []},
        "player_placement": {},
        "constraints": constraints or {},
    })


def area(name, x, z, tiles, cliff=None, coherence=1.0, smooth=0, land=True, line=1):
    return {"name": name, "line": line, "loc": {"x": x, "z": z},
            "size": {"tiles": tiles}, "base_height": 3.0 if land else None,
            "creates_land": land, "coherence": coherence, "smooth_distance": smooth,
            "cliff_type": cliff}


def placement(name, x, z, affinity="land", category="generic", min_d=0.0, max_d=0.0,
              constraints=(), kind="at_loc", line=1, **extra):
    return {"name": name, "line": line, "proto": name, "kind": kind,
            "anchor": [x, z], "min_dist_m": min_d, "max_dist_m": max_d,
            "terrain_affinity": affinity, "category": category,
            "constraints": list(constraints), **extra}


def verdict_of(scene, name, sc=SC):
    rs = scene.resolve(sc)
    p = next(p for p in rs.placements if p.name == name)
    return check_placement(p, rs)


class TestRegression1PirateHeadlands:
    """The case that refuted the draft boundary model (plan section 1.2):
    land grouping at (0.17, 0.30) on a 1100-tile authored disc must be OK."""

    def test_hand_built_scene_is_ok(self):
        scene = make_scene(
            areas=[area("pirate_site1", 0.17, 0.30, 1100, smooth=15)],
            placements=[{
                "name": "pirate city 1", "line": 615, "proto": "pirate_village05",
                "kind": "grouping_at_loc",
                "anchor": {"runtime": "controller readback", "approx": [0.17, 0.30]},
                "terrain_affinity": "land", "category": "generic",
            }],
        )
        f = verdict_of(scene, "pirate city 1")
        assert f.verdict == "OK"
        assert f.approximate  # literal-anchor rule, reported as approximate

    def test_real_scene_pirate_city_is_ok(self):
        scene = Scene.load(FIXTURES / "independence_war.scene.json")
        rs = scene.resolve(SC)
        city = next(p for p in rs.placements if p.name == "pirate city 1")
        f = check_placement(city, rs)
        assert f.verdict == "OK" and f.approximate


class TestRegression2PirateVillageMaxDistance:
    """The original silent failure: MaxDistance 30 m could not reach the
    region the village was required to be in — must assert CONSTRAINT_UNSAT."""

    def test_unreachable_constraint(self):
        scene = make_scene(
            areas=[area("headland", 0.17, 0.30, 1100, smooth=15)],
            placements=[placement("old pirate village", 0.17, 0.30,
                                  min_d=0.0, max_d=30.0,
                                  constraints=["requiredHalf"])],
            constraints={"requiredHalf": {"kind": "box", "box": [0.0, 0.45, 1.0, 1.0]}},
        )
        # z=0.30 is 120 m from origin-z; box starts at 180 m; 30 m reach cannot bridge 60 m.
        f = verdict_of(scene, "old pirate village")
        assert f.verdict == "CONSTRAINT_UNSAT"
        assert f.details["unsat"] == ["requiredHalf"]

    def test_reachable_constraint_passes(self):
        scene = make_scene(
            areas=[area("headland", 0.17, 0.44, 1100, smooth=15)],
            placements=[placement("village", 0.17, 0.44, min_d=0.0, max_d=30.0,
                                  constraints=["requiredHalf"])],
            constraints={"requiredHalf": {"kind": "box", "box": [0.0, 0.45, 1.0, 1.0]}},
        )
        assert verdict_of(scene, "village").verdict == "OK"


class TestRegression3HarbourSockets:
    """Harbours before the shore cliffs existed had nothing to dock to."""

    def test_no_cliffs_wrong_terrain(self):
        scene = make_scene(
            placements=[placement("harbour TP", 0.6, 0.4, max_d=20.0)],
        )
        f = verdict_of(scene, "harbour TP")
        assert f.verdict == "WRONG_TERRAIN"

    def test_with_cliff_ok(self):
        scene = make_scene(
            areas=[area("shoreLine1", 0.7, 0.4, 700, cliff="New England")],
            placements=[placement("harbour TP", 0.6, 0.4, max_d=20.0)],
        )
        # cliff disc r=29.85 m, conf r=23.88 m, 40 m away: reachable within 20 m.
        assert verdict_of(scene, "harbour TP").verdict == "OK"


class TestVerdictTaxonomy:
    def test_off_map_raises_error_verdict(self):
        scene = make_scene(placements=[placement("bad", 1.01, 0.5)])
        f = verdict_of(scene, "bad")
        assert f.verdict == "OFF_MAP" and f.severity == "error"

    def test_edge_fish_is_warning_not_error(self):
        # Cascade Range places fish at (1.00, 0.70): outside the circle but
        # tolerated for water objects (plan section 1.2).
        scene = make_scene(placements=[placement("fish", 1.00, 0.70, affinity="water")])
        f = verdict_of(scene, "fish")
        assert f.verdict == "EDGE_RISK" and f.severity == "warning"

    def test_land_object_outside_circle_is_error(self):
        scene = make_scene(placements=[placement("hut", 0.95, 0.95, affinity="either")])
        f = verdict_of(scene, "hut")
        assert f.verdict == "OUTSIDE_CIRCLE" and f.severity == "error"

    def test_edge_risk_tiers(self):
        # r=0.46: beyond the player_tc 0.45 cap, inside the generic 0.47 tier.
        scene = make_scene(
            areas=[area("land", 0.96, 0.5, 3000)],
            placements=[placement("tc", 0.96, 0.5, category="player_tc"),
                        placement("obj", 0.96, 0.5, category="generic")],
        )
        assert verdict_of(scene, "tc").verdict == "EDGE_RISK"
        assert verdict_of(scene, "obj").verdict == "OK"

    def test_unknown_runtime_without_approx(self):
        scene = make_scene(placements=[{
            "name": "probe", "line": 1, "proto": "x", "kind": "closest_point",
            "anchor": {"runtime": "rmFindClosestPointVector(...)"},
            "terrain_affinity": "water", "category": "generic",
        }])
        f = verdict_of(scene, "probe")
        assert f.verdict == "UNKNOWN_RUNTIME" and f.severity == "info"

    def test_near_edge_of_area(self):
        # Anchor reaches only the expanded band of a low-coherence area.
        scene = make_scene(
            areas=[area("blob", 0.5, 0.5, 700, coherence=0.4)],
            placements=[placement("cabin", 0.61, 0.5, max_d=0.0)],
        )
        # r=29.85, band=0.5r=14.93; conf 14.93, exp 44.78; d=44 m: beyond the
        # confident disc, inside the expanded band -> NEAR_EDGE_OF_AREA.
        f = verdict_of(scene, "cabin")
        assert f.verdict == "NEAR_EDGE_OF_AREA" and f.severity == "warning"

    def test_inactive_mode_gate(self):
        scene = make_scene(placements=[
            placement("hill", 0.5, 0.72, when={"koth": True})])
        f = verdict_of(scene, "hill")
        assert f.verdict == "INACTIVE"
        f_koth = verdict_of(scene, "hill", Scenario(2, 2, koth=True))
        assert f_koth.verdict != "INACTIVE"

    def test_in_area_land_check(self):
        scene = make_scene(
            areas=[area("island", 0.5, 0.5, 3000), area("marker", 0.5, 0.3, 1000, land=False)],
            placements=[
                placement("mine ok", 0, 0, kind="in_area", area_refs=["island"]),
                placement("mine bad", 0, 0, kind="in_area", area_refs=["marker"]),
                placement("mine missing", 0, 0, kind="in_area", area_refs=["nope"]),
            ],
        )
        assert verdict_of(scene, "mine ok").verdict == "OK"
        assert verdict_of(scene, "mine bad").verdict == "WRONG_TERRAIN"
        assert verdict_of(scene, "mine missing").verdict == "CONFIG"


class TestSceneLevelChecks:
    def test_area_overlap_cliff_vs_flat_is_warning(self):
        scene = make_scene(areas=[
            area("estateValley", 0.60, 0.40, 700),
            area("shoreCliff", 0.66, 0.40, 700, cliff="New England"),
        ])
        rs = scene.resolve(SC)
        findings = check_area_overlaps(rs)
        assert len(findings) == 1
        assert findings[0].verdict == "AREA_OVERLAP" and findings[0].severity == "warning"

    def test_same_center_overlay_not_flagged(self):
        scene = make_scene(areas=[
            area("island", 0.8, 0.8, 3000),
            area("hills", 0.8, 0.8, 2000),
        ])
        assert check_area_overlaps(scene.resolve(SC)) == []

    def test_docked_socket_far_from_route(self):
        scene = Scene({
            "config": {"size_ladder": [[1, 400]], "sea_level": 1.0, "world_circle": True},
            "areas": [],
            "placements": [placement("socket", 0.8, 0.8, affinity="water",
                                     route_docked=True, max_d=0.5)],
            "trade_route": {"waypoints": [{"point": [0.5, 0.7]}, {"point": [0.5, 0.3]}]},
            "player_placement": {},
            "constraints": {},
        })
        rs = scene.resolve(SC)
        findings = check_trade_route(rs, blocksize_m=16.0)
        far = [f for f in findings if f.verdict == "ROUTE_TOO_FAR"]
        assert len(far) == 1 and far[0].severity == "error"

    def test_ring_off_land(self):
        scene = Scene({
            "config": {"size_ladder": [[1, 400]], "sea_level": 1.0, "world_circle": True},
            "areas": [area("tiny", 0.5, 0.5, 100)],
            "placements": [],
            "trade_route": {"waypoints": []},
            "player_placement": {"branches": [
                {"when": {"teams_gt": 2}, "kind": "circular", "min": 0.38, "max": 0.42}]},
            "constraints": {},
        })
        rs = scene.resolve(Scenario(4, 4))
        findings = check_player_ring(rs)
        assert findings[0].verdict == "RING_OFF_LAND" and findings[0].severity == "error"


class TestRealSceneSmoke:
    """run_checks over the real golden scene must complete and stay free of
    the hard verdicts that would mean the deployed map is broken."""

    @pytest.mark.parametrize("sc", [Scenario(2, 2), Scenario(3, 2), Scenario(5, 2),
                                    Scenario(7, 2), Scenario(8, 4), Scenario(5, 5)])
    def test_no_hard_failures_on_real_map(self, sc):
        scene = Scene.load(FIXTURES / "independence_war.scene.json")
        rs = scene.resolve(sc)
        findings = run_checks(rs, blocksize_m=float(scene.data["trade_route"]["blocksize_m"]))
        hard = [f for f in findings if f.severity == "error"]
        assert hard == [], [f.to_dict() for f in hard]


ISLAND_IN_LAKE = """
void main(void) {
   rmSetStatusText("", 0.1);
   rmSetMapSize(400, 400);
   rmSetSeaLevel(6.0);
   rmTerrainInitialize("deccan\ground_grass3_deccan");
   int lake = rmCreateArea("lake");
   rmSetAreaSize(lake, 0.2, 0.2);
   rmSetAreaLocation(lake, 0.5, 0.5);
   rmSetAreaWaterType(lake, "great lakes");
   rmSetAreaBaseHeight(lake, 0.0);
   rmBuildArea(lake);
   int isle = rmCreateArea("King's Island");
   rmSetAreaSize(isle, rmAreaTilesToFraction(200), rmAreaTilesToFraction(200));
   rmSetAreaLocation(isle, 0.5, 0.5);
   rmSetAreaBaseHeight(isle, 1.0);
   rmSetAreaCoherence(isle, 1.0);
   rmBuildArea(isle);
   int dry = rmCreateTerrainDistanceConstraint("avoid impassable land", "Land", false, 4.0);
   int obj = rmCreateObjectDef("marker");
   rmAddObjectDefItem(obj, "ypKingsHill", 1, 0);
   rmAddObjectDefConstraint(obj, dry);
   rmPlaceObjectDefAtLoc(obj, 0, 0.5, 0.5, 1);
   rmSetStatusText("", 1.0);
}
"""


class TestTerrainConstraintsSeeBuiltTerrain:
    """zpeyrebasin.xs KotH (2026-09-25): a land-initialized map builds its King's Island (base 1.0, 200 tiles) on
    top of the water-typed lake and places the hill there with 'kings hill avoids impassable land' (Land, false,
    4 m). The game places it (owner: Eyre Basin's hill stands on a tiny island). mapsim tested the constraint
    against the lake's authored disc, which ignores the island built over it, and reported CONSTRAINT_UNSAT. The
    grouping solver already measured water distance on the built grid; object placements now do the same."""

    def test_island_hill_is_placeable(self, tmp_path):
        from scripts.mapsim.bridge import extraction_to_resolved
        from scripts.mapsim.xs_extract import extract
        src = tmp_path / "isle.xs"
        src.write_text(ISLAND_IN_LAKE, encoding="utf-8")
        rs = extraction_to_resolved(extract(src, Scenario(2, 2)))
        f = [x for x in run_checks(rs) if x.name == "marker"]
        assert f and f[0].verdict != "CONSTRAINT_UNSAT", f[0].message


KOTH_SEA = """
void main(void) {
   rmSetStatusText("", 0.1);
   rmSetMapSize(400, 400);
   rmSetSeaLevel(1.0);
   rmTerrainInitialize("water");
   rmSetSeaType("caribbean coast");
   rmSetPlacementSection(0.1, 0.9);
   rmPlacePlayersCircular(0.2, 0.2, 0.0);
   int home = rmCreateArea("home");
   rmSetAreaSize(home, 0.3, 0.3);
   rmSetAreaLocation(home, 0.5, 0.5);
   rmSetAreaBaseHeight(home, 2.0);
   rmSetAreaCoherence(home, 1.0);
   rmBuildArea(home);
   int isle = rmCreateArea("koth isle");
   rmSetAreaSize(isle, rmAreaTilesToFraction(250), rmAreaTilesToFraction(250));
   rmSetAreaLocation(isle, 0.9, 0.1);
   rmSetAreaBaseHeight(isle, 2.0);
   rmSetAreaCoherence(isle, 1.0);
   rmBuildArea(isle);
   if (rmGetIsKOTH())
      ypKingsHillPlacer(XX, ZZ, 0.0, 0);
   rmSetStatusText("", 1.0);
}
"""


class TestKothFinding:
    """check_koth (feedback 2026-09-25 item 2): the land the hill stands on, its size, whether a player start
    reaches it by land or shallows, and the distance to deep water (ypkingshill.tactics AutoConvert 12 m: ships
    capture). Owner ground truth it reproduces on the real maps: tiny islands on Eyre Basin, Burma, Dead Sea, Torres
    Strait, Labrador Coast, Cold War; bigger islands on Polynesia, Cook Islands, Melanesia, Elbe, Atols."""

    def _koth(self, tmp_path, x, z):
        from scripts.mapsim.bridge import extraction_to_resolved
        from scripts.mapsim.checks import check_koth
        from scripts.mapsim.xs_extract import extract
        src = tmp_path / "koth.xs"
        src.write_text(KOTH_SEA.replace("XX", str(x)).replace("ZZ", str(z)), encoding="utf-8")
        rs = extraction_to_resolved(extract(src, Scenario(2, 2, koth=True)))
        return check_koth(rs)

    def test_tiny_island_hill(self, tmp_path):
        (f,) = self._koth(tmp_path, 0.9, 0.1)
        assert f.verdict == "KOTH_TINY_ISLAND", f.message
        assert f.details["land"] == "koth isle" and 200 <= f.details["tiles"] < 600
        assert not f.details["reaches_player_start"] and 0 < f.details["deep_water_m"] < 40

    def test_mainland_hill(self, tmp_path):
        (f,) = self._koth(tmp_path, 0.5, 0.5)
        assert f.verdict == "KOTH_MAINLAND", f.message
        assert f.details["reaches_player_start"] and f.details["land"] == "home"

    def test_no_koth_no_finding(self, tmp_path):
        from scripts.mapsim.bridge import extraction_to_resolved
        from scripts.mapsim.checks import check_koth
        from scripts.mapsim.xs_extract import extract
        src = tmp_path / "koth.xs"
        src.write_text(KOTH_SEA.replace("XX", "0.9").replace("ZZ", "0.1"), encoding="utf-8")
        assert check_koth(extraction_to_resolved(extract(src, Scenario(2, 2)))) == []
