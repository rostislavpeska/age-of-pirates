"""The map disc for a lobby minimap, from two captures of the EXTENDED in-game minimap (camera elsewhere in each).

    python minimap_disc.py A.png B.png OUT_disc.png [--mask MASK.png] [--fit] [--cx X --cy Y --r R]

1. Capture A is the base: one moment, every unit icon as it stood. Only A's own camera-view outline is replaced
   from B: the connected pieces of the A/B difference where A is the lighter one and which are long and thin. The
   small blobs are icons that moved between the captures (fish, herds) and stay as A has them. (A "darker pixel
   wins" merge deletes or doubles those icons, measured on the Danube 2026-10-07.)
2. The disc is cut 1.5 px inside the in-game frame's inner edge and keeps the minimap's own dark edge shading
   (the finished lobby images keep it).
3. Lanczos-resized onto a 512 x 512 canvas: opaque out to r 225.5 px around 256 / 256, a 1 px soft edge to 226.5
   (the template's ring layers start at r 226; the template's own map discs span 30..482).

The frame circle: measured at 2880 x 1800 (Danube, 2026-10-07: centre 2369.5 / 1259.5, inner edge r 483.9, 665 of
716 rays within 2.5 px). --fit re-measures it from capture A: the first green -> brown step along 720 rays. It needs
land (green) at the map's edge; for water or desert edges pass the measured circle."""
import argparse
import math

import numpy as np
from PIL import Image

OUT_R = 226.0


def fit_circle(a, cx0, cy0, r_lo, r_hi):
    pts = []
    for k in range(720):
        t = math.radians(k / 2)
        prev_green = False
        for r10 in range(int(r_lo * 10), int(r_hi * 10), 5):
            r = r10 / 10
            x, y = cx0 + r * math.cos(t), cy0 - r * math.sin(t)
            xi, yi = int(round(x)), int(round(y))
            if not (0 <= xi < a.shape[1] and 0 <= yi < a.shape[0]):
                break
            R_, G_, B_ = a[yi, xi]
            if G_ > R_ + 4:
                prev_green = True
            elif prev_green and R_ > G_ + 3 and B_ < R_:
                pts.append((x, y))
                break
    p = np.array(pts, dtype=float)

    def kasa(q):
        A = np.column_stack([2 * q[:, 0], 2 * q[:, 1], np.ones(len(q))])
        cx, cy, c = np.linalg.lstsq(A, (q ** 2).sum(axis=1), rcond=None)[0]
        return cx, cy, math.sqrt(c + cx * cx + cy * cy)

    cx, cy, R = kasa(p)
    keep = np.ones(len(p), bool)
    for _ in range(4):
        d = np.hypot(p[:, 0] - cx, p[:, 1] - cy) - R
        keep = np.abs(d) < 2.5
        cx, cy, R = kasa(p[keep])
    return cx, cy, R, len(p), int(keep.sum())


def outline_only(a, b, inside):
    diff = (np.abs(a - b).max(axis=2) > 6) & inside
    lighter_a = diff & (a.max(axis=2) > b.max(axis=2))
    take_b = np.zeros_like(diff)
    seen = np.zeros_like(diff)
    H, W = diff.shape
    for y0, x0 in zip(*np.nonzero(lighter_a)):
        if seen[y0, x0]:
            continue
        stack, comp = [(y0, x0)], []
        seen[y0, x0] = True
        while stack:
            y, x = stack.pop()
            comp.append((y, x))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < H and 0 <= nx < W and lighter_a[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
        ys, xs = zip(*comp)
        span = max(max(ys) - min(ys), max(xs) - min(xs))
        if span >= 40 and len(comp) < 0.25 * span * span:
            for y, x in comp:
                take_b[y, x] = True
    grown = take_b.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            grown |= np.roll(np.roll(take_b, dy, axis=0), dx, axis=1)
    return diff, grown & diff


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('a')
    ap.add_argument('b')
    ap.add_argument('out')
    ap.add_argument('--mask')
    ap.add_argument('--fit', action='store_true')
    ap.add_argument('--cx', type=float, default=2369.5)
    ap.add_argument('--cy', type=float, default=1259.5)
    ap.add_argument('--r', type=float, default=483.9)
    o = ap.parse_args(argv)
    A = Image.open(o.a).convert('RGB')
    B = Image.open(o.b).convert('RGB')
    a = np.asarray(A).astype(np.int16)
    b = np.asarray(B).astype(np.int16)
    cx, cy, R = o.cx, o.cy, o.r
    if o.fit:
        cx, cy, R, n, on = fit_circle(a, o.cx, o.cy, o.r * 0.91, o.r * 1.075)
        print(f'fitted frame circle: centre ({cx:.1f}, {cy:.1f}) r {R:.1f} ({on} of {n} rays within 2.5 px)')
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    inside = np.hypot(xx - cx, yy - cy) <= R + 2
    diff, take_b = outline_only(a, b, inside)
    print(f'differences inside the disc: {int(diff.sum())} px; replaced from B (the outline in A): {int(take_b.sum())}; '
          f'kept from A: {int((diff & ~take_b).sum())}')
    if take_b.sum() == 0:
        print('WARNING: no outline found in A - check that the camera outline lies inside the disc in capture A')
    m = np.where(take_b[:, :, None], b, a).astype(np.uint8)
    if o.mask:
        mk = np.zeros(a.shape, np.uint8)
        mk[take_b] = (255, 80, 80)
        mk[diff & ~take_b] = (80, 160, 255)
        Image.fromarray(mk).crop((int(cx - R - 10), int(cy - R - 10), int(cx + R + 10), int(cy + R + 10))).save(o.mask)
    r_crop = R - 1.5
    side = int(round(2 * OUT_R))
    part = Image.fromarray(m).resize((side, side), Image.LANCZOS, box=(cx - r_crop, cy - r_crop, cx + r_crop, cy + r_crop))
    disc = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
    disc.paste(part, (256 - side // 2, 256 - side // 2))
    d = np.asarray(disc).astype(np.float64)
    gy, gx = np.mgrid[0:512, 0:512]
    rr = np.hypot(gx + 0.5 - 256.0, gy + 0.5 - 256.0)
    d[:, :, 3] = np.clip(OUT_R + 0.5 - rr, 0.0, 1.0) * 255.0
    Image.fromarray(d.round().astype(np.uint8), 'RGBA').save(o.out)
    print('disc written:', o.out)


if __name__ == '__main__':
    main()
