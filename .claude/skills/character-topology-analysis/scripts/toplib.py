"""character-topology-analysis: the one metric library (pure Python + numpy).

Every metric here has ONE written definition in ../references/definitions.md (section numbers in the docstrings) and
ONE implementation: this module and its companions tl_skeleton.py (joints, segments, regions) and tl_features.py
(rings, joint rings, shoulder/hip flow, eye/mouth rings, plane map, density). Loading lives in tl_io.py; Blender is
used only through tl_blender.py (background, for .blend cages, foreign formats and Tris-to-Quads).

Library use:
    from toplib import analyse
    rep = analyse(loaded, kind='body')        # loaded = tl_io.load(...)

Command line (writes a JSON report):
    python -I toplib.py measure <mesh> [--kind body|head|hand|part] [--select REGEX] [--exclude REGEX] [--group G]
                             [--up y|z] [--rot RX,RY,RZ] [--skeleton auto|rig|estimate|FILE.json]
                             [--joints-from-groups PREFIX] [--face-source native|ogt|t2q] [--declared-caps N]
                             [--blender EXE] --out report.json
"""
import json
import math
import os
import sys

import numpy as np

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:          # python -I (isolated mode) does not put the script folder on sys.path
    sys.path.insert(0, _HERE)

LIB_VERSION = '1.1.0'

# ---------------------------------------------------------------------------------------------------------------- constants
# Every constant below is stated in definitions.md; change both together.
WELD_REL = 1e-6            # D2: weld distance = WELD_REL x bounding-box diagonal of the referenced vertices of the part
WELD_SENSITIVITY = (0.0, 1e-6, 1e-5, 1e-4)
ZERO_AREA_REL = 1e-10      # D9: a face is zero-area below ZERO_AREA_REL x H^2
SYM_REL = 1e-4             # D16: mirror partner within SYM_REL x H; centre vertices |dx| < SYM_REL x H
SYM_CENTRE_EXACT = 1e-5    # D16: a centre vertex is exact when |dx| <= 1e-5 H
EYEBALL_RMS_REL = 0.05     # D4: sphere-fit RMS residual <= 5 % of the radius
EYEBALL_SIZE_REL = 0.10    # D4: sphere radius <= 10 % of the unit height
CAP_MIN_SIDES = 5          # D4: a cap closes a ring of >= 5 edges
LOOP_MIN_EDGES = 1


# ---------------------------------------------------------------------------------------------------------------- helpers
def r(x, k=4):
    """round for reports (None-safe, numpy-safe)."""
    if x is None:
        return None
    if isinstance(x, (list, tuple)):
        return [r(v, k) for v in x]
    if isinstance(x, np.ndarray):
        return [r(v, k) for v in x.tolist()]
    if isinstance(x, (np.integer,)):
        return int(x)
    xf = float(x)
    if math.isnan(xf) or math.isinf(xf):
        return None
    return round(xf, k)


def pct(a, qs=(0, 1, 10, 50, 90, 99, 100)):
    a = np.asarray(a, dtype=float)
    if a.size == 0:
        return None
    return {('p%d' % q if q < 100 else 'max'): r(np.percentile(a, q), 4) for q in qs}


class UnionFind:
    def __init__(self, n):
        self.p = np.arange(n)

    def find(self, a):
        p = self.p
        root = a
        while p[root] != root:
            root = p[root]
        while p[a] != root:
            p[a], a = root, p[a]
        return root

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            if ra < rb:
                self.p[rb] = ra
            else:
                self.p[ra] = rb

    def roots(self):
        return np.array([self.find(i) for i in range(len(self.p))])


def grid_pairs(P, tol):
    """all index pairs (i < j) with |P_i - P_j| <= tol (grid hash; tol > 0)."""
    cells = {}
    C = np.floor(P / tol).astype(np.int64)
    out = []
    tol2 = tol * tol
    for i in range(len(P)):
        cx, cy, cz = C[i]
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for j in cells.get((cx + dx, cy + dy, cz + dz), ()):
                        d = P[i] - P[j]
                        if d @ d <= tol2:
                            out.append((j, i))
        cells.setdefault((cx, cy, cz), []).append(i)
    return out


def nearest_within(P, Q, tol):
    """for every point of Q: index of the nearest point of P within tol, else -1 (grid hash)."""
    cells = {}
    C = np.floor(P / tol).astype(np.int64)
    for i in range(len(P)):
        cells.setdefault(tuple(C[i]), []).append(i)
    out = np.full(len(Q), -1, dtype=np.int64)
    CQ = np.floor(Q / tol).astype(np.int64)
    tol2 = tol * tol
    for k in range(len(Q)):
        cx, cy, cz = CQ[k]
        best, bd = -1, tol2
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for j in cells.get((cx + dx, cy + dy, cz + dz), ()):
                        d = P[j] - Q[k]
                        dd = d @ d
                        if dd <= bd:
                            if dd < bd or best < 0 or j < best:
                                best, bd = j, dd
        out[k] = best
    return out


def bbox_diag(V):
    if len(V) == 0:
        return 0.0
    return float(np.linalg.norm(V.max(axis=0) - V.min(axis=0)))


# ---------------------------------------------------------------------------------------------------------------- D2 weld
def weld_map(V, tol):
    """D2: union-find of points within tol (transitive). Returns (raw->welded id, welded positions). The welded position
    is the lexicographically smallest member position, so the result does not depend on the input order."""
    n = len(V)
    if n == 0:
        return np.zeros(0, np.int64), np.zeros((0, 3))
    uf = UnionFind(n)
    if tol <= 0:
        _, inv = np.unique(V, axis=0, return_inverse=True)
        inv = inv.reshape(-1)
        first = {}
        for i, k in enumerate(inv.tolist()):
            if k in first:
                uf.union(first[k], i)
            else:
                first[k] = i
    else:
        for i, j in grid_pairs(V, tol):
            uf.union(i, j)
    roots = uf.roots()
    groups = {}
    for i, rt in enumerate(roots.tolist()):
        groups.setdefault(rt, []).append(i)
    reps = []
    for rt, mem in groups.items():
        sub = V[mem]
        k = np.lexsort((sub[:, 2], sub[:, 1], sub[:, 0]))[0]
        reps.append((tuple(sub[k]), mem))
    reps.sort(key=lambda t: t[0])
    wid = np.empty(n, np.int64)
    WP = np.zeros((len(reps), 3))
    for g, (pos, mem) in enumerate(reps):
        wid[mem] = g
        WP[g] = pos
    return wid, WP


