"""The coordinate transform: world metres <-> map fractions <-> minimap plane (u, v) <-> screen pixels.

Conventions (rm-coordinates skill, mapsim render.py:173-186, both must agree):
- fractions: (fx, fz) in [0, 1] as the map script uses them; 1 tile = 2 m; the map is size_x_m by size_z_m.
- display units: the scene is drawn in fraction space stretched by the aspect a = size_z / size_x, then rotated
  +45 degrees about the centre (0.5, 0.5 a). One display unit = the map's x side.
- minimap plane: u to the right, v up:  u = (dx - a dz) / sqrt2,  v = (dx + a dz) / sqrt2, with dx = fx - 0.5 and
  dz = fz - 0.5. Visual top = code (1, 1), right = (1, 0), left = (0, 1), bottom = (0, 0).
- the disc: the minimap is a circle; its diameter is the map's longer side in display units, max(1, a)
  (mapsim's WORLD_CIRCLE_R = 0.5 times max(1, a)), unless a calibration measured the other fill ("diagonal").
- screen pixels: px = cx + sign_u * s * u,  py = cy + sign_v * s * v, with s = pixels per display unit, derived from
  the calibrated disc radius in pixels and the map aspect. Screen y grows downward, so sign_v is -1.

A Calibration is a measured record (calibrate.py); nothing here assumes pixel values.
"""
from __future__ import annotations

import json
import math
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

SQRT2 = math.sqrt(2.0)
TILE_M = 2.0
WORLD_CIRCLE_R = 0.5          # mapsim geometry.py; the skill's 0.455 is the safe placement margin, not the disc
CAL_DIR = Path(__file__).resolve().parent / "cal"

Point = Tuple[float, float]


# ----------------------------------------------------------------------------- metres / tiles / fractions
def world_to_frac(x_m: float, z_m: float, size_x_m: float, size_z_m: float) -> Point:
    _positive("size_x_m", size_x_m); _positive("size_z_m", size_z_m)
    return x_m / size_x_m, z_m / size_z_m


def frac_to_world(fx: float, fz: float, size_x_m: float, size_z_m: float) -> Point:
    _positive("size_x_m", size_x_m); _positive("size_z_m", size_z_m)
    return fx * size_x_m, fz * size_z_m


def world_to_tiles(x_m: float, z_m: float) -> Point:
    return x_m / TILE_M, z_m / TILE_M


def tiles_to_world(tx: float, tz: float) -> Point:
    return tx * TILE_M, tz * TILE_M


def aspect_of(size_x_m: float, size_z_m: float) -> float:
    _positive("size_x_m", size_x_m); _positive("size_z_m", size_z_m)
    return size_z_m / size_x_m


# ----------------------------------------------------------------------------- the minimap plane
def frac_to_uv(fx: float, fz: float, aspect: float = 1.0) -> Point:
    """Fraction -> minimap plane (u right, v up), display units; the +45 degree rotation about the centre."""
    dx = fx - 0.5
    dz = (fz - 0.5) * aspect
    return (dx - dz) / SQRT2, (dx + dz) / SQRT2


def uv_to_frac(u: float, v: float, aspect: float = 1.0) -> Point:
    dx = (u + v) / SQRT2
    dz = (v - u) / SQRT2
    return dx + 0.5, dz / aspect + 0.5


def disc_radius_display(aspect: float = 1.0, fill: str = "longer_side") -> float:
    """The minimap disc's radius in display units for a map of this aspect."""
    if fill == "longer_side":
        return WORLD_CIRCLE_R * max(1.0, aspect)
    if fill == "diagonal":
        return 0.5 * math.hypot(1.0, aspect)
    raise ValueError("fill must be 'longer_side' or 'diagonal', got %r" % (fill,))


def in_minimap_disc(fx: float, fz: float, aspect: float = 1.0, fill: str = "longer_side") -> bool:
    u, v = frac_to_uv(fx, fz, aspect)
    return math.hypot(u, v) <= disc_radius_display(aspect, fill) + 1e-12


