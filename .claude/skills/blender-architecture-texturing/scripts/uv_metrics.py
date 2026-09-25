"""World-space, two-axis UV density and fixed-density rectangle packing.

NumPy only; no Blender dependency. Pixel dimensions may be rectangular. Pattern
frequency in a tiled source shader is deliberately not treated as delivery density.
"""
import math
import numpy as np


def triangle_metrics(xyz, uv, size):
    p = np.asarray(xyz, dtype=float)
    q = np.asarray(uv, dtype=float) * np.asarray(size, dtype=float)
    if p.shape != (3, 3) or q.shape != (3, 2):
        raise ValueError('Expected three world-space XYZ and UV coordinates')
    if not np.isfinite(p).all() or not np.isfinite(q).all() or min(size) <= 0:
        raise ValueError('Nonfinite data or invalid image size')
    e1, e2 = p[1] - p[0], p[2] - p[0]
    length = np.linalg.norm(e1)
    area = np.linalg.norm(np.cross(e1, e2)) / 2
    if length <= 1e-12 or area <= 1e-12:
        raise ValueError('Degenerate world triangle')
    along = np.dot(e1, e2) / length
    across = 2 * area / length
    jacobian = np.column_stack((q[1] - q[0], q[2] - q[0])) @ np.linalg.inv(
        [[length, along], [0, across]])
    axes = np.linalg.svd(jacobian, compute_uv=False)
    if axes[1] <= 1e-9:
        raise ValueError('Degenerate UV triangle')
    return dict(area=float(area), high=float(axes[0]), low=float(axes[1]),
                equivalent=float(math.sqrt(axes[0] * axes[1])),
                anisotropy=float(axes[0] / axes[1]),
                mirrored=bool(np.linalg.det(jacobian) < 0))


def weighted_quantile(values, weights, q):
    values, weights = np.asarray(values), np.asarray(weights)
    if not len(values) or weights.sum() <= 0:
        raise ValueError('Empty distribution')
    order = np.argsort(values)
    cumulative = np.cumsum(weights[order])
    return float(values[order[min(len(order)-1, np.searchsorted(cumulative, q*cumulative[-1]))]])


def density_summary(rows, target, tolerance=.20, max_anisotropy=1.5):
    if target <= 0 or not 0 <= tolerance < 1 or max_anisotropy < 1:
        raise ValueError('Invalid density profile')
    area = sum(r['area'] for r in rows)
    if area <= 0:
        raise ValueError('No valid triangles')
    bad = [i for i, r in enumerate(rows) if r['low'] < target*(1-tolerance)
           or r['high'] > target*(1+tolerance) or r['anisotropy'] > max_anisotropy]
    return dict(target=target, tolerance=tolerance, max_anisotropy=max_anisotropy,
                area=area, failing_triangles=bad,
                failing_area_fraction=sum(rows[i]['area'] for i in bad)/area,
                low_p10=weighted_quantile([r['low'] for r in rows], [r['area'] for r in rows], .1),
                equivalent_median=weighted_quantile([r['equivalent'] for r in rows], [r['area'] for r in rows], .5),
                high_p90=weighted_quantile([r['high'] for r in rows], [r['area'] for r in rows], .9))


def pack_rectangles(rectangles, size, padding, max_pages):
    """Guillotine packing with 90-degree rotations; never scales supplied rectangles.

    Each input is (unique id, width_px, height_px). Outputs padded disjoint bounds.
    Raises on overflow instead of silently changing texel density or page count.
    """
    if size <= 0 or padding < 0 or max_pages < 1:
        raise ValueError('Invalid packing profile')
    if len({r[0] for r in rectangles}) != len(rectangles):
        raise ValueError('Repeated chart id')
    pending = []
    for key, w, h in rectangles:
        if min(w, h) <= 0 or not math.isfinite(w+h):
            raise ValueError(f'Invalid rectangle {key}')
        rw, rh = math.ceil(w)+2*padding, math.ceil(h)+2*padding
        if max(rw, rh) > size:
            raise ValueError(f'Chart {key} exceeds page size at requested density')
        pending.append((key, rw, rh))
    pending.sort(key=lambda r: (max(r[1:]), r[1]*r[2]), reverse=True)
    free = [[(0, 0, size, size)]]; placed = {}
    for key, w, h in pending:
        best = None
        for page, spaces in enumerate(free):
            for i, (x, y, fw, fh) in enumerate(spaces):
                for rot, rw, rh in [(False, w, h), (True, h, w)]:
                    if rw <= fw and rh <= fh:
                        score = (fw*fh-rw*rh, min(fw-rw, fh-rh), page, i)
                        if best is None or score < best[0]:
                            best = (score, page, i, rot, rw, rh)
        if best is None:
            if len(free) < max_pages:
                page = len(free); free.append([])
            else:
                raise ValueError(f'Packing exceeds {max_pages} page(s); keep density and revise chart/asset budget')
            free[page].append((0, 0, size, size))
            best = ((0,), page, len(free[page])-1, False, w, h)
        _, page, index, rot, rw, rh = best
        x, y, fw, fh = free[page].pop(index)
        # Disjoint cuts. Keep the longer leftover dimension in one free block.
        if fw-rw > fh-rh:
            parts = [(x+rw, y, fw-rw, fh), (x, y+rh, rw, fh-rh)]
        else:
            parts = [(x, y+rh, fw, fh-rh), (x+rw, y, fw-rw, rh)]
        free[page].extend(r for r in parts if r[2] > 0 and r[3] > 0)
        placed[key] = dict(page=page, x=x+padding, y=y+padding, rotated=rot,
                           padded_bounds=[x, y, x+rw, y+rh])
    return placed
