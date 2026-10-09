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


def test_swap_skeleton_takes_the_donor_hierarchy_at_the_target_joints(tmp_path):
    target, _ = P.parse_model(gxo(tmp_path, 't.gxo', MODEL))
    donor_text = 'b "Bip01_Root" 0 %s 0 0 0\nb "Pelvis" 1 %s 0 0 0.5\nb "Arm" 2 %s 0 0 3\n' % (I, I, I)
    donor, _ = P.parse_model(gxo(tmp_path, 'd.gxo', donor_text))
    swapped = P.swap_skeleton(donor, target)
    assert [b['name'] for b in swapped] == ['Bip01_Root', 'Pelvis', 'Arm']
    assert [b['parent'] for b in swapped] == [-1, 0, 1]
    assert np.allclose(swapped[2]['W0'][3, :3], [0, 0, 1])          # the target's Arm joint, not the donor's
    assert np.allclose(swapped[1]['W0'][3, :3], [0, 0, 0.5])        # donor-only bone keeps its offset
