#!/usr/bin/env python3
"""Composite artwork into an Age of Empires III icon border, or crop a portrait.

    python iconforge.py <art.png> <out.png> [options]

      --kind tech|unit|ability|building|team|big|portrait   (default tech)
      --full            art fills the canvas and the border overlays it, hiding
                        any frame already painted into the art
      --inset 0.06      trim a fraction off each edge of the source first
      --fit cover|contain                                   (default cover)
      --size N          output size; portraits default to 512
      --disabled        also write <out>_disabled.png

Borders ship alongside this script in ../borders, so nothing depends on a local
OneDrive path. All five square borders share one window, so a single geometry
covers tech / unit / ability / building / team_tech; big is the only different
one, and portrait uses no border at all.

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

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
BORDERS = os.path.join(HERE, '..', 'borders')
NAMES = {'tech': 'tech_border.png', 'unit': 'unit_border.png',
         'ability': 'ability_border.png', 'building': 'building_border.png',
         'team': 'team_tech.png', 'big': 'big_border.png'}
PORTRAIT_DEFAULT = 512


def window(border):
    """Transparent inner box of a border, measured rather than hardcoded."""
    a = border.split()[3]
    box = a.point(lambda v: 255 if v < 16 else 0).getbbox()
    if box is None:
        sys.exit('border has no transparent window')
    return box


def fit(art, size, mode):
    tw, th = size
    if mode == 'contain':
        out = Image.new('RGBA', size, (0, 0, 0, 0))
        c = art.copy()
        c.thumbnail(size, Image.LANCZOS)
        out.paste(c, ((tw - c.width) // 2, (th - c.height) // 2))
        return out
    # cover: scale so the shorter axis fills, then centre-crop the overflow
    s = max(tw / art.width, th / art.height)
    r = art.resize((max(1, round(art.width * s)), max(1, round(art.height * s))),
                   Image.LANCZOS)
    return r.crop(((r.width - tw) // 2, (r.height - th) // 2,
                   (r.width - tw) // 2 + tw, (r.height - th) // 2 + th))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('art')
    ap.add_argument('out')
    ap.add_argument('--kind', default='tech',
                    choices=sorted(NAMES) + ['portrait'])
    ap.add_argument('--inset', type=float, default=0.0)
    ap.add_argument('--fit', default='cover', choices=('cover', 'contain'))
    ap.add_argument('--full', action='store_true')
    ap.add_argument('--size', type=int, default=0,
                    help='output size; portraits default to 512, bordered kinds '
                         'default to the border resolution')
    ap.add_argument('--disabled', action='store_true')
    a = ap.parse_args(argv)

    art = Image.open(a.art).convert('RGBA')
    if a.inset:
        w, h = art.size
        dx, dy = round(w * a.inset), round(h * a.inset)
        art = art.crop((dx, dy, w - dx, h - dy))

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
    canvas.alpha_composite(border)

    if a.size and a.size != canvas.width:
        # scale the finished composite so the border stays proportional
        canvas = canvas.resize(
            (a.size, round(canvas.height * a.size / canvas.width)), Image.LANCZOS)
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
