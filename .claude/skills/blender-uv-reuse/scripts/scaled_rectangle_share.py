"""Proposal-only bounded scaling for small, generic rectangular material patches.

Not for roofs, walls, signs, windows, ornaments, AO or final normal-map reuse.
An explicit material allowlist, size ceiling and both-axis density ceiling are
required. This helper does not mutate charts or authorize bulk application.
"""
import numpy as np
from planar_share import prepare


def frame(chart,allowed_materials,max_area,max_extent):
    if {f['material'] for f in chart['faces']} - set(allowed_materials):return None
    p=prepare(chart)
    if p is None or p['shape'].geom_type!='Polygon' or p['shape'].interiors:return None
    box=p['shape'].minimum_rotated_rectangle
    if box.area>max_area or p['shape'].symmetric_difference(box).area>max(1e-9,box.area*1e-5):return None
    q=np.asarray(box.exterior.coords)[:4];edges=np.roll(q,-1,axis=0)-q;lengths=np.linalg.norm(edges,axis=1);i=int(lengths.argmax());origin=q[i];u=edges[i]/lengths[i];v=(q[(i-1)%4]-origin);h=np.linalg.norm(v);v/=h
    if max(lengths[i],h)>max_extent:return None
    return dict(prepared=p,origin=origin,axes=np.column_stack((u,v)),size=np.array([lengths[i],h]))


def proposal(owner,member,allowed_materials=('S1B_ID_WOOD',),max_area=.16,max_extent=.8,max_axis_scale=.02,max_density_change=.02):
    if owner.get('page')!=member.get('page'):return None
    a=frame(owner,allowed_materials,max_area,max_extent);b=frame(member,allowed_materials,max_area,max_extent)
    if a is None or b is None or a['prepared']['key']!=b['prepared']['key']:return None
    scales=a['size']/b['size']
    if np.max(abs(scales-1))>max_axis_scale:return None
    ap=a['prepared'];bp=b['prepared'];uv={};density=[]
    for face in member['faces']:
        xy=(np.asarray(face['points'])-bp['center'])@bp['basis'];local=(xy-b['origin'])@b['axes'];target=(local*scales)@a['axes'].T+a['origin'];mapped=target@ap['uv_map'][:2]+ap['uv_map'][2]
        old=np.asarray(face['uv']);fit=np.linalg.lstsq(np.c_[old,np.ones(len(old))],mapped,rcond=None)[0];axes=np.linalg.svd(fit[:2],compute_uv=False)
        if max(abs(axes-1))>max_density_change:return None
        uv[str(face['id'])]=mapped.tolist();density.extend(abs(axes-1))
    return dict(owner=owner['id'],member=member['id'],coverage='full',transform='scaled',axis_scale_long_short=scales.tolist(),max_density_change=float(max(density)),face_uv=uv,geometry_changed=False,policy=dict(allowed_materials=list(allowed_materials),max_area=max_area,max_extent=max_extent,max_axis_scale=max_axis_scale,max_density_change=max_density_change),status='proposal_only_not_applied_to_main_model',texture_pattern_and_AO_review_pending=True)


def partial_rectangle(owner,member,tile_divisors=(2,3),density_relative=.001):
    """Geometry-only 1/N rectangle reuse; no stretch, same material and page.

    Anchor at an owner corner. Artwork/module phase is not inferred from a
    rectangle: pattern, trim, AO and channel compatibility remain pending.
    """
    mats={f['material'] for f in owner['faces']}
    if len(mats)!=1 or {f['material'] for f in member['faces']}!=mats or owner.get('page')!=member.get('page'):return None
    a=frame(owner,mats,float('inf'),float('inf'));b=frame(member,mats,float('inf'),float('inf'))
    if a is None or b is None:return None
    ap=a['prepared'];bp=b['prepared']
    for swap in (False,True):
        sizes=b['size'][::-1] if swap else b['size'];axes=b['axes'][:,::-1] if swap else b['axes'];ratio=a['size']/sizes;counts=np.rint(ratio).astype(int)
        if np.max(abs(ratio-counts))>1e-4 or not any(n>1 for n in counts) or any(n not in (1,*tile_divisors) for n in counts):continue
        uv={};errors=[]
        for f in member['faces']:
            xy=(np.asarray(f['points'])-bp['center'])@bp['basis'];local=(xy-b['origin'])@axes;target=local@a['axes'].T+a['origin'];new=target@ap['uv_map'][:2]+ap['uv_map'][2]
            old=np.asarray(f['uv']);fit=np.linalg.lstsq(np.c_[old,np.ones(len(old))],new,rcond=None)[0];ds=np.linalg.svd(fit[:2],compute_uv=False);err=float(max(abs(ds-1)))
            if err>density_relative+1e-5:break
            uv[str(f['id'])]=new.tolist();errors.append(err)
        if len(uv)!=len(member['faces']):continue
        return dict(owner=owner['id'],member=member['id'],coverage='partial',transform='rigid',tile_divisors=counts.tolist(),covered_owner_fraction=1/int(np.prod(counts)),face_uv=uv,max_density_change=max(errors),pattern_phase='owner_corner_only_artwork_not_validated',AO_tested=False,geometry_changed=False)
    return None
