"""tool_guard.py R3: an endless loop in a background Bash call or a Monitor command is refused unless it runs through
.claude/hooks/watch.py (incident INC-027, task KTC-164).

INC-027: the exact background Bash command below (run_in_background=true, 2026-09-29) ran 32 h after its job ended;
its Monitor twin (INC027_MONITOR, timeout_ms 1800000) was re-armed six times. Both are refused now; the same watch
through watch.py passes; a foreground Bash call is never checked and never starts Python (the settings command's
`case` fast path), so ordinary calls cost only the bash start.

    python -m pytest .claude/hooks/tests/test_loop_guard.py -q

The harness log is a temp file (AOP_HARNESS_LOG); nothing real is written.
"""
import importlib.util
import json
import os
import re
import statistics
import subprocess
import sys
import time
from pathlib import Path

import pytest

HOOKS = Path(__file__).resolve().parents[1]
REPO = HOOKS.parent.parent
SCRIPT = HOOKS / 'tool_guard.py'
ENTRIES = json.loads((HOOKS / 'settings_entries.json').read_text(encoding='utf-8'))

spec = importlib.util.spec_from_file_location('tool_guard_r3_under_test', SCRIPT)
G = importlib.util.module_from_spec(spec)
spec.loader.exec_module(G)

# the exact INC-027 commands, as the coordinator's transcript (session 606bcdfd) recorded them
INC027_BASH = ('while netstat -ano 2>/dev/null | grep -q ":9876 .*LISTENING"; do sleep 20; done; '
               'echo "$(date +%H:%M:%S) Blender MCP port 9876 DOWN"')
INC027_MONITOR = ('prev=""; while true; do if netstat -ano 2>/dev/null | grep -q ":9876 .*LISTENING"; then s=UP; '
                  'else s=DOWN; fi; if [ "$s" != "$prev" ]; then echo "$(date +%H:%M:%S) Blender MCP port 9876 $s"; '
                  'prev=$s; fi; sleep 20; done')
VIA_WATCH = 'python .claude/hooks/watch.py start --task KTC-164 --ttl 3h --every 20 --until-port-down 9876'

DENIED = [
    INC027_BASH,
    INC027_MONITOR,
    'until grep -q "^EXIT" "C:/x/render_run.log" 2>/dev/null; do sleep 5; done; tail -3 C:/x/render_run.log',
    'for ((;;)); do date; sleep 1; done',
    'tail -f build.log | grep --line-buffered ERROR',
    'tail -n 100 -F C:/x/blender.log',
    'watch -n 5 nvidia-smi',
    'sleep infinity',
    'ping -t 127.0.0.1',
    'python -c "import time\nwhile True:\n    time.sleep(5)"',
    'powershell -Command "while ($true) { Start-Sleep 20 }"',
    "timeout 7200 bash -c 'while ! test -f done; do sleep 2; done'",       # bounded, but by more than 1h
    'timeout 5 curl -s x; while true; do sleep 1; done',                    # the timeout does not wrap the loop
    'python watch.py list; while true; do sleep 1; done',                   # not the wrapper's start
    'bash -c "tail -f x.log"',                                              # quoted, as in a process command line
    '/usr/bin/tail -f x.log',
    # INC-037: the forms the verifier got through (2026-09-30)
    'for i in $(seq 1 100000); do netstat -ano | grep -q ":9876" || break; sleep 20; done',
    'for i in {1..99999}; do sleep 20; done',
    'for ((i=0;;i++)); do sleep 20; done',
    'for i in 1 2 3; do date; sleep 1; done',                                # any for loop with a sleep is a loop
    'poll() { sleep 20; netstat -ano | grep -q 9876 && poll; }; poll',      # a recursive function
    'eval "$(echo d2hpbGUgdHJ1ZTsgZG8gc2xlZXAgMjA7IGRvbmU= | base64 -d)"',  # base64 of `while true; do sleep 20; done`
    'powershell -Command "do { Start-Sleep 20 } while ($true)"',
    ': watch.py start; while true; do sleep 20; done',                      # the text, not a real watch.py start
    'python .claude/hooks/watch.py start --task KTC-164 --ttl 1h --until-port-down 9876; while true; do sleep 20; done',
]
ALLOWED = [
    VIA_WATCH,
    'cd C:/w && python .claude/hooks/watch.py start --task KTC-164 --every 20 -- "netstat -ano | grep -q :9876"',
    'python watch.py start --task KTC-164 -- "while true; do sleep 1; done"',   # the wrapper bounds its check
    "timeout 600 bash -c 'while ! test -f done; do sleep 2; done'",
    'timeout 30m tail -n 50 -F build.log',
    'timeout -k 5 1h tail -f x.log',
    'bash -c "timeout 600 tail -f x.log"',
    'python -m pytest -q tests',
    "timeout 600 bash -c 'for i in $(seq 1 30); do sleep 20; done'",       # a for loop wrapped by a timeout
    'sleep 30; echo done',
    'tail -n 40 build.log',
    'blender -b x.blend -P s.py',
    'grep -rn "watch" docs | head',
]


