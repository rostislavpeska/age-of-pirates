"""Junction check: score DECLARED junctions between named parts of a Blender scene (world space). Read-only.

Run inside Blender:

    blender -b FILE.blend --factory-startup --python junction_check.py -- --key KEY.json --out REPORT.json [--strict]

--strict exits 1 unless the report status is PASS. Modifiers are evaluated (the measured mesh is what the viewer sees).
Measurement reuses blender-overlap-cleanup/scripts/logic_qa.py (sample lattice, generalized winding number, protrusion
depth to the nearest surface) and shell_orientation.py (signed volume, flipped n-gon triangles); nothing is forked.

Answer key (JSON; the builder never sees it):

    {"name": "J7 rail into post",
     "scope": {"collection": "optional collection name", "exclude": ["fnmatch", ...]},
     "junctions": [{"id": "rail-post", "a": "Rail.*", "b": "Post.*", "strategy": "butt",
                    "max_gap": .005, "max_pen": .02, "max_proud": .005, "reach": .25}],
     "orientation": ["*"],
     "undeclared": {"scan": true, "max_pen": .01}}

Every part matched by `a` must meet the `b` parts near it (within `reach`, default .25 m): a junction FAILS when any
`a` part fails. With "all_b": true every `b` part within reach must be met (a rail between two posts), otherwise the
nearest one is enough. Per `a` part:
  gap    0 when it touches a `b` part (crossing, or within 4 mm after normal inflation), else the smallest
         surface-to-surface distance (sample points both ways)
  pen    how deep one part runs into the other, both ways: into a CLOSED part, the deepest sample inside it (winding
         number) measured to its nearest surface. Into an OPEN sheet (single-sided roof field or panel), measured along
         the sheet's face normals (the drawn side; the game culls back faces): for 'constructed' everything of the
         other part BEHIND the sheet (an untrimmed valley, a wing sliding under the main roof; a sheet trimmed at the
         intersection line scores 0); for other strategies only a pass-through, the smaller of the reach on the two
         sides (a rafter resting under a roof field scores 0). Measured on every touching pair (BVH overlap() misses
         sheets that meet along a shared triangle diagonal)
  proud  how far `a` stands out beyond the `b` part it touches, across a's own axis (members butting into posts)
  cover  (only with min_cover) share of a's faces that face the b parts lying within max_gap of them, sampled every
         2 cm: touching at one corner is not attachment (a balcony deck touching its wall on 6 % of its side)
  zfight area of coincident same-facing faces of the pair (a board top laid exactly on the roof flickers in game);
         fails above max_zfight (default 1e-4 m2). The undeclared scan applies the same rule to every touching pair
Strategy defaults (an explicit max_* overrides):
  constructed  the parts share the seam               gap .005  pen .005
  seated       one rests in/on the other, hidden seat gap .005  pen = max_pen (required)
  butt         a member ends against the other        gap .005  pen .02  proud .005
  camouflaged  no modelled seam (texture valley)      gap .02   pen .02
INCONCLUSIVE (counted as FAIL): a pattern matches nothing, or a 'seated' junction has no seat depth.
orientation: every closed shell of the matched parts encloses positive signed volume; no n-gon has flipped triangles or
an outline that crosses itself.
up: every face of the matched single-sided sheets (roof fields) points above the horizon.
extents: [{"part": fnmatch, "min": [x, y, z], "max": [x, y, z], "tol": .02}] the matched parts span that world box
(null skips an axis), so a tiny or misplaced part cannot pass a junction.
probes: [{"part": fnmatch, "inside": [[x, y, z]], "on": [[x, y, z]], "tol": .005}] points inside a matched closed part
(a filled cornice corner) or on a matched surface (a valley line both roofs reach).
undeclared: any other crossing pair deeper than max_pen (default .01) fails - an overlap nobody declared.
"""
import fnmatch
import json
import sys
from collections import defaultdict
from pathlib import Path
from types import SimpleNamespace

import bpy
import numpy as np
from mathutils import Vector

