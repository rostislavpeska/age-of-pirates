"""Deterministic logic QA for procedurally built architecture in Blender (world space): openings, roofs, joints.

Read-only: it reports, never edits. Methods (see ../references/logic-qa.md for sources and pitfalls): Navisworks-style
hard clash with a depth tolerance, IfcOpenShell protrusion and pierce, Solibri-style free area in front of doors and
"components must touch", Jacobson 2013 generalized winding number for containment.

  door_free_area   rays through a free box in front of every door/shutter (width x .9 m x up to 1.8 m; .6 m for raised
                   gallery/balcony doors, whose deck ends at a railing): hit = blocked
  door_support     every door (any storey) needs a step, deck or floor within .40 below the sill, .45 in front
  window_clearance rays .35 m out of every window: any hit = blocked
  stair_headroom   rays up 1.85 m from three points on every tread: any hit outside the stair group = blocked
  roof_poke        a part that crosses a roof shell and has points OUTSIDE the shell, EXPOSED (ray +z misses the
                   shell) and above the shell's top surface (ray -z hits an upward face) by > .03: it shows through
                   the roof (beams through a skirt roof, a gable triangle through the slope above it)
  roof_embed       a non-roof part protruding into a closed roof shell deeper than .015 (unless a joint allows it)
  pierce           the centre axis of an elongated part A (beam, post, rail, baluster) enters and leaves closed part
                   B with both axis ends outside B, B surrounding A's section, for > .01 (IfcOpenShell 'pierce' on
                   the member axis): balusters through a rail; thin crossings escape the protrusion test
  penetration      part pairs whose protrusion depth (deepest sample point of A inside closed B, distance to B's
                   nearest surface) exceeds .01 and no joint rule allows it; touching faces are contacts
  floating         contact graph (triangle crossing, or crossing after a 4 mm normal inflation); parts not connected
                   to the datum (ground z<=0 for land roles, seabed z < -1 for water roles)
  zfight           coincident same-facing faces of two parts (triangle centroid within .5 mm of the other part,
                   normals within 2.5 deg); faces pointing down (nz < -.7) are back-facing from a fixed RTS pitch
  open_shells      meshes with an edge used by an odd number of faces: containment is undefined (listed, not tested)

Advisory inspection topics (R['inspect'], never a gate; expect some false positives):
  attachment       a deck side facing the building within .20 that does not touch it (gap) or touches < 60% of the face
  junction_proud   a horizontal member butting into a vertical post that sticks out beyond the post's faces
  frame_proud      an opening frame more than .05 proud of the wall face
  opening_band     an opening sill/head edge inside a horizontal band or rail, or leaving a < .05 sliver next to one
  near_gap         two parts that do not touch but face each other across a .006-.08 slot over an area

Containment: generalized winding number (|w| > .5) on closed meshes (pinched 4-face edges keep it exact); points
within .2 mm of a surface are contacts. Sample points: vertices, edge midpoints, triangle centroids and an 8 cm
lattice on every triangle (a post sunk into a girder with a coplanar bottom face has no vertex inside the girder).
Never use polygon vertex means: the mean of a concave n-gon can lie outside the face.
Fixed math only: no random rays, sorted outputs.

Naming contract: part names are '<Role>.<Group>....<Member>'. family() maps the second token (PREFIX) or the last
non-coordinate token's suffix (SUFFIX) to a construction family; joints are family pairs with a maximum protrusion
(JOINTS) plus per-pair declarations ({'a': fnmatch, 'b': fnmatch, 'max': depth, 'kind': text}). A joint deeper than
its maximum is reported. Projects add their own vocabulary with configure(); keep it in the project, not here.
Openings: dicts {id, role, kind door|shutter|window, origin (role-local), u (along wall), n (outward), width, z0, z1}.
"""
import fnmatch
import json
import math
import re
from collections import defaultdict

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOF_SHELL = ('HipField.LOW', 'ConnectedFields.LOW')   # name suffixes of closed roof field shells
POKE_EXEMPT = ('Mast', 'Crane')              # families that pass through roofs by design (flag masts)
CONTACT = .004
EPS_ON = 2e-4

# token suffix -> family, scanned from the last name token backwards (most specific first within a token)
SUFFIX = [('StoneBase', 'Base'), ('BaseBlock', 'Base'), ('LowerPanelRail', 'Opening'), ('LowerPanel', 'Opening'),
          ('KingPost', 'Post'), ('RailPost', 'Post'), ('Baluster', 'Post'), ('Post', 'Post'),
          ('Rail', 'Rail'), ('Panel', 'Rail'), ('Strut', 'Strut'), ('Step', 'Stair'), ('Tread', 'Stair'),
          ('EdgeBeam', 'Deck'), ('Deck', 'Deck'), ('Pile', 'Pile'), ('Bollard', 'Bollard'), ('Stile', 'Ladder'),
          ('Rung', 'Ladder'), ('Bracket', 'Bracket'), ('Rafter', 'Rafter'), ('Girder', 'Beam'), ('EaveInfill', 'Infill'),
          ('Shutter', 'Shutter'), ('Verge', 'Verge'), ('BoardClosure', 'Closure'), ('FloorBand', 'Band'),
          ('Signboard', 'Sign'), ('Thatch', 'Thatch'), ('GoodsSurface', 'Bin'), ('Bin', 'Bin'), ('Plate', 'Beam'),
          ('Beam', 'Beam'), ('Wall', 'Wall'), ('Sill', 'WallRail'), ('Lintel', 'WallRail')]
