#!/usr/bin/env python
"""Vertex format, fill, weight storage and split causes of unit gr2 meshes (read-only).

    python vertex_fill.py --archive Art/units/asians/chinese/iron_flail/iron_rider_0.gr2 [...]
    python vertex_fill.py FILE.gr2 [...] [--json OUT.json]

Per mesh: the vertex layout (member, type, count, offset) and stride; DiffuseColor0 values; Normal.w and Tangent.w
histograms; weight sums over the uint8 slots, descending order, a bone twice in one vertex, the index carried by
zero-weight slots (slot 0's index, the previous slot's, 0, other); the smallest nonzero weight and how many weights
fall under 5, 13 and 26 /255; why GPU vertices outnumber positions: extra splits per attribute (unique (position,
attribute) pairs minus unique positions) and, per split position, whether the normal (> 5 deg), the UV or both differ.
These back the "Influences and weights", "Shipped buffers are inflated" and "Vertex format" sections of
vanilla-unit-measurements.md.
"""
import argparse
import collections
import json
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import unit_gr2 as U  # noqa: E402


def hist(arr):
    return {int(k): int(v) for k, v in zip(*np.unique(arr, return_counts=True))}


def weight_storage(me):
    W = me.comps['BoneWeights'].astype(np.int64)
    B = me.comps['BoneIndices'].astype(np.int64)
    sums = hist(W.sum(1))
    desc = int(np.all(W[:, :-1] >= W[:, 1:], axis=1).sum())
    dup = 0
    for w, b in zip(W, B):
        used = [int(i) for x, i in zip(w, b) if x]
        dup += len(used) != len(set(used))
    zs = collections.Counter()
    for w, b in zip(W, B):
        for k in range(W.shape[1]):
            if w[k] == 0:
                zs['slot0' if b[k] == b[0] else ('previous' if b[k] == b[k - 1] else ('zero' if b[k] == 0 else 'other'))] += 1
    nz = W[W > 0]
    return dict(slots=int(W.shape[1]), sums=sums, descending=desc, dup_bone=dup, zero_slot_index=dict(zs),
                zero_slot_share=round(zs['slot0'] / max(sum(zs.values()), 1), 4),
                min_weight=int(nz.min()) if nz.size else None, under5=int((nz < 5).sum()),
                under13=int((nz < 13).sum()), under26=int((nz < 26).sum()), nonzero=int(nz.size))


def angle(a, b):
    la, lb = np.linalg.norm(a) or 1.0, np.linalg.norm(b) or 1.0
    return math.degrees(math.acos(max(-1.0, min(1.0, float(np.dot(a, b) / la / lb)))))


def split_causes(me):
    pos = np.round(me.pos, 5)
    _, inv = np.unique(pos, axis=0, return_inverse=True)
    inv = inv.ravel()
    n_pos = int(inv.max()) + 1 if me.n else 0
    extra = {}
    for k, v in me.comps.items():
        if k == 'Position':
            continue
        extra[k] = int(len(np.unique(np.hstack([pos, v.astype(np.float64)]), axis=0))) - n_pos
    groups = collections.defaultdict(list)
    N = me.comps.get('Normal')
    UV = me.comps.get('TextureCoordinates0')
    for i in range(me.n):
        groups[int(inv[i])].append(i)
    kinds = collections.Counter()
    for _, idx in groups.items():
        if len(idx) < 2:
            continue
        nd = N is not None and max(angle(N[idx[0], :3].astype(float), N[j, :3].astype(float)) for j in idx[1:]) > 5
        ud = UV is not None and any(np.abs(UV[idx[0]].astype(float) - UV[j].astype(float)).max() > 1e-4 for j in idx[1:])
        kinds[('normal' if nd else '') + ('+' if nd and ud else '') + ('uv' if ud else '') or 'other attributes'] += 1
    return dict(gpu=me.n, unique_positions=n_pos, welded=me.welded_count(), tris=len(me.tris),
                gpu_per_tri=round(me.n / max(len(me.tris), 1), 3),
                welded_per_tri=round(me.welded_count() / max(len(me.tris), 1), 3),
                welded_per_position=round(me.welded_count() / max(n_pos, 1), 3),
                extra_splits_by_attribute=extra, split_positions=dict(kinds))


def fill(me):
    out = {}
    if 'DiffuseColor0' in me.comps:
        c = collections.Counter(tuple(int(x) for x in row) for row in me.comps['DiffuseColor0'])
        out['colour_top'] = [[list(k), v] for k, v in c.most_common(3)]
    for k in ('Normal', 'Tangent'):
        if k in me.comps and me.comps[k].shape[1] >= 4:
            out[k.lower() + '_w'] = hist(me.comps[k][:, 3])
    return out


def measure(m):
    rows = []
    for me in m.meshes:
        r = dict(file=m.name, mesh=me.name, stride=me.stride, layout=me.layout, **fill(me))
        if me.skinned:
            r['weights'] = weight_storage(me)
        r['splits'] = split_causes(me)
        rows.append(r)
    return rows


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    U.add_input_args(ap)
    ap.add_argument('--json', help='write the records here (default: a temp folder)')
    a = ap.parse_args(argv)
    allrows = []
    for p, m, why in U.models(U.resolve_inputs(a)):
        if m is None:
            print('%s: UNREADABLE %s' % (Path(p).stem, why))
            continue
        for r in measure(m):
            allrows.append(r)
            print('%s / %s: stride %d layout %s' % (r['file'], r['mesh'], r['stride'],
                                                    ' '.join('%s:%s%s@%d' % (n, t, 'x%d' % c if c > 1 else '', o)
                                                             for n, t, c, o in r['layout'])))
            if 'colour_top' in r:
                print('   colour %s  normal.w %s  tangent.w %s' % (r['colour_top'], r.get('normal_w'), r.get('tangent_w')))
            if 'weights' in r:
                w = r['weights']
                print('   weights: sums %s, descending %d, bone twice %d, zero slots %s (slot0 share %.4f), min %s/255, '
                      'under 5/13/26: %d/%d/%d of %d' % (w['sums'], w['descending'], w['dup_bone'], w['zero_slot_index'],
                                                         w['zero_slot_share'], w['min_weight'], w['under5'],
                                                         w['under13'], w['under26'], w['nonzero']))
            s = r['splits']
            print('   splits: gpu %d welded %d positions %d tris %d (gpu/tri %.2f, welded/tri %.2f, welded/position %.2f); '
                  'extra by attribute %s; split positions %s' % (
                      s['gpu'], s['welded'], s['unique_positions'], s['tris'], s['gpu_per_tri'], s['welded_per_tri'],
                      s['welded_per_position'], s['extra_splits_by_attribute'], s['split_positions']))
    out = Path(a.json) if a.json else U.temp_dir('reports') / 'vertex_fill.json'
    out.write_text(json.dumps(allrows, indent=1, default=str))
    print('JSON', out)
    return allrows


if __name__ == '__main__':
    main()
