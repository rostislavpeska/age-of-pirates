"""Feature metrics for character-topology-analysis (definitions.md D11-D13, D20-D27): limb rings, joint rings, the
shoulder / hip flow measure, poles on bending bands and pole zones, eye / mouth / mask rings found from topology, the
plane map of low-poly heads, density per region, limb edge alignment, torso and neck checks, ring-transition parity.
"""
import math

import numpy as np

from toplib import (r, pct, frame_of, winding_number, plane_fit, point_in_loop, face_normals_areas, Topology,
                    face_centroids)

RING_T_RANGE = (-0.2, 1.2)        # D11: ring centroid along its segment (x L)
RING_LABEL_SHARE = 0.75           # D11: >= 75 % of ring vertices labelled with the segment or a neighbour
BAND = 0.15                       # D12: pivot band +/- 15 % of the parent segment length
RING_BAND = 0.05                  # D12: pivot ring band +/- 5 %
SPACING_WINDOW = 0.20             # D12: L3 spacing window +/- 20 %
FLOW_T = (-0.25, 0.35)            # D20: shoulder / hip flow zone along the child segment (x L_child)
FLOW_RADIUS = 2.5                 # D20: zone radius = 2.5 x the local limb radius
FLOW_TURN = 0.75                  # D20: a loop run wraps when it turns >= 0.75 of a full turn
PLANE_DEG = 20.0                  # D23: plane-map growth angle
PLANE_MAP_MAX_TRIS = 700          # D23: plane-map heads: up to 700 head triangles (calibrated: the Blender Studio planar
                                  # head is 632, S12 LOD2 at 796 already carries eye rings)
ANIMATED_FACE_MIN_TRIS = 1500     # D13: a head over 1500 triangles is judged as an animated face (F1-F3)
FRONT = np.array([0.0, -1.0, 0.0])


# ---------------------------------------------------------------------------------------------------------------- helpers
def seg_frame(s):
    """axis a, front u, side w; w mirrors between left and right so angles read the same on both sides."""
    a, u, w = frame_of(s['d'])
    if s['name'].endswith('_r'):
        w = -w
    return a, u, w


def seg_coords(P, s):
    a, u, w = seg_frame(s)
    R = P - s['A']
    t = (R @ a) / s['L']
    Rp = R - np.outer(R @ a, a)
    ang = np.degrees(np.arctan2(Rp @ w, Rp @ u)) % 360
    rad = np.linalg.norm(Rp, axis=1)
    return t, ang, rad


def neighbours(segs, jf):
    idx = {s['name']: k for k, s in enumerate(segs)}
    nb = {k: {k} for k in range(len(segs))}
    for j in jf.values():
        p, c = idx.get(j['parent']), idx.get(j['child'])
        if p is not None and c is not None:
            nb[p].add(c)
            nb[c].add(p)
    # the torso segments border every limb root
    for k, s in enumerate(segs):
        if s['name'] in ('spine_lower', 'spine_upper'):
            for m, t in enumerate(segs):
                if t['name'] in ('spine_lower', 'spine_upper') or t['name'].startswith(('pelvis_', 'clavicle_')):
                    nb[k].add(m)
                    nb[m].add(k)
    return nb


# ---------------------------------------------------------------------------------------------------------------- D21 regions
def region_density(ctx):
    V, topo, sk = ctx['V'], ctx['topo'], ctx['skel']
    _, A = face_normals_areas(V, topo.faces)
    freg = sk['freg']
    tri = topo.sides - 2
    tot_t, tot_a = max(int(tri.sum()), 1), max(float(A.sum()), 1e-30)
    out = {}
    for rg in sorted(set(freg.tolist())):
        m = freg == rg
        t, a = int(tri[m].sum()), float(A[m].sum())
        out[rg] = dict(faces=int(m.sum()), tri_equivalent=t, tri_share=r(t / tot_t, 4), area_share=r(a / tot_a, 4),
                       density_ratio=r((t / tot_t) / max(a / tot_a, 1e-12), 3),
                       median_face_area_over_H2=r(np.median(A[m]) / ctx['H'] ** 2, 7) if m.any() else None,
                       quads=int((topo.sides[m] == 4).sum()))
    hs = sum(out[k]['tri_equivalent'] for k in ('head', 'neck') if k in out)
    return dict(per_region=out, head_share=r(out.get('head', {}).get('tri_equivalent', 0) / tot_t, 4),
                head_with_neck_share=r(hs / tot_t, 4), tri_equivalent=tot_t)


# ---------------------------------------------------------------------------------------------------------------- D11 rings
def find_rings(ctx):
    """D11: a ring of segment s is a closed edge loop that winds exactly once around s's axis, whose centroid lies at
    t in [-0.2, 1.2] of s, and >= 75 % of whose vertices are labelled s or a neighbour of s. A loop that qualifies for
    several segments belongs to the one owning most of its vertices (then the one with t nearest 0.5)."""
    V, sk = ctx['V'], ctx['skel']
    segs, vseg, jf = sk['segs'], sk['vseg'], sk['jf']
    nb = neighbours(segs, jf)
    rings = []
    for li, L in enumerate(ctx['loops']):
        if not L['closed'] or len(L['verts']) < 3:
            continue
        vs = np.array(L['verts'])
        P = V[vs]
        labs = vseg[vs]
        c = P.mean(axis=0)
        best = None
        for k, s in enumerate(segs):
            ok = np.isin(labs, list(nb[k])).mean()
            if ok < RING_LABEL_SHARE:
                continue
            t = float((c - s['A']) @ s['d'] / s['L'])
            if t < RING_T_RANGE[0] or t > RING_T_RANGE[1]:
                continue
            wn, rad = winding_number(P, s['A'], s['d'])
            if abs(round(wn)) != 1 or rad.min() < 1e-9:
                continue
            own = float((labs == k).mean())
            score = (round(own, 6), -abs(t - 0.5))
            if best is None or score > best[0]:
                best = (score, k, t, rad)
        if best is None:
            continue
        _, k, t, rad = best
        s = segs[k]
        _, n, _ = plane_fit(P)
        tilt = math.degrees(math.acos(min(1.0, abs(float(n @ s['d'])))))
        rings.append(dict(loop=li, seg=s['name'], k=k, t=t, sides=len(vs), tilt=tilt, radius=float(rad.mean()),
                          centroid=c))
    return rings


