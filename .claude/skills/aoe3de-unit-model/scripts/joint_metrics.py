#!/usr/bin/env python
"""Joint facts of rider gr2 files (read-only): bind pose, segment lengths, edge rings and weight blends at the joints.

    python joint_metrics.py --archive Art/units/asians/chinese/iron_flail/iron_rider_0.gr2 [...] [--what all]
    python joint_metrics.py FILE.gr2 [...] --what bind,segments,rings,blends,density,sides,axes

bind: angles of the rest skeleton from the InverseWorld matrices (degrees): hip flexion = thigh vector vs the down axis
  (neck -> pelvis), knee = thigh vs shin, elbow = upper arm vs forearm, arm from down = upper arm vs down, thigh spread.
segments: joint-to-joint lengths (engine units) of the rider rig.
rings: vertex rings across the knee (Calf joint) and elbow (ForeArm joint): unique positions dominated by the two bones
  of the joint, projected on the bent limb axis through the joint, |t| < 35 % of the upper segment and radius < 60 %;
  the axial coordinate is clustered (gap > 1.2 % of the segment) and clusters of >= 3 positions are rings:
  (t / segment, positions, share with 2+ influences, mean weight of the lower bone). Approximate: oblique loops split
  or merge. A ring is blended when its share is > 0; the lower-bone weights of the blended rings are the row recipe.
blends: hinge blends - unique positions whose two largest weights are the two bones of a joint (knee, elbow, ankle,
  wrist, head-chest, pelvis-thigh, clavicle-upper arm, pelvis-spine, spine-spine1): count and median minor weight.
density: unique positions per 10 % of segment length within 15 % of the knee / elbow against mid upper segment.
sides: positions per ring at mid-segment (thigh, calf, upper arm, forearm; 25-75 % of the segment).
axes: principal axis of the positions each limb and torso bone dominates, in degrees from vertical (standing or
  seated modelling).
Backs "Influences and weights" (hinge blends, density) and "Joint rings and blend rows" of
vanilla-unit-measurements.md and sections 3-4 of rider-skeleton.md.
"""
import argparse
import math
import statistics
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import unit_gr2 as U  # noqa: E402

SEGMENTS = [('pelvis', 'l thigh'), ('l thigh', 'l calf'), ('l calf', 'l foot'), ('pelvis', 'spine'),
            ('spine', 'spine1'), ('spine1', 'head'), ('l clavicle', 'l upperarm'), ('l upperarm', 'l forearm'),
            ('l forearm', 'l hand')]
JOINTS = {tuple(sorted(k)): v for k, v in {
    ('thigh', 'calf'): 'knee', ('upperarm', 'forearm'): 'elbow', ('calf', 'foot'): 'ankle', ('forearm', 'hand'): 'wrist',
    ('head', 'spine1'): 'head-chest', ('pelvis', 'thigh'): 'pelvis-thigh', ('clavicle', 'upperarm'): 'clavicle-upperarm',
    ('pelvis', 'spine'): 'pelvis-spine', ('spine', 'spine1'): 'spine-spine1'}.items()}


def ang(a, b):
    a = a / (np.linalg.norm(a) or 1)
    b = b / (np.linalg.norm(b) or 1)
    return math.degrees(math.acos(max(-1.0, min(1.0, float(a @ b)))))


def bind(m):
    J = m.joints()

    def j(n):
        return J['bip01 ' + n]
    down = j('pelvis') - j('neck')
    r = {}
    for s in 'lr':
        th, sh = j(s + ' calf') - j(s + ' thigh'), j(s + ' foot') - j(s + ' calf')
        ua, fa = j(s + ' forearm') - j(s + ' upperarm'), j(s + ' hand') - j(s + ' forearm')
        r[s] = dict(hip=round(ang(th, down), 1), knee=round(ang(th, sh), 1), elbow=round(ang(ua, fa), 1),
                    arm_from_down=round(ang(ua, down), 1))
    r['thigh_spread'] = round(ang(j('l calf') - j('l thigh'), j('r calf') - j('r thigh')), 1)
    ys = [p[1] for p in J.values()]
    r['joint_y'] = (round(min(ys), 3), round(max(ys), 3))
    r['root'] = [round(float(x), 4) for x in m.skeleton[0]['world'][3, :3]] if m.skeleton else None
    r['pelvis'] = [round(float(x), 4) for x in j('pelvis')]
    return r


