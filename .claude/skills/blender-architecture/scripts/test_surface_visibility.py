import unittest
import numpy as np
from surface_visibility import (camera_cone_max_dot, convex_render_shell,
    strictly_inside, persistent_burial_mask, mesh_components)


def cube():
    p = np.array([[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1],
                  [-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]], float)
    f = np.array([[0,2,1],[0,3,2],[4,5,6],[4,6,7],[0,1,5],[0,5,4],
                  [1,2,6],[1,6,5],[2,3,7],[2,7,6],[3,0,4],[3,4,7]])
    return p[f]


class VisibilityTests(unittest.TestCase):
    def test_all_compass_sides_are_visible(self):
        r = camera_cone_max_dot([[1,0,0],[-1,0,0],[0,1,0],[0,-1,0]])
        np.testing.assert_allclose(r, np.cos(np.radians(30)))

    def test_down_and_sloping_soffit(self):
        r = camera_cone_max_dot([[0,0,-1],[.8,0,-.6],[0,0,1]])
        self.assertLess(r[0], 0)
        self.assertGreater(r[1], 0)
        self.assertGreater(r[2], 0)

    def test_analytic_matches_dense_search(self):
        rng = np.random.default_rng(12)
        n = rng.normal(size=(30,3)); n /= np.linalg.norm(n,axis=1)[:,None]
        a,e = np.meshgrid(np.linspace(0,2*np.pi,721),np.radians(np.linspace(20,70,201)))
        v = np.stack([np.cos(e)*np.cos(a),np.cos(e)*np.sin(a),np.sin(e)],-1).reshape(-1,3)
        np.testing.assert_allclose(camera_cone_max_dot(n,20,70), (n@v.T).max(1), atol=2e-5)

    def test_unknown_normal_not_certified(self):
        self.assertTrue(np.isnan(camera_cone_max_dot([[0,0,0]])[0]))

    def test_cube_containment_not_touching(self):
        planes = convex_render_shell(cube()); self.assertIsNotNone(planes)
        t = np.array([[[0,0,0],[.5,0,0],[0,.5,0]],
                      [[1,0,0],[1,.5,0],[1,0,.5]]])
        np.testing.assert_array_equal(strictly_inside(t,planes),[True,False])

    def test_open_or_inverted_shell_rejected(self):
        self.assertIsNone(convex_render_shell(cube()[:-1]))
        self.assertIsNone(convex_render_shell(cube()[:,::-1]))

    def test_concave_shell_rejected(self):
        t = cube(); t[np.all(t==[1,1,1],axis=-1)] = [0,0,0]
        self.assertIsNone(convex_render_shell(t))

    def test_damage_neighbor_alpha_and_deleted_occluder_protected(self):
        t=cube()*.2; planes=convex_render_shell(cube())
        for flags in [(False,True,True),(True,False,True),(True,True,False)]:
            self.assertFalse(persistent_burial_mask(t,planes,opaque=flags[0],
                same_rigid_motion=flags[1],shell_retained=flags[2]).any())

    def test_uv_split_does_not_make_boundary(self):
        _,edges,_ = mesh_components(cube())
        self.assertTrue(all(len(f)==2 for f in edges.values()))


if __name__ == '__main__':
    unittest.main()
