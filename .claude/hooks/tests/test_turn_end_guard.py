"""turn_end_guard.py (the Stop hook) and harness_status.py's background line: a turn does not end quietly while
background work outlives its job (incident INC-027, task KTC-164).

INC-027: a port watchdog ran 32 h after its job; no turn end ever mentioned it. On its first dry run (2026-09-30) this
guard found a second one in the coordinator's session: `until grep -q "^EXIT" .../render_run.log; do sleep 5; done`,
23 h 44 min old (the render had logged "RENDER OK", never "EXIT"). The hook blocks once per item on a watch that
outlived its TTL / task / run and on a raw endless loop of the session, stays silent when clean, never blocks twice
for one item, removes entries of killed watches without a block, and fails open on anything corrupt.

    python -m pytest .claude/hooks/tests/test_turn_end_guard.py -q

Temp task store (AOP_TASKS_DIR), temp harness log; stand-in processes are real (python sleep, Git Bash loops) and
killed in finally. The process scan is off (AOP_TURN_END_SCAN=off) except in the raw-loop tests, which root it at
this test process so nothing of the running session is looked at.
"""
import importlib.util
import io
import json
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

import pytest

HOOKS = Path(__file__).resolve().parents[1]
REPO = HOOKS.parent.parent
SCRIPT = HOOKS / 'turn_end_guard.py'
ENTRIES = json.loads((HOOKS / 'settings_entries.json').read_text(encoding='utf-8'))

spec = importlib.util.spec_from_file_location('turn_end_guard_under_test', SCRIPT)
T = importlib.util.module_from_spec(spec)
spec.loader.exec_module(T)
W = T.W
TASK = 'KTC-900'
STOP_IN = {'session_id': 's1', 'hook_event_name': 'Stop', 'stop_hook_active': False}


def put(td, status='ready'):
    (td / 'tasks.json').write_text(json.dumps({'tasks': {TASK: {'id': TASK, 'status': status, 'lease': None}}}),
                                   encoding='utf-8')


@pytest.fixture
def td(tmp_path, monkeypatch):
    d = tmp_path / 'tasks'
    (d / 'inbox').mkdir(parents=True)
    put(d)
    for k, v in (('AOP_TASKS_DIR', str(d)), ('AOP_HARNESS_LOG', str(tmp_path / 'log.jsonl')),
                 ('AOP_TURN_END_WAIT', '0.3'), ('AOP_TURN_END_SCAN', 'off')):
        monkeypatch.setenv(k, v)
    monkeypatch.delenv('AOP_TURN_END_GUARD', raising=False)
    return d


@pytest.fixture
def proc():
    """a real process standing in for a running watch"""
    p = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(120)'])
    try:
        for _ in range(50):
            c = W.proc_created(p.pid)
            if c:
                break
            time.sleep(0.1)
        yield p.pid, c
    finally:
        if p.poll() is None:
            W.kill_tree(p.pid)
            p.wait(timeout=20)


def entry(td, pid, created, started_ago=60.0, ttl=3 * 3600):
    e = W.new_entry(TASK, None, ttl, 20, {'port_down': 9876}, now=time.time() - started_ago, pid=pid, created=created)
    W.register(e, td / 'watch')
    return e


def run_hook(inp=None, raw=None, env_extra=None):
    env = dict(os.environ)
    env.update(env_extra or {})
    data = raw if raw is not None else json.dumps(inp or STOP_IN).encode()
    return subprocess.run([sys.executable, str(SCRIPT)], input=data, capture_output=True, env=env, timeout=60)


def block_reason(p):
    assert p.returncode == 0, p.stderr
    o = json.loads(p.stdout)
    assert o['decision'] == 'block'
    return o['reason']


def log_events(tmp_path):
    p = tmp_path / 'log.jsonl'
    return [json.loads(x)['event'] for x in p.read_text(encoding='utf-8').splitlines()] if p.exists() else []


