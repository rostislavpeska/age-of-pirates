"""Check a declared trim termination against an actual planar cover face.

The caller identifies the intended cover and samples the complete termination.
This is a setback check, not proof of alpha coverage or a general collision test.
"""
import numpy as np


def check_termination(points, cover_polygon, outward_normal, minimum_setback,
                      tolerance=1e-6):
    p=np.asarray(points,dtype=float);q=np.asarray(cover_polygon,dtype=float)
    n=np.asarray(outward_normal,dtype=float)
    if (p.ndim!=2 or p.shape[1:]!=(3,) or not len(p) or q.ndim!=2
            or q.shape[1:]!=(3,) or len(q)<3 or n.shape!=(3,)
            or not all(np.isfinite(x).all() for x in (p,q,n))
            or not np.isfinite(minimum_setback) or minimum_setback<0):
        return {'status':'INCOMPLETE','reason':'invalid or missing geometry'}
    length=float(np.linalg.norm(n))
    if length<=tolerance or np.linalg.matrix_rank(q-q.mean(0),tol=tolerance)<2:
        return {'status':'INCOMPLETE','reason':'degenerate cover'}
    n=n/length;d=q@n
    if float(np.ptp(d))>tolerance:
        return {'status':'INCOMPLETE','reason':'declared cover is not planar in this normal'}
    clearance=float(d.mean())-p@n
    failed=np.flatnonzero(clearance<minimum_setback-tolerance).tolist()
    return {'status':'FAIL' if failed else 'PASS','minimum_clearance':float(clearance.min()),
            'required_clearance':float(minimum_setback),'failed_vertices':failed,
            'sample_count':len(p),'limitation':'cover extent/opacity and visible corner require separate verification'}