def clean_faces(faces):
    """D3: drop consecutive repeats; a face with < 3 distinct vertices is degenerate, a face that still repeats a vertex
    is invalid, a face whose vertex set equals an earlier face's is a duplicate. Returns (kept faces, counts)."""
    kept, seen = [], {}
    cnt = dict(degenerate=0, invalid=0, duplicate=0, duplicate_reversed=0)
    for f in faces:
        g = []
        for v in f:
            if not g or g[-1] != v:
                g.append(v)
        while len(g) > 1 and g[0] == g[-1]:
            g.pop()
        if len(set(g)) < 3:
            cnt['degenerate'] += 1
            continue
        if len(set(g)) != len(g):
            cnt['invalid'] += 1
            continue
        key = frozenset(g)
        if key in seen:
            cnt['duplicate'] += 1
            prev = seen[key]
            if canon_rot(prev) != canon_rot(g):
                cnt['duplicate_reversed'] += 1
            continue
        seen[key] = tuple(g)
        kept.append(tuple(g))
    return kept, cnt


def canon_rot(f):
    """rotate a face so it starts at its smallest vertex id (winding kept)."""
    k = int(np.argmin(f))
    return tuple(f[k:]) + tuple(f[:k])


def canonicalize(V, faces):
    """D1: vertices sorted by (x, y, z), faces rotated to their smallest id and sorted. Only referenced vertices kept.
    Everything downstream runs on this order, so results do not depend on the input vertex or face order."""
    used = sorted({v for f in faces for v in f})
    U = V[used]
    order = np.lexsort((U[:, 2], U[:, 1], U[:, 0]))
    rank = np.empty(len(used), np.int64)
    rank[order] = np.arange(len(used))
    remap = {old: int(rank[k]) for k, old in enumerate(used)}
    NV = U[order]
    NF = sorted(canon_rot([remap[v] for v in f]) for f in faces)
    return NV, NF, remap


def _weld_topology(V, faces, tol):
    """weld at tol, clean, canonicalise; returns (V, faces, clean counts, raw->final map)."""
    wid, WP = weld_map(V, tol)
    wf = [[int(wid[v]) for v in f] for f in faces]
    kept, cnt = clean_faces(wf)
    NV, NF, remap = canonicalize(WP, kept)
    raw2 = np.array([remap.get(int(w), -1) for w in wid], dtype=np.int64)
    return NV, NF, cnt, raw2, len(WP)


def weld_and_clean(V, faces, rel=WELD_REL):
    """D2 + D3 + D1 in order: weld at rel x diagonal of the REFERENCED vertices, clean, canonicalise.
    Fusion check (D2): non-manifold edges and bow-ties on the raw ids, after an exact-position weld and after the rule
    weld. fused_by_tolerance = the rule weld made more of either than the exact weld (stacked cards / near-coincident
    shells fused); the rule weld is then reported, never silently trusted. Returns (V, faces, report, raw->final map)."""
    V = np.asarray(V, dtype=float)
    used = sorted({int(v) for f in faces for v in f})
    pos = {v: k for k, v in enumerate(used)}
    U = V[used] if used else np.zeros((0, 3))
    uf = [[pos[int(v)] for v in f] for f in faces]
    D = bbox_diag(U)
    tol = rel * D
    rep = dict(rule='merge referenced vertices within %.0e x their bounding-box diagonal (D2)' % rel, diag=r(D, 6),
               tol=tol, verts_file=int(len(V)), verts_referenced=int(len(U)), sensitivity={})
    for s in WELD_SENSITIVITY:
        rep['sensitivity'][('%g' % s)] = int(len(weld_map(U, s * D)[1]))
    raw_t = Topology(len(U), clean_faces(uf)[0])
    EV, EF, ecnt, _, _ = _weld_topology(U, uf, 0.0)
    exact_t = Topology(len(EV), EF)
    NV, NF, cnt, raw2u, nweld = _weld_topology(U, uf, tol)
    post = Topology(len(NV), NF)
    rep.update(verts_welded=int(nweld), verts_final=int(len(NV)), faces_raw=len(faces), faces_final=len(NF), **cnt)
    fc = dict(nonmanifold_edges=dict(raw=int(raw_t.n_nonmanifold), exact=int(exact_t.n_nonmanifold), rule=int(post.n_nonmanifold)),
              bowtie_verts=dict(raw=len(raw_t.bowtie_vertices()), exact=len(exact_t.bowtie_vertices()),
                                rule=len(post.bowtie_vertices())),
              duplicate_faces=dict(exact=int(ecnt['duplicate']), rule=int(cnt['duplicate'])),
              degenerate_faces=dict(exact=int(ecnt['degenerate']), rule=int(cnt['degenerate'])))
    rep['fusion_check'] = fc
    rep['fused_by_tolerance'] = bool(any(fc[k]['rule'] > fc[k]['exact'] for k in fc))
    raw2final = np.full(len(V), -1, dtype=np.int64)
    if used:
        raw2final[np.array(used)] = raw2u
    return NV, NF, rep, raw2final


