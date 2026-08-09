"""Verdict engine for the map spawn simulator.

Per-placement verdict order (docs/plan_map_spawn_simulator.md section 2.3):
OFF_MAP -> OUTSIDE_CIRCLE / EDGE_RISK -> WRONG_TERRAIN / NEAR_EDGE_OF_AREA ->
CONSTRAINT_UNSAT -> OK. UNKNOWN_RUNTIME short-circuits unless the
literal-anchor rule resolved an approximate position (plan section 1.2).

Scene-level checks (area overlaps, trade route, player ring) emit their own
finding records — they are not per-placement verdicts.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

from scripts.mapsim.geometry import (
    WORLD_CIRCLE_R,
    angle_frac_in_arc,
    annulus_intersects_annulus,
    annulus_intersects_box,
    annulus_intersects_disc,
    dist,
    dist_point_to_polyline,
    in_world_circle,
)
from scripts.mapsim.scene import (
    ResolvedArea,
    ResolvedPlacement,
    ResolvedScene,
    _check_when,
    resolve_branch,
)

# Only the 0.45 player cap is documented (guide:8135). 0.47/0.48 are inferred
# from stock-map convention — same epistemic status as WORLD_CIRCLE_R; the E3
# in-game markers measure all three (plan sections 1.2, 5).
SAFE_RADIUS_FRAC = {
    "player_tc": 0.45,
    "generic": 0.47,
    "nugget_flag": 0.48,
}

# Disc-model honesty band (plan section 1.2): blob shape is out of scope, so
# an area is its ideal disc +/- smooth distance plus a coherence-scaled slack.
BAND_COHERENT = 0.2      # coherence ~1.0: near-circular areas
BAND_INCOHERENT = 0.5    # low/unset coherence: wandering blobs


@dataclass
class Finding:
    scope: str                  # placement | area_pair | route | ring | config
    name: str
    verdict: str                # verdict enum for placements; kind for scene-level
    severity: str               # error | warning | info
    message: str
    approximate: bool = False
    details: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "scope": self.scope, "name": self.name, "verdict": self.verdict,
            "severity": self.severity, "message": self.message,
            "approximate": self.approximate, "details": self.details,
        }


def _area_band_m(area: ResolvedArea) -> float:
    coherent = area.coherence is not None and area.coherence >= 0.99
    slack = BAND_COHERENT if coherent else BAND_INCOHERENT
    return area.smooth_distance + slack * area.radius_m


def _land_areas_at(rs: ResolvedScene, before_line: Optional[int]) -> List[ResolvedArea]:
    """Land areas that exist at a given point in the script.

    Build order matters: the pirate controllers stand on open water that only
    BECOMES land when the headland areas build a few lines later
    (snapshot lines 571 vs 593). None = end of script (all authored land).
    """
    areas = rs.land_areas()
    if before_line is None:
        return areas
    return [a for a in areas if a.line <= before_line]


def area_is_land(rs: ResolvedScene, a: ResolvedArea) -> bool:
    """Whether the area's surface ends up above water: water types never,
    explicit heights by comparison with sea level, everything else inherits
    the rmTerrainInitialize base (rm_commands_reference.md:285-286) —
    or the curated scene's explicit creates_land flag."""
    if a.water_type is not None:
        return False
    if a.base_height is not None:
        return a.base_height > rs.sea_level
    return a.creates_land or not rs.base_is_water


def _water_features_m(rs: ResolvedScene, before_line: Optional[int]):
    """(kind-tuple, band_m, name) shapes of authored water on a LAND-base
    map: water-type areas (disc + influence capsules, blob band) and river
    bands (deterministic, zero band)."""
    g = rs.grid
    feats = []
    for a in rs.areas:
        if a.x is None:
            continue
        wet = (a.water_type is not None
               or (a.base_height is not None and a.base_height <= rs.sea_level)
               or (a.is_invisible() and a.has_elevation
                   and a.height_blend < 2.0 and rs.sea_level >= 0.0))
        if not wet:
            continue
        if before_line is not None and a.line > before_line:
            continue
        band = _area_band_m(a)
        feats.append((("disc", g.x_frac_to_m(a.x), g.z_frac_to_m(a.z), a.radius_m),
                      band, a.name))
        from scripts.mapsim.field import connected_influence_segments
        for x1, z1, x2, z2 in connected_influence_segments(a, g):
            feats.append((("capsule", g.x_frac_to_m(x1), g.z_frac_to_m(z1),
                           g.x_frac_to_m(x2), g.z_frac_to_m(z2), a.radius_m),
                          band, a.name))
    for r in rs.rivers:
        if before_line is not None and int(r.get("line", 0)) > before_line:
            continue
        halfw = float(r["width_m"]) / 2.0
        pts = [(g.x_frac_to_m(x), g.z_frac_to_m(z)) for x, z in r["waypoints"]]
        for (x1, z1), (x2, z2) in zip(pts, pts[1:]):
            feats.append((("capsule", x1, z1, x2, z2, halfw), 0.0, "river"))
    return feats


