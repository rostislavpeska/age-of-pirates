"""Rule-based seam planner for organic meshes (host Python, numpy only, no Blender).

    python seam_plan.py MESH_DUMP.json RULES.json --out ABS_SEAMS.json [--objects A,B]

Reads a mesh dump (mesh_dump.py) and a declared seam-rule table, writes the seam edges per object, the rule that
made each edge, the island census (faces, parts, side, Euler characteristic, boundary loops, genus, disk or not) and
the mirror check. Exit 0 = every island is a disk (or a declared disk with holes) and every mirror object's seam set
is mirror-invariant; 1 = a FAIL in the census (the file is still written); 2 = setup error.

Rule table (JSON, schema blender-organic-uv/seam-rules/1):

    {"schema": "blender-organic-uv/seam-rules/1",
     "objects": {"<object>": {
        "mirror": true,             mirror-exact across local x = 0: side rules run on +X and are mirrored to -X
        "graph": "<object>",        optional: paths only on this object's edges (the quad authoring mesh with the
                                    same vertex order as a triangulated export copy: diagonals never become seams)
        "back": [0, 1, 0],          back direction (default +Y; Blender's front view looks at -Y)
        "up": [0, 0, 1],            up direction (default +Z)
        "hide": [0, 1, 0],          default hidden side for tube / cone / completion cuts
        "centre_tol": 1e-5,         |x| below this = on the centre plane
        "attrs": {"ring": "ring", "slot": "slot"},   names of the INT vertex attributes in the dump
        "allow_holes": ["coat"],    islands with one of these parts may keep interior holes (unwrap with fill_holes)
        "cone_deg": 0,              > 0: join every interior vertex whose angle sum is below this to the island border
        "complete": "report",       non-disk islands: "report" (FAIL) or "cut" (an automatic hidden cut, reported)
        "rules": [ {"id": "...", "kind": "...", ...}, ... ]}}}

Rule kinds (every rule needs a unique "id"; "parts" lists face part labels; "side" is "+x" (mirror objects' default
for path, slot_line, tube and apex) or "all"):
  border     {"a": [parts], "b": [parts]}             every edge between a face of a and a face of b
  centre     {"parts": [...], "side": "back"|"front"} edges on the centre plane whose faces point back / front
  path       {"parts": [...], "from": SEL, "to": SEL, "hide": [x,y,z], "k": 6}
             cheapest path inside the region; edge cost = length x (1 + k x (1 - n.hide) / 2), n = vertex normal,
             so the cut runs on the side facing "hide" (inner leg, arm underside, palm, back of the heel)
  slot_line  {"parts": [...], "slot": S, "rings": [lo, hi]}   edges joining two rings at constant slot S
  ring_loop  {"parts": [...], "ring": R}               edges around ring R (a deliberate loop seam)
  tube       {"parts": [...], "hide": [...], "cap": true}  per connected component of the region: 2 boundary loops
             -> one hidden cut joining them; 1 loop and cap -> a cut from the loop to the farthest vertex (closed
             end, e.g. a pointed cap); 0 loops -> a cut between the two farthest vertices
  apex       {"parts": [...], "hide": [...], "max_faces": 8}  small open pyramids (studs, spikes): one edge from the
             apex to the base vertex lying farthest towards "hide"
  edges      {"pairs": [[a, b], ...], "mirror": true}  explicit edges (mirrored on mirror objects unless false)
Selectors SEL: {"border": [[a parts], [b parts]]} | {"centre_lowest": [parts]} | {"centre_highest": [parts]} |
  {"farthest_from": "from"} | {"extreme": [x,y,z], "band": {"axis": [x,y,z], "within": d}} | {"end_of": "<rule id>"} |
  {"ring": R} | {"ring": R, "slot": S} | {"vertices": [ids]}; every selector is limited to the rule's side and region.
"""
import argparse
import collections
import heapq
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import uvenv  # noqa: E402

SCHEMA_RULES = 'blender-organic-uv/seam-rules/1'
SCHEMA_SEAMS = 'blender-organic-uv/seams/1'
SIDE_KINDS = ('path', 'slot_line', 'tube', 'apex')


class PlanError(Exception):
    pass


def ekey(a, b):
    a, b = int(a), int(b)
    return (a, b) if a < b else (b, a)