_OVERLAP = Path(__file__).resolve().parents[2] / 'blender-overlap-cleanup' / 'scripts'
sys.path.insert(0, str(_OVERLAP))
import logic_qa as lq  # noqa: E402
import shell_orientation as so  # noqa: E402

STRATEGY = {'constructed': {'max_gap': .005, 'max_pen': .005},
            'seated': {'max_gap': .005},
            'butt': {'max_gap': .005, 'max_pen': .02, 'max_proud': .005},
            'camouflaged': {'max_gap': .02, 'max_pen': .02}}
REACH = .25
FAR = 1.0                                   # gaps are measured up to 1 m; beyond that a part is reported as 'far'
EXTRA = ('orientation', 'up', 'extents', 'probes', 'undeclared')    # whole-scene checks, in report order
ZFIGHT_AREA = 1e-4                          # m2 of coincident same-facing faces tolerated (float noise); per junction: max_zfight
COVER_STEP = .02                            # contact-cover sample spacing (m): a 4 x 4 grid missed 2.5 cm strips


class Scene:
    """Evaluated, world-space parts of the scope, built lazily (a full building has hundreds of parts)."""

    def __init__(self, scope=None):
        scope = scope or {}
        objs = [o for o in bpy.data.objects if o.type in ('MESH', 'CURVE') and not o.hide_render]
        if scope.get('collection'):
            coll = bpy.data.collections[scope['collection']]
            objs = [o for o in objs if o.name in coll.all_objects]
        ex = scope.get('exclude', [])
        self.objs = {o.name: o for o in sorted(objs, key=lambda o: o.name) if not any(fnmatch.fnmatchcase(o.name, p) for p in ex)}
        self.dg = bpy.context.evaluated_depsgraph_get()
        self._parts = {}; self._meshes = []

    def names(self, pattern):
        return [n for n in self.objs if fnmatch.fnmatchcase(n, pattern)]

    def mesh(self, name):
        o = self.objs[name]
        me = bpy.data.meshes.new_from_object(o.evaluated_get(self.dg))
        self._meshes.append(me)
        return SimpleNamespace(name=name, matrix_world=o.matrix_world.copy(), data=me)

    def part(self, name):
        if name not in self._parts:
            self._parts[name] = lq.Part(self.mesh(name))
        return self._parts[name]

    def free(self):
        for me in self._meshes:
            bpy.data.meshes.remove(me)
        self._meshes = []; self._parts = {}; _BORDER.clear()


def _near(A, B, pad):
    return not (np.any(A.lo > B.hi + pad) or np.any(B.lo > A.hi + pad))


def touching(A, B):
    """Crossing (triangles intersect), contact within the 4 mm inflation, or one closed part fully inside the other."""
    if not _near(A, B, lq.CONTACT):
        return False, False
    crossing = bool(A.bvh.overlap(B.bvh))
    touch = crossing or bool(A.infl.overlap(B.bvh)) or bool(A.bvh.overlap(B.infl))
    if not touch:
        for small, big in ((A, B), (B, A)):
            if big.closed and np.all(small.lo >= big.lo) and np.all(small.hi <= big.hi) and abs(lq.winding(small.V[:1], big)[0]) > .5:
                return True, True                        # contained: overlap() cannot see it
    return touch, crossing


def gap(A, B):
    """Smallest surface-to-surface distance (sample points of each part against the other's surface), capped at FAR,
    and the midpoint of that closest pair (None when nothing is within FAR)."""
    best, at = FAR, None
    for X, Y in ((A, B), (B, A)):
        P = X.S[np.all((X.S >= Y.lo - best) & (X.S <= Y.hi + best), axis=1)]
        for p in P:
            hit = Y.bvh.find_nearest(Vector(p), best)
            if hit[0] is not None and hit[3] < best:
                best, at = hit[3], (Vector(p) + hit[0]) / 2
    return best, at


