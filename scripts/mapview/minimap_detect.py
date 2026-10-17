"""Image analysis of the minimap (PIL only, offline on screenshots): the drawn disc, the camera trapezoid, player blobs.

Measured on real 2560x1080 frames (2026-09-24 review): the editor minimap (Paris generation) and the in-match HUD
minimap (Istanbul). Both have the same ring, read from the inside out along any radius:

    map content ... dark edge line (the drawn disc's rim) | ~1 px (41,35,25) | dark-gold band ~4 px (79,62,19)
    | bright-gold line 1-2 px (206-222, 170-182, 82-90) | dark (40,35,24) | outside

Editor: edge 130, band 131/132-135, bright line 136-137 px from the centre. Match: edge ~147, band 148/149-152,
bright line 153-154. The map's longer side touches the disc at the edge line (the editor's black interior spans
exactly that; the icon fit on the four Paris explorer stars gives radius 130.29, residual 0.36 px - the review's
"command posts" at 130.2 were in fact the Explorers, read one record late by the census).

measure_disc() fits a circle to the bright-gold line (about a thousand pixels, no icons, RANSAC against the
N/S/E/W markers and the HUD buttons' gold frames), then reads the disc edge per ray INWARD from that line as the
inner end of the dark-gold band touching it, minus 1.5 px, refuses a ring whose line / rim ratio is off, and
returns probe pixels on the bright line for a "is the minimap on screen" check (a modal dialog dims the screen to
about 0.63x and fails every probe).

find_trapezoid() finds the camera's white outline by shape - two horizontal edges, the far (top) one wider,
joined by legs - and returns the intersection of its diagonals, which is where the screen centre projects
(a centroid of the outline is 7-10 px off toward the wide edge). Trade-route lines, X markers and icons are
white too, which is why colour alone cannot be used. An outline cut by the rim comes back clipped, rebuilt by
symmetry when one edge is intact, else with look_at None.

first_black_along() walks a ray to the first run of black pixels: the map rectangle's edge on the editor minimap,
for calibrate.py edges (the disc outside a non-square map is drawn black).

player_star() finds a player's STAR, which marks the player's EXPLORER, not the start building (2026-09-24, from
the save headers at tag-49: on the Paris, Florence and Versailles editor frames of 2026-09-20 the 11 stars found
sit 0.7-1.4 px from their Explorer's predicted pixel; Paris's deSPCCommandPost glyph is the same-colour shape drawn
BEHIND the star, 4-7 px away from the star's centre). The star is drawn over that glyph with a dark outline, so
the colour mask is eroded down to its ultimate cores and the core whose surroundings look most like a five-point
star (inside the colour, a 1 px band outside it not) is returned.
"""
from __future__ import annotations

import math
import random
from dataclasses import dataclass, field, asdict
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

Point = Tuple[float, float]


# ----------------------------------------------------------------------------- colour classes
def is_bright_gold(rgb) -> bool:
    r, g, b = rgb[0], rgb[1], rgb[2]
    return r >= 150 and 120 <= g <= 200 and 55 <= b <= 110 and r - b >= 80 and 0.72 <= g / max(r, 1) <= 0.90


def is_dark_gold(rgb) -> bool:
    r, g, b = rgb[0], rgb[1], rgb[2]
    return 60 <= r <= 105 and 45 <= g <= 85 and b <= 40 and r - b >= 40


def is_ring_dark(rgb) -> bool:
    """The dark line just outside the bright-gold line: (40,35,24), (41,33,27), (49,40,25) on both screens."""
    r, g, b = rgb[0], rgb[1], rgb[2]
    return 30 <= r <= 62 and 24 <= g <= 50 and 16 <= b <= 36 and 6 <= r - b <= 32 and r >= g >= b - 2


_DIRS = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1))


def is_ring_pixel(px, x: int, y: int, W: int, H: int) -> bool:
    """A bright-gold pixel with the ring's layering across it: dark-gold band 1-4 px to one side, the dark outer line
    1-3 px to the other. Gold-coloured terrain (sand, city ground behind the editor's minimap) lacks it."""
    if not is_bright_gold(px[x, y]):
        return False
    for dx, dy in _DIRS:
        inner = any(0 <= x - k * dx < W and 0 <= y - k * dy < H and is_dark_gold(px[x - k * dx, y - k * dy]) for k in (1, 2, 3, 4))
        if not inner:
            continue
        if any(0 <= x + k * dx < W and 0 <= y + k * dy < H and is_ring_dark(px[x + k * dx, y + k * dy]) for k in (1, 2, 3)):
            return True
    return False


def _load(img):
    """A PIL image or a path -> (image, pixel access)."""
    from PIL import Image
    im = img if hasattr(img, "load") and hasattr(img, "size") else Image.open(img)
    im = im.convert("RGB")
    return im, im.load()


# ----------------------------------------------------------------------------- circles
def fit_circle(points: Sequence[Point]) -> Tuple[float, float, float]:
    """Algebraic least-squares circle (Kasa): (cx, cy, r)."""
    n = len(points)
    if n < 3:
        raise ValueError("need 3 points")
    sx = sum(p[0] for p in points) / n
    sy = sum(p[1] for p in points) / n
    suu = suv = svv = suuu = svvv = suvv = svuu = 0.0
    for x, y in points:
        u, v = x - sx, y - sy
        suu += u * u; svv += v * v; suv += u * v
        suuu += u ** 3; svvv += v ** 3; suvv += u * v * v; svuu += v * u * u
    det = suu * svv - suv * suv
    if abs(det) < 1e-9:
        raise ValueError("degenerate points")
    b1 = 0.5 * (suuu + suvv)
    b2 = 0.5 * (svvv + svuu)
    uc = (b1 * svv - b2 * suv) / det
    vc = (b2 * suu - b1 * suv) / det
    r = math.sqrt(uc * uc + vc * vc + (suu + svv) / n)
    return uc + sx, vc + sy, r


