"""Pinned-reader API fixtures; audit 2026-10-13-codex-tc-packer-01, KTC-377."""
import copy
import hashlib
import json
import math
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from pack_masks import pack,validate
from pixel_audit import shape_for

def rect(key,x,y,w,h):
    return {'id':key,'polygons':[[[x,y],[x+w,y],[x+w,y+h],[x,y+h]]]}

class PinnedPack(unittest.TestCase):
    def specimen(self):
        return {'size':[48,32],'padding_px':2,'charts':[rect('moving',0,0,6,6)],
                'obstacles':[dict(rect('wall',0,0,16,32),source='fixture-state')]}

    def test_default_exact_regression(self):
        # Existing empty-page path: unchanged first placement and output keys.
        result=pack({'size':[32,32],'padding_px':2,'charts':[rect('a',10,20,5,3)]},1,2)
        self.assertEqual(set(result),{'scale','step_px','quarter_turns','transforms','spec','qa'})
        self.assertEqual(result['transforms']['a']['linear'],[[1.,0.],[0.,1.]])
        self.assertEqual(result['transforms']['a']['translation'],[2+math.sqrt(2)-10,2+math.sqrt(2)-20])
        self.assertEqual(result['qa'],{'errors':[],'minimum_gap_px':None,'gap_required':4,'border_required':2})

    def test_valid_pinned_slot_identity_and_source_unchanged(self):
        spec=self.specimen();before=json.dumps(spec,sort_keys=True);result=pack(spec,1,1,True)
        self.assertIsNotNone(result);self.assertFalse(result['qa']['errors'])
        self.assertEqual(before,json.dumps(spec,sort_keys=True))
        self.assertEqual(result['spec']['obstacles'],spec['obstacles'])
        encoded=json.dumps(spec['obstacles'],sort_keys=True,separators=(',',':')).encode()
        self.assertEqual(result['protected']['sha256'],hashlib.sha256(encoded).hexdigest())
        self.assertEqual(result['protected']['count'],1)
        shape=shape_for(result['spec']['charts'][0]);obstacle=shape_for(spec['obstacles'][0])
        self.assertGreaterEqual(shape.distance(obstacle),4-1e-5)
        A=np.array(result['transforms']['moving']['linear'])
        np.testing.assert_allclose(A.T@A,np.eye(2));self.assertAlmostEqual(np.linalg.det(A),1)
        result['spec']['obstacles'][0]['polygons'][0][0][0]=999
        self.assertEqual(before,json.dumps(spec,sort_keys=True))

    def test_fully_blocked_refuses(self):
        spec=self.specimen();spec['obstacles']=[rect('page',0,0,48,32)]
        self.assertIsNone(pack(spec,1,1))

    def test_exact_gap_rejects_insufficient_padding(self):
        spec=self.specimen();spec['charts']=[rect('moving',18,8,6,6)]
        self.assertTrue(any(e[0]=='obstacle_gap' for e in validate(spec,4,2)['errors']))
        spec['charts']=[rect('moving',20,8,6,6)]
        self.assertFalse(validate(spec,4,2)['errors'])

    def test_positive_overlap_rejected_with_zero_padding(self):
        spec=self.specimen();spec['padding_px']=0;spec['charts']=[rect('moving',10,8,6,6)]
        self.assertGreater(shape_for(spec['charts'][0]).intersection(shape_for(spec['obstacles'][0])).area,0)
        self.assertTrue(validate(spec,0,0)['errors'])

    def test_exact_check_rejects_false_raster_clearance(self):
        spec=self.specimen();spec['obstacles']=[rect('page',0,0,48,32)]
        # Force the raster to miss every protected/candidate sample. Geometry
        # still blocks every proposal; a raster-only implementation would pass.
        def empty(shape,x,y):return np.zeros(np.broadcast_shapes(x.shape,y.shape),dtype=bool)
        with patch('pack_masks.intersects_xy',side_effect=empty):
            self.assertIsNone(pack(spec,1,4))

    def test_fixed_readers_may_touch_page_border(self):
        spec=self.specimen();spec['charts']=[rect('moving',22,8,6,6)]
        self.assertFalse(validate(spec,4,2)['errors'])

    def test_degenerate_and_unrepresentable_readers_fail_closed(self):
        fixtures=[{'id':'point','polygons':[[[2,2],[2,2],[2,2]]]},
                  {'id':'line','polygons':[[[2,2],[3,3],[4,4]]]},
                  {'id':'explicit-line','lines':[[[0,0],[1,1]]],'polygons':rect('x',0,0,4,4)['polygons']},
                  {'id':'mixed','polygons':rect('x',0,0,4,4)['polygons']+[[[2,2],[3,3],[4,4]]]},
                  {'id':'empty','polygons':[]},rect('outside',-1,0,4,4),
                  {'id':'nonfinite','polygons':[[[0,0],[float('nan'),1],[2,0]]]}]
        for obstacle in fixtures:
            with self.subTest(obstacle=obstacle['id']):
                spec=self.specimen();spec['obstacles']=[obstacle]
                with self.assertRaises(ValueError):pack(spec,1)

    def test_opt_in_does_not_allow_scaling(self):
        with self.assertRaisesRegex(ValueError,'scale=1'):pack(self.specimen(),.9)

    def test_duplicate_protected_identity_refused(self):
        spec=self.specimen();spec['obstacles'].append(copy.deepcopy(spec['obstacles'][0]))
        with self.assertRaisesRegex(ValueError,'Duplicate'):pack(spec,1)

    def test_duplicate_movable_transform_keys_refused(self):
        spec=self.specimen();spec['charts']=[rect(1,0,0,4,4),rect('1',0,0,6,6)]
        with self.assertRaisesRegex(ValueError,'Duplicate movable'):pack(spec,1)

    def test_movable_and_protected_ids_are_separate_namespaces(self):
        spec=self.specimen();spec['charts'][0]['id']='wall'
        result=pack(spec,1,1);self.assertIsNotNone(result)
        self.assertEqual(set(result['transforms']),{'wall'})
        self.assertEqual(result['protected']['obstacles'][0]['id'],'wall')
        self.assertGreaterEqual(shape_for(result['spec']['charts'][0]).distance(shape_for(spec['obstacles'][0])),4-1e-5)
        self.assertFalse(result['qa']['errors'])

if __name__=='__main__':unittest.main()
