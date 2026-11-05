"""Camera and capture in a running match (or the editor), aimed by WORLD metres through a measured calibration.

    python scripts/mapview/camera.py goto   <x_m> <z_m> (--size 360x686 | --map zplondon --players 4 [--teams 2])
                                            [--screen ingame] [--name N] [--out DIR] [--unchecked] [--dry-run]
    python scripts/mapview/camera.py shot   <x_m> <z_m> <size> --name enemy_block [--out DIR] ...
    python scripts/mapview/camera.py record <x_m> <z_m> <size> --name bridge --seconds 60 [--out DIR] ...
    python scripts/mapview/camera.py verify [--screen ingame] [<size>] [--out DIR] [--unchecked]   (no input at all)

Owner's rules (spec 3.4): this module moves the camera ONLY. It clicks nothing but the minimap disc, never selects
or orders a unit, never kills or launches the game.

Rewritten 2026-09-24 on scripts/gameio and the disc calibration (camera review F1-F14 of 2026-09-24):
- Input only through gameio.inputs.Session: the focus is verified (F4), and before EVERY event the Session checks
  the abort corner (cursor in the top-left 5x5 px) and that the game is the foreground window. Screenshots only
  through gameio.capture.shot of the game's client area: the old file is deleted first and a fresh one is verified
  (F5); one file per attempt (<name>_pre.png, <name>_verify_1.png, <name>_verify_2.png). Recording through
  gameio.capture.Recorder, verified (F6).
- Before ANY click: transform.load_calibration(screen, W, H) for the game's client size (accepted AND checked;
  --unchecked drops only the check gate), a fresh screenshot, and minimap_detect.probes_ok on it with the record's
  ring probes: the minimap must be on screen and undimmed (F7; a modal dialog dims the screen to about 0.63x and
  fails every probe, measured on the fixtures 2026-09-24). The same probe check runs on the verify shot before the
  one retry click.
- The map size is printed in every line and stored in every JSON: --size WxL, or --map/--players, which reads it
  from the map script through mapsim (mapinfo.map_size); both given and different -> refused (F1, F14: London is
  645 / 685 / 765 m long by player count, and 645 instead of 685 moves the aim about 9 px at the bridge).
  mapinfo.map_size gives the ENGINE size since the fix round of 2026-09-24: whole 2 m tiles, 646 / 686 / 766 m (the
  save's terrain header: London 4p = 180 x 343 tiles although rmSetMapSize asks 685), so --size 360x685 together
  with --map zplondon --players 4 is refused as disagreeing.
- Clicks only inside the drawn disc with CLICK_MARGIN_PX (6 px) from its rim (F8; radius_px is the drawn rim since
  the disc calibration: 147.0 px in a match, 130.5 px in the editor at 2560x1080).
- Verification (F2, F3): minimap_detect.find_trapezoid finds the camera outline by shape and returns the
  intersection of its diagonals (look_at), where the screen centre projects. error = |look_at - (target_px +
  cal.look_offset_px)|; verified when error <= max(3.0, (cal.check_residual_px or 0) + 1.5) (F9). A trapezoid
  cut by the rim (clipped=True; its look_at may be None) is its own state 'clipped': never a verification and never
  retried - a second click at the same pixel gives the same cut outline (fix round 2026-09-24; London's end-of-map
  bases lie there). One retry click on not_found / off_target (the first click after a focus change is eaten,
  spec 3.4). moved_px (pre-click look-at to the last look-at) shows whether the camera moved at all.
- Focus (gameio review F1, fix round 2026-09-24): ONLY the first event of a goto may call Session.focus(), and a
  batch passes focus=False for every target after the one that first reached it (snapshots.py --world). The retry,
  and every later target, run Session.check() - the guard and the foreground check, sending nothing - so a game
  the owner has left is never pulled back to the front: NotForeground, and the batch stops (STOP_BATCH = Aborted,
  GameNotFound, NotForeground, CursorMismatch). A pre-click screenshot that shows another window raises
  NotForeground too. Session() itself refuses a window that does not belong to AoE3DE_s.exe, and every press
  checks the window under the point (gameio review F4).
- Targets must lie on the map rectangle [0, size] (review F11: London's short ends leave black disc area), and the
  calibration needs >= MIN_RING_PROBES (4, calibrate.py DISC_MIN_PROBES) ring probes.
- Output: <name>.json with the target, the size, look_at, error, the calibration file and every attempt, in
  --out or a FRESH temp folder (F11: never the repository).
- The mouse is parked, after every click, on the sheet point match.park_mouse (editor.park_mouse) when
  scripts/gameio/sheets/<W>x<H>.json has a measured one. The 2560x1080 sheet has none (2026-09-24), so it parks on
  the ring's OUTER DARK BAND (40,35,24) just outside the bright-gold line, at 315 degrees (lower right: the cursor
  arrow then points away from the disc), r_line + 2 px, checked on the pre-click screenshot to be a ring-dark pixel
  at least 5 px outside the rim; the fallback angles 305/325/295/335 are tried in that order. On the committed
  fixtures that is (2509, 1009) in a match and (2367, 1018) in the editor. NOT verified live: that hovering the ring
  shows no tooltip, and how far the hammer button's hover area reaches (its circle is about 10 px away in a match).
  Never over the 3D world (F12).

Exit codes: 0 verified (goto / shot / record), or planned (--dry-run); 1 clicked but not verified (clipped
included), the photo / video is missing, or an error after a click; 2 refused before any click (no window,
calibration, map size, target outside the disc or the map, minimap not on screen, bad arguments); 3 the game could
not be brought to the front or left it; 4 aborted (cursor in the abort corner); 5 the cursor did not land on the
click point (gameio's CursorMismatch).
"""
from __future__ import annotations

