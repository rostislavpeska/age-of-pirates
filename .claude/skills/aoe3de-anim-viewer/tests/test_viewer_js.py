"""aoe3de-anim-viewer browser modules under Node's built-in test runner (no install, no browser).

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests -q
    node --test .claude/skills/aoe3de-anim-viewer/tests/js/            (the same suite, minus the fixture case)

Writes a small bundle with av_common.BufferWriter into pytest's temp folder, so bundle.js is checked against the
Python writer value for value, then runs every tests/js/*.test.mjs. Skipped where Node (18 or newer) is missing.
CI-safe.
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import av_common as C  # noqa: E402

NODE = shutil.which('node')


def node_major():
    try:
        out = subprocess.run([NODE, '--version'], capture_output=True, text=True, timeout=30).stdout
        return int(out.strip().lstrip('v').split('.')[0])
    except (OSError, ValueError, subprocess.SubprocessError):
        return 0


def write_fixture(folder):
    arrays = {
        'position': (np.array([[0.0, 1.5, -2.25], [3.0, 4.0, 5.0]], np.float32), 'f32', 3, False),
        'normal': (np.array([[127, -127, 0, 1], [-128, 5, 64, 1]], np.int8), 'i8', 4, True),
        'uv': (np.array([[0.5, 1.0], [0.25, -2.0]], np.float16), 'f16', 2, False),
        'weights': (np.array([[255, 0, 0, 0], [128, 127, 0, 0]], np.uint8), 'u8', 4, True),
        'indices': (np.array([0, 1, 1, 70000], np.uint32), 'u32', 1, False),
    }
    w = C.BufferWriter('geo')
    views = {k: w.add(a, dt, comps, norm) for k, (a, dt, comps, norm) in arrays.items()}
    C.write_bytes(folder / 'geo.bin', w.data())
    manifest = {'schema': C.SCHEMA_NAME, 'schema_version': C.SCHEMA_VERSION, 'bundle_id': C.cache_key('fixture'),
                'buffers': [w.record()], 'test_views': views,
                'test_expect': {k: a.astype(np.float64).ravel().tolist() for k, (a, *_r) in arrays.items()}}
    C.write_json(folder / 'manifest.json', manifest)


@pytest.mark.skipif(not NODE, reason='node not on PATH')
def test_js_suite_under_node(tmp_path):
    """Includes INC-271 GPU stream buffer selection regression in buffer_streams.test.mjs."""
    if node_major() < 18:
        pytest.skip('node --test needs Node 18 or newer')
    write_fixture(tmp_path)
    files = sorted(str(p) for p in (HERE / 'js').glob('*.test.mjs'))
    assert files, 'no JS tests found'
    env = dict(os.environ, AV_BUNDLE_FIXTURE=str(tmp_path))
    r = subprocess.run([NODE, '--test', '--test-reporter=tap', *files], capture_output=True, text=True,
                       encoding='utf-8', errors='replace', timeout=300, env=env, cwd=str(HERE.parent))
    out = r.stdout + r.stderr
    assert r.returncode == 0, out[-6000:]
    assert '# fail 0' in out and '# skipped 0' in out, out[-3000:]
    assert 'MODULE_TYPELESS_PACKAGE_JSON' not in out, 'viewer/package.json must keep "type": "module"'
