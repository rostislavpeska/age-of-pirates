"""Editor regeneration loop (2026-09-18, the debugRandomMaps bisect). Kills the game - ONLY on the user's explicit
word, the game-startup skill forbids it otherwise - relaunches via Steam, skips intros until the MAIN MENU is
recognised by pixels, opens the Scenario Editor, generates London (row 2 of the Type list) with a fixed seed,
screenshots the load bar every 10 s and prints its fill (0 % after the first reads = generated; a constant value =
hung). Screenshots go to sandbox/census/samples/regen/.
  python sandbox/census/editor_regen.py <tag> <seed>                # full restart
  python sandbox/census/editor_regen.py <tag> <seed> --from-menu    # game already at the main menu
  python sandbox/census/editor_regen.py <tag> <seed> --in-editor    # editor already open
  add --dry-run to any form: print the window, its monitor and every kill / launch / key / click it WOULD do,
  with normalised and pixel coordinates; no input event, no screenshot. Exit 2 when there is no game window.
Coordinates are the 2560x1080 client sheet of census_run.py, normalised through gamewin.py so the window may sit on
any monitor; the map row (1024, 528) is London's - another map needs its own row (screenshot the open dropdown
first). Importing this module runs nothing (london_gen_safe.py imports grab / is_editor / bar_fill)."""
import subprocess, sys, time, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gamewin as gw
from census_run import C
from PIL import Image
S = os.path.join(os.path.dirname(os.path.abspath(__file__)), "samples", "regen")
N = gw.normalise_sheet(C)                      # census_run.py:41-49, 2560x1080 client pixels -> 0..1
W0, H0 = gw.CALIBRATION                        # 2560 x 1080: the client size every position below was measured at

# every position below: 2560x1080 client pixels (measured 2026-09-18 for this script) / (2560, 1080)
MENU_COLUMN_X = 444 / W0                       # x of the main menu's left button column (gold labels)
MENU_COLUMN_Y = (240 / H0, 720 / H0)           # the column's scanned y range, every 2 px
MENU_EDITOR = (444 / W0, 599 / H0)             # main menu: the Scenario Editor button
EDITOR_MENUBAR = (1280 / W0, 14 / H0)          # editor: dark grey menu bar
EDITOR_PLAYERBOX = (2375 / W0, 45 / H0)        # editor: the blue player-colour box
VIDEO_PROBES = ((1280 / W0, 540 / H0), (640 / W0, 300 / H0))   # a non-black pixel here = an intro video
LOADBAR_Y = 1032 / H0                          # the generation load bar row
LOADBAR_X = (785 / W0, 1773 / W0)              # its x span
LONDON_ROW = (1024 / W0, 528 / H0)             # Type dropdown, list scrolled to the top: row 2 = 00000_zplondon


def _px(im, nx, ny):
    w, h = im.size
    return im.getpixel((min(w - 1, round(nx * w)), min(h - 1, round(ny * h))))


def grab(h):
    """The client area of window h as RGB (all monitors)."""
    return gw.Pilot(h).grab()


def is_menu(im):
    # the left button column: >= 12 gold label rows between y 240 and 720 (videos give < 8)
    def gold(c): return c[0] > 190 and c[1] > 160 and c[2] < 160
    w, h = im.size
    x = round(MENU_COLUMN_X * w)
    step = max(1, round(2 * h / H0))
    rows = sum(1 for y in range(round(MENU_COLUMN_Y[0] * h), round(MENU_COLUMN_Y[1] * h), step) if gold(im.getpixel((x, y))))
    return rows >= 12


def is_editor(im):
    a = _px(im, *EDITOR_MENUBAR); b = _px(im, *EDITOR_PLAYERBOX)     # dark grey menu bar + the blue player-colour box
    return abs(a[0] - a[1]) < 12 and a[0] < 60 and b[2] > 200 and b[0] < 80


