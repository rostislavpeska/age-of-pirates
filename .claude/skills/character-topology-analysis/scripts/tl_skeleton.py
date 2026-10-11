"""Skeleton, segments and region segmentation for character-topology-analysis (definitions.md D17-D19).

Joint sources, in this order for --skeleton auto: the asset's rig (GLB skin, Blender armature, OBJ joint groups) mapped
to canonical keys by name; else the landmark estimator (standing human, Z up, facing -Y, arms away from the body).
--skeleton estimate forces the estimator, --skeleton FILE.json gives joints {canonical key: [x, y, z]} in the mesh frame.

Canonical keys: pelvis, chest, neck, head, top, l_/r_ clavicle, shoulder, elbow, wrist, hand_tip, hip, knee, ankle,
toe, toe_tip. The character's left is +X.
"""
import json
import math
import re

import numpy as np

SIDES = ('l', 'r')

# D19: segment chains (name, region, start key, end key); {s} = side
SEGMENTS = [
    ('spine_lower', 'torso', 'pelvis', 'chest'),
    ('spine_upper', 'torso', 'chest', 'neck'),
    ('neck', 'neck', 'neck', 'head'),
    ('head', 'head', 'head', 'top'),
    ('clavicle_{s}', 'torso', 'neck', '{s}_shoulder'),
    ('upperarm_{s}', 'arms', '{s}_shoulder', '{s}_elbow'),
    ('forearm_{s}', 'arms', '{s}_elbow', '{s}_wrist'),
    ('hand_{s}', 'hands', '{s}_wrist', '{s}_hand_tip'),
    ('pelvis_{s}', 'torso', 'pelvis', '{s}_hip'),
    ('thigh_{s}', 'legs', '{s}_hip', '{s}_knee'),
    ('calf_{s}', 'legs', '{s}_knee', '{s}_ankle'),
    ('foot_{s}', 'feet', '{s}_ankle', '{s}_toe_tip'),
]
# D19: joints (name, parent segment, child segment)
JOINTS = [
    ('neck_base', 'spine_upper', 'neck'),
    ('head', 'neck', 'head'),
    ('shoulder_{s}', 'clavicle_{s}', 'upperarm_{s}'),
    ('elbow_{s}', 'upperarm_{s}', 'forearm_{s}'),
    ('wrist_{s}', 'forearm_{s}', 'hand_{s}'),
    ('hip_{s}', 'pelvis_{s}', 'thigh_{s}'),
    ('knee_{s}', 'thigh_{s}', 'calf_{s}'),
    ('ankle_{s}', 'calf_{s}', 'foot_{s}'),
]
# D19: radius priors (x H) used to normalise the capsule distance in the region segmentation (heuristic, stated)
RADIUS_PRIOR = dict(spine_lower=0.095, spine_upper=0.095, neck=0.035, head=0.06, clavicle=0.05, upperarm=0.032,
                    forearm=0.026, hand=0.03, pelvis=0.07, thigh=0.05, calf=0.035, foot=0.03)
HEAD_PLANE_TILT_DEG = 50.0      # D19: the head plane leans forward (jaw, chin and mouth cavity head, throat neck); calibrated on hm08 weights
REGIONS = ('head', 'neck', 'torso', 'arms', 'hands', 'legs', 'feet')


def expand(tmpl):
    out = []
    for t in tmpl:
        if any('{s}' in x for x in t):
            for s in SIDES:
                out.append(tuple(x.replace('{s}', s) for x in t))
        else:
            out.append(t)
    return out


SEGS = expand(SEGMENTS)
JNTS = expand(JOINTS)
SEG_INDEX = {s[0]: i for i, s in enumerate(SEGS)}


# ---------------------------------------------------------------------------------------------------------------- D17 names
_DROP_TOKENS = {'mixamorig', 'bip01', 'bip1', 'def', 'org', 'mch', 'armature', 'skeleton', 'pikeman', 'joint', 'bone'}


def _tokens(name):
    n = re.sub(r'([a-z])([A-Z])', r'\1 \2', str(name))
    n = n.lower()
    out = []
    for t in re.split(r'[^a-z0-9]+', n):
        if not t or t in _DROP_TOKENS:
            continue
        t = re.sub(r'\d+$', '', t)
        if t and t not in _DROP_TOKENS and t != 'bip':
            out.append(t)
    return out


def _side(tk, raw):
    s = None
    for t in tk:
        if t in ('l', 'left') or t.startswith('left'):
            s = 'l'
        elif t in ('r', 'right') or t.startswith('right'):
            s = 'r'
    return s


