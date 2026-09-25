"""Terrain-state model tests: base init, water types, elevation classes.

Ground truth: random_map_generation_guide_v2.md (sea level / TerrainInitialize
semantics), rm_commands_reference.md:285/354 (base height inheritance, water
type carving), repo waterbodies XML (carved depths), and the ten-map survey
of 2026-08-08 (Paris/Civil War land bases, Riverina cascade, Cook Islands
underwater cliffs).
"""

import math
from pathlib import Path

import pytest

from scripts.mapsim.bridge import extraction_to_resolved
from scripts.mapsim.field import terrain_grid
from scripts.mapsim.scene import Scenario, Scene
from scripts.mapsim.waterdata import (
    SHALLOW_BUILD_DEPTH_M, depth_of, is_water_type_name, water_bodies,
)
from scripts.mapsim.xs_extract import extract

REPO = Path(__file__).resolve().parents[3]


def make_scene(areas, config_extra=None, rivers=None):
    config = {"size_ladder": [[1, 400]], "sea_level": 1.0, "world_circle": False,
              "terrain_init": "water"}
    config.update(config_extra or {})
    data = {
        "config": config,
        "areas": areas,
        "placements": [],
        "trade_route": {"waypoints": []},
        "player_placement": {"branches": []},
    }
    if rivers:
        data["rivers"] = rivers
    return Scene(data).resolve(Scenario(2, 2))


def area(name, x, z, tiles, line=1, bh=None, water_type=None, cliff=None,
         land=None, paint=False):
    if land is None:
        land = water_type is None and bh is not None and bh > 1.0
    return {"name": name, "line": line, "loc": {"x": x, "z": z},
            "size": {"tiles": tiles}, "base_height": bh, "creates_land": land,
            "coherence": 1.0, "smooth_distance": 0, "water_type": water_type,
            "cliff_type": cliff, "has_paint": paint}


class TestWaterData:
    def test_catalog_loads_mod_and_vanilla(self):
        cat = water_bodies()
        assert len(cat) > 100
        assert "caribbean coast" in cat

    def test_known_depths(self):
        # data/waterbodies2.xml ground truth from the research pass
        assert depth_of("ZP Riverina Waterfalls") == pytest.approx(3.0)
        assert depth_of("Caribbean Coast") == pytest.approx(4.0)
        assert depth_of("great lakes2") == pytest.approx(6.0)

    def test_water_type_names(self):
        assert is_water_type_name("water")
        assert is_water_type_name("ZP Cook Islands 4")
        assert not is_water_type_name("grass")
        assert not is_water_type_name("nwterritory\\ground_grass2_nwt")


class TestBaseTerrainExtraction:
    def test_water_base_maps(self):
        ex = extract(REPO / "game" / "randmaps" / "zptortuga.xs", Scenario(4, 2))
        rs = extraction_to_resolved(ex)
        assert rs.base_is_water is True
        assert rs.sea_level == pytest.approx(2.0)
        assert rs.sea_type == "caribbean coast"

    def test_land_base_maps(self):
        ex = extract(REPO / "randmaps" / "zpparis.xs", Scenario(3, 3))
        rs = extraction_to_resolved(ex)
        assert rs.base_is_water is False
        assert rs.base_elevation_m == pytest.approx(1.0)
        assert rs.sea_level == pytest.approx(0.0)

    def test_area_water_type_extracted(self):
        ex = extract(REPO / "game" / "randmaps" / "zpaustralia.xs", Scenario(4, 2))
        rs = extraction_to_resolved(ex)
        lake = next(a for a in rs.areas if a.water_type is not None)
        assert lake.water_type == "ZP Australia Red Lake"
        assert lake.creates_land is False


