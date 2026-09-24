"""Visual documentation of a running match (owner 2026-09-24: 'screenshots of player base incl. farms behind the
walls + the minimap ... before you end the test').

    python scripts/aitest/snapshots.py <out_dir>

Takes: minimap.png (the minimap crop), full.png, then base_<colour>.png for each player colour found on the minimap -
the camera is moved by clicking the centroid of that colour's pixels on the minimap (the densest cluster = the base).
Only moves the camera; never selects or orders anything. Measured on the 2880x1800 sheet (minimap_center).
"""
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


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    from PIL import Image
    nav = driver.load_coords()
    cx, cy = nav["minimap_center"]["x"], nav["minimap_center"]["y"]
    r = 200 * driver.SW // 2880
    driver.focus_game()
    park = (driver.SW // 2, 60 * driver.SH // 1800)   # the mouse off the minimap: its hover tooltip covers it
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
    main()
