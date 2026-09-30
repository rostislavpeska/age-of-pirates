"""tool_guard.py: R1 (raw image repoint in Blender MCP code) and R2 (blender_gate.py piped / unchecked).

    python -m pytest .claude/hooks/tests/test_tool_guard.py -q

Unit cases on evaluate(), then the script as Claude Code runs it (stdin JSON -> deny JSON or 0 bytes), then the exact
settings_entries.json command through Git Bash. The harness log is a temp file (AOP_HARNESS_LOG); nothing real is
written. Incidents: "The process is STILL flawed!" (owner 2026-09-29 13:05: raw repoints bypassed the watcher), the
19-image reload that dropped the MCP link (28-176), `blender_gate.py | tail -1` launching Blender on a TIMEOUT (29-28).
"""
import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

HOOKS = Path(__file__).resolve().parents[1]
REPO = HOOKS.parent.parent
SCRIPT = HOOKS / 'tool_guard.py'
ENTRIES = json.loads((HOOKS / 'settings_entries.json').read_text(encoding='utf-8'))
BT = 'mcp__blender__execute_blender_code'

spec = importlib.util.spec_from_file_location('tool_guard_under_test', SCRIPT)
G = importlib.util.module_from_spec(spec)
spec.loader.exec_module(G)

REPOINTS = [
    "bpy.data.images['P2048_BaseColor'].filepath = r'C:/x/candidates/KTC-158/P2048_BaseColor.png'",
    "img = bpy.data.images.get('P1024_Normal')\nimg.filepath_raw = p\nimg.reload()",
    "for im in bpy.data.images:\n    if im.name.startswith('P2048'):\n        im.reload()",
    "mat.node_tree.nodes['Image Texture'].image.filepath = new_path",
    "bpy.ops.image.reload()",
    "t = bpy.data.images['x']\nsetattr(t, 'filepath', p)",
    "t = bpy.data.images['x']\nt.filepath = p   # quick preview",
]
ALLOWED_CODE = [
    "st = sys.modules['_aop_review_live_registry'].state\nprint(st.beta_show('KTC-158-a1'))",
    "import importlib.util as u; s = u.spec_from_file_location('aop_review_live', r'C:/x/aop_review_live.py'); "
    "m = u.module_from_spec(s); s.loader.exec_module(m); print(m.install())",
    "import importlib; importlib.reload(m)",
    "bpy.context.scene.render.filepath = '//shots/front.png'\nbpy.ops.render.render(write_still=True)",
    "img = bpy.data.images.load(r'C:/x/new_map.png', check_existing=True)",
    "print([(i.name, i.filepath) for i in bpy.data.images if i.filepath == p])",
    "# img.filepath = p  (a comment)\nprint(len(bpy.data.objects))",
    "bpy.data.libraries['kit'].reload()",
    "scene = bpy.context.scene\nscene.render.filepath = out\nprint(bpy.data.images.keys())",
]
GATE_BAD = [
    "python blender_gate.py --timeout 600 | tail -1 && blender -b x.blend -P s.py",
    "python C:/w/Claude_CP2/blender_gate.py; blender -b f.blend -P s.py",
    "py blender_gate.py --timeout 60 || blender --background f.blend",
    "cd C:/w && python blender_gate.py 2>&1 | grep GO && blender.exe -b a.blend",
]
GATE_OK = [
    "python blender_gate.py --timeout 600 && blender -b x.blend -P s.py",
    "set -o pipefail; python blender_gate.py | tee gate.log && blender -b x.blend",
    "grep -n GO_HOLD blender_gate.py | head",
    "python -m pytest gate_tests/test_blender_gate.py -q | tail -3",
    "cat blender_gate.py | head -20",
    "python blender_gate.py --timeout 60; echo exit=$?",
]


def ev(tool, **ti):
    return G.evaluate({'tool_name': tool, 'tool_input': ti})


@pytest.mark.parametrize('code', REPOINTS)
def test_raw_repoints_are_denied(code):
    d, rule, reason, hits, _ = ev(BT, code=code)
    assert (d, rule) == ('deny', 'R1') and hits
    assert 'publish.py candidate' in reason and 'beta_show' in reason and 'aop-allow-repoint' in reason


@pytest.mark.parametrize('code', ALLOWED_CODE)
def test_watcher_api_loads_and_render_paths_pass(code):
    assert ev(BT, code=code)[0] == 'allow'


