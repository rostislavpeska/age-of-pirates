"""Constraint-reactive grouping placement solver (plan Part H3).

The engine places a grouping by searching its [min, max] distance annulus
around the authored anchor for a RANDOM point satisfying every constraint
(rmPlaceGroupingInArea searches inside the target area instead). This
module replays that search DETERMINISTICALLY: nearest feasible point
first, ties broken clockwise from north (the pinned ring convention), so
the sim shows the closest legal spot to the authored intent — the
engine's residual randomness is the honest limitation (the render draws a
tether from anchor to solved spot).

Placements are processed in SCRIPT ORDER and each solved grouping
deposits its XML units into the placed-type registry and its footprint
into its rmAddGroupingToClass classes — that sequential feedback is
exactly how same-anchor groupings scatter in-game (wwcanyon's four Sufi
villages all anchor at map center; avoidSufi = 70 m from "SocketApache",
a unit inside each previously placed village).

Search geometry is the FieldContext's AUTHORED shapes (the same
approximation every other constraint test uses) — never the grown grid,
so the solver stays grid-free and cheap. Samples walk polar rings at
SAMPLE_STEP_M spacing; the first feasible sample wins.
"""

from __future__ import annotations

import math
from typing import Dict, List, Optional, Tuple

from scripts.mapsim.field import (FieldContext, _chamfer_dist_m,
                                  _shape_clearance, dist, point_allowed,
                                  terrain_grid)
from scripts.mapsim.scene import ResolvedScene

SAMPLE_STEP_M = 2.0          # one tile — the engine's placement granularity
EVAL_KINDS = ("terrain", "class_distance", "route_distance", "pie", "box",
              "type_distance", "area_within", "area_distance", "area_max",
              "terrain_max")


def _named_specs(rs: ResolvedScene, names) -> Tuple[List[Tuple[str, dict]], List[str]]:
    """[(name, spec)] for evaluable constraints; second return = names the
    model cannot evaluate (reported, never silently satisfied)."""
    ev, skipped = [], []
    for n in names:
        spec = rs.constraints.get(n)
        if spec is None or not spec.get("applied", True):
            continue
        if spec.get("kind") in EVAL_KINDS:
            ev.append((n, spec))
        else:
            skipped.append(n)
    return ev, skipped


class _GrownFields:
    """Chamfer distance fields over the BUILT terrain grid — class and
    area distances measured from grown reality, not authored discs (a
    mesa's authored disc covers the valley corridors its grown claim
    leaves open; growth-side class distance already works this way,
    field.py's documented Paris shoreLine rationale)."""

    def __init__(self, rs: ResolvedScene, tg):
        self.tg = tg
        self.step_m = rs.grid.size_x_m / tg.nx
        self._fields: Dict[str, List[List[float]]] = {}
        self._area_cells: Dict[str, Optional[List[Tuple[int, int]]]] = {}

    def cell(self, p_m) -> Tuple[int, int]:
        tg = self.tg
        i = min(tg.nx - 1, max(0, int(p_m[0] / self.step_m)))
        j = min(tg.nz - 1, max(0, int(p_m[1] / self.step_m)))
        return i, j

    def _field(self, key: str, cells) -> List[List[float]]:
        fld = self._fields.get(key)
        if fld is None:
            fld = _chamfer_dist_m(self.tg.nx, self.tg.nz, self.step_m, cells)
            self._fields[key] = fld
        return fld

    def class_dist(self, cls: str, p_m) -> Optional[float]:
        cells = self.tg.class_cells.get(cls.lower())
        if not cells:
            return None
        i, j = self.cell(p_m)
        return self._field("cls:" + cls.lower(), cells)[j][i]

    def area_cells(self, aname: str) -> Optional[List[Tuple[int, int]]]:
        key = aname.lower()
        if key in self._area_cells:
            return self._area_cells[key]
        tg = self.tg
        idx = next((k + 1 for k, n in enumerate(tg.land_order)
                    if n.lower() == key), None)
        cells = None
        if idx is not None:
            cells = [(i, j) for j in range(tg.nz) for i in range(tg.nx)
                     if tg.land[j][i] == idx]
        if not cells:
            claim = next((cs for n, cs in tg.cliff_claims
                          if n.lower() == key), None)
            cells = list(claim) if claim else None
        self._area_cells[key] = cells
        return cells

    def area_dist(self, aname: str, p_m) -> Optional[float]:
        cells = self.area_cells(aname)
        if not cells:
            return None
        i, j = self.cell(p_m)
        return self._field("area:" + aname.lower(), cells)[j][i]

    def water_dist(self, p_m) -> Optional[float]:
        tg = self.tg
        if not tg.water:
            return None
        cells = self._fields.get("_watercells")
        if cells is None:
            cells = [(i, j) for j in range(tg.nz) for i in range(tg.nx)
                     if tg.water[j][i]]
            self._fields["_watercells"] = cells
        if not cells:
            return math.inf
        i, j = self.cell(p_m)
        return self._field("_water", cells)[j][i]


