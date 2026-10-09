"""python -m pytest .claude/skills/masonry-texturing/scripts -q"""
import importlib.util
import unittest
from pathlib import Path

import numpy as np

spec = importlib.util.spec_from_file_location('paint_relief', Path(__file__).with_name('paint_relief.py'))
R = importlib.util.module_from_spec(spec); spec.loader.exec_module(R)
PPM, TEX = 800., 1 / 100.                                     # painting 800 px/m, page 100 texels/m (8 px per texel)


def grain(n=240, period_px=24, contrast=.1, seed=0):
    """vertical boards: dark grain streaks every period_px columns, running down the rows, plus fine speckle"""
    rng = np.random.default_rng(seed); x = np.arange(n)
    L = .4 + contrast * np.cos(2 * np.pi * x / period_px)[None, :] * np.ones((n, 1))
    return np.clip(L + rng.normal(0, .01, (n, n)), 0, 1)


class PaintRelief(unittest.TestCase):
    def test_dark_is_low(self):
        h, _ = R.detail_height(grain(), PPM, TEX, bands=((3., .001),), grain_axis=0)
        x = np.arange(240); dark = np.cos(2 * np.pi * x / 24) < -.9; bright = np.cos(2 * np.pi * x / 24) > .9
        self.assertLess(h[60:180, 60:180][:, dark[60:180]].mean(), -.0005)
        self.assertGreater(h[60:180, 60:180][:, bright[60:180]].mean(), .0005)

    def test_normalize_makes_pale_painting_as_pronounced(self):
        strong, weak = grain(contrast=.1), grain(contrast=.02)
        hs, _ = R.detail_height(strong, PPM, TEX, bands=((3., .001),), normalize=1.)
        hw, _ = R.detail_height(weak, PPM, TEX, bands=((3., .001),), normalize=1.)
        ratio = hw[40:200, 40:200].std() / hs[40:200, 40:200].std()
        self.assertGreater(ratio, .8)                             # normalised: depth independent of contrast
        hs0, _ = R.detail_height(strong, PPM, TEX, bands=((3., .001),), normalize=0.)
        hw0, _ = R.detail_height(weak, PPM, TEX, bands=((3., .001),), normalize=0.)
        self.assertLess(hw0[40:200, 40:200].std() / hs0[40:200, 40:200].std(), .35)   # absolute: follows the painting

    def test_sub_texel_speckle_is_dropped(self):
        rng = np.random.default_rng(3); speck = .4 + .1 * rng.choice([-1, 1], (240, 240))   # 1-px noise = 1/8 texel
        h, _ = R.detail_height(speck, PPM, TEX, bands=((3., .001),), normalize=0.)
        hg, _ = R.detail_height(grain(), PPM, TEX, bands=((3., .001),), normalize=0.)
        self.assertLess(h.std(), .35 * hg.std())

    def test_mask_no_leak_from_dark_neighbour(self):
        L = np.full((200, 200), .45); L[:, 100:] = .08                 # wood left, black iron band right
        m = np.zeros((200, 200)); m[:, :100] = 1
        h, _ = R.detail_height(L, PPM, TEX, mask=m, bands=((3., .001), (8., .001)), normalize=.7)
        self.assertEqual(float(np.abs(h[:, 100:]).max()), 0.)
        self.assertLess(float(np.abs(h[:, 80:100]).max()), 1e-4)     # no ridge or groove along the boundary

    def test_normal_points_up_a_slope(self):
        h = np.tile(np.linspace(0, .2, 50)[:, None][::-1], (1, 50))    # 0.2 m over 0.5 m, higher towards the top row (+v)
        n = R.normal_from_height(h, 100.)
        self.assertLess(n[25, 25, 1], -.1)                               # surface rises with +v: normal tilts to -v
        self.assertAlmostEqual(float(np.linalg.norm(n[25, 25])), 1., places=6)


if __name__ == '__main__':
    unittest.main()
