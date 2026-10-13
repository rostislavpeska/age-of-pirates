"""Audit: 2026-10-13-roof-consulate-valley-03. Physical probe controls."""
import unittest
import numpy as np
from paired_surface import exact_edge_pairs, edge_probes, normal_to_physical


class TestPairedSurface(unittest.TestCase):
    def setUp(self):
        self.co = np.array([[0., 0, 0], [1, 0, 0], [0, 1, 0]])
        self.uv = self.co[:, :2]
        self.n = np.tile([0., 0, 1], (3, 1))
        self.w = np.array([[.2, .3, .5]])

    def test_split_duplicate_edge_and_rotated_uv(self):
        co = np.array([self.co, [[1., 0, 0], [1, 1, 0], [0, 1, 0]]])
        uv = co[:, :, :2].copy(); uv[1] += 2
        pairs, ambiguous = exact_edge_pairs(co, uv)
        self.assertEqual(len(pairs), 1); self.assertFalse(ambiguous)
        self.assertGreater(pairs[0]['uv_gap'], 2)

    def test_ambiguous_three_sides(self):
        pairs, ambiguous = exact_edge_pairs(np.array([self.co]*3), np.array([self.uv]*3))
        self.assertFalse(pairs); self.assertEqual(len(ambiguous), 3)

    def test_interior_and_outside_probes(self):
        _, _, valid = edge_probes(self.co, (0, 1), [.2, .8], .1)
        self.assertTrue(valid.all())
        _, _, valid = edge_probes(self.co, (0, 1), [.2, .8], 2)
        self.assertFalse(valid.any())

    def test_mirrored_and_rotated_normals(self):
        v = np.array([[.3, .4, np.sqrt(.75)]])
        ordinary = normal_to_physical(self.co, self.uv, self.n, self.w, (v+1)/2)
        mirrored = normal_to_physical(self.co, self.uv*[-1, 1], self.n, self.w, (v*[-1,1,1]+1)/2)
        rotated = normal_to_physical(self.co, self.uv[:, ::-1]*[1,-1], self.n, self.w, (v[:,[1,0,2]]*[1,-1,1]+1)/2)
        np.testing.assert_allclose(ordinary, mirrored, atol=1e-12)
        np.testing.assert_allclose(ordinary, rotated, atol=1e-12)
        wrong = normal_to_physical(self.co, self.uv*[-1, 1], self.n, self.w, (v+1)/2)
        self.assertGreater(np.linalg.norm(ordinary-wrong), .5)

    def test_degenerate_uv_rejected(self):
        with self.assertRaises(ValueError):
            normal_to_physical(self.co, np.zeros((3,2)), self.n, self.w, [[.5,.5,1]])

if __name__ == '__main__':unittest.main()
