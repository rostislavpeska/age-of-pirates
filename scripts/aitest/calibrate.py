"""Record the named navigation points for driver.py - run once per resolution.

Hover the target, then press Enter in this console. Records cursor position
and the pixel colour under it (used by the driver to verify screen state
before clicking). Writes nav_points.json next to this script.

Pure stdlib: ctypes against user32/gdi32, no dependencies.
"""
import ctypes
import json
import os

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32
user32.SetProcessDPIAware()


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


POINTS = [
    ("main_single", "MAIN MENU: hover the Single Player button"),
    ("sp_skirmish", "SINGLE PLAYER page: hover the Skirmish button"),
    ("lobby_start", "SKIRMISH LOBBY: hover the Start Game button"),
    ("esc_menu_restart", "IN MATCH: press Esc, hover the Restart entry"),
    ("restart_confirm", "hover the Restart confirmation button (or Restart again if no dialog)"),
    ("match_probe", "IN MATCH: hover a pixel that only looks like this during a match (fixed HUD corner)"),
    ("menu_probe", "MAIN MENU: hover a pixel that only looks like this on the main menu"),
]


def main():
    out = {}
    print("Calibration - %d points. Alt-tab to the game, hover, come back, press Enter." % len(POINTS))
    print("(Screen is sampled at the moment you press Enter, so keep the cursor there.)")
    for name, desc in POINTS:
        input("\n[%s]\n  %s\n  ... hover now, then press Enter here: " % (name, desc))
        x, y = cursor_pos()
        rgb = pixel_at(x, y)
        out[name] = {"x": x, "y": y, "rgb": rgb}
        warn = ""
        if rgb is None or rgb == (0, 0, 0):
            warn = "  <- WARNING: pure black / invalid. Exclusive fullscreen? Use windowed."
        print("  recorded (%d, %d) rgb=%s%s" % (x, y, rgb, warn))
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "nav_points.json")
    json.dump(out, open(path, "w"), indent=2)
    print("\nWrote %s" % path)


if __name__ == "__main__":
    main()
