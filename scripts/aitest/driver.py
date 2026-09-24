"""Unattended skirmish test driver - hands-off-the-process edition.

    python scripts/aitest/driver.py --runs 20

HARD RULE (user directive 2026-08-24): this script NEVER kills and NEVER
launches the game process. Restarts are the user's job, done manually - and
only ever needed for process-load data (art/xml), never for AI scripts, which
recompile at every match start. When the driver cannot proceed (game not
running, navigation lost, quit not confirmed) it STOPS and reports; it does
not "fix" the situation by touching the process.

Per run:
  1. verify the game is running and at the home menu (calibrated
     Skirmish-button pixel); if not, stop and ask the human
  2. click Skirmish (124,490) -> verify lobby pixel -> click Play (1647,1020)
  3. wait for the MATCH via the log: a new "Main is starting" appended to
     Age3Log.txt (the loading screen blits black, so pixels cannot see it -
     the log is authoritative)
  4. tail the log live until a landing verdict or the --cap-min cap
  5. archive events + log slice to runs/run_NNN/, append results.csv
  6. graceful cog -> Quit -> Yes back to the home menu (this flushes the
     per-player AI logs) - and loop

STOP file next to this script = end batch after current run. Mouse to the
top-left corner = instant abort. Writes only under scripts/aitest/.
Self-calibrated for 1920x1080 borderless; recalibrate nav_points.json if the
resolution or UI scale changes (see NAVIGATION.md).
"""
import argparse
import ctypes
import glob
import json
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
# device-agnostic: the AoE3 user folder lives under the CURRENT profile
USERDIR = os.path.join(os.path.expanduser("~"), "Games", "Age of Empires 3 DE")
LOG = os.path.join(USERDIR, "Logs", "Age3Log.txt")
AI_FILE = os.path.normpath(os.path.join(
    HERE, "..", "..", "game", "ai", "core", "aipiraterules.xs"))
STEAM_URL = "steam://rungameid/933110"
LOADED_DIR = os.path.join(HERE, "runs", "_loaded")   # the post-load screenshot; the driver copies it into the run folder
AI_HASH_AT_PLAY = None
EXE = "AoE3DE_s.exe"

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32
user32.SetProcessDPIAware()
SW = user32.GetSystemMetrics(0)
SH = user32.GetSystemMetrics(1)


class MOUSEINPUT(ctypes.Structure):
    _fields_ = [("dx", ctypes.c_long), ("dy", ctypes.c_long),
                ("mouseData", ctypes.c_ulong), ("dwFlags", ctypes.c_ulong),
                ("time", ctypes.c_ulong),
                ("dwExtraInfo", ctypes.POINTER(ctypes.c_ulong))]


class _IU(ctypes.Union):
    _fields_ = [("mi", MOUSEINPUT)]


class INPUT(ctypes.Structure):
    _fields_ = [("type", ctypes.c_ulong), ("u", _IU)]


class POINT(ctypes.Structure):
    _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]


def send(inputs):
    arr = (INPUT * len(inputs))(*inputs)
    user32.SendInput(len(inputs), arr, ctypes.sizeof(INPUT))


def focus_game():
    """Bring the game window to the front: the game eats the first click after
    losing focus (coords sheet note). The Alt tap lifts the foreground lock."""
    h = user32.FindWindowW(None, "Age of Empires III: Definitive Edition")
    if not h:
        return False
    user32.keybd_event(0x12, 0, 0, 0); user32.SetForegroundWindow(h); user32.keybd_event(0x12, 0, 2, 0)
    time.sleep(1.0)
    return True


def click(x, y):
    mv = INPUT(type=0)
    mv.u.mi = MOUSEINPUT(int(x * 65535 / SW), int(y * 65535 / SH), 0,
                         0x0001 | 0x8000, 0, None)
    send([mv]); time.sleep(0.2)
    dn = INPUT(type=0); dn.u.mi = MOUSEINPUT(0, 0, 0, 0x0002, 0, None)
    up = INPUT(type=0); up.u.mi = MOUSEINPUT(0, 0, 0, 0x0004, 0, None)
    send([dn]); time.sleep(0.09); send([up])


def pixel_at(x, y):
    dc = user32.GetDC(0)
    raw = gdi32.GetPixel(dc, x, y)
    user32.ReleaseDC(0, dc)
    if raw == 0xFFFFFFFF:
        return None
    return (raw & 0xFF, (raw >> 8) & 0xFF, (raw >> 16) & 0xFF)