PIERCE_OK = {frozenset(k) for k in [('Opening',), ('Roof', 'Mast'), ('Mast',), ('Crane',), ('Roof',), ('Shutter',), ('Stair',),
                                     ('Base', 'Wall'),    # post base stones stand proud of a base (dado) wall
                                     ('Rafter', 'Attic'), ('Rafter', 'Infill')]}   # rafters notched over the wall-top boards
PREFIX = {'Roof': 'Roof', 'Attic': 'Attic', 'Mast': 'Mast', 'Flag': 'Mast', 'Crane': 'Crane', 'Foundation': 'Foundation',
          'Quay': 'Foundation', 'Ladder': 'Ladder'}
COORD = re.compile(r'^(?:[XYZ]-?\d+|-?\d+)$')

# family-pair joint defaults: maximum protrusion (m). Absent pair = no joint (tolerance .01).
JOINTS = {frozenset(k): v for k, v in [
    (('Roof',), .14), (('Roof', 'Attic'), .03), (('Roof', 'Infill'), .03), (('Roof', 'Rafter'), .12), (('Roof', 'Bracket'), .12),
    (('Roof', 'Mast'), 9.0), (('Mast',), 9.0), (('Mast', 'Deck'), .05), (('Crane',), .14), (('Crane', 'Deck'), .06),
    (('Bracket', 'Post'), .26), (('Bracket',), .06),   # corner arms cross in a halving joint
    (('Bracket', 'Attic'), .12), (('Bracket', 'Infill'), .12), (('Bracket', 'Rafter'), .12),
    (('Bracket', 'Wall'), .05), (('Bracket', 'WallRail'), .08),
    (('Beam', 'Wall'), .02), (('Rafter', 'Attic'), .12), (('Rafter', 'Infill'), .12), (('Rafter', 'Wall'), .10), (('Rafter', 'WallRail'), .10), (('Rafter', 'Post'), .10),
    (('Attic', 'Post'), .10), (('Attic', 'Wall'), .05), (('Attic', 'WallRail'), .05), (('Attic',), .13),
    (('Infill', 'Post'), .15), (('Infill', 'Wall'), .05), (('Infill', 'WallRail'), .08), (('Infill', 'Opening'), .05),
    (('Base', 'Wall'), .10), (('Base', 'WallRail'), .10), (('Base', 'Post'), .02),
    (('Post', 'WallRail'), .08), (('Post', 'Wall'), .05), (('Post', 'Band'), .08), (('Post', 'Beam'), .08), (('Post', 'Closure'), .05),
    (('Post', 'Rail'), .05), (('Post', 'Stair'), .05), (('Post', 'Strut'), .05), (('Post', 'Deck'), .05), (('Post', 'Opening'), .03),
    (('Rail',), .05), (('Rail', 'Strut'), .03), (('Strut', 'Deck'), .06), (('Stair',), .30),
    (('Opening',), .05), (('Opening', 'Wall'), .05), (('Opening', 'WallRail'), .08), (('Shutter',), .03), (('Shutter', 'Opening'), .05),
    (('Wall', 'WallRail'), .05), (('WallRail',), .05), (('Wall',), .02), (('Band', 'Wall'), .05), (('Band', 'WallRail'), .05),
    (('Verge', 'Closure'), .06), (('Verge',), .06), (('Roof', 'Verge'), .025),   # barge timbers seated under the roof boards
     (('Closure', 'Wall'), .05), (('Closure', 'WallRail'), .05), (('Post', 'Verge'), .0),
    (('Pile', 'Deck'), .15), (('Deck',), .02), (('Beam',), .06), (('Ladder',), .03), (('Ladder', 'Deck'), .03),
    (('Bin',), .03), (('Thatch', 'Beam'), .08), (('Thatch', 'Post'), .08), (('Attic', 'Beam'), .06), (('Sign', 'Roof'), .0)]}


ROLE_FAMILY = {}                             # role token -> family for whole roles (a props catalog)


def configure(suffix=(), prefix=None, joints=None, pierce_ok=(), role_family=None):
    """Add project vocabulary: suffix [(token_suffix, family)] (checked first), prefix {group_token: family},
    joints {(fam_a, fam_b) or (fam,): max_protrusion}, pierce_ok [(fam_a, fam_b) or (fam,)], role_family {role: family}."""
    ROLE_FAMILY.update(role_family or {})
    SUFFIX[:0] = list(suffix)
    PREFIX.update(prefix or {})
    JOINTS.update({frozenset(k): v for k, v in (joints or {}).items()})
    PIERCE_OK.update(frozenset(k) for k in pierce_ok)


def family(name):
    t = name.split('.')
    if t[0] in ROLE_FAMILY:
        return ROLE_FAMILY[t[0]]
    if len(t) > 1 and t[1] in PREFIX:
        return PREFIX[t[1]]
    if 'Opening' in t and 'Shutter' not in t:
        return 'Opening'
    for tok in reversed(t[1:]):
        if COORD.match(tok):
            continue
        for suf, fam in SUFFIX:
            if tok.endswith(suf):
                return fam
    return 'Other'