def partial_rings(ctx, s, k):
    """D11: broken rings of segment s - open loops whose run of vertices labelled s turns >= 0.75 around the axis."""
    V, vseg = ctx['V'], ctx['skel']['vseg']
    n, best = 0, 0.0
    for L in ctx['loops']:
        if L['closed'] or len(L['verts']) < 4:
            continue
        vs = np.array(L['verts'])
        ins = vseg[vs] == k
        if ins.sum() < 4:
            continue
        runs, cur = [], []
        for i, f in enumerate(ins):
            if f:
                cur.append(i)
            elif cur:
                runs.append(cur)
                cur = []
        if cur:
            runs.append(cur)
        for rr in runs:
            if len(rr) < 4:
                continue
            wn, _ = winding_number(V[vs[rr]], s['A'], s['d'], closed=False)
            best = max(best, abs(wn))
            if abs(wn) >= FLOW_TURN:
                n += 1
    return n, best


RING_STRIP_TILT_COS = 0.8         # D11: a ring strip is perpendicular when cos(tilt) >= 0.8 (tilt <= 36.9 deg)
RING_STRIP_T = (0.25, 0.9)        # D11: limb faces judged for ring cover: the shaft, centroid t in [0.25, 0.9] (the
                                  # root quarter belongs to the shoulder / hip flow, D20)


def face_segments(ctx):
    """per face: the segment label held by most of its vertices (ties: the lower segment index)."""
    vseg = ctx['skel']['vseg']
    out = np.full(ctx['topo'].nF, -1, np.int64)
    for f, fv in enumerate(ctx['topo'].faces):
        cnt = {}
        for v in fv:
            cnt[int(vseg[v])] = cnt.get(int(vseg[v]), 0) + 1
        out[f] = sorted(cnt.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]
    return out


def ring_strips(ctx):
    """D11: closed face rings (D10) that wind exactly once around a segment axis: >= 75 % of their faces labelled with
    that segment or a neighbour, the winding number of the ordered face centroids around the axis is +-1. Each strip is
    given to the qualifying segment owning most of its faces. Returns list of dict(faces, k, tilt)."""
    V, topo, sk = ctx['V'], ctx['topo'], ctx['skel']
    segs = sk['segs']
    if not segs:
        return []
    nb = neighbours(segs, sk['jf'])
    fseg = ctx.get('fseg')
    if fseg is None:
        fseg = ctx['fseg'] = face_segments(ctx)
    C = face_centroids(V, topo.faces)
    out = []
    for st in ctx['strips']:
        if not st['closed'] or len(st['faces']) < 3:
            continue
        fs = np.array(st['faces'])
        labs = fseg[fs]
        best = None
        for k in np.unique(labs):
            if k < 0:
                continue
            if np.isin(labs, list(nb[int(k)])).mean() < RING_LABEL_SHARE:
                continue
            s = segs[int(k)]
            wn, rad = winding_number(C[fs], s['A'], s['d'])
            if abs(round(wn)) != 1 or rad.min() < 1e-12:
                continue
            own = float((labs == k).mean())
            if best is None or own > best[0]:
                best = (own, int(k))
        if best is None:
            continue
        s = segs[best[1]]
        _, n, _ = plane_fit(C[fs])
        tilt = math.degrees(math.acos(min(1.0, abs(float(n @ s['d'])))))
        out.append(dict(faces=fs, k=best[1], tilt=tilt))
    return out


def ring_cover(ctx, strips, k):
    """D11 (L1): share of segment k's faces (centroid t in [0.1, 0.9]) that lie on a ring strip of k, and the share on
    a perpendicular one (cos tilt >= 0.8). Density-free: a low-poly limb with one face row per segment is covered by
    its single ring strip."""
    V, topo = ctx['V'], ctx['topo']
    s = ctx['skel']['segs'][k]
    fseg = ctx['fseg']
    C = face_centroids(V, topo.faces)
    t = ((C - s['A']) @ s['d']) / s['L']
    mine = np.where((fseg == k) & (t >= RING_STRIP_T[0]) & (t <= RING_STRIP_T[1]))[0]
    if len(mine) == 0:
        return None, None, 0
    on, on_al = set(), set()
    for g in strips:
        if g['k'] != k:
            continue
        on.update(int(f) for f in g['faces'])
        if math.cos(math.radians(g['tilt'])) >= RING_STRIP_TILT_COS:
            on_al.update(int(f) for f in g['faces'])
    return (float(np.isin(mine, list(on)).mean()), float(np.isin(mine, list(on_al)).mean()), int(len(mine)))


def ring_report(ctx, rings):
    sk = ctx['skel']
    H = ctx['H']
    strips = ring_strips(ctx)
    ctx['ring_strips'] = strips
    out = {}
    for k, s in enumerate(sk['segs']):
        rs = sorted([g for g in rings if g['k'] == k], key=lambda g: g['t'])
        pr, pbest = partial_rings(ctx, s, k)
        mid = [g for g in rs if 0.25 <= g['t'] <= 0.75]
        aligned = [g for g in mid if math.cos(math.radians(g['tilt'])) >= 0.8]
        cov, cov_al, nf = ring_cover(ctx, strips, k)
        out[s['name']] = dict(rings=len(rs), t=[r(g['t'], 3) for g in rs], sides=[g['sides'] for g in rs],
                              tilt_deg=[r(g['tilt'], 1) for g in rs], radius_over_H=[r(g['radius'] / H, 4) for g in rs],
                              median_sides=(int(np.median([g['sides'] for g in rs])) if rs else None),
                              mid_rings=len(mid), mid_aligned=len(aligned),
                              ring_face_share=r(cov, 3), ring_face_share_aligned=r(cov_al, 3), judged_faces=nf,
                              ring_strips=sum(1 for g in strips if g['k'] == k),
                              partial_rings=pr, best_open_turn=r(pbest, 2))
    return out


