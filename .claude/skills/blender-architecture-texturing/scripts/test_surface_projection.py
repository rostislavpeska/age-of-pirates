"""INC-186: valid atlas area must not conceal collapsed source coordinates."""
import unittest
import numpy as np
from surface_projection import triangle_metrics,face_frame

class ProjectionTests(unittest.TestCase):
    def test_real_house_plinth_valid_atlas_but_collapsed_source(self):
        # A/B/C r13 south foundation: longest object axis is Y, constant here.
        p=np.array([[-1.625,-1.690000057,0],[1.625,-1.690000057,0],[1.625,-1.690000057,.400000006]])
        atlas=np.array([[487,52],[925.048,52],[925.048,105.914]])
        self.assertEqual(triangle_metrics(p,atlas)['status'],'PASS')
        defective=np.column_stack((p[:,1]*364/2.6,p[:,2]*344/1.5))
        self.assertEqual(triangle_metrics(p,defective)['status'],'FAIL')
        repaired=np.column_stack((p[:,0]*364/2.6,p[:,2]*344/1.5))
        self.assertEqual(triangle_metrics(p,repaired)['status'],'PASS')

    def test_all_box_faces_and_opposing_stair_sides(self):
        for normal_axis in range(3):
            other=[i for i in range(3) if i!=normal_axis]
            for sign in [-1,1]:
                p=np.zeros((4,3));p[:,normal_axis]=sign*2
                p[:,other[0]]=[0,3,3,0];p[:,other[1]]=[0,0,.4,.4]
                u,v=face_frame(p,normal_axis)
                q=np.column_stack((p@u,p@v))*128
                for tri in [[0,1,2],[0,2,3]]:
                    self.assertEqual(triangle_metrics(p[tri],q[tri])['status'],'PASS')

    def test_near_zero_and_nonfinite_are_not_hidden_by_positive_area(self):
        p=[[0,0,0],[3,0,0],[3,1,0]]
        self.assertEqual(triangle_metrics(p,[[0,0],[1e-8,0],[1e-8,300]])['status'],'FAIL')
        self.assertEqual(triangle_metrics(p,[[0,0],[float('nan'),0],[100,100]])['status'],'FAIL')
        self.assertEqual(triangle_metrics([[0,0,0]]*3,[[0,0],[100,0],[0,100]])['status'],'INCOMPLETE')

    def test_rotation_and_scale_preserve_measurement(self):
        p=np.array([[0,0,0],[2,0,0],[2,3,0]],float)
        q=p[:,:2]*100
        ang=.73;rot=np.array([[1,0,0],[0,np.cos(ang),-np.sin(ang)],[0,np.sin(ang),np.cos(ang)]])
        x=triangle_metrics(p@rot.T+123,q)
        np.testing.assert_allclose(x['axis_pixels_per_unit'],[100,100],rtol=1e-9)

if __name__=='__main__':unittest.main()
