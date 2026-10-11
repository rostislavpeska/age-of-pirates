"""Pure-Python layout metrics and static-stability arithmetic for prop arrangements (no bpy).

Yaws are plan angles in degrees measured against the building axes (0 = parallel to the building x axis).
Points are plan centres (x, y) in metres. See references/research.md for sources and thresholds."""
import math

THRESHOLDS = {
    'aligned_share_max': 0.35,       # non-round props within 5 deg of a building axis
    'aligned_tol_deg': 5.0,
    'axis_rows_max': 0,              # groups of >= 3 centres sharing x or y within 0.10 m (declared rows exempt)
    'row_tol_m': 0.10,
    'contact_share_min': 0.30,       # props touching a prop or a wall (side contact <= 1 cm, or resting on a prop)
    'isolated_share_max': 0.20,      # nothing within 0.6 m
    'isolated_radius_m': 0.6,
    'lean_mu_max': 0.4,              # wood on wood 0.25-0.5
    'stability_margin_min_m': 0.02,  # centre of mass inside the support polygon by max(2 cm, 10 % of its smallest width)
    'stability_margin_frac': 0.10,
    'small_prop_m': 0.20,            # smaller props go on a host only (Blender rigid bodies are unstable below ~20 cm)
    'clark_evans_want_max': 0.8,     # advisory: clustered
    'clark_evans_flag_min': 1.1,     # advisory: regular
    'nn_cv_min': 0.45,               # advisory: random ~0.52, grid 0
    'entropy_min': 0.6,              # advisory, needs >= 6 asymmetric props
    'parallel_share_max': 0.3,       # pairs closer than 1 m with |dyaw mod 90| < 3 deg
}


def yaw_offset(yaw, axis=0.0):
    """distance in degrees (0..45) from the nearest building axis"""
    d = (yaw - axis) % 90.0
    return min(d, 90.0 - d)


def alignment_share(yaws, axis=0.0, tol=5.0):
    if not yaws:
        return 0.0
    return sum(yaw_offset(y, axis) < tol for y in yaws) / len(yaws)


def axis_rows(points, tol=0.10, k=3):
    """groups of >= k centres whose x (or y) agree within tol (chained along the sorted coordinate)"""
    rows = []
    for j in (0, 1):
        idx = sorted(range(len(points)), key=lambda i: points[i][j]); grp = [idx[0]] if idx else []
        for a_, b_ in zip(idx, idx[1:]):
            if points[b_][j] - points[grp[0]][j] <= tol:
                grp.append(b_)
            else:
                if len(grp) >= k:
                    rows.append(('xy'[j], sorted(grp)))
                grp = [b_]
        if len(grp) >= k:
            rows.append(('xy'[j], sorted(grp)))
    return rows


def nn_distances(points):
    return [min(math.dist(p, q) for j, q in enumerate(points) if j != i) for i, p in enumerate(points)] if len(points) > 1 else []


def clark_evans(points, area, perimeter):
    """Clark-Evans R with Donnelly's (1978) edge correction for a window of the given area / perimeter.
    E[d] = 0.5 sqrt(A/n) + (0.0514 + 0.041 / sqrt(n)) P / n  (matches Monte Carlo within 0.4 % for n 5-30 in
    rectangles; for other polygons it is an approximation). sd(R) is about 0.27 at n = 5 and 0.17 at n = 12:
    R separates clustered from regular only with n >= ~10 per window - advisory, never a hard gate."""
    n = len(points); d = nn_distances(points)
    if n < 3 or area <= 0:
        return None
    e = 0.5 * math.sqrt(area / n) + (0.0514 + 0.041 / math.sqrt(n)) * perimeter / n
    return (sum(d) / n) / e


def nn_cv(points):
    d = nn_distances(points)
    if len(d) < 2:
        return None
    m = sum(d) / len(d)
    return math.sqrt(sum((x - m) ** 2 for x in d) / len(d)) / m if m else None


def orientation_entropy(yaws, axis=0.0, bins=9):
    if len(yaws) < 2:
        return None
    h = [0] * bins
    for y in yaws:
        h[min(int(yaw_offset(y, axis) / (45.0 / bins)), bins - 1)] += 1
    p = [c / len(yaws) for c in h if c]
    return -sum(x * math.log(x) for x in p) / math.log(bins)


def parallel_share(points, yaws, radius=1.0, tol=3.0):
    pairs = [(i, j) for i in range(len(points)) for j in range(i + 1, len(points)) if math.dist(points[i], points[j]) < radius]
    if not pairs:
        return 0.0
    return sum(yaw_offset(yaws[i] - yaws[j]) < tol for i, j in pairs) / len(pairs)


def polygon_area_perimeter(poly):
    a = 0.0; p = 0.0
    for i in range(len(poly)):
        (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % len(poly)]
        a += x1 * y2 - x2 * y1; p += math.hypot(x2 - x1, y2 - y1)
    return abs(a) / 2, p


def point_in_polygon(poly, x, y):
    c = False
    for i in range(len(poly)):
        (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % len(poly)]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-12) + x1:
            c = not c
    return c


def convex_hull(points):
    pts = sorted(set((round(x, 5), round(y, 5)) for x, y in points))
    if len(pts) < 3:
        return pts
    cr = lambda o, a_, b_: (a_[0] - o[0]) * (b_[1] - o[1]) - (a_[1] - o[1]) * (b_[0] - o[0])
    lo, up = [], []
    for q in pts:
        while len(lo) >= 2 and cr(lo[-2], lo[-1], q) <= 0:
            lo.pop()
        lo.append(q)
    for q in reversed(pts):
        while len(up) >= 2 and cr(up[-2], up[-1], q) <= 0:
            up.pop()
        up.append(q)
    return lo[:-1] + up[:-1]


def support_margin(com_xy, support_points):
    """signed plan distance from the centre of mass to the edge of the support polygon (convex hull of the contact
    points): > 0 inside. Returns (margin, smallest polygon width); (-inf, 0) when the contacts span no area."""
    H = convex_hull(support_points)
    if len(H) < 3:
        return float('-inf'), 0.0
    x, y = com_xy; inside = True; m = float('inf'); widths = []
    for i in range(len(H)):
        (x1, y1), (x2, y2) = H[i], H[(i + 1) % len(H)]
        ex, ey = x2 - x1, y2 - y1; L = math.hypot(ex, ey) or 1e-12
        s = (ex * (y - y1) - ey * (x - x1)) / L          # > 0 left of the edge (hull is counter-clockwise)
        inside &= s >= 0; m = min(m, abs(s))
        widths.append(max(abs(ex * (py - y1) - ey * (px - x1)) / L for px, py in H))
    return (m if inside else -m), min(widths)


def stability_ok(com_xy, support_points, th=THRESHOLDS):
    m, w = support_margin(com_xy, support_points)
    need = max(th['stability_margin_min_m'], th['stability_margin_frac'] * w)
    return m >= need, round(m, 4), round(need, 4)


def lean_mu_required(d_com, h_contact):
    """ladder case against a frictionless support: mu = horizontal distance (ground contact -> centre of mass) /
    height of the upper contact; a uniform disc or rod tilted by theta from vertical gives tan(theta) / 2"""
    return abs(d_com) / h_contact if h_contact > 1e-6 else float('inf')
