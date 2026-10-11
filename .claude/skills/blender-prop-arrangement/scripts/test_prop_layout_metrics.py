"""Regression tests for prop_layout_metrics (pure Python): python test_prop_layout_metrics.py"""
import math, random, unittest
from prop_layout_metrics import (alignment_share, axis_rows, clark_evans, lean_mu_required, nn_cv, orientation_entropy,
                                 polygon_area_perimeter, stability_ok, support_margin, yaw_offset)


class Metrics(unittest.TestCase):
    def test_yaw_offset(self):
        self.assertAlmostEqual(yaw_offset(92), 2); self.assertAlmostEqual(yaw_offset(-3), 3); self.assertAlmostEqual(yaw_offset(45), 45)

    def test_grid_is_boxy(self):
        grid = [(x * .8, y * .8) for x in range(4) for y in range(3)]
        A, P = polygon_area_perimeter([(-.4, -.4), (2.8, -.4), (2.8, 2.0), (-.4, 2.0)])
        self.assertGreater(clark_evans(grid, A, P), 1.1)                 # regular
        self.assertLess(nn_cv(grid), .05)
        self.assertGreater(len(axis_rows(grid)), 0)
        self.assertEqual(alignment_share([0, 90, 180, 1.5]), 1.0)
        self.assertLess(orientation_entropy([0, 90, 180, 1.5, 0, 0]), .2)

    def test_clustered_reads_clustered(self):
        rng = random.Random(3); pts = []
        for cx, cy in ((.5, .5), (2.4, 1.6)):
            pts += [(cx + rng.gauss(0, .12), cy + rng.gauss(0, .12)) for _ in range(6)]
        A, P = polygon_area_perimeter([(0, 0), (3, 0), (3, 2.2), (0, 2.2)])
        self.assertLess(clark_evans(pts, A, P), .8)

    def test_donnelly_matches_random_patterns(self):
        rng = random.Random(1); w, h, n = 2.0, 3.0, 12; A, P = w * h, 2 * (w + h); R = []
        for _ in range(1500):
            R.append(clark_evans([(rng.random() * w, rng.random() * h) for _ in range(n)], A, P))
        self.assertAlmostEqual(sum(R) / len(R), 1.0, delta=.03)        # unbiased for Poisson patterns (edge-corrected)

    def test_support_margin(self):
        sq = [(0, 0), (.4, 0), (.4, .4), (0, .4)]
        m, w = support_margin((.2, .2), sq); self.assertAlmostEqual(m, .2); self.assertAlmostEqual(w, .4)
        self.assertLess(support_margin((.5, .2), sq)[0], 0)
        self.assertTrue(stability_ok((.2, .2), sq)[0]); self.assertFalse(stability_ok((.39, .2), sq)[0])
        self.assertEqual(support_margin((0, 0), [(0, 0), (1, 0)])[0], float('-inf'))   # a line contact spans no area

    def test_lean_ladder(self):
        r, th = .625, math.radians(13)                                   # cannon wheel leaning 13 deg on a wall
        self.assertAlmostEqual(lean_mu_required(r * math.sin(th), 2 * r * math.cos(th)), math.tan(th) / 2)
        self.assertLess(lean_mu_required(r * math.sin(th), 2 * r * math.cos(th)), .4)


if __name__ == '__main__':
    unittest.main()
