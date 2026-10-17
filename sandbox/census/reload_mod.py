"""Fast mod reload: Tools -> Mods -> toggle age-of-pirates off, on -> Back.

    python sandbox/census/reload_mod.py            # reload, with a staleness check
    python sandbox/census/reload_mod.py --no-check  # reload even if XMBs are stale
    python sandbox/census/reload_mod.py --check     # only report staleness, don't touch the game

IMPORTANT, measured 2026-08-18: toggling the mod does NOT recompile any
.xml.xmb. Resource Manager still has to compile every data file you edited
BEFORE this script runs, or the game reloads the old compiled data and the
test is meaningless. That is what --check guards against.

Menu coordinates are for a 1920x1080 client area and are scaled from that.
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import game_driver as gd  # noqa: E402
from capture import capture  # noqa: E402

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]

# reference layout the coordinates were measured against
REF_W, REF_H = 1920, 1080
P_TOOLS = (124, 765)     # main menu -> Tools
P_MODS = (124, 464)      # Tools -> Mods
P_TOGGLE = (103, 260)    # first row's enable radio (age-of-pirates, priority 1)
P_BACK = (70, 25)        # Mods -> Back

# every data file the game compiles; add to this list as the mod grows
DATA = [
    "data/protomods.xml",
    "data/protounitcommandmods.xml",
    "data/techtreemods.xml",
    "data/civmods.xml",
    "data/abilities/abilitymods.xml",
    "data/abilities/powermods.xml",
    "data/strings/english/stringmods.xml",
    "data/unittypes.xml",
    "data/unittransform.xml",
]


def stale():
    out = []
    for rel in DATA:
        xml = REPO / rel
        xmb = REPO / (rel + ".xmb")
        if not xml.is_file() or not xmb.is_file():
            continue
        if xml.stat().st_mtime > xmb.stat().st_mtime:
            out.append((rel, xml.stat().st_mtime, xmb.stat().st_mtime))
    return out


def report_stale(items):
    if not items:
        print("XMB check: all compiled files are newer than their XML - good to reload")
        return True
    print("XMB check: %d file(s) NOT COMPILED since last edit:" % len(items))
    for rel, x, m in items:
        print("   STALE  %-42s  xml %s > xmb %s"
              % (rel, time.strftime("%H:%M:%S", time.localtime(x)),
                 time.strftime("%H:%M:%S", time.localtime(m))))
    print("   -> run Resource Manager on these first; a mod reload will NOT compile them")
    return False


def scaled(hwnd, pt):
    _x, _y, w, h = gd.client_rect(hwnd)
    return int(pt[0] * w / REF_W), int(pt[1] * h / REF_H)


def reload_mod(shot=True):
    hwnd = gd.find_game()
    if not hwnd:
        raise SystemExit("game window not found - is AoE3DE running?")
    gd.focus(hwnd)
    for label, pt, wait in (("Tools", P_TOOLS, 1.2), ("Mods", P_MODS, 2.0),
                            ("mod OFF", P_TOGGLE, 3.0), ("mod ON", P_TOGGLE, 6.0),
                            ("Back", P_BACK, 2.0)):
        x, y = scaled(hwnd, pt)
        print("  click %-8s at (%d, %d)" % (label, x, y))
        gd.click(hwnd, x, y)
        time.sleep(wait)
    if shot:
        capture(str(HERE / "reload_done.png"))
    print("mod reloaded")


if __name__ == "__main__":
    args = sys.argv[1:]
    items = stale()
    if "--check" in args:
        sys.exit(0 if report_stale(items) else 1)
    ok = report_stale(items)
    if not ok and "--no-check" not in args:
        raise SystemExit("refusing to reload with stale XMBs (pass --no-check to override)")
    reload_mod()
