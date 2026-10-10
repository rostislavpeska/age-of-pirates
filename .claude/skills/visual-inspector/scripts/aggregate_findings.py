"""Aggregate inspector outputs into voted findings. Pure Python.

    python aggregate_findings.py --job JOB.json --results RESULTS_DIR --out AGGREGATE.json [--min-votes 2]

Per inspector (all must hold, else the inspector is INVALID and its votes are dropped, never read as "clean"):
  answered  every assigned image has an entry
  labels    the copied view label matches the burned-in label (proof the image was looked at)
  planted   every planted control image is reported not clean with at least one finding
  clean     every clean control image is reported clean
  cells     grid cells exist in the image grid
Votes: per image and class, findings from valid inspectors are clustered by cell adjacency (Chebyshev distance <= 1).
A cluster with >= --min-votes distinct inspectors is CONSENSUS; else SINGLE. Images seen by fewer than --min-votes valid
inspectors are UNDER_COVERED (re-run more inspectors). Every consensus and every high-confidence single finding goes to
deterministic or close-up verification before anything is changed; the aggregate never edits the asset.
"""
import argparse, difflib, json, re, string
from collections import defaultdict
from pathlib import Path


def norm(t):
    return re.sub(r'[^a-z0-9]', '', (t or '').lower())


def label_ok(expected, read):
    e, r = norm(expected), norm(read)
    return bool(e) and (e in r or r in e and len(r) >= .8 * len(e) or difflib.SequenceMatcher(None, e, r).ratio() >= .85)


def cell(c, grid):
    m = re.fullmatch(r'\s*([A-Za-z])\s*([0-9]{1,2})\s*', c or '')
    if not m:
        return None
    col, row = string.ascii_uppercase.index(m.group(1).upper()), int(m.group(2)) - 1
    return (col, row) if col < grid[0] and 0 <= row < grid[1] else None


def aggregate(job, results, min_votes=2, clean_void=None):
    images = job['images']; base = {Path(f).name: f for f in images}
    inspectors = {}; votes = defaultdict(list); seen = defaultdict(set)
    for b in job['batches']:
        iid = b['inspector_id']; r = results.get(iid); probs = []
        if r is None:
            inspectors[iid] = {'valid': False, 'engine': b['engine'], 'problems': ['no result (failed run)']}; continue
        got = {}
        for e in r.get('images', []):
            f = base.get(Path(str(e.get('image_file', ''))).name)
            if f is None:                                    # tolerate a path variant: match by the label instead
                f = next((x for x in b['images'] if label_ok(images[x]['label'], e.get('view_label_read', ''))), None)
            if f is not None:
                got[f] = e
        for f in b['images']:
            e = got.get(f); meta = images[f]
            if e is None:
                probs.append(f'unanswered {Path(f).name}'); continue
            if not label_ok(meta['label'], e.get('view_label_read', '')):
                probs.append(f"label mismatch {Path(f).name}: read {e.get('view_label_read', '')!r}")
            fs = e.get('findings') or []
            if meta['control'] == 'planted' and (e.get('clean', True) or not fs):
                probs.append(f'missed planted control {Path(f).name}')
            if meta['control'] == 'clean' and (not e.get('clean', False) or fs) and not clean_void:
                probs.append(f'reported findings on clean control {Path(f).name}')
            for x in fs:
                if not x.get('grid_cells') or any(cell(c, meta['grid']) is None for c in x['grid_cells']):
                    probs.append(f"bad grid cells {x.get('grid_cells')} in {Path(f).name}")
        inspectors[iid] = {'valid': not probs, 'engine': b['engine'], 'problems': probs}
        if probs:
            continue
        for f in b['images']:
            if images[f]['control']:
                continue
            seen[f].add(iid)
            for x in got[f].get('findings') or []:
                votes[(f, x['class'])].append({'inspector': iid, 'engine': b['engine'], 'cells': [cell(c, images[f]['grid']) for c in x['grid_cells']],
                                               'raw_cells': x['grid_cells'], 'what': x.get('what', ''), 'confidence': x.get('confidence', 'low'),
                                               'severity': x.get('severity', 'minor')})
    findings = []
    for (f, cls), vs in votes.items():
        clusters = []                                        # union-find over findings whose cells touch
        for v in vs:
            hit = [c for c in clusters if any(max(abs(a[0] - b_[0]), abs(a[1] - b_[1])) <= 1 for a in v['cells'] for w in c for b_ in w['cells'])]
            merged = [v] + [w for c in hit for w in c]
            clusters = [c for c in clusters if c not in hit] + [merged]
        for c in clusters:
            who = sorted({w['inspector'] for w in c}); eng = sorted({w['engine'] for w in c})
            status = 'consensus' if len(who) >= min_votes else 'single'
            conf = max((w['confidence'] for w in c), key=['low', 'med', 'high'].index)
            findings.append({'image': Path(f).name, 'label': images[f]['label'], 'class': cls, 'status': status, 'votes': len(who),
                             'engines': eng, 'inspectors': who, 'cells': sorted({rc for w in c for rc in w['raw_cells']}),
                             'max_confidence': conf, 'severity': 'major' if any(w['severity'] == 'major' for w in c) else 'minor',
                             'what': [w['what'] for w in c], 'verify': status == 'consensus' or conf == 'high'})
    order = {'consensus': 0, 'single': 1}
    findings.sort(key=lambda x: (order[x['status']], -x['votes'], x['image'], x['class']))
    targets = [f for f, m in images.items() if not m['control']]
    return {'inspectors': inspectors, 'valid_inspectors': sum(v['valid'] for v in inspectors.values()), 'all_inspectors': len(inspectors),
            'under_covered': sorted(Path(f).name for f in targets if len(seen[f]) < min_votes),
            'clean_images': sorted(Path(f).name for f in targets if len(seen[f]) >= min_votes and not any(k[0] == f for k in votes)),
            'findings': findings, 'min_votes': min_votes, 'clean_control_void': clean_void}


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--job', required=True); ap.add_argument('--results', required=True)
    ap.add_argument('--out', required=True); ap.add_argument('--min-votes', type=int, default=2)
    ap.add_argument('--clean-control-void', default=None, help='REASON: the clean control itself was defective; recorded, never silent')
    a = ap.parse_args(); job = json.load(open(a.job)); res = {}
    for p in Path(a.results).glob('*.json'):
        try:
            d = json.load(open(p)); res[d.get('inspector_id', p.stem)] = d
        except Exception:
            pass
    agg = aggregate(job, res, a.min_votes, a.clean_control_void); json.dump(agg, open(a.out, 'w'), indent=1)
    print('AGGREGATE valid', agg['valid_inspectors'], '/', agg['all_inspectors'], 'consensus', sum(f['status'] == 'consensus' for f in agg['findings']),
          'single', sum(f['status'] == 'single' for f in agg['findings']), 'under_covered', len(agg['under_covered']))
    for iid, v in agg['inspectors'].items():
        if not v['valid']:
            print('  INVALID', iid, v['problems'][:3])
