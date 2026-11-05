"""watch.py: background watchdogs end with their job (incident INC-027, task KTC-164).

INC-027: `while netstat -ano 2>/dev/null | grep -q ":9876 .*LISTENING"; do sleep 20; done`, started as a Claude
background task, ran 32 h after its job ended (the port never dropped). These tests pin the wrapper that replaces such
loops: TTL expiry on a fake clock, exit within 30 s of the task / run / session ending, refusal without --task, an
orphan (no session, no run, a task that never ends) ending at its TTL, only state changes printed, the registry
(list / stop / stop --stale), and ONE real 60 s watch tied to a scratch task that is gone - process and registry
entry - within seconds of the task ending.

    python -m pytest .claude/hooks/tests/test_watch.py -q

Everything runs on a temp task store (AOP_TASKS_DIR) and a temp harness log; the real store is never read or written.
The fake-clock tests run hours of watch in well under a second.
"""
import importlib.util
import io
import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

import pytest

HOOKS = Path(__file__).resolve().parents[1]
SCRIPT = HOOKS / 'watch.py'
spec = importlib.util.spec_from_file_location('watch_under_test', SCRIPT)
W = importlib.util.module_from_spec(spec)
spec.loader.exec_module(W)

T0 = 1_900_000_000.0
TASK, RUN = 'KTC-900', 'wf_watchtest-1'


# ------------------------------------------------------------------------------------------ helpers
def task(tid=TASK, status='ready', lease_job=None):
    return {'id': tid, 'status': status, 'lease': {'job': lease_job, 'holder': 'claude'} if lease_job else None}


def put(td, *tasks):
    (td / 'tasks.json').write_text(json.dumps({'tasks': {t['id']: t for t in tasks}}), encoding='utf-8')


def bind(td, mapping):
    (td / 'inbox' / 'runs.json').write_text(json.dumps(mapping), encoding='utf-8')


@pytest.fixture
def td(tmp_path, monkeypatch):
    d = tmp_path / 'tasks'
    (d / 'inbox').mkdir(parents=True)
    put(d, task())
    bind(d, {RUN: TASK})
    monkeypatch.setenv('AOP_TASKS_DIR', str(d))
    monkeypatch.setenv('AOP_HARNESS_LOG', str(tmp_path / 'log.jsonl'))
    return d


class Clock:
    """a fake clock: sleep() advances it and fires the events scheduled for that time"""

    def __init__(self, t=T0):
        self.t, self.events, self.sleeps = t, [], 0

    def __call__(self):
        return self.t

    def sleep(self, s):
        assert s > 0
        self.sleeps += 1
        self.t += s
        for ev in [e for e in self.events if self.t >= e[0]]:
            self.events.remove(ev)
            ev[1]()

    def at(self, dt, fn):
        self.events.append((T0 + dt, fn))


def make(td, clock, run=None, ttl=3 * 3600, every=20, parent=None, alive=None, probe=None, lease_job=None,
         until=None):
    e = W.new_entry(TASK, run, ttl, every, until or {'port_down': 9876}, parent=parent, lease_job=lease_job,
                    now=clock(), pid=os.getpid(), created=W.proc_created(os.getpid()))
    W.register(e, td / 'watch')
    calls = []

    def default_probe():
        calls.append(clock())
        return {'port 9876': ('up', '')}

    out = io.StringIO()
    w = W.Watch(e, W.Store(td), wdir=td / 'watch', clock=clock, sleep=clock.sleep, out=out,
                probe=probe or default_probe, alive=alive or (lambda pid, created=None: True))
    w.calls = calls
    return w, e, out


def registry(td):
    return sorted(p.name for p in (td / 'watch').glob('w-*.json')) if (td / 'watch').is_dir() else []


