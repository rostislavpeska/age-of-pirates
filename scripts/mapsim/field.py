"""Feasibility field: constraint-only "dynamic area" evaluation (plan WP3b).

No blobs — an entity's allowed region is the intersection of its evaluable
constraints against geometry the scene already knows: the authored-land disc
union (terrain constraints), class-tagged discs/rects (marker areas, bridge
footprint, socket/estate anchors), the trade-route polyline, and pies/boxes.
Sampling is DETERMINISTIC on the tile grid — stable across runs, testable.

Caveat (plan WP3b): terrain constraints reference *generated* terrain; this
module approximates it with the authored-disc union at nominal radii, so
results near shorelines inherit the disc model's uncertainty.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field as dfield
from typing import Any, Dict, List, Optional, Tuple

from scripts.mapsim.geometry import (
    WORLD_CIRCLE_R,
    dist,
    dist_point_to_polyline,
    dist_point_to_segment,
    dist_range_to_box,
)
from scripts.mapsim.scene import ResolvedArea, ResolvedScene, resolve_branch

Disc = Tuple[float, float, float, int]              # cx_m, cz_m, r_m, line
Rect = Tuple[float, float, float, float, int]       # x0, z0, x1, z1 (m), line


def connected_influence_segments(area: ResolvedArea, g) -> List[tuple]:
    """E7 RESOLVED (2026-08-09): the engine grows an area only along
    influence segments whose skeleton CHAINS back to the disc anchor; a
    segment cluster disconnected from the anchor contributes NO budget
    mass. Forensic proof on zpaustralia's Uluru mesa: the script anchors
    it at (0.5, 0.65) but keeps a stale 4-segment cage at (~0.5, 0.41),
    5.6x the radius away — the in-game minimap massif sits at the ANCHOR
    (view-transform verified to pixel precision via Lake Eyre at
    (0.55, 0.45)), while equal-weight seeding put 89% of the budget at
    the cage. Connection tolerance = the area's own radius; that keeps
    every legitimate chained skeleton in the corpus intact (Australia
    "big lone island" 25-segment ring dmin 0.014 of the anchor,
    IW/civilwar river segments dmin 0)."""
    segs = list(area.influence_segments)
    if not segs or area.x is None:
        return segs
    from scripts.mapsim.geometry import dist_point_to_segment
    anchor = (g.x_frac_to_m(area.x), g.z_frac_to_m(area.z))
    P = [(g.x_frac_to_m(x1), g.z_frac_to_m(z1),
          g.x_frac_to_m(x2), g.z_frac_to_m(z2)) for x1, z1, x2, z2 in segs]
    tol = area.radius_m

    def seg_seg_close(a: tuple, b: tuple) -> bool:
        (ax1, az1, ax2, az2), (bx1, bz1, bx2, bz2) = a, b
        return min(
            dist_point_to_segment((ax1, az1), (bx1, bz1), (bx2, bz2)),
            dist_point_to_segment((ax2, az2), (bx1, bz1), (bx2, bz2)),
            dist_point_to_segment((bx1, bz1), (ax1, az1), (ax2, az2)),
            dist_point_to_segment((bx2, bz2), (ax1, az1), (ax2, az2)),
        ) <= tol

    keep = [dist_point_to_segment(anchor, (x1, z1), (x2, z2)) <= tol
            for x1, z1, x2, z2 in P]
    changed = True
    while changed:
        changed = False
        for i in range(len(P)):
            if keep[i]:
                continue
            if any(keep[j] and seg_seg_close(P[i], P[j])
                   for j in range(len(P))):
                keep[i] = True
                changed = True
    return [s for s, k in zip(segs, keep) if k]


def _area_shapes_m(rs: ResolvedScene, area: ResolvedArea) -> List[tuple]:
    """An area's deterministic footprint: its disc plus a capsule along each
    anchor-connected influence segment (the engine grows the area along
    those lines — snapshot lines 376/390-392 shape the river channel and
    the gulf; disconnected segments are dead weight, see
    connected_influence_segments)."""
    g = rs.grid
    shapes: List[tuple] = [("disc", g.x_frac_to_m(area.x), g.z_frac_to_m(area.z),
                            area.radius_m)]
    for x1, z1, x2, z2 in connected_influence_segments(area, g):
        shapes.append(("capsule", g.x_frac_to_m(x1), g.z_frac_to_m(z1),
                       g.x_frac_to_m(x2), g.z_frac_to_m(z2), area.radius_m))
    return shapes


def _shape_clearance(p_m: Tuple[float, float], shape: tuple) -> float:
    """Signed distance from a point to the shape's boundary (negative inside)."""
    if shape[0] == "disc":
        _, cx, cz, r = shape
        return dist(p_m, (cx, cz)) - r
    if shape[0] == "rect":
        _, x0, z0, x1, z1 = shape
        lo, _ = dist_range_to_box(p_m, (x0, z0, x1, z1))
        return lo
    _, x1, z1, x2, z2, r = shape
    return dist_point_to_segment(p_m, (x1, z1), (x2, z2)) - r


