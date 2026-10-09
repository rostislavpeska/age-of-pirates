import unittest
from beam_contact import certify_box,contact

def box(lo,hi):
    v=[[lo[0],lo[1],lo[2]],[hi[0],lo[1],lo[2]],
       [hi[0],hi[1],lo[2]],[lo[0],hi[1],lo[2]],
       [lo[0],lo[1],hi[2]],[hi[0],lo[1],hi[2]],
       [hi[0],hi[1],hi[2]],[lo[0],hi[1],hi[2]]]
    f=[[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]
    return v,f

class ContactTests(unittest.TestCase):
    def test_closed_supported_and_real_gap(self):
        b=certify_box(*box([0,0,0],[1,.03,.03]))
        self.assertEqual(contact(b,certify_box(*box([1,-.1,-.1],[1.1,.1,.1])),0,1)['status'],'PASS')
        self.assertEqual(contact(b,certify_box(*box([1.0125,-.1,-.1],[1.1,.1,.1])),0,1)['status'],'FAIL')
    def test_edge_only_support_and_penetration_fail(self):
        b=certify_box(*box([0,0,0],[.03,.03,1]))
        self.assertEqual(contact(b,certify_box(*box([0,.03,-.1],[.03,.06,0])),2,-1)['support_coverage'],0)
        self.assertEqual(contact(b,certify_box(*box([0,.03,-.1],[.03,.06,0])),2,-1)['status'],'FAIL')
        self.assertEqual(contact(b,certify_box(*box([0,0,-.1],[.03,.03,.02])),2,-1)['status'],'FAIL')
    def test_missing_cap_slanted_crossed_unknown(self):
        v,f=box([0,0,0],[1,1,1])
        self.assertIsNone(certify_box(v,f[:-1]))
        bad=[p[:] for p in v];bad[0][0]=.2
        self.assertIsNone(certify_box(bad,f))
        f[0]=[0,2,3,1]
        self.assertIsNone(certify_box(v,f))
        self.assertEqual(contact(None,([0,0,0],[1,1,1]),0,1)['status'],'INCONCLUSIVE')

if __name__=='__main__':unittest.main()
