"""Visual documentation of a running match (owner 2026-09-24: 'screenshots of player base incl. farms behind the
walls + the minimap ... before you end the test').

    python scripts/aitest/snapshots.py <out_dir>

Takes: minimap.png (the minimap crop), full.png, then base_<colour>.png for each player colour found on the minimap -
the camera is moved by clicking the centroid of that colour's pixels on the minimap (the densest cluster = the base).
Only moves the camera; never selects or orders anything. Reads the sheet's minimap_center (with its crop radius r) and
mouse_park.
"""
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import driver  # noqa: E402

# player colours on the minimap (lobby order 1-5): blue, red, yellow, purple, green; tolerance per channel
COLOURS = {"p2_red": (230, 0, 0), "p3_yellow": (235, 235, 0), "p4_purple": (128, 0, 128), "p5_green": (0, 220, 0)}
TOL = 45


def move(pt):
    """Mouse move only (no click)."""
    mv = driver.INPUT(type=0)
    mv.u.mi = driver.MOUSEINPUT(int(pt[0] * 65535 / driver.SW), int(pt[1] * 65535 / driver.SH), 0, 0x0001 | 0x8000, 0, None)
    driver.send([mv])


def shot(path):
    subprocess.run([sys.executable, os.path.join(HERE, "probe.py"), "shot", path], timeout=30)


