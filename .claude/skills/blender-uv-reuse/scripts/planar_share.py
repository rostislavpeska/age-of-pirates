"""Experimental whole planar-chart reuse, independent of internal tessellation.

Rigid/reflected 2D surface alignment; no scale fit, packing, AO or mesh edits.
Uses NumPy and Shapely 2.x. Finite raster tests supplement geometric tests;
they are not a proof of texture-channel compatibility or full Hausdorff bounds.
"""
import numpy as np
from shapely.geometry import Polygon
from shapely.ops import unary_union
from shapely.affinity import affine_transform
from shapely import contains_xy


def polygons(g):
    if g.geom_type == 'Polygon':
        return [g]
    return [p for p in getattr(g, 'geoms', []) if p.geom_type == 'Polygon']


def prepare(chart, plane_tolerance=2e-5, uv_tolerance=.025):
    """Keep whole chart, holes and every material region. Reject ambiguous overlap."""
    pts = np.concatenate([f['points'] for f in chart['faces']])
    uv = np.concatenate([f['uv'] for f in chart['faces']])
    center = pts.mean(0)
    _, _, vh = np.linalg.svd(pts-center, full_matrices=False)
    basis = vh[:2].T
    xy = (pts-center) @ basis
    plane_error = float(np.max(np.abs((pts-center) @ vh[2])))
    if plane_error > plane_tolerance:
        return None
    design = np.c_[xy, np.ones(len(xy))]
    uv_map = np.linalg.lstsq(design, uv, rcond=None)[0]
    uv_error = float(np.linalg.norm(design @ uv_map-uv, axis=1).max())
    if uv_error > uv_tolerance or abs(np.linalg.det(uv_map[:2])) < 1e-10:
        return None
    regs = {}
    area_sum = 0.
    for face in chart['faces']:
        q = (np.asarray(face['points'])-center) @ basis
        poly = Polygon(q)
        if not poly.is_valid or poly.area < 1e-12:
            return None
        area_sum += poly.area
        regs.setdefault(face['material'], []).append(poly)
    regions = {m: unary_union(ps) for m, ps in regs.items()}
    shape = unary_union(list(regions.values()))
    if not shape.is_valid or area_sum-shape.area > max(1e-9, area_sum*1e-6):
        return None
    n = np.sum([np.asarray(f['normal']) * Polygon((np.asarray(f['points'])-center) @ basis).area for f in chart['faces']], axis=0)
    n /= np.linalg.norm(n)
    if max(np.degrees(np.arccos(np.clip(np.dot(n, f['normal']), -1, 1))) for f in chart['faces']) > .5:
        return None
    return dict(chart=chart, center=center, basis=basis, normal=n, shape=shape,
                regions=regions, uv_map=uv_map, plane_error=plane_error,
                uv_error=uv_error, key=(chart.get('page'), tuple(sorted(regions))),
                length=float(np.linalg.norm(np.ptp(xy, axis=0))))


def moved(g, r, t):
    return affine_transform(g, [r[0,0],r[0,1],r[1,0],r[1,1],t[0],t[1]])


def _edges(shape, simplify):
    for poly in polygons(shape.simplify(simplify, preserve_topology=True)):
        for ring in [poly.exterior]+list(poly.interiors):
            q = np.asarray(ring.coords)
            for a,b in zip(q[:-1], q[1:]):
                if np.linalg.norm(b-a) > simplify:
                    yield a,b


def _raster(regions, bounds, size, offset=0.):
    lo = np.asarray(bounds[:2]); hi = np.asarray(bounds[2:])
    span = max(hi-lo); scale = (size-16)/span
    image = np.zeros((size,size),dtype=np.uint8)
    # Sample pixel centers against the unified regions. Polygon scan conversion
    # can change edge pixels when the same straight boundary has extra vertices;
    # that must not masquerade as a geometric difference.
    xs=lo[0]+(np.arange(size)+.5-8-offset)/scale
    ys=lo[1]+(np.arange(size)+.5-8-offset)/scale
    for code, material in enumerate(sorted(regions),1):
        image[contains_xy(regions[material],xs[None,:],ys[:,None])]=code
    return image


def image_comparison(owner, member_regions, sizes=(256,1024), return_images=False):
    """Same-frame material-ID raster comparison at two scales and subpixel phases."""
    allshape = unary_union([owner['shape']]+list(member_regions.values()))
    rows=[]; images=None
    for size in sizes:
        for offset in (0., .375):
            a=_raster(owner['regions'], allshape.bounds, size, offset)
            b=_raster(member_regions, allshape.bounds, size, offset)
            union=(a>0)|(b>0); common=(a>0)&(b>0)
            rows.append(dict(size=size,offset=offset,
                silhouette_iou=float(common.sum()/max(1,union.sum())),
                material_mismatch=float(((a!=b)&common).sum()/max(1,common.sum())),
                coverage_pixels=int(union.sum())))
            if return_images and size==max(sizes) and offset==0:
                images=(a,b)
    result=dict(samples=rows,min_iou=min(r['silhouette_iou'] for r in rows),
                max_material_mismatch=max(r['material_mismatch'] for r in rows))
    return (result,images) if return_images else result


