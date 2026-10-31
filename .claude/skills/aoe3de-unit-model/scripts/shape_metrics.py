#!/usr/bin/env python
"""Shape, region and UV metrics of unit gr2 meshes (read-only).

    python shape_metrics.py --archive Art/units/asians/chinese/iron_flail/iron_rider_0.gr2 [...] [--what all]
    python shape_metrics.py FILE.gr2 [...] --what shells,symmetry,regions,heads,uv,hands,seat [--tex 1024]
    python shape_metrics.py --compare A.gr2 B.gr2        # welded positions of A found in B (tiers, stock hands)

shells: connected shells (positions welded at 0.1 mm), the largest shells' triangle counts, open (boundary) edges,
  edges with more than two faces, the smallest triangle angle, and each large shell's dominant body regions.
symmetry: share of welded positions with a mirror partner within 1 mm across each axis (engine x = across).
regions: triangle share by the bone with the largest summed weight over the corners (legs include feet), and unique
  position share by dominant bone (feet separate); bones of a flail chain count as weapon.
heads: figure height (y extent) / extent of the vertices weighted >= 0.9 to the head bone (headgear in the body mesh
  counts as head).
hands: per side, vertices dominated by a hand bone: triangles, unique positions and the x/y/z extent.
uv: 3D area, UV area (overlaps counted twice), UV box, texel density sqrt(uvArea * tex^2 / area3d) in px per engine unit,
  and the share of UV area with negative winding (mirrored shells).
seat: faces a mount covers in the bind pose - pelvis- or thigh-dominated triangles facing down (seat) or, on a thigh,
  towards the mid-plane (inner thigh) - and their share of the mesh's triangles (kept or removed by the reference).
Backs "Regions", "Shape and symmetry", "Faces the mount covers", "Hands and feet" and the UV facts in
materials-textures.md.
"""
import argparse
import collections
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import unit_gr2 as U  # noqa: E402


def welded_index(P, decimals=4):
    _, inv = np.unique(np.round(P, decimals), axis=0, return_inverse=True)
    return inv.ravel()


def dominant(weights):
    return max(weights, key=weights.get) if weights else None


def tri_dominant_bones(me):
    vw = me.vertex_weights()
    out = []
    for t in me.tris:
        acc = collections.Counter()
        for c in t:
            for b, w in vw[c].items():
                acc[b] += w
        out.append(acc.most_common(1)[0][0] if acc else None)
    return out


def shells(me):
    vid = welded_index(me.pos)
    W = vid[me.tris]
    par = list(range(int(vid.max()) + 1 if len(vid) else 0))

    def find(x):
        while par[x] != x:
            par[x] = par[par[x]]
            x = par[x]
        return x
    edges = collections.Counter()
    for a, b, c in W:
        for u, v in ((a, b), (b, c), (c, a)):
            if u != v:
                edges[(min(u, v), max(u, v))] += 1
                par[find(u)] = find(v)
    tri_shell = [find(int(t[0])) for t in W]
    sizes = collections.Counter(tri_shell)
    doms = tri_dominant_bones(me)
    reg = collections.defaultdict(collections.Counter)
    for s, d in zip(tri_shell, doms):
        reg[s][U.region(d) if d else 'none'] += 1
    P = me.pos
    a, b, c = P[me.tris[:, 0]], P[me.tris[:, 1]], P[me.tris[:, 2]]

    def ang(u, v):
        nu, nv = np.linalg.norm(u, axis=1), np.linalg.norm(v, axis=1)
        return np.degrees(np.arccos(np.clip(np.einsum('ij,ij->i', u, v) / np.maximum(nu * nv, 1e-20), -1, 1)))
    A, B = ang(b - a, c - a), ang(a - b, c - b)
    mn = np.minimum(np.minimum(A, B), 180 - A - B)
    top = sizes.most_common(8)
    return dict(tris=len(me.tris), welded_positions=len(par), shells=len(sizes), largest=[n for _, n in top],
                small_shells=sum(1 for n in sizes.values() if n <= 12),
                boundary_edges=sum(1 for n in edges.values() if n == 1), edges_over_2_faces=sum(1 for n in edges.values() if n > 2),
                min_angle=round(float(mn.min()), 2) if len(mn) else None, tris_under_10deg=int((mn < 10).sum()),
                shell_regions=[(n, dict(reg[s].most_common(3))) for s, n in top])


