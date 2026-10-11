#!/usr/bin/env python
"""Export metrics from the viewer's geometry dumps: rider-horse penetration and hoof height (M5 compare mode).

    python metrics.py FRAME.geom.bin [...] [--json]        # one line per dump (or the JSON records)

    import metrics as MX
    g = MX.read_geom(path)               # {header, t, instances: [{role, model, bones, meshes: [{name, posed, bind,
                                         #   indices, bone}]}]} - numpy arrays, engine (gr2) frame, +Y up
    MX.penetration(g)                    # rider (child) vertices inside the horse (main) meshes, with depths
    MX.hoof_heights(g)                   # lowest vertex of each leg (FL, FR, BL, BR) above the ground plane y = 0
    MX.leg_of_footprint('HS BONE HOOF FRNT LT', 'FootstepLeft')   # -> ['FL']

The dumps come from viewer/export/geometry.js (layout in its header comment): the posed meshes are the viewer's
CPU-skinned positions (rig.js skinPositions, the same pose the PNG shows). Both metrics are approximations, flagged A
in the bundle fidelity (bundle.py EXPORT_STAGES):
- penetration: a rider vertex is inside when the generalised winding number of the horse triangles around it is above
  0.5 in magnitude (Jacobson et al. 2013: robust on open triangle soups, any consistent winding); its depth is the
  distance to the nearest horse triangle. Units are the gr2's (metres assumed).
- hoof height: the legs are the horse vertices in the lowest LEG_FRACTION of the bind pose's height, split front/back
  and left/right. The forward side is where the vertices bound to a head/neck/skull bone sit, the left side where the
  bones named *_l / L ... sit (both measured from the dump's own skeleton names; the Iron Flail horse faces +Z with its
  _l bones on -X, the defaults when a skeleton names neither). The footprintbone of a footstep tag
  (HS BONE HOOF FRNT LT ...) picks the leg; without one the tag type picks the side.
Brute force with numpy in chunks: a rider of ~1k vertices against ~1.4k horse triangles takes milliseconds.
"""
from __future__ import annotations

import argparse
import json
import re
import struct
import sys
from pathlib import Path

import numpy as np

MAGIC = b'AVGEOM1\x00'
DTYPES = {'f32': np.float32, 'u32': np.uint32, 'i16': np.int16}
LEG_FRACTION = 0.12
WINDING_INSIDE = 0.5
LEGS = ('FL', 'FR', 'BL', 'BR')
DEFAULT_FORWARD = 1.0       # +Z: the Iron Flail horse's head bone sits at z = +0.90 (bind pose), its tail at -1.22
DEFAULT_LEFT = -1.0         # -X: its shoulder_l / thigh_stretch_l / hand_l / toes_01_l bones sit on -x
HEAD_RE = re.compile(r'head|neck|skull', re.I)
LEFT_RE = re.compile(r'(^|[ _])l([ _]|$)|left', re.I)
RIGHT_RE = re.compile(r'(^|[ _])r([ _]|$)|right', re.I)


# ---------------------------------------------------------------------------------------------------- the dump
def write_geom(header, arrays) -> bytes:
    """the AVGEOM1 bytes of a header and its arrays (the writer the tests use; geometry.js packGeometry in the page).
    Array offsets in the header are filled here, in the order of `arrays` [(mesh dict, name, ndarray)]."""
    blobs, off = [], 0
    for mesh, name, arr in arrays:
        dt = {np.dtype(np.float32): 'f32', np.dtype(np.uint32): 'u32', np.dtype(np.int16): 'i16'}[arr.dtype]
        comps = arr.shape[1] if arr.ndim == 2 else 1
        mesh.setdefault('arrays', {})[name] = {'offset': off, 'dtype': dt, 'count': arr.shape[0], 'components': comps}
        b = np.ascontiguousarray(arr).tobytes()
        b += b'\x00' * ((4 - len(b) % 4) % 4)
        blobs.append(b)
        off += len(b)
    hj = json.dumps(header).encode('utf-8')
    hj += b' ' * ((4 - len(hj) % 4) % 4)
    return MAGIC + struct.pack('<I', len(hj)) + hj + b''.join(blobs)


