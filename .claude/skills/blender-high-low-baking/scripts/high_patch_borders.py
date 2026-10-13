"""Pad only the exterior of a quad HIGH sampling group, never internal LOW edges.

Internal overscan creates coplanar/near-coplanar HIGH overlaps and false baked AO.
Corner order: a,b,c,d; U runs a->b, V runs a->d. Units are source world units.
"""
from collections import Counter
import math

def edge_key(a,b,tolerance=1e-6):
    return tuple(sorted(tuple(round(float(x)/tolerance) for x in p) for p in (a,b)))

def edge_inventory(quads):
    counts=Counter()
    seen=set()
    for q in quads:
        if len(q)!=4:raise ValueError('Expected quad sampling patches')
        face=tuple(sorted(tuple(round(float(x)/1e-6)for x in p)for p in q))
        if face in seen:raise ValueError('Duplicated LOW sampling patch')
        seen.add(face)
        for i in range(4):counts[edge_key(q[i],q[(i+1)%4])]+=1
    if any(n>2 for n in counts.values()):raise ValueError('Non-manifold or duplicated LOW sampling patches')
    return counts

def padding(q,counts,world_margin):
    if world_margin<0:raise ValueError('Negative HIGH overscan')
    a,b,c,d=q
    eu=max(math.dist(a,b),math.dist(c,d));ev=max(math.dist(a,d),math.dist(b,c))
    if min(eu,ev)<=1e-9:raise ValueError('Degenerate sampling patch')
    edges=[(a,d,eu),(b,c,eu),(a,b,ev),(d,c,ev)]
    return tuple(world_margin/length if counts[edge_key(x,y)]==1 else 0.0 for x,y,length in edges)
