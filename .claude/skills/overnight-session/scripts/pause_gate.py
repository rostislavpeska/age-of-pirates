"""Validate a no-useful-work pause against the existing status audit snapshot.
Audit: 2026-10-13-codex-roof-pattern-44. Does not control the automation API.
"""
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def evaluate(review, now=None):
    now = now or datetime.now(timezone.utc)
    errors, runnable = [], []
    try:
        stamp = datetime.fromisoformat(review['reviewed_at'].replace('Z', '+00:00'))
        age = (now - stamp).total_seconds()
        if not 0 <= age <= 900:
            errors.append('Queue review is stale or future-dated')
    except (KeyError, ValueError, TypeError):
        errors.append('Queue review needs an explicit timezone-aware timestamp')
    expected, rows = review.get('expected_task_ids'), review.get('tasks')
    if not isinstance(expected, list) or not expected or any(not isinstance(x, str) or not x for x in expected):
        return {'can_pause': False, 'errors': errors + ['Expected authorized task IDs missing'], 'runnable': []}
    if len(set(expected)) != len(expected):
        errors.append('Duplicate expected task IDs')
    if not isinstance(rows, list) or any(not isinstance(x, dict) for x in rows):
        return {'can_pause': False, 'errors': errors + ['Task accounting missing'], 'runnable': []}
    ids = [x.get('id') for x in rows]
    if any(not isinstance(x, str) for x in ids) or sorted(x for x in ids if isinstance(x, str)) != sorted(expected):
        errors.append('Missing, extra or duplicate task accounting')
    for row in rows:
        identity, state = row.get('id'), row.get('state')
        if not row.get('evidence'):
            errors.append(f'{identity}: missing evidence')
        if state in ('ready', 'running'):
            runnable.append(identity)
        elif state == 'blocked':
            for field in ('blocked_stage', 'reason', 'unblocks'):
                if not isinstance(row.get(field), str) or not row[field].strip():
                    errors.append(f'{identity}: missing {field}')
        elif state != 'done':
            errors.append(f'{identity}: unknown state')
    return {'can_pause': not errors and not runnable, 'errors': errors, 'runnable': runnable}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--status', required=True)
    args = parser.parse_args()
    try:
        status = json.loads(Path(args.status).read_text(encoding='utf-8-sig'))
        result = evaluate(status.get('pause_review', {}))
    except (OSError, ValueError, TypeError, AttributeError) as exc:
        result = {'can_pause': False, 'errors': [str(exc)], 'runnable': []}
    print(json.dumps(result))
    return 0 if result['can_pause'] else 2


if __name__ == '__main__':
    raise SystemExit(main())
