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

--preserve-alpha copies original DXT5 alpha blocks at every mip (RGB edit only).
--green-only fits only green endpoint bits with fixed selectors/order, preserving
decoded R/B/A and untouched blocks exactly. It implies alpha preservation.
--alpha-only changes DXT5 alpha blocks while retaining every RGB block byte.
--alpha-selectors additionally locks alpha endpoints and untouched pixel selectors;
stored mip alpha receives only the filtered edit delta. An unavailable cutout
classification fails instead of changing endpoints. No reader approval is implied.
This does not certify shared-reader compatibility or mip silhouette quality.
Audit: 2026-10-13-codex-castle-delivery-01; port of tested stage_castles.py mechanics.
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


def decode_level(b, H, i):
    """Decode a stored mip independently, including the minimum 4x4 levels."""
    level = dict(H, w=max(H['w'] >> i, 4), h=max(H['h'] >> i, 4), mips=[H['mips'][i]])
    return decode_mip0(b, level)


def green_only(old, target, *, force_four=False):
    """Fit green endpoints while retaining selectors, R/B endpoints and mode.

    This constrained encoding may leave a requested green change unrepresented;
    it never trades protected channels for a smaller green error.
    """
    c = old.copy()
    c0 = c[:, :2].copy().view('<u2').reshape(-1).astype(np.int64)
    c1 = c[:, 2:4].copy().view('<u2').reshape(-1).astype(np.int64)
    bits = c[:, 4:8].copy().view('<u4').reshape(-1)
    idx = ((bits[:, None] >> (2 * np.arange(16, dtype=np.uint32))) & 3).astype(int)
    order = c0 > c1
    four = np.ones(len(c0), bool) if force_four else order
    aa = np.array([1., 0., 2/3, 1/3])[idx]; bb = 1-aa
    aa[~four] = np.array([1., 0., .5, 0.])[idx[~four]]
    bb[~four] = np.array([0., 1., .5, 0.])[idx[~four]]
    xx = (aa*aa).sum(1); yy = (bb*bb).sum(1); xy = (aa*bb).sum(1)
    xt = (aa*target).sum(1); yt = (bb*target).sum(1)
    det = xx*yy-xy*xy; good = det > 1e-6
    g0 = ((c0 >> 5) & 63).astype(float); g1 = ((c1 >> 5) & 63).astype(float)
    g0[good] = (xt[good]*yy[good]-yt[good]*xy[good])/det[good]*63/255
    g1[good] = (yt[good]*xx[good]-xt[good]*xy[good])/det[good]*63/255
    only0 = (~good) & (xx > 0) & (yy == 0); only1 = (~good) & (yy > 0) & (xx == 0)
    g0[only0] = xt[only0]/xx[only0]*63/255; g1[only1] = yt[only1]/yy[only1]*63/255
    g0 = np.clip(np.rint(g0), 0, 63).astype(int); g1 = np.clip(np.rint(g1), 0, 63).astype(int)
    best0 = c0.copy(); best1 = c1.copy()
    def loss(a, b):
        return (((((a >> 5) & 63)*255//63)[:, None]*aa +
                 (((b >> 5) & 63)*255//63)[:, None]*bb-target)**2).mean(1)
    best = loss(c0, c1)
    for d0 in (-1, 0, 1):
        for d1 in (-1, 0, 1):
            n0 = (c0 & ~2016) | (np.clip(g0+d0, 0, 63) << 5)
            n1 = (c1 & ~2016) | (np.clip(g1+d1, 0, 63) << 5)
            err = loss(n0, n1); pick = ((n0 > n1) == order) & (err < best)
            best[pick] = err[pick]; best0[pick] = n0[pick]; best1[pick] = n1[pick]
    c[:, :2] = best0.astype('<u2').view(np.uint8).reshape(-1, 2)
    c[:, 2:4] = best1.astype('<u2').view(np.uint8).reshape(-1, 2)
    return c


def alpha_selectors(old, target, changed, threshold=None):
    """Audit2026-10-14-codex-zen-rollout-44: keep BC3 endpoints/other pixels exact."""
    blocks=old.copy();a=old[:,0].astype(int);b=old[:,1].astype(int)
    palette=np.empty((len(old),8),int);palette[:,0]=a;palette[:,1]=b
    for j in range(2,8):
        palette[:,j]=np.where(a>b,((8-j)*a+(j-1)*b)//7,
                             ((6-j)*a+(j-1)*b)//5 if j<6 else 0 if j==6 else 255)
    bits=sum(old[:,j+2].astype(np.uint64) << np.uint64(8*j) for j in range(6))
    shifts=np.arange(16,dtype=np.uint64)*3
    prior=((bits[:,None]>>shifts)&7).astype(int)
    loss=abs(palette[:,None,:]-target[:,:,None]).astype(float)
    if threshold is not None:
        allowed=(palette[:,None,:]>=threshold)==(target[:,:,None]>=threshold)
        if np.any(changed & ~allowed.any(2)):
            raise ValueError('fixed alpha palette cannot represent requested cutout class')
        loss[~allowed]=np.inf
    best=loss.argmin(2)
    # Preserve equivalent selectors and every non-target pixel.
    prior_loss=np.take_along_axis(loss,prior[:,:,None],2)[:,:,0]
    best=np.where(changed & (loss.min(2)<prior_loss),best,prior)
    packed=np.sum(best.astype(np.uint64)<<shifts,axis=1,dtype=np.uint64)
    for j in range(6):blocks[:,j+2]=((packed>>np.uint64(8*j))&255).astype(np.uint8)
    return blocks


def patch(src, new_png, mask_png, out, *, cutout_threshold=None,
          preserve_alpha=False, green_only_mode=False, alpha_only=False,
          alpha_selectors_mode=False):
    b = bytearray(Path(src).read_bytes()); H = header(b); W, Hh = H['w'], H['h']
    source = bytes(b)
    if alpha_selectors_mode and not alpha_only:
        raise ValueError('alpha-selectors requires alpha-only')
    # audit2026-10-14-codex-zen-rollout-40 / INC366: bounded padding repair.
    if alpha_only and (H['fmt'] != 9 or preserve_alpha or green_only_mode):
        raise ValueError('alpha-only requires DXT5 and excludes other channel modes')
    if cutout_threshold is not None and (preserve_alpha or green_only_mode):
        raise ValueError('cutout-threshold and protected-channel modes are mutually exclusive')
    if preserve_alpha and H['fmt'] != 9:
        raise ValueError('preserve-alpha requires DXT5; use green-only for DXT1 packed maps')
    base = decode_mip0(bytes(b), H)
    new = np.asarray(Image.open(new_png).convert('RGBA')); mask = np.asarray(Image.open(mask_png).convert('L')) > 127
    assert new.shape[:2] == (Hh, W) and mask.shape == (Hh, W), 'NEW/MASK must be the page size'
    full = base.copy(); full[mask] = new[mask]
    bpb = 8 if H['fmt'] == 4 else 16; report = []
    rgb_img = Image.fromarray(np.ascontiguousarray(full[..., :3]), 'RGB'); a_img = Image.fromarray(np.ascontiguousarray(full[..., 3]), 'L')
    original_alpha=Image.fromarray(np.ascontiguousarray(base[:,:,3]))
    for i, (off, size) in enumerate(H['mips']):
        w, h = max(W >> i, 4), max(Hh >> i, 4)
        # colour and alpha resized apart: an RGBA resize premultiplies and turns the colour under alpha 0 black (ddt_dxt1)
        level = full if i == 0 else np.dstack([np.asarray(rgb_img.resize((w, h), Image.LANCZOS)), np.asarray(a_img.resize((w, h), Image.LANCZOS))])
        bw, bh = w // 4, h // 4
        m = np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).resize((bw, bh), Image.BOX)) > 0
        m = m | np.pad(m, 1)[2:, 1:-1] | np.pad(m, 1)[:-2, 1:-1] | np.pad(m, 1)[1:-1, 2:] | np.pad(m, 1)[1:-1, :-2]
        assert size == bw * bh * bpb, (i, size, bw, bh)
        if preserve_alpha or green_only_mode or alpha_only:
            touched = m.ravel()
            oldblocks = np.frombuffer(source[off:off+size], np.uint8).reshape(-1, bpb)
            blocks = oldblocks.copy()
            if alpha_only:
                if alpha_selectors_mode:
                    original_level=decode_level(source,H,i)[:,:,3].astype(int)
                    prior_filter=base[:,:,3] if i==0 else np.asarray(original_alpha.resize((w,h),Image.LANCZOS))
                    delta=level[:,:,3].astype(int)-prior_filter.astype(int)
                    target=np.clip(original_level+delta,0,255)
                    def as_blocks(x):return x.reshape(bh,4,bw,4).transpose(0,2,1,3).reshape(-1,16)
                    active=as_blocks(delta!=0);touched=active.any(1)
                    blocks[:,:8]=alpha_selectors(oldblocks[:,:8],as_blocks(target),active,cutout_threshold)
                    m=touched.reshape(bh,bw)
                else:
                    encoded = encode_alpha(np.ascontiguousarray(level[:, :, 3]), cutout_threshold=cutout_threshold)
                    blocks[touched, :8] = np.asarray(encoded, dtype=np.uint8).reshape(-1, 8)[touched]
            elif green_only_mode:
                target = level[:, :, 1].reshape(bh, 4, bw, 4).transpose(0, 2, 1, 3).reshape(-1, 16).astype(float)
                blocks[touched, bpb-8:] = green_only(oldblocks[touched, bpb-8:], target[touched], force_four=H['fmt'] == 9)
            else:
                encoded = np.frombuffer(encode_dxt1(np.ascontiguousarray(level[:, :, :3])), np.uint8).reshape(-1, 8)
                blocks[touched, bpb-8:] = encoded[touched]
            b[off:off+size] = blocks.tobytes()
            before = decode_level(source, H, i); after = decode_level(bytes(b), H, i)
            protected = [0, 1, 2] if alpha_only else [0, 2, 3] if green_only_mode else [3]
            assert np.array_equal(before[:, :, protected], after[:, :, protected]), 'protected channel drift'
            assert np.array_equal(oldblocks[~touched], blocks[~touched]), 'untouched block drift'
            report.append((i, int(m.sum()), bw * bh))
            continue
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
    ap.add_argument('--preserve-alpha', action='store_true')
    ap.add_argument('--green-only', action='store_true')
    ap.add_argument('--alpha-only', action='store_true')
    ap.add_argument('--alpha-selectors', action='store_true')
    a = ap.parse_args()
    rep = patch(a.src, a.new_png, a.mask_png, a.out, cutout_threshold=a.cutout_threshold,
                preserve_alpha=a.preserve_alpha, green_only_mode=a.green_only, alpha_only=a.alpha_only,
                alpha_selectors_mode=a.alpha_selectors)
    print('DDT_PATCH', ' '.join(f'mip{i}:{c}/{t}' for i, c, t in rep))
