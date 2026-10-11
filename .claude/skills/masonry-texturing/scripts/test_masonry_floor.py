"""Synthetic controls for masonry_floor.py: a tiled stone source with a drawn grid fails; per-stone masonry passes."""
import json, os, sys, tempfile, unittest
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import masonry_floor as mf

N = 512


def page(kind, seed=3):
    rng = np.random.default_rng(seed); yy, xx = np.mgrid[0:N, 0:N]
    if kind == 'tiled':                                             # one 32 px speckle tile repeated + a regular grid
        tile = rng.uniform(.45, .6, (32, 32)); L = np.tile(tile, (N // 32, N // 32))
        L[(yy % 64) < 2] = .25; L[((xx + (yy // 64 % 2) * 32) % 96) < 2] = .25
    else:                                                           # stones with their own tone, irregular lengths
        L = np.zeros((N, N)); row = yy // 60
        for r in range(N // 60 + 1):
            edges = np.cumsum(rng.uniform(70, 150, 12)) - rng.uniform(0, 70)
            k = np.searchsorted(edges, xx[row == r]); L[row == r] = .35 + .3 * rng.uniform(size=len(edges) + 1)[k]
        L += rng.normal(0, .02, L.shape); L[(yy % 60) < 2] = .2
        for r in range(N // 60 + 1):
            pass
    img = np.clip(np.dstack([L] * 3) * 255, 0, 255).astype(np.uint8)
    return img


class Floor(unittest.TestCase):
    def run_kind(self, kind):
        d = tempfile.mkdtemp(); p = os.path.join(d, 'page.png'); f = os.path.join(d, 'faces.json')
        Image.fromarray(page(kind)).save(p)
        json.dump({'faces': [{'group': 'wall', 'page': 0, 'uv_px': [[16, 16], [496, 16], [496, 496], [16, 496]]}]}, open(f, 'w'))
        return mf.main([p, f, '--json', os.path.join(d, 'out.json')]), json.load(open(os.path.join(d, 'out.json')))

    def test_tiled_source_fails(self):
        rc, out = self.run_kind('tiled')
        self.assertEqual(rc, 1); self.assertIn('tile_repeat', out['groups']['wall']['fails'])

    def test_per_stone_passes(self):
        rc, out = self.run_kind('stones')
        self.assertEqual(rc, 0, out)


if __name__ == '__main__':
    unittest.main()
