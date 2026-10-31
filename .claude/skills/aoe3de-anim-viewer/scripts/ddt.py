"""AoE3 DE .ddt (RTS3) reader for the animation viewer: raw BC blocks per mip for direct S3TC upload, plus an RGBA
decode for the PNG fallback (bundle-schema.md section 8).

    import ddt, av_common as C
    w = C.BufferWriter('tex')
    rec = ddt.texture_record('units/.../iron_rider_0_mata_basecolor.ddt', data, w, provenance=3)
    rgba = ddt.decode_rgba(data, level=0)          # numpy uint8 (h, w, 4), Pillow's BCn decoder

RTS3 layout (measured 2026-10-11 on the retail archives; a header census of every raw DDT and every 15th
compressed one, ~3000 files):
    0   'RTS3'
    4   u8 usage    bit flags; 8 = cube (6 faces in the image table, measured on effects/sky/spanish_sky.ddt);
                    1, 2, 4 are named alpha-test, low-detail, bump after the community DDT notes (guess; normal maps
                    carry 6 = 2|4)
    5   u8 alpha    0 none, 1, 2, 4, 8 (names player, ?, trans, blend are a guess)
    6   u8 format   1 BGRA8, 3 (other header layout: unsupported), 4 DXT1 = BC1, 5 DXT1 with 1-bit alpha = BC1,
                    7 grey8, 8 DXT3 = BC2, 9 DXT5 = BC3
    7   u8 mip count
    8   u32 width, u32 height
    16  (u32 offset, u32 length) per image, face-major (all mips of face 0, then face 1, ...; the cube order is a
        guess: the only cube seen has one mip); the first offset equals 16 + 8 * mips * faces
Mip chains stop at 4x4 (1024 px -> 9 levels): the viewer sets TEXTURE_MAX_LEVEL = mip_count - 1. Some archive
entries hold the DDT inside an alz4 wrapper; it is removed first.

D3D11 decodes BC1 index 3 of a 3-colour block as transparent black whatever the header says, so format 4 and 5 are
both BC1 and both are uploaded as COMPRESSED_RGBA_S3TC_DXT1 (headless-gpu.md). The PNG fallback reuses
aoe3-texture-weathering's ddt2png (its DXT FourCC table and synthetic-DDS route into Pillow), generalised to any mip
and to bytes; tests prove both decode the top mip identically.
"""
from __future__ import annotations

import io
import math
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402

DDT2PNG_DIR = HERE.parents[1] / 'aoe3-texture-weathering' / 'scripts'

FORMATS = {
    1: {'name': 'bgra8', 'bc': None, 'block_bytes': None, 'texel_bytes': 4},
    3: {'name': 'format-3', 'bc': None, 'block_bytes': None, 'texel_bytes': None},
    4: {'name': 'dxt1', 'bc': 'BC1', 'block_bytes': 8, 'texel_bytes': None},
    5: {'name': 'dxt1-alpha', 'bc': 'BC1', 'block_bytes': 8, 'texel_bytes': None},
    7: {'name': 'grey8', 'bc': None, 'block_bytes': None, 'texel_bytes': 1},
    8: {'name': 'dxt3', 'bc': 'BC2', 'block_bytes': 16, 'texel_bytes': None},
    9: {'name': 'dxt5', 'bc': 'BC3', 'block_bytes': 16, 'texel_bytes': None},
}
USAGE_BITS = {1: 'alpha-test', 2: 'low-detail', 4: 'bump', 8: 'cube'}
USAGE_STATUS = {'cube': 'measured', 'alpha-test': 'guess', 'low-detail': 'guess', 'bump': 'guess'}
ALPHA_TYPES = {0: 'none', 1: 'player', 2: 'unknown-2', 4: 'trans', 8: 'blend'}
CUBE_BIT = 8
HEADER_FIXED = 16


class DdtError(ValueError):
    """bytes that are not a readable RTS3 texture."""


