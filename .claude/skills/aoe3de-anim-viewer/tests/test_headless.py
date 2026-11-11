"""aoe3de-anim-viewer headless runner (scripts/headless.py) and the M0 spike.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests -q            # CI: add -m "not local"

The first group is synthetic and CI-safe: browser discovery from a fake device config, the command line (headless,
throwaway profile), the INC-237 guards (Edge never automatic, a pending update swap refused) and the no-browser path.
The M0 cases run the real spike page in this device's Chrome, headless (no window, no screen), with the cache and the
outputs in pytest's temp folder. They carry the consumer's bare `local` marker (the owner's machine; CI deselects
them) and skip where no Chrome is selected. Each texel the GPU returned is checked against an independent Python
decoder of the block bytes the page reports (exact float maths and NVIDIA's rounding, see viewer/lib/s3tc.js).
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
import headless as H  # noqa: E402


@pytest.fixture(autouse=True)
def cache_in_tmp(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))
    monkeypatch.delenv(H.BROWSER_ENV, raising=False)


def fake_exe(folder, name):
    p = Path(folder) / name
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(b'MZ')
    return p


def fake_config(tmp_path, **tools):
    cfg = tmp_path / 'config' / 'tool-paths.local.json'
    cfg.parent.mkdir(parents=True, exist_ok=True)
    cfg.write_text(json.dumps({'tools': {k: {'path': str(v)} for k, v in tools.items()}}))
    return cfg


# ---------------------------------------------------------------- synthetic, CI-safe
def test_discovery_order_and_sources(tmp_path):
    chrome = fake_exe(tmp_path / 'g', 'chrome.exe')
    edge = fake_exe(tmp_path / 'm', 'msedge.exe')
    other = fake_exe(tmp_path / 'p', 'chromium')
    cfg = fake_config(tmp_path, chrome=chrome, edge=edge)
    which = lambda n: str(other) if n == 'chromium' else None   # noqa: E731
    found = H.find_browsers(None, cfg, env={}, which=which)
    assert [(b['name'], b['source']) for b in found] == [
        ('chrome', 'config tools.chrome.path'), ('edge', 'config tools.edge.path'), ('chrome', 'PATH (chromium)')]
    found = H.find_browsers(None, fake_config(tmp_path, edge=edge), env={}, which=which)
    assert [b['source'] for b in found] == ['config tools.edge.path', 'PATH (chromium)']
    assert [b['name'] for b in H.find_browsers('edge', cfg, env={}, which=which)] == ['edge']
    env = {H.BROWSER_ENV: str(other)}
    assert H.find_browsers(None, cfg, env=env, which=which)[0]['source'] == H.BROWSER_ENV


def test_missing_files_and_duplicates_are_dropped(tmp_path):
    chrome = fake_exe(tmp_path / 'g', 'chrome.exe')
    cfg = fake_config(tmp_path, chrome=tmp_path / 'absent' / 'chrome.exe', edge='')
    assert H.find_browsers(None, cfg, env={}, which=lambda n: None) == []
    cfg = fake_config(tmp_path, chrome=chrome)
    found = H.find_browsers(None, cfg, env={}, which=lambda n: str(chrome) if n == 'chrome' else None)
    assert len(found) == 1


def test_edge_is_never_an_automatic_choice(tmp_path):
    """INC-237: Edge's launcher opened a visible window on the owner's profile; it runs only when named."""
    chrome = fake_exe(tmp_path / 'g', 'chrome.exe')
    edge = fake_exe(tmp_path / 'm', 'msedge.exe')
    none = lambda n: None                                        # noqa: E731
    cfg = fake_config(tmp_path, chrome=chrome, edge=edge)
    assert [b['name'] for b in H.select_browsers(None, cfg, env={}, which=none)] == ['chrome']
    assert H.select_browsers(None, fake_config(tmp_path, edge=edge), env={}, which=none) == []
    assert [b['name'] for b in H.select_browsers('edge', cfg, env={}, which=none)] == ['edge']
    env = {H.BROWSER_ENV: str(edge)}
    assert [b['source'] for b in H.select_browsers(None, cfg, env=env, which=none)] == [H.BROWSER_ENV]


def test_a_pending_update_swap_is_refused(tmp_path):
    chrome = fake_exe(tmp_path / 'g', 'chrome.exe')
    assert H.pending_update(chrome) is None
    fake_exe(tmp_path / 'g', 'new_chrome.exe')
    assert 'update swap pending' in H.pending_update(chrome)
    rec = H.run_page('m0/index.html', out_dir=tmp_path / 'out', browser={'name': 'chrome', 'path': str(chrome),
                                                                         'source': 'test'}, log=lambda *_: None)
    assert rec['status'] == 'refused' and 'new_chrome.exe' in rec['error']
    assert C.read_json(tmp_path / 'out' / 'run.json')['status'] == 'refused'


def test_command_line_is_headless_with_a_throwaway_profile(tmp_path):
    prof = H.profile_dir('t1')
    assert prof.parent == Path(os.path.abspath(tmp_path / 'cache' / 'profiles')) and prof.is_dir()
    cmd = H.browser_command('X:/chrome.exe', 'http://127.0.0.1:1/viewer/m0/index.html?token=t', prof)
    assert cmd[0] == 'X:/chrome.exe' and cmd[-1].startswith('http://127.0.0.1:1/')
    assert '--headless=new' in cmd and '--user-data-dir=%s' % prof in cmd
    assert sum(a.startswith('--user-data-dir=') for a in cmd) == 1
    assert not any('swiftshader' in a for a in cmd)
    sw = H.browser_command('X:/chrome.exe', 'u', prof, 'swiftshader')
    assert '--use-angle=swiftshader' in sw and '--enable-unsafe-swiftshader' in sw
    assert '--use-angle=d3d11' in H.browser_command('X:/chrome.exe', 'u', prof, 'd3d11')
    with pytest.raises(ValueError):
        H.browser_command('X:/chrome.exe', 'u', prof, 'opengl')


def test_profiles_never_go_into_a_repo(tmp_path, monkeypatch):
    (tmp_path / 'repo' / '.git').mkdir(parents=True)
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'repo' / 'cache'))
    with pytest.raises(C.RepoPathError):
        H.profile_dir('t2')


def test_no_browser_is_reported_not_raised(tmp_path):
    rec = H.run_page('m0/index.html', out_dir=tmp_path / 'out', browser=None, log=lambda *_: None)
    assert rec['status'] == 'no-browser' and C.read_json(tmp_path / 'out' / 'run.json')['status'] == 'no-browser'
    res = H.run_m0(tmp_path / 'm0', browser=str(tmp_path / 'absent.exe'), log=lambda *_: None)
    assert res['summary']['status'] == 'no-browser' and res['browsers_selected'] == [] and res['runs'] == []


def test_an_explicit_path_is_the_only_candidate(tmp_path):
    chrome = fake_exe(tmp_path / 'g', 'chrome.exe')
    edge = fake_exe(tmp_path / 'm', 'msedge.exe')
    cfg = fake_config(tmp_path, chrome=chrome, edge=edge)
    mine = fake_exe(tmp_path / 'x', 'chromium.exe')
    assert [b['path'] for b in H.find_browsers(str(mine), cfg, env={}, which=lambda n: None)] == [str(mine)]
    assert H.find_browsers(str(tmp_path / 'absent.exe'), cfg, env={}, which=lambda n: None) == []
    assert H.select_browsers(str(tmp_path / 'absent.exe'), cfg, env={}, which=lambda n: None) == []


def test_an_undeletable_profile_is_reported_with_its_holders(tmp_path, monkeypatch):
    """2026-10-11 review: the INC-237 Edge launcher exited at once, its orphaned browser kept the throwaway profile for
    hours, and the run record said nothing. A 'browser' that exits at once (python refusing the Chromium flags) and a
    profile that will not delete must show up as profile_deleted False plus the holders."""
    monkeypatch.setattr(H, '_rmtree_retry', lambda p, tries=20: False)
    monkeypatch.setattr(H, 'profile_holders', lambda p: [{'pid': 4242, 'app': 'Fake Browser'}])
    lines = []
    rec = H.run_page('m0/index.html', out_dir=tmp_path / 'out', timeout=20, log=lines.append,
                     browser={'name': 'custom', 'path': sys.executable, 'source': 'test'})
    assert rec['status'] in ('browser-handoff', 'browser-exited')
    assert rec['profile_deleted'] is False and rec['profile_holders'] == [{'pid': 4242, 'app': 'Fake Browser'}]
    assert Path(rec['profile']).parent == Path(os.path.abspath(tmp_path / 'cache' / 'profiles'))
    on_disk = C.read_json(tmp_path / 'out' / 'run.json')
    assert on_disk['profile_deleted'] is False and on_disk['profile_holders'][0]['pid'] == 4242
    assert any('NOT deleted' in m and 'pid 4242' in m for m in lines)


def test_a_deleted_profile_is_recorded(tmp_path):
    rec = H.run_page('m0/index.html', out_dir=tmp_path / 'out', timeout=20, log=lambda *_: None,
                     browser={'name': 'custom', 'path': sys.executable, 'source': 'test'})
    assert rec['profile_deleted'] is True and rec['profile_holders'] == [] and not Path(rec['profile']).exists()


@pytest.mark.skipif(os.name != 'nt', reason='the Restart Manager query is Windows-only')
def test_profile_holders_names_the_process_that_holds_the_lockfile(tmp_path):
    import subprocess
    prof = tmp_path / 'prof'
    prof.mkdir()
    assert H.profile_holders(prof) is None                       # no lockfile: nothing to ask
    lock = prof / 'lockfile'
    lock.write_bytes(b'')
    assert H.profile_holders(prof) == []
    child = subprocess.Popen([sys.executable, '-c', 'import sys, time; f = open(sys.argv[1], "rb"); '
                              'print("held", flush=True); time.sleep(60)', str(lock)],
                             stdout=subprocess.PIPE, text=True)
    try:
        assert child.stdout.readline().strip() == 'held'
        assert child.pid in [h['pid'] for h in H.profile_holders(prof)]
    finally:
        child.kill()                                             # this test's own child process
        child.wait(10)


def test_summary_of_a_page_result():
    rec = {'status': 'done', 'gpu_mode': 'auto', 'browser': {'name': 'chrome'}, 'elapsed_s': 1.0, 'out_dir': 'O',
           'result': {'status': 'ok', 'gpu_path': 'angle-d3d11', 'webgl2': True, 'png': 'm0_readback.png',
                      'renderer': {'renderer': 'r', 'unmasked_renderer': 'ANGLE (x, D3D11)'},
                      'texture_decoder': 'nvidia-hardware',
                      'regions': [{'id': 'dxt1', 'path': 's3tc', 'decoder_match': 'nvidia-hardware',
                                   'max_abs_error': 0.0002, 'max_value': 1.0,
                                   'errors': {'exact': {'rgb': 0.0196, 'alpha': 0.0}, 'nvidia': {'rgb': 0.0002, 'alpha': 0.0}}}]}}
    s = H.summarise_m0(rec)
    assert s['renderer'] == 'ANGLE (x, D3D11)' and s['regions']['dxt1']['error_exact_rgb'] == 0.0196
    assert s['png'] == str(Path('O') / 'm0_readback.png') and s['page_status'] == 'ok'


# ---------------------------------------------------------------- independent reference decoder (Python)
def _unpack565(c):
    r, g, b = (c >> 11) & 31, (c >> 5) & 63, c & 31
    return [(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)]


def _bc1_palette(w0, w1, four, model):
    e0, e1 = _unpack565(w0), _unpack565(w1)
    pal = [[v / 255 for v in e0] + [1.0], [v / 255 for v in e1] + [1.0]]
    four = four or w0 > w1
    if model == 'exact':
        if four:
            pal += [[(2 * a + b) / 3 / 255 for a, b in zip(e0, e1)] + [1.0],
                    [(a + 2 * b) / 3 / 255 for a, b in zip(e0, e1)] + [1.0]]
        else:
            pal += [[(a + b) / 2 / 255 for a, b in zip(e0, e1)] + [1.0]]
    else:                                                        # NVIDIA: integer maths, C division semantics
        r0, b0, r1, b1 = w0 >> 11 & 31, w0 & 31, w1 >> 11 & 31, w1 & 31
        def third5(a, b): return ((2 * a + b) * 22) // 8
        def half5(a, b): return ((a + b) * 33) // 8
        def g6(g0, g1, k): d = g1 - g0; return (256 * g0 + int(d / 4) + 128 + d * k) // 256
        if four:
            pal += [[third5(r0, r1) / 255, g6(e0[1], e1[1], 80) / 255, third5(b0, b1) / 255, 1.0],
                    [third5(r1, r0) / 255, g6(e1[1], e0[1], 80) / 255, third5(b1, b0) / 255, 1.0]]
        else:
            pal += [[half5(r0, r1) / 255, g6(e0[1], e1[1], 128) / 255, half5(b0, b1) / 255, 1.0]]
    if not four:
        pal.append([0.0, 0.0, 0.0, 0.0])
    return pal


def decode_texture(blocks, bc3, model, width=8, height=8):
    bpb = 16 if bc3 else 8
    out = np.zeros((height, width, 4))
    bw = width // 4
    for n in range(len(blocks) // bpb):
        blk = blocks[n * bpb:(n + 1) * bpb]
        col = blk[8:] if bc3 else blk
        w0, w1 = col[0] | col[1] << 8, col[2] | col[3] << 8
        pal = _bc1_palette(w0, w1, bc3, model)
        bits = int.from_bytes(col[4:8], 'little')
        if bc3:
            a0, a1 = blk[0], blk[1]
            ap = [a0, a1] + ([((7 - i) * a0 + i * a1) / 7 for i in range(1, 7)] if a0 > a1 else
                             [((5 - i) * a0 + i * a1) / 5 for i in range(1, 5)] + [0, 255])
            abits = int.from_bytes(blk[2:8], 'little')
        for i in range(16):
            y, x = (n // bw) * 4 + i // 4, (n % bw) * 4 + i % 4
            out[y, x] = pal[(bits >> 2 * i) & 3]
            if bc3:
                out[y, x, 3] = ap[(abits >> 3 * i) & 7] / 255
    return out


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def test_reference_decoder_on_hand_made_blocks():
    red_blue = bytes([0x00, 0xF8, 0x1F, 0x00, 0xE4, 0xE4, 0xE4, 0xE4])     # 4-colour ramp per row
    t = decode_texture(red_blue * 4, False, 'exact')
    np.testing.assert_allclose(t[0, :4], [[1, 0, 0, 1], [0, 0, 1, 1], [2 / 3, 0, 1 / 3, 1], [1 / 3, 0, 2 / 3, 1]])
    punch = bytes([0xE0, 0x07, 0xFF, 0xFF, 0xE4, 0xE4, 0xE4, 0xE4])         # green < white: 3-colour, index 3 clear
    assert list(decode_texture(punch * 4, False, 'exact')[0, 3]) == [0, 0, 0, 0]
    yellow_black = bytes([0xE0, 0xFF, 0x00, 0x00, 0xE4, 0xE4, 0xE4, 0xE4])
    nv = decode_texture(yellow_black * 4, False, 'nvidia')
    assert round(nv[0, 2, 1] * 255) == 175 and round(nv[0, 3, 1] * 255) == 80 and round(nv[0, 2, 0] * 255) == 170


# ---------------------------------------------------------------- the M0 spike in this device's Chrome (local)
CHROME = H.select_browsers()


@pytest.mark.local
@pytest.mark.skipif(not CHROME, reason='no Chrome selected on this device (config tools.chrome.path or PATH)')
@pytest.mark.parametrize('mode', ['auto', 'swiftshader'])
def test_m0_spike_renders_s3tc_into_a_float_target(tmp_path, mode):
    res = H.run_m0(tmp_path / 'm0', gpu=mode, timeout=90, log=lambda *_: None)
    s = res['summary']
    assert s['status'] in ('ok', 'degraded'), json.dumps(res['runs'], indent=1)[:3000]
    run = s[mode]
    assert run['webgl2'] and run['target']['complete'] and run['hdr_kept']
    assert not run['leftover_processes'], run['leftover_processes']
    for name in ('EXT_color_buffer_float', 'WEBGL_compressed_texture_s3tc', 'WEBGL_compressed_texture_s3tc_srgb'):
        assert name in run['extensions']
    page = C.read_json(Path(res['out_dir']) / ('%s-chrome' % mode) / 'run.json')['result']
    for g in page['regions']:
        got = np.array(g['samples']).reshape(8, 8, 4)
        blocks = bytes.fromhex(g['blocks_hex'])
        errs = {}
        for model in ('exact', 'nvidia'):
            want = decode_texture(blocks, 'DXT5' in g['format'], model)
            if g['srgb']:
                want[..., :3] = srgb_to_linear(want[..., :3])
            want[..., :3] *= g['scale']
            errs[model] = (np.abs(got[..., :3] - want[..., :3]).max(), np.abs(got[..., 3] - want[..., 3]).max())
        best_rgb = min(errs['exact'][0], errs['nvidia'][0])
        assert best_rgb <= 0.006 * g['scale'], (g['id'], errs)
        assert errs['exact'][1] <= 0.03, (g['id'], errs)               # NVIDIA's BC3 alpha rounding: up to 6/255
        assert g['uniformity_max_dev'] <= 1e-3
    png = Path(run['png'])
    assert png.is_file() and not C.is_repo_path(png)
    PIL = pytest.importorskip('PIL.Image')
    im = PIL.open(png).convert('RGB')
    assert im.size == (512, 512)
    assert im.getpixel((16, 511 - 16)) == (255, 0, 0)                  # dxt1 region, texel (0, 0): red
    assert im.getpixel((48, 511 - 16)) == (0, 0, 255)                  # texel (1, 0): blue
    assert not any((tmp_path / 'cache' / 'profiles').iterdir())          # the throwaway profile was deleted
