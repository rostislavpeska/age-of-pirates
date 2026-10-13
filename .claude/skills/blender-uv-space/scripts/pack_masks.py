"""Bounded whole-owner raster packing experiment; no mesh edits or new chart boundaries.

Opt-in pinned mode: spec["obstacles"] is a list of {id, polygons} in page pixels,
with optional JSON provenance. These groups never move; they may overlap each
other and touch the page border. Only nondegenerate valid polygons are supported:
point/line readers must be represented by an explicitly justified area footprint,
or this API refuses them. No implicit buffering/omission of degenerate readers.
Pinned mode requires scale=1, preserves the existing quarter-turn option, and
checks movable border=padding_px and content gap=2*padding_px. Even at gap=0,
intersection (including boundary contact) is conservatively rejected. The result
includes protected input identities; it does not certify reader completeness,
texture/mip compatibility or source UV correspondence. Without the obstacles key,
the previous empty-page behavior and output schema are unchanged.
Movable IDs must be unique after str conversion. Protected IDs have a separate
namespace: matching a movable ID never exempts that fixed reader from checks.

Audit: 2026-10-13-codex-tc-packer-01 (KTC-377).
"""
import argparse
import copy
import hashlib
import json
import math
import time
from pathlib import Path
import cv2
import numpy as np
from shapely import intersects_xy
from shapely.affinity import affine_transform
from shapely.ops import unary_union
from pixel_audit import shape_for


def _protected(spec):
    """Validate, identify and read fixed polygons without normalizing their input."""
    rows=spec['obstacles']
    if not isinstance(rows,list):raise ValueError('obstacles must be a list')
    if len(spec['size'])!=2 or any(type(v)!=int or v<=0 for v in spec['size']):
        raise ValueError('Pinned mode requires positive integer page dimensions')
    w,h=spec['size'];ids=[];shapes=[];identities=[]
    for row in rows:
        if not isinstance(row,dict) or 'id' not in row or not isinstance(row.get('polygons'),list) or not row['polygons']:
            raise ValueError('Every obstacle needs an id and nonempty polygons')
        if 'points' in row or 'lines' in row:
            raise ValueError('Point/line obstacles are unsupported; no reader may be omitted')
        key=str(row['id'])
        if key in ids:raise ValueError('Duplicate obstacle id: '+key)
        # shape_for rejects nonfinite, invalid and zero-area input polygons.
        shape=shape_for(row);x0,y0,x1,y1=shape.bounds
        if min(x0,y0)<0 or x1>w or y1>h:
            raise ValueError('Obstacle outside page: '+key)
        ids.append(key);shapes.append(shape)
        encoded=json.dumps(row,sort_keys=True,separators=(',',':'),allow_nan=False).encode('utf-8')
        identities.append({'id':row['id'],'sha256':hashlib.sha256(encoded).hexdigest()})
    encoded=json.dumps(rows,sort_keys=True,separators=(',',':'),allow_nan=False).encode('utf-8')
    return shapes,{'sha256':hashlib.sha256(encoded).hexdigest(),'count':len(rows),'obstacles':identities}


def _interferes(s,t,gap):
    return s.intersects(t) or s.distance(t)<gap-1e-5


def validate(spec,gap,border):
    w,h=spec['size'];shapes=[shape_for(c) for c in spec['charts']];errors=[];minimum=None
    pinned='obstacles' in spec
    protected,identity=_protected(spec) if pinned else ([],None)
    protected_minimum=None
    if pinned and (not math.isfinite(gap) or not math.isfinite(border) or min(gap,border)<0):
        raise ValueError('Pinned gap/border must be finite and nonnegative')
    for i,s in enumerate(shapes):
        x0,y0,x1,y1=s.bounds
        if min(x0,y0)<border-1e-5 or x1>w-border+1e-5 or y1>h-border+1e-5:
            errors.append(['border',spec['charts'][i]['id']])
        for j in range(i):
            d=s.distance(shapes[j]);minimum=d if minimum is None else min(minimum,d)
            if d<gap-1e-5:errors.append(['gap',spec['charts'][i]['id'],spec['charts'][j]['id'],d])
            elif pinned and s.intersects(shapes[j]):errors.append(['overlap',spec['charts'][i]['id'],spec['charts'][j]['id']])
        for j,t in enumerate(protected):
            d=s.distance(t);protected_minimum=d if protected_minimum is None else min(protected_minimum,d)
            if _interferes(s,t,gap):errors.append(['obstacle_gap',spec['charts'][i]['id'],spec['obstacles'][j]['id'],d])
    result={'errors':errors,'minimum_gap_px':minimum,'gap_required':gap,'border_required':border}
    if pinned:result.update(protected=identity,minimum_obstacle_gap_px=protected_minimum)
    return result


