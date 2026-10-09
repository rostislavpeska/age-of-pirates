"""Repair a dark player-colour area in a UI icon or portrait (AoE III DE).

The game multiplies the player colour into the RGB stored under a transparent pixel (pccheck.py). This rewrites that
RGB, inside the player-colour region only (alpha below 250 holding no image corner, plus a 1 px rim), as
a light grey: the stored luminance rescaled to 150..245 when it still carries the cloth's folds, else a flat 205
(vanilla monk sashes: medians 109-232). Alpha is never changed, so the shape and the coverage stay as painted.

    python .claude/skills/icon-forge/scripts/pcfix.py IN.png [IN.png ...] [--out-dir DIR] [--dry-run]

Without --out-dir the file is rewritten in place (the image is fully computed and checked before writing).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pccheck import LUMA, player_area, region_luma  # noqa: E402

LO, HI, FLAT, TARGET = 150.0, 245.0, 205.0, 150.0


def region(alpha):
    """The area pccheck.py judges (alpha < 128, no image corner, no frame strip) plus its soft rim: the partially
    transparent pixels up to 2 px around it. Bohemian knight 2026-10-09: an alpha < 250 search joined the area to a
    corner through soft pixels and left it dark."""
    inner = player_area(alpha < 128)
    return binary_dilation(inner, iterations=2) & (alpha < 255) | inner


def fix(path):
    im = Image.open(path).convert('RGBA')
    a = np.array(im).astype(np.float32)
    m = region(a[..., 3])
    if not m.any():
        return None, 'no enclosed transparent region'
    lum = a[..., :3] @ LUMA
    vals = lum[m]
    p5, p95 = np.percentile(vals, [5, 95])
    med = float(np.median(vals))
    if med >= 40:                                         # a deep but real shading: scale it, keep its contrast
        grey = np.clip(lum * TARGET / med, 0, 250)        # (a stretch to 150..245 turned the Janissary's coat grain
        how = 'shading scaled x%.2f (median %.0f -> %.0f)' % (TARGET / med, med, TARGET)   # into white blotches)
    elif p95 - p5 > 12 and p95 > 25:                      # faint folds still stored: lift them to light grey
        grey = LO + (HI - LO) * np.clip((lum - p5) / (p95 - p5), 0, 1)
        how = 'folds kept (luminance %.0f..%.0f -> %.0f..%.0f)' % (p5, p95, LO, HI)
    else:
        grey = np.full(lum.shape, FLAT)
        how = 'flat grey %.0f (nothing stored)' % FLAT
    out = a.copy()
    for c in range(3):
        out[..., c] = np.where(m, grey, a[..., c])
    res = Image.fromarray(out.round().clip(0, 255).astype(np.uint8))
    assert (np.array(res)[..., 3] == np.array(im)[..., 3]).all()   # alpha untouched
    return res, how


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('paths', nargs='+')
    ap.add_argument('--out-dir')
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()
    for p in a.paths:
        before = region_luma(p)
        res, how = fix(p)
        if res is None:
            print('SKIP  %s: %s' % (p, how))
            continue
        q = os.path.join(a.out_dir, os.path.basename(p)) if a.out_dir else p
        if not a.dry_run:
            res.save(q)
        after = region_luma(q) if not a.dry_run else None
        print('%s %s: luminance %s -> %s, %s' % ('WOULD' if a.dry_run else 'FIXED', q.replace(chr(92), '/'),
              '%.0f' % before[0] if before else '-', '%.0f' % after[0] if after else '-', how))
    return 0


if __name__ == '__main__':
    sys.exit(main())