def ev(tool, **ti):
    return G.evaluate({'tool_name': tool, 'tool_input': ti})


# ------------------------------------------------------------------------------------------ INC-027 itself
def test_the_inc027_command_is_refused_in_background():
    d, rule, reason, hits, _ = ev('Bash', command=INC027_BASH, run_in_background=True)
    assert (d, rule) == ('deny', 'R3') and hits
    assert 'INC-027' in reason and 'watch.py start --task' in reason and 'aop-allow-loop' in reason


def test_the_inc027_monitor_twin_is_refused():
    d, rule, _reason, hits, _ = ev('Monitor', command=INC027_MONITOR, description='Blender MCP port', timeout_ms=1800000)
    assert (d, rule) == ('deny', 'R3') and any('endless while' in h for h in hits)


def test_the_same_watch_through_watch_py_is_allowed():
    assert ev('Bash', command=VIA_WATCH, run_in_background=True)[0] == 'allow'
    assert ev('Monitor', command=VIA_WATCH, description='Blender MCP port', timeout_ms=1800000)[0] == 'allow'


def test_a_foreground_bash_call_is_not_checked():
    """the Bash tool bounds a foreground call itself (2-10 min): R3 is for background work only"""
    assert ev('Bash', command=INC027_BASH)[0] == 'allow'
    assert ev('Bash', command=INC027_BASH, run_in_background=False)[0] == 'allow'
    assert ev('Monitor', ws={'url': 'wss://example.invalid/stream'}, description='x', timeout_ms=1000)[0] == 'allow'


@pytest.mark.parametrize('cmd', DENIED)
def test_endless_background_loops_are_denied(cmd):
    """INC-027, and INC-037: the nine forms the verifier got through (for-seq, {1..N}, C for with an init, any for loop
    with a sleep, a recursive function, eval of base64, powershell do-while, watch.py start text before a loop)"""
    assert ev('Bash', command=cmd, run_in_background=True)[:2] == ('deny', 'R3')
    assert ev('Monitor', command=cmd, description='x', timeout_ms=60000)[:2] == ('deny', 'R3')


@pytest.mark.parametrize('cmd', ALLOWED)
def test_bounded_or_wrapped_background_commands_pass(cmd):
    assert ev('Bash', command=cmd, run_in_background=True)[0] == 'allow'


