"""aoe3de-anim-viewer shared helpers (scripts/av_common.py): protected-folder refusal, cache, provenance, JSON and
binary buffers.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests -q

Synthetic and CI-safe: every fixture is built in pytest's temp folder; the cache root is redirected there through
AOP_ANIM_VIEWER_CACHE. Needs Python and numpy only.
"""
import json
import os
import sys
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import av_common as C  # noqa: E402


@pytest.fixture(autouse=True)
def cache_in_tmp(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))
    return tmp_path / 'cache'


# ---------------------------------------------------------------- protected folders
def test_a_git_work_tree_is_refused_at_any_depth(tmp_path):
    repo = tmp_path / 'repo'
    (repo / '.git').mkdir(parents=True)
    for target in (repo / 'x.png', repo / 'a' / 'b' / 'c.json', repo):
        with pytest.raises(C.RepoPathError, match='git work tree'):
            C.refuse_repo_path(target)
    wt = tmp_path / 'worktree'                                   # a linked worktree has a .git FILE
    wt.mkdir()
    (wt / '.git').write_text('gitdir: elsewhere')
    assert C.is_repo_path(wt / 'out.png')


def test_aoe3_profile_mods_and_install_are_refused(tmp_path):
    profile = tmp_path / 'profile'
    (profile / 'mods').mkdir(parents=True)
    (profile / 'mods' / 'age3-mod-status.json').write_text('{}')
    install = tmp_path / 'AoE3DE'
    (install / 'Game').mkdir(parents=True)
    (install / 'AoE3DE_s.exe').write_bytes(b'MZ')
    for target, label in ((profile / 'mods' / 'local' / 'm' / 'x.png', 'mods folder'),
                          (profile / 'Screenshots' / 'x.png', 'profile folder'),
                          (install / 'Game' / 'Art' / 'x.png', 'install')):
        with pytest.raises(C.RepoPathError, match=label):
            C.refuse_repo_path(target)


def test_this_skill_folder_is_refused_when_it_sits_in_a_checkout():
    if C.git_root(C.SKILL_DIR) is None:
        pytest.skip('the skill is not inside a git work tree here (an exported copy)')
    with pytest.raises(C.RepoPathError):
        C.refuse_repo_path(C.SKILL_DIR / 'viewer' / 'shot.png')


def test_a_plain_temp_folder_is_accepted(tmp_path):
    p = C.refuse_repo_path(tmp_path / 'out' / 'x.png')
    assert p == Path(os.path.abspath(tmp_path / 'out' / 'x.png'))


def test_git_root_uses_bartools_walk(tmp_path):
    (tmp_path / 'r' / '.git').mkdir(parents=True)
    assert C.git_root(tmp_path / 'r' / 'deep' / 'x') == tmp_path / 'r'
    assert C.git_root(tmp_path / 'elsewhere') is None


# ---------------------------------------------------------------- cache and outputs
def test_cache_root_follows_the_environment_and_refuses_a_repo(tmp_path, monkeypatch, cache_in_tmp):
    assert C.cache_root() == Path(os.path.abspath(cache_in_tmp)) and cache_in_tmp.is_dir()
    (tmp_path / 'repo' / '.git').mkdir(parents=True)
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'repo' / 'cache'))
    with pytest.raises(C.RepoPathError):
        C.cache_root()
    assert not (tmp_path / 'repo' / 'cache').exists()


def test_cache_root_default_is_the_system_temp(monkeypatch):
    monkeypatch.delenv(C.CACHE_ENV, raising=False)
    import tempfile
    assert C.cache_root(create=False) == Path(os.path.abspath(Path(tempfile.gettempdir()) / 'aop-anim-viewer'))


def test_cache_key_is_stable_and_order_sensitive(tmp_path):
    k = C.cache_key('proto', 'ypIronFlail', {'b': 2, 'a': 1})
    assert k == C.cache_key('proto', 'ypIronFlail', {'a': 1, 'b': 2}) and len(k) == 16
    assert int(k, 16) >= 0
    assert k != C.cache_key('ypIronFlail', 'proto', {'a': 1, 'b': 2})
    assert C.cache_key(tmp_path / 'x') == C.cache_key(str(tmp_path / 'x'))


def test_cache_dir_and_output_dir(tmp_path, cache_in_tmp):
    d = C.cache_dir('bundle', 1)
    assert d.parent == Path(os.path.abspath(cache_in_tmp)) and d.name == C.cache_key('bundle', 1) and d.is_dir()
    o = C.output_dir(None, 'm 0/../x!')
    assert o.parent == Path(os.path.abspath(cache_in_tmp / 'out')) and o.is_dir()
    assert o.name.startswith('m_0_x-') and '.' not in o.name
    assert C.output_dir(tmp_path / 'mine') == Path(os.path.abspath(tmp_path / 'mine'))
    (tmp_path / 'repo' / '.git').mkdir(parents=True)
    with pytest.raises(C.RepoPathError):
        C.output_dir(tmp_path / 'repo' / 'renders')
    assert not (tmp_path / 'repo' / 'renders').exists()


def test_safe_name():
    assert C.safe_name('m0_readback.png') == 'm0_readback.png'
    assert C.safe_name('sheet-01.json') == 'sheet-01.json'
    for bad in ('../x.png', 'a/b.png', 'a' + chr(92) + 'b.png', '.hidden.png', 'x.exe', 'a..b.png', '', 'c:x.png'):
        with pytest.raises(ValueError):
            C.safe_name(bad)