def proud(A, B):
    """How far member A stands out beyond B across A's own section axes (a rail wider than the post it butts into).
    None when A is not elongated."""
    seg = lq.axis_of(A)
    if seg is None:
        return None
    worst = 0.0
    for v, _half in seg[2]:
        pa = A.V @ v; pb = B.V @ v
        worst = max(worst, float(pa.max() - pb.max()), float(pb.min() - pa.min()))
    return worst


_BORDER = {}


def border(b):
    """Open-border segments of sheet b (triangle edges used once), cached per part."""
    if id(b) not in _BORDER:
        cnt = {}
        for t in b.T:
            for i, j in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
                k = (min(i, j), max(i, j)); cnt[k] = cnt.get(k, 0) + 1
        E = np.array([k for k, n in cnt.items() if n == 1], dtype=np.int64).reshape(-1, 2)
        _BORDER[id(b)] = (b.V[E[:, 0]], b.V[E[:, 1]])
    return _BORDER[id(b)]


def off_border(q, b, margin=1e-3):
    """Is q (a point on sheet b) farther than margin from b's open border?"""
    A, B = border(b)
    if not len(A):
        return True
    d = B - A; t = np.clip(np.einsum('ij,ij->i', np.array(q) - A, d) / np.maximum(np.einsum('ij,ij->i', d, d), 1e-18), 0, 1)
    return float(np.min(np.linalg.norm(A + t[:, None] * d - np.array(q), axis=1))) > margin


def edge_inside(sheet, solid):
    """Does an open-border point of the sheet (segment ends and midpoints) lie inside the closed solid, off its surface?"""
    A, B = border(sheet)
    if not len(A):
        return False
    P = np.vstack([A, B, (A + B) / 2])
    P = P[np.all((P >= solid.lo - 1e-6) & (P <= solid.hi + 1e-6), axis=1)]
    if not len(P):
        return False
    for p, w in zip(P, lq.winding(P, solid)):
        if abs(w) > .5 and solid.bvh.find_nearest(Vector(p))[3] > lq.EPS_ON:
            return True
    return False


def sides(a, b):
    """Open sheet b (a roof field, a single-sided panel): a's farthest reach in front of and behind b, measured along
    b's face normal where the nearest point lies inside b, at least 1 mm from its open border (a wall face that a
    roof edge ends on would otherwise read as both in front of and behind the roof), with the sample point of each.
    Front = the normal side, the side the game draws (back faces are culled)."""
    P = a.S[np.all((a.S >= b.lo - FAR) & (a.S <= b.hi + FAR), axis=1)]
    front = back = (0.0, None)
    for p in P:
        loc, nrm, idx, dist = b.bvh.find_nearest(Vector(p))
        if loc is None or dist <= lq.EPS_ON:
            continue
        s = (Vector(p) - loc).dot(nrm)
        if abs(s) >= .98 * dist and off_border(loc, b):
            if s > front[0]:
                front = (s, p)
            elif -s > back[0]:
                back = (-s, p)
    return front, back


def protrusion_at(a, b):
    """logic_qa.protrusion (deepest sample of a inside closed b, to b's nearest surface) plus where that sample is."""
    P = a.S[np.all((a.S >= b.lo - 1e-6) & (a.S <= b.hi + 1e-6), axis=1)]
    best = (0.0, None)
    if not len(P):
        return best
    for p, wi in zip(P, lq.winding(P, b)):
        if abs(wi) > .5:
            dist = b.bvh.find_nearest(Vector(p))[3]
            if dist is not None and dist > lq.EPS_ON and dist > best[0]:
                best = (dist, p)
    return best


def depth(a, b, hidden):
    """How deep a runs into b, and where (world point or None). Closed b: winding-number protrusion. Open sheet b: with
    hidden=True (a 'constructed' seam, where neither part may continue behind the other) everything of a behind b's
    drawn side - an untrimmed valley or a wing sliding under the main roof; otherwise only a pass-through, the smaller
    of a's reach on the two sides, so a rafter resting under a roof field scores 0."""
    if b.closed:
        return protrusion_at(a, b) + ('winding',)
    front, back = sides(a, b)
    if hidden:
        return back + ('sheet behind',)
    return (front[0], front[1], 'sheet through') if front[0] < back[0] else back + ('sheet through',)