def unit(v):
    v = np.asarray(v, float)
    n = np.linalg.norm(v)
    if n == 0:
        raise PlanError('zero direction vector')
    return v / n


class Mesh:
    """Polygon mesh with parts, adjacency, normals, mirror map and optional graph edges."""

    def __init__(self, name, d, graph=None, centre_tol=1e-5):
        self.name = name
        self.P = np.array(d['co'], float).reshape(-1, 3)
        self.F = [list(map(int, f)) for f in d['polys']]
        self.part = list(d['parts']) if d.get('parts') else ['(none)'] * len(self.F)
        if len(self.part) != len(self.F):
            raise PlanError('%s: %d part labels for %d polygons' % (name, len(self.part), len(self.F)))
        self.mm = list(d.get('mirror_map') or [-1] * len(self.P))
        self.vattrs = {k: list(v) for k, v in (d.get('vattrs') or {}).items()}
        self.tol = centre_tol
        self.E = collections.defaultdict(list)
        for fi, f in enumerate(self.F):
            for k in range(len(f)):
                self.E[ekey(f[k], f[(k + 1) % len(f)])].append(fi)
        self.gedges = set(self.E)
        if graph is not None:
            if len(graph['co']) != len(self.P):
                raise PlanError('%s: graph object has %d vertices, mesh has %d' % (name, len(graph['co']), len(self.P)))
            if np.abs(np.array(graph['co'], float) - self.P).max() > 1e-6:
                raise PlanError('%s: graph object vertex positions differ (vertex order must be identical)' % name)
            self.gedges = set()
            for f in graph['polys']:
                for k in range(len(f)):
                    self.gedges.add(ekey(f[k], f[(k + 1) % len(f)]))
            missing = self.gedges - set(self.E)
            if missing:
                raise PlanError('%s: %d graph edges are not mesh edges' % (name, len(missing)))
        self.fn = np.zeros((len(self.F), 3))
        self.farea = np.zeros(len(self.F))
        self.fc = np.zeros((len(self.F), 3))
        for fi, f in enumerate(self.F):
            Q = self.P[f]
            n = np.zeros(3)
            for k in range(len(f)):                      # Newell normal: robust for quads and n-gons
                a, b = Q[k], Q[(k + 1) % len(f)]
                n += np.cross(a, b)
            ln = np.linalg.norm(n)
            self.farea[fi] = ln / 2
            self.fn[fi] = n / ln if ln > 0 else n
            self.fc[fi] = Q.mean(0)
        vn = np.zeros_like(self.P)
        for fi, f in enumerate(self.F):
            for v in f:
                vn[v] += self.fn[fi]
        self.vn = vn / np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-12)

    # -- regions
    def side_of_face(self, f):
        x = self.fc[f][0]
        return 1 if x > self.tol else (-1 if x < -self.tol else 0)

    def faces_of(self, parts, side=None):
        parts = set(parts)
        return [i for i, p in enumerate(self.part) if p in parts and (side is None or self.side_of_face(i) == side)]

    def region_verts(self, faces):
        return sorted(set(v for f in faces for v in self.F[f]))

    def border_between(self, A, B):
        A, B = set(A), set(B)
        out = []
        for e, fs in self.E.items():
            if len(fs) == 2:
                p0, p1 = self.part[fs[0]], self.part[fs[1]]
                if (p0 in A and p1 in B) or (p0 in B and p1 in A):
                    out.append(e)
        return out

    def centre_edges(self, parts, back_sign, back):
        parts = set(parts)
        out = []
        for e, fs in self.E.items():
            a, b = e
            if abs(self.P[a][0]) > self.tol or abs(self.P[b][0]) > self.tol:
                continue
            fs2 = [f for f in fs if self.part[f] in parts]
            if not fs2:
                continue
            nb = float(np.mean([self.fn[f] @ back for f in fs2]))
            if (nb > 0) == (back_sign > 0):
                out.append(e)
        return out

    def boundary_loops(self, faces):
        fset = set(faces)
        be = [e for e, fs in self.E.items() if sum(1 for f in fs if f in fset) == 1]
        adj = collections.defaultdict(list)
        for a, b in be:
            adj[a].append(b)
            adj[b].append(a)
        seen, loops = set(), []
        for v in sorted(adj):
            if v in seen:
                continue
            st, comp = [v], []
            while st:
                x = st.pop()
                if x in seen:
                    continue
                seen.add(x)
                comp.append(x)
                st += adj[x]
            loops.append(sorted(comp))
        return loops

    def components(self, faces, cut=frozenset()):
        fset = set(faces)
        par = {f: f for f in faces}

        def find(x):
            while par[x] != x:
                par[x] = par[par[x]]
                x = par[x]
            return x
        for e, fs in self.E.items():
            if e in cut:
                continue
            inn = [f for f in fs if f in fset]
            if len(inn) == 2:
                par[find(inn[0])] = find(inn[1])
        out = collections.defaultdict(list)
        for f in faces:
            out[find(f)].append(f)
        return sorted(out.values(), key=lambda c: (-len(c), c[0]))

    def path(self, faces, sources, targets, hide, k=6.0, forbid=()):
        """Dijkstra over graph edges touching the region, sources -> nearest target; returns (edges, end vertex)."""
        fset = set(faces)
        d = unit(hide)
        forbid = set(forbid)
        adj = collections.defaultdict(list)
        for e, fs in self.E.items():
            if e in self.gedges and e not in forbid and any(f in fset for f in fs):
                adj[e[0]].append(e[1])
                adj[e[1]].append(e[0])
        score = (1 - self.vn @ d) / 2.0
        sources = [int(s) for s in sources]
        targets = set(int(t) for t in targets) - set(sources)
        if not sources or not targets:
            raise PlanError('empty source or target set')
        dist, prev, h = {}, {}, []
        for s in sources:
            dist[s] = 0.0
            heapq.heappush(h, (0.0, s))
        end = None
        while h:
            c, v = heapq.heappop(h)
            if c > dist.get(v, 1e18):
                continue
            if v in targets:
                end = v
                break
            for w in sorted(adj[v]):
                ln = float(np.linalg.norm(self.P[v] - self.P[w]))
                cc = c + ln * (1 + k * 0.5 * (score[v] + score[w]))
                if cc < dist.get(w, 1e18):
                    dist[w] = cc
                    prev[w] = v
                    heapq.heappush(h, (cc, w))
        if end is None:
            raise PlanError('no path inside the region')
        p = [end]
        while p[-1] in prev:
            p.append(prev[p[-1]])
        return [ekey(p[i], p[i + 1]) for i in range(len(p) - 1)], end

    def mirror_edge(self, e):
        a, b = self.mm[e[0]], self.mm[e[1]]
        if a < 0 or b < 0:
            raise PlanError('%s: edge %s has no mirror partner (mesh not mirror-exact there)' % (self.name, e))
        return ekey(a, b)

    def angle_sum(self, v, faces):
        tot = 0.0
        for f in faces:
            vs = self.F[f]
            if v not in vs:
                continue
            i = vs.index(v)
            a, b = self.P[vs[i - 1]], self.P[vs[(i + 1) % len(vs)]]
            e1, e2 = a - self.P[v], b - self.P[v]
            c = e1 @ e2 / max(np.linalg.norm(e1) * np.linalg.norm(e2), 1e-30)
            tot += np.degrees(np.arccos(np.clip(c, -1, 1)))
        return tot


