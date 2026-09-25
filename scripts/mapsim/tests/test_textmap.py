"""The agent-readable text map (textmap.py) and the player / Town Center markers the preview shares with it
(owner 2026-09-25: "add players"; "the tool is mainly for you, you must be able to read and debug a map from it").
Pure Python - no matplotlib; scenes are built in the test (no Steam, no map scripts)."""

from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapsim.checks import Finding  # noqa: E402
from scripts.mapsim.scene import ResolvedArea, ResolvedPlacement, ResolvedScene, Scenario  # noqa: E402
from scripts.mapsim.textmap import (  # noqa: E402
    COLS, _Canvas, build_text_map, player_starts, team_of, town_centers_apart,
)
from scripts.mapsim.units import MapGrid  # noqa: E402

SIZE_M = 400.0


def _area(name, x, z, radius_m, line, land=True, base_height=2.0, count=1):
    return ResolvedArea(
        name=name, line=line, x=x, z=z, radius_m=radius_m, radius_min_m=radius_m,
        base_height=base_height, creates_land=land, obey_world_circle=True, coherence=None,
        smooth_distance=0.0, cliff_type=None, engine_placed=x is None, count=count, constraints=[],
        has_paint=True)


def _placement(name, x, z, line, items=(), players=(), grouping=False):
    return ResolvedPlacement(
        name=name, line=line, proto=name, kind="at_loc", x=x, z=z, runtime_expr=None, approx=False,
        min_dist_m=0.0, max_dist_m=0.0, terrain_affinity="either", category="generic", route_docked=False,
        area_refs=[], count=1, per_player=len(players) > 1, constraints=[], active=True,
        is_grouping=grouping, player_id=players[0] if players else None, items=tuple(items),
        players=list(players))


def island_scene(size_z_m=SIZE_M):
    """A water map with one 60 m island at the centre holding both starts, an engine-placed land loop (no
    location), a trade route along the south edge; player 1's Town Center on its start, player 2's 30 m north."""
    grid = MapGrid(SIZE_M, size_z_m)
    areas = [_area("big island", 0.5, 0.5, 60.0, line=10),
             _area("extra islet", None, None, 20.0, line=20, count=5)]
    tc2_z = 0.5 + grid.z_m_to_frac(30.0)
    placements = [
        _placement("player TC", 0.42, 0.5, line=30, items=("TownCenter",), players=(1,)),
        _placement("player TC", 0.58, tc2_z, line=30, items=("TownCenter",), players=(2,)),
    ]
    return ResolvedScene(
        scenario=Scenario(2, 2), grid=grid, world_circle=False, sea_level=0.0, areas=areas,
        placements=placements, trade_route_waypoints=[(0.1, 0.1), (0.9, 0.1)], player_placement={},
        constraints={}, trade_routes=[[(0.1, 0.1), (0.9, 0.1)]], base_is_water=True,
        player_locs=[(0.42, 0.5), (0.58, 0.5)])


def _grid_char(text, canvas, x, z):
    """The character the text map printed at fraction (x, z)."""
    rows = [ln for ln in text.splitlines() if ln.startswith("  ") and "|" in ln and ln[2:6].replace(".", "").isdigit()]
    r, c = canvas.rc_of(x, z)
    row = rows[r]
    return row[row.index("|") + 1 + c]


def test_team_of_is_contiguous_blocks_of_the_lobby_order():
    assert [team_of(k, 6, 2) for k in range(6)] == [0, 0, 0, 1, 1, 1]
    assert [team_of(k, 4, 4) for k in range(4)] == [0, 1, 2, 3]
    assert [team_of(k, 2, 2) for k in range(2)] == [0, 1]


def test_player_starts_and_town_centers_apart():
    rs = island_scene()
    assert player_starts(rs) == [(1, 0, 0.42, 0.5), (2, 1, 0.58, 0.5)]
    apart = town_centers_apart(rs)
    # player 1's Town Center stands on its start (the numbered start marks it); player 2's is 30 m away
    assert [(players, start) for _p, players, start in apart] == [([2], (0.58, 0.5))]