def mirror_share(P, axis, tol=0.001):
    Q = P.copy()
    Q[:, axis] *= -1
    try:
        from scipy.spatial import cKDTree
        d, _ = cKDTree(P).query(Q)
    except ImportError:                                  # numpy fallback, fine for a few thousand positions
        d = np.array([np.sqrt(((P - q) ** 2).sum(1)).min() for q in Q])
    return float(np.mean(d < tol))


def symmetry(me):
    P = np.unique(np.round(me.pos, 4), axis=0)
    return dict(positions=len(P), mirrored={'XYZ'[k]: round(100 * mirror_share(P, k), 1) for k in range(3)})


def regions(meshes):
    tri, pos = collections.Counter(), collections.Counter()
    for me in meshes:
        if not (me.skinned or me.bones):
            continue
        for d in tri_dominant_bones(me):
            tri[U.legs_region(U.region(d)) if d else 'none'] += 1
        vw = me.vertex_weights()
        seen = {}
        for i, p in enumerate(np.round(me.pos, 4)):
            seen.setdefault(tuple(p), i)
        for i in seen.values():
            d = dominant(vw[i])
            pos[U.region(d) if d else 'none'] += 1
    nt, npos = sum(tri.values()) or 1, sum(pos.values()) or 1
    return dict(tris={k: (v, round(100 * v / nt, 1)) for k, v in tri.most_common()},
                positions={k: (v, round(100 * v / npos, 1)) for k, v in pos.most_common()})


def heads(m):
    P_all, H = [], []
    for me in m.meshes:
        if not me.skinned:
            continue
        hb = [b for b in me.bones if U.nm(b).endswith('head')]
        P_all.append(me.pos)
        if hb:
            vw = me.vertex_weights()
            H += [p for p, w in zip(me.pos, vw) if w.get(hb[0], 0) >= 0.9]
    if not P_all or not H:
        return None
    P, H = np.vstack(P_all), np.array(H)
    tot, hh = float(np.ptp(P[:, 1])), float(np.ptp(H[:, 1]))
    return dict(figure_y=(round(float(P[:, 1].min()), 3), round(float(P[:, 1].max()), 3)), head_height=round(hh, 3),
                heads_tall=round(tot / hh, 2) if hh else None, bbox=[np.round(P.min(0), 3).tolist(), np.round(P.max(0), 3).tolist()])


def hands(m):
    out = {}
    for me in m.meshes:
        if not me.skinned:
            continue
        doms = tri_dominant_bones(me)
        vw = me.vertex_weights()
        for side in ('l', 'r'):
            hb = [b for b in me.bones if U.nm(b) == 'bip01 %s hand' % side]
            if not hb:
                continue
            idx = [i for i, w in enumerate(vw) if dominant(w) == hb[0]]
            if not idx:
                continue
            P = np.unique(np.round(me.pos[idx], 4), axis=0)
            out[side] = dict(tris=sum(1 for d in doms if d == hb[0]), unique_positions=len(P),
                             extent=np.round(np.ptp(P, 0), 3).tolist(), x_range=np.round([P[:, 0].min(), P[:, 0].max()], 3).tolist())
    return out


