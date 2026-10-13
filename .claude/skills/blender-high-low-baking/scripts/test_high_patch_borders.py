import unittest
from high_patch_borders import edge_inventory,padding

class Borders(unittest.TestCase):
    def test_shared_boundary_has_no_overlap(self):
        a=[(0,0,0),(1,0,0),(1,1,0),(0,1,0)]
        b=[(1,0,0),(2,0,0),(2,1,0),(1,1,0)]
        e=edge_inventory([a,b]);pa=padding(a,e,.035);pb=padding(b,e,.035)
        self.assertEqual(pa,(.035,0,.035,.035));self.assertEqual(pb,(0,.035,.035,.035))
        self.assertEqual(1+pa[1],1-pb[0])
        self.assertGreater((1+.035)-(1-.035),0) # Negative control: old 70mm overlap.

    def test_curved_row_topology(self):
        a=[(0,0,0),(1,0,0),(1,1,.3),(0,1,.3)]
        b=[(0,1,.3),(1,1,.3),(1,2,.8),(0,2,.8)]
        e=edge_inventory([a,b]);self.assertEqual(padding(a,e,.035)[3],0);self.assertEqual(padding(b,e,.035)[2],0)

    def test_nonmanifold_rejected(self):
        q=[(0,0,0),(1,0,0),(1,1,0),(0,1,0)]
        with self.assertRaises(ValueError):edge_inventory([q,q,q])

if __name__=='__main__':unittest.main()
