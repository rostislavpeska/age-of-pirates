import unittest
import numpy as np
from check_render_response import check


class ResponseTests(unittest.TestCase):
    def test_inert_active_material_fails_even_when_control_was_set(self):
        blue = np.full((20, 20, 3), [30, 30, 190], dtype=np.uint8)
        self.assertFalse(check(blue, blue.copy(), {'gable': [0, 0, 20, 20]})['pass'])

    def test_unrelated_band_does_not_hide_inert_gable(self):
        a = np.full((40, 20, 3), [30, 30, 190], dtype=np.uint8)
        b = a.copy(); b[20:] = [190, 30, 30]
        self.assertFalse(check(a, b, {'gable': [0, 0, 20, 20]})['pass'])
        b[:20] = [190, 30, 30]
        self.assertTrue(check(a, b, {'gable': [0, 0, 20, 20]})['pass'])


if __name__ == '__main__':
    unittest.main()
