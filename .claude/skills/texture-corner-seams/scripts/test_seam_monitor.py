"""Fixtures for seam_monitor.py on a synthetic 256 page: a box-section beam (two faces meeting at a 90 degree corner, split
in UV). Same paint on both faces = ok; one face 25 % darker = tone (and the edit fixes it without touching anything
else); unrelated stripes = pattern (never edited); a family texel shared beyond its seam group is never edited.

    python -m unittest test_seam_monitor -v        (from this folder)
"""
import unittest
import numpy as np
from seam_monitor import Seams

N = 256


def inventory(shared_extra=False):
    # face A: x 20..120, y 20..60 (edge along y = 60); face B: x 20..120, y 80..120 (edge along y = 80). One 3D edge.
    A = [[20, 20], [120, 20], [120, 60], [20, 60]]; Bf = [[20, 80], [120, 80], [120, 120], [20, 120]]
    faces = [{'obj': 'Beam', 'face': 0, 'page': 0, 'role': 0, 'px': A}, {'obj': 'Beam', 'face': 1, 'page': 0, 'role': 0, 'px': Bf}]
    if shared_extra:                                                                      # an unrelated face reusing face A's texels
        faces.append({'obj': 'Other', 'face': 0, 'page': 0, 'role': 2, 'px': A})
    seam = {'obj': 'Beam', 'faces': [0, 1], 'pages': [0, 0], 'roles': [0, 0], 'subtypes': [3, 3], 'materials': [0, 0],
            'p3': [[0, 0, 0], [1, 0, 0]], 'len_m': 1.0, 'dihedral_deg': 90.0,
            'uv_a': [[20, 60], [120, 60]], 'uv_b': [[20, 80], [120, 80]], 'cen_a': [70, 40], 'cen_b': [70, 100], 'normals': [[0, 0, 1], [0, 1, 0]]}
    return {'pages': {'0': N}, 'faces': faces, 'seams': [seam]}


def page(kind):
    """face A rows 20..60 (distance to the edge = 60 - y), face B rows 80..120 (distance = y - 80): mirrored across the edge"""
    rng = np.random.default_rng(1); img = np.zeros((N, N, 4), np.float32); img[..., 3] = 1
    x = np.arange(N); grain = .5 + .06 * np.sin(x / 3.1)[None, :] + .02 * rng.standard_normal((1, N))
    for y in range(20, 60):
        img[y, :, :3] = grain[..., None] * np.array([1.1, .6, .4])
    for y in range(80, 120):
        g = grain if kind != 'pattern' else (.5 + .12 * np.sign(np.sin(x / 1.7)))[None, :]
        img[y, :, :3] = g[..., None] * np.array([1.1, .6, .4]) * (.75 if kind == 'tone' else 1.)
    return {0: img}


class SeamMonitorTest(unittest.TestCase):
    def measure(self, kind, shared=False):
        S = Seams(inventory(shared)); return S, S.measure(page(kind), S.inv['seams'][0])

    def test_matching_corner_is_ok(self):
        _, m = self.measure('same'); self.assertEqual(m['class'], 'ok', m)

    def test_darker_face_is_tone_and_edit_fixes_it(self):
        S, m = self.measure('tone'); self.assertEqual(m['class'], 'tone', m)
        pg = page('tone'); summ, rows = S.monitor(pg); new, touched, changed = S.edit(pg, rows)
        m2 = S.measure(new, S.inv['seams'][0]); self.assertLess(m2['across'], .5 * m['across'], (m, m2))
        d = np.abs(new[0] - pg[0]).max(-1); ys, xs = np.nonzero(d > 1e-6)
        self.assertTrue(len(ys) > 0)
        self.assertTrue(((ys >= 52) & (ys <= 63) | (ys >= 77) & (ys <= 88)).all(), (ys.min(), ys.max()))   # bands only

    def test_unrelated_structure_is_pattern_and_not_edited(self):
        S, m = self.measure('pattern'); self.assertEqual(m['class'], 'pattern', m)
        pg = page('pattern'); summ, rows = S.monitor(pg); new, touched, changed = S.edit(pg, rows)
        self.assertEqual(touched, []); self.assertEqual(changed[0], 0)

    def test_texel_shared_beyond_its_seam_group_is_never_edited(self):
        S, m = self.measure('tone', shared=True)
        pg = page('tone'); summ, rows = S.monitor(pg); new, touched, changed = S.edit(pg, rows)
        self.assertTrue((np.abs(new[0][20:60] - pg[0][20:60]) < 1e-6).all())                          # face A untouched
        self.assertTrue((np.abs(new[0][80:120] - pg[0][80:120]).max() > 0))                             # face B still pulled

    def test_subtype_filter_and_boundary(self):
        S = Seams(inventory()); pg = page('tone'); summ, rows = S.monitor(pg)
        new, touched, changed = S.edit(pg, rows, subtypes={7}); self.assertEqual(touched, [])
        inv = inventory(); inv['seams'][0]['subtypes'] = [3, 9]; S2 = Seams(inv)
        self.assertEqual(S2.measure(pg, inv['seams'][0])['class'], 'boundary')


if __name__ == '__main__':
    unittest.main()