class TestTerrainState:
    def test_land_base_is_land_everywhere_without_areas(self):
        rs = make_scene([], config_extra={"terrain_init": "grass", "sea_level": 0.0})
        tg = terrain_grid(rs)
        assert tg.is_land_frac(0.5, 0.5)
        assert tg.is_land_frac(0.1, 0.9)

    def test_water_base_is_water_without_areas(self):
        rs = make_scene([])
        tg = terrain_grid(rs)
        assert not tg.is_land_frac(0.5, 0.5)

    def test_water_type_area_carves_land_base(self):
        rs = make_scene(
            [area("lake", 0.5, 0.5, 700, water_type="great lakes2")],
            config_extra={"terrain_init": "grass", "sea_level": 0.0})
        tg = terrain_grid(rs)
        i, j = tg.cell_of_frac(0.5, 0.5)
        assert tg.water[j][i]
        assert tg.wdepth[j][i] > SHALLOW_BUILD_DEPTH_M   # great lakes2 depth 6 -> DEEP
        assert tg.is_land_frac(0.1, 0.1)               # base stays land

    def test_elevated_lake_is_still_water(self):
        # Riverina cascade: water type + rmSetAreaBaseHeight lifts the
        # SURFACE — the cell must stay water, never land.
        rs = make_scene(
            [area("upper lake", 0.5, 0.5, 700, bh=7.0,
                  water_type="ZP Riverina Waterfalls")],
            config_extra={"terrain_init": "grass", "sea_level": 0.0})
        tg = terrain_grid(rs)
        i, j = tg.cell_of_frac(0.5, 0.5)
        assert tg.water[j][i]

    def test_submerged_ground_is_shallow(self):
        # Cook Islands team shoal idiom: base height just below sea level.
        rs = make_scene([area("shoal", 0.5, 0.5, 700, bh=0.75)])
        tg = terrain_grid(rs)
        i, j = tg.cell_of_frac(0.5, 0.5)
        assert tg.water[j][i]
        assert tg.wdepth[j][i] == pytest.approx(0.25)
        assert tg.wdepth[j][i] <= SHALLOW_BUILD_DEPTH_M   # class SHALLOW

    def test_underwater_cliff_keeps_water_with_cliff_code(self):
        # Cook Islands "Cave" reef ring: cliff at -5 under sea level 0.
        rs = make_scene(
            [area("reef", 0.5, 0.5, 700, bh=-5.0, cliff="Cave")],
            config_extra={"sea_level": 0.0})
        tg = terrain_grid(rs)
        i, j = tg.cell_of_frac(0.5, 0.5)
        assert tg.water[j][i]
        assert tg.wdepth[j][i] == pytest.approx(5.0)
        assert tg.cliff[j][i] != 0
        assert tg.cliff_order[tg.cliff[j][i] - 1] == "reef"

    def test_cliff_without_height_inherits_land(self):
        # Blue Mountains / Uluru mesas: cliff type only, on a land base.
        rs = make_scene(
            [area("mesa", 0.5, 0.5, 700, cliff="Deccan Plateau")],
            config_extra={"terrain_init": "grass", "sea_level": 0.0})
        tg = terrain_grid(rs)
        i, j = tg.cell_of_frac(0.5, 0.5)
        assert not tg.water[j][i]
        assert tg.cliff[j][i] != 0

    def test_flat_mask_carves_to_sea_floor_on_land_base(self):
        # Civil War riverArea idiom: ElevationVariation(0.0) + no height
        # carves down to the SEA TYPE's floor — the arms BLOCK land units
        # (great lakes2 depth 6), which is why the map authors fords/bridges.
        raw = area("mask", 0.5, 0.5, 700)
        raw["has_elevation"] = True
        rs = make_scene(
            [raw], config_extra={"terrain_init": "grass", "sea_level": 0.0,
                                 "sea_type": "great lakes2"})
        tg = terrain_grid(rs)
        i, j = tg.cell_of_frac(0.5, 0.5)
        assert tg.water[j][i]
        assert tg.wdepth[j][i] == pytest.approx(6.0)   # DEEP: blocks units
        assert tg.marker[j][i]

    def test_template_mask_without_elevation_stays_dry(self):
        # WW Canyon bank idiom: location+size+constraints only, NO
        # elevation-family call — a pure constraint template, no stamp.
        rs = make_scene(
            [area("bank", 0.5, 0.5, 700)],
            config_extra={"terrain_init": "grass", "sea_level": 0.0})
        tg = terrain_grid(rs)
        assert tg.is_land_frac(0.5, 0.5)
        i, j = tg.cell_of_frac(0.5, 0.5)
        assert tg.marker[j][i]

    def test_flat_mask_with_blend_stays_dry(self):
        # Paris city-hill masks: rmSetAreaHeightBlend(3) flattens the stamp
        # (ref:315 "anything above 2 may flatten an area completely").
        raw = area("mask", 0.5, 0.5, 700)
        raw["has_elevation"] = True
        raw["height_blend"] = 3.0
        rs = make_scene(
            [raw], config_extra={"terrain_init": "grass", "sea_level": 0.0})
        tg = terrain_grid(rs)
        assert tg.is_land_frac(0.5, 0.5)
        i, j = tg.cell_of_frac(0.5, 0.5)
        assert tg.marker[j][i]

    def test_invisible_mask_sinks_earlier_land_on_water_base(self):
        # Elbe ground truth: a no-height claim adopts the map base height —
        # on a water base that re-floods land built before it.
        mask = area("mask", 0.5, 0.5, 700, line=2)
        mask["has_elevation"] = True   # Elbe's mask calls ElevationVariation(0.0)
        rs = make_scene([
            area("slab", 0.5, 0.5, 2000, bh=3.0, line=1),
            mask,
        ])
        tg = terrain_grid(rs)
        i, j = tg.cell_of_frac(0.5, 0.5)
        assert tg.water[j][i]
        assert not tg.is_land_frac(0.5, 0.5)

    def test_river_water_type_depth(self):
        rs = make_scene(
            [], config_extra={"terrain_init": "grass", "sea_level": 0.0},
            rivers=[{"line": 5, "width_m": 30.0,
                     "waypoints": [[0.5, 0.0], [0.5, 1.0]],
                     "water_type": "ZP Riverina Waterfalls"}])
        tg = terrain_grid(rs)
        i, j = tg.cell_of_frac(0.5, 0.5)
        assert tg.water[j][i]
        assert tg.wdepth[j][i] == pytest.approx(3.0)