def zfight(A, B):
    """Area (m2) of coincident same-facing faces between two parts, both ways (logic_qa's rule: triangle centroid
    within .5 mm of the other part, normals within 2.5 deg; faces pointing down are never seen from the RTS camera).
    A board top laid exactly on a roof, a post top cut exactly to it: both faces are drawn at one depth and flicker."""
    best = 0.0
    for X, Y in ((A, B), (B, A)):
        area = 0.0
        for c, nrm, ar in zip(X.pc, X.pn, X.pa):
            if ar < 1e-6 or nrm.z < -.7:
                continue
            loc, n2, idx, d = Y.bvh.find_nearest(Vector(c), 1e-3)
            if loc is not None and d < 5e-4 and nrm.dot(n2) > .999:
                area += ar
        best = max(best, area)
    return best


def measure(A, B, want_proud, hidden=False):
    t, crossing = touching(A, B)
    g, at = (0.0, None) if t else gap(A, B)
    pen, how = 0.0, []
    if t:                                  # BVH overlap() misses sheets meeting along a shared triangle diagonal: measure every contact
        ab, ba = depth(A, B, hidden), depth(B, A, hidden)
        # a closed part and a sheet: a sheet whose own edge ends inside the part (a roof run into a tower) overlaps it
        # by its buried depth, not by the part's reach above and below the sheet's plane; a sheet that continues past
        # the part on every side (a post poking up through a roof) is passed through, so the reach counts
        if A.closed and not B.closed and edge_inside(B, A):
            ab = (0.0, None, ab[2])
        if B.closed and not A.closed and edge_inside(A, B):
            ba = (0.0, None, ba[2])
        for d, p, h in (ab, ba):
            how.append(h)
            if d > pen:
                pen, at = d, Vector(p)
    pr = proud(A, B) if (want_proud and t) else None
    zf = zfight(A, B) if t else 0.0
    return {'b': B.name, 'touch': t, 'gap': round(g, 4), 'pen': round(pen, 4), 'proud': None if pr is None else round(pr, 4),
            'zfight': round(zf, 5), 'method': sorted(set(how)), 'at': None if at is None else [round(c, 3) for c in at]}


def cover(sc, a, bs, reach, contact):
    """Share of a's faces that FACE the b parts (a ray from the face centre along its normal reaches a b part within
    reach) lying within `contact` of b, on a k x k grid per face (logic_qa's deck attachment rule, against named
    parts): a deck touching its wall at one corner covers 6 %, a seated deck most of its side. None: no facing face."""
    ns = sc.mesh(a); mw = ns.matrix_world; mw3 = mw.to_3x3(); Bs = [sc.part(b) for b in bs]

    def hit(o_, d_, dist):
        return any(B.bvh.ray_cast(o_ - d_ * 1e-3, d_, dist + 1e-3)[0] is not None for B in Bs)
    me = ns.data; me.calc_loop_triangles()
    tris = defaultdict(list)
    for t in me.loop_triangles:
        tris[t.polygon_index].append([mw @ me.vertices[i].co for i in t.vertices])
    tot = got = 0
    for p in me.polygons:
        if p.area < 1e-3:
            continue
        n = (mw3 @ p.normal).normalized()
        if not hit(mw @ p.center, n, reach):
            continue
        pts = [q for tri in tris[p.index] for q in tri_points(*tri)]
        tot += len(pts); got += sum(1 for q in pts if hit(q, n, contact))
    return round(got / tot, 3) if tot else None


def tri_points(a, b, c, step=COVER_STEP, cap=2000):
    """Area-uniform barycentric grid inside a triangle, about `step` apart (at most cap points), centroid included."""
    k = max(1, min(int(max((b - a).length, (c - b).length, (a - c).length) / step), int((2 * cap) ** .5)))
    return [a + (b - a) * ((i + 1 / 3) / k) + (c - a) * ((j + 1 / 3) / k) for i in range(k) for j in range(k - i)]


