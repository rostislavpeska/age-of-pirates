import unittest
import numpy as np
from check_edit_scope import compare


class ScopeTests(unittest.TestCase):
    def setUp(self):
        self.a = np.zeros((100, 100, 4), dtype=np.uint16)
        self.mask = np.zeros((100, 100), dtype=bool)
        self.mask[20:40, 20:40] = True

    def test_single_sample_below_percentile_is_rejected(self):
        b = self.a.copy(); b[80, 80, 0] = 1
        self.assertEqual(np.quantile(abs(b.astype(float)-self.a), .99), 0)
        self.assertEqual(compare(self.a, b, self.mask)['status'], 'FAIL')

    def test_declared_edit_passes(self):
        b = self.a.copy(); b[25, 25, 0] = 100
        self.assertEqual(compare(self.a, b, self.mask, [3])['status'], 'PASS')

    def test_alpha_protected_even_inside_edit(self):
        b = self.a.copy(); b[25, 25, 3] = 1
        self.assertEqual(compare(self.a, b, self.mask, [3])['status'], 'FAIL')

    def test_precision_mismatch_fails(self):
        with self.assertRaises(ValueError): compare(self.a, self.a.astype(np.uint8), self.mask)

    def test_vacuous_scope_fails(self):
        with self.assertRaises(ValueError): compare(self.a, self.a, np.ones_like(self.mask))

    def test_nonfinite_fails(self):
        a = self.a.astype(float); a[0, 0, 0] = np.nan
        with self.assertRaises(ValueError): compare(a, a, self.mask)


if __name__ == '__main__': unittest.main()
