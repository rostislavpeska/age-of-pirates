"""Frozen-input chart experiments. Writes only to an explicit external output folder.

No mesh editing: adjacency and solver proxies are analytical. World units are
Blender world units, not asserted metres. UV comparisons use actual corner data.
"""
import argparse
import colorsys
import json
import math
import sys
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
from shapely.geometry import Polygon
from shapely.strtree import STRtree


class DSU:
    def __init__(self, n):
        self.p = list(range(n))

    def find(self, a):
        while a != self.p[a]:
            self.p[a] = self.p[self.p[a]]
            a = self.p[a]
        return a

    def join(self, a, b):
        self.p[self.find(b)] = self.find(a)


def groups(n, edges):
    d = DSU(n)
    for a, b in edges:
        d.join(a, b)
    result = defaultdict(list)
    for a in range(n):
        result[d.find(a)].append(a)
    return list(result.values())


def adjacency(faces, tolerance=2e-5):
    """Full coincident edges within a source part; reject point/near/cross contacts.

    Broadphase buckets are larger than tolerance, with neighboring buckets probed.
    Endpoint distances are checked afterward. Ambiguous edge fans are excluded.
    Material/page policy is separate from geometric connectivity.
    """
    from itertools import product
    buckets = defaultdict(list)
    edges = []
    candidates = []
    width = tolerance * 4
    for fi, f in enumerate(faces):
        pts = np.array(f['points'])
        for j in range(len(pts)):
            a, b = pts[j], pts[(j + 1) % len(pts)]
            mid = (a + b) / 2
            bucket = tuple(np.floor(mid / width).astype(int))
            ei = len(edges)
            for delta in product((-1, 0, 1), repeat=3):
                key = (f['part'],) + tuple(bucket[k] + delta[k] for k in range(3))
                for oj in buckets[key]:
                    ofi, oloop, oa, ob = edges[oj]
                    if ofi == fi:
                        continue
                    direct = max(np.linalg.norm(a - oa), np.linalg.norm(b - ob))
                    reverse = max(np.linalg.norm(a - ob), np.linalg.norm(b - oa))
                    if min(direct, reverse) <= tolerance:
                        candidates.append((oj, ei, direct < reverse))
            buckets[(f['part'],) + bucket].append(ei)
            edges.append((fi, j, a, b))
    counts = Counter(i for a, b, _ in candidates for i in (a, b))
    result = []
    for a, b, direct in candidates:
        if counts[a] != 1 or counts[b] != 1:
            continue
        fa, la, pa, qa = edges[a]
        fb, lb, pb, qb = edges[b]
        lb2 = (lb + 1) % len(faces[fb]['points'])
        result.append(dict(a=fa, b=fb, ai=la,
                           aj=(la + 1) % len(faces[fa]['points']),
                           bi=lb if direct else lb2, bj=lb2 if direct else lb,
                           length=float(np.linalg.norm(qa - pa))))
    return result, {'matched_edges': len(result),
                    'ambiguous_half_edges': sum(v > 1 for v in counts.values()),
                    'tolerance_world': tolerance}


def uv_joined(e, uv, eps=2e-6):
    return max(np.linalg.norm(uv[e['a']][e['ai']] - uv[e['b']][e['bi']]),
               np.linalg.norm(uv[e['a']][e['aj']] - uv[e['b']][e['bj']])) <= eps


def islands(faces, edges, uv):
    return groups(len(faces), [(e['a'], e['b']) for e in edges
                              if faces[e['a']]['page'] == faces[e['b']]['page']
                              and uv_joined(e, uv)])


def native_edges(faces, edges):
    return [e for e in edges if faces[e['a']].get('mesh') == faces[e['b']].get('mesh')
            and all(faces[e['a']]['mesh_vertices'][e[a]] == faces[e['b']]['mesh_vertices'][e[b]]
                    for a,b in [('ai','bi'),('aj','bj')])]