def test_the_override_is_logged_not_silent(tmp_path, monkeypatch):
    log = tmp_path / 'log.jsonl'
    monkeypatch.setenv('AOP_HARNESS_LOG', str(log))
    cmd = INC027_BASH + '  # aop-allow-loop: owner asked for a raw loop here'
    d, rule, _r, _h, why = ev('Bash', command=cmd, run_in_background=True)
    assert (d, rule, why) == ('override', 'R3', 'owner asked for a raw loop here')
    assert ev('Bash', command=INC027_BASH + ' # aop-allow-loop: short', run_in_background=True)[0] == 'deny'
    p = run_script({'tool_name': 'Bash', 'tool_input': {'command': cmd, 'run_in_background': True}}, tmp_path)
    assert p.returncode == 0 and p.stdout == b''
    rec = json.loads(log.read_text(encoding='utf-8').splitlines()[-1])
    assert (rec['decision'], rec['rule']) == ('override', 'R3')


# ------------------------------------------------------------------------------------------ the script and the settings command
def run_script(inp, tmp_path):
    env = dict(os.environ, AOP_HARNESS_LOG=os.environ.get('AOP_HARNESS_LOG') or str(tmp_path / 'log.jsonl'))
    env.pop('AOP_TOOL_GUARD', None)
    return subprocess.run([sys.executable, str(SCRIPT)], input=json.dumps(inp).encode(), capture_output=True,
                          env=env, timeout=60)


def test_the_script_denies_through_json(tmp_path):
    p = run_script({'tool_name': 'Bash', 'tool_input': {'command': INC027_BASH, 'run_in_background': True}}, tmp_path)
    o = json.loads(p.stdout)['hookSpecificOutput']
    assert p.returncode == 0 and o['permissionDecision'] == 'deny' and 'R3' in o['permissionDecisionReason']
    p = run_script({'tool_name': 'Bash', 'tool_input': {'command': VIA_WATCH, 'run_in_background': True}}, tmp_path)
    assert (p.returncode, p.stdout) == (0, b'')


def git_bash():
    for c in (os.environ.get('CLAUDE_CODE_GIT_BASH_PATH'), r'C:\Program Files\Git\bin\bash.exe',
              r'C:\Program Files (x86)\Git\bin\bash.exe'):
        if c and Path(c).is_file():
            return c
    pytest.skip('Git Bash not installed')


def guard_entry():
    return next(g for g in ENTRIES['hooks']['PreToolUse'] if 'tool_guard.py' in json.dumps(g))


def bash(cmd, inp, proj, tmp_path):
    env = dict(os.environ, CLAUDE_PROJECT_DIR=str(proj), AOP_HARNESS_LOG=str(tmp_path / 'log.jsonl'))
    env.pop('AOP_TOOL_GUARD', None)
    t0 = time.perf_counter()
    r = subprocess.run([git_bash(), '-c', cmd], input=json.dumps(inp).encode(), capture_output=True, env=env,
                       timeout=60)
    r.secs = time.perf_counter() - t0
    return r


def test_the_settings_entry_covers_bash_and_monitor():
    assert set(guard_entry()['matcher'].split('|')) >= {'Bash', 'Monitor', 'PowerShell'}     # PowerShell: INC-037


def test_the_settings_command_refuses_the_inc027_command(tmp_path):
    cmd = guard_entry()['hooks'][0]['command']
    for tool, ti in (('Bash', {'command': INC027_BASH, 'run_in_background': True}),
                     ('Monitor', {'command': INC027_MONITOR, 'description': 'x', 'timeout_ms': 1800000})):
        r = bash(cmd, {'tool_name': tool, 'tool_input': ti}, REPO, tmp_path)
        assert r.returncode == 0
        assert json.loads(r.stdout)['hookSpecificOutput']['permissionDecision'] == 'deny', tool
    r = bash(cmd, {'tool_name': 'Bash', 'tool_input': {'command': VIA_WATCH, 'run_in_background': True}}, REPO,
             tmp_path)
    assert (r.returncode, r.stdout) == (0, b'')


def stub_project(tmp_path):
    proj = tmp_path / 'proj'
    (proj / '.claude' / 'hooks').mkdir(parents=True)
    marker = tmp_path / 'python_ran'
    (proj / '.claude' / 'hooks' / 'tool_guard.py').write_text(
        'import sys\nsys.stdin.buffer.read()\nopen(%r, "a").write("x")\n' % str(marker), encoding='utf-8')
    return proj, marker


