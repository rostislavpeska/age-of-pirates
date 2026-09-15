"""Validate the local 2048 RGB TGA / RTS3 DXT1 ten-mip profile. Read-only.
Requires Pillow. python validate_opaque_textures.py texture.tga texture.ddt
Not a validator for other DDT profiles or transparent assets.
"""
import argparse
import io
import json
import struct
from pathlib import Path
from PIL import Image, ImageChops, ImageStat


def validate(tga, ddt):
    raw = Path(tga).read_bytes()
    if len(raw) < 18:
        raise ValueError('Truncated TGA')
    width, height = struct.unpack_from('<HH', raw, 12)
    if (width, height) != (2048, 2048) or raw[16] != 24 or raw[17] & 15 or raw[1] != 0 or raw[2] not in (2, 10):
        raise ValueError('Expected 2048x2048 24-bit opaque true-color TGA')
    source = Image.open(tga).convert('RGB')
    source.load()
    data = Path(ddt).read_bytes()
    if len(data) < 96 or data[:8] != b'RTS3\x00\x00\x04\x0a':
        raise ValueError('Expected RTS3 flags 0,0,4,10')
    if struct.unpack_from('<II', data, 8) != (2048, 2048):
        raise ValueError('DDT dimensions differ')
    previous_end = 96
    mips = []
    error = None
    for i in range(10):
        offset, size = struct.unpack_from('<II', data, 16 + i*8)
        w, h = max(1, width >> i), max(1, height >> i)
        expected = max(1, (w+3)//4)*max(1, (h+3)//4)*8
        if size != expected or offset != previous_end or offset + size > len(data):
            raise ValueError(f'Invalid DXT1 mip {i}')
        header = struct.pack('<7I', 124, 0x81007, h, w, size, 0, 1) + bytes(44)
        header += struct.pack('<II4s5I', 32, 4, b'DXT1', 0, 0, 0, 0, 0)
        header += struct.pack('<5I', 0x1000, 0, 0, 0, 0)
        decoded = Image.open(io.BytesIO(b'DDS ' + header + data[offset:offset+size])).convert('RGB')
        decoded.load()
        if i == 0:
            error = sum(ImageStat.Stat(ImageChops.difference(source, decoded)).mean)/3
            if error > 8:
                raise ValueError(f'Unexpected mean compression error: {error}')
        mips.append([w, h])
        previous_end = offset + size
    if previous_end != len(data):
        raise ValueError('Trailing bytes outside mip data')
    return dict(passed=True, dimensions=[width, height], alpha=False,
                mips=mips, mean_rgb_compression_error=error)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tga')
    parser.add_argument('ddt')
    args = parser.parse_args()
    print(json.dumps(validate(args.tga, args.ddt), indent=2))
