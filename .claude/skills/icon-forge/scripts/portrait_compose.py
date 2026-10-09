"""Unit portrait (512) and icon (128) in the vanilla look from ONE generated image (owner 2026-10-09: "cheap repeatable
path"; the Korean Seungjang and Seungbyeong portraits).

Input: the unit on flat green (#00FF00, the Gemini route returns JPEG) or on a transparent background, with the area
that should take the player colour (sash, kasaya, emblem) painted flat magenta (#FF00FF).
Output, free and deterministic:
- green keyed out; the magenta area keyed by hue (generators shade it) and made transparent;
- under it, a light grey made from the magenta's own shading: the game MULTIPLIES the player colour into the RGB stored
  under a transparent pixel (pccheck.py), so black there shows a black sash;
- behind the figure the stock backdrop shared by the vanilla unit portraits (per-pixel median of every vanilla 512
  portrait whose corners carry it, smooth fill where figures cover it), cached in the temp folder, never in the repo;
- a halo along the silhouette measured on the vanilla Asian portraits (743 edges: +49 luminance at the outline,
  exponential fall-off 21 px at 512, warm grey).

    python .claude/skills/icon-forge/scripts/portrait_compose.py IN.(jpg|png) OUT_portrait.png [--icon OUT_icon.png]

Known difference to vanilla (owner: "for future"): generated figures carry a crisp light rim line; leave "crisp rim
light" out of the prompt.
"""
import argparse
import io
import os
import sys
import tempfile

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, gaussian_filter, label

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', '..', 'aoe3de-bar-archives', 'scripts'))
from pccheck import region_luma  # noqa: E402

SIZE = 512
LUMA = np.array([0.299, 0.587, 0.114], np.float32)
HALO_PEAK, HALO_TAU, HALO_TINT = 49.0, 21.0, np.array([1.0, 1.0, 0.84], np.float32)
STOCK = ((8, 8, (30, 30, 25)), (10, 256, (33, 33, 29)))          # (x, y, rgb) pixels every stock-backdrop portrait has
CACHE = os.path.join(tempfile.gettempdir(), 'aoe3_portrait_backdrop_v1.png')


def backdrop():
    """512x512 RGB float: the vanilla stock portrait backdrop (built once from the game archives, then cached)."""
    if os.path.isfile(CACHE):
        return np.asarray(Image.open(CACHE).convert('RGB'), np.float32)
    import bartool
    idx = bartool.build_index(bartool.find_game_dir())
    stack = []
    for p, e in idx.items():
        if not (p.startswith('data/wpfg/resources/art/units/') and p.endswith('portrait.png')):
            continue
        try:
            a = np.asarray(Image.open(io.BytesIO(bartool.read_entry(e))).convert('RGB'))
        except Exception:
            continue
        if a.shape[:2] == (SIZE, SIZE) and all(tuple(a[y, x]) == rgb for x, y, rgb in STOCK):
            stack.append(a)
    if len(stack) < 20:
        sys.exit('only %d stock-backdrop portraits found in the archives' % len(stack))
    s = np.stack(stack).astype(np.float32)
    med = np.median(s, 0)
    agree = (np.abs(s - med[None]).max(-1) <= 2).mean(0) > 0.5          # pixels where the portraits agree
    w = agree.astype(np.float32)
    out = med.copy()
    for sig in (8, 16, 32, 64, 128):                                      # fill the figure area from the edges
        den = gaussian_filter(w, sig)[..., None]
        fill = np.dstack([gaussian_filter(med[..., c] * w, sig) for c in range(3)]) / np.maximum(den, 1e-4)
        out = np.where(w[..., None] > 0, med, np.where(den > 0.02, fill, out))
    smooth = np.dstack([gaussian_filter(out[..., c], 40) for c in range(3)])
    edge = gaussian_filter(w, 12)[..., None]
    bd = med * w[..., None] + (smooth * (1 - edge) + med * edge) * (1 - w[..., None])
    Image.fromarray(bd.round().clip(0, 255).astype(np.uint8)).save(CACHE)
    return bd


