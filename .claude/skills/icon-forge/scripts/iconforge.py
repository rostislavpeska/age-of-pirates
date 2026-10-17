#!/usr/bin/env python3
"""Composite artwork into an Age of Empires III icon border, or crop a portrait.

    python iconforge.py <art.png> <out.png> [options]

      --kind tech|unit|ability|building|team|big|portrait|politician   (default tech)
      --full            art fills the canvas and the border overlays it, hiding
                        any frame already painted into the art
      --inset 0.06      trim a fraction off each edge of the source first
      --fit cover|contain                                   (default cover)
      --size N          output size; portraits default to 512
                        (politician = 512x1024 card portrait, no border)
      --cut X,Y[,W]     politician only: cut a W x 2W window (default 512x1024, i.e.
                        native scale) with its top-left at X,Y and scale it to the
                        card; W < 512 zooms in - use it to match head sizes across a set
      --disabled        also write <out>_disabled.png

Borders ship alongside this script in ../borders, so nothing depends on a local
OneDrive path. All five square borders share one window, so a single geometry
covers tech / unit / ability / building / team_tech; big is the only different
one, portrait uses no border at all, and politician is the 512x1024 (1:2) card
portrait every entry in data/politicianmods.xml uses - no border, RGB, the
source is cover-cropped to 1:2 (a 2:3 generation loses its outer sides).

    128x128 borders    window (14,18)-(115,114)  ->  101x96
    big_border 270x410 window (34,36)-(239,377)  ->  205x341

The square window is NOT centred -- 14px left, 18px top, 13px right, 14px bottom
-- so art centred naively sits ~2px high, and at 101x96 it is not square either,
so a square source must be cropped or letterboxed rather than just scaled. Both
are handled here; the numbers are measured from the border at run time rather
than hardcoded, so replacing a border file stays safe.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
BORDERS = os.path.join(HERE, '..', 'borders')
NAMES = {'tech': 'tech_border.png', 'unit': 'unit_border.png',
         'ability': 'ability_border.png', 'building': 'building_border.png',
         'team': 'team_tech.png', 'big': 'big_border.png'}
PORTRAIT_DEFAULT = 512
POLITICIAN_SIZE = (512, 1024)


def window(border):
    """Transparent inner box of a border, measured rather than hardcoded."""
    a = border.split()[3]
    box = a.point(lambda v: 255 if v < 16 else 0).getbbox()
    if box is None:
        sys.exit('border has no transparent window')
    return box


def resize_keep_rgb(im, size):
    """Resize RGBA without premultiplying: Pillow's RGBA resize writes RGB (0,0,0) under every alpha-0 pixel, and the
    game multiplies the player colour into that RGB, so a transparent player-colour area turns black in game
    (pccheck.py; Korean monk portraits 2026-10-09). RGB and alpha are resized separately."""
    if im.size == tuple(size):
        return im.copy()
    rgb = im.convert('RGB').resize(size, Image.LANCZOS)
    rgb.putalpha(im.getchannel('A').resize(size, Image.LANCZOS))
    return rgb


def composite_keep_rgb(base, over):
    """base.alpha_composite(over) that keeps base's RGB where the result stays transparent (Pillow writes black)."""
    b = np.asarray(base, dtype=np.float32) / 255
    o = np.asarray(over, dtype=np.float32) / 255
    ba, oa = b[..., 3:], o[..., 3:]
    out_a = oa + ba * (1 - oa)
    blend = (o[..., :3] * oa + b[..., :3] * ba * (1 - oa)) / np.maximum(out_a, 1e-6)
    rgb = np.where(out_a > 1e-6, blend, b[..., :3])
    rgb = np.where(oa > 1e-6, rgb, b[..., :3])           # nothing on top: the art's own colour, unchanged
    return Image.fromarray((np.concatenate([rgb, out_a], -1) * 255 + 0.5).clip(0, 255).astype(np.uint8))