def _feat_axis_dist(anchor_m, feat) -> Tuple[float, float]:
    """(distance to the shape's axis, shape radius)."""
    from scripts.mapsim.geometry import dist_point_to_segment
    if feat[0] == "disc":
        _, cx, cz, r = feat
        return dist(anchor_m, (cx, cz)), r
    _, x1, z1, x2, z2, r = feat
    return dist_point_to_segment(anchor_m, (x1, z1), (x2, z2)), r


def _land_reach(
    rs: ResolvedScene, anchor_m: Tuple[float, float], r_min: float, r_max: float,
    before_line: Optional[int] = None,
) -> Tuple[bool, bool, Optional[str]]:
    """(solid, possible, nearest_area): can the annulus reach authored land?

    solid  — intersects a land disc shrunk by its uncertainty band
    possible — intersects a land disc expanded by its band
    """
    if not rs.base_is_water:
        # Land-base map: everything is land except authored water features.
        # Land is unreachable only when the whole annulus sits inside one
        # water feature (single-shape union approximation, same convention
        # as the water-base single-disc rule below) AND no authored land
        # area (island in a lake) reaches into the annulus either.
        solid = possible = True
        inside_of = None
        for feat, band, name in _water_features_m(rs, before_line):
            d, r = _feat_axis_dist(anchor_m, feat)
            if d + r_max <= r + band:
                solid = False
                inside_of = name
            if d + r_max <= max(0.0, r - band):
                possible = False
        if not solid or not possible:
            for area in _land_areas_at(rs, before_line):
                d = dist(anchor_m, (rs.grid.x_frac_to_m(area.x),
                                    rs.grid.z_frac_to_m(area.z)))
                band = _area_band_m(area)
                if annulus_intersects_disc(d, r_min, r_max,
                                           max(0.0, area.radius_m - band)):
                    solid = True
                if annulus_intersects_disc(d, r_min, r_max, area.radius_m + band):
                    possible = True
        return solid, possible, inside_of
    solid = possible = False
    nearest = None
    nearest_gap = math.inf
    for area in _land_areas_at(rs, before_line):
        d = dist(anchor_m, (rs.grid.x_frac_to_m(area.x), rs.grid.z_frac_to_m(area.z)))
        band = _area_band_m(area)
        if annulus_intersects_disc(d, r_min, r_max, max(0.0, area.radius_m - band)):
            solid = True
        if annulus_intersects_disc(d, r_min, r_max, area.radius_m + band):
            possible = True
        gap = d - area.radius_m
        if gap < nearest_gap:
            nearest_gap, nearest = gap, area.name
    return solid, possible, nearest


def _inside_land(
    rs: ResolvedScene, anchor_m, r_min, r_max, before_line: Optional[int] = None
) -> Tuple[bool, bool]:
    """(fully_inside_conf, fully_inside_expanded) any single land disc."""
    if not rs.base_is_water:
        # Land-base map: "inside land" means the annulus cannot touch any
        # water feature (annulus geometry incl. the r_min hole).
        conf = expanded = True
        for feat, band, _name in _water_features_m(rs, before_line):
            d, r = _feat_axis_dist(anchor_m, feat)
            if annulus_intersects_disc(d, r_min, r_max, r + band):
                conf = False
            if annulus_intersects_disc(d, r_min, r_max, max(0.0, r - band)):
                expanded = False
        return conf, expanded
    conf = expanded = False
    for area in _land_areas_at(rs, before_line):
        d = dist(anchor_m, (rs.grid.x_frac_to_m(area.x), rs.grid.z_frac_to_m(area.z)))
        band = _area_band_m(area)
        if d + r_max <= max(0.0, area.radius_m - band):
            conf = True
        if d + r_max <= area.radius_m + band:
            expanded = True
    return conf, expanded