def pack(spec,scale,step=4,allow_quarter_turn=False,deadline=None):
    if scale<=0 or not math.isfinite(scale) or step<1:raise ValueError('Invalid scale/step')
    w,h=spec['size'];pad=spec['padding_px'];extra=step*math.sqrt(2)/2;offset=pad+extra
    pinned='obstacles' in spec
    protected,identity=_protected(spec) if pinned else ([],None)
    if pinned and (scale!=1 or type(step)!=int or type(pad)!=int or pad<0):
        raise ValueError('Pinned mode requires scale=1, integer step and nonnegative integer padding')
    if pinned:
        chart_ids=[str(c['id']) for c in spec['charts']]
        if len(chart_ids)!=len(set(chart_ids)):raise ValueError('Duplicate movable chart id')
    H,W=h//step,w//step;occupied=np.zeros((H,W),np.float32);placed={};used_x=used_y=0
    placed_shapes=[]
    if pinned and (H==0 or W==0):return None
    if protected:
        xx=(np.arange(W)[None,:]+.5)*step;yy=(np.arange(H)[:,None]+.5)*step
        occupied=intersects_xy(unary_union(protected).buffer(pad+extra),xx,yy).astype(np.float32)
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
                if pinned and deadline and time.monotonic()>deadline:return None
                x,y=int(xs[index]),int(ys[index])
                if np.any(occupied[y:y+mh,x:x+mw]*mask):continue
                if pinned:
                    candidate=affine_transform(local,[1,0,0,1,x*step,y*step])
                    bx,by,bX,bY=candidate.bounds
                    if min(bx,by)<pad-1e-5 or bX>w-pad+1e-5 or bY>h-pad+1e-5:continue
                    if any(_interferes(candidate,t,2*pad) for t in protected+placed_shapes):continue
                cost=(int(max(nx[index],ny[index])),int(nx[index]*ny[index]),y,x)
                if best is None or cost<best[0]:best=(cost,x,y,mask,A,shift)
                break
        if best is None:return None
        _,x,y,mask,A,shift=best;mh,mw=mask.shape
        occupied[y:y+mh,x:x+mw]=np.maximum(occupied[y:y+mh,x:x+mw],mask)
        used_x=max(used_x,x+mw);used_y=max(used_y,y+mh)
        shift=shift+np.array([x*step,y*step]);placed[str(c['id'])]={'linear':A.tolist(),'translation':shift.tolist()}
        if pinned:placed_shapes.append(affine_transform(s,[*A[0],*A[1],*shift]))
    charts=[]
    for c in spec['charts']:
        a=placed[str(c['id'])];A=np.array(a['linear']);v=np.array(a['translation'])
        charts.append({**c,'polygons':[(np.array(p)@A.T+v).tolist() for p in c['polygons']]})
    candidate={**spec,'charts':charts}
    if pinned:candidate['obstacles']=copy.deepcopy(spec['obstacles'])
    qa=validate(candidate,2*pad,pad)
    if pinned and qa['errors']:return None
    result={'scale':scale,'step_px':step,'quarter_turns':allow_quarter_turn,'transforms':placed,'spec':candidate,'qa':qa}
    if pinned:result['protected']=identity
    return result


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
