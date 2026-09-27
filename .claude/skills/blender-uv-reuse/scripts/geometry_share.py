"""Whole-chart rigid geometry correspondence for a provisional UV-sharing gate.

No AO, packing, Blender mutation or topology edits. UV inputs are pixel-space.
Geometry, material patterns and polygon connectivity drive discovery; existing
UV layout does not. Per-face density must remain within the declared tolerance.
Different mesh topologies still conservatively stay unique. The older variants()
and correspondence() functions are retained for historical diagnostic callers;
group_charts() no longer uses their exact rounded UV signature.
"""
import hashlib
import itertools
import collections
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


def _cycle(indices):
    """Canonical polygon boundary, independent of first corner and winding."""
    seq=tuple(indices);rev=seq[::-1]
    return min(
        [seq[i:]+seq[:i] for i in range(len(seq))]+
        [rev[i:]+rev[:i] for i in range(len(rev))])


def _area(uv):
    q=np.asarray(uv,float)
    return abs(float(np.sum(q[:,0]*np.roll(q[:,1],-1)-q[:,1]*np.roll(q[:,0],-1))))*.5


def _prepare(chart):
    # Exact source vertex identity preserves existing split boundaries. We do not
    # weld or alter the mesh to manufacture a match.
    vertices=[];lookup={};faces=[];boundary={};ambiguous=False
    for f in chart['faces']:
        ids=[]
        for p in f['points']:
            key=tuple(p)
            if key not in lookup:lookup[key]=len(vertices);vertices.append(p)
            ids.append(lookup[key])
        points=np.array(f['points'],float)
        distances=np.linalg.norm(points[:,None,:]-points[None,:,:],axis=2)
        row=dict(source=f,ids=ids,points=points,distances=distances)
        key=(f['material'],_cycle(ids))
        if key in boundary:ambiguous=True
        boundary[key]=len(faces);faces.append(row)
    v=np.array(vertices,float);center=v.mean(0);radius=np.sort(np.linalg.norm(v-center,axis=1))
    signature=tuple(sorted(collections.Counter((f['material'],len(f['points'])) for f in chart['faces']).items()))
    return dict(chart=chart,vertices=v,faces=faces,boundary=boundary,radius=radius,
                key=(chart.get('page'),len(v),signature),ambiguous=ambiguous)


def _fits(a,b):
    ac=a.mean(0);bc=b.mean(0);u,s,vh=np.linalg.svd((a-ac).T@(b-bc))
    for sign in (1,-1):
        r=vh.T@np.diag([1,1,sign])@u.T
        yield r,bc-r@ac


