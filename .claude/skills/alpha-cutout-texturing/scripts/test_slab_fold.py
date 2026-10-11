"""Fixtures for slab_fold.py: a synthetic 2 m slab (top, back, underside, a three-facet rounded nose, two end caps) on a
512 page at 100 px/m. A page painted through the folded coordinates passes the seam QA; the same painting with the end
caps and back in their own frames (the Korean Market stall thatch before 2026-10-11) fails it.

    python -m unittest test_slab_fold -v        (from this folder)
"""
import unittest
import numpy as np
from slab_fold import Slab, seam_qa

W, PXM, N = 2.0, 100.0, 512
OUT = [(0., 0.), (1., 0.), (1., -.1), (-.01, -.1), (-.035, -.07), (-.035, -.03)]       # lip -> top -> back -> under -> nose


def p3(u, s, t):
    return np.array([u, s, t], float)                                                 # c0 = 0, U = x, Vv = y, nt = z


def synthetic_profile():
    n = len(OUT); cum = [0.]
    for i in range(1, n + 1):
        cum.append(cum[-1] + float(np.hypot(*(np.array(OUT[i % n]) - OUT[i - 1]))))
    kinds = ['top', 'back', 'under', 'nose', 'nose', 'nose']; faces = []; y0 = 10.
    cen = np.mean(OUT, axis=0)
    for i in range(n):                                                                # side faces: u across, segment down the page
        A_, B_ = np.array(OUT[i]), np.array(OUT[(i + 1) % n]); L = float(np.linalg.norm(B_ - A_))
        corners = [(0, A_), (W, A_), (W, B_), (0, B_)]
        px = [(10 + u * PXM, y0 + (0 if k < 2 else L * PXM)) for k, (u, _) in enumerate(corners)]
        X3 = [p3(u, q[0], q[1]) for u, q in corners]
        T, *_ = np.linalg.lstsq(np.c_[np.array(px), np.ones(4)], np.array(X3), rcond=None)
        d = (B_ - A_) / L; nn = np.array([d[1], -d[0]])
        if nn @ ((A_ + B_) / 2 - cen) < 0:
            nn = -nn
        faces.append({'face': i, 'kind': kinds[i], 'normal': [0., float(nn[0]), float(nn[1])], 'uv_px': px, 'px_to_3d': T.tolist(),
                      'slab': [[u, float(q[0]), float(q[1])] for u, q in corners]})
        y0 += L * PXM + 8
    for j, u in enumerate((0., W)):                                                   # end caps
        px = [(250 + (s + .04) * PXM, 10 + j * 30 + (-t) * PXM) for s, t in OUT]; X3 = [p3(u, s, t) for s, t in OUT]
        T, *_ = np.linalg.lstsq(np.c_[np.array(px), np.ones(n)], np.array(X3), rcond=None)
        faces.append({'face': n + j, 'kind': 'end', 'normal': [-1. if j == 0 else 1., 0., 0.], 'uv_px': px, 'px_to_3d': T.tolist(),
                      'slab': [[u, s, t] for s, t in OUT]})
    shared = []
    for k in range(n):                                                                # side | side along the eave
        s, t = OUT[k]; shared.append({'faces': [(k - 1) % n, k], 'a': list(p3(0, s, t)), 'b': list(p3(W, s, t))})
    for i in range(n):                                                                # side | cap
        A_, B_ = OUT[i], OUT[(i + 1) % n]
        for j, u in enumerate((0., W)):
            shared.append({'faces': [n + j, i], 'a': list(p3(u, *A_)), 'b': list(p3(u, *B_))})
    return {'size': N, 'c0': [0, 0, 0], 'U': [1, 0, 0], 'Vv': [0, 1, 0], 'nt': [0, 0, 1], 'u0': 0., 'u_len': W,
            'outline_st': [list(q) for q in OUT], 'outline_cum': cum, 'faces': faces, 'shared_edges': shared}


def material(us, v):
    """a smooth straw-like field (strands along v), deterministic"""
    rng = np.random.default_rng(3); out = []
    for c in range(3):
        f = np.zeros_like(us)
        for _ in range(6):
            ku, kv, ph = rng.uniform(8, 30), rng.uniform(1, 6), rng.uniform(0, 6.3)
            f += np.sin(ku * us + kv * v + ph)
        out.append(.5 + .07 * f)
    return np.clip(np.stack(out, -1), 0, 1)


def paint(slab, own_frames=False):
    bc = np.zeros((N, N, 4), np.float32)
    for f in slab.pm['faces']:
        yy, xx = slab.texels(f, 3); c = slab.face_coords(f, yy, xx); us, v = c['us'], c['v']
        if own_frames and f['kind'] in ('end', 'back'):                               # the old compose: each face its own frame
            us, v = (c['s'] + .37 * W, -c['t']) if f['kind'] == 'end' else (c['u'] + .5, -c['t'])
        bc[yy, xx, :3] = material(us, v); bc[yy, xx, 3] = 1
    return bc


class SlabFoldTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.S = Slab(synthetic_profile())

    def test_segment_kinds_and_round_nose_v(self):
        S = self.S
        self.assertEqual(S.seg_kind, ['top', 'back', 'under', 'nose', 'nose', 'nose'])
        self.assertTrue(S.VK[3] < S.VK[4] < S.VK[5] < S.VK[0] + 1e-12, S.VK)     # monotone round the nose
        self.assertAlmostEqual(S.VK[1], 1.0); self.assertAlmostEqual(S.VK[2], 1.0)

    def test_coordinates_continuous_on_every_shared_edge(self):
        S = self.S
        for e in S.pm['shared_edges']:
            A3, B3 = np.array(e['a']), np.array(e['b']); P3 = A3 + np.linspace(.1, .9, 9)[:, None] * (B3 - A3)
            got = []
            for fid in e['faces']:
                px = S.px_of(fid, P3); c = S.face_coords(S.F[fid], px[:, 1] - .5, px[:, 0] - .5)
                got.append(np.c_[c['us'], c['v']])
            self.assertLess(np.abs(got[0] - got[1]).max(), 1e-6, e['faces'])

    def test_end_caps_carry_the_top_straight_down(self):
        S = self.S; X3 = np.array([[0, .5, -.02], [0, .5, -.08], [W, .5, -.05]])
        c = S.coords_3d(X3)
        np.testing.assert_allclose(c['us'], [.02, .08, W - .05], atol=1e-9)          # depth inward, no mid-thickness mirror
        np.testing.assert_allclose(c['v'], [.5, .5, .5], atol=1e-9)

    def test_seam_qa_passes_folded_page(self):
        R = seam_qa(self.S, paint(self.S))
        self.assertTrue(R['pass'], (R['mean_ratio'], R['worst_ratio']))

    def test_seam_qa_fails_per_face_frames(self):
        R = seam_qa(self.S, paint(self.S, own_frames=True))
        self.assertFalse(R['pass'], (R['mean_ratio'], R['worst_ratio']))


if __name__ == '__main__':
    unittest.main()
