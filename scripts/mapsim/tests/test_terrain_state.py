"""Terrain-state model tests: base init, water types, elevation classes.

Ground truth: random_map_generation_guide_v2.md (sea level / TerrainInitialize
semantics), rm_commands_reference.md:285/354 (base height inheritance, water
type carving), repo waterbodies XML (carved depths), and the ten-map survey
of 2026-08-08 (Paris/Civil War land bases, Riverina cascade, Cook Islands
underwater cliffs).
"""

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