class TestGoldenGrids:
    """Determinism lock (plan B6): the classified grid of the fixture map is
    pinned byte-for-byte. A failure here means the terrain MODEL changed —
    review the diff, then regenerate the golden deliberately:
    python -c "..." (see goldens/ generation snippet in the plan)."""

    @pytest.mark.parametrize("players,teams", [(2, 2), (8, 8)])
    def test_fixture_grid_matches_golden(self, players, teams):
        import json
        scene = Scene.load(REPO / "scripts" / "mapsim" / "tests" / "fixtures"
                           / "independence_war.scene.json")
        rs = scene.resolve(Scenario(players, teams))
        got = terrain_grid(rs).digest()
        golden = json.loads(
            (REPO / "scripts" / "mapsim" / "tests" / "goldens"
             / f"independence_war_P{players}T{teams}.json").read_text())
        assert got == golden


DEAD_SEA_LIKE = r"""
void main(void) {
   rmSetStatusText("", 0.1);
   rmSetMapSize(400, 400);
   rmSetSeaLevel(6.0);
   rmTerrainInitialize("deccan\ground_grass3_deccan");
   int lake = rmCreateArea("lake");
   rmSetAreaSize(lake, 0.05, 0.05);
   rmSetAreaLocation(lake, 0.5, 0.5);
   rmSetAreaWaterType(lake, "great lakes");
   rmSetAreaBaseHeight(lake, 0.0);
   rmBuildArea(lake);
   int valley = rmCreateArea("valley");
   rmSetAreaSize(valley, 0.03, 0.03);
   rmSetAreaLocation(valley, 0.2, 0.2);
   rmSetAreaBaseHeight(valley, 0.0);
   rmBuildArea(valley);
   int home = rmCreateArea("home");
   rmSetAreaSize(home, 0.03, 0.03);
   rmSetAreaLocation(home, 0.8, 0.8);
   rmSetAreaBaseHeight(home, 2.0);
   rmBuildArea(home);
   rmSetStatusText("", 1.0);
}
"""


