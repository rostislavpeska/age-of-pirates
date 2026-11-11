"""python -m scripts.gameio <command> - one action per call, a superset of scripts/aitest/probe.py.

    shot <png> [--window] [--area client|primary|all]   capture + <png>.json sidecar (who was in front)
    pixel <x> <y> [--client]                            rgb under a screen (or client) pixel
    click <x> <y> [--client] [--dry-run]                focus the game, then click (refused unless it is in front)
    menu <NAME> [--dry-run]                             focus, capture the client area, require the measured
                                                        home-menu layout (screens.menu_layout_ok) and the point's
                                                        label probe, then click sheet point menu.<NAME>
                                                        (skirmish, scenario_editor, tools)
    key <NAME> [--times N] [--dry-run]                  focus, then tap a key (esc, enter, end, backspace, f5, a ...)
    type <TEXT> [--dry-run]                             focus, then type unicode text
    state [--no-look]                                   window, foreground, process, screens; recognisers on a
                                                        capture (PrintWindow when the game is covered)
    where                                               cursor position (screen and client) and its pixel

Exit codes: 0 done, 1 error, 2 no game window, 3 not in the foreground / focus failed, 4 aborted (cursor in the
top-left corner), 5 the cursor did not land where aimed, 6 the screen is not the one expected (menu: layout or
probe failed - nothing clicked). Every input command prints its events as JSON lines ('DRY ' prefix in a dry run).
A focus that switched the foreground waits 1.0 s before the first event (inputs.Session.FOCUS_SETTLE_S).
Run from the repository root.
"""
from __future__ import annotations

import argparse
import json
import sys

from . import capture, geom, inputs, screens, sheets, win


def _session(args) -> inputs.Session:
    return inputs.Session(dry_run=args.dry_run, out=sys.stdout)


def _focused(s: inputs.Session) -> bool:
    if s.focus():
        return True
    print(f"the game did not come to the foreground ({win.foreground_title()!r} is in front) - nothing sent")
    return False


def cmd_shot(args) -> int:
    p = capture.shot(args.png, mode="window" if args.window else "screen", area=args.area)
    meta = json.loads(p.with_name(p.name + ".json").read_text(encoding="utf-8"))
    print(f"saved {p} {meta['size'][0]}x{meta['size'][1]} ({meta['mode']}, area {meta['area']})")
    if meta["mode"] == "screen" and not meta["game_foreground"]:
        print(f"WARNING: the game was NOT in front - the shot shows {meta['foreground_title']!r}")
    return 0


def cmd_pixel(args) -> int:
    x, y = args.x, args.y
    if args.client:
        c = win.client_rect(win.find_window())
        if not c:
            print("no game window")
            return 2
        x, y = c[0] + x, c[1] + y
    print(json.dumps({"screen": [x, y], "rgb": capture.pixel(x, y)}))
    return 0


def cmd_click(args) -> int:
    s = _session(args)
    if not _focused(s):
        return 3
    s.click(args.x, args.y, space="client" if args.client else "screen")
    return 0


def cmd_menu(args) -> int:
    """A home-menu click that looks first (gameio review F3, 2026-09-24): the point must be a measured sheet point
    with a label probe; after the focus, a fresh grab of the client area must show the measured layout
    (screens.menu_layout_ok) and the probe (screens.probe_ok, with its 'also'), else exit 6 and nothing is clicked.
    A dry run plans the focus and the click and skips the look (no capture)."""
    s = _session(args)
    c = s.client_rect()
    pt = sheets.load_sheet(c[2], c[3]).point("menu." + args.name)
    if pt.get("rgb") is None or pt.get("space") != "client":
        print(f"REFUSED: {pt['name']} has no label probe (rgb) in client space - nothing clicked")
        return 6
    if not _focused(s):
        return 3
    if args.dry_run:
        print("DRY look skipped: a live run checks menu_layout_ok and the probe on a fresh capture before the click")
    else:
        s.check("menu look")
        img = capture.grab(geom.rect_ltrb(c))
        lay_ok, lay_ev = screens.menu_layout_ok(img)
        pr_ok, pr_ev = screens.probe_ok(img, pt)
        if not (lay_ok and pr_ok):
            print("REFUSED: not the measured home menu - nothing clicked: " +
                  json.dumps({"layout_ok": lay_ok, "layout": lay_ev, "probe_ok": pr_ok, "probe": pr_ev}, default=list))
            return 6
    s.click_point(pt)
    return 0