def segments(m):
    J = m.joints()
    return {'%s -> %s' % s: round(float(np.linalg.norm(J['bip01 ' + s[1]] - J['bip01 ' + s[0]])), 3)
            for s in SEGMENTS if 'bip01 ' + s[0] in J and 'bip01 ' + s[1] in J}


def unique_weighted(m):
    """[(position, {nm(bone): w})] over the skinned meshes, one per position (rounded 1e-4)."""
    out = []
    for me in m.meshes:
        if not me.skinned:
            continue
        seen = set()
        for p, w in zip(me.pos, me.vertex_weights()):
            k = tuple(np.round(p, 4))
            if k in seen:
                continue
            seen.add(k)
            out.append((p, {U.nm(b): x for b, x in w.items()}))
    return out


def rings(V, J, upper, lower, child):
    a, b, c = J['bip01 ' + upper], J['bip01 ' + lower], J['bip01 ' + child]
    L = float(np.linalg.norm(b - a))
    axis = (b - a) / L + (c - b) / np.linalg.norm(c - b)
    axis /= np.linalg.norm(axis)
    sel = []
    for p, wd in V:
        if not wd:
            continue
        dom = max(wd, key=wd.get)
        if dom not in ('bip01 ' + upper, 'bip01 ' + lower):
            continue
        d = p - b
        t = float(d @ axis)
        r = float(np.linalg.norm(d - t * axis))
        if abs(t) < 0.35 * L and r < 0.6 * L:
            sel.append((t / L, len(wd) > 1, wd.get('bip01 ' + lower, 0.0)))
    sel.sort()
    cl, cur = [], []
    for s in sel:
        if cur and s[0] - cur[-1][0] > 0.012:
            cl.append(cur)
            cur = []
        cur.append(s)
    if cur:
        cl.append(cur)
    res = []
    for c_ in cl:
        if len(c_) >= 3:
            res.append((round(sum(x[0] for x in c_) / len(c_), 3), len(c_),
                        round(sum(1 for x in c_ if x[1]) / len(c_), 2), round(sum(x[2] for x in c_) / len(c_), 2)))
    return round(L, 3), res


def joint_rings(m):
    J, V = m.joints(), unique_weighted(m)
    out = {}
    for side in ('l', 'r'):
        for label, (u, lo, ch) in (('knee', ('thigh', 'calf', 'foot')), ('elbow', ('upperarm', 'forearm', 'hand'))):
            try:
                L, res = rings(V, J, side + ' ' + u, side + ' ' + lo, side + ' ' + ch)
            except KeyError:
                continue
            blended = [r for r in res if r[2] > 0]
            out['%s %s' % (label, side)] = dict(segment=L, rings=res, blended_rows=len(blended),
                                                row_weights=[r[3] for r in blended])
    return out


def part(bone):
    """'bip01 l thigh' -> ('l', 'thigh'); 'bip01 spine1' -> ('', 'spine1')"""
    t = bone.split()
    if len(t) >= 3 and t[1] in ('l', 'r'):
        return t[1], t[2]
    return '', t[-1]


def blends(m):
    return blend_counts(unique_weighted(m))


def blend_counts(V):
    """V [(position, {nm(bone): w})] -> {joint: {positions, median_minor}} for positions whose two largest weights are
    the two bones of a joint."""
    acc = {}
    for _, wd in V:
        if len(wd) < 2:
            continue
        (b1, w1), (b2, w2) = sorted(wd.items(), key=lambda kv: -kv[1])[:2]
        (s1, p1), (s2, p2) = part(b1), part(b2)
        name = JOINTS.get(tuple(sorted((p1, p2))))
        if not name:
            continue
        side = s1 or s2
        key = name + (' ' + side if side and name not in ('head-chest', 'pelvis-spine', 'spine-spine1') else '')
        acc.setdefault(key, []).append(w2)
    return {k: dict(positions=len(v), median_minor=round(statistics.median(v), 2)) for k, v in sorted(acc.items())}


