"""Measure a source-image projection independently of destination atlas UV density.

Inputs must be the coordinates actually supplied to the texture sampler, BEFORE
modulo/repeat. Do not substitute the intended frame or measure only UV area.
Dependencies: NumPy. Read-only analytical triangle measurements.
"""
import numpy as np


def triangle_metrics(points, source_pixels, minimum_axis=1e-3):
    p=np.asarray(points,dtype=float);q=np.asarray(source_pixels,dtype=float)
    if p.shape!=(3,3) or q.shape!=(3,2) or not np.isfinite(p).all() or not np.isfinite(q).all():
        return {'status':'FAIL','reason':'invalid/nonfinite projection evidence'}
    e1=p[1]-p[0];e2=p[2]-p[0];length=float(np.linalg.norm(e1))
    area2=float(np.linalg.norm(np.cross(e1,e2)))
    if length<1e-10 or area2<1e-10:
        return {'status':'INCOMPLETE','reason':'degenerate geometry; never a projection pass','area3d':area2/2}
    x=e1/length;n=np.cross(e1,e2)/area2;y=np.cross(n,x)
    world=np.array([[np.dot(e1,x),np.dot(e2,x)],[np.dot(e1,y),np.dot(e2,y)]])
    tex=np.column_stack([q[1]-q[0],q[2]-q[0]])
    J=tex@np.linalg.inv(world);singular=np.linalg.svd(J,compute_uv=False)
    small=float(singular[-1]);large=float(singular[0])
    return {'status':'PASS' if small>=minimum_axis else 'FAIL',
            'reason':'two source axes resolved' if small>=minimum_axis else 'collapsed/near-zero source sampling axis',
            'axis_pixels_per_unit':[large,small],'area3d':area2/2,
            'anisotropy':large/small if small>1e-12 else None}


def face_frame(points, preferred_axis=0):
    """A face-tangent orthonormal frame for an explicitly classified surface.

    Preserve the preferred direction when it lies in the face; on an end cap
    choose a spanning axis. Callers still choose source material/scale and test
    all shared readers. This does not invent grain semantics or UV coordinates.
    """
    p=np.asarray(points,float);center=p.mean(0)
    _,sv,vh=np.linalg.svd(p-center,full_matrices=False)
    if len(sv)<2 or sv[1]<1e-9:raise ValueError('No two-dimensional face')
    n=vh[-1];e=np.eye(3)[int(preferred_axis)];u=e-n*np.dot(e,n)
    if np.linalg.norm(u)<1e-7:
        spans=np.ptp(p,axis=0)
        for axis in np.argsort(-spans):
            e=np.eye(3)[axis];u=e-n*np.dot(e,n)
            if np.linalg.norm(u)>1e-7:break
    u/=np.linalg.norm(u)
    choices=[e-n*np.dot(e,n)-u*np.dot(e,u) for e in np.eye(3)]
    v=max(choices,key=np.linalg.norm);v/=np.linalg.norm(v)
    return u,v
