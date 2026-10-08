"""Bounded whole-owner raster packing experiment; no mesh edits or new chart boundaries."""
import argparse
import json
import math
import time
from pathlib import Path
import cv2
import numpy as np
from shapely import intersects_xy
from shapely.affinity import affine_transform
from pixel_audit import shape_for


def validate(spec,gap,border):
    w,h=spec['size'];shapes=[shape_for(c) for c in spec['charts']];errors=[];minimum=None
    for i,s in enumerate(shapes):
        x0,y0,x1,y1=s.bounds
        if min(x0,y0)<border-1e-5 or x1>w-border+1e-5 or y1>h-border+1e-5:
            errors.append(['border',spec['charts'][i]['id']])
        for j in range(i):
            d=s.distance(shapes[j]);minimum=d if minimum is None else min(minimum,d)
            if d<gap-1e-5:errors.append(['gap',spec['charts'][i]['id'],spec['charts'][j]['id'],d])
    return {'errors':errors,'minimum_gap_px':minimum,'gap_required':gap,'border_required':border}


def pack(spec,scale,step=4,allow_quarter_turn=False,deadline=None):
    if scale<=0 or not math.isfinite(scale) or step<1:raise ValueError('Invalid scale/step')
    w,h=spec['size'];pad=spec['padding_px'];extra=step*math.sqrt(2)/2;offset=pad+extra
    H,W=h//step,w//step;occupied=np.zeros((H,W),np.float32);placed={};used_x=used_y=0
    rows=[]
    for c in spec['charts']:
        s=shape_for(c);x0,y0,x1,y1=s.bounds
        rows.append((max(x1-x0,y1-y0),s.area,c,s))
    rows.sort(key=lambda row:(-row[0],-row[1],str(row[2]['id'])))
    for _,_,c,s in rows:
        if deadline and time.monotonic()>deadline:return None
        best=None
        for quarter in range(4 if allow_quarter_turn else 1):
            A=np.linalg.matrix_power(np.array([[0.,-1.],[1.,0.]]),quarter)*scale
            rotated=affine_transform(s,[*A[0],*A[1],0,0]);x0,y0,x1,y1=rotated.bounds
            shift=np.array([offset-x0,offset-y0]);local=affine_transform(rotated,[1,0,0,1,*shift])
            mw=math.ceil((x1-x0+2*offset)/step);mh=math.ceil((y1-y0+2*offset)/step)
            if mw>W or mh>H:continue
            xx=(np.arange(mw)[None,:]+.5)*step;yy=(np.arange(mh)[:,None]+.5)*step
            mask=intersects_xy(local.buffer(pad+extra),xx,yy).astype(np.float32)
            scores=cv2.matchTemplate(occupied,mask,cv2.TM_CCORR)
            ys,xs=np.nonzero(scores<.25)
            if len(xs)==0:continue
            nx=np.maximum(used_x,xs+mw);ny=np.maximum(used_y,ys+mh)
            order=np.lexsort((xs,ys,nx*ny,np.maximum(nx,ny)))
            # Floating correlation only proposes positions; exact discrete dot verifies.
            for index in order:
                x,y=int(xs[index]),int(ys[index])
                if np.any(occupied[y:y+mh,x:x+mw]*mask):continue
                cost=(int(max(nx[index],ny[index])),int(nx[index]*ny[index]),y,x)
                if best is None or cost<best[0]:best=(cost,x,y,mask,A,shift)
                break
        if best is None:return None
        _,x,y,mask,A,shift=best;mh,mw=mask.shape
        occupied[y:y+mh,x:x+mw]=np.maximum(occupied[y:y+mh,x:x+mw],mask)
        used_x=max(used_x,x+mw);used_y=max(used_y,y+mh)
        shift=shift+np.array([x*step,y*step]);placed[str(c['id'])]={'linear':A.tolist(),'translation':shift.tolist()}
    charts=[]
    for c in spec['charts']:
        a=placed[str(c['id'])];A=np.array(a['linear']);v=np.array(a['translation'])
        charts.append({**c,'polygons':[(np.array(p)@A.T+v).tolist() for p in c['polygons']]})
    candidate={**spec,'charts':charts};qa=validate(candidate,2*pad,pad)
    return {'scale':scale,'step_px':step,'quarter_turns':allow_quarter_turn,'transforms':placed,'spec':candidate,'qa':qa}


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('input');ap.add_argument('--out',required=True);ap.add_argument('--scales',type=float,nargs='+',required=True);ap.add_argument('--step',type=int,default=4);ap.add_argument('--seconds',type=float,default=60);ap.add_argument('--quarter-turns',action='store_true');a=ap.parse_args()
    if a.seconds<=0 or len(a.scales)>32:raise ValueError('Bound search to positive time and <=32 trials')
    spec=json.loads(Path(a.input).read_text());deadline=time.monotonic()+a.seconds;best=None;trials=[]
    for scale in a.scales:
        if time.monotonic()>deadline:break
        start=time.monotonic();candidate=pack(spec,scale,a.step,a.quarter_turns,deadline)
        valid=candidate is not None and not candidate['qa']['errors'];trials.append({'scale':scale,'valid':valid,'seconds':time.monotonic()-start})
        print(json.dumps(trials[-1]),flush=True)
        if valid and (best is None or scale>best['scale']):best=candidate
    out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
    (out/'TRIALS.json').write_text(json.dumps(trials,indent=2))
    if best:(out/'BEST.json').write_text(json.dumps(best,indent=2))
    print(json.dumps({'best_scale':best['scale'] if best else None,'trials':len(trials)}))
