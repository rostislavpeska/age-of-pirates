import unittest
import numpy as np
from neutralize_ao import neutralize

class NeutralTests(unittest.TestCase):
 def test_union_mask_removes_conflict_for_both_members(self):
  owner=np.array([[.2,.8],[.4,.7]]);member=np.array([[.9,.8],[.6,.7]]);mask=np.array([[1.,0],[1.,0]])
  a=neutralize(owner,mask);b=neutralize(member,mask)
  np.testing.assert_array_equal(a,b);np.testing.assert_array_equal(a[:,1],owner[:,1]);self.assertTrue((a[:,0]==1).all())
 def test_wrong_resolution_or_bad_values_fail(self):
  for mask in (np.zeros((2,3)),np.full((2,2),255),np.full((2,2),float('nan'))):
   with self.assertRaises(ValueError):neutralize(np.ones((2,2)),mask)
 def test_feather_only_lifts_and_does_not_modify_input(self):
  a=np.array([[.2,.8]]);np.testing.assert_allclose(neutralize(a,np.array([[.5,0]])),[[.6,.8]]);np.testing.assert_array_equal(a,[[.2,.8]])

if __name__=='__main__':unittest.main()
