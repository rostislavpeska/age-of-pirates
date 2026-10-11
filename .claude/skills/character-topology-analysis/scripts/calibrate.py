"""Calibration table of a survey folder (written by survey.py): for every rule, the verdict and the measured values of
each item, grouped by role, and the extremes of the gated numbers over the calibration items. This is the evidence a
threshold change cites (references/calibration.md); it never edits rules.json itself.

    python -I calibrate.py <survey dir> --out calibration_table.json [--roles calibration,reference,control,own]
                           [--md calibration_table.md]

Exit 0. A calibration item that fails a rule outside its recorded defects is printed as CALIBRATION MISMATCH: either
the rule or the implementation is wrong for that reference, and the threshold must not be shipped as it is.
"""
import argparse
import json
import os
import sys

NUMERIC_KEYS = {
    'M4': ['concave_share'], 'M5': ['share_over_30deg'], 'M6': ['p99', 'max'], 'M7': ['p1', 'min'],
    'M8': ['p99', 'max'], 'P1': ['p6_share_of_verts'],
}


def _num(meas, key):
    if isinstance(meas, dict) and isinstance(meas.get(key), (int, float)):
        return float(meas[key])
    return None


def table(survey_dir, roles=None):
    summ = json.load(open(os.path.join(survey_dir, 'summary.json')))
    rows = [r for r in summ if 'error' not in r and (not roles or r.get('role') in roles)]
    out = {}
    for r in rows:
        rr = json.load(open(os.path.join(survey_dir, r['id'], 'rules.json')))
        for rid, res in rr['rules'].items():
            e = out.setdefault(rid, dict(level=res['level'], title=res['title'], threshold=res['threshold'],
                                         scope=res.get('scope'), items={}))
            e['items'][r['id']] = dict(role=r.get('role'), verdict=res['verdict'], measured=res.get('measured'),
                                       recorded_defect=rid in (r.get('recorded_defects') or []))
    for rid, e in out.items():
        ext = {}
        for key in NUMERIC_KEYS.get(rid, []):
            vals = [(sid, _num(it['measured'], key)) for sid, it in e['items'].items() if it['role'] == 'calibration']
            vals = [(s, v) for s, v in vals if v is not None]
            if vals:
                lo = min(vals, key=lambda t: t[1])
                hi = max(vals, key=lambda t: t[1])
                ext[key] = dict(min=lo, max=hi)
        e['calibration_extremes'] = ext
        e['mismatch'] = sorted(sid for sid, it in e['items'].items() if it['role'] == 'calibration'
                               and it['verdict'] == 'FAIL' and e['level'] in ('must', 'should') and not it['recorded_defect'])
        e['controls_failing'] = sorted(sid for sid, it in e['items'].items() if it['role'] == 'control' and it['verdict'] == 'FAIL')
    return out


def to_md(t):
    lines = ['| rule | level | scope | calibration verdicts | controls failing | extremes (calibration) |',
             '| --- | --- | --- | --- | --- | --- |']
    for rid in sorted(t, key=lambda k: (k[0], int(''.join(c for c in k if c.isdigit()) or 0))):
        e = t[rid]
        cal = [it['verdict'] for it in e['items'].values() if it['role'] == 'calibration']
        if not cal or all(v == 'N/A' for v in cal):
            continue
        counts = ', '.join('%s %d' % (v, cal.count(v)) for v in ('PASS', 'FAIL', 'REPORT', 'N/A') if cal.count(v))
        ext = '; '.join('%s %s..%s' % (k, '%s %.4g' % v['min'], '%s %.4g' % v['max']) for k, v in e['calibration_extremes'].items())
        lines.append('| %s | %s | %s | %s | %s | %s |' % (rid, e['level'], e.get('scope'), counts,
                                                       ', '.join(e['controls_failing']) or '-', ext or '-'))
    return '\n'.join(lines) + '\n'


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('survey')
    ap.add_argument('--out', required=True)
    ap.add_argument('--md')
    ap.add_argument('--roles')
    a = ap.parse_args(argv)
    t = table(a.survey, set(a.roles.split(',')) if a.roles else None)
    with open(a.out, 'w') as fh:
        json.dump(t, fh, indent=1)
    if a.md:
        with open(a.md, 'w') as fh:
            fh.write(to_md(t))
    for rid, e in sorted(t.items()):
        if e['mismatch']:
            print('CALIBRATION MISMATCH %s: %s' % (rid, ', '.join(e['mismatch'])))
    print('CALIBRATE', a.out, len(t), 'rules')
    return 0


if __name__ == '__main__':
    sys.exit(main())
