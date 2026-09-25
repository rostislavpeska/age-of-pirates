import unittest
from uv_metrics import triangle_metrics, density_summary, pack_rectangles


class MetricsTests(unittest.TestCase):
    def test_isotropic_and_rectangular_image(self):
        r = triangle_metrics([[0,0,0],[2,0,0],[0,2,0]], [[0,0],[.25,0],[0,.5]], [1024,512])
        self.assertAlmostEqual(r['low'],128)
        self.assertAlmostEqual(r['high'],128)

    def test_area_density_hides_one_axis_stretch(self):
        r = triangle_metrics([[0,0,0],[1,0,0],[0,1,0]], [[0,0],[.25,0],[0,.0625]], [1024,1024])
        self.assertAlmostEqual(r['equivalent'],128)
        self.assertEqual(density_summary([r],128)['failing_triangles'],[0])

    def test_world_scale_and_mirror(self):
        r = triangle_metrics([[0,0,0],[2,0,0],[0,2,0]], [[0,0],[-.25,0],[0,.25]], [1024,1024])
        self.assertEqual(r['low'],128)
        self.assertTrue(r['mirrored'])

    def test_degenerate_rejected(self):
        with self.assertRaises(ValueError):
            triangle_metrics([[0,0,0],[1,0,0],[0,1,0]], [[0,0],[0,0],[0,0]], [1024,1024])

    def test_padding_and_pages_do_not_overlap(self):
        p=pack_rectangles([(i,30+i%4,15+i%3) for i in range(24)],128,4,4)
        for i,a in p.items():
            x,y,r,t=a['padded_bounds'];self.assertTrue(0<=x<r<=128 and 0<=y<t<=128)
            for j,b in p.items():
                if j<=i or a['page']!=b['page']:continue
                u,v,s,w=b['padded_bounds'];self.assertFalse(min(r,s)>max(x,u) and min(t,w)>max(y,v))

    def test_budget_failure_never_rescales(self):
        with self.assertRaises(ValueError):pack_rectangles([('a',90,90),('b',90,90)],100,2,1)

    def test_exact_full_page_is_not_reopened(self):
        p=pack_rectangles([('a',96,96),('b',20,20)],100,2,2)
        self.assertNotEqual(p['a']['page'],p['b']['page'])


if __name__=='__main__':unittest.main()