class TestSeaLevelOnLandBase:
    """zpdeadsea.xs / zpeyrebasin.xs (2026-09-25): land-initialized, rmSetSeaLevel(6.0), lakes as water-typed areas at
    0.0, players on areas at base height 1-2. The live editor minimap (2880x1800, Dead Sea 2p and 6p) shows land
    everywhere but the lake: the grey 'dead sea valley' (base 0.0) and both players' areas (2.0) are dry. mapsim
    flooded every area below the sea level (48% minimap agreement, 0/2 Town Centers on land)."""

    def _grid(self, tmp_path):
        src = tmp_path / "deadsea_like.xs"
        src.write_text(DEAD_SEA_LIKE, encoding="utf-8")
        ex = extract(src, Scenario(2, 2))
        rs = extraction_to_resolved(ex)
        return rs, terrain_grid(rs)

    def test_low_ground_stays_land(self, tmp_path):
        rs, tg = self._grid(tmp_path)
        assert not rs.base_is_water
        for x, z in ((0.2, 0.2), (0.8, 0.8)):
            i, j = tg.cell_of_frac(x, z)
            assert not tg.water[j][i], (x, z)

    def test_the_water_typed_lake_is_the_only_water(self, tmp_path):
        rs, tg = self._grid(tmp_path)
        i, j = tg.cell_of_frac(0.5, 0.5)
        assert tg.water[j][i]
        wet = sum(1 for row in tg.water for w in row if w)
        assert wet < 0.08 * tg.nx * tg.nz

    def test_checks_agree(self, tmp_path):
        from scripts.mapsim.checks import area_is_land
        rs, _ = self._grid(tmp_path)
        by = {a.name: a for a in rs.areas}
        assert area_is_land(rs, by["valley"]) and area_is_land(rs, by["home"])
        assert not area_is_land(rs, by["lake"])


TEAM_ISLANDS = """
void main(void) {
   rmSetMapSize(740, 740);
   rmSetSeaLevel(1.0);
   rmSetSeaType("ZP Malta No Waves");
   rmTerrainInitialize("water");
   rmSetPlacementSection(0.40, 0.10);
   rmPlacePlayersCircular(0.29, 0.29, 0);
   for(i=0; <cNumberTeams) {
      int teamID = rmCreateArea("team "+i);
      rmSetAreaSize(teamID, 0.11, 0.11);
      rmSetAreaBaseHeight(teamID, 2.0);
      rmSetAreaLocTeam(teamID, i);
      rmBuildArea(teamID);
   }
}
"""


class TestTeamAreaCoversItsMembers:
    """zpBalearicIslands.xs 6p (2026-09-25): team islands by rmSetAreaLocTeam, teammates ~50 deg apart on the ring.
    The live minimap shows two crescents, each holding its team's three Town Centers; mapsim grew one disc at the
    team's mean direction and left the end players in the sea (3 of 6 real Town Centers off mapsim land)."""

    def test_every_player_start_is_on_its_team_island(self, tmp_path):
        src = tmp_path / "team_islands.xs"
        src.write_text(TEAM_ISLANDS, encoding="utf-8")
        rs = extraction_to_resolved(extract(src, Scenario(6, 2)))
        tg = terrain_grid(rs)
        for x, z in rs.player_locs:
            i, j = tg.cell_of_frac(x, z)
            assert not tg.water[j][i], (round(x, 3), round(z, 3))
        chains = [a.influence_segments for a in rs.areas if a.name.startswith("team ")]
        assert [len(c) for c in chains] == [2, 2]


