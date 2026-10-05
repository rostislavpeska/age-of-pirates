"""INC-079: missing face evidence; INC-080: stale AO cache after input mutation."""
import unittest
import numpy as np
from ao_compat import compatible


def chart(points):
    return {'N': np.array([[1., 0., 0.], [0., 1., 0.]]), 'L': 100., 'W': 100.,
            'faces': [{'ao': points}]}


class AOEvidenceTests(unittest.TestCase):
    def test_missing_evidence_is_not_compatible(self):
        self.assertFalse(compatible(chart([]), chart([]), np.eye(3)))

    def test_unmatched_member_sample_is_not_dropped(self):
        self.assertFalse(compatible(chart([[1, 1, .8], [90, 90, .8]]), chart([[1, 1, .8]]), np.eye(3)))

    def test_every_face_needs_evidence(self):
        m = chart([[1, 1, .8]])
        m['faces'].append({'ao': []})
        self.assertFalse(compatible(m, chart([[1, 1, .8]]), np.eye(3)))

    def test_equal_means_do_not_hide_local_shadow(self):
        a = chart([[1, 1, .4], [90, 90, .8]])
        b = chart([[1, 1, .8], [90, 90, .4]])
        self.assertFalse(compatible(a, b, np.eye(3)))

    def test_valid_pointwise_match_passes(self):
        a = chart([[1, 1, .7], [90, 90, .9]])
        b = chart([[1, 1, .72], [90, 90, .88]])
        self.assertTrue(compatible(a, b, np.eye(3)))

    def test_bad_samples_and_nan_policy_do_not_pass(self):
        self.assertFalse(compatible(chart([[1, 1, float('nan')]]), chart([[1, 1, .8]]), np.eye(3)))
        with self.assertRaises(ValueError):
            compatible(chart([[1, 1, .8]]), chart([[1, 1, .8]]), np.eye(3), p={'cell': 0})

    def test_changed_sample_or_frame_invalidates_cached_evidence(self):
        a, b = chart([[1, 1, .8]]), chart([[1, 1, .8]])
        self.assertTrue(compatible(a, b, np.eye(3)))
        b['faces'][0]['ao'][0][2] = .1
        self.assertFalse(compatible(a, b, np.eye(3)))
        b['faces'][0]['ao'][0][2] = .8
        self.assertTrue(compatible(a, b, np.eye(3)))
        b['N'][0, 2] = 80
        self.assertFalse(compatible(a, b, np.eye(3)))


if __name__ == '__main__':
    unittest.main()