def test_override_marker_needs_a_reason():
    code = REPOINTS[0] + '\n# aop-allow-repoint: not the review file, a scratch bake preview'
    d, _, _, _, why = ev(BT, code=code)
    assert d == 'override' and why.startswith('not the review file')
    assert ev(BT, code=REPOINTS[0] + '\n# aop-allow-repoint: x')[0] == 'deny'


@pytest.mark.parametrize('cmd', GATE_BAD)
def test_gate_bypasses_are_denied(cmd):
    d, rule, reason, _, _ = ev('Bash', command=cmd)
    assert (d, rule) == ('deny', 'R2') and '&&' in reason


@pytest.mark.parametrize('cmd', GATE_OK)
def test_checked_gate_calls_and_reads_pass(cmd):
    assert ev('Bash', command=cmd)[0] == 'allow'


def test_other_tools_and_odd_input_pass():
    assert ev('Write', file_path='x', content=REPOINTS[0])[0] == 'allow'
    assert G.evaluate({'tool_name': BT, 'tool_input': 'not a dict'})[0] == 'allow'
    assert G.evaluate({})[0] == 'allow'


def test_deny_texts_stay_short():
    """every deny text lands in the model's context: keep it under 700 bytes"""
    r1 = ev(BT, code=REPOINTS[1])[2]
    r2 = ev('Bash', command=GATE_BAD[0])[2]
    assert len(r1.encode()) < 700 and len(r2.encode()) < 700


# ------------------------------------------------------------------------------------------ the script as a hook
def run_hook(payload, tmp_path, **env_extra):
    env = dict(os.environ, AOP_HARNESS_LOG=str(tmp_path / 'log.jsonl'), **env_extra)
    env.pop('AOP_TOOL_GUARD', None) if 'AOP_TOOL_GUARD' not in env_extra else None
    data = payload if isinstance(payload, bytes) else json.dumps(payload).encode()
    return subprocess.run([sys.executable, str(SCRIPT)], input=data, capture_output=True, env=env, timeout=60)


def logged(tmp_path):
    p = tmp_path / 'log.jsonl'
    return [json.loads(x) for x in p.read_text(encoding='utf-8').splitlines()] if p.exists() else []


def test_deny_is_hook_json_and_logged(tmp_path):
    r = run_hook({'tool_name': BT, 'tool_input': {'code': REPOINTS[0]}, 'session_id': 's1'}, tmp_path)
    assert r.returncode == 0
    out = json.loads(r.stdout)['hookSpecificOutput']
    assert out['hookEventName'] == 'PreToolUse' and out['permissionDecision'] == 'deny'
    [rec] = logged(tmp_path)
    assert rec['hook'] == 'tool_guard' and rec['decision'] == 'deny' and rec['rule'] == 'R1' and rec['session_id'] == 's1'


def test_allow_prints_nothing_and_logs_nothing(tmp_path):
    r = run_hook({'tool_name': BT, 'tool_input': {'code': ALLOWED_CODE[0]}}, tmp_path)
    assert r.returncode == 0 and r.stdout == b'' and r.stderr == b'' and logged(tmp_path) == []


def test_env_off_and_marker_overrides_are_logged(tmp_path):
    r = run_hook({'tool_name': 'Bash', 'tool_input': {'command': GATE_BAD[0]}}, tmp_path, AOP_TOOL_GUARD='off')
    assert r.returncode == 0 and r.stdout == b''
    code = REPOINTS[2] + '\n# aop-allow-repoint: owner asked for a raw reload of his scratch file'
    r = run_hook({'tool_name': BT, 'tool_input': {'code': code}}, tmp_path)
    assert r.stdout == b''
    recs = logged(tmp_path)
    assert [x['decision'] for x in recs] == ['override', 'override']
    assert recs[0]['why'] == 'env AOP_TOOL_GUARD=off' and recs[1]['why'].startswith('owner asked')


@pytest.mark.parametrize('raw', [b'', b'not json', b'[1, 2]', b'{"tool_name": 5}'])
def test_garbage_input_fails_open(tmp_path, raw):
    r = run_hook(raw, tmp_path)
    assert r.returncode == 0 and r.stdout == b''


# ------------------------------------------------------------------------------------------ the settings command
def git_bash():
    for c in (os.environ.get('CLAUDE_CODE_GIT_BASH_PATH'), r'C:\Program Files\Git\bin\bash.exe',
              r'C:\Program Files (x86)\Git\bin\bash.exe'):
        if c and Path(c).is_file():
            return c
    pytest.skip('Git Bash not installed')


def guard_entry():
    [g] = [g for g in ENTRIES['hooks']['PreToolUse'] if 'tool_guard.py' in g['hooks'][0]['command']]
    return g


