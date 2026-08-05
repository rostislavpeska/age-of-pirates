"""Unit conversion calculator for AoE3 DE random map coordinates.

Mirrors the engine's fraction / meter / tile conversions exactly, per the
evidence in docs/plan_map_spawn_simulator.md section 1.1:

- 1 tile = 2.0 m x 2.0 m (random_map_generation_guide_v2.md:650).
- rmSetMapSize(x, z) takes METERS (guide:1814; amazonia.xs:25-27 echoes the
  value as "m x m"), so the terrain grid is (x/2) x (z/2) tiles.
- rmSetAreaSize takes a fraction of total map AREA; an ideal area is a disc
  of radius sqrt(area_frac / pi) in fraction-of-side units.

Sign convention: linear conversions (tiles/meters <-> fraction) accept signed
values because map scripts use them as offsets around an anchor, e.g.
``0.5 - rmXTilesToFraction(22)`` (000_Elbe.xs:527). Map dimensions and area
quantities must be positive; non-finite input always raises.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import ClassVar, Tuple

# rmSetMapSize ladder of 000_independence_war.xs (post 20%-growth rework):
# base 480 m, >=3 players 600 m, >=5 players 720 m, >=7 players 792 m.
INDEPENDENCE_WAR_LADDER: Tuple[Tuple[int, float], ...] = (
    (1, 480.0),
    (3, 600.0),
    (5, 720.0),
    (7, 792.0),
)


def _require_finite(name: str, value: float) -> float:
    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite, got {value!r}")
    return float(value)


def _require_non_negative(name: str, value: float) -> float:
    value = _require_finite(name, value)
    if value < 0.0:
        raise ValueError(f"{name} must be >= 0, got {value!r}")
    return value


@dataclass(frozen=True)
class MapGrid:
    """A map's coordinate system: sizes in meters, as rmSetMapSize takes them.

    Supports non-square maps: X conversions divide by size_x_m, Z conversions
    by size_z_m. Conflating the axes is exactly the class of silent bug this
    tool exists to catch, so the axes never share a code path.
    """

    size_x_m: float
    size_z_m: float

    TILE_M: ClassVar[float] = 2.0

    def __post_init__(self) -> None:
        for name in ("size_x_m", "size_z_m"):
            value = _require_finite(name, getattr(self, name))
            if value <= 0.0:
                raise ValueError(f"{name} must be > 0, got {value!r}")
            object.__setattr__(self, name, value)

    @classmethod
    def for_players(
        cls,
        players: int,
        ladder: Tuple[Tuple[int, float], ...] = INDEPENDENCE_WAR_LADDER,
    ) -> "MapGrid":
        """Square grid for a non-gaia player count, from a size ladder.

        The ladder is ((min_players, size_m), ...) sorted ascending; the
        largest rung with min_players <= players wins.
        """
        if players < 1:
            raise ValueError(f"players must be >= 1, got {players!r}")
        size_m = None
        for min_players, rung_size in ladder:
            if players >= min_players:
                size_m = rung_size
        if size_m is None:
            raise ValueError(f"no ladder rung matches players={players!r}")
        return cls(size_m, size_m)

    # ----- derived dimensions -------------------------------------------------

    @property
    def tiles_x(self) -> float:
        return self.size_x_m / self.TILE_M

    @property
    def tiles_z(self) -> float:
        return self.size_z_m / self.TILE_M

    @property
    def total_tiles(self) -> float:
        return self.tiles_x * self.tiles_z

    # ----- linear conversions (signed: offsets are legitimate) ---------------

    def x_tiles_to_frac(self, tiles: float) -> float:
        """rmXTilesToFraction: (tiles * 2.0) / size_x_m."""
        return _require_finite("tiles", tiles) * self.TILE_M / self.size_x_m

    def z_tiles_to_frac(self, tiles: float) -> float:
        """rmZTilesToFraction: (tiles * 2.0) / size_z_m."""
        return _require_finite("tiles", tiles) * self.TILE_M / self.size_z_m

    def x_m_to_frac(self, meters: float) -> float:
        """rmXMetersToFraction: meters / size_x_m."""
        return _require_finite("meters", meters) / self.size_x_m

    def z_m_to_frac(self, meters: float) -> float:
        """rmZMetersToFraction: meters / size_z_m."""
        return _require_finite("meters", meters) / self.size_z_m

    def x_frac_to_m(self, frac: float) -> float:
        """rmXFractionToMeters: frac * size_x_m."""
        return _require_finite("frac", frac) * self.size_x_m

    def z_frac_to_m(self, frac: float) -> float:
        """rmZFractionToMeters: frac * size_z_m."""
        return _require_finite("frac", frac) * self.size_z_m

    # ----- area conversions (non-negative by nature) --------------------------

    def area_tiles_to_frac(self, tiles: float) -> float:
        """rmAreaTilesToFraction: tiles / total_tiles."""
        return _require_non_negative("tiles", tiles) / self.total_tiles

    def area_frac_to_m2(self, frac: float) -> float:
        return _require_non_negative("frac", frac) * self.size_x_m * self.size_z_m

    def area_frac_to_radius_m(self, frac: float) -> float:
        """Radius in meters of an ideal disc covering `frac` of the map area.

        Valid for non-square maps too: the disc area is frac * X * Z m^2.
        """
        return math.sqrt(self.area_frac_to_m2(frac) / math.pi)

    def area_tiles_to_radius_m(self, tiles: float) -> float:
        """Radius in meters of an ideal disc of `tiles` area tiles.

        Map-size invariant: sqrt(tiles / pi) * 2.0 regardless of grid.
        """
        return math.sqrt(_require_non_negative("tiles", tiles) / math.pi) * self.TILE_M

    def area_frac_to_radius_frac_x(self, frac: float) -> float:
        """Disc radius as a fraction of the X side (== sqrt(frac/pi) if square)."""
        return self.area_frac_to_radius_m(frac) / self.size_x_m

    def area_frac_to_radius_frac_z(self, frac: float) -> float:
        return self.area_frac_to_radius_m(frac) / self.size_z_m

    # ----- distances ----------------------------------------------------------

    def frac_dist_m(self, x1: float, z1: float, x2: float, z2: float) -> float:
        """Meter distance between two fraction-space points.

        Anisotropy-safe: each axis is scaled by its own side length before the
        Euclidean norm, so it stays correct on non-square maps.
        """
        for name, value in (("x1", x1), ("z1", z1), ("x2", x2), ("z2", z2)):
            _require_finite(name, value)
        return math.hypot((x2 - x1) * self.size_x_m, (z2 - z1) * self.size_z_m)

    def frac_to_m(self, x: float, z: float) -> Tuple[float, float]:
        """Fraction-space point -> meter-space point (world-vector space)."""
        return (self.x_frac_to_m(x), self.z_frac_to_m(z))

    def m_to_frac(self, x_m: float, z_m: float) -> Tuple[float, float]:
        return (self.x_m_to_frac(x_m), self.z_m_to_frac(z_m))
