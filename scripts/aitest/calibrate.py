"""Calibrate the driver's UI coordinates into a resolution-keyed sheet.

    python scripts/aitest/calibrate.py                 -> <RES>_default sheet
    python scripts/aitest/calibrate.py --sheet 1920x1080_tv

Per point: bring the game to the screen named in the prompt, hover the
target, come back to this console and press Enter. Cursor position and the
pixel colour under it are sampled at that moment.

Sheets land in scripts/aitest/coords/<name>.json and are TRACKED - any
device with the same resolution reuses them. whichsheet.json (GITIGNORED,
device-local) is updated to select the freshly calibrated sheet; edit or
delete it to switch sheets manually. See the ui-calibrate skill.

Pure stdlib: ctypes against user32/gdi32, no dependencies.
"""
import argparse
import ctypes
import json
import os

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32
user32.SetProcessDPIAware()
SW = user32.GetSystemMetrics(0)
SH = user32.GetSystemMetrics(1)
HERE = os.path.dirname(os.path.abspath(__file__))


class POINT(ctypes.Structure):
    _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]


def cursor_pos():
    p = POINT()
    user32.GetCursorPos(ctypes.byref(p))
    return p.x, p.y


def pixel_at(x, y):
    dc = user32.GetDC(0)
    raw = gdi32.GetPixel(dc, x, y)
    user32.ReleaseDC(0, dc)
    if raw == 0xFFFFFFFF:          # CLR_INVALID
        return None
    return (raw & 0xFF, (raw >> 8) & 0xFF, (raw >> 16) & 0xFF)


# The complete coordinate table the driver consumes - keep in sync with
# driver.py's nav[...] uses.
POINTS = [
    ("home_skirmish", "HOME SCREEN: hover the SKIRMISH button (doubles as the"
                      " home-screen colour probe - pick a stable gold spot)"),
    ("lobby_probe",   "SKIRMISH LOBBY: hover a spot whose colour only looks"
                      " like this in the lobby (e.g. the map preview frame)"),
    ("lobby_play",    "SKIRMISH LOBBY: hover the PLAY button"),
    ("match_cog",     "IN A MATCH: hover the cog/menu button (top-right)"),
    ("match_quit",    "COG MENU OPEN: hover the QUIT entry"),
    ("quit_yes",      "QUIT CONFIRMATION: hover the YES button"),
    ("minimap_center", "IN A MATCH: hover the CENTER of the minimap circle"
                       " (bottom-right) - the observe-mode camera anchor"),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", default="%dx%d_default" % (SW, SH),
                    help="sheet name (default: <resolution>_default)")
    a = ap.parse_args()

    out = {"_comment": "calibrated manually, screen %dx%d" % (SW, SH)}
    print("Calibration -> coords/%s.json (%d points)." % (a.sheet, len(POINTS)))
    print("Alt-tab to the game, hover, come back, press Enter."
          " Screen is sampled at the moment you press Enter.")
    for name, desc in POINTS:
        input("\n[%s]\n  %s\n  ... hover now, then press Enter here: " % (name, desc))
        x, y = cursor_pos()
        rgb = pixel_at(x, y)
        out[name] = {"x": x, "y": y, "rgb": list(rgb) if rgb else None}
        warn = ""
        if rgb is None or rgb == (0, 0, 0):
            warn = "  <- WARNING: pure black / invalid. Exclusive fullscreen? Use borderless."
        print("  recorded (%d, %d) rgb=%s%s" % (x, y, rgb, warn))

    cdir = os.path.join(HERE, "coords")
    os.makedirs(cdir, exist_ok=True)
    path = os.path.join(cdir, a.sheet + ".json")
    json.dump(out, open(path, "w"), indent=2)
    json.dump({"sheet": a.sheet}, open(os.path.join(HERE, "whichsheet.json"), "w"),
              indent=2)
    print("\nWrote %s and selected it in whichsheet.json (device-local)." % path)


if __name__ == "__main__":
    main()
