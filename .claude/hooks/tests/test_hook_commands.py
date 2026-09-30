"""The exact hook command strings (settings_entries.json for Claude, .codex/hooks.json for Codex) run as the harness
runs them, plus harness_status.py.

Run: python -m pytest .claude/hooks/tests/test_hook_commands.py -q
Claude commands run through Git Bash (what Claude Code uses on Windows); skipped when it is not installed. Everything
works on temporary copies: no real tasks folder, log or ledger is written.
"""
import importlib.util
import json
import os
import shutil
import statistics
import subprocess
import sys
import time
from pathlib import Path

import pytest

HOOKS = Path(__file__).resolve().parents[1]
REPO = HOOKS.parent.parent
ENTRIES = json.loads((HOOKS / 'settings_entries.json').read_text(encoding='utf-8'))
CODEX = json.loads((REPO / '.codex' / 'hooks.json').read_text(encoding='utf-8'))
ENGINE = Path.home() / 'Documents' / 'WORKSPACE' / 'korean-buildings-blender' / 'research' / 'Texturing_11' / \
    'Claude_CP2' / 'tasks'
RUN, TASK = 'wf_cmdtest0-001', 'T-1'


def cmd(event):
    return ENTRIES['hooks'][event][0]['hooks'][0]['command']


def git_bash():
    for c in (os.environ.get('CLAUDE_CODE_GIT_BASH_PATH'), r'C:\Program Files\Git\bin\bash.exe',
              r'C:\Program Files (x86)\Git\bin\bash.exe'):
        if c and Path(c).is_file():
            return c
    pytest.skip('Git Bash not installed')


def payload(event='PostToolUse', agent='a1', run=RUN):
    p = {'session_id': 'sess', 'hook_event_name': event, 'agent_id': agent, 'cwd': str(REPO),
         'transcript_path': 'C:\\x\\.claude\\projects\\p\\sess\\subagents\\workflows\\%s\\agent-%s.jsonl' % (run, agent)}
    if event == 'PostToolUse':
        p.update({'tool_name': 'Bash', 'tool_input': {'command': 'ls'}, 'tool_response': {'stdout': ''}})
    return json.dumps(p).encode()


@pytest.fixture
def eng(tmp_path):
    """a temp task engine (inbox.py copied from the real one) with RUN bound to TASK"""
    if not (ENGINE / 'inbox.py').is_file():
        pytest.skip('task engine not on this machine')
    td = tmp_path / 'tasks'
    td.mkdir()
    shutil.copy(ENGINE / 'inbox.py', td / 'inbox.py')
    sys.path.insert(0, str(td))
    try:
        spec = importlib.util.spec_from_file_location('inbox_cmdtest', td / 'inbox.py')
        ib = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(ib)
    finally:
        sys.path.remove(str(td))
    ib.bind_run(td / 'inbox', TASK, RUN)
    return type('Eng', (), {'dir': td, 'ib': ib, 'root': td / 'inbox'})


def bash_run(command, data, env_extra, cwd=None):
    env = dict(os.environ)
    env.update(env_extra)
    t0 = time.perf_counter()
    p = subprocess.run([git_bash(), '-c', command], input=data, capture_output=True, env=env, cwd=cwd, timeout=60)
    p.secs = time.perf_counter() - t0
    return p


def stub_project(tmp_path, body=None):
    """a project dir whose inbox_hook.py only records that Python ran"""
    proj = tmp_path / 'proj'
    (proj / '.claude' / 'hooks').mkdir(parents=True)
    marker = tmp_path / 'python_ran'
    if body is None:
        body = 'import sys\nsys.stdin.buffer.read()\nopen(%r, "a").write("x")\n' % str(marker)
    (proj / '.claude' / 'hooks' / 'inbox_hook.py').write_text(body, encoding='utf-8')
    return proj, marker


# ------------------------------------------------------------------------------------------ hole: fails closed on a missing script
def test_plain_python_on_a_missing_script_exits_2():
    """why the guard exists: exit 2 would block every SubagentStop and feed stderr to the model on every call"""
    p = subprocess.run([sys.executable, 'Z:/no/such/inbox_hook.py'], input=b'{}', capture_output=True)
    assert p.returncode == 2 and p.stderr


@pytest.mark.parametrize('event', ['PostToolUse', 'SubagentStop'])
def test_inbox_command_missing_script_fails_open(tmp_path, eng, event):
    empty = tmp_path / 'fresh-clone'
    empty.mkdir()
    eng.ib.note(eng.root, TASK, 'x')
    p = bash_run(cmd(event), payload(event), {'CLAUDE_PROJECT_DIR': str(empty), 'AOP_TASKS_DIR': str(eng.dir)})
    assert (p.returncode, p.stdout, p.stderr) == (0, b'', b'')


def test_gate_command_missing_script_fails_open(tmp_path):
    empty = tmp_path / 'fresh-clone'
    empty.mkdir()
    p = bash_run(cmd('PreToolUse'), b'{"tool_name":"Workflow"}', {'CLAUDE_PROJECT_DIR': str(empty)})
    assert (p.returncode, p.stdout, p.stderr) == (0, b'', b'')