# ---------------------------------------------------------------- topology census
def island_topology(m, seams, faces):
    """Euler characteristic, boundary loops and genus of an island as it exists in UV space (split along seams)."""
    fs = set(faces)
    par = {}

    def find(x):
        while par[x] != x:
            par[x] = par[par[x]]
            x = par[x]
        return x
    for fi in fs:
        for v in m.F[fi]:
            par[(v, fi)] = (v, fi)
    for e, efs in m.E.items():
        if e in seams:
            continue
        inn = [f for f in efs if f in fs]
        if len(inn) == 2:
            for v in e:
                a, b = find((v, inn[0])), find((v, inn[1]))
                par[a] = b
    vid = {k: find(k) for k in par}
    nv = len(set(vid.values()))
    edges = collections.Counter()
    for fi in fs:
        f = m.F[fi]
        for i in range(len(f)):
            a, b = f[i], f[(i + 1) % len(f)]
            edges[frozenset((vid[(a, fi)], vid[(b, fi)]))] += 1
    chi = nv - len(edges) + len(fs)
    adj = collections.defaultdict(list)
    for e, c in edges.items():
        if c == 1:
            a, b = tuple(e)
            adj[a].append(b)
            adj[b].append(a)
    seen, loops = set(), 0
    for s in adj:
        if s in seen:
            continue
        loops += 1
        st = [s]
        while st:
            x = st.pop()
            if x in seen:
                continue
            seen.add(x)
            st.extend(adj[x])
    genus = (2 - chi - loops) / 2.0
    return {'faces': len(fs), 'chi': chi, 'boundary_loops': loops, 'genus': genus}