TRIANGLE_ISLAND = r"""
void main(void) {
   rmSetMapSize(760, 760);
   rmSetSeaLevel(2.0);
   rmTerrainInitialize("water");
   int south = rmCreateArea("south island");
   rmSetAreaSize(south, 0.15, 0.15);
   rmSetAreaLocation(south, 0.0, 0.3);
   rmSetAreaBaseHeight(south, 3.5);
   rmAddAreaInfluenceSegment(south, 0.2, 0.1, 0.4, 0.55);
   rmAddAreaInfluenceSegment(south, 0.4, 0.55, 0.0, 0.5);
   rmAddAreaInfluenceSegment(south, 0.0, 0.5, 0.2, 0.1);
   rmBuildArea(south);
}
"""


class TestClosedSegmentLoopFills:
    """zptorresstrait.xs draws each big island as a triangle of influence segments: the live minimaps show solid
    triangles, where the flood's segment band left the inside sea (2p 77.4 -> 82.1 % minimap agreement with the
    fill)."""

    def test_triangle_inside_is_land(self, tmp_path):
        src = tmp_path / "triangle.xs"
        src.write_text(TRIANGLE_ISLAND, encoding="utf-8")
        tg = terrain_grid(extraction_to_resolved(extract(src, Scenario(2, 2))))
        i, j = tg.cell_of_frac(0.2, 0.38)          # the centroid, ~90 m from every segment
        assert not tg.water[j][i]

    def test_open_chain_is_not_filled(self, tmp_path):
        src = tmp_path / "chain.xs"
        src.write_text(TRIANGLE_ISLAND.replace("rmAddAreaInfluenceSegment(south, 0.0, 0.5, 0.2, 0.1);\n", ""),
                       encoding="utf-8")
        tg = terrain_grid(extraction_to_resolved(extract(src, Scenario(2, 2))))
        i, j = tg.cell_of_frac(0.2, 0.38)
        assert tg.water[j][i]


ONE_ISLAND = r"""
void main(void) {
   rmSetMapSize(400, 400);
   rmSetSeaType("%(sea)s");
   rmSetSeaLevel(1.0);
   rmTerrainInitialize("%(init)s");
   int island = rmCreateArea("island");
   rmSetAreaSize(island, %(size)s, %(size)s);
   rmSetAreaLocation(island, 0.5, 0.5);
   rmSetAreaCoherence(island, %(coh)s);
   rmSetAreaBaseHeight(island, 2.0);
   rmSetAreaSmoothDistance(island, 20);
   rmBuildArea(island);
}
"""


def _island(tmp_path, sea, size, coh, init="water"):
    src = tmp_path / "one_island.xs"
    src.write_text(ONE_ISLAND % {"sea": sea, "size": size, "coh": coh, "init": init}, encoding="utf-8")
    rs = extraction_to_resolved(extract(src, Scenario(2, 2)))
    tg = terrain_grid(rs)
    step = rs.grid.size_x_m / tg.nx
    dry = sum(1 for j in range(tg.nz) for i in range(tg.nx) if not tg.water[j][i])
    nondeep = sum(1 for j in range(tg.nz) for i in range(tg.nx) if not tg.water[j][i] or tg.wwalk[j][i])
    r_eq = lambda n: math.sqrt(n / math.pi) * step       # noqa: E731 - equivalent-disc radius in metres
    return rs.areas[0].radius_m, r_eq(dry), r_eq(nondeep)