# ---------------------------------------------------------------------------------------------------------------- topology
class Topology:
    """Half-edge style adjacency over a polygon list (D5-D7). Vertices without faces are allowed and ignored."""

    def __init__(self, nV, faces):
        self.nV = int(nV)
        self.faces = [tuple(f) for f in faces]
        self.nF = len(self.faces)
        self.sides = np.array([len(f) for f in self.faces], dtype=np.int64)
        hv0, hv1, hf, hk = [], [], [], []
        for fi, f in enumerate(self.faces):
            k = len(f)
            for j in range(k):
                hv0.append(f[j])
                hv1.append(f[(j + 1) % k])
                hf.append(fi)
                hk.append(j)
        self.hv0 = np.array(hv0, dtype=np.int64)
        self.hv1 = np.array(hv1, dtype=np.int64)
        self.hf = np.array(hf, dtype=np.int64)
        self.hk = np.array(hk, dtype=np.int64)
        if len(self.hv0):
            lo = np.minimum(self.hv0, self.hv1)
            hi = np.maximum(self.hv0, self.hv1)
            key = lo * max(self.nV, 1) + hi
            ukey, self.he_edge, cnt = np.unique(key, return_inverse=True, return_counts=True)
            self.he_edge = self.he_edge.reshape(-1)
            self.E = np.stack([ukey // max(self.nV, 1), ukey % max(self.nV, 1)], axis=1).astype(np.int64)
            self.edge_nf = cnt.astype(np.int64)
        else:
            self.he_edge = np.zeros(0, np.int64)
            self.E = np.zeros((0, 2), np.int64)
            self.edge_nf = np.zeros(0, np.int64)
        self.nE = len(self.E)
        # edge -> half-edges (CSR)
        order = np.argsort(self.he_edge, kind='stable')
        self.eh = order
        self.eh_off = np.concatenate([[0], np.cumsum(self.edge_nf)]).astype(np.int64)
        # face -> first half-edge
        self.f_off = np.concatenate([[0], np.cumsum(self.sides)]).astype(np.int64)
        # vertex -> edges
        ve = np.concatenate([self.E[:, 0], self.E[:, 1]]) if self.nE else np.zeros(0, np.int64)
        vi = np.concatenate([np.arange(self.nE), np.arange(self.nE)]) if self.nE else np.zeros(0, np.int64)
        o = np.argsort(ve, kind='stable')
        self.ve_e = vi[o]
        self.valence = np.bincount(ve, minlength=self.nV).astype(np.int64)
        self.ve_off = np.concatenate([[0], np.cumsum(self.valence)]).astype(np.int64)
        # vertex -> faces
        fv = self.hv0
        o = np.argsort(fv, kind='stable')
        self.vf_f = self.hf[o]
        self.vnf = np.bincount(fv, minlength=self.nV).astype(np.int64)
        self.vf_off = np.concatenate([[0], np.cumsum(self.vnf)]).astype(np.int64)
        self.boundary_e = self.edge_nf == 1
        self.nonman_e = self.edge_nf >= 3
        self.n_boundary = int(self.boundary_e.sum())
        self.n_nonmanifold = int(self.nonman_e.sum())
        bv = np.zeros(self.nV, bool)
        if self.nE:
            bv[self.E[self.boundary_e].ravel()] = True
        self.boundary_v = bv
        nmv = np.zeros(self.nV, bool)
        if self.nE:
            nmv[self.E[self.nonman_e].ravel()] = True
        self.nonman_v = nmv
        self._bowtie = None
        self._pair = None

    # -------------------------------------------------------------------------------------- basic queries
    def vertex_edges(self, v):
        return self.ve_e[self.ve_off[v]:self.ve_off[v + 1]]

    def vertex_faces(self, v):
        return self.vf_f[self.vf_off[v]:self.vf_off[v + 1]]

    def edge_faces(self, e):
        return self.hf[self.eh[self.eh_off[e]:self.eh_off[e + 1]]]

    def edge_halfedges(self, e):
        return self.eh[self.eh_off[e]:self.eh_off[e + 1]]

    def face_edges(self, f):
        return self.he_edge[self.f_off[f]:self.f_off[f + 1]]

    def other(self, e, v):
        a, b = self.E[e]
        return int(b) if a == v else int(a)

    def used_vertices(self):
        return np.where(self.vnf > 0)[0]

    # -------------------------------------------------------------------------------------- D6 manifold
    def flipped_edges(self):
        """manifold edges whose two faces walk them in the same direction (inconsistent winding)."""
        out = []
        for e in np.where(self.edge_nf == 2)[0]:
            h = self.edge_halfedges(e)
            if self.hv0[h[0]] == self.hv0[h[1]]:
                out.append(int(e))
        return out

    def bowtie_vertices(self):
        """D6: a vertex whose incident faces form more than one fan (faces joined through edges at that vertex)."""
        if self._bowtie is not None:
            return self._bowtie
        out = []
        for v in self.used_vertices():
            fs = self.vertex_faces(v)
            if len(fs) < 2:
                continue
            idx = {int(f): k for k, f in enumerate(fs)}
            uf = UnionFind(len(fs))
            for e in self.vertex_edges(v):
                fl = [idx[int(f)] for f in self.edge_faces(e) if int(f) in idx]
                for k in fl[1:]:
                    uf.union(fl[0], k)
            if len(set(uf.roots().tolist())) > 1:
                out.append(int(v))
        self._bowtie = out
        return out

    def inner_mask(self):
        """D7: inner vertex = has faces, no boundary edge, no non-manifold edge, not a bow-tie."""
        m = (self.vnf > 0) & ~self.boundary_v & ~self.nonman_v
        bt = self.bowtie_vertices()
        if bt:
            m[np.array(bt)] = False
        return m

    def boundary_loops(self):
        """D6: boundary edges chained into loops; at a vertex with several boundary edges the next one is found by
        rotating through the fan of the face that owns the incoming boundary half-edge."""
        bh = [int(h) for e in np.where(self.boundary_e)[0] for h in self.edge_halfedges(e)]
        if not bh:
            return []
        bhs = set(bh)
        out_of = {}
        for h in bh:
            out_of.setdefault(int(self.hv0[h]), []).append(h)
        twin = {}
        for e in np.where(self.edge_nf == 2)[0]:
            a, b = self.edge_halfedges(e)
            twin[int(a)], twin[int(b)] = int(b), int(a)

        def nxt_in_face(h):
            f = self.hf[h]
            k = self.hk[h]
            return int(self.f_off[f] + (k + 1) % self.sides[f])

        used, loops = set(), []
        for h0 in sorted(bh):
            if h0 in used:
                continue
            chain, h, closed = [], h0, False
            for _ in range(len(bh) + 1):
                used.add(h)
                chain.append(int(self.hv0[h]))
                v = int(self.hv1[h])
                # find the next boundary half-edge leaving v
                g = nxt_in_face(h)
                guard = 0
                while g in twin and guard < 1000:
                    g = nxt_in_face(twin[g])
                    guard += 1
                if g not in bhs or self.hv0[g] != v:
                    cand = [x for x in out_of.get(v, []) if x not in used]
                    g = cand[0] if cand else None
                if g is None:
                    break
                if g == h0:
                    closed = True
                    break
                if g in used:
                    break
                h = g
            loops.append(dict(verts=chain, nverts=len(chain), closed=closed))
        loops.sort(key=lambda L: (-L['nverts'], min(L['verts'])))
        return loops

    # -------------------------------------------------------------------------------------- D8 edge loops
    def loop_pairs(self, inner=None):
        """D8: at every inner valence-4 vertex each edge is paired with the one edge that shares no face with it."""
        if self._pair is not None:
            return self._pair
        if inner is None:
            inner = self.inner_mask()
        pair = {}
        for v in np.where(inner & (self.valence == 4))[0]:
            es = [int(e) for e in self.vertex_edges(v)]
            fs = [set(int(f) for f in self.edge_faces(e)) for e in es]
            d = {}
            for i in range(4):
                opp = [es[j] for j in range(4) if j != i and not (fs[i] & fs[j])]
                if len(opp) == 1:
                    d[es[i]] = opp[0]
            if len(d) == 4:
                pair[int(v)] = d
        self._pair = pair
        return pair

    def edge_loops(self):
        """D8: partition of the edges into maximal loops through inner valence-4 vertices. Each loop:
        verts (ordered), edges, closed, ends (the two stop vertices of an open loop)."""
        pair = self.loop_pairs()
        visited = np.zeros(self.nE, bool)
        loops = []
        for e0 in range(self.nE):
            if visited[e0]:
                continue
            visited[e0] = True
            a, b = (int(x) for x in self.E[e0])
            seqv, seqe = [a, b], [e0]
            ce, cv, closed = e0, b, False
            while True:
                nx = pair.get(cv, {}).get(ce)
                if nx is None:
                    break
                if nx == e0:
                    closed = True
                    break
                if visited[nx]:
                    break
                visited[nx] = True
                seqe.append(nx)
                cv = self.other(nx, cv)
                seqv.append(cv)
                ce = nx
            if closed:
                seqv = seqv[:-1]
            else:
                bv, be = [], []
                ce, cv = e0, a
                while True:
                    nx = pair.get(cv, {}).get(ce)
                    if nx is None or visited[nx]:
                        break
                    visited[nx] = True
                    be.append(nx)
                    cv = self.other(nx, cv)
                    bv.append(cv)
                    ce = nx
                seqv = bv[::-1] + seqv
                seqe = be[::-1] + seqe
            loops.append(dict(verts=seqv, edges=seqe, closed=closed,
                              ends=None if closed else (seqv[0], seqv[-1])))
        return loops

    # -------------------------------------------------------------------------------------- D10 face rings
    def face_strips(self):
        """D10: quads chained across opposite edges. Each quad is in exactly two strips (one per direction). Closed
        strips are face rings. Returns list of dict(faces, closed)."""
        quads = np.where(self.sides == 4)[0]
        isq = np.zeros(self.nF, bool)
        isq[quads] = True
        visited = set()
        strips = []

        def step(f, k_out):
            """leave quad f through its edge k_out; return (g, k_in) or None."""
            e = int(self.he_edge[self.f_off[f] + k_out])
            if self.edge_nf[e] != 2:
                return None
            hs = self.edge_halfedges(e)
            g = [int(self.hf[h]) for h in hs if int(self.hf[h]) != f]
            if len(g) != 1 or not isq[g[0]]:
                return None
            g = g[0]
            kin = [int(self.hk[h]) for h in hs if int(self.hf[h]) == g][0]
            return g, kin

        for f in quads:
            for d in (0, 1):
                if (int(f), d) in visited:
                    continue
                visited.add((int(f), d))
                seq, closed = [int(f)], False
                cur, kout = int(f), d + 2
                while True:
                    s = step(cur, kout)
                    if s is None:
                        break
                    g, kin = s
                    if g == f and kin % 2 == d:
                        closed = True
                        break
                    if (g, kin % 2) in visited:
                        break
                    visited.add((g, kin % 2))
                    seq.append(g)
                    cur, kout = g, (kin + 2) % 4
                if not closed:
                    back = []
                    cur, kout = int(f), d
                    while True:
                        s = step(cur, kout)
                        if s is None:
                            break
                        g, kin = s
                        if (g, kin % 2) in visited:
                            break
                        visited.add((g, kin % 2))
                        back.append(g)
                        cur, kout = g, (kin + 2) % 4
                    seq = back[::-1] + seq
                strips.append(dict(faces=seq, closed=closed))
        return strips


# ---------------------------------------------------------------------------------------------------------------- geometry
def face_normals_areas(V, faces):
    """Newell normal per polygon; area = |Newell| / 2."""
    N = np.zeros((len(faces), 3))
    for i, f in enumerate(faces):
        P = V[list(f)]
        Q = np.roll(P, -1, axis=0)
        N[i] = np.array([((P[:, 1] - Q[:, 1]) * (P[:, 2] + Q[:, 2])).sum(),
                         ((P[:, 2] - Q[:, 2]) * (P[:, 0] + Q[:, 0])).sum(),
                         ((P[:, 0] - Q[:, 0]) * (P[:, 1] + Q[:, 1])).sum()])
    A = np.linalg.norm(N, axis=1) / 2
    Nn = N / np.where(A[:, None] > 0, 2 * A[:, None], 1)
    return Nn, A


def face_centroids(V, faces):
    return np.array([V[list(f)].mean(axis=0) for f in faces]) if faces else np.zeros((0, 3))


def sphere_fit(P):
    """algebraic least-squares sphere: returns centre, radius, rms residual."""
    A = np.c_[2 * P, np.ones(len(P))]
    b = (P ** 2).sum(axis=1)
    sol, *_ = np.linalg.lstsq(A, b, rcond=None)
    c = sol[:3]
    rad = math.sqrt(max(sol[3] + c @ c, 0.0))
    res = np.linalg.norm(P - c, axis=1) - rad
    return c, rad, float(np.sqrt((res ** 2).mean()))


def plane_fit(P):
    c = P.mean(axis=0)
    _, s, vt = np.linalg.svd(P - c, full_matrices=False)
    return c, vt[-1], s


def frame_of(a):
    a = np.asarray(a, float)
    a = a / np.linalg.norm(a)
    ref = np.array([0.0, -1.0, 0.0]) if abs(a[1]) < 0.9 else np.array([0.0, 0.0, 1.0])
    u = ref - (ref @ a) * a
    u /= np.linalg.norm(u)
    w = np.cross(a, u)
    return a, u, w


def winding_number(P, c, axis, closed=True):
    """D11: signed number of turns of the point sequence P around the line through c along axis."""
    a, u, w = frame_of(axis)
    R = P - c
    R = R - np.outer(R @ a, a)
    th = np.arctan2(R @ w, R @ u)
    d = np.diff(np.append(th, th[0])) if closed else np.diff(th)
    d = (d + np.pi) % (2 * np.pi) - np.pi
    return float(d.sum() / (2 * np.pi)), np.linalg.norm(R, axis=1)


def point_in_loop(points, P):
    """D13: is each point inside the closed polygon P (ordered), tested in P's best-fit plane (even-odd rule)."""
    c, n, _ = plane_fit(P)
    a, u, w = frame_of(n)
    Q = np.c_[(P - c) @ u, (P - c) @ w]
    pts = np.atleast_2d(points)
    X = np.c_[(pts - c) @ u, (pts - c) @ w]
    out = []
    for x, y in X:
        inside = False
        for k in range(len(Q)):
            x1, y1 = Q[k]
            x2, y2 = Q[(k + 1) % len(Q)]
            if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
                inside = not inside
        out.append(inside)
    return np.array(out)


# ---------------------------------------------------------------------------------------------------------------- D4 judged unit
def find_caps(topo):
    """D4: cap = (a) one face with >= 5 sides each of whose vertices has exactly one edge outside that face, or
    (b) a full fan of >= 5 triangles around one inner vertex whose rim vertices each have exactly one edge outside the
    fan. Returns list of dict(kind, faces, rim)."""
    caps = []
    for f in np.where(topo.sides >= CAP_MIN_SIDES)[0]:
        fv = topo.faces[f]
        fe = set(int(e) for e in topo.face_edges(f))
        ok = True
        for v in fv:
            outside = [e for e in topo.vertex_edges(v) if int(e) not in fe]
            if len(outside) != 1:
                ok = False
                break
        if ok:
            caps.append(dict(kind='ngon', faces=[int(f)], rim=list(fv), sides=len(fv)))
    inner = (topo.vnf > 0) & ~topo.boundary_v & ~topo.nonman_v
    for v in np.where(inner & (topo.valence >= CAP_MIN_SIDES))[0]:
        fs = topo.vertex_faces(v)
        if len(fs) != topo.valence[v] or any(topo.sides[f] != 3 for f in fs):
            continue
        rim = sorted({int(x) for f in fs for x in topo.faces[f] if x != v})
        fanE = set(int(e) for f in fs for e in topo.face_edges(f))
        ok = len(rim) == topo.valence[v]
        for x in rim:
            outside = [e for e in topo.vertex_edges(x) if int(e) not in fanE]
            if len(outside) != 1:
                ok = False
                break
        if ok:
            caps.append(dict(kind='fan', faces=sorted(int(f) for f in fs), rim=rim, sides=len(rim), centre=int(v)))
    return caps


def shells(topo):
    """D4: face components joined through shared edges (any edge, manifold or not)."""
    uf = UnionFind(topo.nF)
    for e in range(topo.nE):
        fs = topo.edge_faces(e)
        for g in fs[1:]:
            uf.union(int(fs[0]), int(g))
    roots = uf.roots()
    comp = {}
    for f, rt in enumerate(roots.tolist()):
        comp.setdefault(rt, []).append(f)
    out = sorted(comp.values(), key=lambda fl: (-len(fl), fl[0]))
    return out


def judged_unit(V, faces, H=None, keep_eyeballs=False, declared_caps=None):
    """D4: the judged unit = every shell of the part (garments, teeth, separate limbs all stay) minus
    (a) eyeball shells: any shell but the largest that is small (fitted sphere radius <= 10 % of H) and spherical (fit
        RMS <= 5 % of the radius), open or closed - always excluded and listed (keep_eyeballs keeps them);
    (b) closing caps, ONLY when the caller declares how many the part has (declared_caps = N, e.g. the README-declared
        wrist cap of a separate hand). Caps are found by shape (find_caps); when the found count differs from N nothing
        is excluded and the mismatch is reported, so an undeclared cap always counts as the n-gon it is.
    Returns (faces, report)."""
    topo = Topology(len(V), faces)
    _, A = face_normals_areas(V, faces)
    if H is None:
        H = float(np.ptp(V[:, 2])) if len(V) else 0.0
    sh = shells(topo)
    rep = dict(shells=len(sh), shell_faces=[len(s) for s in sh[:12]], eyeballs=[], caps=[], declared_caps=declared_caps)
    drop = set()
    if len(sh) > 1 and not keep_eyeballs:
        for si, fl in enumerate(sh[1:], start=1):
            sub = Topology(len(V), [faces[f] for f in fl])
            if sub.n_nonmanifold:
                continue
            vs = sub.used_vertices()
            if len(vs) < 8:
                continue
            c, rad, rms = sphere_fit(V[vs])
            if rad <= EYEBALL_SIZE_REL * H and rms <= EYEBALL_RMS_REL * rad:
                rep['eyeballs'].append(dict(shell=si, faces=len(fl), closed=not sub.n_boundary, radius_over_H=r(rad / H, 4),
                                            rms_over_radius=r(rms / rad, 4)))
                drop.update(fl)
    cands = [cp for cp in find_caps(topo) if not any(f in drop for f in cp['faces'])]
    rep['cap_candidates'] = [dict(kind=cp['kind'], sides=cp['sides'], faces=len(cp['faces']),
                                  area_share=r(float(A[cp['faces']].sum() / max(A.sum(), 1e-30)), 5)) for cp in cands]
    if declared_caps is not None:
        if len(cands) == int(declared_caps):
            for cp in cands:
                rep['caps'].append(dict(kind=cp['kind'], sides=cp['sides'], faces=len(cp['faces'])))
                drop.update(cp['faces'])
        else:
            rep['caps_mismatch'] = dict(declared=int(declared_caps), found=len(cands))
    kept = [f for i, f in enumerate(faces) if i not in drop]
    rep['faces_excluded'] = len(drop)
    rep['faces_judged'] = len(kept)
    rep['rule'] = ('all shells of the part; small spherical shells (eyeballs) excluded; closing caps excluded only when '
                   'declared and found in that number (D4)')
    return kept, rep


# ---------------------------------------------------------------------------------------------------------------- D5 face kinds
def face_kinds(topo):
    s = topo.sides
    nF = max(topo.nF, 1)
    hist = {int(k): int((s == k).sum()) for k in np.unique(s)} if topo.nF else {}
    tri_eq = int((s - 2).sum()) if topo.nF else 0
    q = int((s == 4).sum())
    return dict(faces=int(topo.nF), quads=q, tris=int((s == 3).sum()), ngons=int((s > 4).sum()), sides_hist=hist,
                quad_share=r(q / nF, 4), tri_equivalent=tri_eq,
                stated_dev=r(abs(q - tri_eq / 2) / max(tri_eq / 2, 1), 4))


# ---------------------------------------------------------------------------------------------------------------- D7 poles
def classify_vertex(topo, inner, v):
    if topo.vnf[v] == 0:
        return 'unused'
    if v in set(topo.bowtie_vertices()):
        return 'bowtie'
    if topo.nonman_v[v]:
        return 'nonmanifold'
    if topo.boundary_v[v]:
        return 'boundary'
    k = int(topo.valence[v])
    if k == 4:
        return 'regular'
    if k <= 2:
        return 'valence2'
    if k == 3:
        return 'pole3'
    if k == 5:
        return 'pole5'
    return 'pole6+'


def pole_census(topo):
    inner = topo.inner_mask()
    val = topo.valence
    n_used = int((topo.vnf > 0).sum())
    n_inner = int(inner.sum())
    p3 = inner & (val == 3)
    p5 = inner & (val == 5)
    p6 = inner & (val >= 6)
    v2 = inner & (val <= 2)
    vh = {int(k): int((val[inner] == k).sum()) for k in np.unique(val[inner])} if n_inner else {}
    poles = p3 | p5 | p6
    excl = {}
    bt = set(topo.bowtie_vertices())
    for v in np.where((topo.vnf > 0) & ~inner & ~topo.boundary_v)[0]:
        why = 'bowtie' if int(v) in bt else 'nonmanifold'
        k = str(min(int(val[v]), 6)) if val[v] != 4 else '4'
        excl.setdefault(why, {}).setdefault(k, 0)
        excl[why][k] += 1
    return dict(verts=n_used, inner=n_inner, v3=int(p3.sum()), v5=int(p5.sum()), v6plus=int(p6.sum()),
                excluded_off_boundary=excl,
                valence2=int(v2.sum()), total=int(poles.sum()), valence_hist=vh,
                pole_share=r(poles.sum() / max(n_inner, 1), 5),
                p6_share_of_verts=r(p6.sum() / max(n_used, 1), 5),
                p6_share_of_inner=r(p6.sum() / max(n_inner, 1), 5)), poles, inner


def pole_chains(topo, poles):
    """P5: connected components of same-valence poles joined by edges."""
    comps = []
    val = topo.valence
    pv = set(np.where(poles)[0].tolist())
    uf = UnionFind(topo.nV)
    joined = 0
    same = 0
    for e in range(topo.nE):
        a, b = (int(x) for x in topo.E[e])
        if a in pv and b in pv:
            joined += 1
            if min(val[a], 6) == min(val[b], 6):
                same += 1
                uf.union(a, b)
    groups = {}
    for v in pv:
        groups.setdefault(uf.find(v), []).append(v)
    sizes = sorted((len(g) for g in groups.values()), reverse=True)
    return dict(edges_joining_two_poles=joined, same_valence_edges=same, max_same_valence_chain=sizes[0] if sizes else 0,
                chains_over_2=sum(1 for s in sizes if s > 2)), groups


# ---------------------------------------------------------------------------------------------------------------- D9 face quality
def quad_quality(V, topo):
    quads = np.array([f for f in topo.faces if len(f) == 4], dtype=np.int64).reshape(-1, 4)
    Nn, A = face_normals_areas(V, topo.faces)
    H = float(np.ptp(V[topo.used_vertices(), 2])) if topo.nF else 1.0
    out = dict(quads=int(len(quads)))
    out['zero_area_faces'] = int((A < ZERO_AREA_REL * H * H).sum())
    if len(quads) == 0:
        return out
    P = V[quads]
    E = np.roll(P, -1, axis=1) - P
    el = np.linalg.norm(E, axis=2)
    aspect = el.max(axis=1) / np.maximum(el.min(axis=1), 1e-15)
    prev = np.roll(P, 1, axis=1) - P
    nxt = np.roll(P, -1, axis=1) - P
    cosang = (prev * nxt).sum(axis=2) / np.maximum(np.linalg.norm(prev, axis=2) * np.linalg.norm(nxt, axis=2), 1e-30)
    ang = np.degrees(np.arccos(np.clip(cosang, -1, 1)))
    Q = np.roll(P, -1, axis=1)
    nn = np.stack([((P[:, :, 1] - Q[:, :, 1]) * (P[:, :, 2] + Q[:, :, 2])).sum(1),
                   ((P[:, :, 2] - Q[:, :, 2]) * (P[:, :, 0] + Q[:, :, 0])).sum(1),
                   ((P[:, :, 0] - Q[:, :, 0]) * (P[:, :, 1] + Q[:, :, 1])).sum(1)], axis=1)
    inc = P - np.roll(P, 1, axis=1)
    out_e = np.roll(P, -1, axis=1) - P
    sg = (np.cross(inc, out_e) * nn[:, None, :]).sum(axis=2)
    concave = ~((sg > 0).all(axis=1) | (sg < 0).all(axis=1))
    # D9: the reflex (interior > 180 deg) corner of each concave quad, measured in its Newell plane
    worst = []
    for i in np.where(concave)[0]:
        major = 1.0 if (sg[i] > 0).sum() >= 2 else -1.0
        for k in range(4):
            if sg[i, k] * major < 0:
                worst.append(360.0 - float(ang[i, k]))
    d02 = np.linalg.norm(P[:, 2] - P[:, 0], axis=1)
    d13 = np.linalg.norm(P[:, 3] - P[:, 1], axis=1)
    n1a = np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0])
    n2a = np.cross(P[:, 2] - P[:, 0], P[:, 3] - P[:, 0])
    n1b = np.cross(P[:, 2] - P[:, 1], P[:, 3] - P[:, 1])
    n2b = np.cross(P[:, 3] - P[:, 1], P[:, 0] - P[:, 1])
    use_a = d02 <= d13
    n1 = np.where(use_a[:, None], n1a, n1b)
    n2 = np.where(use_a[:, None], n2a, n2b)
    l1 = np.linalg.norm(n1, axis=1)
    l2 = np.linalg.norm(n2, axis=1)
    cosd = (n1 * n2).sum(axis=1) / np.maximum(l1 * l2, 1e-30)
    planar = np.where((l1 > 0) & (l2 > 0), np.degrees(np.arccos(np.clip(cosd, -1, 1))), 0.0)
    # neighbour area ratio (every face, reported over quads)
    nbr = np.ones(topo.nF)
    for e in np.where(topo.edge_nf >= 2)[0]:
        fs = topo.edge_faces(e)
        a = A[fs]
        rt = a.max() / max(a.min(), 1e-30)
        for f in fs:
            nbr[f] = max(nbr[f], rt)
    qmask = topo.sides == 4
    out.update(concave_quads=int(concave.sum()), concave_worst_deg=r(max(worst), 1) if worst else None,
               planarity_deg=pct(planar, (50, 90, 99, 100)), planar_share_over_30=r((planar > 30).mean(), 5),
               aspect=pct(aspect, (50, 90, 99, 100)), min_corner_deg=pct(ang.min(axis=1), (0, 1, 10, 50)),
               max_corner_deg=pct(ang.max(axis=1), (50, 90, 99, 100)), neighbour_area_ratio=pct(nbr[qmask], (50, 90, 99, 100)))
    return out