def census(m, seams, allow_holes, mirror):
    rows = []
    for isl in m.components(range(len(m.F)), cut=seams):
        t = island_topology(m, seams, isl)
        parts = sorted(set(m.part[f] for f in isl))
        xs = m.fc[isl][:, 0]
        side = 'centre' if (xs.min() < -m.tol and xs.max() > m.tol) or np.all(np.abs(xs) <= m.tol) else (
            '+x' if xs.max() > m.tol else '-x')
        disk = t['boundary_loops'] == 1 and t['genus'] == 0
        holes_ok = (t['genus'] == 0 and t['boundary_loops'] >= 2 and bool(set(parts) & set(allow_holes)))
        status = 'disk' if disk else ('disk_with_holes' if holes_ok else 'FAIL')
        rows.append(dict(t, parts=parts, side=side if mirror else 'all', status=status,
                         area=float(m.farea[isl].sum()), faces_list=sorted(isl)))
    return rows


# ---------------------------------------------------------------- selectors and rules
def side_filter(m, verts, sgn):
    if sgn is None:
        return list(verts)
    return [v for v in verts if sgn * m.P[v][0] > m.tol or abs(m.P[v][0]) <= m.tol]


def select(m, sel, region, sgn, ctx, up, src=None):
    rv = set(m.region_verts(region))
    if not isinstance(sel, dict) or len(sel) == 0:
        raise PlanError('selector must be an object, got %r' % (sel,))
    if 'border' in sel:
        A, B = sel['border']
        vs = set(v for e in m.border_between(A, B) for v in e)
        if sgn is not None:
            vs = [v for v in vs if sgn * m.P[v][0] > m.tol]
        return sorted(vs)
    if 'centre_lowest' in sel or 'centre_highest' in sel:
        parts = sel.get('centre_lowest', sel.get('centre_highest'))
        cv = [v for v in m.region_verts(m.faces_of(parts)) if abs(m.P[v][0]) <= m.tol]
        if not cv:
            raise PlanError('no centre-plane vertex in %s' % parts)
        key = (lambda v: m.P[v] @ up)
        return [min(cv, key=key) if 'centre_lowest' in sel else max(cv, key=key)]
    if 'farthest_from' in sel:
        if src is None:
            raise PlanError('farthest_from needs a source set')
        c = m.P[src].mean(0)
        return [max(sorted(rv), key=lambda v: float(np.linalg.norm(m.P[v] - c)))]
    if 'extreme' in sel:
        d = unit(sel['extreme'])
        vs = sorted(side_filter(m, rv, sgn))
        band = sel.get('band')
        if band:
            ax = unit(band['axis'])
            lo = min(m.P[v] @ ax for v in vs)
            vs = [v for v in vs if m.P[v] @ ax < lo + float(band['within'])]
        return [max(vs, key=lambda v: float(m.P[v] @ d))]
    if 'end_of' in sel:
        key = (sel['end_of'], sgn)
        if key not in ctx['ends']:
            raise PlanError('end_of %r: no earlier path rule with that id on this side' % sel['end_of'])
        return [ctx['ends'][key]]
    if 'ring' in sel:
        rn, sn = ctx['attrs'].get('ring', 'ring'), ctx['attrs'].get('slot', 'slot')
        if rn not in m.vattrs:
            raise PlanError('vertex attribute %r missing in the dump' % rn)
        vs = [v for v in rv if m.vattrs[rn][v] == int(sel['ring'])]
        if 'slot' in sel:
            if sn not in m.vattrs:
                raise PlanError('vertex attribute %r missing in the dump' % sn)
            vs = [v for v in vs if m.vattrs[sn][v] == int(sel['slot'])]
        return sorted(side_filter(m, vs, sgn))
    if 'vertices' in sel:
        return [int(v) for v in sel['vertices']]
    raise PlanError('unknown selector %r' % (sel,))