def _circle3(a: Point, b: Point, c: Point) -> Optional[Tuple[float, float, float]]:
    ax, ay = a; bx, by = b; cx, cy = c
    d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
    if abs(d) < 1e-9:
        return None
    ux = ((ax * ax + ay * ay) * (by - cy) + (bx * bx + by * by) * (cy - ay) + (cx * cx + cy * cy) * (ay - by)) / d
    uy = ((ax * ax + ay * ay) * (cx - bx) + (bx * bx + by * by) * (ax - cx) + (cx * cx + cy * cy) * (bx - ax)) / d
    return ux, uy, math.hypot(ax - ux, ay - uy)


@dataclass
class DiscMeasurement:
    cx: float                     # disc centre, screen pixels
    cy: float
    r_disc: float                 # the drawn disc's rim (the map's longer side touches it)
    r_line: float                 # the bright-gold line
    n_line_px: int                # bright-gold pixels on the fitted line
    rms_line_px: float            # their rms distance from the fitted circle
    n_rays: int                   # rays that produced a band start
    ray_spread_px: float          # interquartile range of the per-ray band starts
    probes: List[Dict] = field(default_factory=list)   # [{"x", "y", "rgb"}] on the bright line
    box: Tuple[int, int, int, int] = (0, 0, 0, 0)

    def to_dict(self) -> Dict:
        return asdict(self)


RING_RATIO = 1.0435           # r_line / r_disc: 1.0432-1.0438 on all 76 full-resolution frames (2026-09-24 review:
RING_RATIO_TOL = 0.004        # editor 136.18 / 130.5, match 153.35 / 147.0); 0.004 is about 0.6 px of rim
BAND_MAX_SKIP = 4             # pixels from round(r_line) inward to the band's first dark-gold pixel: 2-3 measured
BAND_MAX_RUN = 6              # the dark-gold band is 2-4 px thick; a longer run has merged with same-coloured terrain


def _band_inner_end(px, W: int, H: int, cx: float, cy: float, r_line: float, a: float) -> Tuple[Optional[int], str]:
    """One ray, scanned INWARD from the bright line: the dark-gold run that touches the line (its first pixel at most
    BAND_MAX_SKIP + 1 px inside round(r_line)) and its inner end. A 1 px dark-gold pixel between the bright line and
    the ring-dark line (11 of 288 rays on the match crop, 4 on the editor crop) is not the band when a longer run
    follows within reach. (radius, 'ok') | (None, 'none' | 'long' | 'edge')."""
    ca, sa = math.cos(a), math.sin(a)
    start = int(round(r_line))
    depth = BAND_MAX_SKIP + 1 + BAND_MAX_RUN + 2
    cls = []
    for k in range(depth):
        rr = start - k
        x = int(round(cx + rr * ca)); y = int(round(cy - rr * sa))
        if not (0 <= x < W and 0 <= y < H):
            return None, "edge"
        cls.append(is_dark_gold(px[x, y]))
    runs, k = [], 0                                   # maximal dark-gold runs as (outer k, inner k)
    while k < depth:
        if cls[k]:
            k0 = k
            while k + 1 < depth and cls[k + 1]:
                k += 1
            runs.append((k0, k))
        k += 1
    near = [r_ for r_ in runs if r_[0] <= BAND_MAX_SKIP + 1]
    if not near:
        return None, "none"
    run = next((r_ for r_ in near if r_[1] > r_[0]), near[0])
    if run[1] - run[0] + 1 > BAND_MAX_RUN or run[1] == depth - 1:
        return None, "long"
    return start - run[1], "ok"


