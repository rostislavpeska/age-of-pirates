"""Does a skinned mesh sit on its skeleton? The scale and placement gate of NEW skinned unit geometry (INC-251).

    python scripts/havok/skeleton_fit.py MODEL.gr2 [...]          # the fit of every bound skinned mesh; exit 1 = FAIL

In the rest pose a skinned vertex lies around the bone that weights it most (BoneWeights slot 0): between that bone's
joint and its children's joints. A model exported at the wrong scale (0.3937x: a GXO written for the pose tests, or in
inches), offset, or in another frame keeps every byte check green (weights, layout, the donor skeleton byte for byte)
and shows only in the game. Measured here, per model:

- dist: per vertex, the distance (model units) from the vertex to the nearest point of its dominant bone's segments
  (joint -> each child joint; a leaf bone: its joint); p50 / p95 / max over the vertices of every skinned mesh;
- height_ratio: the vertical (y) extent of the vertices over the vertical extent of the joints of the bones they weight.

LIMITS: measured 2026-10-11 on the 20 referenced DE full-LOD riders (aoe3de-unit-model vanilla-unit-measurements.md;
scratch extraction, read-only): every rider passes; the 0.3937x specimen fails all three. The numbers are in model units
because unit skeletons are vanilla skeletons (gr2_lint unit_skeleton: one reference skeleton byte for byte), so the
scale is fixed. Used by skinned_gr2.py (before it writes) and gr2_lint (check unit_fit).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

# measured on the 20 referenced DE full-LOD riders 2026-10-11 (evidence C:/work/unit-process/export/repair/fit_vanilla.json,
# made by its scripts/measure_fit.py): dist p50 0.1068-0.1563, dist p95 0.1957-0.3714 (naginata_rider_2), dist max up to
# 1.5855 (naginata_rider_2's plume), height ratio 1.1923-1.9035 (naginata_rider_2's tall hat). A 0.3937x model (the
# verifier's wrong-scale W2): p50 0.2664, p95 0.7861, ratio 0.4717.
LIMITS = dict(dist_p50_max=0.20, dist_p95_max=0.45, height_ratio_min=1.0, height_ratio_max=2.2)
LIMITS_DOC = ('measured on the 20 referenced DE full-LOD riders (2026-10-11): dist p50 <= 0.1563, dist p95 <= 0.3714, '
              'height ratio 1.19-1.90; limits about 1.25x the worst rider, ratio >= 1.0 because a body reaches past its '
              'foot and head joints. A coarse gate: it catches unit-system errors (0.3937, 2.54, 100x) and gross offsets, '
              'not a 10 % scale error - the joint check of skinned_gr2 (JOINT_TOL) is the fine gate.')


def joints(world):
    """(n, 4, 4) row-vector world rest matrices -> (n, 3) joint positions (translation row)."""
    W = np.asarray(world, float).reshape(-1, 4, 4)
    return W[:, 3, :3].copy()


def segments(parents, J):
    """per bone: [(a, b)] its segments - joint to each child joint; a leaf bone: (joint, joint)."""
    kids = {i: [] for i in range(len(parents))}
    for i, p in enumerate(parents):
        if p is not None and int(p) >= 0:
            kids[int(p)].append(i)
    return {i: [(J[i], J[c]) for c in kids[i]] or [(J[i], J[i])] for i in range(len(parents))}


def point_segment_distance(P, a, b):
    P = np.asarray(P, float)
    ab = np.asarray(b, float) - np.asarray(a, float)
    L2 = float(ab @ ab)
    t = np.zeros(len(P)) if L2 < 1e-18 else np.clip(((P - a) @ ab) / L2, 0.0, 1.0)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def fit(meshes, names, parents, J):
    """meshes: [dict(name, pos (n,3), w (n,4) slot weights descending, bi (n,4) palette indices, palette [bone names])],
    the skeleton as names, parents, joints (n,3). -> the fit record (dist quantiles, height ratio, per mesh)."""
    index = {n: i for i, n in enumerate(names)}
    seg = segments(parents, np.asarray(J, float))
    all_d, all_p, weighted, rows = [], [], set(), []
    for m in meshes:
        P = np.asarray(m['pos'], float).reshape(-1, 3)
        w, bi = np.asarray(m['w']), np.asarray(m['bi']).astype(int)
        dom = bi[np.arange(len(bi)), np.argmax(w, axis=1)]
        missing = sorted({m['palette'][k] for k in set(dom.tolist()) if k < len(m['palette'])
                          and m['palette'][k] not in index} | ({'<index past palette>'} if (dom >= len(m['palette'])).any()
                                                               else set()))
        if missing:
            rows.append(dict(mesh=m['name'], vertices=len(P), missing_bones=missing))
            continue
        d = np.full(len(P), np.inf)
        for k in np.unique(dom):
            b = index[m['palette'][int(k)]]
            sel = dom == k
            for a, c in seg[b]:
                d[sel] = np.minimum(d[sel], point_segment_distance(P[sel], a, c))
        used = np.unique(bi[np.asarray(w) > 0])
        weighted |= {index[m['palette'][int(k)]] for k in used if int(k) < len(m['palette'])}
        all_d.append(d)
        all_p.append(P)
        rows.append(dict(mesh=m['name'], vertices=len(P), dist_p50=round(float(np.percentile(d, 50)), 4),
                         dist_p95=round(float(np.percentile(d, 95)), 4), dist_max=round(float(d.max()), 4)))
    out = dict(meshes=rows)
    if not all_d:
        out['error'] = 'no skinned vertex on a skeleton bone'
        return out
    d, P = np.concatenate(all_d), np.vstack(all_p)
    Jw = np.asarray(J, float)[sorted(weighted)]
    jh = float(Jw[:, 1].max() - Jw[:, 1].min()) if len(Jw) else 0.0
    mh = float(P[:, 1].max() - P[:, 1].min())
    out.update(vertices=int(len(d)), dist_p50=round(float(np.percentile(d, 50)), 4),
               dist_p95=round(float(np.percentile(d, 95)), 4), dist_max=round(float(d.max()), 4),
               mesh_height=round(mh, 4), joint_height=round(jh, 4),
               height_ratio=round(mh / jh, 4) if jh > 1e-9 else None, weighted_bones=len(weighted))
    return out


def judge(rep, limits=None):
    """-> list of failures (empty = the mesh sits on its skeleton)."""
    lim = dict(LIMITS, **(limits or {}))
    bad = []
    if rep.get('error'):
        return [rep['error']]
    for r in rep['meshes']:
        if r.get('missing_bones'):
            bad.append('mesh %s: dominant bones not in the skeleton %s' % (r['mesh'], r['missing_bones']))
    if rep.get('dist_p50') is not None and rep['dist_p50'] > lim['dist_p50_max']:
        bad.append('vertices sit %.4f units (p50) from their dominant bone, max %.4f' % (rep['dist_p50'],
                                                                                         lim['dist_p50_max']))
    if rep.get('dist_p95') is not None and rep['dist_p95'] > lim['dist_p95_max']:
        bad.append('vertices sit %.4f units (p95) from their dominant bone, max %.4f' % (rep['dist_p95'],
                                                                                         lim['dist_p95_max']))
    hr = rep.get('height_ratio')
    if hr is None:
        bad.append('the weighted joints have no height: the ratio cannot be measured')
    elif not lim['height_ratio_min'] <= hr <= lim['height_ratio_max']:
        bad.append('mesh height %.4f / weighted-joint height %.4f = %.3f, outside %.2f-%.2f (wrong scale?)' % (
            rep['mesh_height'], rep['joint_height'], hr, lim['height_ratio_min'], lim['height_ratio_max']))
    return bad


def from_info(info):
    """gr2_lint read_raw / load info -> (meshes, names, parents, joints) of the bound skinned meshes."""
    names = [b['name'] for b in info['bones']]
    parents = [int(b['parent']) for b in info['bones']]
    J = joints([b['world'] for b in info['bones']])
    meshes = []
    for m in info['render']:
        c = m.get('comps') or {}
        if 'BoneWeights' not in c or 'BoneIndices' not in c:
            continue
        meshes.append(dict(name=m['name'], pos=m['pos'], w=np.rint(c['BoneWeights'] * 255).astype(int),
                           bi=c['BoneIndices'].astype(int), palette=list(m['bone_names'])))
    return meshes, names, parents, J


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    here = Path(__file__).resolve().parent
    if str(here) not in sys.path:
        sys.path.insert(0, str(here))
    from gr2_lint import read_raw
    worst = 0
    for p in argv:
        rep = fit(*from_info(read_raw(p)))
        bad = judge(rep)
        print(json.dumps(dict(file=p, fit=rep, fails=bad), indent=1))
        worst = max(worst, 1 if bad else 0)
    return worst


if __name__ == '__main__':
    sys.exit(main())
