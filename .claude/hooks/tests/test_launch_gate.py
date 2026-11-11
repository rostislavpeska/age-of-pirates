"""Tests for .claude/hooks/launch_gate.py on fake sessions and a fake tasks.json.

Run: python -m pytest .claude/hooks/tests/test_launch_gate.py -q
Nothing here touches the real session, tasks.json or harness_log.jsonl (every path comes from env).
"""
import importlib.util
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

GATE = Path(__file__).resolve().parents[1] / 'launch_gate.py'
SID = '11111111-2222-3333-4444-555555555555'
SLUG = 'C--fake-project'


def load_gate():
    spec = importlib.util.spec_from_file_location('launch_gate_under_test', GATE)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def env(tmp_path, monkeypatch):
    projects = tmp_path / 'projects'
    sess = projects / SLUG / SID
    (sess / 'subagents' / 'workflows').mkdir(parents=True)
    (sess / 'workflows' / 'scripts').mkdir(parents=True)
    vals = {'AOP_LAUNCH_GATE_PROJECTS_DIR': str(projects),
            'AOP_LAUNCH_GATE_TASKS': str(tmp_path / 'tasks.json'),
            'AOP_HARNESS_LOG': str(tmp_path / 'harness_log.jsonl'),
            'AOP_LAUNCH_GATE_OFF_FILE': str(tmp_path / 'LAUNCH_GATE_OFF'),
            'AOP_LAUNCH_GATE_LEDGER': str(tmp_path / 'ledger')}
    for k, v in vals.items():
        monkeypatch.setenv(k, v)
    monkeypatch.delenv('AOP_LAUNCH_GATE', raising=False)
    monkeypatch.delenv('AOP_LAUNCH_GATE_CAP', raising=False)
    monkeypatch.delenv('AOP_LAUNCH_GATE_SCOPE', raising=False)
    write_tasks(tmp_path, [])
    return type('Env', (), {'root': tmp_path, 'projects': projects, 'sess': sess, 'vals': vals,
                            'log': tmp_path / 'harness_log.jsonl', 'ledger': tmp_path / 'ledger' / 'ledger.json'})


def write_tasks(root, tasks):
    (root / 'tasks.json').write_text(json.dumps({'schema': 'korean-tc-tasks/2', 'tasks': {t['id']: t for t in tasks}}),
                                     encoding='utf-8')


def task(tid, band='P0', typ='bug', status='ready', title='a bug', eff_band=None, owner=None):
    t = {'id': tid, 'type': typ, 'status': status, 'title': title, 'prio': {'band': band}}
    if eff_band:
        t['prio']['eff_band'] = eff_band
    if owner is not None:
        t['owner'] = owner
    return t


def touch(p, age_s):
    ts = time.time() - age_s
    os.utime(p, (ts, ts))


def add_run(env, rid, name, age_s=120, record=None, last_age=None, final_line=False, slug=SLUG):
    """a workflow run: journal (+ optional run record), script copy under `slug`"""
    last_age = age_s if last_age is None else last_age
    rdir = env.sess / 'subagents' / 'workflows' / rid
    rdir.mkdir(parents=True)
    lines = [{'type': 'launched'}, {'type': 'started', 'key': 'v2:x', 'agentId': 'a1', 'label': 'x'}]
    if final_line:
        lines.append({'type': 'workflow_result', 'result': {}})
    j = rdir / 'journal.jsonl'
    j.write_text('\n'.join(json.dumps(l) for l in lines) + '\n', encoding='utf-8')
    sdir = env.projects / slug / SID / 'workflows' / 'scripts'
    sdir.mkdir(parents=True, exist_ok=True)
    sc = sdir / ('%s-%s.js' % (name.lower(), rid))
    sc.write_text("export const meta = { name: '%s', description: 'd' }" % name, encoding='utf-8')
    touch(sc, age_s)
    if record:
        rec = env.sess / 'workflows' / (rid + '.json')
        rec.write_text(json.dumps({'runId': rid, 'status': record, 'workflowName': name,
                                   'startTime': int((time.time() - age_s) * 1000), 'script': 'status: running'}),
                       encoding='utf-8')
    touch(j, last_age)
    touch(rdir, last_age)


