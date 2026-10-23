"""Split conjoined families across fixed runtime texture pages at ONE uniform density.

Input: charts / owners / assign from blender-uv-conjoin `families()` (working texels at
the working density, e.g. 256 texels/unit) and a list of pages:
    [dict(name='P2048', size=2048), dict(name='P1024', size=1024,
          prefer=['EAVE_CUTOUT', 'ROOF_TRIM', 'ROOF_TILE'], must=['EAVE_CUTOUT'])]
Rule: pages with `prefer` are filled with those materials in priority order ("as much as
possible"); `must` materials have to fit there (e.g. alpha-bearing families on the alpha
page); everything else goes to the first page without preferences. The uniform scale s
(runtime texels per working texel) is maximised by bisection, so no page is downscaled
relative to another. Gutter is fixed in RUNTIME texels (default 4: DXT block + mips).
A family is the unit: owner and members always land on the same page.
"""
import math
import numpy as np
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'blender-uv-conjoin' / 'scripts'))
from pack_rects import maxrects


def _fits(rects, side):
    return not rects or maxrects(rects, side, side) is not None


def validate_inputs(charts, owners, pages, s, gutter_rt):
    if not math.isfinite(s) or s <= 0 or not math.isfinite(gutter_rt) or gutter_rt < 0:
        raise ValueError('scale must be finite and positive; gutter finite and nonnegative')
    names = [p['name'] for p in pages]
    if not names or len(set(names)) != len(names):
        raise ValueError('pages need distinct names')
    for p in pages:
        if not isinstance(p['size'], int) or p['size'] <= 0:
            raise ValueError('page size must be a positive integer')
        if not set(p.get('must', [])) <= set(p.get('prefer', [])):
            raise ValueError('every required material must occur in prefer')
    if sum(not p.get('prefer') for p in pages) != 1:
        raise ValueError('exactly one catch-all page is required')
    if not owners or len(set(owners)) != len(owners) or any(j not in range(len(charts)) for j in owners):
        raise ValueError('owners must be unique chart indices')
    for j in owners:
        if any(not math.isfinite(charts[j][k]) or charts[j][k] <= 0 for k in ('L', 'W')):
            raise ValueError('owner dimensions must be finite and positive')


def assign_pages(charts, owners, pages, s, gutter_rt=4.):
    validate_inputs(charts, owners, pages, s, gutter_rt)
    g = gutter_rt / s
    rect = {j: (charts[j]['L'] + g, charts[j]['W'] + g) for j in owners}
    side = {p['name']: p['size'] / s for p in pages}
    free = set(owners)
    out = {p['name']: [] for p in pages}
    for p in pages:
        if not p.get('prefer'):
            continue
        for mat in p['prefer']:
            cand = sorted((j for j in free if charts[j]['mat'] == mat), key=lambda j: -rect[j][0] * rect[j][1])
            for j in cand:
                trial = out[p['name']] + [j]
                if _fits([rect[k] for k in trial], side[p['name']]):
                    out[p['name']] = trial; free.discard(j)
                elif mat in p.get('must', []):
                    return None
    rest = [p for p in pages if not p.get('prefer')]
    if len(rest) != 1:
        raise ValueError('exactly one catch-all page (no prefer list) is required')
    out[rest[0]['name']] = sorted(free)
    if not _fits([rect[k] for k in out[rest[0]['name']]], side[rest[0]['name']]):
        return None
    return out


def best_split(charts, owners, pages, gutter_rt=4., lo=.02, hi=2., iters=24):
    validate_inputs(charts, owners, pages, lo, gutter_rt)
    if not math.isfinite(hi) or hi < lo or not isinstance(iters, int) or not 1 <= iters <= 100:
        raise ValueError('invalid bounded scale search')
    start = assign_pages(charts, owners, pages, lo, gutter_rt)
    if start is None:
        return None
    best = (lo, start)
    for _ in range(iters):
        mid = (lo + hi) / 2
        a = assign_pages(charts, owners, pages, mid, gutter_rt)
        if a is None:
            hi = mid
        else:
            lo, best = mid, (mid, a)
    return best