def density(m):
    J, V = m.joints(), unique_weighted(m)
    out = {}
    for lab, (u, lo) in (('knee', ('l thigh', 'l calf')), ('elbow', ('l upperarm', 'l forearm'))):
        a, b = J['bip01 ' + u], J['bip01 ' + lo]
        L = float(np.linalg.norm(b - a))
        ax = (b - a) / L
        ts = [float((p - a) @ ax) / L for p, wd in V if wd and max(wd, key=wd.get) in ('bip01 ' + u, 'bip01 ' + lo)]
        near = sum(1 for t in ts if 0.85 <= t <= 1.15) / 3.0
        mid = sum(1 for t in ts if 0.35 <= t <= 0.65) / 3.0
        out[lab] = dict(joint=round(near, 1), mid=round(mid, 1), ratio=round(near / max(mid, 0.1), 1))
    return out


def sides(m):
    J, V = m.joints(), unique_weighted(m)
    seg = {'thigh': ('thigh', 'calf'), 'calf': ('calf', 'foot'), 'upperarm': ('upperarm', 'forearm'),
           'forearm': ('forearm', 'hand')}
    out = {}
    for name, (a_, b_) in seg.items():
        a, b = J['bip01 l ' + a_], J['bip01 l ' + b_]
        L = float(np.linalg.norm(b - a))
        ax = (b - a) / L
        ts = sorted(float((p - a) @ ax) / L for p, wd in V if wd and max(wd, key=wd.get) == 'bip01 l ' + a_
                    and 0.25 <= float((p - a) @ ax) / L <= 0.75)
        cl, cur = [], []
        for t in ts:
            if cur and t - cur[-1] > 0.015:
                cl.append(len(cur))
                cur = []
            cur.append(t)
        if cur:
            cl.append(len(cur))
        out[name] = cl
    return out


def axes(m):
    """per mesh: principal axis of the unique positions each limb or torso bone dominates, degrees from vertical (y):
    thighs and calves near vertical mean the mesh is modelled standing (a seated body would show thighs near 90)."""
    out = {}
    for me in m.meshes:
        if not me.skinned:
            continue
        res = out[me.name] = {}
        seen = {}
        for p, w in zip(me.pos, me.vertex_weights()):
            seen.setdefault(tuple(np.round(p, 4)), (p, max(w, key=w.get) if w else None))
        by = {}
        for p, d in seen.values():
            if d and any(k in d.lower() for k in ('thigh', 'calf', 'upperarm', 'forearm', 'spine', 'pelvis')):
                by.setdefault(d, []).append(p)
        for bone, pts in sorted(by.items()):
            if len(pts) < 3:
                continue
            P = np.array(pts)
            _, _, vt = np.linalg.svd(P - P.mean(0))
            res[bone] = dict(n=len(pts), deg_from_vertical=round(math.degrees(math.acos(min(1.0, abs(float(vt[0][1]))))), 1))
    return out


WHAT = ('bind', 'segments', 'rings', 'blends', 'density', 'sides', 'axes')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    U.add_input_args(ap)
    ap.add_argument('--what', default='all', help='comma list of %s, or all' % ','.join(WHAT))
    a = ap.parse_args(argv)
    what = WHAT if a.what == 'all' else tuple(a.what.split(','))
    res = {}
    for p, m, why in U.models(U.resolve_inputs(a)):
        if m is None:
            print('%s: UNREADABLE %s' % (Path(p).stem, why))
            continue
        r = res[m.name] = {}
        print('== %s (skeleton %s, %d bones)' % (m.name, m.skeletons[0]['name'] if m.skeletons else '-', len(m.skeleton)))
        for w in what:
            try:
                r[w] = {'bind': bind, 'segments': segments, 'rings': joint_rings, 'blends': blends,
                        'density': density, 'sides': sides, 'axes': axes}[w](m)
            except KeyError as e:
                print('   %s: missing joint %s' % (w, e))
                continue
            if w == 'rings':
                for k, v in r[w].items():
                    print('   rings %-7s seg %.3f blended rows %d %s  rings(t/L, n, blended, w_lower)=%s' % (
                        k, v['segment'], v['blended_rows'], v['row_weights'], v['rings']))
            else:
                print('   %s %s' % (w, r[w]))
    return res


if __name__ == '__main__':
    main()
