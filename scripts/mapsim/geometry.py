"""Geometry primitives for the map spawn simulator.

Most functions are unit-agnostic: the caller supplies points and radii in one
consistent unit (meters or fractions). The exceptions are the world-circle and
guide-octagon helpers, which are defined in fraction space by the engine /
authoring guide (docs/plan_map_spawn_simulator.md section 1.2).

Membership tests are boundary-inclusive: the engine tolerates exact-edge
values (fish at fraction 1.00 in Cascade Range.xs:1327), so a point exactly on
a boundary counts as inside.
"""

from __future__ import annotations

import math
from typing import Sequence, Tuple

Point = Tuple[float, float]

WORLD_CIRCLE_CENTER: Point = (0.5, 0.5)
# Inferred, not documented: every stock edge constraint tops out at 0.48 and
# the guide calls 0.5 "at the map edge", but no source states the engine's
# world-circle radius outright. Experiment E3 measures it in-game.
WORLD_CIRCLE_R: float = 0.5


def _require_finite(name: str, value: float) -> float:
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite, got {value!r}")
    return float(value)


def _require_point(name: str, p: Point) -> Point:
    x, z = p
    return (_require_finite(f"{name}[0]", x), _require_finite(f"{name}[1]", z))


def _require_radius(name: str, value: float) -> float:
    value = _require_finite(name, value)
    if value < 0.0:
        raise ValueError(f"{name} must be >= 0, got {value!r}")
    return value


def _require_annulus(name: str, r_min: float, r_max: float) -> Tuple[float, float]:
    r_min = _require_radius(f"{name}.r_min", r_min)
    r_max = _require_radius(f"{name}.r_max", r_max)
    if r_min > r_max:
        raise ValueError(f"{name}: r_min {r_min!r} > r_max {r_max!r}")
    return r_min, r_max


def dist(a: Point, b: Point) -> float:
    ax, az = _require_point("a", a)
    bx, bz = _require_point("b", b)
    return math.hypot(bx - ax, bz - az)


def point_in_circle(p: Point, center: Point, r: float) -> bool:
    return dist(p, center) <= _require_radius("r", r)


def in_world_circle(p: Point) -> bool:
    """Fraction-space world-circle membership.

    Assumes a square map; on non-square maps the engine's clip shape is
    unknown (never observed), so callers should treat this as square-only.
    """
    return point_in_circle(p, WORLD_CIRCLE_CENTER, WORLD_CIRCLE_R)


def discs_overlap(c1: Point, r1: float, c2: Point, r2: float) -> bool:
    """Tangent discs count as overlapping (boundary-inclusive)."""
    return dist(c1, c2) <= _require_radius("r1", r1) + _require_radius("r2", r2)


def dist_point_to_segment(p: Point, a: Point, b: Point) -> float:
    px, pz = _require_point("p", p)
    ax, az = _require_point("a", a)
    bx, bz = _require_point("b", b)
    abx, abz = bx - ax, bz - az
    seg_len_sq = abx * abx + abz * abz
    if seg_len_sq == 0.0:
        return math.hypot(px - ax, pz - az)
    t = ((px - ax) * abx + (pz - az) * abz) / seg_len_sq
    t = max(0.0, min(1.0, t))
    return math.hypot(px - (ax + t * abx), pz - (az + t * abz))


def dist_point_to_polyline(p: Point, pts: Sequence[Point]) -> float:
    if len(pts) == 0:
        raise ValueError("polyline needs at least one point")
    if len(pts) == 1:
        return dist(p, pts[0])
    return min(dist_point_to_segment(p, pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def reachable_dist_interval(d: float, r_min: float, r_max: float) -> Tuple[float, float]:
    """Range of distances from an external point to the points of an annulus.

    d is the distance from the external point to the annulus center. The
    reachable minimum is 0 when the point lies inside the annulus band itself.
    """
    d = _require_radius("d", d)
    r_min, r_max = _require_annulus("annulus", r_min, r_max)
    lo = max(0.0, r_min - d, d - r_max)
    hi = d + r_max
    return lo, hi


def intervals_overlap(a_lo: float, a_hi: float, b_lo: float, b_hi: float) -> bool:
    return a_lo <= b_hi and b_lo <= a_hi


def annulus_intersects_annulus(
    d: float, a_min: float, a_max: float, b_min: float, b_max: float
) -> bool:
    """Do two annuli (regions, centers d apart) share at least one point?

    By continuity every distance in the reachable interval is realized by some
    point of annulus A, so intersection reduces to interval overlap with B's
    radial band.
    """
    b_min, b_max = _require_annulus("b", b_min, b_max)
    lo, hi = reachable_dist_interval(d, a_min, a_max)
    return intervals_overlap(lo, hi, b_min, b_max)


def annulus_intersects_disc(d: float, a_min: float, a_max: float, disc_r: float) -> bool:
    return annulus_intersects_annulus(d, a_min, a_max, 0.0, _require_radius("disc_r", disc_r))


Box = Tuple[float, float, float, float]  # x0, z0, x1, z1 with x0<=x1, z0<=z1


def dist_range_to_box(p: Point, box: Box) -> Tuple[float, float]:
    """Nearest and farthest distance from a point to an axis-aligned box."""
    px, pz = _require_point("p", p)
    x0, z0, x1, z1 = (_require_finite(f"box[{i}]", v) for i, v in enumerate(box))
    if x0 > x1 or z0 > z1:
        raise ValueError(f"box must be (x0,z0,x1,z1) with x0<=x1, z0<=z1, got {box!r}")
    dx = max(x0 - px, 0.0, px - x1)
    dz = max(z0 - pz, 0.0, pz - z1)
    nearest = math.hypot(dx, dz)
    farthest = max(
        math.hypot(px - cx, pz - cz)
        for cx in (x0, x1)
        for cz in (z0, z1)
    )
    return nearest, farthest


def annulus_intersects_box(p: Point, r_min: float, r_max: float, box: Box) -> bool:
    r_min, r_max = _require_annulus("annulus", r_min, r_max)
    lo, hi = dist_range_to_box(p, box)
    return intervals_overlap(lo, hi, r_min, r_max)


def angle_frac_in_arc(angle: float, start: float, end: float) -> bool:
    """rmSetPlacementSection membership: fractions of the full circle, 0-1.

    Wraps through 0 when end < start after normalization — the map's own
    (0.73, 0.27) arc for >2 teams, and crownlands' end value 1.0615 which
    normalizes to 0.0615 (guide:11729-11736). Spatial coordinates never wrap;
    only these angle fractions do.
    """
    angle = _require_finite("angle", angle) % 1.0
    start = _require_finite("start", start) % 1.0
    end = _require_finite("end", end) % 1.0
    if start <= end:
        return start <= angle <= end
    return angle >= start or angle <= end


def in_guide_octagon(p: Point) -> bool:
    """The guide's literal red-zone rules (guide:279), pinned per plan §1.2.

    Advisory-only authoring overlay, not an engine boundary: it admits
    (0.9, 0.9), which the world circle rejects.
    """
    x, z = _require_point("p", p)
    if not (0.0 <= x <= 1.0 and 0.0 <= z <= 1.0):
        return False
    return 0.2 <= x + z <= 1.8 and abs(x - z) < 0.8


def in_safe_box(p: Point, margin: float = 0.1) -> bool:
    """The guide's softer 0.1-0.9 authoring recommendation."""
    x, z = _require_point("p", p)
    margin = _require_radius("margin", margin)
    return margin <= x <= 1.0 - margin and margin <= z <= 1.0 - margin
