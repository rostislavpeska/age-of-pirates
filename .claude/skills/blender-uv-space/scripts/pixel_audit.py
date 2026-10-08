"""Pixel-centre ownership audit; schema: size [w,h], padding_px, charts [{id, polygons}]."""
import argparse
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter
from shapely import intersects_xy
from shapely.geometry import Polygon
from shapely.ops import unary_union


def shape_for(chart):
    polys=[]
    for coordinates in chart['polygons']:
        a=np.asarray(coordinates,float)
        if a.ndim!=2 or a.shape[1]!=2 or len(a)<3 or not np.isfinite(a).all():
            raise ValueError('Invalid polygon coordinates')
        poly=Polygon(a)
        if not poly.is_valid: raise ValueError('Invalid UV polygon: '+str(chart['id']))
        polys.append(poly)
    shape=unary_union(polys)
    if shape.is_empty or shape.area<=0:raise ValueError('Empty chart')
    return shape


def raster(shape,w,h):
    x0,y0,x1,y1=shape.bounds
    x0=max(0,math.floor(x0));y0=max(0,math.floor(y0))
    x1=min(w,math.ceil(x1));y1=min(h,math.ceil(y1))
    xx=np.arange(x0,x1)[None,:]+.5;yy=np.arange(y0,y1)[:,None]+.5
    return (x0,y0,x1,y1),intersects_xy(shape,xx,yy)


def audit(spec):
    w,h=spec['size'];pad=spec['padding_px']
    if any(type(x)!=int or x<=0 for x in (w,h)) or type(pad)!=int or pad<0:
        raise ValueError('Integer dimensions and nonnegative integer padding required')
    ids=[str(c['id']) for c in spec['charts']]
    if not ids or len(ids)!=len(set(ids)):raise ValueError('Owners must be unique and nonempty')
    counts=np.zeros((h,w),np.uint32);rows=[];errors=[]
    for c in spec['charts']:
        shape=shape_for(c);(x0,y0,x1,y1),mask=raster(shape,w,h)
        counts[y0:y1,x0:x1]+=mask.astype(np.uint32)
        bx,by,bX,bY=shape.bounds
        if min(bx,by)<-1e-5 or bX>w+1e-5 or bY>h+1e-5:errors.append({'owner':c['id'],'error':'outside page'})
        rows.append({'id':c['id'],'geometric_area':shape.area,'sampled_pixels':int(mask.sum()),'envelope_void':(bX-bx)*(bY-by)-shape.area})
    content=counts>0
    padded=np.asarray(Image.fromarray(content.astype(np.uint8)*255).filter(ImageFilter.MaxFilter(2*pad+1)))>0 if pad else content
    # Exact partition of the finite pixel grid; no padded bounding-box substitution.
    classes=np.zeros((h,w),np.uint8);classes[padded]=1;classes[content]=2;classes[counts>1]=3
    n=int(content.sum());p=int((padded&~content).sum());free=w*h-n-p
    result={'size':[w,h],'padding_px':pad,'sampling':'pixel centres; closed polygon boundaries; square raster dilation','total_pixels':w*h,'content_pixels':n,'padding_pixels':p,'unallocated_pixels':free,'content_percent':100*n/(w*h),'cross_owner_overlap_pixels':int((counts>1).sum()),'errors':errors,'subpixel_owners':[r['id'] for r in rows if r['sampled_pixels']==0],'largest_empty_envelopes':sorted(rows,key=lambda r:-r['envelope_void'])[:12],'geometric_owner_area':sum(r['geometric_area'] for r in rows)}
    return result,classes


def write(spec,out):
    out=Path(out);out.mkdir(parents=True,exist_ok=True);result,classes=audit(spec)
    colors=np.array([[20,25,31],[218,171,63],[63,183,151],[240,60,70]],np.uint8)
    Image.fromarray(colors[classes][::-1]).save(out/'PIXEL_ACCOUNTING.png')
    (out/'PIXEL_ACCOUNTING.json').write_text(json.dumps(result,indent=2)+'\n')
    return result


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('input');ap.add_argument('--out',required=True);a=ap.parse_args()
    r=write(json.loads(Path(a.input).read_text()),a.out);print(json.dumps(r,indent=2))
