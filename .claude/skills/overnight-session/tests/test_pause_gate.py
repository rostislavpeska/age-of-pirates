"""Regression for INC-305 follow-on: local metadata hold must not stop all work."""
import importlib.util
from datetime import datetime, timezone
from pathlib import Path

spec = importlib.util.spec_from_file_location('pause_gate', Path(__file__).parents[1] / 'scripts/pause_gate.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
NOW = datetime(2026, 10, 13, 12, tzinfo=timezone.utc)


def review(second='ready'):
    return {'reviewed_at': NOW.isoformat(), 'expected_task_ids': ['archive', 'forensics'], 'tasks': [
        {'id': 'archive', 'state': 'blocked', 'evidence': 'INC-305', 'blocked_stage': 'publish',
         'reason': 'immutable metadata', 'unblocks': 'specific owner exception'},
        {'id': 'forensics', 'state': second, 'evidence': 'pinned source package'}]}


def test_local_blocker_does_not_hide_ready_independent_work():
    result = gate.evaluate(review(), NOW)
    assert not result['can_pause'] and result['runnable'] == ['forensics']


def test_all_accounted_done_or_blocked_permits_pause():
    assert gate.evaluate(review('done'), NOW)['can_pause']


def test_missing_duplicate_unknown_stale_and_unexplained_refuse_pause():
    cases = []
    missing = review('done'); missing['tasks'].pop(); cases.append(missing)
    duplicate = review('done'); duplicate['tasks'].append(duplicate['tasks'][0]); cases.append(duplicate)
    cases.append(review('unknown'))
    stale = review('done'); stale['reviewed_at'] = '2026-10-13T10:00:00Z'; cases.append(stale)
    naive = review('done'); naive['reviewed_at'] = '2026-10-13T12:00:00'; cases.append(naive)
    unexplained = review('done'); del unexplained['tasks'][0]['unblocks']; cases.append(unexplained)
    for case in cases:
        assert not gate.evaluate(case, NOW)['can_pause']
