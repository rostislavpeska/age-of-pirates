"""The rule checker: the 60 rules of ../references/rules.json evaluated on one library report (one implementation per
metric, in toplib / tl_features). Verdicts: PASS, FAIL, REPORT (measured, no threshold in this profile), N/A (an input
the rule needs is missing - named in 'needs').

    python -I rules.py <mesh> [load and analysis options as toplib measure] [--profile profiles/<p>.json]
                    [--declared-openings N] [--face-mode auto|animated|static|planes]
                    [--stage authoring|reduction|export] [--subject build|reference] [--recorded-defects M2,P1]
                    --out rules_report.json

Exit 0 when no 'must' rule fails (gate PASS), 1 otherwise (2 = setup error); the report also carries the reference
grade (no must or should failure). A profile overrides thresholds by rule id
({"thresholds": {"F5": {"head_share_range": [0.2, 0.31]}}}); profiles/generic.json is the default.
"""
import argparse
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import toplib as TL  # noqa: E402

RULES_JSON = os.path.join(HERE, '..', 'references', 'rules.json')
DEFAULT_PROFILE = os.path.join(HERE, '..', 'profiles', 'generic.json')


def load_rules(path=RULES_JSON):
    return json.load(open(path, encoding='utf-8'))


def load_profile(path=None):
    p = json.load(open(path or DEFAULT_PROFILE, encoding='utf-8'))
    p.setdefault('thresholds', {})
    return p


def face_mode(rep, inputs):
    m = inputs.get('face_mode', 'auto')
    if m != 'auto':
        return m
    rg = rep.get('regions', {}).get('per_region', {})
    ht = rg.get('head', {}).get('tri_equivalent', 0)
    if rep['kind'] not in ('body', 'head') or ht == 0:
        return None
    import tl_features as FT
    if ht > FT.ANIMATED_FACE_MIN_TRIS:
        return 'animated'
    if ht > FT.PLANE_MAP_MAX_TRIS:
        return 'static'
    return 'planes'


# ---------------------------------------------------------------------------------------------------------------- rules
def _v(ok):
    return 'PASS' if ok else 'FAIL'


def check(rep, profile=None, inputs=None):
    """Evaluate every rule. Returns dict(rules={id: {verdict, level, measured, threshold, note}}, summary).
    inputs: declared_openings, face_mode, stage (authoring|export), subject (build|reference: a 'pipeline' rule - one
    our own pipeline needs, not a claim about good topology - is only REPORTed on a reference), recorded_defects (rule
    ids a reference is known to fail; listed apart, never hidden).
    gate  = PASS when no 'must' rule fails; grade = PASS when no 'must' or 'should' rule fails (reference grade).
    expected_fail = failures named in recorded_defects; unexpected_fail = every other must / should failure."""
    rules = load_rules()['rules']
    profile = profile or load_profile()
    inputs = inputs or {}
    th_over = profile.get('thresholds', {})
    subject = inputs.get('subject', 'build')
    out = {}
    body = rep['kind'] == 'body' and bool(rep.get('rings') is not None)
    fm = face_mode(rep, inputs)
    ctx = rep.get('_ctx')
    for rl in rules:
        rid = rl['id']
        th = dict(rl['threshold'])
        th.update(th_over.get(rid, {}))
        res = dict(level=rl['level'], title=rl['title'], threshold=th, scope=rl.get('scope', 'practice'))
        try:
            v, meas, note = RULE_FUNCS.get(rid, _na)(rep, th, inputs, body, fm, ctx, rl)
        except KeyError as exc:
            v, meas, note = 'N/A', None, 'metric missing: %s' % exc
        if rl.get('scope') == 'pipeline' and subject == 'reference' and v in ('PASS', 'FAIL'):
            note = ((note + '; ') if note else '') + 'pipeline rule: reported on a reference (measured verdict %s)' % v
            v = 'REPORT'
        res.update(verdict=v, measured=meas)
        if note:
            res['note'] = note
        if v == 'N/A':
            res['needs'] = rl.get('needs', [])
        out[rid] = res
    summ = {}
    for rid, rr in out.items():
        summ.setdefault(rr['verdict'], 0)
        summ[rr['verdict']] += 1
    must_fail = sorted(rid for rid, rr in out.items() if rr['verdict'] == 'FAIL' and rr['level'] == 'must')
    should_fail = sorted(rid for rid, rr in out.items() if rr['verdict'] == 'FAIL' and rr['level'] == 'should')
    may_fail = sorted(rid for rid, rr in out.items() if rr['verdict'] == 'FAIL' and rr['level'] == 'may')
    known = set(inputs.get('recorded_defects') or [])
    failing = must_fail + should_fail
    return dict(profile=profile.get('name'), face_mode=fm, subject=subject, rules=out, summary=summ,
                must_fail=must_fail, should_fail=should_fail, may_fail=may_fail,
                expected_fail=sorted(r for r in failing if r in known),
                unexpected_fail=sorted(r for r in failing if r not in known),
                gate='PASS' if not must_fail else 'FAIL', grade='PASS' if not failing else 'FAIL')