def read_geom(src) -> dict:
    """a geometry dump (path or bytes) -> {header, t, meta, instances: [{role, model, animfile, anim, variant, clip,
    bones, meshes: [{name, posed (n,3) f64, bind (n,3) f64, indices (m,3) i64, bone (n,) i64}]}]}"""
    data = Path(src).read_bytes() if not isinstance(src, (bytes, bytearray, memoryview)) else bytes(src)
    if data[:8] != MAGIC:
        raise ValueError('not an AVGEOM1 geometry dump')
    hl = struct.unpack_from('<I', data, 8)[0]
    header = json.loads(data[12:12 + hl].decode('utf-8'))
    base = 12 + hl
    out = {'header': header, 't': header.get('t'), 'meta': header.get('meta') or {}, 'instances': []}
    for inst in header.get('instances', []):
        meshes = []
        for m in inst.get('meshes', []):
            arr = {}
            for name, r in m.get('arrays', {}).items():
                dt = np.dtype(DTYPES[r['dtype']])
                comps = r.get('components') or 1
                a = np.frombuffer(data, dt, r['count'] * comps, base + r['offset'])
                arr[name] = a.reshape(-1, comps) if comps > 1 else a
            meshes.append({'name': m.get('name'), 'vertex_count': m.get('vertex_count'),
                           'posed': arr.get('posed', np.zeros((0, 3), np.float32)).astype(np.float64),
                           'bind': arr.get('bind', np.zeros((0, 3), np.float32)).astype(np.float64),
                           'indices': arr.get('indices', np.zeros((0, 3), np.uint32)).astype(np.int64),
                           'bone': arr.get('bone', np.zeros(0, np.int16)).astype(np.int64)})
        out['instances'].append(dict({k: v for k, v in inst.items() if k != 'meshes'}, meshes=meshes))
    return out


def _gather(geom, roles, key='posed'):
    """(vertices (n,3), triangles (m,3) into them, owner rows [(instance, mesh)], vertex owner index, vertex bone
    names) of every mesh of the instances with these roles."""
    vs, ts, owners, own, names = [], [], [], [], []
    n = 0
    for inst in geom['instances']:
        if inst.get('role') not in roles:
            continue
        bones = inst.get('bones') or []
        for m in inst['meshes']:
            v = m[key]
            if not len(v):
                continue
            vs.append(v)
            if len(m['indices']):
                ts.append(m['indices'] + n)
            owners.append((inst.get('model'), m.get('name')))
            own.append(np.full(len(v), len(owners) - 1))
            b = m['bone'] if len(m['bone']) == len(v) else np.full(len(v), -1)
            names.extend(bones[i] if 0 <= i < len(bones) else None for i in b)
            n += len(v)
    if not vs:
        return np.zeros((0, 3)), np.zeros((0, 3), np.int64), [], np.zeros(0, np.int64), []
    return np.vstack(vs), (np.vstack(ts) if ts else np.zeros((0, 3), np.int64)), owners, np.concatenate(own), names


def _tri_verts(V, T):
    tv = V[T]                                                # (m, 3, 3)
    area = np.linalg.norm(np.cross(tv[:, 1] - tv[:, 0], tv[:, 2] - tv[:, 0]), axis=1)
    return tv[area > 1e-12]


# ---------------------------------------------------------------------------------------------------- geometry maths
def winding_numbers(points, tv, chunk=256) -> np.ndarray:
    """generalised winding number of the triangles tv (m, 3, 3) around each point (k, 3): sum of the signed solid
    angles / 4 pi (Van Oosterom-Strackee). About +-1 inside a closed surface, 0 outside, robust on open soups."""
    P = np.asarray(points, np.float64)
    out = np.zeros(len(P))
    if not len(tv) or not len(P):
        return out
    A0, B0, C0 = tv[:, 0][None], tv[:, 1][None], tv[:, 2][None]
    for s in range(0, len(P), chunk):
        p = P[s:s + chunk, None, :]
        a, b, c = A0 - p, B0 - p, C0 - p
        la, lb, lc = (np.linalg.norm(x, axis=2) for x in (a, b, c))
        det = np.einsum('kmi,kmi->km', a, np.cross(b, c))
        den = la * lb * lc + np.einsum('kmi,kmi->km', a, b) * lc + np.einsum('kmi,kmi->km', b, c) * la + \
            np.einsum('kmi,kmi->km', c, a) * lb
        out[s:s + chunk] = (2.0 * np.arctan2(det, den)).sum(axis=1) / (4.0 * np.pi)
    return out


