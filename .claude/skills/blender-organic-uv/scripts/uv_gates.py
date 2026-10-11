"""Check uv_eval runs against a gate profile derived from shipped reference units (host Python, standard library).

    python uv_gates.py --profile PROFILE.json --run page=RUN_DIR [--run body=RUN_DIR ...] [--out ABS_GATES.json]

A profile (schema blender-organic-uv/gates/1) lists checks; each names the run it reads ("page" = every mesh on the
texture page, "body" = the body alone, the fair comparison with a reference body that owns its page), a metric path
into that run's metrics.json, a hard limit and a target ({"min": x} and/or {"max": y}; null = none). A hard limit that
fails, or a metric that is missing (status MISSING), fails the gate; a missed target is reported but does not fail.
Numbers are compared at full precision: no tolerance, no rounding.

Exit 0 = every hard limit passes, 1 = a hard limit failed or a metric is missing, 2 = setup error.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import uvenv  # noqa: E402

SCHEMA = 'blender-organic-uv/gates/1'


def get(d, path):
    for k in path.split('.'):
        if not isinstance(d, dict) or k not in d:
            return None
        d = d[k]
    return d


def judge(value, limit):
    """True/False against {"min", "max"}; None when there is no limit."""
    if not limit:
        return None
    if value is None or isinstance(value, (str, bool)):
        return False
    lo, hi = limit.get('min'), limit.get('max')
    return (lo is None or value >= lo) and (hi is None or value <= hi)


def fmt_limit(limit):
    if not limit:
        return '-'
    lo, hi = limit.get('min'), limit.get('max')
    if lo is not None and hi is not None:
        return '%g..%g' % (lo, hi)
    return ('>= %g' % lo) if lo is not None else ('<= %g' % hi)


def evaluate(profile, runs):
    if profile.get('schema') != SCHEMA:
        raise uvenv.SetupError('profile schema must be %s' % SCHEMA)
    rows, hard_ok = [], True
    for c in profile['checks']:
        run = c.get('run', 'page')
        M = runs.get(run)
        value = get(M, c['metric']) if M is not None else None
        hard, target = c.get('hard'), c.get('target')
        hp, tp = judge(value, hard), judge(value, target)
        if value is None:
            status = 'MISSING' if hard else 'n/a'
            if hard:
                hard_ok = False
        elif hp is False:
            status = 'FAIL'
            hard_ok = False
        else:
            status = 'PASS' if hp else 'info'
        rows.append({'id': c['id'], 'label': c.get('label', c['id']), 'run': run, 'metric': c['metric'],
                     'value': value, 'hard': hard, 'target': target, 'status': status, 'target_met': tp,
                     'evidence': c.get('evidence', '')})
    missed = [r['id'] for r in rows if r['target_met'] is False]
    return {'schema': SCHEMA, 'profile': profile.get('name'), 'rows': rows, 'hard_pass': hard_ok,
            'targets_missed': missed}


def main(argv=None):
    ap = argparse.ArgumentParser(prog='uv_gates.py', description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--profile', required=True)
    ap.add_argument('--run', action='append', default=[], metavar='NAME=RUN_DIR')
    ap.add_argument('--out')
    a = ap.parse_args(argv)
    profile = uvenv.read_json(a.profile)
    runs, dirs = {}, {}
    for item in a.run:
        if '=' not in item:
            raise uvenv.SetupError('--run NAME=RUN_DIR, got %r' % item)
        name, d = item.split('=', 1)
        runs[name] = uvenv.read_json(os.path.join(d, 'metrics.json'))
        dirs[name] = os.path.abspath(d)
    if not runs:
        raise uvenv.SetupError('give at least one --run')
    res = evaluate(profile, runs)
    res['runs'] = dirs
    for r in res['rows']:
        v = r['value']
        vs = ('%.4f' % v).rstrip('0').rstrip('.') if isinstance(v, float) else str(v)
        print('%-8s %-44s %-5s %-14s hard %-12s target %-12s%s' % (
            r['status'], r['label'][:44], r['run'], vs, fmt_limit(r['hard']), fmt_limit(r['target']),
            '' if r['target_met'] is not False else '  (target missed)'))
    print('HARD %s | targets missed: %s' % ('PASS' if res['hard_pass'] else 'FAIL', res['targets_missed'] or 'none'))
    if a.out:
        print('GATES', uvenv.write_json(uvenv.out_path(a.out, 'gate report'), res))
    return 0 if res['hard_pass'] else 1


if __name__ == '__main__':
    sys.exit(main())
