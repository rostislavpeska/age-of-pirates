"""aoe3de-trigger-camera: Camera Cut vectors and the camera bench's generated triggers (no game, no network)."""
import math
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = next(p for p in HERE.parents if (p / 'scripts' / 'aitest' / 'camera_bench.py').exists())
sys.path.insert(0, str(REPO / 'scripts' / 'aitest'))
import camera_bench as CB  # noqa: E402

EDITOR_FORMAT = re.compile(r'^vector\(-?\d+\.\d{6},-?\d+\.\d{6},-?\d+\.\d{6}\)(, vector\(-?\d+\.\d{6},-?\d+\.\d{6},-?\d+\.\d{6}\)){3}$')


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def test_the_basis_is_orthonormal_with_a_horizontal_right_and_an_upward_up():
    for h in range(0, 360, 30):
        for pitch in (10, 28, 60, 85):
            p, d, u, r = CB.camera((100, 1, 100), h, pitch, 16)
            for v in (d, u, r):
                assert abs(dot(v, v) - 1) < 1e-9
            assert abs(dot(d, u)) < 1e-9 and abs(dot(d, r)) < 1e-9 and abs(dot(u, r)) < 1e-9
            assert r[1] == 0 and u[1] > 0
            assert abs(math.dist(p, (100, 1, 100)) - 16) < 1e-9


def test_heading_0_looks_along_plus_z_and_90_along_plus_x():
    _, d0, _, r0 = CB.camera((0, 0, 0), 0, 0, 1)
    _, d90, _, _ = CB.camera((0, 0, 0), 90, 0, 1)
    assert d0 == (0.0, -0.0, 1.0) and r0 == (1.0, 0.0, -0.0)
    assert abs(d90[0] - 1) < 1e-12 and abs(d90[2]) < 1e-12


def test_camera_info_uses_the_editors_own_text_format():
    """AoE3DE_s.exe, 2026-10-08: the editor's Set Cut writes 'vector(%f,%f,%f), vector(%f,%f,%f), ...' (4 vectors)."""
    assert EDITOR_FORMAT.match(CB.camera_info((100, 1, 100), 45, 28, 16))


def test_generated_map_has_one_camera_cut_per_view_and_markers():
    target = (100.0, 1.0, 100.0)
    vl = CB.views(target, [0, 45, 90, 135, 180, 225, 270, 315], 20, 14)
    xs, xml, trigs = CB.render('000000_cambench_t', 'CAMBENCH T', 'zzKoreanStablePhysics', vl, 8, 5, target)
    assert len(vl) == 9 and vl[-1]['label'] == 'overhead'
    assert xs.count('rmAddTriggerEffect("Camera Cut");') == 9
    params = re.findall(r'rmSetTriggerEffectParam\("CameraInfo", "([^"]+)"\);', xs)
    assert len(params) == 9 and all(EDITOR_FORMAT.match(p) for p in params)
    assert 'ZPMARK V01' in xs and 'ZPMARK V09' in xs and 'ZPMARK END' in xs
    assert [v['t'] for v in vl] == list(range(8, 8 + 5 * 9, 5))
    assert not re.search(r'\{[A-Z_]+\}', xs)


def test_bone_offset_maps_raw_to_world_like_the_placed_stable():
    """2026-10-08 top view: world = position + (-raw x, raw y, -raw z); horse bones raw (-1.085, 0, 3.42) and
    (-1.085, 0, -0.02) -> mean world offset (1.085, 0, -1.70)."""
    gr2 = REPO / 'art/zbench_korean_military/stable/korean_stable_physics.gr2'
    off = CB.bone_offset(gr2, ['bone_horse1', 'bone_horse2'])
    assert abs(off[0] - 1.085) < 1e-3 and abs(off[1]) < 1e-3 and abs(off[2] + 1.70) < 1e-3


def test_view_markers_survive_ocr_confusions():
    assert CB.parse_view_markers(['ZPMARK VO7']) == {'V07'}
    assert CB.parse_view_markers(['zp mark v1l', 'ZPMARK END']) == {'V11', 'END'}
