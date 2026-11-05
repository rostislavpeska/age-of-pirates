"""Read an AoE3DE .ddt (RTS3 container, format 4 = DXT1) back into a Pillow image - the inverse of
scripts/havok/ddt_dxt1.py, top mip only. Used to derive the UI flag PNGs (civ flag icon, post-game banner,
home-city button) from a flag texture so a flag-override civ needs no hand-made art.

    python scripts/tools/ddt_read.py IN.ddt OUT.png
    python scripts/tools/ddt_read.py --flag-set IN.ddt OUTDIR NAME   # writes flag_NAME.png (512x341),
                                                                     # postgame_flag_NAME.png (976x256), flag_hc_NAME.png (200x200)
"""
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


def from565(v):
    v = np.asarray(v, dtype=np.int64)
    r = ((v >> 11) & 31) * 255 // 31
    g = ((v >> 5) & 63) * 255 // 63
    b = (v & 31) * 255 // 31
    return np.stack([r, g, b], axis=-1).astype(np.float64)


def decode_dxt1(data, w, h):
    bw, bh = max(w // 4, 1), max(h // 4, 1)
    blocks = np.frombuffer(data[: bw * bh * 8], dtype=np.uint8).reshape(-1, 8)
    c0 = blocks[:, 0:2].copy().view('<u2').reshape(-1).astype(np.int64)
    c1 = blocks[:, 2:4].copy().view('<u2').reshape(-1).astype(np.int64)
    bits = blocks[:, 4:8].copy().view('<u4').reshape(-1).astype(np.int64)
    p0, p1 = from565(c0), from565(c1)
    four = (c0 > c1)[:, None]
    p2 = np.where(four, (2 * p0 + p1) / 3, (p0 + p1) / 2)
    p3 = np.where(four, (p0 + 2 * p1) / 3, 0.0)
    pal = np.stack([p0, p1, p2, p3], axis=1)                       # blocks x 4 x 3
    idx = np.stack([(bits >> (2 * i)) & 3 for i in range(16)], axis=1)  # blocks x 16
    px = np.take_along_axis(pal, idx[:, :, None].repeat(3, axis=2), axis=1)  # blocks x 16 x 3
    img = px.reshape(bh, bw, 4, 4, 3).transpose(0, 2, 1, 3, 4).reshape(bh * 4, bw * 4, 3)
    return Image.fromarray(np.clip(np.rint(img), 0, 255).astype(np.uint8)[:h, :w])


def read_ddt(path):
    b = open(path, 'rb').read()
    assert b[:4] == b'RTS3', 'not an RTS3 ddt'
    usage, alpha, fmt, nmips = b[4:8]
    assert fmt == 4, 'only DXT1 (format 4) is decoded here, got %d' % fmt
    w, h = struct.unpack('<II', b[8:16])
    off, ln = struct.unpack('<II', b[16:24])
    return decode_dxt1(b[off:off + ln], w, h)


def flag_set(img, outdir, name):
    """The three PNGs a flag civ declares (measured on flag_paris_republic / postgame_flag_paris_republic / flag_hc_paris_republic)."""
    import os
    flag = img.resize((512, 341), Image.LANCZOS).convert('RGB')
    flag.save(os.path.join(outdir, 'flag_%s.png' % name))
    # post-game banner: the flag stretched wide, darkened towards the right edge like the vanilla renders
    banner = img.resize((976, 256), Image.LANCZOS).convert('RGBA')
    shade = np.linspace(1.0, 1.0, 976); shade[780:] = np.linspace(1.0, 0.35, 976 - 780)
    arr = np.asarray(banner).astype(np.float64)
    arr[:, :, :3] *= shade[None, :, None]
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA').save(os.path.join(outdir, 'postgame_flag_%s.png' % name))
    # home-city button: the flag inside a circle with a soft top gloss
    n = 200
    disc = img.resize((n, n), Image.LANCZOS).convert('RGBA')
    mask = Image.new('L', (n * 4, n * 4), 0)
    ImageDraw.Draw(mask).ellipse((8, 8, n * 4 - 8, n * 4 - 8), fill=255)
    mask = mask.resize((n, n), Image.LANCZOS)
    gloss = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(gloss).ellipse((30, 12, n - 30, n // 2), fill=(255, 255, 255, 70))
    gloss = gloss.filter(ImageFilter.GaussianBlur(10))
    disc.alpha_composite(gloss)
    disc.putalpha(mask)
    disc.save(os.path.join(outdir, 'flag_hc_%s.png' % name))
    return ['flag_%s.png' % name, 'postgame_flag_%s.png' % name, 'flag_hc_%s.png' % name]


if __name__ == '__main__':
    a = sys.argv[1:]
    if a and a[0] == '--flag-set':
        img = read_ddt(a[1])
        print(img.size, flag_set(img, a[2], a[3]))
    elif len(a) == 2:
        img = read_ddt(a[0]); img.save(a[1]); print(a[1], img.size)
    else:
        sys.exit(__doc__)