def joint_role(name):
    """D17: (side, role) of a joint or bone name; role None when it is not a canonical body joint."""
    tk = _tokens(name)
    j = ' '.join(tk)
    side = _side(tk, name)
    if any(t in ('twist', 'roll', 'nub', 'end', 'tip', 'ik', 'pole', 'target', 'helper') for t in tk) and 'finger' not in j:
        if 'head' in tk and ('end' in tk or 'nub' in tk or 'top' in tk):
            return None, 'top'
        return side, None
    if 'finger' in j or any(t in ('thumb', 'index', 'middle', 'ring', 'pinky', 'little') for t in tk):
        return side, 'finger'
    if 'toe' in j or 'ball' in tk:
        return side, 'toe' if side else None
    if 'clavicle' in tk or 'collar' in tk:
        return side, 'clavicle'
    if 'forearm' in tk or 'lowerarm' in tk or ('lower' in tk and 'arm' in tk) or ('fore' in tk and 'arm' in tk) or 'elbow' in tk:
        return side, 'elbow'
    if 'upperarm' in tk or ('upper' in tk and 'arm' in tk) or (tk[-1:] == ['arm'] and side):
        return side, 'shoulder'
    if 'shoulder' in tk:
        return side, 'shoulder?'
    if 'hand' in tk or 'wrist' in tk:
        return side, 'wrist'
    if 'thigh' in tk or 'upleg' in tk or ('up' in tk and 'leg' in tk) or ('upper' in tk and 'leg' in tk):
        return side, 'hip'
    if 'calf' in tk or 'shin' in tk or 'lowerleg' in tk or ('lower' in tk and 'leg' in tk) or 'knee' in tk or (tk[-1:] == ['leg'] and side):
        return side, 'knee'
    if 'foot' in tk or 'ankle' in tk:
        return side, 'ankle'
    if 'hip' in tk and side:
        return side, 'hip'
    if 'pelvis' in tk or 'hips' in tk or ('hip' in tk and not side):
        return None, 'pelvis'
    if 'neck' in tk:
        return None, 'neck'
    if 'head' in tk:
        return None, 'head'
    if 'spine' in tk or 'chest' in tk:
        return None, 'spine'
    return side, None