# ---------------------------------------------------------------------------------------------------------------- D16 symmetry
def symmetry(V, topo, H):
    used = topo.used_vertices()
    if len(used) == 0:
        return None
    P = V[used]
    xmid = 0.5 * (P[:, 0].min() + P[:, 0].max())
    tol = SYM_REL * H
    M = P.copy()
    M[:, 0] = 2 * xmid - M[:, 0]
    nn = nearest_within(P, M, tol)
    partner = np.full(topo.nV, -1, np.int64)
    partner[used] = np.where(nn >= 0, used[np.maximum(nn, 0)], -1)
    has = nn >= 0
    centre = np.abs(P[:, 0] - xmid) < tol
    fset = set(frozenset(f) for f in topo.faces)
    fm = 0
    for f in topo.faces:
        img = [partner[v] for v in f]
        if min(img) >= 0 and frozenset(img) in fset:
            fm += 1
    dx = np.abs(P[centre, 0] - xmid) / H if centre.any() else np.zeros(0)
    return dict(x_mid_over_H=r(xmid / H, 5), tol_over_H=SYM_REL, partner_share=r(has.mean(), 5),
                face_mirror_share=r(fm / max(topo.nF, 1), 5), centre_verts=int(centre.sum()),
                centre_abs_dx_max_over_H=r(dx.max() if dx.size else 0.0, 8),
                centre_inexact=int((dx > SYM_CENTRE_EXACT).sum())), partner


