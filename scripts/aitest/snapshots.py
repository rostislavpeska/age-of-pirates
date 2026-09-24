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


if __name__ == "__main__":
    main()