# ------------------------------------------------------------------------------------------ hole: every tool call slower
def test_inbox_command_starts_python_only_when_something_is_bound(tmp_path):
    proj, marker = stub_project(tmp_path)
    td = tmp_path / 'tasks'
    (td / 'inbox').mkdir(parents=True)
    env = {'CLAUDE_PROJECT_DIR': str(proj), 'AOP_TASKS_DIR': str(td)}
    assert bash_run(cmd('PostToolUse'), payload(), env).returncode == 0 and not marker.exists()      # no runs.json
    (td / 'inbox' / 'runs.json').write_text('{}\n', encoding='utf-8')
    assert bash_run(cmd('PostToolUse'), payload(), env).returncode == 0 and not marker.exists()      # nothing bound
    (td / 'inbox' / 'runs.json').write_text('{"%s": "%s"}\n' % (RUN, TASK), encoding='utf-8')
    assert bash_run(cmd('PostToolUse'), payload(), env).returncode == 0 and marker.exists()          # bound: Python


def test_unbound_path_costs_the_bash_start_only(tmp_path):
    """wall clock of the nothing-bound path stays at the bash floor (no Python start: ~0.2-0.6 s on this PC)"""
    proj, _m = stub_project(tmp_path)
    env = {'CLAUDE_PROJECT_DIR': str(proj), 'AOP_TASKS_DIR': str(tmp_path / 'none')}
    big = payload()[:-1] + b', "pad": "' + b'a' * 200000 + b'"}'
    floor = statistics.median(bash_run('exit 0', big, env).secs for _ in range(5))
    ours = statistics.median(bash_run(cmd('PostToolUse'), big, env).secs for _ in range(5))
    py = statistics.median(bash_run('python -c pass', big, env).secs for _ in range(3))
    assert ours < floor + 0.12, (ours, floor, py)
    assert ours < py, (ours, py)


# ------------------------------------------------------------------------------------------ the real hooks through the commands
def test_inbox_command_delivers_and_its_exit_2_survives(eng):
    env = {'CLAUDE_PROJECT_DIR': str(REPO), 'AOP_TASKS_DIR': str(eng.dir)}
    assert bash_run(cmd('PostToolUse'), payload(), env).stdout == b''          # empty inbox: nothing
    eng.ib.note(eng.root, TASK, 'Use the 2048 page.', by='owner')
    stop = bash_run(cmd('SubagentStop'), payload('SubagentStop'), env)
    assert stop.returncode == 2 and b'read your inbox' in stop.stderr
    out = bash_run(cmd('PostToolUse'), payload(), env)
    ctx = json.loads(out.stdout)['hookSpecificOutput']['additionalContext']
    assert 'NEW INSTRUCTION from the owner (note 1): Use the 2048 page.' in ctx
    assert bash_run(cmd('PostToolUse'), payload(), env).stdout == b''
    assert bash_run(cmd('SubagentStop'), payload('SubagentStop'), env).returncode == 0


def test_gate_command_denies_through_json(tmp_path):
    (tmp_path / 'projects').mkdir()
    (tmp_path / 'tasks.json').write_text(json.dumps({'tasks': {'KTC-155': {
        'id': 'KTC-155', 'type': 'bug', 'status': 'ready', 'prio': {'band': 'P0'}, 'title': 'Windows fall'}}}),
        encoding='utf-8')
    env = {'CLAUDE_PROJECT_DIR': str(REPO), 'AOP_LAUNCH_GATE_PROJECTS_DIR': str(tmp_path / 'projects'),
           'AOP_LAUNCH_GATE_TASKS': str(tmp_path / 'tasks.json'), 'AOP_HARNESS_LOG': str(tmp_path / 'log.jsonl'),
           'AOP_LAUNCH_GATE_LEDGER': str(tmp_path / 'ledger'), 'AOP_LAUNCH_GATE_OFF_FILE': str(tmp_path / 'OFF')}
    inp = {'session_id': 's1', 'tool_name': 'Workflow', 'tool_input': {
        'script': "export const meta = {name: 'decor', description: 'more decor'}"}}
    p = bash_run(cmd('PreToolUse'), json.dumps(inp).encode(), env, cwd=str(tmp_path))
    o = json.loads(p.stdout)['hookSpecificOutput']
    assert p.returncode == 0 and o['permissionDecision'] == 'deny' and 'KTC-155' in o['permissionDecisionReason']


# ------------------------------------------------------------------------------------------ Codex command (any shell)
def codex_cmd(event):
    return CODEX['hooks'][event][0]['hooks'][0]['command']


def test_codex_command_outside_the_repo_fails_open(tmp_path, eng):
    eng.ib.note(eng.root, TASK, 'x')
    env = dict(os.environ, AOP_TASKS_DIR=str(eng.dir))
    for ev in ('PostToolUse', 'SubagentStop'):
        p = subprocess.run(codex_cmd(ev), shell=True, input=payload(ev), capture_output=True, env=env,
                           cwd=str(tmp_path), timeout=60)
        assert (p.returncode, p.stdout, p.stderr) == (0, b'', b'')