def key_esc():
    """Tap Escape - skips the intro videos during a cold boot (the home-menu
    pixel never appears while they play; see the game-startup skill)."""
    key_vk(0x1B)   # the old keyboard-only INPUT struct was silently dropped by SendInput (2026-09-23)


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [("wVk", ctypes.c_ushort), ("wScan", ctypes.c_ushort),
                ("dwFlags", ctypes.c_ulong), ("time", ctypes.c_ulong),
                ("dwExtraInfo", ctypes.POINTER(ctypes.c_ulong))]


class _KIU(ctypes.Union):
    # the union MUST hold the mouse member too: SendInput checks cbSize against the full INPUT (40 bytes on x64)
    # and silently drops keyboard-only structs (2026-09-23: every typed key of the map search was lost)
    _fields_ = [("mi", MOUSEINPUT), ("ki", KEYBDINPUT)]


class KINPUT(ctypes.Structure):
    _fields_ = [("type", ctypes.c_ulong), ("u", _KIU)]


def _send_key(vk, scan, flags):
    arr = (KINPUT * 1)()
    arr[0].type = 1
    arr[0].u.ki = KEYBDINPUT(vk, scan, flags, 0, None)
    return user32.SendInput(1, arr, ctypes.sizeof(KINPUT))


def key_vk(vk):
    # the game reads the scan code (a VK-only backspace is ignored, 2026-09-23); Delete/End/arrows are extended keys
    scan = user32.MapVirtualKeyW(vk, 0)
    ext = 0x0001 if vk in (0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x2D, 0x2E) else 0
    _send_key(vk, scan, ext); time.sleep(0.03)
    _send_key(vk, scan, ext | 0x0002); time.sleep(0.03)


def type_text(text):
    """Unicode typing (KEYEVENTF_UNICODE), probe.py's type_text."""
    for ch in text:
        _send_key(0, ord(ch), 0x0004); time.sleep(0.03)
        _send_key(0, ord(ch), 0x0004 | 0x0002); time.sleep(0.03)


