"""INC-103: whole perimeter/view coverage; alpha pixels alone were insufficient."""
import copy
import unittest
from check_alpha_chain import assess_clearance


class ClearanceTests(unittest.TestCase):
 def setUp(self):
  self.expected={'main':['f1','f2'],'small':['f3']};self.views=['low','moderate','left','right']
  self.rows={roof+'|'+view:dict(fronts=faces,samples=1116,blocked=28,blocked_fraction=28/1116,face_samples={f:1116//len(faces) for f in faces})
             for roof,faces in self.expected.items() for view in self.views}
 def verdict(self):return assess_clearance(self.rows,self.expected,self.views)['verdict']
 def test_current_clearance_passes(self):self.assertEqual(self.verdict(),'PASS')
 def test_measured_pre_inset_rate_fails_on_one_small_roof(self):
  row=self.rows['small|left'];row.update(blocked=416,blocked_fraction=416/1116)
  self.assertEqual(self.verdict(),'FAIL')
 def test_cannot_omit_small_roof(self):
  self.rows={k:v for k,v in self.rows.items() if not k.startswith('small|')};self.assertEqual(self.verdict(),'FAIL')
 def test_cannot_omit_oblique_view(self):
  del self.rows['main|right'];self.assertEqual(self.verdict(),'FAIL')
 def test_cannot_duplicate_front_to_hide_omission(self):
  self.rows['main|low']['fronts']=['f1','f1'];self.assertEqual(self.verdict(),'FAIL')
 def test_nan_count_fails(self):
  self.rows['main|low']['samples']=float('nan');self.assertEqual(self.verdict(),'FAIL')
 def test_zero_or_tiny_sample_cannot_pass(self):
  self.rows['main|low'].update(samples=1,blocked=0,blocked_fraction=0);self.assertEqual(self.verdict(),'FAIL')
 def test_reported_fraction_cannot_hide_actual_blockers(self):
  self.rows['small|low']['blocked']=800;self.assertEqual(self.verdict(),'FAIL')
 def test_opaque_face_cannot_hide_behind_good_neighbour(self):
  self.rows['main|low']['face_samples']={'f1':1116,'f2':0};self.assertEqual(self.verdict(),'FAIL')

if __name__=='__main__':unittest.main()
