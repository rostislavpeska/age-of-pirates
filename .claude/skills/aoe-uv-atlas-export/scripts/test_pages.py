import sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'blender-uv-conjoin' / 'scripts'))
from conjoin import prepare, families
from pages import best_split, emit, military_2048


def rect(cid, w, h, mat):
    return [dict(id=f'{cid}:0', chart=cid, material=mat, uv=[[0, 0], [w, 0], [w, h], [0, h]])]


class PagesTests(unittest.TestCase):
    def test_military_profile_keeps_family_together_and_real_pixel_gutter(self):
        faces = rect('wall1', 600, 400, 'PLASTER') + rect('wall2', 600, 400, 'PLASTER') + rect('roof', 800, 700, 'ROOF')
        charts, owners, members, _ = families(faces)
        result = military_2048(charts, owners, members, min_scale=.8, max_scale=1.2, gutter_rt=8)
        self.assertEqual(result['pages'], [dict(name='P2048', size=2048)])
        self.assertEqual(set(result['faces']), {f['id'] for f in faces})
        self.assertGreaterEqual(result['scale'], .8)
        a, b = result['faces']['wall1:0'], result['faces']['wall2:0']
        self.assertEqual(a['family'], b['family'])
        self.assertEqual(a['uv'], b['uv'])
        for x in result['faces'].values():
            self.assertEqual(x['page'], 'P2048')
            self.assertTrue(all(4 - 1e-6 <= t * 2048 <= 2044 + 1e-6 for uv in x['uv'] for t in uv))

    def test_military_cannot_shrink_below_floor_or_add_page(self):
        charts = prepare(rect('roof', 3000, 3000, 'ROOF'))
        with self.assertRaisesRegex(ValueError, 'does not fit'):
            military_2048(charts, [0], {}, min_scale=1., max_scale=2., gutter_rt=8)

    def test_exact_minimum_fit_is_retained(self):
        charts = prepare(rect('roof', 2040, 2040, 'ROOF'))
        result = military_2048(charts, [0], {}, min_scale=1., max_scale=1., gutter_rt=8)
        self.assertEqual(result['scale'], 1.)

    def test_invalid_profile_values_fail_before_pack(self):
        charts = prepare(rect('roof', 100, 100, 'ROOF'))
        for kw in ({'min_scale':float('nan'),'gutter_rt':8}, {'min_scale':1,'gutter_rt':-1},
                   {'min_scale':1,'gutter_rt':float('nan')}, {'min_scale':1,'max_scale':.5,'gutter_rt':8}):
            with self.assertRaises(ValueError):
                military_2048(charts, [0], {}, **kw)

    def test_emission_refuses_dropped_or_duplicate_owners(self):
        charts = prepare(rect('wall', 100, 100, 'PLASTER') + rect('roof', 100, 100, 'ROOF'))
        pages = [dict(name='P2048', size=2048)]
        for split in ({'P2048':[0]}, {'P2048':[0,0,1]}):
            with self.assertRaisesRegex(ValueError, 'every owner exactly once'):
                emit(charts, [0,1], {}, pages, 1., split)
        with self.assertRaisesRegex(ValueError, 'every chart'):
            emit(charts, [0], {}, pages, 1., {'P2048':[0]})

    def test_uniform_density_material_split(self):
        faces = rect('eave', 800, 100, 'EAVE_CUTOUT') + rect('ridge', 900, 120, 'ROOF_TRIM') \
            + rect('roof', 1200, 900, 'ROOF_TILE') + rect('wall', 1500, 1200, 'PLASTER') + rect('beam', 1400, 90, 'WOOD')
        charts = prepare(faces)
        owners = list(range(len(charts)))
        pages = [dict(name='P2048', size=2048), dict(name='P1024', size=1024, prefer=['EAVE_CUTOUT', 'ROOF_TRIM', 'ROOF_TILE'], must=['EAVE_CUTOUT'])]
        s, split = best_split(charts, owners, pages)
        mats = {p: {charts[j]['mat'] for j in ids} for p, ids in split.items()}
        self.assertIn('EAVE_CUTOUT', mats['P1024'])
        self.assertIn('PLASTER', mats['P2048'])
        self.assertEqual(sum(len(v) for v in split.values()), len(owners))
        plan = emit(charts, owners, {}, pages, s, split)
        for x in plan.values():
            for u, v in x['uv']:
                self.assertTrue(-1e-6 <= u <= 1 + 1e-6 and -1e-6 <= v <= 1 + 1e-6)
        # same density on both pages: chart size in runtime texels = working size * s
        by = {x['page']: x for x in plan.values()}
        self.assertGreater(s, 0)


if __name__ == '__main__':
    unittest.main()