# ---------------------------------------------------------------------------------------------------------------- D12 joints
def joint_rings(ctx, rings):
    """D12: rings of the joint's two segments whose centroid lies within +/-15 % of the parent length of the pivot
    plane (normal = bisector of the two segment directions); L3 spacing ratio inside +/-20 %."""
    sk = ctx['skel']
    out = {}
    for jn, j in sk['jf'].items():
        Lb = band_length(j)
        cand = [g for g in rings if g['seg'] in (j['parent'], j['child'])]
        off = sorted(float((g['centroid'] - j['pivot']) @ j['n']) / Lb for g in cand)
        inb = [g for g in cand if abs(float((g['centroid'] - j['pivot']) @ j['n'])) <= BAND * Lb]
        near = [x for x in off if abs(x) <= SPACING_WINDOW]
        gn = np.diff(near) if len(near) > 1 else np.array([])
        ga = np.diff(off) if len(off) > 1 else np.array([])
        out[jn] = dict(rings_in_band=len(inb), sides=sorted(g['sides'] for g in inb),
                       offsets=[r(x, 3) for x in near], median_gap_near=r(np.median(gn), 4) if gn.size else None,
                       median_gap_all=r(np.median(ga), 4) if ga.size else None,
                       spacing_ratio=r(np.median(gn) / np.median(ga), 3) if gn.size and ga.size and np.median(ga) > 0 else None,
                       band_length_over_H=r(Lb / ctx['H'], 4))
    return out


def band_length(j):
    """D12: the band is measured in units of the longer of the joint's two segments (the parent at elbow, knee, wrist and
    ankle; the upper arm / thigh at shoulder and hip, where the short clavicle / pelvis segment made the band vanish)."""
    return max(j['L_parent'], j['L_child'])


def band_poles(ctx):
    """D12: poles (inner valence != 4) labelled with the joint's two segments inside +/-15 % (band) and +/-5 % (ring band)
    of the parent length from the pivot plane."""
    V, sk, poles = ctx['V'], ctx['skel'], ctx['poles']
    idx = {s['name']: k for k, s in enumerate(sk['segs'])}
    used = ctx['topo'].vnf > 0
    out = {}
    for jn, j in sk['jf'].items():
        ks = [idx[j['parent']], idx[j['child']]]
        own = np.isin(sk['vseg'], ks) & used
        d = np.abs((V - j['pivot']) @ j['n'])
        b15 = own & (d <= BAND * band_length(j))
        b05 = own & (d <= RING_BAND * band_length(j))
        ins = ctx.get('inset_owner', {})
        cap = [int(v) for v in np.where(b15 & poles)[0] if int(v) in ins and not on_crease(ctx, jn, V[v])]
        capm = np.zeros(len(V), bool)
        capm[cap] = True
        crease = [int(v) for v in np.where(b15 & poles)[0] if on_crease(ctx, jn, V[v])]
        out[jn] = dict(poles_band=int((b15 & poles & ~capm).sum()), verts_band=int(b15.sum()),
                       poles_band_crease=len(crease), poles_band_extension=int((b15 & poles).sum()) - len(crease),
                       poles_ring_band=int((b05 & poles & ~capm).sum()), verts_ring_band=int(b05.sum()),
                       cap_pattern_poles=len(cap),
                       pole_valences=sorted(int(ctx['topo'].valence[v]) for v in np.where(b15 & poles & ~capm)[0]))
    return out


# ---------------------------------------------------------------------------------------------------------------- D20 flow
def limb_radius(ctx, c, a):
    """D20: the local limb radius at axis point c: mean distance from c of the plane section (normal a) component
    nearest c - exact at any density (a low-poly thigh has no vertex at mid length, its section still exists)."""
    import tl_skeleton as SK
    topo = ctx['topo']
    if 'FE' not in ctx:
        ctx['FE'] = [topo.face_edges(f) for f in range(topo.nF)]
    P = SK.nearest_component(SK.section_components(ctx['V'], topo.E, ctx['FE'], c, a), c)
    if P is None:
        return None
    return float(np.mean(np.linalg.norm(P - c, axis=1)))


def flow_measure(ctx, jn):
    """D20: shoulder / hip flow. Zone: t in [-0.25, 0.35] of the child segment (upper arm / thigh) from the pivot and
    radial distance <= 2.5 x the local limb radius (limb_radius at t 0.4 of the child).
    Every edge loop (open or closed) is cut into runs of consecutive zone vertices; a run that turns >= 0.75 around the
    child axis wraps the limb root. Reports the wrapping runs (count, t, tilt), the closed rings among them and the
    straw-ring transition (tilt falling as t grows)."""
    V, sk = ctx['V'], ctx['skel']
    j = sk['jf'].get(jn)
    if j is None:
        return None
    segs = {s['name']: (k, s) for k, s in enumerate(sk['segs'])}
    kc, C = segs[j['child']]
    a = C['d']
    L = C['L']
    used = ctx['topo'].vnf > 0
    R = V - j['pivot']
    t = (R @ a) / L
    rad = np.linalg.norm(R - np.outer(R @ a, a), axis=1)
    r_loc = limb_radius(ctx, j['pivot'] + 0.4 * L * a, a)
    if r_loc is None:
        return dict(error='the plane at t 0.4 of %s misses the mesh' % j['child'])
    zone = used & (t >= FLOW_T[0]) & (t <= FLOW_T[1]) & (rad <= FLOW_RADIUS * r_loc)
    runs = []
    for li, Lp in enumerate(ctx['loops']):
        vs = np.array(Lp['verts'])
        if len(vs) < 3:
            continue
        ins = zone[vs]
        if not ins.any():
            continue
        if Lp['closed'] and ins.all():
            seqs = [(list(range(len(vs))), True)]
        else:
            seqs, cur = [], []
            order = list(range(len(vs)))
            if Lp['closed']:
                k0 = int(np.argmin(ins))      # start the scan at a vertex outside the zone
                order = order[k0:] + order[:k0]
            for i in order:
                if ins[i]:
                    cur.append(i)
                elif cur:
                    seqs.append((cur, False))
                    cur = []
            if cur:
                seqs.append((cur, False))
        for sq, full in seqs:
            if len(sq) < 3:
                continue
            P = V[vs[sq]]
            wn, _ = winding_number(P, j['pivot'], a, closed=full)
            if abs(wn) >= FLOW_TURN:
                _, n, _ = plane_fit(P)
                tilt = math.degrees(math.acos(min(1.0, abs(float(n @ a)))))
                runs.append(dict(loop=li, t=float(t[vs[sq]].mean()), tilt=tilt, verts=len(sq), closed=bool(full),
                                 turn=abs(wn)))
    runs.sort(key=lambda g: g['t'])
    ts = [g['t'] for g in runs]
    tl = [g['tilt'] for g in runs]
    trend = None
    if len(runs) >= 3 and np.ptp(ts) > 0:
        trend = float(np.polyfit(ts, tl, 1)[0])
    root = [g for g in runs if 0.0 <= g['t'] <= 0.25]
    return dict(wrapping_loops=len(runs), closed_rings=sum(1 for g in runs if g['closed']),
                arm_root_wrapping=len(root), t=[r(x, 3) for x in ts], tilt_deg=[r(x, 1) for x in tl],
                tilt_slope_deg_per_L=r(trend, 1), zone_radius_over_H=r(FLOW_RADIUS * r_loc / ctx['H'], 4),
                zone_verts=int(zone.sum()), zone_poles=int((zone & ctx['poles']).sum()))


