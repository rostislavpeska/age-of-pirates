"""Open a background-built review .blend in a NEW Blender instance (see ../SKILL.md and
../references/research.md - "background-Python connector alternative").

Why this exists: two live Blender GUI processes both running the MCP add-on's
default auto-start fight over the same fixed TCP port (9876). The add-on sets
SO_REUSEADDR before bind() (blender_mcp_addon.py ~line 542), which on Windows lets a
SECOND process's bind() silently take over a port a FIRST process is still listening
on - see research.md for the evidence. The safe pattern is: never open a second live
Blender while one already owns port 9876. Build/modify the review file with a
background `blender -b file --python script.py` run (no MCP, no live UI, cannot
collide with anything), THEN use this script to open exactly one dedicated Blender
window on it for human/agent review - after confirming nothing else already holds
the port.

Usage:
    python open_review.py REVIEW_BLEND [--exe path\\to\\blender.exe] [--port 9876]
        [--timeout 120] [--poll-interval 2] [--force]

Exit codes: 0 = port opened within the timeout, 1 = timed out, 2 = refused to start
(port already held by something else - pass --force to override).

Only the argument parsing and the port-wait polling loop are meant to be exercised
offline (see test_open_review.py). launch_blender() is a thin wrapper around
subprocess.Popen precisely so tests can monkeypatch it without ever starting Blender.
"""
import argparse
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mcp_log  # noqa: E402  (path insert must happen first)


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("blend", help="Path to the review .blend to open")
    ap.add_argument("--exe", default=None, help="Path to blender.exe (default: mcp_log.blender_exe())")
    ap.add_argument("--port", type=int, default=9876, help="MCP port to wait for (default 9876)")
    ap.add_argument("--timeout", type=float, default=120.0, help="Seconds to wait for the port (default 120)")
    ap.add_argument("--poll-interval", type=float, default=2.0, help="Seconds between port checks (default 2)")
    ap.add_argument("--force", action="store_true",
                     help="Launch even if something is already listening on --port "
                          "(reproduces the multi-instance port collision - see research.md)")
    return ap.parse_args(argv)


def wait_for_port(port, timeout, poll_interval=2.0, check_fn=None, sleep_fn=time.sleep, clock_fn=time.monotonic):
    """Poll check_fn(port) until it returns True or timeout elapses.

    Pure polling logic with every side effect injectable, so it can be unit-tested
    without opening a real socket or sleeping for real. Returns (opened: bool, elapsed: float).
    """
    if check_fn is None:
        check_fn = mcp_log.port_open
    start = clock_fn()
    while True:
        if check_fn(port):
            return True, clock_fn() - start
        elapsed = clock_fn() - start
        if elapsed >= timeout:
            return False, elapsed
        sleep_fn(poll_interval)


def launch_blender(exe, blend_path, popen_fn=subprocess.Popen):
    """Start Blender on blend_path. Isolated so tests can stub popen_fn."""
    return popen_fn([exe, str(blend_path)])


def main(argv=None):
    args = parse_args(argv)
    blend_path = Path(args.blend)
    exe = args.exe or mcp_log.blender_exe()

    already_open = mcp_log.port_open(args.port)
    if already_open and not args.force:
        print(f"Refusing to start: port {args.port} is already open. Opening another Blender "
              f"pointed at a different file will race the existing one for that port "
              f"(SO_REUSEADDR port-steal - see references/research.md). Close the existing "
              f"Blender first, or pass --force if you understand the risk.")
        mcp_log.write(dict(
            event="open_review",
            action=f"refused: port {args.port} already open",
            file=str(blend_path),
            forced=False,
        ))
        return 2

    mcp_log.write(dict(
        event="open_review",
        action="launching review instance",
        file=str(blend_path),
        exe=exe,
        port=args.port,
        forced=bool(already_open and args.force),
    ))

    launch_blender(exe, blend_path)

    opened, elapsed = wait_for_port(args.port, args.timeout, args.poll_interval)

    mcp_log.write(dict(
        event="open_review",
        action="wait_for_port result",
        file=str(blend_path),
        port=args.port,
        mcp_port_open=opened,
        seconds=round(elapsed, 1),
    ))

    if opened:
        print(f"Review Blender is up; port {args.port} responding after {elapsed:.1f}s.")
        return 0

    print(f"Timed out after {elapsed:.1f}s waiting for port {args.port}. "
          f"Check the new Blender window's system console for a bind error "
          f"(most likely cause: another Blender still holds the port).")
    return 1


if __name__ == "__main__":
    sys.exit(main())
