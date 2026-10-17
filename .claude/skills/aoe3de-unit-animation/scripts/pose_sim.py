#!/usr/bin/env python
"""Engine-style pose of a skinned unit from converter GXO text, without the game: animation tracks bind to the model's
bones BY NAME and their keys are LOCAL to the model's own parent; bones without a track keep their rest local; meshes
deform by linear blend skinning. Optionally seats the posed model on a posed mount (rider origin = the mount's seat
bone, as a horse animfile attaches its rider) and simulates a skeleton swap (gr2_reskeleton.py) before building it.

    python pose_sim.py --model RIDER.gxo --anim RIDE.gxo --out posed.obj
           [--frame 0] [--det-tol 0.001] [--orthonormalize]
           [--mount HORSE.gxo --mount-anim HORSE_IDLE.gxo [--seat attachpoint]]
           [--skeleton-from DONOR.gxo]

Models: GXO from the GR2 converter (`--format gxo`) or written from Blender by `scripts/havok/rig_table.py --skinned`.
Clips: a converter GXO dump is a pose at key 0 ONLY - from key 1 on its keys leave the curves (oprichnik_attack_a:
a bone whose curve is constant turns and shrinks, det 0.97 by key 17, 0.0003 by key 159; horse_idle_a reaches det 4e8),
and neither a polar factor nor rest offsets recover them (verified 2026-10-11). For any key after 0, decode the clip
straight from its gr2 with aoe3de-unit-model's `clip_decode.py` (same GXO text, every key a pose). Every key is
checked: a bone-driving track whose 3x3 has |det - 1| > --det-tol (default 0.001) is refused, naming the track (raise
the tolerance only for a decoded clip that keys scale on purpose). `--orthonormalize` replaces each key's 3x3 by its
nearest rotation after that check: float polish, not a repair. Writes OBJ files (z up, with UVs: `<out>` and
`<out stem>_mount.obj`) for a background Blender render, and prints the posed height range and how many bones the
animation drives. Validated on the vanilla yabusame rider + horse (cavalry idle, key 0): seated, z 0.406..1.179 with
the converter's clips and with decoded ones.
"""
import argparse
import os
import re

import numpy as np


def m4(vals):
    """GXO 3x3 (row-major) + translation -> 4x4 for row vectors: p' = p @ M."""
    M = np.eye(4)
    M[:3, :3] = np.array(vals[:9], float).reshape(3, 3)
    M[3, :3] = vals[9:12]
    return M


def parse_model(path):
    """bones [{name, parent (0-based, -1 root), W0 absolute}] and meshes [{name, mb, v, vt, vw, f}]."""
    bones, meshes, cur = [], [], None
    for line in open(path, encoding='utf-8', errors='replace'):
        tok = line.split()
        if not tok:
            continue
        if tok[0] == 'b':
            rest = line.split('"')[2].split()
            bones.append({'name': line.split('"')[1], 'parent': int(rest[0]) - 1, 'W0': m4([float(x) for x in rest[1:13]])})
        elif tok[0] == 'm':
            cur = {'name': line.split('"')[1], 'mb': [], 'v': [], 'vt': [], 'vw': [], 'f': []}
            meshes.append(cur)
        elif cur is None:
            continue
        elif tok[0] == 'mb':
            cur['mb'].append(line.split('"')[1])
        elif tok[0] == 'v':
            cur['v'].append([float(x) for x in tok[1:4]])
        elif tok[0] == 'vt':
            cur['vt'].append([float(x) for x in tok[1:3]])
        elif tok[0] == 'vw':
            cur['vw'].append([float(x) for x in tok[1:9]])
        elif tok[0] == 'f':
            cur['f'].append([int(x) for x in tok[1:4]])
    return bones, meshes


def norm(name):
    """bone name as the engine matches it: a space and an underscore are the same character (vanilla 2026-10-09: the
    Ashigaru, Inca spearman, Somali warrior and ~20 more Bip01_* models play pikemen_charge_*, whose tracks are
    'Bip01 Head' ...)."""
    return name.replace(' ', '_')