def add_bg(env, aid, desc, age_s=60, ended=False, shape='background', tool_use_id=None, sess=None):
    sub = (sess or env.sess) / 'subagents'
    sub.mkdir(parents=True, exist_ok=True)
    meta = {'description': desc, 'requestShape': shape}
    if tool_use_id:
        meta['toolUseId'] = tool_use_id
    (sub / ('agent-%s.meta.json' % aid)).write_text(json.dumps(meta), encoding='utf-8')
    tr = sub / ('agent-%s.jsonl' % aid)
    last = {'type': 'assistant', 'message': {'stop_reason': 'end_turn' if ended else 'tool_use'}}
    tr.write_text(json.dumps({'type': 'user', 'message': {}}) + '\n' + json.dumps(last) + '\n', encoding='utf-8')
    touch(tr, age_s)


def wf(name, description='does a thing', resume=None, **extra):
    ti = {'script': "export const meta = {\n  name: '%s',\n  description: '%s',\n}\nexport default 1" % (name, description)}
    if resume:
        ti['resumeFromRunId'] = resume
    ti.update(extra)
    return {'session_id': SID, 'hook_event_name': 'PreToolUse', 'tool_name': 'Workflow', 'tool_input': ti,
            'cwd': '.', 'transcript_path': 'x/%s.jsonl' % SID}


def agent(description, prompt='do it', background=True, tool='Agent', tool_use_id=None, agent_id=None):
    p = {'session_id': SID, 'hook_event_name': 'PreToolUse', 'tool_name': tool,
         'tool_input': {'description': description, 'prompt': prompt, 'run_in_background': background}}
    if tool_use_id:
        p['tool_use_id'] = tool_use_id
    if agent_id:
        p['agent_id'] = agent_id
    return p


def run_hook(env, payload, extra_env=None, args=()):
    e = dict(os.environ)
    e.update(env.vals)
    e.pop('AOP_LAUNCH_GATE', None)
    e.update(extra_env or {})
    data = payload if isinstance(payload, bytes) else json.dumps(payload).encode('utf-8')
    p = subprocess.run([sys.executable, str(GATE), *args], input=data, capture_output=True, env=e, timeout=30)
    return p.returncode, p.stdout.decode('utf-8'), p.stderr.decode('utf-8')


def log_lines(env):
    if not env.log.exists():
        return []
    return [json.loads(l) for l in env.log.read_text(encoding='utf-8').splitlines() if l.strip()]


def rules(res):
    return [v['rule'] for v in res['violations']]


# ------------------------------------------------------------------------------------------ rule A
def test_cap_refuses_at_two_running_workflows(env):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    add_run(env, 'wf_aaaa0002-002', 'job-two')
    res = g.evaluate(wf('job-three'))
    assert res['decision'] == 'deny' and rules(res) == ['A']
    assert 'wf_aaaa0001-001' in res['violations'][0]['text'] and 'job-two' in res['violations'][0]['text']


def test_cap_allows_with_one_running(env):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    assert g.evaluate(wf('job-three'))['decision'] == 'allow'


def test_finished_killed_stale_and_final_runs_do_not_count(env):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'done-job', record='completed')
    add_run(env, 'wf_aaaa0002-002', 'killed-job', record='killed')
    add_run(env, 'wf_aaaa0003-003', 'orphan-job', age_s=7 * 3600)            # no record, silent for 7 h
    add_run(env, 'wf_aaaa0004-004', 'final-job', final_line=True)
    add_run(env, 'wf_aaaa0005-005', 'live-job')
    res = g.evaluate(wf('new-job'))
    assert res['decision'] == 'allow', res
    assert res['facts']['A']['running_workflows'] == ['wf_aaaa0005-005']


def test_long_agent_keeps_run_alive_past_journal_age(env):
    """journal written 5 h ago, an agent transcript in the run dir moved 1 min ago -> running"""
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'long-job', age_s=5 * 3600)
    add_run(env, 'wf_aaaa0002-002', 'other-job', age_s=5.5 * 3600, last_age=5.5 * 3600)
    a = env.sess / 'subagents' / 'workflows' / 'wf_aaaa0002-002' / 'agent-x.jsonl'
    a.write_text('{}\n', encoding='utf-8')
    touch(a, 60)
    assert rules(g.evaluate(wf('new-job'))) == ['A']


