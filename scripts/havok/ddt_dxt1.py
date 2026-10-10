"""Write an AoE3DE .ddt (RTS3, usage 0, alpha 0, format 4 = DXT1, full mip chain) from any image Pillow can open -
the same profile as the vanilla building textures (verified header on british_tol_matA_*.ddt: 'RTS3',0,0,4,10, 2048x2048).
Square power-of-two images only. Endpoints per 4x4 block from the principal colour axis, 4-colour mode.

    python ddt_dxt1.py IN.png OUT.ddt [--size 512]
    python ddt_dxt1.py --pack AO.png ROUGH.png METAL.png OUT.ddt [--size 512]     # R=AO G=roughness B=metallic masks
    python ddt_dxt1.py IN.png OUT.ddt --dxt5 [--size 1024]    # keeps the alpha: format 9 = DXT5, alpha flag 4, mips
                                                              # to 4x4 - the profile of vanilla BaseColors with
                                                              # cut-out cards (changdao_0_matA_BaseColor: 'RTS3',0,4,9)
An image whose alpha cuts out more than 1% of its texels is refused for DXT1 (the cards would turn opaque) unless
--drop-alpha says the alpha is unused; a smaller share is written with a warning.
"""
import struct, sys
import numpy as np
from PIL import Image


def rgb565(c):
    c = np.asarray(c, dtype=np.int64)
    return ((c[..., 0] >> 3) << 11) | ((c[..., 1] >> 2) << 5) | (c[..., 2] >> 3)


def from565(v):
    v = np.asarray(v, dtype=np.int64)
    r = ((v >> 11) & 31) * 255 // 31; g = ((v >> 5) & 63) * 255 // 63; b = (v & 31) * 255 // 31
    return np.stack([r, g, b], axis=-1).astype(np.float64)


def encode_dxt1(img):
    """img: HxWx3 uint8, H and W multiples of 4 (1x1 / 2x2 mips are padded) -> bytes"""
    h, w = img.shape[:2]
    if h < 4 or w < 4:
        pad = np.zeros((max(h, 4), max(w, 4), 3), np.uint8); pad[:h, :w] = img
        pad[h:, :w] = img[-1:, :]; pad[:, w:] = pad[:, w - 1:w]; img = pad; h, w = img.shape[:2]
    bh, bw = h // 4, w // 4
    B = img.reshape(bh, 4, bw, 4, 3).transpose(0, 2, 1, 3, 4).reshape(-1, 16, 3).astype(np.float64)
    mean = B.mean(axis=1, keepdims=True); D = B - mean
    # principal axis per block (power iteration on the 3x3 covariance, 8 steps)
    cov = np.einsum('bij,bik->bjk', D, D) + np.eye(3) * 1e-6
    v = np.ones((len(B), 3)) / np.sqrt(3)
    for _ in range(8):
        v = np.einsum('bjk,bk->bj', cov, v); v /= np.linalg.norm(v, axis=1, keepdims=True) + 1e-12
    proj = np.einsum('bij,bj->bi', D, v)
    lo = mean[:, 0] + v * proj.min(axis=1, keepdims=True); hi = mean[:, 0] + v * proj.max(axis=1, keepdims=True)
    lo = np.clip(np.rint(lo), 0, 255); hi = np.clip(np.rint(hi), 0, 255)
    c0 = rgb565(hi); c1 = rgb565(lo)
    swap = c0 < c1; c0s = np.where(swap, c1, c0); c1s = np.where(swap, c0, c1)
    p0 = from565(c0s); p1 = from565(c1s)
    pal = np.stack([p0, p1, (2 * p0 + p1) / 3, (p0 + 2 * p1) / 3], axis=1)           # b x 4 x 3
    solid = c0s == c1s
    d2 = ((B[:, :, None, :] - pal[:, None, :, :]) ** 2).sum(axis=-1)                   # b x 16 x 4
    idx = d2.argmin(axis=-1); idx[solid] = 0
    bits = np.zeros(len(B), dtype=np.uint32)
    for i in range(16): bits |= (idx[:, i].astype(np.uint32) & 3) << (2 * i)
    out = np.zeros((len(B), 8), np.uint8)
    out[:, 0:2] = c0s.astype('<u2').view(np.uint8).reshape(-1, 2); out[:, 2:4] = c1s.astype('<u2').view(np.uint8).reshape(-1, 2)
    out[:, 4:8] = bits.astype('<u4').view(np.uint8).reshape(-1, 4)
    return out.tobytes()


