"""Build an OpenAI image-edit mask: a PNG the size of the input image whose FULLY TRANSPARENT pixels are the area the
model may change (everything opaque is kept). Free, local, no harness call.

python make_mask.py IN.png MASK.png (--rect x0,y0,x1,y1 ...| --paint PAINT.png [--edit-white|--edit-black] |
                                      --key RRGGBB [--tol 24]) [--grow PX] [--feather PX] [--preview PREVIEW.png]
  --rect    editable rectangles in pixels of IN.png (repeatable), origin top-left
  --paint   a grey/BW image (any size, resized to IN): white = editable (default --edit-white) or black (--edit-black)
  --key     editable where IN.png has this colour (+- tol per channel), e.g. a placeholder colour painted into a
            layout picture ("fill the magenta areas with ...")
  --grow    dilate the editable area by PX pixels (lets the model blend into the surroundings)
  --feather soften the alpha border over PX pixels (OpenAI edits only where alpha == 0; partial alpha is kept)
  --preview IN with the editable area tinted magenta, to look at before paying
Prints the editable fraction. OpenAI applies the mask to the FIRST input image of an edit.
"""
import argparse

import numpy as np
from PIL import Image, ImageFilter


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('src'); ap.add_argument('dst')
    ap.add_argument('--rect', action='append', default=[]); ap.add_argument('--paint')
    g = ap.add_mutually_exclusive_group(); g.add_argument('--edit-white', action='store_true'); g.add_argument('--edit-black', action='store_true')
    ap.add_argument('--key'); ap.add_argument('--tol', type=int, default=24)
    ap.add_argument('--grow', type=int, default=0); ap.add_argument('--feather', type=int, default=0); ap.add_argument('--preview')
    a = ap.parse_args()
    src = Image.open(a.src).convert('RGB'); w, h = src.size
    edit = np.zeros((h, w), bool)
    for r in a.rect:
        x0, y0, x1, y1 = (int(v) for v in r.split(','))
        edit[max(0, min(y0, y1)):min(h, max(y0, y1)), max(0, min(x0, x1)):min(w, max(x0, x1))] = True
    if a.paint:
        p = np.asarray(Image.open(a.paint).convert('L').resize((w, h), Image.NEAREST)) > 127
        edit |= ~p if a.edit_black else p
    if a.key:
        c = np.array([int(a.key[i:i + 2], 16) for i in (0, 2, 4)])
        edit |= (np.abs(np.asarray(src).astype(int) - c) <= a.tol).all(-1)
    if not edit.any():
        raise SystemExit('ERROR: no editable pixel - give --rect, --paint or --key')
    m = Image.fromarray((edit * 255).astype(np.uint8))
    if a.grow:
        m = m.filter(ImageFilter.MaxFilter(2 * a.grow + 1))
    alpha = 255 - np.asarray(m)                                   # editable -> alpha 0
    if a.feather:
        soft = np.asarray(Image.fromarray(alpha.astype(np.uint8)).filter(ImageFilter.GaussianBlur(a.feather)))
        alpha = np.where(alpha == 0, 0, soft)                     # keep the core fully transparent
    out = np.dstack([np.asarray(src), alpha.astype(np.uint8)])
    Image.fromarray(out, 'RGBA').save(a.dst, 'PNG')
    frac = float((alpha == 0).mean())
    print(f'MASK {a.dst} {w}x{h} editable {frac:.1%}')
    if frac > .98:
        print('  note: almost everything is editable - an edit without --mask may be what you want')
    if a.preview:
        pv = np.asarray(src).astype(float); t = (alpha == 0)[..., None]
        Image.fromarray((pv * (1 - .55 * t) + np.array([255, 0, 255]) * .55 * t).astype(np.uint8)).save(a.preview)


if __name__ == '__main__':
    main()