def apply_rule(m, r, cfg, ctx):
    """edges of one rule (before mirroring) and whether they must be mirrored."""
    kind = r.get('kind')
    mirror = cfg['mirror']
    side = r.get('side', '+x' if (mirror and kind in SIDE_KINDS) else 'all')
    sgn = 1 if side == '+x' else (-1 if side == '-x' else None)
    if sgn is not None and not mirror:
        raise PlanError('rule %s: side %s needs a mirror object' % (r['id'], side))
    up, back = cfg['up'], cfg['back']
    k = float(r.get('k', 6.0))
    hide = r.get('hide', cfg['hide'])
    edges = []
    if kind == 'border':
        edges = m.border_between(r['a'], r['b'])
        if not edges:
            raise PlanError('rule %s: no edge between %s and %s' % (r['id'], r['a'], r['b']))
        return edges, False
    if kind == 'centre':
        s = r.get('side', 'back')
        if s not in ('back', 'front'):
            raise PlanError('rule %s: centre side must be back or front' % r['id'])
        edges = m.centre_edges(r['parts'], +1 if s == 'back' else -1, back)
        if not edges:
            raise PlanError('rule %s: no centre-plane edge in %s' % (r['id'], r['parts']))
        return edges, False
    if kind == 'edges':
        edges = [ekey(a, b) for a, b in r['pairs']]
        bad = [e for e in edges if e not in m.E]
        if bad:
            raise PlanError('rule %s: not mesh edges %s' % (r['id'], bad[:5]))
        return edges, bool(mirror and r.get('mirror', True))
    region = m.faces_of(r['parts'], sgn)
    if not region:
        raise PlanError('rule %s: no faces of %s on side %s' % (r['id'], r['parts'], side))
    if kind == 'path':
        src = select(m, r['from'], region, sgn, ctx, up)
        tgt = select(m, r['to'], region, sgn, ctx, up, src=src)
        edges, end = m.path(region, src, tgt, hide, k)
        ctx['ends'][(r['id'], sgn)] = end
    elif kind == 'slot_line':
        rn, sn = ctx['attrs'].get('ring', 'ring'), ctx['attrs'].get('slot', 'slot')
        for an in (rn, sn):
            if an not in m.vattrs:
                raise PlanError('rule %s: vertex attribute %r missing in the dump' % (r['id'], an))
        R, S = m.vattrs[rn], m.vattrs[sn]
        lo, hi = r.get('rings', [-10 ** 9, 10 ** 9])
        fset = set(region)
        for e, fs in m.E.items():
            a, b = e
            if e not in m.gedges or not any(f in fset for f in fs):
                continue
            if S[a] == S[b] == int(r['slot']) and R[a] != R[b] and lo <= R[a] <= hi and lo <= R[b] <= hi:
                edges.append(e)
    elif kind == 'ring_loop':
        rn = ctx['attrs'].get('ring', 'ring')
        if rn not in m.vattrs:
            raise PlanError('rule %s: vertex attribute %r missing in the dump' % (r['id'], rn))
        R = m.vattrs[rn]
        fset = set(region)
        edges = [e for e, fs in m.E.items() if e in m.gedges and R[e[0]] == R[e[1]] == int(r['ring'])
                 and any(f in fset for f in fs)]
    elif kind == 'tube':
        for comp in m.components(region):
            loops = m.boundary_loops(comp)
            if len(loops) >= 2:
                es, _ = m.path(comp, loops[0], [v for lp in loops[1:] for v in lp], hide, k)
            elif len(loops) == 1:
                if not r.get('cap', True):
                    continue
                c = m.P[loops[0]].mean(0)
                tip = max(m.region_verts(comp), key=lambda v: float(np.linalg.norm(m.P[v] - c)))
                if tip in loops[0]:
                    continue
                es, _ = m.path(comp, loops[0], [tip], hide, k)
            else:
                vs = m.region_verts(comp)
                Q = m.P[vs] - m.P[vs].mean(0)
                ax = np.linalg.svd(Q, full_matrices=False)[2][0]
                pr = Q @ ax
                es, _ = m.path(comp, [vs[int(np.argmin(pr))]], [vs[int(np.argmax(pr))]], hide, k)
            edges += es
    elif kind == 'apex':
        d = unit(hide)
        for comp in m.components(region):
            if len(comp) > int(r.get('max_faces', 8)):
                continue
            loops = m.boundary_loops(comp)
            if len(loops) != 1:
                continue
            inner = [v for v in m.region_verts(comp) if v not in loops[0]]
            if len(inner) != 1:
                continue
            apex = inner[0]
            base = loops[0]
            c = m.P[base].mean(0)
            w = max(base, key=lambda v: float((m.P[v] - c) @ d))
            if ekey(apex, w) not in m.E:
                raise PlanError('rule %s: apex %d is not joined to base vertex %d' % (r['id'], apex, w))
            edges.append(ekey(apex, w))
    else:
        raise PlanError('rule %s: unknown kind %r' % (r.get('id'), kind))
    if not edges:
        raise PlanError('rule %s (%s) produced no edge' % (r['id'], kind))
    return edges, sgn is not None