class FieldContext:
    """Pre-resolved geometry shared by all point tests of one scenario."""

    def __init__(self, rs: ResolvedScene):
        self.rs = rs
        g = rs.grid
        self.grid = g
        self.base_is_water = rs.base_is_water
        self.routes_m: List[List[Tuple[float, float]]] = [
            [g.frac_to_m(x, z) for x, z in route] for route in rs.all_routes()
        ]
        self.route_m: List[Tuple[float, float]] = (
            self.routes_m[0] if self.routes_m else [])   # back-compat: first route
        self.land: List[Disc] = [
            (g.x_frac_to_m(a.x), g.z_frac_to_m(a.z), a.radius_m, a.line)
            for a in rs.land_areas()
        ]
        # Authored water features (for land-base maps, where terrain
        # constraints invert): water-type areas, elevation masks and river
        # capsules (scene.area_floods: a base height alone floods nothing
        # on a land-initialized map, 2026-09-25).
        from scripts.mapsim.scene import area_floods
        self.water_shapes: List[Tuple[tuple, int]] = []
        for a in rs.areas:
            if a.x is None:
                continue
            if area_floods(rs, a):
                for shape in _area_shapes_m(rs, a):
                    self.water_shapes.append((shape, a.line))
        for r in rs.rivers:
            halfw = float(r["width_m"]) / 2.0
            pts = [(g.x_frac_to_m(x), g.z_frac_to_m(z)) for x, z in r["waypoints"]]
            for (x1, z1), (x2, z2) in zip(pts, pts[1:]):
                self.water_shapes.append(
                    (("capsule", x1, z1, x2, z2, halfw), int(r.get("line", 0))))
        self.class_discs: Dict[str, List[Disc]] = {}
        self.class_rects: Dict[str, List[Rect]] = {}
        self.class_shapes: Dict[str, List[Tuple[tuple, int]]] = {}
        # Placement-only class geometry, kept separate: terrain_grid growth
        # measures area members from their ACTUAL claimed cells but must
        # still respect placement footprints (bridge decks, sockets), which
        # never claim cells.
        self.class_pshapes: Dict[str, List[Tuple[tuple, int]]] = {}
        for a in rs.areas:
            if a.x is None:
                continue
            for cls in a.classes:
                self.class_discs.setdefault(cls.lower(), []).append(
                    (g.x_frac_to_m(a.x), g.z_frac_to_m(a.z), a.radius_m, a.line))
                for shape in _area_shapes_m(rs, a):
                    self.class_shapes.setdefault(cls.lower(), []).append((shape, a.line))
        # Area shapes BY NAME: rmCreateAreaConstraint family targets one
        # specific area ("remain within" / "stay away" / "stay near" —
        # AoM code reference, verified 2026-08-10; wwcanyon mesas).
        self.area_shapes_by_name: Dict[str, List[Tuple[tuple, int]]] = {}
        for a in rs.areas:
            if a.x is None:
                continue
            for shape in _area_shapes_m(rs, a):
                self.area_shapes_by_name.setdefault(
                    a.name.lower(), []).append((shape, a.line))
        # Placed-type registry (plan Part H2): (type_lower, x_m, z_m, line)
        # for every unit a placement puts on the ground — object-def items
        # at the anchor, grouping XML units at anchor+offset. Grouping
        # units enter only AFTER the solver ran (their anchors move);
        # during solving gsolve deposits sequentially itself.
        self.placed_types: List[Tuple[str, float, float, int]] = []
        # id() of the placement each placed_types entry came from (parallel
        # list): lets a placement's own units be left out of its own
        # type-distance test (type_clear).
        self.placed_owner: List[int] = []
        self._type_match_cache: Dict[str, List[Tuple[float, float, int]]] = {}
        for p in rs.placements:
            if p.x is None:
                continue
            px, pz = g.frac_to_m(p.x, p.z)
            if p.is_grouping:
                # PINNED groupings (max_dist 0) cannot move: their units
                # are known before any solve and must constrain terrain
                # growth (IW's water avoids the bridge's zpBridgeFace
                # units). Annulus groupings enter only after the solver
                # fixed their spot.
                if (getattr(rs, "groupings_solved", False)
                        or float(p.max_dist_m or 0.0) <= 0.0):
                    self.deposit_grouping_types(p, px, pz)
            else:
                for t in getattr(p, "items", ()) or ():
                    self.placed_types.append((t.lower(), px, pz, p.line))
                    self.placed_owner.append(id(p))
        for p in rs.placements:
            if p.x is None or not p.classes:
                continue
            px, pz = g.frac_to_m(p.x, p.z)
            if p.footprint_tiles:
                hw = p.footprint_tiles[0] * g.TILE_M / 2.0
                hh = p.footprint_tiles[1] * g.TILE_M / 2.0
                rect = (px - hw, pz - hh, px + hw, pz + hh, p.line)
                for cls in p.classes:
                    self.class_rects.setdefault(cls.lower(), []).append(rect)
                    self.class_pshapes.setdefault(cls.lower(), []).append(
                        (("rect", px - hw, pz - hh, px + hw, pz + hh), p.line))
            else:
                for cls in p.classes:
                    self.class_discs.setdefault(cls.lower(), []).append((px, pz, 0.0, p.line))
                    self.class_pshapes.setdefault(cls.lower(), []).append(
                        (("disc", px, pz, 0.0), p.line))

    def _land_at(self, before_line: Optional[int]) -> List[Disc]:
        if before_line is None:
            return self.land
        return [d for d in self.land if d[3] <= before_line]

    def deposit_grouping_types(self, p, px_m: float, pz_m: float) -> None:
        """Register the units INSIDE a grouping at its (solved) anchor —
        the substrate of type-distance constraints (avoidSufi measures
        from each village's SocketApache). First prefix variant = the
        deterministic nominal, matching the footprint rule."""
        from scripts.refdata import catalog as _catalog
        from scripts.refdata.catalogs import grouping_units_m
        for e in _catalog("grouping").resolve(str(p.proto)):
            units = grouping_units_m(e.name)
            if units:
                for t, dx, dz in units:
                    self.placed_types.append(
                        (t.lower(), px_m + dx, pz_m + dz, p.line))
                    self.placed_owner.append(id(p))
                self._type_match_cache.clear()
                return

    def type_clear(self, spec: Dict[str, Any], p_m: Tuple[float, float],
                   before_line: Optional[int], exclude_owner: int) -> bool:
        """type_distance test that leaves out the units of ONE placement
        (the one being checked: a placement never avoids itself)."""
        from scripts.refdata.catalogs import proto_counts_as
        d = float(spec["distance_m"])
        key = ("owned", spec["type"].lower(), len(self.placed_types))
        hits = self._type_match_cache.get(key)
        if hits is None:
            hits = [(px, pz, ln, own) for (t, px, pz, ln), own
                    in zip(self.placed_types, self.placed_owner)
                    if proto_counts_as(t, spec["type"])]
            self._type_match_cache[key] = hits
        for px, pz, ln, own in hits:
            if own == exclude_owner:
                continue
            if before_line is not None and ln > before_line:
                continue
            if dist(p_m, (px, pz)) < d:
                return False
        return True

    def type_points(self, type_name: str) -> List[Tuple[float, float, int]]:
        """Registry entries whose proto counts as type_name (cached; the
        cache is cleared on every deposit)."""
        key = type_name.lower()
        hit = self._type_match_cache.get(key)
        if hit is None:
            from scripts.refdata.catalogs import proto_counts_as
            hit = [(px, pz, ln) for t, px, pz, ln in self.placed_types
                   if proto_counts_as(t, type_name)]
            self._type_match_cache[key] = hit
        return hit


def point_allowed(ctx: FieldContext, p_m: Tuple[float, float], spec: Dict[str, Any],
                  before_line: Optional[int] = None,
                  exclude_line: Optional[int] = None) -> Optional[bool]:
    """True/False when the constraint kind is evaluable; None when opaque.

    exclude_line: skip class shapes created on this line — an area's own
    footprint must not trip its own class-distance constraint (Tortuga's
    north island is in classIsland and avoids classIsland at 48 m; counting
    itself would forbid every cell it wants to claim)."""
    kind = spec.get("kind")
    if kind == "terrain":
        d = float(spec["distance_m"])
        if not ctx.base_is_water:
            # Land-base map (rmTerrainInitialize with a terrain texture):
            # everything is land except authored water features, so the
            # constraint inverts against the water-shape union.
            shapes = [s for s, ln in ctx.water_shapes
                      if before_line is None or ln <= before_line]
            if spec["avoid"] == "land":
                # must sit at least d INSIDE some water feature
                return any(_shape_clearance(p_m, s) <= -d for s in shapes)
            return all(_shape_clearance(p_m, s) >= d for s in shapes)
        land = ctx._land_at(before_line)
        if spec["avoid"] == "land":
            return all(dist(p_m, (cx, cz)) - r >= d for cx, cz, r, _ in land)
        # avoid "water": the point must lie at least d inside SOME land disc
        # (union depth approximated by the deepest single disc — conservative).
        return any(r - dist(p_m, (cx, cz)) >= d for cx, cz, r, _ in land)
    if kind == "class_distance":
        d = float(spec["distance_m"])
        cls = spec["class"].lower()
        for shape, line in ctx.class_shapes.get(cls, []):
            if before_line is not None and line > before_line:
                continue
            if exclude_line is not None and line == exclude_line:
                continue
            if _shape_clearance(p_m, shape) < d:
                return False
        for x0, z0, x1, z1, line in ctx.class_rects.get(cls, []):
            if before_line is not None and line > before_line:
                continue
            if exclude_line is not None and line == exclude_line:
                continue
            lo, _ = dist_range_to_box(p_m, (x0, z0, x1, z1))
            if lo < d:
                return False
        return True
    if kind == "route_distance":
        if not ctx.routes_m:
            return True
        # The route ROAD occupies 16 m blocks around the waypoint polyline
        # (the tool's established blocksize); the constraint keeps distance
        # from the road, so half a block is added to the authored margin.
        d_eff = float(spec["distance_m"]) + ROUTE_HALF_WIDTH_M
        return all(dist_point_to_polyline(p_m, route) >= d_eff
                   for route in ctx.routes_m)
    if kind == "pie":
        g = ctx.grid
        center = (g.x_frac_to_m(spec["center"][0]), g.z_frac_to_m(spec["center"][1]))
        r0 = float(resolve_branch(spec["r_min"], ctx.rs.scenario, g))
        r1 = float(resolve_branch(spec["r_max"], ctx.rs.scenario, g))
        return r0 <= dist(p_m, center) <= r1
    if kind == "box":
        g = ctx.grid
        x0, z0, x1, z1 = spec["box"]
        lo, _ = dist_range_to_box(
            p_m, (g.x_frac_to_m(x0), g.z_frac_to_m(z0), g.x_frac_to_m(x1), g.z_frac_to_m(z1)))
        return lo == 0.0
    if kind == "type_distance":
        d = float(spec["distance_m"])
        for px, pz, line in ctx.type_points(spec["type"]):
            if before_line is not None and line > before_line:
                continue
            if exclude_line is not None and line == exclude_line:
                continue
            if dist(p_m, (px, pz)) < d:
                return False
        return True
    if kind in ("area_within", "area_distance", "area_max"):
        shapes = ctx.area_shapes_by_name.get((spec.get("area") or "").lower())
        if not shapes:
            return None    # target area unknown/unlocated: opaque
        clear = min(_shape_clearance(p_m, s) for s, _ln in shapes)
        if kind == "area_within":
            return clear <= 0.0
        if kind == "area_distance":
            return clear >= float(spec.get("distance_m") or 0.0)
        return clear <= float(spec.get("distance_m") or 0.0)
    if kind == "terrain_max":
        d = float(spec["distance_m"])
        if not ctx.base_is_water:
            if spec["near"] == "land":
                return True     # land base: land is everywhere
            shapes = [s for s, ln in ctx.water_shapes
                      if before_line is None or ln <= before_line]
            return any(_shape_clearance(p_m, s) <= d for s in shapes)
        land = ctx._land_at(before_line)
        if spec["near"] == "land":
            return any(dist(p_m, (cx, cz)) - r <= d for cx, cz, r, _ in land)
        # near water on a water base: distance to the nearest non-land
        # point, approximated per containing disc; outside all discs the
        # point already stands in water.
        inside = [r - dist(p_m, (cx, cz)) for cx, cz, r, _ in land
                  if dist(p_m, (cx, cz)) <= r]
        return True if not inside else min(inside) <= d
    return None