def match(owner, member, absolute=2e-5, relative=2e-5, density_relative=.001,
          min_image_iou=.997, max_image_material_error=.001,
          max_review_pixel_error=.5, review_pixels_per_unit=120.,
          image_gate=True):
    """Map member to owner; preserve size and both UV density axes.

    Position tolerance bounds the sampled symmetric Shapely Hausdorff estimate
    and material-region symmetric difference. Two-scale images are a second gate.
    Directly compare every member to its owner; do not chain accepted similarities.
    """
    if owner is None or member is None or owner['key']!=member['key']:
        return None
    limit=absolute+relative*owner['length']
    a=owner['shape']; b=member['shape']
    if abs(a.area-b.area)>limit*(a.length+b.length):
        return None
    # Simplification removes redundant collinear subdivision points only at a
    # much smaller tolerance than the accepted surface discrepancy.
    eps=max(1e-8,min(1e-6,limit*.01))
    aedges=list(_edges(a,eps)); bedges=list(_edges(b,eps))
    if not aedges or not bedges:return None
    oa,ob=max(aedges,key=lambda e:np.linalg.norm(e[1]-e[0]))
    ov=ob-oa; olen=np.linalg.norm(ov); ou=ov/olen
    obasis=np.column_stack((ou,[-ou[1],ou[0]]))
    best=None
    for ma,mb in bedges:
        for x,y in ((ma,mb),(mb,ma)):
            mv=y-x; mlen=np.linalg.norm(mv)
            if abs(olen-mlen)>2*limit:continue
            mu=mv/mlen; mbasis=np.column_stack((mu,[-mu[1],mu[0]]))
            for sign in (1,-1):
                r=obasis@np.diag([1,sign])@mbasis.T
                # Center the edge residual, rather than pin one end.
                t=(oa+ob)*.5-r@((x+y)*.5)
                regions={k:moved(g,r,t) for k,g in member['regions'].items()}
                surface=moved(b,r,t)
                hd=float(a.hausdorff_distance(surface))
                if hd>limit or hd*review_pixels_per_unit>max_review_pixel_error:continue
                if any(owner['regions'][k].symmetric_difference(g).area>
                       limit*(owner['regions'][k].length+g.length) for k,g in regions.items()):continue
                # new_uv=(member_xy @ r.T+t) @ owner_uv_linear+owner_uv_offset.
                new_linear=r.T@owner['uv_map'][:2]
                uv_delta=np.linalg.solve(member['uv_map'][:2],new_linear)
                scales=np.linalg.svd(uv_delta,compute_uv=False)
                density_error=float(np.max(np.abs(scales-1)))
                if density_error>density_relative+1e-5:continue
                images=image_comparison(owner,regions)
                passed=all(s['silhouette_iou']>=(min_image_iou if s['size']>=1024 else min(min_image_iou,.995)) for s in images['samples']) and images['max_material_mismatch']<=max_image_material_error
                uv={}
                for f in member['chart']['faces']:
                    xy=(np.asarray(f['points'])-member['center'])@member['basis']
                    uv[str(f['id'])]=((xy@r.T+t)@owner['uv_map'][:2]+owner['uv_map'][2]).tolist()
                row=dict(member=member['chart']['id'],owner=owner['chart']['id'],
                    matrix2=r.tolist(),translation2=t.tolist(),reflected=bool(np.linalg.det(r)<0),
                    uv_reflected=bool(np.linalg.det(uv_delta)<0),
                    world_determinant=float(np.linalg.det(owner['basis']@r@member['basis'].T+np.outer(owner['normal'],member['normal']))),
                    hausdorff_estimate=hd,position_limit=limit,
                    review_pixel_error=hd*review_pixels_per_unit,
                    density_axes=scales.tolist(),max_density_relative_error=density_error,
                    image_metrics=images,image_passed=passed,face_uv=uv,
                    owner_face_count=len(owner['chart']['faces']),member_face_count=len(member['chart']['faces']),
                    method='planar_material_region_alignment')
                if best is None or (not passed,hd)<(not best['image_passed'],best['hausdorff_estimate']):best=row
    if best and (best['image_passed'] or not image_gate):return best
    return None