def test_codex_command_at_the_repo_root_works_and_keeps_exit_2(eng):
    env = dict(os.environ, AOP_TASKS_DIR=str(eng.dir))
    eng.ib.note(eng.root, TASK, 'z')
    stop = subprocess.run(codex_cmd('SubagentStop'), shell=True, input=payload('SubagentStop'), capture_output=True,
                          env=env, cwd=str(REPO), timeout=60)
    assert stop.returncode == 2 and b'read your inbox' in stop.stderr
    post = subprocess.run(codex_cmd('PostToolUse'), shell=True, input=payload(), capture_output=True, env=env,
                          cwd=str(REPO), timeout=60)
    assert 'note 1' in json.loads(post.stdout)['hookSpecificOutput']['additionalContext']


# ------------------------------------------------------------------------------------------ harness_status
def load_status():
    spec = importlib.util.spec_from_file_location('harness_status_under_test', HOOKS / 'harness_status.py')
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def test_merge_keeps_existing_hooks_and_is_idempotent():
    hs = load_status()
    cur = json.loads((REPO / '.claude' / 'settings.json').read_text(encoding='utf-8'))
    m = hs.merged(cur, ENTRIES)
    assert m['hooks']['PostToolUse'][0] == cur['hooks']['PostToolUse'][0]          # the existing entry, untouched
    assert all(hs.registration(m, ENTRIES).values())
    assert hs.merged(m, ENTRIES) == m
    for k in cur:
        if k != 'hooks':
            assert m[k] == cur[k]


def test_status_reports_not_live_until_registered_and_seen(tmp_path, monkeypatch):
    hs = load_status()
    log = tmp_path / 'log.jsonl'
    monkeypatch.setenv('AOP_HARNESS_LOG', str(log))
    sp = tmp_path / 'settings.json'
    sp.write_text(json.dumps({'hooks': {}}), encoding='utf-8')
    st = hs.status(sp)
    assert st['live'] is False and not any(st['registered'].values())
    sp.write_text(json.dumps(hs.merged({}, ENTRIES)), encoding='utf-8')
    log.write_text('\n'.join(json.dumps(r) for r in [
        {'t': '1', 'hook': 'launch_gate', 'decision': 'allow', 'session_id': 's'},
        {'at': '2', 'src': 'inbox_hook', 'event': 'inbox_delivered', 'key': 'a1', 'agent_id_in_input': True},
    ]) + '\n', encoding='utf-8')
    st = hs.status(sp)
    assert all(st['registered'].values()) and st['gate_seen_live'] == '1' and st['inbox_seen_live'] is None
    with open(log, 'a', encoding='utf-8') as f:
        f.write(json.dumps({'at': '3', 'src': 'inbox_hook', 'event': 'inbox_delivered', 'key': 'wf_ab-1',
                            'agent_id_in_input': True}) + '\n')
    assert hs.status(sp)['live'] is True


def test_status_counts_idle_approved_work(tmp_path, monkeypatch):
    """INC-002 G3 (KTC-160): approved work that never started is counted from the task store's board
    (meta.board.approved_waiting, written by every tasks.py command): only the entries past their due time"""
    hs = load_status()
    monkeypatch.setenv('AOP_TASKS_DIR', str(tmp_path / 'tasks'))
    monkeypatch.setenv('AOP_HARNESS_LOG', str(tmp_path / 'log.jsonl'))
    assert hs.approved_idle() is None
    (tmp_path / 'tasks').mkdir()
    (tmp_path / 'tasks' / 'tasks.json').write_text(json.dumps({'meta': {'board': {'approved_waiting': [
        {'id': 'KTC-057', 'by': 'D-001 = B', 'since': '2026-09-29T20:11:41Z', 'due': '2026-09-29T21:11:41Z'},
        {'id': 'KTC-200', 'by': 'owner go', 'since': '2099-01-01T00:00:00Z', 'due': '2099-01-01T01:00:00Z'}]}}}),
        encoding='utf-8')
    ai = hs.approved_idle()
    assert ai['count'] == 1 and ai['ids'] == ['KTC-057'] and ai['waiting'] == 2
    sp = tmp_path / 'settings.json'
    sp.write_text(json.dumps({'hooks': {}}), encoding='utf-8')
    st = hs.status(sp)
    assert st['approved_idle']['ids'] == ['KTC-057']
    assert 'approved work idle > 60 min: 1 - KTC-057 (2 approved and waiting' in hs.text(st)


def test_write_proposed_cli(tmp_path):
    out = tmp_path / 'proposed.json'
    p = subprocess.run([sys.executable, str(HOOKS / 'harness_status.py'), '--write-proposed', str(out)],
                       capture_output=True, timeout=60)
    assert p.returncode == 0
    hs = load_status()
    assert all(hs.registration(json.loads(out.read_text(encoding='utf-8')), ENTRIES).values())
