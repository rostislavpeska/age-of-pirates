#!/usr/bin/env python
"""Review a set of bordered icons the way a player sees them (references/visual-language.md, section 5).

    python .claude/skills/icon-forge/scripts/iconsheet.py OUT.png icon.png [icon.png ...] [--max-share 0.8]

Lays the icons out at 128 and at 64 px (the size where one shape has to carry each icon), names each icon's
dominant colour inside the border window and prints a table. Exit 1 when one dominant colour covers more than
--max-share of the set: nearly the whole set in one colour (calibrated 2026-10-09: amber dominates 150 of 281
vanilla Asian tech icons and 5 of the owner's 9 "really good" Parliament icons - fine; the rejected first Korean
monastery set was 4 of 4 amber; at 0.8 about 5% of random vanilla 5-icon panels warn, at 0.6 23%). Colour is the only thing it measures: whether the set looks like
AoE (form and rendering) is judged by eye on the sheet. Pass the new icons together with their in-game neighbours
(vanilla icons extracted into the scratchpad, the mod's own icons) so the set is judged as the panel shows it. Write
OUT into the session scratchpad, never into the repo. Needs Pillow.
"""
import argparse
import colorsys
import os
import sys
from collections import Counter

from PIL import Image, ImageDraw

WINDOW = (14, 18, 115, 114)            # the 128-px border window of tech/unit/ability/building/team icons
HUES = [(15, 'red'), (45, 'amber'), (70, 'yellow'), (150, 'green'), (195, 'teal'), (255, 'blue'), (300, 'purple'),
        (345, 'magenta'), (361, 'red')]


def dominant(path):
    """(name, share, second) inside the border window, 128-px geometry: the hue family that most chromatic pixels
    fall in (a cast, a field or a big object), or 'dark' when under a quarter of the pixels carry colour."""
    im = Image.open(path).convert('RGB').resize((128, 128), Image.LANCZOS).crop(WINDOW).resize((48, 46))
    count, n = Counter(), 0
    for rgb in im.getdata():
        h, s, v = colorsys.rgb_to_hsv(*(c / 255.0 for c in rgb))
        n += 1
        if s >= 0.25 and v >= 0.12:
            count[next(name for top, name in HUES if h * 360 < top)] += 1
    total = sum(count.values())
    if total < n / 4:
        return 'dark', 1 - total / n, (count.most_common(1) or [('-', 0)])[0][0]
    (first, k), *rest = count.most_common(2) + [('-', 0)]
    return first, k / total, rest[0][0]


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('out')
    ap.add_argument('icons', nargs='+')
    ap.add_argument('--max-share', type=float, default=0.8,
                    help='warn when one dominant colour covers more of the set than this (default 0.8)')
    a = ap.parse_args()
    rows = [(p, *dominant(p)) for p in a.icons]
    n = len(rows)
    pad, label = 8, 30
    w = pad + n * (128 + pad)
    sheet = Image.new('RGB', (w, pad + 128 + label + 64 + label), (34, 34, 34))
    d = ImageDraw.Draw(sheet)
    for i, (p, name, share, _second) in enumerate(rows):
        icon = Image.open(p).convert('RGBA')
        x = pad + i * (128 + pad)
        sheet.paste(icon.resize((128, 128), Image.LANCZOS), (x, pad), icon.resize((128, 128), Image.LANCZOS))
        d.text((x, pad + 130), os.path.splitext(os.path.basename(p))[0][:21], fill=(220, 220, 220))
        d.text((x, pad + 142), '%s %d%%' % (name, round(share * 100)), fill=(170, 200, 255))
        small = icon.resize((64, 64), Image.LANCZOS)
        sheet.paste(small, (x + 32, pad + 128 + label), small)
    sheet.save(a.out)
    print('%-34s %-8s %5s  %s' % ('icon', 'dominant', 'share', 'second'))
    for p, name, share, second in rows:
        print('%-34s %-8s %4d%%  %s' % (os.path.basename(p)[:34], name, round(share * 100), second))
    over = {k: v for k, v in Counter(r[1] for r in rows).items() if len(rows) >= 3 and v / len(rows) > a.max_share}
    print('sheet:', a.out)
    if over:
        print('MIX WARNING: one colour dominates %s of %d icons (limit %d%%)' % (over, len(rows), a.max_share * 100))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
