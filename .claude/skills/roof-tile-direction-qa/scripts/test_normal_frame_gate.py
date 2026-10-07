"""Positive and negative controls for the diagnostic frame prerequisite."""
import unittest
import numpy as np
from normal_frame_gate import assess


class FrameTests(unittest.TestCase):
    def setUp(self):
        self.p = np.array([[[0,0,0],[1,0,0],[0,1,0]]],float)
        self.u = self.p[:,:,:2].copy()
        self.n = np.broadcast_to([0,0,1],self.p.shape).copy()
        self.t = np.broadcast_to([1,0,0],self.p.shape).copy()
        self.b = np.broadcast_to([0,1,0],self.p.shape).copy()

    def check(self):return assess(self.p,self.u,self.n,self.t,self.b)['status']
    def test_correct_frame(self):self.assertEqual(self.check(),'PASS')
    def test_normal_contaminated_tangent(self):
        self.t=np.broadcast_to([.8,0,.6],self.p.shape);self.assertEqual(self.check(),'FAIL')
    def test_orthogonal_but_reversed_u(self):
        self.t=-self.t;self.b=-self.b;self.assertEqual(self.check(),'FAIL')
    def test_wrong_handedness(self):
        self.b=-self.b;self.assertEqual(self.check(),'FAIL')
    def test_mirrored_uv_with_correct_frame(self):
        self.u[:,:,0]=1-self.u[:,:,0];self.t=-self.t;self.assertEqual(self.check(),'PASS')
    def test_degenerate_uv(self):
        self.u[:]=0;self.assertEqual(self.check(),'FAIL')
    def test_nonfinite_input(self):
        self.p[0,0,0]=np.nan
        with self.assertRaises(ValueError):self.check()
    def test_corner_shape_mismatch(self):
        with self.assertRaises(ValueError):assess(self.p,self.u,self.n,self.t[:,:2],self.b)


if __name__=='__main__':unittest.main()