def cmd_key(args) -> int:
    inputs.resolve_key(args.name)          # an unknown name fails before anything is looked up or sent
    s = _session(args)
    if not _focused(s):
        return 3
    s.key(args.name, times=args.times)
    return 0


def cmd_type(args) -> int:
    s = _session(args)
    if not _focused(s):
        return 3
    s.type_text(args.text)
    return 0


def cmd_state(args) -> int:
    h = win.find_window()
    out = {"game_window": bool(h), "hwnd": h, "client_rect": win.client_rect(h) if h else None,
           "window_rect": win.window_rect(h) if h else None, "game_foreground": bool(h) and win.is_foreground(h),
           "foreground_title": win.foreground_title(), "process_running": win.process_running(),
           "screen_size": win.screen_size(), "virtual_screen": win.virtual_screen(), "cursor": win.cursor_pos()}
    if h and not args.no_look:
        if out["game_foreground"]:
            img, how = capture.grab(geom.rect_ltrb(out["client_rect"])), "screen grab of the client area"
        else:
            img, how = capture.window_image(h), "PrintWindow (the game is covered)"
        m_ok, m_ev = screens.is_main_menu(img)
        e_ok, e_ev = screens.is_editor(img)
        out["look"] = {"source": how, "is_main_menu": m_ok, "menu_layout_ok": screens.menu_layout_ok(img)[0],
                       "is_editor": e_ok,
                       "menu_evidence": {k: v for k, v in m_ev.items() if k != "frame_lines"} |
                       {"frame_lines": len(m_ev["frame_lines"])}, "editor_evidence": e_ev}
    print(json.dumps(out, indent=1, default=list))
    return 0 if h else 2


def cmd_where(args) -> int:
    x, y = win.cursor_pos()
    out = {"screen": [x, y], "rgb": capture.pixel(x, y)}
    h = win.find_window()
    c = win.client_rect(h) if h else None
    if c:
        out["client"] = [x - c[0], y - c[1]]
    print(json.dumps(out))
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="python -m scripts.gameio", description=__doc__.split("\n")[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("shot"); a.add_argument("png"); a.add_argument("--window", action="store_true")
    a.add_argument("--area", choices=("client", "primary", "all")); a.set_defaults(fn=cmd_shot)
    a = sub.add_parser("pixel"); a.add_argument("x", type=int); a.add_argument("y", type=int)
    a.add_argument("--client", action="store_true"); a.set_defaults(fn=cmd_pixel)
    a = sub.add_parser("click"); a.add_argument("x", type=float); a.add_argument("y", type=float)
    a.add_argument("--client", action="store_true"); a.add_argument("--dry-run", action="store_true")
    a.set_defaults(fn=cmd_click)
    a = sub.add_parser("menu"); a.add_argument("name"); a.add_argument("--dry-run", action="store_true")
    a.set_defaults(fn=cmd_menu)
    a = sub.add_parser("key"); a.add_argument("name"); a.add_argument("--times", type=int, default=1)
    a.add_argument("--dry-run", action="store_true"); a.set_defaults(fn=cmd_key)
    a = sub.add_parser("type"); a.add_argument("text"); a.add_argument("--dry-run", action="store_true")
    a.set_defaults(fn=cmd_type)
    a = sub.add_parser("state"); a.add_argument("--no-look", action="store_true"); a.set_defaults(fn=cmd_state)
    a = sub.add_parser("where"); a.set_defaults(fn=cmd_where)
    return p


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    win.dpi_aware()
    try:
        return args.fn(args)
    except inputs.GameNotFound as e:
        print(f"GAME WINDOW NOT FOUND: {e}")
        return 2
    except inputs.NotForeground as e:
        print(f"NOT IN THE FOREGROUND: {e}")
        return 3
    except inputs.Aborted as e:
        print(f"ABORTED: {e}")
        return 4
    except inputs.CursorMismatch as e:
        print(f"CURSOR MISMATCH: {e}")
        return 5
    except (RuntimeError, ValueError, OSError, KeyError) as e:
        print(f"ERROR: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
