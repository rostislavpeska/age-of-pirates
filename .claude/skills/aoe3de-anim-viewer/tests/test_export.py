"""aoe3de-anim-viewer M5 exports, CI-safe: metrics.py, sheets.py, video.py, the anim_viewer.py render / video / compare
plumbing, the server's job route and geometry uploads, headless.run_job's long-job hand-over.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_export.py -q

No game, no browser, no ffmpeg: synthetic meshes, images and box streams built in the test (pytest's temp folder).
- penetration by the generalised winding number on a closed box and an open soup; nearest-triangle depth; hoof
  heights of a synthetic quadruped whose skeleton names give the forward and left sides; footprintbone parsing;
- the AVGEOM1 reader against the Python writer and against geometry.js packGeometry run under Node (when present);
- the video schedule (t = i / fps mod D), distinct poses, tag hits across the loop end, the flash plan, the overlay
  (strip size, flash border), WebP round trip, the ffmpeg command, MP4 box order (faststart), a missing ffmpeg;
- sheets: grid, captions, sidecars; every writer refuses a repository;
- the CLI: cameras (ortho3), --at, the render job (at expansion, geometry on the first camera only, clip framing),
  lgt routing to presets, a clear exit 2 when ffmpeg is not configured.
"""
import http.client
import io
import json
import os
import shutil
import struct
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import av_common as C  # noqa: E402
import metrics as MX  # noqa: E402
import sheets as S  # noqa: E402
import video as VD  # noqa: E402
import anim_viewer as AV  # noqa: E402

NODE = shutil.which('node')
REPO_DIR = HERE                                     # inside the AoP work tree: every writer must refuse it

CUBE_V = np.array([[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0], [0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]], float)
CUBE_T = np.array([[0, 2, 1], [0, 3, 2], [4, 5, 6], [4, 6, 7], [0, 1, 5], [0, 5, 4], [2, 3, 7], [2, 7, 6], [1, 2, 6],
                   [1, 6, 5], [0, 4, 7], [0, 7, 3]])


@pytest.fixture(autouse=True)
def cache(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))


# ---------------------------------------------------------------------------------------------------- metrics
def box(lo, hi):
    lo, hi = np.asarray(lo, float), np.asarray(hi, float)
    return lo + CUBE_V * (hi - lo), CUBE_T.copy()


def geom(instances):
    """a dump through the Python writer: instances [(role, bones, [(name, posed, bind, tris, bone)])]"""
    header = {'version': 1, 't': 0.5, 'meta': {'subject': 'a'}, 'instances': []}
    arrays = []
    for role, bones, meshes in instances:
        inst = {'role': role, 'model': role + '.gr2', 'bones': bones, 'meshes': []}
        for name, posed, bind, tris, bone in meshes:
            m = {'name': name, 'vertex_count': len(posed), 'triangle_count': len(tris)}
            inst['meshes'].append(m)
            arrays += [(m, 'posed', np.asarray(posed, np.float32)), (m, 'bind', np.asarray(bind, np.float32)),
                       (m, 'indices', np.asarray(tris, np.uint32)), (m, 'bone', np.asarray(bone, np.int16))]
        header['instances'].append(inst)
    return MX.read_geom(MX.write_geom(header, arrays))


def test_winding_numbers_and_nearest_distances_on_a_box():
    tv = CUBE_V[CUBE_T]
    p = np.array([[0.5, 0.5, 0.5], [0.1, 0.5, 0.5], [1.5, 0.5, 0.5], [0.5, 0.5, -0.2], [0.95, 0.9, 0.5]])
    w = MX.winding_numbers(p, tv)
    assert np.allclose(np.abs(w), [1, 1, 0, 0, 1], atol=1e-9)
    assert np.allclose(np.abs(MX.winding_numbers(p, tv[:, ::-1])), np.abs(w)), 'any consistent winding'
    d, _i = MX.nearest_distances(p, tv)
    assert np.allclose(d, [0.5, 0.1, 0.5, 0.2, 0.05], atol=1e-12)
    open_soup = tv[2:]                                                   # the bottom face removed
    assert 0.5 < abs(MX.winding_numbers(p[:1], open_soup)[0]) < 1.0, 'an open box still counts as inside the centre'


