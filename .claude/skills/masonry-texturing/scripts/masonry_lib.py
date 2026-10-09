"""Reusable pieces of geometry-locked masonry texturing (numpy + Pillow, no Blender).

hull / row_extent        convex outline of a face set in its (u, v) frame and the u-extent at height v
value_noise / pnoise     smooth noise in [-1, 1]; pnoise wraps horizontally (for quarter-perimeter rings)
rounded_box_distance     distance inside a unit to its rounded-corner outline (not-boxy units)
ring_bond_positions      head-joint positions in normalised x for one course of a closed running-bond ring
periodic_joint_distance  metres to the nearest head joint (periodic)
corner_s                 unrolled corner coordinate for a facet pixel
registration_gate        dark-line F1 of a painting against a layout joint mask, best shift within +-8 px
crossfade_wrap           close a ring painting's wrap strip into its start
"""
import hashlib
import numpy as np
from PIL import Image, ImageFilter


def rng(*key):
    return np.random.default_rng(int.from_bytes(hashlib.md5(repr(key).encode()).digest()[:8], 'little'))


def hull(pts):
    pts = sorted(set(map(tuple, pts)))
    def half(ps):
        out = []
        for p in ps:
            while len(out) >= 2 and (out[-1][0] - out[-2][0]) * (p[1] - out[-2][1]) - (out[-1][1] - out[-2][1]) * (p[0] - out[-2][0]) <= 0:
                out.pop()
            out.append(p)
        return out
    return half(pts)[:-1] + half(pts[::-1])[:-1]


def row_extent(poly, v):
    vs = [p[1] for p in poly]; v = np.clip(v, min(vs) + 1e-6, max(vs) - 1e-6)
    lo, hi = np.full(np.shape(v), np.inf), np.full(np.shape(v), -np.inf)
    for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1]):
        if abs(y1 - y0) < 1e-9:
            continue
        t = (v - y0) / (y1 - y0); ok = (t >= 0) & (t <= 1); x = x0 + t * (x1 - x0)
        lo = np.where(ok, np.minimum(lo, x), lo); hi = np.where(ok, np.maximum(hi, x), hi)
    return lo, hi


def value_noise(shape, cell_px, key):
    h, w = shape; gh, gw = max(2, int(h / cell_px) + 2), max(2, int(w / cell_px) + 2)
    g = rng('vn', key, cell_px).uniform(-1, 1, (gh, gw)).astype(np.float32)
    return np.asarray(Image.fromarray(g, 'F').resize((int(gw * cell_px), int(gh * cell_px)), Image.BICUBIC))[:h, :w]


def pnoise(shape, cell_px, key):
    """value noise that wraps horizontally: column w joins column 0."""
    h, w = shape; gh, gw = max(2, int(h / cell_px) + 2), max(2, int(round(w / cell_px)))
    g = rng('pn', key, cell_px).uniform(-1, 1, (gh, gw)).astype(np.float32); g3 = np.concatenate([g, g, g], 1)
    big = np.asarray(Image.fromarray(g3, 'F').resize((3 * w, int(gh * cell_px)), Image.BICUBIC))   # middle third wraps
    return big[:h, w:2 * w]


def rounded_box_distance(dh, dv, rc):
    """dh / dv: distances to the nearest vertical / horizontal joint; rc: corner radius (per unit)."""
    corner = (dh < rc) & (dv < rc)
    return np.where(corner, rc - np.hypot(rc - dh, rc - dv), np.minimum(dh, dv))


def ring_bond_positions(Q, L, course, key, jitter=.1):
    """head joints of one course of a closed ring of length Q (metres), unit length about L, in normalised [0, 1).
    A whole number of units closes the ring exactly; odd courses shift by half a unit (running bond)."""
    N = max(1, int(round(Q / L))); r = rng('ring bond', key, int(course))
    ls = 1 + jitter * r.uniform(-1, 1, N); pos = np.concatenate([[0.], np.cumsum(ls) / ls.sum()])[:-1]
    return np.sort(np.mod(pos + (course % 2) * .5 / N + r.uniform(0, .2) / N, 1.))


def periodic_joint_distance(xn, pos, Q):
    d = np.abs(np.asarray(xn)[..., None] - pos); d = np.minimum(d, 1 - d)
    return d.min(-1) * Q


def corner_s(facet_widths_below, t):
    """unrolled corner coordinate of a facet pixel: summed widths of the facets before it (at this height) + t."""
    return facet_widths_below + t


def _blur(x, r):
    r = max(1, int(round(r))); x = np.pad(x.astype(np.float64), r + 1, mode='edge')
    for ax in (0, 1):
        c = np.cumsum(x, axis=ax); x = (np.take(c, range(2 * r + 1, c.shape[ax]), axis=ax) - np.take(c, range(0, c.shape[ax] - 2 * r - 1), axis=ax)) / (2 * r + 1)
    return x[:-1, :-1].astype(np.float32)


def _dilate(m, r):
    return np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(2 * r + 1))) > 127


def registration_gate(paint_rgb, joints, mask=None, search=8, min_f1=.5, max_shift=4):
    """paint_rgb: HxWx3 floats in [0, 1]; joints: HxW bool layout joint mask. Returns (pass, f1, dx, dy, precision, recall)."""
    mask = np.ones(joints.shape, bool) if mask is None else mask
    gl = (paint_rgb * [.2126, .7152, .0722]).sum(-1); dark = gl < _blur(gl, 9) * .80; Jd = _dilate(joints, 3); res = []
    for dy in range(-search, search + 1):
        for dx in range(-search, search + 1):
            d = np.roll(np.roll(dark, -dy, 0), -dx, 1) & mask
            prec = (d & Jd).sum() / max(d.sum(), 1); rec = (_dilate(d, 3) & joints & mask).sum() / max((joints & mask).sum(), 1)
            res.append((float(2 * prec * rec / max(prec + rec, 1e-6)), dx, dy, float(prec), float(rec)))
    top = max(r[0] for r in res)                       # near-ties (within the dilation) go to the smallest shift
    f1, dx, dy, prec, rec = min((r for r in res if r[0] >= top - .005), key=lambda r: (abs(r[1]) + abs(r[2]), -r[0]))
    return (f1 >= min_f1 and abs(dx) <= max_shift and abs(dy) <= max_shift), f1, dx, dy, prec, rec


def crossfade_wrap(sheet, Wn):
    """sheet: H x (Wn + ext) x C painting of a ring; returns a copy whose first ext columns blend into the wrap strip."""
    out = sheet.copy(); ext = sheet.shape[1] - Wn; w = (np.arange(ext) + .5) / ext
    out[:, :ext] = sheet[:, Wn:Wn + ext] * (1 - w)[None, :, None] + sheet[:, :ext] * w[None, :, None]
    return out
