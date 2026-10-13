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


if __name__ == '__main__': unittest.main()
