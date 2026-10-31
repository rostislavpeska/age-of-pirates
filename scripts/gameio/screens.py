"""Screen-state recognisers on a captured client image: each returns (bool, evidence dict).

Positions are 2560x1080 client pixels, scaled proportionally to the image size like sandbox/census/editor_regen.py
(which is only measured at 2560x1080; the evidence carries a warning at any other size). img = a PIL image or a
path. Measured facts behind them:

is_main_menu - editor_regen.is_menu's column test, copied: at x = 444, y 240..720 every 2 px, at least 12 'gold'
    pixels (R > 190, G > 160, B < 160). Measured 2026-09-24 on stored frames, that test alone also fires on sand:
    16 gold rows on the Istanbul match frame sandbox/census/tt_state0.png (2026-08-15) and 19 on the editor's New
    Scenario dialog over city ground (samples/regen/ldn3_dialog.png, 2026-09-22). So a second, structural test is
    required too: the home-menu buttons. On the home menu of 2026-09-20 (game v100.19.18309.0, a full-screen
    2560x1080 shot, fixture tests/fixtures/menu_20260920_col.png) column x = 444 crosses nine buttons, each a fill
    (82, 34, 17) framed by a 2-px line (253, 228, 163) with a black (0, 0, 0) line outside it - 18 frame lines at a
    55 px pitch between y 251 and 728. Required: >= 8 frame lines (four buttons); 0 were found on each of 12
    non-menu frames (editor, dialogs, matches, VS Code). A reward popup or a dimming dialog over the menu fails the
    frame test, which is intended - that is not a clickable menu.

menu_layout_ok - is_main_menu AND its frame lines equal, one for one within 1 px, the layout stored in the coordinate
    sheet (menu._layout, measured 2026-09-24 on the live post-September-patch home menu, the main session's
    live/01_menu.png: 18 lines 251, 287, ... 691, 727 - pixel-identical to the 2026-09-20 shot). is_main_menu alone
    accepts ANY layout with >= 8 frame lines, and the button column has moved before: on 2026-08-26 Skirmish sat one
    55 px pitch lower (y 490), where Multiplayer is now (gameio review F3). Call it before any menu click.

is_editor - editor_regen.is_editor, copied (measured 2026-09-18): (1280, 14) is the dark grey menu bar
    (|R - G| < 12 and R < 60; (28, 28, 28) on the 2026-09-17..22 frames) and (2375, 45) the blue active-player box
    (B > 200 and R < 80; (0, 0, 255)). A modal Save File dialog dims the whole screen and makes it False
    (box (12, 11, 162), 2026-09-20); the New Scenario dialog does not dim it (True).

probe_ok - driver.probe_ok's semantics on an image: every channel within tol of the point's rgb, and the point's
    'also' pixel too when it has one (driver.py 2026-09-23: in-match terrain under the Skirmish button matched a
    single-pixel home probe).
"""
from __future__ import annotations

from typing import Dict, Optional, Tuple

CALIBRATION = (2560, 1080)
MENU_COLUMN_X = 444
MENU_GOLD_Y = (240, 720)            # editor_regen MENU_COLUMN_Y
MENU_GOLD_MIN = 12
MENU_FRAME_Y = (240, 740)
MENU_FRAME_RGB = (253, 228, 163)
MENU_FRAME_TOL = 16
MENU_FRAME_MIN = 8
EDITOR_MENUBAR = (1280, 14)
EDITOR_PLAYERBOX = (2375, 45)


def load(img):
    """A PIL image or a path -> an RGB PIL image."""
    from PIL import Image
    im = img if hasattr(img, "getpixel") and hasattr(img, "size") else Image.open(img)
    return im.convert("RGB") if im.mode != "RGB" else im


def _scale(im) -> Tuple[float, float]:
    w, h = im.size
    return w / CALIBRATION[0], h / CALIBRATION[1]


def _warn(im, ev: Dict) -> Dict:
    ev["size"] = list(im.size)
    if tuple(im.size) != CALIBRATION:
        ev["warning"] = (f"image {im.size[0]}x{im.size[1]} != {CALIBRATION[0]}x{CALIBRATION[1]}: positions scaled "
                         f"proportionally, which is not measured for this game's UI")
    return ev