def _na(rep, th, inputs, body, fm, ctx, rl):
    return 'N/A', None, None


def r_M1(rep, th, *a):
    fk = rep['face_kinds']
    ok = fk['ngons'] <= th['ngons_max'] and fk['quad_share'] >= th['quad_share_min']
    return _v(ok), dict(quad_share=fk['quad_share'], ngons=fk['ngons'], tris=fk['tris'], sides=fk['sides_hist']), None


def r_M2(rep, th, *a):
    m, q, w = rep['manifold'], rep['quality'], rep['weld']
    meas = dict(nonmanifold_edges=m['nonmanifold_edges'], wire_edges=m['wire_edges'], flipped_edges=m['flipped_edges'],
                bowtie_verts=m['bowtie_verts'], zero_area_faces=q.get('zero_area_faces', 0), duplicate_faces=w['duplicate'],
                degenerate_faces=w['degenerate'])
    return _v(all(v == 0 for v in meas.values())), meas, None


def r_M3(rep, th, inputs, *a):
    n = rep['manifold']['boundary_loops']
    if inputs.get('declared_openings') is None:
        return 'REPORT', dict(boundary_loops=n, sizes=rep['manifold']['boundary_loop_sizes']), 'no declared openings given'
    return _v(n == int(inputs['declared_openings'])), dict(boundary_loops=n, declared=int(inputs['declared_openings'])), None


def r_M4(rep, th, *a):
    q = rep['quality']
    c = q.get('concave_quads', 0)
    share = c / max(q.get('quads', 0), 1)
    return _v(share <= th['concave_share_max']), dict(concave_quads=c, concave_share=round(share, 5),
                                                      worst_reflex_deg=q.get('concave_worst_deg')), None


CALIBRATED_KINDS = ('body', 'head')      # the shape heuristics M5-M8 were calibrated on bodies and heads only


def _shape(rep, ok, meas, note=None):
    """M5-M8 verdict: gated on bodies and heads; on hands and parts (garments, props) only reported - no hand or
    garment was in the calibration set (calibration.md)."""
    if rep['kind'] not in CALIBRATED_KINDS:
        return 'REPORT', meas, 'shape heuristic not calibrated for kind %s: reported' % rep['kind']
    return _v(ok), meas, note


def r_M5(rep, th, *a):
    s = rep['quality'].get('planar_share_over_30')
    if s is None:
        return 'N/A', None, 'no quads'
    return _shape(rep, s <= th['share_over_30deg_max'], dict(share_over_30deg=s, p90=rep['quality']['planarity_deg']['p90']))


def r_M6(rep, th, *a):
    q = rep['quality'].get('aspect')
    if not q:
        return 'N/A', None, 'no quads'
    return _shape(rep, q['p99'] <= th['p99_max'], dict(p99=q['p99'], max=q['max']), 'the single worst quad is reported, not gated')


def r_M7(rep, th, *a):
    q = rep['quality'].get('min_corner_deg')
    if not q:
        return 'N/A', None, 'no quads'
    return _shape(rep, q['p1'] >= th['p1_min_deg'], dict(p1=q['p1'], min=q['p0']), 'the single worst corner is reported, not gated')


def r_M8(rep, th, *a):
    q = rep['quality'].get('neighbour_area_ratio')
    if not q:
        return 'N/A', None, 'no quads'
    return _shape(rep, q['p99'] <= th['p99_max'], dict(p99=q['p99'], max=q['max']), 'the single worst pair is reported, not gated')