def cone_cuts(m, seams, rule_of, cfg):
    """join interior vertices with an angle sum below cone_deg to their island border (hidden-side path)."""
    deg = float(cfg.get('cone_deg', 0) or 0)
    added, skipped = 0, []
    if deg <= 0:
        return added, skipped
    for _ in range(200):
        changed = False
        for isl in m.components(range(len(m.F)), cut=seams):
            fs = set(isl)
            border = set()
            for e, efs in m.E.items():
                inn = [f for f in efs if f in fs]
                if inn and (len(inn) == 1 or e in seams):
                    border.update(e)
            for v in m.region_verts(isl):
                if v in border or v in skipped or m.angle_sum(v, isl) >= deg:
                    continue
                if cfg['mirror'] and abs(m.P[v][0]) <= m.tol:
                    skipped.append(v)               # a centre cone needs a declared centre rule
                    continue
                es, _ = m.path(isl, [v], sorted(border), cfg['hide'])
                new = set(es)
                if cfg['mirror']:
                    new |= set(m.mirror_edge(e) for e in es)
                for e in new - seams:
                    rule_of[e] = 'cone_cut'
                seams |= new
                added += 1
                changed = True
                break
            if changed:
                break
        if not changed:
            break
    return added, skipped


def complete(m, seams, rule_of, cfg):
    rows = census(m, seams, cfg['allow_holes'], cfg['mirror'])
    auto = []
    if cfg['complete'] != 'cut':
        return auto
    for row in rows:
        if row['status'] != 'FAIL':
            continue
        if cfg['mirror'] and row['side'] in ('centre', '-x'):
            continue                                  # centre islands need a declared rule; -x follows +x
        comp = row['faces_list']
        loops = m.boundary_loops(comp)
        try:
            if len(loops) >= 2:
                es, _ = m.path(comp, loops[0], [v for lp in loops[1:] for v in lp], cfg['hide'])
            else:
                vs = m.region_verts(comp)
                Q = m.P[vs] - m.P[vs].mean(0)
                pr = Q @ np.linalg.svd(Q, full_matrices=False)[2][0]
                es, _ = m.path(comp, [vs[int(np.argmin(pr))]], [vs[int(np.argmax(pr))]], cfg['hide'])
        except PlanError as exc:
            auto.append({'parts': row['parts'], 'error': str(exc)})
            continue
        new = set(es)
        if cfg['mirror']:
            new |= set(m.mirror_edge(e) for e in es)
        for e in new - seams:
            rule_of[e] = 'auto_complete'
        seams |= new
        auto.append({'parts': row['parts'], 'edges': len(new)})
    return auto


def object_config(name, o):
    cfg = {'mirror': bool(o.get('mirror', False)), 'back': unit(o.get('back', [0, 1, 0])),
           'up': unit(o.get('up', [0, 0, 1])), 'hide': o.get('hide', o.get('back', [0, 1, 0])),
           'centre_tol': float(o.get('centre_tol', 1e-5)), 'attrs': o.get('attrs', {}),
           'allow_holes': list(o.get('allow_holes', [])), 'cone_deg': o.get('cone_deg', 0),
           'complete': o.get('complete', 'report'), 'rules': o.get('rules', []), 'graph': o.get('graph')}
    if cfg['complete'] not in ('report', 'cut'):
        raise PlanError('%s: complete must be report or cut' % name)
    ids = [r.get('id') for r in cfg['rules']]
    if any(not i for i in ids) or len(set(ids)) != len(ids):
        raise PlanError('%s: every rule needs a unique id' % name)
    return cfg