def check_placement(p: ResolvedPlacement, rs: ResolvedScene) -> Finding:
    if not p.active:
        return Finding("placement", p.name, "INACTIVE", "info",
                       "gated off in this scenario (mode condition)")

    if p.kind == "in_area":
        def ref_matches(ref: str) -> bool:
            # Collapsed loop areas keep the loop prefix ("underwater_patch_
            # area" for members ..._area0..4): match refs by prefix there.
            return any(a.name == ref
                       or (a.count > 1 and ref.startswith(a.name))
                       for a in rs.areas)
        unknown_runtime = [ref for ref in p.area_refs if ref == "?"]
        missing = [ref for ref in p.area_refs
                   if ref != "?" and not ref_matches(ref)]
        if missing:
            return Finding("placement", p.name, "CONFIG", "error",
                           f"references unknown areas: {missing}")
        if unknown_runtime:
            return Finding("placement", p.name, "UNKNOWN_RUNTIME", "info",
                           "area reference resolved at runtime")
        if p.terrain_affinity == "land":
            refs = [a for a in rs.areas
                    if a.name in p.area_refs
                    or (a.count > 1 and any(r.startswith(a.name)
                                            for r in p.area_refs))]
            not_land = [a.name for a in refs if not area_is_land(rs, a)]
            if not_land:
                return Finding("placement", p.name, "WRONG_TERRAIN", "error",
                               f"land placement in non-land areas: {not_land}")
        return Finding("placement", p.name, "OK", "info", "placed inside authored areas")

    if p.kind == "closest_point" and p.runtime_expr:
        # The literal-anchor rule covers pure readbacks only (plan 1.2). A
        # closest-point search deliberately lands AWAY from its origin, so an
        # approx origin must not be checked as if it were the final position.
        origin = f" (search origin ~({p.x:.2f}, {p.z:.2f}))" if p.x is not None else ""
        return Finding("placement", p.name, "UNKNOWN_RUNTIME", "info",
                       f"closest-point search, result depends on generated terrain{origin}")

    if p.x is None or p.z is None:
        return Finding("placement", p.name, "UNKNOWN_RUNTIME", "info",
                       f"runtime-dependent anchor, not statically checkable: {p.runtime_expr}")

    grid = rs.grid
    if not (0.0 <= p.x <= 1.0 and 0.0 <= p.z <= 1.0):
        return Finding("placement", p.name, "OFF_MAP", "error",
                       f"anchor ({p.x:.3f}, {p.z:.3f}) outside the [0,1]^2 domain",
                       approximate=p.approx)

    if p.min_dist_m > p.max_dist_m:
        raise ValueError(f"{p.name}: min_dist_m {p.min_dist_m} > max_dist_m {p.max_dist_m}")

    anchor_m = grid.frac_to_m(p.x, p.z)
    center_m = (grid.x_frac_to_m(0.5), grid.z_frac_to_m(0.5))
    d_center_m = dist(anchor_m, center_m)
    warnings: List[Finding] = []

    if rs.world_circle:
        # True meter circle, diameter = the map's LONGER side (rect maps).
        circle_r_m = WORLD_CIRCLE_R * max(grid.size_x_m, grid.size_z_m)
        if not annulus_intersects_disc(d_center_m, p.min_dist_m, p.max_dist_m, circle_r_m):
            msg = (f"entire search annulus outside the world circle "
                   f"(anchor r={d_center_m / circle_r_m * WORLD_CIRCLE_R:.3f} frac)")
            if p.terrain_affinity == "water":
                warnings.append(Finding("placement", p.name, "EDGE_RISK", "warning",
                                        msg + " — water objects tolerate this in stock maps",
                                        approximate=p.approx))
            else:
                return Finding("placement", p.name, "OUTSIDE_CIRCLE", "error",
                               msg + " — placement will silently fail or fall back",
                               approximate=p.approx)
        else:
            r_frac = d_center_m / max(grid.size_x_m, grid.size_z_m)
            safe = SAFE_RADIUS_FRAC[p.category]
            if r_frac > safe:
                warnings.append(Finding(
                    "placement", p.name, "EDGE_RISK", "warning",
                    f"anchor at r={r_frac:.3f} frac, beyond the {p.category} "
                    f"safe radius {safe} (inferred constant, see plan 1.2)",
                    approximate=p.approx))

    if p.terrain_affinity == "land":
        solid, possible, nearest = _land_reach(rs, anchor_m, p.min_dist_m, p.max_dist_m,
                                               before_line=p.line)
        if not possible:
            return Finding("placement", p.name, "WRONG_TERRAIN", "error",
                           f"no authored land within reach (nearest: {nearest})",
                           approximate=p.approx)
        if not solid:
            warnings.append(Finding("placement", p.name, "NEAR_EDGE_OF_AREA", "warning",
                                    f"only reaches land inside the uncertainty band of {nearest}",
                                    approximate=p.approx))
    elif p.terrain_affinity == "water":
        conf, expanded = _inside_land(rs, anchor_m, p.min_dist_m, p.max_dist_m,
                                      before_line=p.line)
        if conf:
            return Finding("placement", p.name, "WRONG_TERRAIN", "error",
                           "water placement fully inside an authored land area",
                           approximate=p.approx)
        if expanded:
            warnings.append(Finding("placement", p.name, "NEAR_EDGE_OF_AREA", "warning",
                                    "water placement inside a land area's uncertainty band",
                                    approximate=p.approx))

    unsat: List[str] = []
    field_ctx = None
    for cname in p.constraints:
        spec = rs.constraints.get(cname)
        if spec is None:
            return Finding("placement", p.name, "CONFIG", "error",
                           f"constraint {cname!r} not in catalog")
        if not spec.get("applied", True) or spec["kind"] == "opaque":
            continue
        if spec["kind"] == "pie":
            pie_center_m = (grid.x_frac_to_m(spec["center"][0]), grid.z_frac_to_m(spec["center"][1]))
            r0 = float(resolve_branch(spec["r_min"], rs.scenario, grid))
            r1 = float(resolve_branch(spec["r_max"], rs.scenario, grid))
            d = dist(anchor_m, pie_center_m)
            if not annulus_intersects_annulus(d, p.min_dist_m, p.max_dist_m, r0, r1):
                unsat.append(cname)
        elif spec["kind"] == "box":
            x0, z0, x1, z1 = spec["box"]
            box_m = (grid.x_frac_to_m(x0), grid.z_frac_to_m(z0),
                     grid.x_frac_to_m(x1), grid.z_frac_to_m(z1))
            if not annulus_intersects_box(anchor_m, p.min_dist_m, p.max_dist_m, box_m):
                unsat.append(cname)
        else:
            # Terrain / class / route constraints: deterministic annulus
            # sampling — satisfied if ANY sample point in the search annulus
            # is allowed (WP3b; import here to avoid a module cycle).
            from scripts.mapsim.field import FieldContext, point_allowed
            if field_ctx is None:
                field_ctx = FieldContext(rs)
            radii = sorted({p.min_dist_m, (p.min_dist_m + p.max_dist_m) / 2.0, p.max_dist_m})
            satisfied = False
            for r in radii:
                if satisfied:
                    break
                if r == 0.0:
                    if point_allowed(field_ctx, anchor_m, spec, p.line) is not False:
                        satisfied = True
                    continue
                for k in range(16):
                    theta = 2.0 * math.pi * k / 16.0
                    sample = (anchor_m[0] + r * math.cos(theta),
                              anchor_m[1] + r * math.sin(theta))
                    if point_allowed(field_ctx, sample, spec, p.line) is not False:
                        satisfied = True
                        break
            if not satisfied:
                unsat.append(cname)
    if unsat:
        return Finding("placement", p.name, "CONSTRAINT_UNSAT", "error",
                       f"search annulus cannot satisfy: {unsat}",
                       approximate=p.approx, details={"unsat": unsat})

    if warnings:
        return warnings[0]
    return Finding("placement", p.name, "OK", "info",
                   "approximate (literal-anchor rule)" if p.approx else "ok",
                   approximate=p.approx)


