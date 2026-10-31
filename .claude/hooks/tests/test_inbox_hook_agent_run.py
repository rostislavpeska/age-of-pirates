"""Regression for the live finding of 2026-09-29 23:20: inside a workflow agent, PostToolUse carries only agent_id and
the SESSION transcript_path (only SubagentStop carries the agent's own transcript). The hook must find the agent's
run under <session>/subagents/workflows/<run>/agent-<id>.jsonl, deliver a note exactly once, and cost nothing after.
"""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

HOOK = Path(__file__).resolve().parents[1] / 'inbox_hook.py'
sys.path.append(str(HOOK.parents[2] / 'scripts' / 'tools'))
import local_env  # noqa: E402
ENGINE = Path(os.environ.get('AOP_TASKS_DIR_SRC') or local_env.value('AOP_TASKS_DIR') or HOOK.parents[2] / 'no-engine')


@pytest.fixture()
def world(tmp_path):
    if not (ENGINE / 'inbox.py').exists():
        pytest.skip('task engine (inbox.py) not on this machine')
    td = tmp_path / 'tasks'
    td.mkdir()
    shutil.copy(ENGINE / 'inbox.py', td / 'inbox.py')
    sess = tmp_path / 'session-1234'
    run, agent = 'wf_test-run', 'a0123456789abcdef'
    (sess / 'subagents' / 'workflows' / run).mkdir(parents=True)
    (sess / 'subagents' / 'workflows' / run / f'agent-{agent}.jsonl').write_text('{}\n')
    sys.path.insert(0, str(td))
    try:
        import importlib
        import inbox as ib
        importlib.reload(ib)
        root = td / 'inbox'
        root.mkdir()
        (root / 'runs.json').write_text(json.dumps({run: 'KTC-900'}))
        ib.note(root, 'KTC-900', 'say KIWI', 'coordinator')
    finally:
        sys.path.pop(0)
    return td, sess, agent


def call(td, sess, agent, event='PostToolUse'):
    inp = {'hook_event_name': event, 'tool_name': 'Bash', 'agent_id': agent,
           'transcript_path': str(sess) + '.jsonl'}
    env = dict(os.environ, AOP_TASKS_DIR=str(td))
    return subprocess.run([sys.executable, str(HOOK)], input=json.dumps(inp).encode(), capture_output=True, env=env)


def test_agent_only_input_delivers_once_then_nothing(world):
    td, sess, agent = world
    r1 = call(td, sess, agent)
    assert r1.returncode == 0
    out = json.loads(r1.stdout)
    assert 'say KIWI' in out['hookSpecificOutput']['additionalContext']
    r2 = call(td, sess, agent)
    assert r2.returncode == 0 and r2.stdout == b''          # zero tokens once read
    cache = (td / 'inbox' / 'agents.cache').read_text()
    assert f'{agent} wf_test-run' in cache


def test_unbound_agent_costs_nothing_and_is_cached(world):
    td, sess, _agent = world
    r = call(td, sess, 'afffffffffffffff0')                 # no transcript for it: not bound
    assert r.returncode == 0 and r.stdout == b''
    assert 'afffffffffffffff0 ' in (td / 'inbox' / 'agents.cache').read_text()


def test_bad_input_fails_open(world):
    td, _sess, _agent = world
    env = dict(os.environ, AOP_TASKS_DIR=str(td))
    r = subprocess.run([sys.executable, str(HOOK)], input=b'{"agent_id": "x", "transcript_path": ', capture_output=True, env=env)
    assert r.returncode == 0 and r.stdout == b''