def bash(command, payload, project, tmp_path):
    env = dict(os.environ, CLAUDE_PROJECT_DIR=str(project), AOP_HARNESS_LOG=str(tmp_path / 'log.jsonl'))
    env.pop('AOP_TOOL_GUARD', None)
    return subprocess.run([git_bash(), '-c', command], input=json.dumps(payload).encode(), capture_output=True,
                          env=env, timeout=60)


def test_entry_matches_both_tools_and_keeps_the_launch_gate_first():
    g = guard_entry()
    assert set(g['matcher'].split('|')) == {'Bash', 'PowerShell', 'Monitor', BT}   # Monitor: INC-027; PowerShell: INC-037
    assert 'launch_gate.py' in ENTRIES['hooks']['PreToolUse'][0]['hooks'][0]['command']   # test_hook_commands' cmd()


def test_settings_command_denies_through_json(tmp_path):
    cmd = guard_entry()['hooks'][0]['command']
    r = bash(cmd, {'tool_name': 'Bash', 'tool_input': {'command': GATE_BAD[0]}}, REPO, tmp_path)
    assert r.returncode == 0
    assert json.loads(r.stdout)['hookSpecificOutput']['permissionDecision'] == 'deny'
    r = bash(cmd, {'tool_name': BT, 'tool_input': {'code': REPOINTS[1]}}, REPO, tmp_path)
    assert json.loads(r.stdout)['hookSpecificOutput']['permissionDecision'] == 'deny'


def test_settings_command_starts_python_only_for_the_gate_or_blender(tmp_path):
    """an ordinary Bash call costs the bash start only: Python never runs (a stub script records any start)"""
    proj = tmp_path / 'proj'
    (proj / '.claude' / 'hooks').mkdir(parents=True)
    marker = tmp_path / 'python_ran'
    (proj / '.claude' / 'hooks' / 'tool_guard.py').write_text(
        'import sys\nsys.stdin.buffer.read()\nopen(%r, "a").write("x")\n' % str(marker), encoding='utf-8')
    cmd = guard_entry()['hooks'][0]['command']
    r = bash(cmd, {'tool_name': 'Bash', 'tool_input': {'command': 'git status --short'}}, proj, tmp_path)
    assert r.returncode == 0 and r.stdout == b'' and not marker.exists()
    bash(cmd, {'tool_name': 'Bash', 'tool_input': {'command': 'python blender_gate.py | tail'}}, proj, tmp_path)
    assert marker.exists()


def test_settings_command_missing_script_fails_open(tmp_path):
    cmd = guard_entry()['hooks'][0]['command']
    r = bash(cmd, {'tool_name': 'Bash', 'tool_input': {'command': GATE_BAD[0]}}, tmp_path / 'nothing', tmp_path)
    assert r.returncode == 0 and r.stdout == b''


def test_status_lists_the_guard_as_pending_without_hiding_a_live_core(tmp_path, monkeypatch):
    """harness_status: a settings file with the gate + inbox but not the guard is still LIVE (with proof), and names
    tool_guard.py as not registered yet"""
    spec = importlib.util.spec_from_file_location('hs_guard', HOOKS / 'harness_status.py')
    hs = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(hs)
    log = tmp_path / 'log.jsonl'
    log.write_text(json.dumps({'t': '1', 'hook': 'launch_gate', 'decision': 'allow', 'session_id': 's'}) + '\n' +
                   json.dumps({'at': '2', 'src': 'inbox_hook', 'event': 'inbox_delivered', 'key': 'wf_a-1',
                               'agent_id_in_input': True}) + '\n', encoding='utf-8')
    monkeypatch.setenv('AOP_HARNESS_LOG', str(log))
    full = hs.merged({}, ENTRIES)
    core = json.loads(json.dumps(full))
    core['hooks']['PreToolUse'] = [g for g in core['hooks']['PreToolUse'] if 'tool_guard' not in json.dumps(g)]
    core['hooks'].pop('Stop', None)                     # turn_end_guard.py (INC-027) is not core either
    sp = tmp_path / 'settings.json'
    sp.write_text(json.dumps(core), encoding='utf-8')
    st = hs.status(sp)
    assert st['live'] is True and st['pending'] == ['tool_guard.py', 'turn_end_guard.py']
    assert 'not registered yet: tool_guard.py, turn_end_guard.py' in hs.text(st)
    sp.write_text(json.dumps(full), encoding='utf-8')
    st = hs.status(sp)
    assert st['live'] is True and st['pending'] == []
