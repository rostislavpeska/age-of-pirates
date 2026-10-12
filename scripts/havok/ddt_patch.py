"""Patch an AoE3DE .ddt (RTS3, DXT1 format 4 or DXT5 format 9, full mip chain) at BLOCK level: only the 4x4 blocks a
change mask touches are re-encoded, on every mip; every other byte stays identical (a full re-encode of a decoded page
would add one more generation of block loss to every texel). For owner fine-tuning of shipped pages (Korean player
colour, 2026-10-11: "strip player color from the masionry", "ALPHA COLORED RAILING FULLY IN PLAYER COLOR", "fix all").

    python ddt_patch.py IN.ddt NEW.png MASK.png OUT.ddt [--cutout-threshold 128]
      NEW.png  the edited mip 0 (RGBA, page size); only its texels under MASK matter
      MASK.png white = changed texels (page size)

Mip i of the new page = Lanczos downsample of (NEW where MASK else the decoded original mip 0) - the same filter the
project encoders use; blocks of mip i overlapping the mask's footprint (dilated by one block) are re-encoded with
ddt_dxt1.encode_dxt1 / encode_alpha. Prints the changed block counts per mip.
Optional --cutout-threshold preserves each changed texel's classification at that
integer alpha-test cutoff after compression. It does not preserve coverage lost
or gained by the mip filter, and must not be used for blended opacity.
"""
import io, struct, sys
from pathlib import Path
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ddt_dxt1 import encode_dxt1, encode_alpha  # noqa: E402


def header(b):
    assert b[:4] == b'RTS3', 'not an RTS3 ddt'
    usage, aflag, fmt, n = b[4], b[5], b[6], b[7]; w, h = struct.unpack_from('<II', b, 8)
    mips = [struct.unpack_from('<II', b, 16 + 8 * i) for i in range(n)]
    assert fmt in (4, 9), f'format {fmt} not supported (DXT1 4 / DXT5 9)'
    return dict(usage=usage, aflag=aflag, fmt=fmt, n=n, w=w, h=h, mips=mips)


def decode_mip0(b, H):
    off, size = H['mips'][0]; four = b'DXT1' if H['fmt'] == 4 else b'DXT5'
    hdr = struct.pack('<7I', 124, 0x81007, H['h'], H['w'], size, 0, 1) + bytes(44)
    hdr += struct.pack('<II4s5I', 32, 4, four, 0, 0, 0, 0, 0) + struct.pack('<5I', 0x1000, 0, 0, 0, 0)
    im = Image.open(io.BytesIO(b'DDS ' + hdr + b[off:off + size])); im.load()
    return np.asarray(im.convert('RGBA'))


def patch(src, new_png, mask_png, out, *, cutout_threshold=None):
    b = bytearray(Path(src).read_bytes()); H = header(b); W, Hh = H['w'], H['h']
    base = decode_mip0(bytes(b), H)
    new = np.asarray(Image.open(new_png).convert('RGBA')); mask = np.asarray(Image.open(mask_png).convert('L')) > 127
    assert new.shape[:2] == (Hh, W) and mask.shape == (Hh, W), 'NEW/MASK must be the page size'
    full = base.copy(); full[mask] = new[mask]
    bpb = 8 if H['fmt'] == 4 else 16; report = []
    rgb_img = Image.fromarray(np.ascontiguousarray(full[..., :3]), 'RGB'); a_img = Image.fromarray(np.ascontiguousarray(full[..., 3]), 'L')
    for i, (off, size) in enumerate(H['mips']):
        w, h = max(W >> i, 4), max(Hh >> i, 4)
        # colour and alpha resized apart: an RGBA resize premultiplies and turns the colour under alpha 0 black (ddt_dxt1)
        level = full if i == 0 else np.dstack([np.asarray(rgb_img.resize((w, h), Image.LANCZOS)), np.asarray(a_img.resize((w, h), Image.LANCZOS))])
        bw, bh = w // 4, h // 4
        m = np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).resize((bw, bh), Image.BOX)) > 0
        m = m | np.pad(m, 1)[2:, 1:-1] | np.pad(m, 1)[:-2, 1:-1] | np.pad(m, 1)[1:-1, 2:] | np.pad(m, 1)[1:-1, :-2]
        assert size == bw * bh * bpb, (i, size, bw, bh)
        ys, xs = np.nonzero(m)
        for by, bx in zip(ys, xs):
            blk = np.ascontiguousarray(level[by * 4:by * 4 + 4, bx * 4:bx * 4 + 4])
            col = encode_dxt1(np.ascontiguousarray(blk[..., :3]))
            data = col if H['fmt'] == 4 else bytes(encode_alpha(np.ascontiguousarray(blk[..., 3]), cutout_threshold=cutout_threshold).tobytes()) + col
            assert len(data) == bpb
            o = off + (by * bw + bx) * bpb; b[o:o + bpb] = data
        report.append((i, int(m.sum()), bw * bh))
    Path(out).write_bytes(b)
    return report


if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    for name in ('src', 'new_png', 'mask_png', 'out'):
        ap.add_argument(name)
    ap.add_argument('--cutout-threshold', type=int, choices=range(1, 256), metavar='1..255')
    a = ap.parse_args()
    rep = patch(a.src, a.new_png, a.mask_png, a.out, cutout_threshold=a.cutout_threshold)
    print('DDT_PATCH', ' '.join(f'mip{i}:{c}/{t}' for i, c, t in rep))