# ------------------------------------------------------------------------------------------ INC-027: the end conditions
def test_ttl_expiry_with_a_fake_clock(td):
    """INC-027 as it happened: the port stays up for ever, nobody stops the watch. It ends at its TTL (default 3h),
    printed 3 lines in 3 hours (start, one state, end) and left no registry entry"""
    assert W.TTL_DEFAULT_S == 3 * 3600 and W.TTL_MAX_S == 12 * 3600
    c = Clock()
    w, e, out = make(td, c, ttl=W.TTL_DEFAULT_S)
    assert registry(td) == [e['id'] + '.json']
    reason = w.run()
    assert reason == 'ttl 3h00m reached'
    assert W.TTL_DEFAULT_S <= c.t - T0 <= W.TTL_DEFAULT_S + W.TICK_S + 1e-6
    lines = out.getvalue().splitlines()
    assert len(lines) == 3 and 'started' in lines[0] and lines[1].endswith('port 9876 up')
    assert lines[2].endswith('ended after 3h00m: ttl 3h00m reached')
    assert 500 <= len(w.calls) <= 541            # probed every 20 s, printed once
    assert registry(td) == []


@pytest.mark.parametrize('status', ['done', 'rejected', 'superseded', 'on_hold'])
def test_ends_within_30s_of_the_task_ending(td, status):
    """INC-027: the job ended, the watch did not. Now the task's end (any terminal status, or on_hold) ends it"""
    c = Clock()
    w, _e, out = make(td, c)
    c.at(100, lambda: put(td, task(status=status)))
    reason = w.run()
    assert reason == f'task {TASK} is {status}'
    assert 100 <= c.t - T0 <= 130
    assert out.getvalue().splitlines()[-1].endswith(f'task {TASK} is {status}')
    assert registry(td) == []


def test_ends_within_30s_of_the_run_being_unbound(td):
    """INC-027: the watch is tied to its workflow run; tasks.py bind-run --unbind (or the 24 h expiry) ends it"""
    c = Clock()
    w, _e, _out = make(td, c, run=RUN)
    c.at(250, lambda: bind(td, {}))
    reason = w.run()
    assert reason == f'run {RUN} is no longer bound to {TASK} (inbox/runs.json)'
    assert 250 <= c.t - T0 <= 280


def test_a_released_lease_ends_a_leased_watch(td):
    """INC-027: the task stays open, but the job (the lease the watch was started under) is over"""
    put(td, task(status='leased', lease_job=f'{TASK}-a1'))
    c = Clock()
    w, _e, _out = make(td, c, lease_job=f'{TASK}-a1')
    c.at(60, lambda: put(td, task(status='ready')))
    assert w.run() == f'task {TASK}: lease {TASK}-a1 ended'
    assert 60 <= c.t - T0 <= 90


def test_the_session_ending_ends_the_watch(td):
    """INC-027: the Claude Code process that started the watch is gone"""
    c = Clock()
    par = {'pid': 4242, 'created': 7, 'name': 'claude.exe', 'via': 'CLAUDE_PID'}
    w, _e, out = make(td, c, parent=par, alive=lambda pid, created=None: c.t < T0 + 50)
    assert w.run() == 'session gone (claude.exe 4242 ended)'
    assert 50 <= c.t - T0 <= 80
    assert 'session claude.exe 4242 ends' in out.getvalue().splitlines()[0]


def test_an_orphan_ends_at_its_ttl(td):
    """INC-027: no session known, no run, a task that never ends - the TTL alone still ends it"""
    c = Clock()
    w, _e, out = make(td, c, ttl=2 * 3600, parent=None)
    assert w.run() == 'ttl 2h00m reached'
    assert 2 * 3600 <= c.t - T0 <= 2 * 3600 + W.TICK_S + 1e-6
    assert 'no session known' in out.getvalue().splitlines()[0]
    assert registry(td) == []


def test_only_state_changes_are_printed_and_the_port_drop_ends_it(td):
    """INC-027's purpose, done right: one line when the port is up, one when it drops, then the watch ends"""
    c = Clock()
    seq = iter(['up'] * 30 + ['down'] + ['up'] * 5)
    w, _e, out = make(td, c, probe=lambda: {'port 9876': (next(seq), '')})
    assert w.run() == 'port 9876 down'
    lines = out.getvalue().splitlines()
    assert [ln.split(': ', 1)[1] for ln in lines[1:3]] == ['port 9876 up', 'port 9876 down']
    assert len(lines) == 4 and 30 * 20 <= c.t - T0 <= 31 * 20 + 1