def geometry_correspondence(owner,member,absolute=2e-5,relative=2e-5,
                            uv_limit=.025,normal_degrees=.5,density_relative=.001):
    """Whole-chart isometry first; source UVs never shortlist geometry.

    The same face topology/material pattern is required. Different UV layouts
    can inherit owner coordinates when per-face texel density is preserved.
    uv_limit is reported as a diagnostic threshold, not a geometry veto.
    """
    if owner['key']!=member['key'] or owner['ambiguous'] or member['ambiguous']:return None
    a=owner['vertices'];b=member['vertices']
    length=2*float(owner['radius'][-1]);limit=absolute+relative*length
    if np.max(np.abs(owner['radius']-member['radius']))>2*limit:return None
    # A large, non-collinear anchor polygon gives a stable initial transform.
    # Try every compatible target and cyclic winding; do not hash float lengths.
    anchor=max(owner['faces'],key=lambda f:np.linalg.norm(np.cross(
        f['points']-f['points'][0],np.roll(f['points'],-1,axis=0)-f['points'][0]).sum(0)))
    n=len(anchor['ids']);cos_limit=np.cos(np.radians(normal_degrees))
    for candidate in member['faces']:
        if len(candidate['ids'])!=n or candidate['source']['material']!=anchor['source']['material']:continue
        for reverse in (False,True):
            for shift in range(n):
                order=[(shift+(-k if reverse else k))%n for k in range(n)]
                target=candidate['points'][order]
                if np.max(np.abs(anchor['distances']-candidate['distances'][np.ix_(order,order)]))>2*limit:continue
                for rotation,translation in _fits(anchor['points'],target):
                    if np.dot(rotation@np.array(anchor['source']['normal']),candidate['source']['normal'])<cos_limit:continue
                    moved=a@rotation.T+translation
                    distances=np.linalg.norm(moved[:,None,:]-b[None,:,:],axis=2)
                    mapping=distances.argmin(1)
                    if len(set(mapping))!=len(b) or distances[np.arange(len(a)),mapping].max()>4*limit:continue
                    pairs=[];used=set()
                    for face in owner['faces']:
                        ids=[int(mapping[i]) for i in face['ids']]
                        index=member['boundary'].get((face['source']['material'],_cycle(ids)))
                        if index is None or index in used:break
                        used.add(index);other=member['faces'][index]
                        corners=[other['ids'].index(i) for i in ids]
                        pairs.append((face,other,corners))
                    if len(pairs)!=len(owner['faces']):continue
                    # Refine with all matched vertices, then certify the final
                    # rigid fit, every face normal and every boundary cycle.
                    for r,t in _fits(a,b[mapping]):
                        error=float(np.linalg.norm(a@r.T+t-b[mapping],axis=1).max())
                        if error>limit:continue
                        dots=[np.dot(r@np.array(x['source']['normal']),y['source']['normal']) for x,y,_ in pairs]
                        angle=float(np.degrees(np.arccos(np.clip(min(dots),-1,1))))
                        if angle>normal_degrees:continue
                        uv_a=[];uv_b=[];refs=[];density_errors=[];bad_density=False
                        for x,y,corners in pairs:
                            uva=np.array(x['source']['uv']);uvb=np.array(y['source']['uv'])[corners]
                            area_a=_area(uva);area_b=_area(uvb)
                            if min(area_a,area_b)<=1e-10:bad_density=True;break
                            density_error=abs(np.sqrt(area_a/area_b)-1)
                            if density_error>density_relative+1e-4/max(np.sqrt(area_b),1):bad_density=True;break
                            density_errors.append(density_error);uv_a.extend(uva);uv_b.extend(uvb)
                            refs.extend(dict(owner_face=int(x['source']['id']),owner_corner=k,
                                             member_face=int(y['source']['id']),member_corner=int(j)) for k,j in enumerate(corners))
                        if bad_density:continue
                        ua=np.array(uv_a,float);ub=np.array(uv_b,float);ua-=ua.mean(0);ub-=ub.mean(0)
                        u,s,vh=np.linalg.svd(ua.T@ub);ur=vh.T@u.T
                        uv_error=float(np.linalg.norm(ua@ur.T-ub,axis=1).max())
                        return dict(rotation=r.tolist(),translation=t.tolist(),determinant=float(np.linalg.det(r)),
                                    position_error=error,position_limit=limit,normal_error_degrees=angle,
                                    uv_error_pixels=uv_error,uv_reflection=bool(np.linalg.det(ur)<0),
                                    uv_layout_differs=uv_error>uv_limit,max_density_relative_error=max(density_errors),
                                    loop_correspondence=refs,method='geometry_first_boundary_correspondence')
    return None


def group_charts(charts,precision=.01,**tolerances):
    """Every member is geometrically checked against its owner, never chained.

    precision is retained for historical callers but is no longer a UV hash gate.
    """
    cache={c['id']:_prepare(c) for c in charts};groups=[];buckets={};unmatched=[]
    comparisons=0
    for chart in sorted(charts,key=lambda c:c['id']):
        prepared=cache[chart['id']];key=prepared['key']
        if prepared['ambiguous']:
            unmatched.append(dict(chart=chart['id'],reason='ambiguous_coincident_geometry_faces'));continue
        chosen=None
        for gi in buckets.get(key,[]):
            comparisons+=1;found=geometry_correspondence(cache[groups[gi]['owner']],prepared,**tolerances)
            if found:chosen=(gi,found);break
        if chosen:
            gi,found=chosen;groups[gi]['members'].append(dict(chart=chart['id'],**found))
        else:
            gi=len(groups);buckets.setdefault(key,[]).append(gi)
            groups.append(dict(owner=chart['id'],members=[],signature_hash=hashlib.sha256(repr(key).encode()).hexdigest()))
    return dict(groups=groups,unmatched=unmatched,candidate_comparisons=comparisons,
                candidate_method='topology_material_then_measured_geometry',uv_hash_used=False,
                density_relative_tolerance=tolerances.get('density_relative',.001),
                ao_tested=False,packing_performed=False,scope='provisional_whole_chart_geometry_only')
