"""Planar overlap repair primitives. Python 3, NumPy, Shapely >=2.

No Blender mutation. Faces carry world points, geometric normal and stable id.
Box occluders must be certified from actual opaque retained render surfaces by
the caller; source AABBs or collision proxies alone are not certificates.
"""
import itertools
import numpy as np
from shapely import difference, intersection, union_all
from shapely.geometry import Polygon, LineString, Point
from shapely.ops import split


def frame(points, normal):
    n=np.asarray(normal,float);n=n/np.linalg.norm(n)
    axis=int(np.argmax(np.abs(n)));axes=[i for i in range(3) if i!=axis]
    return n,axis,axes,float(n@np.asarray(points[0]))


def lift(coords, basis):
    n,axis,axes,d=basis
    p=np.zeros((len(coords),3));p[:,axes]=coords
    p[:,axis]=(d-p@n)/n[axis]
    return p


def clean_ring(coords, tolerance=1e-8):
    p=[np.asarray(x,float) for x in coords]
    if len(p)>1 and np.linalg.norm(p[0]-p[-1])<tolerance:p.pop()
    changed=True
    while changed and len(p)>3:
        changed=False
        for i in range(len(p)):
            a=p[i]-p[i-1];b=p[(i+1)%len(p)]-p[i]
            if np.linalg.norm(a)<tolerance or (abs(a[0]*b[1]-a[1]*b[0])<tolerance*max(np.linalg.norm(a)+np.linalg.norm(b),1e-8) and a@b>=0):
                p.pop(i);changed=True;break
    return np.array(p)


def simple_pieces(geom, area_epsilon=1e-10):
    """Eliminate polygon holes with coherent straight cuts, not tessellation."""
    if geom.is_empty:return []
    if geom.geom_type!='Polygon':
        return [p for g in geom.geoms for p in simple_pieces(g,area_epsilon)] if hasattr(geom,'geoms') else []
    if geom.area<=area_epsilon:return []
    if not geom.interiors:return [clean_ring(geom.exterior.coords)]
    hole=Polygon(geom.interiors[0]);x=hole.representative_point().x
    lo=geom.bounds;pad=max(lo[2]-lo[0],lo[3]-lo[1],1)
    cut=split(geom,LineString([(x,lo[1]-pad),(x,lo[3]+pad)]))
    if len(cut.geoms)<2:raise ValueError('Hole partition failed; requires manual coherent cut')
    return [p for g in cut.geoms for p in simple_pieces(g,area_epsilon)]


def no_triangle_polygons(ring):
    if len(ring)!=3:return [ring]
    center=ring.mean(0);mid=(ring+np.roll(ring,-1,axis=0))/2
    return [np.array([ring[i],mid[i],center,mid[i-1]]) for i in range(3)]


def overlap_pairs(records,tolerance=1e-5,area_epsilon=1e-8):
    ns=np.array([r['normal'] for r in records]);lo=np.array([np.min(r['points'],0) for r in records]);hi=np.array([np.max(r['points'],0) for r in records]);pairs=[];nonplanar=[]
    for i,r in enumerate(records):
        p=np.array(r['points']);n=ns[i]
        if max(abs((p-p[0])@n))>tolerance:nonplanar.append(i);continue
        base=frame(p,n);axes=base[2];a=Polygon(p[:,axes])
        if not a.is_valid or a.area<area_epsilon:continue
        js=np.flatnonzero((np.arange(len(records))>i)&np.all(hi>=lo[i]-tolerance,1)&np.all(lo<=hi[i]+tolerance,1)&(abs(ns@n)>1-1e-7))
        for j in js:
            q=np.array(records[j]['points'])
            if max(abs((q-p[0])@n))>tolerance:continue
            b=Polygon(q[:,axes])
            if not b.is_valid:continue
            area=a.intersection(b).area/abs(n[base[1]])
            if area>area_epsilon:pairs.append(dict(a=i,b=int(j),area=float(area),same_direction=bool(n@ns[j]>0)))
    return dict(pairs=pairs,nonplanar=nonplanar)