def closest_on_triangles(p, a, b, c):
    """closest points on triangles (a, b, c broadcast against p), Ericson's region tests, vectorised."""
    ab, ac, ap = b - a, c - a, p - a
    dot = lambda x, y: np.einsum('...i,...i->...', x, y)  # noqa: E731
    d1, d2 = dot(ab, ap), dot(ac, ap)
    bp = p - b
    d3, d4 = dot(ab, bp), dot(ac, bp)
    cp = p - c
    d5, d6 = dot(ab, cp), dot(ac, cp)
    va, vb, vc = d3 * d6 - d5 * d4, d5 * d2 - d1 * d6, d1 * d4 - d3 * d2
    with np.errstate(divide='ignore', invalid='ignore'):
        den = va + vb + vc
        v, w = vb / den, vc / den
        res = a + ab * v[..., None] + ac * w[..., None]
        wbc = (d4 - d3) / ((d4 - d3) + (d5 - d6))
        res = np.where(((va <= 0) & (d4 - d3 >= 0) & (d5 - d6 >= 0))[..., None], b + (c - b) * wbc[..., None], res)
        wac = d2 / (d2 - d6)
        res = np.where(((vb <= 0) & (d2 >= 0) & (d6 <= 0))[..., None], a + ac * wac[..., None], res)
        res = np.where(((d6 >= 0) & (d5 <= d6))[..., None], c, res)
        vab = d1 / (d1 - d3)
        res = np.where(((vc <= 0) & (d1 >= 0) & (d3 <= 0))[..., None], a + ab * vab[..., None], res)
        res = np.where(((d3 >= 0) & (d4 <= d3))[..., None], b, res)
        res = np.where(((d1 <= 0) & (d2 <= 0))[..., None], a, res)
    return res


def nearest_distances(points, tv, chunk=128):
    """(distance, triangle index) of the nearest triangle of tv (m, 3, 3) to each point (k, 3)."""
    P = np.asarray(points, np.float64)
    dist = np.full(len(P), np.inf)
    idx = np.full(len(P), -1, np.int64)
    if not len(tv) or not len(P):
        return dist, idx
    a, b, c = tv[:, 0][None], tv[:, 1][None], tv[:, 2][None]
    for s in range(0, len(P), chunk):
        p = P[s:s + chunk, None, :]
        q = closest_on_triangles(p, a, b, c)
        d = np.linalg.norm(q - p, axis=2)
        j = np.argmin(d, axis=1)
        dist[s:s + chunk] = d[np.arange(len(j)), j]
        idx[s:s + chunk] = j
    return dist, idx


# ---------------------------------------------------------------------------------------------------- penetration
def penetration(geom, rider_roles=('child',), body_roles=('main',), threshold=WINDING_INSIDE) -> dict:
    """rider vertices inside the body meshes: {status, n_points, n_inside, frac_inside, max_depth, mean_depth,
    p95_depth, deepest {mesh, model, bone, position, depth}, by_bone [{bone, n, max_depth}], by_mesh [...],
    body_triangles, rule}. status 'n/a' when the dump has no rider or no body."""
    P, _t, owners, own, names = _gather(geom, rider_roles)
    V, T, _o, _w, _n = _gather(geom, body_roles)
    rule = 'inside: |generalised winding number| > %.2f of the %s triangles; depth: distance to the nearest one' % (
        threshold, '/'.join(body_roles))
    if not len(P) or not len(T):
        return {'status': 'n/a', 'reason': 'no %s vertices' % '/'.join(rider_roles) if not len(P) else
                'no %s triangles' % '/'.join(body_roles), 'rule': rule}
    tv = _tri_verts(V, T)
    lo, hi = tv.reshape(-1, 3).min(0) - 1e-6, tv.reshape(-1, 3).max(0) + 1e-6
    cand = np.where(np.all((P >= lo) & (P <= hi), axis=1))[0]          # outside the body's box: never inside
    w = np.zeros(len(P))
    w[cand] = winding_numbers(P[cand], tv)
    inside = np.abs(w) > threshold
    ii = np.where(inside)[0]
    depth = np.zeros(len(P))
    if len(ii):
        depth[ii], _j = nearest_distances(P[ii], tv)
    rec = {'status': 'ok', 'n_points': int(len(P)), 'n_inside': int(len(ii)), 'frac_inside': float(len(ii) / len(P)),
           'max_depth': float(depth.max()) if len(ii) else 0.0,
           'mean_depth': float(depth[ii].mean()) if len(ii) else 0.0,
           'p95_depth': float(np.percentile(depth[ii], 95)) if len(ii) else 0.0,
           'body_triangles': int(len(tv)), 'rule': rule, 'deepest': None, 'by_bone': [], 'by_mesh': []}
    if len(ii):
        k = int(ii[np.argmax(depth[ii])])
        model, mesh = owners[own[k]]
        rec['deepest'] = {'model': model, 'mesh': mesh, 'bone': names[k], 'position': [float(x) for x in P[k]],
                          'depth': float(depth[k])}
        by = {}
        for i in ii:
            e = by.setdefault(names[i] or '-', [0, 0.0])
            e[0] += 1
            e[1] = max(e[1], float(depth[i]))
        rec['by_bone'] = [{'bone': b, 'n': n, 'max_depth': d} for b, (n, d) in
                          sorted(by.items(), key=lambda kv: -kv[1][1])[:8]]
        for oi, (model, mesh) in enumerate(owners):
            sel = ii[own[ii] == oi]
            if len(sel):
                rec['by_mesh'].append({'model': model, 'mesh': mesh, 'n_inside': int(len(sel)),
                                       'max_depth': float(depth[sel].max())})
    return rec


