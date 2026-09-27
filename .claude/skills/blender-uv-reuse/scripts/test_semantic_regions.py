import copy,unittest
from semantic_regions import refine
from test_planar_share import grid

class SemanticRegionTests(unittest.TestCase):
    def test_adjacent_panel_quads_remain_one_region(self):
        c=grid('facade',(0,.5,1));self.assertEqual(len(refine(c,{'WOOD'})),1)
        self.assertEqual(len(refine(c,{'WOOD'})[0]['faces']),2)
    def test_material_boundary_keeps_frame(self):
        c=grid('facade',(0,.4,.6,1));c['faces'][0]['material']='PLASTER';c['faces'][2]['material']='PLASTER'
        old=copy.deepcopy(c);out=refine(c,{'PLASTER'});self.assertEqual(c,old);self.assertEqual(len(out),3)
        self.assertEqual(out[0]['id'],'facade');self.assertEqual(out[0]['faces'][0]['material'],'WOOD')
    def test_corner_contact_does_not_join_panels(self):
        c=grid('facade',(0,1,2),(0,1,2));c['faces']=[c['faces'][0],c['faces'][3]]
        self.assertEqual(len(refine(c,{'WOOD'})),2)
    def test_non_coplanar_regions_not_joined(self):
        c=grid('facade',(0,.5,1));c['faces'][1]['normal']=[1,0,0]
        self.assertEqual(len(refine(c,{'WOOD'})),2)

if __name__=='__main__':unittest.main()
