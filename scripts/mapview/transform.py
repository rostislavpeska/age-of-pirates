"""The coordinate transform: world metres <-> map fractions <-> minimap plane (u, v) <-> screen pixels.

Conventions (rm-coordinates skill, mapsim render.py:173-186, both must agree):
- fractions: (fx, fz) in [0, 1] as the map script uses them; 1 tile = 2 m; the map is size_x_m by size_z_m, the
  ENGINE size: rmSetMapSize rounded to whole 2 m tiles (London 4p 685 -> 686 m, Paris 653 -> 654 m; the save's
  terrain header, 16 saves, 2026-09-24; mapinfo.map_size). Saved positions are metres on that terrain and the
  minimap draws it: the live London 4p Explorer stars sit 0.75-1.22 px from their pixels at 686 m, up to 1.52 px
  at 685 m.
- display units: the scene is drawn in fraction space stretched by the aspect a = size_z / size_x, then rotated
  +45 degrees about the centre (0.5, 0.5 a). One display unit = the map's x side.
- minimap plane: u to the right, v up:  u = (dx - a dz) / sqrt2,  v = (dx + a dz) / sqrt2, with dx = fx - 0.5 and
  dz = fz - 0.5. Visual top = code (1, 1), right = (1, 0), left = (0, 1), bottom = (0, 0).
- the disc: the minimap is a circle; its diameter is the map's longer side in display units, max(1, a)
  (mapsim's WORLD_CIRCLE_R = 0.5 times max(1, a)), unless a calibration measured the other fill ("diagonal").
  Confirmed on the editor minimap for a < 1 (Paris 654 x 360) and a > 1 (London 360 x 686) on 2026-09-24; the
  drawn map's long edges sit 1.3-2.1 px inside the model's on both sides (calibrate.py edges).
- screen pixels: px = cx + sign_u * s * u,  py = cy + sign_v * s * v, with s = pixels per display unit, derived from
  the calibrated disc radius in pixels and the map aspect. Screen y grows downward, so sign_v is -1 (sign_u +1,
  sign_v -1 fitted on real editor pixels 2026-09-24: the four Paris explorer stars).

A Calibration is a measured record (calibrate.py); nothing here assumes pixel values. Two gates make it usable:
accepted (it was measured: the drawn disc, or an icon fit within ACCEPT_FIT_PX) and checked (independent pairs in
metres, with their map size, all within ACCEPT_CHECK_PX; or, on a non-square map, the long edges of the map
rectangle: calibrate.py edges, check_pairs of kind 'edge'). load_calibration refuses a record that lacks either.
"""
from __future__ import annotations

import json
import math
import os
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

SQRT2 = math.sqrt(2.0)
TILE_M = 2.0
WORLD_CIRCLE_R = 0.5          # mapsim geometry.py; the skill's 0.455 is the safe placement margin, not the disc
CAL_DIR = Path(__file__).resolve().parent / "cal"
ACCEPT_FIT_PX = 2.0           # an icon fit is accepted when every fitted pair is within this
ACCEPT_CHECK_PX = 3.0         # a record is checked when every independent pair is within this

Point = Tuple[float, float]


def cal_dir() -> Path:
    """Where records live: $MAPVIEW_CAL_DIR when set (scratch runs), else scripts/mapview/cal."""
    env = os.environ.get("MAPVIEW_CAL_DIR")
    return Path(env) if env else CAL_DIR


def cal_path(screen: str, width: int, height: int) -> Path:
    return cal_dir() / ("%s_%dx%d.json" % (screen, int(width), int(height)))


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
    radius_px: float                 # the drawn disc's rim, screen pixels (the map's longer side touches it)
    fill: str = "longer_side"        # how a rectangular map fills the disc
    sign_u: int = 1                  # u (right) grows with px
    sign_v: int = -1                 # v (up) shrinks py
    measured: bool = False           # kept for older readers (twin.py): True exactly when accepted
    note: str = ""
    points: List[Dict[str, Any]] = field(default_factory=list)   # the pairs an icon fit used (with metres + size)
    residual_px: Optional[float] = None                          # worst fitted pair (icons) / None (disc)
    method: str = ""                 # "disc" (the drawn ring, calibrate.py disc) | "icons" (calibrate.py fit)
    accepted: bool = False           # the measurement gate passed (disc found / icon fit within ACCEPT_FIT_PX)
    checked: bool = False            # independent pairs passed calibrate.py check (ACCEPT_CHECK_PX)
    r_line_px: Optional[float] = None                            # the ring's bright-gold line (disc method)
    probes: List[Dict[str, Any]] = field(default_factory=list)   # [{'x','y','rgb'}] on the bright line
    check_pairs: List[Dict[str, Any]] = field(default_factory=list)   # [{'what','x_m','z_m','size_x_m','size_z_m','px','py','err_px'}]
    check_residual_px: Optional[float] = None
    look_offset_px: List[float] = field(default_factory=lambda: [0.0, 0.0])   # camera: look-at minus clicked pixel

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
        return cal_path(self.screen, self.width, self.height)

    def save(self) -> Path:
        p = self.path(); p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(self.to_json(), encoding="utf-8")
        return p


