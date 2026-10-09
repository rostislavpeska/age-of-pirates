"""python -m pytest .claude/skills/masonry-texturing/scripts -q"""
import importlib.util
import unittest
from pathlib import Path

import numpy as np

spec = importlib.util.spec_from_file_location('masonry_lib', Path(__file__).with_name('masonry_lib.py'))
M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)


class Masonry(unittest.TestCase):
    def test_ring_bond_closes(self):
        for course in range(6):
            pos = M.ring_bond_positions(6.58, .25, course, 'ring0')
            self.assertEqual(len(pos), round(6.58 / .25))
            gaps = np.diff(np.concatenate([pos, [pos[0] + 1]]))           # includes the wrap gap
            self.assertAlmostEqual(gaps.sum(), 1., places=9)
            self.assertTrue(np.all(gaps * 6.58 > .2) and np.all(gaps * 6.58 < .3))

    def test_running_bond_offset(self):
        a, b = M.ring_bond_positions(6.0, .25, 0, 'k'), M.ring_bond_positions(6.0, .25, 1, 'k')
        d = M.periodic_joint_distance(b, a, 6.0)                            # odd-course joints sit inside even-course units
        self.assertGreater(float(d.min()), .05)

    def test_pnoise_wraps(self):
        n = M.pnoise((40, 300), 20, 'wrap')
        self.assertLess(float(np.abs(n[:, 0] - n[:, -1]).mean()), .2)

    def test_rounded_box(self):
        self.assertLess(float(M.rounded_box_distance(np.array(0.), np.array(0.), .1)), 0)
        self.assertAlmostEqual(float(M.rounded_box_distance(np.array(.5), np.array(.3), .1)), .3)

    def test_gate_accepts_aligned_rejects_shifted(self):
        J = np.zeros((120, 200), bool); J[::30, :] = True; J[:, ::40] = True
        paint = np.where(J[..., None], .1, .6) * np.ones(3)
        ok, f1, dx, dy, *_ = M.registration_gate(paint, J)
        self.assertTrue(ok); self.assertEqual((dx, dy), (0, 0)); self.assertGreater(f1, .9)
        noise = np.random.default_rng(0).uniform(.3, .7, (120, 200, 3))      # unrelated painting
        self.assertFalse(M.registration_gate(noise, J)[0])

    def test_crossfade_closes_wrap(self):
        sheet = np.random.default_rng(1).random((10, 130, 3)); out = M.crossfade_wrap(sheet, 100)
        np.testing.assert_allclose(out[:, 0], sheet[:, 100] * (1 - .5 / 30) + sheet[:, 0] * (.5 / 30))

    def test_row_extent(self):
        poly = M.hull([(0, 0), (4, 0), (3.6, 2), (.4, 2)])                   # battered trapezoid
        lo, hi = M.row_extent(poly, np.array([0.001, 1., 1.999]))
        np.testing.assert_allclose(hi - lo, [4, 3.6, 3.2], atol=1e-3)


if __name__ == '__main__':
    unittest.main()