def test_text_map_grid_players_route_and_sections():
    rs = island_scene()
    findings = [
        Finding("koth", "hill", "KOTH_ISLAND", "info", "hill on 'big island'",
                details={"hill_m": [200.0, 168.0]}),
        Finding("placement", "stray gold", "WRONG_TERRAIN", "error", "stands in deep water"),
    ]
    text = build_text_map(rs, findings, title="unit island")
    canvas = _Canvas(rs)
    lines = text.splitlines()

    assert lines[0].startswith("MAPSIM TEXT MAP  unit island  P2 T2")
    assert any(ln.startswith("legend:") for ln in lines)
    assert canvas.cols == COLS and canvas.rows == COLS
    header = next(ln for ln in lines if ln.startswith("  z"))
    assert header.index("|") == lines[lines.index(header) + 1].index("|")   # x labels stand over their columns
    # terrain: the island centre is land, a far corner deep water, the route crosses the south
    assert _grid_char(text, canvas, 0.5, 0.52) == "."
    assert _grid_char(text, canvas, 0.1, 0.9) == "~"
    assert _grid_char(text, canvas, 0.5, 0.1) == "="
    # overlays: the numbered starts, player 2's Town Center 30 m north, the KotH hill
    assert _grid_char(text, canvas, 0.42, 0.5) == "1"
    assert _grid_char(text, canvas, 0.58, 0.5) == "2"
    assert _grid_char(text, canvas, 0.58, 0.5 + 30.0 / SIZE_M) == "T"
    assert _grid_char(text, canvas, 0.5, 168.0 / SIZE_M) == "K"

    p1 = next(ln for ln in lines if ln.startswith("  1 T1"))
    p2 = next(ln for ln in lines if ln.startswith("  2 T2"))
    assert "on land 'big island'" in p1 and "TC 'player TC' at start" in p1
    assert "30 m away" in p2
    assert any(ln.startswith("KOTH KOTH_ISLAND") for ln in lines)
    island = next(ln for ln in lines if "big island" in ln and ln.strip().startswith("10 "))
    budget = round(math.pi * 60.0 ** 2 / 4.0)
    assert f"{budget}/{budget}" in island                      # built cells vs the tile budget
    engine = next(ln for ln in lines if "extra islet" in ln)
    assert "NOT BUILT" in engine and "5 x" in engine           # the engine-placed loop is listed, not silently lost
    assert any("ERROR   WRONG_TERRAIN stray gold" in ln for ln in lines)
    assert len(lines) < 150


def test_text_map_names_a_start_in_deep_water():
    rs = island_scene()
    rs.player_locs = [(0.42, 0.5), (0.9, 0.9)]
    text = build_text_map(rs, [], title="t")
    p2 = next(ln for ln in text.splitlines() if ln.startswith("  2 T2"))
    assert "on DEEP WATER" in p2


def test_rectangular_map_keeps_square_characters_along_the_longer_side():
    rs = island_scene(size_z_m=1500.0)
    canvas = _Canvas(rs)
    assert canvas.rows == COLS and canvas.cols == round(COLS * SIZE_M / 1500.0)


def test_sim_writes_the_text_map_without_a_png(tmp_path, capsys):
    from scripts.mapsim import sim
    rs = island_scene()
    sim.run_scenario(None, rs.scenario, tmp_path, rs=rs, tag_prefix="unit_", text=True)
    out = tmp_path / "map_unit_P2_T2.txt"
    assert out.is_file() and "MAPSIM TEXT MAP  unit" in out.read_text(encoding="utf-8")
    assert "text map:" in capsys.readouterr().out
    assert not list(tmp_path.glob("preview_*.png"))


def test_preview_section_arc_runs_through_the_ring_starts():
    """render.section_arc_degrees follows xs_extract.ring_positions (0 = north, clockwise; an end below the start
    wraps): zpBalearicIslands.xs rmSetPlacementSection(0.40, 0.10) at 6 players - every start lies on the arc."""
    from scripts.mapsim.render import section_arc_degrees
    from scripts.mapsim.xs_extract import ring_positions
    evs = [{"call": "rmPlacePlayersCircular", "min": 0.29, "max": 0.29, "section": (0.40, 0.10)}]
    theta1, theta2 = section_arc_degrees(0.40, 0.10)
    assert theta2 > theta1
    for x, z in ring_positions(evs, 6, 2):
        ang = math.degrees(math.atan2(z - 0.5, x - 0.5))
        rel = (ang - theta1) % 360.0
        assert rel <= (theta2 - theta1) + 1e-6, (x, z, ang, theta1, theta2)
    # and the gap (s = 0.1 .. 0.4, the east) stays empty: s = 0.25 sits at due east, angle 0
    assert (0.0 - theta1) % 360.0 > theta2 - theta1
