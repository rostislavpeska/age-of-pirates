"""Whole-chart rigid geometry correspondence for a provisional UV-sharing gate.

No AO, packing, Blender mutation or topology edits. UV inputs are pixel-space,
in consistent density units. Charts contain face records with points, uv, normal,
material and id. Equal UV layout only shortlists; 3D and material correspondence
must pass. Different tessellations/parameterizations conservatively stay unique.
"""
import hashlib
import itertools
import numpy as np


def orientations():
    for swap in (False, True):
        for sx,sy in itertools.product((-1,1),repeat=2):
            a=np.diag([sx,sy]).astype(float)
            if swap:a=a[:,::-1]
            yield a


def variants(chart, precision=.01):
    out=[]
    for matrix in orientations():
        all_uv=np.concatenate([f['uv'] for f in chart['faces']])@matrix.T
        origin=all_uv.min(0);rows=[];geometry=[];uv=[];normals=[];refs=[]
        for f in chart['faces']:
            q=np.array(f['uv'])@matrix.T-origin
            # Cyclic order may reverse in a mirrored chart. Keep source loop refs.
            order=sorted(range(len(q)),key=lambda k:tuple(np.round(q[k]/precision).astype(int)))
            quantized=[tuple(np.round(pt/precision).astype(int)) for pt in q]
            edges=tuple(sorted(tuple(sorted((quantized[k],quantized[(k+1)%len(q)]))) for k in range(len(q))))
            signature=(f['material'],len(q),tuple(quantized[k] for k in order),edges)
            rows.append((signature,f,q,order))
        rows.sort(key=lambda row:row[0])
        signature=tuple(row[0] for row in rows)
        if len(set(signature))!=len(signature):
            # Indistinguishable coincident faces require a separate diagnosis.
            continue
        for _,f,q,order in rows:
            geometry.extend(np.array(f['points'])[order]);uv.extend(q[order])
            normals.extend([f['normal']]*len(order));refs.extend((f['id'],k) for k in order)
        out.append(dict(signature=signature,matrix=matrix,origin=origin,
                        points=np.array(geometry),uv=np.array(uv),
                        normals=np.array(normals),refs=refs))
    return out


def correspondence(owner,member,absolute=2e-5,relative=2e-5,
                   uv_limit=.025,normal_degrees=.5):
    """Fit both proper/improper isometries; never fit a scale factor."""
    if owner['signature']!=member['signature']:return None
    a=owner['points'];b=member['points']
    if a.shape!=b.shape:return None
    uv_error=float(np.linalg.norm(owner['uv']-member['uv'],axis=1).max())
    if uv_error>uv_limit:return None
    ac=a.mean(0);bc=b.mean(0);u,s,vh=np.linalg.svd((a-ac).T@(b-bc))
    length=float(np.linalg.norm(np.ptp(a,axis=0)));limit=absolute+relative*length
    successes=[]
    for sign in (1,-1):
        rotation=vh.T@np.diag([1,1,sign])@u.T;translation=bc-rotation@ac
        error=float(np.linalg.norm(a@rotation.T+translation-b,axis=1).max())
        if error>limit:continue
        dots=np.sum((owner['normals']@rotation.T)*member['normals'],axis=1)
        angular=float(np.degrees(np.arccos(np.clip(dots,-1,1))).max())
        if angular>normal_degrees:continue
        successes.append(dict(rotation=rotation.tolist(),translation=translation.tolist(),
                              determinant=float(np.linalg.det(rotation)),position_error=error,
                              position_limit=limit,normal_error_degrees=angular,uv_error_pixels=uv_error))
    if not successes:return None
    result=min(successes,key=lambda r:(r['position_error'],r['normal_error_degrees']))
    result['loop_correspondence']=[dict(owner_face=int(a[0]),owner_corner=int(a[1]),member_face=int(b[0]),member_corner=int(b[1])) for a,b in zip(owner['refs'],member['refs'])]
    result['uv_reflection']=bool(np.linalg.det(owner['matrix'])*np.linalg.det(member['matrix'])<0)
    return result


def group_charts(charts,precision=.01,**tolerances):
    """Every member is measured against its chosen owner, never chained matches."""
    cache={c['id']:variants(c,precision) for c in charts};groups=[];buckets={};unmatched=[]
    for chart in sorted(charts,key=lambda c:c['id']):
        vv=cache[chart['id']]
        if not vv:
            unmatched.append(dict(chart=chart['id'],reason='ambiguous_coincident_uv_faces'));continue
        canonical=min(v['signature'] for v in vv)
        key=(chart.get('page'),canonical)
        matches=[v for v in vv if v['signature']==canonical]
        chosen=None
        for gi in buckets.get(key,[]):
            group=groups[gi]
            for ov in group['_variants']:
                for mv in matches:
                    found=correspondence(ov,mv,**tolerances)
                    if found:
                        chosen=(gi,found);break
                if chosen:break
            if chosen:break
        if chosen:
            gi,found=chosen;groups[gi]['members'].append(dict(chart=chart['id'],**found))
        else:
            gi=len(groups);buckets.setdefault(key,[]).append(gi)
            groups.append(dict(owner=chart['id'],members=[],_variants=matches,
                               signature_hash=hashlib.sha256(repr(key).encode()).hexdigest()))
    for g in groups:g.pop('_variants')
    return dict(groups=groups,unmatched=unmatched,precision_pixels=precision,
                ao_tested=False,packing_performed=False,scope='provisional_whole_chart_geometry_only')