def minimap_signature():
    """A coarse fingerprint of the lobby's minimap (2880x1800 sheet: centre 2330,360, radius ~180): a 9 x 9 grid
    of pixels. It changes whenever another map is selected."""
    cx, cy = int(2330 * SW / 2880), int(360 * SH / 1800)
    r = int(150 * SW / 2880)
    return tuple(pixel_at(cx + dx * r // 4, cy + dy * r // 4) for dx in range(-4, 5) for dy in range(-4, 5))


# the maps the campaign plays, by SCRIPT name (what the game log's MAP CODE names): the picker search text (part of the
# display name, unique in its category) and the category - the mod's maps are only under Select Type = Custom Maps.
# 2026-09-24: '--map Paris' searched All Maps, found no 'Paris' (the map is 'Storming of the Bastille') and started
# Carolina; the owner: 'learn to control the map selector ... you must use custom maps ... should be automated'.
MAPS = {
    "zpparis": ("Bastille", True),       # Storming of the Bastille
    "zplondon": ("Restoration", True),   # Restoration of the Monarchy
    "amazonia": ("Amazonia", False),
}


def region_flat(x, y, r=40):
    """True when the screen around (x, y) is one flat colour: an empty grid slot (a tile has a minimap / artwork)."""
    px = [pixel_at(x + dx, y + dy) for dx in (-r, 0, r) for dy in (-r, 0, r)]
    if any(q is None for q in px):
        return False
    return max(max(q[c] for q in px) - min(q[c] for q in px) for c in range(3)) <= 25


def select_map(nav, name, shot_path=None, custom=False):
    """Lobby -> map picker -> the map whose name matches `name` -> OK (calibrated 2026-09-23 on Amazonia/Carolina).
    The picker's rules, measured: it REMEMBERS its search text and applies it only when it opens (an open picker
    with text shows the filtered list); typing into an open picker filters nothing; emptying the box resets it to
    the category grid, whose first tile is 'All Maps' (a RANDOM map). So: open, clear, type, cancel, reopen (now the
    filtered list), take the first tile, OK. `name` must be specific enough that the wanted map is the first tile.
    Verified twice: the lobby preview must be a round minimap (not the square All Maps parchment) and must differ
    from before unless it was already this map. shot_path: a lobby screenshot for the visual check."""
    for k in ("lobby_mapbutton", "picker_search", "picker_first", "picker_ok"):
        if k not in nav:
            print("   coordinate sheet lacks %s - cannot select a map" % k); return False
    before = minimap_signature()
    focus_game()
    guard(); click(nav["lobby_mapbutton"]["x"], nav["lobby_mapbutton"]["y"]); time.sleep(3)
    guard(); click(nav["picker_search"]["x"], nav["picker_search"]["y"]); time.sleep(0.8)
    for _ in range(40):   # the click drops the caret mid-word: clear both sides
        key_vk(0x2E)      # Delete
        key_vk(0x08)      # Backspace
    time.sleep(1.5)
    type_text(name); time.sleep(1.0)
    key_esc(); time.sleep(2.5)                     # cancel: the picker keeps the text
    if not wait_probe(nav["lobby_probe"], 10):
        print("   the picker did not close on Escape"); return False
    guard(); click(nav["lobby_mapbutton"]["x"], nav["lobby_mapbutton"]["y"]); time.sleep(3.5)   # reopens filtered
    # the category: a reopened picker is back on 'All Maps', where the mod's maps do not exist (measured 2026-09-24);
    # set it explicitly every time
    if custom and "picker_type_custom" in nav:
        guard(); click(nav["picker_type"]["x"], nav["picker_type"]["y"]); time.sleep(1.2)
        guard(); click(nav["picker_type_custom"]["x"], nav["picker_type_custom"]["y"]); time.sleep(2.5)
    elif "picker_type_all" in nav:
        guard(); click(nav["picker_type"]["x"], nav["picker_type"]["y"]); time.sleep(1.2)
        guard(); click(nav["picker_type_all"]["x"], nav["picker_type_all"]["y"]); time.sleep(2.5)
    if "picker_second" in nav:
        if region_flat(nav["picker_first"]["x"], nav["picker_first"]["y"] - 30):
            print("   the filtered list is EMPTY for '%s' (custom %s) - not selected" % (name, custom))
            key_esc(); return False
        if not region_flat(nav["picker_second"]["x"], nav["picker_second"]["y"]):
            print("   the filtered list has MORE than one tile for '%s' - the search text is not unique; not selected" % name)
            key_esc(); return False
    guard(); click(nav["picker_first"]["x"], nav["picker_first"]["y"]); time.sleep(1.5)
    guard(); click(nav["picker_ok"]["x"], nav["picker_ok"]["y"]); time.sleep(3)
    if not wait_probe(nav["lobby_probe"], 15):
        print("   map picker did not return to the lobby"); return False
    time.sleep(2)
    corner = pixel_at(int(2185 * SW / 2880), int(215 * SH / 1800))
    if corner is None or max(corner) > 70:
        print("   the lobby shows no round minimap (corner %s) - probably the random 'All Maps' tile; '%s' not selected"
              % (corner, name))
        return False
    if minimap_signature() == before:
        print("   the lobby minimap did not change - '%s' was already selected, or the pick failed" % name)
    if shot_path:
        try:
            subprocess.run([sys.executable, os.path.join(HERE, "probe.py"), "shot", shot_path], timeout=30)
        except Exception as e:
            print("   lobby screenshot failed: %s" % e)
    print("   map selected: %s (custom maps %s)" % (name, custom))
    return True


def dismiss_crash_dialog():
    """Close BugSplat's crash-report window with WM_CLOSE (the polite
    'Don't send'). Steam refuses to relaunch while the dialog holds the dead
    session. Returns how many dialogs were closed. Never touches the game
    process itself."""
    closed = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    def cb(hwnd, lparam):
        buf = ctypes.create_unicode_buffer(160)
        user32.GetWindowTextW(hwnd, buf, 160)
        if "encountered a problem" in buf.value:
            user32.PostMessageW(hwnd, 0x0010, 0, 0)   # WM_CLOSE
            closed.append(buf.value)
        return True

    user32.EnumWindows(cb, 0)
    return len(closed)


def wait_home_with_skip(nav, timeout_s):
    """Wait for the home menu after a cold boot: tap Esc every ~10 s to skip
    intro videos, and every other cycle click the popup Close spot (weekly
    reward popups dim the menu, defeat the pixel probe, and ignore Esc; on a
    clean home screen that spot is background water, so the click is inert).
    Returns True when the home probe matches."""
    t0 = time.time()
    cycle = 0
    while time.time() - t0 < timeout_s:
        guard()
        if probe_ok(nav["home_skirmish"]):
            return True
        key_esc()
        if cycle % 2 == 1 and "popup_close" in nav:
            click(nav["popup_close"]["x"], nav["popup_close"]["y"])
        cycle += 1
        time.sleep(10)
    return False


def probe_ok(pt, tol=30):
    got = pixel_at(pt["x"], pt["y"])
    if got is None:
        return False
    if max(abs(a - b) for a, b in zip(pt["rgb"], got)) > tol:
        return False
    # a point may carry a second pixel that must match too (2026-09-23: the in-match terrain under the Skirmish
    # button matched the home probe, the driver took a resign screen for the home menu and the logs never flushed)
    also = pt.get("also")
    if also:
        return probe_ok(also, tol)
    return True


def abort_requested():
    p = POINT()
    user32.GetCursorPos(ctypes.byref(p))
    return p.x <= 5 and p.y <= 5


def guard():
    if abort_requested():
        print("ABORT: mouse in top-left corner"); sys.exit(2)


def stop_requested():
    return os.path.exists(os.path.join(HERE, "STOP"))


def load_coords():
    """Device-agnostic UI coordinates. Sheets live in coords/*.json, named
    <WIDTH>x<HEIGHT>_<variant> and are TRACKED (a sheet is reusable on any
    device with the same resolution). whichsheet.json next to this script is
    GITIGNORED, purely device-local, and selects the sheet:
        {"sheet": "1920x1080_default"}
    Without it, <current-resolution>_default is assumed. Missing sheet =
    stop and calibrate (python scripts/aitest/calibrate.py - see the
    ui-calibrate skill); the driver never guesses pixel positions."""
    sel = os.path.join(HERE, "whichsheet.json")
    if os.path.exists(sel):
        name = json.load(open(sel))["sheet"]
    else:
        name = "%dx%d_default" % (SW, SH)
    path = os.path.join(HERE, "coords", name + ".json")
    if not os.path.exists(path):
        sys.exit("no coordinate sheet '%s' (screen is %dx%d) - run\n"
                 "  python scripts/aitest/calibrate.py\n"
                 "or point scripts/aitest/whichsheet.json at an existing "
                 "sheet in scripts/aitest/coords/" % (name, SW, SH))
    print("   coordinate sheet: %s" % name)
    return json.load(open(path))


def game_running():
    try:
        out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq " + EXE],
                             capture_output=True, text=True, timeout=30).stdout
        return EXE in out
    except Exception:
        return False


def menu_state(nav):
    """Which cog menu is open (2026-09-24, measured): 'live' = the in-match menu (Photo Mode ... Resign, Quit - a
    button at y 615); 'post' = the short post-match menu (View Postgame ... Quit at y 414, where the LIVE menu has
    Restart); None = no menu. Decided on button-background pixels, never on text."""
    live = nav.get("menu_live_probe")
    post = nav.get("menu_post_probe")
    if live and probe_ok(live, 12):
        return "live"
    if post and probe_ok(post, 12):
        return "post"
    return None


def end_match(nav):
    """Graceful exit to the home menu (flushes the per-player AI logs). NEVER touches the game process - if the home
    menu does not come back, the driver stops and leaves the machine to the human (see the HARD RULE in the header).
    Run 20 (2026-09-24): a blind 'post-match Quit' click on the LIVE menu hit Restart and left a 'Restart current
    game?' dialog; so every click now follows a menu-state check, and an unknown state is answered with Escape."""
    for attempt in range(4):
        if probe_ok(nav["home_skirmish"]):
            time.sleep(4)
            return True
        focus_game()
        state = menu_state(nav)
        if state is None:
            guard(); click(nav["match_cog"]["x"], nav["match_cog"]["y"]); time.sleep(1.5)
            state = menu_state(nav)
        if state == "live":
            guard(); click(nav["match_quit"]["x"], nav["match_quit"]["y"]); time.sleep(2.5)
            guard(); click(nav["quit_yes"]["x"], nav["quit_yes"]["y"])
        elif state == "post":
            guard(); click(nav["postmatch_quit"]["x"], nav["postmatch_quit"]["y"]); time.sleep(1.5)
            if menu_state(nav) == "post":          # the first click after a focus change is eaten
                guard(); click(nav["postmatch_quit"]["x"], nav["postmatch_quit"]["y"])
        else:
            print("   quit attempt %d: no menu recognised - Escape and retry" % (attempt + 1))
            key_esc(); time.sleep(1.5)
            continue
        if wait_probe(nav["home_skirmish"], 25):
            time.sleep(4)   # give the exit flush a moment
            return True
        print("   quit attempt %d (%s menu) did not reach the home menu" % (attempt + 1, state))
    print("   graceful quit did NOT reach the home menu - stopping;"
          " the game process is untouched, hand it to the human")
    return False


def start_recording(path, cap_s):
    """Screen capture, 1280-wide, 10 fps, local file only.

    Primary: ddagrab (Desktop Duplication API) - reads the GPU's real output,
    so no gdigrab flicker (run_012 alternated two brightness levels every
    frame; ddagrab measured flat). Fallback: the old gdigrab pipeline if the
    ddagrab process dies within 2 s (no d3d11 device etc.).
    -t caps the recording so it self-stops even if the driver dies."""
    ff = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet",
                      "Packages", "Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe",
                      "ffmpeg-9.0-full_build", "bin", "ffmpeg.exe")
    if not os.path.exists(ff):
        ff = "ffmpeg"
    dda = [ff, "-y", "-t", str(cap_s),
           "-filter_complex", "ddagrab=framerate=10,hwdownload,format=bgra,scale=1280:-2",
           "-c:v", "libx264", "-preset", "ultrafast", "-crf", "26",
           "-pix_fmt", "yuv420p", path]
    gdi = [ff, "-y", "-f", "gdigrab", "-framerate", "10", "-t", str(cap_s),
           "-i", "desktop", "-vf", "scale=1280:-2",
           "-c:v", "libx264", "-preset", "ultrafast", "-crf", "28",
           "-pix_fmt", "yuv420p", path]
    for args in (dda, gdi):
        try:
            proc = subprocess.Popen(args, stdin=subprocess.PIPE,
                                    stdout=subprocess.DEVNULL,
                                    stderr=subprocess.DEVNULL)
            time.sleep(2)
            if proc.poll() is None:
                return proc
        except Exception:
            continue
    return None