def measure_disc(img, box: Optional[Tuple[int, int, int, int]] = None, r_min: float = 90.0, r_max: float = 260.0,
                 seed: int = 1, n_probes: int = 12) -> DiscMeasurement:
    """Measure the minimap disc inside box (default: the right-most 700 x the bottom-most 500 px of the frame, where
    both the editor's and the match's minimap live at 2560x1080). Raises ValueError when no ring is found, when the
    band is found on fewer than 90 rays, or when the ring's geometry is off: |r_line / r_disc - RING_RATIO| >
    RING_RATIO_TOL (review F1, 2026-09-24).

    The rim per ray is read INWARD from the bright line: the dark-gold run touching it, its inner end minus 1.5 px
    (the dark edge line sits 1 px inside the band, the map ends half a pixel further in). A run longer than
    BAND_MAX_RUN has merged with same-coloured map content and the ray is dropped. The old outward scan (first
    dark-gold pixel from r_line - 14) took olive / mud terrain next to the rim for the band: the review painted a
    12 px (70,80,30) band inside the rim of the committed crops and read r_disc 120.5 instead of 130.5 (editor) and
    137.5 instead of 147.0 (match) with every gate passing."""
    im, px = _load(img)
    W, H = im.size
    if box is None:
        box = (max(0, W - 700), max(0, H - 500), W, H)
    x0, y0, x1, y1 = (max(0, box[0]), max(0, box[1]), min(W, box[2]), min(H, box[3]))
    gold = [(x, y) for y in range(y0, y1) for x in range(x0, x1) if is_ring_pixel(px, x, y, W, H)]
    if len(gold) < 60:
        raise ValueError("no minimap ring in box %s (%d ring px) - is a dialog dimming the screen, or the minimap hidden?" % ((x0, y0, x1, y1), len(gold)))
    rnd = random.Random(seed)
    best = None
    for _ in range(1500):
        c = _circle3(*rnd.sample(gold, 3))
        if c is None or not (r_min <= c[2] <= r_max):
            continue
        cx, cy, r = c
        n = sum(1 for x, y in gold if abs(math.hypot(x - cx, y - cy) - r) <= 1.5)
        if best is None or n > best[0]:
            best = (n, c)
    if best is None or best[0] < math.pi * r_min:          # at least half the circumference of the smallest ring
        raise ValueError("no circle of radius %s-%s px among %d ring px (best %s)" % (r_min, r_max, len(gold), best and best[0]))
    cx, cy, r = best[1]
    for _ in range(3):                                   # refine on the inliers
        inl = [(x, y) for x, y in gold if abs(math.hypot(x - cx, y - cy) - r) <= 1.8]
        cx, cy, r = fit_circle(inl)
    inl = [(x, y) for x, y in gold if abs(math.hypot(x - cx, y - cy) - r) <= 1.8]
    rms = math.sqrt(sum((math.hypot(x - cx, y - cy) - r) ** 2 for x, y in inl) / len(inl))
    # the disc rim per ray: the inner end of the dark-gold band that touches the bright line, minus 1.5 px; skip the
    # compass markers (0/90/180/270 +-9)
    starts = []
    dropped = {"none": 0, "long": 0, "edge": 0}
    for k in range(360):
        deg = k + 0.5
        if min(abs(((deg - m + 180) % 360) - 180) for m in (0, 90, 180, 270)) < 9:
            continue
        end, why = _band_inner_end(px, W, H, cx, cy, r, math.radians(deg))
        if end is None:
            dropped[why] += 1
        else:
            starts.append(end)
    if len(starts) < 90:
        raise ValueError("the ring's dark-gold band was found on only %d rays (dropped: %d no band next to the bright "
                         "line, %d band merged with same-coloured map content, %d off the image)"
                         % (len(starts), dropped["none"], dropped["long"], dropped["edge"]))
    starts.sort()
    q1, q3 = starts[len(starts) // 4], starts[(3 * len(starts)) // 4]
    mid = starts[len(starts) // 4:(3 * len(starts)) // 4 + 1]
    r_disc = sum(mid) / len(mid) - 1.5
    ratio = r / r_disc
    if abs(ratio - RING_RATIO) > RING_RATIO_TOL:
        raise ValueError("the ring's geometry is off: bright line %.2f / rim %.2f = %.4f, measured %.4f +- %.3f on "
                         "every frame - map content next to the rim was probably read as the ring's band"
                         % (r, r_disc, ratio, RING_RATIO, RING_RATIO_TOL))
    # probes on the bright line at 30, 60, ... 360 degrees. Four of the twelve fall ON the N/E/S/W markers (review F4);
    # the markers are static bright-gold UI, so a probe there tests "on screen and undimmed" as well as one on the
    # line. The angles stay: records and tests pin these probes (8 of 12 found on both 2026-09-24 crops; 15, 45, ...
    # would give 9 and move every stored probe).
    probes = []
    for k in range(n_probes):
        deg = 360.0 * (k + 0.5) / n_probes + 15.0
        a = math.radians(deg)
        bestp = None
        for dr in (0.0, -0.5, 0.5, -1.0, 1.0):
            x = int(round(cx + (r + dr) * math.cos(a))); y = int(round(cy - (r + dr) * math.sin(a)))
            if 0 <= x < W and 0 <= y < H and is_bright_gold(px[x, y]):
                bestp = {"x": x, "y": y, "rgb": list(px[x, y])}
                break
        if bestp:
            probes.append(bestp)
    return DiscMeasurement(round(cx, 2), round(cy, 2), round(r_disc, 2), round(r, 2), len(inl), round(rms, 3),
                           len(starts), float(q3 - q1), probes, (x0, y0, x1, y1))


def probes_ok(img, probes: Iterable[Dict], tol: int = 30, need_frac: float = 0.75) -> Tuple[bool, int, int]:
    """The minimap is on screen and undimmed: at least need_frac of the probes within tol per channel."""
    im, px = _load(img)
    probes = list(probes)
    good = 0
    for p in probes:
        x, y = p["x"], p["y"]
        if 0 <= x < im.size[0] and 0 <= y < im.size[1]:
            c = px[x, y]
            if all(abs(c[i] - p["rgb"][i]) <= tol for i in range(3)):
                good += 1
    return (len(probes) > 0 and good >= need_frac * len(probes)), good, len(probes)


# ----------------------------------------------------------------------------- the camera trapezoid
TRAP_CUT_PX = 2.5            # an outline end this close to the drawn rim is cut: the ring hides the rest of it


def find_trapezoid(img, cx: float, cy: float, radius: float, thr: int = 250, min_run: int = 12) -> Optional[Dict]:
    """The camera outline on the minimap, or None when no outline is seen:
        {look_at, TL, TR, BL, BR, leg_support, clipped, method, rebuilt}
    look_at = the intersection of the diagonals (where the screen centre projects), or None when the rim hides too
    much of the outline to place it. The outline is symmetric about a vertical line (the far edge on top, wider).
    method:
    - 'outline': the outline as seen. clipped False when every corner is at least TRAP_CUT_PX inside the rim; clipped
      True when exactly one corner is that close but the seen shape still passes (look_at from the seen corners, as
      before this fix: gen_paris.png's bottom-left corner, 130.4 px from the centre).
    - 'mirror': one horizontal edge ends at the rim on one side (cut); it is rebuilt by symmetry about the other,
      intact edge's centre (rebuilt names the corner) when the legs, checked on their visible rows only, support the
      rebuilt shape better than the seen one; clipped True, look_at from the rebuilt corners.
    - 'partial': both ends of one side at the rim, the other side's leg intact: clipped True, look_at None, the cut
      side's corners None.
    - 'legs': one edge beyond the rim; the other edge and its two legs traced: clipped True, look_at None.
    Review F2 (2026-09-24): 18 of the 76 real frames with a disc returned None although the outline was on screen -
    the editor camera at London P1's end runs under the ring (ldn_hb2_generated: top run 2216..2260 at y 803 cut on
    the left, bottom 2207..2244), a leg outside the disc (ldn_s4242p_generated), a zoomed-out camera whose far edge is
    beyond the rim (ub_unitbench_ctl_s4242_generated). Re-run on the same 76 frames after the fix: the 58 earlier
    answers keep their look_at (to 0.1 px; one flag changes: ldn_s4242m_generated is now clipped, its top-right
    corner 128.4 px from the centre on a 130.5 rim, inside the band that was 2.0 px before); of the 18, 9 'mirror',
    4 'partial', 4 'legs', and None on ldn_s4242b_picked (one line from the rim, no edge)."""
    im, px = _load(img)
    W, H = im.size
    r = int(radius)

    def white(x, y):
        return 0 <= x < W and 0 <= y < H and min(px[x, y]) >= thr

    def near_rim(x, y, pad=0.0):
        return math.hypot(x - cx, y - cy) >= radius - TRAP_CUT_PX - pad

    def leg_rows(x0, y0, x1, y1):
        """(white rows, visible rows) along a leg from (x0, y0) down to (x1, y1), the rim's hidden rows skipped."""
        h = y1 - y0
        hit = rows = 0
        for k in range(1, int(h)):
            t = k / h
            yy = int(round(y0 + k))
            lx = x0 + (x1 - x0) * t
            if near_rim(lx, yy):
                continue
            rows += 1
            hit += any(white(int(round(lx)) + d, yy) for d in (-1, 0, 1))
        return hit, rows

    runs = []
    for y in range(int(cy) - r, int(cy) + r + 1):
        x = int(cx) - r
        while x <= int(cx) + r:
            if math.hypot(x - cx, y - cy) <= radius and white(x, y):
                s = x
                while x <= int(cx) + r and white(x, y):
                    x += 1
                if x - s >= min_run:
                    runs.append((y, s, x - 1))
            x += 1
    edges = []                                           # [x0, x1, ysum, n, ylast] - 1 px stair-steps merged
    for y, a, b in sorted(runs):
        for e in edges:
            if abs(y - e[4]) <= 1 and a <= e[1] + 2 and b >= e[0] - 2:
                e[0] = min(e[0], a); e[1] = max(e[1], b); e[2] += y * (b - a + 1); e[3] += b - a + 1; e[4] = y
                break
        else:
            edges.append([a, b, y * (b - a + 1), b - a + 1, y])
    edges = [(e[0], e[1], e[2] / e[3]) for e in edges]
    best = mirror = partial = None
    for tx0, tx1, ty in edges:
        for bx0, bx1, by in edges:
            h = by - ty
            if not (8 <= h <= 150):
                continue
            cut = {"TL": near_rim(tx0, ty), "TR": near_rim(tx1, ty), "BL": near_rim(bx0, by), "BR": near_rim(bx1, by)}
            if not any(cut.values()):                        # the whole outline inside the disc
                tw, bw = tx1 - tx0, bx1 - bx0
                if tw < 1.2 * bw or abs((tx0 + tx1) / 2 - (bx0 + bx1) / 2) > 4:
                    continue
                support = rows = 0
                for k in range(1, int(h)):
                    t = k / h
                    yy = int(round(ty + k))
                    lx = tx0 + (bx0 - tx0) * t
                    rx = tx1 + (bx1 - tx1) * t
                    rows += 1
                    ok_l = any(white(int(round(lx)) + d, yy) for d in (-1, 0, 1))
                    ok_r = any(white(int(round(rx)) + d, yy) for d in (-1, 0, 1))
                    support += ok_l and ok_r
                score = support / max(rows, 1)
                if score >= 0.7 and (best is None or score > best[0]):
                    best = (score, (tx0, ty), (tx1, ty), (bx0, by), (bx1, by))
                continue
            cuts = [k for k in ("TL", "TR", "BL", "BR") if cut[k]]
            # one side hidden (both its ends cut; the second may sit up to 1.5 px further in, where the hidden leg
            # hugs the rim - ldn_s4242g: 129.2 and 127.9 px on a 130.5 rim): confirm the other side's leg
            near = {k: near_rim(*p, pad=1.5) for k, p in (("TL", (tx0, ty)), ("TR", (tx1, ty)), ("BL", (bx0, by)),
                                                             ("BR", (bx1, by)))}
            for side, other in (("L", "R"), ("R", "L")):
                if not (near["T" + side] and near["B" + side] and (cut["T" + side] or cut["B" + side])):
                    continue
                if cut["T" + other] or cut["B" + other]:
                    continue
                ox_t, ox_b = (tx1, bx1) if other == "R" else (tx0, bx0)
                if (ox_t - ox_b) * (1 if other == "R" else -1) < 1:        # the far edge sticks out on that side
                    continue
                hit, rows = leg_rows(ox_t, ty, ox_b, by)
                if rows >= 6 and hit >= 0.7 * rows and (partial is None or hit / rows > partial[0]):
                    corners = {"TL": (tx0, ty), "TR": (tx1, ty), "BL": (bx0, by), "BR": (bx1, by)}
                    for k in ("T" + side, "B" + side):
                        corners[k] = None
                    partial = (hit / rows, corners)
            if len(cuts) != 1:
                continue
            # one end cut: the outline as seen (the end may just touch the rim) or the cut edge rebuilt by symmetry
            # about the intact edge's centre, whichever the visible legs support better (ties: as seen)
            c = cuts[0]
            if c[0] == "T":
                axis = (bx0 + bx1) / 2.0
                ntx0, ntx1, nbx0, nbx1 = (2 * axis - tx1, tx1, bx0, bx1) if c == "TL" else (tx0, 2 * axis - tx0, bx0, bx1)
            else:
                axis = (tx0 + tx1) / 2.0
                ntx0, ntx1, nbx0, nbx1 = (tx0, tx1, 2 * axis - bx1, bx1) if c == "BL" else (tx0, tx1, bx0, 2 * axis - bx0)
            shapes = [((tx0, tx1, bx0, bx1), [], abs((tx0 + tx1) / 2 - (bx0 + bx1) / 2) <= 4)]
            if ntx0 <= tx0 + 1 and ntx1 >= tx1 - 1 and nbx0 <= bx0 + 1 and nbx1 >= bx1 - 1:   # hidden end beyond
                shapes.append(((ntx0, ntx1, nbx0, nbx1), [c], True))
            for (a0, a1, b0, b1), rebuilt, aligned in shapes:
                if not aligned or a1 - a0 < 1.2 * (b1 - b0):
                    continue
                hl, rl = leg_rows(a0, ty, b0, by)
                hr, rr = leg_rows(a1, ty, b1, by)
                if rl + rr < h - 1 or any(n >= 3 and hh < 0.7 * n for hh, n in ((hl, rl), (hr, rr))):
                    continue
                score = (hl + hr) / float(rl + rr)
                key = (score, 0 if rebuilt else 1)
                if score >= 0.7 and (mirror is None or key > mirror[0]):
                    mirror = (key, (a0, ty), (a1, ty), (b0, by), (b1, by), rebuilt)
    if best is not None:
        score, TL, TR, BL, BR = best
        ix, iy = _intersect(TL, BR, TR, BL)
        return {"look_at": (round(ix, 1), round(iy, 1)), "TL": TL, "TR": TR, "BL": BL, "BR": BR,
                "leg_support": round(score, 2), "clipped": False, "method": "outline", "rebuilt": []}
    if mirror is not None:
        (score, _), TL, TR, BL, BR, rebuilt = mirror
        ix, iy = _intersect(TL, BR, TR, BL)
        return {"look_at": (round(ix, 1), round(iy, 1)), "TL": TL, "TR": TR, "BL": BL, "BR": BR,
                "leg_support": round(score, 2), "clipped": True, "method": "mirror" if rebuilt else "outline",
                "rebuilt": rebuilt}
    if partial is not None:
        score, corners = partial
        return dict(look_at=None, leg_support=round(score, 2), clipped=True, method="partial", rebuilt=[], **corners)
    legs = _legs_to_rim(edges, white, near_rim, H)
    if legs is not None:
        return legs
    return None


def _trace_leg(white, x: int, y: int, dy: int, lo: int, hi: int, H: int) -> List[Tuple[int, int]]:
    """Follow a 1 px white line row by row from (x, y) in direction dy, each step within [lo, hi] px sideways of the
    last pixel and nearest to the running slope; stops after two empty rows."""
    pts: List[Tuple[int, int]] = []
    xx, yy, miss, slope = x, y, 0, 0.0
    while miss <= 1 and len(pts) < 400:
        yy += dy
        if not (0 <= yy < H):
            break
        cands = [xx + d for d in range(lo * (miss + 1), hi * (miss + 1) + 1) if white(xx + d, yy)]
        if not cands:
            miss += 1
            continue
        nx = min(cands, key=lambda c: abs(c - (xx + slope * (miss + 1))))
        slope = (nx - xx) / float(miss + 1)
        xx, miss = nx, 0
        pts.append((xx, yy))
    return pts


def _legs_to_rim(edges, white, near_rim, H: int) -> Optional[Dict]:
    """An intact horizontal edge with two straight, mirror-symmetric legs, diverging toward a missing far edge or
    converging toward a missing near edge, at least one of them traced to the rim: {'method': 'legs', 'look_at':
    None, ...}. On the bench frames (ub_unitbench_*_generated, a zoomed-out editor camera on a square desert map)
    one leg ends 98 px from the centre, short of the rim, where the far part of the outline is not drawn; the
    other reaches 127.6 px (rim 130.5)."""
    best = None
    for x0, x1, y in edges:
        if near_rim(x0, y) or near_rim(x1, y):
            continue
        yi = int(round(y))
        for dy, name in ((-1, "bottom"), (1, "top")):       # the visible edge is the bottom one: legs go up
            spread = 1 if dy < 0 else -1                     # +1: the legs part going away from this edge
            left = _trace_leg(white, x0, yi, dy, -3 if spread > 0 else -1, 1 if spread > 0 else 3, H)
            right = _trace_leg(white, x1, yi, dy, -1 if spread > 0 else -3, 3 if spread > 0 else 1, H)
            if len(left) < 8 or len(right) < 8:
                continue
            if not (near_rim(*left[-1], pad=1.5) or near_rim(*right[-1], pad=1.5)):
                continue
            dl, dr = left[-1][0] - x0, right[-1][0] - x1
            if not (spread * dl < -1 and spread * dr > 1):
                continue
            sl, sr = abs(dl) / float(len(left)), abs(dr) / float(len(right))    # px sideways per row
            if abs(sl - sr) > 0.3 * max(sl, sr) + 0.1:
                continue
            if max(_chord_dev(left), _chord_dev(right)) > 1.5:
                continue
            n = min(len(left), len(right))
            if best is None or n > best[0]:
                corners = {"TL": None, "TR": None, "BL": None, "BR": None}
                if name == "bottom":
                    corners.update(BL=(x0, y), BR=(x1, y))
                else:
                    corners.update(TL=(x0, y), TR=(x1, y))
                best = (n, dict(look_at=None, leg_support=1.0, clipped=True, method="legs", rebuilt=[],
                                legs=[list(left[-1]), list(right[-1])], **corners))
    return best[1] if best else None


def _chord_dev(pts: Sequence[Tuple[int, int]]) -> float:
    """The largest distance of a traced leg's pixels from the chord between its ends (a straight leg: <= ~1 px)."""
    (x0, y0), (x1, y1) = pts[0], pts[-1]
    L = math.hypot(x1 - x0, y1 - y0) or 1.0
    return max(abs((x1 - x0) * (y0 - y) - (x0 - x) * (y1 - y0)) / L for x, y in pts)


def _intersect(p1: Point, p2: Point, p3: Point, p4: Point) -> Point:
    (x1, y1), (x2, y2), (x3, y3), (x4, y4) = p1, p2, p3, p4
    d = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    a = x1 * y2 - y1 * x2
    b = x3 * y4 - y3 * x4
    return (a * (x3 - x4) - (x1 - x2) * b) / d, (a * (y3 - y4) - (y1 - y2) * b) / d


# ----------------------------------------------------------------------------- the map rectangle's edge
EDGE_BLACK_MAX = 20          # max channel of the black drawn outside the map rectangle ((0,0,0) on the editor frames)
EDGE_BLACK_RUN = 4           # consecutive black pixels (1 px apart) that start the outside; icon outlines are 1 px


def first_black_along(img, rays: Sequence[Tuple[float, float, float, float, float]], before: float = 12.0,
                      after: float = 8.0, step: float = 0.25, black_max: int = EDGE_BLACK_MAX,
                      run: int = EDGE_BLACK_RUN) -> List[Optional[float]]:
    """rays = [(x0, y0, nx, ny, d_model)]: from (x0, y0) along the unit vector (nx, ny), searched from d_model - before
    to d_model + after in step increments. For each ray: the distance ALONG THE RAY of the centre of the first pixel
    that starts `run` black pixels (the pixel centre projected on the ray, so the answer is not quantised to the
    step), or None when the window holds no such run. On the editor minimap the disc outside a non-square map is
    drawn (0,0,0) and the map's long edges darken over the last 1-2 px (2026-09-24, London live frame and
    gen_paris.png): the first black pixel's centre sits 1.31 px inside the model edge on both sides of London 360 x 686,
    1.59 / 2.07 px on Paris 654 x 360."""
    im, px = _load(img)
    W, H = im.size
    out: List[Optional[float]] = []
    for x0, y0, nx, ny, dm in rays:
        hit = None
        d = max(0.0, dm - before)
        while d <= dm + after:
            ok = True
            first = None
            for k in range(run):
                x = int(round(x0 + (d + k) * nx)); y = int(round(y0 + (d + k) * ny))
                if not (0 <= x < W and 0 <= y < H) or max(px[x, y]) > black_max:
                    ok = False
                    break
                if first is None:
                    first = (x, y)
            if ok:
                hit = (first[0] - x0) * nx + (first[1] - y0) * ny
                break
            d += step
        out.append(hit)
    return out


# ----------------------------------------------------------------------------- player blobs
def chroma(rgb) -> Tuple[float, float, float]:
    s = float(rgb[0] + rgb[1] + rgb[2]) or 1.0
    return rgb[0] / s, rgb[1] / s, rgb[2] / s


def hue_chroma(rgb) -> Tuple[float, float, float]:
    """The chroma of the colour with its grey part removed: (r-m, g-m, b-m) over their sum, m = the smallest channel.
    A modal dialog's dim is not a pure scale but about 0.615 c + 8 (gen_londonext.png, the Open File dialog up,
    2026-09-20: the ring (222,183,90) -> (145,121,63), the red star (255,0,0) -> (165,11,9)); the added grey moves
    plain chroma by 0.11 for a pure player colour and leaves this one within 0.02."""
    m = min(rgb[0], rgb[1], rgb[2])
    r, g, b = rgb[0] - m, rgb[1] - m, rgb[2] - m
    s = float(r + g + b) or 1.0
    return r / s, g / s, b / s


def colour_match(rgb, want: Tuple[float, float, float], tol: float = 0.08, min_sat: int = 40) -> bool:
    """rgb shows the player colour whose hue_chroma is want: saturated enough (max - min >= min_sat, which drops the
    black outlines and grey/white icons) and within tol per hue-chroma channel. Brown city ground (146,107,45) is
    0.12 from yellow and the maroon glyphs (127,51,63) 0.14 from red: both rejected. ORANGE is not separated (review
    F5, 2026-09-24): brown ground's hue chroma (0.620, 0.380, 0) is 0.046 from orange (255,128,0)'s (0.666, 0.334, 0),
    so brown ground matches orange; on the review's 76 frames the best orange terrain core scored 0.786
    (gen_verseilles), 0.780, 0.766 against STAR_MIN_SCORE 0.85 - for orange the star shape is the only margin. A grey
    or white player colour can never match (the saturation floor); only the saturated player colours were measured."""
    if max(rgb[0], rgb[1], rgb[2]) - min(rgb[0], rgb[1], rgb[2]) < min_sat:
        return False
    k = hue_chroma(rgb)
    return abs(k[0] - want[0]) <= tol and abs(k[1] - want[1]) <= tol and abs(k[2] - want[2]) <= tol


def disc_tuple(disc) -> Optional[Tuple[float, float, float]]:
    """(cx, cy, r) from a DiscMeasurement (its drawn rim r_disc), a Calibration-like object (radius_px), a dict with
    cx/cy and r_disc or radius_px, or a 3-sequence. None stays None."""
    if disc is None:
        return None
    if hasattr(disc, "r_disc"):
        return float(disc.cx), float(disc.cy), float(disc.r_disc)
    if hasattr(disc, "radius_px"):
        return float(disc.cx), float(disc.cy), float(disc.radius_px)
    if isinstance(disc, dict):
        r = disc.get("r_disc", disc.get("radius_px"))
        return float(disc["cx"]), float(disc["cy"]), float(r)
    cx, cy, r = disc[0], disc[1], disc[2]
    return float(cx), float(cy), float(r)


def blobs(img, box: Tuple[int, int, int, int], colour: Optional[Sequence[int]] = None, tol: float = 0.08,
          min_px: int = 4, disc=None, min_sum: int = 90, min_sat: int = 40) -> List[Tuple[float, float, int, Tuple[int, int, int]]]:
    """8-connected blobs of one colour inside box, matched on hue_chroma (colour_match) so a dimmed screen still
    matches; pixels darker than min_sum (channel sum) are ignored. disc = (cx, cy, r) or a DiscMeasurement keeps only
    pixels inside the disc (the ring never enters). The box is clamped to the image. Without a colour: saturated
    pixels (max - min > 90), which on a real minimap include terrain (brown city ground). Returns
    [(cx, cy, n_px, mean_rgb)] largest first."""
    im, px = _load(img)
    W, H = im.size
    disc = disc_tuple(disc)
    x0, y0, x1, y1 = max(0, box[0]), max(0, box[1]), min(W, box[2]), min(H, box[3])
    want = hue_chroma(colour) if colour is not None else None
    mask = set()
    for y in range(y0, y1):
        for x in range(x0, x1):
            if disc is not None and math.hypot(x - disc[0], y - disc[1]) > disc[2]:
                continue
            c = px[x, y]
            if c[0] + c[1] + c[2] < min_sum:
                continue
            if want is None:
                ok = (max(c) - min(c)) > 90
            else:
                ok = colour_match(c, want, tol, min_sat)
            if ok:
                mask.add((x, y))
    out = []
    seen = set()
    for p in mask:
        if p in seen:
            continue
        stack = [p]
        seen.add(p)
        comp = []
        while stack:
            q = stack.pop()
            comp.append(q)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nq = (q[0] + dx, q[1] + dy)
                    if nq in mask and nq not in seen:
                        seen.add(nq)
                        stack.append(nq)
        if len(comp) >= min_px:
            mx = sum(q[0] for q in comp) / len(comp)
            my = sum(q[1] for q in comp) / len(comp)
            rgb = tuple(sum(px[q][i] for q in comp) // len(comp) for i in range(3))
            out.append((round(mx, 2), round(my, 2), len(comp), rgb))
    return sorted(out, key=lambda b: -b[2])


# ----------------------------------------------------------------------------- the player's star (= the Explorer)
_N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
_N8 = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1))
STAR_RATIO = 0.5                       # inner / outer radius of the template; the drawn star fits R 7.5-8.5 at 2560x1080
STAR_RADII = tuple(6.0 + 0.5 * k for k in range(11))       # 6 .. 11 px
STAR_MIN_SCORE = 0.85                  # measured 2026-09-24 on 5 frames (one dimmed): 19 real stars 0.92-1.00, the best non-star 0.806
STAR_RADII_REF_RIM = 147.0             # the largest rim measured at 2560x1080 (match HUD); radii scale only above it


def star_radii(r_disc: float) -> Tuple[float, ...]:
    """The template radii for a disc of rim r_disc px. The stars are UI art: they grow with the game's UI scale, as
    the disc does. At 2560x1080 (editor rim 130.5, match 147.0) the radii are STAR_RADII unchanged; above 147 px they
    scale by r_disc / 147. Measured 2026-09-24 on the 2880x1800 editor (rim 218.72): the four live stars fit R 11.9 and
    score 0.94-0.995 with the scaled radii (next best core 0.53); with STAR_RADII they scored 0.75-0.82 at R 11, the
    largest template, and player_star returned None for all four."""
    k = max(1.0, r_disc / STAR_RADII_REF_RIM)
    return STAR_RADII if k == 1.0 else tuple(k * r for r in STAR_RADII)
_STAR_TPL: Dict[Tuple[float, float, float], Tuple[List[Tuple[int, int]], List[Tuple[int, int]]]] = {}


def _star_polygon(cx: float, cy: float, R: float, ratio: float = STAR_RATIO) -> List[Point]:
    """A five-point star, one point straight up (screen y grows downward)."""
    out = []
    for k in range(10):
        rr = R if k % 2 == 0 else R * ratio
        a = math.radians(90 + 36 * k)
        out.append((cx + rr * math.cos(a), cy - rr * math.sin(a)))
    return out


def _in_polygon(x: float, y: float, poly: Sequence[Point]) -> bool:
    inside = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            inside = not inside
    return inside


def _polygon_distance(x: float, y: float, poly: Sequence[Point]) -> float:
    best = float("inf")
    n = len(poly)
    for i in range(n):
        (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % n]
        dx, dy = x2 - x1, y2 - y1
        t = max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)))
        best = min(best, math.hypot(x - x1 - t * dx, y - y1 - t * dy))
    return best


