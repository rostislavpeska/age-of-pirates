import unittest
from bounded_pack import search

class BoundedPackingTests(unittest.TestCase):
 def test_cannot_consume_more_than_authorized_30_percent(self):
  self.assertIsNone(search([(3000,3000)],min_scale=.7,gap=12)['best'])
 def test_fixed_runtime_gaps_and_border(self):
  r=search([(600,400)]*8,min_scale=.7,gap=12);b=r['best'];self.assertIsNotNone(b);self.assertGreaterEqual(b['scale'],.7)
  for i,x,y,w,h,rot in b['placements']:
   self.assertGreaterEqual(x,0);self.assertGreaterEqual(y,0);self.assertLessEqual(x+w,2048+1e-7);self.assertLessEqual(y+h,2048+1e-7)
   for j,a,c,d,e,_ in b['placements']:
    if i!=j:self.assertTrue(x+w<=a+1e-7 or a+d<=x+1e-7 or y+h<=c+1e-7 or c+e<=y+1e-7)
 def test_exact_limit_and_deterministic_search(self):
  args=dict(min_scale=.7,max_scale=.7,gap=12)
  self.assertEqual(search([(2036/.7,2036/.7)],**args)['best']['scale'],.7)
  self.assertEqual(search([(700,180),(240,120)],**args),search([(700,180),(240,120)],**args))
 def test_invalid_budget_is_not_silently_corrected(self):
  for minimum in (0,-1,float('nan'),1.1):
   with self.assertRaises(ValueError):search([(100,100)],min_scale=minimum)

if __name__=='__main__':unittest.main()