def stop_recording(proc):
    if proc is None:
        return
    try:
        proc.stdin.write(b"q")
        proc.stdin.flush()
        proc.wait(timeout=20)
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass


def log_size():
    try:
        return os.path.getsize(LOG)
    except OSError:
        return 0


def ai_files_hash():
    """One hash over game/ai/core/*.xs - the AI compiles at match start, so an edit between Play and the end of the
    load makes the run ambiguous (run 21, 2026-09-24: an edit landed 60 s after Play on a slow London generation)."""
    import hashlib
    h = hashlib.sha1()
    core = os.path.join(os.path.dirname(AI_FILE))
    for f in sorted(glob.glob(os.path.join(core, "*.xs"))):
        with open(f, "rb") as fi:
            h.update(fi.read())
    return h.hexdigest()[:12]


def new_log_content(pos):
    size = log_size()
    if size < pos:
        pos = 0
    if size == pos:
        return pos, ""
    with open(LOG, "rb") as f:
        f.seek(pos)
        chunk = f.read(size - pos).decode("utf-8", errors="replace")
    return size, chunk


def wait_probe(pt, timeout_s):
    t0 = time.time()
    while time.time() - t0 < timeout_s:
        guard()
        if probe_ok(pt):
            return True
        time.sleep(3)
    return False


