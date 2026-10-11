"""tangent_compare.py on a synthetic UV sphere whose stored tangents are Blender's own; skips without Blender.

    python -B -m pytest .claude/skills/blender-organic-modeling/scripts -q -p no:cacheprovider
"""
import json
import subprocess
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import blender_env as E  # noqa: E402

BLENDER = E.find_blender()
pytestmark = pytest.mark.skipif(not BLENDER, reason='Blender not found (set BLENDER or put blender on PATH)')


def run(args):
    return subprocess.run(E.blender_command(BLENDER, HERE / 'tangent_compare.py', args), capture_output=True,
                          text=True, errors='replace', timeout=300)


def test_mikktspace_input_matches_in_the_v_convention_only(tmp_path):
    src, out = tmp_path / 'sphere.json', tmp_path / 'result.json'
    assert run(['--make-synthetic', src]).returncode == 0
    r = run(['--input', src, '--out', out])
    assert r.returncode == 0, r.stdout[-2000:] + r.stderr[-2000:]
    rec = json.loads(out.read_text(encoding='utf-8'))['results'][0]
    assert rec['v']['tangent_dot_median'] > 0.999 and rec['v']['sign_agree'] > 0.99
    assert rec['1-v']['sign_agree'] < 0.01          # flipping v flips the bitangent sign, nothing else


def test_int8_scaled_vectors_are_normalized(tmp_path):
    src, out = tmp_path / 'sphere.json', tmp_path / 'result.json'
    assert run(['--make-synthetic', src]).returncode == 0
    data = json.loads(src.read_text(encoding='utf-8'))
    m = data[0]['meshes'][0]
    m['N'] = [[round(c * 127) for c in n] + [0] for n in m['N']]
    m['T'] = [[round(c * 127) for c in t[:3]] + [127 if t[3] >= 0 else -127] for t in m['T']]
    m['I'] = [[i] for i in m['I']]                   # nested indices, as some readers return them
    src.write_text(json.dumps(data), encoding='utf-8')
    assert run(['--input', src, '--out', out]).returncode == 0
    rec = json.loads(out.read_text(encoding='utf-8'))['results'][0]
    assert rec['v']['tangent_dot_p05'] > 0.99 and rec['v']['sign_agree'] > 0.99


@pytest.mark.parametrize('content', [None, '[{"file": "x", "meshes": [', json.dumps([{'file': 'x', 'meshes': [
    {'name': 'm', 'P': [[0, 0, 0]] * 3, 'N': [[0, 0, 1]] * 3, 'T': [[1, 0, 0]] * 3, 'UV': [[0, 0]] * 3,
     'I': [0, 1, 2]}]}]), json.dumps([{'file': 'x', 'meshes': [
    {'name': 'm', 'P': [[0, 0, 0]] * 3, 'N': [[0, 0, 1]] * 3, 'T': [[1, 0, 0, 1]] * 3, 'UV': [[0, 0]] * 3,
     'I': [0, 1, 7]}]}])], ids=['missing', 'not_json', 'tangent_without_w', 'index_out_of_range'])
def test_missing_or_malformed_input_exits_2_without_output(tmp_path, content):
    src, out = tmp_path / 'input.json', tmp_path / 'result.json'
    if content is not None:
        src.write_text(content, encoding='utf-8')
    r = run(['--input', src, '--out', out])
    assert r.returncode == 2 and 'SETUP ERROR' in r.stderr and '--input' in r.stderr, r.stderr[-1500:]
    assert 'Traceback' not in r.stderr and not out.exists()


def test_output_inside_a_git_work_tree_is_refused(tmp_path):
    target = HERE / 'refused_tangents.json'
    r = run(['--make-synthetic', target])
    assert r.returncode == 2 and 'git work tree' in r.stderr and not target.exists()