def signed_area(p):
    return float(np.sum(p[:, 0] * np.roll(p[:, 1], -1) -
                        p[:, 1] * np.roll(p[:, 0], -1)) / 2)


def local_projection(f):
    p = np.asarray(f['points'], float)
    n = np.asarray(f['normal'], float)
    n /= np.linalg.norm(n)
    v = p[1] - p[0]
    v -= np.dot(v, n) * n
    v /= np.linalg.norm(v)
    w = np.cross(n, v)
    return (p - p[0]) @ np.array([v, w]).T


def eligible(a, b):
    return (not a['hidden'] and not b['hidden'] and a['page'] == b['page']
            and a['part'] == b['part'] and a['physical_family'] == b['physical_family'])


def merge_experiment(faces, edges, angle=1, mode='planar', protect_normals=False):
    """Whole baseline chart merges. Rigid strip unfolding never splits a chart.

    Planar mode requires complete source charts to be coplanar. Strip mode aligns
    matching chart edges without scaling; rejects changed orientation, mismatched
    edge length and positive-area chart intersections. It is greedy, not optimal.
    """
    base = [np.array(f['uv'], float) for f in faces]
    initial = islands(faces, edges, base)
    owner = {i: k for k, g in enumerate(initial) for i in g}
    members = {k: list(g) for k, g in enumerate(initial)}
    uv = [x.copy() for x in base]
    reasons = Counter()
    accepted = []
    # Long gentle edges first; all tie breaks are reproducible.
    ordered = sorted(edges, key=lambda e: (1 - float(np.dot(faces[e['a']]['normal'], faces[e['b']]['normal'])), -e['length'], e['a'], e['b']))
    for e in ordered:
        a, b = e['a'], e['b']
        ga, gb = owner[a], owner[b]
        if ga == gb or not eligible(faces[a], faces[b]):
            continue
        if protect_normals and min(np.dot(faces[a]['corner_normals'][e[ka]],faces[b]['corner_normals'][e[kb]]) for ka,kb in [('ai','bi'),('aj','bj')]) < math.cos(math.radians(5)):
            reasons['protected_corner_normal_seam'] += 1
            continue
        if np.dot(faces[a]['normal'], faces[b]['normal']) < math.cos(math.radians(angle)):
            reasons['dihedral_limit'] += 1
            continue
        whole = members[ga] + members[gb]
        if any(not eligible(faces[a], faces[i]) for i in whole):
            reasons['whole_chart_semantic_boundary'] += 1
            continue
        if mode == 'planar':
            origin = np.array(faces[a]['points'][0]); normal = np.array(faces[a]['normal'])
            if any(np.max(np.abs((np.array(faces[i]['points']) - origin) @ normal)) > 2e-5 for i in whole):
                reasons['nonplanar_whole_chart'] += 1
                continue
        va = uv[a][e['aj']] - uv[a][e['ai']]
        vb = uv[b][e['bj']] - uv[b][e['bi']]
        la, lb = np.linalg.norm(va), np.linalg.norm(vb)
        if min(la, lb) < 1e-10 or abs(la - lb) / max(la, lb) > .005:
            reasons['density_or_edge_length_mismatch'] += 1
            continue
        theta = math.atan2(va[1], va[0]) - math.atan2(vb[1], vb[0])
        c, s = math.cos(theta), math.sin(theta)
        rotation = np.array([[c, -s], [s, c]])
        offset = uv[a][e['ai']] - uv[b][e['bi']] @ rotation.T
        proposed = {i: uv[i] @ rotation.T + offset for i in members[gb]}
        if np.linalg.norm(proposed[b][e['bj']] - uv[a][e['aj']]) > 2e-6:
            reasons['endpoint_residual'] += 1
            continue
        pa = [Polygon(uv[i]) for i in members[ga]]
        pb = [Polygon(proposed[i]) for i in members[gb]]
        if any(not p.is_valid or p.area <= 1e-14 for p in pa + pb):
            reasons['invalid_source_polygon'] += 1
            continue
        tree = STRtree(pa)
        if any(p.intersection(pa[int(j)]).area > 1e-11 for p in pb for j in tree.query(p)):
            reasons['positive_area_overlap'] += 1
            continue
        for i, x in proposed.items():
            uv[i] = x
        for i in members[gb]:
            owner[i] = ga
        members[ga].extend(members.pop(gb))
        accepted.append([faces[a]['id'], faces[b]['id']])
    # Each chart keeps its original scale; give experimental charts unique
    # diagnostic addresses. This is not final-atlas packing or a capacity result.
    uv = contact_layout(faces, edges, uv)
    return uv, {'accepted_merges': len(accepted), 'witness_edges': accepted,
                'rejections': dict(reasons), 'angle_degrees': angle,
                'scale_changes': False, 'production_packing': False}