import argparse
import datetime
import json
import math
import re
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

REPO = Path(__file__).resolve().parents[2]
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))
from scripts.gameio import capture, inputs, sheets, win  # noqa: E402  (no Win32 call at import)
from scripts.mapview import mapinfo  # noqa: E402
from scripts.mapview import minimap_detect as MD  # noqa: E402
from scripts.mapview.transform import (Calibration, cal_path, load_calibration, minimap_to_world,  # noqa: E402
                                       pixel_in_disc, world_to_minimap)

ACCEPT_MIN_PX = 3.0               # the spec's acceptance
ACCEPT_RESIDUAL_PAD_PX = 1.5      # added to the record's check residual (click rounding + 1 px raster lines)
CLICK_MARGIN_PX = 6.0             # clicks stay this far inside the drawn rim (review F8)
CLICK_TO_PARK_S = 0.6             # the old camera.py timings (click, 0.6 s, park, 0.8 s, shot)
PARK_TO_SHOT_S = 0.8
PHOTO_WAIT_S = 2.5                # spec 3.4 / snapshots.py
MAX_CLICKS = 2                    # the click and one retry
RETRY_STATES = ("not_found", "off_target")      # never 'clipped' (fix round 2026-09-24) nor 'minimap_lost'
MIN_RING_PROBES = 4               # = scripts/mapview/calibrate.py DISC_MIN_PROBES (review F11; a test pins it)
RECORD_FPS, RECORD_WIDTH = 10, 1280   # driver.py start_recording's live-run values (ddagrab, 1280 wide, 10 fps)
PARK_ANGLES_DEG = (315.0, 305.0, 325.0, 295.0, 335.0)
PARK_DR_PX = (2.0, 2.5, 3.0)      # beyond the bright-gold line: the dark band is 1-2 px (fixtures 2026-09-24)
PARK_MIN_OUT_PX = 5.0             # a park point stays at least this far outside the drawn rim
SHEET_NS = {"ingame": "match", "editor": "editor"}
CROP_W, CROP_H = 1280, 800
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]*$")


class Refused(RuntimeError):
    """Nothing was clicked: a guard failed before the first click. fatal=True when every further target on this
    screen would be refused the same way (no usable calibration or park point), so a batch stops."""

    def __init__(self, msg: str, fatal: bool = False):
        super().__init__(msg)
        self.fatal = fatal


STOP_BATCH = (inputs.Aborted, inputs.GameNotFound, inputs.NotForeground, inputs.CursorMismatch)


def stops_batch(exc: BaseException) -> bool:
    """A batch (snapshots.py --world) stops at an abort, a vanished window, the owner taking the foreground, a
    cursor that did not land (gameio review F1, 2026-09-24) or a fatal refusal."""
    return isinstance(exc, STOP_BATCH) or bool(getattr(exc, "fatal", False))


# ----------------------------------------------------------------------------- seams (tests replace these)
def new_session(dry_run: bool = False):
    """The one input path: gameio.inputs.Session (GameNotFound when the window is missing; nothing sent)."""
    return inputs.Session(dry_run=dry_run)


def take_shot(path: Path, hwnd) -> Path:
    """A fresh screenshot of the game's client area (image pixels = client pixels = calibration pixels)."""
    return capture.shot(path, hwnd=hwnd, mode="screen", area="client")


