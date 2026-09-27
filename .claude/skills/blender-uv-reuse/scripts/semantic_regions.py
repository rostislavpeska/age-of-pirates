"""Refine a composite chart at explicit material boundaries, never face scraps.

The caller supplies approved panel materials. Whole connected planar regions
become reusable units; the remaining facade frame stays one inherited chart.
No UV coordinates, topology or geometry are changed by this discovery helper.
"""
import copy
import numpy as np
from shapely.geometry import Polygon


def refine(chart, panel_materials, plane_tolerance=2e-5, adjacency_tolerance=1e-6):
    faces=chart['faces'];candidates=[f for f in faces if f['material'] in panel_materials]
    remaining=[f for f in faces if f['material'] not in panel_materials]
    parent={f['id']:f['id'] for f in candidates}
    def root(i):
        while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
        return i
    for k,a in enumerate(candidates):
        pts=np.asarray(a['points']);center=pts.mean(0);_,_,vh=np.linalg.svd(pts-center,full_matrices=False);basis=vh[:2].T;poly=Polygon((pts-center)@basis)
        for b in candidates[k+1:]:
            if a['material']!=b['material'] or np.dot(a['normal'],b['normal'])<.99999:continue
            q=np.asarray(b['points'])-center
            if abs(q@vh[2]).max()>plane_tolerance:continue
            other=Polygon(q@basis)
            # Positive common boundary length, not a single point contact.
            near=poly.boundary.intersection(other.boundary.buffer(adjacency_tolerance))
            if near.length>adjacency_tolerance*8:
                parent[root(b['id'])]=root(a['id'])
    components={}
    for f in candidates:components.setdefault(root(f['id']),[]).append(f)
    result=[]
    if remaining:result.append(dict(chart,id=chart['id'],faces=copy.deepcopy(remaining),semantic_region='retained_frame'))
    for _,rows in sorted(components.items()):
        ids=sorted(f['id'] for f in rows);name=chart['id']+'::Panel_'+str(ids[0])
        result.append(dict(chart,id=name,faces=copy.deepcopy(rows),parent_chart=chart['id'],semantic_region=rows[0]['material'],source_face_ids=ids))
    return result