def contact_layout(faces, edges, uv):
    out = [x.copy() for x in uv]
    charts = islands(faces, edges, uv)
    # Outside 0..1 intentionally: no shrink-to-fit, no runtime atlas claim.
    x,y,rowheight=0.,0.,0.
    for k, g in enumerate(charts):
        if faces[g[0]]['hidden']:
            continue
        points=np.vstack([uv[i] for i in g]);lo=points.min(axis=0);size=points.max(axis=0)-lo
        if x+size[0]>4 and x>0:x=0.;y+=rowheight+.02;rowheight=0.
        shift = np.array([x,y]) - lo
        for i in g:
            out[i] += shift
        x+=size[0]+.02;rowheight=max(rowheight,size[1])
    return out


def metrics(faces, edges, uv):
    charts = islands(faces, edges, uv)
    visible = [g for g in charts if not faces[g[0]]['hidden']]
    singleton = [g for g in visible if len(g) == 1]
    sizes = [len(g) for g in visible]
    cut = sum(e['length'] for e in edges if eligible(faces[e['a']], faces[e['b']]) and not uv_joined(e, uv))
    candidates = sum(e['length'] for e in edges if eligible(faces[e['a']], faces[e['b']]))
    overlaps = []; invalid = []; degenerate = []; distortion = []
    for g in visible:
        polys = [Polygon(uv[i]) for i in g]
        for i, p in zip(g, polys):
            if not p.is_valid: invalid.append(faces[i]['id'])
        if all(p.is_valid for p in polys):
            tree = STRtree(polys)
            for k, p in enumerate(polys):
                for j in tree.query(p):
                    if int(j) > k and p.intersection(polys[int(j)]).area > 1e-11:
                        overlaps.append([faces[g[k]]['id'], faces[g[int(j)]]['id']])
    for i, f in enumerate(faces):
        if f['hidden']: continue
        pts = np.array(f['points'])
        for tri in f['triangles']:
            p = pts[tri]; q = uv[i][tri]
            e1, e2 = p[1] - p[0], p[2] - p[0]
            area = np.linalg.norm(np.cross(e1, e2)) / 2
            l = np.linalg.norm(e1)
            if min(l, area) < 1e-12: continue
            u = e1 / l; x = np.dot(e2, u)
            y = np.linalg.norm(e2 - x * u)
            J = np.column_stack((q[1] - q[0], q[2] - q[0])) @ np.linalg.inv(np.array([[l, x], [0, y]]))
            sv = np.linalg.svd(J, compute_uv=False)
            if sv[-1] <= 1e-12: degenerate.append(f['id']); continue
            distortion.append((float(sv[0] / sv[-1]), float(area), f['id']))
    total = sum(x[1] for x in distortion)
    return dict(visible_charts=len(visible), visible_faces=sum(sizes),
                singleton_charts=len(singleton), singleton_face_fraction=len(singleton)/max(1,sum(sizes)),
                median_faces_per_chart=float(np.median(sizes)),
                maximum_faces_per_chart=max(sizes), cut_length_world=cut,
                cut_fraction=cut/max(candidates,1e-15),
                intra_chart_overlap_pairs=len(overlaps), overlap_witnesses=overlaps[:100],
                invalid_polygons=invalid, degenerate_uv_faces=sorted(set(degenerate)),
                anisotropy_area_above_1_1=sum(a for r,a,_ in distortion if r>1.1)/total,
                worst_anisotropy=max((r for r,_,_ in distortion),default=0),
                worst_distortion_faces=sorted(distortion,reverse=True)[:15])