# ------------------------------------------------------------------------------------------ W: registered watches
def test_blocks_on_a_watch_past_its_ttl(td, proc):
    """INC-027: a watch alive past its TTL -> 'stop <id> first', with the command that does it"""
    e = entry(td, *proc, started_ago=4 * 3600)
    r = block_reason(run_hook())
    assert f"stop {e['id']} first" in r and 'ttl 3h00m reached' in r and f"watch.py stop {e['id']}" in r
    assert 'INC-027' in r


def test_blocks_on_a_watch_that_outlived_its_task(td, proc):
    e = entry(td, *proc)
    put(td, 'done')
    r = block_reason(run_hook())
    assert f"stop {e['id']} first" in r and f'task {TASK} is done' in r


def test_silent_when_clean(td, proc, tmp_path):
    """no registry, then a watch within its limits: nothing printed, exit 0, no block logged"""
    assert (lambda p: (p.returncode, p.stdout))(run_hook()) == (0, b'')
    entry(td, *proc)
    assert (lambda p: (p.returncode, p.stdout))(run_hook()) == (0, b'')
    assert 'turn_end_block' not in log_events(tmp_path)


def test_never_blocks_twice_for_the_same_item(td, proc, tmp_path):
    """INC-027: one continuation per item - the same stale watch is named once, a new one is named alone"""
    e1 = entry(td, *proc, started_ago=4 * 3600)
    assert e1['id'] in block_reason(run_hook())
    assert run_hook().stdout == b''
    e2 = entry(td, *proc, started_ago=5 * 3600)
    r = block_reason(run_hook())
    assert e2['id'] in r and e1['id'] not in r
    assert run_hook().stdout == b''
    mem = json.loads((td / 'watch' / T.MEMORY).read_text(encoding='utf-8'))
    assert set(mem) == {f"watch:{e1['id']}", f"watch:{e2['id']}"}
    assert log_events(tmp_path).count('turn_end_block') == 2


def test_fails_open_on_a_corrupt_registry(td, proc):
    """INC-027 hook contract: a corrupt entry, memory file, task store or hook input never blocks a turn end and
    never hides a valid stale watch next to it"""
    (td / 'watch').mkdir()
    (td / 'watch' / 'w-badbad.json').write_text('{"id": "w-badbad", "pid": ', encoding='utf-8')
    (td / 'watch' / T.MEMORY).write_text('[not, a, dict', encoding='utf-8')
    (td / 'tasks.json').write_text('{"tasks": {', encoding='utf-8')
    for p in (run_hook(), run_hook(raw=b'\xff\xfe garbage'), run_hook(raw=b'')):
        assert (p.returncode, p.stdout) == (0, b'')
    e = entry(td, *proc, started_ago=4 * 3600)
    assert e['id'] in block_reason(run_hook())


def test_a_registry_that_is_not_a_folder_fails_open(td):
    (td / 'watch').write_text('not a folder', encoding='utf-8')
    p = run_hook()
    assert (p.returncode, p.stdout) == (0, b'')


def test_an_internal_error_fails_open(td, tmp_path, monkeypatch, capsys):
    def boom(*_a, **_k):
        raise RuntimeError('registry exploded')
    monkeypatch.setattr(T.W, 'entries', boom)
    monkeypatch.setattr(sys, 'stdin', io.TextIOWrapper(io.BytesIO(json.dumps(STOP_IN).encode())))
    assert T.main() == 0
    assert capsys.readouterr().out == ''
    assert 'turn_end_error' in log_events(tmp_path)


def test_a_killed_watch_entry_is_removed_without_a_block(td, tmp_path):
    e = entry(td, 99999999, 5, started_ago=4 * 3600)
    assert run_hook().stdout == b''
    assert not (td / 'watch' / f"{e['id']}.json").exists()
    assert 'watch_entry_pruned' in log_events(tmp_path)


def test_a_watch_about_to_exit_gets_its_grace(td, proc):
    """the task just ended and the watch notices within ~5 s: the hook waits instead of blocking"""
    e = entry(td, *proc)
    put(td, 'done')
    f = td / 'watch' / f"{e['id']}.json"
    threading.Timer(0.3, f.unlink).start()
    assert T.watch_items(wait=3) == []