def bar_fill(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    y = min(h - 1, round(LOADBAR_Y * h)); x0, x1 = round(LOADBAR_X[0] * w), round(LOADBAR_X[1] * w)
    lit = sum(1 for x in range(x0, x1) if (lambda p: p[2] > 150 and p[1] > 150 and p[0] < 120)(im.getpixel((x, y))))
    return round(100.0 * lit / (x1 - x0), 1)


def open_editor(P, tag, exit_code):
    """From the main menu: wait out the click lock, click Scenario Editor up to 4 times, 40 s each."""
    P.wait(10, "(the menu ignores clicks for a while after it appears)")
    t2 = time.time(); ok = False
    for attempt in range(4):
        P.focus(); P.click(*MENU_EDITOR, "Scenario Editor")
        if P.dry_run:
            print(f"DRY check is_editor at {EDITOR_MENUBAR} and {EDITOR_PLAYERBOX} every 5 s, 8 times, up to 4 attempts")
            ok = True; break
        for _ in range(8):
            time.sleep(5)
            if is_editor(P.grab()): ok = True; break
        if ok: break
        print("editor click", attempt + 1, "did not take", flush=True)
    print("editor" if ok else "EDITOR NOT SEEN", "after", round(time.time() - t2), "s", flush=True)
    if not ok:
        P.shot(os.path.join(S, f"{tag}_noeditor.png")); return exit_code
    P.wait(3)
    return 0


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    dry = "--dry-run" in argv
    pos = [a for a in argv if not a.startswith("--")]
    tag = pos[0] if len(pos) > 0 else "run"
    seed = pos[1] if len(pos) > 1 else "4242"
    restart = "--no-restart" not in argv and "--from-menu" not in argv and "--in-editor" not in argv
    from_menu = "--from-menu" in argv
    if not dry:
        os.makedirs(S, exist_ok=True)

    if restart:
        if dry:
            P = gw.open_pilot(True)
            if not P: return 2
            print("DRY kill AoE3DE_s (Stop-Process -Force) - ONLY on the user's explicit word")
            print("DRY launch steam://rungameid/933110, wait up to 150 s for the window, then 30 s")
            print(f"DRY every 6 s for up to 300 s, once the client is >= {W0}x{H0}: focus, grab; is_menu at x "
                  f"{MENU_COLUMN_X:.5f}, y {MENU_COLUMN_Y[0]:.5f}..{MENU_COLUMN_Y[1]:.5f} -> done; a lit pixel at "
                  f"{VIDEO_PROBES} -> Esc (0x1B)")
            rc = open_editor(P, tag, 4)
            if rc: return rc
        else:
            subprocess.run(["powershell", "-NoProfile", "-Command", "Stop-Process -Name AoE3DE_s -Force -ErrorAction SilentlyContinue"], capture_output=True)
            time.sleep(4)
            subprocess.run(["powershell", "-NoProfile", "-Command", "Start-Process 'steam://rungameid/933110'"], capture_output=True)
            t0 = time.time(); h = None
            while time.time() - t0 < 150:
                h = gw.find_window()
                if h: break
                time.sleep(3)
            print("window after", round(time.time() - t0), "s", flush=True)
            time.sleep(30)
            t1 = time.time(); ok = False; black = 0; P = None
            while time.time() - t1 < 300:
                h = gw.find_window()
                if h:
                    try:
                        P = gw.Pilot(h)
                        w, hh = P.size()
                        if w >= W0 and hh >= H0:          # the window boots small; the sheet needs the full client
                            P.focus()
                            im = P.grab()
                            if is_menu(im):
                                ok = True; break
                            if any(sum(_px(im, *p)) > 30 for p in VIDEO_PROBES):
                                P.key(0x1B)        # a video is showing: skip it
                            else:
                                black += 1
                    except Exception as e:
                        print("grab err", e, flush=True)
                time.sleep(6)
            print("black frames seen", black, flush=True)
            print("menu" if ok else "MENU NOT SEEN", "after", round(time.time() - t1), "s", flush=True)
            if not ok:
                if P: P.shot(os.path.join(S, f"{tag}_nomenu.png"))
                return 2
            print(P.header(), flush=True)
            rc = open_editor(P, tag, 4)
            if rc: return rc
    if from_menu:
        P = gw.open_pilot(dry)
        if not P: return 2
        P.focus(); P.wait(1)
        if not dry and not is_menu(P.grab()):
            P.shot(os.path.join(S, f"{tag}_notmenu.png")); print("NOT AT THE MENU"); return 3
        rc = open_editor(P, tag, 4)
        if rc: return rc
    P = gw.open_pilot(dry) if not restart else gw.Pilot(gw.find_window(), dry_run=dry)
    if not P or not P.hwnd: return 2
    P.focus()
    P.shot(os.path.join(S, f"{tag}_editor.png"))
    P.click(*N["file_menu"], "File"); P.wait(0.8)
    P.click(*N["file_new"], "New"); P.wait(1.5)
    P.click(*N["type_arrow"], "Type dropdown arrow"); P.wait(0.8)
    P.drag(N["dd_thumb_top_from"], N["dd_thumb_top_to"], "dropdown thumb to the top"); P.wait(0.5)
    P.click(*LONDON_ROW, "row 2 = 00000_zplondon"); P.wait(0.6)
    P.set_field(*N["seed_field"], seed, width=6, label="seed")
    P.shot(os.path.join(S, f"{tag}_dialog.png"))
    P.click(*N["generate"], "Generate")
    for i in range(12):
        P.wait(10)
        p = os.path.join(S, f"{tag}_gen_{i:02d}.png")
        P.shot(p)
        if dry:
            print(f"DRY bar_fill of each shot at y {LOADBAR_Y:.5f}, x {LOADBAR_X[0]:.5f}..{LOADBAR_X[1]:.5f}; "
                  f"stop when 0 % after the first reads (up to 12 x 10 s)")
            break
        f = bar_fill(p)
        print(f"t+{(i+1)*10}s bar {f}%", flush=True)
        if f == 0.0 and i >= 1:
            print("bar gone", flush=True); break
    P.shot(os.path.join(S, f"{tag}_final.png"))
    print("END", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