def load_calibration(screen: str, width: int, height: int, require_checked: bool = True) -> Calibration:
    """The record for that screen. FileNotFoundError when absent; ValueError when it was never accepted (e.g. a
    `fit --force` that failed the fit gate) or, with require_checked, never passed `calibrate.py check`."""
    p = cal_path(screen, width, height)
    if not p.is_file():
        raise FileNotFoundError("no calibration %s - run scripts/mapview/calibrate.py disc on that screen" % p.name)
    cal = Calibration.from_json(p.read_text(encoding="utf-8"))
    if not cal.accepted:
        raise ValueError("%s is not an accepted calibration (method %r, accepted=false) - refuse to aim with it"
                         % (p.name, cal.method))
    if require_checked and not cal.checked:
        raise ValueError("%s is accepted but never passed `calibrate.py check` (checked=false) - refuse to aim with it"
                         % p.name)
    return cal


def list_calibrations() -> List[Path]:
    d = cal_dir()
    return sorted(d.glob("*.json")) if d.is_dir() else []


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


# ----------------------------------------------------------------------------- checking
def evaluate_pairs(cal: Calibration, pairs: Iterable[Dict[str, Any]]) -> Tuple[float, List[Dict[str, Any]]]:
    """Pairs in METRES with their own map size: {'what', 'x_m', 'z_m', 'size_x_m', 'size_z_m', 'px', 'py'}.
    Returns (worst error px, the pairs with 'err_px' and the predicted 'qx', 'qy'). The size travels with every
    pair: a wrong map length shifts every pixel by a constant, which a fit absorbs silently (review F1)."""
    rows = []
    worst = 0.0
    for p in pairs:
        sx, sz = float(p["size_x_m"]), float(p["size_z_m"])
        qx, qy = world_to_minimap(float(p["x_m"]), float(p["z_m"]), sx, sz, cal)
        e = math.hypot(qx - float(p["px"]), qy - float(p["py"]))
        worst = max(worst, e)
        rows.append({"what": p.get("what", ""), "x_m": float(p["x_m"]), "z_m": float(p["z_m"]), "size_x_m": sx,
                     "size_z_m": sz, "px": float(p["px"]), "py": float(p["py"]), "err_px": round(e, 3),
                     "qx": round(qx, 2), "qy": round(qy, 2)})
    return worst, rows


# ----------------------------------------------------------------------------- fitting (icons)
def fit_calibration(pairs: Sequence[Tuple[float, float, float, float]], aspect: float, screen: str, width: int,
                    height: int, fill: str = "longer_side", note: str = "", accept_px: float = ACCEPT_FIT_PX,
                    points: Optional[List[Dict[str, Any]]] = None) -> Calibration:
    """Least-squares fit of the disc centre and radius from (fx, fz, px, py) pairs measured on one map of the given
    aspect. The signs come from the per-axis slopes (px against u, py against v); then ONE scale s and the centre are
    solved jointly (review F2: averaging two per-axis slopes and keeping their intercepts is not the least-squares
    centre for the scale used):
        s  = (sign_u * Sum (u-u_)(px-px_) + sign_v * Sum (v-v_)(py-py_)) / (Sum (u-u_)^2 + Sum (v-v_)^2)
        cx = px_ - sign_u * s * u_,   cy = py_ - sign_v * s * v_
    Residual = the largest pixel distance between a pair and its prediction. accepted (and measured) = residual
    within accept_px. At least 3 pairs: 2 pairs fit any aspect with 0 px residual (review F7)."""
    if len(pairs) < 3:
        raise ValueError("need at least 3 pairs (4 for the free-affine diagnostic); got %d" % len(pairs))
    us, vs, pxs, pys = [], [], [], []
    for fx, fz, px, py in pairs:
        u, v = frac_to_uv(fx, fz, aspect)
        us.append(u); vs.append(v); pxs.append(float(px)); pys.append(float(py))
    n = float(len(pairs))
    mu, mv, mpx, mpy = sum(us) / n, sum(vs) / n, sum(pxs) / n, sum(pys) / n
    suu = sum((u - mu) ** 2 for u in us)
    svv = sum((v - mv) ** 2 for v in vs)
    sup = sum((u - mu) * (p - mpx) for u, p in zip(us, pxs))
    svp = sum((v - mv) * (p - mpy) for v, p in zip(vs, pys))
    if suu == 0 or svv == 0 or sup == 0 or svp == 0:
        raise ValueError("degenerate pairs: no spread on an axis")
    sign_u = 1 if sup > 0 else -1
    sign_v = 1 if svp > 0 else -1
    s = (sign_u * sup + sign_v * svp) / (suu + svv)
    if s <= 0:
        raise ValueError("degenerate pairs: the joint scale is not positive (%.4f)" % s)
    cx = mpx - sign_u * s * mu
    cy = mpy - sign_v * s * mv
    cal = Calibration(screen=screen, width=int(width), height=int(height), cx=cx, cy=cy,
                      radius_px=s * disc_radius_display(aspect, fill), fill=fill, sign_u=sign_u, sign_v=sign_v,
                      note=note, method="icons",
                      points=points if points is not None else
                      [{"fx": fx, "fz": fz, "px": px, "py": py} for fx, fz, px, py in pairs])
    cal.residual_px = max_residual(cal, pairs, aspect)
    cal.accepted = cal.measured = cal.residual_px <= accept_px
    return cal


