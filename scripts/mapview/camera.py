"""Camera and capture in a running match, aimed by world coordinates through a measured calibration.

    python scripts/mapview/camera.py goto   <x_m> <z_m> --size 360x645 [--screen ingame]
    python scripts/mapview/camera.py shot   <x_m> <z_m> --size 360x645 --name enemy_block [--out dir]
    python scripts/mapview/camera.py record <x_m> <z_m> --size 360x645 --seconds 60 --name bridge [--out dir]
    python scripts/mapview/camera.py verify                       (where does the camera trapezoid sit now)

Owner's rules (spec 3.4): this module moves the camera ONLY. It clicks nothing but the minimap disc, never
selects or orders a unit, never kills or launches the game. It refuses to click without a MEASURED calibration
for the current screen (scripts/mapview/cal/ingame_<WxH>.json) and refuses a target outside the disc.

The click lands where transform.world_to_minimap says; `verify` finds the minimap's white camera trapezoid
(near-white pixels inside the disc) and reports its centroid's distance from the target - the spec's acceptance
is 3 px. The first click after a focus change is eaten by the game, so goto focuses first and re-verifies.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(REPO / "scripts" / "aitest"))
from scripts.mapview.transform import load_calibration, pixel_in_disc, world_to_minimap  # noqa: E402

ACCEPT_PX = 3.0
WHITE = 235


def _driver():
    import driver  # scripts/aitest/driver.py: click, focus_game, SW/SH, start_recording
    return driver


def screen_size():
    d = _driver()
    return d.SW, d.SH


def screenshot(path: Path) -> Path:
    subprocess.run([sys.executable, str(REPO / "scripts" / "aitest" / "probe.py"), "shot", str(path)], timeout=30, check=True)
    return path


def park_mouse():
    """The mouse off the minimap: its hover tooltip covers it (snapshots.py)."""
    d = _driver()
    mv = d.INPUT(type=0)
    mv.u.mi = d.MOUSEINPUT(int((d.SW // 2) * 65535 / d.SW), int((60 * d.SH // 1800) * 65535 / d.SH), 0, 0x0001 | 0x8000, 0, None)
    d.send([mv])


def trapezoid_centroid(png: Path, cal) -> tuple | None:
    """Centroid of the near-white pixels inside the disc (the camera trapezoid on the HUD minimap), or None."""
    from PIL import Image
    im = Image.open(png).convert("RGB")
    px = im.load()
    r = int(cal.radius_px) + 2
    pts = []
    for y in range(max(0, int(cal.cy) - r), min(im.height, int(cal.cy) + r)):
        for x in range(max(0, int(cal.cx) - r), min(im.width, int(cal.cx) + r)):
            if math.hypot(x - cal.cx, y - cal.cy) > cal.radius_px:
                continue
            c = px[x, y]
            if c[0] >= WHITE and c[1] >= WHITE and c[2] >= WHITE:
                pts.append((x, y))
    if len(pts) < 8:
        return None
    return sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts), len(pts)


def goto(x_m: float, z_m: float, size_x_m: float, size_z_m: float, screen: str = "ingame", out: Path | None = None) -> dict:
    d = _driver()
    w, h = screen_size()
    cal = load_calibration(screen, w, h)              # refuses an unmeasured record
    px, py = world_to_minimap(x_m, z_m, size_x_m, size_z_m, cal)
    if not pixel_in_disc(px, py, cal, margin_px=1.0):
        raise ValueError("target (%.1f, %.1f) m maps to (%.1f, %.1f) px, outside the minimap disc - refused" % (x_m, z_m, px, py))
    d.focus_game()
    d.click(px, py)
    time.sleep(0.6)
    park_mouse()
    time.sleep(0.8)
    out = out or (REPO / "scripts" / "mapview" / "out" / "camera")
    out.mkdir(parents=True, exist_ok=True)
    shot = screenshot(out / "verify.png")
    c = trapezoid_centroid(shot, cal)
    err = None if c is None else math.hypot(c[0] - px, c[1] - py)
    if c is None or err > ACCEPT_PX:
        # the first click after a focus change is eaten: one retry, then report honestly
        d.click(px, py); time.sleep(0.6); park_mouse(); time.sleep(0.8)
        shot = screenshot(out / "verify.png")
        c = trapezoid_centroid(shot, cal)
        err = None if c is None else math.hypot(c[0] - px, c[1] - py)
    res = {"target_m": [x_m, z_m], "target_px": [round(px, 1), round(py, 1)], "trapezoid_px": None if c is None else [round(c[0], 1), round(c[1], 1)],
           "error_px": None if err is None else round(err, 2), "ok": err is not None and err <= ACCEPT_PX, "screen": "%s_%dx%d" % (screen, w, h)}
    print("goto (%.1f, %.1f) m -> (%.1f, %.1f) px: trapezoid %s, error %s px -> %s" % (
        x_m, z_m, px, py, res["trapezoid_px"], res["error_px"], "OK" if res["ok"] else "NOT VERIFIED"))
    return res


def shot(x_m: float, z_m: float, size_x_m: float, size_z_m: float, name: str, out: Path | None = None, screen: str = "ingame") -> dict:
    out = out or (REPO / "scripts" / "mapview" / "out" / "camera")
    res = goto(x_m, z_m, size_x_m, size_z_m, screen, out)
    time.sleep(2.5)
    full = screenshot(out / ("%s_full.png" % name))
    from PIL import Image
    im = Image.open(full)
    w, h = im.size
    box = (w // 2 - 640, h // 2 - 400, w // 2 + 640, h // 2 + 400)
    im.crop(box).save(out / ("%s_crop.png" % name))
    res.update({"full": str(full), "crop": str(out / ("%s_crop.png" % name))})
    (out / ("%s.json" % name)).write_text(json.dumps(res, indent=1), encoding="utf-8")
    return res


def record(x_m: float, z_m: float, size_x_m: float, size_z_m: float, seconds: int, name: str, out: Path | None = None, screen: str = "ingame") -> dict:
    d = _driver()
    out = out or (REPO / "scripts" / "mapview" / "out" / "camera")
    res = goto(x_m, z_m, size_x_m, size_z_m, screen, out)
    tmp = out / ("%s_recording_tmp.mp4" % name)
    proc = d.start_recording(str(tmp), seconds + 5)
    time.sleep(seconds)
    d.stop_recording(proc)
    final = out / ("%s.mp4" % name)
    try:
        os.replace(tmp, final)
    except OSError:
        final = tmp
    res.update({"video": str(final), "seconds": seconds})
    return res


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("goto", "shot", "record"):
        s = sub.add_parser(name); s.add_argument("x_m", type=float); s.add_argument("z_m", type=float)
        s.add_argument("--size", required=True, help="map size WxL in metres, e.g. 360x645")
        s.add_argument("--screen", default="ingame"); s.add_argument("--out", default=None)
        if name != "goto":
            s.add_argument("--name", required=True)
        if name == "record":
            s.add_argument("--seconds", type=int, default=60)
    sub.add_parser("verify")
    a = ap.parse_args(argv)
    if a.cmd == "verify":
        w, h = screen_size(); cal = load_calibration("ingame", w, h)
        p = screenshot(REPO / "scripts" / "mapview" / "out" / "camera" / "verify.png")
        print("trapezoid:", trapezoid_centroid(p, cal))
        return 0
    sx, sz = (float(x) for x in a.size.lower().split("x"))
    out = Path(a.out) if a.out else None
    if a.cmd == "goto":
        res = goto(a.x_m, a.z_m, sx, sz, a.screen, out)
    elif a.cmd == "shot":
        res = shot(a.x_m, a.z_m, sx, sz, a.name, out, a.screen)
    else:
        res = record(a.x_m, a.z_m, sx, sz, a.seconds, a.name, out, a.screen)
    return 0 if res.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
