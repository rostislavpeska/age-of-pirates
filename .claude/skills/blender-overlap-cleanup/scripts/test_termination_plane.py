"""INC-188: a covered beam must not protrude through its sloped eave."""
import unittest
import numpy as np
from termination_plane import check_termination


class TerminationTests(unittest.TestCase):
    def setUp(self):
        # Actual House A eave-front cross-section: the rectangular timber cap
        # protruded below the sloping roof end despite a plausible bounding box.
        self.cover=np.array([[-1.88,-1.9650000334,3.2151138783],[-1.88,-1.9176913500,3.0414421558],
                             [1.88,-1.9176913500,3.0414421558],[1.88,-1.9650000334,3.2151138783]])
        n=np.cross(self.cover[1]-self.cover[0],self.cover[2]-self.cover[0]);self.n=n/np.linalg.norm(n)
        self.old=np.array([[-1.88,-1.95,3.1642],[-1.79,-1.95,3.1642],
                           [-1.79,-1.95,3.0542],[-1.88,-1.95,3.0542]])

    def repaired(self):
        p=self.old.copy();offset=float(self.cover[0]@self.n)-.015
        delta=np.maximum(0,p@self.n-offset);p[:,1]-=delta/self.n[1]
        return p

    def test_actual_protruding_cap_fails_and_trim_passes(self):
        self.assertEqual(check_termination(self.old,self.cover,self.n,.015)['status'],'FAIL')
        self.assertEqual(check_termination(self.repaired(),self.cover,self.n,.015)['status'],'PASS')

    def test_rotated_and_translated_models_same_result(self):
        rot=np.array([[0,-1,0],[1,0,0],[0,0,1]]);shift=np.array([700,17,-4])
        for points,status in [(self.old,'FAIL'),(self.repaired(),'PASS')]:
            self.assertEqual(check_termination(points@rot.T+shift,self.cover@rot.T+shift,self.n@rot.T,.015)['status'],status)

    def test_empty_nan_and_nonplanar_never_pass(self):
        for p in [[],[[0,0,float('nan')]]]:
            self.assertEqual(check_termination(p,self.cover,self.n,.015)['status'],'INCOMPLETE')
        q=self.cover.copy();q[0,2]+=.1
        self.assertEqual(check_termination(self.old,q,self.n,.015)['status'],'INCOMPLETE')

    def test_no_clearance_is_not_an_approved_setback(self):
        self.assertEqual(check_termination(self.cover,self.cover,self.n,.015)['status'],'FAIL')


if __name__=='__main__':unittest.main()
