"""Audit 2026-10-13-codex-roof-pattern-80; INC-334."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import numpy as np

p=Path(__file__).resolve().parents[1]/'scripts/runtime_reader_census.py'
s=importlib.util.spec_from_file_location('census',p); C=importlib.util.module_from_spec(s);s.loader.exec_module(C)


class CensusTests(unittest.TestCase):
    def mesh(self):
        return dict(name='two groups',tris=np.array([[0,1,2],[0,2,3]]),
            uv=np.array([[0,0],[1,0],[1,1],[0,1.]]),pos=np.zeros((4,3)),
            bone=np.array([0,1,1,0]),bone_names=['a','b'],
            mats=['protected','roof'],groups=[(1,0,1),(0,1,1)])

    def test_material_indices_not_group_order(self):
        mesh=self.mesh(); a,rows=C.collect({'render':[mesh]},{'protected':{},'roof':{}})
        self.assertEqual(a['material'].tolist(),['roof','protected'])
        self.assertEqual(a['triangle'].tolist(),[0,1])
        self.assertEqual(a['bone'].tolist(),[[0,1,1],[0,1,0]])
        self.assertEqual(rows[0]['bone_names'],['a','b'])

    def test_uncovered_triangle_refused(self):
        mesh=self.mesh();mesh['groups']=[(0,0,1)]
        with self.assertRaisesRegex(ValueError,'Uncovered'): C.collect({'render':[mesh]},{'protected':{}})

    def test_duplicate_reader_assignment_refused(self):
        mesh=self.mesh();mesh['groups']=[(0,0,2),(1,0,1)]
        with self.assertRaisesRegex(ValueError,'multiply'): C.collect({'render':[mesh]},{'protected':{},'roof':{}})

    def test_missing_material_refused(self):
        with self.assertRaisesRegex(ValueError,'Missing material'): C.collect({'render':[self.mesh()]},{'protected':{}})

    def test_missing_uv_refused(self):
        mesh=self.mesh();mesh['uv']=None
        with self.assertRaisesRegex(ValueError,'Missing/nonfinite UV'): C.collect({'render':[mesh]},{})


MATERIAL = '''<material>
  <submaterial name="{a}"><materialdef name="default" />
    <parameters><texture name="BaseColor" override="buildings\\x\\x_matA_BaseColor" /></parameters></submaterial>
  <submaterial name="{b}"><materialdef name="default_doublesided_cutout" /><parameters /></submaterial>
  <submaterial name="matD"><materialdef name="default" /><parameters /></submaterial>
</material>
'''


class CaseInsensitiveBindingTests(unittest.TestCase):
    """Audit 2026-10-17-claude-opus-5.5 harness-fixes-02: vanilla japan_consulate_age2.material
    declares matA/matB/matC, its GR2 binds mata/matb/matc; the game renders it textured."""

    def bindings(self, a='Protected', b='ROOF'):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'x.material'
            path.write_text(MATERIAL.format(a=a, b=b), encoding='utf-8')
            return C.material_bindings(path, Path(d))

    def test_bound_spelling_used_and_declared_name_kept(self):
        mesh = CensusTests.mesh(self)
        bound = C.match_bindings({'render': [mesh]}, self.bindings())
        self.assertEqual(list(bound), ['protected', 'roof', 'matD'])
        self.assertEqual(bound['protected']['declared_name'], 'Protected')
        self.assertEqual(bound['roof']['shader'], 'default_doublesided_cutout')
        self.assertNotIn('declared_name', bound['matD'])  # declared, never bound: own spelling
        a, _ = C.collect({'render': [mesh]}, bound)
        self.assertEqual(a['material'].tolist(), ['roof', 'protected'])

    def test_exact_spelling_unchanged(self):
        bound = C.match_bindings({'render': [CensusTests.mesh(self)]}, self.bindings('protected', 'roof'))
        self.assertNotIn('declared_name', bound['protected'])
        self.assertEqual(bound['protected']['textures']['BaseColor']['source'], 'archive_or_unresolved')

    def test_names_equal_up_to_case_refused(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate material name .*matA, mata'):
            self.bindings('matA', 'mata')

    def test_still_missing_when_no_case_variant_declared(self):
        mesh = CensusTests.mesh(self); mesh['mats'] = ['protected', 'roof2']
        with self.assertRaisesRegex(ValueError, 'Missing material binding: roof2'):
            C.collect({'render': [mesh]}, C.match_bindings({'render': [mesh]}, self.bindings()))


if __name__=='__main__':unittest.main()