# ------------------------------------------------------------------------------------------------ private helpers
def _bartool():
    """aoe3de-bar-archives' bartool (alz4); a missing helper of av_common, kept private here."""
    if str(C.BARTOOL_DIR) not in sys.path:
        sys.path.insert(0, str(C.BARTOOL_DIR))
    import bartool
    return bartool


def _ddt2png():
    """aoe3-texture-weathering's ddt2png module (companion skill), or None when that skill is absent."""
    if not (DDT2PNG_DIR / 'ddt2png.py').is_file():
        return None
    if str(DDT2PNG_DIR) not in sys.path:
        sys.path.insert(0, str(DDT2PNG_DIR))
    import ddt2png
    return ddt2png


def unwrap(data) -> bytes:
    data = bytes(data)
    return _bartool().unwrap_alz4(data) if data[:4] == b'alz4' else data


# ------------------------------------------------------------------------------------------------ header
def level_dims(width, height, level):
    return max(1, width >> level), max(1, height >> level)


def level_bytes(fmt, width, height):
    """byte size of one image of `fmt` at width x height, or None for an unsupported format."""
    f = FORMATS.get(fmt)
    if not f:
        return None
    if f['block_bytes']:
        return math.ceil(width / 4) * math.ceil(height / 4) * f['block_bytes']
    if f['texel_bytes']:
        return width * height * f['texel_bytes']
    return None


def parse_header(data) -> dict:
    """the RTS3 header and image table: {usage, usage_flags, alpha, alpha_type, format, format_name, bc, mip_count,
    width, height, faces, header_size, images: [{face, level, width, height, offset, length, expected}],
    problems: [...]}. Raises DdtError for a wrong magic or a table outside the file."""
    data = unwrap(data)
    if len(data) < HEADER_FIXED or data[:4] != b'RTS3':
        raise DdtError('not an RTS3 texture (magic %r)' % data[:4])
    usage, alpha, fmt, nmips = data[4:8]
    width, height = struct.unpack_from('<II', data, 8)
    faces = 6 if usage & CUBE_BIT else 1
    header_size = HEADER_FIXED + 8 * nmips * faces
    if len(data) < header_size:
        raise DdtError('image table (%d bytes) runs past the file (%d bytes)' % (header_size, len(data)))
    images, problems = [], []
    for face in range(faces):
        for level in range(nmips):
            off, ln = struct.unpack_from('<II', data, HEADER_FIXED + 8 * (face * nmips + level))
            w, h = level_dims(width, height, level)
            exp = level_bytes(fmt, w, h)
            images.append({'face': face, 'level': level, 'width': w, 'height': h, 'offset': off, 'length': ln,
                           'expected': exp})
            if off + ln > len(data):
                problems.append('face %d level %d runs past the file' % (face, level))
            elif exp is not None and ln != exp:
                problems.append('face %d level %d holds %d bytes, %s %dx%d needs %d'
                                % (face, level, ln, FORMATS[fmt]['name'], w, h, exp))
    if images and images[0]['offset'] != header_size and fmt in FORMATS and FORMATS[fmt]['bc']:
        problems.append('first image at %d, header ends at %d' % (images[0]['offset'], header_size))
    info = FORMATS.get(fmt, {'name': 'format-%d' % fmt, 'bc': None})
    return {'usage': usage, 'usage_flags': [n for b, n in sorted(USAGE_BITS.items()) if usage & b],
            'alpha': alpha, 'alpha_type': ALPHA_TYPES.get(alpha, 'unknown-%d' % alpha),
            'format': fmt, 'format_name': info['name'], 'bc': info['bc'], 'mip_count': nmips,
            'width': width, 'height': height, 'faces': faces, 'header_size': header_size,
            'images': images, 'problems': problems}


def images(data, face=None):
    """[{face, level, width, height, data}] - the raw bytes of every image (face filter optional)."""
    data = unwrap(data)
    hdr = parse_header(data)
    out = []
    for im in hdr['images']:
        if face is not None and im['face'] != face:
            continue
        out.append(dict(im, data=data[im['offset']:im['offset'] + im['length']]))
    return out


