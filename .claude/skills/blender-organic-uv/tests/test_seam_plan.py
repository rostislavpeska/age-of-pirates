"""seam_plan.py on the synthetic mirror-exact tube body (pure Python + numpy; no Blender, CI-safe)."""
import copy
import json
import subprocess
import sys
from pathlib import Path

import pytest

TESTS = Path(__file__).resolve().parent
SCRIPTS = TESTS.parent / 'scripts'
sys.path[:0] = [str(SCRIPTS), str(TESTS)]
import seam_plan as SP  # noqa: E402
import synthetic as S  # noqa: E402


@pytest.fixture(scope='module')
def body():
    return S.dump(S.tube_body())


def plan(body, rules):
    return SP.plan(body, rules)['objects']['Body']


def test_declared_rules_give_disks_and_a_mirror_invariant_set(body):
    v = plan(body, S.BODY_RULES)
    assert v['ok'] and v['mirror_invariant'] is True and not v['fails']
    assert sorted(r['status'] for r in v['islands']) == ['disk'] * 8
    by = {tuple(r['parts']) + (r['side'],): r for r in v['islands']}
    assert ('coat', 'centre') in by and ('guard', 'centre') in by
    assert ('sleeve', '+x') in by and ('sleeve', '-x') in by and ('hand', '-x') in by
    assert v['rule_edges'] == {'neck': 8, 'wrist': 16, 'back': 5, 'arm_under': 4, 'palm': 4, 'inseam': 6}


def test_slot_line_runs_on_the_underside_at_constant_slot(body):
    o = body['objects']['Body']
    v = plan(body, S.BODY_RULES)
    arm = [tuple(map(int, k.split('-'))) for k, rid in v['rule_of'].items() if rid == 'arm_under']
    ring, slot, P = o['vattrs']['ring'], o['vattrs']['slot'], o['co']
    assert len(arm) == 4
    for a, b in arm:
        assert slot[a] == slot[b] == 0 and ring[a] != ring[b]
        assert P[a][2] < 0.8 and P[b][2] < 0.8                       # slot 0 = underside of the arm
    assert {P[a][0] > 0 for a, _ in arm} == {True, False}            # both arms (mirrored)


def test_path_prefers_the_hidden_side(body):
    o = body['objects']['Body']
    v = plan(body, S.BODY_RULES)
    ins = [tuple(map(int, k.split('-'))) for k, rid in v['rule_of'].items() if rid == 'inseam']
    for a, b in ins:
        pa, pb = o['co'][a], o['co'][b]
        # the inner side of each leg faces the other leg: |x| smaller than the leg centre 0.2
        assert abs(pa[0]) < 0.2 and abs(pb[0]) < 0.2


def test_missing_rule_reports_a_tube_and_completion_cuts_it(body):
    rules = copy.deepcopy(S.BODY_RULES)
    rules['objects']['Body']['rules'] = [r for r in rules['objects']['Body']['rules'] if r['id'] != 'inseam']
    v = plan(body, rules)
    assert not v['ok'] and any('trousers' in f for f in v['fails'])
    rules['objects']['Body']['complete'] = 'cut'
    rules['objects']['Body']['hide'] = [-1, 0, 0]
    v = plan(body, rules)
    assert v['ok'] and len(v['auto_complete']) == 1 and v['auto_complete'][0]['parts'] == ['trousers']
    assert v['mirror_invariant'] is True


def test_tube_and_ring_loop_rules(body):
    rules = copy.deepcopy(S.BODY_RULES)
    rr = rules['objects']['Body']['rules']
    rr[:] = [r for r in rr if r['id'] != 'inseam']
    rr.append({'id': 'legs', 'kind': 'tube', 'parts': ['trousers'], 'hide': [-1, 0, 0]})
    rr.append({'id': 'knee', 'kind': 'ring_loop', 'parts': ['trousers'], 'ring': 21})
    v = plan(body, rules)
    assert v['ok'] and v['rule_edges']['knee'] == 16 and v['rule_edges']['legs'] >= 6
    legs = [r for r in v['islands'] if r['parts'] == ['trousers']]
    assert len(legs) == 4 and all(r['status'] == 'disk' for r in legs)


def test_holes_need_a_declaration(body):
    """without its back cut the coat is an open band (2 boundary loops): a FAIL until its part may keep holes. A cup
    (the guard with its cap) is a topological disk: the census cannot see cap distortion, the palm/apex rules do."""
    rules = copy.deepcopy(S.BODY_RULES)
    rr = rules['objects']['Body']['rules']
    rr[:] = [r for r in rr if r['id'] != 'back']
    v = plan(body, rules)
    coat = [r for r in v['islands'] if r['parts'] == ['coat']][0]
    guard = [r for r in v['islands'] if r['parts'] == ['guard']][0]
    assert not v['ok'] and coat['status'] == 'FAIL' and coat['boundary_loops'] == 2
    assert guard['status'] == 'disk'
    rules['objects']['Body']['allow_holes'] = ['coat']
    v = plan(body, rules)
    assert v['ok'] and [r for r in v['islands'] if r['parts'] == ['coat']][0]['status'] == 'disk_with_holes'


def test_setup_errors_are_reported(body):
    bad = copy.deepcopy(S.BODY_RULES)
    bad['objects']['Body']['rules'].append({'id': 'x', 'kind': 'nonsense', 'parts': ['coat']})
    with pytest.raises(SP.PlanError):
        SP.plan(body, bad)
    bad = copy.deepcopy(S.BODY_RULES)
    bad['objects']['Body']['rules'].append({'id': 'neck', 'kind': 'border', 'a': ['coat'], 'b': ['guard']})
    with pytest.raises(SP.PlanError):
        SP.plan(body, bad)                       # duplicate id
    noattr = copy.deepcopy(body)
    noattr['objects']['Body']['vattrs'] = {}
    with pytest.raises(SP.PlanError):
        SP.plan(noattr, S.BODY_RULES)             # slot_line without the attributes
    with pytest.raises(SP.PlanError):
        SP.plan(body, {'schema': 'wrong', 'objects': {}})


def test_cli_writes_and_refuses_repo_output(body, tmp_path):
    d, r = tmp_path / 'dump.json', tmp_path / 'rules.json'
    d.write_text(json.dumps(body), encoding='utf-8')
    r.write_text(json.dumps(S.BODY_RULES), encoding='utf-8')
    out = tmp_path / 'seams.json'
    p = subprocess.run([sys.executable, '-B', str(SCRIPTS / 'seam_plan.py'), str(d), str(r), '--out', str(out)],
                       capture_output=True, text=True)
    assert p.returncode == 0, p.stdout + p.stderr
    res = json.loads(out.read_text())
    assert res['schema'] == SP.SCHEMA_SEAMS and res['ok']
    inside = TESTS / '_refused_seams.json'
    p = subprocess.run([sys.executable, '-B', str(SCRIPTS / 'seam_plan.py'), str(d), str(r), '--out', str(inside)],
                       capture_output=True, text=True)
    assert p.returncode == 2 and not inside.exists()