def r_M9(rep, th, *a):
    s = rep.get('symmetry')
    if not s:
        return 'N/A', None, None
    ok = s['partner_share'] >= th['partner_share_min'] and s['centre_inexact'] <= th['centre_inexact_max']
    return _v(ok), dict(partner_share=s['partner_share'], face_mirror_share=s['face_mirror_share'],
                        centre_inexact=s['centre_inexact']), None


def r_P1(rep, th, *a):
    p = rep['poles']
    return _v(p['p6_share_of_verts'] <= th['p6_share_max']), dict(v6plus=p['v6plus'], p6_share_of_verts=p['p6_share_of_verts'],
                                                                  verts=p['verts']), None


def r_P2(rep, th, inputs, body, fm, ctx, rl):
    pz = rep.get('pole_zones')
    if not pz:
        return 'N/A', None, 'no skeleton / not a body or head'
    return _v(pz['unexplained'] <= th['unexplained_max']), pz, None


def r_P3(rep, th, inputs, body, *a):
    if not body:
        return 'N/A', None, 'not a body'
    bp = rep['band_poles']
    meas = {k: dict(crease=v['poles_band_crease'], extension=v['poles_band_extension'])
            for k, v in bp.items() if k.startswith(('elbow', 'knee'))}
    ok = all(v['crease'] <= th['elbow_crease_max' if k.startswith('elbow') else 'knee_crease_max'] for k, v in meas.items())
    return _v(ok and bool(meas)), meas, 'extension-side poles (kneecap, elbow tip) are reported, not gated'


def r_P4(rep, th, inputs, body, *a):
    if not body:
        return 'N/A', None, 'not a body'
    bp = rep['band_poles']
    meas = {k: v['poles_ring_band'] for k, v in bp.items()}
    ok = True
    for k, v in meas.items():
        base = k.rsplit('_', 1)[0]
        key = base + '_max'
        if key in th and v > th[key]:
            ok = False
    gated = sorted(k[:-4] for k in th if k.endswith('_max'))
    return _v(ok), meas, 'gated joints: %s; the others reported only' % ', '.join(gated)


def r_P5(rep, th, inputs, body, fm, ctx, rl):
    if ctx is None or not ctx.get('pole_zone'):
        return 'N/A', None, None
    topo = ctx['topo']
    zones = ctx['pole_zone']
    skip = set(th.get('skip_zones', ['hand', 'foot', 'face_site', 'ear_side']))
    keep = {v for v, z in zones.items() if z not in skip}
    uf = TL.UnionFind(topo.nV)
    for a_, b_ in topo.E:
        a_, b_ = int(a_), int(b_)
        if a_ in keep and b_ in keep and min(topo.valence[a_], 6) == min(topo.valence[b_], 6):
            uf.union(a_, b_)
    comp = {}
    for v in keep:
        comp.setdefault(uf.find(v), []).append(v)
    mx = max((len(c) for c in comp.values()), default=0)
    return _v(mx <= th['max_chain']), dict(max_chain=mx, chains_over_2=sum(1 for c in comp.values() if len(c) > 2)), None


def r_P6(rep, *a):
    return 'REPORT', dict(pole_share=rep['poles']['pole_share']), None


def r_L1(rep, th, inputs, body, *a):
    if not body:
        return 'N/A', None, 'not a body'
    meas = {k: dict(on_rings=v['ring_face_share'], on_perpendicular_rings=v['ring_face_share_aligned'])
            for k, v in rep['rings'].items() if k.rsplit('_', 1)[0] in ('upperarm', 'forearm', 'thigh', 'calf')}
    known = {k: v for k, v in meas.items() if v['on_rings'] is not None}
    if not known:
        return 'N/A', meas, 'no limb faces'
    ok = all(v['on_rings'] >= th['covered_share_min'] and v['on_perpendicular_rings'] >= th['ring_alignment_min']
             for v in known.values())
    return _v(ok), meas, None


def r_L2(rep, th, inputs, body, *a):
    if not body:
        return 'N/A', None, 'not a body'
    meas = {k: v['rings_in_band'] for k, v in rep['joint_rings'].items() if k.startswith(('elbow', 'knee'))}
    ok = all(v >= th['elbow_min' if k.startswith('elbow') else 'knee_min'] for k, v in meas.items())
    return _v(ok and bool(meas)), meas, None