class Part:
    __slots__ = ('name', 'fam', 'V', 'T', 'E', 'bvh', 'infl', 'lo', 'hi', 'closed', 'S', 'pnz', 'pc', 'pn', 'pa')

    def __init__(self, o):
        mw = o.matrix_world; me = o.data; me.calc_loop_triangles()
        self.name = o.name; self.fam = family(o.name)
        self.V = np.array([tuple(mw @ v.co) for v in me.vertices], dtype=np.float64)
        self.T = np.array([tuple(t.vertices) for t in me.loop_triangles], dtype=np.int64).reshape(-1, 3)
        self.E = [tuple(e.vertices) for e in me.edges]
        faces = [list(p.vertices) for p in me.polygons]
        vs = [Vector(v) for v in self.V]
        self.bvh = BVHTree.FromPolygons(vs, faces)
        mw3 = mw.to_3x3()
        self.infl = BVHTree.FromPolygons([vs[i] + (mw3 @ v.normal).normalized() * CONTACT for i, v in enumerate(me.vertices)], faces)
        self.lo = self.V.min(0); self.hi = self.V.max(0)
        uses = defaultdict(int)
        for p in me.polygons:
            for ek in p.edge_keys:
                uses[ek] += 1
        self.closed = bool(uses) and all(n % 2 == 0 for n in uses.values())   # pinched (4-face) edges keep the winding number exact
        mids = [(self.V[a] + self.V[b]) / 2 for a, b in uses]
        # triangle centroids, never polygon vertex means: the mean of a concave n-gon (an attic board whose top
        # follows a sagging roof underside) can lie outside the face and fake an embedding
        tc = self.V[self.T].mean(1) if len(self.T) else np.zeros((0, 3))
        self.S = np.vstack([self.V] + ([np.array(mids)] if mids else []) + [tc] + lattice(self.V, self.T))
        normals = [(mw3 @ p.normal).normalized() for p in me.polygons]
        self.pnz = [n.z for n in normals]
        tn = np.cross(self.V[self.T[:, 1]] - self.V[self.T[:, 0]], self.V[self.T[:, 2]] - self.V[self.T[:, 0]]) if len(self.T) else np.zeros((0, 3))
        ta = np.linalg.norm(tn, axis=1) / 2
        self.pc = [Vector(c) for c in tc]; self.pn = [Vector(n_ / (2 * a_)) if a_ > 1e-12 else Vector((0, 0, 0)) for n_, a_ in zip(tn, ta)]
        self.pa = list(ta)                                      # per triangle (z-fight test); builders keep unit object scale


def lattice(V, T, step=.08, cap=400):
    """Deterministic in-plane lattice points (spacing step) inside every triangle, aligned to its longest edge."""
    out = []
    for t in T:
        a, b, c = V[t[0]], V[t[1]], V[t[2]]
        es = [(b - a, a), (c - b, b), (a - c, c)]; e, o = max(es, key=lambda x: np.linalg.norm(x[0]))
        L = np.linalg.norm(e)
        if L < 2 * step:
            continue
        nrm = np.cross(b - a, c - a); na = np.linalg.norm(nrm)
        if na < 1e-9:
            continue
        u = e / L; w = np.cross(nrm / na, u)
        P2 = np.array([[np.dot(p - o, u), np.dot(p - o, w)] for p in (a, b, c)])
        lo, hi = P2.min(0), P2.max(0)
        xs = np.arange(lo[0] + step / 2, hi[0], step); ys = np.arange(lo[1] + step / 2, hi[1], step)
        if len(xs) * len(ys) > cap:                                      # very large triangles: a capped, still regular lattice
            k = int(math.sqrt(cap)); xs = np.linspace(lo[0], hi[0], k + 2)[1:-1]; ys = np.linspace(lo[1], hi[1], k + 2)[1:-1]
        if not len(xs) or not len(ys):
            continue
        G = np.array([(x, y) for x in xs for y in ys])
        A2, B2, C2 = P2; v0 = B2 - A2; v1 = C2 - A2; v2 = G - A2
        d00 = v0 @ v0; d01 = v0 @ v1; d11 = v1 @ v1; den = d00 * d11 - d01 * d01
        if abs(den) < 1e-12:
            continue
        d20 = v2 @ v0; d21 = v2 @ v1
        bv = (d11 * d20 - d01 * d21) / den; bw = (d00 * d21 - d01 * d20) / den
        keep = (bv > 1e-3) & (bw > 1e-3) & (bv + bw < 1 - 1e-3)
        if keep.any():
            out.append(o + np.outer(G[keep, 0], u) + np.outer(G[keep, 1], w))
    return [np.vstack(out)] if out else []


