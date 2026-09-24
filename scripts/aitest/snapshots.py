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
    """The fields behind the city walls: the map is a rotated rectangle on the minimap with the river along its long
    axis, so the countryside behind each bank's wall is the strip along the two long outer edges. The axes come from
    the lit minimap pixels (PCA); three shots per edge at -90 / 0 / +90 px along the long axis, 85 % out along the short."""
    import numpy as np
    im = np.array(mm).astype(int)
    h, w, _ = im.shape
    ys, xs = np.mgrid[0:h, 0:w]
    lit = (((xs - w / 2) ** 2 + (ys - h / 2) ** 2) < (0.82 * w / 2) ** 2) & (im.sum(axis=2) > 90)
    pts = np.stack([xs[lit], ys[lit]], 1).astype(float)
    if len(pts) < 500:
        print("countryside: minimap not readable")
        return
    c = pts.mean(0)
    ev, evec = np.linalg.eigh(np.cov((pts - c).T))
    major, minor = evec[:, 1], evec[:, 0]
    half_w = np.percentile(np.abs((pts - c) @ minor), 97)
    for side, sgn in (("a", 1.0), ("b", -1.0)):
        for k, along in enumerate((-90.0, 0.0, 90.0)):
            q = c + major * along * w / 400.0 + minor * sgn * 0.85 * half_w
            driver.click(int(q[0]) + box[0], int(q[1]) + box[1])
            move(park)
            time.sleep(2.5)
            shot(os.path.join(out, "countryside_%s%d.png" % (side, k + 1)))
    print("countryside: 6 shots along both outer edges")


if __name__ == "__main__":
    main()
