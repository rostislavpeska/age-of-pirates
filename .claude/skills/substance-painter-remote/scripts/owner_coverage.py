"""Compare CURRENT own-atlas triangles with the Painter authoring mesh.

Requires NumPy in the calling host (or Blender's bundled Python), not in Painter.
Coordinates are normalized UVs in the same page. Shared readers may overlap in
current_uv; the owner mesh must represent every used pixel without relying on
obsolete semantic labels. This raster check does not replace geometric overlap QA.
"""
import numpy as np


def raster(triangles,size=2048):
    result=np.zeros((size,size),dtype=bool)
    for triangle in triangles:
        uv=np.asarray(triangle,dtype=float)*size
        if uv.shape!=(3,2) or not np.isfinite(uv).all():
            raise ValueError('Finite UV triangles are required')
        lo=np.maximum(np.floor(uv.min(0)).astype(int),0)
        hi=np.minimum(np.ceil(uv.max(0)).astype(int),size-1)
        if np.any(hi<lo):continue
        a=np.column_stack((uv[1]-uv[0],uv[2]-uv[0]))
        if abs(np.linalg.det(a))<1e-10:continue
        yy,xx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1]
        w=(np.c_[xx.ravel()+.5,yy.ravel()+.5]-uv[0])@np.linalg.inv(a).T
        hit=(w.min(1)>=-1e-6)&(w.sum(1)<=1.000001)
        result[yy.ravel()[hit],xx.ravel()[hit]]=True
    return result


def assess(current_uv,owner_uv,size=2048):
    used=raster(current_uv,size);covered=raster(owner_uv,size);missing=used&~covered
    return {'status':'FAIL' if missing.any() else 'PASS','size':size,
            'used_pixels':int(used.sum()),'represented_pixels':int((used&covered).sum()),
            'missing_pixels':int(missing.sum()),'unused_owner_pixels':int((covered&~used).sum())}