def test_the_off_switch(td, proc):
    entry(td, *proc, started_ago=4 * 3600)
    assert run_hook(env_extra={'AOP_TURN_END_GUARD': 'off'}).stdout == b''


# ------------------------------------------------------------------------------------------ L: raw loops of the session
def git_bash():
    for c in (os.environ.get('CLAUDE_CODE_GIT_BASH_PATH'), r'C:\Program Files\Git\bin\bash.exe',
              r'C:\Program Files (x86)\Git\bin\bash.exe'):
        if c and Path(c).is_file():
            return c
    pytest.skip('Git Bash not installed')


def sweep(tag):
    """kill every process whose command line carries tag: taskkill /T cannot reach what MSYS started through fork +
    exec (timeout's bash is parentless at once), so the fixture finds its own processes by their tag"""
    t = W.proc_table()
    for pid in t:
        if tag in (W.proc_cmdline(pid) or ''):
            W.kill_tree(pid)


@pytest.fixture
def loops():
    """two real Git Bash processes under this test process: an endless loop, and the same loop wrapped in timeout 60.
    Both carry a tag (a bash comment) so that nothing survives the test"""
    tag = 'aop-teg-' + os.urandom(4).hex()
    endless = subprocess.Popen([git_bash(), '-c', f'while true; do sleep 1; done # {tag}'])
    bounded = subprocess.Popen([git_bash(), '-c', f"timeout 60 bash -c 'while true; do sleep 1; done # {tag}'"])
    try:
        yield endless, bounded
    finally:
        for p in (endless, bounded):
            if p.poll() is None:
                W.kill_tree(p.pid)
        for _ in range(3):
            sweep(tag)
            time.sleep(0.3)
        for p in (endless, bounded):
            p.wait(timeout=20)
        left = [pid for pid in W.proc_table() if tag in (W.proc_cmdline(pid) or '')]
        assert left == [], f'test loops left running: {left}'


def _wait_raw(root, timeout=15):
    t_end = time.time() + timeout
    found = []
    while time.time() < t_end:
        found = T.raw_loops(root=root, orphans=False)
        kids = T.descendants(root, W.proc_table())
        if found and len(kids) >= 5:           # both launchers + their bash copies + timeout are up
            time.sleep(0.5)
            return T.raw_loops(root=root, orphans=False)
        time.sleep(0.2)
    return found


def test_a_raw_endless_loop_is_found_and_a_timeout_bound_one_is_not(td, loops):
    """INC-027 (and its 23 h render-wait twin): an endless loop running under the session outside watch.py is one
    item (its Git Bash copies collapse to the top process); the same loop under `timeout 60` is not"""
    endless, bounded = loops
    found = _wait_raw(os.getpid())
    assert [r['pid'] for r in found] == [endless.pid], found
    assert found[0]['hits'][0].startswith('endless while') and found[0]['age'] is not None
    assert bounded.poll() is None


def test_a_raw_loop_blocks_the_turn_end_once(td, loops):
    endless, _bounded = loops
    assert _wait_raw(os.getpid())
    reason, keys = T.evaluate(STOP_IN, scan=True, root=os.getpid(), orphans=False)
    assert reason and f'stop pid {endless.pid} first' in reason and 'while true; do sleep 1; done' in reason
    assert keys == [f'proc:{endless.pid}:{W.proc_created(endless.pid)}']
    assert T.evaluate(STOP_IN, scan=True, root=os.getpid(), orphans=False) == (None, [])


def test_no_session_root_means_no_scan():
    assert T.raw_loops(table={1: (0, 'bash.exe')}, root=0) == []