def test_closest_point_on_a_triangle_matches_dense_sampling():
    rng = np.random.default_rng(3)
    a, b, c = rng.normal(size=(3, 3))
    p = rng.normal(size=(300, 3)) * 2
    q = MX.closest_on_triangles(p[:, None, :], a[None, None], b[None, None], c[None, None])[:, 0]
    u, v = np.meshgrid(np.linspace(0, 1, 301), np.linspace(0, 1, 301))
    m = u + v <= 1
    pts = a + np.outer(u[m], b - a) + np.outer(v[m], c - a)
    dense = np.sqrt(((p[:, None, :] - pts[None]) ** 2).sum(-1)).min(1)
    exact = np.linalg.norm(q - p, axis=1)
    assert np.all(exact <= dense + 1e-12) and np.max(dense - exact) < 2e-3


def test_penetration_rider_inside_the_body_with_depth_and_bone():
    hv, ht = box([-0.5, 1.0, -1.0], [0.5, 2.0, 1.0])                  # the horse body
    rider = np.array([[0.0, 1.8, 0.0], [0.0, 2.5, 0.0], [0.45, 1.5, 0.0], [3.0, 1.5, 0.0]])
    g = geom([('main', ['body'], [('horse', hv, hv, ht, [0] * 8)]),
              ('child', ['Bip01_Pelvis', 'Bip01_L_Calf'], [('rider', rider, rider, [[0, 1, 2]], [0, 0, 1, 1])])])
    p = MX.penetration(g)
    assert p['status'] == 'ok' and p['n_points'] == 4 and p['n_inside'] == 2
    assert p['max_depth'] == pytest.approx(0.2) and p['deepest']['bone'] == 'Bip01_Pelvis'
    assert p['mean_depth'] == pytest.approx((0.2 + 0.05) / 2)
    assert [x['bone'] for x in p['by_bone']] == ['Bip01_Pelvis', 'Bip01_L_Calf']
    assert p['by_mesh'][0]['mesh'] == 'rider' and p['by_mesh'][0]['n_inside'] == 2
    assert MX.penetration(geom([('main', ['b'], [('horse', hv, hv, ht, [0] * 8)])]))['status'] == 'n/a'


def quadruped():
    """a body box over four leg boxes; bones: head at +z, *_l legs on -x (the Iron Flail horse's sides)"""
    parts, bones = [], ['spine', 'head_x', 'hand_l', 'hand_r', 'toes_01_l', 'toes_01_r']
    parts.append((box([-0.4, 1.0, -1.0], [0.4, 1.8, 1.0]), 0))
    parts.append((box([-0.2, 1.6, 1.0], [0.2, 2.4, 1.5]), 1))
    for (x, z), b in (((-0.3, 0.8), 2), ((0.3, 0.8), 3), ((-0.3, -0.8), 4), ((0.3, -0.8), 5)):
        parts.append((box([x - 0.08, 0.0, z - 0.08], [x + 0.08, 1.0, z + 0.08]), b))
    V = np.vstack([p[0][0] for p in parts])
    T = np.vstack([p[0][1] + 8 * i for i, p in enumerate(parts)])
    B = np.concatenate([[p[1]] * 8 for p in parts])
    return V, T, B, bones


def test_hoof_heights_by_leg_from_the_skeleton_sides():
    V, T, B, bones = quadruped()
    posed = V.copy()
    lifted = np.where(B == 3)[0]                                       # hand_r: front right leg lifted 0.25
    posed[lifted, 1] += 0.25
    g = geom([('main', bones, [('horse', posed, V, T, B)])])
    ax = MX.body_axes(g)
    assert ax['forward'] == 1.0 and ax['left'] == -1.0 and ax['source']['forward'].startswith('skeleton')
    h = MX.hoof_heights(g)
    assert h['status'] == 'ok'
    assert h['legs']['FR']['height'] == pytest.approx(0.25) and h['legs']['FL']['height'] == pytest.approx(0.0)
    assert h['legs']['BL']['position'][0] < 0 and h['legs']['BL']['position'][2] < 0
    tags = [{'type': 'FootstepRight', 'role': 'main', 'footstep': True, 'footprintbone': 'HS BONE HOOF FRNT RT',
             'time': 0.5, 'fraction': 0.5},
            {'type': 'FootstepLeft', 'role': 'main', 'footstep': True, 'footprintbone': None, 'time': 0.2},
            {'type': 'FootstepLeft', 'role': 'child', 'footstep': True, 'time': 0.2},
            {'type': 'Attack', 'role': 'main', 'footstep': False}]
    rep = MX.footstep_report(g, tags)
    assert [r['legs'] for r in rep] == [['FR'], ['FL', 'BL']], 'rider footsteps and other tags are left out'
    assert rep[0]['height'] == pytest.approx(0.25) and rep[1]['height'] == pytest.approx(0.0)
    mirrored = geom([('main', ['spine', 'head', 'leg_r', 'leg_r', 'leg_l', 'leg_l'],
                      [('horse', V * [-1, 1, -1], V * [-1, 1, -1], T, B)])])
    assert MX.body_axes(mirrored)['forward'] == -1.0, 'the head bone side decides, not a fixed axis'


