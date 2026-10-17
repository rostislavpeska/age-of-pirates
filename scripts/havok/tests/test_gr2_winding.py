"""gr2_lint check_winding: a face's winding must agree with its stored normal (the engine culls by winding and lights
by the normal). Korean House r14, 2026-10-09: a mirrored export frame without corner reversal shipped every face inside
out - black two-sided roofs, dark walls - and no other check saw it."""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import gr2_lint as L


def box(reverse=False, flip_one=False):
    """a closed unit cube, outward normals per corner; reverse = every face's corner order reversed (inside out)"""
    quads = [((0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0), (0, 0, -1)), ((0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1), (0, 0, 1)),
             ((0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1), (0, -1, 0)), ((0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0), (0, 1, 0)),
             ((0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0), (-1, 0, 0)), ((1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1), (1, 0, 0))]
    pos, nrm, tris = [], [], []
    for qi, (*corners, n) in enumerate(quads):
        b = len(pos); pos += corners; nrm += [n] * 4
        for t in ((b, b + 1, b + 2), (b, b + 2, b + 3)):
            if reverse or (flip_one and qi == 0):
                t = t[::-1]
            tris.append(t)
    return dict(name='box', mats=['mata'], pos=np.array(pos, float), nrm=np.array(nrm, float), tris=np.array(tris))


def test_outward_box_passes():
    r = L.check_winding('intact', {'render': [box()]})
    assert r['status'] == 'PASS' and r['data']['share'] == 1.0


def test_inside_out_box_fails_and_names_the_mesh():
    r = L.check_winding('intact', {'render': [box(reverse=True)]})
    assert r['status'] == 'FAIL' and r['data']['share'] == 0.0 and 'INSIDE OUT' in r['summary']


def test_one_flipped_face_of_six_fails_the_model_share():
    r = L.check_winding('intact', {'render': [box(flip_one=True)]})       # 5/6 = 83 % < 90 %
    assert r['status'] == 'FAIL' and abs(r['data']['share'] - 5 / 6) < 1e-3


def test_a_small_mostly_reversed_mesh_fails_even_when_the_model_share_passes():
    big = box(); big['pos'] = big['pos'] * 10                             # 100x the area of the small one
    r = L.check_winding('intact', {'render': [big, box(reverse=True)]})
    assert r['data']['share'] > 0.98 and r['status'] == 'FAIL'


def test_mirrored_frame_needs_reversed_corners():
    """Blender -> raw (-x, z, -y) has det -1: positions and normals through it, corners kept -> inside out"""
    M = np.array([[-1, 0, 0], [0, 0, 1], [0, -1, 0]], float)
    assert round(np.linalg.det(M)) == -1
    b = box(); b['pos'] = b['pos'] @ M.T; b['nrm'] = b['nrm'] @ M.T
    assert L.check_winding('x', {'render': [b]})['status'] == 'FAIL'
    b['tris'] = b['tris'][:, ::-1]
    assert L.check_winding('x', {'render': [b]})['status'] == 'PASS'