def r_L3(rep, th, inputs, body, *a):
    if not body:
        return 'N/A', None, 'not a body'
    meas = {k: v['spacing_ratio'] for k, v in rep['joint_rings'].items() if k.startswith(('elbow', 'knee', 'wrist'))}
    known = {k: v for k, v in meas.items() if v is not None}
    if not known:
        return 'N/A', meas, 'fewer than two rings near every joint'
    return _v(all(v <= th['ratio_max'] for v in known.values())), meas, None


def r_L5(rep, th, inputs, body, fm, ctx, rl):
    if not body or ctx is None:
        return 'N/A', None, 'not a body'
    meas = {}
    ok = True
    V, sk, poles = ctx['V'], ctx['skel'], ctx['poles']
    for side in ('l', 'r'):
        jn = 'shoulder_' + side
        fl = rep['flow'].get(jn)
        if not fl or 'error' in fl:
            continue
        j = sk['jf'][jn]
        import tl_features as FT
        lb = FT.band_length(j)
        idx = {s['name']: k for k, s in enumerate(sk['segs'])}
        own = np.isin(sk['vseg'], [idx[j['parent']], idx[j['child']]])
        d = np.abs((V - j['pivot']) @ j['n'])
        sel = np.where(own & poles & (d <= FT.BAND * lb))[0]
        C = [s for s in sk['segs'] if s['name'] == j['child']][0]
        a_ = C['d']
        up = np.array([0, 0, 1.0]) - (a_ @ np.array([0, 0, 1.0])) * a_
        up = up / max(np.linalg.norm(up), 1e-12)
        low = top = 0
        for v in sel:
            rv = V[v] - j['pivot']
            rv = rv - (rv @ a_) * a_
            nr = np.linalg.norm(rv)
            if nr < 1e-12:
                continue
            c = float(rv @ up) / nr
            low += c < 0
            top += c >= math.cos(math.radians(30))
        share = low / len(sel) if len(sel) else 1.0
        meas[jn] = dict(arm_root_wrapping=fl['arm_root_wrapping'], wrapping_loops=fl['wrapping_loops'], band_poles=int(len(sel)),
                        lower_half_share=round(share, 3), deltoid_top_poles=int(top))
        ok &= fl['arm_root_wrapping'] >= th.get('arm_root_wrapping_min', 0) and top <= th['deltoid_top_poles_max'] \
            and share >= th['lower_half_share_min']
    if not meas:
        return 'N/A', None, 'no shoulder joints'
    return _v(ok), meas, None


def r_L6(rep, th, inputs, body, *a):
    if not body:
        return 'N/A', None, 'not a body'
    meas, ok = {}, True
    for jn in ('hip_l', 'hip_r'):
        fl = rep['flow'].get(jn)
        if not fl or 'error' in fl:
            continue
        v = sum(1 for t, g in zip(fl['t'], fl['tilt_deg']) if 20 <= g <= 60 and -0.25 <= t <= 0.25)
        tr = sum(1 for t in fl['t'] if 0.05 <= t <= 0.20)
        meas[jn] = dict(v_ring=v, thigh_ring=tr, wrapping_loops=fl['wrapping_loops'])
        ok &= v >= th.get('v_ring_min', 0) and tr >= th.get('thigh_ring_min', 0)
    if not meas:
        return 'N/A', None, None
    if th.get('report'):
        return 'REPORT', meas, 'not confirmed by the reference library (calibration.md): reported only'
    return _v(ok), meas, None


def r_L7(rep, th, inputs, body, *a):
    if not body:
        return 'N/A', None, 'not a body'
    rp = rep['ring_parity']
    return _v(rp['odd_without_nonquad'] <= th['max']), dict(transitions=rp['transitions'], odd=rp['odd'],
                                                            odd_without_nonquad=rp['odd_without_nonquad']), None


def r_L8(rep, th, inputs, body, *a):
    if not body:
        return 'N/A', None, 'not a body'
    t = rep['torso']
    ok = t['waist_rings'] >= th['waist_rings_min'] and t.get('faces_spanning_both_spine_pivots', 0) <= th['spanning_faces_max']
    return _v(ok), {k: t.get(k) for k in ('waist_rings', 'faces_spanning_both_spine_pivots')}, None