@pytest.mark.parametrize('bone,typ,legs', [
    ('HS BONE HOOF FRNT LT', None, ['FL']), ('HS Bone Hoof Back Rt', None, ['BR']), ('hoof_front_left', None, ['FL']),
    ('HS BONE HOOF BACK', 'FootstepLeft', ['BL']), (None, 'FootstepRight', ['FR', 'BR']), ('', None, ['FL', 'FR', 'BL', 'BR'])])
def test_leg_of_footprint(bone, typ, legs):
    assert MX.leg_of_footprint(bone, typ) == legs


def test_geometry_reader_refuses_other_files():
    with pytest.raises(ValueError):
        MX.read_geom(b'PNG\x00' * 8)


@pytest.mark.skipif(not NODE, reason='node not on PATH')
def test_geometry_js_pack_reads_in_python(tmp_path):
    """geometry.js packGeometry under Node -> metrics.read_geom: the same arrays."""
    js = HERE.parent / 'viewer' / 'export' / 'geometry.js'
    out = tmp_path / 'g.geom.bin'
    script = tmp_path / 'pack.mjs'
    script.write_text(
        "import { packGeometry } from %s;\nimport { writeFileSync } from 'node:fs';\n"
        "const posed = new Float32Array([0, 1, 2, 3, 4, 5]); const bind = new Float32Array([1, 1, 1, 2, 2, 2]);\n"
        "const idx = new Uint32Array([0, 1, 1]); const bone = new Int16Array([-1, 7]);\n"
        "const r = (o, dt, n, c) => ({ offset: o, dtype: dt, count: n, components: c });\n"
        "const header = { version: 1, t: 0.75, meta: { x: 'y' }, instances: [{ role: 'main', model: 'm.gr2', bones: ['a'],\n"
        "  meshes: [{ name: 'k', vertex_count: 2, triangle_count: 1, arrays: { posed: r(0, 'f32', 2, 3),\n"
        "  bind: r(24, 'f32', 2, 3), indices: r(48, 'u32', 1, 3), bone: r(60, 'i16', 2, 1) } }] }] };\n"
        "writeFileSync(%s, packGeometry(header, [posed, bind, idx, bone]));\n"
        % (json.dumps(js.as_uri()), json.dumps(str(out))), encoding='utf-8')
    r = subprocess.run([NODE, str(script)], capture_output=True, text=True, timeout=60)
    assert r.returncode == 0, r.stderr
    g = MX.read_geom(out)
    m = g['instances'][0]['meshes'][0]
    assert g['t'] == 0.75 and g['meta'] == {'x': 'y'}
    assert m['posed'].tolist() == [[0, 1, 2], [3, 4, 5]] and m['bind'].tolist() == [[1, 1, 1], [2, 2, 2]]
    assert m['indices'].tolist() == [[0, 1, 1]] and m['bone'].tolist() == [-1, 7]