def _star_template(R: float, phase_x: float, phase_y: float):
    """Integer pixel offsets (relative to an integer base) inside a star centred at base + phase, and those of the
    band 0.5-1.5 px outside its outline. Cached."""
    key = (R, phase_x, phase_y)
    if key not in _STAR_TPL:
        poly = _star_polygon(phase_x, phase_y, R)
        inside, ring = [], []
        m = int(R + 3)
        for y in range(-m, m + 1):
            for x in range(-m, m + 1):
                if _in_polygon(x, y, poly):
                    inside.append((x, y))
                elif 0.5 <= _polygon_distance(x, y, poly) <= 1.5:
                    ring.append((x, y))
        _STAR_TPL[key] = (inside, ring)
    return _STAR_TPL[key]


def _components(pixels) -> List[List[Tuple[int, int]]]:
    pixels = set(pixels)
    seen = set()
    out = []
    for p in pixels:
        if p in seen:
            continue
        stack = [p]
        seen.add(p)
        comp = []
        while stack:
            q = stack.pop()
            comp.append(q)
            for dx, dy in _N8:
                n = (q[0] + dx, q[1] + dy)
                if n in pixels and n not in seen:
                    seen.add(n)
                    stack.append(n)
        out.append(comp)
    return out


def ultimate_cores(mask) -> List[Tuple[int, List[Tuple[int, int]]]]:
    """Ultimate erosion with the 4-neighbour cross: every component that vanishes at the next erosion, with the
    number of erosions it survived (its depth). A shape's thickest part; glyphs drawn behind a star erode away
    or keep their own core."""
    cur = set(mask)
    out = []
    depth = 0
    while cur:
        nxt = {p for p in cur if all((p[0] + dx, p[1] + dy) in cur for dx, dy in _N4)}
        for comp in _components(cur):
            if not any(p in nxt for p in comp):
                out.append((depth, comp))
        cur = nxt
        depth += 1
    return out