def _violations(ctx: FieldContext, p_m, specs, line,
                gf: Optional[_GrownFields] = None) -> List[str]:
    out = []
    for name, spec in specs:
        kind = spec.get("kind")
        ok = None
        if gf is not None:
            if kind == "class_distance":
                d = gf.class_dist(spec["class"], p_m)
                if d is not None:
                    ok = d >= float(spec["distance_m"])
            elif kind in ("area_within", "area_distance", "area_max"):
                d = gf.area_dist(spec.get("area") or "", p_m)
                if d is not None:
                    if kind == "area_within":
                        ok = d <= 0.0
                    elif kind == "area_distance":
                        ok = d >= float(spec.get("distance_m") or 0.0)
                    else:
                        ok = d <= float(spec.get("distance_m") or 0.0)
            elif kind == "terrain" and spec.get("avoid") == "water":
                d = gf.water_dist(p_m)
                if d is not None:
                    ok = d >= float(spec["distance_m"])
            elif kind == "terrain_max" and spec.get("near") == "water":
                d = gf.water_dist(p_m)
                if d is not None:
                    ok = d <= float(spec["distance_m"])
        if ok is None:
            ok = point_allowed(ctx, p_m, spec, before_line=line,
                               exclude_line=line)
        if ok is False:
            out.append(name)
    return out


def _ring_samples(cx_m: float, cz_m: float, r: float):
    """Points on the radius-r circle, ordered CLOCKWISE FROM NORTH (the
    pinned engine ring convention doubles as the deterministic tie-break).
    r == 0 yields the center itself."""
    if r <= 0.0:
        yield (cx_m, cz_m)
        return
    n = max(8, int(math.ceil(2.0 * math.pi * r / SAMPLE_STEP_M)))
    for k in range(n):
        th = 2.0 * math.pi * k / n
        yield (cx_m + r * math.sin(th), cz_m + r * math.cos(th))


def _in_map(rs: ResolvedScene, p_m) -> bool:
    g = rs.grid
    return 0.0 <= p_m[0] <= g.size_x_m and 0.0 <= p_m[1] <= g.size_z_m


def _solve_annulus(rs, ctx, p, cx_m, cz_m, r_min, r_max, specs, gf):
    """Nearest feasible sample in [r_min, r_max] around (cx, cz); None
    when the whole annulus is blocked."""
    r = max(0.0, r_min)
    while r <= r_max + 1e-9:
        for cand in _ring_samples(cx_m, cz_m, r):
            if not _in_map(rs, cand):
                continue
            if not _violations(ctx, cand, specs, p.line, gf):
                return cand
        if r_max == r:
            break
        r = min(r + SAMPLE_STEP_M, r_max)
    return None


def _solve_in_area(rs, ctx, p, specs, gf):
    """Nearest feasible spot INSIDE the target area, measured from the
    area anchor. Candidates come from the area's GROWN cells when the
    grid claimed any (tortuga's islands anchor at the map edge but grow
    inward — the village belongs in the grown interior), else from the
    authored shapes. None when unknown or fully blocked."""
    ref = (p.area_refs[0] if p.area_refs else "").lower()
    area = next((a for a in rs.areas
                 if a.x is not None
                 and (a.name.lower() == ref
                      or (a.count > 1 and ref.startswith(a.name.lower())))),
                None)
    if area is None:
        return None, None
    g = rs.grid
    cx_m, cz_m = g.x_frac_to_m(area.x), g.z_frac_to_m(area.z)
    cells = gf.area_cells(area.name) if gf is not None else None
    if cells:
        step = gf.step_m
        order = sorted(cells, key=lambda ij: (
            round(dist(((ij[0] + 0.5) * step, (ij[1] + 0.5) * step),
                       (cx_m, cz_m)) * 100),
            (90.0 - math.degrees(math.atan2(
                (ij[1] + 0.5) * step - cz_m,
                (ij[0] + 0.5) * step - cx_m))) % 360.0))
        for i, j in order:
            cand = ((i + 0.5) * step, (j + 0.5) * step)
            if not _violations(ctx, cand, specs, p.line, gf):
                return cand, area
        return None, area
    shapes = ctx.area_shapes_by_name.get(area.name.lower())
    if not shapes:
        return None, area
    r_cap = 0.0
    for shape, _ln in shapes:
        far = _shape_clearance((cx_m, cz_m), shape)
        r_cap = max(r_cap, abs(far) + max(g.size_x_m, g.size_z_m) * 0.5)
    r_cap = min(r_cap, math.hypot(g.size_x_m, g.size_z_m))
    r = 0.0
    while r <= r_cap:
        for cand in _ring_samples(cx_m, cz_m, r):
            if not _in_map(rs, cand):
                continue
            if min(_shape_clearance(cand, s) for s, _ln in shapes) > 0.0:
                continue    # outside the area
            if not _violations(ctx, cand, specs, p.line, gf):
                return cand, area
        r += SAMPLE_STEP_M
    return None, area