def test_a_foreground_bash_call_never_starts_python(tmp_path):
    """near-zero cost: the INC-027 text itself, run in the FOREGROUND, passes the bash `case` without Python; the
    same text in the background, and any Monitor call, reach the script"""
    proj, marker = stub_project(tmp_path)
    cmd = guard_entry()['hooks'][0]['command']
    r = bash(cmd, {'tool_name': 'Bash', 'tool_input': {'command': INC027_BASH}}, proj, tmp_path)
    assert (r.returncode, r.stdout) == (0, b'') and not marker.exists()
    r = bash(cmd, {'tool_name': 'Bash', 'tool_input': {'command': 'ls', 'run_in_background': False}}, proj, tmp_path)
    assert (r.returncode, r.stdout) == (0, b'') and not marker.exists()
    for c in ('git status && git log 2>&1 | head &> x.txt', 'a || b', 'x |& tee y'):          # no detaching `&`
        r = bash(cmd, {'tool_name': 'Bash', 'tool_input': {'command': c}}, proj, tmp_path)
        assert (r.returncode, r.stdout) == (0, b'') and not marker.exists(), c
    r = bash(cmd, {'tool_name': 'PowerShell', 'tool_input': {'command': '& "C:/x/tool.exe" -a 1'}}, proj, tmp_path)
    assert not marker.exists()                                   # PowerShell's call operator is not a detach
    bash(cmd, {'tool_name': 'Bash', 'tool_input': {'command': 'sleep 30 &'}}, proj, tmp_path)
    assert marker.exists()                                       # a foreground call that detaches reaches the script
    marker.unlink()
    bash(cmd, {'tool_name': 'Bash', 'tool_input': {'command': INC027_BASH, 'run_in_background': True}}, proj, tmp_path)
    assert marker.exists()
    marker.unlink()
    bash(cmd, {'tool_name': 'Monitor', 'tool_input': {'command': 'tail -f x'}}, proj, tmp_path)
    assert marker.exists()


def test_the_foreground_path_is_cheaper_than_a_python_start(tmp_path):
    """wall clock of a foreground Bash call through the hook command stays below a bare Python start (INC-038: with
    `b=$(cat)` the median was 349 ms against 155 ms for a bare bash, and this test went red in a serial run; samples
    are interleaved so a load change hits both sides)"""
    proj, _m = stub_project(tmp_path)
    cmd = guard_entry()['hooks'][0]['command']
    inp = {'tool_name': 'Bash', 'tool_input': {'command': 'git status --short ' + 'x' * 2000}}
    ours, py = [], []
    for _ in range(7):
        ours.append(bash(cmd, inp, proj, tmp_path).secs)
        py.append(bash('python -c pass', inp, proj, tmp_path).secs)
    assert statistics.median(ours) < statistics.median(py), (ours, py)


def test_inc038_the_fast_path_forks_nothing():
    """INC-038: the foreground fast path reads its input with the read builtin - no `$(...)`, backtick or pipe before
    the `case` decides (each forks a process: +200 ms per Bash call)"""
    cmd = guard_entry()['hooks'][0]['command']
    head = cmd[:cmd.index('case ')]
    assert "IFS= read -r -d '' b" in head and '$(' not in head and '`' not in head, head
    assert not re.search(r'(?<![|])[|](?![|])', head), head                       # `||` is a list, not a pipe


# ------------------------------------------------------------------------------------------ INC-037: more tools, more forms
PS_DENIED = [
    'while ($true) { Start-Sleep 20; netstat -ano | Select-String 9876 }',
    'Get-Content C:/tmp/log.txt -Wait',
    'do { Start-Sleep 20 } while ($true)',
    'for (;;) { Start-Sleep 5 }',
]