def star_score(mask, neutral, cx: float, cy: float, radii: Sequence[float] = STAR_RADII,
               offsets: Sequence[float] = (-1.0, -0.5, 0.0, 0.5, 1.0)) -> Tuple[float, float, float, float]:
    """How much the colour mask around (cx, cy) looks like a five-point star: the best over radii and half-pixel
    offsets of (template pixels in the mask, neutral white pixels not counted) x (band just outside the outline NOT
    in the mask). Returns (score, R, x, y) of the best template."""
    best = (0.0, 0.0, cx, cy)
    for R in radii:
        for ox in offsets:
            for oy in offsets:
                tx = round(2 * (cx + ox)) / 2.0
                ty = round(2 * (cy + oy)) / 2.0
                bx, by = math.floor(tx), math.floor(ty)
                inside, ring = _star_template(R, tx - bx, ty - by)
                hit = den = 0
                for dx, dy in inside:
                    q = (bx + dx, by + dy)
                    if q in neutral:
                        continue
                    den += 1
                    hit += q in mask
                if not den or hit < 0.6 * den:
                    continue
                out = sum(1 for dx, dy in ring if (bx + dx, by + dy) not in mask)
                s = (hit / den) * (out / len(ring))
                if s > best[0]:
                    best = (s, R, tx, ty)
    return best