def test_running_record_status_counts(env):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'job-one', record='running')
    add_run(env, 'wf_aaaa0002-002', 'job-two')
    assert rules(g.evaluate(wf('job-three'))) == ['A']


def test_background_agents_count_and_ended_ones_do_not(env):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    add_bg(env, 'b1', 'bg worker')
    add_bg(env, 'b2', 'finished worker', ended=True)
    add_bg(env, 'b3', 'silent worker', age_s=3600)
    add_bg(env, 'b4', 'foreground worker', shape='foreground', ended=True)
    res = g.evaluate(agent('another worker'))
    assert rules(res) == ['A']
    assert res['facts']['A']['running_agents'] == ['agent-b1']


@pytest.mark.parametrize('tool,terminal,success,error,followup,matched,ended', [
    ('SubagentHandback', True, True, False, False, True, True),
    ('SubagentHandback', False, True, False, False, True, False),
    ('SubagentHandback', True, False, False, False, True, False),
    ('SubagentHandback', True, True, True, False, True, False),
    ('SubagentHandback', True, True, False, True, True, False),
    ('SubagentHandback', True, True, False, False, False, False),
    ('Read', True, True, False, False, True, False),
])
def test_terminal_handback_releases_only_a_confirmed_finished_agent(
        env, tool, terminal, success, error, followup, matched, ended):
    add_bg(env, 'handback', 'completed or still running')
    path = env.sess / 'subagents' / 'agent-handback.jsonl'
    rows = [
        {'type': 'assistant', 'message': {'stop_reason': None, 'content': [
            {'type': 'tool_use', 'id': 'finish', 'name': tool}]}},
        {'type': 'user', 'toolEndsTurn': terminal, 'message': {'content': [
            {'type': 'tool_result', 'tool_use_id': 'finish' if matched else 'other',
             'is_error': error, 'content': [
                 {'type': 'text', 'text': json.dumps({'success': success})}]}]}},
    ]
    if followup:
        rows.append({'type': 'user', 'message': {'content': 'Continue with a new instruction.'}})
    path.write_text('\n'.join(json.dumps(row) for row in rows), encoding='utf-8')
    g = load_gate()
    assert g._turn_ended(path) is ended
    agents = g.session_agents([env.sess], time.time())
    assert next(a['running'] for a in agents if a['id'] == 'agent-handback') is not ended


def test_read_only_lookup_agent_is_exempt_from_the_cap_and_logged(env):
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    add_run(env, 'wf_aaaa0002-002', 'job-two')
    rc, out, err = run_hook(env, agent('Read-only lookup: find the ddt path', background=False))
    assert (rc, out, err) == (0, '', '')
    last = log_lines(env)[-1]
    assert last['decision'] == 'allow' and last['facts']['A'] == {'exempt': 'read-only lookup'}


def test_lookup_exemption_never_applies_to_workflows(env):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    add_run(env, 'wf_aaaa0002-002', 'job-two')
    assert rules(g.evaluate(wf('job-three', 'read-only lookup of x'))) == ['A']


def test_other_sessions_are_not_counted(env):
    g = load_gate()
    other = env.projects / SLUG / 'other-session' / 'subagents' / 'workflows' / 'wf_bbbb0001-001'
    other.mkdir(parents=True)
    (other / 'journal.jsonl').write_text('{"type":"launched"}\n', encoding='utf-8')
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    assert g.evaluate(wf('job-two'))['decision'] == 'allow'


def test_cap_env(env, monkeypatch):
    g = load_gate()
    monkeypatch.setenv('AOP_LAUNCH_GATE_CAP', '1')
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    assert rules(g.evaluate(wf('job-two'))) == ['A']