def shoulder_poles(ctx, jn):
    """L5: shoulder-band poles below the pivot and inside its |x| (armpit side); poles within 30 deg of straight up
    around the arm axis (deltoid top)."""
    V, sk, poles = ctx['V'], ctx['skel'], ctx['poles']
    j = sk['jf'].get(jn)
    if j is None:
        return None
    idx = {s['name']: k for k, s in enumerate(sk['segs'])}
    own = np.isin(sk['vseg'], [idx[j['parent']], idx[j['child']]])
    d = np.abs((V - j['pivot']) @ j['n'])
    sel = np.where(own & poles & (d <= BAND * band_length(j)))[0]
    xm = 0.0 if 'pelvis' not in sk['J'] else float(sk['J']['pelvis'][0])
    armpit = [v for v in sel if V[v, 2] < j['pivot'][2] and abs(V[v, 0] - xm) <= abs(j['pivot'][0] - xm)]
    C = [s for s in sk['segs'] if s['name'] == j['child']][0]
    a, _, _ = frame_of(C['d'])
    up = np.array([0, 0, 1.0]) - (a @ np.array([0, 0, 1.0])) * a
    top = 0
    if np.linalg.norm(up) > 1e-9:
        up /= np.linalg.norm(up)
        for v in sel:
            rv = V[v] - j['pivot']
            rv = rv - (rv @ a) * a
            if np.linalg.norm(rv) > 1e-12 and float(rv @ up) / np.linalg.norm(rv) >= math.cos(math.radians(30)):
                top += 1
    return dict(band_poles=int(len(sel)), armpit_side=len(armpit), armpit_share=r(len(armpit) / len(sel), 3) if len(sel) else None,
                deltoid_top_poles=top)


# ---------------------------------------------------------------------------------------------------------------- D24 limb edges
def limb_edges(ctx):
    V, topo, sk = ctx['V'], ctx['topo'], ctx['skel']
    lab = sk['vseg']
    segs = sk['segs']
    limb = {k for k, s in enumerate(segs) if s['kind'] in ('upperarm', 'forearm', 'thigh', 'calf')}
    par = perp = tot = 0
    for a, b in topo.E:
        la, lb = lab[a], lab[b]
        if la != lb or la not in limb:
            continue
        d = V[b] - V[a]
        n = np.linalg.norm(d)
        if n < 1e-12:
            continue
        cs = abs(float(d @ segs[la]['d'])) / n
        tot += 1
        par += cs > math.cos(math.radians(20))
        perp += cs < math.sin(math.radians(20))
    return dict(edges=tot, parallel_share=r(par / max(tot, 1), 3), perpendicular_share=r(perp / max(tot, 1), 3),
                aligned_share=r((par + perp) / max(tot, 1), 3))


