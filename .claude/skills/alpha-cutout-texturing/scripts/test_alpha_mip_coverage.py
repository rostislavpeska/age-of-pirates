import unittest
import numpy as np
from alpha_mip_coverage import measure, gate, audit
from pathlib import Path


class RegionalCoverageTests(unittest.TestCase):
    def test_small_region_loss_cannot_hide_in_page_average(self):
        source = np.ones((64,64)); source[:8,:8] = 0; source[2:4,2:4] = 1
        mip = np.ones((32,32)); mip[:4,:4] = 0
        mask = np.zeros_like(source,dtype=bool); mask[:8,:8] = True
        self.assertGreater(mip.mean(), .98)  # whole-page measurement looks healthy
        result = measure(source,mask,mip,1)
        self.assertEqual(result['retention'],0)
        self.assertEqual(gate(result,{'min_retention':.9})[0],'FAIL')

    def test_filled_holes_are_also_a_failure(self):
        source=np.ones((8,8));source[2:6,2:6]=0
        result=measure(source,np.ones_like(source,bool),np.ones((4,4)),1)
        self.assertGreater(result['filled_cutout_samples'],0)
        self.assertEqual(gate(result,{'max_retention':1.1})[0],'FAIL')

    def test_identical_top_mip_is_exact(self):
        source=np.random.default_rng(1).random((16,16))
        result=measure(source,np.ones_like(source,bool),source,0)
        self.assertEqual(result['silhouette_iou'],1)
        self.assertEqual(result['retention'],1)

    def test_empty_alpha_region_uses_absolute_coverage_gate(self):
        source=np.zeros((8,8))
        result=measure(source,np.ones_like(source,bool),np.ones((4,4)),1)
        self.assertIsNone(result['retention'])
        self.assertEqual(gate(result,{'max_empty_coverage':0})[0],'FAIL')
        self.assertEqual(gate(result,{'min_retention':.9})[0],'DIAGNOSTIC')

    def test_no_bounds_cannot_claim_pass(self):
        source=np.ones((8,8))
        self.assertEqual(gate(measure(source,source,source,0),{})[0],'DIAGNOSTIC')

    def test_empty_mask_refused(self):
        with self.assertRaisesRegex(ValueError,'Empty region'):
            measure(np.ones((8,8)),np.zeros((8,8)),np.ones((4,4)),1)

    def test_wrong_mip_dimensions_refused(self):
        with self.assertRaisesRegex(ValueError,'expected'):
            measure(np.ones((8,8)),np.ones((8,8)),np.ones((8,8)),1)

    def test_missing_evidence_refused(self):
        with self.assertRaises(ValueError):audit({'regions':[],'mips':[]},Path('.'))

    def test_duplicate_mips_refused(self):
        with self.assertRaisesRegex(ValueError,'Duplicate mip'):
            audit({'regions':[{'name':'a'}],'mips':[{'level':0},{'level':0}]},Path('.'))

    def test_nan_or_inverted_bounds_cannot_bypass_gate(self):
        for bounds in [{'min_retention':float('nan')},
                       {'min_retention':1.2,'max_retention':1.1},
                       {'max_empty_coverage':2}]:
            with self.subTest(bounds=bounds), self.assertRaises(ValueError):
                audit({'regions':[{'name':'a'}],'mips':[{'level':0,**bounds}]},Path('.'))


if __name__=='__main__':unittest.main()