# ------------------------------------------------------------------------------------------ rule B
def test_open_p0_bug_blocks_and_lists_ids_and_titles(env):
    g = load_gate()
    write_tasks(env.root, [task('KTC-155', title='Windows fall wrong'), task('KTC-010', band='P1'),
                           task('KTC-011', typ='feature'), task('KTC-012', status='leased'),
                           task('KTC-013', status='done'), task('KTC-014', status='on_hold')])
    res = g.evaluate(wf('texture-job', 'more decoration'))
    assert rules(res) == ['B']
    text = res['violations'][0]['text']
    assert 'KTC-155' in text and 'Windows fall wrong' in text
    for other in ('KTC-010', 'KTC-011', 'KTC-013', 'KTC-014'):
        assert other not in text
    assert res['facts']['B'] == {'open_p0_bugs': ['KTC-155'], 'running_p0': ['KTC-012']}   # leased: qualifies only


def test_launch_naming_the_p0_bug_is_allowed(env):
    g = load_gate()
    write_tasks(env.root, [task('KTC-155'), task('KTC-156')])
    assert g.evaluate(wf('windows-fall', 'task: KTC-155 fix the windows'))['decision'] == 'allow'
    assert g.evaluate(wf('windows-fall', 'P0: ktc-156, the windows'))['decision'] == 'allow'   # any case
    assert g.evaluate(wf('x', 'Task=KTC-0155 zero padded'))['decision'] == 'allow'
    assert g.evaluate(wf('x', 'fix it', args={'task': 'KTC-156'}))['decision'] == 'allow'


def test_launch_naming_a_running_p0_task_is_allowed(env):
    g = load_gate()
    write_tasks(env.root, [task('KTC-155'), task('KTC-129', typ='process', status='in_progress')])
    assert g.evaluate(wf('orchestration', 'task: KTC-129 orchestration'))['decision'] == 'allow'
    assert rules(g.evaluate(wf('orchestration', 'task: KTC-999'))) == ['B']


def test_agent_prompt_counts_for_p0_ids(env):
    g = load_gate()
    write_tasks(env.root, [task('KTC-155')])
    assert g.evaluate(agent('fix windows', prompt='Task: KTC-155 ...'))['decision'] == 'allow'
    assert rules(g.evaluate(agent('fix windows', prompt='no id'))) == ['B']


def test_effective_band_owner_prio_inheritance_and_hold(env):
    g = load_gate()
    write_tasks(env.root, [task('KTC-201', band='P1', eff_band='P0'),               # inherited P0
                           task('KTC-202', band='P2', owner={'prio': 'P0'}),         # owner says P0
                           task('KTC-203', owner={'hold': {'on': True}}),            # owner hold
                           task('KTC-204', band='P0', eff_band='P1')])               # scheduler says P1
    ids = g.evaluate(wf('x'))['facts']['B']['open_p0_bugs']
    assert ids == ['KTC-201', 'KTC-202']


def test_no_open_p0_allows(env):
    g = load_gate()
    write_tasks(env.root, [task('KTC-155', status='in_progress')])
    assert g.evaluate(wf('anything'))['decision'] == 'allow'


# ------------------------------------------------------------------------------------------ rule C
def test_same_name_relaunch_is_refused(env):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'damaged-rebuild-split-P0', age_s=2 * 3600, record='killed')
    res = g.evaluate(wf('damaged-rebuild-split-P0'))
    assert rules(res) == ['C']
    assert "resumeFromRunId: 'wf_aaaa0001-001'" in res['violations'][0]['text']


def test_relaunch_of_a_still_running_run_says_running(env):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    res = g.evaluate(wf('JOB-one'))                                  # case-insensitive name match
    assert rules(res) == ['C'] and 'still RUNNING' in res['violations'][0]['text']


def test_resume_and_fresh_run_are_allowed(env):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'job-one', age_s=3600, record='killed')
    assert g.evaluate(wf('job-one', resume='wf_aaaa0001-001'))['decision'] == 'allow'
    res = g.evaluate(wf('job-one', 'redo; fresh-run: inputs changed, old run is invalid'))
    assert res['decision'] == 'allow' and res['facts']['C']['fresh_run'].startswith('fresh-run:')
    assert g.evaluate(wf('job-one', args={'fresh_run_reason': 'new inputs'}))['decision'] == 'allow'
    assert rules(g.evaluate(wf('job-one', 'fresh-run:'))) == ['C']          # empty reason does not count


