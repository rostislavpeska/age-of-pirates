"""The topology BLUEPRINT of a quad mesh: the structure a builder can follow (definitions.md section B).

    python -I blueprint.py <mesh> [load and analysis options as toplib measure] --out blueprint.json

Writes the blueprint and prints its hash. The blueprint holds counts, ratios and normalised positions only (t along a
segment, angle around it, fractions of H) - never vertex coordinates or faces - so a blueprint of a third-party
reference is a measurement, not a copy. Every list is sorted by measured keys, never by file order, and the mesh is
canonicalised before it is measured (D1): the same mesh gives the same hash whatever its vertex or face order.

Fields (B1-B12 in definitions.md): budget, regions, poles (counts, by region / zone, list), loops (open loops with their
start / end stops, closed loops with their role), pole_links, rings (per segment: t, sides, tilt), joints (band rings and
poles, spacing), flow (shoulder / hip), face_rings, face (eye / mouth / mask rings), plane_map (low-poly heads),
symmetry, hash.
"""
import argparse
import hashlib
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import toplib as TL  # noqa: E402
import tl_features as FT  # noqa: E402

SCHEMA = 'cta-blueprint/1'


def _r(x, k=3):
    return TL.r(x, k)


def _compress(seq):
    out = []
    for x in seq:
        if not out or out[-1] != x:
            out.append(x)
    return out


def pole_list(ctx):
    V, topo, sk, H = ctx['V'], ctx['topo'], ctx['skel'], ctx['H']
    zones = ctx.get('pole_zone', {})
    segs = sk['segs']
    items = []
    for v in np.where(ctx['poles'])[0]:
        k = int(sk['vseg'][v]) if len(sk['vseg']) else -1
        it = dict(valence=min(int(topo.valence[v]), 6), region=str(sk['vreg'][v]), zone=zones.get(int(v)))
        if k >= 0 and segs:
            s = segs[k]
            t, ang, rad = FT.seg_coords(V[v][None], s)
            it.update(segment=s['name'], t=_r(t[0], 2), angle_deg=int(round(float(ang[0]) / 5.0) * 5) % 360,
                      radius_over_H=_r(rad[0] / H, 3))
        else:
            used = topo.used_vertices()
            c = 0.5 * (V[used].min(axis=0) + V[used].max(axis=0))
            it.update(segment=None, pos_over_H=[_r(x, 3) for x in (V[v] - c) / H])
        it['_v'] = int(v)
        items.append(it)
    items.sort(key=lambda d: (d['region'], d['valence'], d.get('segment') or '', d.get('t') or 0, d.get('angle_deg') or 0,
                              d.get('pos_over_H') or [], d['_v']))
    vid = {}
    for i, it in enumerate(items):
        it['id'] = i
        vid[it.pop('_v')] = i
    return items, vid


def loop_roles(ctx):
    """closed loop index -> role: ring:<segment>, eye_l / eye_r / mouth / mask (face rings), else none."""
    roles = {}
    for g in ctx.get('rings', []):
        roles[g['loop']] = 'ring:' + g['seg']
    fc = ctx.get('face') or {}
    fl = fc.get('_face_loops') or {}
    key_of = {}
    for key in ('mask', 'eye_l', 'eye_r', 'mouth'):
        for vs in fl.get(key, []):
            key_of.setdefault(frozenset(vs), key)
    for li, L in enumerate(ctx['loops']):
        if L['closed'] and li not in roles:
            k = key_of.get(frozenset(L['verts']))
            if k:
                roles[li] = k
    return roles


