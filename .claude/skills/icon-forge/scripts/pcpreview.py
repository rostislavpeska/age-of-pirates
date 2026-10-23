"""Preview UI icons and portraits the way the game tints them: colour = stored RGB x lerp(player colour, 1, alpha),
drawn opaque (the transparent area does not show what lies behind it; owner's game test 2026-10-09). One row per
image, one column per player colour; the sheet goes to the scratchpad.

    python .claude/skills/icon-forge/scripts/pcpreview.py OUT.png IMAGE.png [IMAGE.png ...] [--size 192]
"""
import argparse

import numpy as np
from PIL import Image

COLOURS = ((45, 90, 230), (220, 40, 40), (240, 210, 40), (60, 170, 60))   # blue, red, yellow, green


def tint(im, colour):
    a = np.asarray(im.convert('RGBA'), dtype=np.float32) / 255
    pc = np.array(colour, np.float32) / 255
    rgb = a[..., :3] * (a[..., 3:] + (1 - a[..., 3:]) * pc)
    return Image.fromarray((rgb * 255).round().clip(0, 255).astype(np.uint8))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('out')
    ap.add_argument('images', nargs='+')
    ap.add_argument('--size', type=int, default=192)
    a = ap.parse_args()
    s = a.size
    sheet = Image.new('RGB', (s * len(COLOURS), s * len(a.images)), (20, 20, 20))
    for i, p in enumerate(a.images):
        im = Image.open(p)
        for j, c in enumerate(COLOURS):
            t = tint(im, c)
            t = t.resize((s, s), Image.NEAREST if im.size[0] <= 128 else Image.LANCZOS)
            sheet.paste(t, (j * s, i * s))
    sheet.save(a.out)
    print(a.out)


if __name__ == '__main__':
    main()