def star_candidates(img, colour: Sequence[int], disc, tol: float = 0.08, min_sum: int = 90, min_sat: int = 40,
                    min_depth: int = 2) -> List[Dict]:
    """Every ultimate core (depth >= min_depth) of the colour inside the disc, scored as a star, best first:
    [{'x', 'y', 'score', 'R', 'depth', 'core_px', 'mask_px'}]. x, y = the core's centroid."""
    im, px = _load(img)
    W, H = im.size
    cx, cy, r = disc_tuple(disc)
    want = hue_chroma(colour)
    mask, neutral = set(), set()
    for y in range(max(0, int(cy - r)), min(H, int(cy + r) + 2)):
        for x in range(max(0, int(cx - r)), min(W, int(cx + r) + 2)):
            if math.hypot(x - cx, y - cy) > r - 1:
                continue
            c = px[x, y]
            if min(c) >= 235:
                neutral.add((x, y))           # route lines and white icons drawn over a star
                continue
            if c[0] + c[1] + c[2] < min_sum:
                continue
            if colour_match(c, want, tol, min_sat):
                mask.add((x, y))
    out = []
    for depth, comp in ultimate_cores(mask):
        if depth < min_depth:
            continue
        mx = sum(p[0] for p in comp) / len(comp)
        my = sum(p[1] for p in comp) / len(comp)
        s, R, _, _ = star_score(mask, neutral, mx, my, radii=star_radii(r))
        out.append({"x": round(mx, 2), "y": round(my, 2), "score": round(s, 3), "R": R, "depth": depth,
                    "core_px": len(comp), "mask_px": len(mask)})
    out.sort(key=lambda d: (-d["score"], -d["depth"], -d["core_px"]))
    return out


