import unittest
from test_planar_share import grid
from scaled_rectangle_share import proposal,partial_rectangle

class ScaledRectangleTests(unittest.TestCase):
    def test_small_wood_and_one_axis_scale(self):
        m=proposal(grid('a',(0,.25),(0,.15)),grid('b',(0,.254),(0,.15)),allowed_materials=('WOOD',))
        self.assertIsNotNone(m);self.assertLess(m['max_density_change'],.02)
    def test_large_wall_not_allowed(self):
        self.assertIsNone(proposal(grid('a',(0,2),(0,3)),grid('b',(0,2.01),(0,3)),allowed_materials=('WOOD',)))
    def test_roof_material_not_allowed(self):
        self.assertIsNone(proposal(grid('a',(0,.25),(0,.15),material='ROOF_TILE'),grid('b',(0,.254),(0,.15),material='ROOF_TILE')))
    def test_large_axis_change_rejected(self):
        self.assertIsNone(proposal(grid('a',(0,.25),(0,.15)),grid('b',(0,.3),(0,.15)),allowed_materials=('WOOD',)))
    def test_half_rectangle_no_scale(self):
        m=partial_rectangle(grid('a',(0,2),(0,1)),grid('b',(0,1),(0,1)))
        self.assertIsNotNone(m);self.assertAlmostEqual(m['covered_owner_fraction'],.5);self.assertLess(m['max_density_change'],1e-9)
    def test_third_rectangle_no_scale(self):
        m=partial_rectangle(grid('a',(0,3),(0,1)),grid('b',(0,1),(0,1)))
        self.assertAlmostEqual(m['covered_owner_fraction'],1/3)

if __name__=='__main__':unittest.main()
