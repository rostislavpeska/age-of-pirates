"""Verify an extracted shared-atlas face census, not a material-name promise.

Consumer extraction must read the actual mesh UVs, shader bindings and source
hashes. This checker validates that evidence; it cannot authenticate an extractor.
All coordinates and cell bounds are runtime pixels, not normalized UVs.
"""
import math


def audit(faces, expected_face_ids, cells, bindings):
    ids=[f.get('face') for f in faces];expected=set(expected_face_ids)
    if len(ids)!=len(set(ids)) or set(ids)!=expected:
        raise ValueError('shared face census differs from mesh scope')
    metrics=dict(shared_face_count=len(faces),unmapped=0,incompatible=0,unbound=0,
                 outside_cells=0,unreviewed_exposure=0,coverage_errors=0)
    issues=[]
    for f in faces:
        reasons=[];cell=cells.get(f.get('cell'))
        if cell is None or f.get('pending',False):reasons.append('unmapped')
        if cell is not None:
            if f.get('physical_class') not in cell.get('physical_classes',[]):reasons.append('incompatible')
            uv=f.get('uv_pixels',[]);rect=cell.get('bounds',[])
            if len(uv)<3 or len(rect)!=4 or not all(math.isfinite(x) for x in rect):
                reasons.append('outside_cells')
            elif any(len(q)!=2 or not all(math.isfinite(x) for x in q) or
                     not(rect[0]<=q[0]<=rect[2] and rect[1]<=q[1]<=rect[3]) for q in uv):
                reasons.append('outside_cells')
        elif not f.get('physical_compatibility_verified',False):reasons.append('incompatible')
        binding=bindings.get(f.get('binding'),{})
        required=binding.get('required_channels',[]);actual=binding.get('actual_channels',{})
        if not required or not binding.get('uv_layer_verified') or any(
            c not in actual or not actual[c].get('source_sha256') or not actual[c].get('bound_image_sha256') or
            actual[c]['source_sha256']!=actual[c]['bound_image_sha256'] for c in required):
            reasons.append('unbound')
        visible=f.get('sampled_exposure')
        if visible is None or (visible>0 and f.get('exposure_disposition')!='adequate_shared_quality'):
            reasons.append('unreviewed_exposure')
        for reason in set(reasons):metrics[reason]+=1
        if reasons:issues.append(dict(face=f['face'],reasons=sorted(set(reasons))))
    return dict(status='PASS' if not issues else 'INCOMPLETE',metrics=metrics,issues=issues)


def metric_errors(metrics):
    required=('shared_face_count','unmapped','incompatible','unbound','outside_cells','unreviewed_exposure','coverage_errors')
    if any(type(metrics.get(k)) is not int or metrics[k]<0 for k in required):
        return ['missing/noninteger shared mapping census']
    return [k+' is nonzero' for k in required[1:] if metrics[k]]
