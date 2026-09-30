import copy,unittest
from texel_floor import check

class FloorTests(unittest.TestCase):
    def setUp(self):
        self.r={'reference':{'floor':137,'evidence':'measured vanilla TC','units':'texels/model unit'},'required_linear_gain':2,'baseline_density':115,'components':[{'id':'window','final_density':[256,260],'source_supported_density':[256,260]}]}
    def test_rebake_meets_floor(self):self.assertEqual(check(self.r),[])
    def test_rejected_small_improvement(self):
        self.r['components'][0]['final_density']=[115,115];self.assertTrue(check(self.r))
    def test_one_weak_axis_cannot_hide_in_average(self):
        self.r['components'][0]['final_density']=[128,512];self.assertTrue(check(self.r))
    def test_upscale_cannot_pass(self):
        self.r['components'][0]['source_supported_density']=[115,115];self.assertTrue(check(self.r))
    def test_missing_measurements_fail(self):
        self.r['components'][0].pop('final_density');self.assertTrue(check(self.r))
    def test_missing_reference_fails(self):
        self.r['reference'].pop('evidence');self.assertTrue(check(self.r))
    def test_nonfinite_fails(self):
        self.r['components'][0]['final_density']=[float('nan'),300];self.assertTrue(check(self.r))

if __name__=='__main__':unittest.main()