def check_area_overlaps(rs: ResolvedScene) -> List[Finding]:
    findings = []
    located = [a for a in rs.areas if a.x is not None and a.creates_land]
    for i, a in enumerate(located):
        for b in located[i + 1:]:
            d_m = rs.grid.frac_dist_m(a.x, a.z, b.x, b.z)
            if d_m < 1e-9:
                continue  # deliberate same-center overlay (hills on islands)
            depth = a.radius_m + b.radius_m - d_m
            if depth <= 0:
                continue
            cliffy = (a.cliff_type is not None) != (b.cliff_type is not None)
            findings.append(Finding(
                "area_pair", f"{a.name} + {b.name}", "AREA_OVERLAP",
                "warning" if cliffy else "info",
                f"land discs overlap by {depth:.1f} m"
                + (" — cliff area cuts into a non-cliff area" if cliffy else ""),
                details={"depth_m": round(depth, 2)}))
    return findings


def check_trade_route(rs: ResolvedScene, blocksize_m: float) -> List[Finding]:
    findings = []
    routes = rs.all_routes()
    for wps in routes:
        for x, z in wps:
            if not (0.0 <= x <= 1.0 and 0.0 <= z <= 1.0):
                findings.append(Finding("route", "waypoint", "OFF_MAP", "error",
                                        f"waypoint ({x}, {z}) outside the domain"))
            if rs.world_circle and not in_world_circle((x, z)):
                findings.append(Finding("route", "waypoint", "OUTSIDE_CIRCLE", "warning",
                                        f"waypoint ({x}, {z}) outside the world circle"))
    polys_m = [[rs.grid.frac_to_m(x, z) for x, z in wps] for wps in routes if wps]
    snap = blocksize_m / 2.0
    for p in rs.placements:
        if not p.route_docked or p.x is None or not polys_m:
            continue
        d = min(dist_point_to_polyline(rs.grid.frac_to_m(p.x, p.z), poly)
                for poly in polys_m)
        allowed = p.max_dist_m + snap
        # Docked defs snap onto the route block grid, so moderate anchor drift
        # still docks — one extra blocksize is drift (warning), beyond is a
        # real detach (error, the historical harbours-off-the-route class).
        if d > allowed + blocksize_m:
            findings.append(Finding(
                "route", p.name, "ROUTE_TOO_FAR", "error",
                f"docked anchor is {d:.1f} m from the waypoint polyline "
                f"(allowed {allowed:.1f} m + {blocksize_m} m drift)",
                details={"distance_m": round(d, 2)}))
        elif d > allowed:
            findings.append(Finding(
                "route", p.name, "ROUTE_DRIFT", "warning",
                f"docked anchor is {d:.1f} m from the polyline; it will snap "
                f"up to a block away from where the anchor suggests",
                details={"distance_m": round(d, 2)}))
    return findings


