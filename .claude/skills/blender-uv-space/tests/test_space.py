import sys,unittest,copy
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from pixel_audit import audit
from pack_masks import pack,validate

def rect(id,x,y,w,h):return {'id':id,'polygons':[[[x,y],[x+w,y],[x+w,y+h],[x,y+h]]]}

class SpaceSmoke(unittest.TestCase):
    def test_exact_pixel_partition_and_overlap(self):
        d={'size':[16,16],'padding_px':1,'charts':[rect('a',2,2,4,4)]}
        r,_=audit(d);self.assertEqual((r['content_pixels'],r['padding_pixels'],r['unallocated_pixels']),(16,20,220))
        d['charts'].append(rect('b',4,2,4,4));r,_=audit(d);self.assertEqual(r['cross_owner_overlap_pixels'],8)
    def test_hollow_chart_does_not_count_its_box(self):
        c=rect('frame',2,2,12,2);c['polygons']+=rect('x',2,4,2,10)['polygons']
        r,_=audit({'size':[16,16],'padding_px':0,'charts':[c]});self.assertEqual(r['content_pixels'],44)
        self.assertEqual(r['largest_empty_envelopes'][0]['envelope_void'],100)
    def test_preserves_disconnected_owner_and_exact_margin(self):
        c=rect('group',0,0,5,5);c['polygons']+=rect('ignored',12,0,5,5)['polygons']
        d={'size':[64,64],'padding_px':2,'charts':[c,rect('b',0,0,14,7)]}
        p=pack(d,1,2,True);self.assertIsNotNone(p);self.assertFalse(p['qa']['errors']);self.assertEqual(len(p['spec']['charts'][0]['polygons']),2)
        self.assertEqual(p['scale'],1);self.assertEqual(set(p['transforms']),{'group','b'})
    def test_gap_and_bounds_reject(self):
        r=validate({'size':[16,16],'charts':[rect('a',0,0,4,4),rect('b',3,0,4,4)]},2,1)
        self.assertTrue(any(e[0]=='gap' for e in r['errors']));self.assertTrue(any(e[0]=='border' for e in r['errors']))

if __name__=='__main__':unittest.main()