class TestIslandShore:
    """Island shores on a flooded base, measured 2026-09-25 on the vertex height field saved with every editor
    generation (171 isolated islands of 15 water-initialized maps, P2T2 + P6T2). Measured relative to mapsim's
    tile-budget disc (where the engine's own tile set ends is not visible in the save): a coherence-1.0 island's
    shores end 3-7 m inside the disc, an incoherent one ends up larger (empirical fit, no known mechanism).
    Measured edges (walkable <= 1.5 m, dry) relative to the claim edge:
    Kurils 'player N' (ZP Kuril Islands, 6 m) -5.2 / -7.0 m, Melanesia (5 m) -4.7 / -6.6 m,
    Mediterranean (ZP Anno 1404, 3 m) -3.0 / -5.6 m. Mediterranean 6p 'player island N' (coherence 0.5, budget r 92.5 m)
    +6.4..+8.2 / +3.3..+5.5 m."""

    @pytest.mark.parametrize("sea, walk, dry", [
        ("ZP Kuril Islands", -5.2, -7.0),
        ("ZP Melanesia", -4.7, -6.6),
        ("ZP Anno 1404", -3.0, -5.6),
    ])
    def test_coherent_island_edges_match_the_measurement(self, sea, walk, dry):
        from types import SimpleNamespace
        from scripts.mapsim.field import shore_offsets
        a = SimpleNamespace(base_height=2.0, smooth_distance=20.0, coherence=1.0, radius_m=33.9)
        d_walk, d_dry = shore_offsets(a, 1.0, depth_of(sea))
        assert d_walk == pytest.approx(walk, abs=0.5)
        assert d_dry == pytest.approx(dry, abs=0.5)

    def test_coherent_island_is_smaller_than_its_budget(self, tmp_path):
        r, r_dry, r_nondeep = _island(tmp_path, "ZP Kuril Islands", 0.0226, 1.0)
        assert r == pytest.approx(33.9, abs=0.5)
        assert r_dry == pytest.approx(r - 7.0, abs=1.5)
        assert r_nondeep == pytest.approx(r - 5.2, abs=1.5)
        assert r_nondeep > r_dry                          # a walkable shallow ring rims the dry land

    def test_incoherent_island_grows_past_its_budget(self, tmp_path):
        r, r_dry, r_nondeep = _island(tmp_path, "ZP Anno 1404", 0.168, 0.5)
        assert r == pytest.approx(92.5, abs=1.0)
        assert r_dry == pytest.approx(r + 4.4, abs=2.0)
        assert r_nondeep == pytest.approx(r + 7.3, abs=2.0)

    def test_height_blend_two_keeps_the_budget_shape(self):
        # Unmeasured by the fit; Independence War's blend-2 islands have a walkable shelf OUTSIDE the claim.
        from types import SimpleNamespace
        from scripts.mapsim.field import shore_offsets
        a = SimpleNamespace(base_height=3.0, smooth_distance=6.0, coherence=1.0, radius_m=155.6, height_blend=2.0)
        assert shore_offsets(a, 1.0, depth_of("ZP New England Calm")) == (0.0, 0.0)

    def test_land_base_keeps_the_plain_budget_edge(self, tmp_path):
        """On a land base a water-typed lake keeps its budget disc: the shore model is for land built on a flooded
        base only (every land map matched the saved terrain unchanged)."""
        src = tmp_path / "lake.xs"
        src.write_text(LAKE_ON_LAND, encoding="utf-8")
        rs = extraction_to_resolved(extract(src, Scenario(2, 2)))
        tg = terrain_grid(rs)
        step = rs.grid.size_x_m / tg.nx
        wet = sum(1 for j in range(tg.nz) for i in range(tg.nx) if tg.water[j][i])
        assert math.sqrt(wet / math.pi) * step == pytest.approx(rs.areas[0].radius_m, abs=1.5)

    def test_growth_respects_constraints_and_authored_water(self, tmp_path):
        """Growth cells must pass the area's own constraints and never take authored water: an incoherent island
        next to a water-typed lake and a class it avoids."""
        src = tmp_path / "grow.xs"
        src.write_text(GROW_NEXT_TO_LAKE, encoding="utf-8")
        rs = extraction_to_resolved(extract(src, Scenario(2, 2)))
        tg = terrain_grid(rs)
        i, j = tg.cell_of_frac(0.71, 0.5)       # 84 m out: the island's growth band (78..90 m), inside the lake
        assert tg.water[j][i]
        i, j = tg.cell_of_frac(0.5, 0.335)      # 14 m from the rock centre: inside its 5 + 12 m keep-out
        assert tg.water[j][i]

    def test_shrink_never_floods_land_that_was_there_before(self, tmp_path):
        """A coherent island built on top of an earlier, larger landmass: the shrink ring only turns back cells that
        were open sea before this build."""
        src = tmp_path / "overlay.xs"
        src.write_text(ISLAND_ON_LAND, encoding="utf-8")
        rs = extraction_to_resolved(extract(src, Scenario(2, 2)))
        tg = terrain_grid(rs)
        for x in (0.5, 0.5 + 30.0 / 400.0, 0.5 - 30.0 / 400.0):   # inside and at the small island's edge
            i, j = tg.cell_of_frac(x, 0.5)
            assert not tg.water[j][i], x