def world_targets(out, targets_json, size=None, screen="ingame", map_ref=None, players=None, teams=2,
                  unchecked=False):
    """2026-09-24 (minimap-twin skill): photograph a list of WORLD targets through the measured calibration -
    targets.json = [{"name": ..., "x_m": ..., "z_m": ...}, ...]; needs scripts/mapview/cal/<screen>_<WxH>.json,
    accepted and checked (unchecked=True drops the check gate). The map size is --size WxL or read from the map
    script (map_ref + players, through mapsim; both given must agree) and printed. Each target is camera.shot:
    verified by the camera trapezoid, then photographed; every result carries its target's name and the size, and
    the list goes to <out>/world_targets.json. Returns 0 only when the list is non-empty and every target was
    verified and photographed, 1 otherwise, 2 when refused before any target (targets file, map size). The batch
    stops at an abort (cursor in the top-left corner), a vanished game window, the game leaving the foreground, a
    cursor that did not land (camera.STOP_BATCH) or a refused calibration; the rest are listed as skipped.
    Only the target that first reaches the camera's focus step may bring the game to the front; every later one
    passes focus=False and needs the game still in front, so a batch never pulls the game back over a window the
    owner switched to (gameio review F1, fix round 2026-09-24). The colour-cluster mode below stays the fallback."""
    sys.path.insert(0, os.path.join(HERE, "..", ".."))
    from pathlib import Path
    from scripts.mapview import camera
    out = Path(out)
    try:
        sx, sz, src = camera.resolve_size(size, map_ref, players, teams)
    except Exception as e:                      # ValueError, FileNotFoundError, mapsim's ExtractError
        print("world: map size refused: %s" % e)
        return 2
    try:
        targets = json.loads(Path(targets_json).read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        print("world: cannot read %s: %s" % (targets_json, e))
        return 2
    if not isinstance(targets, list):
        print("world: %s must hold a JSON list of {name, x_m, z_m}" % targets_json)
        return 2
    out.mkdir(parents=True, exist_ok=True)
    print("world: %d target(s) on %gx%g m (%s), screen %s -> %s" % (len(targets), sx, sz, src, screen, out))
    results, stop, may_focus = [], None, True
    for i, t in enumerate(targets):
        name = t.get("name") if isinstance(t, dict) else None
        if stop is not None:
            results.append({"name": name, "ok": False, "state": "skipped", "size_m": [sx, sz],
                            "error": "batch stopped: %s" % stop})
            continue
        try:
            if not isinstance(t, dict) or not name or "x_m" not in t or "z_m" not in t:
                raise ValueError("target %d needs name, x_m and z_m: %r" % (i, t))
            res = camera.shot(float(t["x_m"]), float(t["z_m"]), sx, sz, str(name), out=out, screen=screen,
                              unchecked=unchecked, size_source=src, focus=may_focus)
            if res.get("focused"):
                may_focus = False
        except Exception as e:
            if (getattr(e, "camera_result", None) or {}).get("focused"):
                may_focus = False
            res = {"ok": False, "state": "error", "size_m": [sx, sz], "error": "%s: %s" % (type(e).__name__, e)}
            print("%s: %s" % (name, res["error"]))
            if camera.stops_batch(e):
                stop = res["error"]
        res["name"] = name
        results.append(res)
    (out / "world_targets.json").write_text(json.dumps(results, indent=1), encoding="utf-8")
    n_ok = sum(1 for r in results if r.get("ok"))
    print("world: %d of %d target(s) verified and photographed on %gx%g m -> %s"
          % (n_ok, len(results), sx, sz, out / "world_targets.json"))
    if not results:
        print("world: the target list is empty - nothing photographed")
        return 1
    return 0 if n_ok == len(results) else 1


def main():
    if "--world" in sys.argv[1:]:
        import argparse
        ap = argparse.ArgumentParser(prog="snapshots.py", description="world-target mode (world_targets)")
        ap.add_argument("out")
        ap.add_argument("--world", required=True, metavar="TARGETS_JSON")
        ap.add_argument("--size", help="map size XxZ in metres, e.g. 360x686 (London 3-5 players, the engine's size)")
        ap.add_argument("--map", help="map script (path, or a name under randmaps/): the size from mapsim")
        ap.add_argument("--players", type=int)
        ap.add_argument("--teams", type=int, default=2)
        ap.add_argument("--screen", default="ingame", choices=("ingame", "editor"))
        ap.add_argument("--unchecked", action="store_true")
        a = ap.parse_args(sys.argv[1:])
        if not a.size and not a.map:
            ap.error("the map size is needed: --size WxL, or --map <xs> --players N")
        return world_targets(a.out, a.world, a.size, a.screen, a.map, a.players, a.teams, a.unchecked)
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    from PIL import Image
    nav = driver.load_coords()
    cx, cy = nav["minimap_center"]["x"], nav["minimap_center"]["y"]
    r = nav["minimap_center"]["r"]                     # the crop's half-width: the whole disc
    driver.focus_game()
    park = (nav["mouse_park"]["x"], nav["mouse_park"]["y"])   # the mouse off the minimap: its hover tooltip covers it
    move(park)
    time.sleep(1.0)
    full = os.path.join(out, "full.png")
    shot(full)
    im = Image.open(full).convert("RGB")
    box = (cx - r, cy - r, cx + r, cy + r)
    im.crop(box).save(os.path.join(out, "minimap.png"))
    mm = im.crop(box)
    px = mm.load()
    for name, rgb in COLOURS.items():
        pts = [(x, y) for x in range(0, mm.width, 2) for y in range(0, mm.height, 2)
               if all(abs(px[x, y][i] - rgb[i]) <= TOL for i in range(3))]
        if len(pts) < 6:
            print("%s: not on the minimap (%d px)" % (name, len(pts)))
            continue
        # densest cluster: the point with the most neighbours within 20 px, then the centroid around it
        best = max(pts, key=lambda p: sum(1 for q in pts if abs(q[0] - p[0]) < 20 and abs(q[1] - p[1]) < 20))
        near = [q for q in pts if abs(q[0] - best[0]) < 25 and abs(q[1] - best[1]) < 25]
        mx = sum(q[0] for q in near) // len(near) + box[0]
        my = sum(q[1] for q in near) // len(near) + box[1]
        driver.click(mx, my)
        move(park)
        time.sleep(2.5)
        shot(os.path.join(out, "base_%s.png" % name))
        print("%s: %d px, camera to %d,%d" % (name, len(pts), mx, my))
    countryside(mm, box, park, out)


def countryside(mm, box, park, out):
    """The fields behind the city walls, per player: the river runs along the lit minimap's long axis (PCA), so a
    player's buildings farthest from that axis are the ones behind the wall - the countryside fields. For each colour,
    the centroid of its outermost 15 % pixels (by distance from the river axis) is clicked and photographed.
    (Run 29: fixed offsets along the short axis landed on the river - the explored strip is narrower than the map.)"""
    import numpy as np
    im = np.array(mm).astype(int)
    h, w, _ = im.shape
    ys, xs = np.mgrid[0:h, 0:w]
    lit = (((xs - w / 2) ** 2 + (ys - h / 2) ** 2) < (0.82 * w / 2) ** 2) & (im.sum(axis=2) > 90)
    # the river: London's water on the minimap is blue-grey, about (72,96,144) - its axis is the river line
    water = lit & (np.abs(im[:, :, 0] - 72) <= 16) & (np.abs(im[:, :, 1] - 96) <= 16) & (np.abs(im[:, :, 2] - 144) <= 20)
    pts = np.stack([xs[water], ys[water]], 1).astype(float)
    if len(pts) < 200:
        print("countryside: no river on the minimap (%d px)" % len(pts))
        return
    c = pts.mean(0)
    ev, evec = np.linalg.eigh(np.cov((pts - c).T))
    minor = evec[:, 0]   # across the river
    for name, rgb in COLOURS.items():
        m = lit & (np.abs(im[:, :, 0] - rgb[0]) <= TOL) & (np.abs(im[:, :, 1] - rgb[1]) <= TOL) & (np.abs(im[:, :, 2] - rgb[2]) <= TOL)
        cp = np.stack([xs[m], ys[m]], 1).astype(float)
        if len(cp) < 10:
            continue
        off = np.abs((cp - c) @ minor)
        far = cp[off >= np.percentile(off, 85)]
        q = far.mean(0)
        driver.click(int(q[0]) + box[0], int(q[1]) + box[1])
        move(park)
        time.sleep(2.5)
        shot(os.path.join(out, "fields_%s.png" % name))
        print("fields %s: outermost %d px at %d,%d" % (name, len(far), int(q[0]) + box[0], int(q[1]) + box[1]))


if __name__ == "__main__":
    sys.exit(main())