@pytest.mark.skipif(os.name != 'nt', reason='Windows process creation times (FILETIME)')
def test_an_orphaned_old_loop_is_found_and_a_young_one_is_not():
    """INC-027's leak path: a loop whose parent is gone (a killed Git Bash tree) is reported when it is older than
    any allowed timeout bound; a young orphan may still be a `timeout <= 1h` child and is left alone"""
    now = time.time()
    ft = lambda ago: int((now - ago + 11644473600) * 1e7)            # noqa: E731
    table = {100: (1, 'claude.exe'), 200: (999, 'bash.exe'), 300: (998, 'bash.exe'), 400: (997, 'bash.exe')}
    cmd = {200: 'bash.exe -c "while true; do sleep 1; done"', 300: 'bash.exe -c "while true; do sleep 1; done"',
           400: 'bash.exe -c "sleep 30"'}
    born = {200: ft(2 * 3600), 300: ft(600), 400: ft(5 * 3600)}
    found = T.raw_loops(table=table, root=100, cmdline=cmd.get, created=born.get, now=now)
    assert [(r['pid'], r['orphan']) for r in found] == [(200, True)]
    assert 'ORPHANED' in T.loop_items(found)[0][1]
    assert T.raw_loops(table=table, root=100, cmdline=cmd.get, created=born.get, now=now, orphans=False) == []


@pytest.mark.skipif(os.name != 'nt', reason='Windows process creation times (FILETIME)')
def test_inc037_a_young_orphan_of_the_session_is_found():
    """INC-037: a detached loop orphaned by a killed Git Bash tree was found only after 65 min. The Stop hook remembers
    the session's processes at every turn end; a young orphan that was one of them, or whose parent was, is the
    session's leak at once. A young orphan of anything else is still left alone"""
    now = time.time()
    ft = lambda ago: int((now - ago + 11644473600) * 1e7)            # noqa: E731
    loop = 'bash.exe -c "while true; do sleep 1; done"'
    table = {100: (1, 'claude.exe'), 300: (250, 'bash.exe'), 310: (999, 'bash.exe'), 500: (260, 'bash.exe')}
    cmd = {300: loop, 310: loop, 500: loop}
    born = {300: ft(600), 310: ft(300), 500: ft(600)}
    seen = {250: ft(700), 310: ft(300)}                             # the parent of 300, and 310 itself, were ours
    found = T.raw_loops(table=table, root=100, cmdline=cmd.get, created=born.get, now=now, seen=seen)
    assert [(r['pid'], r['orphan']) for r in found] == [(300, True), (310, True)]
    assert T.raw_loops(table=table, root=100, cmdline=cmd.get, created=born.get, now=now, seen={}) == []


def test_inc037_the_stop_hook_remembers_the_session_processes(td):
    """INC-037: the descendants of the session at a turn end are written to the watch folder, keyed by the session root, and
    read back for that root only (another session's orphans stay another session's)"""
    table = {100: (1, 'claude.exe'), 200: (100, 'bash.exe'), 210: (200, 'bash.exe'), 900: (1, 'claude.exe')}
    born = {100: 11, 200: 22, 210: 33, 900: 99}
    T.remember_session(100, table, born.get, now=time.time())
    assert T.session_seen(100, born.get) == {200: 22, 210: 33}
    assert T.session_seen(900, born.get) == {}
    assert (td / 'watch' / T.SESSION_PROCS).is_file()


def test_inc038_an_already_reported_stale_watch_costs_no_grace_wait(td, proc, monkeypatch):
    """INC-038: after its one block, every later turn end waited the full grace (7 s) for as long as the stale watch
    lived. An item already reported is neither waited for nor reported again"""
    monkeypatch.setenv('AOP_TURN_END_WAIT', '4')
    e = entry(td, *proc, started_ago=4 * 3600)
    reason, keys = T.evaluate(STOP_IN, scan=False)
    assert keys == [f"watch:{e['id']}"]
    t0 = time.perf_counter()
    assert T.evaluate(STOP_IN, scan=False) == (None, [])
    assert time.perf_counter() - t0 < 1.5


def test_inc038_a_corrupt_memory_file_is_read_as_empty_and_rewritten(td, proc, tmp_path):
    """INC-038: the docstring said a corrupt memory file = no block; the hook reads it as empty (a lost memory must not
    hide a stale watch: that item is named once more) and writes a valid memory, so it is named only once"""
    e = entry(td, *proc, started_ago=4 * 3600)
    (td / 'watch' / T.MEMORY).write_text('{corrupt', encoding='utf-8')
    assert e['id'] in block_reason(run_hook())
    assert run_hook().stdout == b''
    assert 'turn_end_memory_corrupt' in log_events(tmp_path)
    assert 'a corrupt memory file is read as empty' in ' '.join(T.__doc__.split())


