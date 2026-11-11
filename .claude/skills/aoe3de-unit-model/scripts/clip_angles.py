#!/usr/bin/env python
"""Joint angles a rider clip drives, per key (read-only), through aoe3de-unit-animation's pose_sim.py.

    python clip_angles.py MODEL.gr2|MODEL.gxo CLIP.gxo [CLIP.gxo ...] [--det-tol 0.001] [--step 12]

MODEL is a rider gr2 (its skeleton read with unit_gr2, in the GXO frame and units of a converter dump), a converter
GXO of one, or a rig_table.py --skinned dump of a Blender scene in the same units;
CLIP.gxo a clip decoded by clip_decode.py (a converter dump holds a pose at key 0 only: its later keys are refused by
pose_sim's determinant check, --det-tol). Reports the bind angles, then per clip key 0 and the minimum / maximum (with
its key) over every key of: hip flexion (thigh vs the neck -> pelvis axis), knee, thigh spread, upper arm from down
(180 = straight up), elbow, spine bend (pelvis -> spine vs spine1 -> neck) and "spine twist" (pelvis lateral vs
shoulder lateral about the torso axis; it mixes clavicle and arm motion, not a torso twist). Decoded oprichnik_attack_a
on iron_rider_0: hip 105, knee 87 / 85, spine bend 58, upper arm 115 right / 81 left, elbow 111
(rider-skeleton.md, section 6). --step N prints every Nth key.
"""
import argparse
import math
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / 'aoe3de-unit-animation' / 'scripts'))
import pose_sim  # noqa: E402

ORDER = ('hipflex_l', 'hipflex_r', 'knee_l', 'knee_r', 'thigh_spread', 'arm_from_down_l', 'arm_from_down_r',
         'elbow_l', 'elbow_r', 'spine_bend', 'spine_twist')


def ang(a, b):
    a = a / (np.linalg.norm(a) or 1)
    b = b / (np.linalg.norm(b) or 1)
    return math.degrees(math.acos(max(-1.0, min(1.0, float(a @ b)))))


def nkeys(path):
    best, cur = 0, 0
    for line in open(path, encoding='utf-8', errors='replace'):
        if line.startswith('c "'):
            best, cur = max(best, cur), 0
        elif line.startswith('k '):
            cur += 1
    return max(best, cur)


def angles(bones, Wp):
    idx = {pose_sim.norm(b['name']).lower(): i for i, b in enumerate(bones)}

    def J(n):
        return Wp[idx['bip01_' + n]][3, :3]
    down = J('pelvis') - J('neck')
    axis = -down / np.linalg.norm(down)
    r = {}
    for s in 'lr':
        th, sh = J(s + '_calf') - J(s + '_thigh'), J(s + '_foot') - J(s + '_calf')
        ua, fa = J(s + '_forearm') - J(s + '_upperarm'), J(s + '_hand') - J(s + '_forearm')
        r['hipflex_' + s] = ang(th, down)
        r['knee_' + s] = ang(th, sh)
        r['arm_from_down_' + s] = ang(ua, down)
        r['elbow_' + s] = ang(ua, fa)
    r['thigh_spread'] = ang(J('l_calf') - J('l_thigh'), J('r_calf') - J('r_thigh'))

    def proj(v):
        return v - (v @ axis) * axis
    r['spine_twist'] = ang(proj(J('l_thigh') - J('r_thigh')), proj(J('l_upperarm') - J('r_upperarm')))
    r['spine_bend'] = ang(J('spine') - J('pelvis'), J('neck') - J('spine1'))
    return r


def load_bones(path):
    """pose_sim bones [{name, parent, W0}] from a model GXO, or from a gr2 skeleton mapped to the GXO frame and units
    (unit_gr2.to_gxo_matrix: the converter's own mapping, 1.6e-7 on iron_rider_0)."""
    if str(path).lower().endswith('.gr2'):
        sys.path.insert(0, str(HERE))
        import unit_gr2 as U
        return [dict(name=b['name'], parent=b['parent'], W0=U.to_gxo_matrix(b['world']))
                for b in U.Model(path).skeleton]
    return pose_sim.parse_model(path)[0]


def clip_rows(bones, anim, det_tol=1e-3):
    """angles per key; SystemExit on a key whose bone-driving track is not a rotation (pose_sim.check_keys)."""
    rows = []
    for f in range(nkeys(anim)):
        keys = pose_sim.parse_anim(anim, f)
        pose_sim.check_keys(keys, bones, det_tol, 'key %d of %s' % (f, Path(anim).name))
        rows.append(angles(bones, pose_sim.pose(bones, keys)))
    return rows


def ranges(rows):
    return {k: (round(min(r[k] for r in rows)), round(max(r[k] for r in rows))) for k in ORDER if k in rows[0]}


def extremes(rows):
    """{angle: (max, key of the max)}"""
    out = {}
    for k in ORDER:
        vals = [r[k] for r in rows]
        i = int(np.argmax(vals))
        out[k] = (round(vals[i], 1), i)
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('model')
    ap.add_argument('anims', nargs='+')
    ap.add_argument('--det-tol', type=float, default=1e-3, help='pose_sim determinant check per key')
    ap.add_argument('--step', type=int, default=0, help='print every Nth key')
    a = ap.parse_args(argv)
    bones = load_bones(a.model)
    print('BIND', {k: round(v, 1) for k, v in angles(bones, [b['W0'] for b in bones]).items()})
    out = {}
    for anim in a.anims:
        rows = clip_rows(bones, anim, a.det_tol)
        name = Path(anim).name
        print('== %s keys=%d' % (name, len(rows)))
        ext = extremes(rows)
        for k in ORDER:
            vals = [r[k] for r in rows]
            print('   %-16s f0=%6.1f  min=%6.1f  max=%6.1f at key %d' % (k, vals[0], min(vals), max(vals), ext[k][1]))
        if a.step:
            for f in range(0, len(rows), a.step):
                print('   key %3d ' % f + ' '.join('%s=%.0f' % (k, rows[f][k]) for k in ORDER))
        out[name] = dict(f0={k: round(rows[0][k], 1) for k in ORDER}, range=ranges(rows), max=ext)
        print('RANGE', out[name]['range'])
    return out


if __name__ == '__main__':
    main()