def encode_alpha(a):
    """a: HxW uint8 -> DXT5 alpha blocks (8 bytes each): endpoints max/min, 8-level interpolation, 3-bit indices"""
    h, w = a.shape
    if h < 4 or w < 4:
        pad = np.zeros((max(h, 4), max(w, 4)), np.uint8); pad[:h, :w] = a
        pad[h:, :w] = a[-1:, :]; pad[:, w:] = pad[:, w - 1:w]; a = pad; h, w = a.shape
    B = a.reshape(h // 4, 4, w // 4, 4).transpose(0, 2, 1, 3).reshape(-1, 16).astype(np.int64)
    a0 = B.max(axis=1); a1 = B.min(axis=1)
    k = np.arange(8)
    w0 = np.array([7, 0, 6, 5, 4, 3, 2, 1]); w1 = 7 - w0                                # index -> weights of a0, a1
    pal = (w0[None, :] * a0[:, None] + w1[None, :] * a1[:, None]) / 7.0                   # b x 8
    idx = np.abs(B[:, :, None] - pal[:, None, :]).argmin(axis=-1)                          # b x 16
    idx[a0 == a1] = 0
    bits = np.zeros(len(B), dtype=np.uint64)
    for i in range(16): bits |= (idx[:, i].astype(np.uint64) & np.uint64(7)) << np.uint64(3 * i)
    out = np.zeros((len(B), 8), np.uint8)
    out[:, 0] = a0; out[:, 1] = a1
    out[:, 2:8] = bits.astype('<u8').view(np.uint8).reshape(-1, 8)[:, :6]
    return out


def write_ddt(img, path, usage=0, alpha=0, dxt5=False):
    w, h = img.size; assert w == h and w & (w - 1) == 0, 'square power-of-two only'
    mips = []
    if dxt5:
        # the vanilla profile of cut-out BaseColors (changdao_2_mata_BaseColor: 'RTS3',0,4,9, 9 mips for 1024): mips
        # down to 4x4 only, and colour and alpha resized apart - an RGBA resize premultiplies, so the colour under
        # alpha 0 turned black in every smaller mip (owner's test 2026-10-09: black cards over the Gakgung helmets)
        rgb, a = img.convert('RGB'), img.convert('RGBA').getchannel('A')
        while True:
            col = np.frombuffer(encode_dxt1(np.asarray(rgb, dtype=np.uint8)), np.uint8).reshape(-1, 8)
            mips.append(np.concatenate([encode_alpha(np.asarray(a, dtype=np.uint8)), col], axis=1).tobytes())
            if rgb.size[0] <= 4: break
            half = (rgb.size[0] // 2, rgb.size[1] // 2)
            rgb, a = rgb.resize(half, Image.LANCZOS), a.resize(half, Image.LANCZOS)
    else:
        cur = img.convert('RGB')
        while True:
            mips.append(encode_dxt1(np.asarray(cur, dtype=np.uint8)))
            if cur.size[0] == 1: break
            cur = cur.resize((max(cur.size[0] // 2, 1), max(cur.size[1] // 2, 1)), Image.LANCZOS)
    head = b'RTS3' + bytes([usage, 4 if dxt5 else alpha, 9 if dxt5 else 4, len(mips)]) + struct.pack('<II', w, h)
    off = 16 + 8 * len(mips); table = b''
    for m in mips: table += struct.pack('<II', off, len(m)); off += len(m)
    open(path, 'wb').write(head + table + b''.join(mips))
    return len(mips), off


def alpha_guard(src, drop):
    """an image whose alpha cuts texels out must not lose it silently in an opaque DXT1 (owner 2026-10-09: 'test for
    missing alpha'): refuse above 1% of texels below 128 unless --drop-alpha, warn below that"""
    im = Image.open(src)
    if 'A' not in im.getbands():
        return
    al = np.asarray(im.getchannel('A'))
    frac = float((al < 128).mean())
    if frac > 0.01 and not drop:
        sys.exit('REFUSED %s: %.1f%% of its texels have alpha < 128 (cut-out cards?) - DXT1 would make them opaque. '
                 'Use --dxt5 to keep the alpha, or --drop-alpha if it is unused.' % (src, 100 * frac))
    if frac > 0:
        print('WARNING %s: %.2f%% of its texels have alpha < 128; DXT1 drops the alpha' % (src, 100 * frac))


def main():
    a = sys.argv[1:]; size = None
    dxt5 = '--dxt5' in a
    if dxt5: a.remove('--dxt5')
    drop = '--drop-alpha' in a
    if drop: a.remove('--drop-alpha')
    if '--size' in a: i = a.index('--size'); size = int(a[i + 1]); del a[i:i + 2]
    if a[0] == '--pack':
        ao, ro, me, out = a[1:5]
        chans = [Image.open(p).convert('L') for p in (ao, ro, me)]
        if size: chans = [c.resize((size, size), Image.LANCZOS) for c in chans]
        img = Image.merge('RGB', chans)
    else:
        src, out = a[:2]
        if not dxt5:
            alpha_guard(src, drop)
        img = Image.open(src).convert('RGBA' if dxt5 else 'RGB')
        if size: img = img.resize((size, size), Image.LANCZOS)
    n, total = write_ddt(img, out, dxt5=dxt5)
    print('wrote', out, img.size, 'mips', n, 'bytes', total)


if __name__ == '__main__':
    main()