def plan_object(name, dump, o):
    cfg = object_config(name, o)
    objs = dump['objects']
    if name not in objs:
        raise PlanError('object %s not in the mesh dump' % name)
    graph = objs[cfg['graph']] if cfg['graph'] else None
    if cfg['graph'] and graph is None:
        raise PlanError('%s: graph object %s not in the mesh dump' % (name, cfg['graph']))
    m = Mesh(name, objs[name], graph, cfg['centre_tol'])
    if cfg['mirror'] and objs[name].get('mirror_unmatched', 0):
        raise PlanError('%s: declared mirror but %d vertices have no partner' % (name, objs[name]['mirror_unmatched']))
    seams, rule_of, counts = set(), {}, collections.OrderedDict()
    ctx = {'ends': {}, 'attrs': cfg['attrs']}
    for r in cfg['rules']:
        es, mirror_it = apply_rule(m, r, cfg, ctx)
        new = set(es)
        if mirror_it:
            new |= set(m.mirror_edge(e) for e in es)
            if r.get('kind') == 'path':
                end = ctx['ends'].get((r['id'], 1))
                if end is not None and m.mm[end] >= 0:
                    ctx['ends'][(r['id'], -1)] = m.mm[end]
        for e in new - seams:
            rule_of[e] = r['id']
        counts[r['id']] = len(new)
        seams |= new
    cones, cone_skipped = cone_cuts(m, seams, rule_of, cfg)
    auto = complete(m, seams, rule_of, cfg)
    rows = census(m, seams, cfg['allow_holes'], cfg['mirror'])
    mirror_ok = None
    if cfg['mirror']:
        mirror_ok = all(m.mirror_edge(e) in seams for e in seams)
    fails = [r for r in rows if r['status'] == 'FAIL']
    for r in rows:
        r.pop('faces_list', None)
    return {'seams': sorted([list(e) for e in seams]), 'rule_of': {'%d-%d' % e: rid for e, rid in sorted(rule_of.items())},
            'rule_edges': counts, 'cone_cuts': cones, 'cone_centre_vertices_skipped': cone_skipped,
            'auto_complete': auto, 'islands': rows, 'mirror': cfg['mirror'], 'mirror_invariant': mirror_ok,
            'graph': cfg['graph'], 'ok': not fails and mirror_ok is not False,
            'fails': ['%s island %s: %d loops, genus %g' % (name, r['parts'], r['boundary_loops'], r['genus'])
                      for r in fails] + ([] if mirror_ok is not False else ['%s: seam set not mirror-invariant' % name])}


def plan(dump, rules, only=None):
    if rules.get('schema') != SCHEMA_RULES:
        raise PlanError('rules schema must be %s' % SCHEMA_RULES)
    out = {'schema': SCHEMA_SEAMS, 'rules_schema': SCHEMA_RULES, 'blend': dump.get('blend'), 'objects': {}}
    for name, o in rules.get('objects', {}).items():
        if only and name not in only:
            continue
        out['objects'][name] = plan_object(name, dump, o)
    out['ok'] = all(v['ok'] for v in out['objects'].values())
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(prog='seam_plan.py', description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('dump')
    ap.add_argument('rules')
    ap.add_argument('--out', required=True)
    ap.add_argument('--objects', default='')
    a = ap.parse_args(argv)
    out = uvenv.out_path(a.out, 'seam plan')
    dump, rules = uvenv.read_json(a.dump), uvenv.read_json(a.rules)
    try:
        res = plan(dump, rules, [n for n in a.objects.split(',') if n] or None)
    except PlanError as exc:
        raise uvenv.SetupError(str(exc))
    uvenv.write_json(out, res)
    for n, v in res['objects'].items():
        st = collections.Counter(r['status'] for r in v['islands'])
        print('%s: %d seam edges, %d islands %s, mirror invariant %s, auto cuts %d, cone cuts %d' % (
            n, len(v['seams']), len(v['islands']), dict(st), v['mirror_invariant'], len(v['auto_complete']),
            v['cone_cuts']))
        for f in v['fails']:
            print('FAIL', f)
    print('SEAMS', out)
    return 0 if res['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
