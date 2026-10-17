"""Specimen proof for the aoe3de-player-colour scripts, on small synthetic specimens built in pytest's tmp_path (never
images in the repo): the game formula, the keep/lighten rule calibrated on the Korean TC measurements, the lighten modes
touching only masked texels, hue segmentation separating cells from lattice lines under soot where a luma split fails,
the face source refusing collateral texel sharing, and the state check.

python -m pytest .claude/skills/aoe3de-player-colour/scripts/test_player_colour.py -q      (numpy + Pillow, no Blender)
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import pc_common as C  # noqa: E402
import details_mask as DM  # noqa: E402
import lighten_under_mask as LU  # noqa: E402
import check_state as CS  # noqa: E402

CREAM = (220, 210, 190)     # Korean TC cream walls, measured mean (220.1, 210.2, 189.7)
GOLD = (166, 122, 60)       # Korean TC gold gable cells, measured mean (165.8, 122.5, 60.1)
LINE = (200, 175, 95)       # lighter gold lattice line (Lab hue ~92 vs the cells' ~75)
FRAME = (170, 40, 30)       # red frame (hue ~37: outside the gold window)


# ------------------------------------------------------------------------------------------------ formula + rule
def test_game_formula():
    bc = np.array([[[255, 255, 255], [200, 100, 50]]], np.uint8)
    out0 = C.ingame_albedo(bc, np.zeros((1, 2)), 1)
    assert (out0 == bc).all(), 'R = 0 leaves the BaseColor'
    out1 = C.ingame_albedo(bc, np.ones((1, 2)), 1)
    assert tuple(out1[0, 0]) == C.PLAYER_COLORS[1], 'white x player colour = the player colour'
    assert out1[0, 1].sum() < bc[0, 1].sum(), 'a multiply never brightens'


def test_rule_calibration_on_korean_tc_cases():
    def verdict(rgb, n=64, seed=0):
        rng = np.random.default_rng(seed)
        a = np.clip(np.array(rgb) + rng.normal(0, 4, (n, n, 3)), 0, 255).astype(np.uint8)
        return C.classify(C.base_stats(a, np.ones((n, n), bool)))[0]
    assert verdict(CREAM) == 'keep'                   # owner: cream walls keep their BaseColor
    assert verdict(GOLD) == 'lighten'                 # owner: gable gold cells get a lighter base
    assert verdict((223, 206, 181)) == 'keep'         # the 'partial' result on the gables (measured mean) passes
    assert verdict((245, 245, 242)) == 'keep'         # sail / white wall
    assert verdict((158, 158, 152)) == 'lighten'      # castle_regicide grey: neutral but dark - the rule flags it
    assert verdict((230, 200, 120)) == 'lighten'      # light but saturated


# ----------------------------------------------------------------------------------------------- lighten modes
def _lighten_specimen(tmp):
    rng = np.random.default_rng(1)
    n = 48
    bc = np.zeros((n, n, 3), np.float64)
    bc[:, :24] = CREAM; bc[:, 24:] = GOLD
    grain = rng.normal(0, 9, (n, n, 1))
    bc = np.clip(bc + grain, 0, 255).astype(np.uint8)
    r = np.zeros((n, n))
    r[8:40, 28:44] = 1.0
    r[8:40, 27] = 0.5                                 # soft edge column
    C.write_rgb8(tmp / 'bc.png', bc)
    C.write_details(tmp / 'det.png', r)
    return bc, r


@pytest.mark.parametrize('mode', ['keep', 'partial', 'neutral'])
def test_lighten_only_masked_texels(tmp_path, mode):
    bc, r = _lighten_specimen(tmp_path)
    rep = LU.run(tmp_path / 'bc.png', tmp_path / 'det.png', mode, tmp_path / 'out.png')
    assert rep['verdict'] == 'lighten'
    out = C.read_rgb8(tmp_path / 'out.png')
    ch = (out != bc).any(-1)
    assert not (ch & (r == 0)).any(), 'a texel outside the mask changed'
    full = r >= 1
    if mode == 'keep':
        assert C.sha_file(tmp_path / 'out.png') == C.sha_file(tmp_path / 'bc.png')
        assert rep['warning'], 'keeping gold under the mask must warn'
        return
    s = C.base_stats(out, full)
    assert abs(s['luma_mean'] - LU.TARGET_SRGB) < 8, s
    if mode == 'neutral':
        assert s['chroma_mean'] < 1.0, s
    else:
        assert 3.0 < s['chroma_mean'] < 0.6 * C.base_stats(bc, full)['chroma_mean'], s
    assert rep['result']['verdict_after'] == 'keep'
    lb, la = bc[full].astype(float) @ C.LUMA709, out[full].astype(float) @ C.LUMA709
    assert np.corrcoef(lb, la)[0, 1] > 0.9, 'grain / soot kept as relative brightness'
    soft = r == 0.5
    d_soft = np.abs(out[soft].astype(float) - bc[soft]).mean(); d_full = np.abs(out[full].astype(float) - bc[full]).mean()
    assert 0 < d_soft < d_full, 'the soft edge moves by its mask fraction'


def test_lighten_region_and_report_mode(tmp_path):
    bc, r = _lighten_specimen(tmp_path)
    r2 = r.copy(); r2[8:40, 4:20] = 1.0              # the mask also covers cream
    C.write_details(tmp_path / 'det2.png', r2)
    reg = np.zeros(bc.shape, np.uint8); reg[:, :24] = 255
    C.write_rgb8(tmp_path / 'cream_region.png', reg)
    rep = LU.run(tmp_path / 'bc.png', tmp_path / 'det2.png', 'report', region=tmp_path / 'cream_region.png')
    assert rep['verdict'] == 'keep' and 'result' not in rep
    reg[:] = 0; reg[:, 24:] = 255
    C.write_rgb8(tmp_path / 'gold_region.png', reg)
    rep = LU.run(tmp_path / 'bc.png', tmp_path / 'det2.png', 'partial', tmp_path / 'o.png', region=tmp_path / 'gold_region.png')
    out = C.read_rgb8(tmp_path / 'o.png')
    assert (out[:, :24] == bc[:, :24]).all(), 'the cream outside the region is untouched'
    assert rep['verdict'] == 'lighten'
    cli = subprocess.run([sys.executable, str(HERE / 'lighten_under_mask.py'), '--basecolor', str(tmp_path / 'bc.png'),
                          '--details', str(tmp_path / 'det.png')], capture_output=True, text=True)
    assert cli.returncode == 0 and 'VERDICT LIGHTEN' in cli.stdout, cli.stdout + cli.stderr


# --------------------------------------------------------------------------------------------- hue segmentation
def _lattice(n=64, pitch=10, width=2, soot=(1.0, 0.5)):
    img = np.zeros((n, n, 3)); truth = np.zeros((n, n), bool); frame = np.zeros((n, n), bool)
    yy, xx = np.mgrid[0:n, 0:n]
    line = ((yy % pitch) < width) | ((xx % pitch) < width)
    frame[:3] = frame[-3:] = True; frame[:, :3] = frame[:, -3:] = True
    img[:] = GOLD; img[line] = LINE; img[frame] = FRAME
    truth = ~line & ~frame
    f = soot[0] + (soot[1] - soot[0]) * xx / (n - 1)       # soot / fade darkens lines and cells alike
    return np.clip(img * f[..., None], 0, 255).astype(np.uint8), truth, line & ~frame, frame


def test_hue_segmentation_separates_cells_from_lines():
    bc, cells, lines, frame = _lattice()
    lin = C.s2l(bc)
    m, got, rep = DM.field_cells(lin, np.ones(cells.shape, bool), min_chroma=18.0, pick='low', min_cell=8)
    inner = cells & ~(C.shift(~cells, 1, 0, True) | C.shift(~cells, -1, 0, True) | C.shift(~cells, 0, 1, True)
                      | C.shift(~cells, 0, -1, True))
    assert (m[inner] == 1).all(), 'every interior cell texel is full player colour'
    assert (m[lines] <= 0.5).all(), 'lattice lines get at most the soft edge'
    assert (m[frame] == 0).all(), 'the red frame is outside the hue window'
    acc_hue = ((m >= 0.5) == cells)[~frame].mean()
    # the same split on LUMA fails under the soot gradient: that is why the rule splits on hue
    luma = bc.astype(float) @ C.LUMA709
    field = ~frame
    thr = C.otsu(luma[field])
    acc_luma = ((luma < thr) == cells)[field].mean()
    assert acc_hue > 0.98 and acc_luma < acc_hue - 0.1, (acc_hue, acc_luma)
    assert list(rep.values())[0]['cells'] >= 25


# -------------------------------------------------------------------------------------------------- face source
def _faces(seen_b=50):
    sq = lambda u0, v0, u1, v1: [[u0, v0], [u1, v0], [u1, v1], [u0, v1]]  # noqa: E731
    return {'A': dict(uv=sq(0.1, 0.1, 0.415, 0.4), seen_px=100),
            'B': dict(uv=sq(0.1, 0.1, 0.415, 0.4), seen_px=seen_b),       # stacked on A's texels
            'C': dict(uv=sq(0.415, 0.1, 0.7, 0.4), seen_px=100),         # adjacent chart: x = 13.28 splits texel 13
            'D': dict(uv=sq(0.75, 0.6, 0.95, 0.9), seen_px=100)}


def test_faces_refuse_collateral_sharing():
    with pytest.raises(DM.Refused):
        DM.face_mask(_faces(seen_b=50), ['A'], 32)
    m, rep = DM.face_mask(_faces(seen_b=0), ['A'], 32)                   # never-seen member: painted, listed
    assert [x['face'] for x in rep['painted_via_group_never_seen']] == ['B']


def test_faces_mask_soft_edge_and_gutter(tmp_path):
    faces = _faces()
    m, rep = DM.face_mask(faces, ['A', 'B'], 32, dilate_steps=2)
    tex = {k: DM.raster(DM.uv_px(f['uv'], 32), 32) for k, f in faces.items()}
    assert (m[tex['A']] > 0.5).all() and m[tex['A']].min() > 0.5
    assert (m[tex['C']] < 0.5).all() and (m[tex['D']] == 0).all()
    assert rep['soft_edge_texels'] > 0 and rep['gutter_texels'] > 0
    (tmp_path / 'faces.json').write_text(json.dumps(dict(size=32, faces=faces)))
    rc = subprocess.run([sys.executable, str(HERE / 'details_mask.py'), '--out', str(tmp_path / 'd.png'), '--faces',
                         str(tmp_path / 'faces.json'), '--select', 'A'], capture_output=True, text=True)
    assert rc.returncode == 2 and 'REFUSED' in rc.stdout and not (tmp_path / 'd.png').exists()


# -------------------------------------------------------------------------------------------------- state check
def _state(tmp):
    rng = np.random.default_rng(2)
    base = tmp / 'base'; cand = tmp / 'cand'; base.mkdir(); cand.mkdir()
    C.write_rgb8(base / 'P_BaseColor.png', rng.integers(0, 255, (32, 32, 3)).astype(np.uint8))
    C.write_rgb8(base / 'P_Normal.png', rng.integers(0, 255, (32, 32, 3)).astype(np.uint8))
    for f in base.iterdir():
        shutil.copy2(f, cand / f.name)
    faces = _faces()
    (tmp / 'faces.json').write_text(json.dumps(dict(size=32, faces=faces)))
    m, _ = DM.face_mask(faces, ['A', 'B'], 32)
    C.write_details(cand / 'P_Details.png', m)
    bc = C.read_rgb8(base / 'P_BaseColor.png'); bc[m > 0] = 200
    C.write_rgb8(cand / 'P_BaseColor.png', bc)
    return base, cand, m


def test_check_state_pass_and_fails(tmp_path):
    base, cand, m = _state(tmp_path)
    fj = str(tmp_path / 'faces.json')
    assert CS.check(base, cand, faces=fj, select=['A', 'B'])['verdict'] == 'PASS'
    n = C.read_rgb8(cand / 'P_Normal.png'); n[0, 0] = 255 - n[0, 0]; C.write_rgb8(cand / 'P_Normal.png', n)
    rep = CS.check(base, cand)
    assert rep['verdict'] == 'FAIL' and any('P_Normal' in f for f in rep['fails'])
    shutil.copy2(base / 'P_Normal.png', cand / 'P_Normal.png')
    bc = C.read_rgb8(cand / 'P_BaseColor.png'); out = np.argwhere(m == 0)[0]; bc[tuple(out)] = 1
    C.write_rgb8(cand / 'P_BaseColor.png', bc)
    rep = CS.check(base, cand)
    assert rep['verdict'] == 'FAIL' and any('outside the Details mask' in f for f in rep['fails'])


def test_check_state_leak(tmp_path):
    base, cand, m = _state(tmp_path)
    faces = _faces()
    rr, cc = DM.raster(DM.uv_px(faces['D']['uv'], 32), 32)
    m2 = m.copy(); m2[rr, cc] = 1.0                                       # D is not selected but gets player colour
    C.write_details(cand / 'P_Details.png', m2)
    rep = CS.check(base, cand, faces=str(tmp_path / 'faces.json'), select=['A', 'B'])
    assert rep['verdict'] == 'FAIL' and [x['face'] for x in rep['leak_check']['leaking']] == ['D']
    assert [x['face'] for x in rep['leak_check']['soft_edge']] == ['C']