def parse_anim(path, frame=0):
    """track name -> local 4x4 at key `frame`."""
    keys, cur, n = {}, None, 0
    for line in open(path, encoding='utf-8', errors='replace'):
        if line.startswith('c "'):
            cur, n = line.split('"')[1], 0
        elif line.startswith('k ') and cur is not None:
            if n == frame:
                keys[norm(cur)] = m4([float(x) for x in line.split()[1:13]])
            n += 1
    return keys


def bad_tracks(keys, bones, tol=1e-3):
    """[(track, det)] for the tracks that drive a bone of `bones` and whose 3x3 has |det - 1| > tol: a converter dump
    after key 0 (or keyed scale). Tracks without a bone are ignored, as the engine ignores them."""
    names = {norm(b['name']) for b in bones}
    out = []
    for name, K in sorted(keys.items()):
        if name in names:
            d = float(np.linalg.det(K[:3, :3]))
            if not abs(d - 1.0) <= tol:
                out.append((name, d))
    return out


def check_keys(keys, bones, tol, what):
    bad = bad_tracks(keys, bones, tol)
    if bad:
        raise SystemExit('%s: %d bone-driving track(s) with |det - 1| > %g: %s. A converter GXO dump of a clip is a pose '
                         'at key 0 only; decode the clip with aoe3de-unit-model clip_decode.py (raise --det-tol only for '
                         'a decoded clip that keys scale)' % (what, len(bad), tol,
                                                             ', '.join('%s %.4g' % x for x in bad[:6])))


def orthonormalize(keys):
    """keys with each 3x3 replaced by its polar factor (the nearest rotation: U @ Vt of the SVD, sign-fixed to det +1),
    translations kept. Polishes float noise of a key that is already a rotation; it cannot recover a converter key
    after 0 (verified 2026-10-11: orthonormalized, the converter's oprichnik_idle1 drops iron_rider_0's head to 75 GXO
    units below its pelvis, the decoded clip keeps it 0.266 above)."""
    out = {}
    for name, K in keys.items():
        U, _, Vt = np.linalg.svd(K[:3, :3])
        if np.linalg.det(U @ Vt) < 0:
            U[:, -1] *= -1
        K2 = K.copy()
        K2[:3, :3] = U @ Vt
        out[name] = K2
    return out


def pose(bones, keys):
    """posed world matrices: local (track if named, else rest local) @ parent world (parents listed first)."""
    Wp = [None] * len(bones)
    for i, b in enumerate(bones):
        p = b['parent']
        L0 = b['W0'] @ np.linalg.inv(bones[p]['W0']) if p >= 0 else b['W0']
        Wp[i] = keys.get(norm(b['name']), L0) @ (Wp[p] if p >= 0 else np.eye(4))
    return Wp


def skin(bones, Wp, mesh):
    idx = {b['name']: i for i, b in enumerate(bones)}
    S = {}
    out = []
    for v, w in zip(mesh['v'], mesh['vw']):
        acc = np.zeros(4)
        vh = np.array(v + [1.0])
        for k in range(4):
            if w[k] > 0:
                bi = idx[mesh['mb'][int(w[4 + k]) - 1]]
                if bi not in S:
                    S[bi] = np.linalg.inv(bones[bi]['W0']) @ Wp[bi]
                acc += w[k] * (vh @ S[bi])
        out.append(acc[:3])
    return np.array(out)