# ---------------------------------------------------------------------------------------------------- hoof height
def body_axes(geom, roles=('main',)) -> dict:
    """{forward: +1/-1 (the z side the head is on), left: +1/-1 (the x side of the left bones), source} from the bind
    positions of the vertices bound to head/neck/skull bones and to left/right-named bones."""
    B, _t, _o, _w, names = _gather(geom, roles, key='bind')
    out = {'forward': DEFAULT_FORWARD, 'left': DEFAULT_LEFT, 'source': {'forward': 'default', 'left': 'default'}}
    if not len(B):
        return out
    names = np.array([n or '' for n in names], dtype=object)
    cz, cx = float(np.median(B[:, 2])), float(np.median(B[:, 0]))
    head = np.array([bool(HEAD_RE.search(n)) for n in names])
    if head.any():
        dz = float(B[head, 2].mean() - cz)
        if abs(dz) > 1e-6:
            out['forward'] = 1.0 if dz > 0 else -1.0
            out['source']['forward'] = 'skeleton (head/neck/skull bones)'
    left = np.array([bool(LEFT_RE.search(n)) for n in names])
    right = np.array([bool(RIGHT_RE.search(n)) for n in names])
    if left.any() and right.any():
        dx = float(B[left, 0].mean() - B[right, 0].mean())
        if abs(dx) > 1e-6:
            out['left'] = 1.0 if dx > 0 else -1.0
            out['source']['left'] = 'skeleton (left/right bone names)'
    elif left.any():
        dx = float(B[left, 0].mean() - cx)
        if abs(dx) > 1e-6:
            out['left'] = 1.0 if dx > 0 else -1.0
            out['source']['left'] = 'skeleton (left bone names)'
    return out


def leg_groups(geom, roles=('main',), fraction=LEG_FRACTION, axes=None) -> dict:
    """{FL, FR, BL, BR: vertex index arrays into the gathered vertices}, the axes and the height threshold: the
    vertices in the lowest `fraction` of the bind pose, split at the middle of their z and x extents."""
    B, _t, _o, _w, _n = _gather(geom, roles, key='bind')
    axes = axes or body_axes(geom, roles)
    if not len(B):
        return {'legs': {k: np.zeros(0, np.int64) for k in LEGS}, 'axes': axes, 'threshold': None}
    y0, y1 = float(B[:, 1].min()), float(B[:, 1].max())
    thr = y0 + fraction * (y1 - y0)
    low = np.where(B[:, 1] <= thr)[0]
    zm = 0.5 * (B[low, 2].min() + B[low, 2].max())
    xm = 0.5 * (B[low, 0].min() + B[low, 0].max())
    front = (B[low, 2] - zm) * axes['forward'] > 0
    leftside = (B[low, 0] - xm) * axes['left'] > 0
    legs = {'FL': low[front & leftside], 'FR': low[front & ~leftside], 'BL': low[~front & leftside],
            'BR': low[~front & ~leftside]}
    return {'legs': legs, 'axes': axes, 'threshold': thr}