def winding(P, part):
    """Generalized winding number of points P (n,3) w.r.t. the closed triangle mesh of part (Jacobson 2013)."""
    V, T = part.V, part.T
    A, B, C = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
    out = np.zeros(len(P))
    step = max(1, int(400000 // max(len(T), 1)))
    for s in range(0, len(P), step):
        p = P[s:s + step, None, :]
        a = A[None] - p; b = B[None] - p; c = C[None] - p
        la = np.linalg.norm(a, axis=2); lb = np.linalg.norm(b, axis=2); lc = np.linalg.norm(c, axis=2)
        det = np.einsum('ijk,ijk->ij', a, np.cross(b, c))
        div = la * lb * lc + np.einsum('ijk,ijk->ij', a, b) * lc + np.einsum('ijk,ijk->ij', b, c) * la + np.einsum('ijk,ijk->ij', c, a) * lb
        out[s:s + step] = np.arctan2(det, div).sum(1) / (2 * math.pi)
    return out


def protrusion(a, b, pad=1e-6):
    """Deepest sample point of part a inside closed part b: distance to b's nearest surface (0 if none)."""
    if not b.closed:
        return 0.0
    P = a.S[np.all((a.S >= b.lo - pad) & (a.S <= b.hi + pad), axis=1)]
    if not len(P):
        return 0.0
    w = winding(P, b); best = 0.0
    for p, wi in zip(P, w):
        if abs(wi) > .5:
            loc, nrm, idx, dist = b.bvh.find_nearest(Vector(p))
            if loc is not None and dist > EPS_ON:
                best = max(best, dist)
    return best


def axis_of(a):
    """Principal axis segment of an elongated part (longest PCA extent >= 3 x the second), else None."""
    C = a.V.mean(0); X = a.V - C
    w, vec = np.linalg.eigh(X.T @ X)
    ax = vec[:, 2]; pr = X @ ax; ext = sorted(np.ptp(X @ vec[:, i]) for i in range(3))
    if ext[1] < 1e-6 or ext[2] < 3 * ext[1]:
        return None
    half = [(vec[:, i], np.ptp(X @ vec[:, i]) / 2) for i in (0, 1)]       # cross-section axes and half extents
    return C + ax * (pr.min() + .002), C + ax * (pr.max() - .002), half


def pierce(a, b):
    """Elongated part a whose centre axis enters and leaves closed part b, both axis ends outside b (IfcOpenShell
    'pierce' on the member axis): a baluster through a rail, a post through a verge. Boards seated lengthwise in a
    wall top have no axis through the wall, so they stay joints for the protrusion test."""
    if not b.closed:
        return 0.0
    seg = axis_of(a)
    if seg is None:
        return 0.0
    p0, p1, half = seg
    if np.any(np.minimum(p0, p1) > b.hi) or np.any(np.maximum(p0, p1) < b.lo):
        return 0.0
    if np.any(np.abs(winding(np.array([p0, p1]), b)) > .5):
        return 0.0                                                     # an axis end inside b: seated or tenoned, not through
    p = Vector(p0); d = Vector(p1) - p; L = d.length; d.normalize(); best = 0.0; t = 0.0
    while t < L:
        h1 = b.bvh.ray_cast(p + d * t, d, L - t)
        if h1[0] is None:
            break
        t1 = t + h1[3]; h2 = b.bvh.ray_cast(h1[0] + d * 1e-4, d, L - t1 - 1e-4)
        if h2[0] is None:
            break
        length = h2[3] + 1e-4; mid = h1[0] + d * (length / 2)
        ring = np.array([np.array(mid) + s_ * v_ * max(h_ - .002, 0) for v_, h_ in half for s_ in (-1, 1)])
        surrounded = np.sum(np.abs(winding(ring, b)) > .5) >= 3        # b surrounds a's section: a passes THROUGH b
        if surrounded and b.bvh.find_nearest(mid)[3] > EPS_ON and abs(winding(np.array([tuple(mid)]), b)[0]) > .5:
            best = max(best, length)
        t = t1 + length + 1e-4
    return best


# ------------------------------------------------------------------ advisory inspection topics (not a gate)
INSPECT = {'attach_families': {'Deck'}, 'attach_reach': .20, 'attach_cover': .60, 'attach_contact': .006,
           'proud_tol': .005, 'frame_proud': .05, 'band_regions': {'wall_bottom', 'storey_band', 'upper_frieze'},
           'band_families': {'WallRail', 'Band'}, 'band_margin': .005, 'sliver': .05,
           'gap_lo': .01, 'gap_hi': .08, 'gap_min_samples': 6, 'cap': 80,
           'junction_posts': {'Post'}, 'junction_members': {'WallRail', 'Band', 'Beam', 'Rail', 'Deck', 'Strut'},
           # family pairs whose near-gaps are construction noise (panels meet through posts, roof assemblies, bracket arms
           # passing a wall, railing struts above a panel)
           'gap_skip': {frozenset(k) for k in [('Wall',), ('Roof',), ('Bracket', 'Wall'), ('Rail', 'Strut')]}}


def _assembly(name):
    """Opening assembly prefix ('...Opening.N') or None."""
    t = name.split('.')
    return '.'.join(t[:t.index('Opening') + 2]) if 'Opening' in t and t.index('Opening') + 1 < len(t) else None


def gap_worth(a, b):
    """near_gap noise filter: internals of one opening, opening internals against the wall around them, and shutter boards
    (gapped by design) are not inspection topics."""
    fa, fb = family(a), family(b); ka, kb = _assembly(a), _assembly(b)
    if ka and ka == kb:
        return False
    frame = lambda n_: any(t in n_ for t in ('.Jamb.', '.Sill', '.Lintel'))
    if (ka and not frame(a) and fb in ('Wall', 'WallRail')) or (kb and not frame(b) and fa in ('Wall', 'WallRail')):
        return False
    return not (fa == fb == 'Shutter') and frozenset({fa, fb}) not in INSPECT['gap_skip']


def _face_points(o, p, k=4):
    """Deterministic points on polygon p of object o (world): a k x k bilinear grid on quads, triangle-fan centroids
    and edge midpoints otherwise."""
    mw = o.matrix_world; vs = [mw @ o.data.vertices[i].co for i in p.vertices]
    if len(vs) == 4:
        return [vs[0].lerp(vs[1], (i + .5) / k).lerp(vs[3].lerp(vs[2], (i + .5) / k), (j + .5) / k) for i in range(k) for j in range(k)]
    c = sum(vs, Vector()) / len(vs)
    return [c] + [(c + a + b) / 3 for a, b in zip(vs, vs[1:] + vs[:1])]


def inspect(role, parts, names, scene_bvh, owner, ops, M, adj):
    """Topics to inspect (owner 'maybe some false positives, but at least topics to inspect'): weak attachment of decks,
    members proud of the posts they butt into, protruding opening frames, opening edges inside or near bands, and
    near-miss slots between parts. Advisory: reported, never a build failure."""
    I = {'attachment': [], 'junction_proud': [], 'frame_proud': [], 'opening_band': [], 'near_gap': []}
    up = Vector((0, 0, 1))

    def ray_owner(o_, d_, dist, me):
        loc, nrm, idx, dd = scene_bvh.ray_cast(o_, d_, dist)
        return (owner[idx], dd) if loc is not None and owner[idx] != me else (None, None)
    # attachment: a deck side facing the building within reach must touch it over most of the face. Rays start 1 mm
    # behind the face and test each nearby part's own BVH, so a flush contact measures 0 (a scene ray from the face
    # starts inside a coplanar wall and misses it).
    reach = INSPECT['attach_reach']
    def first_hit(o_, d_, dist, cands):
        best = (None, None)
        for nm_ in cands:
            loc, nrm, idx, dd = parts[nm_].bvh.ray_cast(o_ - d_ * 1e-3, d_, dist + 1e-3)
            if loc is not None and (best[1] is None or dd - 1e-3 < best[1]):
                best = (nm_, max(0.0, dd - 1e-3))
        return best
    for nm in names:
        if parts[nm].fam not in INSPECT['attach_families']:
            continue
        D = parts[nm]
        cands = [x for x in names if x != nm and not (np.any(parts[x].lo > D.hi + reach) or np.any(parts[x].hi < D.lo - reach))]
        o = bpy.data.objects[nm]; mw3 = o.matrix_world.to_3x3()
        for p in o.data.polygons:
            n = (mw3 @ p.normal).normalized()
            if abs(n.z) > .3 or p.area < .01:
                continue
            c = o.matrix_world @ p.center
            hit, d = first_hit(c, n, reach, cands)
            if hit is None or parts[hit].fam in INSPECT['attach_families']:
                continue
            pts = _face_points(o, p)
            cov = sum(1 for q in pts if first_hit(q, n, INSPECT['attach_contact'], cands)[0] is not None) / len(pts)
            if d > INSPECT['attach_contact'] or cov < INSPECT['attach_cover']:
                I['attachment'].append({'part': nm, 'facing': hit, 'gap': round(d, 3), 'coverage': round(cov, 2),
                                        'normal': [round(x, 2) for x in n]})
    # junction: a horizontal member butting into a vertical post must stay within the post's faces
    axes = {}
    for a in names:
        for b in adj[a]:
            A, B = parts[a], parts[b]
            for X in (A, B):
                if X.name not in axes:
                    axes[X.name] = axis_of(X)
            sa, sb = axes[a], axes[b]
            if sa is None or sb is None:
                continue
            ax = Vector(sa[1]) - Vector(sa[0]); bx = Vector(sb[1]) - Vector(sb[0])
            if ax.length < 1e-6 or bx.length < 1e-6 or abs(ax.normalized().z) > .3 or abs(bx.normalized().z) < .9:
                continue
            if B.fam not in INSPECT['junction_posts'] or A.fam not in INSPECT['junction_members']:
                continue
            bc = Vector(((B.lo[0] + B.hi[0]) / 2, (B.lo[1] + B.hi[1]) / 2, 0)); bh = max(B.hi[0] - B.lo[0], B.hi[1] - B.lo[1]) / 2
            ends = [Vector(e) for e in sa[:2]]
            if not any((Vector((e.x, e.y, 0)) - bc).length <= bh + .05 and B.lo[2] - .01 <= e.z <= B.hi[2] + .01 for e in ends):
                continue
            v = Vector((-ax.y, ax.x, 0)).normalized()
            pa = A.V @ np.array(v); pb = B.V @ np.array(v)
            proud = max(pa.max() - pb.max(), pb.min() - pa.min())
            if proud > INSPECT['proud_tol']:
                I['junction_proud'].append({'member': a, 'post': b, 'proud': round(float(proud), 3)})
    # openings: frame projection, edges inside / next to horizontal bands and rails
    for op in ops:
        org = M @ Vector(op['origin']); u = Vector(op['u']).normalized(); n = Vector(op['n']).normalized()
        frame = [nm for nm in names if nm.startswith(op['id'] + '.') and any(t in nm for t in ('.Jamb.', '.Sill', '.Lintel'))]
        if frame:
            pr = max(float(((parts[nm].V - np.array(org)) @ np.array(n)).max()) for nm in frame)
            if pr > INSPECT['frame_proud']:
                I['frame_proud'].append({'opening': op['id'], 'proud': round(pr, 3)})
        z0w, z1w = M.translation.z + op['z0'], M.translation.z + op['z1']; hw = op['width'] / 2
        for nm in names:
            o = bpy.data.objects[nm]
            if nm.startswith(op['id'] + '.') or not (o.get('pc_region') in INSPECT['band_regions'] or parts[nm].fam in INSPECT['band_families']):
                continue
            P = parts[nm]; rel = P.V - np.array(org)
            du = rel @ np.array(u); dn = rel @ np.array(n); pz0, pz1 = P.lo[2], P.hi[2]
            if dn.min() < -.30 or dn.max() > .20 or du.max() < -hw - .15 or du.min() > hw + .15 or pz1 - pz0 > .5:
                continue
            for edge, ze in (('sill', z0w), ('head', z1w)):
                m_ = INSPECT['band_margin']
                if pz0 + m_ < ze < pz1 - m_:
                    I['opening_band'].append({'opening': op['id'], 'edge': edge, 'kind': 'inside', 'part': nm, 'band': [round(pz0, 3), round(pz1, 3)]})
                else:
                    gap_ = min(abs(ze - pz0), abs(ze - pz1))
                    if m_ < gap_ < INSPECT['sliver']:
                        I['opening_band'].append({'opening': op['id'], 'edge': edge, 'kind': 'sliver', 'gap': round(gap_, 3), 'part': nm})
    seen = set(); uniq = []
    for x in I['opening_band']:
        k = (x['opening'], x['edge'], x['kind'])
        if k not in seen:
            seen.add(k); uniq.append(x)
    I['opening_band'] = uniq
    return I


def near_gap(A, B):
    """Smallest positive gap between two non-touching parts and how many sample points face it (a visible slot)."""
    small, big = (A, B) if len(A.S) <= len(B.S) else (B, A)
    lim = INSPECT['gap_hi']
    P = small.S[np.all((small.S >= big.lo - lim) & (small.S <= big.hi + lim), axis=1)]
    ds = [big.bvh.find_nearest(Vector(p), lim)[3] for p in P]
    ds = [d for d in ds if d is not None]
    close = [d for d in ds if d < lim]
    if len(close) >= INSPECT['gap_min_samples'] and min(close) > INSPECT['gap_lo']:
        return round(min(close), 3), len(close)
    return None



def joint_limit(a, b, joints):
    for j in joints:
        if (fnmatch.fnmatchcase(a, j['a']) and fnmatch.fnmatchcase(b, j['b'])) or (fnmatch.fnmatchcase(b, j['a']) and fnmatch.fnmatchcase(a, j['b'])):
            return j['max'], j.get('kind', 'declared')
    fa, fb = family(a), family(b)
    lim = JOINTS.get(frozenset({fa, fb}))
    return (lim, 'family default') if lim is not None else (.01, 'no joint')


def run(roles, openings, roots, land_roles=('Market',), out=None, extra_openings=(), joints=(), only=None):
    res = {'version': 2, 'tolerances': {'roof_embed': .015, 'roof_poke': .03, 'contact': CONTACT, 'penetration_default': .01, 'door_box': [.9, 1.8],
                                        'window': .35, 'headroom': 1.85, 'zfight_plane': 5e-4},
           'joint_defaults': {' x '.join(sorted(k)) if len(k) > 1 else next(iter(k)) + ' x ' + next(iter(k)): v for k, v in sorted(JOINTS.items(), key=lambda kv: sorted(kv[0]))},
           'roles': {}}
    for role, coll in roles.items():
        objs = sorted([o for o in coll.objects if o.type == 'MESH'], key=lambda o: o.name)
        parts = {o.name: Part(o) for o in objs}
        names = list(parts)
        allv = []; allf = []; owner = []
        for nm in names:
            off = len(allv); allv += [Vector(v) for v in parts[nm].V]
            for p in bpy.data.objects[nm].data.polygons:
                allf.append([off + i for i in p.vertices]); owner.append(nm)
        scene_bvh = BVHTree.FromPolygons(allv, allf)
        checks = ('door_free_area', 'door_support', 'window_clearance', 'stair_headroom', 'roof_poke', 'roof_embed', 'pierce', 'floating', 'zfight')
        R = {k: [] for k in checks}; R['penetration'] = {}
        R['open_shells'] = sorted(nm for nm in names if not parts[nm].closed)
        M = roots[role].matrix_world

        def ray(o_, d_, dist, skip):
            o_ = Vector(o_); travelled = 0.0
            while travelled < dist:
                loc, nrm, idx, dd = scene_bvh.ray_cast(o_, d_, dist - travelled)
                if loc is None:
                    return None
                if not skip(owner[idx]):
                    return owner[idx], round(travelled + dd, 3)
                o_ = loc + d_ * 1e-4; travelled += dd + 1e-4
            return None
        # ---------------------------------------------------------------- openings
        for op in [x for x in openings if x['role'] == role] + [x for x in extra_openings if x['role'] == role]:
            org = M @ Vector(op['origin']); u = Vector(op['u']).normalized(); n = Vector(op['n']).normalized(); own = op['id']
            skip = lambda nm, own=own: nm.startswith(own)
            if op['kind'] == 'door' or (op['kind'] == 'shutter' and op['z0'] < 1.6):
                blocked = []
                depth = .9 if op['z0'] < 1.6 else .6
                for fx in (-.35, 0, .35):
                    for z in (op['z0'] + .25, op['z0'] + 1.0, min(op['z1'] - .15, op['z0'] + 1.8)):
                        h_ = ray(org + u * fx * op['width'] + n * .13 + Vector((0, 0, z)), n, depth, skip)
                        if h_:
                            blocked.append(h_)
                if blocked:
                    R['door_free_area'].append({'opening': op['id'], 'kind': op['kind'], 'depth': depth, 'blocked_by': sorted(set(b[0] for b in blocked)), 'nearest': min(b[1] for b in blocked)})
                if op['kind'] == 'door':
                    s = org + n * .45 + Vector((0, 0, op['z0'] + .10))
                    h_ = ray(s, Vector((0, 0, -1)), .40, skip)
                    if h_ is None and not (role in land_roles and op['z0'] + M.translation.z <= .40):
                        R['door_support'].append({'opening': op['id'], 'sill_z': round(op['z0'], 3), 'note': 'no step, deck or floor within .40 below the sill, .45 in front'})
            elif op['kind'] == 'window':
                blocked = []
                for fx in (-.3, 0, .3):
                    for fz in (.3, .5, .7):
                        h_ = ray(org + u * fx * op['width'] + n * .13 + Vector((0, 0, op['z0'] + (op['z1'] - op['z0']) * fz)), n, .35, skip)
                        if h_:
                            blocked.append(h_)
                if blocked:
                    R['window_clearance'].append({'opening': op['id'], 'blocked_by': sorted(set(b[0] for b in blocked)), 'nearest': min(b[1] for b in blocked)})
        # ---------------------------------------------------------------- stair headroom
        for nm in names:
            if parts[nm].fam != 'Stair' or not any(t in nm for t in ('.Step.', '.Tread.')):
                continue
            p = parts[nm]; group = nm.rsplit('.', 2)[0] + '.'
            top = p.hi[2]; cx, cy = (p.lo[:2] + p.hi[:2]) / 2; ex, ey = (p.hi[:2] - p.lo[:2]) / 2
            hits = []
            for fx, fy in ((0, 0), (-.6, 0), (.6, 0)) if ex >= ey else ((0, 0), (0, -.6), (0, .6)):
                h_ = ray((cx + fx * ex, cy + fy * ey, top + .02), Vector((0, 0, 1)), 1.85, lambda o_, g=group: o_.startswith(g))
                if h_:
                    hits.append(h_)
            if hits:
                R['stair_headroom'].append({'tread': nm, 'blocked_by': sorted(set(h[0] for h in hits)), 'clear': min(h[1] for h in hits)})
        # ---------------------------------------------------------------- roofs: poke-through and embedding
        shells = [nm for nm in names if nm.endswith(ROOF_SHELL)]
        for sh in shells:
            S = parts[sh]
            for nm in names:
                if nm == sh:
                    continue
                P = parts[nm]
                if np.any(P.lo > S.hi + CONTACT) or np.any(P.hi < S.lo - CONTACT):
                    continue
                pairs = S.bvh.overlap(P.bvh)
                crossing_top = [i_s for i_s, i_p in pairs if S.pnz[i_s] > .3]
                is_roofpart = P.fam == 'Roof' and '.Hapgak.' not in nm
                if crossing_top and P.fam not in POKE_EXEMPT and not is_roofpart:
                    worst = 0.0
                    inside = winding(P.S, S) if S.closed else np.zeros(len(P.S))
                    for p, wi in zip(P.S, inside):
                        if abs(wi) > .5:
                            continue
                        v = Vector(p)
                        up = S.bvh.ray_cast(v + Vector((0, 0, 1e-4)), Vector((0, 0, 1)), 40.0)
                        if up[0] is not None:
                            continue                                  # covered by the roof: not visible
                        dn = S.bvh.ray_cast(v, Vector((0, 0, -1)), 40.0)
                        if dn[0] is not None and dn[1].z > .3 and dn[3] > .03:
                            worst = max(worst, dn[3])
                    if worst:
                        R['roof_poke'].append({'part': nm, 'roof': sh, 'poke_height': round(worst, 3), 'crossing_faces': len(crossing_top)})
                if not is_roofpart and P.fam not in POKE_EXEMPT and pairs:
                    d_ = protrusion(P, S)
                    lim, kind = joint_limit(nm, sh, joints)
                    lim = max(lim, .015)
                    if d_ > lim:
                        R['roof_embed'].append({'part': nm, 'roof': sh, 'depth': round(d_, 3), 'allowed': lim, 'rule': kind})
        # ---------------------------------------------------------------- contacts, penetration, z-fighting
        adj = defaultdict(set); pen = []; joint_hits = defaultdict(int); gaps = []
        order = sorted(names, key=lambda nm: parts[nm].lo[0])
        for i, a in enumerate(order):
            A = parts[a]
            for b in order[i + 1:]:
                Bp = parts[b]
                if Bp.lo[0] > A.hi[0] + INSPECT['gap_hi']:
                    break
                if np.any(A.lo > Bp.hi + INSPECT['gap_hi']) or np.any(Bp.lo > A.hi + INSPECT['gap_hi']):
                    continue
                if np.any(A.lo > Bp.hi + CONTACT) or np.any(Bp.lo > A.hi + CONTACT):
                    g_ = near_gap(A, Bp) if gap_worth(a, b) else None
                    if g_:
                        gaps.append({'a': a, 'b': b, 'gap': g_[0], 'samples': g_[1]})
                    continue
                crossing = bool(A.bvh.overlap(Bp.bvh))
                touching = crossing or bool(A.infl.overlap(Bp.bvh)) or bool(A.bvh.overlap(Bp.infl))
                if not touching:
                    small, big = (A, Bp) if np.prod(A.hi - A.lo + 1e-9) <= np.prod(Bp.hi - Bp.lo + 1e-9) else (Bp, A)
                    if big.closed and np.all(small.lo >= big.lo) and np.all(small.hi <= big.hi) and abs(winding(small.V[:1], big)[0]) > .5:
                        crossing = touching = True                    # fully contained: overlap() cannot see it
                if not touching:
                    g_ = near_gap(A, Bp) if gap_worth(a, b) else None
                    if g_:
                        gaps.append({'a': a, 'b': b, 'gap': g_[0], 'samples': g_[1]})
                    continue
                adj[a].add(b); adj[b].add(a)
                if crossing and not (only and not any(fnmatch.fnmatchcase(x, only) for x in (a, b))):
                    if frozenset({A.fam, Bp.fam}) not in PIERCE_OK:
                        for x_, y_ in ((A, Bp), (Bp, A)):
                            pl = pierce(x_, y_)
                            if pl > .01:
                                R['pierce'].append({'part': x_.name, 'through': y_.name, 'length': round(pl, 3)})
                    depth = max(protrusion(A, Bp), protrusion(Bp, A))
                    if depth > .01:
                        lim, kind = joint_limit(a, b, joints)
                        if depth > lim:
                            pen.append((a, b, round(depth, 3), lim, kind))
                        else:
                            joint_hits[kind] += 1
                # z-fighting: coincident same-facing faces
                small, big = (A, Bp) if len(A.pc) <= len(Bp.pc) else (Bp, A)
                zf = 0
                for c, nrm, area in zip(small.pc, small.pn, small.pa):
                    if area < 1e-4 or nrm.z < -.7:
                        continue                                      # tiny, or facing down (never seen from the RTS camera)
                    loc, n2, idx, dist = big.bvh.find_nearest(Vector(c))
                    if loc is not None and dist < 5e-4 and nrm.dot(n2) > .999:
                        zf += 1
                if zf:
                    R['zfight'].append({'a': small.name, 'b': big.name, 'faces': zf})
        datum = [nm for nm in names if (parts[nm].lo[2] <= .005 if role in land_roles else parts[nm].lo[2] < -1.0)]
        seen = set(datum); stack = list(datum)
        while stack:
            x = stack.pop()
            for y in adj[x]:
                if y not in seen:
                    seen.add(y); stack.append(y)
        R['floating'] = sorted(nm for nm in names if nm not in seen)
        fam = defaultdict(int)
        for a, b, d_, lim, kind in pen:
            fam[' x '.join(sorted((family(a), family(b))))] += 1
        R['penetration'] = {'pairs': len(pen), 'by_family': dict(sorted(fam.items(), key=lambda kv: (-kv[1], kv[0]))),
                            'joints_within_limit': dict(joint_hits),
                            'worst': [list(t) for t in sorted(pen, key=lambda t: (-t[2], t[0], t[1]))[:60]]}
        R['zfight'] = sorted(R['zfight'], key=lambda z: (-z['faces'], z['a']))
        R['pierce'] = sorted(R['pierce'], key=lambda z: (-z['length'], z['part']))
        R['summary'] = {k: (len(v) if isinstance(v, list) else v['pairs']) for k, v in R.items() if k != 'open_shells'}
        R['summary']['open_shells'] = len(R['open_shells'])
        I = inspect(role, parts, names, scene_bvh, owner, [x for x in openings if x['role'] == role] + [x for x in extra_openings if x['role'] == role], M, adj)
        I['near_gap'] = sorted(gaps, key=lambda g: (-g['samples'], g['gap'], g['a']))   # largest facing area first
        R['inspect'] = {k: v[:INSPECT['cap']] for k, v in I.items()}
        R['inspect_summary'] = {k: len(v) for k, v in I.items()}
        res['roles'][role] = R
    if out:
        with open(out, 'w', encoding='utf-8') as f:
            json.dump(res, f, indent=1)
    return res


def run_saved(blend_report, out=None, joints=()):
    """Re-run on a saved geometry file (opened in Blender): LOW collections '<Role> | LOW geometry', roots
    '<Role>.NativeOrigin', openings from GEOMETRY_REPORT.json."""
    rep = json.load(open(blend_report, encoding='utf-8'))
    roles = {c.name.split(' | ')[0]: c for c in bpy.data.collections if c.name.endswith(' | LOW geometry')}
    roots = {r: bpy.data.objects[r + '.NativeOrigin'] for r in roles}
    return run(roles, rep.get('openings', []), roots, out=out, joints=joints)