def split_constraints(rs: ResolvedScene, names: List[str]) -> Tuple[List[Dict], List[str]]:
    """(evaluable specs, opaque names) for a constraint name list."""
    evaluable, opaque = [], []
    for name in names:
        spec = rs.constraints.get(name)
        if spec is None or not spec.get("applied", True):
            continue
        if spec.get("kind") in ("terrain", "class_distance", "route_distance",
                                "pie", "box", "type_distance", "area_within",
                                "area_distance", "area_max", "terrain_max"):
            evaluable.append(spec)
        else:
            opaque.append(name)
    return evaluable, opaque


def _all_allowed(ctx: FieldContext, p_m, specs, before_line,
                 exclude_line: Optional[int] = None) -> bool:
    for spec in specs:
        ok = point_allowed(ctx, p_m, spec, before_line, exclude_line)
        if ok is False:
            return False
    return True


def _in_world_circle_m(ctx: FieldContext, p_m) -> bool:
    # A TRUE meter circle whose diameter is the map's LONGER side (Paris
    # minimap ground truth: the 653x360 rectangle is cut by a circle as
    # wide as the 653 m side). Square maps reduce to the classic circle.
    g = ctx.grid
    dx = p_m[0] - g.size_x_m / 2.0
    dz = p_m[1] - g.size_z_m / 2.0
    r = WORLD_CIRCLE_R * max(g.size_x_m, g.size_z_m)
    return dx * dx + dz * dz <= r * r


def radius_to_tiles(radius_m: float) -> float:
    return math.pi * radius_m * radius_m / 4.0   # 4 m^2 per tile


# ---------------------------------------------------------------------------
# Priority-flood growth (research decision record, 2026-07-30):
# the engine accretes a TILE BUDGET from seed(s), filtering candidates by
# constraints; blocked directions redistribute the budget to the open
# frontier (documented accretion + the user's in-game observation that
# edge-seeded areas grow to larger radius). Algorithm: multi-source Dijkstra
# with 8-connectivity, sqrt(2) diagonal cost, lexicographic heap keys for
# total determinism; termination = exactly N claimed cells. Stdlib only.
# ---------------------------------------------------------------------------

# Shore standoff: real land blobs do not hug an avoided marker's boundary —
# they leave ragged clearance. Calibrated 2026-07-30 from three clean
# elbe_mini probes across the invisible corridor (59.3 / 77.5 / 86.0 m
# measured vs 47 m modeled with zero standoff): ~13 m per side.
SHORE_STANDOFF_M = 13.0

# Trade-route road half-width: routes are built from 16 m blocks — now
# DATA-BACKED, not inferred: data/traderoutedefs.xml <route blocksize=
# "16.0"> (verified 2026-08-09; checks.run_checks blocksize_m matches).
# Route-distance constraints measure from the road edge, half a block
# beyond the waypoint polyline.
ROUTE_HALF_WIDTH_M = 8.0

_SQRT2 = math.sqrt(2.0)
_NEIGHBORS = ((1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0),
              (1, 1, _SQRT2), (1, -1, _SQRT2), (-1, 1, _SQRT2), (-1, -1, _SQRT2))


def priority_flood(nx: int, nz: int, seeds: List[Tuple[int, int]], budget: int,
                   allowed) -> List[Tuple[int, int]]:
    """Claim exactly `budget` allowed cells nearest to their seeds.

    Cells are ranked by TRUE Euclidean distance to the seed they grew from
    (inherited along the flood), while expansion itself stays 8-connected —
    free-field areas come out as clean discs instead of chamfer octagons,
    obstacles still deflect growth without being jumped, and blocked budget
    redistributes to the open frontier (the researched engine model).

    `allowed(i, j) -> bool` is consulted lazily. Returns fewer than `budget`
    cells when the reachable allowed component is smaller (keep-partial,
    mirroring rmBuildArea's shortfall behavior). Deterministic: the heap key
    (distance, j, i) breaks ties identically on every run and platform.
    """
    import heapq
    import math as _math
    heap: List[Tuple[float, int, int]] = []
    seen = set()
    src: dict = {}
    for seed in seeds:
        i, j = seed[0], seed[1]
        d0 = float(seed[2]) if len(seed) > 2 else 0.0   # attractor offset (cells)
        if 0 <= i < nx and 0 <= j < nz and (i, j) not in seen and allowed(i, j):
            heapq.heappush(heap, (d0, j, i))
            seen.add((i, j))
            src[(i, j)] = (i, j, d0)
    claimed: List[Tuple[int, int]] = []
    while heap and len(claimed) < budget:
        d, j, i = heapq.heappop(heap)
        claimed.append((i, j))
        si, sj, s0 = src[(i, j)]
        for di, dj, _cost in _NEIGHBORS:
            ni, nj = i + di, j + dj
            if not (0 <= ni < nx and 0 <= nj < nz) or (ni, nj) in seen:
                continue
            if not allowed(ni, nj):
                seen.add((ni, nj))       # cache the rejection
                continue
            seen.add((ni, nj))
            src[(ni, nj)] = (si, sj, s0)
            nd = s0 + _math.hypot(ni - si, nj - sj)
            heapq.heappush(heap, (nd, nj, ni))
    return claimed


def _chamfer_dist_m(nx: int, nz: int, step_m: float,
                    sources: List[Tuple[int, int]]) -> List[List[float]]:
    """Multi-source 8-connectivity distance field in meters (chamfer BFS)."""
    import heapq
    INF = math.inf
    dist = [[INF] * nx for _ in range(nz)]
    heap: List[Tuple[float, int, int]] = []
    for i, j in sources:
        dist[j][i] = 0.0
        heap.append((0.0, j, i))
    heapq.heapify(heap)
    while heap:
        d, j, i = heapq.heappop(heap)
        if d > dist[j][i]:
            continue
        for di, dj, cost in _NEIGHBORS:
            ni, nj = i + di, j + dj
            if 0 <= ni < nx and 0 <= nj < nz:
                nd = d + cost * step_m
                if nd < dist[nj][ni]:
                    dist[nj][ni] = nd
                    heapq.heappush(heap, (nd, nj, ni))
    return dist