def ensure_solved(rs: ResolvedScene) -> None:
    """Idempotent: solve every grouping placement once per scene."""
    if getattr(rs, "groupings_solved", False):
        return
    rs.groupings_solved = True
    if not any(p.is_grouping for p in rs.placements):
        return
    from scripts.refdata import catalog as _catalog
    from scripts.refdata.catalogs import grouping_footprint_m
    ctx = FieldContext(rs)
    g = rs.grid
    gf = _GrownFields(rs, terrain_grid(rs, cell_tiles=1.0))
    gcat = _catalog("grouping")

    def _footprint(p):
        for e in gcat.resolve(str(p.proto)):
            fp = grouping_footprint_m(e.name)
            if fp is not None:
                return fp
        return None

    def _deposit(p, x_m, z_m, types=True):
        if types:
            ctx.deposit_grouping_types(p, x_m, z_m)
        fp = _footprint(p)
        if fp and p.classes:
            rect = (x_m + fp[0], z_m + fp[1], x_m + fp[2], z_m + fp[3], p.line)
            for cls in p.classes:
                ctx.class_rects.setdefault(cls.lower(), []).append(rect)
                ctx.class_pshapes.setdefault(cls.lower(), []).append(
                    (("rect",) + rect[:4], p.line))
            ctx._type_match_cache.clear()

    for p in rs.placements:
        if not p.is_grouping:
            continue
        specs, skipped = _named_specs(rs, p.constraints)
        if skipped:
            p.solve_skipped = skipped

        if p.kind == "in_area":
            solved, area = _solve_in_area(rs, ctx, p, specs, gf)
            if solved is not None:
                p.anchor_x, p.anchor_z = (area.x, area.z)
                p.x, p.z = g.x_m_to_frac(solved[0]), g.z_m_to_frac(solved[1])
                p.approx = True
                _deposit(p, solved[0], solved[1])
            elif area is not None:
                # blocked or shapeless: honest fallback at the area anchor
                p.x, p.z = area.x, area.z
                p.approx = True
                a_m = (g.x_frac_to_m(area.x), g.z_frac_to_m(area.z))
                p.solve_unsat = _violations(ctx, a_m, specs, p.line, gf) \
                    or ["area interior blocked"]
            continue

        if p.x is None or p.z is None:
            continue    # runtime anchor: stays undrawable
        cx_m, cz_m = g.x_frac_to_m(p.x), g.z_frac_to_m(p.z)
        r_max = float(p.max_dist_m or 0.0)
        r_min = min(float(p.min_dist_m or 0.0), r_max)
        if r_max <= 0.0:
            # pinned placement: the engine cannot move it — report
            # violations, place (or fail) exactly here
            bad = _violations(ctx, (cx_m, cz_m), specs, p.line, gf)
            if bad:
                p.solve_unsat = bad
            else:
                # types were already seeded at FieldContext init (pinned
                # groupings register pre-solve); add only the class rect
                _deposit(p, cx_m, cz_m, types=False)
            continue
        solved = _solve_annulus(rs, ctx, p, cx_m, cz_m, r_min, r_max, specs, gf)
        if solved is None:
            p.solve_unsat = _violations(ctx, (cx_m, cz_m), specs, p.line, gf) \
                or ["annulus blocked"]
            continue
        if dist(solved, (cx_m, cz_m)) > 1e-6:
            p.anchor_x, p.anchor_z = p.x, p.z
            p.x, p.z = g.x_m_to_frac(solved[0]), g.z_m_to_frac(solved[1])
            p.approx = True
        _deposit(p, solved[0], solved[1])