def check_player_ring(rs: ResolvedScene, samples: int = 256) -> List[Finding]:
    """Land coverage of the circular player ring.

    Angular origin/direction of rmSetPlacementSection is NOT documented —
    full-ring coverage is origin-independent and reliable; per-section results
    would need the E3/E4 calibration, so only the full ring is checked here.
    """
    findings = []
    # Branches mirror the map's if / else-if / else: only the FIRST branch
    # whose when-condition matches this scenario runs.
    active_branch = None
    for branch in rs.player_placement.get("branches", []):
        if _check_when(branch.get("when", {}), rs.scenario):
            active_branch = branch
            break
    for branch in ([active_branch] if active_branch else []):
        if branch.get("kind") not in ("circular", "circular_teams"):
            continue
        r_mid = (branch["min"] + branch["max"]) / 2.0
        on_land = maybe_land = 0
        for k in range(samples):
            theta = 2.0 * math.pi * k / samples
            x = 0.5 + r_mid * math.cos(theta)
            z = 0.5 + r_mid * math.sin(theta)
            anchor_m = rs.grid.frac_to_m(x, z)
            solid, possible, _ = _land_reach(rs, anchor_m, 0.0, 0.0)
            if solid:
                on_land += 1
            elif possible:
                maybe_land += 1
        coverage = on_land / samples
        label = f"ring r={branch['min']}-{branch['max']}"
        runtime_land = any(a.engine_placed and a.creates_land for a in rs.areas)
        if coverage == 0.0 and maybe_land > 0:
            findings.append(Finding(
                "ring", label, "RING_LOW_LAND", "warning",
                f"ring only reaches land inside area uncertainty bands "
                f"({maybe_land}/{samples} sample points)",
                details={"maybe": round(maybe_land / samples, 3)}))
        elif coverage == 0.0 and runtime_land:
            findings.append(Finding(
                "ring", label, "UNKNOWN_RUNTIME", "info",
                "ring lands on runtime-placed areas — not statically checkable"))
        elif coverage == 0.0:
            findings.append(Finding("ring", label, "RING_OFF_LAND", "error",
                                    "no point of the player ring lies on authored land"))
        elif coverage < 0.25:
            findings.append(Finding(
                "ring", label, "RING_LOW_LAND", "warning",
                f"only {coverage:.0%} of the ring lies on authored land — "
                f"sections must hit that span or players fall back",
                details={"coverage": round(coverage, 3)}))
        else:
            findings.append(Finding("ring", label, "RING_OK", "info",
                                    f"{coverage:.0%} of the ring lies on authored land",
                                    details={"coverage": round(coverage, 3)}))
    return findings