def in_world_circle(fx: float, fz: float, radius: float = WORLD_CIRCLE_R) -> bool:
    """The engine's world-circle constraint as mapsim models it (a circle in fraction space, radius 0.5)."""
    return math.hypot(fx - 0.5, fz - 0.5) <= radius + 1e-12


# ----------------------------------------------------------------------------- the calibration record
@dataclass
class Calibration:
    """A measured screen: where the minimap disc is and how big. Pixels per display unit follow from the map
    aspect (the longer side fills the disc), so one record serves every map on that screen."""
    screen: str                      # "ingame" | "editor"
    width: int
    height: int
    cx: float                        # disc centre, screen pixels
    cy: float
    radius_px: float                 # disc radius, screen pixels
    fill: str = "longer_side"        # how a rectangular map fills the disc
    sign_u: int = 1                  # u (right) grows with px
    sign_v: int = -1                 # v (up) shrinks py
    measured: bool = False           # True only for a record fitted from real pixels (calibrate.py)
    note: str = ""
    points: List[Dict[str, float]] = field(default_factory=list)   # the pairs it was fitted on
    residual_px: Optional[float] = None

    # -- derived
    def pixels_per_unit(self, aspect: float = 1.0) -> float:
        return self.radius_px / disc_radius_display(aspect, self.fill)

    def to_json(self) -> str:
        return json.dumps(asdict(self), indent=1)

    @classmethod
    def from_json(cls, text: str) -> "Calibration":
        d = json.loads(text)
        return cls(**{k: d[k] for k in d if k in cls.__dataclass_fields__})

    def path(self) -> Path:
        return CAL_DIR / ("%s_%dx%d.json" % (self.screen, self.width, self.height))

    def save(self) -> Path:
        p = self.path(); p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(self.to_json(), encoding="utf-8")
        return p


def load_calibration(screen: str, width: int, height: int, require_measured: bool = True) -> Calibration:
    p = CAL_DIR / ("%s_%dx%d.json" % (screen, width, height))
    if not p.is_file():
        raise FileNotFoundError("no calibration %s - run scripts/mapview/calibrate.py on that screen" % p.name)
    cal = Calibration.from_json(p.read_text(encoding="utf-8"))
    if require_measured and not cal.measured:
        raise ValueError("%s is not a measured calibration (measured=false) - refuse to aim with it" % p.name)
    return cal


def list_calibrations() -> List[Path]:
    return sorted(CAL_DIR.glob("*.json")) if CAL_DIR.is_dir() else []


# ----------------------------------------------------------------------------- fractions <-> pixels
def frac_to_minimap(fx: float, fz: float, cal: Calibration, aspect: float = 1.0) -> Point:
    u, v = frac_to_uv(fx, fz, aspect)
    s = cal.pixels_per_unit(aspect)
    return cal.cx + cal.sign_u * s * u, cal.cy + cal.sign_v * s * v


def minimap_to_frac(px: float, py: float, cal: Calibration, aspect: float = 1.0) -> Point:
    s = cal.pixels_per_unit(aspect)
    u = (px - cal.cx) / (cal.sign_u * s)
    v = (py - cal.cy) / (cal.sign_v * s)
    return uv_to_frac(u, v, aspect)


def world_to_minimap(x_m: float, z_m: float, size_x_m: float, size_z_m: float, cal: Calibration) -> Point:
    fx, fz = world_to_frac(x_m, z_m, size_x_m, size_z_m)
    return frac_to_minimap(fx, fz, cal, aspect_of(size_x_m, size_z_m))


def minimap_to_world(px: float, py: float, size_x_m: float, size_z_m: float, cal: Calibration) -> Point:
    fx, fz = minimap_to_frac(px, py, cal, aspect_of(size_x_m, size_z_m))
    return frac_to_world(fx, fz, size_x_m, size_z_m)


def pixel_in_disc(px: float, py: float, cal: Calibration, margin_px: float = 0.0) -> bool:
    return math.hypot(px - cal.cx, py - cal.cy) <= cal.radius_px - margin_px