# ---------------------------------------------------------------------------------------------------------------- analysis driver
def judged_topology(loaded, face_source='native', keep_eyeballs=False, declared_caps=None):
    """Weld (D2), clean (D3), canonicalise (D1) and cut out the judged unit (D4). Returns a dict with the pieces."""
    if face_source == 'native':
        V, faces = loaded['V'], loaded['faces']
    elif face_source == 'ogt':
        if loaded.get('ogt_faces') is None:
            raise ValueError('no OGT read-back for this file: %s' % (loaded.get('ogt') or {}).get('skipped', 'not a GLB'))
        V, faces = loaded['V'], loaded['ogt_faces']
    elif face_source == 't2q':
        if loaded.get('t2q_faces') is None:
            raise ValueError('Tris to Quads was not run (tl_io.add_t2q)')
        V, faces = loaded['t2q_V'], loaded['t2q_faces']
    else:
        raise ValueError(face_source)
    WV, WF, wrep, raw2 = weld_and_clean(V, faces)
    H = float(np.ptp(WV[:, 2])) if len(WV) else 0.0
    JF, jrep = judged_unit(WV, WF, H=H, keep_eyeballs=keep_eyeballs, declared_caps=declared_caps)
    topo = Topology(len(WV), JF)
    return dict(V=WV, faces=JF, all_faces=WF, topo=topo, weld=wrep, judged=jrep, raw2final=raw2, H=H)