def _gold(c) -> bool:
    return c[0] > 190 and c[1] > 160 and c[2] < 160


def _near(c, ref, tol) -> bool:
    return max(abs(int(a) - int(b)) for a, b in zip(c[:3], ref)) <= tol


def _sheet_layout(im) -> Optional[Dict]:
    """The sheet's menu._layout for the image size, or None (no sheet, no layout, a malformed sheet)."""
    from . import sheets
    try:
        return sheets.load_sheet(*im.size).note("menu", "_layout")
    except (FileNotFoundError, KeyError, ValueError):
        return None


def _menu_geometry(im, layout: Optional[Dict]) -> Tuple[Dict, bool]:
    """(column x, gold/frame scan ranges, gold step, line_rows_min, dark_gap, dark_max) and whether it was MEASURED for this
    size: a layout with 'x' (the sheet's menu._layout) gives the column and its own scan range; without one the
    2560x1080 constants are scaled proportionally (a warning). The 2880x1800 device (2026-09-24) showed why the
    scaled fallback is not enough: its menu column is x = 186, the scaled one 500, and its frame lines are 1 or 2
    rows with the black outline 2 rows out and up to (15, 11, 7) dark (line_rows_min 1, dark_gap 2, dark_max 16)."""
    w, h = im.size
    if layout and "x" in layout:
        sy = h / CALIBRATION[1]
        y0, y1 = layout.get("scan_y", (MENU_FRAME_Y[0], MENU_FRAME_Y[1]))
        g0, g1 = layout.get("scan_y", MENU_GOLD_Y)
        return {"x": int(layout["x"]), "gold_y": (int(g0), int(g1)), "frame_y": (int(y0), int(y1)),
                "gold_step": max(1, round(2 * sy)) if "scan_y" in layout else 2,
                "rows_min": int(layout.get("line_rows_min", 2)), "dark_gap": int(layout.get("dark_gap", 1)),
                "dark_max": int(layout.get("dark_max", 12))}, True
    sx, sy = _scale(im)
    return {"x": min(w - 1, round(MENU_COLUMN_X * sx)),
            "gold_y": (round(MENU_GOLD_Y[0] * sy), round(MENU_GOLD_Y[1] * sy)),
            "frame_y": (round(MENU_FRAME_Y[0] * sy), round(MENU_FRAME_Y[1] * sy)),
            "gold_step": max(1, round(2 * sy)), "rows_min": 2, "dark_gap": 1, "dark_max": 12}, False


def is_main_menu(img, layout: Optional[Dict] = None) -> Tuple[bool, Dict]:
    """layout None = the sheet's menu._layout for the image size when it has a column 'x', else the scaled
    2560x1080 constants."""
    im = load(img)
    w, h = im.size
    geo, measured = _menu_geometry(im, layout if layout is not None else _sheet_layout(im))
    x = geo["x"]
    gold = [y for y in range(geo["gold_y"][0], geo["gold_y"][1], geo["gold_step"]) if _gold(im.getpixel((x, y)))]
    frames = []
    gap = geo["dark_gap"]
    y0, y1 = max(gap, geo["frame_y"][0]), min(h - 2 - gap, geo["frame_y"][1])

    def frame(y):
        return _near(im.getpixel((x, y)), MENU_FRAME_RGB, MENU_FRAME_TOL)

    def dark(y):
        return max(im.getpixel((x, y))) <= geo["dark_max"]

    for y in range(y0, y1):
        if geo["rows_min"] >= 2:            # the 2560x1080 rule, unchanged: two frame rows, black on one side
            if frame(y) and frame(y + 1) and (dark(y - 1) or dark(y + 2)):
                frames.append(y)
            continue
        if frame(y) and not frame(y - 1):   # a line's first row; the line is 1 or 2 rows
            n = 2 if frame(y + 1) else 1
            if n == 2 and frame(y + 2):
                continue
            if any(dark(y - k) for k in range(1, gap + 1)) or any(dark(y + n - 1 + k) for k in range(1, gap + 1)):
                frames.append(y)
    ok = len(gold) >= MENU_GOLD_MIN and len(frames) >= MENU_FRAME_MIN
    ev = {"x": x, "gold_rows": len(gold), "gold_need": MENU_GOLD_MIN, "frame_lines": frames,
          "frame_need": MENU_FRAME_MIN, "legacy_is_menu": len(gold) >= MENU_GOLD_MIN}
    if measured:
        ev["size"] = list(im.size)
        return ok, ev
    return ok, _warn(im, ev)


