import copy,unittest
from check_eave_contract import assess

class Contract(unittest.TestCase):
 def setUp(self):
  self.d={'expected_roofs':['main'],'roofs':{'main':{'verified_roles':['field','front_relief','front_opacity','underlip','corners'],'projection_min':.10,'required_projection':.10,'interior_bake_misses':0,'front_cut_fraction':.12,'reader_mismatch_fraction':0,'material_placeholder':False,'geometry_and_uv_identity_checked':True}},'own_pages':[2048,2048],'additional_runtime_materials':0}
  self.d['alpha_chain']={'expected_faces':{'model':1},'projection':{'model':{'faces':[{}],'cut_front_samples':100,'mismatch_fraction':0}},'renders':{'model':{'reference_cut_pixels':1000,'blocked_fraction':0}}}
 def test_complete(self):self.assertEqual(assess(self.d)['verdict'],'PASS')
 def test_missing_feature(self):
  self.d['roofs']['main']['verified_roles'].remove('underlip');self.assertEqual(assess(self.d)['verdict'],'FAIL')
 def test_flush_nose(self):
  self.d['roofs']['main']['projection_min']=0;self.assertEqual(assess(self.d)['verdict'],'FAIL')
 def test_no_alpha(self):
  self.d['roofs']['main']['front_cut_fraction']=0;self.assertEqual(assess(self.d)['verdict'],'FAIL')
 def test_unbaked_material(self):
  self.d['roofs']['main']['material_placeholder']=True;self.assertEqual(assess(self.d)['verdict'],'FAIL')
 def test_missing_alpha_chain(self):
  del self.d['alpha_chain'];self.assertEqual(assess(self.d)['verdict'],'FAIL')
 def test_budget(self):
  self.d['own_pages']=[4096,4096];self.assertEqual(assess(self.d)['verdict'],'FAIL')

if __name__=='__main__':unittest.main()
