import importlib.util
from pathlib import Path
import tempfile
import unittest
import numpy as np
from PIL import Image

spec=importlib.util.spec_from_file_location('resolve_ao',Path(__file__).parents[1]/'scripts/resolve_ao.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class AOTests(unittest.TestCase):
 def test_ten_readers_do_not_darken(self):
  owner=np.full(100,.8);mask,evidence=m.family_conflicts(owner,[owner]*10)
  np.testing.assert_allclose(m.neutralize(owner,mask),.8)
  self.assertFalse(mask.any())
 def test_union_clears_every_conflict(self):
  owner=np.array([.7,.7,.7]);a=np.array([.3,.7,.7]);b=np.array([.7,.2,.7])
  mask,_=m.family_conflicts(owner,[a,b]);np.testing.assert_allclose(m.neutralize(owner,mask),[1,1,.7])
 def test_invalid_values_rejected(self):
  for bad in [np.array([np.nan]),np.array([1.1]),np.array([-.1])]:
   with self.assertRaises(ValueError):m.neutralize(bad,np.array([0]))
 def test_raster_barycentric_coordinates(self):
  yy,xx,w=m.raster_triangle([[0,0],[4,0],[0,4]],4,4)
  np.testing.assert_allclose(w.sum(axis=1),1)
  np.testing.assert_allclose(w@np.array([[0,0],[4,0],[0,4]]),np.column_stack([xx+.5,yy+.5]))
 def test_padding_does_not_change_coverage_values(self):
  a=np.ones((7,7));a[3,3]=.4;c=np.zeros((7,7),bool);c[3,3]=True
  out,_,band=m.padded(a,c,c.astype(int),1)
  self.assertEqual(out[3,3],.4);self.assertEqual(out[0,0],1);self.assertEqual(band.sum(),4)
 def test_end_to_end_shared_owner_and_conflict(self):
  with tempfile.TemporaryDirectory() as tmp:
   p=Path(tmp);Image.fromarray(np.full((8,8),204,np.uint8)).save(p/'a.png');Image.fromarray(np.full((8,8),102,np.uint8)).save(p/'b.png')
   base=dict(resource='wall',production_pixels=[[1,1],[7,1],[1,7]],reference_uv=[[.1,.1],[.9,.1],[.1,.9]])
   conf=dict(size=[8,8],references={'A':str(p/'a.png'),'B':str(p/'b.png')},triangles=[dict(base,chart=1,owner=1,house='A'),dict(base,chart=2,owner=1,house='B')])
   r=m.run(conf,p/'out',0)['resources']['wall'];self.assertEqual(r['maximum_writer_count'],1);self.assertEqual(r['missing_correspondence'],[])
   with np.load(p/'out/wall_AO_EVIDENCE.npz') as e:
    np.testing.assert_allclose(e['resolved'][e['coverage']],1);np.testing.assert_allclose(e['raw'][e['coverage']],.8,atol=1e-7)

if __name__=='__main__':unittest.main()
