"""Regression tests for plan_batches, aggregate_findings and run_inspector prompt filling (no models are called).

    python -m pytest test_visual_inspector.py -q
"""
import json, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from plan_batches import plan
from aggregate_findings import aggregate, label_ok, cell
import run_inspector

SPEC = {'asset': 'test house', 'camera': '40 deg', 'legend': ['MAGENTA = hidden'], 'classes': {'H1': 'magenta visible?'},
        'not_defects': ['grey']}


def ann(n=10):
    a = [{'file': f'd/v{i}__ann.png', 'label': f'v{i} (camera az{i * 10:03d})', 'control': None, 'grid': [8, 6]} for i in range(n)]
    a.append({'file': 'd/CONTROL_c0__ann.png', 'label': 'c0 (camera az022)', 'control': 'planted', 'grid': [8, 6]})
    a.append({'file': 'd/CLEAN_c5__ann.png', 'label': 'c5 (camera az072)', 'control': 'clean', 'grid': [8, 6]})
    return a


def answer(job, iid, findings=None, label_fn=None, skip_planted=False, dirty_clean=False):
    b = next(x for x in job['batches'] if x['inspector_id'] == iid); out = []
    for f in b['images']:
        m = job['images'][f]; fs = list((findings or {}).get(Path(f).name, []))
        if m['control'] == 'planted' and not skip_planted:
            fs.append({'class': 'H1', 'grid_cells': ['D3'], 'what': 'magenta block', 'confidence': 'high', 'severity': 'major'})
        if m['control'] == 'clean' and dirty_clean:
            fs.append({'class': 'H1', 'grid_cells': ['A1'], 'what': 'invented', 'confidence': 'low', 'severity': 'minor'})
        out.append({'image_file': Path(f).name, 'view_label_read': (label_fn or (lambda x: x))(m['label']), 'clean': not fs, 'findings': fs})
    return {'inspector_id': iid, 'images': out}


def test_plan_covers_every_image_votes_times_with_controls():
    job = plan(SPEC, ann(), per=5, votes=2, engines=('claude', 'codex'))
    targets = [f for f, m in job['images'].items() if not m['control']]
    for f in targets:
        assert sum(f in b['images'] for b in job['batches']) == 2
    for b in job['batches']:
        assert 4 <= len(b['images']) <= 6 or b is job['batches'][-1]
        assert any(job['images'][f]['control'] == 'planted' for f in b['images'])
    assert {b['engine'] for b in job['batches'] if b['round'] == 0} == {'claude'}
    assert {b['engine'] for b in job['batches'] if b['round'] == 1} == {'codex'}


def test_plan_refuses_without_planted_control():
    try:
        plan(SPEC, [x for x in ann() if x['control'] != 'planted'])
    except SystemExit as e:
        assert 'planted control' in str(e)
    else:
        raise AssertionError('no planted control must refuse')


def test_consensus_needs_two_inspectors_on_touching_cells():
    job = plan(SPEC, ann(), per=5, votes=2); res = {}
    for b in job['batches']:
        f = {'v3__ann.png': [{'class': 'H1', 'grid_cells': ['E5'] if b['round'] == 0 else ['F4'], 'what': 'stripe', 'confidence': 'med', 'severity': 'minor'}]}
        res[b['inspector_id']] = answer(job, b['inspector_id'], f)
    agg = aggregate(job, res, 2)
    assert agg['valid_inspectors'] == agg['all_inspectors']
    c = [x for x in agg['findings'] if x['image'] == 'v3__ann.png']
    assert len(c) == 1 and c[0]['status'] == 'consensus' and c[0]['votes'] == 2 and c[0]['verify']
    assert 'v4__ann.png' in agg['clean_images'] and not agg['under_covered']


def test_far_cells_stay_separate_singles():
    job = plan(SPEC, ann(), per=5, votes=2); res = {}
    for b in job['batches']:
        f = {'v3__ann.png': [{'class': 'H1', 'grid_cells': ['A1'] if b['round'] == 0 else ['H6'], 'what': 'x', 'confidence': 'low', 'severity': 'minor'}]}
        res[b['inspector_id']] = answer(job, b['inspector_id'], f)
    c = [x for x in aggregate(job, res, 2)['findings'] if x['image'] == 'v3__ann.png']
    assert sorted(x['status'] for x in c) == ['single', 'single'] and not any(x['verify'] for x in c)


def test_missed_planted_control_invalidates_inspector_and_its_clean_votes():
    job = plan(SPEC, ann(), per=5, votes=2); res = {}
    bad = job['batches'][0]['inspector_id']
    for b in job['batches']:
        res[b['inspector_id']] = answer(job, b['inspector_id'], skip_planted=(b['inspector_id'] == bad))
    agg = aggregate(job, res, 2)
    assert not agg['inspectors'][bad]['valid'] and 'missed planted control' in agg['inspectors'][bad]['problems'][0]
    under = {Path(f).name for f in job['batches'][0]['images'] if not job['images'][f]['control']}
    assert under <= set(agg['under_covered'])


def test_clean_control_findings_and_label_mismatch_and_missing_result():
    job = plan(SPEC, ann(), per=5, votes=2); res = {}
    ids = [b['inspector_id'] for b in job['batches']]
    res[ids[0]] = answer(job, ids[0], dirty_clean=True)
    res[ids[1]] = answer(job, ids[1], label_fn=lambda x: 'something else entirely')
    agg = aggregate(job, res, 2)
    assert any('clean control' in p for p in agg['inspectors'][ids[0]]['problems'])
    assert any('label mismatch' in p for p in agg['inspectors'][ids[1]]['problems'])
    assert agg['inspectors'][ids[2]]['problems'] == ['no result (failed run)']


def test_plan_refuses_control_twin_of_an_inspected_view():
    a = ann(); a[-2]['label'] = 'v3 (camera az030)'
    try:
        plan(SPEC, a)
    except SystemExit as e:
        assert 'share a view' in str(e)
    else:
        raise AssertionError('a control twin must refuse')


def test_label_and_cell_parsing():
    assert label_ok('market_az045_el+40  (camera az045_el+40)', 'Market_az045_el+40 (camera az045_el+40)')
    assert not label_ok('market_az045_el+40', 'market_az200_el+15')
    assert cell('H6', [8, 6]) == (7, 5) and cell('I1', [8, 6]) is None and cell('A7', [8, 6]) is None and cell('east', [8, 6]) is None


def test_prompt_fill_per_engine():
    job = plan(SPEC, ann(), per=5, votes=1); b = job['batches'][0]
    pc = run_inspector.fill(job, b, 'claude'); px = run_inspector.fill(job, b, 'codex')
    for p in (pc, px):
        assert '{' + 'asset}' not in p and 'test house' in p and 'H1: magenta visible?' in p and b['inspector_id'] in p
    assert 'Read tool' in pc and 'attached' in px


def test_schema_is_strict_for_codex():
    s = json.load(open(run_inspector.SCHEMA))

    def walk(x):
        if isinstance(x, dict):
            if x.get('type') == 'object':
                assert x.get('additionalProperties') is False and sorted(x['required']) == sorted(x['properties'])
            for v in x.values():
                walk(v)
    walk(s)
