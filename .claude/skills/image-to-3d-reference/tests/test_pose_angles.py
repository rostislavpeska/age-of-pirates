"""pose_angles.py on synthetic picks with known angles (2D and 3D), a drawn limb for the centring and the setup
errors. Host Python with numpy and Pillow; no Blender.

    python -B -m pytest .claude/skills/image-to-3d-reference/tests -q -p no:cacheprovider
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
import pytest

TESTS = Path(__file__).resolve().parent
sys.path[:0] = [str(TESTS.parent / 'scripts'), str(TESTS.parents[1] / 'blender-organic-modeling' / 'scripts')]
import pose_angles as P  # noqa: E402

ORTHO = {'res': 1200, 'px_per_m': 500.0, 'centre_z': 1.0}


def polar(p, deg, length, out):
    """p moved `length` px at `deg` from straight down, outward = +1 (image right) or -1."""
    t = math.radians(deg)
    return [p[0] + out * math.sin(t) * length, p[1] + math.cos(t) * length]


def arm(shoulder, upper, fore, out):
    e = polar(shoulder, upper, 150, out)
    return [shoulder, e, polar(e, fore, 120, out)]


def measure(tmp_path, picks, *extra):
    f = tmp_path / 'picks.json'
    f.write_text(json.dumps(picks), encoding='utf-8')
    out = tmp_path / 'pose.json'
    code = P.main([str(f), '--out', str(out)] + list(extra))
    return code, (json.loads(out.read_text(encoding='utf-8')) if out.is_file() else None)


def test_front_arms_and_legs_at_known_angles(tmp_path):
    hip_r, hip_l = [380, 650], [420, 650]
    knee_l = polar(hip_l, 8.2, 200, 1)
    picks = {'target': {'upper_arm_from_down': 26.2, 'leg_spread': 16.4}, 'cases': {'a': {'front': {
        'arms': {'R': arm([300, 400], 26.2, 40.0, -1), 'L': arm([500, 400], 26.2, 40.0, 1)},
        'legs': {'R': [hip_r, polar(hip_r, 8.2, 400, -1)], 'L': [hip_l, knee_l, polar(knee_l, 0.0, 200, 1)]}}}}}
    code, rep = measure(tmp_path, picks)
    assert code == 0
    c = rep['cases']['a']
    for side in ('R', 'L'):
        a = c['arms'][side]
        assert a['upper_arm_from_down'] == pytest.approx(26.2, abs=0.05)
        assert a['forearm_from_down'] == pytest.approx(40.0, abs=0.05)
        assert a['elbow_projected'] == pytest.approx(13.8, abs=0.05)
    assert c['legs']['R']['leg_from_down'] == pytest.approx(8.2, abs=0.05)
    assert c['legs']['L']['knee_projected'] == pytest.approx(8.2, abs=0.05)
    assert c['leg_spread'] == pytest.approx(c['legs']['R']['leg_from_down'] + c['legs']['L']['leg_from_down'])
    assert c['errors']['upper_arm_R'] == pytest.approx(0.0, abs=0.05)
    assert 'elbow_3d' not in c['errors'] and 'arm_3d' not in c


def test_an_arm_crossing_inward_is_negative(tmp_path):
    picks = {'cases': {'a': {'front': {'arms': {'L': arm([500, 400], -10.0, -10.0, 1)}}}}}
    code, rep = measure(tmp_path, picks)
    assert code == 0 and rep['cases']['a']['arms']['L']['upper_arm_from_down'] == pytest.approx(-10.0, abs=0.05)


def test_hip_rule_places_hidden_hips_from_the_shoulders(tmp_path):
    picks = {'cases': {'a': {'front': {
        'arms': {'R': arm([300, 400], 0, 0, -1), 'L': arm([500, 400], 0, 0, 1)},
        'hip_rule': {'height': 0.5, 'half_width': 0.05, 'ground_y': 1100},
        'legs': {'R': [[365, 1070]], 'L': [[435, 1070]]}}}}}
    code, rep = measure(tmp_path, picks)
    assert code == 0
    c = rep['cases']['a']
    assert c['hip_rule']['hips'] == {'R': [365.0, 750.0], 'L': [435.0, 750.0]}
    assert c['leg_spread'] == pytest.approx(0.0, abs=0.05)


def test_front_and_side_picks_give_the_3d_arm(tmp_path):
    def px(p):
        X, Y, Z = p
        z = 600 - (Z - 1.0) * 500
        return [X * 500 + 600, z], [Y * 500 + 600, z]

    S = np.array([0.2, 0.0, 1.5])
    t, phi = math.radians(23.2), math.radians(30)
    u = np.array([math.sin(t) * math.cos(phi), -math.sin(t) * math.sin(phi), -math.cos(t)])
    Ep = S + 0.3 * u
    W = Ep + 0.3 * np.array([0.25, -0.35, -0.9]) / np.linalg.norm([0.25, -0.35, -0.9])
    front, side = zip(*(px(p) for p in (S, Ep, W)))
    picks = {'target': {'upper_arm_from_down': 26.2, 'elbow': 26.5}, 'cases': {'a': {
        'front': {'arms': {'L': list(front)}}, 'side': {'arm': 'L', 'points': list(side)}, 'ortho': ORTHO}}}
    code, rep = measure(tmp_path, picks)
    assert code == 0
    a3 = rep['cases']['a']['arm_3d']
    down = np.array([0, 0, -1.0])
    ang = lambda u_, v_: math.degrees(math.acos(u_ @ v_ / np.linalg.norm(u_) / np.linalg.norm(v_)))  # noqa: E731
    assert a3['upper_arm_from_down_3d'] == pytest.approx(23.2, abs=0.06)
    assert a3['elbow_3d'] == pytest.approx(ang(Ep - S, W - Ep), abs=0.06)
    assert a3['chord_from_down_3d'] == pytest.approx(ang(W - S, down), abs=0.06)
    assert a3['wrist_forward_of_shoulder_m'] == pytest.approx(S[1] - W[1], abs=1e-3)
    assert a3['front_side_z_mismatch_m'] == pytest.approx(0.0, abs=1e-6)
    assert rep['cases']['a']['errors']['upper_arm_3d'] == pytest.approx(-3.0, abs=0.06)
    # an ortho mapping read from a render_ortho.py JSON (extra keys ignored) gives the same, a bad pick is flagged
    (tmp_path / 'm_ortho.json').write_text(json.dumps(dict(ORTHO, height=2.0, views={})), encoding='utf-8')
    side = [list(p) for p in side]
    side[2][1] += 20
    picks['cases']['a'].update(ortho='m_ortho.json', side={'arm': 'L', 'points': side})
    code, rep = measure(tmp_path, picks)
    assert code == 0 and rep['cases']['a']['arm_3d']['front_side_z_mismatch_m'] == pytest.approx(0.04, abs=1e-6)


def test_centre_limbs_snaps_elbow_and_wrist_to_the_silhouette(tmp_path):
    from PIL import Image, ImageDraw
    im = Image.new('RGBA', (400, 400), (0, 0, 0, 0))
    ImageDraw.Draw(im).line([(200, 50), (260, 300)], fill=(200, 60, 40, 255), width=20)
    im.save(tmp_path / 'limb.png')
    d = np.array([60.0, 250.0]) / math.hypot(60, 250)
    n = np.array([-d[1], d[0]])
    S = np.array([200.0, 50.0])
    E_ = S + d * 128 + n * 6
    W = S + d * 231 - n * 5
    picks = {'cases': {'a': {'front': {'image': 'limb.png', 'arms': {'L': [S.tolist(), E_.tolist(), W.tolist()]}}}}}
    code, rep = measure(tmp_path, picks)
    assert code == 0
    raw = rep['cases']['a']['arms']['L']['upper_arm_from_down']
    code, rep = measure(tmp_path, picks, '--centre-limbs', '--overlay-dir', str(tmp_path / 'ov'))
    assert code == 0
    c = rep['cases']['a']
    want = math.degrees(math.atan2(60, 250))
    assert c['arms']['L']['upper_arm_from_down'] == pytest.approx(want, abs=0.5)
    assert abs(raw - want) > 1.0
    assert 17 <= c['centring']['L']['elbow_width_px'] <= 23 and not c['centring']['L']['elbow_kept_as_picked']
    assert Image.open(c['overlay']).size == (400, 400)


def test_an_elbow_fused_to_the_body_keeps_its_pick(tmp_path):
    """The silhouette run through an elbow that touches a coat has no inner edge: its middle depends on the search
    cap, so the pick must stay as picked and be flagged (the wrist, free, is still centred)."""
    from PIL import Image, ImageDraw
    im = Image.new('RGBA', (400, 400), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    dr.line([(200, 50), (260, 300)], fill=(200, 60, 40, 255), width=20)
    dr.rectangle([60, 140, 228, 200], fill=(40, 40, 160, 255))      # the coat, fused to the arm at the elbow
    im.save(tmp_path / 'fused.png')
    d = np.array([60.0, 250.0]) / math.hypot(60, 250)
    n = np.array([-d[1], d[0]])
    S = np.array([200.0, 50.0])
    E_ = S + d * 128 + n * 6
    W = S + d * 231 - n * 5
    picks = {'cases': {'a': {'front': {'image': 'fused.png', 'arms': {'L': [S.tolist(), E_.tolist(), W.tolist()]}}}}}
    code, rep = measure(tmp_path, picks, '--centre-limbs')
    assert code == 0
    c = rep['cases']['a']
    assert c['centring']['L']['elbow_kept_as_picked'] and not c['centring']['L']['wrist_kept_as_picked']
    assert c['arms']['L']['E'] == pytest.approx(E_.round(1).tolist(), abs=0.05)


@pytest.mark.parametrize('picks,why', [
    ({}, 'cases'),
    ({'cases': {'a': {'front': {'arms': {'L': [[0, 0], [1, 1]]}}}}}, '3 picks'),
    ({'cases': {'a': {'front': {'arms': {'X': [[0, 0], [1, 1], [2, 3]]}}}}}, 'not R or L'),
    ({'cases': {'a': {'front': {'arms': {'L': [[0, 0], [0, 1], [0, 2]]}}, 'side': {'arm': 'L',
                                'points': [[0, 0], [0, 1], [0, 2]]}}}}, 'ortho'),
    ({'cases': {'a': {'front': {'image': 'absent.png', 'arms': {'L': [[0, 0], [0, 1], [0, 2]]}}}}}, 'not found'),
    ({'cases': {'a': {'front': {'arms': {'L': [[0, 0], [0, 1], [0, 2]]},
                                'hip_rule': {'height': 0.5, 'half_width': 0.05, 'ground_y': 900}}}}}, 'both'),
    ({'cases': {'a': {'front': {'arms': {'L': [[0, 0], [0, 0], [0, 2]]}}}}}, 'coincide'),
])
def test_bad_picks_are_setup_errors(tmp_path, capsys, picks, why):
    code, rep = measure(tmp_path, picks)
    assert code == 2 and rep is None
    assert why in capsys.readouterr().err


def test_output_inside_a_git_work_tree_is_refused(tmp_path, capsys):
    f = tmp_path / 'picks.json'
    f.write_text(json.dumps({'cases': {'a': {'front': {'arms': {'L': arm([500, 400], 26, 30, 1)}}}}}))
    target = TESTS / '_refused_pose.json'
    assert P.main([str(f), '--out', str(target)]) == 2
    assert 'git work tree' in capsys.readouterr().err and not target.exists()