def check_area_feasibility(rs: ResolvedScene) -> List[Finding]:
    """WP3b: constraint-derived effective areas (no blobs, constraints only).

    Located areas are judged by GROWTH SHORTFALL (budget-driven priority
    flood, plan research decision): an area only loses tiles when its
    reachable allowed component is smaller than its budget."""
    from scripts.mapsim.field import FieldContext, loop_feasibility, terrain_grid
    ctx = FieldContext(rs)
    findings: List[Finding] = []
    for area in rs.areas:
        if area.engine_placed:
            lf = loop_feasibility(ctx, area)
            if lf is None:
                continue
            detail = {"feasible_tiles": round(lf.feasible_tiles),
                      "demand_tiles": round(lf.demand_tiles),
                      "ratio": round(lf.ratio, 2), "skipped_constraints": lf.skipped}
            # The loops tolerate failure by design (break after 5 consecutive
            # rmBuildArea fails), so plain underfill is a warning; error only
            # when the region is so small the feature effectively vanishes.
            if lf.ratio < 0.3:
                findings.append(Finding(
                    "area_pair", area.name, "FEASIBLE_TOO_SMALL", "error",
                    f"loop demands ~{lf.demand_tiles:.0f} tiles but only "
                    f"{lf.feasible_tiles:.0f} feasible tiles exist (ratio {lf.ratio:.2f})",
                    details=detail))
            elif lf.ratio < 1.5:
                findings.append(Finding(
                    "area_pair", area.name, "FEASIBLE_TIGHT", "warning",
                    f"feasible region only {lf.ratio:.1f}x the demand "
                    f"({lf.feasible_tiles:.0f} vs {lf.demand_tiles:.0f} tiles) — "
                    f"expect underfill (loop breaks after 5 consecutive failures)",
                    details=detail))
            else:
                findings.append(Finding(
                    "area_pair", area.name, "FEASIBLE_OK", "info",
                    f"feasible region {lf.ratio:.1f}x the demand", details=detail))
    tg = terrain_grid(rs, ctx, cell_tiles=2.0)
    for name, (claimed, budget) in tg.shortfalls.items():
        ratio = claimed / budget if budget else 1.0
        findings.append(Finding(
            "area_pair", name, "AREA_SHORTFALL",
            "error" if ratio < 0.5 else "warning",
            f"area reached only {claimed}/{budget} cells ({ratio:.0%}) of its "
            f"tile budget — the reachable allowed region is too small "
            f"(kept partial, rmSetAreaWarnFailure idiom)",
            details={"claimed": claimed, "budget": budget, "ratio": round(ratio, 3)}))
    return findings


def run_checks(rs: ResolvedScene, blocksize_m: float = 16.0) -> List[Finding]:
    findings = [check_placement(p, rs) for p in rs.placements]
    findings += check_area_overlaps(rs)
    findings += check_trade_route(rs, blocksize_m)
    findings += check_player_ring(rs)
    findings += check_area_feasibility(rs)
    return findings
