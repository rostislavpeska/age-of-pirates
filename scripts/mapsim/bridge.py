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


def _ring_positions(ex: Extraction) -> Optional[list]:
    """Nominal player positions — single implementation lives in
    xs_extract.ring_positions (shared with the in-extractor
    rmPlayerLocX/ZFraction resolution). Positions are NOMINAL (variance
    ignored), so consumers must mark results approx."""
    from scripts.mapsim.xs_extract import ring_positions
    return ring_positions(ex.player_events, ex.scenario.players,
                          ex.scenario.teams)


def extraction_to_resolved(ex: Extraction) -> ResolvedScene:
    if ex.map_size_x is None:
        raise ValueError("extraction has no map size")
    grid = MapGrid(ex.map_size_x, ex.map_size_z)
    sea = ex.sea_level if ex.sea_level is not None else 0.0

    ring = _ring_positions(ex)
    n_players = ex.scenario.players
    n_teams = max(1, ex.scenario.teams)

    areas: List[ResolvedArea] = []
    resolved_anchor: dict = {}   # extraction handle -> (x, z) incl. ring anchors
    for handle, a in ex.areas.items():
        x, z = _num(a.x), _num(a.z)
        approx = False
        if x is None and ring:
            # Player/team-anchored areas (rmSetAreaLocPlayer/LocTeam) get a
            # deterministic NOMINAL anchor on the placement ring.
            if a.loc_player is not None and 1 <= a.loc_player <= len(ring):
                x, z = ring[a.loc_player - 1]
                approx = True
            elif a.loc_team is not None and 0 <= a.loc_team < n_teams:
                # Teams occupy contiguous ring blocks; anchor at the block's
                # angular midpoint member.
                members = [k for k in range(n_players)
                           if k * n_teams // n_players == a.loc_team]
                if members:
                    import math
                    xs = [ring[k][0] - 0.5 for k in members]
                    zs = [ring[k][1] - 0.5 for k in members]
                    ang = math.atan2(sum(zs), sum(xs))
                    r = sum(math.hypot(px, pz) for px, pz in zip(xs, zs)) / len(members)
                    x, z = 0.5 + r * math.cos(ang), 0.5 + r * math.sin(ang)
                    approx = True
        resolved_anchor[handle] = (x, z)
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
            # A water-type area is water even with a raised base height (the
            # Riverina cascade lifts the SURFACE, guide:7772-7783).
            creates_land=(a.water_type is None
                          and a.base_height is not None and a.base_height > sea),
            obey_world_circle=a.obey_world_circle,
            coherence=a.coherence,
            smooth_distance=a.smooth,
            cliff_type=a.cliff_type,
            cliff_height=a.cliff_height,
            engine_placed=x is None,
            count=a.count,
            constraints=list(a.constraints),
            classes=list(a.classes),
            influence_segments=segs,
            water_type=a.water_type,
            has_paint=a.has_paint,
            approx=approx,
            height_blend=a.height_blend,
            has_elevation=a.has_elevation,
        ))

    defs_by_line = {d.line: d for d in ex.defs.values()}
    placements: List[ResolvedPlacement] = []
    # Dedup key includes the ANCHOR: branch duplicates (same def, same
    # spot) collapse, but per-player loop instances survive — Cook
    # Islands creates ONE "player native" def line whose loop places six
    # villages at six ring-resolved TC anchors (2026-08-10).
    seen = set()
    suppressed = 0
    for p in ex.placements:
        # Spawn-chance branches (Part H4): the extractor runs BOTH arms of
        # a tainted if but only the NOMINAL arm's placements (lo-roll)
        # enter the scene — Paris rolls ONE monastery per spot, not both.
        if not p.nominal:
            suppressed += 1
            continue
        key = (p.def_line,
               round(p.x, 5) if isinstance(p.x, (int, float)) else None,
               round(p.z, 5) if isinstance(p.z, (int, float)) else None,
               tuple(p.area_refs))
        if key in seen:
            continue
        seen.add(key)
        d: XDef = defs_by_line.get(p.def_line) or XDef(name=p.name, line=p.def_line)
        # Grouping file reference: a literal string, or the literal PREFIX
        # of a runtime concat ("maori_hawaii_0"+rand) — the engine resolves
        # variants by prefix, so the prefix is the deterministic identity.
        if d.is_grouping:
            if isinstance(d.proto, str):
                proto_ref = d.proto
            else:
                proto_ref = getattr(d.proto, "str_prefix", None) or ""
        else:
            proto_ref = str(d.proto or d.name)
        x, z = _num(p.x), _num(p.z)
        runtime = None
        if isinstance(p.x, Tainted) or isinstance(p.z, Tainted):
            runtime = getattr(p.x, "expr", None) or getattr(p.z, "expr", None) or "runtime"
        kind = {"at_loc": "at_loc", "in_area": "in_area", "at_point": "at_point_runtime"}[p.kind]
        count = p.count if not isinstance(p.count, Tainted) else \
            (int(p.count.hi) if p.count.hi is not None else 1)
        placements.append(ResolvedPlacement(
            name=d.name, line=p.def_line, proto=proto_ref, kind=kind,
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
            is_grouping=d.is_grouping,
            player_id=next((int(pl) for pl in p.players
                            if not isinstance(pl, Tainted)
                            and isinstance(pl, (int, float))
                            and 1 <= int(pl) <= 8), None),
            items=tuple(str(t) for t, _n in d.items
                        if isinstance(t, str)),
        ))

    trade_routes = []
    for handle in sorted(ex.route_waypoints):
        wps = [(float(x), float(z)) for x, z in ex.route_waypoints[handle]
               if not isinstance(x, Tainted) and not isinstance(z, Tainted)]
        if len(wps) >= 2:
            trade_routes.append(wps)
    waypoints = trade_routes[0] if trade_routes else []

    connections = []
    for c in ex.connections.values():
        if not c.built or c.base_height is None or len(c.areas) < 2:
            continue
        width = _num(c.width)
        if width is None:
            continue
        a1 = ex.areas.get(c.areas[0])
        a2 = ex.areas.get(c.areas[1])
        if a1 is None or a2 is None:
            continue
        # Endpoints from the RESOLVED anchors — Hawaii's causeways connect
        # to loc_player areas whose positions only exist after ring
        # resolution (raw extraction has them as None).
        x1, z1 = resolved_anchor.get(c.areas[0], (None, None))
        x2, z2 = resolved_anchor.get(c.areas[1], (None, None))
        if None in (x1, z1, x2, z2):
            continue
        r1 = _num(a1.size_max_frac)
        r2 = _num(a2.size_max_frac)
        connections.append({"line": c.line, "width_m": width,
                            "base_height": c.base_height,
                            "x1": x1, "z1": z1, "x2": x2, "z2": z2,
                            "r1_m": grid.area_frac_to_radius_m(r1) if r1 else 0.0,
                            "r2_m": grid.area_frac_to_radius_m(r2) if r2 else 0.0})

    rivers = []
    # RECT-MAP RIVER UNITS (pinned 2026-08-09): the engine reads river
    # waypoints as fractions of SIZE_X on BOTH axes, while trade routes
    # (and areas/objects) use true per-axis fractions. Evidence: wwcanyon
    # (400x560) authors its river to z=1.4 — exactly 1.4*400 = 560 m, the
    # far z edge — and its minimap shows the full-span river with the
    # t=0.5 ford at map center; its trade routes reach the far edge with
    # a plain 1.0. Author-side formula: z_authored = z_wanted * sizeZ/sizeX.
    # Converting here keeps every consumer in uniform per-axis fractions;
    # square maps are a no-op. Waypoints past the map edge (paris' Seine
    # at converted z=1.81) simply clip at the edge, like in-game.
    z_over_x = ((ex.map_size_x / ex.map_size_z)
                if ex.map_size_z else 1.0)
    for r in ex.rivers.values():
        wps = [(float(x), float(z) * z_over_x) for x, z in r.waypoints
               if not isinstance(x, Tainted) and not isinstance(z, Tainted)]
        width = _num(r.width)
        if len(wps) >= 2 and width is not None:
            # Waypoints are stamped LITERALLY as authored (user directive
            # 2026-08-09: mathematical precision over visual polish — the
            # in-game river meanders around this polyline, but the tool is
            # a spawn test surface, so the Z stays a Z).
            rivers.append({"line": r.line, "width_m": width, "waypoints": wps,
                           "water_type": r.water_type,
                           "shallow_radius_m": _num(r.shallow_radius) or 15.0,
                           "shallows": [float(t) for t in r.shallows
                                        if not isinstance(t, Tainted)]})

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

    from scripts.mapsim.waterdata import is_water_type_name
    # Missing rmTerrainInitialize is a documented map error (guide:10508);
    # fall back to the historical water-base assumption.
    base_is_water = (ex.terrain_init is None
                     or is_water_type_name(ex.terrain_init))
    return ResolvedScene(
        suppressed_variants=suppressed,
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
        connections=connections,
        base_is_water=base_is_water,
        base_elevation_m=(ex.terrain_init_height
                          if ex.terrain_init_height is not None else 0.0),
        sea_type=ex.sea_type,
    )