def r_L9(rep, th, inputs, body, fm, ctx, rl):
    sides = (rep.get('torso') or {}).get('neck_ring_sides')
    if sides is None and rep['kind'] == 'head':
        bl = rep['manifold']['boundary_loop_sizes']
        sides = bl[0] if bl else None
    if 'neck_ring_sides' in th:
        return _v(sides == th['neck_ring_sides']), dict(neck_ring_sides=sides), None
    return 'REPORT', dict(neck_ring_sides=sides), None


def _face(rep):
    return rep.get('face') or {}


def r_F1(rep, th, inputs, body, fm, *a):
    f = _face(rep)
    if not f or fm is None:
        return 'N/A', None, 'no head'
    er = f.get('eye_rings', [0, 0])
    meas = dict(eye_rings=er, face_mode=fm, eyes_found=f.get('eyes_found'))
    if fm == 'planes':
        pm = rep.get('plane_map') or {}
        meas['planes'] = pm.get('planes')
        return 'REPORT', meas, 'plane-map head: the eye socket is a plane box, rings are not required'
    need = th['animated_min'] if fm == 'animated' else th['static_min']
    return _v(min(er) >= need), meas, None


def r_F2(rep, th, inputs, body, fm, *a):
    f = _face(rep)
    if not f or fm is None:
        return 'N/A', None, 'no head'
    mr = f.get('mouth_rings', 0)
    if fm == 'planes':
        return 'REPORT', dict(mouth_rings=mr, face_mode=fm), 'plane-map head'
    need = th['animated_min'] if fm == 'animated' else th['static_min']
    return _v(mr >= need), dict(mouth_rings=mr, face_mode=fm), None


def r_F3(rep, th, inputs, body, fm, *a):
    f = _face(rep)
    if not f or fm is None:
        return 'N/A', None, 'no head'
    m = f.get('mask_loops', 0)
    if fm != 'animated':
        return 'REPORT', dict(mask_loops=m, face_mode=fm), 'optional below an animated face'
    return _v(m >= th['animated_min']), dict(mask_loops=m, face_mode=fm), None


def r_F4(rep, th, *a):
    f = _face(rep)
    if not f or not f.get('face_poles'):
        return 'N/A', None, 'no face landmarks found'
    return 'REPORT', f['face_poles'], 'sites beyond eyes, mouth and nose are not measurable from topology alone'


def r_F5(rep, th, inputs, body, *a):
    if rep['kind'] != 'body':
        return 'N/A', None, 'needs a full body'
    rg = rep['regions']
    meas = dict(head_with_neck_share=rg['head_with_neck_share'], head_share=rg['head_share'],
                head_tri_equivalent=rg['per_region'].get('head', {}).get('tri_equivalent', 0)
                + rg['per_region'].get('neck', {}).get('tri_equivalent', 0))
    if 'head_share_range' in th:
        lo, hi = th['head_share_range']
        ok = lo <= rg['head_with_neck_share'] <= hi
        if 'head_tris_min' in th:
            ok &= meas['head_tri_equivalent'] >= th['head_tris_min']
        return _v(ok), meas, None
    return 'REPORT', meas, None


def r_F6(rep, *a):
    pz = rep.get('pole_zones') or {}
    return 'REPORT', dict(ear_side_poles=(pz.get('by_zone') or {}).get('ear_side', 0)), None


def r_D1(rep, th, *a):
    t = rep['face_kinds']['tri_equivalent']
    if 'tri_range' in th:
        lo, hi = th['tri_range']
        return _v(lo <= t <= hi), dict(tri_equivalent=t), None
    return 'REPORT', dict(tri_equivalent=t), None


def r_D2(rep, th, inputs, body, *a):
    if rep['kind'] != 'body':
        return 'N/A', None, 'needs a full body'
    pr = rep['regions']['per_region']
    shares = {k: v['tri_share'] for k, v in pr.items()}
    shares['head_with_neck'] = rep['regions']['head_with_neck_share']
    if 'ranges' in th:
        bad = {k: shares.get(k) for k, (lo, hi) in th['ranges'].items() if not (lo <= (shares.get(k) or 0) <= hi)}
        return _v(not bad), dict(shares=shares, outside=bad), None
    return 'REPORT', shares, None


def r_D3(rep, th, inputs, body, *a):
    if not body:
        return 'N/A', None, 'not a body'
    s = rep['ring_sides_by_kind']
    if 'sides' in th:
        bad = {k: s.get(k) for k, v in th['sides'].items() if s.get(k) is not None and s.get(k) != v}
        return _v(not bad), dict(sides=s, differ=bad), None
    return 'REPORT', s, None


