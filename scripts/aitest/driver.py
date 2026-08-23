"""Unattended skirmish test driver - kill-cycle edition.

    python scripts/aitest/driver.py --runs 20

Per run:
  1. ensure the game is running (steam://rungameid/933110), wait for the home
     menu (verified by the calibrated Skirmish-button pixel)
  2. click Skirmish (124,490) -> verify lobby pixel -> click Play (1647,1020)
  3. wait for the MATCH via the log: a new "Main is starting" appended to
     Age3Log.txt (the loading screen blits black, so pixels cannot see it -
     the log is authoritative)
  4. tail the log live until a landing verdict or the 20-minute cap
  5. archive events + log slice to runs/run_NNN/, append results.csv
  6. taskkill the game - every run recompiles the AI from disk, no Restart
     ambiguity - and loop

STOP file next to this script = end batch after current run. Mouse to the
top-left corner = instant abort. Writes only under scripts/aitest/.
Self-calibrated for 1920x1080 borderless; recalibrate nav_points.json if the
resolution or UI scale changes (see NAVIGATION.md).
"""
import argparse
import ctypes
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


def game_running():
    try:
        out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq " + EXE],
                             capture_output=True, text=True, timeout=30).stdout
        return EXE in out
    except Exception:
        return False


def kill_game():
    subprocess.run(["taskkill", "/IM", EXE, "/F"], capture_output=True, timeout=30)
    time.sleep(8)


def end_match(nav):
    """Graceful exit: cog -> Quit -> Yes -> home menu. Flushes the per-player
    AI logs (a match quit writes Age3DEAIOutputPlayerN.txt) and keeps the game
    process alive, so the next run skips the 75 s relaunch. Falls back to
    taskkill if the home menu never comes back."""
    guard(); click(nav["match_cog"]["x"], nav["match_cog"]["y"]); time.sleep(1.5)
    guard(); click(nav["match_quit"]["x"], nav["match_quit"]["y"]); time.sleep(2.5)
    guard(); click(nav["quit_yes"]["x"], nav["quit_yes"]["y"])
    if wait_probe(nav["home_skirmish"], 120):
        time.sleep(4)   # give the exit flush a moment
        return True
    print("   graceful quit failed - killing the process")
    kill_game()
    return False


def start_recording(path, cap_s):
    """Screen capture via ffmpeg gdigrab: 1280-wide, 10 fps, ~5-10 MB/min.
    -t caps the recording so it self-stops even if the driver dies."""
    ff = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet",
                      "Packages", "Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe",
                      "ffmpeg-9.0-full_build", "bin", "ffmpeg.exe")
    if not os.path.exists(ff):
        ff = "ffmpeg"
    try:
        return subprocess.Popen(
            [ff, "-y", "-f", "gdigrab", "-framerate", "10", "-t", str(cap_s),
             "-i", "desktop", "-vf", "scale=1280:-2",
             "-c:v", "libx264", "-preset", "ultrafast", "-crf", "28",
             "-pix_fmt", "yuv420p", path],
            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL)
    except Exception:
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
    while True:
        guard()
        time.sleep(10)
        pos, chunk = new_log_content(pos)
        for line in chunk.splitlines():
            if re.search(r"LAND p\d|LANDWAIT|GUNRAID|AREARECALC", line):
                events.append(line.strip()[-170:])
        j = "\n".join(events)
        if "LANDED" in j:
            return "LANDED", events
        if "boarding timed out" in j:
            return "BOARD-FAIL", events
        if "crossing timed out" in j:
            return "CROSS-FAIL", events
        if "ship lost" in j:
            return "SHIP-LOST", events
        if "sailing" in j and sail_at is None:
            sail_at = time.time()
        if sail_at and time.time() - sail_at > 6 * 60:
            return "CROSS-FAIL", events
        if time.time() - t0 > cap_s:
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
    a = ap.parse_args()

    nav = json.load(open(os.path.join(HERE, "nav_points.json")))
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
            print("   launching game (cold start)...")
            os.startfile(STEAM_URL)
            time.sleep(90)
        pos = start_match(nav)
        if pos < 0:
            lost += 1
            if lost >= 3:
                print("   LOST %d times - stopping for a human" % lost); break
            print("   navigation failed (%d/3) - fresh game process and retry" % lost)
            kill_game()
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
        end_match(nav)
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
    print("batch done - results in %s" % results)


if __name__ == "__main__":
    main()