def seat(me):
    """Faces a mount covers in the bind pose, kept or removed: triangles dominated by a pelvis or thigh bone whose
    normal faces down (seat, normal y < -0.5) or, thigh-dominated, towards the mid-plane (inner thigh,
    n.x * sign(centroid x) < -0.5). Normals from the winding, oriented outward over the whole mesh (engine y up)."""
    if not me.skinned or not len(me.tris):
        return None
    P = me.pos.astype(np.float64)
    a, b, c = (P[me.tris[:, k]] for k in range(3))
    n = np.cross(b - a, c - a)
    cen = (a + b + c) / 3.0
    if float((n * (cen - P.mean(0))).sum()) < 0:
        n = -n
    length = np.linalg.norm(n, axis=1)
    doms = tri_dominant_bones(me)
    zone = seat_down = inner = 0
    for t, d in enumerate(doms):
        if not length[t] or not d:
            continue
        name = U.nm(d)
        if 'pelvis' not in name and 'thigh' not in name:
            continue
        zone += 1
        u = n[t] / length[t]
        if u[1] < -0.5:
            seat_down += 1
        elif 'thigh' in name and cen[t, 0] and u[0] * np.sign(cen[t, 0]) < -0.5:
            inner += 1
    tris = len(me.tris)
    return dict(tris=tris, pelvis_thigh=zone, seat_down=seat_down, inner_thigh=inner,
                share=round(100.0 * (seat_down + inner) / tris, 1))


def uv(me, tex):
    if 'TextureCoordinates0' not in me.comps:
        return None
    P, UVc = me.pos, me.comps['TextureCoordinates0'].astype(np.float64)
    a, b, c = (P[me.tris[:, k]] for k in range(3))
    a3 = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    ua, ub, uc = (UVc[me.tris[:, k]] for k in range(3))
    su = 0.5 * ((ub[:, 0] - ua[:, 0]) * (uc[:, 1] - ua[:, 1]) - (uc[:, 0] - ua[:, 0]) * (ub[:, 1] - ua[:, 1]))
    auv, area = float(np.abs(su).sum()), float(a3.sum())
    return dict(area3d=round(area, 4), uv_area=round(auv, 4), uv_box=[np.round(UVc.min(0), 3).tolist(), np.round(UVc.max(0), 3).tolist()],
                texel_density=round(float(np.sqrt(auv * tex * tex / area)), 1) if area else None,
                negative_winding=round(float(np.abs(su[su < 0]).sum() / auv), 4) if auv else None)


def compare(pa, pb, tol=0.001):
    """share of A's welded positions with a partner in B: all positions as stored, and per hand after aligning the hands
    (relative to the hand joint, then a few rigid-translation steps: files whose frames differ by the root height, or
    whose hand sits a few mm off its joint, still compare). The hand result reports the residual shift in mm."""
    ma, mb = U.Model(pa), U.Model(pb)
    A = np.unique(np.round(np.vstack([x.pos for x in ma.meshes if x.skinned]), 4), axis=0)
    B = np.unique(np.round(np.vstack([x.pos for x in mb.meshes if x.skinned]), 4), axis=0)
    d = np.array([np.sqrt(((B - p) ** 2).sum(1)).min() for p in A])
    out = dict(positions_a=len(A), positions_b=len(B), shared=round(100 * float(np.mean(d < tol)), 1))
    ha, hb = hand_points(ma), hand_points(mb)
    for s in ('l', 'r'):
        if s in ha and s in hb:
            X, Y = ha[s].copy(), hb[s]
            shift = np.zeros(3)
            for _ in range(6):
                nn = np.array([np.argmin(((Y - p) ** 2).sum(1)) for p in X])
                step = np.median(Y[nn] - X, axis=0)
                X += step
                shift += step
            dd = np.array([np.sqrt(((Y - p) ** 2).sum(1)).min() for p in X])
            out['hand_' + s] = round(100 * float(np.mean(dd < tol)), 1)
            out['hand_%s_shift_mm' % s] = np.round(shift * 1000, 1).tolist()
    return out


