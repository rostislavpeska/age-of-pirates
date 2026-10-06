import unittest
import numpy as np
from geometry_share import group_charts


def chart(name,points=None,uv=None,material='wood'):
    return dict(id=name,page='A',faces=[dict(id=0,material=material,
        points=points or [[0,0,0],[2,0,0],[2,1,0],[0,1,0]],
        uv=uv or [[0,0],[20,0],[20,10],[0,10]],normal=[0,0,1])])


class SharingTests(unittest.TestCase):
    def test_rigid_translated_and_rotated_chart(self):
        a=chart('a');b=chart('b',points=[[5,3,1],[5,5,1],[4,5,1],[4,3,1]],uv=[[80,20],[80,40],[70,40],[70,20]])
        out=group_charts([a,b]);self.assertEqual(len(out['groups']),1)
        self.assertLess(out['groups'][0]['members'][0]['position_error'],1e-8)
        self.assertFalse(out['ao_tested']);self.assertFalse(out['packing_performed'])

    def test_same_uv_different_geometry_is_rejected(self):
        a=chart('a');b=chart('b',points=[[0,0,0],[3,0,0],[3,1,0],[0,1,0]])
        self.assertEqual(len(group_charts([a,b])['groups']),2)

    def test_different_material_is_not_shared(self):
        self.assertEqual(len(group_charts([chart('a'),chart('b',material='stone')])['groups']),2)

    def test_changed_existing_uv_scale_stays_unique(self):
        b=chart('b',uv=[[0,0],[40,0],[40,20],[0,20]])
        self.assertEqual(len(group_charts([chart('a'),b])['groups']),2)

    def test_mirror_is_recorded(self):
        a=chart('a',points=[[0,0,0],[2,0,0],[1.5,1,0],[0,1,0]],uv=[[0,0],[20,0],[15,10],[0,10]])
        b=chart('b',points=[[0,0,0],[-2,0,0],[-1.5,1,0],[0,1,0]],uv=[[20,0],[0,0],[5,10],[20,10]])
        g=group_charts([a,b])['groups'];self.assertEqual(len(g),1)
        self.assertTrue(g[0]['members'][0]['uv_reflection'])

    def test_relief_not_certified_by_flat_uv(self):
        b=chart('b',points=[[0,0,0],[2,0,0],[2,1,.1],[0,1,0]])
        self.assertEqual(len(group_charts([chart('a'),b])['groups']),2)

    def test_no_input_mutation_or_triangle_conversion(self):
        a=chart('a');b=chart('b');old=repr([a,b]);group_charts([a,b])
        self.assertEqual(repr([a,b]),old);self.assertEqual(len(a['faces'][0]['points']),4)

    def test_same_vertices_different_boundary_is_rejected(self):
        a=chart('a');b=chart('b',uv=[[0,0],[20,10],[20,0],[0,10]],points=[[0,0,0],[2,1,0],[2,0,0],[0,1,0]])
        self.assertEqual(len(group_charts([a,b])['groups']),2)

    def test_rounding_boundary_does_not_hide_mirrored_geometry(self):
        a=chart('a',points=[[0,0,0],[2,0,0],[1.5,1,0],[0,1,0]],
                uv=[[0,0],[20.0049,0],[15,10],[0,10]])
        b=chart('b',points=[[0,0,0],[-2,0,0],[-1.5,1,0],[0,1,0]],
                uv=[[20.0051,0],[0,0],[5.0051,10],[20.0051,10]])
        out=group_charts([a,b]);self.assertEqual(len(out['groups']),1)
        self.assertFalse(out['uv_hash_used'])

    def test_arbitrary_uv_rotation_is_not_a_geometry_veto(self):
        a=chart('a');angle=.321;r=np.array([[np.cos(angle),-np.sin(angle)],[np.sin(angle),np.cos(angle)]])
        b=chart('b',uv=(np.array(a['faces'][0]['uv'])@r.T+[80,25]).tolist())
        self.assertEqual(len(group_charts([a,b])['groups']),1)

    def test_shape_changes_in_uv_can_share_when_face_density_matches(self):
        # Equal area, different parameterization. The existing clean owner's
        # coordinates are transferred; no geometric scale fit is permitted.
        b=chart('b',uv=[[0,0],[20,0],[24,10],[4,10]])
        group=group_charts([chart('a'),b])['groups'];self.assertEqual(len(group),1)
        self.assertTrue(group[0]['members'][0]['uv_layout_differs'])

    def test_material_pattern_and_face_correspondence_are_preserved(self):
        a=chart('a');a['faces'].append(dict(id=1,material='paper',points=[[2,0,0],[3,0,0],[3,1,0],[2,1,0]],uv=[[20,0],[30,0],[30,10],[20,10]],normal=[0,0,1]))
        import copy
        b=copy.deepcopy(a);b['id']='b';b['faces'].reverse()
        for f in b['faces']:
            f['id']+=10;f['points']=[[-p[0]+10,p[1]+2,p[2]] for p in f['points']]
        g=group_charts([a,b])['groups'];self.assertEqual(len(g),1)
        pairs=g[0]['members'][0]['loop_correspondence'];self.assertEqual(len(pairs),8)
        self.assertEqual({(p['owner_face'],p['member_face']) for p in pairs},{(0,10),(1,11)})

    def test_near_but_bent_geometry_is_not_accepted_by_density(self):
        b=chart('b',points=[[0,0,0],[2,0,0],[2,1,.003],[0,1,0]])
        self.assertEqual(len(group_charts([chart('a'),b])['groups']),2)

    def test_coincident_duplicate_geometry_is_reported(self):
        import copy
        a=chart('a');other=copy.deepcopy(a['faces'][0]);other['id']=1
        other['uv']=(np.array(other['uv'])+[30,0]).tolist();a['faces'].append(other)
        out=group_charts([a]);self.assertEqual(len(out['unmatched']),1)

    def test_curved_multi_face_roof_recovers_every_mirrored_quad(self):
        import copy
        a=dict(id='a',page='A',faces=[])
        for y in range(3):
            for x in range(4):
                pts=[[xx,yy,.08*yy*yy] for xx,yy in [(x,y),(x+1,y),(x+1,y+1),(x,y+1)]]
                normal=np.cross(np.subtract(pts[1],pts[0]),np.subtract(pts[3],pts[0]));normal/=np.linalg.norm(normal)
                a['faces'].append(dict(id=y*4+x,material='roof',points=pts,normal=normal.tolist(),uv=[[p[0]*50,p[1]*50] for p in pts]))
        b=copy.deepcopy(a);b['id']='b';r=np.diag([1,-1,1])
        for f in b['faces']:
            f['id']+=100;f['points']=(np.array(f['points'])@r+[7,9,2]).tolist();f['normal']=(r@np.array(f['normal'])).tolist()
            f['uv']=[[u+301+v*.00005,v+201] for u,v in f['uv']]
        b['faces'].reverse();out=group_charts([a,b]);self.assertEqual(len(out['groups']),1)
        self.assertEqual(len(out['groups'][0]['members'][0]['loop_correspondence']),48)

    def test_larger_owner_and_complete_corner_transfer(self):
        from geometry_share import transfer_corresponding_uv
        a=chart('a');b=chart('b',uv=[[0,0],[20.016,0],[20.016,10.008],[0,10.008]])
        group=group_charts([a,b],prefer_larger_uv_owner=True)['groups'][0]
        self.assertEqual(group['owner'],'b')
        match=group['members'][0];out=transfer_corresponding_uv(b,a,match)
        self.assertEqual(set(out),{f['id'] for f in a['faces']})
        self.assertEqual(sorted(map(tuple,out[0])),sorted(map(tuple,b['faces'][0]['uv'])))
        broken=dict(match,loop_correspondence=match['loop_correspondence'][:-1])
        with self.assertRaises(ValueError):transfer_corresponding_uv(b,a,broken)
        broken=dict(match,loop_correspondence=match['loop_correspondence']+[match['loop_correspondence'][0]])
        with self.assertRaises(ValueError):transfer_corresponding_uv(b,a,broken)

if __name__=='__main__':unittest.main()
