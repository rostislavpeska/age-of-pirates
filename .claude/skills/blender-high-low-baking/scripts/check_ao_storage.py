"""Check declared contact AO against its measured field, not a darkness quota.

Arrays are 8-bit-scale AO, same raster orientation/shape. The caller supplies the
actual bake and receiver scope; this does not certify geometry or visual quality.
INC-120: white window Masks.R passed while TC requires the measured AO there.
"""
import numpy as np

def assess(expected, actual, scope, tolerance=1, require_contact=True):
    expected=np.asarray(expected);actual=np.asarray(actual);scope=np.asarray(scope,dtype=bool)
    if expected.ndim!=2 or expected.shape!=actual.shape or expected.shape!=scope.shape:
        return {'status':'FAIL','reason':'shape mismatch'}
    if not scope.any():return {'status':'FAIL','reason':'empty receiver scope'}
    e=expected[scope].astype(float);a=actual[scope].astype(float)
    if not np.isfinite(e).all() or not np.isfinite(a).all() or min(e.min(),a.min())<0 or max(e.max(),a.max())>255:
        return {'status':'FAIL','reason':'invalid AO values'}
    witnesses=e<230
    if require_contact and not witnesses.any():
        return {'status':'FAIL','reason':'declared contact has no measured witness'}
    delta=np.abs(e-a)
    return {'status':'PASS' if delta.max()<=tolerance else 'FAIL',
            'reason':'baked channel agreement' if delta.max()<=tolerance else 'measured contact not preserved in packed channel',
            'scope_texels':int(scope.sum()),'contact_witnesses':int(witnesses.sum()),
            'maximum_error':float(delta.max()),'mismatched_texels':int((delta>tolerance).sum())}
