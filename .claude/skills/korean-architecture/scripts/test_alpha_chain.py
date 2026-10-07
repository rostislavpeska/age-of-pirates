"""INC-103: reject front alpha hidden by opaque backing or a useless view.

The measured r43c/r44 fixtures below are portable summaries of the incident,
not tests that depend on private renders. A passing r44 summary establishes only
the supplied underlip/silhouette scope: it did not catch the later shaded full
backing failure repaired by r45b. Keep that limitation explicit.
"""
import unittest,copy
from check_alpha_chain import assess
class AlphaTests(unittest.TestCase):
 def setUp(self):
  self.p={'roof':dict(faces=[{}],cut_front_samples=100,mismatch_fraction=.02)};self.r={'roof':dict(reference_cut_pixels=1000,blocked_fraction=.01)};self.e={'roof':1}
 def test_correct_chain_passes(self):self.assertEqual(assess(self.p,self.r,self.e)['verdict'],'PASS')
 def test_bound_alpha_but_opaque_backing_fails(self):
  self.p['roof']['mismatch_fraction']=.9;self.assertEqual(assess(self.p,self.r,self.e)['verdict'],'FAIL')
 def test_missing_underlip_fails(self):
  self.p['roof']['faces']=[];self.assertEqual(assess(self.p,self.r,self.e)['verdict'],'FAIL')
 def test_opaque_shader_control_fails(self):
  self.r['roof']['blocked_fraction']=1;self.assertEqual(assess(self.p,self.r,self.e)['verdict'],'FAIL')
 def test_empty_or_fully_occluded_camera_fails(self):
  self.r['roof']['reference_cut_pixels']=0;self.assertEqual(assess(self.p,self.r,self.e)['verdict'],'FAIL')
 def test_nan_does_not_pass(self):
  self.p['roof']['mismatch_fraction']=float('nan');self.assertEqual(assess(self.p,self.r,self.e)['verdict'],'FAIL')

class Incident103MeasuredEvidence(unittest.TestCase):
 """Frozen incident measurements: failed specimen and its scoped repair."""
 def setUp(self):
  self.e={'Barracks':136,'Stable':54}
  self.p={
   'Barracks':dict(faces=[{} for _ in range(136)],cut_front_samples=8153,mismatch_fraction=215/8153),
   'Stable':dict(faces=[{} for _ in range(54)],cut_front_samples=3122,mismatch_fraction=112/3122),
  }
  self.r={
   'Barracks':dict(reference_cut_pixels=8000,blocked_fraction=0),
   'Stable':dict(reference_cut_pixels=8462,blocked_fraction=0),
  }
 def test_measured_r44_scoped_repair_passes(self):
  self.assertEqual(assess(self.p,self.r,self.e)['verdict'],'PASS')
 def test_measured_r43c_backing_and_render_both_fail(self):
  failed=copy.deepcopy(self.p);renders=copy.deepcopy(self.r)
  failed['Barracks']['mismatch_fraction']=7430/8153
  failed['Stable']['mismatch_fraction']=2805/3122
  renders['Barracks']['blocked_fraction']=5083/8000
  renders['Stable']['blocked_fraction']=5171/8462
  result=assess(failed,renders,self.e)
  self.assertEqual(result['verdict'],'FAIL')
  for kind in self.e:
   self.assertIn(kind+': opaque backing behind cut front',result['errors'])
   self.assertIn(kind+': rendered cutout is obstructed',result['errors'])
 def test_render_still_blocks_when_projection_alone_passes(self):
  self.r['Stable']['blocked_fraction']=5171/8462
  result=assess(self.p,self.r,self.e)
  self.assertEqual(result['verdict'],'FAIL')
  self.assertEqual(result['errors'],['Stable: rendered cutout is obstructed'])
 def test_cannot_omit_second_building_render(self):
  del self.r['Stable']
  self.assertEqual(assess(self.p,self.r,self.e)['verdict'],'FAIL')
 def test_cannot_omit_one_of_the_measured_underlip_faces(self):
  self.p['Barracks']['faces'].pop()
  result=assess(self.p,self.r,self.e)
  self.assertIn('Barracks: omitted underlip faces',result['errors'])
 def test_projection_needs_actual_cut_samples(self):
  self.p['Stable']['cut_front_samples']=0
  self.assertEqual(assess(self.p,self.r,self.e)['verdict'],'FAIL')
 def test_render_fraction_nan_cannot_pass(self):
  self.r['Stable']['blocked_fraction']=float('nan')
  self.assertEqual(assess(self.p,self.r,self.e)['verdict'],'FAIL')
if __name__=='__main__':unittest.main()