def _raster_cells(nx: int, nz: int, step_m: float, x1: float, z1: float,
                  x2: float, z2: float) -> List[Tuple[int, int]]:
    """Cells along a segment (meters), sampled at half-cell intervals."""
    length = max(dist((x1, z1), (x2, z2)), 1e-9)
    n = max(1, int(length / (step_m / 2.0)))
    cells = []
    for k in range(n + 1):
        t = k / n
        px, pz = x1 + t * (x2 - x1), z1 + t * (z2 - z1)
        i = min(nx - 1, max(0, int(px / step_m)))
        j = min(nz - 1, max(0, int(pz / step_m)))
        if (i, j) not in cells[-2:]:
            cells.append((i, j))
    return cells


@dataclass
class TerrainGrid:
    """Terrain state painted in build order over the rmTerrainInitialize base.

    water[z][x] : True where the cell surface is under water
    wdepth[z][x]: water depth in meters (surface minus floor) for water cells
    land[z][x]  : 0 = not claimed by a land-creating area, else 1-based index
                  into `land_order` (on a land-base map, unclaimed cells are
                  still land — consult `water`, not `land`, for land-ness)
    cliff[z][x] : 0 = no cliff area, else 1-based index into `cliff_order`
    marker[z][x]: True where a non-land authored claim reaches (river band,
                  water-type area, submerged ground, or invisible mask)
    cell_tiles  : sampling resolution
    """
    nx: int
    nz: int
    cell_tiles: float
    land: List[List[int]]
    marker: List[List[bool]]
    land_order: List[str]
    water: List[List[bool]] = dfield(default_factory=list)
    wdepth: List[List[float]] = dfield(default_factory=list)   # RAW depth (checks query it)
    wwalk: List[List[bool]] = dfield(default_factory=list)     # walkable water (source-aware)
    cliff: List[List[int]] = dfield(default_factory=list)
    cliff_band: List[List[bool]] = dfield(default_factory=list)  # impassable rim band
    cliff_order: List[str] = dfield(default_factory=list)
    sea_level: float = 0.0
    shortfalls: Dict[str, Tuple[int, int]] = dfield(default_factory=dict)  # name -> (claimed, budget)
    # Each cliff area's grown claim SNAPSHOT at build time — constraints
    # and influence segments already shaped it (the growth model), and it
    # is NEVER erased by later builds (user diagnosis 2026-08-09: "the
    # code was not that bad, the problem was overriding cliffs with other
    # land areas on top"). Display truth for cliff borders; the mutable
    # cliff/cliff_band arrays stay the passability model.
    cliff_claims: List[Tuple[str, List[Tuple[int, int]]]] = dfield(default_factory=list)
    # ACTUAL claimed cells per class (build-order accumulated) — exposed
    # for the grouping solver (Part H3): class/area distance measured from
    # grown reality, not authored discs (a mesa's authored disc covers the
    # valleys its grown claim leaves open).
    class_cells: Dict[str, List[Tuple[int, int]]] = dfield(default_factory=dict)
    # B1 canonical state (2026-09-25): wsurf[z][x] = height of the water
    # plane over the cell or None (no plane: land-initialized ground outside
    # lakes/rivers/masks); owner[z][x] = index into owner_names of the build
    # step that last wrote ground or water there (0 = rmTerrainInitialize).
    wsurf: List[List[Optional[float]]] = dfield(default_factory=list)
    owner: List[List[int]] = dfield(default_factory=list)
    owner_names: List[str] = dfield(default_factory=list)

    def cell_of_frac(self, x: float, z: float) -> Tuple[int, int]:
        i = min(self.nx - 1, max(0, int(x * self.nx)))
        j = min(self.nz - 1, max(0, int(z * self.nz)))
        return i, j

    def is_land_frac(self, x: float, z: float) -> bool:
        i, j = self.cell_of_frac(x, z)
        if self.water:
            return not self.water[j][i]
        return self.land[j][i] != 0

    def class_code(self, i: int, j: int) -> int:
        """Layer-2 Terrain Standard class: 0 LAND, 1 SHALLOW (walkable +
        buildable, depth <= SHALLOW_BUILD_DEPTH_M), 2 DEEP, 3 CLIFF band."""
        if self.cliff_band and self.cliff_band[j][i]:
            return 3
        if self.water[j][i]:
            return 1 if (self.wwalk and self.wwalk[j][i]) else 2
        return 0

    def digest(self) -> Dict[str, Any]:
        """Golden-grid digest (plan B6): class histogram + a 32x32 majority
        downsample. Byte-stable across runs; any model change shows as an
        explicit golden diff in review."""
        hist = [0, 0, 0, 0]
        codes = [[0] * self.nx for _ in range(self.nz)]
        for j in range(self.nz):
            for i in range(self.nx):
                c = self.class_code(i, j)
                codes[j][i] = c
                hist[c] += 1
        grid32 = []
        for bj in range(32):
            row = []
            j0 = bj * self.nz // 32
            j1 = max(j0 + 1, (bj + 1) * self.nz // 32)
            for bi in range(32):
                i0 = bi * self.nx // 32
                i1 = max(i0 + 1, (bi + 1) * self.nx // 32)
                counts = [0, 0, 0, 0]
                for j in range(j0, j1):
                    for i in range(i0, i1):
                        counts[codes[j][i]] += 1
                row.append(str(max(range(4), key=lambda k: (counts[k], -k))))
            grid32.append("".join(row))
        return {"classes": ["LAND", "SHALLOW", "DEEP", "CLIFF"],
                "hist": hist, "grid32": grid32}


def terrain_grid(rs: ResolvedScene, ctx: Optional[FieldContext] = None,
                 cell_tiles: float = 1.0, on_step=None,
                 water_log: Optional[list] = None) -> TerrainGrid:
    """Compute every area's shape by BUDGET-DRIVEN GROWTH (priority flood).

    Faithful to the researched engine model: each area accretes exactly its
    authored tile budget from its seed (center plus influence-segment lines),
    through cells its constraints allow at build time; blocked directions
    redistribute the budget to the open frontier (the user-observed edge law:
    an edge-seeded area grows to sqrt(2) x its free-field radius). When the
    reachable allowed component is smaller than the budget, the partial
    footprint is KEPT and the shortfall recorded (rmSetAreaWarnFailure idiom).
    Marker areas (river/gulf) grow first and expose chamfer distance fields
    that later class-distance constraints consume. Deterministic throughout.
    """
    from scripts.mapsim.waterdata import SHALLOW_BUILD_DEPTH_M, depth_of

    if ctx is None:
        ctx = FieldContext(rs)
    g = rs.grid
    step = cell_tiles * g.TILE_M
    nx = int(g.size_x_m / step)
    nz = int(g.size_z_m / step)
    land = [[0] * nx for _ in range(nz)]
    marker = [[False] * nx for _ in range(nz)]
    # Base state from rmTerrainInitialize: a flooded base is water carved to
    # the sea type's XML depth; a terrain-texture base is land.
    base_water = rs.base_is_water
    base_depth = depth_of(rs.sea_type) if base_water else 0.0
    water = [[base_water] * nx for _ in range(nz)]
    wdepth = [[base_depth] * nx for _ in range(nz)]
    wwalk = [[base_water and base_depth <= SHALLOW_BUILD_DEPTH_M] * nx
             for _ in range(nz)]
    # B1 `water_surface` (plan_mapsim_architecture.md part B): the height of
    # the water plane covering each cell, or None. A flooded base lies under
    # the sea plane everywhere. A LAND-initialized base has NO plane: the
    # sea level floods nothing there, water exists only where a water-typed
    # area, a river or an elevation mask puts it (fix 2026-09-25, mapsim
    # feedback item 1). Evidence: vanilla Mexico.xs (sea 4.0, land at 2.0,
    # player areas without a base height, a dry land map), Fertile
    # Crescent.xs (sea 3.0, land at 0.0, "land" map with rivers),
    # Manchuria.xs (sea 5.0, land at 4.0, its "spur" at 2.5), and the owner:
    # zpdeadsea / zpeyrebasin (sea 6.0, land at 1.0, players at 2.0) play
    # with their players on land.
    wsurf: List[List[Optional[float]]] = [
        [rs.sea_level if base_water else None] * nx for _ in range(nz)]
    # B1 `owner`: the build step that last wrote ground or water in a cell
    # (index into owner_names; 0 = rmTerrainInitialize).
    owner = [[0] * nx for _ in range(nz)]
    owner_names: List[str] = ["(base terrain)"]
    cliff = [[0] * nx for _ in range(nz)]
    cliff_band = [[False] * nx for _ in range(nz)]
    cliff_claims: List[Tuple[str, List[Tuple[int, int]]]] = []
    cliff_order: List[str] = []
    # Class geometry accumulates ACTUAL claimed cells per class as areas
    # build (build-order faithful). The analytic authored-disc fallback in
    # point_allowed vastly overstates constrained areas (Paris's shoreLine
    # band has a 229 m authored disc but grows as a thin river strip), so
    # once a class has built cells, distance is measured from those.
    class_cells: Dict[str, List[Tuple[int, int]]] = {}
    class_became_water: Dict[str, bool] = {}
    _field_cache: Dict[str, Tuple[int, List[List[float]]]] = {}

    def class_field(cls: str):
        cells_ = class_cells.get(cls)
        if not cells_:
            return None
        cached = _field_cache.get(cls)
        if cached is not None and cached[0] == len(cells_):
            return cached[1]
        fld = _chamfer_dist_m(nx, nz, step, cells_)
        _field_cache[cls] = (len(cells_), fld)
        return fld

    shortfalls: Dict[str, Tuple[int, int]] = {}

    def _snapshot() -> TerrainGrid:
        """Deep-copied state for the layering debugger (--layers)."""
        return TerrainGrid(nx, nz, cell_tiles,
                           [r[:] for r in land], [r[:] for r in marker],
                           list(land_order),
                           water=[r[:] for r in water],
                           wdepth=[r[:] for r in wdepth],
                           wwalk=[r[:] for r in wwalk],
                           cliff=[r[:] for r in cliff],
                           cliff_band=[r[:] for r in cliff_band],
                           cliff_order=list(cliff_order),
                           sea_level=rs.sea_level,
                           shortfalls=dict(shortfalls),
                           wsurf=[r[:] for r in wsurf],
                           owner=[r[:] for r in owner],
                           owner_names=list(owner_names))

    log_prev = ([r[:] for r in water] if water_log is not None else None)

    def _emit(kind: str, name: str, line: int, category: str, cells_) -> None:
        if water_log is not None:
            # (line, [(i, j, is_water)]) for every cell this step flipped -
            # checks replay it to see the terrain at a placement's line.
            changed = []
            for i, j in cells_:
                w = water[j][i]
                if log_prev[j][i] != w:
                    log_prev[j][i] = w
                    changed.append((i, j, w))
            if changed:
                water_log.append((line, changed))
        if on_step is not None:
            on_step({"kind": kind, "name": name, "line": line,
                     "category": category, "cells": list(cells_),
                     "snapshot": _snapshot()})

    # Build sequence: located areas AND rivers, interleaved by script line —
    # rivers paint water bands over whatever land exists at their build point
    # (the coastal-bank idiom: land area first, river carves through it).
    located = sorted((a for a in rs.areas if a.x is not None), key=lambda a: a.line)
    build_items: List[tuple] = [("area", a.line, a) for a in located]
    build_items += [("river", r.get("line", 0), r) for r in rs.rivers]
    build_items += [("conn", c.get("line", 0), c) for c in rs.connections]
    build_items.sort(key=lambda t: t[1])
    land_order: List[str] = []

    def make_allowed(area, specs, depth_field, landdist_field, obey_circle):
        memo: Dict[Tuple[int, int], bool] = {}

        def allowed(i: int, j: int) -> bool:
            key = (i, j)
            hit = memo.get(key)
            if hit is not None:
                return hit
            p = ((i + 0.5) * step, (j + 0.5) * step)
            ok = True
            if obey_circle and not _in_world_circle_m(ctx, p):
                ok = False
            if ok:
                for s in specs:
                    kind = s["kind"]
                    if kind == "terrain":
                        d = float(s["distance_m"])
                        fld = depth_field if s["avoid"] == "water" else landdist_field
                        ok = fld is not None and fld[j][i] >= d
                    elif kind == "class_distance":
                        cls = s["class"].lower()
                        d_min = float(s["distance_m"])
                        fld = class_field(cls)
                        if fld is not None:
                            # The calibrated shore standoff is a LAND-vs-
                            # WATER clearance (Elbe probes); land avoiding
                            # a class whose cells stayed land keeps the
                            # exact authored distance.
                            standoff = (SHORE_STANDOFF_M
                                        if area.creates_land
                                        and class_became_water.get(cls, False)
                                        else 0.0)
                            ok = fld[j][i] >= d_min + standoff
                            # Placement footprints (bridge decks, sockets)
                            # never claim cells — check them separately.
                            if ok:
                                for shape, ln in ctx.class_pshapes.get(cls, []):
                                    if ln > area.line:
                                        continue
                                    if _shape_clearance(p, shape) < d_min:
                                        ok = False
                                        break
                        else:
                            ok = point_allowed(ctx, p, s, area.line,
                                               exclude_line=area.line) is not False
                    else:
                        ok = point_allowed(ctx, p, s, area.line,
                                           exclude_line=area.line) is not False
                    if not ok:
                        break
            memo[key] = ok
            return ok
        return allowed

    for kind_tag, _line, item in build_items:
        if kind_tag == "river":
            poly = [(g.x_frac_to_m(x), g.z_frac_to_m(z)) for x, z in item["waypoints"]]
            halfw = float(item["width_m"]) / 2.0
            r_depth = depth_of(item.get("water_type"))
            xs = [p[0] for p in poly]
            zs = [p[1] for p in poly]
            i0 = max(0, int((min(xs) - halfw) / step) - 1)
            i1 = min(nx - 1, int((max(xs) + halfw) / step) + 1)
            j0 = max(0, int((min(zs) - halfw) / step) - 1)
            j1 = min(nz - 1, int((max(zs) + halfw) / step) + 1)
            step_cells: List[Tuple[int, int]] = []
            r_name = f"river {item.get('water_type') or ''}".strip()
            owner_names.append(r_name)
            r_owner = len(owner_names) - 1
            for j in range(j0, j1 + 1):
                pz = (j + 0.5) * step
                for i in range(i0, i1 + 1):
                    if dist_point_to_polyline(((i + 0.5) * step, pz), poly) <= halfw:
                        land[j][i] = 0
                        cliff[j][i] = 0
                        cliff_band[j][i] = False
                        marker[j][i] = True
                        water[j][i] = True
                        wdepth[j][i] = r_depth
                        wwalk[j][i] = False
                        # the sea level IS the river surface ("rmSetSeaLevel
                        # ... height of river surface compared to surrounding
                        # land", vanilla Florida/Fertile Crescent/Manchuria)
                        wsurf[j][i] = rs.sea_level
                        owner[j][i] = r_owner
                        step_cells.append((i, j))
            # Authored fords (rmRiverAddShallow at length-fraction t): a
            # walkable shallow disc of the river's shallow radius.
            seg_lens = [dist(a_, b_) for a_, b_ in zip(poly, poly[1:])]
            total = sum(seg_lens) or 1.0
            for t in item.get("shallows", []):
                target = t * total
                acc = 0.0
                for (pA, pB), sl in zip(zip(poly, poly[1:]), seg_lens):
                    if acc + sl >= target and sl > 0:
                        f = (target - acc) / sl
                        fx = pA[0] + f * (pB[0] - pA[0])
                        fz = pA[1] + f * (pB[1] - pA[1])
                        rad = float(item.get("shallow_radius_m", 15.0))
                        fi0 = max(0, int((fx - rad) / step))
                        fi1 = min(nx - 1, int((fx + rad) / step))
                        fj0 = max(0, int((fz - rad) / step))
                        fj1 = min(nz - 1, int((fz + rad) / step))
                        for jj in range(fj0, fj1 + 1):
                            for ii in range(fi0, fi1 + 1):
                                if water[jj][ii] and dist(((ii + 0.5) * step,
                                                          (jj + 0.5) * step),
                                                         (fx, fz)) <= rad:
                                    wdepth[jj][ii] = min(wdepth[jj][ii],
                                                         SHALLOW_BUILD_DEPTH_M)
                                    wwalk[jj][ii] = True
                        break
                    acc += sl
            _emit("river", r_name, int(item.get("line", 0)), "river band", step_cells)
            continue
        if kind_tag == "conn":
            # Causeway between two areas: RAISES the sea floor along its
            # path to the connection base height, never digging through
            # existing land (its purpose is connecting). Same elevation
            # rule as terrain: at/above sea level -> walkable land strip
            # (Tortuga's bh==sea sand causeways), below -> shallower water
            # (Hawaii's 0.5 m fords under sea 1.0). The segment is trimmed
            # by each end-area's radius — the engine routes edge to edge.
            p1 = [g.x_frac_to_m(item["x1"]), g.z_frac_to_m(item["z1"])]
            p2 = [g.x_frac_to_m(item["x2"]), g.z_frac_to_m(item["z2"])]
            seg_len = dist(tuple(p1), tuple(p2))
            r1 = float(item.get("r1_m", 0.0))
            r2 = float(item.get("r2_m", 0.0))
            if seg_len > r1 + r2 and seg_len > 0:
                ux = (p2[0] - p1[0]) / seg_len
                uz = (p2[1] - p1[1]) / seg_len
                p1 = [p1[0] + ux * r1, p1[1] + uz * r1]
                p2 = [p2[0] - ux * r2, p2[1] - uz * r2]
            p1, p2 = tuple(p1), tuple(p2)
            halfw = float(item["width_m"]) / 2.0
            bh = float(item["base_height"])
            i0 = max(0, int((min(p1[0], p2[0]) - halfw) / step) - 1)
            i1 = min(nx - 1, int((max(p1[0], p2[0]) + halfw) / step) + 1)
            j0 = max(0, int((min(p1[1], p2[1]) - halfw) / step) - 1)
            j1 = min(nz - 1, int((max(p1[1], p2[1]) + halfw) / step) + 1)
            step_cells = []
            band_cells = []
            n_dry = 0
            owner_names.append("causeway")
            c_owner = len(owner_names) - 1
            for j in range(j0, j1 + 1):
                pz = (j + 0.5) * step
                for i in range(i0, i1 + 1):
                    if dist_point_to_segment(((i + 0.5) * step, pz), p1, p2) > halfw:
                        continue
                    band_cells.append((i, j))
                    if not water[j][i]:
                        continue    # never dig through existing land
                    step_cells.append((i, j))
                    cliff[j][i] = 0
                    cliff_band[j][i] = False
                    owner[j][i] = c_owner
                    # Same elevation rule as terrain, against the plane that
                    # covers THIS cell (sea on a flooded base, the lake's own
                    # surface elsewhere): at/above it -> dry strip.
                    surf = wsurf[j][i] if wsurf[j][i] is not None else rs.sea_level
                    if bh >= surf:
                        water[j][i] = False
                        wdepth[j][i] = 0.0
                        wwalk[j][i] = False
                        n_dry += 1
                    else:
                        wdepth[j][i] = min(wdepth[j][i], surf - bh)
                        wwalk[j][i] = wdepth[j][i] <= SHALLOW_BUILD_DEPTH_M
            # rmAddConnectionToClass (ref:376): the band joins the class for
            # later class-distance constraints.
            for cls in item.get("classes", []) or []:
                class_cells.setdefault(cls.lower(), []).extend(band_cells)
            c_dry = n_dry == len(step_cells) if step_cells else bh >= rs.sea_level
            _emit("connection", "causeway", int(item.get("line", 0)),
                  "causeway (land)" if c_dry else "causeway (shallow)", step_cells)
            continue
        area = item
        specs, _skipped = split_constraints(rs, area.constraints)
        cx, cz = g.x_frac_to_m(area.x), g.z_frac_to_m(area.z)
        seeds: List[tuple] = [(min(nx - 1, max(0, int(cx / step))),
                              min(nz - 1, max(0, int(cz / step))))]
        # Influence segments: the location and every ANCHOR-CONNECTED
        # segment cell seed with equal weight — the area elongates along
        # the line and the width emerges from the budget (countryside S on
        # Elbe is a band along its segment; the IW channel mask spans its
        # full segment run). Disconnected segment clusters get NO seeds:
        # the previous "Uluru forms AT its segment ring" calibration was a
        # y-flip misread of the rotated minimap — the massif is at the
        # anchor (E7, see connected_influence_segments).
        for x1, z1, x2, z2 in connected_influence_segments(area, g):
            seeds += _raster_cells(nx, nz, step,
                                   g.x_frac_to_m(x1), g.z_frac_to_m(z1),
                                   g.x_frac_to_m(x2), g.z_frac_to_m(z2))
        budget = max(1, round(math.pi * area.radius_m ** 2 / (step * step)))

        depth_field = landdist_field = None
        if any(s["kind"] == "terrain" for s in specs):
            # Land/water sets come from the evolving STATE grid (base terrain
            # included) — on a land-init map the whole base counts as land.
            land_cells = [(i, j) for j in range(nz) for i in range(nx) if not water[j][i]]
            water_cells = [(i, j) for j in range(nz) for i in range(nx) if water[j][i]]
            if any(s["kind"] == "terrain" and s["avoid"] == "water" for s in specs):
                depth_field = _chamfer_dist_m(nx, nz, step, water_cells)
            if any(s["kind"] == "terrain" and s["avoid"] == "land" for s in specs):
                landdist_field = _chamfer_dist_m(nx, nz, step, land_cells)

        obey_circle = rs.world_circle and area.obey_world_circle
        allowed_fn = make_allowed(area, specs, depth_field,
                                  landdist_field, obey_circle)
        if seeds and not any(allowed_fn(s[0], s[1]) for s in seeds):
            # Engine blob placement finds nearby valid ground when the
            # authored anchor itself is disallowed (a nominal ring anchor
            # can land inside a keep-out margin). Deterministic spiral to
            # the nearest allowed cell, tie-broken (radius, j, i).
            si, sj = seeds[0][0], seeds[0][1]
            found = None
            for r in range(1, 51):
                ring = []
                for dj in range(-r, r + 1):
                    for di in range(-r, r + 1):
                        if max(abs(di), abs(dj)) != r:
                            continue
                        ni, nj = si + di, sj + dj
                        if 0 <= ni < nx and 0 <= nj < nz and allowed_fn(ni, nj):
                            ring.append((nj, ni))
                if ring:
                    nj, ni = min(ring)
                    found = (ni, nj)
                    break
            if found is not None:
                seeds = [found]
        cells = priority_flood(nx, nz, seeds, budget, allowed_fn)
        owner_names.append(area.name)
        a_owner = len(owner_names) - 1
        writes_ground = False
        n_wet = 0
        if area.water_type is not None:
            # rmSetAreaWaterType paints REAL water and carves elevation
            # itself (rm_commands_reference.md:354); with a base height the
            # SURFACE rides above sea level (Riverina cascade) — still water.
            step_cat = "water area"
            writes_ground = True
            a_depth = depth_of(area.water_type)
            a_walk = a_depth <= SHALLOW_BUILD_DEPTH_M
            a_surf = (area.base_height if area.base_height is not None
                      else rs.sea_level)
            for i, j in cells:
                water[j][i] = True
                wdepth[j][i] = a_depth
                wwalk[j][i] = a_walk
                wsurf[j][i] = a_surf
                marker[j][i] = True
                land[j][i] = 0
                cliff[j][i] = 0
                cliff_band[j][i] = False
            n_wet = len(cells)
        elif area.creates_land and area.base_height is None:
            # Curated scenes may flag land without a height (legacy
            # creates_land contract): land everywhere, as before.
            step_cat = "land"
            writes_ground = True
            land_order.append(area.name)
            code = len(land_order)
            for i, j in cells:
                land[j][i] = code
                water[j][i] = False
                wdepth[j][i] = 0.0
                wwalk[j][i] = False
                cliff[j][i] = 0
        elif area.base_height is not None:
            # Ground at the area's base height (B2.6b), judged PER CELL
            # against the water plane that covers the cell (B2.1/B2.4):
            # water iff the plane is above the ground (depth > 0), with
            # depth = surface - ground; otherwise land. On a flooded base
            # the plane is the sea level everywhere - the old rule "base
            # height <= sea level -> submerged" (Cook Islands -0.25 shoals,
            # -5.0 reef rings, Hawaii fords) - but at EXACTLY the plane the
            # cell is land now, as the standard (B2.4 "land iff depth <= 0")
            # and the connection rule (Tortuga's bh == sea causeways are
            # dry) already said. On a LAND-initialized base only lakes,
            # rivers and masks carry a plane: Dead Sea's players (2.0 under
            # sea 6.0) stand on land, Eyre Basin's King's Island (1.0) is an
            # island in its 0.0 lake.
            writes_ground = True
            bh = float(area.base_height)
            code = None
            for i, j in cells:
                surf = wsurf[j][i]
                if surf is not None and bh < surf:
                    depth = surf - bh
                    water[j][i] = True
                    wdepth[j][i] = depth
                    wwalk[j][i] = depth <= SHALLOW_BUILD_DEPTH_M
                    marker[j][i] = True
                    land[j][i] = 0
                    cliff[j][i] = 0
                    cliff_band[j][i] = False
                    n_wet += 1
                else:
                    if code is None:
                        land_order.append(area.name)
                        code = len(land_order)
                    land[j][i] = code
                    water[j][i] = False
                    wdepth[j][i] = 0.0
                    wwalk[j][i] = False
                    cliff[j][i] = 0
                    # cliff_band DELIBERATELY PERSISTS on dry cells: the
                    # engine keeps blocking placements on a cliff's
                    # footprint even after a ramp / later land area builds
                    # over it — user-verified in-game 2026-08-09, an RM
                    # generation bug this model must reproduce for spawn
                    # checks to be truthful. Water builds still clear the
                    # band: flooded ground blocks as WATER, not as cliff.
            if not cells or n_wet == 0:
                step_cat = "land"
            elif n_wet == len(cells):
                step_cat = "submerged ground"
            else:
                step_cat = "land + submerged ground"
        elif area.cliff_type is not None:
            # Cliff area with no base height: rmSetAreaCliffHeight shapes the
            # interior but the ground stays at its inherited state (Uluru /
            # Blue Mountains mesas on land, reef walls under water).
            step_cat = "cliff (inherits ground)"
        elif area.has_paint:
            # Texture-only area (rmSetAreaMix / terrain layer, no height):
            # paints the ground it finds without touching elevation —
            # Australia's "mountains terrain" massif around Uluru (measured
            # 3246 tiles on the minimap ~ mesa 1200 + paint 1800). Recorded
            # for rendering; land/water state untouched.
            step_cat = "painted (texture only)"   # Layer-3 concern: no terrain state
        elif area.height_blend >= 2.0:
            # A high height blend flattens the stamp into the surroundings
            # (rm_commands_reference.md:315 "anything above 2 may flatten an
            # area completely") — Paris's city-hill masks (blend 3) stay dry
            # in-game. Pure constraint claim.
            step_cat = "invisible mask (blend-flattened)"
            for i, j in cells:
                marker[j][i] = True
        else:
            # Invisible claim (no height/water/cliff/paint, no flattening
            # blend). Whether it carves depends on the elevation family:
            # the guide's water-mask pattern REQUIRES ElevationVariation(0.0)
            # ("must be flat", guide:6038) — such masks carve down to the
            # SEA TYPE's floor (sea level − body depth), never raising an
            # existing water floor (IW author comment: "carves nothing"
            # over open sea). Forensic evidence 2026-08-09: Civil War's
            # arms BLOCK land units (fords/bridges exist to cross ⇒ deep,
            # great lakes2 = 6 m) and Elbe's gulf carries the SHIP trade
            # route (⇒ ≥2 m, Hansa Baltic = 3 m) — a height-0 stamp would
            # make both walkable, contradicting the maps themselves.
            stamp_wet = area.has_elevation and rs.sea_level >= 0.0
            step_cat = ("invisible mask (carve to sea floor)" if stamp_wet
                        else "invisible template (dry)")
            for i, j in cells:
                marker[j][i] = True
                if stamp_wet and not water[j][i]:
                    water[j][i] = True
                    wdepth[j][i] = depth_of(rs.sea_type)
                    wwalk[j][i] = wdepth[j][i] <= SHALLOW_BUILD_DEPTH_M
                    wsurf[j][i] = rs.sea_level
                    owner[j][i] = a_owner
                    land[j][i] = 0
                    cliff[j][i] = 0
                    cliff_band[j][i] = False
            if stamp_wet:
                n_wet = len(cells)
        if writes_ground:
            for i, j in cells:
                owner[j][i] = a_owner
        # Did this area's claim end up as WATER? (drives the shore standoff
        # for later land growth — a class whose members stayed land must
        # not trigger it; review finding 2026-08-08). Read from the cells
        # the step actually flooded (per-cell rule, 2026-09-25).
        wet_claim = (area.water_type is not None or n_wet > 0
                     or (area.is_invisible() and area.has_elevation
                         and area.height_blend < 2.0 and rs.sea_level >= 0.0))
        for cls in area.classes:
            key = cls.lower()
            class_cells.setdefault(key, []).extend(cells)
            class_became_water[key] = class_became_water.get(key, False) or wet_claim
        if area.cliff_type is not None and cells:
            cliff_order.append(area.name)
            ccode = len(cliff_order)
            claim = set(cells)
            cliff_claims.append((area.name, list(cells)))
            for i, j in cells:
                cliff[j][i] = ccode
            # The impassable RIM band (the spawn killer, guide:10960):
            # boundary cells of the claim...
            for i, j in cells:
                for di, dj, _c in _NEIGHBORS[:4]:
                    if (i + di, j + dj) not in claim:
                        cliff_band[j][i] = True
                        break
            if area.cliff_raised():
                # Cliff SIDES slope outward roughly one meter per meter of
                # height (default height 4.0) — the painted rock footprint
                # is the claim dilated by that run.
                h = area.cliff_height if area.cliff_height is not None else 4.0
                rings = max(1, min(4, round(h / step)))
                frontier = list(cells)
                for _ in range(rings):
                    nxt = []
                    for i, j in frontier:
                        for di, dj, _c in _NEIGHBORS[:4]:
                            ni, nj = i + di, j + dj
                            if (0 <= ni < nx and 0 <= nj < nz
                                    and cliff[nj][ni] == 0):
                                cliff[nj][ni] = ccode
                                cliff_band[nj][ni] = True   # ...plus the sloped side run
                                nxt.append((ni, nj))
                    frontier = nxt
        if len(cells) < budget:
            shortfalls[area.name] = (len(cells), budget)
        if area.cliff_type is not None:
            step_cat += " + cliff " + ("rock" if area.cliff_raised() else "rim")
        _emit("area", area.name, area.line, step_cat, cells)
    return TerrainGrid(nx, nz, cell_tiles, land, marker, land_order,
                       water=water, wdepth=wdepth, wwalk=wwalk, cliff=cliff,
                       cliff_band=cliff_band, cliff_order=cliff_order,
                       sea_level=rs.sea_level, shortfalls=shortfalls,
                       cliff_claims=cliff_claims, class_cells=class_cells,
                       wsurf=wsurf, owner=owner, owner_names=owner_names)


@dataclass
class AreaFeasibility:
    name: str
    allowed_fraction: float          # of the authored disc (located areas)
    evaluated: int
    skipped: List[str]


@dataclass
class LoopFeasibility:
    name: str
    feasible_tiles: float
    demand_tiles: float
    ratio: float
    evaluated: int
    skipped: List[str]
    allowed_points: List[Tuple[float, float]]   # fraction-space, for overlays


def area_allowed_fraction(ctx: FieldContext, area: ResolvedArea,
                          cell_tiles: float = 1.0) -> Optional[AreaFeasibility]:
    """Fraction of a located area's authored disc its constraints allow."""
    if area.x is None or not area.constraints:
        return None
    specs, skipped = split_constraints(ctx.rs, area.constraints)
    if not specs:
        return None
    g = ctx.grid
    cx, cz = g.frac_to_m(area.x, area.z)
    r = area.radius_m
    step = cell_tiles * g.TILE_M
    clip_circle = ctx.rs.world_circle and area.obey_world_circle
    allowed = total = 0
    n = max(1, int(r / step))
    for i in range(-n, n + 1):
        for j in range(-n, n + 1):
            px, pz = cx + i * step, cz + j * step
            if dist((px, pz), (cx, cz)) > r:
                continue
            total += 1
            if clip_circle and not _in_world_circle_m(ctx, (px, pz)):
                continue  # engine clips the area here: counts as disallowed
            if _all_allowed(ctx, (px, pz), specs, area.line, exclude_line=area.line):
                allowed += 1
    if total == 0:
        return None
    return AreaFeasibility(area.name, allowed / total, len(specs), skipped)


def region_points(ctx: FieldContext, specs: List[Dict], before_line: Optional[int],
                  cell_tiles: float = 2.0,
                  obey_world_circle: bool = True,
                  exclude_line: Optional[int] = None) -> List[Tuple[float, float]]:
    """Fraction-space cell centers over the whole map where all specs allow."""
    g = ctx.grid
    step = cell_tiles * g.TILE_M
    nx = int(g.size_x_m / step)
    nz = int(g.size_z_m / step)
    clip_circle = ctx.rs.world_circle and obey_world_circle
    allowed: List[Tuple[float, float]] = []
    for i in range(nx):
        for j in range(nz):
            px, pz = (i + 0.5) * step, (j + 0.5) * step
            if clip_circle and not _in_world_circle_m(ctx, (px, pz)):
                continue
            if _all_allowed(ctx, (px, pz), specs, before_line, exclude_line):
                allowed.append((g.x_m_to_frac(px), g.z_m_to_frac(pz)))
    return allowed


def loop_feasibility(ctx: FieldContext, area: ResolvedArea,
                     cell_tiles: float = 2.0) -> Optional[LoopFeasibility]:
    """Feasible-region tiles vs requested tiles for an engine-placed loop."""
    if not area.engine_placed or not area.constraints:
        return None
    specs, skipped = split_constraints(ctx.rs, area.constraints)
    if not specs:
        return None
    allowed_points = region_points(ctx, specs, area.line, cell_tiles,
                                   obey_world_circle=area.obey_world_circle,
                                   exclude_line=area.line)
    feasible_tiles = len(allowed_points) * cell_tiles * cell_tiles
    mean_radius = (area.radius_min_m + area.radius_m) / 2.0
    demand_tiles = area.count * radius_to_tiles(mean_radius)
    ratio = feasible_tiles / demand_tiles if demand_tiles > 0 else math.inf
    return LoopFeasibility(area.name, feasible_tiles, demand_tiles, ratio,
                           len(specs), skipped, allowed_points)


class TerrainTimeline:
    """The GROWN terrain as it stands at any script line (2026-09-25).

    Placement checks used to judge terrain constraints ("avoid water",
    "stay near water") against the authored-disc model only: an island that
    grows along its influence segments (zptorresstrait's south island) or
    rises out of a lake (zpdeadsea/zpeyrebasin King's Island) was water
    there, so TCs and the KotH hill came out CONSTRAINT_UNSAT on maps that
    place them fine in game. The timeline replays terrain_grid's water log,
    so a placement at line L sees the land/water state after every build
    step created up to L (the build-order rule the disc model already used:
    IW's pirate controllers stand on water that only later becomes land).

    Water = the grid's `water` cells (walkable shallows included), the same
    set area growth uses for terrain constraints."""

    def __init__(self, rs: ResolvedScene, cell_tiles: float = 1.0):
        self.rs = rs
        self.log: list = []
        self.tg = terrain_grid(rs, cell_tiles=cell_tiles, water_log=self.log)
        g = rs.grid
        self.nx, self.nz = self.tg.nx, self.tg.nz
        self.step_m = cell_tiles * g.TILE_M
        self._base = rs.base_is_water
        self._cache: Dict[int, Tuple[List[List[float]], List[List[float]]]] = {}

    def version(self, line: Optional[int]) -> int:
        """How many logged steps exist at `line` (None = all)."""
        if line is None:
            return len(self.log)
        return sum(1 for ln, _ in self.log if ln <= line)

    def water_mask(self, version: int) -> List[List[bool]]:
        w = [[self._base] * self.nx for _ in range(self.nz)]
        for _ln, changed in self.log[:version]:
            for i, j, v in changed:
                w[j][i] = v
        return w

    def fields(self, version: int):
        """(distance-to-water, distance-to-land) chamfer fields in meters
        for the state after `version` logged steps; inf where the map has
        no such cell at all."""
        hit = self._cache.get(version)
        if hit is None:
            w = self.water_mask(version)
            wc = [(i, j) for j in range(self.nz) for i in range(self.nx) if w[j][i]]
            lc = [(i, j) for j in range(self.nz) for i in range(self.nx) if not w[j][i]]
            inf_field = None

            def _fld(cells):
                nonlocal inf_field
                if cells:
                    return _chamfer_dist_m(self.nx, self.nz, self.step_m, cells)
                if inf_field is None:
                    inf_field = [[math.inf] * self.nx for _ in range(self.nz)]
                return inf_field
            hit = (_fld(wc), _fld(lc))
            self._cache[version] = hit
        return hit

    def annulus_cells(self, anchor_m: Tuple[float, float], r_min: float,
                      r_max: float):
        """Cells whose centers lie in the [r_min, r_max] annulus around the
        anchor (the anchor's own cell for a pinned search), inside the map."""
        s = self.step_m
        ax, az = anchor_m
        if r_max <= 0.0:
            i = min(self.nx - 1, max(0, int(ax / s)))
            j = min(self.nz - 1, max(0, int(az / s)))
            return [(i, j)]
        lo = max(0.0, r_min - s / 2.0)
        hi = r_max + s / 2.0
        i0 = max(0, int((ax - hi) / s))
        i1 = min(self.nx - 1, int((ax + hi) / s))
        j0 = max(0, int((az - hi) / s))
        j1 = min(self.nz - 1, int((az + hi) / s))
        out = []
        for j in range(j0, j1 + 1):
            cz = (j + 0.5) * s
            for i in range(i0, i1 + 1):
                d = math.hypot((i + 0.5) * s - ax, cz - az)
                if lo <= d <= hi:
                    out.append((i, j))
        return out

    def terrain_ok(self, spec: Dict[str, Any], anchor_m, r_min: float,
                   r_max: float, line: Optional[int]) -> bool:
        """Whether ANY cell of the search annulus satisfies a terrain /
        terrain_max constraint at the placement's line."""
        to_water, to_land = self.fields(self.version(line))
        d = float(spec["distance_m"])
        kind = spec["kind"]
        for i, j in self.annulus_cells(anchor_m, r_min, r_max):
            if kind == "terrain":
                fld = to_water if spec["avoid"] == "water" else to_land
                if fld[j][i] >= d:
                    return True
            else:   # terrain_max: stay within d of the named terrain
                fld = to_water if spec["near"] == "water" else to_land
                if fld[j][i] <= d:
                    return True
        return False
