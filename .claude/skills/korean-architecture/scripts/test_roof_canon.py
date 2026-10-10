"""Canonical roof features must mean the same thing on the TC and on any target page (owner 2026-10-10: "The Town
center last version must be canonical reference ... each copy is worse and worse")."""
import unittest
import numpy as np
from roof_canon import components, across, match_slopes, profile, gate, transfer_field


def grid(cells=4, size=12, down='y'):
    """synthetic tile page: cells x cells tiles, one R value each; f runs 0..1 down-slope inside each tile."""
    n = cells * size; yy, xx = np.mgrid[0:n, 0:n]
    r = ((yy // size) * cells + (xx // size) + 1) / 100.
    along = (yy if down == 'y' else xx) % size
    f = along / (size - 1.)
    return r.astype(np.float32), f.astype(np.float32), np.ones((n, n), bool)


class ComponentTests(unittest.TestCase):
    def test_one_component_per_tile_and_every_texel_kept(self):
        r, f, m = grid()
        lab, d, n = components(r, m)
        self.assertEqual(n, 16)
        self.assertTrue((lab > 0).all())                     # boundary texels attach to a tile, none dropped
        self.assertAlmostEqual(float(d.max()), 1.0, places=5)

    def test_across_is_perpendicular_to_down_slope(self):
        r, f, m = grid(down='y')
        lab, _, n = components(r, m); a = across(lab, f, n)
        cell = a[12:24, 12:24]
        self.assertLess(float(np.ptp(cell[:, 5])), .05)       # constant along the slope (column)
        self.assertGreater(float(np.ptp(cell[5, :])), .9)     # spans 0..1 across it (row)

    def test_across_does_not_depend_on_page_orientation(self):
        r, f, m = grid(down='y')
        lab, _, n = components(r, m); a = across(lab, f, n)
        r2, f2, m2 = grid(down='x')
        lab2, _, n2 = components(r2, m2); a2 = across(lab2, f2, n2)
        c1 = a[12:24, 12:24][5, :]; c2 = a2[12:24, 12:24][:, 5]
        sym = lambda v: np.minimum(v, 1 - v)                  # left/right symmetric by design
        np.testing.assert_allclose(np.sort(sym(c1)), np.sort(sym(c2)), atol=.02)


class SlopeTests(unittest.TestCase):
    def test_match_slopes_hits_canon_quantiles(self):
        rng = np.random.default_rng(1); th = np.radians(rng.uniform(0, 15, (64, 64))); az = rng.uniform(0, 2 * np.pi, th.shape)
        v = np.stack([np.sin(th) * np.cos(az), np.sin(th) * np.sin(az), np.cos(th)], -1)
        q = [0, 10, 21.7, 42.7, 50.2]
        out = match_slopes(v * .5 + .5, np.ones(th.shape, bool), q)
        o = out * 2 - 1; s = np.degrees(np.arcsin(np.clip(np.hypot(o[..., 0], o[..., 1]), 0, 1)))
        np.testing.assert_allclose(np.percentile(s, [0, 25, 50, 75, 100]), q, atol=1.)
        t = s > .5                                            # azimuth kept wherever the texel stays tilted
        np.testing.assert_allclose(np.arctan2(o[..., 1], o[..., 0])[t], np.arctan2(v[..., 1], v[..., 0])[t], atol=1e-4)


class GateTests(unittest.TestCase):
    def setUp(self):
        rng = np.random.default_rng(3); n = 20000
        self.roll = (rng.random(n) > .5).astype(float); self.f = rng.random(n); self.d = rng.random(n)
        self.rgb = np.clip(.05 + .03 * self.roll[:, None] + rng.normal(0, .01, (n, 3)), 0, 1)
        self.canon = profile(self.rgb, self.roll, self.f, self.d, rng.uniform(0, 50, n))

    def test_identical_profile_passes(self):
        ok, fails = gate(self.canon, self.canon)
        self.assertTrue(ok, fails)

    def test_darker_field_fails_per_bin(self):
        t = profile(self.rgb * .6, self.roll, self.f, self.d, None)
        ok, fails = gate(t, self.canon)
        self.assertFalse(ok); self.assertTrue(any(x.startswith('bin ') for x in fails))

    def test_flat_slopes_fail(self):
        t = profile(self.rgb, self.roll, self.f, self.d, np.full(len(self.f), 3.))
        ok, fails = gate(t, self.canon)
        self.assertFalse(ok); self.assertTrue(any(x.startswith('slope') for x in fails))

    def test_ratio_ignores_roll_pan_area_mix(self):
        keep = (self.roll > .5) | (np.arange(len(self.roll)) % 4 == 0)       # 4x fewer pan texels, same look
        t = profile(self.rgb[keep], self.roll[keep], self.f[keep], self.d[keep], None)
        self.assertAlmostEqual(t['global']['roll_pan_ratio'], self.canon['global']['roll_pan_ratio'], delta=.02)


class TransferTests(unittest.TestCase):
    def test_roll_targets_take_roll_texels(self):
        rng = np.random.default_rng(5); ncomp = 40; per = 60
        comp = np.repeat(np.arange(1, ncomp + 1), per); roll = np.repeat((np.arange(ncomp) % 2).astype(float), per)
        rgb = np.where(roll[:, None] > .5, [.2, .1, .05], [.05, .05, .05]).astype(np.float32)
        ex = dict(comp=comp, comp_n=np.bincount(comp), comp_full=np.r_[False, np.ones(ncomp, bool)],
                  comp_roll=np.r_[0., (np.arange(ncomp) % 2).astype(float)], comp_green=np.zeros(ncomp + 1),
                  comp_lum=np.zeros(ncomp + 1), f=rng.random(len(comp)), d=rng.random(len(comp)), rgb=rgb,
                  rough=np.full(len(comp), .8, np.float32))
        lab = np.repeat([1, 2], 30); troll = np.repeat([1., 0.], 30)
        out, rough = transfer_field(ex, lab, rng.random(60), troll, rng.random(60), np.full(60, .5), knn=3)
        np.testing.assert_allclose(out[:30], [[.2, .1, .05]] * 30, atol=1e-6)
        np.testing.assert_allclose(out[30:], [[.05, .05, .05]] * 30, atol=1e-6)


if __name__ == '__main__':
    unittest.main()
