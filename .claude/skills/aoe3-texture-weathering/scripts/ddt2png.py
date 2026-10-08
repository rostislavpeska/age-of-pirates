"""Decode AoE3DE RTS3 .ddt (top mip) to PNG via a synthetic DDS header and Pillow's BCn decoder.
Formats seen: 4 = DXT1 (BC1), 8 = DXT3 (BC2), 9 = DXT5 (BC3), 1 = BGRA8.
usage:  python -I ddt2png.py RAW_ROOT OUT_ROOT
Writes OUT_ROOT/<building_key>/<file stem>.png, plus <stem>_alpha.png for formats with alpha.
"""
import io
import json
import os
import struct
import sys

import numpy as np
from PIL import Image

FOURCC = {4: b'DXT1', 5: b'DXT1', 8: b'DXT3', 9: b'DXT5'}


def read_ddt(path):
    b = open(path, 'rb').read()
    assert b[:4] == b'RTS3', path
    usage, alpha, fmt, nmips = b[4:8]
    w, h = struct.unpack('<II', b[8:16])
    off, ln = struct.unpack('<II', b[16:24])
    data = b[off:off + ln]
    if fmt == 1:
        img = Image.frombytes('RGBA', (w, h), data[: w * h * 4], 'raw', 'BGRA')
    elif fmt in FOURCC:
        hdr = bytearray(124)
        struct.pack_into('<IIIIIII', hdr, 0, 124, 0x1 | 0x2 | 0x4 | 0x1000 | 0x80000, h, w, len(data), 0, 1)
        # pixel format at offset 72
        struct.pack_into('<II4s', hdr, 72, 32, 0x4, FOURCC[fmt])
        struct.pack_into('<I', hdr, 104, 0x1000)
        dds = b'DDS ' + bytes(hdr) + data
        img = Image.open(io.BytesIO(dds))
        img.load()
        img = img.convert('RGBA')
    else:
        raise ValueError('unsupported fmt %d in %s' % (fmt, path))
    return img, dict(usage=usage, alpha=alpha, fmt=fmt, mips=nmips, w=w, h=h)


def key_for(rel):
    p = rel.replace('\\', '/').lower()
    parts = p.split('/')
    i = parts.index('asian_civs')
    sub = [x for x in parts[i + 1:-1] if x != 'textures']
    return '_'.join(sub)


def main(raw, out):
    meta = {}
    for root, _, files in os.walk(raw):
        for f in files:
            if not f.lower().endswith('.ddt'):
                continue
            src = os.path.join(root, f)
            rel = os.path.relpath(src, raw)
            k = key_for(rel)
            img, info = read_ddt(src)
            od = os.path.join(out, k)
            os.makedirs(od, exist_ok=True)
            stem = os.path.splitext(f)[0]
            a = np.asarray(img)
            has_alpha = info['fmt'] in (5, 8, 9, 1) and a[..., 3].min() < 255
            img.convert('RGB').save(os.path.join(od, stem + '.png'))
            if has_alpha:
                Image.fromarray(a[..., 3]).save(os.path.join(od, stem + '_alpha.png'))
            info['alpha_min'] = int(a[..., 3].min())
            info['src'] = rel.replace('\\', '/')
            meta[k + '/' + stem] = info
            print(k, stem, info)
    json.dump(meta, open(os.path.join(out, 'decode_meta.json'), 'w'), indent=1)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