def fit(art, size, mode):
    tw, th = size
    if mode == 'contain':
        out = Image.new('RGBA', size, (0, 0, 0, 0))
        s = min(tw / art.width, th / art.height, 1)
        c = resize_keep_rgb(art, (max(1, round(art.width * s)), max(1, round(art.height * s))))
        out.paste(c, ((tw - c.width) // 2, (th - c.height) // 2))
        return out
    # cover: scale so the shorter axis fills, then centre-crop the overflow
    s = max(tw / art.width, th / art.height)
    r = resize_keep_rgb(art, (max(1, round(art.width * s)), max(1, round(art.height * s))))
    return r.crop(((r.width - tw) // 2, (r.height - th) // 2,
                   (r.width - tw) // 2 + tw, (r.height - th) // 2 + th))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('art')
    ap.add_argument('out')
    ap.add_argument('--kind', default='tech',
                    choices=sorted(NAMES) + ['portrait', 'politician'])
    ap.add_argument('--inset', type=float, default=0.0)
    ap.add_argument('--fit', default='cover', choices=('cover', 'contain'))
    ap.add_argument('--full', action='store_true')
    ap.add_argument('--size', type=int, default=0,
                    help='output size; portraits default to 512, bordered kinds '
                         'default to the border resolution')
    ap.add_argument('--disabled', action='store_true')
    ap.add_argument('--cut', default='', help='politician: X,Y of a native-scale 512x1024 window')
    a = ap.parse_args(argv)

    art = Image.open(a.art).convert('RGBA')
    if a.inset:
        w, h = art.size
        dx, dy = round(w * a.inset), round(h * a.inset)
        art = art.crop((dx, dy, w - dx, h - dy))

    if a.kind == 'politician':
        w, h = POLITICIAN_SIZE
        if a.size:
            w, h = a.size, a.size * 2
        if a.cut:
            parts = [int(v) for v in a.cut.split(',')]
            x, y = parts[0], parts[1]
            cw = parts[2] if len(parts) > 2 else w          # window width; height is always 2x (the card is 1:2)
            ch = cw * 2
            if x < 0 or y < 0 or x + cw > art.width or y + ch > art.height:
                sys.exit(f'--cut window {cw}x{ch} at ({x},{y}) leaves the {art.width}x{art.height} source')
            canvas = art.crop((x, y, x + cw, y + ch)).convert('RGB')
            if (cw, ch) != (w, h):
                canvas = canvas.resize((w, h), Image.LANCZOS)
            canvas.save(a.out)
            print(f'{a.out}  {w}x{h}  politician card portrait (no border, RGB)  cut {cw}x{ch} at ({x},{y}) -> scale x{w / cw:.2f}')
            return 0
        canvas = fit(art, (w, h), a.fit).convert('RGB')
        canvas.save(a.out)
        print(f'{a.out}  {w}x{h}  politician card portrait (no border, RGB)  fit={a.fit} inset={a.inset}')
        return 0

    if a.kind == 'portrait':
        n = a.size or PORTRAIT_DEFAULT
        canvas = fit(art, (n, n), a.fit)
        canvas.save(a.out)
        print(f'{a.out}  {n}x{n}  portrait (no border)  fit={a.fit} inset={a.inset}')
        return 0

    border = Image.open(os.path.join(BORDERS, NAMES[a.kind])).convert('RGBA')
    l, t, r, b = window(border)
    canvas = Image.new('RGBA', border.size, (0, 0, 0, 0))
    if a.full:
        canvas.paste(fit(art, border.size, a.fit), (0, 0))
    else:
        canvas.paste(fit(art, (r - l, b - t), a.fit), (l, t))
    canvas = composite_keep_rgb(canvas, border)

    if a.size and a.size != canvas.width:
        # scale the finished composite so the border stays proportional
        canvas = resize_keep_rgb(canvas, (a.size, round(canvas.height * a.size / canvas.width)))
    canvas.save(a.out)
    print(f'{a.out}  {canvas.size[0]}x{canvas.size[1]}  border={NAMES[a.kind]}  '
          f'window={r - l}x{b - t} at ({l},{t})  fit={a.fit} '
          f'inset={a.inset} full={a.full}')

    if a.disabled:
        ov = Image.open(os.path.join(BORDERS, 'disabled_overlay.png')).convert('RGBA')
        d = canvas.copy()
        if ov.size != d.size:
            ov = ov.resize(d.size, Image.LANCZOS)
        d.alpha_composite(ov)
        p = os.path.splitext(a.out)[0] + '_disabled.png'
        d.save(p)
        print(f'{p}  (disabled variant)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