def test_old_and_other_named_runs_do_not_block(env):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'job-one', age_s=13 * 3600, record='completed')
    assert g.evaluate(wf('job-one'))['decision'] == 'allow'
    assert g.evaluate(wf('job-two'))['decision'] == 'allow'


def test_script_copy_under_a_sibling_project_slug_is_found(env):
    """the session cwd moved: the script copy sits under another project slug"""
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'moved-job', record='completed', slug='C--fake-project--sub')
    assert rules(g.evaluate(wf('moved-job'))) == ['C']


def test_script_path_launch_is_read(env, tmp_path):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'path-job', record='completed')
    sp = tmp_path / 'path-job.js'
    sp.write_text("export const meta = {\n  name: \"path-job\",\n  description: \"it's \\\"quoted\\\"\",\n}",
                  encoding='utf-8')
    inp = wf('ignored')
    inp['tool_input'] = {'scriptPath': str(sp)}
    res = g.evaluate(inp)
    assert res['launch']['name'] == 'path-job' and res['launch']['description'] == 'it\'s "quoted"'
    assert rules(res) == ['C']


def test_rule_c_does_not_apply_to_agents(env):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'job-one', record='completed')
    assert g.evaluate(agent('job-one'))['decision'] == 'allow'


# ------------------------------------------------------------------------------------------ override + log
def test_env_override_allows_and_logs_what_it_overrode(env):
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    add_run(env, 'wf_aaaa0002-002', 'job-two')
    rc, out, err = run_hook(env, wf('job-one'), {'AOP_LAUNCH_GATE': 'off'})
    assert (rc, out, err) == (0, '', '')
    last = log_lines(env)[-1]
    assert last['decision'] == 'override' and last['override'] == 'env AOP_LAUNCH_GATE=off'
    assert last['rules'] == ['A', 'C'] and last['launch']['name'] == 'job-one' and last['t'].endswith('Z')


def test_file_override(env):
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    add_run(env, 'wf_aaaa0002-002', 'job-two')
    Path(env.vals['AOP_LAUNCH_GATE_OFF_FILE']).write_text('', encoding='utf-8')
    rc, out, _ = run_hook(env, wf('job-three'))
    assert out == '' and log_lines(env)[-1]['override'] == 'file LAUNCH_GATE_OFF'


def test_deny_output_follows_the_hook_contract_and_is_logged(env):
    write_tasks(env.root, [task('KTC-155', title='Windows fall')])
    rc, out, err = run_hook(env, wf('decor-job'))
    assert rc == 0 and err == ''
    o = json.loads(out)['hookSpecificOutput']
    assert o['hookEventName'] == 'PreToolUse' and o['permissionDecision'] == 'deny'
    assert 'KTC-155' in o['permissionDecisionReason'] and 'Windows fall' in o['permissionDecisionReason']
    assert 'LAUNCH_GATE_OFF' not in o['permissionDecisionReason']        # the model is not told how to bypass
    last = log_lines(env)[-1]
    assert last['decision'] == 'deny' and last['rules'] == ['B'] and last['launch']['name'] == 'decor-job'


def test_allow_prints_nothing_and_logs(env):
    rc, out, err = run_hook(env, wf('quiet-job'))
    assert (rc, out, err) == (0, '', '')
    assert log_lines(env)[-1]['decision'] == 'allow'


def test_other_tools_pass_silently_without_log(env):
    rc, out, err = run_hook(env, {'session_id': SID, 'tool_name': 'Bash', 'tool_input': {'command': 'ls'}})
    assert (rc, out, err) == (0, '', '') and log_lines(env) == []


# ------------------------------------------------------------------------------------------ fail open
@pytest.mark.parametrize('payload', [b'not json {', b'', b'[1, 2]', json.dumps({'tool_name': 'Workflow'}).encode(),
                                     json.dumps({'tool_name': 'Workflow', 'tool_input': {'scriptPath': 'Z:/nope.js'},
                                                 'session_id': SID}).encode()])
