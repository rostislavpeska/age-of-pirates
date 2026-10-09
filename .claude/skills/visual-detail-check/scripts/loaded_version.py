"""Which version of a file is the running game showing? Read-only: compares the game process start time with each
file's last write time. A game that reads its assets at start shows the last install made BEFORE it started; a file
written later is not on screen until the owner restarts the game. Never stops or starts a process.

    python loaded_version.py [--process AoE3DE_s.exe] FILE [FILE ...]

Exit 0 when every file predates the start, 1 when one is newer (restart needed), 2 when the process is not running.
"""
import argparse, datetime as dt, os, sys
import psutil

ap = argparse.ArgumentParser()
ap.add_argument('--process', default='AoE3DE_s.exe')
ap.add_argument('files', nargs='+')
a = ap.parse_args()
procs = [p for p in psutil.process_iter(['name', 'create_time', 'pid']) if (p.info['name'] or '').lower() == a.process.lower()]
if not procs:
    print(f'{a.process}: not running - nothing on screen to compare'); sys.exit(2)
start = max(p.info['create_time'] for p in procs)
fmt = lambda t: dt.datetime.fromtimestamp(t).strftime('%Y-%m-%d %H:%M:%S')
print(f"{a.process} pid {', '.join(str(p.info['pid']) for p in procs)} started {fmt(start)}")
late = 0
for f in a.files:
    m = os.path.getmtime(f); ok = m < start; late += not ok
    print(f"  {'LOADED     ' if ok else 'NOT LOADED '} {fmt(m)}  {f}" + ('' if ok else '  (written after the start: restart needed)'))
sys.exit(1 if late else 0)
