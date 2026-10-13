"""Audit: 2026-10-13-codex-roof-civic-readers-01; fixed-page regression."""
import unittest
import numpy as np
from alpha_reader_gate import measure


class ReaderGateTests(unittest.TestCase):
    def data(self):
        return dict(pixel=np.array([[1, 1], [1, 1], [2, 2], [2, 2]]),
                    expected=np.array([True, True, False, False]),
                    interior=np.ones(4, bool), reader=np.array(['front', 'back', 'front', 'back']),
                    inventory=np.array(['front', 'back']), size=np.array([4, 4]))

    def test_compatible_reused_faces(self):
        d = self.data()
        alpha = np.zeros((4, 4), np.uint8); alpha[1, 1] = 255
        self.assertEqual(measure(d, alpha)['status'], 'PASS')

    def test_owner_pass_does_not_hide_other_reader(self):
        d = self.data(); d['expected'][1] = False
        alpha = np.zeros((4, 4), np.uint8); alpha[1, 1] = 255
        r = measure(d, alpha)
        self.assertEqual(r['conflicting_texels'], 1)
        self.assertEqual(r['interior_mismatch'], 1)
        self.assertEqual(r['status'], 'FAIL')

    def test_preflight_catches_impossible_sharing_without_texture(self):
        d = self.data(); d['expected'][1] = False
        self.assertEqual(measure(d)['status'], 'FAIL')

    def test_boundary_is_counted_but_not_interior_conflict(self):
        d = self.data(); d['expected'][1] = False; d['interior'][1] = False
        r = measure(d)
        self.assertEqual(r['samples'], 4)
        self.assertEqual(r['status'], 'PASS')

    def test_inventory_and_bounds_fail_closed(self):
        d = self.data(); d['inventory'] = np.array(['front'])
        with self.assertRaises(ValueError): measure(d)
        d = self.data(); d['pixel'][0, 0] = 4
        with self.assertRaises(ValueError): measure(d)

    def test_impossible_sharing_reports_independent_witness_pair(self):
        d = self.data(); d['expected'][1] = False
        r = measure(d)
        self.assertEqual(r['minimum_unavoidable_sample_errors'], 1)
        self.assertEqual(r['conflict_witnesses'], [{
            'pixel': [1, 1], 'opaque_sample': 0, 'cut_sample': 1,
            'opaque_reader': 'front', 'cut_reader': 'back'}])

    def test_fixed_protected_page_blocks_compatible_own_contour(self):
        d = self.data()
        self.assertEqual(measure(d)['status'], 'PASS')
        fixed = np.full((4, 4), 255, np.uint8)
        r = measure(d, fixed_alpha=fixed)
        self.assertEqual(r['status'], 'FAIL')
        self.assertEqual(r['conflicting_texels'], 0)
        self.assertEqual(r['fixed_alpha_mismatch'], 2)
        self.assertEqual(r['minimum_unavoidable_sample_errors'], 2)
        self.assertEqual(r['fixed_alpha_mismatch_texels'], 1)
        self.assertEqual(r['fixed_alpha_witnesses'][0]['reader'], 'front')
        fixed[2, 2] = 0
        self.assertEqual(measure(d, fixed_alpha=fixed)['status'], 'PASS')

    def test_fixed_alpha_boundary_tolerance_and_dimension_validation(self):
        d = self.data(); d['interior'][2:] = False
        self.assertEqual(measure(d, fixed_alpha=np.full((4, 4), 255))['status'], 'PASS')
        with self.assertRaises(ValueError): measure(d, fixed_alpha=np.zeros((3, 3)))


if __name__ == '__main__': unittest.main()
