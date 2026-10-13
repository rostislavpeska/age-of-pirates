"""Audit: 2026-10-13-codex-roof-civic-readers-01; fixed-page regression."""
import unittest
import copy
import hashlib
from pathlib import Path
import tempfile
import numpy as np
from alpha_reader_gate import measure, triangle_cells


def constant_contour(lateral, first, pitch, thickness):
    return .1


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


class CertificateTests(unittest.TestCase):
    """Audit 2026-10-13-codex-market-certificate-01; deliberately independent inputs."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        source = Path(self.temp.name) / 'source.bin'
        source.write_bytes(b'current source identity')
        paths = dict(mesh=source, frame=source, page=source, contour=Path(__file__))
        uv = np.array([[1, 1], [1.5, 1], [1, 2.5]]) / 4
        co = [[0, 0, -.01], [0, .01, -.01], [0, 0, -.02]]
        frame = dict(axis=0, top=[[-1, 0, 0], [1, 0, 0]],
                     bottom=[[-1, 0, 1], [1, 0, 1]], first=0, pitch=.1)
        self.current = dict(page='matc', source_paths=paths, contour=constant_contour,
            triangles=[dict(reader='tiny', triangle_id='mesh:7', co=co, uv=uv, frame=frame)])
        self.cert = dict(schema='constant-station-opaque-v1', page='matc', size=[4, 4],
            reader='tiny', triangle_id='mesh:7', co=co, uv=uv.tolist(),
            source_hashes={key: hashlib.sha256(path.read_bytes()).hexdigest() for key, path in paths.items()},
            cells_yx=[[1, 1], [2, 1]])
        self.data = dict(pixel=np.empty((0, 2), int), expected=np.empty(0, bool),
                         interior=np.empty(0, bool), reader=np.empty(0, str),
                         inventory=np.array(['tiny']), size=np.array([4, 4]))

    def run_gate(self, **kwargs):
        return measure(self.data, certificates=[self.cert], certificate_inputs=self.current, **kwargs)

    def test_whole_triangle_bound_does_not_forge_samples(self):
        r = self.run_gate(fixed_alpha=np.full((4, 4), 255))
        self.assertEqual(r['status'], 'PASS')
        self.assertEqual(r['samples'], 0)
        self.assertEqual(r['interior_samples'], 0)
        self.assertEqual(r['certified_readers'], 1)
        self.assertEqual(r['certificate_cell_constraints'], 2)
        self.assertEqual(r['per_reader'][0]['samples'], 0)

    def test_missing_certificate_and_independent_inputs_fail(self):
        with self.assertRaises(ValueError): measure(self.data)
        with self.assertRaises(ValueError): measure(self.data, certificates=[self.cert])

    def test_duplicate_certificate_fails(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            measure(self.data, certificates=[self.cert, self.cert], certificate_inputs=self.current)

    def test_wrong_identities_fail(self):
        for key, value in [('reader', 'wrong'), ('triangle_id', 'mesh:8'), ('page', 'other'),
                           ('size', [8, 8]), ('schema', 'PASS'), ('source_hashes', {})]:
            with self.subTest(key=key):
                bad = dict(self.cert, **{key: value})
                with self.assertRaises(ValueError):
                    measure(self.data, certificates=[bad], certificate_inputs=self.current)

    def test_wrong_triangle_uv_and_coverage_fail(self):
        for key in ['co', 'uv', 'cells_yx']:
            with self.subTest(key=key):
                bad = copy.deepcopy(self.cert)
                bad[key][0][0] += .01
                with self.assertRaises(ValueError):
                    measure(self.data, certificates=[bad], certificate_inputs=self.current)
        self.cert['cells_yx'].pop()
        with self.assertRaises(ValueError): self.run_gate()

    def test_changed_source_rejects_stale_certificate(self):
        self.current['source_paths']['mesh'].write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'stale'): self.run_gate()

    def test_all_missing_reader_triangles_required(self):
        row = dict(self.current['triangles'][0], triangle_id='mesh:8')
        self.current['triangles'].append(row)
        with self.assertRaisesRegex(ValueError, 'Missing certificate'): self.run_gate()

    def test_varying_frame_and_failed_affine_bound_reject(self):
        self.current['triangles'][0]['co'][0][0] = .01
        with self.assertRaisesRegex(ValueError, 'constant-station'): self.run_gate()
        self.current['triangles'][0]['co'][0][0] = 0
        for point in self.current['triangles'][0]['co']:
            point[2] = .2
        with self.assertRaisesRegex(ValueError, 'bound failed'): self.run_gate()

    def test_arbitrary_pass_string_cannot_replace_bound(self):
        self.cert['status'] = 'PASS'
        for point in self.current['triangles'][0]['co']:
            point[2] = .2
        with self.assertRaisesRegex(ValueError, 'bound failed'): self.run_gate()

    def test_existing_and_certificate_shared_conflicts_survive(self):
        self.data.update(pixel=np.array([[2, 1], [0, 0], [0, 0]]),
            expected=np.array([False, True, False]), interior=np.ones(3, bool),
            reader=np.array(['cut', 'front', 'back']),
            inventory=np.array(['tiny', 'cut', 'front', 'back']))
        r = self.run_gate(fixed_alpha=np.full((4, 4), 255))
        self.assertEqual(r['status'], 'FAIL')
        self.assertEqual(r['conflicting_texels'], 2)
        self.assertEqual(r['fixed_alpha_mismatch'], 2)
        self.assertEqual(r['samples'], 3)
        self.assertEqual(r['certificate_witnesses'][0]['cut_samples'], [0])
        self.assertEqual(r['conflict_witnesses'][0]['opaque_reader'], 'front')

    def test_actual_alpha_and_fixed_page_enforced_separately(self):
        alpha = np.full((4, 4), 255); alpha[2, 1] = 0
        for key in ['alpha', 'fixed_alpha']:
            r = self.run_gate(**{key: alpha})
            self.assertEqual(r['status'], 'FAIL')
            self.assertEqual(len(r['certificate_witnesses']), 1)

    def test_degenerate_outside_and_centre_triangles_rejected(self):
        for uv in [np.zeros((3, 2)), [[0, 0], [1, 0], [0, 1]],
                   [[-1, 0], [0, 0], [0, 1]]]:
            with self.assertRaises(ValueError): triangle_cells(uv, (4, 4))


if __name__ == '__main__': unittest.main()