def colors(faces, edges, uv):
    """Deterministic high-contrast graph coloring, not unconstrained randomness."""
    charts = islands(faces, edges, uv)
    owner = {i:k for k,g in enumerate(charts) for i in g}
    near = defaultdict(set)
    for e in edges:
        a,b=owner[e['a']],owner[e['b']]
        if a!=b:near[a].add(b);near[b].add(a)
    palette = np.array([colorsys.hsv_to_rgb((i*.61803398875)%1, .65+(.2*(i%2)), .85+.15*(i%3==0)) for i in range(64)])
    chosen = {}
    for k in sorted(range(len(charts)),key=lambda k:(-len(near[k]),min(faces[i]['id'] for i in charts[k]))):
        used=[chosen[j] for j in near[k] if j in chosen]
        rng=np.random.default_rng(min(faces[i]['id'] for i in charts[k]))
        order=rng.permutation(len(palette))
        score=[min((np.linalg.norm(palette[j]-c) for c in used),default=1) for j in order]
        chosen[k]=palette[order[int(np.argmax(score))]]
    return {str(f['id']):dict(chart=owner[i],color=([.035]*3 if f['hidden'] else chosen[owner[i]].tolist())) for i,f in enumerate(faces)}


def xatlas_experiment(faces, edges, deps, output):
    sys.path.insert(0, str(deps))
    import xatlas
    uv=[np.array(f['uv']) for f in faces]
    rejects=[]; diagnostics=[]
    # Per connected semantic component; duplicated seam vertices are welded only
    # along verified complete edges in disposable analytical solver input.
    good=[e for e in edges if eligible(faces[e['a']],faces[e['b']])]
    components=groups(len(faces),[(e['a'],e['b']) for e in good])
    for ci,g in enumerate(components):
        if faces[g[0]]['hidden'] or len(g)<2:continue
        corners=[(i,j) for i in g for j in range(len(faces[i]['points']))]
        index={key:k for k,key in enumerate(corners)};d=DSU(len(corners));gs=set(g)
        for e in good:
            if e['a'] in gs and e['b'] in gs:
                for a,b in [('ai','bi'),('aj','bj')]:d.join(index[(e['a'],e[a])],index[(e['b'],e[b])])
        roots={};points=[];indices=[];mapping=[]
        for k,(i,j) in enumerate(corners):
            root=d.find(k)
            if root not in roots:roots[root]=len(points);points.append(faces[i]['points'][j])
        for i in g:
            for tri in faces[i]['triangles']:
                indices.append([roots[d.find(index[(i,j)])] for j in tri]);mapping.append((i,tri))
        atlas=xatlas.Atlas();atlas.add_mesh(np.asarray(points,np.float32),np.asarray(indices,np.uint32))
        co=xatlas.ChartOptions();co.max_iterations=2
        po=xatlas.PackOptions();po.padding=2;po.resolution=512
        atlas.generate(chart_options=co,pack_options=po)
        vm,ix,coords=atlas[0]
        samples=defaultdict(list)
        for (i,tri),outtri in zip(mapping,ix):
            for j,oi in zip(tri,outtri):samples[(i,j)].append(coords[oi])
        # A triangle solver may cut inside an authored quad/ngon. Never apply
        # that conflicting result by splitting the source polygon.
        conflicts=[(i,j) for (i,j),vals in samples.items() if np.max(np.linalg.norm(np.asarray(vals)-vals[0],axis=1))>2e-6]
        if conflicts:
            rejects.append({'component':ci,'faces':[faces[i]['id'] for i in g],'conflicting_corners':len(conflicts)})
            continue
        # Preserve the source component's median UV/world linear density.
        proposed={i:np.array([samples[(i,j)][0] for j in range(len(faces[i]['points']))]) for i in g}
        ratios=[]
        for i in g:
            aa=abs(signed_area(uv[i]));bb=abs(signed_area(proposed[i]))
            if min(aa,bb)>1e-15:ratios.append(math.sqrt(aa/bb))
        scale=float(np.median(ratios)) if ratios else 1
        for i in g:uv[i]=proposed[i]*scale
        diagnostics.append({'component':ci,'faces':len(g),'charts':atlas.chart_count})
    return contact_layout(faces,edges,uv), {'solver':'xatlas-python 0.0.11', 'applied_components':len(diagnostics),'rejected_intra_polygon_cuts':rejects,'details':diagnostics,'density_policy':'median component scale only; per-face density is not guaranteed','production_packing':False}


