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
    dist,
    dist_point_to_polyline,
    dist_point_to_segment,
    dist_range_to_box,
)
from scripts.mapsim.scene import ResolvedArea, ResolvedScene, resolve_branch

Disc = Tuple[float, float, float, int]              # cx_m, cz_m, r_m, line
Rect = Tuple[float, float, float, float, int]       # x0, z0, x1, z1 (m), line


def _area_shapes_m(rs: ResolvedScene, area: ResolvedArea) -> List[tuple]:
    """An area's deterministic footprint: its disc plus a capsule along each
    influence segment (the engine grows the area along those lines —
    snapshot lines 376/390-392 shape the river channel and the gulf)."""
    g = rs.grid
    shapes: List[tuple] = [("disc", g.x_frac_to_m(area.x), g.z_frac_to_m(area.z),
                            area.radius_m)]
    for x1, z1, x2, z2 in area.influence_segments:
        shapes.append(("capsule", g.x_frac_to_m(x1), g.z_frac_to_m(z1),
                       g.x_frac_to_m(x2), g.z_frac_to_m(z2), area.radius_m))
    return shapes


def _shape_clearance(p_m: Tuple[float, float], shape: tuple) -> float:
    """Signed distance from a point to the shape's boundary (negative inside)."""
    if shape[0] == "disc":
        _, cx, cz, r = shape
        return dist(p_m, (cx, cz)) - r
    _, x1, z1, x2, z2, r = shape
    return dist_point_to_segment(p_m, (x1, z1), (x2, z2)) - r


class FieldContext:
    """Pre-resolved geometry shared by all point tests of one scenario."""

    def __init__(self, rs: ResolvedScene):
        self.rs = rs
        g = rs.grid
        self.grid = g
        self.routes_m: List[List[Tuple[float, float]]] = [
            [g.frac_to_m(x, z) for x, z in route] for route in rs.all_routes()
        ]
        self.route_m: List[Tuple[float, float]] = (
            self.routes_m[0] if self.routes_m else [])   # back-compat: first route
        self.land: List[Disc] = [
            (g.x_frac_to_m(a.x), g.z_frac_to_m(a.z), a.radius_m, a.line)
            for a in rs.land_areas()
        ]
        self.class_discs: Dict[str, List[Disc]] = {}
        self.class_rects: Dict[str, List[Rect]] = {}
        self.class_shapes: Dict[str, List[Tuple[tuple, int]]] = {}
        for a in rs.areas:
            if a.x is None:
                continue
            for cls in a.classes:
                self.class_discs.setdefault(cls.lower(), []).append(
                    (g.x_frac_to_m(a.x), g.z_frac_to_m(a.z), a.radius_m, a.line))
                for shape in _area_shapes_m(rs, a):
                    self.class_shapes.setdefault(cls.lower(), []).append((shape, a.line))
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
            else:
                for cls in p.classes:
                    self.class_discs.setdefault(cls.lower(), []).append((px, pz, 0.0, p.line))

    def _land_at(self, before_line: Optional[int]) -> List[Disc]:
        if before_line is None:
            return self.land
        return [d for d in self.land if d[3] <= before_line]


