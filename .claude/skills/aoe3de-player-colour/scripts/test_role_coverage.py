import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from check_role_coverage import validate


class RoleCoverage(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        p = Path(self.tmp.name) / 'source'
        p.write_bytes(b'current-model')
        self.data = {'source': {'path': str(p), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()},
                     'required_components': ['front', 'end', 'rear'],
                     'components': [{'id': k, 'samples': 100, 'covered': 100,
                                     'foreign_reader_conflicts': 0} for k in ['front', 'end', 'rear']]}
        self.census={'schema':1,'source':dict(self.data['source']),
                     'source_parts':['front','end','rear','roof'],
                     'covered_roles':[{'part':k,'role':'solid wall stripe','component':k} for k in ['front','end','rear']],
                     'excluded_roles':[{'part':'roof','role':'roof','reason':'Not a solid wall band'}]}
        self.bind_census()

    def bind_census(self):
        p=Path(self.tmp.name)/'independent_role_census.json'
        p.write_text(json.dumps(self.census),encoding='utf-8')
        self.data['census']={'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}

    def test_complete(self):
        self.assertEqual(validate(self.data)['status'], 'PASS')

    def test_unpainted_end_does_not_hide_in_front_average(self):
        self.data['components'][1]['covered'] = 0
        self.assertEqual(validate(self.data)['status'], 'FAIL')

    def test_omitted_end_fails(self):
        self.data['components'].pop(1)
        self.assertEqual(validate(self.data)['status'], 'FAIL')

    def test_empty_sampling_fails(self):
        self.data['components'][0]['samples'] = 0
        self.assertEqual(validate(self.data)['status'], 'FAIL')

    def test_mirrored_conflict_fails(self):
        self.data['components'][1]['foreign_reader_conflicts'] = 1
        self.assertEqual(validate(self.data)['status'], 'FAIL')

    def test_missing_reader_audit_is_not_zero(self):
        del self.data['components'][1]['foreign_reader_conflicts']
        self.assertEqual(validate(self.data)['status'], 'FAIL')

    def test_old_source_fails(self):
        Path(self.data['source']['path']).write_bytes(b'next-model')
        self.assertEqual(validate(self.data)['status'], 'FAIL')

    def test_duplicate_component_fails(self):
        self.data['components'].append(dict(self.data['components'][0]))
        self.assertEqual(validate(self.data)['status'], 'FAIL')

    def test_empty_census_fails(self):
        self.data['required_components'] = []
        self.assertEqual(validate(self.data)['status'], 'FAIL')

    def test_missing_external_census_fails_legacy_report(self):
        del self.data['census']
        self.assertEqual(validate(self.data)['status'],'FAIL')

    def test_omitting_both_required_and_result_cannot_shrink_the_census(self):
        self.data['required_components'].remove('end')
        self.data['components']=[r for r in self.data['components'] if r['id']!='end']
        self.assertEqual(validate(self.data)['status'],'FAIL')

    def test_external_census_changed_on_disk_fails(self):
        Path(self.data['census']['path']).write_text('{}')
        self.assertEqual(validate(self.data)['status'],'FAIL')

    def test_rehashed_census_for_other_source_fails(self):
        self.census['source']['sha256']='0'*64
        self.bind_census()
        self.assertEqual(validate(self.data)['status'],'FAIL')

    def test_every_source_part_needs_a_declared_role(self):
        self.census['excluded_roles']=[]
        self.bind_census()
        self.assertEqual(validate(self.data)['status'],'FAIL')

    def test_exclusion_requires_reason(self):
        del self.census['excluded_roles'][0]['reason']
        self.bind_census()
        self.assertEqual(validate(self.data)['status'],'FAIL')

    def test_excluded_role_list_must_be_explicit_even_when_empty(self):
        self.census['source_parts'].remove('roof')
        del self.census['excluded_roles']
        self.bind_census()
        self.assertEqual(validate(self.data)['status'],'FAIL')

    def test_role_cannot_be_both_covered_and_excluded(self):
        self.census['excluded_roles'].append({'part':'front','role':'wall','reason':'contradictory'})
        self.bind_census()
        self.assertEqual(validate(self.data)['status'],'FAIL')

    def test_unlisted_source_part_cannot_be_silently_classified(self):
        self.census['covered_roles'].append({'part':'absent','role':'wall','component':'front'})
        self.bind_census()
        self.assertEqual(validate(self.data)['status'],'FAIL')

    def test_separate_wall_and_paired_skirt_can_share_a_coverage_component(self):
        self.census['source_parts'].append('front_wall')
        self.census['covered_roles'].append({'part':'front_wall','role':'facade with paired skirt','component':'front'})
        self.bind_census()
        self.assertEqual(validate(self.data)['status'],'PASS')

    def test_unexpected_sampled_components_fail(self):
        self.data['components'].append({'id':'roof','samples':100,'covered':100,'foreign_reader_conflicts':0})
        self.assertEqual(validate(self.data)['status'],'FAIL')

    def test_boolean_counts_do_not_replace_measurements(self):
        self.data['components'][0].update(samples=True,covered=True,foreign_reader_conflicts=False)
        self.assertEqual(validate(self.data)['status'],'FAIL')


if __name__ == '__main__':
    unittest.main()
