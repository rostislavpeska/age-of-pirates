import copy,unittest
import numpy as np
from planar_share import prepare,match,image_comparison

def grid(name,xs=(0,1),ys=(0,1),material='WOOD',uv_scale=256):
    faces=[]
    for x,X in zip(xs[:-1],xs[1:]):
        for y,Y in zip(ys[:-1],ys[1:]):
            pts=np.array([[x,y,0],[X,y,0],[X,Y,0],[x,Y,0]],float)
            faces.append(dict(id=len(faces),points=pts.tolist(),uv=(pts[:,:2]*uv_scale+500).tolist(),normal=[0,0,1],material=material))
    return dict(id=name,page='A',faces=faces)

class PlanarShareTests(unittest.TestCase):
    def test_different_internal_edges_match_whole_surface(self):
        a=grid('a');b=grid('b',(0,.3,.6,1),(0,.2,1));m=match(prepare(a),prepare(b))
        self.assertIsNotNone(m);self.assertEqual(m['member_face_count'],6)
        self.assertEqual(m['image_metrics']['min_iou'],1)
    def test_input_not_changed(self):
        a=grid('a');b=grid('b',(0,.5,1));old=copy.deepcopy((a,b));match(prepare(a),prepare(b));self.assertEqual((a,b),old)
    def test_rotated_translated_reflected_world_surface(self):
        a=grid('a',(0,2),(0,1));b=grid('b',(0,.5,2),(0,1))
        r=np.array([[-1,0,0],[0,0,-1],[0,1,0]],float)
        for f in b['faces']:
            f['points']=(np.asarray(f['points'])@r.T+[4,8,2]).tolist()
            f['normal']=(r@np.asarray(f['normal'])).tolist()
        m=match(prepare(a),prepare(b));self.assertIsNotNone(m)
        self.assertAlmostEqual(abs(m['world_determinant']),1)
        self.assertLess(m['max_density_relative_error'],1e-9)
    def test_hole_rejected(self):
        a=grid('a');b=grid('b',(0,.3,.6,1),(0,.3,.6,1));b['faces'].pop(4)
        self.assertIsNone(match(prepare(a),prepare(b)))
    def test_material_spatial_pattern(self):
        a=grid('a',(0,.25,1));b=grid('b',(0,.75,1))
        a['faces'][0]['material']='STONE';b['faces'][0]['material']='STONE'
        self.assertIsNone(match(prepare(a),prepare(b)))
    def test_changed_density_rejected(self):
        self.assertIsNone(match(prepare(grid('a')),prepare(grid('b',uv_scale=260))))
    def test_two_axis_density_not_only_area(self):
        a=grid('a');b=grid('b')
        for f in b['faces']:f['uv']=(np.asarray(f['uv'])*[2,.5]).tolist()
        self.assertIsNone(match(prepare(a),prepare(b)))
    def test_nonplanar_rejected(self):
        b=grid('b');b['faces'][0]['points'][0][2]=.01;self.assertIsNone(prepare(b))
    def test_nonaffine_uv_rejected(self):
        b=grid('b');b['faces'][0]['uv'][0][0]+=8;self.assertIsNone(prepare(b))
    def test_duplicate_face_rejected(self):
        b=grid('b');b['faces']+=copy.deepcopy(b['faces']);self.assertIsNone(prepare(b))
    def test_near_match_measured_not_exact(self):
        a=prepare(grid('a'));b=prepare(grid('b',(0,1.0005)))
        self.assertIsNone(match(a,b))
        m=match(a,b,relative=.0025);self.assertIsNotNone(m);self.assertGreater(m['hausdorff_estimate'],0)
    def test_raster_float_roundoff_does_not_shift_whole_edge(self):
        from shapely.affinity import translate
        a=prepare(grid('a'));regs={m:translate(g,xoff=-1e-15) for m,g in a['regions'].items()}
        self.assertEqual(image_comparison(a,regs)['min_iou'],1)

if __name__=='__main__':unittest.main()