def point_allowed(ctx: FieldContext, p_m: Tuple[float, float], spec: Dict[str, Any],
                  before_line: Optional[int] = None) -> Optional[bool]:
    """True/False when the constraint kind is evaluable; None when opaque."""
    kind = spec.get("kind")
    if kind == "terrain":
        d = float(spec["distance_m"])
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
            if _shape_clearance(p_m, shape) < d:
                return False
        for x0, z0, x1, z1, line in ctx.class_rects.get(cls, []):
            if before_line is not None and line > before_line:
                continue
            lo, _ = dist_range_to_box(p_m, (x0, z0, x1, z1))
            if lo < d:
                return False
        return True
    if kind == "route_distance":
        if not ctx.routes_m:
            return True
        return all(dist_point_to_polyline(p_m, route) >= float(spec["distance_m"])
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
    return None


def split_constraints(rs: ResolvedScene, names: List[str]) -> Tuple[List[Dict], List[str]]:
    """(evaluable specs, opaque names) for a constraint name list."""
    evaluable, opaque = [], []
    for name in names:
        spec = rs.constraints.get(name)
        if spec is None or not spec.get("applied", True):
            continue
        if spec.get("kind") in ("terrain", "class_distance", "route_distance", "pie", "box"):
            evaluable.append(spec)
        else:
            opaque.append(name)
    return evaluable, opaque


def _all_allowed(ctx: FieldContext, p_m, specs, before_line) -> bool:
    for spec in specs:
        ok = point_allowed(ctx, p_m, spec, before_line)
        if ok is False:
            return False
    return True


def _in_world_circle_m(ctx: FieldContext, p_m) -> bool:
    g = ctx.grid
    center = (g.x_frac_to_m(0.5), g.z_frac_to_m(0.5))
    return dist(p_m, center) <= g.x_frac_to_m(0.5)


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

_SQRT2 = math.sqrt(2.0)
_NEIGHBORS = ((1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0),
              (1, 1, _SQRT2), (1, -1, _SQRT2), (-1, 1, _SQRT2), (-1, -1, _SQRT2))


def priority_flood(nx: int, nz: int, seeds: List[Tuple[int, int]], budget: int,
                   allowed) -> List[Tuple[int, int]]:
    """Claim exactly `budget` allowed cells nearest (geodesically) to seeds.

    `allowed(i, j) -> bool` is consulted lazily. Returns fewer than `budget`
    cells when the reachable allowed component is smaller (keep-partial,
    mirroring rmBuildArea's shortfall behavior). Deterministic: the heap key
    (distance, j, i) breaks ties identically on every run and platform.
    """
    import heapq
    heap: List[Tuple[float, int, int]] = []
    seen = set()
    for seed in seeds:
        i, j = seed[0], seed[1]
        d0 = float(seed[2]) if len(seed) > 2 else 0.0   # attractor offset (cells)
        if 0 <= i < nx and 0 <= j < nz and (i, j) not in seen and allowed(i, j):
            heapq.heappush(heap, (d0, j, i))
            seen.add((i, j))
    claimed: List[Tuple[int, int]] = []
    while heap and len(claimed) < budget:
        d, j, i = heapq.heappop(heap)
        claimed.append((i, j))
        for di, dj, cost in _NEIGHBORS:
            ni, nj = i + di, j + dj
            if not (0 <= ni < nx and 0 <= nj < nz) or (ni, nj) in seen:
                continue
            if not allowed(ni, nj):
                seen.add((ni, nj))       # cache the rejection
                continue
            seen.add((ni, nj))
            heapq.heappush(heap, (d + cost, nj, ni))
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
    """Constraint-derived terrain: each cell's owner, painted in build order.

    land[z][x]  : 0 = water, else 1-based index into `land_order`
    marker[z][x]: True where a located water-marker area (river/gulf) reaches
    cell_tiles  : sampling resolution
    """
    nx: int
    nz: int
    cell_tiles: float
    land: List[List[int]]
    marker: List[List[bool]]
    land_order: List[str]
    shortfalls: Dict[str, Tuple[int, int]] = dfield(default_factory=dict)  # name -> (claimed, budget)

    def cell_of_frac(self, x: float, z: float) -> Tuple[int, int]:
        i = min(self.nx - 1, max(0, int(x * self.nx)))
        j = min(self.nz - 1, max(0, int(z * self.nz)))
        return i, j

    def is_land_frac(self, x: float, z: float) -> bool:
        i, j = self.cell_of_frac(x, z)
        return self.land[j][i] != 0


def terrain_grid(rs: ResolvedScene, ctx: Optional[FieldContext] = None,
                 cell_tiles: float = 1.0) -> TerrainGrid:
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
    if ctx is None:
        ctx = FieldContext(rs)
    g = rs.grid
    step = cell_tiles * g.TILE_M
    nx = int(g.size_x_m / step)
    nz = int(g.size_z_m / step)
    land = [[0] * nx for _ in range(nz)]
    marker = [[False] * nx for _ in range(nz)]
    marker_fields: Dict[str, List[List[float]]] = {}
    shortfalls: Dict[str, Tuple[int, int]] = {}
    circle_c = (g.x_frac_to_m(0.5), g.z_frac_to_m(0.5))
    circle_r = g.x_frac_to_m(0.5)

    # Build sequence: located areas AND rivers, interleaved by script line —
    # rivers paint water bands over whatever land exists at their build point
    # (the coastal-bank idiom: land area first, river carves through it).
    located = sorted((a for a in rs.areas if a.x is not None), key=lambda a: a.line)
    build_items: List[tuple] = [("area", a.line, a) for a in located]
    build_items += [("river", r.get("line", 0), r) for r in rs.rivers]
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
            if obey_circle and dist(p, circle_c) > circle_r:
                ok = False
            if ok:
                for s in specs:
                    kind = s["kind"]
                    if kind == "terrain":
                        d = float(s["distance_m"])
                        fld = depth_field if s["avoid"] == "water" else landdist_field
                        ok = fld is not None and fld[j][i] >= d
                    elif kind == "class_distance":
                        fld = marker_fields.get(s["class"].lower())
                        if fld is not None:
                            standoff = SHORE_STANDOFF_M if area.creates_land else 0.0
                            ok = fld[j][i] >= float(s["distance_m"]) + standoff
                        else:
                            ok = point_allowed(ctx, p, s, area.line) is not False
                    else:
                        ok = point_allowed(ctx, p, s, area.line) is not False
                    if not ok:
                        break
            memo[key] = ok
            return ok
        return allowed

    for kind_tag, _line, item in build_items:
        if kind_tag == "river":
            poly = [(g.x_frac_to_m(x), g.z_frac_to_m(z)) for x, z in item["waypoints"]]
            halfw = float(item["width_m"]) / 2.0
            xs = [p[0] for p in poly]
            zs = [p[1] for p in poly]
            i0 = max(0, int((min(xs) - halfw) / step) - 1)
            i1 = min(nx - 1, int((max(xs) + halfw) / step) + 1)
            j0 = max(0, int((min(zs) - halfw) / step) - 1)
            j1 = min(nz - 1, int((max(zs) + halfw) / step) + 1)
            for j in range(j0, j1 + 1):
                pz = (j + 0.5) * step
                for i in range(i0, i1 + 1):
                    if dist_point_to_polyline(((i + 0.5) * step, pz), poly) <= halfw:
                        land[j][i] = 0
                        marker[j][i] = True
            continue
        area = item
        specs, _skipped = split_constraints(rs, area.constraints)
        cx, cz = g.x_frac_to_m(area.x), g.z_frac_to_m(area.z)
        seeds: List[tuple] = [(min(nx - 1, max(0, int(cx / step))),
                              min(nz - 1, max(0, int(cz / step))))]
        # Influence segments: the location and every segment cell seed with
        # EQUAL weight — the area elongates along the line and the width
        # emerges from the budget (user-observed engine behavior; countryside
        # S on Elbe is a band along its segment, not a circle; the docs'
        # "peninsula" case is a far-away influence POINT, not a through-
        # location segment).
        for x1, z1, x2, z2 in area.influence_segments:
            seeds += _raster_cells(nx, nz, step,
                                   g.x_frac_to_m(x1), g.z_frac_to_m(z1),
                                   g.x_frac_to_m(x2), g.z_frac_to_m(z2))
        budget = max(1, round(math.pi * area.radius_m ** 2 / (step * step)))

        depth_field = landdist_field = None
        if any(s["kind"] == "terrain" for s in specs):
            land_cells = [(i, j) for j in range(nz) for i in range(nx) if land[j][i]]
            water_cells = [(i, j) for j in range(nz) for i in range(nx) if not land[j][i]]
            if any(s["kind"] == "terrain" and s["avoid"] == "water" for s in specs):
                depth_field = _chamfer_dist_m(nx, nz, step, water_cells)
            if any(s["kind"] == "terrain" and s["avoid"] == "land" for s in specs):
                landdist_field = _chamfer_dist_m(nx, nz, step, land_cells)

        obey_circle = rs.world_circle and area.obey_world_circle
        cells = priority_flood(nx, nz, seeds, budget,
                               make_allowed(area, specs, depth_field,
                                            landdist_field, obey_circle))
        if area.creates_land:
            land_order.append(area.name)
            code = len(land_order)
            for i, j in cells:
                land[j][i] = code
        else:
            # Marker areas carry NO rmSetAreaBaseHeight: they stamp the
            # default height (below sea level) onto claimed cells — SINKING
            # any land built before them. Measured on Elbe ground truth:
            # 0-11 m of land remains across the countryside strip that the
            # markers overlap, vs ~180 m of authored slab.
            for i, j in cells:
                marker[j][i] = True
                land[j][i] = 0
            fld = _chamfer_dist_m(nx, nz, step, cells) if cells else None
            if fld is not None:
                for cls in area.classes:
                    marker_fields[cls.lower()] = fld
        if len(cells) < budget:
            shortfalls[area.name] = (len(cells), budget)
    return TerrainGrid(nx, nz, cell_tiles, land, marker, land_order, shortfalls)


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
            if _all_allowed(ctx, (px, pz), specs, area.line):
                allowed += 1
    if total == 0:
        return None
    return AreaFeasibility(area.name, allowed / total, len(specs), skipped)


def region_points(ctx: FieldContext, specs: List[Dict], before_line: Optional[int],
                  cell_tiles: float = 2.0,
                  obey_world_circle: bool = True) -> List[Tuple[float, float]]:
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
            if _all_allowed(ctx, (px, pz), specs, before_line):
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
                                   obey_world_circle=area.obey_world_circle)
    feasible_tiles = len(allowed_points) * cell_tiles * cell_tiles
    mean_radius = (area.radius_min_m + area.radius_m) / 2.0
    demand_tiles = area.count * radius_to_tiles(mean_radius)
    ratio = feasible_tiles / demand_tiles if demand_tiles > 0 else math.inf
    return LoopFeasibility(area.name, feasible_tiles, demand_tiles, ratio,
                           len(specs), skipped, allowed_points)