# ---------------------------------------------------------------------------------------------------- video
def test_schedule_exact_times_loops_and_distinct_poses():
    s = VD.schedule(1.5, 30, 3)
    assert len(s) == 135 and s[0]['t'] == 0.0 and s[45]['t'] == 0.0 and s[45]['loop'] == 1
    assert s[25]['t'] == pytest.approx(25 / 30) and s[134]['t'] == pytest.approx(134 / 30 - 3.0)
    times, of = VD.unique_times(s)
    assert len(times) == 45 and of[45] == 0 and of[70] == 25
    s2 = VD.schedule(1.0, 24, 1)
    assert len(s2) == 24 and s2[-1]['t'] == pytest.approx(23 / 24)
    assert len(VD.schedule(0, 10, 2)) == 20 and VD.schedule(0, 10, 1)[5]['t'] == 0.0
    assert VD.loop_time(2.5, 1.0) == (pytest.approx(0.5), 2) and VD.loop_time(3.0, 1.5) == (0.0, 2)
    pairs, of2 = VD.unique_times([{'t': 0.1, 't_b': 0.2}, {'t': 0.1, 't_b': 0.3}, {'t': 0.1, 't_b': 0.2}], ('t', 't_b'))
    assert len(pairs) == 2 and of2 == [0, 1, 0]
    with pytest.raises(ValueError):
        VD.schedule(1, 0)


def test_tag_hits_cover_each_frame_interval_and_wrap_at_the_loop_end():
    tl = {'D': 1.5, 'tags': [{'type': 'Attack', 'lane': 'Attack', 'role': 'main', 'reached': [0.81], 'fraction': 0.54},
                             {'type': 'FootstepLeft', 'lane': 'FootstepLeft', 'role': 'main', 'reached': [1.5]},
                             {'type': 'Particles', 'lane': 'Particles', 'role': 'attachment', 'reached': [0.0, 0.4]},
                             {'type': 'SpecificSoundSet', 'lane': 'overflow', 'role': 'main', 'reached': []}]}
    ev = VD.tag_events(tl)
    assert [(e['type'], e['time']) for e in ev] == [('Particles', 0.0), ('Particles', 0.4), ('Attack', 0.81),
                                                    ('FootstepLeft', 1.5)]
    assert [e['type'] for e in VD.hits(ev, 0.8, 0.8333, 1.5)] == ['Attack']
    assert VD.hits(ev, 0.81, 0.84, 1.5) == [], 'a tag counts once: (t_prev, t]'
    assert [e['type'] for e in VD.hits(ev, 1.4667, 0.0, 1.5)] == ['Particles', 'FootstepLeft'], 'across the loop end'
    assert [e['type'] for e in VD.hits(ev, 0, 0.0, 1.5, first=True)] == ['Particles']
    s = VD.schedule(1.5, 30, 2)
    plan = VD.flash_plan(s, ev, 1.5, 30)
    assert [[e['type'] for e in p['hits']] for p in plan if p['hits']] == [
        ['Particles'], ['Particles'], ['Attack'], ['Particles', 'FootstepLeft'], ['Particles'], ['Attack']], \
        'the loop frame (45, t 0) covers both the 1.5 s footstep and the next loop\'s 0.0 s particles'
    assert [s[j]['index'] for j, p in enumerate(plan) if p['hits']] == [0, 12, 25, 45, 57, 70]
    i = next(j for j, p in enumerate(plan) if any(e['type'] == 'Attack' for e in p['hits']))
    assert s[i]['t'] == pytest.approx(25 / 30)
    assert [plan[i + k]['flash'] for k in range(4)] == [1.0, pytest.approx(2 / 3, abs=1e-4),
                                                        pytest.approx(1 / 3, abs=1e-4), 0.0]


def test_overlay_strip_and_flash_border():
    img = Image.new('RGB', (320, 320), (60, 60, 60))
    ev = [{'time': 0.81, 'type': 'Attack', 'lane': 'Attack', 'role': 'main'}]
    info = {'title': 'unit Attack_melee v0 clip.gr2', 't': 0.8333, 'D': 1.5, 'key': 160, 'keys_of': 289,
            'fps_rounded': 192, 'loop': 0, 'loops': 3, 'frame': 25, 'frames': 135, 'sides': ['child x key 1/2'],
            'events': ev, 'hits': ev, 'flash': 1.0, 'flash_events': ev,
            'fidelity': {'stages': {'a': 'M', 'b': 'U', 'c': 'H'}, 'calibration': 'none'}}
    out = VD.overlay(img, info)
    assert out.width == 320 and out.height > 320 + 90
    assert out.getpixel((1, 160)) == S.LANE_COLOURS['Attack'], 'the flash border in the Attack colour'
    calm = VD.overlay(img, dict(info, flash=0.0, flash_events=[]))
    assert calm.getpixel((1, 160)) == (60, 60, 60)
    sbs = VD.side_by_side([out, calm])
    assert sbs.size == (644, out.height)
    assert VD.even(Image.new('RGB', (5, 7))).size == (6, 8)


