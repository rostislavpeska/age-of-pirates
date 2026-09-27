import unittest
import numpy as np
from geometry_share import group_charts


def chart(name,points=None,uv=None,material='wood'):
    return dict(id=name,page='A',faces=[dict(id=0,material=material,
        points=points or [[0,0,0],[2,0,0],[2,1,0],[0,1,0]],
        uv=uv or [[0,0],[20,0],[20,10],[0,10]],normal=[0,0,1])])


class SharingTests(unittest.TestCase):
    def test_rigid_translated_and_rotated_chart(self):
        a=chart('a');b=chart('b',points=[[5,3,1],[5,5,1],[4,5,1],[4,3,1]],uv=[[80,20],[80,40],[70,40],[70,20]])
        out=group_charts([a,b]);self.assertEqual(len(out['groups']),1)
        self.assertLess(out['groups'][0]['members'][0]['position_error'],1e-8)
        self.assertFalse(out['ao_tested']);self.assertFalse(out['packing_performed'])

    def test_same_uv_different_geometry_is_rejected(self):
        a=chart('a');b=chart('b',points=[[0,0,0],[3,0,0],[3,1,0],[0,1,0]])
        self.assertEqual(len(group_charts([a,b])['groups']),2)

    def test_different_material_is_not_shared(self):
        self.assertEqual(len(group_charts([chart('a'),chart('b',material='stone')])['groups']),2)

    def test_changed_existing_uv_scale_stays_unique(self):
        b=chart('b',uv=[[0,0],[40,0],[40,20],[0,20]])
        self.assertEqual(len(group_charts([chart('a'),b])['groups']),2)

    def test_mirror_is_recorded(self):
        a=chart('a',points=[[0,0,0],[2,0,0],[1.5,1,0],[0,1,0]],uv=[[0,0],[20,0],[15,10],[0,10]])
        b=chart('b',points=[[0,0,0],[-2,0,0],[-1.5,1,0],[0,1,0]],uv=[[20,0],[0,0],[5,10],[20,10]])
        g=group_charts([a,b])['groups'];self.assertEqual(len(g),1)
        self.assertTrue(g[0]['members'][0]['uv_reflection'])

    def test_relief_not_certified_by_flat_uv(self):
        b=chart('b',points=[[0,0,0],[2,0,0],[2,1,.1],[0,1,0]])
        self.assertEqual(len(group_charts([chart('a'),b])['groups']),2)

    def test_no_input_mutation_or_triangle_conversion(self):
        a=chart('a');b=chart('b');old=repr([a,b]);group_charts([a,b])
        self.assertEqual(repr([a,b]),old);self.assertEqual(len(a['faces'][0]['points']),4)

    def test_same_vertices_different_boundary_is_rejected(self):
        a=chart('a');b=chart('b',uv=[[0,0],[20,10],[20,0],[0,10]],points=[[0,0,0],[2,1,0],[2,0,0],[0,1,0]])
        self.assertEqual(len(group_charts([a,b])['groups']),2)

if __name__=='__main__':unittest.main()