def analyse(loaded, kind='body', skeleton='auto', face_source='native', keep_eyeballs=False, declared_caps=None,
            profile=None, landmarks=None):
    """The full measurement set for one part. kind: body | head | hand | part. Returns the report dict."""
    import tl_skeleton as SK
    import tl_features as FT
    jt = judged_topology(loaded, face_source, keep_eyeballs, declared_caps)
    V, topo, H = jt['V'], jt['topo'], jt['H']
    rep = dict(lib_version=LIB_VERSION, source=loaded.get('source'), kind=kind, face_source=face_source,
               units_note='lengths relative to H (judged unit height, Z up) unless stated', H=r(H, 6),
               weld=jt['weld'], judged_unit=jt['judged'])
    raw_topo = Topology(len(V), jt['all_faces'])
    rep['face_kinds_all'] = face_kinds(raw_topo)
    rep['face_kinds'] = face_kinds(topo)
    pc, poles, inner = pole_census(topo)
    rep['poles'] = pc
    rep['pole_chains'], _ = pole_chains(topo, poles)
    bl = topo.boundary_loops()
    rep['manifold'] = dict(boundary_edges=topo.n_boundary, nonmanifold_edges=topo.n_nonmanifold,
                           flipped_edges=len(topo.flipped_edges()), bowtie_verts=len(topo.bowtie_vertices()),
                           boundary_loops=len(bl), boundary_loop_sizes=[L['nverts'] for L in bl][:24],
                           open_chains=sum(1 for L in bl if not L['closed']), shells=len(shells(topo)),
                           wire_edges=int(loaded.get('wire_edges', 0)))
    rep['quality'] = quad_quality(V, topo)
    sym = symmetry(V, topo, H)
    rep['symmetry'] = sym[0] if sym else None
    loops = topo.edge_loops()
    strips = topo.face_strips()
    rep['edge_loops'] = dict(count=len(loops), closed=sum(1 for L in loops if L['closed']),
                             open=sum(1 for L in loops if not L['closed']),
                             closed_sides_hist=_hist([len(L['verts']) for L in loops if L['closed']]))
    rep['face_rings'] = dict(strips=len(strips), closed=sum(1 for s in strips if s['closed']),
                             closed_len_hist=_hist([len(s['faces']) for s in strips if s['closed']]))
    ctx = dict(V=V, topo=topo, H=H, loops=loops, strips=strips, poles=poles, inner=inner, kind=kind,
               loaded=loaded, raw2final=jt['raw2final'])
    sk = SK.build_skeleton(ctx, skeleton=skeleton)
    ctx['skel'] = sk
    rep['skeleton'] = sk['report']
    FT.measure_features(ctx, rep, landmarks=landmarks)
    rep['_ctx'] = ctx
    return rep


