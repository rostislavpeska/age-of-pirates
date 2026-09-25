"""Exact positive-area triangle-overlap check for small UNIQUE bake receivers.

No Blender dependency. Not a tiling/UDIM/shared-atlas validator. Input triangles are
three UV pairs. Shared edges are allowed. Run this file for its good/bad fixtures.
"""
import math


def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def area(poly):return abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1])))*.5 if len(poly)>2 else 0


def intersection(a,b):
    if cross(*b)<0:b=list(reversed(b))
    poly=list(a)
    for p,q in zip(b,b[1:]+b[:1]):
        out=[]
        for s,t in zip(poly,poly[1:]+poly[:1]):
            ds,dt=cross(p,q,s),cross(p,q,t)
            ins,inte=ds>=0,dt>=0
            if ins:out.append(s)
            if ins!=inte:
                f=ds/(ds-dt);out.append((s[0]+f*(t[0]-s[0]),s[1]+f*(t[1]-s[1])))
        poly=out
        if not poly:return 0
    return area(poly)


def audit(triangles,tolerance=1e-10):
    bins={};seen=set();overlaps=[];invalid=[]
    triangles=[[tuple(p) for p in tri] for tri in triangles]
    for i,tri in enumerate(triangles):
        if len(tri)!=3 or not all(math.isfinite(v) and -1e-6<=v<=1+1e-6 for p in tri for v in p) or area(tri)<=tolerance:
            invalid.append(i);continue
        xs=[p[0] for p in tri];ys=[p[1] for p in tri]
        for x in range(max(0,int(min(xs)*24)),min(23,int(max(xs)*24))+1):
            for y in range(max(0,int(min(ys)*24)),min(23,int(max(ys)*24))+1):
                cell=bins.setdefault((x,y),[])
                for j in cell:
                    pair=(j,i)
                    if pair in seen:continue
                    seen.add(pair);a=intersection(tri,triangles[j])
                    if a>tolerance:overlaps.append({'triangles':[j,i],'area':a})
                cell.append(i)
    return {'triangles':len(triangles),'invalid':invalid,'positive_area_overlaps':overlaps,
            'passed':not invalid and not overlaps,'scope':'Unique 0..1 receiver only; no padding, density, cage or semantic proof'}


if __name__=='__main__':
    good=[[(0,0),(1,0),(1,1)],[(0,0),(1,1),(0,1)]]
    assert audit(good)['passed']
    assert len(audit(good+[good[0]])['positive_area_overlaps'])==1
    assert not audit([[(0,0),(0,0),(1,0)]])['passed']
    assert not audit([[(-.2,0),(.2,0),(0,.5)]])['passed']
    print('UV fixtures passed: shared-edge, duplicate-area, degenerate and out-of-range')
