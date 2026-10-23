"""INC-601 / KTC-506 native process-path controls; audit observer-53.

No executable or DLL is launched: the process stand-in reproduces the Windows
working-directory failure from the retained R40 candidate validation.
"""
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import gr2_lint as L


def inputs(tmp_path):
    # The actual R40 evidence parent is 125 characters. Keep this control long
    # enough to reproduce its final 270-character native working directory.
    root = tmp_path
    while len(str(root)) < 130:
        root /= 'evidence'
    root.mkdir(parents=True)
    src, exe, dll, dst = [root / name for name in ('source.gr2', 'tool.exe', 'runtime.dll', 'flat.gr2')]
    for path in (src, exe, dll):
        path.write_bytes(path.name.encode())
    return src, dst, exe, dll


def test_long_evidence_path_does_not_become_native_process_cwd(tmp_path, monkeypatch):
    src, dst, exe, dll = inputs(tmp_path)
    workdirs = []

    def process(argv, *, cwd, capture_output, timeout):
        work = Path(cwd)
        workdirs.append(work)
        if len(str(work)) >= 260:
            raise NotADirectoryError(20, 'The directory name is invalid (Win32 267)')
        assert (work / 'in.gr2').read_bytes() == src.read_bytes()
        assert (work / 'granny2_age3de.dll').read_bytes() == dll.read_bytes()
        assert Path(argv[0]) == work / 'gr2raw.exe'
        assert Path(argv[0]).read_bytes() == exe.read_bytes()
        assert timeout == 300 and capture_output
        (work / 'out.gr2').write_bytes(b'identical native output')
        return subprocess.CompletedProcess(argv, 0, b'', b'')

    monkeypatch.setattr(L.subprocess, 'run', process)
    rc, tail = L._dll_native(None, src, dst, exe, dll)
    assert rc == 0, tail
    assert dst.read_bytes() == b'identical native output'
    assert len(workdirs) == len(L.NATIVE_LAYOUTS) == 3
    assert [len(p.name) - len(workdirs[0].name) for p in workdirs] == [0, 64, 128]
    assert all(not p.exists() for p in workdirs)


@pytest.mark.parametrize('failure', ['different', 'empty', 'crash', 'launch'])
def test_native_failure_keeps_all_layout_checks_and_does_not_publish(tmp_path, monkeypatch, failure):
    src, dst, exe, dll = inputs(tmp_path)
    dst.write_bytes(b'previous output')
    workdirs = []

    def process(argv, *, cwd, **kwargs):
        work = Path(cwd)
        workdirs.append(work)
        if failure == 'launch':
            raise OSError('process launch failed')
        if failure != 'empty':
            (work / 'out.gr2').write_bytes(str(len(workdirs)).encode() if failure == 'different' else b'output')
        return subprocess.CompletedProcess(argv, 0xC0000005 if failure == 'crash' else 0, b'', b'')

    monkeypatch.setattr(L.subprocess, 'run', process)
    rc, tail = L._dll_native(None, src, dst, exe, dll)
    assert rc != 0
    assert tail
    assert len(workdirs) == len(L.NATIVE_LAYOUTS)
    assert dst.read_bytes() == b'previous output'
    assert all(not p.exists() for p in workdirs)


def test_copy_failure_also_releases_native_workspace(tmp_path, monkeypatch):
    src, dst, exe, dll = inputs(tmp_path)
    workdirs = []

    def failed_copy(source, target):
        workdirs.append(Path(target).parent)
        raise OSError('input copy failed')

    monkeypatch.setattr(L.shutil, 'copyfile', failed_copy)
    with pytest.raises(OSError, match='input copy failed'):
        L._dll_native(None, src, dst, exe, dll)
    assert all(not p.exists() for p in workdirs)


@pytest.mark.parametrize('native_bytes,native_rc,expected', [
    (b'same output', 0, 'PASS'),
    (b'different output', 0, 'FAIL'),
    (None, None, 'FAIL'),
])
def test_both_routes_still_require_identical_successful_outputs(tmp_path, monkeypatch, native_bytes, native_rc, expected):
    src, dst, exe, dll = inputs(tmp_path)
    tools, reports = tmp_path / 'tools', tmp_path / 'reports'
    tools.mkdir()
    reports.mkdir()
    (tools / 'gr2_to_raw.py').write_text('# stand-in only', encoding='utf-8')
    monkeypatch.setitem(sys.modules, 'gr2_to_raw', SimpleNamespace(build_exe=lambda: b'tool', DISTRO='test'))
    values = {'AOP_GR2_DLL_ROUTE': 'both', 'AOP_GR2_DLL': str(dll)}
    monkeypatch.setattr(L, '_local_value', values.get)
    monkeypatch.setattr(L, 'smart_app_control_on', lambda: False)
    called = []

    def wsl(g2r, source, target, tool, distro):
        called.append('wsl')
        target.write_bytes(b'same output')
        return 0, ''

    def native(g2r, source, target, tool, library):
        called.append('native')
        if native_bytes is not None:
            target.write_bytes(native_bytes)
        return native_rc, '' if native_rc == 0 else 'launch failed'

    monkeypatch.setattr(L, '_dll_wsl', wsl)
    monkeypatch.setattr(L, '_dll_native', native)
    report = L.dll_read(src, tools, reports)
    assert called == ['wsl', 'native']
    assert report['status'] == expected
    assert report['route'] == 'both'
    assert report['runs']['native']['rc'] == native_rc
