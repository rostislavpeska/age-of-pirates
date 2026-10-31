"""aoe3de-anim-viewer M5: render / video / compare on the vanilla Iron Flail in headless Chrome (the owner's machine).

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_export_local.py -q

Local only (the `local` marker; skipped without the game or Chrome; the video tests also without ffmpeg in
config/tool-paths.local.json). No window: headless.py runs Chrome with --headless=new and a throwaway profile; bundles,
lighting packs, PNGs, sheets and videos go to pytest's temp folder (never a repository).
- render --at tags with four cameras (game + ortho3) and --metrics: one cell per tag stop and camera, the Attack at
  0.81 s on key 156 of 289, a <png>.cell.json per cell with the fidelity block (export stages included), one sheet,
  geometry and metrics on the first camera only, the throwaway profile deleted;
- render --at fps=8 on Walk: floor(D x 8) + 1 cells at i / 8 s;
- determinism: the same time rendered twice gives the same pixels, through a job long enough to travel over
  GET /api/job (job=@server);
- video: an MP4 (H.264 yuv420p, moov before mdat) and an animated WebP of Attack_melee v0 at 10 fps x 2 loops with the
  timeline overlay; 15 distinct poses for 30 frames; the Attack flash on frames 9 and 24;
- compare Walk against the vanilla Oprichnik (and a side-by-side video): one clock, both units at every tag stop,
  the rider-horse penetration (the Iron Flail rider's calves sit about 0.29 m inside its barded horse, the Oprichnik
  rider about 0.04 m: measured 2026-10-11) and the front-left hoof on the ground at its FootstepLeft tag.
"""
import json
import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import av_common as C  # noqa: E402

pytestmark = pytest.mark.local


@pytest.fixture(scope='module')
def env(tmp_path_factory):
    mp = pytest.MonkeyPatch()
    root = tmp_path_factory.mktemp('export-local')
    mp.setenv(C.CACHE_ENV, str(root / 'cache'))
    try:
        import gr2_model  # noqa: F401
        import bundle as B
        import headless as H
        import vfs as V
    except ImportError as e:
        mp.undo()
        pytest.skip(str(e))
    if not H.select_browsers():
        mp.undo()
        pytest.skip('no Chrome (config tools.chrome.path, AOP_ANIM_VIEWER_BROWSER or PATH)')
    fs = V.VFS()
    if not any(lay.kind == 'game' for lay in fs.layers):
        mp.undo()
        pytest.skip('no AoE3 DE install found')
    res = B.build_bundle(proto='ypIronFlail', fs=fs, log=lambda m: None)
    yield {'bid': res.bundle_id, 'm': res.manifest, 'root': root, 'H': H}
    mp.undo()


def av(*args):
    import anim_viewer as AV
    return AV.main([str(a) for a in args])


def clean_run(rep):
    run = rep['run']
    assert run['status'] == 'done' and run['profile_deleted'] is True and not run['profile_holders'], run


def ffmpeg_or_skip():
    import video as VD
    try:
        return VD.ffmpeg_path()
    except VD.FfmpegMissing as e:
        pytest.skip(str(e))


def test_render_at_tags_four_cameras_sidecars_sheet_metrics(env):
    out = env['root'] / 'tags'
    assert av('render', '--bundle', env['bid'], '--anim', 'Attack_melee', '--at', 'tags', '--cam', 'game,ortho3',
              '--size', 256, '--metrics', '--out', out) == 0
    rep = json.loads((out / 'report.json').read_text(encoding='utf-8'))
    clean_run(rep)
    cells = rep['cells']
    assert len(cells) == 8 and rep['cameras'] == ['game', 'front', 'side', 'top']
    assert sorted({round(c['time'], 6) for c in cells}) == [0.6, 0.81]
    atk = [c for c in cells if c['tag'] == 'Attack']
    assert len(atk) == 4 and all(c['key'] == 156 and c['keys_of'] == 289 for c in atk)
    assert atk[0]['clip'] == 'animation_library/cavalry/horse_1-5_attack_a.gr2' and atk[0]['D'] == pytest.approx(1.5)
    for c in cells:
        side = json.loads((out / (Path(c['png']).stem + '.cell.json')).read_text(encoding='utf-8'))
        for k in ('anim', 'variant', 'clip', 'key', 'time', 'tag', 'fidelity', 'camera', 'bundle_id', 'keys'):
            assert k in side, k
        st = side['fidelity']['stages']
        assert st['export_frame_times'] == 'M' and st['metric_penetration'] == 'A' and st['camera'] == 'U'
        assert side['framing'] == 'clip'
        assert ('metrics' in side) == (side['camera'] == 'game'), 'geometry and metrics on the first camera only'
    g = [c for c in cells if c['camera'] == 'game' and c['tag'] == 'Attack'][0]
    pen = g['metrics']['penetration']
    assert pen['status'] == 'ok' and pen['n_points'] > 500 and 0.1 < pen['max_depth'] < 0.5
    assert (out / 'sheet_Attack_melee.png').is_file()
    sheet = json.loads((out / 'sheet_Attack_melee.json').read_text(encoding='utf-8'))
    assert len(sheet['cells']) == 8 and sheet['columns'] == ['game', 'front', 'side', 'top']
    assert sheet['fidelity']['counts']['U'] >= 1
    front = np.asarray(Image.open(out / [c['png'] for c in atk if c['camera'] == 'front'][0]))
    side_ = np.asarray(Image.open(out / [c['png'] for c in atk if c['camera'] == 'side'][0]))
    assert np.abs(front.astype(int) - side_.astype(int)).mean() > 2, 'the ortho views differ'
    assert rep['skipped'] == []


