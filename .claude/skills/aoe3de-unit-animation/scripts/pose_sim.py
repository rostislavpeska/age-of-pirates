#!/usr/bin/env python
"""Engine-style pose of a skinned unit from converter GXO text, without the game: animation tracks bind to the model's
bones BY NAME and their keys are LOCAL to the model's own parent; bones without a track keep their rest local; meshes
deform by linear blend skinning. Optionally seats the posed model on a posed mount (rider origin = the mount's seat
bone, as a horse animfile attaches its rider) and simulates a skeleton swap (gr2_reskeleton.py) before building it.

    python pose_sim.py --model RIDER.gxo --anim RIDE.gxo --out posed.obj
           [--frame 0] [--mount HORSE.gxo --mount-anim HORSE_IDLE.gxo [--seat attachpoint]]
           [--skeleton-from DONOR.gxo]

GXO from the GR2 converter (`--format gxo`, works for animation-only files where FBX refuses). Only key 0 of a
converter animation dump is a clean pose (later keys drift; measured 2026-10-09), so judge frame 0. Writes OBJ files
(z up, with UVs: `<out>` and `<out stem>_mount.obj`) for a background Blender render, and prints the posed height range
and how many bones the animation drives. Validated on the vanilla yabusame rider + horse: seated correctly.
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


def parse_anim(path, frame=0):
    """track name -> local 4x4 at key `frame`."""
    keys, cur, n = {}, None, 0
    for line in open(path, encoding='utf-8', errors='replace'):
        if line.startswith('c "'):
            cur, n = line.split('"')[1], 0
        elif line.startswith('k ') and cur is not None:
            if n == frame:
                keys[cur] = m4([float(x) for x in line.split()[1:13]])
            n += 1
    return keys


def pose(bones, keys):
    """posed world matrices: local (track if named, else rest local) @ parent world (parents listed first)."""
    Wp = [None] * len(bones)
    for i, b in enumerate(bones):
        p = b['parent']
        L0 = b['W0'] @ np.linalg.inv(bones[p]['W0']) if p >= 0 else b['W0']
        Wp[i] = keys.get(b['name'], L0) @ (Wp[p] if p >= 0 else np.eye(4))
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
    Wp = pose(bones, keys)
    seat = np.eye(4)
    if a.mount:
        mb, mm = parse_model(a.mount)
        Mp = pose(mb, parse_anim(a.mount_anim, a.frame) if a.mount_anim else {})
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
        os.path.basename(a.out), allp[:, 2].min(), allp[:, 2].max(), len(bones), len(names & set(keys)),
        sorted(set(keys) - names)))


if __name__ == '__main__':
    main()