# ---------------------------------------------------------------------------------------------------------------- D13 face
def face_features(ctx, landmarks=None):
    """D13: eye and mouth centres found from topology. Candidates = closed edge loops and closed boundary loops whose
    vertices are all head-region, that face forward (best-fit normal within 60 deg of -Y) and whose radius is <= 0.3 x
    the head height. The innermost candidates (containing no smaller candidate's centroid) are feature centres: the eye
    pair is the best mirrored pair off the midline in the upper head; the mouth is the innermost candidate on the
    midline 0.6-1.6 eye distances below the eyes. Rings are then counted as in F1-F3."""
    V, topo, sk = ctx['V'], ctx['topo'], ctx['skel']
    vreg = sk['vreg']
    head = (vreg == 'head') & (topo.vnf > 0)
    if head.sum() < 30:
        return None
    Ph = V[head]
    Hh = float(np.ptp(Ph[:, 2]))
    xmid = 0.5 * (Ph[:, 0].min() + Ph[:, 0].max())
    zlo = Ph[:, 2].min()
    loops = [L['verts'] for L in ctx['loops'] if L['closed'] and len(L['verts']) >= 3]
    bl = [L['verts'] for L in topo.boundary_loops() if L['closed'] and L['nverts'] >= 3]
    allc = []
    for kind, lst in (('loop', loops), ('boundary', bl)):
        for vs in lst:
            if not head[vs].all():
                continue
            P = V[vs]
            c, n, _ = plane_fit(P)
            rad = float(np.linalg.norm(P - c, axis=1).max())
            allc.append(dict(kind=kind, verts=vs, c=c, n=n, rad=rad))
    cand = [g for g in allc if abs(float(g['n'] @ FRONT)) >= 0.5 and g['rad'] <= 0.3 * Hh]
    for g in cand:
        g['P'] = V[g['verts']]
    inner = []
    for g in cand:
        smaller = [h for h in cand if h is not g and h['rad'] < g['rad']]
        if smaller and point_in_loop(np.array([h['c'] for h in smaller]), g['P']).any():
            continue
        inner.append(g)

    fam_cache = {}

    def family(g):
        """the closed EDGE loops (not boundaries) around candidate g's centroid."""
        k = id(g)
        if k not in fam_cache:
            fam_cache[k] = [h for h in cand if h['kind'] == 'loop' and h is not g and point_in_loop(g['c'], h['P'])[0]]
        return fam_cache[k]
    best = None
    side = [g for g in cand if abs(g['c'][0] - xmid) >= 0.06 * Hh and g['c'][2] >= zlo + 0.40 * Hh]
    for a in side:
        for b in side:
            if a is b or (a['c'][0] - xmid) <= 0 or (b['c'][0] - xmid) >= 0:
                continue
            if abs(a['c'][0] + b['c'][0] - 2 * xmid) > 0.04 * Hh or abs(a['c'][2] - b['c'][2]) > 0.04 * Hh \
                    or abs(a['c'][1] - b['c'][1]) > 0.04 * Hh:
                continue
            # the eye centre sits inside the most rings; among equals the larger candidate (the eye opening, not a
            # corner detail inside it) wins
            score = (len(family(a)) + len(family(b)), round(a['rad'] + b['rad'], 9), float(a['c'][2]))
            if best is None or score > best[0]:
                best = (score, a, b)
    out = dict(head_height_over_H=r(Hh / ctx['H'], 4), candidates=len(cand), innermost=len(inner))
    if best is None:
        out.update(eyes_found=False, mouth_found=False, eye_rings=[0, 0], mouth_rings=0, mask_loops=0)
        return out
    el, er = best[1]['c'], best[2]['c']
    e = float(np.linalg.norm(el - er))
    ez = 0.5 * (el[2] + er[2])
    ey = 0.5 * (el[1] + er[1])
    mids = [g for g in cand if abs(g['c'][0] - xmid) <= 0.03 * Hh and ez - 1.6 * e < g['c'][2] < ez - 0.6 * e
            and g['c'][1] < ey + 0.3 * e and g['rad'] < 0.9 * e]
    mouth = None
    if mids:
        mouth = sorted(mids, key=lambda g: (-len(family(g)), -g['rad'], abs(g['c'][2] - (ez - 1.1 * e))))[0]['c']

    face_loops = dict(eye_l=[], eye_r=[], mouth=[], mask=[])

    def rings_around(c, key, others):
        """closed edge loops around feature centre c: centroid within 0.6 e of c (front view), radius < 0.9 e, c inside
        and no other feature centre inside (a loop around both eyes, or around an eye and the mouth, is not a ring of
        either)."""
        n = 0
        sizes = []
        for g in allc:
            if g['kind'] != 'loop':
                continue
            if np.linalg.norm((g['c'] - c)[[0, 2]]) > 0.6 * e or g['rad'] >= 0.9 * e:
                continue
            P = V[g['verts']]
            if point_in_loop(c, P)[0] and not any(point_in_loop(o, P)[0] for o in others):
                n += 1
                sizes.append(len(g['verts']))
                face_loops[key].append(list(g['verts']))
        return n, sorted(sizes)
    nl, sl = rings_around(el, 'eye_l', [er] + ([mouth] if mouth is not None else []))
    nr, sr = rings_around(er, 'eye_r', [el] + ([mouth] if mouth is not None else []))
    out.update(eyes_found=True, eye_distance_over_H=r(e / ctx['H'], 4), eye_centres_over_H=[r(el / ctx['H'], 4), r(er / ctx['H'], 4)],
               eye_rings=[nl, nr], eye_ring_sides=[sl, sr])
    nose = None
    if mouth is not None:
        nm, sm = rings_around(mouth, 'mouth', [el, er])
        mid_line = head & (np.abs(V[:, 0] - xmid) <= 0.02 * Hh) & (V[:, 2] > mouth[2]) & (V[:, 2] < ez)
        if mid_line.any():
            ids = np.where(mid_line)[0]
            nose = V[ids[np.argmin(V[ids, 1])]]
        mask = 0
        if nose is not None:
            for g in allc:
                if g['kind'] != 'loop' or g['rad'] >= 1.5 * e:
                    continue
                P = V[g['verts']]
                ins = point_in_loop(np.array([mouth, nose, el, er]), P)
                if ins[0] and ins[1] and not ins[2] and not ins[3]:
                    mask += 1
                    face_loops['mask'].append(list(g['verts']))
        out.update(mouth_found=True, mouth_centre_over_H=r(mouth / ctx['H'], 4), mouth_rings=nm, mouth_ring_sides=sm,
                   nose_tip_over_H=r(nose / ctx['H'], 4) if nose is not None else None, mask_loops=mask)
    else:
        out.update(mouth_found=False, mouth_rings=0, mask_loops=0)
    # face poles: head poles within 1.2 eye distances of the face centre, by valence and nearest landmark
    lm = [('eye', el), ('eye', er)] + ([('mouth', mouth)] if mouth is not None else []) + ([('nose', nose)] if nose is not None else [])
    fc = np.mean([p for _, p in lm], axis=0)
    fp = np.where(ctx['poles'] & head & (np.linalg.norm(V - fc, axis=1) <= 1.2 * e))[0]
    near = {}
    for v in fp:
        d = [(np.linalg.norm(V[v] - p) / e, nm_) for nm_, p in lm]
        dd, nm_ = min(d)
        key = '%s_%s' % (nm_, 'within_0.6e' if dd <= 0.6 else 'beyond_0.6e')
        near[key] = near.get(key, 0) + 1
    out['face_poles'] = dict(total=int(len(fp)), v3=int(sum(ctx['topo'].valence[v] == 3 for v in fp)),
                             v5=int(sum(ctx['topo'].valence[v] == 5 for v in fp)),
                             v6plus=int(sum(ctx['topo'].valence[v] >= 6 for v in fp)), by_landmark=near)
    out['_landmarks'] = dict(eyes=(el, er), mouth=mouth, nose=nose, e=e, xmid=xmid, Hh=Hh)
    out['_face_loops'] = face_loops
    return out


