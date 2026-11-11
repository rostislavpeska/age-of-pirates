"""pose_sim.py on synthetic GXO text (no game files; runs on Linux CI).

    python -m pytest .claude/skills/aoe3de-unit-animation/scripts -q
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pose_sim as P  # noqa: E402

I = '1 0 0 0 1 0 0 0 1'
MODEL = '''b "Root" 0 %s 0 0 0
b "Arm" 1 %s 0 0 1
m "mesh"
mb "Arm"
v 1 0 1
vn 0 0 1
vt 0 0
vw 1 0 0 0 1 1 1 1
v 2 0 1
vn 0 0 1
vt 1 0
vw 1 0 0 0 1 1 1 1
v 1 1 1
vn 0 0 1
vt 0 1
vw 1 0 0 0 1 1 1 1
fg 1
f 1 2 3
''' % (I, I)


def gxo(tmp_path, name, text):
    p = tmp_path / name
    p.write_text(text)
    return p


def test_rest_keys_reproduce_the_rest_mesh(tmp_path):
    bones, meshes = P.parse_model(gxo(tmp_path, 'm.gxo', MODEL))
    anim = gxo(tmp_path, 'a.gxo', 'a 1 30\ncg "Root"\nc "Arm"\nk %s 0 0 1\n' % I)
    out = P.skin(bones, P.pose(bones, P.parse_anim(anim)), meshes[0])
    assert np.allclose(out, meshes[0]['v'])


def test_a_track_rotates_its_bone_relative_to_the_models_parent(tmp_path):
    bones, meshes = P.parse_model(gxo(tmp_path, 'm.gxo', MODEL))
    # 90 degrees about z, row-vector convention (p' = p @ R): x -> y
    anim = gxo(tmp_path, 'a.gxo', 'a 1 30\ncg "Root"\nc "Arm"\nk 0 1 0 -1 0 0 0 0 1 0 0 1\n')
    out = P.skin(bones, P.pose(bones, P.parse_anim(anim)), meshes[0])
    assert np.allclose(out[0], [0, 1, 1]) and np.allclose(out[1], [0, 2, 1])


def test_a_track_for_a_missing_bone_changes_nothing(tmp_path):
    bones, meshes = P.parse_model(gxo(tmp_path, 'm.gxo', MODEL))
    anim = gxo(tmp_path, 'a.gxo', 'a 1 30\ncg "X"\nc "Neck"\nk 0 1 0 -1 0 0 0 0 1 5 5 5\n')
    assert np.allclose(P.skin(bones, P.pose(bones, P.parse_anim(anim)), meshes[0]), meshes[0]['v'])


def test_orthonormalize_takes_the_nearest_rotation_and_keeps_the_translation(tmp_path):
    bones, meshes = P.parse_model(gxo(tmp_path, 'm.gxo', MODEL))
    # float noise on a clean key: the 90 degree z rotation scaled by 1.0004, translation (0, 0, 1) as keyed
    anim = gxo(tmp_path, 'a.gxo', 'a 1 30\ncg "Root"\nc "Arm"\nk 0 1.0004 0 -1.0004 0 0 0 0 1.0004 0 0 1\n')
    keys = P.orthonormalize(P.parse_anim(anim))
    R = keys['Arm'][:3, :3]
    assert np.allclose(R @ R.T, np.eye(3)) and np.isclose(np.linalg.det(R), 1.0)
    assert np.allclose(keys['Arm'][3, :3], [0, 0, 1])
    out = P.skin(bones, P.pose(bones, keys), meshes[0])
    assert np.allclose(out[0], [0, 1, 1]) and np.allclose(out[1], [0, 2, 1])


def test_orthonormalize_fixes_a_reflected_polar_factor():
    K = np.eye(4)
    K[:3, :3] = np.diag([1.0, 1.0, -0.9])                            # det < 0: nearest proper rotation, not a mirror
    R = P.orthonormalize({'Arm': K})['Arm'][:3, :3]
    assert np.isclose(np.linalg.det(R), 1.0)


NEAR_SINGULAR = 'k 0.0019 -0.0128 -0.2591 0.0194 -0.0019 -0.0153 -0.0009 -0.0146 0.2293 0 0 1'   # det ~1e-4


def test_bad_tracks_flags_a_near_singular_key_on_a_driven_bone_only(tmp_path):
    bones, _ = P.parse_model(gxo(tmp_path, 'm.gxo', MODEL))
    anim = gxo(tmp_path, 'a.gxo', 'a 1 30\ncg "Root"\nc "Arm"\n%s\nc "Ghost"\n%s\n' % (NEAR_SINGULAR, NEAR_SINGULAR))
    bad = P.bad_tracks(P.parse_anim(anim), bones)
    assert [n for n, _ in bad] == ['Arm'] and abs(bad[0][1]) < 1e-3     # the bone-less Ghost track is ignored
    clean = gxo(tmp_path, 'c.gxo', 'a 1 30\ncg "Root"\nc "Arm"\nk %s 0 0 1\n' % I)
    assert P.bad_tracks(P.parse_anim(clean), bones) == []
    noisy = {'Arm': np.diag([1.0004, 1.0, 1.0, 1.0])}                 # float noise passes the default 0.001
    assert P.bad_tracks(noisy, bones) == [] and P.bad_tracks(noisy, bones, tol=1e-4) != []


def run(*args):
    import subprocess
    return subprocess.run([sys.executable, str(Path(P.__file__))] + [str(a) for a in args],
                          capture_output=True, text=True)


def test_cli_refuses_a_near_singular_key_and_names_the_decoder(tmp_path):
    m = gxo(tmp_path, 'm.gxo', MODEL)
    a = gxo(tmp_path, 'a.gxo', 'a 2 30\ncg "Root"\nc "Arm"\nk %s 0 0 1\n%s\n' % (I, NEAR_SINGULAR))
    out = tmp_path / 'p.obj'
    r = run('--model', m, '--anim', a, '--out', out, '--frame', 1)
    assert r.returncode != 0 and 'Arm' in r.stderr and 'clip_decode.py' in r.stderr and not out.exists()
    r = run('--model', m, '--anim', a, '--out', out, '--frame', 1, '--orthonormalize')   # polish cannot bypass it
    assert r.returncode != 0 and not out.exists()
    r = run('--model', m, '--anim', a, '--out', out, '--frame', 0, '--orthonormalize')
    assert r.returncode == 0 and out.is_file(), r.stderr
    r = run('--model', m, '--anim', a, '--out', out, '--frame', 5)
    assert r.returncode != 0 and 'no key 5' in r.stderr


def test_cli_checks_the_mount_clip_too(tmp_path):
    m = gxo(tmp_path, 'm.gxo', MODEL)
    a = gxo(tmp_path, 'a.gxo', 'a 1 30\ncg "Root"\nc "Arm"\nk %s 0 0 1\n' % I)
    horse = gxo(tmp_path, 'h.gxo', MODEL.replace('"Arm"', '"seat_attachpoint"'))
    hclip = gxo(tmp_path, 'ha.gxo', 'a 1 30\ncg "Root"\nc "seat_attachpoint"\n%s\n' % NEAR_SINGULAR)
    r = run('--model', m, '--anim', a, '--out', tmp_path / 'p.obj', '--mount', horse, '--mount-anim', hclip)
    assert r.returncode != 0 and 'seat_attachpoint' in r.stderr


def test_swap_skeleton_takes_the_donor_hierarchy_at_the_target_joints(tmp_path):
    target, _ = P.parse_model(gxo(tmp_path, 't.gxo', MODEL))
    donor_text = 'b "Bip01_Root" 0 %s 0 0 0\nb "Pelvis" 1 %s 0 0 0.5\nb "Arm" 2 %s 0 0 3\n' % (I, I, I)
    donor, _ = P.parse_model(gxo(tmp_path, 'd.gxo', donor_text))
    swapped = P.swap_skeleton(donor, target)
    assert [b['name'] for b in swapped] == ['Bip01_Root', 'Pelvis', 'Arm']
    assert [b['parent'] for b in swapped] == [-1, 0, 1]
    assert np.allclose(swapped[2]['W0'][3, :3], [0, 0, 1])          # the target's Arm joint, not the donor's
    assert np.allclose(swapped[1]['W0'][3, :3], [0, 0, 0.5])        # donor-only bone keeps its offset
