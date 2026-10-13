"""Audit: 2026-10-13-roof-consulate-valley-03. Physical probe controls."""
import unittest
import numpy as np
from paired_surface import (exact_edge_pairs, edge_probes, normal_to_physical,
                            register_boundary, boundary_uv)


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

class TestBoundaryRegistration(unittest.TestCase):
    """Audit 2026-10-13-codex-roof-pattern-104; independently known seam fixtures."""

    def setUp(self):
        self.path = np.array([[0., 0, 0], [1, 0, 0], [2, 0, 0]])
        self.edges = np.array([[[1., 0, 0], [0, 0, 0]], [[2., 0, 0], [1, 0, 0]]])
        self.uv = np.array([[[.8, .9], [.8, .1]], [[.2, .1], [.2, .9]]])

    def bind(self, edges=None, uv=None, path=None):
        return register_boundary(self.path if path is None else path,
                                 self.edges if edges is None else edges,
                                 self.uv if uv is None else uv, tolerance=1e-6)

    def test_separate_rotated_mirrored_charts_unequal_subdivision(self):
        # One roof edge versus two reversed end edges on separate rotated charts.
        roof = self.bind(edges=np.array([[[0., 0, 0], [2, 0, 0]]]),
                         uv=np.array([[[.1, .2], [.9, .2]]]))
        strip = self.bind()
        p = [.5, 1.5]
        np.testing.assert_allclose(boundary_uv(roof, p)['uv'], [[.3, .2], [.7, .2]])
        np.testing.assert_allclose(boundary_uv(strip, p)['uv'], [[.8, .5], [.2, .5]])
        self.assertEqual(strip['maximum_residual'], 0)
        # A UV join internal to the strip retains both exact endpoint readers.
        split = boundary_uv(strip, [1.])
        np.testing.assert_array_equal(split['sample'], [0, 0])
        np.testing.assert_allclose(split['uv'], [[.8, .9], [.2, .9]])

    def test_bent_path_uses_arclength_and_rejects_chord(self):
        path = np.array([[0., 0, 0], [1, 0, 0], [1, 1, 0]])
        edges = np.array([path[:2], path[1:]])
        result = self.bind(path=path, edges=edges)
        np.testing.assert_allclose(result['edge_s'], [[0, 1], [1, 2]])
        with self.assertRaisesRegex(ValueError, 'bend'):
            self.bind(path=path, edges=path[[0, 2]][None], uv=self.uv[:1])

    def test_gap_overlap_and_missing_terminal_fail(self):
        gap = self.edges.copy(); gap[0, 0, 0] = .9
        with self.assertRaisesRegex(ValueError, 'Gap'): self.bind(edges=gap)
        overlap = self.edges.copy(); overlap[0, 0, 0] = 1.1
        with self.assertRaisesRegex(ValueError, 'Overlapping'): self.bind(edges=overlap)
        missing = self.edges.copy(); missing[1, 0, 0] = 1.9
        with self.assertRaisesRegex(ValueError, 'endpoints'): self.bind(edges=missing)

    def test_nearby_wrong_surface_is_not_silently_attached(self):
        wrong = self.edges.copy(); wrong[:, :, 2] += .01
        with self.assertRaisesRegex(ValueError, 'off the declared path'): self.bind(edges=wrong)

    def test_repeated_path_is_ambiguous(self):
        path = np.array([[0., 0, 0], [2, 0, 0], [0, 0, 0]])
        with self.assertRaisesRegex(ValueError, 'Ambiguous'): self.bind(path=path)

    def test_invalid_uv_geometry_and_probe_are_rejected(self):
        for bad_uv in (np.zeros_like(self.uv), np.full_like(self.uv, np.nan)):
            with self.assertRaises(ValueError): self.bind(uv=bad_uv)
        bad_path = self.path.copy(); bad_path[1] = bad_path[0]
        with self.assertRaises(ValueError): self.bind(path=bad_path)
        binding = self.bind()
        for bad_probe in ([-.01], [2.01], [np.nan], []):
            with self.assertRaises(ValueError): boundary_uv(binding, bad_probe)


if __name__ == '__main__':unittest.main()