# ---------------------------------------------------------------------------------------------------------------- D23 plane map
def plane_map(ctx):
    """D23: head faces grown into near-planar patches: seeds in order of decreasing area, a neighbour joins when its
    normal is within 20 deg of the patch's area-weighted mean normal. Reported for heads up to 600 triangles."""
    V, topo, sk = ctx['V'], ctx['topo'], ctx['skel']
    hf = np.where(sk['freg'] == 'head')[0]
    tri = int((topo.sides[hf] - 2).sum())
    if len(hf) == 0 or tri > PLANE_MAP_MAX_TRIS:
        return dict(applied=False, head_tri_equivalent=tri, reason='head over %d triangles' % PLANE_MAP_MAX_TRIS if len(hf) else 'no head')
    N, A = face_normals_areas(V, topo.faces)
    C = face_centroids(V, topo.faces)
    inhead = np.zeros(topo.nF, bool)
    inhead[hf] = True
    adj = {int(f): set() for f in hf}
    for e in range(topo.nE):
        fs = [int(f) for f in topo.edge_faces(e) if inhead[f]]
        for a in fs:
            for b in fs:
                if a != b:
                    adj[a].add(b)
    order = sorted(hf.tolist(), key=lambda f: (-A[f], f))
    patch = {}
    patches = []
    cosmax = math.cos(math.radians(PLANE_DEG))
    for s in order:
        if s in patch:
            continue
        pid = len(patches)
        members = [s]
        patch[s] = pid
        acc = N[s] * A[s]
        front = [s]
        while front:
            nxt = []
            for f in front:
                for g in sorted(adj[f]):
                    if g in patch:
                        continue
                    mn = acc / max(np.linalg.norm(acc), 1e-30)
                    if float(N[g] @ mn) >= cosmax:
                        patch[g] = pid
                        members.append(g)
                        acc = acc + N[g] * A[g]
                        nxt.append(g)
            front = nxt
        patches.append(members)
    ctx['plane_patch'] = dict(patch)
    Ph = V[np.unique(np.concatenate([np.array(topo.faces[f]) for f in hf]))]
    ctr = 0.5 * (Ph.min(axis=0) + Ph.max(axis=0))
    Hh = float(np.ptp(Ph[:, 2]))
    tot = float(A[hf].sum())
    out = []
    for pid, mem in enumerate(patches):
        mn = (N[mem] * A[mem][:, None]).sum(axis=0)
        mn = mn / max(np.linalg.norm(mn), 1e-30)
        c = (C[mem] * A[mem][:, None]).sum(axis=0) / max(A[mem].sum(), 1e-30)
        rel = (c - ctr) / max(Hh, 1e-30)
        facing = ['right', 'left', 'back', 'front', 'under', 'top'][int(np.argmax(np.r_[-mn[0], mn[0], mn[1], -mn[1], -mn[2], mn[2]]))]
        side = 'centre' if abs(rel[0]) < 0.08 else ('left' if rel[0] > 0 else 'right')
        out.append(dict(faces=len(mem), tri_equivalent=int((topo.sides[mem] - 2).sum()), area_share=r(A[mem].sum() / tot, 4),
                        normal=r(mn, 2), centre_over_head=r(rel, 3), facing=facing, side=side))
    out.sort(key=lambda p: (-p['area_share'], p['centre_over_head']))
    return dict(applied=True, planes=len(out), head_tri_equivalent=tri, angle_deg=PLANE_DEG,
                planes_over_2pct=sum(1 for p in out if p['area_share'] >= 0.02), patches=out)


# ---------------------------------------------------------------------------------------------------------------- D22 pole zones
INSET_HOPS = 3                    # D26: two 3/5 pole pairs belong to one pattern when they are within 3 edge hops
CREASE_DIR = dict(elbow=np.array([0.0, -1.0, 0.0]), knee=np.array([0.0, 1.0, 0.0]))   # D26: default crease sides


def inset_patterns(ctx):
    """D26: inset (cap) patterns - clusters of >= 2 edge-joined valence-3 / valence-5 pole pairs, within 3 edge hops of
    each other, with as many 3-poles as 5-poles and every 3-pole nearer the cluster centre than its 5-pole (the
    signature of one inset: 5-poles on the outer corners, 3-poles inside). Kneecaps, elbow caps, nipples and the navel
    are built this way. Returns (list of patterns, vertex -> pattern id)."""
    V, topo, poles = ctx['V'], ctx['topo'], ctx['poles']
    val = topo.valence
    pv = set(int(v) for v in np.where(poles)[0] if val[v] in (3, 5))
    pairs = []
    for a, b in topo.E:
        a, b = int(a), int(b)
        if a in pv and b in pv and {int(val[a]), int(val[b])} == {3, 5}:
            pairs.append((a, b) if val[a] == 3 else (b, a))
    if not pairs:
        return [], {}
    near = {}
    for v in {x for pr in pairs for x in pr}:
        seen = {v}
        front = [v]
        for _ in range(INSET_HOPS):
            nxt = []
            for u in front:
                for e in topo.vertex_edges(u):
                    w = topo.other(int(e), u)
                    if w not in seen:
                        seen.add(w)
                        nxt.append(w)
            front = nxt
        near[v] = seen
    from toplib import UnionFind
    uf = UnionFind(len(pairs))
    for i in range(len(pairs)):
        for j in range(i + 1, len(pairs)):
            if any(x in near[pairs[i][0]] or x in near[pairs[i][1]] for x in pairs[j]):
                uf.union(i, j)
    groups = {}
    for i in range(len(pairs)):
        groups.setdefault(uf.find(i), []).append(pairs[i])
    pats, owner = [], {}
    for grp in groups.values():
        n3 = {a for a, _ in grp}
        n5 = {b for _, b in grp}
        if len(grp) < 2 or len(n3) != len(n5) or (n3 & n5):
            continue
        c = V[list(n3 | n5)].mean(axis=0)
        if not all(np.linalg.norm(V[a] - c) < np.linalg.norm(V[b] - c) for a, b in grp):
            continue
        pid = len(pats)
        pats.append(dict(id=pid, poles=sorted(n3 | n5), n3=len(n3), n5=len(n5), centre=c))
        for v in n3 | n5:
            owner[v] = pid
    return pats, owner


def on_crease(ctx, jn, p):
    """True when point p lies on the crease half of the elbow / knee (the flexion side: elbow front, knee back)."""
    j = ctx['skel']['jf'][jn]
    base = jn.rsplit('_', 1)[0]
    cd = CREASE_DIR.get(base)
    if cd is None:
        return True
    n = j['n']
    cd = cd - (cd @ n) * n
    if np.linalg.norm(cd) < 1e-9:
        return True
    rv = p - j['pivot']
    rv = rv - (rv @ n) * n
    return float(rv @ cd) > 0


FACE_SITE_E = 1.0                 # D22: face-site radius in eye distances (0.6 in the step-1 rule; hm08 jaw-side poles sit at 0.96)
TRANSITION_BAND = 0.25            # D22: wrist / ankle zones +-25 % (hand and foot funnels; S03 wrist poles sit at 0.20)
NECK_STUMP_E = 0.8                # D22: a head part's poles more than 0.8 eye distances below the mouth are its neck stump
ALLOWED_ZONES = ('hand', 'foot', 'face_site', 'ear_side', 'head_top_back', 'head_planes', 'jaw_line', 'neck_base',
                 'neck_stump', 'joint_cap',
                 'neck_back', 'shoulder_band', 'hip_band', 'wrist_band', 'ankle_band', 'shoulder_root', 'hip_root',
                 'armpit_side_chest', 'back_flat', 'crotch', 'chest_abdomen', 'inset_pattern')