def test_malformed_input_allows_and_logs(env, payload):
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    add_run(env, 'wf_aaaa0002-002', 'job-two')
    rc, out, err = run_hook(env, payload)
    assert (rc, out, err) == (0, '', '')
    last = log_lines(env)[-1]
    assert last['decision'] == 'error-allow' and last['errors']


def test_broken_tasks_json_skips_rule_b_only(env):
    add_run(env, 'wf_aaaa0001-001', 'job-one', record='completed')
    (env.root / 'tasks.json').write_text('{broken', encoding='utf-8')
    rc, out, _ = run_hook(env, wf('job-one'))
    assert json.loads(out)['hookSpecificOutput']['permissionDecision'] == 'deny'     # rule C still holds
    last = log_lines(env)[-1]
    assert last['rules'] == ['C'] and any(e.startswith('rule B') for e in last['errors'])


def test_missing_session_skips_a_and_c(env):
    g = load_gate()
    inp = wf('job-one')
    inp.pop('session_id')
    inp.pop('transcript_path')
    res = g.evaluate(inp)
    assert res['decision'] == 'allow' and any(e.startswith('session') for e in res['errors'])


def test_unwritable_log_still_allows(env):
    rc, out, err = run_hook(env, wf('quiet-job'), {'AOP_HARNESS_LOG': str(env.root)})   # a directory
    assert (rc, out, err) == (0, '', '')


# ------------------------------------------------------------------------------------------ timing + dry run
def test_timing_on_a_busy_session(env):
    g = load_gate()
    write_tasks(env.root, [task('KTC-%03d' % i, status='done') for i in range(160)] + [task('KTC-500')])
    for i in range(60):
        add_run(env, 'wf_%08x-%03d' % (i, i), 'job-%d' % i, age_s=3600 * (i % 30), record='completed' if i % 3 else None)
    for i in range(40):
        add_bg(env, 'bg%d' % i, 'bg', age_s=7200, ended=True)
    t = time.perf_counter()
    for _ in range(5):
        g.evaluate(wf('new-job', 'task: KTC-500'))
    per_call_ms = (time.perf_counter() - t) * 1000 / 5
    assert per_call_ms < 150, per_call_ms
    t = time.perf_counter()
    rc, out, _ = run_hook(env, wf('new-job', 'task: KTC-500'))
    total_ms = (time.perf_counter() - t) * 1000
    assert rc == 0 and total_ms < 3000, total_ms            # dominated by interpreter start on Windows
    assert log_lines(env)[-1]['ms'] < 150


def test_dry_run_prints_evaluation_and_logs_nothing(env):
    write_tasks(env.root, [task('KTC-155')])
    rc, out, err = run_hook(env, wf('x'), args=('--dry-run',))
    res = json.loads(out)
    assert res['decision'] == 'deny' and 'reason' in res and log_lines(env) == []


# ------------------------------------------------------------------------------------------ reservations (hole: cap bypass)
def _parallel(env, payloads):
    import concurrent.futures as cf
    with cf.ThreadPoolExecutor(len(payloads)) as ex:
        outs = list(ex.map(lambda p: run_hook(env, p), payloads))
    return sorted('deny' if '"deny"' in out else 'allow' for _rc, out, _err in outs)


def test_parallel_background_agents_get_one_slot(env):
    """1 workflow running, 3 background Agent calls in one message: the ledger lock serialises them"""
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    got = _parallel(env, [agent('worker %d' % i, tool_use_id='toolu_%d' % i) for i in range(3)])
    assert got == ['allow', 'deny', 'deny']
    led = json.loads(env.ledger.read_text(encoding='utf-8'))['entries']
    assert len(led) == 1 and led[0]['kind'] == 'reservation' and led[0]['tool_use_id'].startswith('toolu_')


def test_parallel_workflows_get_one_slot(env):
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    assert _parallel(env, [wf('job-%s' % c) for c in 'abc']) == ['allow', 'deny', 'deny']


def test_foreground_agents_count(env):
    """foreground calls count too (decision): 5 launches with 1 workflow running -> 1 allowed"""
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    got = [run_hook(env, agent('fg %d' % i, background=False, tool_use_id='toolu_f%d' % i))[1] for i in range(5)]
    assert ['deny' if '"deny"' in o else 'allow' for o in got] == ['allow', 'deny', 'deny', 'deny', 'deny']


