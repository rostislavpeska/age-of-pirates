"""Extraction -> ResolvedScene bridge (WP5): render/check ANY map from its .xs.

Converts a WP4 Extraction into the ResolvedScene shape the field, checks and
renderer consume. Runtime-dependent (Tainted) values become runtime anchors or
engine-placed areas — flagged, never guessed.
"""

from __future__ import annotations

from typing import Any, List, Optional

from scripts.mapsim.scene import ResolvedArea, ResolvedPlacement, ResolvedScene, Scenario
from scripts.mapsim.units import MapGrid
from scripts.mapsim.xs_extract import Extraction, Tainted, XArea, XDef


def _num(v: Any) -> Optional[float]:
    return None if v is None or isinstance(v, Tainted) else float(v)


def extraction_to_resolved(ex: Extraction) -> ResolvedScene:
    if ex.map_size_x is None:
        raise ValueError("extraction has no map size")
    grid = MapGrid(ex.map_size_x, ex.map_size_z)
    sea = ex.sea_level if ex.sea_level is not None else 0.0

    areas: List[ResolvedArea] = []
    for a in ex.areas.values():
        x, z = _num(a.x), _num(a.z)
        frac_max = _num(a.size_max_frac)
        frac_min = _num(a.size_min_frac)
        if frac_max is None:
            continue    # size never set or runtime-dependent: not modelable
        segs = [tuple(float(c) for c in s) for s in a.influence_segments
                if not any(isinstance(c, Tainted) for c in s)]
        areas.append(ResolvedArea(
            name=a.name, line=a.line, x=x, z=z,
            radius_m=grid.area_frac_to_radius_m(frac_max),
            radius_min_m=grid.area_frac_to_radius_m(frac_min if frac_min is not None else frac_max),
            base_height=a.base_height,
            creates_land=a.base_height is not None and a.base_height > sea,
            obey_world_circle=a.obey_world_circle,
            coherence=a.coherence,
            smooth_distance=a.smooth,
            cliff_type=a.cliff_type,
            engine_placed=x is None,
            count=a.count,
            constraints=list(a.constraints),
            classes=list(a.classes),
            influence_segments=segs,
        ))

    defs_by_line = {d.line: d for d in ex.defs.values()}
    placements: List[ResolvedPlacement] = []
    seen_lines = set()
    for p in ex.placements:
        if p.def_line in seen_lines:
            continue
        seen_lines.add(p.def_line)
        d: XDef = defs_by_line.get(p.def_line) or XDef(name=p.name, line=p.def_line)
        x, z = _num(p.x), _num(p.z)
        runtime = None
        if isinstance(p.x, Tainted) or isinstance(p.z, Tainted):
            runtime = getattr(p.x, "expr", None) or getattr(p.z, "expr", None) or "runtime"
        kind = {"at_loc": "at_loc", "in_area": "in_area", "at_point": "at_point_runtime"}[p.kind]
        count = p.count if not isinstance(p.count, Tainted) else \
            (int(p.count.hi) if p.count.hi is not None else 1)
        placements.append(ResolvedPlacement(
            name=d.name, line=p.def_line, proto=str(d.proto or d.name), kind=kind,
            x=x, z=z, runtime_expr=runtime, approx=False,
            min_dist_m=_num(d.min_dist) or 0.0,
            max_dist_m=_num(d.max_dist) or 0.0,
            terrain_affinity="either",           # curation semantics; unknown from .xs
            category="generic",
            route_docked=d.route_docked,
            area_refs=list(p.area_refs),
            count=int(count) if count else 1,
            per_player=len(p.players) > 1,
            constraints=list(d.constraints),
            active=True,
            classes=list(d.classes),
            footprint_tiles=None,
        ))

    trade_routes = []
    for handle in sorted(ex.route_waypoints):
        wps = [(float(x), float(z)) for x, z in ex.route_waypoints[handle]
               if not isinstance(x, Tainted) and not isinstance(z, Tainted)]
        if len(wps) >= 2:
            trade_routes.append(wps)
    waypoints = trade_routes[0] if trade_routes else []

    rivers = []
    for r in ex.rivers.values():
        wps = [(float(x), float(z)) for x, z in r.waypoints
               if not isinstance(x, Tainted) and not isinstance(z, Tainted)]
        width = _num(r.width)
        if len(wps) >= 2 and width is not None:
            rivers.append({"line": r.line, "width_m": width, "waypoints": wps})

    branches = []
    for ev in ex.player_events:
        if ev.get("call") == "rmPlacePlayersCircular":
            mn, mx = _num(ev.get("min")), _num(ev.get("max"))
            if mn is not None and mx is not None:
                branches.append({"when": {}, "kind": "circular", "min": mn, "max": mx,
                                 "section": ev.get("section")})
                break

    constraints = {}
    for cname, spec in ex.constraints.items():
        spec = dict(spec)
        if spec.get("kind") == "pie":
            spec["r_min"] = _num(spec.pop("r_min_m")) or 0.0
            spec["r_max"] = _num(spec.pop("r_max_m")) or 0.0
        constraints[cname] = spec

    return ResolvedScene(
        scenario=ex.scenario,
        grid=grid,
        world_circle=ex.world_circle,
        sea_level=sea,
        areas=sorted(areas, key=lambda a: a.line),
        placements=placements,
        trade_route_waypoints=waypoints,
        player_placement={"branches": branches},
        constraints=constraints,
        trade_routes=trade_routes,
        rivers=rivers,
    )
