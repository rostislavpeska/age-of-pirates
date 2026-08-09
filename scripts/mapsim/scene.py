"""Scene model for the map spawn simulator.

A scene JSON is a single branch-keyed description of a map's geometry
(docs/plan_map_spawn_simulator.md section 2.2). Values may branch on the
resolution key (players, teams, mode) — never on player count alone, because
map geometry branches on cNumberTeams too (TC MaxDistance 20 m at 2 teams,
else 60 m). `Scene.resolve(scenario)` returns plain numbers via the scenario's
MapGrid.

Branchable value forms accepted anywhere a number is expected:
  42.0                                      constant
  {"ladder": [[min_players, value], ...]}   largest rung with min_players <= P
  {"cases": [{"when": {...}, "value": v},
             ...], "default": v}            first matching case wins
  {"frac_x": 0.45} / {"frac_z": 0.47}       fraction-derived meters
                                            (rmX/ZFractionToMeters at resolve)

`when` conditions (ANDed): players_lt, players_gte, players_eq, players_in,
teams_eq, teams_gt, koth, nomad.

Coordinates: {"base": 0.5, "tiles": 22} adds rmXTilesToFraction(22) (or the Z
twin, by axis) to the base fraction. Runtime-dependent anchors are
{"runtime": "<expr>", "approx": [x, z]} — approx present only when the
literal-anchor rule applies (plan section 1.2).
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from scripts.mapsim.units import MapGrid


@dataclass(frozen=True)
class Scenario:
    """Resolution key: never player count alone."""

    players: int
    teams: int
    koth: bool = False
    nomad: bool = False

    def __post_init__(self) -> None:
        if self.players < 1:
            raise ValueError(f"players must be >= 1, got {self.players!r}")
        if not (1 <= self.teams <= self.players):
            raise ValueError(
                f"teams must be in 1..players ({self.players}), got {self.teams!r}"
            )


def _check_when(when: Dict[str, Any], sc: Scenario) -> bool:
    for key, expected in when.items():
        if key == "players_lt":
            if not sc.players < expected:
                return False
        elif key == "players_gte":
            if not sc.players >= expected:
                return False
        elif key == "players_eq":
            if sc.players != expected:
                return False
        elif key == "players_in":
            if sc.players not in expected:
                return False
        elif key == "teams_eq":
            if sc.teams != expected:
                return False
        elif key == "teams_gt":
            if not sc.teams > expected:
                return False
        elif key in ("offteam_players_lte", "offteam_players_gte"):
            # Players NOT on team 0 under the alternating team model
            # ((p-1) mod teams) — Independence War lumps every non-0 team
            # onto the "west" shore counter, and its fort path shuts off
            # when either lumped shore exceeds 4 players.
            offteam = sc.players - math.ceil(sc.players / sc.teams)
            if key.endswith("_lte") and not offteam <= expected:
                return False
            if key.endswith("_gte") and not offteam >= expected:
                return False
        elif key == "koth":
            if sc.koth != expected:
                return False
        elif key == "nomad":
            if sc.nomad != expected:
                return False
        else:
            raise ValueError(f"unknown when-condition {key!r}")
    return True


def resolve_branch(value: Any, sc: Scenario, grid: Optional[MapGrid] = None) -> Any:
    """Resolve a branchable value to a plain number (or passthrough)."""
    if not isinstance(value, dict):
        return value
    if "ladder" in value:
        picked = None
        for min_players, rung in value["ladder"]:
            if sc.players >= min_players:
                picked = rung
        if picked is None:
            raise ValueError(f"no ladder rung matches players={sc.players}: {value!r}")
        return resolve_branch(picked, sc, grid)
    if "cases" in value:
        for case in value["cases"]:
            if _check_when(case["when"], sc):
                return resolve_branch(case["value"], sc, grid)
        if "default" not in value:
            raise ValueError(f"no case matched and no default: {value!r}")
        return resolve_branch(value["default"], sc, grid)
    if "frac_x" in value:
        if grid is None:
            raise ValueError("frac_x needs a MapGrid to resolve")
        return grid.x_frac_to_m(resolve_branch(value["frac_x"], sc, grid))
    if "frac_z" in value:
        if grid is None:
            raise ValueError("frac_z needs a MapGrid to resolve")
        return grid.z_frac_to_m(resolve_branch(value["frac_z"], sc, grid))
    raise ValueError(f"unrecognized branchable value: {value!r}")


def resolve_coord(spec: Any, sc: Scenario, grid: MapGrid, axis: str) -> float:
    """Resolve a coordinate spec to a fraction on the given axis ('x'|'z')."""
    if isinstance(spec, (int, float)):
        return float(spec)
    if isinstance(spec, dict) and ("base" in spec or "tiles" in spec):
        base = float(resolve_branch(spec.get("base", 0.0), sc, grid))
        tiles = float(resolve_branch(spec.get("tiles", 0.0), sc, grid))
        meters = float(resolve_branch(spec.get("meters", 0.0), sc, grid))
        if axis == "x":
            return base + grid.x_tiles_to_frac(tiles) + grid.x_m_to_frac(meters)
        if axis == "z":
            return base + grid.z_tiles_to_frac(tiles) + grid.z_m_to_frac(meters)
        raise ValueError(f"axis must be 'x' or 'z', got {axis!r}")
    return float(resolve_branch(spec, sc, grid))


@dataclass
class ResolvedArea:
    name: str
    line: int
    x: Optional[float]              # None => engine_placed
    z: Optional[float]
    radius_m: float                 # from the max of the size range
    radius_min_m: float             # from the min of the size range
    base_height: Optional[float]
    creates_land: bool
    obey_world_circle: bool
    coherence: Optional[float]
    smooth_distance: float
    cliff_type: Optional[str]
    engine_placed: bool
    count: int                      # loop areas attempt up to this many
    constraints: List[str]
    classes: List[str] = field(default_factory=list)
    influence_segments: List[Tuple[float, float, float, float]] = field(default_factory=list)
    water_type: Optional[str] = None    # rmSetAreaWaterType: paints real water
    has_paint: bool = False             # painted a terrain mix/type/layer
    approx: bool = False                # anchor derived (player/team ring), not literal
    height_blend: float = 0.0           # rmSetAreaHeightBlend; >=2 flattens the stamp
    has_elevation: bool = False         # any rmSetAreaElevation* call (flat-stamp marker)
    cliff_height: Optional[float] = None  # rmSetAreaCliffHeight; None = default 4.0 (raised)

    def cliff_raised(self) -> bool:
        """Raised cliffs (height > 0, or unset -> engine default 4.0) are
        rock massifs; height-0 cliffs are flat ground with a carved rim
        (Elbe docks, Paris quays, Crownlands shores)."""
        return self.cliff_height is None or self.cliff_height > 0.0

    def is_invisible(self) -> bool:
        """Pure constraint mask (guide:5824 'they mark where water should
        STAY'): built but paints nothing — no height, no water, no cliff,
        no terrain paint. Changes nothing on the map."""
        return (self.base_height is None and self.water_type is None
                and self.cliff_type is None and not self.has_paint)

    def radius_frac_x(self, grid: MapGrid) -> float:
        return grid.x_m_to_frac(self.radius_m)


@dataclass
class ResolvedPlacement:
    name: str
    line: int
    proto: str
    kind: str                       # at_loc | grouping_at_loc | at_point_runtime |
                                    # closest_point | in_area | player_loop
    x: Optional[float]
    z: Optional[float]
    runtime_expr: Optional[str]
    approx: bool                    # True when x/z came from the literal-anchor rule
    min_dist_m: float
    max_dist_m: float
    terrain_affinity: str           # land | water | either
    category: str                   # player_tc | generic | nugget_flag
    route_docked: bool
    area_refs: List[str]
    count: int
    per_player: bool
    constraints: List[str]
    active: bool                    # False when a mode gate (when) excluded it
    classes: List[str] = field(default_factory=list)
    footprint_tiles: Optional[Tuple[float, float]] = None
    is_grouping: bool = False       # rmCreateGrouping def: proto = the
                                    # grouping FILE reference (prefix-variant)
    player_id: Optional[int] = None  # owning player 1-8; None/0 = gaia


@dataclass
class ResolvedScene:
    scenario: Scenario
    grid: MapGrid
    world_circle: bool
    sea_level: float
    areas: List[ResolvedArea]
    placements: List[ResolvedPlacement]
    trade_route_waypoints: List[Tuple[float, float]]   # first route (back-compat)
    player_placement: Dict[str, Any]
    constraints: Dict[str, Any]
    trade_routes: List[List[Tuple[float, float]]] = field(default_factory=list)
    rivers: List[Dict[str, Any]] = field(default_factory=list)  # {line, width_m, waypoints, water_type}
    connections: List[Dict[str, Any]] = field(default_factory=list)  # {line, width_m, base_height, x1..z2}
    # Base terrain from rmTerrainInitialize: a flooded base ("water" or a
    # water-type name) vs a land base at base_elevation_m. Default matches
    # the historical assumption (water base) for curated scenes without the
    # config keys.
    base_is_water: bool = True
    base_elevation_m: float = 0.0       # init height arg (default 0.0, guide:3145)
    sea_type: Optional[str] = None      # rmSetSeaType water body name

    def all_routes(self) -> List[List[Tuple[float, float]]]:
        return self.trade_routes or ([self.trade_route_waypoints] if self.trade_route_waypoints else [])

    def land_areas(self) -> List[ResolvedArea]:
        return [a for a in self.areas if a.creates_land and not a.engine_placed]


class Scene:
    """Loader for the branch-keyed scene JSON."""

    def __init__(self, data: Dict[str, Any]):
        self.data = data
        for section in ("config", "areas", "placements", "trade_route", "player_placement"):
            if section not in data:
                raise ValueError(f"scene JSON missing section {section!r}")

    @classmethod
    def load(cls, path: Path | str) -> "Scene":
        with open(path, encoding="utf-8") as f:
            return cls(json.load(f))

    def grid_for(self, sc: Scenario) -> MapGrid:
        ladder = tuple((int(p), float(s)) for p, s in self.data["config"]["size_ladder"])
        return MapGrid.for_players(sc.players, ladder)

    def resolve(self, sc: Scenario) -> ResolvedScene:
        grid = self.grid_for(sc)
        cfg = self.data["config"]

        areas = []
        for raw in self.data["areas"]:
            engine_placed = bool(raw.get("engine_placed", False))
            if engine_placed:
                x = z = None
            else:
                loc = raw["loc"]
                x = resolve_coord(loc["x"], sc, grid, "x")
                z = resolve_coord(loc["z"], sc, grid, "z")
            size = raw["size"]
            if "tiles" in size:
                t_max = float(resolve_branch(size["tiles"], sc, grid))
                t_min = float(resolve_branch(size.get("tiles_min", size["tiles"]), sc, grid))
                radius_m = grid.area_tiles_to_radius_m(t_max)
                radius_min_m = grid.area_tiles_to_radius_m(t_min)
            elif "fraction" in size:
                f_max = float(resolve_branch(size["fraction"], sc, grid))
                f_min = float(resolve_branch(size.get("fraction_min", size["fraction"]), sc, grid))
                radius_m = grid.area_frac_to_radius_m(f_max)
                radius_min_m = grid.area_frac_to_radius_m(f_min)
            else:
                raise ValueError(f"area {raw['name']!r}: size needs 'tiles' or 'fraction'")
            base_height = raw.get("base_height")
            areas.append(ResolvedArea(
                name=raw["name"],
                line=int(raw["line"]),
                x=x, z=z,
                radius_m=radius_m,
                radius_min_m=radius_min_m,
                base_height=None if base_height is None else float(resolve_branch(base_height, sc, grid)),
                creates_land=bool(raw["creates_land"]),
                obey_world_circle=bool(raw.get("obey_world_circle", True)),
                coherence=raw.get("coherence"),
                smooth_distance=float(raw.get("smooth_distance", 0.0)),
                cliff_type=raw.get("cliff_type"),
                engine_placed=engine_placed,
                count=int(resolve_branch(raw.get("count", 1), sc, grid)),
                constraints=list(raw.get("constraints", [])),
                classes=list(raw.get("classes", [])),
                influence_segments=[tuple(s) for s in raw.get("influence_segments", [])],
                water_type=raw.get("water_type"),
                has_paint=bool(raw.get("has_paint", False)),
                height_blend=float(raw.get("height_blend", 0.0)),
                has_elevation=bool(raw.get("has_elevation", False)),
                cliff_height=raw.get("cliff_height"),
            ))

        placements = []
        for raw in self.data["placements"]:
            active = _check_when(raw.get("when", {}), sc)
            anchor = raw.get("anchor")
            x = z = None
            runtime_expr = None
            approx = False
            if isinstance(anchor, dict) and "runtime" in anchor:
                runtime_expr = anchor["runtime"]
                if "approx" in anchor:
                    approx = True
                    x = resolve_coord(anchor["approx"][0], sc, grid, "x")
                    z = resolve_coord(anchor["approx"][1], sc, grid, "z")
            elif anchor is not None:
                x = resolve_coord(anchor[0], sc, grid, "x")
                z = resolve_coord(anchor[1], sc, grid, "z")
            placements.append(ResolvedPlacement(
                name=raw["name"],
                line=int(raw["line"]),
                proto=raw.get("proto", ""),
                kind=raw["kind"],
                x=x, z=z,
                runtime_expr=runtime_expr,
                approx=approx,
                min_dist_m=float(resolve_branch(raw.get("min_dist_m", 0.0), sc, grid)),
                max_dist_m=float(resolve_branch(raw.get("max_dist_m", 0.0), sc, grid)),
                terrain_affinity=raw.get("terrain_affinity", "either"),
                category=raw.get("category", "generic"),
                route_docked=bool(raw.get("route_docked", False)),
                area_refs=list(raw.get("area_refs", [])),
                count=int(resolve_branch(raw.get("count", 1), sc, grid)),
                per_player=bool(raw.get("per_player", False)),
                constraints=list(raw.get("constraints", [])),
                active=active,
                classes=list(raw.get("classes", [])),
                footprint_tiles=tuple(raw["footprint_tiles"]) if raw.get("footprint_tiles") else None,
            ))

        waypoints: List[Tuple[float, float]] = []
        for entry in self.data["trade_route"]["waypoints"]:
            if "cases" in entry or "ladder" in entry:
                point = resolve_branch(entry, sc, grid)
            else:
                if not _check_when(entry.get("when", {}), sc):
                    continue
                point = entry["point"]
            if point is not None:
                waypoints.append((float(point[0]), float(point[1])))

        rivers = []
        for raw in self.data.get("rivers", []):
            rivers.append({
                "line": int(raw.get("line", 0)),
                "width_m": float(resolve_branch(raw["width_m"], sc, grid)),
                "waypoints": [(float(p[0]), float(p[1])) for p in raw["waypoints"]],
                "water_type": raw.get("water_type"),
            })

        from scripts.mapsim.waterdata import is_water_type_name
        terrain_init = str(cfg.get("terrain_init", "water"))
        return ResolvedScene(
            scenario=sc,
            grid=grid,
            world_circle=bool(cfg.get("world_circle", True)),
            sea_level=float(cfg.get("sea_level", 0.0)),
            areas=areas,
            placements=placements,
            trade_route_waypoints=waypoints,
            player_placement=self.data["player_placement"],
            constraints=self.data.get("constraints", {}),
            trade_routes=[waypoints] if waypoints else [],
            rivers=rivers,
            base_is_water=is_water_type_name(terrain_init),
            base_elevation_m=float(cfg.get("terrain_init_height", 0.0)),
            sea_type=cfg.get("sea_type"),
        )
