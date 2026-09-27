"""Measured evidence kernels extracted from the five-method experiment. No asset edits."""
from pathlib import Path
import math
import numpy as np
from numba import njit
from scipy.ndimage import binary_propagation

@njit(cache=True)
def raster(tri,fids,d,right,up,center,size,span):
    z=np.full((size,size),-1e30);ids=np.full((size,size),-1,np.int32);scale=size/span
    for i in range(len(tri)):
        xy=np.empty((3,2));dep=np.empty(3)
        for j in range(3):
            q=tri[i,j]-center;xy[j,0]=size*.5+np.dot(q,right)*scale;xy[j,1]=size*.5-np.dot(q,up)*scale;dep[j]=np.dot(q,d)
        xmin=max(0,int(math.floor(np.min(xy[:,0]))));xmax=min(size-1,int(math.ceil(np.max(xy[:,0]))))
        ymin=max(0,int(math.floor(np.min(xy[:,1]))));ymax=min(size-1,int(math.ceil(np.max(xy[:,1]))))
        x0,y0=xy[0];x1,y1=xy[1];x2,y2=xy[2];den=(y1-y2)*(x0-x2)+(x2-x1)*(y0-y2)
        if abs(den)<1e-12:continue
        for y in range(ymin,ymax+1):
            for x in range(xmin,xmax+1):
                w0=((y1-y2)*(x+.5-x2)+(x2-x1)*(y+.5-y2))/den
                w1=((y2-y0)*(x+.5-x2)+(x0-x2)*(y+.5-y2))/den;w2=1-w0-w1
                if w0< -1e-9 or w1< -1e-9 or w2< -1e-9:continue
                depth=w0*dep[0]+w1*dep[1]+w2*dep[2]
                if depth>z[y,x]+1e-8:z[y,x]=depth;ids[y,x]=fids[i]
    return ids


def directions(els,n,phase=0):
    for e in np.radians(els):
        for a in np.arange(n)*2*np.pi/n+phase:
            yield np.array([np.cos(e)*np.cos(a),np.cos(e)*np.sin(a),np.sin(e)])


def sweep(tri,fi,fs,els,n,size,phase,save=None,output_dir=None):
    center=(tri.min((0,1))+tri.max((0,1)))/2;span=np.linalg.norm(tri.max((0,1))-tri.min((0,1)))*1.03
    normal=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);N=len(fs)
    maxpix=np.zeros(N);maxfrac=np.zeros(N);viewfreq=np.zeros(N);views=[]
    for vi,d in enumerate(directions(els,n,phase)):
        right=np.cross([0.,0.,1.],d);right/=np.linalg.norm(right);up=np.cross(d,right)
        ids=raster(tri,fi,d,right,up,center,size,span)
        counts=np.bincount(ids[ids>=0],minlength=N)
        projected=np.bincount(fi,weights=np.abs(normal@d)*.5*(size/span)**2,minlength=N)
        fraction=np.minimum(1,counts/np.maximum(projected,1))
        maxpix=np.maximum(maxpix,counts);maxfrac=np.maximum(maxfrac,fraction);viewfreq+=counts>0
        views.append({'direction':d.tolist(),'face_pixels':{str(i):int(counts[i]) for i in np.where(counts>0)[0]}})
        if save and vi in (0,3,12):np.savez_compressed(Path(output_dir)/f'{save}_view_{vi}.npz',ids=ids)
    return {'max_pixels':maxpix.tolist(),'max_fraction':maxfrac.tolist(),'view_frequency':(viewfreq/(len(els)*n)).tolist(),'views':views}


@njit(cache=True)
def stamp(tris,origin,h,shape):
    occ=np.zeros((shape[0],shape[1],shape[2]),np.bool_);half=h*.5000001
    for t in tris:
        lo=np.empty(3,np.int64);hi=np.empty(3,np.int64)
        for a in range(3):
            lo[a]=max(0,int(np.floor((min(t[0,a],t[1,a],t[2,a])-origin[a])/h))-1)
            hi[a]=min(shape[a]-1,int(np.floor((max(t[0,a],t[1,a],t[2,a])-origin[a])/h))+1)
        edges=np.empty((3,3));edges[0]=t[1]-t[0];edges[1]=t[2]-t[1];edges[2]=t[0]-t[2]
        axes=np.zeros((13,3));axes[0]=np.cross(edges[0],edges[1]);axes[1:4]=np.eye(3);q=4
        for e in edges:
            for base in np.eye(3):axes[q]=np.cross(e,base);q+=1
        lower=np.zeros(13);upper=np.zeros(13)
        for a in range(13):
            pp=t@axes[a];r=half*np.sum(np.abs(axes[a]));lower[a]=np.min(pp)-r;upper[a]=np.max(pp)+r
        for x in range(lo[0],hi[0]+1):
            for y in range(lo[1],hi[1]+1):
                for z in range(lo[2],hi[2]+1):
                    cx=origin[0]+h*(x+.5);cy=origin[1]+h*(y+.5);cz=origin[2]+h*(z+.5);hit=True
                    for a in range(13):
                        p=cx*axes[a,0]+cy*axes[a,1]+cz*axes[a,2]
                        if p<lower[a] or p>upper[a]:hit=False;break
                    if hit:occ[x,y,z]=True
    return occ


def voxel_run(tri,fs,h,shift,max_cells=8000000):
    lo=tri.min((0,1));hi=tri.max((0,1));origin=lo-3*h+shift*h
    shape=np.ceil((hi-origin)/h).astype(np.int64)+4
    if int(np.prod(shape)) > max_cells:
        raise ValueError(f'Voxel budget exceeded: {shape.tolist()}; revise scale/pitch or budget explicitly.')
    occ=stamp(tri,origin,h,shape)
    seed=np.zeros_like(occ);seed[0,:,:]=True;seed[-1,:,:]=True;seed[:,0,:]=True;seed[:,-1,:]=True;seed[:,:,0]=True;seed[:,:,-1]=True
    exterior=binary_propagation(seed&~occ,structure=np.ones((3,3,3),bool),mask=~occ)
    enclosed=~occ&~exterior;ret=[]
    for f in fs:
        p=np.array(f['points']);center=p.mean(0);samples=np.vstack([center,.9*p+.1*center]);n=np.array(f['normal'])
        values=[]
        for scale in (1.25,2.5):
            ids=np.floor((samples+n*h*scale-origin)/h).astype(int)
            valid=np.all((ids>=0)&(ids<shape),axis=1);vals=np.zeros(len(ids),bool)
            ix=ids[valid];vals[valid]=enclosed[ix[:,0],ix[:,1],ix[:,2]]
            values.append(float(np.mean(vals)))
        ret.append(min(values))
    return np.array(ret),{'shape':shape.tolist(),'occupied':int(occ.sum()),'enclosed_air':int(enclosed.sum()),'pitch':h,'shift':shift}