def max_residual(cal: Calibration, pairs: Iterable[Tuple[float, float, float, float]], aspect: float) -> float:
    worst = 0.0
    for fx, fz, px, py in pairs:
        qx, qy = frac_to_minimap(fx, fz, cal, aspect)
        worst = max(worst, math.hypot(qx - px, qy - py))
    return worst


def fit_affine_diagnostic(pairs: Sequence[Tuple[float, float, float, float]], aspect: float, sign_u: int = 1,
                          sign_v: int = -1) -> Dict[str, Any]:
    """A free 2x3 affine fit (pure Python least squares) from the SIGNED plane (sign_u u, sign_v v) to (px, py):
    tells whether the real minimap is the fixed model (angle 0, no skew, equal scales) or needs more. The fitted
    signs are applied first, so a mirrored axis the model handles reads angle 0, not 180 (review F8). With 3 pairs
    the affine is exactly determined: residual_px is None ('n/a'), and angle/skew carry no evidence."""
    if len(pairs) < 3:
        raise ValueError("the affine diagnostic needs at least 3 pairs")
    rows, P = [], []
    for fx, fz, px, py in pairs:
        u, v = frac_to_uv(fx, fz, aspect)
        rows.append((sign_u * u, sign_v * v, 1.0)); P.append((float(px), float(py)))
    ata = [[sum(r[i] * r[j] for r in rows) for j in range(3)] for i in range(3)]
    col_x = _solve3(ata, [sum(r[i] * p[0] for r, p in zip(rows, P)) for i in range(3)])
    col_y = _solve3(ata, [sum(r[i] * p[1] for r, p in zip(rows, P)) for i in range(3)])
    a, b, tx = col_x                       # px = a u' + b v' + tx
    c, d, ty = col_y                       # py = c u' + d v' + ty
    res = None
    if len(pairs) > 3:
        res = max(math.hypot(a * r[0] + b * r[1] + tx - p[0], c * r[0] + d * r[1] + ty - p[1]) for r, p in zip(rows, P))
    ang_u = math.degrees(math.atan2(c, a))                     # the image of u' on screen (0 = the model)
    ang_v = math.degrees(math.atan2(d, b))                     # the image of v' (+90 in screen coords for the model)
    between = (ang_v - ang_u + 180.0) % 360.0 - 180.0
    return {"a": a, "b": b, "c": c, "d": d, "tx": tx, "ty": ty,
            "scale_u": math.hypot(a, c), "scale_v": math.hypot(b, d),
            "angle_deg": ang_u, "skew_deg": abs(between) - 90.0, "residual_px": res, "n": len(pairs),
            "sign_u": sign_u, "sign_v": sign_v}


# ----------------------------------------------------------------------------- helpers
def _solve3(m: List[List[float]], rhs: List[float]) -> List[float]:
    """Gaussian elimination with partial pivoting for a 3x3 system."""
    a = [list(m[i]) + [rhs[i]] for i in range(3)]
    for col in range(3):
        piv = max(range(col, 3), key=lambda r: abs(a[r][col]))
        if abs(a[piv][col]) < 1e-12:
            raise ValueError("degenerate pairs: the affine system is singular")
        a[col], a[piv] = a[piv], a[col]
        for r in range(3):
            if r != col:
                f = a[r][col] / a[col][col]
                for k in range(col, 4):
                    a[r][k] -= f * a[col][k]
    return [a[i][3] / a[i][i] for i in range(3)]


def _positive(name: str, value: float) -> None:
    if not (isinstance(value, (int, float)) and math.isfinite(value) and value > 0):
        raise ValueError("%s must be a positive finite number, got %r" % (name, value))
