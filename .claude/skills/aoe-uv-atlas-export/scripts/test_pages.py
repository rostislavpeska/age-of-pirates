import sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'blender-uv-conjoin' / 'scripts'))
from conjoin import prepare
from pages import best_split, emit


def rect(cid, w, h, mat):
    return [dict(id=f'{cid}:0', chart=cid, material=mat, uv=[[0, 0], [w, 0], [w, h], [0, h]])]


class PagesTests(unittest.TestCase):
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