# ------------------------------------------------------------------------------------------------ bundle record
def texture_record(texture_id, data, writer, *, provenance=None, path=None) -> dict:
    """the bundle texture record (bundle-schema.md section 8). For BC formats every mip's raw blocks go into
    `writer` (an av_common.BufferWriter) as a u8 view; other formats and broken files keep their id with
    decodable=false and the reason (`ddt-format-<code>`, `ddt-header-invalid`, `ddt-size-mismatch`).
    Extra fields beyond the schema: format_name, usage, usage_flags, alpha, alpha_type, faces, max_level,
    complete_to_1x1, problems."""
    rec = {'id': texture_id, 'path': path or texture_id, 'provenance': provenance, 'decodable': False,
           'unavailable_reason': None, 'ddt_format': None, 'bc': None, 'width': None, 'height': None,
           'mip_count': None, 'mips': [], 'fallback': None}
    if data is None:
        rec['unavailable_reason'] = 'file-missing'
        return rec
    try:
        data = unwrap(data)
        hdr = parse_header(data)
    except (DdtError, ValueError) as exc:
        rec['unavailable_reason'] = 'ddt-header-invalid'
        rec['problems'] = [str(exc)]
        return rec
    rec.update({'ddt_format': hdr['format'], 'format_name': hdr['format_name'], 'bc': hdr['bc'],
                'width': hdr['width'], 'height': hdr['height'], 'mip_count': hdr['mip_count'],
                'usage': hdr['usage'], 'usage_flags': hdr['usage_flags'], 'alpha': hdr['alpha'],
                'alpha_type': hdr['alpha_type'], 'faces': hdr['faces'], 'max_level': max(hdr['mip_count'] - 1, 0),
                'complete_to_1x1': bool(hdr['images']) and max(hdr['images'][-1]['width'],
                                                                hdr['images'][-1]['height']) == 1,
                'problems': list(hdr['problems'])})
    if not hdr['bc']:
        rec['unavailable_reason'] = 'ddt-format-%d' % hdr['format']
        return rec
    if hdr['problems']:
        rec['unavailable_reason'] = 'ddt-size-mismatch'
        return rec
    for im in hdr['images']:
        raw = memoryview(data)[im['offset']:im['offset'] + im['length']]
        view = writer.add(bytearray(raw), 'u8', 1)
        mip = {'level': im['level'], 'width': im['width'], 'height': im['height'], 'view': view}
        if hdr['faces'] > 1:
            mip['face'] = im['face']
        rec['mips'].append(mip)
    rec['decodable'] = True
    return rec


# ------------------------------------------------------------------------------------------------ RGBA decode
def _dds(width, height, fourcc, nbytes):
    """the synthetic DDS header ddt2png builds for Pillow (same fields), for one image of any size."""
    hdr = bytearray(124)
    struct.pack_into('<IIIIIII', hdr, 0, 124, 0x1 | 0x2 | 0x4 | 0x1000 | 0x80000, height, width, nbytes, 0, 1)
    struct.pack_into('<II4s', hdr, 72, 32, 0x4, fourcc)
    struct.pack_into('<I', hdr, 104, 0x1000)
    return b'DDS ' + bytes(hdr)