def test_webp_round_trip(tmp_path):
    frames = [Image.new('RGB', (32, 24), (i * 20, 0, 0)) for i in range(6)]
    rec = VD.encode_webp(frames, tmp_path / 'a.webp', 30)
    assert rec['frames'] == 6 and rec['duration_ms'] == 33
    im = Image.open(tmp_path / 'a.webp')
    assert im.n_frames == 6 and im.info.get('loop') == 0
    with pytest.raises(C.RepoPathError):
        VD.encode_webp(frames, REPO_DIR / 'x.webp', 30)


def test_ffmpeg_comes_only_from_the_config(tmp_path, monkeypatch):
    cfg = tmp_path / 'tool-paths.local.json'
    cfg.write_text(json.dumps({'tools': {'ffmpeg': {'path': ''}}}))
    with pytest.raises(VD.FfmpegMissing, match='tools.ffmpeg.path'):
        VD.ffmpeg_path(config=cfg)
    cfg.write_text(json.dumps({'tools': {'ffmpeg': {'path': str(tmp_path / 'nope.exe')}}}))
    with pytest.raises(VD.FfmpegMissing, match='not found'):
        VD.ffmpeg_path(config=cfg)
    exe = tmp_path / 'ffmpeg.exe'
    exe.write_bytes(b'')
    cfg.write_text(json.dumps({'tools': {'ffmpeg': {'path': str(exe)}}}))
    assert VD.ffmpeg_path(config=cfg) == str(exe)
    assert VD.ffmpeg_path(str(exe), config=tmp_path / 'absent.json') == str(exe)
    monkeypatch.setattr(C, 'local_tool_path', lambda *a, **k: None)
    with pytest.raises(VD.FfmpegMissing):
        VD.ffmpeg_path()


def test_mp4_command_and_box_order(tmp_path):
    cmd = VD.mp4_command('ffmpeg', tmp_path, 'v_%05d.png', 30, tmp_path / 'o.mp4')
    s = ' '.join(cmd)
    for part in ('-c:v libx264', '-pix_fmt yuv420p', '-movflags +faststart', '-framerate 30', '-start_number 0',
                 'out_color_matrix=bt709', '-an'):
        assert part in s, part

    def bx(t, payload=b''):
        return struct.pack('>I4s', 8 + len(payload), t) + payload
    fast = tmp_path / 'fast.mp4'
    fast.write_bytes(bx(b'ftyp', b'isom') + bx(b'moov', b'x' * 10) + bx(b'mdat', b'y' * 40))
    slow = tmp_path / 'slow.mp4'
    slow.write_bytes(bx(b'ftyp', b'isom') + bx(b'mdat', b'y' * 40) + bx(b'moov', b'x' * 10))
    assert [b[0] for b in VD.mp4_boxes(fast)] == ['ftyp', 'moov', 'mdat'] and VD.is_faststart(fast)
    assert not VD.is_faststart(slow)
    with pytest.raises(C.RepoPathError):
        VD.encode_mp4(tmp_path, 'v_%05d.png', 30, REPO_DIR / 'x.mp4', 'ffmpeg')