def judge_junction(sc, j):
    lim = dict(STRATEGY.get(j.get('strategy', 'constructed'), {}))
    lim.update({k: j[k] for k in ('max_gap', 'max_pen', 'max_proud', 'min_cover', 'max_zfight') if j.get(k) is not None})
    out = {'id': j['id'], 'a': j['a'], 'b': j['b'], 'strategy': j.get('strategy', 'constructed'), 'limits': lim, 'members': []}
    an, bn = sc.names(j['a']), sc.names(j['b'])
    if not an or not bn:
        out.update(status='INCONCLUSIVE', reason='no part matches ' + (j['a'] if not an else j['b']))
        return out
    if 'max_pen' not in lim:
        out.update(status='INCONCLUSIVE', reason="strategy 'seated' needs max_pen (the seat depth)")
        return out
    reach = j.get('reach', REACH)
    for a in an:
        A = sc.part(a)
        rows = [measure(A, sc.part(b), 'max_proud' in lim, out['strategy'] == 'constructed')
                for b in bn if b != a and _near(A, sc.part(b), reach)]
        m = {'a': a}
        if not rows:
            m.update(status='FAIL', reason='no %s part within %.2f m' % (j['b'], reach), gap=None)
            out['members'].append(m); continue
        # all_b: every b part within reach must be met (a rail's two end posts), not just the nearest one
        near = max(rows, key=lambda r: (r['gap'], r['pen'])) if j.get('all_b') else min(rows, key=lambda r: (r['gap'], -r['pen']))
        deep = max(rows, key=lambda r: r['pen'])
        m.update(gap=near['gap'], nearest=near['b'], pen=deep['pen'])
        m['at'] = deep['at'] if deep['pen'] > 0 else near['at']      # where to look: the deepest clash, else the closest gap
        prs = [r['proud'] for r in rows if r['proud'] is not None]
        if 'max_proud' in lim:
            m['proud'] = max(prs) if prs else None
        m['method'] = sorted({h for r in rows for h in r['method']})
        why = []
        if m['gap'] > lim['max_gap']:
            why.append('gap %.3f > %.3f' % (m['gap'], lim['max_gap']))
        if m['pen'] > lim['max_pen']:
            why.append('pen %.3f > %.3f' % (m['pen'], lim['max_pen']))
        if m.get('proud') is not None and m['proud'] > lim['max_proud']:
            why.append('proud %.3f > %.3f' % (m['proud'], lim['max_proud']))
        m['zfight'] = max(r['zfight'] for r in rows)
        if m['zfight'] > lim.get('max_zfight', ZFIGHT_AREA):
            why.append('coincident faces %.4f m2' % m['zfight'])
        if 'min_cover' in lim:
            m['cover'] = cover(sc, a, [r['b'] for r in rows], reach, max(lim['max_gap'], lq.CONTACT))
            if m['cover'] is None or m['cover'] < lim['min_cover']:
                why.append('cover %s < %.2f' % ('none' if m['cover'] is None else '%.2f' % m['cover'], lim['min_cover']))
        m.update(status='FAIL', reason='; '.join(why)) if why else m.update(status='PASS')
        out['members'].append(m)
    st = [m['status'] for m in out['members']]
    out['status'] = 'FAIL' if 'FAIL' in st else 'INCONCLUSIVE' if 'INCONCLUSIVE' in st else 'PASS'
    for k in ('gap', 'pen', 'proud'):
        vals = [m[k] for m in out['members'] if m.get(k) is not None]
        if vals:
            out['worst_' + k] = max(vals)
    covs = [m['cover'] for m in out['members'] if m.get('cover') is not None]
    if covs:
        out['worst_cover'] = min(covs)
    return out


