#!/usr/bin/env python
"""Pixel grid overlay for picking joint centres by eye on a render or a generated image.

    python grid.py IN.png OUT.png [--step 50] [--crop X0,Y0,X1,Y1] [--zoom 2] [--background 205,205,205]

Composites a transparent render on a flat grey, draws a line every --step pixels (red every second line, blue in
between) and labels the lines with the SOURCE image's pixel coordinates, also inside a crop and after a zoom, so a
point read off the grid is directly a pick for pose_angles.py. Host Python with Pillow; no Blender. OUT must lie
outside every git work tree; relative paths are made absolute. Exit 0 = written, 2 = setup error.
"""
import argparse
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE), str(HERE.parents[1] / 'blender-organic-modeling' / 'scripts')]
try:
    import blender_env as E  # noqa: E402
except ImportError:
    sys.exit('SETUP ERROR: companion skill blender-organic-modeling (scripts/blender_env.py) not found')


def build_parser():
    ap = argparse.ArgumentParser(prog='grid.py', description=__doc__.splitlines()[0])
    ap.add_argument('src', help='input image (PNG/JPEG/WEBP; alpha is composited on the background)')
    ap.add_argument('dst', help='output image, outside any git work tree')
    ap.add_argument('--step', type=int, default=50, help='grid spacing in source pixels (default 50)')
    ap.add_argument('--crop', help='X0,Y0,X1,Y1 in source pixels (default: whole image)')
    ap.add_argument('--zoom', type=float, default=1.0, help='scale factor after cropping (default 1)')
    ap.add_argument('--background', default='205,205,205', help='R,G,B behind transparent pixels')
    return ap


def first_line(start, step):
    """First multiple of step at or after start."""
    return -(-start // step) * step


def make_grid(src, step=50, crop=None, zoom=1.0, background=(205, 205, 205)):
    from PIL import Image, ImageDraw
    im = Image.open(src).convert('RGBA')
    bg = Image.new('RGBA', im.size, tuple(background) + (255,))
    bg.alpha_composite(im)
    im = bg.convert('RGB')
    x0, y0, x1, y1 = crop or (0, 0, im.width, im.height)
    if not (0 <= x0 < x1 <= im.width and 0 <= y0 < y1 <= im.height):
        raise ValueError('crop %s outside the %dx%d image' % ((x0, y0, x1, y1), im.width, im.height))
    im = im.crop((x0, y0, x1, y1))
    if zoom != 1.0:
        im = im.resize((max(1, round(im.width * zoom)), max(1, round(im.height * zoom))), Image.LANCZOS)
    d = ImageDraw.Draw(im)
    for gx in range(first_line(x0, step), x1, step):
        X = (gx - x0) * zoom
        d.line([(X, 0), (X, im.height)], fill=(255, 0, 0) if gx % (2 * step) == 0 else (0, 140, 255), width=1)
        d.text((X + 2, 2), str(gx), fill=(255, 0, 0))
    for gy in range(first_line(y0, step), y1, step):
        Y = (gy - y0) * zoom
        d.line([(0, Y), (im.width, Y)], fill=(255, 0, 0) if gy % (2 * step) == 0 else (0, 140, 255), width=1)
        d.text((2, Y + 2), str(gy), fill=(255, 0, 0))
    return im


def main(argv=None):
    try:
        a = build_parser().parse_args(argv)
    except SystemExit as exc:
        return 2 if exc.code else 0
    try:
        crop = tuple(int(v) for v in a.crop.split(',')) if a.crop else None
        bgc = tuple(int(v) for v in a.background.split(','))
        if (crop and len(crop) != 4) or len(bgc) != 3 or a.step < 2 or a.zoom <= 0:
            raise ValueError('--crop needs 4 integers, --background 3, --step >= 2, --zoom > 0')
    except ValueError as exc:
        print('SETUP ERROR: %s' % exc, file=sys.stderr)
        return 2
    dst = os.path.abspath(a.dst)
    err = E.refuse_in_worktree(dst, 'output')
    if err:
        print('SETUP ERROR: ' + err, file=sys.stderr)
        return 2
    if not os.path.isfile(a.src):
        print('SETUP ERROR: input not found: %s' % a.src, file=sys.stderr)
        return 2
    try:
        im = make_grid(a.src, a.step, crop, a.zoom, bgc)
    except (OSError, ValueError) as exc:
        print('SETUP ERROR: %s' % exc, file=sys.stderr)
        return 2
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst)
    print('GRID %s %dx%d' % (dst, im.width, im.height))
    return 0


if __name__ == '__main__':
    sys.exit(main())