# ---------------------------------------------------------------------------------------------------- sheets
def test_sheet_grid_captions_and_sidecars(tmp_path):
    cells = []
    for r in range(2):
        for k, cam in enumerate(('game', 'close')):
            p = tmp_path / ('f%d%d.png' % (r, k))
            Image.new('RGBA', (100, 80), (40 * r, 80 * k, 120, 255)).save(p)
            rec = {'anim': 'Walk', 'variant': 0, 'clip': 'c.gr2', 'key': r, 'time': r * 0.5, 'tag': 'Attack' if r else None}
            S.write_cell_sidecar(p, rec)
            cells.append({'png': p, 'row': 't%d' % r, 'col': cam, 'caption': ['v0 t %.1f' % (r * 0.5), 'x'], 'record': rec,
                          'highlight': (255, 0, 0) if r else None})
    fid = {'stages': {'pose': 'M', 'camera': 'U', 'timing': 'H', 'shadows': 'A', 'skinning': 'M'}, 'calibration': 'none',
           'shader_model': 'v1'}
    side = S.make_sheet(cells, tmp_path / 'sheet.png', title='T', subtitle='s', fidelity=fid, notes=['n1'])
    assert (tmp_path / 'sheet.png').is_file() and (tmp_path / 'sheet.json').is_file()
    assert side['rows'] == ['t0', 't1'] and side['columns'] == ['game', 'close']
    assert side['fidelity']['counts'] == {'M': 2, 'A': 1, 'U': 1, 'H': 1} and side['fidelity']['badge'] == 'MUHAM'
    assert [c['png'] for c in side['cells']] == ['f00.png', 'f01.png', 'f10.png', 'f11.png']
    assert side['cells'][3]['tag'] == 'Attack' and side['cells'][3]['box'][0] > side['cells'][2]['box'][0]
    assert json.loads((tmp_path / 'f10.cell.json').read_text())['time'] == 0.5
    im = Image.open(tmp_path / 'sheet.png')
    x0, y0, w, h = side['cells'][3]['box']
    assert im.getpixel((x0 - 1, y0 + h // 2)) == (255, 0, 0), 'highlighted cell'
    with pytest.raises(C.RepoPathError):
        S.make_sheet(cells, REPO_DIR / 'sheet.png')
    with pytest.raises(ValueError):
        S.make_sheet([], tmp_path / 'e.png')


# ---------------------------------------------------------------------------------------------------- CLI
def fake_manifest():
    clip = lambda d: {'duration': d, 'fps_declared': 30, 'key_count': int(d * 30) + 1}  # noqa: E731
    return {'bundle_id': '0123456789abcdef', 'subject': {'kind': 'proto', 'proto': 'zzUnit', 'animfile': 'u/u.xml'},
            'composition': {'main': 'u/u.xml'},
            'animfiles': {'u/u.xml': {'anims': {'Idle': {'variants': [{'clip': 'i.gr2', 'tags': []}]},
                                                'Attack_melee': {'variants': [{'clip': 'a.gr2', 'tags': []},
                                                                              {'clip': 'b.gr2', 'tags': []}]}}}},
            'clips': {'i.gr2': clip(2.0), 'a.gr2': clip(1.5), 'b.gr2': clip(1.25)},
            'fidelity': {'stages': {'pose': 'M'}, 'notes': {'pose': 'p'}, 'calibration': 'none'},
            'lighting': {'lgt': {'name': 'Tantalus Viewer'}, 'presets': [{'name': 'NewEngland_Skirmish', 'bundle_id': 'f' * 16}]}}


def test_cameras_at_and_anim_helpers():
    assert [c[0] for c in AV.cameras('game,ortho3')] == ['game', 'front', 'side', 'top']
    assert AV.cameras('close')[0][1] == {'mode': 'close'}
    assert AV.cameras('side')[0][1] == {'mode': 'ortho', 'az': 90, 'el': 0.05}
    with pytest.raises(ValueError):
        AV.cameras('fisheye')
    assert AV.parse_at('TAGS') == 'tags' and AV.parse_at('fps=12') == 'fps=12' and AV.parse_at('fps = 2.5') == 'fps=2.5'
    for bad in ('fps=0', 'frames', 'keys=3'):
        with pytest.raises(ValueError):
            AV.parse_at(bad)
    m = fake_manifest()
    assert AV.anim_name(m, 'attack_MELEE') == 'Attack_melee'
    with pytest.raises(LookupError, match='have Idle, Attack_melee'):
        AV.anim_name(m, 'Walk')
    assert AV.main_duration(m, 'Attack_melee', 1) == 1.25 and AV.main_duration(m, 'Attack_melee', 3) == 1.25


@pytest.mark.parametrize('variant', ['0', 'all', '7'])
def test_render_static_component_without_animation_clips(variant):
    """INC-270: static building components render once without modulo-zero or invented clips."""
    m = fake_manifest()
    m['animfiles']['u/u.xml']['anims'] = {'Idle': {'variants': []}}
    m['clips'] = {}
    a = AV.parser().parse_args(['render', '--bundle', m['bundle_id'], '--anim', 'Idle',
                                '--variant', variant, '--time', '0', '--cam', 'game,side'])
    job, at, cams = AV.render_job(m, a, None)
    assert at is None
    assert [(f['anim'], f['variant'], f['time'], f['_cam']) for f in job['frames']] == [
        ('Idle', 0, 0.0, 'game'), ('Idle', 0, 0.0, 'side')]
    assert m['animfiles']['u/u.xml']['anims']['Idle']['variants'] == []
    assert m['clips'] == {}, 'a static render must not fabricate a clip'


def test_render_job_expands_in_the_page_with_one_geometry_camera():
    m = fake_manifest()
    a = AV.parser().parse_args(['render', '--bundle', '0123456789abcdef', '--anim', 'Attack_melee', '--variant', 'all',
                                '--at', 'tags', '--cam', 'game,close', '--metrics', '--transparent', '--player', '3'])
    job, at, cams = AV.render_job(m, a, 'NewEngland_Skirmish')
    assert at == 'tags' and [c[0] for c in cams] == ['game', 'close']
    assert [(f['variant'], f['_cam'], f['at'], f.get('geometry', False)) for f in job['frames']] == [
        (0, 'game', 'tags', True), (0, 'close', 'tags', False), (1, 'game', 'tags', True), (1, 'close', 'tags', False)]
    assert job['bounds'] == 'clip' and job['timeline'] is True and job['background'] == [0, 0, 0, 0] and not job['grid']
    assert job['shading'] == {'lighting': 'NewEngland_Skirmish', 'player': 3}
    a2 = AV.parser().parse_args(['render', '--bundle', '0123456789abcdef', '--anim', 'all', '--key', '7', '--key-of',
                                 'child'])
    job2, at2, _c = AV.render_job(m, a2, None)
    assert at2 is None and job2['bounds'] == 'frame' and 'shading' not in job2
    assert [(f['anim'], f['key'], f['key_of']) for f in job2['frames']] == [('Idle', 7, 'child'), ('Attack_melee', 7, 'child')]
    a3 = AV.parser().parse_args(['render', '--bundle', '0123456789abcdef', '--anim', 'Idle', '--keys', 'tags'])
    assert AV.render_job(m, a3, None)[1] == 'tags', 'the M2 spelling --keys tags still works'


def test_lgt_routing_and_bundle_subjects(tmp_path):
    bid = '0123456789abcdef'
    folder = C.cache_root() / bid
    folder.mkdir(parents=True)
    C.write_json(folder / 'manifest.json', fake_manifest())
    assert AV.load_subject(bundle_id=bid, lgt='NewEngland_Skirmish')[2] == 'NewEngland_Skirmish'
    assert AV.load_subject(bundle_id=bid, lgt='Tantalus Viewer')[2] is None, "the bundle's own lgt"
    with pytest.raises(LookupError, match='neither'):
        AV.load_subject(bundle_id=bid, lgt='Yukon_Skirmish')
    with pytest.raises(ValueError):
        AV.load_subject(bundle_id='nothex')
    with pytest.raises(FileNotFoundError):
        AV.load_subject(bundle_id='f' * 16)
    import lighting as L
    assert AV._lgt_plan(None) == ('Tantalus Viewer', None)
    assert AV._lgt_plan(L.PRESETS[1]['name']) == ('Tantalus Viewer', L.PRESETS[1]['name'])
    assert AV._lgt_plan('Yukon_Skirmish') == ('Yukon_Skirmish', None)


def test_merged_fidelity_carries_the_timeline_and_export_stages():
    import bundle as B
    f = AV.merged_fidelity(fake_manifest(), {'fidelity': {'stages': {'pose': 'M', 'brdf': 'A'}, 'notes': {}}})
    assert f['stages']['brdf'] == 'A' and f['calibration'] == 'none'
    for k in list(B.TIMELINE_STAGES) + list(B.EXPORT_STAGES):
        assert k in f['stages'] and f['notes'][k]
    blk = B.fidelity_block()
    assert blk['stages']['export_frame_times'] == 'M' and blk['stages']['video_encode'] == 'A'
    assert blk['stages']['compare_clock'] == 'H' and blk['stages']['metric_penetration'] == 'A'
    assert blk['stages']['key_grid'] == 'M' and blk['stages']['tag_overflow'] == 'U'


def test_video_without_ffmpeg_is_a_clear_error_before_any_render(monkeypatch, capsys):
    monkeypatch.setattr(C, 'local_tool_path', lambda *a, **k: None)
    rc = AV.main(['video', '--bundle', '0123456789abcdef', '--anim', 'Walk'])
    assert rc == 2
    err = capsys.readouterr().err
    assert 'ffmpeg is not configured' in err and 'tools.ffmpeg.path' in err


def test_outputs_refuse_a_repository():
    with pytest.raises(C.RepoPathError):
        C.output_dir(REPO_DIR / 'out', 'render')


# ---------------------------------------------------------------------------------------------------- server, headless
def test_server_hands_the_job_over_and_takes_geometry(tmp_path):
    from server import ViewerServer
    job = {'frames': [{'name': 'p', 'times': list(np.linspace(0, 1, 500).round(6))}]}
    with ViewerServer(tmp_path / 'out', job=job) as s, ViewerServer(tmp_path / 'out2') as s2:
        def req(srv, method, path, body=None, token=True):
            c = http.client.HTTPConnection('127.0.0.1', srv.port, timeout=10)
            h = {'Host': '127.0.0.1:%d' % srv.port}
            if token:
                h['X-AV-Token'] = srv.token
            c.request(method, path, body=body, headers=h)
            r = c.getresponse()
            d = r.read()
            c.close()
            return r.status, d
        st, data = req(s, 'GET', '/api/job')
        assert st == 200 and json.loads(data) == json.loads(json.dumps(job))
        assert req(s, 'GET', '/api/job', token=False)[0] == 403
        assert req(s2, 'GET', '/api/job')[0] == 404
        st, _d = req(s, 'POST', '/api/file?name=f.geom.bin', body=b'AVGEOM1\x00' + b'\x00' * 8)
        assert st == 200 and (s.out_dir / 'f.geom.bin').read_bytes()[:7] == b'AVGEOM1'
        assert req(s, 'POST', '/api/file?name=f.exe', body=b'x')[0] == 400


def test_run_job_passes_a_long_job_over_the_server(tmp_path, monkeypatch):
    import headless as H
    root = tmp_path / 'bundles'
    for b in ('a' * 16, 'b' * 16):
        (root / b).mkdir(parents=True)
        (root / b / 'manifest.json').write_text('{}')
    seen = {}
    monkeypatch.setattr(H, 'run_page', lambda page, **kw: seen.update(kw) or {'status': 'done'})
    monkeypatch.setattr(H, 'select_browsers', lambda b=None: [{'name': 'chrome', 'path': 'x'}])
    small = {'frames': [{'name': 'a', 'time': 0.5}]}
    H.run_job('a' * 16, small, bundle_root=root)
    assert seen['query']['job'] == json.dumps(small, separators=(',', ':')) and seen['job'] is None
    big = {'frames': [{'name': 'p', 'times': [i / 30 for i in range(900)]}], 'other': {'bundle': 'b' * 16}}
    H.run_job('a' * 16, big, bundle_root=root)
    assert seen['query']['job'] == '@server' and seen['job'] == big
    with pytest.raises(FileNotFoundError, match='c' * 16):
        H.run_job('a' * 16, {'frames': [], 'other': {'bundle': 'c' * 16}}, bundle_root=root)


def test_children_of_a_browser_running_before_the_run_are_not_leftovers():
    """2026-10-11: the owner's own Chrome opened tab processes during a headless run; they were reported as this
    run's leftovers. A process whose parent ran before the run is someone else's (owner_children)."""
    import headless as H
    leftover, owner = H.classify_appeared([5, 6, 7], {1, 2}, {5: 1, 6: 99})
    assert leftover == [6, 7] and owner == [5], 'unknown parent (7) stays a possible leftover'
    assert H.classify_appeared([], {1}, {}) == ([], [])
    if os.name == 'nt':
        assert H.parent_pids([os.getpid()]) == {os.getpid(): os.getppid()}
    else:
        assert H.parent_pids([os.getpid()]) == {}
