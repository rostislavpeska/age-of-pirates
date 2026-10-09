"""Bounded butt-joint check for explicitly certified axis-aligned closed boxes.

Not a general mesh intersection solver. Caller supplies the intended support;
paper, glass and decorative backing must not substitute for structural support.
Unknown/slanted/open geometry is INCONCLUSIVE, never a fabricated passing box.
"""
from collections import Counter
import math

def certify_box(vertices, faces, tolerance=1e-6):
    if len(vertices) != 8 or len(faces) != 6 or any(len(f) != 4 for f in faces):
        return None
    if any(not math.isfinite(v) for p in vertices for v in p):
        return None
    lo = [min(p[i] for p in vertices) for i in range(3)]
    hi = [max(p[i] for p in vertices) for i in range(3)]
    if any(b-a <= tolerance for a,b in zip(lo,hi)):
        return None
    corners=[]
    for p in vertices:
        bits=[]
        for i in range(3):
            if abs(p[i]-lo[i]) <= tolerance: bits.append(0)
            elif abs(p[i]-hi[i]) <= tolerance: bits.append(1)
            else: return None
        corners.append(tuple(bits))
    if len(set(corners)) != 8: return None
    edges=Counter();planes=[]
    for face in faces:
        if len(set(face)) != 4 or any(i<0 or i>=8 for i in face):return None
        axes=[(axis,corners[face[0]][axis]) for axis in range(3)
              if len({corners[i][axis] for i in face}) == 1]
        if len(axes)!=1:return None
        planes.append(axes[0])
        for a,b in zip(face,face[1:]+face[:1]):
            # Diagonal/crossed quad order is not a valid box face.
            if sum(x!=y for x,y in zip(corners[a],corners[b]))!=1:return None
            edges[tuple(sorted((a,b)))]+=1
    if len(set(planes))!=6 or len(edges)!=12 or any(n!=2 for n in edges.values()):return None
    return lo,hi

def contact(beam, support, axis, side, tolerance=1e-5, max_penetration=1e-5,
            minimum_coverage=.999):
    if beam is None or support is None:
        return {'status':'INCONCLUSIVE','reason':'uncertified or open box'}
    if axis not in (0,1,2) or side not in (-1,1):raise ValueError('axis/side')
    lo,hi=beam;sl,sh=support
    end=hi[axis] if side>0 else lo[axis]
    near=sl[axis] if side>0 else sh[axis]
    gap=(near-end)*side
    cross=[i for i in range(3) if i!=axis]
    area=math.prod(hi[i]-lo[i] for i in cross)
    covered=math.prod(max(0,min(hi[i],sh[i])-max(lo[i],sl[i])) for i in cross)
    fraction=covered/area
    ok=-max_penetration <= gap <= tolerance and fraction>=minimum_coverage
    return {'status':'PASS' if ok else 'FAIL','gap':gap,'end_area':area,
            'support_coverage':fraction,'axis':axis,'side':side,
            'reason':'supported butt joint' if ok else 'gap, penetration or incomplete support'}