def judge_orientation(sc, patterns):
    names = sorted({n for p in patterns for n in sc.names(p)})
    bad = []
    for n in names:
        ns = sc.mesh(n); me = ns.data; mw = ns.matrix_world
        verts = [tuple(mw @ v.co) for v in me.vertices]
        for r in so.check_mesh(verts, [tuple(p.vertices) for p in me.polygons]):
            if r['status'] == 'INSIDE_OUT':
                bad.append({'part': n, 'kind': 'inside_out', 'volume': round(r['volume'], 5), 'faces': r['faces']})
        me.calc_loop_triangles(); flips = {}
        for t in me.loop_triangles:
            if t.area > 1e-10 and t.normal.dot(me.polygons[t.polygon_index].normal) < 0:
                flips[t.polygon_index] = flips.get(t.polygon_index, 0) + 1
        bad += [{'part': n, 'kind': 'flipped_triangles', 'face': f, 'flipped': k} for f, k in sorted(flips.items())]
        # the cause behind flipped triangles, caught even when this triangulation happens not to flip (the game
        # exporter triangulates on its own): an n-gon outline that crosses itself in its own plane
        for p in me.polygons:
            if len(p.vertices) < 4 or p.index in flips or p.normal.length < 1e-9:
                continue
            nv = p.normal.normalized(); u = nv.orthogonal().normalized(); w = nv.cross(u)
            pts2 = [(me.vertices[i].co.dot(u), me.vertices[i].co.dot(w)) for i in p.vertices]
            if so.self_intersecting(pts2):
                bad.append({'part': n, 'kind': 'self_intersecting_ngon', 'face': p.index, 'verts': len(p.vertices)})
    return {'parts': len(names), 'status': 'FAIL' if bad else 'PASS', 'defects': bad}


def judge_extents(sc, rules):
    """The parts a pattern matches must span the stated world box (union of their bounding boxes, each bound within
    tol; null skips an axis): a builder cannot pass a junction by building a tiny or misplaced part."""
    bad = []
    for r in rules:
        names = sc.names(r['part'])
        if not names:
            bad.append({'part': r['part'], 'reason': 'no part matches'}); continue
        lo = np.min([sc.part(n).lo for n in names], axis=0); hi = np.max([sc.part(n).hi for n in names], axis=0)
        tol = r.get('tol', .02)
        for i, ax in enumerate('xyz'):
            for bound, got in (('min', lo[i]), ('max', hi[i])):
                want = r.get(bound, [None] * 3)[i]
                if want is not None and abs(got - want) > tol:
                    bad.append({'part': r['part'], 'reason': '%s %s %.3f, expected %.3f +- %.3f' % (ax, bound, got, want, tol)})
    return {'status': 'FAIL' if bad else 'PASS', 'defects': bad}


def judge_probes(sc, rules):
    """Points that must be inside a matched closed part (winding number), or on a matched part's surface (within tol):
    a cornice corner that is really filled, a valley line both roofs really reach."""
    bad = []
    for r in rules:
        parts = [sc.part(n) for n in sc.names(r['part'])]
        if not parts:
            bad.append({'part': r['part'], 'reason': 'no part matches'}); continue
        for p in r.get('inside', []):
            if not any(P.closed and abs(lq.winding(np.array([p]), P)[0]) > .5 for P in parts):
                bad.append({'part': r['part'], 'point': p, 'reason': 'not inside'})
        for p in r.get('on', []):
            d = min(P.bvh.find_nearest(Vector(p))[3] for P in parts)
            if d > r.get('tol', .005):
                bad.append({'part': r['part'], 'point': p, 'reason': 'not on the surface (%.3f away)' % d})
    return {'status': 'FAIL' if bad else 'PASS', 'defects': bad}


def judge_up(sc, patterns):
    """Single-sided sheets that must face up (roof fields: the game draws the front side only): every face with
    area has a normal pointing above the horizon."""
    bad = []
    for n in sorted({n for p in patterns for n in sc.names(p)}):
        P = sc.part(n)
        down = sum(1 for nrm, a in zip(P.pn, P.pa) if a > 1e-6 and nrm.z <= .05)
        if down:
            bad.append({'part': n, 'faces_not_up': down})
    return {'status': 'FAIL' if bad or not any(sc.names(p) for p in patterns) else 'PASS', 'defects': bad}