BAD_ZONES = ('bend_band', 'limb_mid', 'face_other', 'neck_front')


def pole_zones(ctx, face):
    """D22 (P2): every pole gets one zone, first match wins.
    hands / feet region -> hand / foot.
    head region -> face_site (<= 1.0 eye distance of an eye, mouth or nose landmark in the front view (x, z), so the
      mouth and eye cavities count), neck_stump (head parts: more than 0.8 e below the mouth), ear_side
      (|x - head centre| >= 0.6 half width), head_top_back (behind the head centre or above the eyes), head_planes (no
      face landmarks), else face_other.
    neck region -> jaw_line / neck_base (inside the head / neck-base joint band), neck_back, else neck_front.
    limb poles of an inset pattern (D26) off the crease half of an elbow / knee band -> inset_pattern.
    torso and limbs -> the joint band it sits in: elbow / knee +-15 % -> bend_band on the crease half, joint_cap on the
      extension half (kneecap, elbow tip); shoulder_band, hip_band (+-15 %); wrist_band, ankle_band (+-25 %); then
      shoulder_root / hip_root (t <= 0.35 of the upper arm / thigh); else torso: armpit_side_chest (|x| >= half the
      shoulder half-width), back_flat (behind the torso centre), crotch (below the pelvis joint near the midline),
      chest_abdomen; limbs: limb_mid.
    Not allowed: bend_band, limb_mid, face_other, neck_front."""
    V, sk, poles, topo = ctx['V'], ctx['skel'], ctx['poles'], ctx['topo']
    vreg = sk['vreg']
    J = sk['J']
    zones, per = {}, {}
    lm = face.get('_landmarks') if face else None
    head = vreg == 'head'
    if head.any():
        Ph = V[head & (topo.vnf > 0)]
        hx = 0.5 * (Ph[:, 0].min() + Ph[:, 0].max())
        hw = 0.5 * np.ptp(Ph[:, 0])
        hc = 0.5 * (Ph.min(axis=0) + Ph.max(axis=0))
    idx = {s['name']: k for k, s in enumerate(sk['segs'])}
    bands = [(jn, [idx[j['parent']], idx[j['child']]], j) for jn, j in sk['jf'].items()]
    xm = float(J['pelvis'][0]) if 'pelvis' in J else 0.0
    torso_v = V[(vreg == 'torso') & (topo.vnf > 0)]
    yc = 0.5 * (torso_v[:, 1].min() + torso_v[:, 1].max()) if len(torso_v) else 0.0
    sh = [J[k] for k in ('l_shoulder', 'r_shoulder') if k in J]
    shx = float(np.mean([abs(q[0] - xm) for q in sh])) if sh else 0.15 * ctx['H']

    def in_band(v, names):
        for jn, ks, j in bands:
            base = jn.rsplit('_', 1)[0]
            width = TRANSITION_BAND if base in ('wrist', 'ankle') else BAND
            if base in names and sk['vseg'][v] in ks and abs(float((V[v] - j['pivot']) @ j['n'])) <= width * band_length(j):
                return base
        return None

    def limb_root(v):
        """D22: a pole of an upper arm / thigh in its root zone (t <= 0.35 from the shoulder / hip, D20's flow zone)."""
        s = sk['segs'][int(sk['vseg'][v])] if sk['vseg'][v] >= 0 else None
        if s is None or s['kind'] not in ('upperarm', 'thigh'):
            return None
        t = float((V[v] - s['A']) @ s['d']) / s['L']
        return ('shoulder_root' if s['kind'] == 'upperarm' else 'hip_root') if t <= FLOW_T[1] else None
    for v in np.where(poles)[0]:
        rg = vreg[v]
        p = V[v]
        z = None
        if rg == 'hands':
            z = 'hand'
        elif rg == 'feet':
            z = 'foot'
        elif rg == 'head':
            if lm is not None:
                pts = [x for x in (lm['eyes'][0], lm['eyes'][1], lm['mouth'], lm['nose']) if x is not None]
                if min(np.linalg.norm((p - x)[[0, 2]]) for x in pts) <= FACE_SITE_E * lm['e']:
                    z = 'face_site'
            if z is None and lm is not None and lm['mouth'] is not None and ctx['kind'] == 'head' \
                    and p[2] < lm['mouth'][2] - NECK_STUMP_E * lm['e']:
                z = 'neck_stump'
            if z is None:
                if abs(p[0] - hx) >= 0.6 * hw:
                    z = 'ear_side'
                elif p[1] > hc[1] or (lm is not None and p[2] > 0.5 * (lm['eyes'][0][2] + lm['eyes'][1][2])):
                    z = 'head_top_back'
                elif lm is None:
                    z = 'head_planes'
                else:
                    z = 'face_other'
        elif rg == 'neck':
            b = in_band(v, ('head', 'neck_base'))
            if b == 'head':
                z = 'jaw_line'
            elif b == 'neck_base':
                z = 'neck_base'
            else:
                z = 'neck_back' if p[1] > (J['neck'][1] if 'neck' in J else 0.0) else 'neck_front'
        else:
            b = in_band(v, ('elbow', 'knee', 'shoulder', 'hip', 'wrist', 'ankle'))
            ins = ctx.get('inset_owner', {})
            crease = False
            if b in ('elbow', 'knee'):
                jn = [x for x in sk['jf'] if x.startswith(b) and sk['vseg'][v] in
                      (idx[sk['jf'][x]['parent']], idx[sk['jf'][x]['child']])]
                crease = on_crease(ctx, jn[0], p) if jn else True
            if int(v) in ins and rg in ('arms', 'legs') and not crease:
                z = 'inset_pattern'
            elif b in ('elbow', 'knee'):
                z = 'bend_band' if crease else 'joint_cap'     # the extension side (kneecap, elbow tip) is allowed
            elif b is not None:
                z = b + '_band'
            elif limb_root(v):
                z = limb_root(v)
            elif rg == 'torso':
                pel = J.get('pelvis')
                if abs(p[0] - xm) >= 0.5 * shx:
                    z = 'armpit_side_chest'
                elif p[1] > yc:
                    z = 'back_flat'
                elif pel is not None and p[2] < pel[2] and abs(p[0] - xm) < 0.35 * shx:
                    z = 'crotch'
                else:
                    z = 'chest_abdomen'
            else:
                z = 'limb_mid'
        zones[int(v)] = z
        per[z] = per.get(z, 0) + 1
    return dict(by_zone=dict(sorted(per.items())), unexplained=sum(c for z, c in per.items() if z in BAD_ZONES),
                unexplained_zones=sorted(z for z in per if z in BAD_ZONES)), zones