def test_the_stop_file_ends_the_watch(td):
    c = Clock()
    w, e, _out = make(td, c)
    c.at(90, lambda: W.stop_path(e['id'], td / 'watch').write_text('stop', encoding='utf-8'))
    assert w.run() == 'stopped (watch.py stop)'
    assert c.t - T0 <= 90 + W.TICK_S + 1e-6
    assert not (td / 'watch' / f"{e['id']}.stop").exists() and registry(td) == []


def test_an_unreadable_store_is_no_verdict(td):
    """a torn tasks.json mid-write must not end the watch (the last good read counts), nor keep it past its TTL"""
    c = Clock()
    w, _e, _out = make(td, c, ttl=600)
    c.at(100, lambda: (td / 'tasks.json').write_text('{"tasks": {', encoding='utf-8'))
    assert w.run() == 'ttl 10m00s reached'


# ------------------------------------------------------------------------------------------ refusals (CLI)
def test_start_refuses_without_task_through_the_real_script(td, tmp_path):
    """INC-027: a watch without a task is exactly the loop that ran 32 h - the script refuses it (exit 2), registers
    nothing and runs nothing"""
    p = subprocess.run([sys.executable, str(SCRIPT), 'start', '--every', '5', '--until-port-down', '9876'],
                       capture_output=True, text=True, timeout=60, env=dict(os.environ))
    assert p.returncode == 2 and p.stdout == ''
    assert '--task <KTC id> is required' in p.stderr and 'INC-027' in p.stderr
    assert registry(td) == []
    rec = json.loads((tmp_path / 'log.jsonl').read_text(encoding='utf-8').splitlines()[-1])
    assert rec['event'] == 'watch_refused' and rec['task'] is None


@pytest.mark.parametrize('args,why', [
    (['--task', 'KTC-999', '--until-port-down', '9876'], 'is not in the task store'),
    (['--task', 'not a task', '--until-port-down', '9876'], 'is not a task id'),
    (['--task', TASK, '--ttl', '13h', '--until-port-down', '9876'], 'outside 1s..12h'),
    (['--task', TASK, '--ttl', 'soon', '--until-port-down', '9876'], 'bad duration'),
    (['--task', TASK, '--every', '0.2', '--until-port-down', '9876'], 'below 1s'),
    (['--task', TASK], 'nothing to watch'),
    (['--task', TASK, '--run', 'wf_other-9', '--until-port-down', '9876'], 'is not bound to'),
    (['--task', 'KTC-901', '--until-port-down', '9876'], 'is done'),
])
def test_start_refusals(td, capsys, args, why):
    put(td, task(), task('KTC-901', 'done'))
    assert W.main(['start', '--parent-pid', '0'] + args) == 2
    err = capsys.readouterr().err
    assert 'refused' in err and why in err
    assert registry(td) == []


def test_start_refuses_when_the_store_cannot_be_read(td, capsys):
    (td / 'tasks.json').unlink()
    assert W.main(['start', '--task', TASK, '--parent-pid', '0', '--until-port-down', '9876']) == 2
    assert 'cannot be read' in capsys.readouterr().err


# ------------------------------------------------------------------------------------------ registry: list / stop
def sleeper(secs=90):
    p = subprocess.Popen([sys.executable, '-c', f'import time; time.sleep({secs})'])
    for _ in range(50):
        c = W.proc_created(p.pid)
        if c:
            return p, c
        time.sleep(0.1)
    p.kill()
    pytest.fail('the stand-in process did not start')


def entry_for(td, pid, created, started_ago, ttl=3 * 3600, tid=TASK):
    e = W.new_entry(tid, None, ttl, 20, {'port_down': 9876}, now=time.time() - started_ago, pid=pid, created=created)
    W.register(e, td / 'watch')
    return e


