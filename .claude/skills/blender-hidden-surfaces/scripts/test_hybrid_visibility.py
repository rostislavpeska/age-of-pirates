import copy
import unittest

import numpy as np
from hybrid_visibility import DEFAULTS, adjacency, classify, cut


def fixture():
    faces = []
    for i in range(2):
        faces.append({'id': i, 'points': [[i, 0, 0], [i, 1, 0], [i + 1, 1, 0], [i + 1, 0, 0]],
                      'normal': [0, 0, -1], 'area': 1, 'alpha': False, 'physical_material': 'wood'})
    images = {'train': {'max_pixels': [0, 0], 'max_fraction': [0, 0]},
              'heldout': {'max_pixels': [0, 5], 'max_fraction': [0, .2]}}
    rays = {'faces': [{'id': i, 'max_exposure': 0, 'pair_coverage': 1} for i in range(2)]}
    voxels = {'minimum_enclosure': [0, 0], 'unstable': [False, False]}
    return faces, images, rays, voxels


class HybridTests(unittest.TestCase):
    def test_label_polarity(self):
        self.assertEqual(cut(np.array([.9, .1]), [], 0).tolist(), [True, False])

    def test_boundary_material_and_normal(self):
        faces, *_ = fixture()
        self.assertEqual(len(adjacency(faces, DEFAULTS)), 1)
        faces[1]['physical_material'] = 'stone'
        self.assertEqual(adjacency(faces, DEFAULTS), [])
        faces[1]['physical_material'] = 'wood'
        faces[1]['normal'] = [0, 0, 1]
        self.assertEqual(adjacency(faces, DEFAULTS), [])

    def test_alpha_protected_even_with_extreme_smoothing(self):
        data = fixture(); data[0][1]['alpha'] = True
        self.assertNotIn(1, classify(*data, {'graph_lambda': 1000})['candidate_ids'])

    def test_exposed_and_override_protected(self):
        data = fixture()
        data[1]['train']['max_pixels'][1] = 8
        data[1]['train']['max_fraction'][1] = .5
        self.assertEqual(classify(*data, keep_ids=[0])['candidate_ids'], [])

    def test_heldout_never_changes_training_mask(self):
        data = fixture()
        r = classify(*data)
        self.assertEqual(r['candidate_ids'], [0, 1])
        self.assertEqual(r['heldout_exposed_ids'], [1])
        data[1]['heldout']['max_pixels'] = [0, 0]
        self.assertEqual(classify(*data)['candidate_ids'], r['candidate_ids'])

    def test_preserves_inputs(self):
        data = fixture(); before = copy.deepcopy(data)
        classify(*data)
        self.assertEqual(data, before)

    def test_wrong_id_order_rejected(self):
        data = fixture(); data[2]['faces'].reverse()
        with self.assertRaises(ValueError): classify(*data)

    def test_nonfinite_evidence_rejected(self):
        data = fixture(); data[1]['train']['max_pixels'][0] = float('nan')
        with self.assertRaises(ValueError): classify(*data)

    def test_malformed_evidence_rejected(self):
        data = fixture(); data[3]['unstable'].pop()
        with self.assertRaises(ValueError): classify(*data)

    def test_degenerate_normal_rejected(self):
        data = fixture(); data[0][0]['normal'] = [0, 0, 0]
        with self.assertRaises(ValueError): classify(*data)


if __name__ == '__main__':
    unittest.main()
