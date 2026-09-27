import unittest
import itertools
import numpy as np
from shapely.geometry import Polygon
from overlap_geometry import overlap_pairs,repair_plan,positive_box_overlaps,frame,transverse_pairs

def face(points,n,i=0,**kw):
    axes=frame(points,n)[2]
    return dict(id=i,points=points,normal=n,area=Polygon(np.array(points)[:,axes]).area/max(abs(np.array(n))),**kw)

def box_faces(lo,hi,start=0):
    out=[]
    for axis,sgn in itertools.product(range(3),[-1,1]):
        other=[a for a in range(3) if a!=axis];p=[];n=np.zeros(3);n[axis]=sgn
        for u,v in [(0,0),(1,0),(1,1),(0,1)]:
            x=np.zeros(3);x[axis]=(lo if sgn<0 else hi)[axis];x[other[0]]=(lo,hi)[u][other[0]];x[other[1]]=(lo,hi)[v][other[1]];p.append(x)
        if np.cross(p[1]-p[0],p[2]-p[0])@n<0:p=p[::-1]
        out.append(face(np.array(p).tolist(),n.tolist(),start+len(out)))
    return out

def apply(records,plan):
    changes={p['index']:p for p in plan['plans']};out=[]
    for i,r in enumerate(records):
        if i in changes:
            out.extend(dict(r,points=p) for p in changes[i]['polygons'])
        else:out.append(r)
    return out

class GeometryTests(unittest.TestCase):
    def test_transverse_intersection_and_shared_edge(self):
        a=face([[-1,-1,0],[1,-1,0],[1,1,0],[-1,1,0]],[0,0,1])
        b=face([[0,-1,-1],[0,1,-1],[0,1,1],[0,-1,1]],[1,0,0],1)
        def measure(rows):
            ts=[];ids=[]
            for i,r in enumerate(rows):
                p=np.array(r['points'])
                ts.extend([p[[0,1,2]],p[[0,2,3]]]);ids.extend([i,i])
            return transverse_pairs(ts,ids,itertools.combinations(range(len(ts)),2),rows)
        self.assertEqual(len(measure([a,b])),1)
        self.assertAlmostEqual(measure([a,b])[0]['midpoint'][0],0)
        # A proper joint at the boundary is not an intersecting surface.
        b['points']=(np.array(b['points'])+[1,0,0]).tolist()
        self.assertEqual(measure([a,b]),[])

    def test_partial_coplanar_and_edge_only(self):
        a=face([[0,0,0],[2,0,0],[2,2,0],[0,2,0]],[0,0,1]);b=face([[1,0,0],[3,0,0],[3,2,0],[1,2,0]],[0,0,1],1)
        self.assertAlmostEqual(overlap_pairs([a,b])['pairs'][0]['area'],2)
        fixed=apply([a,b],repair_plan([a,b]));self.assertEqual(len(overlap_pairs(fixed)['pairs']),0)
        self.assertAlmostEqual(sum(Polygon(np.array(f['points'])[:,:2]).area for f in fixed),6)
        b['points']=[[2,0,0],[3,0,0],[3,2,0],[2,2,0]];self.assertEqual(overlap_pairs([a,b])['pairs'],[])

    def test_volume_overlap_union_boundary(self):
        boxes=[dict(id=0,lo=[0,0,0],hi=[1,1,1]),dict(id=1,lo=[.5,0,0],hi=[1.5,1,1])]
        records=box_faces(boxes[0]['lo'],boxes[0]['hi'])+box_faces(boxes[1]['lo'],boxes[1]['hi'],6)
        self.assertAlmostEqual(positive_box_overlaps(boxes)[0]['volume'],.5)
        fixed=apply(records,repair_plan(records,boxes));self.assertEqual(overlap_pairs(fixed)['pairs'],[])
        area=sum(Polygon(np.array(f['points'])[:,frame(f['points'],f['normal'])[2]]).area for f in fixed)
        self.assertAlmostEqual(area,8)
        self.assertTrue(all(len(f['points'])>=4 for f in fixed))
        self.assertEqual(repair_plan(fixed,boxes)['plans'],[])

    def test_opposed_unknown_is_report_only(self):
        a=face([[0,0,0],[1,0,0],[1,1,0],[0,1,0]],[0,0,1]);b=dict(a,id=1,normal=[0,0,-1],points=a['points'][::-1])
        plan=repair_plan([a,b]);self.assertEqual(plan['plans'],[]);self.assertEqual(len(plan['opposing_owner_candidates']),1)

    def test_alpha_receiver_is_not_cut(self):
        a=face([[0,0,0],[1,0,0],[1,1,0],[0,1,0]],[0,0,1],alpha=True)
        b=dict(id=0,lo=[-1,-1,-1],hi=[2,2,1]);self.assertEqual(repair_plan([a],[b])['plans'],[])

    def test_slanted_plane(self):
        a=face([[0,0,0],[2,0,0],[2,2,0],[0,2,0]],[0,0,1]);b=dict(a,id=1)
        theta=.731;rot=np.array([[1,0,0],[0,np.cos(theta),-np.sin(theta)],[0,np.sin(theta),np.cos(theta)]])
        for f in [a,b]:f['points']=(np.array(f['points'])@rot.T+np.array([8,-2,3])).tolist();f['normal']=(rot@np.array(f['normal'])).tolist()
        self.assertAlmostEqual(overlap_pairs([a,b])['pairs'][0]['area'],4)

    def test_hole_partition_keeps_quad_ngon_contract(self):
        a=face([[0,0,0],[4,0,0],[4,4,0],[0,4,0]],[0,0,1]);box=dict(id=0,lo=[1,1,-1],hi=[3,3,1])
        fixed=apply([a],repair_plan([a],[box]));self.assertTrue(all(len(f['points'])>=4 for f in fixed))
        self.assertAlmostEqual(sum(Polygon(np.array(f['points'])[:,:2]).area for f in fixed),12)

    def test_containment_volume_without_crossing(self):
        b=[dict(id=0,lo=[0,0,0],hi=[3,3,3]),dict(id=1,lo=[1,1,1],hi=[2,2,2])]
        self.assertEqual(positive_box_overlaps(b)[0]['volume'],1)
        self.assertEqual(overlap_pairs(box_faces(b[0]['lo'],b[0]['hi'])+box_faces(b[1]['lo'],b[1]['hi'],6))['pairs'],[])

if __name__=='__main__':unittest.main()