def menu_layout_ok(img, layout: Optional[Dict] = None) -> Tuple[bool, Dict]:
    """The home menu with exactly the measured button layout: is_main_menu, and its frame lines equal
    layout['frame_lines'] one for one within layout['tol_px'] (1). layout None = the sheet's menu._layout for the
    image size (False, with the reason, when there is no sheet or no layout for that size)."""
    im = load(img)
    if layout is None:
        from . import sheets
        try:
            layout = sheets.load_sheet(*im.size).note("menu", "_layout")
        except (FileNotFoundError, KeyError, ValueError) as e:
            return False, _warn(im, {"error": f"no measured menu layout for {im.size[0]}x{im.size[1]}: {e}"})
    want = [int(v) for v in layout["frame_lines"]]
    tol = int(layout.get("tol_px", 1))
    menu, mev = is_main_menu(im, layout if "x" in layout else None)
    got = mev["frame_lines"]
    diffs = [abs(a - b) for a, b in zip(got, want)] if len(got) == len(want) else None
    same = diffs is not None and all(d <= tol for d in diffs)
    ev = {"is_main_menu": menu, "want": want, "got": got, "tol_px": tol,
          "max_diff_px": max(diffs) if diffs else None, "count": [len(got), len(want)]}
    return bool(menu and same), _warn(im, ev)


def _editor_points(im) -> Optional[Tuple[Tuple[int, int], Tuple[int, int]]]:
    """The sheet's measured editor.menubar and editor.player_box for the image size, or None."""
    from . import sheets
    try:
        sh = sheets.load_sheet(*im.size)
        a, b = sh.point("editor.menubar"), sh.point("editor.player_box")
    except (FileNotFoundError, KeyError, ValueError):
        return None
    return (round(a["x"]), round(a["y"])), (round(b["x"]), round(b["y"]))


def is_editor(img) -> Tuple[bool, Dict]:
    """The sheet's measured editor.menubar / editor.player_box for the image size when it has them (2026-09-24: the
    2880x1800 bar and box are (1440,14) and (2673,76)), else the 2560x1080 positions scaled (a warning)."""
    im = load(img)
    sx, sy = _scale(im)
    w, h = im.size
    pts = _editor_points(im)

    def at(p, scale=True):
        q = (min(w - 1, round(p[0] * sx)), min(h - 1, round(p[1] * sy))) if scale else p
        return q, im.getpixel(q)[:3]

    if pts:
        (pa, a), (pb, b) = at(pts[0], False), at(pts[1], False)
    else:
        (pa, a), (pb, b) = at(EDITOR_MENUBAR), at(EDITOR_PLAYERBOX)
    bar = abs(a[0] - a[1]) < 12 and a[0] < 60
    box = b[2] > 200 and b[0] < 80
    ev = {"menubar": {"xy": list(pa), "rgb": list(a), "ok": bar}, "playerbox": {"xy": list(pb), "rgb": list(b), "ok": box}}
    if pts:
        ev["size"] = list(im.size)
        return bar and box, ev
    return bar and box, _warn(im, ev)


def probe_ok(img, point: Dict, tol: int = 30) -> Tuple[bool, Dict]:
    """point = a sheet point with 'rgb' (and optionally 'also'), in the image's pixel space."""
    im = load(img)
    if point.get("rgb") is None:
        raise ValueError(f"point {point.get('name', point)} has no rgb to probe")
    x, y = int(round(point["x"])), int(round(point["y"]))
    got = im.getpixel((x, y))[:3]
    ok = _near(got, point["rgb"], tol)
    ev = {"xy": [x, y], "want": list(point["rgb"]), "got": list(got), "tol": tol, "ok": ok}
    also = point.get("also")
    if also:
        a_ok, a_ev = probe_ok(im, also, tol)
        ev["also"] = a_ev
        ok = ok and a_ok
    return ok, ev
