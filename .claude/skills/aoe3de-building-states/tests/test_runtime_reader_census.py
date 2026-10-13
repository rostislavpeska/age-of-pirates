"""Audit 2026-10-13-codex-roof-pattern-80; INC-334."""
import importlib.util
from pathlib import Path
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


if __name__=='__main__':unittest.main()