def test_inc039_inc027_is_not_hardened_while_its_guards_are_unregistered():
    """INC-039: INC-027 was marked hardened while tool_guard.py and turn_end_guard.py were not in .claude/settings.json
    (no session ran them) and its occurrence 2 still ran. The live task store may call INC-027 hardened (or closed)
    only once the owner registered both guard entries (harness_status --write-proposed)"""
    hs = load_status()
    store = hs.tasks_dir() / 'tasks.json'
    if not store.is_file():
        pytest.skip(f'no live task store at {store}')
    inc = (json.loads(store.read_text(encoding='utf-8')).get('incidents') or {}).get('INC-027') or {}
    have = hs._commands([g for groups in json.loads((REPO / '.claude' / 'settings.json').read_text(encoding='utf-8'))
                         .get('hooks', {}).values() for g in groups])
    guards = {n: {h['command'] for groups in ENTRIES['hooks'].values() for g in groups for h in g['hooks']
                  if n in h['command']} for n in ('tool_guard.py', 'turn_end_guard.py')}
    unregistered = sorted(n for n, cmds in guards.items() if not cmds <= have)
    assert not (inc.get('status') in ('hardened', 'closed') and unregistered), (inc.get('status'), unregistered)


# ------------------------------------------------------------------------------------------ the settings command
def stop_entry():
    return ENTRIES['hooks']['Stop'][0]['hooks'][0]


def bash(cmd, data, proj):
    env = dict(os.environ, CLAUDE_PROJECT_DIR=str(proj))
    return subprocess.run([git_bash(), '-c', cmd], input=data, capture_output=True, env=env, timeout=60)


def test_the_settings_command_blocks_through_json(td, proc, tmp_path):
    e = entry(td, *proc, started_ago=4 * 3600)
    r = bash(stop_entry()['command'], json.dumps(STOP_IN).encode(), REPO)
    assert e['id'] in block_reason(r)
    empty = tmp_path / 'fresh-clone'
    empty.mkdir()
    r = bash(stop_entry()['command'], json.dumps(STOP_IN).encode(), empty)
    assert (r.returncode, r.stdout, r.stderr) == (0, b'', b'')
    assert stop_entry()['timeout'] >= 15


# ------------------------------------------------------------------------------------------ harness_status
def load_status():
    s = importlib.util.spec_from_file_location('harness_status_bg', HOOKS / 'harness_status.py')
    m = importlib.util.module_from_spec(s)
    s.loader.exec_module(m)
    return m


def test_harness_status_counts_background_tasks(td, proc, tmp_path):
    """INC-027 asked for 'a status line listing the coordinator's own background tasks with their age'"""
    hs = load_status()
    assert hs.background_line(hs.background(scan=False)) == 'background tasks: 0'
    old = entry(td, *proc, started_ago=4 * 3600 + 30)
    entry(td, *proc, started_ago=600)
    entry(td, 99999999, 5, started_ago=60)
    bg = hs.background(scan=False)
    assert bg['count'] == 2 and bg['oldest']['what'] == old['id'] and bg['dead']
    line = hs.background_line(bg)
    assert line.startswith(f"background tasks: 2 (oldest {old['id']} 4h00m, task {TASK})")
    assert 'outlived their job' in line and 'watch.py stop --stale' in line and 'left behind' in line
    sp = tmp_path / 'settings.json'
    sp.write_text('{"hooks": {}}', encoding='utf-8')
    assert f"background tasks: 2 (oldest {old['id']}" in hs.text(hs.status(sp))
    loops = {'count': 1, 'oldest': {'what': 'pid 7', 'task': None, 'age_s': 7200.0, 'why': 'x'}, 'watches': 0,
             'stale': [], 'dead': [], 'corrupt': 0, 'loops': [{'what': 'pid 7', 'task': None, 'age_s': 7200.0}]}
    assert hs.background_line(loops).startswith('background tasks: 1 (oldest pid 7 2h00m, task none: raw loop')