def hoof_heights(geom, roles=('main',), groups=None) -> dict:
    """{status, legs: {FL: {height, n, position}, ...}, lowest, axes, threshold, rule}: the lowest posed vertex of each
    leg above the ground plane y = 0 (engine frame)."""
    P, _t, _o, _w, _n = _gather(geom, roles, key='posed')
    if not len(P):
        return {'status': 'n/a', 'reason': 'no %s vertices' % '/'.join(roles)}
    g = groups or leg_groups(geom, roles)
    legs = {}
    for k, idx in g['legs'].items():
        if len(idx):
            j = int(idx[np.argmin(P[idx, 1])])
            legs[k] = {'height': float(P[j, 1]), 'n': int(len(idx)), 'position': [float(x) for x in P[j]]}
        else:
            legs[k] = {'height': None, 'n': 0, 'position': None}
    return {'status': 'ok', 'legs': legs, 'lowest': float(P[:, 1].min()), 'axes': g['axes'],
            'threshold': g['threshold'], 'leg_fraction': LEG_FRACTION,
            'rule': 'lowest posed vertex of each leg (legs: the lowest %d %% of the bind pose, split front/back, '
                    'left/right) above y = 0' % round(LEG_FRACTION * 100)}


def leg_of_footprint(bone, tag_type=None) -> list:
    """the legs a footstep names: its footprintbone tokens (FRNT / FRONT / FORE, BACK / REAR / HIND; LT / LEFT, RT /
    RIGHT), else its type's side (FootstepLeft -> FL, BL)."""
    toks = {t for t in re.split(r'[^A-Za-z]+', str(bone or '').upper()) if t}
    fb = 'F' if toks & {'FRNT', 'FRONT', 'FORE', 'FR', 'FRT'} else 'B' if toks & {'BACK', 'BK', 'REAR', 'HIND'} else None
    side = 'L' if toks & {'LT', 'LEFT', 'L', 'LFT'} else 'R' if toks & {'RT', 'RIGHT', 'R', 'RGT'} else None
    if side is None and tag_type:
        t = str(tag_type).lower()
        side = 'L' if t.endswith('left') else 'R' if t.endswith('right') else None
    fbs = [fb] if fb else ['F', 'B']
    sides = [side] if side else ['L', 'R']
    return [f + s for f in fbs for s in sides]


def footstep_report(geom, tags, roles=('main',)) -> list:
    """per footstep tag of these roles: {type, footprintbone, legs, heights {leg: h}, height (the lowest named leg)}"""
    hh = hoof_heights(geom, roles)
    out = []
    for tag in tags or []:
        if not tag.get('footstep') or tag.get('role') not in roles:
            continue
        legs = leg_of_footprint(tag.get('footprintbone') or (tag.get('attrs') or {}).get('footprintbone'),
                                tag.get('type'))
        hs = {k: (hh.get('legs', {}).get(k) or {}).get('height') for k in legs}
        vals = [v for v in hs.values() if v is not None]
        out.append({'type': tag.get('type'), 'time': tag.get('time'), 'fraction': tag.get('fraction'),
                    'footprintbone': tag.get('footprintbone'), 'legs': legs, 'heights': hs,
                    'height': min(vals) if vals else None, 'all_legs': {k: v['height'] for k, v in
                                                                        (hh.get('legs') or {}).items()}})
    return out


def summarise(path) -> dict:
    g = read_geom(path)
    return {'file': str(path), 't': g['t'], 'meta': g['meta'], 'penetration': penetration(g),
            'hooves': hoof_heights(g)}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('dumps', nargs='+')
    ap.add_argument('--json', action='store_true')
    a = ap.parse_args(argv)
    recs = [summarise(p) for p in a.dumps]
    if a.json:
        sys.stdout.write(json.dumps(recs, indent=1) + '\n')
        return 0
    for r in recs:
        p, h = r['penetration'], r['hooves']
        legs = ' '.join('%s %s' % (k, '-' if v['height'] is None else '%.3f' % v['height'])
                        for k, v in (h.get('legs') or {}).items())
        print('%s  t=%.4f  penetration %s  hooves %s' % (Path(r['file']).name, r['t'] or 0,
              'n/a' if p['status'] != 'ok' else 'max %.3f, %d/%d inside' % (p['max_depth'], p['n_inside'],
                                                                           p['n_points']), legs))
    return 0


if __name__ == '__main__':
    sys.exit(main())
