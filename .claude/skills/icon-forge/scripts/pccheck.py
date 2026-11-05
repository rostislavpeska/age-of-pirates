"""Player-colour check for UI icons and portraits (AoE III DE).

The game does NOT show the player colour through a transparent pixel: it multiplies the player colour into the RGB
stored under it (vanilla monk sashes keep a light grey shading there, luminance median 109-232; owner's game test
2026-10-09: the Korean portraits stored (21,1,21) and (0,0,0) there and showed a near-black sash). Many tools write
black RGB under alpha 0 (Photoshop export, Pillow resizing, a premultiplied composite), which is why the same art
"sometimes works".

Checks every transparent region (alpha < 128) that holds no corner of the image (background transparency of rounded
or free-form icons does): the median luminance of the RGB stored there must be at least --min (default 60).
Calibration, 1492 vanilla icons and portraits with such a region: median 131; 122 vanilla files (8%, e.g. the
Wayward Ronin icon, the Barbary Corsair portrait) are below 60 and show the same dark area in game.

    python .claude/skills/icon-forge/scripts/pccheck.py FILE_OR_DIR [...] [--min 60] [--list-ok]

Exit 1 when any image has a dark player-colour region. Fix: icon-forge `pcfix.py` (or repaint the region light grey).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image
from scipy.ndimage import find_objects, label

LUMA = np.array([0.299, 0.587, 0.114])


def player_area(holes):
    """Transparent components that are not background: background transparency (rounded or free-form icons) holds a
    corner of the image; a sash that runs off one edge (most vanilla monk portraits) does not."""
    lab, n = label(holes)
    skip = {lab[0, 0], lab[0, -1], lab[-1, 0], lab[-1, -1]} - {0}
    h, w = holes.shape
    for i, sl in enumerate(find_objects(lab), 1):
        if sl is None:
            continue
        bh, bw = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        area = (lab[sl] == i).sum()
        size = min(h, w)
        ring = bh > 0.8 * h and bw > 0.8 * w and area < 0.1 * bh * bw
        strip = min(bh, bw) <= max(3, 0.035 * size) and max(bh, bw) >= 0.5 * size
        if ring or strip or area < 0.0015 * size * size:
            skip.add(i)          # the gap between art and frame (iconforge, 3 px strips) or specks: it reads as the
                                 # frame's bevel; painting it light would draw a player-colour line round the art
    return holes & ~np.isin(lab, list(skip))


def region_luma(path):
    """(median luminance of the RGB under the enclosed player-colour region, its pixel count), or None."""
    a = np.array(Image.open(path).convert('RGBA')).astype(np.float32)
    holes = a[..., 3] < 128
    inner = player_area(holes)
    if inner.sum() < 0.005 * holes.size:
        return None
    return float(np.median(a[inner][:, :3] @ LUMA)), int(inner.sum())


def files(args):
    for p in args:
        if os.path.isdir(p):
            for d, _, fs in os.walk(p):
                for f in fs:
                    if f.lower().endswith('.png'):
                        yield os.path.join(d, f)
        else:
            yield p


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('paths', nargs='+')
    ap.add_argument('--min', type=float, default=60)
    ap.add_argument('--list-ok', action='store_true')
    a = ap.parse_args()
    dark, ok = [], []
    for p in sorted(files(a.paths)):
        try:
            r = region_luma(p)
        except Exception as e:
            print('SKIP  %s (%s)' % (p, e))
            continue
        if r is None:
            continue
        (dark if r[0] < a.min else ok).append((r[0], r[1], p.replace(chr(92), '/')))
    for med, n, p in dark:
        print('DARK  luminance %5.0f  %7d px  %s' % (med, n, p))
    if a.list_ok:
        for med, n, p in ok:
            print('ok    luminance %5.0f  %7d px  %s' % (med, n, p))
    print('%d image(s) with a player-colour region: %d dark, %d fine' % (len(dark) + len(ok), len(dark), len(ok)))
    return 1 if dark else 0


if __name__ == '__main__':
    sys.exit(main())
