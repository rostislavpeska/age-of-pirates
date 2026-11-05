#!/usr/bin/env python
"""Decode an animation gr2 straight into converter-style GXO clip text (`a`, `cg`, `c`, `k` lines), no converter.

    python clip_decode.py CLIP.gr2 [CLIP.gr2 ...] [--out-dir DIR] [--method bspline|knots] [--fps N] [--units U]
    python clip_decode.py --archive Art/animation_library/cavalry/oprichnik_attack_A.gr2 [--extract-to DIR] ...

Why: a converter `--format gxo` dump of a clip is a pose at key 0 only. From key 1 on its 3x3s drift away from the
curves (verified 2026-10-11 on oprichnik_attack_a: Bip01_L_Clavicle's rotation curve is three controls equal within
4e-6, with identity scale-shear, yet the dump turns that bone and shrinks it, det 0.97 by key 17, 0.0003 by key 159,
5.3 by key 279). Neither a polar factor nor rest translations recover such keys.

Output, per input, `<stem>.gxo` in DIR (default a temp folder; a folder inside a git working tree is refused, the keys
are vanilla-derived): `a <keys> <fps>`, `cg "<track group>"`, then per transform track `c "<bone>"` and one `k` line per
key - the bone's local 3x3 (row-major, row vectors: p' = p @ M) and translation in the converter's GXO frame and units
(frame A of unit_gr2, translations x --units, default 1/2.54), so aoe3de-unit-animation's pose_sim.py and clip_angles.py
read it as they read a converter dump. Keys run every 1/fps s from 0 to the clip's Duration (default fps = 1/TimeStep,
192 for the oprichnik clips: 289 keys). Key 0 equals the converter's key 0 within 6e-7 on all 32 tracks of
oprichnik_attack_a (tests/test_unit_model_scripts.py pins the decode itself).

Curves decoded: Identity, Constant32f, D3Constant32f, D4Constant32f and K32fC32f (real32 knots and controls, any
degree; all 62 clips of the Iron Flail rider and horse animfiles use it, at degree 2 except some degree-0 curves in
rider_death_havoc_a/b, whose empty scale-shear curves are read as the identity - inferred). Compressed formats (K16uC16u, D4nK16uC15u, D3K8uC8u, ...) are
refused by name. `--method bspline` (default) evaluates the B-spline of the curve's degree with one knot per control:
on [knot i-1, knot i) controls i-degree..i (Cox-de Boor; at degree 1 that is a linear key at each knot). Granny's own
index alignment is inferred, not measured; `--method knots` reads every control as a key at its knot time (linear,
the LSLib reading) to show how much the choice moves a result. Orientations are renormalized. Scale-shear composes as
M = R @ S in the row-vector form, the converter's own order: its key 0 of horse_idle_a (20 stretch tracks with keyed
scale-shear) matches within 2.8e-7, the other order misses by 4e-4; tracks with scale-shear are counted in the summary.
"""
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import unit_gr2 as U  # noqa: E402
from gr2_dump import CURVE_FMT, refs  # noqa: E402  (consumer reader, on sys.path through unit_gr2)


class Undecodable(Exception):
    pass


def q2m(q):
    """unit quaternion (x, y, z, w) -> column-vector rotation matrix."""
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def _floats(g, arr):
    _, n, p = arr[:3]
    return np.array(struct.unpack_from('<%df' % n, g.payload[p[0]], p[1]), float) if n else np.zeros(0)


def read_curve(g, cv, dim):
    """granny curve2 -> (format name, degree, knots (n,), controls (n, dim)); None for an identity curve."""
    v = cv.get('CurveData') if cv else None
    if not v or v[0] != 'variant' or not v[1] or not v[2]:
        return None
    tp, op = v[1], v[2]
    fmt, degree = g.payload[op[0]][op[1]], g.payload[op[0]][op[1] + 1]
    name = CURVE_FMT.get(fmt, str(fmt))
    if fmt == 2:
        return None
    rec = g.read(*tp, *op)
    if fmt in (3, 4, 5):
        c = rec.get('Controls')
        vals = _floats(g, c) if isinstance(c, tuple) and c and c[0] == 'array' else np.array(c, float)
        if len(vals) != dim:
            raise Undecodable('%s with %d controls for a %d-vector' % (name, len(vals), dim))
        return name, 0, np.zeros(1), vals.reshape(1, dim)
    if fmt == 1:
        K, C = _floats(g, rec['Knots']), _floats(g, rec['Controls'])
        if not len(K) and not len(C):
            return None                                     # an empty curve holds the identity (inferred)
        if not len(K) or len(C) != len(K) * dim:
            raise Undecodable('%s: %d knots, %d controls for a %d-vector' % (name, len(K), len(C), dim))
        return name, degree, K, C.reshape(len(K), dim)
    raise Undecodable('curve format %s is not decoded (compressed); only key 0 of a converter dump stands in' % name)


def bspline(K, C, degree, t):
    """value at t of the degree-`degree` B-spline with knot K[m] and control C[m] per index: on [K[i-1], K[i]) the
    controls C[i-degree..i] and knots K[i-degree..i+degree-1] (indices clamped at both ends). Cox-de Boor."""
    n = len(K)
    if n == 1:
        return C[0].copy()
    t = min(max(t, K[0]), K[-1])
    i = int(np.searchsorted(K, t, side='right'))              # first knot > t
    i = min(max(i, 1), n - 1)
    p = int(degree)

    def knot(m):                                            # standard knot vector: u_m = K[m - 1]
        return K[min(max(m - 1, 0), n - 1)]
    d = [C[min(max(i - p + j, 0), n - 1)].astype(float).copy() for j in range(p + 1)]
    for r in range(1, p + 1):
        for j in range(p, r - 1, -1):
            lo, hi = knot(j + i - p), knot(j + 1 + i - r)
            a = 0.0 if hi == lo else (t - lo) / (hi - lo)
            d[j] = (1.0 - a) * d[j - 1] + a * d[j]
    return d[p]