def r_X1(rep, th, inputs, *a):
    if rep['kind'] != 'body':
        return 'N/A', None, 'needs a full body'
    pr = rep['regions']['per_region']
    meas = dict(hand_share=pr.get('hands', {}).get('tri_share'), hand_poles=(rep.get('pole_zones') or {}).get('by_zone', {}).get('hand'))
    if 'hand_share_range' in th:
        lo, hi = th['hand_share_range']
        return _v(lo <= (meas['hand_share'] or 0) <= hi), meas, None
    return 'REPORT', meas, None


def r_X3(rep, th, *a):
    if rep['kind'] != 'body':
        return 'N/A', None, 'needs a full body'
    return 'REPORT', dict(foot_share=rep['regions']['per_region'].get('feet', {}).get('tri_share')), None


def r_R1(rep, th, inputs, body, fm, ctx, rl):
    if inputs.get('stage') != 'reduction':
        return 'N/A', None, 'judged on a reduced mesh (run with --stage reduction)'
    m1 = r_M1(rep, load_rules_thr('M1'))[0]
    p1 = r_P1(rep, load_rules_thr('P1'))[0]
    p3 = r_P3(rep, load_rules_thr('P3'), inputs, body)[0] if body else 'N/A'
    ok = m1 == 'PASS' and p1 == 'PASS' and p3 in ('PASS', 'N/A')
    return _v(ok), dict(M1=m1, P1=p1, P3=p3), None


def r_T1(rep, th, inputs, *a):
    if inputs.get('stage') != 'export':
        return 'N/A', None, 'authoring mesh (run with --stage export on the export copy)'
    n = rep['face_kinds']['faces'] - rep['face_kinds']['tris']
    return _v(n <= th['non_triangles_max']), dict(non_triangles=n), None


_THR = {}


def load_rules_thr(rid):
    if not _THR:
        for rl in load_rules()['rules']:
            _THR[rl['id']] = rl['threshold']
    return _THR[rid]


RULE_FUNCS = dict(M1=r_M1, M2=r_M2, M3=r_M3, M4=r_M4, M5=r_M5, M6=r_M6, M7=r_M7, M8=r_M8, M9=r_M9, P1=r_P1, P2=r_P2,
                  P3=r_P3, P4=r_P4, P5=r_P5, P6=r_P6, L1=r_L1, L2=r_L2, L3=r_L3, L5=r_L5, L6=r_L6, L7=r_L7, L8=r_L8,
                  L9=r_L9, F1=r_F1, F2=r_F2, F3=r_F3, F4=r_F4, F5=r_F5, F6=r_F6, D1=r_D1, D2=r_D2, D3=r_D3, X1=r_X1,
                  X3=r_X3, R1=r_R1, T1=r_T1)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    TL.add_analysis_args(ap)
    ap.add_argument('--profile')
    ap.add_argument('--declared-openings', type=int)
    ap.add_argument('--face-mode', default='auto', choices=['auto', 'animated', 'static', 'planes'])
    ap.add_argument('--stage', default='authoring', choices=['authoring', 'reduction', 'export'])
    ap.add_argument('--subject', default='build', choices=['build', 'reference'],
                    help='reference: pipeline rules are only reported (definitions.md D27)')
    ap.add_argument('--recorded-defects', default='', help='comma-separated rule ids a reference is known to fail')
    ap.add_argument('--out', required=True)
    a = ap.parse_args(argv)
    try:
        _, rep = TL.analyse_from_args(a)
    except (OSError, ValueError, RuntimeError) as exc:
        print('SETUP ERROR: %s' % exc, file=sys.stderr)
        return 2
    res = check(rep, load_profile(a.profile), dict(declared_openings=a.declared_openings, face_mode=a.face_mode,
                                                   stage=a.stage, subject=a.subject,
                                                   recorded_defects=[x for x in a.recorded_defects.split(',') if x]))
    res['source'] = rep.get('source')
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, 'w') as fh:
        json.dump(res, fh, indent=1, default=TL._json_default)
    print('RULES', a.out, res['gate'], 'must_fail', res['must_fail'], 'should_fail', res['should_fail'], res['summary'])
    return 0 if res['gate'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main())