def player_star(img, colour: Sequence[int], disc, min_score: float = STAR_MIN_SCORE, **kw) -> Optional[Point]:
    """The pixel of the player's star (its Explorer) in that player colour, or None when no star-shaped core scores
    min_score. The position is the centroid of the star's ULTIMATE-EROSION core: by the star's symmetry that is its
    centre, and it ignores the glyph drawn behind it. Measured 2026-09-24 against the Explorers decoded from the save
    headers, disc calibration only: Paris 1.34/1.06/0.90/1.14 px at the engine size 654 m (1.27/1.12/0.89/1.30 at
    rmSetMapSize's 653), live London 4p 0.75/1.22/0.80/0.81 px at 686 m, Florence 1.23/0.99/1.19/1.36 px, Versailles
    0.74/1.43/1.23 px (its blue star, cut by a white route line and merged with a building, scored 0.56 and the
    best other core 0.75, so the answer is None, never a wrong star). The in-match HUD frame
    (sandbox/census/tt_state0.png, no save) gives all four stars, the yellow one among yellow buildings, and the
    dimmed editor frame gen_londonext.png (a dialog up; disc passed from the record) all four.
    The centroid of the un-eroded star pixels inside a fitted template was worse (1.7-2.1 px): the star's legs are
    heavier than its top point. disc = a DiscMeasurement, (cx, cy, r) or a calibration record (its rim radius)."""
    cands = star_candidates(img, colour, disc, **kw)
    if not cands or cands[0]["score"] < min_score:
        return None
    return cands[0]["x"], cands[0]["y"]
