"""Make a generated texture tile seamlessly (post-edit for GPT / photo sources).

python make_seamless.py IN.png OUT.png [--feather 0.18] [--flatten 0.12] [--preview PREVIEW.png]
1. flatten: divide by a large blur (radius = flatten x size) and restore the mean - removes the lighting
   drift that makes a repeat visible; 0 disables.
2. offset by half a tile in x and y, so the original borders meet in the centre and the new borders are
   continuous; blend the original back over a feathered centre cross (width = feather x size), hiding the
   seam cross. The borders of the result are exactly the offset image: the tile wraps without a seam.
3. --preview writes a 2x2 repeat for a visual check.
"""
import argparse

import numpy as np
from PIL import Image, ImageFilter


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('src'); ap.add_argument('dst')
    ap.add_argument('--feather', type=float, default=0.18); ap.add_argument('--flatten', type=float, default=0.12)
    ap.add_argument('--preview'); a = ap.parse_args()
    im = Image.open(a.src).convert('RGB'); w, h = im.size
    img = np.asarray(im, np.float32) / 255
    if a.flatten > 0:
        big = np.asarray(Image.fromarray((img * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(a.flatten * w)), np.float32) / 255
        img = np.clip(img / np.maximum(big, 1e-3) * img.mean(axis=(0, 1)), 0, 1)
    off = np.roll(np.roll(img, h // 2, 0), w // 2, 1)
    y, x = np.mgrid[0:h, 0:w]
    fx = np.clip(1 - np.abs(x - w / 2) / (a.feather * w), 0, 1); fy = np.clip(1 - np.abs(y - h / 2) / (a.feather * h), 0, 1)
    m = np.maximum(fx, fy); m = (m * m * (3 - 2 * m))[..., None]
    out = off * (1 - m) + img * m
    Image.fromarray((np.clip(out, 0, 1) * 255 + .5).astype(np.uint8)).save(a.dst)
    edge = float(np.abs(out[:, 0] - out[:, -1]).mean() + np.abs(out[0] - out[-1]).mean())
    print('SEAMLESS', a.dst, 'wrap edge difference', round(edge, 4))
    if a.preview:
        t = np.tile(out, (2, 2, 1)); Image.fromarray((np.clip(t, 0, 1) * 255 + .5).astype(np.uint8)).resize((w, h)).save(a.preview)


if __name__ == '__main__':
    main()
