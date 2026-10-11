"""The rule checker: the 60 step-1 rules in references/rules.json, one implementation each, and the verdict semantics."""
import json
import os

import numpy as np

import synth
import toplib as TL
import rules as RU

REFS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'references')


def loaded(V, F):
    return dict(V=np.asarray(V, float), faces=[tuple(f) for f in F], source=dict(path='synthetic', format='npz'),
                rig=None, vgroup_dom=None, wire_edges=0)


def test_sixty_rules_well_formed():
    data = json.load(open(os.path.join(REFS, 'rules.json'), encoding='utf-8'))
    ids = [r['id'] for r in data['rules']]
    assert len(ids) == 60 and len(set(ids)) == 60
    for r in data['rules']:
        assert r['level'] in ('must', 'should', 'may') and r['scope'] in ('practice', 'pipeline')
        assert isinstance(r['threshold'], dict) and r['threshold']
        assert 'needs' in r and 'metric' in r and r['title']
        if r['id'] not in RU.RULE_FUNCS:
            assert r['needs'], '%s has no implementation and declares no missing input' % r['id']
    assert set(RU.RULE_FUNCS) <= set(ids)


def test_every_rule_gets_a_verdict():
    rep = TL.analyse(loaded(*synth.quad_sphere(3)), kind='head')
    res = RU.check(rep)
    assert set(res['rules']) == set(json.load(open(os.path.join(REFS, 'rules.json')))['rules'][i]['id'] for i in range(60))
    for rid, rr in res['rules'].items():
        assert rr['verdict'] in ('PASS', 'FAIL', 'REPORT', 'N/A'), rid
        if rr['verdict'] == 'N/A':
            assert 'needs' in rr


def test_quad_sphere_head_passes_mesh_rules():
    res = RU.check(TL.analyse(loaded(*synth.quad_sphere(3)), kind='head'))
    for rid in ('M1', 'M2', 'M4', 'P1'):
        assert res['rules'][rid]['verdict'] == 'PASS', rid


def test_triangles_fail_m1_and_p1():
    res = RU.check(TL.analyse(loaded(*synth.uv_sphere(12, 8)), kind='head'))
    assert res['rules']['M1']['verdict'] == 'FAIL' and res['rules']['P1']['verdict'] == 'FAIL'
    assert res['gate'] == 'FAIL' and 'M1' in res['must_fail']


def test_pipeline_rule_is_reported_on_a_reference():
    V, F = synth.quad_sphere(3)
    V = V.copy()
    V[0, 0] += 0.05                                   # break the mirror
    rep = TL.analyse(loaded(V, F), kind='head')
    assert RU.check(rep, inputs=dict(subject='build'))['rules']['M9']['verdict'] == 'FAIL'
    r = RU.check(rep, inputs=dict(subject='reference'))['rules']['M9']
    assert r['verdict'] == 'REPORT' and 'pipeline rule' in r['note']


def test_recorded_defects_are_expected_not_hidden():
    rep = TL.analyse(loaded(*synth.uv_sphere(12, 8)), kind='head')
    res = RU.check(rep, inputs=dict(recorded_defects=['P1']))
    assert 'P1' in res['must_fail'] and 'P1' in res['expected_fail'] and 'P1' not in res['unexpected_fail']
    assert 'M1' in res['unexpected_fail'] and res['gate'] == 'FAIL'


def test_profile_overrides_threshold():
    rep = TL.analyse(loaded(*synth.quad_sphere(3)), kind='head')
    prof = dict(name='t', thresholds=dict(D1=dict(tri_range=[200, 300])))
    assert RU.check(rep, prof)['rules']['D1']['verdict'] == 'FAIL'
    prof = dict(name='t', thresholds=dict(D1=dict(tri_range=[100, 120])))
    assert RU.check(rep, prof)['rules']['D1']['verdict'] == 'PASS'


def test_declared_openings():
    rep = TL.analyse(loaded(*synth.tube(n=8, rows=4)), kind='part')
    assert RU.check(rep, inputs=dict(declared_openings=2))['rules']['M3']['verdict'] == 'PASS'
    assert RU.check(rep, inputs=dict(declared_openings=0))['rules']['M3']['verdict'] == 'FAIL'
    assert RU.check(rep)['rules']['M3']['verdict'] == 'REPORT'


def test_shape_heuristics_reported_on_parts():
    rep = TL.analyse(loaded(*synth.tube(n=8, rows=4)), kind='part')
    assert RU.check(rep)['rules']['M6']['verdict'] == 'REPORT'
