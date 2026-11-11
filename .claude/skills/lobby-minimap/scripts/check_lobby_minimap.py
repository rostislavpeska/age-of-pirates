"""Check a composed pair before the owner sees it.

    python check_lobby_minimap.py DIR NAME DISC.png --border gold|silver

  - both files 512 x 512 RGBA;
  - the ring and its shadow (r >= 228, above the ribbon box) equal a finished map with the same border
    (gold: elbe_mini.png, silver: london_mini2.png): mean difference < 1 level, no pixel off by more than 8;
  - no hole: alpha 255 everywhere inside r < 238;
  - nothing of the template's old map shows: inside r < 225 (outside the ribbon box) the output equals the disc;
  - <name>_mini differs from <name>_mini2 only inside the ribbon box.
Exit 1 on any failure."""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[4]
REF = REPO / 'data' / 'wpfg' / 'resources' / 'images' / 'icons' / 'random_map'
RING_REF = {'gold': REF / 'elbe' / 'elbe_mini.png', 'silver': REF / 'london' / 'london_mini2.png'}
RIBBON_BOX = (slice(415, 512), slice(20, 492))


def load(p):
    im = Image.open(p)
    return im.size, im.mode, np.asarray(im.convert('RGBA')).astype(float)


def seen(a):
    return np.dstack([a[:, :, :3] * a[:, :, 3:4] / 255.0, a[:, :, 3]])


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument('dir')
    ap.add_argument('name')
    ap.add_argument('disc')
    ap.add_argument('--border', choices=sorted(RING_REF), required=True)
    o = ap.parse_args(argv)
    d = Path(o.dir)
    fails = []
    s1, m1, mini = load(d / f'{o.name}_mini.png')
    s2, m2, mini2 = load(d / f'{o.name}_mini2.png')
    _, _, disc = load(o.disc)
    _, _, ref = load(RING_REF[o.border])
    for n, s, m in ((f'{o.name}_mini.png', s1, m1), (f'{o.name}_mini2.png', s2, m2)):
        if s != (512, 512) or m != 'RGBA':
            fails.append(f'{n}: {s} {m}, want (512, 512) RGBA')
    yy, xx = np.mgrid[0:512, 0:512]
    rr = np.hypot(xx + 0.5 - 256, yy + 0.5 - 256)
    box = np.zeros((512, 512), bool)
    box[RIBBON_BOX] = True
    ring = (rr >= 228) & ~box
    e = np.abs(seen(mini2) - seen(ref)).max(axis=2)[ring]
    print(f'ring vs {RING_REF[o.border].name}: mean {e.mean():.2f}, max {e.max():.0f}, > 8 levels {(e > 8).sum()}')
    if e.mean() >= 1.0 or (e > 8).sum():
        fails.append('the ring differs from the reference border')
    hole = mini2[:, :, 3][rr < 238].min()
    print('alpha min inside r < 238:', hole)
    if hole < 255:
        fails.append('a hole in the image')
    inner = (rr < 225) & ~box
    e = np.abs(seen(mini2) - seen(disc)).max(axis=2)[inner]
    print(f'inside r < 225 vs the disc: max {e.max():.0f}, > 2 levels {(e > 2).sum()}')
    if (e > 2).sum():
        fails.append('the output differs from the disc inside the circle (old map showing, or the disc moved)')
    e = np.abs(seen(mini) - seen(mini2)).max(axis=2)
    outside_box = (e > 2) & ~box
    print('mini vs mini2 outside the ribbon box: differing pixels', int(outside_box.sum()))
    if outside_box.sum():
        fails.append('mini and mini2 differ outside the ribbon box')
    for f in fails:
        print('FAIL:', f)
    print('OK' if not fails else f'{len(fails)} failure(s)')
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