def swap_skeleton(donor, target_bones):
    """donor hierarchy and names at the target's joints (what gr2_reskeleton.py builds); 'Bip01_Root' takes the
    target's root when the target calls it otherwise; donor-only bones keep the donor's offset to their parent."""
    tw = {b['name']: b['W0'] for b in target_bones}
    root = next(b['name'] for b in target_bones if b['parent'] < 0)
    out = []
    for i, b in enumerate(donor):
        nb = dict(b)
        name = b['name'] if b['name'] in tw else (root if b['parent'] < 0 else None)
        if name:
            nb['W0'] = tw[name]
        elif b['parent'] >= 0:
            nb['W0'] = (b['W0'] @ np.linalg.inv(donor[b['parent']]['W0'])) @ out[b['parent']]['W0']
        out.append(nb)
    return out


def write_obj(path, parts):
    with open(path, 'w') as fh:
        base = 1
        for name, P, mesh in parts:
            fh.write('o %s\n' % name)
            for p in P:
                fh.write('v %.6f %.6f %.6f\n' % tuple(p))
            for t in mesh['vt']:
                fh.write('vt %.6f %.6f\n' % (t[0], t[1]))
            for f in mesh['f']:
                a, b, c = (x - 1 + base for x in f)
                fh.write('f %d/%d %d/%d %d/%d\n' % (a, a, b, b, c, c))
            base += len(P)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--model', required=True)
    ap.add_argument('--anim', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--frame', type=int, default=0)
    ap.add_argument('--det-tol', type=float, default=1e-3,
                    help='refuse a key whose bone-driving track has |det - 1| above this (default 0.001)')
    ap.add_argument('--orthonormalize', action='store_true',
                    help='after the check, replace each key 3x3 by its nearest rotation (float polish only)')
    ap.add_argument('--mount')
    ap.add_argument('--mount-anim')
    ap.add_argument('--seat', default='attachpoint', help='seat bone name ending (case/underscore-insensitive)')
    ap.add_argument('--skeleton-from', help='simulate gr2_reskeleton.py with this donor skeleton')
    a = ap.parse_args()
    bones, meshes = parse_model(a.model)
    if a.skeleton_from:
        bones = swap_skeleton(parse_model(a.skeleton_from)[0], bones)
    names = {b['name'] for b in bones}
    missing = sorted({n for m in meshes for n in m['mb']} - names)
    if missing:
        raise SystemExit('weighted bones missing from the skeleton: %s' % missing)
    keys = parse_anim(a.anim, a.frame)
    if not keys:
        raise SystemExit('%s has no key %d' % (a.anim, a.frame))
    check_keys(keys, bones, a.det_tol, 'key %d of %s' % (a.frame, os.path.basename(a.anim)))
    if a.orthonormalize:
        keys = orthonormalize(keys)
    Wp = pose(bones, keys)
    seat = np.eye(4)
    if a.mount:
        mb, mm = parse_model(a.mount)
        mkeys = parse_anim(a.mount_anim, a.frame) if a.mount_anim else {}
        if a.mount_anim:
            check_keys(mkeys, mb, a.det_tol, 'key %d of %s' % (a.frame, os.path.basename(a.mount_anim)))
        if a.orthonormalize:
            mkeys = orthonormalize(mkeys)
        Mp = pose(mb, mkeys)
        si = next(i for i, b in enumerate(mb) if b['name'].lower().replace('_', '').endswith(a.seat.lower().replace('_', '')))
        seat = Mp[si]
        write_obj(os.path.splitext(a.out)[0] + '_mount.obj', [(m['name'], skin(mb, Mp, m), m) for m in mm if m['vw']])
    parts = []
    for m in meshes:
        P = skin(bones, Wp, m)
        parts.append((m['name'], (np.c_[P, np.ones(len(P))] @ seat)[:, :3], m))
    write_obj(a.out, parts)
    allp = np.vstack([p for _, p, _ in parts])
    print('posed %s: z %.3f..%.3f, bones %d, driven by the animation %d, tracks without a bone %s' % (
        os.path.basename(a.out), allp[:, 2].min(), allp[:, 2].max(), len(bones), len({norm(n) for n in names} & set(keys)),
        sorted(set(keys) - {norm(n) for n in names})))


if __name__ == '__main__':
    main()