def emit(charts, owners, assign, pages, s, split, gutter_rt=4.):
    """Per-face runtime UV in [0,1] of its page: {face_id: dict(page, uv, family, owner)}."""
    validate_inputs(charts, owners, pages, s, gutter_rt)
    if set(owners) & set(assign) or set(owners) | set(assign) != set(range(len(charts))):
        raise ValueError('every chart must be exactly one owner or member')
    if any(a[1] not in owners for a in assign.values()):
        raise ValueError('member refers to a missing owner')
    if set(split) != {p['name'] for p in pages}:
        raise ValueError('split page names differ from profile')
    placed = [j for ids in split.values() for j in ids]
    if len(placed) != len(set(placed)) or set(placed) != set(owners):
        raise ValueError('split must contain every owner exactly once')
    g = gutter_rt / s
    out = {}
    fam_size = {j: 1 for j in owners}
    for i, (_, j, _, _, _) in assign.items():
        fam_size[j] += 1
    for p in pages:
        ids = split[p['name']]
        rects = [(charts[j]['L'] + g, charts[j]['W'] + g) for j in ids]
        side = p['size'] / s
        place = {}
        for k, x, y, rw, rh in (maxrects(rects, side, side) or []):
            j = ids[k]; T = np.eye(3)
            if abs(rw - rects[k][0]) > 1e-6:
                T[:2, :2] = [[0, -1], [1, 0]]; T[:2, 2] = [charts[j]['W'], 0]
            T2 = np.eye(3); T2[:2, 2] = [x + g / 2, y + g / 2]
            place[j] = T2 @ T
        members = [(i, a) for i, a in assign.items() if a[1] in place]
        for i, (j, M) in [(j, (j, np.eye(3))) for j in ids] + [(i, (a[1], a[2])) for i, a in members]:
            H = np.eye(3); H[:2, :] = charts[i]['N']
            A = place[j] @ M @ H
            for f in charts[i]['faces']:
                q = np.c_[np.asarray(f['uv'], float), np.ones(len(f['uv']))] @ A.T
                out[str(f['id'])] = dict(page=p['name'], uv=(q[:, :2] / side).tolist(), family=charts[j]['id'],
                                         family_size=fam_size[j], owner=i == j, material=charts[i]['mat'])
    expected = [str(f['id']) for c in charts for f in c['faces']]
    if len(set(expected)) != len(expected) or set(out) != set(expected):
        raise ValueError('face coverage changed during page emission')
    if any(not np.isfinite(x['uv']).all() or np.min(x['uv']) < -1e-7 or np.max(x['uv']) > 1 + 1e-7 for x in out.values()):
        raise ValueError('emitted UV is nonfinite or outside its page')
    return out


def military_2048(charts, owners, assign, *, min_scale, gutter_rt, max_scale=2.):
    """One-page candidate, never silently below min_scale or on an extra page.

    min_scale comes from measured working densities and the approved floor, not
    a nominal exporter target. The emitted mesh must still pass density_floor.py.
    This is packing support, not proof that a particular military building fits.
    """
    pages = [dict(name='P2048', size=2048)]
    result = best_split(charts, owners, pages, gutter_rt, lo=min_scale, hi=max_scale)
    if result is None:
        raise ValueError('military_2048: does not fit at the minimum scale; retain parent and report capacity')
    scale, split = result
    plan = emit(charts, owners, assign, pages, scale, split, gutter_rt)
    return dict(profile='military_2048_v1', pages=pages, scale=scale, min_scale=min_scale,
                gutter_rt=gutter_rt, split=split, faces=plan, status='CANDIDATE_REQUIRES_DENSITY_AND_MIP_QA')