def run(folder):
    faces=json.loads((folder/'faces.json').read_text())
    edges,info=adjacency(faces)
    base=[np.array(f['uv']) for f in faces]
    variants={'Baseline':(base,{'source':'S12 actual UVMap'})}
    for name,angle,mode in [('Planar',1,'planar'),('Strip65',65,'strip'),('Strip100',100,'strip')]:
        print('Running',name,flush=True)
        variants[name]=merge_experiment(faces,edges,angle,mode)
    print('Running Xatlas',flush=True)
    try:
        variants['Xatlas']=xatlas_experiment(faces,edges,folder/'deps',folder)
    except ImportError as exc:
        (folder/'xatlas_blocked.json').write_text(json.dumps({'tested':False,'reason':str(exc)}))
    reports={}
    for name,(uv,details) in variants.items():
        m=metrics(faces,edges,uv)
        # Rigid methods must preserve every original face's edge lengths.
        ratios=[]
        for f,a,b in zip(faces,base,uv):
            if f['hidden']:continue
            old=np.linalg.norm(np.roll(a,-1,axis=0)-a,axis=1);new=np.linalg.norm(np.roll(b,-1,axis=0)-b,axis=1)
            ratios.extend((new[old>1e-10]/old[old>1e-10]).tolist())
        m['edge_scale_min']=min(ratios);m['edge_scale_max']=max(ratios)
        bypart={}
        chartgroups=islands(faces,edges,uv)
        for g in chartgroups:
            if faces[g[0]]['hidden']:continue
            key=faces[g[0]]['part'];b= bypart.setdefault(key,dict(charts=0,singletons=0,faces=0))
            b['charts']+=1;b['singletons']+=len(g)==1;b['faces']+=len(g)
        reports[name]={'metrics':m,'details':details,'by_part':bypart}
        color=colors(faces,edges,uv)
        result={str(f['id']):dict(uv=q.tolist(),**color[str(f['id'])]) for f,q in zip(faces,uv)}
        (folder/(name+'.json')).write_text(json.dumps(result))
        print(name,json.dumps({k:v for k,v in m.items() if not isinstance(v,list)}),flush=True)
    info['geometric_components']=len(groups(len(faces),[(e['a'],e['b']) for e in edges]))
    info['visible_geometric_components']=sum(any(not faces[i]['hidden'] for i in g) for g in groups(len(faces),[(e['a'],e['b']) for e in edges]))
    (folder/'adjacency.json').write_text(json.dumps({'info':info,'edges':edges}))
    (folder/'results.json').write_text(json.dumps(reports,indent=2))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('folder',type=Path);args=p.parse_args();run(args.folder)