def transverse_pairs(triangles, face_indices, candidate_pairs, records,
                     plane_epsilon=1e-6, boundary_epsilon=2e-5):
    """Measure proper surface crossings in READ-ONLY tessellation arrays.

    face_indices map triangles to indices in records. The caller supplies BVH
    candidates including different original polygons within the same object.
    Coplanar and shared-edge contacts are excluded, and containment requires the
    separate solid detector. For nonplanar original polygons the dominant-plane
    interior test is a review heuristic, not a certified curved-solid algorithm.
    Return one witness segment per original polygon pair; never mutate a mesh.
    """
    tri=np.asarray(triangles,float)
    ns=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0])
    lengths=np.linalg.norm(ns,axis=1)
    ns/=np.maximum(lengths[:,None],1e-30)
    projected={};found={}

    def section(t,n,d):
        distance=t@n-d
        if min(distance)>plane_epsilon or max(distance)<-plane_epsilon:return None
        points=[]
        for k,p in enumerate(t):
            nxt=(k+1)%3
            if abs(distance[k])<plane_epsilon*.1:points.append(p)
            if distance[k]*distance[nxt]<0:
                points.append(p+distance[k]/(distance[k]-distance[nxt])*(t[nxt]-p))
        return np.array(points) if len(points)>1 else None

    for i,j in candidate_pairs:
        fi,fj=int(face_indices[i]),int(face_indices[j]);key=tuple(sorted((fi,fj)))
        if fi==fj or key in found or min(lengths[i],lengths[j])<1e-15:continue
        if abs(ns[i]@ns[j])>1-1e-7:continue
        line=np.cross(ns[i],ns[j]);line/=np.linalg.norm(line)
        a=section(tri[i],ns[j],ns[j]@tri[j,0])
        b=section(tri[j],ns[i],ns[i]@tri[i,0])
        if a is None or b is None:continue
        aa=a@line;bb=b@line;lo=max(min(aa),min(bb));hi=min(max(aa),max(bb))
        if hi-lo<boundary_epsilon:continue
        mid=a[0]+line*((lo+hi)*.5-aa[0]);valid=True
        for f in (fi,fj):
            if f not in projected:
                r=records[f];axes=frame(r['points'],r['normal'])[2]
                projected[f]=(axes,Polygon(np.array(r['points'])[:,axes]))
            axes,poly=projected[f];point=Point(mid[axes])
            if not poly.is_valid or not poly.contains(point) or poly.boundary.distance(point)<boundary_epsilon:
                valid=False;break
        if valid:
            found[key]=dict(a=fi,b=fj,segment_length=float(hi-lo),midpoint=mid.tolist())
    return list(found.values())


def box_section(lo,hi,basis,tolerance=1e-8):
    n,axis,axes,d=basis;corners=np.array(list(itertools.product(*zip(lo,hi))));signed=corners@n-d;pts=[]
    for i,p in enumerate(corners):
        if abs(signed[i])<=tolerance:pts.append(p[axes])
        for j in range(i+1,len(corners)):
            if sum(corners[i]!=corners[j])!=1 or signed[i]*signed[j]>=0:continue
            t=signed[i]/(signed[i]-signed[j]);pts.append((p+t*(corners[j]-p))[axes])
    if len(pts)<3:return Polygon()
    from shapely.geometry import MultiPoint
    return MultiPoint(pts).convex_hull


