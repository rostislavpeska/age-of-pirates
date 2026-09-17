"""Write an AoE3DE .ddt (RTS3, usage 0, alpha 0, format 4 = DXT1, full mip chain) from any image Pillow can open -
the same profile as the vanilla building textures (verified header on british_tol_matA_*.ddt: 'RTS3',0,0,4,10, 2048x2048).
Square power-of-two images only. Endpoints per 4x4 block from the principal colour axis, 4-colour mode.

    python ddt_dxt1.py IN.png OUT.ddt [--size 512]
    python ddt_dxt1.py --pack AO.png ROUGH.png METAL.png OUT.ddt [--size 512]     # R=AO G=roughness B=metallic masks
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


def write_ddt(img, path, usage=0, alpha=0):
    w, h = img.size; assert w == h and w & (w - 1) == 0, 'square power-of-two only'
    mips = []; cur = img.convert('RGB')
    while True:
        mips.append(encode_dxt1(np.asarray(cur, dtype=np.uint8)))
        if cur.size[0] == 1: break
        cur = cur.resize((max(cur.size[0] // 2, 1), max(cur.size[1] // 2, 1)), Image.LANCZOS)
    head = b'RTS3' + bytes([usage, alpha, 4, len(mips)]) + struct.pack('<II', w, h)
    off = 16 + 8 * len(mips); table = b''
    for m in mips: table += struct.pack('<II', off, len(m)); off += len(m)
    open(path, 'wb').write(head + table + b''.join(mips))
    return len(mips), off


def main():
    a = sys.argv[1:]; size = None
    if '--size' in a: i = a.index('--size'); size = int(a[i + 1]); del a[i:i + 2]
    if a[0] == '--pack':
        ao, ro, me, out = a[1:5]
        chans = [Image.open(p).convert('L') for p in (ao, ro, me)]
        if size: chans = [c.resize((size, size), Image.LANCZOS) for c in chans]
        img = Image.merge('RGB', chans)
    else:
        src, out = a[:2]; img = Image.open(src).convert('RGB')
        if size: img = img.resize((size, size), Image.LANCZOS)
    n, total = write_ddt(img, out)
    print('wrote', out, img.size, 'mips', n, 'bytes', total)


if __name__ == '__main__':
    main()