def canon_from_rig(rig):
    """D17: canonical joints from a {name: position} rig (bone heads or joint markers)."""
    if not rig:
        return {}, {}
    cand = {}
    for name in sorted(rig):
        side, role = joint_role(name)
        if role is None:
            continue
        cand.setdefault((side, role), []).append((name, np.asarray(rig[name], float)))
    J, used = {}, {}

    def put(key, item):
        J[key] = item[1]
        used[key] = item[0]
    for s in SIDES:
        sh = cand.get((s, 'shoulder'), [])
        amb = cand.get((s, 'shoulder?'), [])
        if sh:
            put(s + '_shoulder', sh[0])
            if amb:
                put(s + '_clavicle', amb[0])
        elif amb:
            put(s + '_shoulder', amb[0])
        for role, key in (('clavicle', 'clavicle'), ('elbow', 'elbow'), ('wrist', 'wrist'), ('hip', 'hip'),
                          ('knee', 'knee'), ('ankle', 'ankle')):
            lst = cand.get((s, role), [])
            if lst and (s + '_' + key) not in J:
                # several bones of one role (e.g. foot-1 / foot-2): the one nearest the body centre keeps the role
                put(s + '_' + key, lst[0])
        toes = cand.get((s, 'toe'), [])
        if toes and (s + '_ankle') in J:
            # the toe joint nearest the ankle is the ball, the farthest is the toe tip
            d = [np.linalg.norm(p - J[s + '_ankle']) for _, p in toes]
            put(s + '_toe', toes[int(np.argmin(d))])
            put(s + '_toe_tip', toes[int(np.argmax(d))])
        fing = cand.get((s, 'finger'), [])
        if fing and (s + '_wrist') in J:
            d = [np.linalg.norm(p - J[s + '_wrist']) for _, p in fing]
            put(s + '_hand_tip', fing[int(np.argmax(d))])
    for role in ('pelvis', 'neck', 'head', 'top'):
        lst = cand.get((None, role), [])
        if lst:
            # lowest neck bone is the neck base; the head joint is the lowest 'head' bone
            k = int(np.argmin([p[2] for _, p in lst]))
            put(role, lst[k])
    sp = cand.get((None, 'spine'), [])
    if sp:
        zs = [p[2] for _, p in sp]
        o = np.argsort(zs)
        put('chest', sp[int(o[len(o) // 2])] if len(o) > 2 else sp[int(o[-1])])
    return J, used


# ---------------------------------------------------------------------------------------------------------------- D18 estimator
def section_points(V, E, p0, n):
    """D18: the points where the mesh edges E cross the plane through p0 with normal n (exact, any density)."""
    n = np.asarray(n, float) / np.linalg.norm(n)
    s = (V - p0) @ n
    a, b = E[:, 0], E[:, 1]
    sa, sb = s[a], s[b]
    m = (sa * sb < 0)
    t = sa[m] / (sa[m] - sb[m])
    P = V[a[m]] + (V[b[m]] - V[a[m]]) * t[:, None]
    on = np.where(s == 0)[0]
    return np.vstack([P, V[on]]) if len(on) else P


def section_components(V, E, FE, p0, n):
    """D18: the plane section split into its connected polylines (one per limb, torso, hand ... the plane cuts):
    crossing points of edges that share a face are joined. FE = per face the list of its edge ids. Returns a list of
    point arrays."""
    n = np.asarray(n, float) / np.linalg.norm(n)
    s = (V - p0) @ n
    sa, sb = s[E[:, 0]], s[E[:, 1]]
    cross = np.where(sa * sb < 0)[0]
    if len(cross) == 0:
        return []
    idx = {int(e): k for k, e in enumerate(cross)}
    parent = list(range(len(cross)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for fe in FE:
        ks = [idx[int(e)] for e in fe if int(e) in idx]
        for k in ks[1:]:
            ra, rb = find(ks[0]), find(k)
            if ra != rb:
                parent[max(ra, rb)] = min(ra, rb)
    t = sa[cross] / (sa[cross] - sb[cross])
    P = V[E[cross, 0]] + (V[E[cross, 1]] - V[E[cross, 0]]) * t[:, None]
    groups = {}
    for k in range(len(cross)):
        groups.setdefault(find(k), []).append(k)
    return [P[g] for g in sorted(groups.values(), key=lambda g: g[0])]


def nearest_component(comps, c, min_points=3):
    """the section component whose centroid is nearest c (None when there is none)."""
    best = None
    for P in comps:
        if len(P) < min_points:
            continue
        d = float(np.linalg.norm(P.mean(axis=0) - c))
        if best is None or d < best[0]:
            best = (d, P)
    return None if best is None else best[1]


def _section_centroid(V, E, c, n, rad, FE=None):
    """centroid of the plane section through c (normal n): the connected section component nearest c when FE is given
    (else the points within rad of c); c itself when the plane misses the mesh there."""
    if FE is not None:
        P = nearest_component(section_components(V, E, FE, c, n), c)
        if P is not None and np.linalg.norm(P.mean(axis=0) - c) < 2 * rad:
            return P.mean(axis=0), len(P)
        return np.asarray(c, float), 0
    P = section_points(V, E, c, n)
    if len(P):
        P = P[np.linalg.norm(P - c, axis=1) < rad]
    if len(P) < 3:
        return np.asarray(c, float), 0
    return P.mean(axis=0), len(P)


UPPER_ARM = 0.186                  # D18: segment lengths x H (Drillis & Contini)
FOREARM = 0.146
HAND = 0.108
ARM_WALK_STEP = 0.01               # D18: arm centre-line walk step (x H)
ARM_WALK_SKIP = 0.15               # D18: no root test within this distance of the hand tip (fingers, palm)
ARM_ROOT_JUMP = 2.0                # D18: the arm root is where the section radius jumps above 2x the arm's median


def arm_chain(V, E, FE, tip, sh0, H):
    """D18: walk the arm's centre line from the hand tip toward the body through perpendicular plane sections (nearest
    connected component each step, direction re-estimated from the last centroids) until the section merges with the
    torso (radius > 2x the arm's running median, tested only beyond 0.15 H from the tip). Shoulder = the last arm
    centroid moved one arm radius further along the walk; elbow and wrist = the points of the centre line at the
    Drillis fractions 0.186 / 0.44 and 0.332 / 0.44 of the shoulder -> tip length. Returns (shoulder, elbow, wrist) or
    None when the walk fails (the caller keeps the proportion estimate)."""
    d = sh0 - tip
    if np.linalg.norm(d) < 1e-9:
        return None
    d = d / np.linalg.norm(d)
    p = tip + d * 0.02 * H
    pts, radii = [np.asarray(tip, float)], [0.0]
    walked = 0.0
    root = None
    for _ in range(int(0.9 / ARM_WALK_STEP)):
        P = nearest_component(section_components(V, E, FE, p, d), p)
        if P is None:
            break
        c = P.mean(axis=0)
        rad = float(np.mean(np.linalg.norm(P - c, axis=1)))
        if np.linalg.norm(c - p) > 0.08 * H:
            break
        arm_r = [x for x in radii[1:] if x > 0]
        if walked > ARM_WALK_SKIP * H and len(arm_r) >= 5 and rad > ARM_ROOT_JUMP * float(np.median(arm_r[-12:])):
            root = (pts[-1], float(np.median(arm_r[-12:])))
            break
        walked += float(np.linalg.norm(c - pts[-1]))
        pts.append(c)
        radii.append(rad)
        if len(pts) >= 4:
            nd = pts[-1] - pts[-4]
            if np.linalg.norm(nd) > 1e-9:
                d = 0.5 * d + 0.5 * nd / np.linalg.norm(nd)
                d = d / np.linalg.norm(d)
        p = c + d * ARM_WALK_STEP * H
    if root is None or walked < 0.25 * H:
        return None
    sh = root[0] + d * root[1]
    line = np.vstack(pts[::-1] + [])          # shoulder side first
    line = np.vstack([sh, line])
    seg = np.linalg.norm(np.diff(line, axis=0), axis=1)
    cum = np.concatenate([[0], np.cumsum(seg)])
    total = cum[-1]

    def at(frac):
        s = frac * total
        k = int(np.searchsorted(cum, s, side='right') - 1)
        k = min(max(k, 0), len(seg) - 1)
        w = (s - cum[k]) / max(seg[k], 1e-12)
        return line[k] + w * (line[k + 1] - line[k])
    return sh, at(UPPER_ARM / (UPPER_ARM + FOREARM + HAND)), at((UPPER_ARM + FOREARM) / (UPPER_ARM + FOREARM + HAND))


def estimate_joints(V, E=None, FE=None):
    """D18: proportions of a standing adult (knee 0.285 H, hip 0.51 H, shoulder 0.80 H, upper arm 0.186 H, forearm
    0.146 H; Drillis & Contini / Winter) refined by plane SECTIONS of the mesh (exact at any density, so a low-poly body
    with one face row per segment is located as well as a dense one). A section is split into its connected polylines
    and the one nearest the expected place is used, so a hand hanging beside the thigh never pulls the leg centroid.
    knee = leg section centroid at 0.285 H; ankle = the knee -> 0.08 H section line extended to 0.045 H; hip 0.01 H
    inside the 0.45 H thigh section, at 0.51 H; elbow = centroid of the arm section perpendicular to the provisional
    shoulder -> hand-tip line; shoulder = 0.186 H back from the elbow along the upper-arm axis (mid upper-arm section ->
    elbow), so wide or narrow shoulders follow the mesh; wrist = 0.146 H from the elbow toward the hand tip, re-centred
    on its section; neck = the narrowest horizontal section component between 0.80 and 0.93 H. Z up, facing -Y, the
    character's left at +X. V = the used vertices, E = edges over V, FE = per face its edge ids (without E a vertex-slab
    fallback is used)."""
    if E is None or len(E) == 0:
        return _estimate_slab(V)
    zmin = V[:, 2].min()
    H = V[:, 2].max() - zmin
    Z = lambda f: zmin + f * H
    up = np.array([0, 0, 1.0])
    sec = section_points(V, E, np.array([0, 0, Z(0.68)]), up)
    x0 = float(np.median(sec[:, 0])) if len(sec) else float(np.median(V[:, 0]))
    y0 = float(np.median(sec[:, 1])) if len(sec) else float(np.median(V[:, 1]))

    def comp_centroid(c, n, rad):
        return _section_centroid(V, E, c, n, rad, FE)[0]
    J = {}
    for s, sg in (('l', 1), ('r', -1)):
        def leg_centroid(f, guess_x):
            c = np.array([guess_x, y0, Z(f)])
            if FE is not None:
                P = nearest_component(section_components(V, E, FE, c, up), c)
                if P is not None:
                    P = P[sg * (P[:, 0] - x0) > 0.0]       # a pelvis-wide section: keep this side only
            else:
                P = section_points(V, E, c, up)
                P = P[(sg * (P[:, 0] - x0) > 0.005 * H) & (np.abs(P[:, 0] - x0) < 0.25 * H)] if len(P) else P
            if P is None or len(P) < 3:
                return c
            m = P.mean(axis=0)
            return np.array([m[0], m[1], Z(f)])
        kn = leg_centroid(0.285, x0 + sg * 0.06 * H)
        lo = leg_centroid(0.08, kn[0])
        d = lo - kn
        an = kn + d * ((Z(0.045) - kn[2]) / d[2]) if abs(d[2]) > 1e-9 else np.array([kn[0], kn[1], Z(0.045)])
        th = leg_centroid(0.45, kn[0])
        hp = np.array([th[0] - sg * 0.01 * H, th[1], Z(0.51)])
        J[s + '_hip'], J[s + '_knee'], J[s + '_ankle'] = hp, kn, an
        side = V[(sg * (V[:, 0] - x0) > 0)]
        hi = side[side[:, 2] > Z(0.30)]
        tip = hi[np.argmax(sg * (hi[:, 0] - x0))] if len(hi) else np.array([x0 + sg * 0.4 * H, y0, Z(0.6)])
        sh0 = np.array([x0 + sg * 0.105 * H, y0, Z(0.80)])
        chain = arm_chain(V, E, FE, tip, sh0, H) if FE is not None else None
        if chain is not None:
            sh, el, wr = chain
        else:
            dvec = tip - sh0
            Lr = max(np.linalg.norm(dvec), 1e-9)
            dd = dvec / Lr
            sh = sh0
            el = comp_centroid(sh0 + dd * Lr * (0.186 / 0.44), dd, 0.07 * H)
            wr = comp_centroid(sh0 + dd * Lr * (0.332 / 0.44), dd, 0.05 * H)
        J[s + '_shoulder'], J[s + '_elbow'], J[s + '_wrist'], J[s + '_hand_tip'] = sh, el, wr, tip
    best = None
    for f in np.linspace(0.80, 0.93, 27):
        c = np.array([x0, y0, Z(f)])
        if FE is not None:
            P = nearest_component(section_components(V, E, FE, c, up), c, min_points=4)
        else:
            P = section_points(V, E, c, up)
            P = P[np.abs(P[:, 0] - x0) < 0.09 * H] if len(P) else P
        if P is None or len(P) < 4:
            continue
        w = np.ptp(P[:, 0]) * np.ptp(P[:, 1])
        if best is None or w < best[0]:
            best = (w, f, P[:, :2].mean(axis=0))
    nc = np.array([best[2][0], best[2][1], Z(best[1])]) if best else np.array([x0, y0, Z(0.87)])
    J['neck'] = nc - 0.033 * H * up
    J['head'] = nc + 0.033 * H * up
    J['pelvis'] = np.array([x0, y0, Z(0.53)])
    return J


def _slab_centroid(V, c, d, half, rad):
    d = d / np.linalg.norm(d)
    R = V - c
    t = R @ d
    perp = np.linalg.norm(R - np.outer(t, d), axis=1)
    m = (np.abs(t) < half) & (perp < rad)
    if m.sum() < 3:
        return c
    q = V[m].mean(axis=0)
    return q - ((q - c) @ d) * d


def _estimate_slab(V):
    """vertex-slab fallback of D18 for a point set without edges."""
    zmin = V[:, 2].min()
    H = V[:, 2].max() - zmin
    Z = lambda f: zmin + f * H
    tor = V[(V[:, 2] > Z(0.60)) & (V[:, 2] < Z(0.75))]
    x0 = float(np.median(tor[:, 0])) if len(tor) else 0.0
    y0 = float(np.median(tor[:, 1])) if len(tor) else 0.0
    up = np.array([0, 0, 1.0])
    J = {}
    for s, sg in (('l', 1), ('r', -1)):
        side = V[(sg * (V[:, 0] - x0) > 0)]
        leg = side[np.abs(side[:, 0] - x0) < 0.20 * H]
        kn = _slab_centroid(leg, np.array([x0 + sg * 0.06 * H, y0, Z(0.285)]), up, 0.015 * H, 0.12 * H)
        lo = _slab_centroid(leg, np.array([kn[0], kn[1], Z(0.12)]), up, 0.012 * H, 0.08 * H)
        d = lo - kn
        an = kn + d * ((Z(0.045) - kn[2]) / d[2]) if abs(d[2]) > 1e-9 else np.array([kn[0], kn[1], Z(0.045)])
        th = _slab_centroid(leg, np.array([x0 + sg * 0.07 * H, y0, Z(0.45)]), up, 0.015 * H, 0.10 * H)
        J[s + '_hip'], J[s + '_knee'], J[s + '_ankle'] = np.array([th[0] - sg * 0.01 * H, th[1], Z(0.51)]), kn, an
        hi = side[side[:, 2] > Z(0.30)]
        tip = hi[np.argmax(sg * (hi[:, 0] - x0))] if len(hi) else np.array([x0 + sg * 0.4 * H, y0, Z(0.6)])
        sh = np.array([x0 + sg * 0.105 * H, y0, Z(0.80)])
        dvec = tip - sh
        Lr = max(np.linalg.norm(dvec), 1e-9)
        dd = dvec / Lr
        J[s + '_shoulder'], J[s + '_hand_tip'] = sh, tip
        J[s + '_elbow'] = _slab_centroid(V, sh + dd * Lr * (0.186 / 0.44), dd, 0.012 * H, 0.07 * H)
        J[s + '_wrist'] = _slab_centroid(V, sh + dd * Lr * (0.332 / 0.44), dd, 0.010 * H, 0.05 * H)
    J['neck'] = np.array([x0, y0, Z(0.837)])
    J['head'] = np.array([x0, y0, Z(0.903)])
    J['pelvis'] = np.array([x0, y0, Z(0.53)])
    return J


def complete(J, V, H):
    """D17: derived joints - pelvis (mid hips), chest (mid pelvis-neck), top (crown), hand tips, toe tips."""
    J = {k: np.asarray(v, float) for k, v in J.items()}
    if 'pelvis' not in J and 'l_hip' in J and 'r_hip' in J:
        J['pelvis'] = (J['l_hip'] + J['r_hip']) / 2
    if 'neck' not in J and 'head' in J and 'pelvis' in J:
        J['neck'] = J['head'] - 0.066 * H * np.array([0, 0, 1.0])
    if 'head' not in J and 'neck' in J:
        J['head'] = J['neck'] + 0.066 * H * np.array([0, 0, 1.0])
    if 'chest' not in J and 'pelvis' in J and 'neck' in J:
        J['chest'] = (J['pelvis'] + J['neck']) / 2
    if 'head' in J and 'top' not in J:
        hj = J['head']
        m = (np.linalg.norm(V[:, :2] - hj[:2], axis=1) < 0.08 * H) & (V[:, 2] > hj[2])
        J['top'] = np.array([hj[0], hj[1], V[m, 2].max() if m.any() else hj[2] + 0.12 * H])
    for s in SIDES:
        w, e = J.get(s + '_wrist'), J.get(s + '_elbow')
        if w is not None and e is not None and (s + '_hand_tip') not in J:
            d = (w - e) / max(np.linalg.norm(w - e), 1e-9)
            R = V - w
            t = R @ d
            perp = np.linalg.norm(R - np.outer(t, d), axis=1)
            m = (t > 0) & (perp < 0.07 * H)
            if m.any() and t[m].max() > 0.01 * H:       # no hand when nothing reaches past the wrist
                J[s + '_hand_tip'] = w + d * t[m].max()
        a = J.get(s + '_ankle')
        if a is not None and (s + '_toe_tip') not in J:
            sg = 1 if s == 'l' else -1
            m = (V[:, 2] < a[2]) & (np.abs(V[:, 0] - a[0]) < 0.08 * H) & (sg * (V[:, 0] - J.get('pelvis', a)[0]) > 0)
            ymin = V[m, 1].min() if m.any() else a[1] - 0.12 * H
            J[s + '_toe_tip'] = np.array([a[0], ymin, a[2] - 0.5 * (a[2] - V[:, 2].min())])
        if (s + '_shoulder') in J and (s + '_clavicle') not in J and 'neck' in J:
            pass
    return J


# ---------------------------------------------------------------------------------------------------------------- D19 segments
def build_segments(J):
    segs = []
    for name, region, a, b in SEGS:
        if a == 'neck' and name.startswith('clavicle') and (name[-1] + '_clavicle') in J:
            a = name[-1] + '_clavicle'
        if a in J and b in J and np.linalg.norm(J[b] - J[a]) > 1e-9:
            d = J[b] - J[a]
            segs.append(dict(name=name, region=region, a=a, b=b, A=J[a], B=J[b], L=float(np.linalg.norm(d)),
                             d=d / np.linalg.norm(d), kind=re.sub(r'_[lr]$', '', name)))
    return segs


def _front_normal(d, tilt_deg):
    front = np.array([0, -1.0, 0])
    f = front - (front @ d) * d
    if np.linalg.norm(f) < 1e-9:
        return d
    f /= np.linalg.norm(f)
    t = math.radians(tilt_deg)
    n = math.cos(t) * d + math.sin(t) * f
    return n / np.linalg.norm(n)


def joint_frames(segs):
    """D19: for every joint between two present segments: the pivot, the plane normal (bisector of the two segment
    directions; the head plane leans HEAD_PLANE_TILT_DEG forward), the parent length."""
    by = {s['name']: s for s in segs}
    out = {}
    for name, p, c in JNTS:
        if p in by and c in by:
            P, C = by[p], by[c]
            if name == 'head':
                n = _front_normal(C['d'], HEAD_PLANE_TILT_DEG)
            else:
                n = P['d'] + C['d']
                n = n / np.linalg.norm(n) if np.linalg.norm(n) > 1e-9 else C['d']
            out[name] = dict(name=name, parent=p, child=c, pivot=C['A'], n=n, L_parent=P['L'], L_child=C['L'])
    return out


def segment_labels(V, segs, jf, H):
    """D19: each vertex takes the segment with the smallest capsule distance / radius prior among the segments whose
    slab (between its start and end joint planes) contains it; when none does, among all segments."""
    n = len(V)
    if not segs:
        return np.full(n, -1)
    start_plane, end_plane = {}, {}
    for j in jf.values():
        start_plane[j['child']] = (j['pivot'], j['n'])
        end_plane[j['parent']] = (j['pivot'], j['n'])
    D = np.full((n, len(segs)), np.inf)
    allowed = np.ones((n, len(segs)), bool)
    for k, s in enumerate(segs):
        ab = s['B'] - s['A']
        t = np.clip(((V - s['A']) @ ab) / max(ab @ ab, 1e-30), 0, 1)
        d = np.linalg.norm(V - (s['A'] + t[:, None] * ab), axis=1)
        rad = RADIUS_PRIOR.get(s['kind'], 0.05) * H
        D[:, k] = d / rad
        if s['name'] in start_plane:
            p, nn = start_plane[s['name']]
            allowed[:, k] &= (V - p) @ nn >= 0
        if s['name'] in end_plane:
            p, nn = end_plane[s['name']]
            allowed[:, k] &= (V - p) @ nn <= 0
    Da = np.where(allowed, D, np.inf)
    lab = np.argmin(Da, axis=1)
    none = ~np.isfinite(Da.min(axis=1))
    lab[none] = np.argmin(D[none], axis=1)
    return lab


def clean_labels(lab, topo):
    """D19 connectivity clean-up: within each shell, every segment label keeps only its largest edge-connected piece;
    the other pieces (an elbow ring that the fat torso capsule claimed, a chest patch caught by the tilted head plane)
    are re-labelled by the majority of their labelled edge neighbours, repeated until stable. A shell is never
    re-labelled from another shell. Returns (labels, number of vertices moved)."""
    lab = np.asarray(lab).copy()
    used = topo.vnf > 0
    nV = len(lab)
    adj = [[] for _ in range(nV)]
    for a, b in topo.E:
        adj[int(a)].append(int(b))
        adj[int(b)].append(int(a))
    from toplib import UnionFind
    uf = UnionFind(nV)
    for a, b in topo.E:
        uf.union(int(a), int(b))
    shell = np.array([uf.find(i) for i in range(nV)])
    free = np.zeros(nV, bool)
    for sh in np.unique(shell[used]):
        vs = np.where(used & (shell == sh))[0]
        for k in np.unique(lab[vs]):
            mem = [int(v) for v in vs if lab[v] == k]
            ms = set(mem)
            seen, comps = set(), []
            for v in mem:
                if v in seen:
                    continue
                comp, stack = [], [v]
                seen.add(v)
                while stack:
                    u = stack.pop()
                    comp.append(u)
                    for w in adj[u]:
                        if w in ms and w not in seen:
                            seen.add(w)
                            stack.append(w)
                comps.append(comp)
            if len(comps) > 1:
                comps.sort(key=lambda c: (-len(c), min(c)))
                for c in comps[1:]:
                    free[c] = True
    moved = int(free.sum())
    for _ in range(nV):
        if not free.any():
            break
        changed = False
        for v in np.where(free)[0]:
            votes = {}
            for w in adj[v]:
                if not free[w]:
                    votes[int(lab[w])] = votes.get(int(lab[w]), 0) + 1
            if votes:
                lab[v] = sorted(votes.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]
                free[v] = False
                changed = True
        if not changed:
            break
    return lab, moved


def rig_mismatch(J, P):
    """D17: a rig is rejected when it does not sit in the mesh: more than 10 % of its joints outside the mesh bounding box
    grown by 10 %, or the head joint below 70 % of the mesh height, or the knees above the hips."""
    lo, hi = P.min(axis=0), P.max(axis=0)
    pad = 0.1 * (hi - lo)
    out = [k for k, p in J.items() if np.any(p < lo - pad) or np.any(p > hi + pad)]
    if len(out) > 0.1 * len(J):
        return 'joints outside the mesh: %s' % sorted(out)[:6]
    H = hi[2] - lo[2]
    if 'head' in J and J['head'][2] < lo[2] + 0.7 * H:
        return 'head joint at %.2f H' % ((J['head'][2] - lo[2]) / H)
    for s in SIDES:
        if (s + '_knee') in J and (s + '_hip') in J and J[s + '_knee'][2] > J[s + '_hip'][2]:
            return 'knee above hip'
    return None


def build_skeleton(ctx, skeleton='auto'):
    """D17-D19 for the analysis context. Sets labels per vertex and region per vertex / face."""
    V, topo, H, kind = ctx['V'], ctx['topo'], ctx['H'], ctx['kind']
    used = topo.used_vertices()
    rep = dict(kind=kind)
    if kind != 'body':
        reg = {'head': 'head', 'hand': 'hands', 'part': 'part'}[kind]
        vreg = np.array([reg] * len(V), dtype=object)
        freg = np.array([reg] * topo.nF, dtype=object)
        rep.update(source='none (single-region part)', regions=[reg])
        return dict(J={}, segs=[], jf={}, vseg=np.full(len(V), -1), vreg=vreg, freg=freg, report=rep)
    J, src, used_names = {}, None, {}
    if skeleton not in ('auto', 'rig', 'estimate'):
        J = {k: np.asarray(v, float) for k, v in json.load(open(skeleton)).items()}
        src = 'given (%s)' % skeleton.replace('\\', '/').split('/')[-1]
    if not J and skeleton in ('auto', 'rig'):
        J, used_names = canon_from_rig(ctx['loaded'].get('rig'))
        need = ('l_shoulder', 'l_elbow', 'l_wrist', 'l_hip', 'l_knee', 'l_ankle', 'r_shoulder', 'r_elbow', 'r_wrist',
                'r_hip', 'r_knee', 'r_ankle', 'head')
        miss = [k for k in need if k not in J]
        bad = rig_mismatch(J, V[used]) if not miss else None
        if miss or bad:
            if miss:
                rep['rig_missing'] = miss
            if bad:
                rep['rig_rejected'] = bad
            if skeleton == 'rig':
                raise ValueError('rig unusable: %s' % (miss or bad))
            J = {}
        else:
            src = 'rig'
    if not J:
        pos = -np.ones(len(V), np.int64)
        pos[used] = np.arange(len(used))
        E = pos[topo.E] if topo.nE else np.zeros((0, 2), np.int64)
        FE = [topo.face_edges(f) for f in range(topo.nF)]
        J = estimate_joints(V[used], E, FE)
        src = 'estimate (D18)'
    J = complete(J, V[used], H)
    segs = build_segments(J)
    jf = joint_frames(segs)
    lab0 = segment_labels(V, segs, jf, H)
    lab, moved = clean_labels(lab0, topo)
    rep['labels_moved_by_connectivity'] = int(moved)
    vreg = np.array([segs[k]['region'] if k >= 0 else 'other' for k in lab], dtype=object)
    order = {r: i for i, r in enumerate(REGIONS)}
    freg = []
    for f in topo.faces:
        cnt = {}
        for v in f:
            cnt[vreg[v]] = cnt.get(vreg[v], 0) + 1
        freg.append(sorted(cnt.items(), key=lambda kv: (-kv[1], order.get(kv[0], 99)))[0][0])
    rep.update(source=src, joints={k: [round(float(x) / H, 4) for x in v] for k, v in sorted(J.items())},
               joints_unit='x H, mesh frame', rig_names=used_names,
               segments=[dict(name=s['name'], L_over_H=round(s['L'] / H, 4)) for s in segs])
    return dict(J=J, segs=segs, jf=jf, vseg=lab, vreg=vreg, freg=np.array(freg, dtype=object), report=rep)
