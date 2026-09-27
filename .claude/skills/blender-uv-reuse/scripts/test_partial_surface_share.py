import copy,unittest,numpy as np
from test_planar_share import grid
from partial_surface_share import match_subset,_interpolate_render_uv

class PartialSurfaceTests(unittest.TestCase):
    def test_cut_patch_shares_without_splitting_source(self):
        a=grid('a',(0,1,2));b=grid('b',(0,1,2));b['faces'][1]['points'][1][0]=1.6;b['faces'][1]['points'][2][0]=1.6
        b['faces'][1]['uv'][1][0]=1.6*256+500;b['faces'][1]['uv'][2][0]=1.6*256+500
        old=copy.deepcopy((a,b));m=match_subset(a,b);self.assertIsNotNone(m);self.assertAlmostEqual(m['covered_owner_fraction'],.8);self.assertEqual((a,b),old)
    def test_wrong_material_rejected(self):
        a=grid('a',(0,1,2));b=grid('b',(0,1,2));b['faces'][1]['material']='STONE';self.assertIsNone(match_subset(a,b))
    def test_surface_outside_owner_rejected(self):
        a=grid('a',(0,1,2));b=grid('b',(0,1,2));b['faces'][1]['points'][2][1]=1.3
        self.assertIsNone(match_subset(a,b))
    def test_density_change_rejected(self):
        self.assertIsNone(match_subset(grid('a',(0,1,2)),grid('b',(0,1,2),uv_scale=300)))
    def test_derived_render_interpolation_uses_existing_diagonal(self):
        plane={'xy':np.array([[0,0],[1,0],[1,1],[0,1]],float)}
        face={'uv':[[0,0],[1,0],[1.1,1],[0,1]],'render_corner_triangles':[[0,1,2],[0,2,3]]}
        np.testing.assert_allclose(_interpolate_render_uv([[.25,.25]],plane,face,1e-5),[[.275,.25]])
    def test_render_interpolation_rejects_outside(self):
        plane={'xy':np.array([[0,0],[1,0],[1,1],[0,1]],float)}
        face={'uv':[[0,0],[1,0],[1.1,1],[0,1]],'render_corner_triangles':[[0,1,2],[0,2,3]]}
        self.assertIsNone(_interpolate_render_uv([[2,2]],plane,face,1e-5))

if __name__=='__main__':unittest.main()