def hand_points(m):
    """per side: unique positions dominated by the hand bone, minus that bone's rest joint position."""
    out, J = {}, m.joints()
    for me in m.meshes:
        if not me.skinned:
            continue
        vw = me.vertex_weights()
        for s in ('l', 'r'):
            hb = [b for b in me.bones if U.nm(b) == 'bip01 %s hand' % s]
            if hb:
                pts = [p for p, w in zip(me.pos, vw) if dominant(w) == hb[0]]
                if pts and U.nm(hb[0]) in J:
                    out[s] = np.unique(np.round(np.array(pts) - J[U.nm(hb[0])], 4), axis=0)
    return out


WHAT = ('shells', 'symmetry', 'regions', 'heads', 'hands', 'uv', 'seat')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    U.add_input_args(ap)
    ap.add_argument('--what', default='all', help='comma list of %s, or all' % ','.join(WHAT))
    ap.add_argument('--tex', type=int, default=1024, help='page size for the texel density')
    ap.add_argument('--compare', nargs=2, metavar=('A', 'B'))
    a = ap.parse_args(argv)
    if a.compare:
        r = compare(*a.compare)
        print('COMPARE %s in %s: %s' % (Path(a.compare[0]).stem, Path(a.compare[1]).stem, r))
        return r
    what = WHAT if a.what == 'all' else tuple(a.what.split(','))
    res = {}
    for p, m, why in U.models(U.resolve_inputs(a)):
        if m is None:
            print('%s: UNREADABLE %s' % (Path(p).stem, why))
            continue
        r = res[m.name] = {}
        print('== %s' % m.name)
        for me in m.meshes:
            if 'shells' in what:
                s = r.setdefault('shells', {})[me.name] = shells(me)
                print('   shells %s: %d tris, %d shells, largest %s, small %d, boundary edges %d, edges >2 faces %d, '
                      'min angle %s (%d under 10 deg); regions of the largest %s' % (
                          me.name, s['tris'], s['shells'], s['largest'], s['small_shells'], s['boundary_edges'],
                          s['edges_over_2_faces'], s['min_angle'], s['tris_under_10deg'], s['shell_regions'][:4]))
            if 'symmetry' in what:
                s = r.setdefault('symmetry', {})[me.name] = symmetry(me)
                print('   symmetry %s: %d positions, mirror partner %s %%' % (me.name, s['positions'], s['mirrored']))
            if 'uv' in what:
                s = r.setdefault('uv', {})[me.name] = uv(me, a.tex)
                if s:
                    print('   uv %s: area3d %.4f uvArea %.4f box %s texel %.1f px/unit @%d, negative winding %.4f' % (
                        me.name, s['area3d'], s['uv_area'], s['uv_box'], s['texel_density'] or 0, a.tex,
                        s['negative_winding'] or 0))
            if 'seat' in what:
                s = r.setdefault('seat', {})[me.name] = seat(me)
                if s:
                    print('   seat %s: %d tris, pelvis+thigh %d, seat-down %d, inner-thigh %d (%.1f %% of the mesh)' % (
                        me.name, s['tris'], s['pelvis_thigh'], s['seat_down'], s['inner_thigh'], s['share']))
        if 'regions' in what:
            s = r['regions'] = regions(m.meshes)
            print('   regions by triangles %s' % s['tris'])
            print('   regions by unique positions %s' % s['positions'])
        if 'heads' in what:
            s = r['heads'] = heads(m)
            if s:
                print('   heads: figure y %s, head %.3f -> %.1f heads tall; bbox %s' % (
                    s['figure_y'], s['head_height'], s['heads_tall'] or 0, s['bbox']))
        if 'hands' in what:
            s = r['hands'] = hands(m)
            for side, h in s.items():
                print('   hand %s: %d tris, %d positions, extent %s, x %s' % (side, h['tris'], h['unique_positions'],
                                                                         h['extent'], h['x_range']))
    return res


if __name__ == '__main__':
    main()
