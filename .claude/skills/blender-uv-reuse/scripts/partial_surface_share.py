"""Whole curved patch -> matching subset of another patch, without mesh edits.

Use exact corresponding polygons wherever possible; use affine plane projection
only for trimmed polygons contained within a sufficiently planar owner polygon.
No scale fit, AO, packing, nearest-surface guesses or authored tessellation.
"""
import numpy as np
from shapely.geometry import Polygon
from geometry_share import _fits, _area


def _plane(face, plane_tolerance=2e-5, uv_tolerance=.025):
    p=np.asarray(face['points']);c=p.mean(0);_,_,vh=np.linalg.svd(p-c,full_matrices=False);b=vh[:2].T
    if abs((p-c)@vh[2]).max()>plane_tolerance:return None
    xy=(p-c)@b;poly=Polygon(xy)
    if not poly.is_valid:return None
    a=np.linalg.lstsq(np.c_[xy,np.ones(len(xy))],face['uv'],rcond=None)[0]
    affine_error=np.linalg.norm(np.c_[xy,np.ones(len(xy))]@a-face['uv'],axis=1).max()
    if affine_error>uv_tolerance and not face.get('render_corner_triangles'):return None
    return dict(center=c,basis=b,normal=vh[2],polygon=poly,affine=a,
                use_render_interpolation=bool(affine_error>uv_tolerance),xy=xy)


def _interpolate_render_uv(xy, plane, face, tolerance):
    """Read-only interpolation from Blender's derived render cache, not an edit."""
    uv=[];source_uv=np.asarray(face['uv'])
    for point in xy:
        options=[]
        for indices in face['render_corner_triangles']:
            q=plane['xy'][indices];matrix=np.column_stack((q[1]-q[0],q[2]-q[0]))
            if abs(np.linalg.det(matrix))<1e-14:continue
            st=np.linalg.solve(matrix,point-q[0]);weights=np.array([1-st.sum(),st[0],st[1]])
            # A tiny boundary tolerance accounts for the mirrored source floats.
            if min(weights)>=-tolerance/max(1e-8,np.linalg.norm(np.ptp(q,axis=0))):
                options.append((float(max(0,-min(weights))),weights@source_uv[indices]))
        if not options:return None
        uv.append(min(options,key=lambda r:r[0])[1])
    return np.asarray(uv)


def match_subset(owner, member, absolute=2e-5,relative=2e-5,normal_degrees=.5,density_relative=.001):
    if owner.get('page')!=member.get('page'):return None
    op=np.concatenate([f['points'] for f in owner['faces']]);length=float(np.linalg.norm(np.ptp(op,axis=0)));limit=absolute+relative*length;coslimit=np.cos(np.radians(normal_degrees))
    planes={f['id']:_plane(f) for f in owner['faces']}
    anchor=max(member['faces'],key=lambda f:_area(f['uv']));a=np.asarray(anchor['points']);n=len(a);ad=np.linalg.norm(a[:,None]-a[None,:],axis=2)
    for target in owner['faces']:
        if target['material']!=anchor['material'] or len(target['points'])!=n:continue
        tpoints=np.asarray(target['points'])
        for reverse in (False,True):
            for shift in range(n):
                order=[(shift+(-k if reverse else k))%n for k in range(n)];b=tpoints[order];bd=np.linalg.norm(b[:,None]-b[None,:],axis=2)
                if abs(ad-bd).max()>2*limit:continue
                for rotation,translation in _fits(a,b):
                    if np.linalg.norm(a@rotation.T+translation-b,axis=1).max()>limit:continue
                    if np.dot(rotation@np.asarray(anchor['normal']),target['normal'])<coslimit:continue
                    mapped={};correspondences=[];maxerror=0.;maxdensity=0.;failed=False
                    for face in member['faces']:
                        moved=np.asarray(face['points'])@rotation.T+translation;best=None
                        for other in owner['faces']:
                            if other['material']!=face['material'] or np.dot(rotation@np.asarray(face['normal']),other['normal'])<coslimit:continue
                            q=np.asarray(other['points']);uv=None;mode=None;error=None
                            if len(q)==len(moved):
                                for rev in (False,True):
                                    for sh in range(len(q)):
                                        ids=[(sh+(-k if rev else k))%len(q) for k in range(len(q))];e=float(np.linalg.norm(moved-q[ids],axis=1).max())
                                        if e<=limit:uv=np.asarray(other['uv'])[ids];mode='whole_polygon';error=e;break
                                    if uv is not None:break
                            if uv is None:
                                pp=planes[other['id']]
                                if pp is None:continue
                                error=float(abs((moved-pp['center'])@pp['normal']).max())
                                if error>limit:continue
                                xy=(moved-pp['center'])@pp['basis'];poly=Polygon(xy)
                                if not poly.is_valid or not pp['polygon'].buffer(limit).covers(poly):continue
                                uv=_interpolate_render_uv(xy,pp,other,limit) if pp['use_render_interpolation'] else np.c_[xy,np.ones(len(xy))]@pp['affine']
                                if uv is None:continue
                                mode='trimmed_render_subset' if pp['use_render_interpolation'] else 'trimmed_subset'
                            old=np.asarray(face['uv']);fit=np.linalg.lstsq(np.c_[old,np.ones(len(old))],uv,rcond=None)[0];axes=np.linalg.svd(fit[:2],compute_uv=False);de=float(np.max(abs(axes-1)))
                            residual=float(np.linalg.norm(np.c_[old,np.ones(len(old))]@fit-uv,axis=1).max())
                            if de>density_relative+1e-5 or residual>.025:continue
                            row=dict(member_face=face['id'],owner_face=other['id'],mode=mode,position_error=error,density_axes=axes.tolist(),uv_reflected=bool(np.linalg.det(fit[:2])<0),uv_affine_error=residual)
                            score=(mode!='whole_polygon',error)
                            if best is None or score<best[0]:best=(score,uv,row,de)
                        if best is None:failed=True;break
                        _,uv,row,de=best;mapped[str(face['id'])]=uv.tolist();correspondences.append(row);maxerror=max(maxerror,row['position_error']);maxdensity=max(maxdensity,de)
                    if failed:continue
                    oa=sum(_area(f['uv']) for f in owner['faces']);ma=sum(_area(v) for v in mapped.values());fraction=ma/oa
                    # This helper is a subset matcher, not a route to overfull
                    # or duplicate coverage. A later UV union check is required.
                    if fraction>1.0001:continue
                    return dict(owner=owner['id'],member=member['id'],rotation=rotation.tolist(),translation=translation.tolist(),world_reflected=bool(np.linalg.det(rotation)<0),uv_reflected=any(r['uv_reflected'] for r in correspondences),coverage='partial' if fraction<.9999 else 'full',scale_type='rigid',covered_owner_fraction=fraction,position_error=maxerror,position_limit=limit,max_density_relative_error=maxdensity,face_uv=mapped,face_correspondence=correspondences,authoring_geometry_changed=False,AO_tested=False)
    return None
