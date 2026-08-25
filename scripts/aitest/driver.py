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
LOG = "c:/Users/rosti/Games/Age of Empires 3 DE/Logs/Age3Log.txt"
AI_FILE = os.path.normpath(os.path.join(
    HERE, "..", "..", "game", "ai", "core", "aipiraterules.xs"))
STEAM_URL = "steam://rungameid/933110"
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


def probe_ok(pt, tol=30):
    got = pixel_at(pt["x"], pt["y"])
    if got is None:
        return False
    return max(abs(a - b) for a, b in zip(pt["rgb"], got)) <= tol


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


def end_match(nav):
    """Graceful exit: cog -> Quit -> Yes -> home menu. Flushes the per-player
    AI logs (a match quit writes Age3DEAIOutputPlayerN.txt). NEVER touches the
    game process - if the home menu does not come back, the driver stops and
    leaves the machine to the human (see the HARD RULE in the header)."""
    guard(); click(nav["match_cog"]["x"], nav["match_cog"]["y"]); time.sleep(1.5)
    guard(); click(nav["match_quit"]["x"], nav["match_quit"]["y"]); time.sleep(2.5)
    guard(); click(nav["quit_yes"]["x"], nav["quit_yes"]["y"])
    if wait_probe(nav["home_skirmish"], 120):
        time.sleep(4)   # give the exit flush a moment
        return True
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


def start_match(nav):
    """Home menu -> Skirmish -> Play -> wait for 'Main is starting' in the log.
    Returns the log offset at match start, or -1."""
    if not wait_probe(nav["home_skirmish"], 150):
        print("   home menu not detected"); return -1
    guard(); click(nav["home_skirmish"]["x"], nav["home_skirmish"]["y"])
    time.sleep(4)
    if not wait_probe(nav["lobby_probe"], 30):
        print("   lobby not detected after Skirmish click"); return -1
    pos = log_size()
    guard(); click(nav["lobby_play"]["x"], nav["lobby_play"]["y"])
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


def watch_verdict(pos, cap_s):
    t0 = time.time()
    events = []
    sail_at = None
    capture_seen = False
    while True:
        guard()
        time.sleep(10)
        # crash awareness: a dead game process is a first-class verdict, not
        # a 30-minute log-tail wait. (The corner-abort also fires on crashes
        # because Windows resets the cursor to 0,0 - this check names the
        # cause properly and points at the freshest minidump if armed.)
        if not game_running():
            dumps = sorted(glob.glob(
                "c:/Users/rosti/Games/Age of Empires 3 DE/CrashDumps/*.dmp"),
                key=os.path.getmtime)
            note = ("newest dump: " + os.path.basename(dumps[-1])) if dumps \
                else "no dump found (LocalDumps not armed?)"
            events.append("GAME PROCESS DIED - " + note)
            return "GAME-CRASHED", events
        pos, chunk = new_log_content(pos)
        for line in chunk.splitlines():
            if re.search(r"LAND p\d|LANDWAIT|GUNRAID|AREARECALC|PALACE", line):
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
    a = ap.parse_args()

    nav = load_coords()
    runs_dir = os.path.join(HERE, "runs")
    os.makedirs(runs_dir, exist_ok=True)
    results = os.path.join(HERE, "results.csv")
    if not os.path.exists(results):
        with open(results, "w") as f:
            f.write("run,start,verdict,seconds,events,ai_mtime\n")
    existing = [d for d in os.listdir(runs_dir) if d.startswith("run_")]
    n0 = max([int(d.split("_")[1]) for d in existing], default=0)
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
            os.startfile(STEAM_URL)
            if not wait_probe(nav["home_skirmish"], 240):
                print("   relaunch did not reach the home menu in 240 s -"
                      " stopping for a human")
                break
            time.sleep(5)
        pos = start_match(nav)
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
        verdict, events = watch_verdict(pos, a.cap_min * 60)
        secs = int(time.time() - t0)
        rd = os.path.join(runs_dir, "run_%03d" % run_no)
        os.makedirs(rd, exist_ok=True)
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
        # campaign is DONE only after 3 consecutive all-PASS runs.
        try:
            crit = subprocess.run(
                [sys.executable, os.path.join(HERE, "criteria.py"), rd],
                capture_output=True, text=True, timeout=60)
            with open(os.path.join(rd, "criteria.txt"), "w", encoding="utf-8") as f:
                f.write(crit.stdout)
            for ln in crit.stdout.splitlines():
                if ln.startswith("RUN VERDICT"):
                    print("   " + ln)
        except Exception as e:
            print("   criteria evaluation failed: %s" % e)
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
        quit_ok = end_match(nav)
        # archive the per-player AI logs the quit just flushed
        logdir = "c:/Users/rosti/Games/Age of Empires 3 DE/Logs"
        for pn in range(1, 9):
            src = os.path.join(logdir, "Age3DEAIOutputPlayer%d.txt" % pn)
            if os.path.exists(src) and os.path.getsize(src) > 0:
                try:
                    with open(src, "rb") as fi, open(
                            os.path.join(rd, os.path.basename(src)), "wb") as fo:
                        fo.write(fi.read())
                except OSError:
                    pass
        if not quit_ok:
            print("   screen state unknown after failed quit - stopping the"
                  " batch; the game process is untouched")
            break
    print("batch done - results in %s" % results)


if __name__ == "__main__":
    main()
