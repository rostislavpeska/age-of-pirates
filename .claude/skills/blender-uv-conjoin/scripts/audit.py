"""Space gate for conjoinment: split hollow charts first, audit the packed page after.

Incident 2026-09-28 (Korean TC): whole timber facade frames stayed as single hollow,
unique charts. Their bounding rectangles took about 2/3 of the page; the owner had to
catch it by eye (estimated cost about USD 600). Splitting them into posts and beams
cut the page from 4360 to 2782 texels. These checks exist so that never ships again.

split_hollow(faces, fill)   charts whose area / min-area-rectangle < fill are regrouped
                            into straight members (end-to-end, same direction, same width).
audit(...)                  page usage by category + runtime texel density, with gates.
"""
import math, collections
import numpy as np
from shapely.geometry import Polygon
from shapely.ops import unary_union

GATES = dict(max_hollow_share=.10, max_unique_share=.45, min_packing_efficiency=.45,
             max_single_owner_share=.25, min_runtime_density=0.)


def _poly(q):
    g = Polygon(q)
    return g if g.is_valid else g.buffer(0)


def _frame(q):
    r = np.asarray(_poly(q).minimum_rotated_rectangle.exterior.coords)[:4]
    e1, e2 = r[1] - r[0], r[2] - r[1]
    l1, l2 = np.linalg.norm(e1), np.linalg.norm(e2)
    if l1 < l2:
        e1, l1, l2 = e2, l2, l1
    return math.atan2(e1[1], e1[0]) % math.pi, l1, l2


def fill_ratio(shape):
    r = shape.minimum_rotated_rectangle.area
    return shape.area / r if r > 0 else 1.


def split_hollow(faces, fill=.6, min_faces=3):
    """Regroup hollow charts (frames, rings, ladders) into straight members, in place.
    Returns the ids of the charts that were split."""
    charts = collections.defaultdict(list)
    for f in faces:
        charts[f['chart']].append(f)
    split = []
    for cid, fs in charts.items():
        if len(fs) < min_faces or any(f.get('protect') for f in fs):
            continue
        if fill_ratio(unary_union([_poly(f['uv']) for f in fs])) >= fill:
            continue
        info = {f['id']: _frame(f['uv']) for f in fs}
        key = lambda p: (round(p[0], 2), round(p[1], 2))
        edges = collections.defaultdict(list)
        for f in fs:
            q = f['uv']
            for a, b in zip(q, q[1:] + q[:1]):
                edges[frozenset((key(a), key(b)))].append((f['id'], np.asarray(a, float), np.asarray(b, float)))
        parent = {f['id']: f['id'] for f in fs}

        def find(x):
            while parent[x] != x:
                parent[x] = parent[parent[x]]; x = parent[x]
            return x
        for lst in edges.values():
            if len(lst) != 2:
                continue
            (fa, a, b), (fb, _, _) = lst
            ang_a, La, Wa = info[fa]; ang_b, Lb, Wb = info[fb]
            e = b - a; el = float(np.linalg.norm(e))
            if el < 1e-6:
                continue
            sq_a, sq_b = La / max(Wa, 1e-9) < 1.3, Lb / max(Wb, 1e-9) < 1.3
            direction = ang_b if sq_a else ang_a
            if not sq_a and not sq_b:
                d = abs(ang_a - ang_b) % math.pi
                if min(d, math.pi - d) > math.radians(10):
                    continue
            ed = math.atan2(e[1], e[0]) % math.pi
            d = abs(ed - direction) % math.pi
            if abs(min(d, math.pi - d) - math.pi / 2) > math.radians(10):
                continue
            w = min(Wa, Wb)
            if abs(el - w) > .1 * w + 1:
                continue
            parent[find(fa)] = find(fb)
        for f in fs:
            f['chart'] = f"{cid}|m{find(f['id'])}"
        split.append(cid)
    return split


def audit(charts, owners, fam_size, side, gutter, target_density=256., runtime_page=2048., fill=.6, gates=None):
    """Where does the page go? charts: prepared charts (area, L, W, shape, mat, id)."""
    g = dict(GATES, **(gates or {}))
    rows = []
    for j in owners:
        c = charts[j]
        rect = (c['L'] + gutter) * (c['W'] + gutter)
        rows.append(dict(chart=c['id'], material=c['mat'], rect=rect, filled=c['area'],
                         fill=c['area'] / max(c['L'] * c['W'], 1e-9), family_size=fam_size.get(j, 1)))
    total = sum(r['rect'] for r in rows) or 1.
    hollow = sum(r['rect'] for r in rows if r['fill'] < fill) / total
    unique = sum(r['rect'] for r in rows if r['family_size'] <= 1) / total
    biggest = max(r['rect'] for r in rows) / (side * side) if rows else 0.
    eff = sum(r['filled'] for r in rows) / (side * side)
    runtime_density = target_density * runtime_page / side
    res = dict(page_side_texels=side, runtime_page=runtime_page, runtime_texels_per_unit=runtime_density,
               hollow_share=hollow, unique_share=unique, packing_efficiency=eff, single_owner_share=biggest,
               top_consumers=sorted(rows, key=lambda r: -r['rect'])[:10])
    fails = []
    if hollow > g['max_hollow_share']:
        fails.append(f"hollow charts use {hollow:.0%} of owner rectangles (max {g['max_hollow_share']:.0%}): split frames/rings")
    if unique > g['max_unique_share']:
        fails.append(f"unshared charts use {unique:.0%} of owner rectangles (max {g['max_unique_share']:.0%}): conjoinment ineffective")
    if len(rows) >= 10 and eff < g['min_packing_efficiency']:   # tiny pages are dominated by one long strip
        fails.append(f"packing efficiency {eff:.0%} (min {g['min_packing_efficiency']:.0%}): empty space dominates")
    if biggest > g['max_single_owner_share']:
        fails.append(f"one chart takes {biggest:.0%} of the page (max {g['max_single_owner_share']:.0%})")
    if g['min_runtime_density'] and runtime_density < g['min_runtime_density']:
        fails.append(f"runtime density {runtime_density:.0f} texels/unit < {g['min_runtime_density']:.0f}: texture will be blurry")
    res['fails'] = fails
    res['verdict'] = 'FAIL' if fails else 'PASS'
    return res