# ---------------------------------------------------------------- provenance and paths
def test_logical_path():
    assert C.logical_path('Art' + chr(92) + 'Units' + chr(92) + 'Foo_0.GR2') == 'units/foo_0.gr2'
    assert C.logical_path('units' + chr(92) + 'asians' + chr(92) + 'chinese' + chr(92) + 'iron_rider_0') == \
        'units/asians/chinese/iron_rider_0'
    assert C.logical_path('/art//animation_library/cavalry/horse_idle_A.gr2') == 'animation_library/cavalry/horse_idle_a.gr2'
    assert C.logical_path('Data/tactics/handcavalrysplash.tactics') == 'data/tactics/handcavalrysplash.tactics'


def test_provenance_records_and_dedupe(tmp_path):
    f = tmp_path / 'a.xml'
    f.write_bytes(b'<animfile/>\r\n')
    prov = C.Provenance()
    i = prov.add('mod:age-of-pirates', 'units/x/a.xml', file=f)
    j = prov.add('mod:age-of-pirates', 'units/x/a.xml', data=f.read_bytes())
    k = prov.add('game', 'units/x/a.xml', data=b'other', container='ArtUnits.bar')
    assert i == j == 0 and k == 1 and len(prov.records) == 2
    r = prov.records[0]
    assert r['sha256'] == C.sha256_bytes(b'<animfile/>\r\n') == C.sha256_file(f) and r['size'] == 13
    assert set(r) == {'layer', 'path', 'sha256', 'size', 'container', 'note'}
    assert prov.records[1]['container'] == 'ArtUnits.bar'
    with pytest.raises(ValueError):
        C.provenance_record('game', 'x')


# ---------------------------------------------------------------- JSON
def test_write_json_is_atomic_and_refuses_bad_values(tmp_path):
    p = tmp_path / 'out' / 'manifest.json'
    C.write_json(p, {'schema': C.SCHEMA_NAME, 'v': np.float32(0.5), 'a': np.arange(3), 'p': tmp_path})
    d = C.read_json(p)
    assert d['v'] == 0.5 and d['a'] == [0, 1, 2] and d['p'] == str(tmp_path)
    raw = p.read_bytes()
    assert raw.endswith(b'\n') and b'\r\n' not in raw
    with pytest.raises(ValueError):                              # NaN: refused before the file is touched
        C.write_json(p, {'x': float('nan')})
    assert p.read_bytes() == raw
    assert [x.name for x in p.parent.iterdir()] == ['manifest.json']   # no temporary file left behind


def test_write_json_refuses_a_repo(tmp_path):
    (tmp_path / 'repo' / '.git').mkdir(parents=True)
    with pytest.raises(C.RepoPathError):
        C.write_json(tmp_path / 'repo' / 'm.json', {})
    assert not (tmp_path / 'repo' / 'm.json').exists()


# ---------------------------------------------------------------- binary buffers
def test_buffer_writer_aligns_every_view_and_round_trips():
    w = C.BufferWriter('geo')
    pos = np.array([[0, 1, 2], [3, 4, 5.5]], np.float32)
    nrm = np.array([[127, -127, 0, 1], [-128, 0, 64, 1]], np.int8)
    uv = np.array([[0.5, 1.0], [0.25, -2.0]], np.float16)
    idx = np.array([0, 1, 1], np.uint16)
    views = [w.add(pos, 'f32', 3), w.add(nrm, 'i8', 4, normalized=True), w.add(uv, 'f16', 2), w.add(idx, 'u16')]
    data = w.data()
    assert all(v['byteOffset'] % C.BUFFER_ALIGN == 0 for v in views)
    assert [v['byteOffset'] for v in views] == [0, 32, 48, 64]
    assert views[1]['normalized'] and not views[0]['normalized'] and views[3]['components'] == 1
    assert data[24:32] == b'\0' * 8                              # padding is zero bytes
    np.testing.assert_array_equal(C.read_view(data, views[0]), pos)
    np.testing.assert_array_equal(C.read_view(data, views[1]), nrm)
    np.testing.assert_array_equal(C.read_view(data, views[2]), uv)
    np.testing.assert_array_equal(C.read_view(data, views[3]), idx)
    rec = w.record()
    assert rec == {'id': 'geo', 'uri': 'geo.bin', 'byteLength': len(data), 'sha256': C.sha256_bytes(data)}


def test_buffer_writer_checks_dtype_and_components():
    w = C.BufferWriter('x')
    with pytest.raises(ValueError):
        w.add([1, 2, 3], 'f64')
    with pytest.raises(ValueError):
        w.add([1, 2, 3, 4], 'f32', components=3)


def test_schema_versions_agree_with_the_js_reader():
    js = (C.VIEWER_DIR / 'lib' / 'bundle.js').read_text(encoding='utf-8')
    assert "SCHEMA_NAME = '%s'" % C.SCHEMA_NAME in js
    assert 'SCHEMA_VERSION = %d;' % C.SCHEMA_VERSION in js
    assert 'ALIGN = %d;' % C.BUFFER_ALIGN in js
    for name in C.DTYPES:
        assert '%s:' % name in js, name


# ---------------------------------------------------------------- local tool paths
def test_local_tool_path(tmp_path):
    cfg = tmp_path / 'config' / 'tool-paths.local.json'
    cfg.parent.mkdir()
    cfg.write_text(json.dumps({'tools': {'chrome': {'path': 'X:/c/chrome.exe'}, 'edge': {'path': ''}}}))
    assert C.local_tool_path('chrome', cfg) == 'X:/c/chrome.exe'
    assert C.local_tool_path('edge', cfg) is None and C.local_tool_path('blender', cfg) is None
    assert C.find_tool_config(tmp_path / 'config' / 'deeper') == cfg
    cfg.write_text('{broken')
    assert C.local_tool_path('chrome', cfg) is None
    assert C.local_tool_path('chrome', tmp_path / 'absent.json') is None