LAKE_ON_LAND = r"""
void main(void) {
   rmSetMapSize(400, 400);
   rmSetSeaLevel(1.0);
   rmTerrainInitialize("grass");
   int lake = rmCreateArea("lake");
   rmSetAreaSize(lake, 0.05, 0.05);
   rmSetAreaLocation(lake, 0.5, 0.5);
   rmSetAreaWaterType(lake, "ZP Kuril Islands");
   rmSetAreaCoherence(lake, 0.5);
   rmSetAreaSmoothDistance(lake, 20);
   rmBuildArea(lake);
}
"""

GROW_NEXT_TO_LAKE = r"""
void main(void) {
   rmSetMapSize(400, 400);
   rmSetSeaType("ZP Anno 1404");
   rmSetSeaLevel(1.0);
   rmTerrainInitialize("water");
   int classRock = rmDefineClass("rock");
   int rock = rmCreateArea("rock");
   rmSetAreaSize(rock, rmAreaTilesToFraction(20), rmAreaTilesToFraction(20));
   rmSetAreaLocation(rock, 0.5, 0.3);
   rmSetAreaBaseHeight(rock, 2.0);
   rmAddAreaToClass(rock, classRock);
   rmBuildArea(rock);
   int lake = rmCreateArea("lake");
   rmSetAreaSize(lake, 0.004, 0.004);
   rmSetAreaLocation(lake, 0.715, 0.5);
   rmSetAreaWaterType(lake, "ZP Anno 1404");
   rmBuildArea(lake);
   int avoidRock = rmCreateClassDistanceConstraint("avoid rock", classRock, 12.0);
   int island = rmCreateArea("island");
   rmSetAreaSize(island, 0.12, 0.12);
   rmSetAreaLocation(island, 0.5, 0.5);
   rmSetAreaCoherence(island, 0.3);
   rmSetAreaBaseHeight(island, 2.0);
   rmSetAreaSmoothDistance(island, 20);
   rmAddAreaConstraint(island, avoidRock);
   rmBuildArea(island);
}
"""

ISLAND_ON_LAND = r"""
void main(void) {
   rmSetMapSize(400, 400);
   rmSetSeaType("ZP Kuril Islands");
   rmSetSeaLevel(1.0);
   rmTerrainInitialize("water");
   int big = rmCreateArea("big");
   rmSetAreaSize(big, 0.2, 0.2);
   rmSetAreaLocation(big, 0.5, 0.5);
   rmSetAreaBaseHeight(big, 2.0);
   rmSetAreaCoherence(big, 1.0);
   rmBuildArea(big);
   int small = rmCreateArea("small");
   rmSetAreaSize(small, rmAreaTilesToFraction(700), rmAreaTilesToFraction(700));
   rmSetAreaLocation(small, 0.5, 0.5);
   rmSetAreaBaseHeight(small, 3.0);
   rmSetAreaCoherence(small, 1.0);
   rmSetAreaSmoothDistance(small, 20);
   rmBuildArea(small);
}
"""