# ---------------------------------------------------------------------------------------------------------------- torso / neck / parity
def torso_checks(ctx, rings):
    V, topo, sk = ctx['V'], ctx['topo'], ctx['skel']
    J = sk['J']
    out = {}
    waist = [g for g in rings if g['seg'] == 'spine_lower' and 0.15 <= g['t'] <= 0.85]
    out['waist_rings'] = len(waist)
    if 'pelvis' in J and 'chest' in J:
        z0, z1 = sorted([J['pelvis'][2], J['chest'][2]])
        span = 0
        for f, rg in zip(topo.faces, sk['freg']):
            if rg != 'torso':
                continue
            zs = V[list(f), 2]
            if zs.min() <= z0 and zs.max() >= z1:
                span += 1
        out['faces_spanning_both_spine_pivots'] = span
    neck = sorted([g for g in rings if g['seg'] == 'neck'], key=lambda g: g['radius'])
    out['neck_ring_sides'] = neck[0]['sides'] if neck else None
    out['neck_rings'] = len(neck)
    return out


def ring_parity(ctx, rings):
    """D25 (L7): consecutive rings of a segment with N != M sides. In an all-quad band 4Q = 2 E_inner + (N + M), so N + M
    is even and the band holds >= |N - M| / 2 pole pairs by construction; the measurable failure is an odd N + M step,
    which needs a triangle or an n-gon among the faces between the two rings."""
    V, topo, sk = ctx['V'], ctx['topo'], ctx['skel']
    loops = ctx['loops']
    trans = []
    for k, s in enumerate(sk['segs']):
        rs = sorted([g for g in rings if g['k'] == k], key=lambda g: g['t'])
        if len(rs) < 2:
            continue
        for g, h in zip(rs[:-1], rs[1:]):
            if g['sides'] == h['sides']:
                continue
            band = band_faces(topo, loops[g['loop']]['edges'], loops[h['loop']]['edges'])
            if band is None:
                trans.append(dict(seg=s['name'], sides=(g['sides'], h['sides']), odd=bool((g['sides'] + h['sides']) % 2),
                                  band='not an annulus', ok=True))
                continue
            nonquad = int(sum(1 for f in band if topo.sides[f] != 4))
            bv = {v for f in band for v in topo.faces[f]} - set(loops[g['loop']]['verts']) - set(loops[h['loop']]['verts'])
            odd = bool((g['sides'] + h['sides']) % 2)
            trans.append(dict(seg=s['name'], sides=(g['sides'], h['sides']), odd=odd, band_faces=len(band),
                              nonquad_between=nonquad, poles_between=int(sum(1 for v in bv if ctx['poles'][v])),
                              ok=(not odd) or nonquad > 0))
    return dict(transitions=len(trans), odd=sum(1 for x in trans if x['odd']),
                odd_without_nonquad=sum(1 for x in trans if not x['ok']), items=trans[:40])


def band_faces(topo, edges_a, edges_b):
    """D25: the faces between two rings = the face component(s) that touch both rings once the edges of both rings are
    cut (flood fill over the remaining edges). None when no component touches both (the rings do not bound an annulus)."""
    cut = set(int(e) for e in edges_a) | set(int(e) for e in edges_b)
    ea, eb = set(int(e) for e in edges_a), set(int(e) for e in edges_b)
    from toplib import UnionFind
    uf = UnionFind(topo.nF)
    for e in range(topo.nE):
        if e in cut:
            continue
        fs = topo.edge_faces(e)
        for g in fs[1:]:
            uf.union(int(fs[0]), int(g))
    touch_a, touch_b = set(), set()
    for e in ea:
        touch_a.update(uf.find(int(f)) for f in topo.edge_faces(e))
    for e in eb:
        touch_b.update(uf.find(int(f)) for f in topo.edge_faces(e))
    both = touch_a & touch_b
    if not both or not (touch_a - both) or not (touch_b - both):
        return None                  # the two rings do not cut an annulus out of the surface
    roots = uf.roots()
    return [f for f in range(topo.nF) if roots[f] in both]


# ---------------------------------------------------------------------------------------------------------------- driver
def measure_features(ctx, rep, landmarks=None):
    sk = ctx['skel']
    rep['regions'] = region_density(ctx)
    face = face_features(ctx, landmarks)
    ctx['face'] = face
    if face is not None:
        rep['face'] = {k: v for k, v in face.items() if not k.startswith('_')}
    else:
        rep['face'] = None
    rep['plane_map'] = plane_map(ctx) if (sk['freg'] == 'head').any() else None
    pats, owner = inset_patterns(ctx)
    ctx['insets'], ctx['inset_owner'] = pats, owner
    rep['inset_patterns'] = dict(count=len(pats), sizes=[p['n3'] + p['n5'] for p in pats])
    if ctx['kind'] == 'body' and sk['segs']:
        rings = find_rings(ctx)
        ctx['rings'] = rings
        rep['rings'] = ring_report(ctx, rings)
        rep['joint_rings'] = joint_rings(ctx, rings)
        rep['band_poles'] = band_poles(ctx)
        rep['flow'] = {jn: flow_measure(ctx, jn) for jn in ('shoulder_l', 'shoulder_r', 'hip_l', 'hip_r') if jn in sk['jf']}
        rep['shoulder_poles'] = {jn: shoulder_poles(ctx, jn) for jn in ('shoulder_l', 'shoulder_r') if jn in sk['jf']}
        rep['limb_edges'] = limb_edges(ctx)
        rep['torso'] = torso_checks(ctx, rings)
        rep['ring_parity'] = ring_parity(ctx, rings)
        rep['ring_sides_by_kind'] = _sides_by_kind(sk['segs'], rings)
    else:
        ctx['rings'] = []
    pz, zones = pole_zones(ctx, face) if ctx['kind'] in ('body', 'head') else (None, {})
    ctx['pole_zone'] = zones
    rep['pole_zones'] = pz


def _sides_by_kind(segs, rings):
    out = {}
    for s in segs:
        out.setdefault(s['kind'], []).extend(g['sides'] for g in rings if g['seg'] == s['name'])
    return {k: (int(np.median(v)) if v else None) for k, v in sorted(out.items())}
