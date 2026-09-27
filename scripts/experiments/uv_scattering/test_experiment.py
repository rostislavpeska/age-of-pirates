import unittest
import numpy as np
from experiment import adjacency, islands, merge_experiment, metrics, native_edges

def face(i, points, uv, normal=(0,0,1), part='wall'):
    return dict(id=i,points=points,uv=uv,normal=normal,part=part,
                page='A',physical_family=1,hidden=False,triangles=[[0,1,2],[0,2,3]])

def pair():
    return [face(0,[(0,0,0),(1,0,0),(1,1,0),(0,1,0)],[(0,0),(1,0),(1,1),(0,1)]),
            face(1,[(1,0,0),(2,0,0),(2,1,0),(1,1,0)],[(3,0),(4,0),(4,1),(3,1)])]

class RegressionTests(unittest.TestCase):
    def test_split_vertex_planar_join(self):
        f=pair();e,_=adjacency(f);u,d=merge_experiment(f,e)
        self.assertEqual(len(e),1);self.assertEqual(len(islands(f,e,u)),1)
        self.assertEqual(metrics(f,e,u)['intra_chart_overlap_pairs'],0)

    def test_point_contact_is_not_edge(self):
        f=pair();f[1]['points']=(np.array(f[1]['points'])+[0,1,0]).tolist()
        self.assertEqual(adjacency(f)[0],[])

    def test_nearby_parallel_surface_is_not_adjacent(self):
        f=pair();f[1]['points']=(np.array(f[1]['points'])+[0,0,.0001]).tolist()
        self.assertEqual(adjacency(f)[0],[])

    def test_cross_part_contact_never_welded(self):
        f=pair();f[1]['part']='independent_frame'
        self.assertEqual(adjacency(f)[0],[])

    def test_same_side_uv_foldover_is_rejected(self):
        f=pair();f[1]['uv']=[(1,0),(0,0),(0,1),(1,1)]
        e,_=adjacency(f);u,d=merge_experiment(f,e)
        self.assertEqual(d['accepted_merges'],0)
        self.assertEqual(metrics(f,e,u)['intra_chart_overlap_pairs'],1)

    def test_density_mismatch_is_not_stretched(self):
        f=pair();f[1]['uv']=(np.array(f[1]['uv'])*2).tolist()
        e,_=adjacency(f);u,d=merge_experiment(f,e)
        self.assertEqual(d['accepted_merges'],0)

    def test_ambiguous_three_face_edge_is_rejected(self):
        f=pair();f.append(face(2,[(1,0,0),(1,0,1),(1,1,1),(1,1,0)],[(0,0),(1,0),(1,1),(0,1)],(-1,0,0)))
        e,info=adjacency(f);self.assertEqual(e,[]);self.assertGreater(info['ambiguous_half_edges'],0)

    def test_bent_strip_distinguishes_planar_from_unfolding(self):
        f=pair();theta=np.deg2rad(45)
        f[1]['points']=[(1,0,0),(1+np.cos(theta),0,np.sin(theta)),(1+np.cos(theta),1,np.sin(theta)),(1,1,0)]
        f[1]['normal']=(-np.sin(theta),0,np.cos(theta))
        e,_=adjacency(f)
        _,a=merge_experiment(f,e,1,'planar');uv,b=merge_experiment(f,e,65,'strip')
        self.assertEqual(a['accepted_merges'],0);self.assertEqual(b['accepted_merges'],1)
        self.assertEqual(metrics(f,e,uv)['intra_chart_overlap_pairs'],0)

    def test_uv_coincidence_does_not_prove_native_connectivity(self):
        f=pair()
        for i,x in enumerate(f):x['mesh']='same';x['mesh_vertices']=[4*i+j for j in range(4)]
        e,_=adjacency(f);uv,_=merge_experiment(f,e)
        self.assertEqual(len(islands(f,e,uv)),1)
        self.assertEqual(len(islands(f,native_edges(f,e),uv)),2)

    def test_corner_normal_gate_blocks_an_otherwise_valid_join(self):
        f=pair();f[0]['corner_normals']=[(0,0,1)]*4;f[1]['corner_normals']=[(0,1,0)]*4
        e,_=adjacency(f);uv,d=merge_experiment(f,e,100,'strip',protect_normals=True)
        self.assertEqual(d['accepted_merges'],0)
        self.assertEqual(d['rejections']['protected_corner_normal_seam'],1)

if __name__=='__main__':unittest.main()