def start_match(nav, from_lobby=False, blind=False, load_s=150, map_name=None):
    """Home menu -> Skirmish -> Play -> wait for 'Main is starting' in the log.
    from_lobby: the lobby is already open with the map, skip the home-menu step.
    blind (2026-09-23, the live echo channel is silent since the September patch):
    after Play wait load_s for generation + load and return; the verdict then
    comes from the per-player AI files the quit flushes.
    Returns the log offset at match start, or -1."""
    if not from_lobby:
        if not wait_probe(nav["home_skirmish"], 150):
            print("   home menu not detected"); return -1
        focus_game(); guard(); click(nav["home_skirmish"]["x"], nav["home_skirmish"]["y"])
        time.sleep(4)
    if not wait_probe(nav["lobby_probe"], 30):
        print("   lobby not detected"); return -1
    if map_name:
        text, custom = MAPS.get(map_name, (map_name, False))
        if not select_map(nav, text, os.path.join(HERE, "last_lobby.png"), custom):
            return -1
    pos = log_size()
    global AI_HASH_AT_PLAY
    AI_HASH_AT_PLAY = ai_files_hash()
    focus_game(); guard(); click(nav["lobby_play"]["x"], nav["lobby_play"]["y"])
    time.sleep(6)
    if probe_ok(nav["lobby_play"]):   # the first click after a focus change is eaten: the lobby is still up, click once more
        print("   lobby still up after Play - clicking Play once more")
        guard(); click(nav["lobby_play"]["x"], nav["lobby_play"]["y"])
    if blind:
        print("   blind mode: %d s for generation + load" % load_s)
        t0 = time.time()
        while time.time() - t0 < load_s:
            guard(); time.sleep(5)
        # an AI compile error kills every AI player and shows a modal dialog the blind driver cannot see
        # (run 19, 2026-09-23): the game log names it - stop the batch instead of watching dead AIs for 30 minutes
        # ALWAYS a screenshot right after the load, no exception (owner 2026-09-24): an AI error dialog is visible
        # there before any log line is read; the agent looks at it every run
        try:
            os.makedirs(LOADED_DIR, exist_ok=True)
            loaded = os.path.join(LOADED_DIR, "loaded.png")
            subprocess.run([sys.executable, os.path.join(HERE, "probe.py"), "shot", loaded], timeout=30)
            print("   LOADED SCREENSHOT: %s - LOOK AT IT" % loaded)
        except Exception as e:
            print("   LOADED SCREENSHOT FAILED: %s - stopping" % e)
            return -2
        if ai_files_hash() != AI_HASH_AT_PLAY:
            print("   WARNING: game/ai/core changed during generation + load - this run is AMBIGUOUS (which AI compiled?)")
        else:
            print("   AI files unchanged during the load (hash %s)" % AI_HASH_AT_PLAY)
        _, chunk = new_log_content(pos)
        # the map the game generated, from its own log - a wrong map is stopped here, not watched for the whole cap
        if map_name:
            codes = re.findall(r"MAP CODE: '([^/']+)/", chunk)
            want = (map_name, "00000_" + map_name)
            if not codes:
                print("   no MAP CODE in the log after the load - cannot confirm the map; stopping")
                return -3
            if codes[-1].lower() not in want:
                print("   WRONG MAP: the game generated '%s', wanted '%s' - quitting this match" % (codes[-1], map_name))
                return -3
            print("   map confirmed by the log: %s" % codes[-1])
        errs = [ln.strip() for ln in chunk.splitlines() if "XS: Error" in ln]
        if errs:
            print("   AI COMPILE ERROR - stopping; first lines:")
            for ln in errs[:3]:
                print("     " + ln[-160:])
            return -2
        return pos
    t0 = time.time()
    buf = ""
    while time.time() - t0 < 300:          # map gen + load can be slow
        guard()
        time.sleep(5)
        pos, chunk = new_log_content(pos)
        buf += chunk
        if "Main is starting" in buf:
            return pos
    print("   match never started (no 'Main is starting' within 300 s)")
    return -1


