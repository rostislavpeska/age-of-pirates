"""Clone-stamp patches for minor flaws on baked / painted atlas pages - no re-bake, no re-UV (owner 2026-10-11: "Simply find
out how to patch things like this. Patching can be useful for minor flaws and can save tokens, because bake and re uv is
difficult process").

    python texture_patch.py period --page PAGE_BaseColor.png --rect x0,y0,x1,y1 --axis x|y
        local pattern period (px) along one page axis, from the autocorrelation of luminance inside a CLEAN window
    python texture_patch.py apply --maps DIR --prefix Market_P0 --mask MASK.npz --full F --fade G --shift S [--axis-from-gradient]
        [--dx DX --dy DY] [--report PATCH.json]

A patch copies texels of the same page from a fixed offset onto the flawed texels - BaseColor, Normal and Masks TOGETHER
(a pure translation in UV keeps tangent-space normals valid; a rotation or mirror would not). The mask is an .npz with
integer arrays x, y and a float array d (a distance: 0 = the flaw's core, growing outwards; e.g. the 3D distance to a cap).
Weight 1 where d <= F, fading to 0 at G. The offset is either explicit (--dx/--dy, page px) or, with
--axis-from-gradient, S px along the gradient of d (away from the core) per texel. Choose S from the pattern period: a whole
period keeps the pattern in phase (hide a stain), half a period swaps rolls and pans (cover a dark trough). The source
must lie outside the patch's core: texels whose source falls inside it are skipped (reported; > 50 % fails), or the patch
would copy its own flaw.
"""
import argparse, json, sys
from pathlib import Path
import numpy as np
from PIL import Image


def load(path, mode):
    return np.asarray(Image.open(path).convert(mode)).astype(np.float32) / 255


def period(a):
    lum = load(a.page, 'RGB').mean(-1); x0, y0, x1, y1 = map(int, a.rect.split(','))
    w = lum[y0:y1, x0:x1]
    if a.axis == 'y':
        w = w.T
    s = w - w.mean(1, keepdims=True); L = s.shape[1]
    ac = np.array([np.mean(s[:, :L - k] * s[:, k:]) for k in range(L // 2)]); ac /= ac[0]
    lo = int(np.argmax(ac < 0)) if (ac < 0).any() else 2                    # first zero crossing, then the next peak
    p = int(np.argmax(ac[lo:]) + lo)
    print('PERIOD', p, 'px along', a.axis, '| autocorrelation at it', round(float(ac[p]), 2), '| half period', round(p / 2, 1))
    return p


def apply(a):
    D = Path(a.maps); M = np.load(a.mask); x, y, d = M['x'].astype(int), M['y'].astype(int), M['d'].astype(np.float32)
    maps = {k: (D / f'{a.prefix}_{k}.png', 'RGBA' if k == 'BaseColor' else 'RGB') for k in ('BaseColor', 'Normal', 'Masks')}
    imgs = {k: load(p, m) for k, (p, m) in maps.items()}; N = imgs['BaseColor'].shape[0]
    w = np.clip((a.fade - d) / max(a.fade - a.full, 1e-6), 0, 1)
    if a.axis_from_gradient:
        R = np.full((N, N), np.nan, np.float32); R[y, x] = d
        gy, gx = np.gradient(np.where(np.isnan(R), np.nanmax(R) + .05, R)); g = np.stack([gx[y, x], gy[y, x]], 1)
        gn = np.linalg.norm(g, axis=1); w[gn < 1e-9] = 0; u = g / np.maximum(gn, 1e-9)[:, None]
        dx, dy = u[:, 0] * a.shift, u[:, 1] * a.shift
    else:
        dx, dy = np.full(len(x), a.dx, float), np.full(len(x), a.dy, float)
    sx = np.clip(np.rint(x + dx).astype(int), 0, N - 1); sy = np.clip(np.rint(y + dy).astype(int), 0, N - 1)
    core = np.zeros((N, N), bool); core[y[w >= 1], x[w >= 1]] = True
    inside_src = core[sy, sx] & (w > 0)                                     # a source inside the flaw would copy the flaw:
    w[inside_src] = 0                                                         # those texels stay as they are (curved ends)
    assert inside_src.mean() < .5, f'{inside_src.mean():.1%} of the patch copies from its own core: raise --shift'
    W = w[:, None]
    for k, im in imgs.items():
        ch = slice(0, 3); src = im[sy, sx, ch].copy(); im[y, x, ch] = im[y, x, ch] * (1 - W) + src * W
        Image.fromarray(np.clip(np.rint(im * 255), 0, 255).astype(np.uint8), maps[k][1]).save(maps[k][0])
    rep = dict(prefix=a.prefix, mask=str(a.mask), texels=int((w > 0).sum()), full=int((w >= 1).sum()), shift=a.shift,
               offset_mode='gradient' if a.axis_from_gradient else 'fixed', skipped_self_copy=round(float(inside_src.mean()), 4))
    if a.report:
        Path(a.report).write_text(json.dumps(rep, indent=1))
    print('PATCH', json.dumps(rep))


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('mode', choices=('period', 'apply'))
    ap.add_argument('--page'); ap.add_argument('--rect'); ap.add_argument('--axis', default='x')
    ap.add_argument('--maps'); ap.add_argument('--prefix'); ap.add_argument('--mask'); ap.add_argument('--full', type=float, default=.0)
    ap.add_argument('--fade', type=float, default=.0); ap.add_argument('--shift', type=float, default=0.); ap.add_argument('--axis-from-gradient', action='store_true')
    ap.add_argument('--dx', type=float, default=0.); ap.add_argument('--dy', type=float, default=0.); ap.add_argument('--report')
    a = ap.parse_args()
    period(a) if a.mode == 'period' else apply(a)