def test_reservation_is_met_by_its_agent_and_not_double_counted(env):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    assert run_hook(env, agent('worker', tool_use_id='toolu_A'))[1] == ''
    add_bg(env, 'real', 'worker', tool_use_id='toolu_A')                  # the real agent appears, running
    res = g.evaluate(agent('another', tool_use_id='toolu_B'), reserve=True)
    assert rules(res) == ['A']
    assert res['facts']['A']['running_agents'] == ['agent-real'] and res['facts']['A']['pending'] == []
    add_bg(env, 'real', 'worker', tool_use_id='toolu_A', ended=True)       # it finished: the slot is free
    assert g.evaluate(agent('another', tool_use_id='toolu_B'))['decision'] == 'allow'


def test_workflow_reservation_is_met_by_its_run(env):
    g = load_gate()
    assert run_hook(env, wf('job-new'))[1] == ''
    add_run(env, 'wf_aaaa0009-009', 'job-new', age_s=5)
    res = g.evaluate(wf('job-x'))
    assert res['facts']['A']['pending'] == [] and res['facts']['A']['running_workflows'] == ['wf_aaaa0009-009']


def test_reservation_expires(env):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    assert run_hook(env, agent('worker', tool_use_id='toolu_A'))[1] == ''
    assert rules(g.evaluate(agent('x'))) == ['A']
    later = time.time() + g.RES_TTL_S + 5
    assert g.evaluate(agent('x'), now=later)['facts']['A']['pending'] == []


def test_inner_launch_is_part_of_its_job(env):
    """an Agent call from inside a running job (agent_id) is not a new job: no cap, no reservation"""
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    add_run(env, 'wf_aaaa0002-002', 'job-two')
    rc, out, err = run_hook(env, agent('helper', agent_id='a123', tool_use_id='toolu_i'))
    assert (rc, out, err) == (0, '', '')
    assert log_lines(env)[-1]['facts']['A']['exempt'].startswith('inside a running job')
    assert not env.ledger.exists()


def test_ledger_lock_timeout_fails_open(env, monkeypatch):
    g = load_gate()
    monkeypatch.setattr(g, 'LOCK_WAIT_S', 0.1)
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    env.ledger.parent.mkdir(parents=True)
    (env.ledger.parent / '.lock').write_text('1 1', encoding='utf-8')     # a live holder
    res = g.evaluate(agent('worker'), reserve=True)
    assert res['decision'] == 'allow' and any('TimeoutError' in e for e in res['errors'])
    assert 'reserved' not in res and 'A' in res['facts']


def test_corrupt_ledger_is_ignored_and_rewritten(env):
    g = load_gate()
    env.ledger.parent.mkdir(parents=True)
    env.ledger.write_text('{broken', encoding='utf-8')
    res = g.evaluate(agent('worker'), reserve=True)
    assert res['decision'] == 'allow' and any(e.startswith('ledger') for e in res['errors'])
    assert len(json.loads(env.ledger.read_text(encoding='utf-8'))['entries']) == 1


def test_dry_run_reserves_nothing(env):
    run_hook(env, wf('x'), args=('--dry-run',))
    assert not env.ledger.exists()


# ------------------------------------------------------------------------------------------ hole: rule B lexical, rule C rename
def test_a_mention_is_not_a_declaration(env):
    g = load_gate()
    write_tasks(env.root, [task('KTC-001')])
    res = g.evaluate(agent('polish README, not KTC-1'))
    assert rules(res) == ['B'] and 'mentioned but not declared' in res['violations'][0]['text']
    assert g.evaluate(agent('polish README', prompt='task: KTC-1'))['decision'] == 'allow'


