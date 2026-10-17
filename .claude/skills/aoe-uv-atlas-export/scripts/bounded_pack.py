"""Deterministic rectangle trials with an explicit baseline-relative scale cap.

Placement coordinates include half the fixed runtime gap on every side.
This reports the best tried heuristic, never a proof of global optimality.
"""
import math
import numpy as np


def place(rects, side, order='long', score='short'):
    priorities = {'long': lambda r: max(r), 'area': lambda r: r[0]*r[1],
                  'perimeter': lambda r: sum(r)}
    free = [(0., 0., side, side)]
    out = []
    for i in sorted(range(len(rects)), key=lambda i: (-priorities[order](rects[i]), i)):
        w, h = rects[i]; best = None
        for fx, fy, fw, fh in free:
            for rotated, (rw, rh) in enumerate(((w, h), (h, w))):
                if rw > fw + 1e-9 or rh > fh + 1e-9: continue
                a, b = fw-rw, fh-rh
                rank = {'short': (min(a,b), max(a,b), fy, fx),
                        'area': (fw*fh-rw*rh, min(a,b), fy, fx),
                        'bottom': (fy+rh, fx, min(a,b), max(a,b))}[score]
                if best is None or rank < best[0]: best=(rank,fx,fy,rw,rh,bool(rotated))
        if best is None: return None
        _,x,y,rw,rh,rotated=best;out.append((i,x,y,rw,rh,rotated));nf=[]
        for fx,fy,fw,fh in free:
            if x>=fx+fw or x+rw<=fx or y>=fy+fh or y+rh<=fy:
                nf.append((fx,fy,fw,fh));continue
            if x>fx:nf.append((fx,fy,x-fx,fh))
            if x+rw<fx+fw:nf.append((x+rw,fy,fx+fw-x-rw,fh))
            if y>fy:nf.append((fx,fy,fw,y-fy))
            if y+rh<fy+fh:nf.append((fx,y+rh,fw,fy+fh-y-rh))
        if not nf:free=[];continue
        A=np.asarray(nf);x0,y0=A[:,0],A[:,1];x1,y1=x0+A[:,2],y0+A[:,3]
        inside=((x0[:,None]>=x0[None,:]-1e-9)&(y0[:,None]>=y0[None,:]-1e-9)&
                (x1[:,None]<=x1[None,:]+1e-9)&(y1[:,None]<=y1[None,:]+1e-9))
        np.fill_diagonal(inside,False);same=inside&inside.T;ix=np.arange(len(nf))
        drop=(inside&~same).any(1)|(same&(ix[None,:]<ix[:,None])).any(1)
        free=[r for r,d in zip(nf,drop) if not d]
    return out


def search(dimensions, *, min_scale, max_scale=1., side=2048, gap=12., iterations=12, methods=None):
    if not dimensions or any(len(d)!=2 or any(not math.isfinite(v) or v<=0 for v in d) for d in dimensions):
        raise ValueError('positive finite bank dimensions required')
    if not (math.isfinite(min_scale) and math.isfinite(max_scale) and 0<min_scale<=max_scale<=1):
        raise ValueError('explicit retained fraction in (0,1] required')
    if not math.isfinite(gap) or gap<0 or side<=0 or iterations<1:raise ValueError('invalid page/gap/search bound')
    methods=methods or [(o,s) for o in ('long','area','perimeter') for s in ('short','area','bottom')]
    trials=[];winner=None
    for order,score in methods:
        def attempt(scale):return place([(w*scale+gap,h*scale+gap) for w,h in dimensions],side,order,score)
        initial=attempt(min_scale)
        if initial is None:
            trials.append(dict(order=order,score=score,fits_minimum=False));continue
        lo,hi=min_scale,max_scale;packed=initial
        for _ in range(iterations):
            mid=(lo+hi)/2;p=attempt(mid)
            if p is None:hi=mid
            else:lo=mid;packed=p
        result=dict(order=order,score=score,scale=lo,placements=packed)
        trials.append(dict(order=order,score=score,fits_minimum=True,scale=lo))
        if winner is None or lo>winner['scale']:winner=result
    return dict(best=winner,trials=trials,min_scale=min_scale,gap=gap,side=side)