def yes_no_dialog_up():
    """The game's modal Yes/No dialog (resignation offer, Quit, Restart): the left edges of its Yes and No buttons,
    measured 2026-09-24 on three dialogs: (960,1008) = (70,29,14) and (1540,1008) = (63,26,13); plain terrain differs."""
    a = pixel_at(960 * SW // 2880, 1008 * SH // 1800)
    b = pixel_at(1540 * SW // 2880, 1008 * SH // 1800)
    if a is None or b is None:
        return False
    return (max(abs(x - y) for x, y in zip(a, (70, 29, 14))) <= 10 and
            max(abs(x - y) for x, y in zip(b, (63, 26, 13))) <= 10)


def watch_verdict(pos, cap_s, blind=False):
    t0 = time.time()
    events = []
    sail_at = None
    capture_seen = False
    if blind:   # no live channel: keep the process alive to the cap, judge from the per-player files afterwards
        while time.time() - t0 < cap_s:
            guard(); time.sleep(10)
            if not game_running():
                events.append("GAME PROCESS DIED - blind mode")
                return "GAME-CRASHED", events
            # a beaten AI offers its resignation in a modal Yes/No dialog that PAUSES the game (run 24: Napoleon at
            # 27:01, the rest of the cap frozen); the Yes/No buttons' left edges identify it - accept
            if yes_no_dialog_up():
                focus_game()
                click(1139 * SW // 2880, 1008 * SH // 1800); time.sleep(1.5)
                if yes_no_dialog_up():          # the first click after a focus change is eaten
                    click(1139 * SW // 2880, 1008 * SH // 1800); time.sleep(1.5)
                msg = "AI RESIGNATION DIALOG accepted at %ds of the cap" % int(time.time() - t0)
                events.append(msg); print("   " + msg)
        return "BLIND-CAP", events
    while True:
        guard()
        time.sleep(10)
        # crash awareness: a dead game process is a first-class verdict, not
        # a 30-minute log-tail wait. (The corner-abort also fires on crashes
        # because Windows resets the cursor to 0,0 - this check names the
        # cause properly and points at the freshest minidump if armed.)
        if not game_running():
            dumps = sorted(glob.glob(
                os.path.join(USERDIR, "CrashDumps", "*.dmp")),
                key=os.path.getmtime)
            note = ("newest dump: " + os.path.basename(dumps[-1])) if dumps \
                else "no dump found (LocalDumps not armed?)"
            events.append("GAME PROCESS DIED - " + note)
            return "GAME-CRASHED", events
        pos, chunk = new_log_content(pos)
        for line in chunk.splitlines():
            # widened 2026-08-27: the narrow filter discarded GUNFLEET/GARRISON/
            # HOLD/MONITOR and the PALTRACE state lines, so the final tick
            # before a crash was lost and north-vs-south was unverifiable.
            if re.search(r"PALTRACE|LAND p\d|LANDWAIT|GUNRAID|GUNFLEET|AREARECALC"
                         r"|PALACE|GARRISON|HOLD p\d|MONITOR|BOARD|CROSS", line):
                events.append(line.strip()[-170:])
        j = "\n".join(events)
        # PALACE CAMPAIGN semantics: LANDED is progress, not a terminal -
        # the run succeeds when a landed force captures and garrisons the
        # OVERSEAS flag (PALACEHOLD comes only from the mission rule).
        # forensics FIX 5: the first PALACEHOLD used to END the run, leaving
        # the home-side captures a 1-2 second observation window. Now the
        # capture is latched and the run observes to the cap; boarding and
        # crossing failures likewise stay non-terminal (they self-heal via
        # the landing's cooldown retry).
        if "PALACEHOLD" in j:
            capture_seen = True
        if time.time() - t0 > cap_s:
            if capture_seen:
                return "PALACE-CAPTURED", events
            if "LANDED" in j:
                return "LANDED-NO-CAPTURE", events
            waits = re.findall(r"gate=([^\r\n]+)", j)
            if waits and "boarding" not in j:
                return "GATES-STUCK", events
            return ("NO-DATA" if not events else "GATES-STUCK"), events


def run_criteria(script, rd, extra=None):
    """Run a criteria module on the run folder; the table to criteria.txt, the verdict line to the console."""
    try:
        crit = subprocess.run([sys.executable, os.path.join(HERE, script), rd] + (extra or []),
                              capture_output=True, text=True, timeout=60)
        with open(os.path.join(rd, "criteria.txt"), "w", encoding="utf-8") as f:
            f.write(crit.stdout)
        for ln in crit.stdout.splitlines():
            if ln.startswith("RUN VERDICT"):
                print("   " + ln)
    except Exception as e:
        print("   criteria evaluation failed: %s" % e)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=10)
    ap.add_argument("--cap-min", type=int, default=20)
    ap.add_argument("--record", action="store_true",
                    help="capture the screen for each run into its archive")
    ap.add_argument("--allow-restart", action="store_true",
                    help="user-authorized (2026-08-25): relaunch the game via"
                         " Steam after a crash and continue the batch."
                         " Without it the driver stops and waits for a human."
                         " Killing the process remains forbidden always.")
    ap.add_argument("--from-lobby", action="store_true",
                    help="the lobby is already open with the map: skip the home-menu and Skirmish steps")
    ap.add_argument("--blind", action="store_true",
                    help="no live echo channel: after Play wait --load-s, then the cap, then quit;"
                         " the verdict comes from the per-player AI files (criteria module)")
    ap.add_argument("--load-s", type=int, default=150, help="--blind: seconds for map generation + load")
    ap.add_argument("--snapshots", action="store_true", help="before the quit: minimap + every AI base (snapshots.py)")
    ap.add_argument("--floor", default=None, help="--criteria baseline: the floor run's metrics.json to judge against")
    ap.add_argument("--map", default=None, help="select this map in the lobby first, by SCRIPT name (MAPS: zpparis, zplondon,"
                    " amazonia); the game log's MAP CODE must confirm it after the load")
    ap.add_argument("--criteria", default="istanbul", help="istanbul (criteria.py) or london (criteria_london.py)")
    a = ap.parse_args()

    nav = load_coords()
    runs_dir = os.path.join(HERE, "runs")
    os.makedirs(runs_dir, exist_ok=True)
    results = os.path.join(HERE, "results.csv")
    if not os.path.exists(results):
        with open(results, "w") as f:
            f.write("run,start,verdict,seconds,events,ai_mtime\n")
    existing = [d for d in os.listdir(runs_dir) if d.startswith("run_")]
    n0 = max([int(d.split("_")[1]) for d in existing if d.split("_")[1].isdigit()], default=0)   # run_032b, _loaded: not runs
    lost = 0
    done = 0

    # navigation failures cost `lost` budget, never a run - a batch of N means
    # N matches actually watched
    while done < a.runs:
        if stop_requested():
            print("STOP file found - ending batch"); break
        run_no = n0 + done + 1
        print("== run %d ==" % run_no)
        if not game_running():
            if not a.allow_restart:
                print("   game is NOT running - start it manually, then rerun,"
                      " or pass --allow-restart. The driver never kills the"
                      " process.")
                break
            print("   game not running - relaunching via Steam"
                  " (--allow-restart)...")
            n = dismiss_crash_dialog()
            if n:
                print("   dismissed %d crash-report dialog(s)" % n)
            t0 = time.time()
            while game_running() and time.time() - t0 < 60:
                time.sleep(5)   # let the dead session fully release
            os.startfile(STEAM_URL)
            if not wait_home_with_skip(nav, 300):
                print("   relaunch did not reach the home menu in 300 s -"
                      " stopping for a human")
                break
            time.sleep(5)
        # --from-lobby holds for the first match only: every quit returns to the home menu, and the lobby keeps
        # its setup (map, players, teams) for the next Skirmish click
        pos = start_match(nav, a.from_lobby and done == 0, a.blind, a.load_s, a.map)
        if pos == -2:
            print("   fix the AI file, dismiss the dialog (its OK moves with the error length), quit the match; rerun")
            break
        if pos == -3:   # the wrong map (or none confirmed) is running: leave it at once, never watch it
            end_match(nav)
            print("   stopped: the map was not confirmed - check MAPS / the picker, then rerun")
            break
        if pos < 0:
            lost += 1
            if lost >= 3:
                print("   LOST %d times - stopping for a human" % lost); break
            print("   navigation failed (%d/3) - waiting 20 s and retrying,"
                  " game process untouched" % lost)
            time.sleep(20)
            continue
        lost = 0
        done = done + 1
        rec = None
        rec_tmp = os.path.join(HERE, "recording_tmp.mp4")
        if a.record:
            rec = start_recording(rec_tmp, a.cap_min * 60 + 300)
        t0 = time.time()
        ai_mtime = time.strftime("%Y%m%d-%H%M%S",
                                 time.localtime(os.path.getmtime(AI_FILE)))
        verdict, events = watch_verdict(pos, a.cap_min * 60, a.blind)
        secs = int(time.time() - t0)
        rd = os.path.join(runs_dir, "run_%03d" % run_no)
        os.makedirs(rd, exist_ok=True)
        try:
            import shutil
            shutil.copy(os.path.join(LOADED_DIR, "loaded.png"), os.path.join(rd, "loaded.png"))
        except OSError:
            pass
        with open(os.path.join(rd, "events.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(events))
        with open(results, "a") as f:
            f.write("%d,%s,%s,%d,%d,%s\n" % (
                run_no, time.strftime("%H:%M:%S", time.localtime(t0)),
                verdict, secs, len(events), ai_mtime))
        print("   VERDICT %s after %ds (%d events)" % (verdict, secs, len(events)))
        stop_recording(rec)
        if a.record and os.path.exists(rec_tmp):
            try:
                os.replace(rec_tmp, os.path.join(rd, "match.mp4"))
            except OSError:
                pass
        # deterministic criteria: every run judges itself; the table lands in
        # the archive and the one-line verdict in the console. A stage of the
        # campaign is DONE only after 3 consecutive all-PASS runs. The London
        # criteria read the per-player files, so they run after the quit's flush.
        if a.criteria not in ("london", "baseline"):
            run_criteria("criteria.py", rd)
        if verdict == "GAME-CRASHED":
            if not a.allow_restart:
                print("   game process died mid-run - restart it manually and"
                      " rerun, or pass --allow-restart; the driver never"
                      " kills the process")
                break
            print("   game crashed - the next loop pass relaunches it"
                  " (--allow-restart); dump triage:"
                  " python scripts/aitest/crashdump_triage.py")
            continue
        if a.snapshots and verdict != "GAME-CRASHED":   # owner 2026-09-24: bases incl. the fields + the minimap
            try:
                subprocess.run([sys.executable, os.path.join(HERE, "snapshots.py"), os.path.join(rd, "snapshots")], timeout=120)
            except Exception as e:
                print("   snapshots failed: %s" % e)
        try:   # the match as it stands at the cap: score, age, minimap - the visual record of every run
            subprocess.run([sys.executable, os.path.join(HERE, "probe.py"), "shot", os.path.join(rd, "end.png")], timeout=30)
        except Exception as e:
            print("   end screenshot failed: %s" % e)
        quit_ok = end_match(nav)
        # archive the per-player AI logs the quit just flushed; only files written
        # during this run - a smaller match leaves the higher players' old files
        logdir = os.path.join(USERDIR, "Logs")
        for pn in range(1, 9):
            src = os.path.join(logdir, "Age3DEAIOutputPlayer%d.txt" % pn)
            if (os.path.exists(src) and os.path.getsize(src) > 0
                    and os.path.getmtime(src) >= t0):
                try:
                    with open(src, "rb") as fi, open(
                            os.path.join(rd, os.path.basename(src)), "wb") as fo:
                        fo.write(fi.read())
                except OSError:
                    pass
        if a.criteria == "baseline":   # standard map: the AIDIAG regression floor
            run_criteria("criteria_baseline.py", rd, ["--floor", a.floor] if a.floor else None)
        if a.criteria == "london":
            run_criteria("criteria_london.py", rd)
        if not quit_ok:
            print("   screen state unknown after failed quit - stopping the"
                  " batch; the game process is untouched")
            break
    print("batch done - results in %s" % results)


if __name__ == "__main__":
    main()
