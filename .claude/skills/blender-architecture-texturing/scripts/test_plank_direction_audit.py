"""Synthetic checks of plank_direction_audit (host Python): boards painted along x on a deck pass; a deck whose two halves
show boards in different directions fails coherence; a long tread with boards across it fails the long-axis rule; a
mirrored / rotated UV island is judged in the world; a flat texture is unassessed, never a pass."""
import math, sys, unittest
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import plank_direction_audit as A  # noqa: E402

S = 512


def boards(axis='x', width=16):
    """image with board seams: axis 'x' = boards run along image x (horizontal seams)"""
    y, x = np.mgrid[0:S, 0:S]
    k = (y if axis == 'x' else x) % width
    g = 150 + 30 * np.sin((x if axis == 'x' else y) * .7) * 0 + np.where(k < 2, -90, 0) + (np.random.default_rng(1).normal(0, 6, (S, S)))
    return np.clip(np.stack([g] * 3, -1), 0, 255).astype(np.uint8)


def quad(x0, x1, y0, y1, u0, u1, v0, v1, rot=False, z=0.):
    P = np.array([[x0, y0, z], [x1, y0, z], [x1, y1, z], [x0, y1, z]], float)
    U = np.array([[u0, v0], [u1, v0], [u1, v1], [u0, v1]], float)
    if rot:                                                                   # UV island turned 90 deg
        U = np.array([[u0, v0], [u0, v1], [u1, v1], [u1, v0]], float)
    return P, U


def mesh(quads):
    P, U, T = [], [], []
    for q in quads:
        o = len(P); P += list(q[0]); U += list(q[1]); T += [[o, o + 1, o + 2], [o, o + 2, o + 3]]
    return np.array(P), np.array(U), np.array(T)


class PlankAudit(unittest.TestCase):
    def test_long_deck_along_x_passes(self):
        P, U, T = mesh([quad(0, 3, 0, 1, .05, .95, .3, .6)])
        r = A.audit(P, U, T, boards('x'))
        self.assertEqual(r['status'], 'PASS', r['problems'])

    def test_mixed_directions_fail_coherence(self):
        P, U, T = mesh([quad(0, 1.5, 0, 1, .05, .45, .3, .6), quad(1.5, 3, 0, 1, .55, .95, .3, .6, rot=True)])
        r = A.audit(P, U, T, boards('x'))
        self.assertEqual(r['status'], 'FAIL'); self.assertTrue(any(p['error'] == 'coherence' for p in r['problems']))

    def test_tread_boards_across_fail_long_axis(self):
        P, U, T = mesh([quad(0, .4, 0, 2.0, .05, .95, .3, .6)])               # long along y, boards painted along x
        r = A.audit(P, U, T, boards('x'))
        self.assertTrue(any(p['error'] == 'floor_long_axis' for p in r['problems']))

    def test_rotated_island_judged_in_world(self):
        P, U, T = mesh([quad(0, .4, 0, 2.0, .05, .95, .3, .6, rot=True)])     # same tread, island turned: boards along y
        r = A.audit(P, U, T, boards('x'))
        self.assertEqual(r['status'], 'PASS', r['problems'])

    def test_flat_texture_unassessed(self):
        P, U, T = mesh([quad(0, 3, 0, 1, .05, .95, .3, .6)])
        flat = np.full((S, S, 3), 128, np.uint8)
        r = A.audit(P, U, T, flat)
        self.assertEqual(r['status'], 'INCOMPLETE'); self.assertGreater(r['unassessed'], 0)


if __name__ == '__main__':
    unittest.main()