def test_render_at_fps_counts_cells(env):
    out = env['root'] / 'fps'
    assert av('render', '--bundle', env['bid'], '--anim', 'Walk', '--at', 'fps=8', '--size', 128, '--out', out) == 0
    rep = json.loads((out / 'report.json').read_text(encoding='utf-8'))
    import anim_viewer as AV
    D = AV.main_duration(env['m'], 'Walk', 0)
    n = int(np.floor(D * 8 + 1e-9)) + 1
    assert len(rep['cells']) == n
    assert [round(c['time'], 9) for c in rep['cells']] == [round(min(i / 8, D), 9) for i in range(n)]


def test_same_time_same_pixels_through_the_server_job_route(env):
    out = env['root'] / 'det'
    job = {'width': 160, 'height': 160, 'bounds': 'clip', 'comment': 'x' * 7000,
           'frames': [{'name': 'd', 'anim': 'Attack_melee', 'variant': 0, 'times': [0.81, 0.3, 0.81]}]}
    from urllib.parse import quote
    H = env['H']
    assert len(quote(json.dumps(job, separators=(',', ':')), safe='-_.~')) > H.URL_JOB_LIMIT, 'travels over /api/job'
    rec = H.run_job(env['bid'], job, out_dir=out, timeout=180, log=lambda m: None, label='det')
    assert rec['status'] == 'done', rec.get('error')
    assert rec['profile_deleted'] is True
    a, b, c = (np.asarray(Image.open(out / ('d_%05d.png' % i))) for i in range(3))
    assert np.array_equal(a, c), 'the same exact time renders the same pixels'
    assert not np.array_equal(a, b)
    frames = rec['result']['frames']
    assert [f['expand']['kind'] for f in frames] == ['times'] * 3 and frames[0]['cell']['key'] == 156


def test_video_mp4_webp_overlay(env):
    import video as VD
    ff = ffmpeg_or_skip()
    out = env['root'] / 'video'
    assert av('video', '--bundle', env['bid'], '--anim', 'Attack_melee', '--variant', 0, '--fps', 10, '--loops', 2,
              '--timeline-overlay', '--webp', '--size', 200, '--out', out) == 0
    v = json.loads((out / 'video.json').read_text(encoding='utf-8'))
    clean_run(v)
    assert v['frames'] == 30 and v['unique_poses'] == 15 and v['D'] == pytest.approx(1.5)
    assert [s['index'] for s in v['schedule'] if 'Attack' in s['hits']] == [9, 24]
    assert [s['index'] for s in v['schedule'] if 'SpecificSoundSet' in s['hits']] == [6, 21]
    mp4 = Path(v['mp4']['out'])
    assert mp4.is_file() and VD.is_faststart(mp4) and v['mp4']['returncode'] == 0
    pr = v['mp4'].get('probe') or VD.probe(mp4, ff)
    if pr:
        assert pr['codec_name'] == 'h264' and pr['pix_fmt'] == 'yuv420p' and int(pr['nb_read_frames']) == 30
        assert int(pr['width']) % 2 == 0 and int(pr['height']) > 200
    w = Image.open(v['webp']['out'])
    assert w.n_frames == 30
    f9 = Image.open(out / 'frames' / 'v_00009.png')
    assert f9.width == 200 and f9.height > 200, 'the overlay strip below the render'
    assert f9.getpixel((1, 100)) != Image.open(out / 'frames' / 'v_00003.png').getpixel((1, 100)), 'the flash border'
    assert v['fidelity']['stages']['video_encode'] == 'A'


def test_compare_walk_iron_flail_vs_oprichnik(env):
    out = env['root'] / 'compare'
    assert av('compare', '--bundle', env['bid'], '--other', 'Oprichnik', '--anim', 'Walk', '--size', 200,
              '--out', out) == 0
    rep = json.loads((out / 'compare.json').read_text(encoding='utf-8'))
    clean_run(rep)
    assert rep['b']['subject']['proto'] == 'Oprichnik' and rep['at'] == 'tags'
    rows = rep['rows']
    assert len(rows) >= 4 and all(r['a'] and r['b'] for r in rows)
    sa, sb = rep['summary']['a'], rep['summary']['b']
    assert 0.15 < sa['max_penetration'] < 0.45 and 'Calf' in (sa['worst_bone'] or '')
    assert sb['max_penetration'] < 0.1
    fl = [f for f in sa['footsteps'] if f['legs'] == ['FL']]
    assert fl and abs(fl[0]['height']) < 0.03, 'the front-left hoof is on the ground at its FootstepLeft tag'
    assert all(len(f['legs']) == 2 for f in sb['footsteps']), 'Oprichnik footsteps name no hoof: the side legs'
    assert (out / 'compare.png').is_file() and rep['fidelity']['stages']['compare_clock'] == 'H'


def test_side_by_side_video(env):
    ffmpeg_or_skip()
    out = env['root'] / 'sbs'
    assert av('video', '--bundle', env['bid'], '--anim', 'Walk', '--fps', 6, '--loops', 1, '--side-by-side', 'Oprichnik',
              '--timeline-overlay', '--size', 160, '--out', out) == 0
    v = json.loads((out / 'video.json').read_text(encoding='utf-8'))
    assert v['other']['subject']['proto'] == 'Oprichnik' and v['mp4']['returncode'] == 0
    f0 = Image.open(out / 'frames' / 'v_00000.png')
    assert f0.width >= 2 * 160
    assert all(s['t_b'] is not None for s in v['schedule'])