# ----------------------------------------------------------------------------- fitting
def fit_calibration(pairs: Sequence[Tuple[float, float, float, float]], aspect: float, screen: str, width: int,
                    height: int, fill: str = "longer_side", note: str = "") -> Calibration:
    """Least-squares fit of the disc centre and radius from (fx, fz, px, py) pairs measured on one map of the given
    aspect. px = cx + A u and py = cy + B v are fitted independently; A and B carry the signs, |A| and |B| are
    the pixels per display unit on each axis (they should agree within a pixel or two; the record keeps their
    mean as one radius). Residual = the largest pixel distance between a measured pair and its prediction."""
    if len(pairs) < 2:
        raise ValueError("need at least 2 pairs, 3 or more to see a residual")
    us, vs, pxs, pys = [], [], [], []
    for fx, fz, px, py in pairs:
        u, v = frac_to_uv(fx, fz, aspect)
        us.append(u); vs.append(v); pxs.append(float(px)); pys.append(float(py))
    a, cx = _linreg(us, pxs)
    b, cy = _linreg(vs, pys)
    if a == 0 or b == 0:
        raise ValueError("degenerate pairs: no spread on an axis")
    sign_u = 1 if a > 0 else -1
    sign_v = 1 if b > 0 else -1
    s = (abs(a) + abs(b)) / 2.0
    cal = Calibration(screen=screen, width=int(width), height=int(height), cx=cx, cy=cy,
                      radius_px=s * disc_radius_display(aspect, fill), fill=fill, sign_u=sign_u, sign_v=sign_v,
                      measured=True, note=note,
                      points=[{"fx": fx, "fz": fz, "px": px, "py": py} for fx, fz, px, py in pairs])
    cal.residual_px = max_residual(cal, pairs, aspect)
    return cal


def max_residual(cal: Calibration, pairs: Iterable[Tuple[float, float, float, float]], aspect: float) -> float:
    worst = 0.0
    for fx, fz, px, py in pairs:
        qx, qy = frac_to_minimap(fx, fz, cal, aspect)
        worst = max(worst, math.hypot(qx - px, qy - py))
    return worst


def fit_affine_diagnostic(pairs: Sequence[Tuple[float, float, float, float]], aspect: float) -> Dict[str, float]:
    """A free 2x3 affine fit (numpy) from (u, v) to (px, py): tells whether the real minimap is a pure 45 degree
    rotation (angle near 0 in the u/v frame, no skew, equal scales) or needs more than the model above. Diagnostic
    only; the Calibration keeps the fixed model."""
    import numpy as np
    U = np.array([[*frac_to_uv(fx, fz, aspect), 1.0] for fx, fz, _, _ in pairs])
    P = np.array([[px, py] for _, _, px, py in pairs])
    M, *_ = np.linalg.lstsq(U, P, rcond=None)         # 3x2: [[a, c], [b, d], [tx, ty]]
    a, c = M[0]; b, d = M[1]; tx, ty = M[2]
    pred = U @ M
    res = float(np.max(np.hypot(*(pred - P).T))) if len(pairs) else 0.0
    ang_u = math.degrees(math.atan2(c, a))
    ang_v = math.degrees(math.atan2(d, b))
    between = (ang_v - ang_u + 180.0) % 360.0 - 180.0          # the angle between the u and v images, (-180, 180]
    return {"a": float(a), "b": float(b), "c": float(c), "d": float(d), "tx": float(tx), "ty": float(ty),
            "scale_u": float(math.hypot(a, c)), "scale_v": float(math.hypot(b, d)),
            "angle_deg": float(ang_u),                         # rotation of the u axis on screen (0 = pure model)
            "skew_deg": float(abs(between) - 90.0),            # 0 when u and v stay perpendicular (a flip is not skew)
            "residual_px": res}


# ----------------------------------------------------------------------------- helpers
def _linreg(xs: Sequence[float], ys: Sequence[float]) -> Tuple[float, float]:
    n = len(xs)
    mx = sum(xs) / n; my = sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    if sxx == 0:
        return 0.0, my
    sxy = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    slope = sxy / sxx
    return slope, my - slope * mx


def _positive(name: str, value: float) -> None:
    if not (isinstance(value, (int, float)) and math.isfinite(value) and value > 0):
        raise ValueError("%s must be a positive finite number, got %r" % (name, value))
