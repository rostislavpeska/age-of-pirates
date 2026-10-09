"""Assembly gate regression (owner 2026-10-09: the roof bottom is baked with the field, never left out).
python test_assembly_scope.py   (pure Python)
The first case is the real failure: a roof-field pilot whose eave fronts/underlip sat on another page and whose caps
object was not a source - it baked, and the owner saw a roof without its bottom.
"""
import json
import tempfile
import unittest
from pathlib import Path

from assembly_scope import check

SPEC = {'name': 'roof', 'parts': {
    'field': {'materials': ['roof_field'], 'bake': 'high'},
    'front': {'materials': ['roof_end_receiver'], 'bake': 'high'},
    'underlip': {'materials': ['roof_underlip'], 'bake': 'high'},
    'caps': {'materials': ['clay_cap'], 'bake': 'high'},
    'soffit': {'materials': ['soffit_rafters'], 'bake': 'none', 'reason': 'no relief; assembly AO'}}}


def plan():
    f = {}
    for i in range(4):
        f[f'ROOF:{i}'] = {'owner': True, 'page': 'R0', 'material': 'roof_field'}
    for i in range(4, 6):
        f[f'ROOF:{i}'] = {'owner': True, 'page': 'R2', 'material': 'roof_end_receiver'}
    f['ROOF:6'] = {'owner': True, 'page': 'R2', 'material': 'roof_underlip'}
    f['ROOF:7'] = {'owner': False, 'page': 'R2', 'material': 'roof_underlip'}       # member: never a target
    f['ROOF:8'] = {'owner': True, 'page': 'R2', 'material': 'soffit_rafters'}
    f['CAP:0'] = {'owner': True, 'page': 'R0', 'material': 'clay_cap'}
    return f


def recipe(regions, assembly=SPEC, sources=('ROOF', 'CAP'), **kw):
    r = {'sources': {s: s for s in sources}, 'scope': {'mode': 'pilot', 'regions': [{'id': k, 'faces': v, 'highs': ['H']} for k, v in regions.items()]}}
    if assembly is not None:
        r['assembly'] = assembly
    r.update(kw)
    return r


FULL = {'field': ['ROOF:0', 'ROOF:1', 'ROOF:2', 'ROOF:3'], 'front': ['ROOF:4', 'ROOF:5'], 'underlip': ['ROOF:6'], 'caps': ['CAP:0']}


class AssemblyGate(unittest.TestCase):
    def test_field_only_pilot_fails(self):            # the 2026-10-09 failure
        r = check(recipe({'field': FULL['field']}, sources=('ROOF',)), plan())
        self.assertEqual(r['verdict'], 'FAIL')
        text = ' '.join(r['errors'])
        for part in ('front', 'underlip', 'caps'):
            self.assertIn(part, text)

    def test_roof_scope_without_assembly_fails(self):
        r = check(recipe(FULL, assembly=None), plan())
        self.assertEqual(r['verdict'], 'FAIL'); self.assertIn('without a declared assembly', r['errors'][0])

    def test_full_assembly_passes(self):
        r = check(recipe(FULL), plan())
        self.assertEqual(r['verdict'], 'PASS', r['errors'])
        self.assertEqual(r['parts']['underlip']['owner_faces'], 1)      # the member is not counted

    def test_bottom_page_left_out_fails(self):        # fronts on R2 dropped from the scope
        regions = dict(FULL); regions.pop('front')
        r = check(recipe(regions), plan())
        self.assertEqual(r['verdict'], 'FAIL'); self.assertTrue(any('front' in e and "'R2'" in e for e in r['errors']))

    def test_missing_caps_needs_declared_absence(self):
        regions = dict(FULL); regions.pop('caps'); p = plan(); p.pop('CAP:0')
        self.assertEqual(check(recipe(regions), p)['verdict'], 'FAIL')
        ok = check(recipe(regions, assembly_absent={'caps': 'this test roof has no hip caps'}), p)
        self.assertEqual(ok['verdict'], 'PASS', ok['errors'])
        bad = check(recipe(regions, assembly_absent={'caps': ''}), p)
        self.assertEqual(bad['verdict'], 'FAIL')

    def test_none_part_needs_reason(self):
        spec = json.loads(json.dumps(SPEC)); spec['parts']['soffit']['reason'] = ''
        self.assertEqual(check(recipe(FULL, assembly=spec), plan())['verdict'], 'FAIL')

    def test_unknown_scoped_material_fails(self):
        p = plan(); p['ROOF:9'] = {'owner': True, 'page': 'R0', 'material': 'roof_mystery'}
        regions = dict(FULL); regions['field'] = FULL['field'] + ['ROOF:9']
        self.assertEqual(check(recipe(regions), p)['verdict'], 'FAIL')

    def test_spec_path_relative_to_recipe(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / 'spec.json').write_text(json.dumps(SPEC))
            r = check(recipe(FULL, assembly='spec.json'), plan(), d)
            self.assertEqual(r['verdict'], 'PASS', r['errors'])

    def test_non_roof_scope_is_not_gated(self):
        p = {'W:0': {'owner': True, 'page': 'P', 'material': 'WALL'}}
        r = check({'scope': {'regions': [{'id': 'w', 'faces': ['W:0'], 'highs': ['H']}]}}, p)
        self.assertEqual(r['verdict'], 'PASS')


if __name__ == '__main__':
    unittest.main()