def judge_undeclared(sc, junctions, cfg):
    lim = cfg.get('max_pen', .01)
    declared = set()
    for j in junctions:
        for a in sc.names(j['a']):
            for b in sc.names(j['b']):
                declared.add(frozenset((a, b)))
    names = list(sc.objs); found = []
    order = sorted(names, key=lambda n: sc.part(n).lo[0])
    for i, a in enumerate(order):
        A = sc.part(a)
        for b in order[i + 1:]:
            B = sc.part(b)
            if B.lo[0] > A.hi[0] + lq.CONTACT:
                break
            if frozenset((a, b)) in declared or not _near(A, B, lq.CONTACT):
                continue
            t, crossing = touching(A, B)
            if not t:
                continue
            d = max(depth(A, B, False)[0], depth(B, A, False)[0])
            zf = zfight(A, B)
            if d > lim or zf > ZFIGHT_AREA:
                found.append({'a': a, 'b': b, 'pen': round(d, 4), 'zfight': round(zf, 5)})
    found.sort(key=lambda x: (-x['pen'], x['a'], x['b']))
    return {'max_pen': lim, 'status': 'FAIL' if found else 'PASS', 'clashes': found}


def evaluate(key):
    """Score one answer key against the open scene. Returns the report dict."""
    sc = Scene(key.get('scope'))
    try:
        rep = {'name': key.get('name', ''), 'blend': bpy.data.filepath, 'scope': key.get('scope'), 'parts_in_scope': len(sc.objs),
               'junctions': [judge_junction(sc, j) for j in key.get('junctions', [])]}
        if key.get('orientation'):
            rep['orientation'] = judge_orientation(sc, key['orientation'])
        if key.get('up'):
            rep['up'] = judge_up(sc, key['up'])
        if key.get('extents'):
            rep['extents'] = judge_extents(sc, key['extents'])
        if key.get('probes'):
            rep['probes'] = judge_probes(sc, key['probes'])
        if key.get('undeclared', {}).get('scan'):
            rep['undeclared'] = judge_undeclared(sc, key.get('junctions', []), key['undeclared'])
    finally:
        sc.free()
    st = [j['status'] for j in rep['junctions']] + [rep[k]['status'] for k in EXTRA if k in rep]
    rep['status'] = 'PASS' if st and all(s == 'PASS' for s in st) else 'FAIL'
    return rep


def table(rep):
    lines = ['%s  %s' % (rep['status'], rep['name'])]
    for j in rep['junctions']:
        w = ' '.join('%s=%.3f' % (k[6:], j[k]) for k in ('worst_gap', 'worst_pen', 'worst_proud', 'worst_cover') if k in j)
        bad = [m for m in j['members'] if m['status'] != 'PASS']
        lines.append('  %-12s %-11s %-12s %s%s' % (j['status'], j['strategy'], j['id'], w,
                                                   ('  e.g. %s: %s' % (bad[0]['a'], bad[0].get('reason', ''))) if bad else
                                                   ('  ' + j['reason'] if j.get('reason') else '')))
    for k in EXTRA:
        if k in rep:
            r = rep[k]; d = r.get('defects', r.get('clashes', []))
            lines.append('  %-12s %s (%d)%s' % (r['status'], k, len(d), ('  e.g. ' + json.dumps(d[0])[:140]) if d else ''))
    return '\n'.join(lines)


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--key', required=True); ap.add_argument('--out', required=True); ap.add_argument('--strict', action='store_true')
    a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    rep = evaluate(json.load(open(a.key, encoding='utf-8')))
    with open(a.out, 'w', encoding='utf-8') as f:
        json.dump(rep, f, indent=1)
    print('JUNCTION_CHECK\n' + table(rep))
    if a.strict and rep['status'] != 'PASS':
        sys.exit(1)


if __name__ == '__main__':
    main()
