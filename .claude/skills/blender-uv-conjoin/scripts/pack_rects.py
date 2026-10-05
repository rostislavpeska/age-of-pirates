"""Deterministic packed-page measurement (protocol (e), metric A).

Every owner chart becomes its minimum-area bounding rectangle padded by the gutter
g on two sides (so neighbours are g apart). MaxRects with best-short-side-fit
(Jylanki 2010) places them, 0/90 degree rotation allowed; the minimum square page
side L* at fixed density is found by bisection to 1 texel and re-verified.
Rectangles ignore holes and concavities, so L* is an upper bound for an exact-shape
packer; the exact-area lower bound sqrt(sum(area + g/2 * perimeter)) is reported too.
Controls with known optima validate the instrument before real data.
"""
import json, math, sys, re
from pathlib import Path
import numpy as np
from shapely.geometry import Polygon
from shapely.ops import unary_union

P = Path(__file__).parent


def maxrects(rects, W, H):
    free = [(0., 0., W, H)]
    placed = []
    for i, (w, h) in sorted(enumerate(rects), key=lambda r: -max(r[1])):
        best = None
        for fx, fy, fw, fh in free:
            for rw, rh in ((w, h), (h, w)):
                if rw <= fw + 1e-9 and rh <= fh + 1e-9:
                    ss = min(fw - rw, fh - rh); ls = max(fw - rw, fh - rh)
                    if best is None or (ss, ls) < best[0]:
                        best = ((ss, ls), fx, fy, rw, rh)
        if best is None:
            return None
        _, x, y, rw, rh = best
        placed.append((i, x, y, rw, rh))
        nf = []
        for fx, fy, fw, fh in free:
            if x >= fx + fw or x + rw <= fx or y >= fy + fh or y + rh <= fy:
                nf.append((fx, fy, fw, fh)); continue
            if x > fx: nf.append((fx, fy, x - fx, fh))
            if x + rw < fx + fw: nf.append((x + rw, fy, fx + fw - x - rw, fh))
            if y > fy: nf.append((fx, fy, fw, y - fy))
            if y + rh < fy + fh: nf.append((fx, y + rh, fw, fy + fh - y - rh))
        # prune free rectangles contained in another (vectorised; ties keep the first)
        if not nf:
            free = []
            continue
        A = np.asarray(nf, float).reshape(-1, 4)
        x0, y0, x1, y1 = A[:, 0], A[:, 1], A[:, 0] + A[:, 2], A[:, 1] + A[:, 3]
        inside = ((x0[:, None] >= x0[None, :] - 1e-9) & (y0[:, None] >= y0[None, :] - 1e-9) &
                  (x1[:, None] <= x1[None, :] + 1e-9) & (y1[:, None] <= y1[None, :] + 1e-9))
        np.fill_diagonal(inside, False)
        same = inside & inside.T
        idx = np.arange(len(nf))
        drop = (inside & ~same).any(1) | (same & (idx[None, :] < idx[:, None])).any(1)
        free = [tuple(a) for a, d in zip(nf, drop) if not d]
    return placed


def min_side(rects):
    if not rects or any(not math.isfinite(v) or v <= 0 for r in rects for v in r):
        raise ValueError('packing requires finite positive rectangle dimensions')
    lb = math.sqrt(sum(w * h for w, h in rects))
    lb = max(lb, max(max(r) for r in rects))
    if not math.isfinite(lb):
        raise ValueError('packing dimensions overflow')
    lo, hi = lb, lb
    for attempt in range(96):
        if maxrects(rects, hi, hi) is not None:
            break
        hi *= 1.1
    else:
        raise ValueError('packing search exceeded 96 growth trials')
    while hi - lo > 1:
        mid = (lo + hi) / 2
        if maxrects(rects, mid, mid) is None:
            lo = mid
        else:
            hi = mid
    assert maxrects(rects, hi, hi) is not None
    return hi


def chart_rect(polys, g):
    shape = unary_union([Polygon(p).buffer(0) for p in polys])
    r = np.asarray(shape.minimum_rotated_rectangle.exterior.coords)[:4]
    w = np.linalg.norm(r[1] - r[0]); h = np.linalg.norm(r[2] - r[1])
    return (w + g, h + g), shape.area, shape.length


def measure(charts, g=16.):
    rects, area, per = [], 0., 0.
    for c in charts:
        (w, h), a, l = chart_rect(c, g)
        rects.append((w, h)); area += a; per += l
    L = min_side(rects)
    return dict(page_side_texels=L, charts=len(charts), filled_texels=area,
                packing_efficiency=area / (L * L), exact_area_lower_bound_side=math.sqrt(area + g / 2 * per),
                padded_bbox_area=sum(w * h for w, h in rects))


if __name__ == '__main__':
    sq = lambda n, s=100.: [[[[0, 0], [s, 0], [s, s], [0, s]]] for _ in range(n)]
    for n, expect in ((16, 464.), (9, 348.), (8, 348.), (4, 232.), (1, 116.)):
        m = measure(sq(n))
        print(f'control {n:2} squares: L*={m["page_side_texels"]:.1f} expected {expect} ->',
              'OK' if abs(m['page_side_texels'] - expect) <= 1.01 else 'FAIL')
    # mixed control: 2 rectangles 300x100 + 1 square 100 fits exactly in 316? (known 332 with padding)
    m = measure([[[[0, 0], [300, 0], [300, 100], [0, 100]]]] * 3)
    print('control 3 strips 300x100: L*=%.1f expected 348 (3 stacked strips of 116 in 316 width)' % m['page_side_texels'])
