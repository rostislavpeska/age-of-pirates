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


def is_main_menu(img) -> Tuple[bool, Dict]:
    im = load(img)
    sx, sy = _scale(im)
    w, h = im.size
    x = min(w - 1, round(MENU_COLUMN_X * sx))
    step = max(1, round(2 * sy))
    gold = [y for y in range(round(MENU_GOLD_Y[0] * sy), round(MENU_GOLD_Y[1] * sy), step)
            if _gold(im.getpixel((x, y)))]
    frames = []
    y0, y1 = max(1, round(MENU_FRAME_Y[0] * sy)), min(h - 3, round(MENU_FRAME_Y[1] * sy))
    for y in range(y0, y1):
        if _near(im.getpixel((x, y)), MENU_FRAME_RGB, MENU_FRAME_TOL) and \
                _near(im.getpixel((x, y + 1)), MENU_FRAME_RGB, MENU_FRAME_TOL):
            if max(im.getpixel((x, y - 1))) <= 12 or max(im.getpixel((x, y + 2))) <= 12:
                frames.append(y)
    ok = len(gold) >= MENU_GOLD_MIN and len(frames) >= MENU_FRAME_MIN
    ev = {"x": x, "gold_rows": len(gold), "gold_need": MENU_GOLD_MIN, "frame_lines": frames,
          "frame_need": MENU_FRAME_MIN, "legacy_is_menu": len(gold) >= MENU_GOLD_MIN}
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
    menu, mev = is_main_menu(im)
    got = mev["frame_lines"]
    diffs = [abs(a - b) for a, b in zip(got, want)] if len(got) == len(want) else None
    same = diffs is not None and all(d <= tol for d in diffs)
    ev = {"is_main_menu": menu, "want": want, "got": got, "tol_px": tol,
          "max_diff_px": max(diffs) if diffs else None, "count": [len(got), len(want)]}
    return bool(menu and same), _warn(im, ev)


def is_editor(img) -> Tuple[bool, Dict]:
    im = load(img)
    sx, sy = _scale(im)
    w, h = im.size

    def at(p):
        q = (min(w - 1, round(p[0] * sx)), min(h - 1, round(p[1] * sy)))
        return q, im.getpixel(q)[:3]

    (pa, a), (pb, b) = at(EDITOR_MENUBAR), at(EDITOR_PLAYERBOX)
    bar = abs(a[0] - a[1]) < 12 and a[0] < 60
    box = b[2] > 200 and b[0] < 80
    ev = {"menubar": {"xy": list(pa), "rgb": list(a), "ok": bar}, "playerbox": {"xy": list(pb), "rgb": list(b), "ok": box}}
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