def sample(curve, t, method='bspline'):
    _, degree, K, C = curve
    return bspline(K, C, 1 if method == 'knots' and degree > 1 else degree, t)


def local_matrix(q, p, ss, units=U.GXO_PER_ENGINE):
    """engine (quaternion, position, scale-shear 3x3) -> GXO-frame row-vector 4x4 like a converter key
    (rotation then scale-shear in row-vector form, the converter's order)."""
    q = np.asarray(q, float)
    q = q / (np.linalg.norm(q) or 1.0)
    M3 = q2m(q).T @ np.asarray(ss, float).reshape(3, 3)
    out = np.eye(4)
    out[:3, :3] = U.A @ M3 @ U.A.T
    out[3, :3] = np.asarray(p, float) @ U.A.T * units
    return out


def decode(path, method='bspline', fps=None, units=U.GXO_PER_ENGINE):
    """-> dict(group, fps, keys, tracks [(name, [4x4 per key])], formats {name: count}, ss_keys, det_dev)."""
    g = U.Gr2(str(path))
    anims = [a for a, _ in refs(g, g.root().get('Animations'))]
    if not anims:
        raise Undecodable('%s holds no animation' % Path(path).name)
    an = anims[0]
    dur, step = float(an['Duration'][0]), float(an['TimeStep'][0])
    fps = fps or round(1.0 / step)
    nkeys = int(round(dur * fps)) + 1
    groups = [t for t, _ in refs(g, an.get('TrackGroups'))]
    tg = groups[0]
    times = [min(f / fps, dur) for f in range(nkeys)]
    tracks, formats, ss_keys, det_dev = [], {}, 0, 0.0
    ident = {'rot': np.array([0.0, 0, 0, 1]), 'pos': np.zeros(3), 'scl': np.eye(3).ravel()}
    for tr in g.array(tg['TransformTracks']):
        curves = {}
        for key, field, dim in (('rot', 'OrientationCurve', 4), ('pos', 'PositionCurve', 3),
                                ('scl', 'ScaleShearCurve', 9)):
            c = read_curve(g, tr[field], dim)
            label = 'Identity' if c is None else '%s deg %d' % (c[0], c[1])
            formats[label] = formats.get(label, 0) + 1
            curves[key] = c
        keys = []
        for t in times:
            v = {k: (ident[k] if c is None else sample(c, t, method)) for k, c in curves.items()}
            if np.abs(np.asarray(v['scl']) - ident['scl']).max() > 1e-4:
                ss_keys += 1
            M = local_matrix(v['rot'], v['pos'], v['scl'], units)
            det_dev = max(det_dev, abs(np.linalg.det(M[:3, :3]) - np.linalg.det(np.asarray(v['scl']).reshape(3, 3))))
            keys.append(M)
        tracks.append((tr['Name'], keys))
    return dict(group=tg['Name'], fps=fps, keys=nkeys, duration=dur, tracks=tracks, formats=formats, ss_keys=ss_keys,
                det_dev=det_dev, groups=len(groups), animations=len(anims))


def gxo_text(res):
    lines = ['a %d %d' % (res['keys'], res['fps']), 'cg "%s"' % res['group']]
    for name, keys in res['tracks']:
        lines.append('c "%s"' % name)
        for M in keys:
            lines.append('k ' + ' '.join('%.9g' % x for x in list(M[:3, :3].ravel()) + list(M[3, :3])))
    return '\n'.join(lines) + '\n'


def refuse_repo_target(path):
    U.refuse_repo_target(path, 'decoded clips are vanilla-derived')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    U.add_input_args(ap)
    ap.add_argument('--out-dir', help='folder for the GXO files (default: a temp folder; never a repository)')
    ap.add_argument('--method', choices=('bspline', 'knots'), default='bspline')
    ap.add_argument('--fps', type=int, help='keys per second (default: 1 / the clip TimeStep)')
    ap.add_argument('--units', type=float, default=U.GXO_PER_ENGINE,
                    help='GXO units per engine unit for translations (default 1/2.54, a converter dump)')
    a = ap.parse_args(argv)
    out_dir = Path(a.out_dir) if a.out_dir else U.temp_dir('clips')
    refuse_repo_target(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for p in U.resolve_inputs(a):
        try:
            res = decode(p, a.method, a.fps, a.units)
        except (Undecodable, U.Unreadable, NotImplementedError) as e:
            print('SKIP %s: %s' % (Path(p).name, e))
            continue
        out = out_dir / (Path(p).stem + '.gxo')
        out.write_text(gxo_text(res), encoding='utf-8', newline='\n')
        written.append(out)
        print('%s: %d tracks x %d keys at %d fps (%.3f s, %s), curves %s, scale-shear keys %d, max |det - det(S)| %.1e'
              % (out, len(res['tracks']), res['keys'], res['fps'], res['duration'], a.method,
                 dict(sorted(res['formats'].items())), res['ss_keys'], res['det_dev']))
        if res['groups'] > 1 or res['animations'] > 1:
            print('  note: only the first animation / track group was decoded')
    return written


if __name__ == '__main__':
    main()
