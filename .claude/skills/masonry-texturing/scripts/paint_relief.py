"""Surface detail relief from a painting (owner 2026-10-09: "you can pronounce the wood more - check how to improve
normals generation even more and parametrize it in case the base color is not that pronounced").

Structure (bands, studs, frames, seams, joints) stays a geometric model of the measured features; this module adds the
SURFACE on top of it - wood grain, pores, chisel marks - from the painting's luma:

- frequency bands sized in texels of the FINAL page (`texel_m`): detail finer than ~2 page texels never reaches the game
  and only adds aliasing, broad tone (lighting baked into a painting, board-to-board colour) is removed;
- band-pass = blur(L, r_fine) - blur(L, r_coarse); bright = high, dark = low (pores, latewood, grooves);
- optional smoothing ALONG the grain (`grain_axis`): keeps the streaks, kills speckle across them;
- contrast normalisation `normalize` 0..1: 0 = the depth follows the painting's own contrast against `ref_std`
  (a pale, washed-out painting gives a shallow relief), 1 = every band reaches its full depth whatever the painting's
  contrast (local RMS normalisation); in between blends the two. Clipped at +-`clip` sigma;
- `mask` (the material, e.g. wood without the iron): normalised convolution, so a dark neighbour never leaks a ridge
  along the boundary, and zero height outside.

normal_from_height() turns a height in metres into a tangent normal (OpenGL: x = +u, y = +v, rows top-down).
Sources: frequency separation for texture maps (Corona forum topic 8462), albedo without lighting (Unity manual
"Texture types"); measured on the Korean castle door (premium_m7_extras.py).
"""
import numpy as np

LUM = np.array([.2126, .7152, .0722])


def box_blur(x, ry, rx=None):
    """separable box blur, radii in pixels (rx defaults to ry), edge-clamped; radius 0 = identity on that axis"""
    rx = ry if rx is None else rx
    out = np.asarray(x, np.float64)
    for ax, r in ((0, int(round(ry))), (1, int(round(rx)))):
        if r <= 0:
            continue
        pad = [(0, 0)] * out.ndim; pad[ax] = (r + 1, r)
        c = np.cumsum(np.pad(out, pad, mode='edge'), axis=ax); n = out.shape[ax]
        out = (np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=ax) - np.take(c, np.arange(0, n), axis=ax)) / (2 * r + 1)
    return out


def _mblur(x, m, ry, rx=None):
    """normalised convolution: the masked mean (mask m in 0..1) - neighbours outside the material do not count"""
    if m is None:
        return box_blur(x, ry, rx)
    return box_blur(x * m, ry, rx) / np.maximum(box_blur(m, ry, rx), 1e-6)


def detail_height(rgb, px_per_m, texel_m, mask=None, bands=((2.5, .0008), (8., .0012)), grain_axis=None,
                  anisotropy=3., normalize=.7, ref_std=.08, clip=2.5, dark_low=True):
    """Height in metres of the painted surface detail.
    rgb: HxWx3 (or HxW luma) in 0..1; px_per_m: the painting's pixels per metre; texel_m: one texel of the final page.
    bands: (period in page texels, depth in metres at 1 sigma). grain_axis: 0 = grain runs down the rows (vertical
    boards), 1 = along the columns, None = isotropic. Returns (height, per-band list)."""
    L = (np.asarray(rgb, np.float64)[..., :3] * LUM).sum(-1) if np.ndim(rgb) == 3 else np.asarray(rgb, np.float64)
    m = None if mask is None else np.clip(np.asarray(mask, np.float64), 0, 1)
    h = np.zeros_like(L); parts = []
    for period, depth in bands:
        w = period * texel_m * px_per_m                       # period in painting pixels
        r_c, r_f = max(1., w / 2.), max(.0, w / 8.)
        if grain_axis is None:
            fine = _mblur(L, m, r_f)
        else:                                                 # stretch the fine blur along the grain
            along = r_f * anisotropy
            fine = _mblur(L, m, along, r_f) if grain_axis == 0 else _mblur(L, m, r_f, along)
        bp = fine - _mblur(L, m, r_c)
        rms = np.sqrt(_mblur(bp * bp, m, 2 * r_c))
        k = (1 - normalize) / ref_std + normalize / np.maximum(rms, 1e-4)
        s = np.clip(bp * k, -clip, clip) * (1 if dark_low else -1)
        hb = depth * s
        if m is not None:
            hb = hb * m
        parts.append(hb); h += hb
    return h, parts


def normal_from_height(h, px_per_m, gain=1.):
    """unit tangent normals (x = +u right, y = +v up; rows top-down) of a height field in metres"""
    gy, gx = np.gradient(np.asarray(h, np.float64), 1. / px_per_m)
    n = np.dstack([-gx * gain, gy * gain, np.ones_like(h)])  # +v is -row, so dh/dv = -gy -> n.y = +gy
    return n / np.linalg.norm(n, axis=2, keepdims=True)
