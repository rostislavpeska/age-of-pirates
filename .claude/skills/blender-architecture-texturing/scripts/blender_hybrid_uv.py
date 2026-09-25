"""Conservative, geometry-context-proven chart reuse after fixed-density layout.

Uses an explicit Blender mesh scope. A repeated chart must have the same semantic
policy, density, canonical geometry/normals and nearby opaque triangle geometry.
AO equivalence applies only to the recorded finite distance and quantization.
Charts touching cutout geometry are kept unique. Does not bake or delete anything.
"""
import hashlib,importlib.util,json
from pathlib import Path
import numpy as np
import bpy

sp=importlib.util.spec_from_file_location('uv_metrics',Path(__file__).with_name('uv_metrics.py'))
metrics=importlib.util.module_from_spec(sp);sp.loader.exec_module(metrics)


def consolidate(objects,layout,uv_name,context_distance=.35,quantization=.0001,
                alpha_faces=None,max_pages=None):
    objects=list(objects);alpha_faces=alpha_faces or set()
    if context_distance<=0 or not 0<quantization<context_distance/100:
        raise ValueError('Use a positive AO distance and much smaller geometric tolerance')
    alltri=[];alpha=[]
    for ob in objects:
        ob.data.calc_loop_triangles()
        for tri in ob.data.loop_triangles:
            alltri.append([(ob.matrix_world@ob.data.vertices[v].co)[:] for v in tri.vertices])
            alpha.append((ob.name,tri.polygon_index) in alpha_faces)
    tris=np.asarray(alltri);alpha=np.asarray(alpha);bounds_min=tris.min(axis=1);bounds_max=tris.max(axis=1)
    res=layout['profile']['resolution'];charts=layout['charts'];cache={};groups={};protected=0
    for c in charts:
        ob=bpy.data.objects[c['object']];me=ob.data;uv=me.uv_layers[uv_name]
        lis=[li for fi in c['faces'] for li in me.polygons[fi].loop_indices]
        coords=np.array([uv.data[li].uv[:] for li in lis])*res
        p=c['placement'];coords-=np.array([p['x'],p['y']])
        if p['rotated']:coords=np.column_stack((c['pixel_size'][0]-coords[:,1],coords[:,0]))
        coords=np.maximum(coords,0);cache[c['key']]=(lis,coords)
        world=np.array([(ob.matrix_world@me.vertices[me.loops[li].vertex_index].co)[:] for li in lis])
        local=coords/c['density'];index={li:i for i,li in enumerate(lis)}
        tri=next(t for t in me.loop_triangles if t.polygon_index in c['faces'])
        ix=[index[li] for li in tri.loops];q=local[ix];w=world[ix]
        basis=(w[1:]-w[0]).T@np.linalg.inv((q[1:]-q[0]).T)
        n=np.cross(w[1]-w[0],w[2]-w[0]);n/=np.linalg.norm(n)
        matrix=np.column_stack((basis,n));inv=np.linalg.inv(matrix)
        origin=w[0]-basis@q[0];canonical=(world-origin)@inv.T
        normal_matrix=ob.matrix_world.to_3x3().inverted().transposed()
        normals=np.array([(normal_matrix@me.corner_normals[li].vector).normalized()[:] for li in lis])@matrix
        geometry=sorted(tuple(v) for v in np.rint(np.column_stack((local,canonical,normals))/quantization).astype(np.int64))
        # Broad phase in world space, followed by the same oriented local bounds.
        mask=np.all(bounds_max>=world.min(axis=0)-context_distance,axis=1)&np.all(bounds_min<=world.max(axis=0)+context_distance,axis=1)
        nearby=(tris[mask]-origin)@inv.T
        # Keep a conservative cuboid; all rays of the finite AO hemisphere fit.
        # Column norms are ~1 at validated metric UV density. Extra margin covers
        # residual allowed stretch; matching contexts need identical geometry.
        radius=context_distance*max(np.linalg.norm(inv,axis=1))*1.01
        lo=canonical.min(axis=0)-radius;hi=canonical.max(axis=0)+radius
        keep=np.all(nearby.max(axis=1)>=lo,axis=1)&np.all(nearby.min(axis=1)<=hi,axis=1)
        if np.any(alpha[mask][keep]) or any((ob.name,fi) in alpha_faces for fi in c['faces']):
            key=('protected_alpha',c['key']);protected+=1
        else:
            context=sorted(tuple(sorted(map(tuple,t))) for t in np.rint(nearby[keep]/quantization).astype(np.int64))
            payload={'policy':c.get('policy',{}),'density':c['density'],'geometry':geometry,'context':context}
            key=hashlib.sha256(repr(payload).encode()).hexdigest()
        groups.setdefault(key,[]).append(c['key'])
    owner={i:ids[0] for ids in groups.values() for i in ids}
    owners=[c for c in charts if owner[c['key']]==c['key']]
    pages=max_pages or layout['profile']['max_pages']
    placements=metrics.pack_rectangles([(c['key'],*c['pixel_size']) for c in owners],res,layout['profile']['padding'],pages)
    for c in charts:
        oid=owner[c['key']];p=placements[oid];lis,coords=cache[c['key']];coords=coords.copy()
        if p['rotated']:coords=np.column_stack((coords[:,1],c['pixel_size'][0]-coords[:,0]))
        coords=(coords+[p['x'],p['y']])/res
        uv=bpy.data.objects[c['object']].data.uv_layers[uv_name]
        for li,co in zip(lis,coords):uv.data[li].uv=co
        c['owner']=oid;c['placement']=p
        for fi in c['faces']:layout['objects'][c['object']][str(fi)].update(page=p['page'],owner=oid)
    before=layout['padded_pixel_area'];after=sum((p['padded_bounds'][2]-p['padded_bounds'][0])*(p['padded_bounds'][3]-p['padded_bounds'][1]) for p in placements.values())
    layout['padded_pixel_area']=after;layout['pages']=max(p['page'] for p in placements.values())+1
    layout['hybrid']={'proof':'canonical chart geometry, normals, semantic policy and finite local opaque triangle context match after quantization','ao_distance':context_distance,'quantization':quantization,'chart_count':len(charts),'owner_count':len(owners),'shared_groups':[ids for ids in groups.values() if len(ids)>1],'alpha_protected_charts':protected,'padded_pixels_before_reuse':before,'padded_pixels_after_reuse':after,'bake_policy':'Bake owner faces only; all scoped geometry remains an occluder. Never bake the entire overlapped mesh directly.'}
    return layout