@pytest.mark.parametrize('cmd', PS_DENIED)
def test_inc037_the_powershell_tool_is_checked(cmd):
    """INC-037"""
    assert ev('PowerShell', command=cmd, run_in_background=True)[:2] == ('deny', 'R3')
    assert ev('PowerShell', command=cmd)[0] == 'allow'                     # foreground: the tool bounds it
    assert ev('PowerShell', command='Get-ChildItem C:/x | Select-Object -First 3', run_in_background=True)[0] == 'allow'


@pytest.mark.parametrize('cmd', [
    "nohup bash -c 'while true; do sleep 20; done' >/dev/null 2>&1 &",
    '(while true; do sleep 20; done) & disown',
    'setsid bash -c "while true; do sleep 1; done"',
    'while true; do sleep 20; done &',
])
def test_inc037_a_foreground_command_that_detaches_a_loop_is_denied(cmd):
    """INC-037: a foreground call that detaches (& / nohup / disown / setsid) outlives the tool's own bound"""
    assert ev('Bash', command=cmd)[:2] == ('deny', 'R3')


def test_inc037_foreground_commands_without_a_detached_loop_pass():
    """INC-037"""
    for cmd in ('git status && git diff 2>&1 | head', 'sleep 5 &', 'python a.py &> log.txt', 'ls & wait'):
        assert ev('Bash', command=cmd)[0] == 'allow', cmd


def test_inc037_the_script_a_background_call_runs_is_scanned(tmp_path):
    """INC-037: a loop inside a .py / .sh file run in background: the file is read (relative to the call's cwd)"""
    (tmp_path / 'poll.py').write_text('import time\nwhile True:\n    time.sleep(20)\n', encoding='utf-8')
    (tmp_path / 'poll.sh').write_text('#!/bin/bash\nwhile true; do sleep 20; done\n', encoding='utf-8')
    (tmp_path / 'wait.py').write_text('import time\nwhile not done():\n    time.sleep(2)\n', encoding='utf-8')
    (tmp_path / 'ok.py').write_text('print(1)\nfor i in range(3):\n    print(i)\n', encoding='utf-8')
    (tmp_path / 'bounded.py').write_text('# aop-allow-loop: ends with its render, max 40 min\nimport time\n'
                                         'while not done():\n    time.sleep(2)\n', encoding='utf-8')
    run = lambda c: G.evaluate({'tool_name': 'Bash', 'cwd': str(tmp_path),  # noqa: E731
                                'tool_input': {'command': c, 'run_in_background': True}})
    for c in ('python poll.py', 'bash poll.sh', 'python -u wait.py --x 1', f'cd "{tmp_path}" && python poll.py',
              'sh ./poll.sh'):
        d, rule, _r, hits, _w = run(c)
        assert (d, rule) == ('deny', 'R3') and any('poll' in h or 'wait.py' in h for h in hits), (c, hits)
    assert run('python ok.py')[0] == 'allow'
    assert run('python bounded.py')[:2] == ('override', 'R3')
    assert run('python missing.py')[0] == 'allow'                          # nothing to read: nothing found
    assert run('python .claude/hooks/watch.py start --task KTC-1 --ttl 1h --until-port-down 9876')[0] == 'allow'


@pytest.mark.parametrize('tool,ti', [
    ('PowerShell', {'command': 'while ($true) { Start-Sleep 20 }', 'run_in_background': True}),
    ('Bash', {'command': "nohup bash -c 'while true; do sleep 20; done' >/dev/null 2>&1 &"}),
    ('Bash', {'command': '(while true; do sleep 20; done) & disown'}),
    ('Bash', {'command': 'while true; do sleep 20; done &'}),
])
def test_inc037_the_settings_command_reaches_the_script(tmp_path, tool, ti):
    """INC-037"""
    cmd = guard_entry()['hooks'][0]['command']
    r = bash(cmd, {'tool_name': tool, 'tool_input': ti}, REPO, tmp_path)
    assert r.returncode == 0 and json.loads(r.stdout)['hookSpecificOutput']['permissionDecision'] == 'deny', r.stdout