def repair_plan(records,certified_boxes=(),tolerance=1e-5,grid=0,opposing_policy='report'):
    """Boolean union boundary: trim buried patches, give coplanar patches one owner.

    Opposite contacts without a volume certificate are report-only by default.
    Explicit single_owner_intact requires a separate preserved damage/capped source
    and confirmed compatible sidedness/material/rigid-body ownership.
    Returns per-face replacement polygons, original indices and removal reasons.
    """
    audit=overlap_pairs(records,tolerance);neighbors={}
    if opposing_policy not in {'report','single_owner_intact'}:raise ValueError('Unknown opposing policy')
    for pair in audit['pairs']:
        neighbors.setdefault(pair['a'],[]).append(pair['b']);neighbors.setdefault(pair['b'],[]).append(pair['a'])
    # Detailed surface wins over a black backing; then larger coherent face.
    def priority(i):
        r=records[i];return (bool(r.get('hidden',False)),-float(r.get('area',Polygon(np.array(r['points'])[:,frame(r['points'],r['normal'])[2]]).area)),str(r.get('id',i)))
    order=sorted(range(len(records)),key=priority);rank={x:k for k,x in enumerate(order)}
    plans=[];areas={};ambiguous=[]
    for i,r in enumerate(records):
        points=np.array(r['points']);basis=frame(points,r['normal']);n,axis,axes,d=basis
        if i in audit['nonplanar']:continue
        original=Polygon(points[:,axes])
        if not original.is_valid:continue
        cutters=[];reasons=[];lo=points.min(0);hi=points.max(0)
        if not r.get('alpha',False):
            for box in certified_boxes:
                bl=np.array(box['lo']);bh=np.array(box['hi'])
                if np.any(hi<bl-tolerance) or np.any(lo>bh+tolerance):continue
                # Equal outward plane is handled by ownership, not burial.
                outward=False
                for a in range(3):
                    if abs(n[a])>1-1e-7 and ((n[a]>0 and max(abs(points[:,a]-bh[a]))<tolerance) or (n[a]<0 and max(abs(points[:,a]-bl[a]))<tolerance)):outward=True
                if outward:continue
                section=box_section(bl,bh,basis)
                if section.area and original.intersection(section).area>1e-9:cutters.append(section);reasons.append('inside_verified_volume:'+str(box['id']))
        for j in neighbors.get(i,[]):
            if rank[j]>=rank[i] or r.get('alpha') or records[j].get('alpha'):continue
            if n@np.array(records[j]['normal'])<0:
                ambiguous.append([i,j])
                if opposing_policy=='report':continue
            q=np.array(records[j]['points']);cutters.append(Polygon(q[:,axes]));reasons.append('coplanar_owner:'+str(records[j].get('id',j)))
        if not cutters:continue
        remaining=difference(original,union_all(cutters),grid_size=grid)
        delta=original.area-remaining.area
        if delta<=1e-9:continue
        polys=[]
        for ring in simple_pieces(remaining,1e-8):
            rect=np.asarray(Polygon(ring).minimum_rotated_rectangle.exterior.coords)[:4]
            if min(np.linalg.norm(rect-np.roll(rect,1,axis=0),axis=1))<5e-7:continue
            for patch in no_triangle_polygons(ring):
                world=lift(patch,basis)
                cross=sum((np.cross(world[k],world[(k+1)%len(world)]) for k in range(len(world))),np.zeros(3))
                if cross@n<0:world=world[::-1]
                polys.append(world.tolist())
        plans.append(dict(index=i,id=r.get('id',i),polygons=polys,reasons=sorted(set(reasons)),removed_area=float(delta/abs(n[axis]))))
    return dict(plans=plans,input_audit=audit,opposing_owner_candidates=ambiguous,tolerance=tolerance,grid=grid,opposing_policy=opposing_policy)


def positive_box_overlaps(boxes,tolerance=1e-5):
    result=[]
    for i,a in enumerate(boxes):
        for j,b in enumerate(boxes[i+1:],i+1):
            extent=np.minimum(a['hi'],b['hi'])-np.maximum(a['lo'],b['lo'])
            if min(extent)>tolerance:result.append(dict(a=i,b=j,volume=float(np.prod(extent))))
    return result