def shot_meta(path: Path) -> Dict[str, Any]:
    """The sidecar gameio.capture.shot writes beside a shot ({} when absent)."""
    side = Path(path).with_name(Path(path).name + ".json")
    try:
        return json.loads(side.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def load_image(path: Path):
    from PIL import Image
    with Image.open(path) as im:
        return im.convert("RGB")


def new_recorder(path: Path, seconds: float):
    """driver.py's live-run recording settings (review F7): 10 fps, 1280 wide; gdigrab falls back to the primary."""
    return capture.Recorder(path, seconds, fps=RECORD_FPS, width=RECORD_WIDTH)


# ----------------------------------------------------------------------------- helpers
def resolve_size(size=None, map_ref=None, players=None, teams: int = 2) -> Tuple[float, float, str]:
    """(size_x_m, size_z_m, source). size = 'WxL' or a pair; map_ref + players read it from the map script through
    mapsim (mapinfo.map_size). Both given: they must agree, else ValueError (review F1 / F14)."""
    got = None
    if map_ref is not None or players is not None:
        if map_ref is None or players is None:
            raise ValueError("--map and --players go together")
        mx, mz = mapinfo.map_size(map_ref, int(players), int(teams))
        got = (mx, mz, "mapsim %s, %d players, %d teams" % (mapinfo.resolve_map(map_ref).name, int(players), int(teams)))
    if size is not None:
        if isinstance(size, str):
            sx, sz = mapinfo.parse_size(size)
        else:
            sx, sz = float(size[0]), float(size[1])
            if not (math.isfinite(sx) and math.isfinite(sz) and sx > 0 and sz > 0):
                raise ValueError("a map size must be positive, got %r" % (size,))
        if got is not None and (abs(sx - got[0]) > 1e-6 or abs(sz - got[1]) > 1e-6):
            raise ValueError("--size %gx%g disagrees with %s: %gx%g - refused (a wrong map length moves every "
                             "aimed pixel)" % (sx, sz, got[2], got[0], got[1]))
        if got is None:
            got = (sx, sz, "--size %gx%g" % (sx, sz))
    if got is None:
        raise ValueError("the map size is needed: --size WxL, or --map <xs> --players N")
    return got


def out_dir(out=None) -> Path:
    """--out as a Path (str or Path accepted, review F1), else a fresh temp folder - never the repository."""
    p = Path(tempfile.mkdtemp(prefix="mapview_camera_")) if out is None or str(out) == "" else Path(out)
    p.mkdir(parents=True, exist_ok=True)
    return p


def accept_px(cal: Calibration) -> float:
    return max(ACCEPT_MIN_PX, float(cal.check_residual_px or 0.0) + ACCEPT_RESIDUAL_PAD_PX)


def _check_name(name: str) -> str:
    if not isinstance(name, str) or not NAME_RE.match(name):
        raise ValueError("a shot name is letters, digits, '_', '-' or '.', got %r" % (name,))
    return name


def _now() -> str:
    return datetime.datetime.now().isoformat(timespec="seconds")


def _carry(exc: BaseException, res: Dict[str, Any]) -> None:
    """Attach the result so far to an exception (.camera_result): exit_code counts its clicks, and a batch reads
    whether the goto had reached its focus step (res['focused'])."""
    try:
        exc.camera_result = res
    except AttributeError:
        pass


def _write(out: Path, name: str, res: Dict[str, Any]) -> Path:
    p = Path(out) / ("%s.json" % name)
    p.write_text(json.dumps(res, indent=1, default=list), encoding="utf-8")
    return p


def _cal_info(cal: Calibration, screen: str, w: int, h: int) -> Dict[str, Any]:
    return {"file": str(cal_path(screen, w, h)), "method": cal.method, "accepted": cal.accepted,
            "checked": cal.checked, "check_residual_px": cal.check_residual_px, "cx": cal.cx, "cy": cal.cy,
            "radius_px": cal.radius_px, "r_line_px": cal.r_line_px, "probes": len(cal.probes or [])}


def _load_cal(screen: str, w: int, h: int, unchecked: bool) -> Calibration:
    try:
        return load_calibration(screen, w, h, require_checked=not unchecked)
    except (FileNotFoundError, ValueError) as e:
        raise Refused("calibration: %s" % e, fatal=True) from None


def _pixel(img, x: int, y: int):
    return tuple(img.getpixel((x, y)))[:3]


def park_point(cal: Calibration, img, screen: str, width: int, height: int,
               client: Tuple[int, int, int, int] = (0, 0, 0, 0)) -> Dict[str, Any]:
    """Where the mouse rests after a click: off the minimap (its hover tooltip covers it) and off the 3D world.
    A measured sheet point <ns>.park_mouse first; else the ring's outer dark band (see the module docstring), checked
    pixel by pixel on img (the pre-click screenshot) - img None (a dry run) gives the geometric point, unverified."""
    ns = SHEET_NS.get(screen, screen)
    why = ""
    try:
        p = sheets.load_sheet(width, height).point(ns + ".park_mouse")
    except (FileNotFoundError, KeyError, ValueError) as e:
        why = "no measured sheet point %s.park_mouse (%s)" % (ns, e.__class__.__name__)
    else:
        px, py = float(p["x"]), float(p["y"])
        if p.get("space") == "screen":
            px, py = px - client[0], py - client[1]
        if not (0 <= px < width and 0 <= py < height):
            raise Refused("the sheet point %s (%g, %g) is outside the game's %dx%d client area - no park point"
                          % (p["name"], p["x"], p["y"], width, height), fatal=True)
        if math.hypot(px - cal.cx, py - cal.cy) <= cal.radius_px + PARK_MIN_OUT_PX:
            raise Refused("the sheet point %s (%g, %g) lies on the minimap disc - no park point" % (p["name"], px, py),
                          fatal=True)
        return {"x": p["x"], "y": p["y"], "space": p.get("space", "client"), "source": "sheet " + p["name"],
                "provenance": p.get("provenance"), "verified": True}
    if cal.r_line_px is None:
        raise Refused(why + ", and the calibration has no r_line_px (not a disc record) - no park point; run "
                      "calibrate.py disc", fatal=True)
    w, h = (img.size if img is not None else (width, height))
    for deg in PARK_ANGLES_DEG:
        a = math.radians(deg)
        for dr in PARK_DR_PX:
            r = cal.r_line_px + dr
            x = int(round(cal.cx + r * math.cos(a)))
            y = int(round(cal.cy - r * math.sin(a)))
            if not (0 <= x < w and 0 <= y < h) or math.hypot(x - cal.cx, y - cal.cy) < cal.radius_px + PARK_MIN_OUT_PX:
                continue
            spot = {"x": x, "y": y, "space": "client", "note": why,
                    "source": "ring outer dark band, %g deg, r_line + %g px" % (deg, dr)}
            if img is None:
                spot.update(verified=False, rgb=None)
                return spot
            rgb = _pixel(img, x, y)
            if MD.is_ring_dark(rgb):
                spot.update(verified=True, rgb=list(rgb))
                return spot
    raise Refused(why + ", and no ring-dark pixel on the ring's outer band at %s degrees on this screenshot - no "
                  "park point" % (list(PARK_ANGLES_DEG),))


def _look_at(t: Optional[Dict[str, Any]]) -> Optional[Tuple[float, float]]:
    """find_trapezoid's look_at as floats, or None (no trapezoid, or a clipped one whose look_at is None)."""
    la = t.get("look_at") if t else None
    return (float(la[0]), float(la[1])) if la is not None else None


def judge(img, cal: Calibration, expected: Optional[Tuple[float, float]], accept: float) -> Dict[str, Any]:
    """One verify screenshot: the ring probes, the trapezoid, and the state
    'minimap_lost' | 'not_found' | 'clipped' | 'ok' | 'off_target' ('found' when no expected point is given).
    A trapezoid with clipped=True is 'clipped' whatever its look_at (which may be None): reported with its error when
    it has a look_at, never a verification."""
    ok_p, good, n = MD.probes_ok(img, cal.probes)
    row: Dict[str, Any] = {"probes": [good, n], "look_at_px": None, "error_px": None, "clipped": None,
                           "leg_support": None}
    if not ok_p:
        row["state"] = "minimap_lost"
        return row
    t = MD.find_trapezoid(img, cal.cx, cal.cy, cal.radius_px)
    if t is None:
        row["state"] = "not_found"
        return row
    la = _look_at(t)
    row.update(clipped=bool(t.get("clipped")), leg_support=t.get("leg_support"))
    if la is not None:
        row["look_at_px"] = [round(la[0], 2), round(la[1], 2)]
        if expected is not None:
            row["error_px"] = round(math.hypot(la[0] - expected[0], la[1] - expected[1]), 2)
    if row["clipped"]:
        row["state"] = "clipped"
    elif la is None:
        row["state"] = "not_found"                  # an unclipped outline without a look-at: nothing to judge
    elif expected is None:
        row["state"] = "found"
    else:
        row["state"] = "ok" if row["error_px"] <= accept else "off_target"
    return row


# ----------------------------------------------------------------------------- goto / shot / record
def goto(x_m: float, z_m: float, size_x_m: float, size_z_m: float, screen: str = "ingame", out=None,
         name: str = "goto", unchecked: bool = False, session=None, dry_run: bool = False,
         size_source: Optional[str] = None, focus: bool = True) -> Dict[str, Any]:
    """Click the minimap pixel of world (x_m, z_m) on a size_x_m x size_z_m map and verify the camera went there.
    focus=True: the first event is Session.focus(); focus=False (a later batch target): Session.check() instead - the
    game must already be in front, it is never pulled back (review F1). A session passed in must match dry_run
    (ValueError otherwise, review F9). Raises (nothing clicked): Refused, ValueError, inputs.GameNotFound,
    inputs.NotForeground (focus failed, the game is not in front, or the pre-click shot shows another window); after a
    click: inputs.Aborted / NotForeground / CursorMismatch from the Session. Every exception carries the result so far
    as .camera_result (clicks, focused). Returns the result dict (also <name>.json)."""
    _check_name(name)
    sx, sz, src = resolve_size((size_x_m, size_z_m))
    size_source = size_source or src
    if session is not None and bool(getattr(session, "dry_run", False)) != bool(dry_run):
        raise ValueError("goto(dry_run=%s) with a session whose dry_run is %s - refused, nothing sent"
                         % (bool(dry_run), bool(getattr(session, "dry_run", False))))
    out = out_dir(out)
    res: Dict[str, Any] = {"cmd": "goto", "name": name, "time": _now(), "target_m": [float(x_m), float(z_m)],
                           "size_m": [sx, sz], "size_source": size_source, "out": str(out), "clicks": 0,
                           "focused": False}
    try:
        session = session if session is not None else new_session(dry_run)
        _goto(session, res, float(x_m), float(z_m), sx, sz, screen, out, name, unchecked, focus)
    except Exception as e:
        res.update(state="refused" if isinstance(e, Refused) else "error", ok=False, verified=False,
                   error="%s: %s" % (type(e).__name__, e))
        _write(out, name, res)
        _carry(e, res)
        print("goto %s: (%.1f, %.1f) m on %gx%g m [%s] -> %s -> %s" % (name, x_m, z_m, sx, sz, size_source,
                                                                        res["error"], out))
        raise
    _write(out, name, res)
    print("goto %s: (%.1f, %.1f) m on %gx%g m [%s] -> (%.1f, %.1f) px: look-at %s, error %s px (accept %.1f), "
          "%d click(s) -> %s -> %s" % (name, x_m, z_m, sx, sz, size_source, res["target_px"][0], res["target_px"][1],
                                        res.get("look_at_px"), res.get("error_px"), res["accept_px"],
                                        res.get("clicks", 0), res["state"].upper(), out))
    return res


def _goto(session, res, x_m, z_m, sx, sz, screen, out, name, unchecked, focus=True) -> None:
    client = tuple(session.client_rect())
    w, h = int(client[2]), int(client[3])
    res["screen"] = "%s_%dx%d" % (screen, w, h)
    res["dry_run"] = bool(getattr(session, "dry_run", False))
    cal = _load_cal(screen, w, h, unchecked)
    res["calibration"] = _cal_info(cal, screen, w, h)
    px, py = world_to_minimap(x_m, z_m, sx, sz, cal)
    click = (int(round(px)), int(round(py)))
    res.update(target_px=[round(px, 2), round(py, 2)], click_px=list(click))
    if not (pixel_in_disc(px, py, cal, CLICK_MARGIN_PX) and pixel_in_disc(click[0], click[1], cal, CLICK_MARGIN_PX)):
        raise Refused("target (%.1f, %.1f) m on %gx%g m maps to (%.1f, %.1f) px, %.1f px from the disc centre: "
                      "outside the drawn disc (rim %.1f px) less the %g px click margin" % (
                          x_m, z_m, sx, sz, px, py, math.hypot(px - cal.cx, py - cal.cy), cal.radius_px,
                          CLICK_MARGIN_PX))
    if not (0.0 <= x_m <= sx and 0.0 <= z_m <= sz):
        raise Refused("target (%.1f, %.1f) m lies outside the %gx%g m map (x 0..%g, z 0..%g): the disc there is "
                      "black, not the map - no click" % (x_m, z_m, sx, sz, sx, sz))
    if len(cal.probes or []) < MIN_RING_PROBES:
        raise Refused("%s has %d ring probes, fewer than the %d calibrate.py disc demands (method %r): the "
                      "minimap-on-screen check is not trustworthy - run calibrate.py disc on this screen" % (
                          res["calibration"]["file"], len(cal.probes or []), MIN_RING_PROBES, cal.method), fatal=True)
    accept = accept_px(cal)
    off = [float(v) for v in (cal.look_offset_px or [0.0, 0.0])]
    expected = (px + off[0], py + off[1])
    res.update(accept_px=round(accept, 2), look_offset_px=off,
               expected_look_at_px=[round(expected[0], 2), round(expected[1], 2)])
    if res["dry_run"]:
        park = park_point(cal, None, screen, w, h, client)
        res["park"] = park
        if focus:
            session.focus()
        else:
            session.check("goto %s" % name)
        res["focused"] = True
        session.click(px, py, space="client")
        session.wait(CLICK_TO_PARK_S, "camera moves")
        session.move(park["x"], park["y"], space=park["space"])
        res.update(state="planned", ok=False, verified=False, clicks=0, attempts=[],
                   events=[dict(e) for e in getattr(session, "log", [])])
        return
    # the ONLY focus() of a goto, and only when the caller allows it (review F1)
    if focus:
        if not session.focus():
            raise inputs.NotForeground("the game could not be brought to the foreground - no click")
    else:
        session.check("goto %s: the game must still be in front (a later batch target never re-focuses)" % name)
    res["focused"] = True
    pre = take_shot(Path(out) / ("%s_pre.png" % name), session.hwnd)
    meta = shot_meta(pre)
    res.update(pre_shot=str(pre), pre_game_foreground=meta.get("game_foreground"))
    if meta.get("game_foreground") is False:
        raise inputs.NotForeground("the pre-click screenshot shows %r, not the game - no click"
                                   % meta.get("foreground_title"))
    img = load_image(pre)
    ok_p, good, n = MD.probes_ok(img, cal.probes)
    res["pre_probes"] = [good, n]
    if not ok_p:
        raise Refused("the minimap is not on screen or is dimmed: %d of %d ring probes match (a dialog, a menu or "
                      "another screen) - no click" % (good, n))
    park = park_point(cal, img, screen, w, h, client)
    res["park"] = park
    la0 = _look_at(MD.find_trapezoid(img, cal.cx, cal.cy, cal.radius_px))
    res["pre_look_at_px"] = [round(la0[0], 2), round(la0[1], 2)] if la0 is not None else None
    attempts: List[Dict[str, Any]] = []
    res["attempts"] = attempts
    for k in range(1, MAX_CLICKS + 1):
        if k > 1:       # never focus() here: the owner may have taken the foreground since click 1 (review F1)
            session.check("retry click %d" % k)
        session.click(px, py, space="client")
        res["clicks"] = k
        session.wait(CLICK_TO_PARK_S, "camera moves")
        session.move(park["x"], park["y"], space=park["space"])
        session.wait(PARK_TO_SHOT_S, "the view settles")
        v = take_shot(Path(out) / ("%s_verify_%d.png" % (name, k)), session.hwnd)
        row = judge(load_image(v), cal, expected, accept)
        row.update(attempt=k, shot=str(v), game_foreground=shot_meta(v).get("game_foreground"))
        attempts.append(row)
        if row["state"] not in RETRY_STATES:
            break
    last = attempts[-1]
    moved = None
    if la0 is not None and last["look_at_px"] is not None:
        moved = round(math.hypot(last["look_at_px"][0] - la0[0], last["look_at_px"][1] - la0[1]), 2)
    res.update(state=last["state"], look_at_px=last["look_at_px"], error_px=last["error_px"], clipped=last["clipped"],
               moved_px=moved, verified=last["state"] == "ok", ok=last["state"] == "ok")


def centre_box(size: Tuple[int, int], w: int = CROP_W, h: int = CROP_H) -> Tuple[int, int, int, int]:
    """A w x h box around the screen centre (the camera's look-at), clamped to the image."""
    W, H = size
    x0, y0 = max(0, W // 2 - w // 2), max(0, H // 2 - h // 2)
    return x0, y0, min(W, x0 + w), min(H, y0 + h)


def shot(x_m: float, z_m: float, size_x_m: float, size_z_m: float, name: str, out=None, screen: str = "ingame",
         unchecked: bool = False, session=None, dry_run: bool = False,
         size_source: Optional[str] = None, focus: bool = True) -> Dict[str, Any]:
    """goto, wait 2.5 s, photograph: <name>_full.png and <name>_crop.png (1280x800 around the screen centre).
    ok = verified AND the photo was taken with the game in front. focus: see goto."""
    _check_name(name)
    out = out_dir(out)
    session = session if session is not None else new_session(dry_run)
    res = goto(x_m, z_m, size_x_m, size_z_m, screen, out, name, unchecked, session, dry_run, size_source, focus=focus)
    res["cmd"] = "shot"
    if res.get("dry_run"):
        _write(out, name, res)
        return res
    try:
        session.wait(PHOTO_WAIT_S, "the view settles before the photo")
        full = take_shot(Path(out) / ("%s_full.png" % name), session.hwnd)
        fg = shot_meta(full).get("game_foreground")
        img = load_image(full)
        box = centre_box(img.size)
        crop = Path(out) / ("%s_crop.png" % name)
        img.crop(box).save(str(crop))
    except Exception as e:                      # after the click(s): the exit code must say so (review F10)
        _carry(e, res)
        raise
    res.update(full=str(full), crop=str(crop), crop_box=list(box), photo_game_foreground=fg,
               ok=bool(res.get("verified")) and fg is not False)
    _write(out, name, res)
    print("shot %s: %s on %gx%g m -> %s%s" % (name, res["target_m"], res["size_m"][0], res["size_m"][1], full,
                                               "" if fg is not False else " (NOT the game in front)"))
    return res


def record(x_m: float, z_m: float, size_x_m: float, size_z_m: float, seconds: int, name: str, out=None,
           screen: str = "ingame", unchecked: bool = False, session=None, dry_run: bool = False,
           size_source: Optional[str] = None, focus: bool = True) -> Dict[str, Any]:
    """goto, then an ffmpeg recording of the primary screen (<name>.mp4, capped at seconds + 5; 10 fps, 1280 wide).
    Fails loudly when ffmpeg does not start; ok = verified AND a non-empty video exists after the stop."""
    _check_name(name)
    if not (isinstance(seconds, (int, float)) and seconds > 0):
        raise ValueError("seconds must be positive, got %r" % (seconds,))
    out = out_dir(out)
    session = session if session is not None else new_session(dry_run)
    res = goto(x_m, z_m, size_x_m, size_z_m, screen, out, name, unchecked, session, dry_run, size_source, focus=focus)
    res.update(cmd="record", seconds=seconds)
    if res.get("dry_run"):
        _write(out, name, res)
        return res
    video = Path(out) / ("%s.mp4" % name)
    try:
        rec = new_recorder(video, seconds + 5)
        if not rec.start():
            msg = "ffmpeg did not start (not found, or ddagrab and gdigrab both died within 2 s) - NO VIDEO"
            print("ERROR record %s: %s" % (name, msg), file=sys.stderr)
            res.update(video=None, video_ok=False, error=msg, ok=False)
            _write(out, name, res)
            return res
        try:
            session.wait(seconds, "recording")
        finally:
            video_ok = bool(rec.stop())
    except Exception as e:                      # after the click(s): the exit code must say so (review F10)
        _carry(e, res)
        raise
    res.update(video=str(video) if video_ok else None, video_ok=video_ok, recorder=getattr(rec, "how", None),
               ok=bool(res.get("verified")) and video_ok)
    if not video_ok:
        res["error"] = "ffmpeg stopped without a non-empty %s - NO VIDEO" % video.name
        print("ERROR record %s: %s" % (name, res["error"]), file=sys.stderr)
    _write(out, name, res)
    print("record %s: %s on %gx%g m, %s s -> %s" % (name, res["target_m"], res["size_m"][0], res["size_m"][1],
                                                     seconds, res["video"]))
    return res


def verify_now(screen: str = "ingame", out=None, unchecked: bool = False,
               size: Optional[Tuple[float, float, str]] = None) -> Dict[str, Any]:
    """Where is the camera now: one screenshot, no input at all. With a size, the world point under the look-at."""
    win.dpi_aware()
    hwnd = win.find_window()
    if not hwnd:
        raise inputs.GameNotFound("no game window - nothing captured")
    c = win.client_rect(hwnd)
    if c is None:
        raise inputs.GameNotFound("the game window is gone - nothing captured")
    w, h = int(c[2]), int(c[3])
    cal = _load_cal(screen, w, h, unchecked)
    out = out_dir(out)
    p = take_shot(out / "verify.png", hwnd)
    meta = shot_meta(p)
    row = judge(load_image(p), cal, None, accept_px(cal))
    row.update(cmd="verify", time=_now(), shot=str(p), screen="%s_%dx%d" % (screen, w, h),
               game_foreground=meta.get("game_foreground"), calibration=_cal_info(cal, screen, w, h))
    if size is not None and row["look_at_px"] is not None:
        wx, wz = minimap_to_world(row["look_at_px"][0], row["look_at_px"][1], size[0], size[1], cal)
        row.update(size_m=[size[0], size[1]], size_source=size[2], look_at_m=[round(wx, 1), round(wz, 1)])
    _write(out, "verify", row)
    print("verify: %s, look-at %s px%s, probes %d/%d, game in front %s -> %s" % (
        row["state"], row["look_at_px"], (" = %s m on %gx%g m" % (row["look_at_m"], size[0], size[1]))
        if "look_at_m" in row else "", row["probes"][0], row["probes"][1], row["game_foreground"], p))
    return row


# ----------------------------------------------------------------------------- CLI
def exit_code(exc: BaseException) -> int:
    """4 Aborted, 5 CursorMismatch, 3 NotForeground, 2 refused before any click, 1 anything else - including a
    ValueError / FileNotFoundError raised AFTER a click (its .camera_result counts the clicks, review F10)."""
    if isinstance(exc, inputs.Aborted):
        return 4
    if isinstance(exc, inputs.CursorMismatch):
        return 5
    if isinstance(exc, inputs.NotForeground):
        return 3
    if isinstance(exc, (Refused, inputs.GameNotFound, ValueError, FileNotFoundError)):
        clicks = (getattr(exc, "camera_result", None) or {}).get("clicks") or 0
        return 1 if clicks > 0 else 2
    return 1


def _size_args(p) -> None:
    p.add_argument("--size", help="map size XxZ in metres, e.g. 360x686 (London 3-5 players, the engine's size)")
    p.add_argument("--map", help="map script (path, or a name under randmaps/): the size from mapsim")
    p.add_argument("--players", type=int)
    p.add_argument("--teams", type=int, default=2)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for cmd in ("goto", "shot", "record"):
        s = sub.add_parser(cmd)
        s.add_argument("x_m", type=float)
        s.add_argument("z_m", type=float)
        _size_args(s)
        s.add_argument("--screen", default="ingame", choices=("ingame", "editor"))
        s.add_argument("--out", default=None, help="output folder (default: a fresh temp folder)")
        s.add_argument("--name", required=cmd != "goto", default="goto" if cmd == "goto" else None)
        s.add_argument("--unchecked", action="store_true", help="accept a record that never passed calibrate.py check")
        s.add_argument("--dry-run", action="store_true", help="plan only: no screenshot, no input event")
        if cmd == "record":
            s.add_argument("--seconds", type=int, default=60)
    v = sub.add_parser("verify")
    _size_args(v)
    v.add_argument("--screen", default="ingame", choices=("ingame", "editor"))
    v.add_argument("--out", default=None)
    v.add_argument("--unchecked", action="store_true")
    a = ap.parse_args(argv)
    try:
        size = resolve_size(a.size, a.map, a.players, a.teams) if (a.cmd != "verify" or a.size or a.map) else None
    except Exception as e:                      # ValueError, FileNotFoundError, mapsim's ExtractError
        print("REFUSED: map size: %s" % e, file=sys.stderr)
        return 2
    try:
        if a.cmd == "verify":
            return 0 if verify_now(a.screen, a.out, a.unchecked, size)["state"] == "found" else 1
        common = dict(out=a.out, screen=a.screen, unchecked=a.unchecked, dry_run=a.dry_run, size_source=size[2])
        if a.cmd == "goto":
            res = goto(a.x_m, a.z_m, size[0], size[1], name=a.name, **common)
        elif a.cmd == "shot":
            res = shot(a.x_m, a.z_m, size[0], size[1], a.name, **common)
        else:
            res = record(a.x_m, a.z_m, size[0], size[1], a.seconds, a.name, **common)
    except Exception as e:
        code = exit_code(e)
        print("%s: %s: %s" % ("REFUSED" if code == 2 else "FAILED", type(e).__name__, e), file=sys.stderr)
        return code
    return 0 if res.get("ok") or res.get("state") == "planned" else 1


if __name__ == "__main__":
    sys.exit(main())