def test_list_and_stop_stale(td, capsys, monkeypatch):
    """a hung watch past its TTL (a real process standing in for it) is STALE and `stop --stale` ends it; an entry
    whose process is gone is DEAD and removed; an unreadable entry is removed; a watch within its limits is kept"""
    monkeypatch.setattr(W, 'STOP_GRACE_S', 0.5)
    hung, hung_c = sleeper()
    fine, fine_c = sleeper()
    try:
        stale = entry_for(td, hung.pid, hung_c, started_ago=4 * 3600)
        ok = entry_for(td, fine.pid, fine_c, started_ago=60)
        gone = entry_for(td, 99999999, 5, started_ago=60)
        (td / 'watch' / 'w-badbad.json').write_text('{not json', encoding='utf-8')
        assert W.main(['list', '--json']) == 0
        rows = {r['id']: r for r in json.loads(capsys.readouterr().out)}
        assert rows[stale['id']]['status'] == 'STALE' and rows[stale['id']]['why'] == 'ttl 3h00m reached'
        assert rows[ok['id']]['status'] == 'running' and rows[gone['id']]['status'] == 'DEAD'
        assert rows['w-badbad']['status'] == 'CORRUPT'
        assert W.main(['stop', '--stale']) == 0
        out = capsys.readouterr().out
        assert f"{stale['id']}: killed" in out and f"{gone['id']}: removed (process already gone)" in out
        assert 'w-badbad: removed (unreadable entry)' in out
        hung.wait(timeout=20)
        assert not W.proc_alive(hung.pid, hung_c)
        assert registry(td) == [ok['id'] + '.json'] and fine.poll() is None
        assert W.main(['stop', ok['id']]) == 0
        fine.wait(timeout=20)
        assert registry(td) == []
    finally:
        for p in (hung, fine):
            if p.poll() is None:
                W.kill_tree(p.pid)


# ------------------------------------------------------------------------------------------ probes
def test_run_check_states_and_timeout():
    assert W.run_check([sys.executable, '-c', 'print("hi")'], 20) == ('ok', 'hi')
    assert W.run_check([sys.executable, '-c', 'import sys; sys.exit(3)'], 20)[0] == 'fail rc=3'
    t = time.monotonic()
    st, _ = W.run_check([sys.executable, '-c', 'import time; time.sleep(60)'], 1)
    assert st == 'timeout' and time.monotonic() - t < 15


def test_port_state_reads_the_listening_table():
    """the R9 probe reads netstat (never connects to the port): a socket we listen on is up, then down"""
    s = socket.socket()
    s.bind(('127.0.0.1', 0))
    s.listen(1)
    port = s.getsockname()[1]
    try:
        assert W.port_state(port) == 'up'
    finally:
        s.close()
    assert W.port_state(port) == 'down'


def test_durations():
    assert [W.parse_dur(x) for x in ('3h', '90m', '1h30m', '45s', '120', '2.5h')] == \
        [10800, 5400, 5400, 45, 120, 9000]
    with pytest.raises(ValueError):
        W.parse_dur('soon')


# ------------------------------------------------------------------------------------------ the one real live test
def test_live_watch_ends_when_its_task_ends(td, tmp_path):
    """INC-027, for real: a 60 s watch tied to a scratch task (a real process, real clock, real registry in a temp
    store). The task ends -> within seconds the process has exited 0, its registry entry is gone, and its last line
    names the reason. Nothing is left running whatever happens (finally: kill)."""
    env = dict(os.environ, PYTHONUNBUFFERED='1')
    p = subprocess.Popen([sys.executable, str(SCRIPT), 'start', '--task', TASK, '--ttl', '60', '--every', '1',
                          '--until-file', str(tmp_path / 'never'), '--parent-pid', str(os.getpid())],
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)
    try:
        t_end = time.time() + 20
        while time.time() < t_end and not registry(td) and p.poll() is None:
            time.sleep(0.1)
        assert registry(td), 'the watch never registered'
        e = json.loads((td / 'watch' / registry(td)[0]).read_text(encoding='utf-8'))
        assert e['pid'] == p.pid and e['task'] == TASK and e['ttl_s'] == 60
        time.sleep(1.5)
        assert p.poll() is None                                    # still running while the task is open
        t_done = time.time()
        put(td, task(status='done'))
        rc = p.wait(timeout=30)
        took = time.time() - t_done
        out, err = p.communicate(timeout=10)
        assert rc == 0, err
        assert took < 15, took
        assert registry(td) == []
        assert not W.proc_alive(p.pid, e['created'])
        assert out.splitlines()[-1].endswith(f'task {TASK} is done'), out
        assert 'file absent' in out and out.count('file absent') == 1
    finally:
        if p.poll() is None:
            W.kill_tree(p.pid)
            p.wait(timeout=20)
