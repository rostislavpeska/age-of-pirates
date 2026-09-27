import unittest
from conjoin import conjoin, PRESETS
from pack_rects import measure


def rect(cid, w, h, mat='WOOD', x0=0., y0=0., protect=False, nx=1):
    faces = []
    for i in range(nx):
        a, b = x0 + w * i / nx, x0 + w * (i + 1) / nx
        faces.append(dict(id=f'{cid}:{i}', chart=cid, material=mat, protect=protect,
                          uv=[[a, y0], [b, y0], [b, y0 + h], [a, y0 + h]]))
    return faces


class ConjoinTests(unittest.TestCase):
    def test_identical_charts_share_one_owner_regardless_of_tessellation(self):
        f = rect('a', 300, 100) + rect('b', 300, 100, x0=900, nx=3) + rect('c', 100, 300, y0=500)
        plan, st = conjoin(f, *PRESETS['T1'])
        self.assertEqual(st['owners'], 1)
        self.assertEqual(len({x['family'] for x in plan.values()}), 1)

    def test_material_never_merges(self):
        f = rect('a', 300, 100, 'WOOD') + rect('b', 300, 100, 'STONE', x0=900)
        self.assertEqual(conjoin(f, *PRESETS['T3'])[1]['owners'], 2)

    def test_tolerance_boundary(self):
        f = rect('a', 300, 100) + rect('b', 240, 100, x0=900)     # 20 % shorter
        self.assertEqual(conjoin(f, *PRESETS['T1'])[1]['owners'], 2)
        self.assertEqual(conjoin(f, *PRESETS['T2'])[1]['owners'], 1)

    def test_protected_chart_stays_unique(self):
        f = rect('a', 300, 100) + rect('b', 300, 100, x0=900, protect=True)
        self.assertEqual(conjoin(f, *PRESETS['T3'])[1]['owners'], 2)

    def test_members_land_inside_owner_and_page(self):
        f = rect('a', 300, 100) + rect('b', 280, 95, x0=900) + rect('c', 50, 50, x0=2000)
        plan, st = conjoin(f, *PRESETS['T3'])
        for x in plan.values():
            for u, v in x['uv']:
                self.assertTrue(-1e-9 <= u <= 1 + 1e-9 and -1e-9 <= v <= 1 + 1e-9)

    def test_packer_controls(self):
        sq = [[[[0, 0], [100, 0], [100, 100], [0, 100]]] for _ in range(16)]
        self.assertLessEqual(abs(measure(sq)['page_side_texels'] - 464.), 1.01)

    def test_frame_incident_hollow_frame_is_split_and_gated(self):
        # 2026-09-28: a whole timber frame kept as one hollow chart ate the page
        def ring(cid, x0):
            W, H, b = 600., 400., 40.
            q = [(0, 0, W, b), (0, H - b, W, H), (0, b, b, H - b), (W - b, b, W, H - b)]
            return [dict(id=f'{cid}:{i}', chart=cid, material='WOOD',
                         uv=[[x0 + a, c], [x0 + d, c], [x0 + d, e], [x0 + a, e]]) for i, (a, c, d, e) in enumerate(q)]
        faces = []
        for k in range(6):
            faces += ring(f'frame{k}', k * 1000.)
        _, bad = conjoin(faces, *PRESETS['T3'], split_hollow_charts=False)
        self.assertEqual(bad['audit']['verdict'], 'FAIL')
        _, good = conjoin(faces, *PRESETS['T3'])
        self.assertGreater(good['hollow_charts_split'], 0)
        self.assertGreater(bad['audit']['hollow_share'], .5)
        self.assertEqual(good['audit']['hollow_share'], 0.)

    def test_original_scale_keeps_owner_size(self):
        f = rect('a', 300, 100) + rect('b', 280, 95, x0=900)
        plan, st = conjoin(f, *PRESETS['T3'], page_texels=8192.)
        q = plan['a:0']['uv']
        self.assertAlmostEqual((q[1][0] - q[0][0]) * 8192., 300., places=3)


if __name__ == '__main__':
    unittest.main()