def cut_out(im):
    """RGBA float 0..1 of the figure: alpha from the image's own alpha, or from greenness when it is opaque."""
    a = np.asarray(im.convert('RGBA'), np.float32) / 255
    if a[..., 3].min() > 0.99:                                            # opaque: green screen
        r, g, b = a[..., 0], a[..., 1], a[..., 2]
        green = np.clip((g - np.maximum(r, b) - 40 / 255) / (60 / 255), 0, 1)
        a[..., 3] = gaussian_filter(1 - green, 0.7)
        spill = g > np.maximum(r, b)
        a[..., 1] = np.where(spill, np.maximum(r, b) + (g - np.maximum(r, b)) * 0.15, g)
    return a


def magenta(rgb):
    """0..1 mask of the flat-magenta player-colour area (hue 285-350, saturated), specks dropped."""
    hsv = np.asarray(Image.fromarray((rgb * 255).astype(np.uint8)).convert('HSV'), np.float32) / 255
    hue, sat, val = hsv[..., 0] * 360, hsv[..., 1], hsv[..., 2]
    m = np.clip(np.minimum((hue - 285) / 10, (350 - hue) / 10), 0, 1) * np.clip((sat - .35) / .15, 0, 1) \
        * np.clip((val - .2) / .1, 0, 1)
    m = gaussian_filter(np.maximum(m, np.pad(m, 1, mode='edge')[2:, 1:-1]), 1)
    lab, n = label(m > 0.5)
    sizes = np.bincount(lab.ravel())
    m[np.isin(lab, [i for i in range(1, n + 1) if sizes[i] < 0.002 * m.size])] = 0
    return np.clip(m, 0, 1)


def compose(src, glow=1.0):
    im = Image.open(src)
    if im.size != (SIZE, SIZE):
        im = im.convert('RGBA').resize((SIZE, SIZE), Image.LANCZOS) if im.mode == 'RGBA' else \
            im.convert('RGB').resize((SIZE, SIZE), Image.LANCZOS)
    f = cut_out(im)
    mag = magenta(f[..., :3])
    hole, rim = mag > 0.5, mag > 0.02
    if hole.sum() < 0.005 * hole.size:
        sys.exit('no magenta player-colour area found: paint it flat #FF00FF in the prompt')
    lum = f[..., :3] @ LUMA * 255
    p5, p95 = np.percentile(lum[hole], [5, 95])
    grey = (150 + 95 * np.clip((lum - p5) / max(p95 - p5, 1), 0, 1)) / 255
    rgb = np.where(rim[..., None], grey[..., None], f[..., :3])
    fa = f[..., 3]
    d = distance_transform_edt(fa < 0.5)
    halo = glow * HALO_PEAK * np.exp(-np.maximum(d - 1, 0) / HALO_TAU)
    bg = (backdrop() + halo[..., None] * HALO_TINT / HALO_TINT.mean()) / 255
    figure_a = fa * (1 - mag)                                             # the figure without its magenta area
    out_rgb = np.where(rim[..., None], rgb, rgb * figure_a[..., None] + bg * (1 - figure_a[..., None]))
    out_a = np.where(hole, 1 - mag, 1.0)
    out_a = np.where(rim & ~hole, np.minimum(1.0, 1 - mag + (1 - fa)), out_a)
    return Image.fromarray((np.dstack([out_rgb, out_a]) * 255).round().clip(0, 255).astype(np.uint8))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('src')
    ap.add_argument('out')
    ap.add_argument('--icon', help='also write the 128 unit icon (iconforge --kind unit --full)')
    ap.add_argument('--glow', type=float, default=1.0)
    a = ap.parse_args()
    compose(a.src, a.glow).save(a.out)
    med, n = region_luma(a.out)
    print('%s: player-colour area %d px, stored luminance %.0f' % (a.out, n, med))
    if a.icon:
        import iconforge
        iconforge.main([a.out, a.icon, '--kind', 'unit', '--full'])
        print('%s: stored luminance %.0f' % (a.icon, region_luma(a.icon)[0]))
    return 0


if __name__ == '__main__':
    sys.exit(main())