def _hist(vals):
    h = {}
    for v in vals:
        h[int(v)] = h.get(int(v), 0) + 1
    return {str(k): h[k] for k in sorted(h)}


def public(rep):
    """the report without the in-memory context (JSON-safe)."""
    return {k: v for k, v in rep.items() if not k.startswith('_')}


def add_analysis_args(ap):
    """the load options (tl_io) plus the analysis options shared by every command line of the skill."""
    import tl_io
    tl_io.add_load_args(ap)
    ap.add_argument('--kind', default='body', choices=['body', 'head', 'hand', 'part'])
    ap.add_argument('--skeleton', default='auto', help='auto | rig | estimate | FILE.json (canonical joints, mesh frame)')
    ap.add_argument('--face-source', default='native', choices=['native', 'ogt', 't2q'])
    ap.add_argument('--keep-eyeballs', action='store_true', help='judge eyeball shells too (D4)')
    ap.add_argument('--declared-caps', type=int, help='number of closing caps the part declares (D4)')


def analyse_from_args(a):
    import tl_io
    loaded = tl_io.load_from_args(a, need_t2q=(a.face_source == 't2q'))
    rep = analyse(loaded, kind=a.kind, skeleton=a.skeleton, face_source=a.face_source, keep_eyeballs=a.keep_eyeballs,
                  declared_caps=a.declared_caps)
    return loaded, rep


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    m = sub.add_parser('measure')
    add_analysis_args(m)
    m.add_argument('--out', required=True)
    a = ap.parse_args(argv)
    loaded, rep = analyse_from_args(a)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, 'w') as fh:
        json.dump(public(rep), fh, indent=1, default=_json_default)
    print('MEASURE', a.out, json.dumps(dict(faces=rep['face_kinds'], poles=rep['poles']['total'])))
    return 0


def _json_default(o):
    if isinstance(o, np.integer):
        return int(o)
    if isinstance(o, np.floating):
        return float(o)
    if isinstance(o, np.ndarray):
        return o.tolist()
    if isinstance(o, (set, frozenset)):
        return sorted(o)
    raise TypeError(type(o))


if __name__ == '__main__':
    sys.exit(main())
