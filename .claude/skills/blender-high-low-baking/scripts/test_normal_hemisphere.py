import unittest
import numpy as np
from normal_hemisphere import assess


class HemisphereTest(unittest.TestCase):
    def test_negative_control_and_transparent_scope(self):
        normal = np.array([[[0., 0., 1.], [0., 0., -1.]]])
        used = np.ones((1, 2), bool)
        self.assertEqual(assess(normal, used, np.ones((1, 2)))['negative_z_pixels'], 1)
        self.assertEqual(assess(normal, used, np.array([[1., 0.]]))['status'], 'PASS')

    def test_nonfinite_and_empty_evidence_fail(self):
        self.assertEqual(assess(np.full((1, 1, 3), np.nan), [[True]], [[1.]])['status'], 'FAIL')
        self.assertEqual(assess(np.array([[[0., 0., 1.]]]), [[False]], [[1.]])['status'], 'FAIL')

    def test_quantized_horizon_is_tolerated(self):
        normal = np.array([[[1., 0., -1 / 255]]])
        self.assertEqual(assess(normal, [[True]], [[1.]])['status'], 'PASS')


if __name__ == '__main__':
    unittest.main()