def decode_rgba(data, level=0, face=0):
    """numpy uint8 (h, w, 4) RGBA of one image. BC1/2/3 go through Pillow's BCn decoder behind ddt2png's synthetic
    DDS header. Measured with Pillow 11.3: a BC1 3-colour block decodes index 3 as transparent black (the D3D11
    rule) and its midpoint by truncation (127 for 0 and 255); the thirds of a 4-colour block are exact (170/85).
    The GPU's own decoder may round differently (NVIDIA: headless-gpu.md). BGRA8 and grey8 are converted directly."""
    import numpy as np
    data = unwrap(data)
    hdr = parse_header(data)
    im = next((i for i in hdr['images'] if i['level'] == level and i['face'] == face), None)
    if im is None:
        raise DdtError('no image at face %d level %d (mip_count %d, faces %d)'
                       % (face, level, hdr['mip_count'], hdr['faces']))
    raw = data[im['offset']:im['offset'] + im['length']]
    w, h, fmt = im['width'], im['height'], hdr['format']
    if fmt == 1:
        a = np.frombuffer(raw[:w * h * 4], np.uint8).reshape(h, w, 4)
        return a[..., [2, 1, 0, 3]].copy()
    if fmt == 7:
        g = np.frombuffer(raw[:w * h], np.uint8).reshape(h, w)
        return np.dstack([g, g, g, np.full_like(g, 255)])
    d2p = _ddt2png()
    if d2p is None:
        raise RuntimeError('the PNG fallback needs the companion skill aoe3-texture-weathering (ddt2png.py)')
    if fmt not in d2p.FOURCC:
        raise DdtError('format %d has no RGBA decoder' % fmt)
    from PIL import Image
    img = Image.open(io.BytesIO(_dds(w, h, d2p.FOURCC[fmt], len(raw)) + raw))
    img.load()
    return np.asarray(img.convert('RGBA')).copy()


def png_bytes(data, level=0, face=0) -> bytes:
    from PIL import Image
    buf = io.BytesIO()
    Image.fromarray(decode_rgba(data, level, face)).save(buf, format='PNG')      # (h, w, 4) uint8 -> RGBA
    return buf.getvalue()


def write_png(data, out_path, level=0, face=0) -> Path:
    """decoded RGBA PNG of one image, written atomically; refused inside a repository (AGENTS.md rule 8)."""
    return C.write_bytes(out_path, png_bytes(data, level, face), 'a decoded texture PNG')


def write_fallback(record, data, bundle_dir, level=0) -> str:
    """writes the reserved fallback PNG inside the bundle folder (`fallback/<id stem>.png`), sets
    record['fallback'] to that uri and returns it."""
    name = C.safe_stem(record['id'].rsplit('/', 1)[-1].rsplit('.', 1)[0]) + '.png'
    uri = 'fallback/' + name
    write_png(data, Path(bundle_dir) / 'fallback' / name, level)
    record['fallback'] = uri
    return uri


# ------------------------------------------------------------------------------------------------ CLI
def _read_spec(spec):
    p = Path(spec)
    if p.is_file():
        return p.read_bytes()
    bt = _bartool()
    try:
        game = bt.find_game_dir()
    except SystemExit as exc:                    # bartool exits when no install is found
        raise FileNotFoundError('%s: no such local file, and no game archives (%s)' % (spec, exc)) from None
    idx = bt.build_index(game)
    key = spec.replace(chr(92), '/').lower()
    for k in (key, 'art/' + key):
        if k in idx:
            return bt.read_entry(idx[k])
    raise FileNotFoundError(spec)


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description='Inspect an AoE3 DE .ddt or decode one mip to PNG (outside any '
                                             'repository). Reads a local file or a game archive path.')
    sub = ap.add_subparsers(dest='cmd', required=True)
    i = sub.add_parser('info', help='print the header and image table as JSON')
    i.add_argument('ddt')
    p = sub.add_parser('png', help='decode one image to PNG')
    p.add_argument('ddt')
    p.add_argument('--out', help='output folder (default: the viewer cache out/ folder)')
    p.add_argument('--level', type=int, default=0)
    p.add_argument('--face', type=int, default=0)
    a = ap.parse_args(argv)
    data = _read_spec(a.ddt)
    if a.cmd == 'info':
        sys.stdout.write(C.json_text(parse_header(data)))
        return 0
    out = C.output_dir(a.out, 'ddt')
    stem = C.safe_stem(Path(a.ddt.replace(chr(92), '/')).stem)
    path = write_png(data, out / ('%s_l%d.png' % (stem, a.level)), a.level, a.face)
    print(path)
    return 0


if __name__ == '__main__':
    sys.exit(main())