def build(rep):
    ctx = rep['_ctx']
    V, topo, sk, H = ctx['V'], ctx['topo'], ctx['skel'], ctx['H']
    inner = ctx['inner']
    vreg = sk['vreg']
    bp = dict(schema=SCHEMA)
    bp['meta'] = dict(source=rep.get('source'), kind=rep['kind'], face_source=rep['face_source'], lib_version=rep['lib_version'])
    fk = rep['face_kinds']
    bp['budget'] = dict(faces=fk['faces'], quads=fk['quads'], tris=fk['tris'], ngons=fk['ngons'],
                        tri_equivalent=fk['tri_equivalent'], quad_share=fk['quad_share'], verts=rep['poles']['verts'],
                        caps_excluded=len(rep['judged_unit']['caps']), eyeballs_excluded=len(rep['judged_unit']['eyeballs']))
    rg = rep['regions']
    bp['regions'] = {k: dict(tri_share=v['tri_share'], area_share=v['area_share'], density_ratio=v['density_ratio'],
                             faces=v['faces']) for k, v in sorted(rg['per_region'].items())}
    bp['head_share'] = rg['head_share']
    bp['head_with_neck_share'] = rg['head_with_neck_share']
    plist, vid = pole_list(ctx)
    byreg = {}
    for p in plist:
        byreg.setdefault(p['region'], {}).setdefault(str(p['valence']), 0)
        byreg[p['region']][str(p['valence'])] += 1
    pc = rep['poles']
    bp['poles'] = dict(counts={'3': pc['v3'], '5': pc['v5'], '6+': pc['v6plus']}, pole_share=pc['pole_share'],
                       by_region={k: dict(sorted(v.items())) for k, v in sorted(byreg.items())},
                       by_zone=(rep.get('pole_zones') or {}).get('by_zone'), list=plist)
    roles = loop_roles(ctx)
    opens, closeds = [], []
    links = {}
    for li, L in enumerate(ctx['loops']):
        vs = L['verts']
        regs = _compress([str(vreg[v]) for v in vs])
        if L['closed']:
            closeds.append(dict(sides=len(vs), role=roles.get(li, 'none'), regions=sorted(set(regs)), _key=min(vs)))
        else:
            ends = []
            for e in (vs[0], vs[-1]):
                ty = TL.classify_vertex(topo, inner, e)
                ends.append(dict(type=ty, pole=vid.get(int(e)), region=str(vreg[e])))
            if (ends[0]['type'], ends[0]['pole'] if ends[0]['pole'] is not None else -1, ends[0]['region']) > \
                    (ends[1]['type'], ends[1]['pole'] if ends[1]['pole'] is not None else -1, ends[1]['region']):
                ends = ends[::-1]
                regs = regs[::-1]
            k = '%s-%s' % (ends[0]['type'], ends[1]['type'])
            links[k] = links.get(k, 0) + 1
            opens.append(dict(edges=len(L['edges']), start=ends[0], end=ends[1], regions=regs[:12], _key=min(vs)))
    opens.sort(key=lambda d: (d['start']['type'], d['end']['type'], d['start']['pole'] if d['start']['pole'] is not None else -1,
                              d['end']['pole'] if d['end']['pole'] is not None else -1, d['edges'], d['regions'], d['_key']))
    closeds.sort(key=lambda d: (d['role'], d['sides'], d['regions'], d['_key']))
    for lst in (opens, closeds):
        for i, d in enumerate(lst):
            d.pop('_key')
            d['id'] = i
    rolecount = {}
    for d in closeds:
        rk = d['role'].split(':')[0]
        rolecount[rk] = rolecount.get(rk, 0) + 1
    bp['loops'] = dict(count=len(ctx['loops']), open=len(opens), closed=len(closeds), closed_roles=dict(sorted(rolecount.items())),
                       open_list=opens, closed_list=closeds)
    bp['pole_links'] = dict(sorted(links.items()))
    if rep.get('rings'):
        bp['rings'] = {seg: dict(count=v['rings'], t=v['t'], sides=v['sides'], tilt_deg=v['tilt_deg'],
                                 median_sides=v['median_sides'], partial=v['partial_rings'])
                       for seg, v in sorted(rep['rings'].items())}
        bp['joints'] = {}
        for jn in sorted(rep['joint_rings']):
            jr, bpl = rep['joint_rings'][jn], rep['band_poles'][jn]
            bp['joints'][jn] = dict(rings_in_band=jr['rings_in_band'], sides=jr['sides'], spacing_ratio=jr['spacing_ratio'],
                                    poles_band=bpl['poles_band'], poles_ring_band=bpl['poles_ring_band'])
        bp['flow'] = {k: (dict(wrapping_loops=v['wrapping_loops'], closed_rings=v['closed_rings'], t=v['t'],
                               tilt_deg=v['tilt_deg']) if v and 'error' not in v else v) for k, v in sorted(rep['flow'].items())}
    strips = ctx['strips']
    fr = {}
    for s in strips:
        if not s['closed']:
            continue
        cnt = {}
        for f in s['faces']:
            cnt[sk['freg'][f]] = cnt.get(sk['freg'][f], 0) + 1
        reg = sorted(cnt.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]
        fr.setdefault(str(reg), []).append(len(s['faces']))
    bp['face_rings'] = dict(closed=sum(len(v) for v in fr.values()), open=sum(1 for s in strips if not s['closed']),
                            by_region={k: dict(count=len(v), lengths=sorted(v)) for k, v in sorted(fr.items())})
    if rep.get('face'):
        f = rep['face']
        bp['face'] = {k: f.get(k) for k in ('eyes_found', 'mouth_found', 'eye_rings', 'eye_ring_sides', 'mouth_rings',
                                            'mouth_ring_sides', 'mask_loops', 'eye_distance_over_H')}
    pm = rep.get('plane_map')
    if pm and pm.get('applied'):
        bp['plane_map'] = dict(planes=pm['planes'], planes_over_2pct=pm['planes_over_2pct'], angle_deg=pm['angle_deg'],
                               patches=[{k: p[k] for k in ('faces', 'tri_equivalent', 'area_share', 'normal',
                                                           'centre_over_head', 'facing', 'side')} for p in pm['patches']])
    sy = rep.get('symmetry') or {}
    bp['symmetry'] = dict(partner_share=sy.get('partner_share'), face_mirror_share=sy.get('face_mirror_share'))
    bp['hash'] = blueprint_hash(bp)
    return bp


def blueprint_hash(bp):
    body = {k: v for k, v in bp.items() if k not in ('meta', 'hash')}
    txt = json.dumps(body, sort_keys=True, separators=(',', ':'), default=TL._json_default)
    return hashlib.sha256(txt.encode('utf-8')).hexdigest()


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    TL.add_analysis_args(ap)
    ap.add_argument('--out', required=True)
    a = ap.parse_args(argv)
    _, rep = TL.analyse_from_args(a)
    bp = build(rep)
    txt = json.dumps(bp, indent=1, default=TL._json_default)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, 'w') as fh:
        fh.write(txt)
    print('BLUEPRINT', a.out, bp['hash'])
    return 0


if __name__ == '__main__':
    sys.exit(main())