def test_renamed_copy_of_a_recent_run_is_rule_c(env):
    g = load_gate()
    body = '\n'.join("  await agent('step %d: do the thing number %d')" % (i, i) for i in range(20))
    add_run(env, 'wf_aaaa0001-001', 'job-one', record='killed')
    sc = next((env.sess / 'workflows' / 'scripts').glob('job-one-*.js'))
    sc.write_text("export const meta = {\n  name: 'job-one',\n  description: 'd',\n}\n" + body, encoding='utf-8')
    inp = wf('job-one-b')
    inp['tool_input']['script'] = "export const meta = {\n  name: 'job-one-b',\n  description: 'x',\n}\n" + body
    res = g.evaluate(inp)
    assert rules(res) == ['C'] and 'renamed copy' in res['violations'][0]['text']
    assert res['facts']['C']['similar_runs'][0][0] == 'wf_aaaa0001-001'
    inp['tool_input']['script'] = inp['tool_input']['script'].replace("description: 'x'",
                                                                      "description: 'fresh-run: new inputs'")
    assert g.evaluate(inp)['decision'] == 'allow'
    inp['tool_input']['script'] = "export const meta = {\n  name: 'job-one-b',\n  description: 'x',\n}\n" + \
        '\n'.join("  await agent('other work %d')" % i for i in range(20))
    assert g.evaluate(inp)['decision'] == 'allow'


# ------------------------------------------------------------------------------------------ hole: other sessions, Codex
def _other_session_run(env, slug, sid, rid, name):
    d = env.projects / slug / sid
    (d / 'subagents' / 'workflows' / rid).mkdir(parents=True)
    (d / 'subagents' / 'workflows' / rid / 'journal.jsonl').write_text('{"type":"launched"}\n', encoding='utf-8')
    (d / 'workflows' / 'scripts').mkdir(parents=True)
    (d / 'workflows' / 'scripts' / ('%s-%s.js' % (name, rid))).write_text('x', encoding='utf-8')
    return d


def test_in_scope_other_session_counts_out_of_scope_does_not(env, monkeypatch):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    _other_session_run(env, 'C--Users-x-mods-local-age-of-pirates', 'sess-two', 'wf_bbbb0001-001', 'their-job')
    _other_session_run(env, 'C--Users-x-WORKSPACE-ai-founders-bot', 'sess-three', 'wf_cccc0001-001', 'unrelated')
    res = g.evaluate(wf('job-two'))
    assert rules(res) == ['A'] and 'session sess-two' in res['violations'][0]['text']
    assert 'wf_cccc0001-001' not in res['violations'][0]['text']
    monkeypatch.setenv('AOP_LAUNCH_GATE_SCOPE', 'ai-founders')
    assert 'wf_cccc0001-001' in g.evaluate(wf('job-two'))['facts']['A']['running_workflows']


def _claim(env, *args):
    e = dict(os.environ)
    e.update(env.vals)
    e['AOP_LAUNCH_GATE_SCOPE'] = 'fake-project'     # a claim has no own session: the fake slug must be in scope
    p = subprocess.run([sys.executable, str(GATE), *args], capture_output=True, env=e, timeout=30)
    return p.returncode, json.loads(p.stdout.decode('utf-8'))


def test_codex_claim_takes_a_slot_and_the_hook_counts_it(env):
    g = load_gate()
    add_run(env, 'wf_aaaa0001-001', 'job-one')
    rc, out = _claim(env, '--claim', 'codex texture pass', '--by', 'codex')
    assert rc == 0 and out['claim_id'].startswith('c-')
    res = g.evaluate(wf('job-two'))
    assert rules(res) == ['A'] and 'claim by codex' in res['violations'][0]['text']
    rc2, out2 = _claim(env, '--claim', 'second codex job', '--by', 'codex')
    assert rc2 == 3 and out2['decision'] == 'deny'
    assert _claim(env, '--release', out['claim_id'])[0] == 0
    assert g.evaluate(wf('job-two'))['decision'] == 'allow'
    assert [l['decision'] for l in log_lines(env)] == ['allow', 'deny', 'release']


def test_codex_claim_obeys_p0_first(env):
    write_tasks(env.root, [task('KTC-155')])
    assert _claim(env, '--claim', 'decor', '--by', 'codex')[0] == 3
    rc, out = _claim(env, '--claim', 'windows', '--by', 'codex', '--task', 'KTC-155')
    assert rc == 0 and out['claim_id']
