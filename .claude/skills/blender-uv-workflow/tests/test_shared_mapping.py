import copy,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from shared_mapping import audit,metric_errors

class SharedMappingTests(unittest.TestCase):
 def setUp(self):
  self.faces=[dict(face='bottom',cell='wood',pending=False,physical_class='WOOD',uv_pixels=[[20,20],[100,20],[100,100]],binding='matc',sampled_exposure=0)]
  self.cells={'wood':dict(bounds=[16,16,160,160],physical_classes=['WOOD'])}
  self.bindings={'matc':dict(required_channels=['BaseColor','Normals','Masks'],uv_layer_verified=True,actual_channels={k:dict(source_sha256='a'*64,bound_image_sha256='a'*64) for k in ('BaseColor','Normals','Masks')})}
 def run_audit(self):return audit(self.faces,['bottom'],self.cells,self.bindings)
 def test_valid_shared_face_and_no_shared_resources(self):
  self.assertEqual(self.run_audit()['status'],'PASS');self.assertFalse(metric_errors(audit([],[],{}, {})['metrics']))
 def test_INC095_slot_name_without_mapping_or_images_fails(self):
  self.faces[0].update(cell=None,pending=True);self.bindings['matc']['actual_channels']={}
  r=self.run_audit();self.assertEqual(r['status'],'INCOMPLETE');self.assertEqual(r['metrics']['unmapped'],1);self.assertEqual(r['metrics']['unbound'],1)
 def test_cell_border_and_nonfinite_uv_fail(self):
  for q in ([161,20],[float('nan'),20],[0,0]):
   self.faces[0]['uv_pixels'][0]=q;self.assertEqual(self.run_audit()['metrics']['outside_cells'],1)
 def test_plaster_is_not_wood(self):
  self.faces[0]['physical_class']='PLASTER';self.assertEqual(self.run_audit()['metrics']['incompatible'],1)
 def test_exposed_downward_face_needs_quality_disposition(self):
  self.faces[0]['sampled_exposure']=5;self.assertEqual(self.run_audit()['metrics']['unreviewed_exposure'],1)
  self.faces[0]['exposure_disposition']='adequate_shared_quality';self.assertEqual(self.run_audit()['status'],'PASS')
 def test_missing_or_duplicate_faces_fail(self):
  for ids in ([],['missing']):
   with self.assertRaises(ValueError):audit(self.faces,ids,self.cells,self.bindings)
  with self.assertRaises(ValueError):audit(self.faces*2,['bottom'],self.cells,self.bindings)
 def test_wrong_image_revision_is_unbound(self):
  self.bindings['matc']['actual_channels']['Normals']['bound_image_sha256']='b'*64
  self.assertEqual(self.run_audit()['metrics']['unbound'],1)
 def test_pending_count_cannot_be_wrapped_as_pass(self):
  self.assertTrue(metric_errors({'shared_face_count':100,'unmapped':1,'incompatible':0,'unbound':0,'outside_cells':0,'unreviewed_exposure':0,'coverage_errors':0}))

if __name__=='__main__':unittest.main()
