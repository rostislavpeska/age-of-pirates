"""Fixed-density unique delivery UVs from reviewed source charts, in Blender.

Call build_layout on explicitly scoped COPIES. Geometry, normals and source UVs
are not modified. Requires NumPy and adjacent uv_metrics.py. Returns face/page
assignments; callers retain semantic/source material roles when changing slots.
No auto-save, UI automation, global selection, hidden-face deletion or rescaling.
"""
import importlib.util
import math
from pathlib import Path
import numpy as np
import bpy

_spec=importlib.util.spec_from_file_location('uv_metrics',Path(__file__).with_name('uv_metrics.py'))
metrics=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(metrics)


def build_layout(objects, source_uv, delivery_uv, density, resolution, padding, max_pages,
                 repair_distorted_faces=False, face_profiles=None):
    objects=list(objects)
    if not objects or len({o.name for o in objects})!=len(objects):
        raise ValueError('Explicit nonempty unique mesh scope required')
    charts=[]
    for ob in objects:
        if ob.type!='MESH' or source_uv not in ob.data.uv_layers or delivery_uv in ob.data.uv_layers:
            raise ValueError(f'{ob.name}: missing source UV or delivery UV already exists')
        me=ob.data;me.calc_loop_triangles();uv=me.uv_layers[source_uv]
        parent=list(range(len(me.polygons)))
        def root(i):
            while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
            return i
        edges={}
        for p in me.polygons:
            lis=list(p.loop_indices)
            for a,b in zip(lis,lis[1:]+lis[:1]):
                va,vb=me.loops[a].vertex_index,me.loops[b].vertex_index
                entry=(p.index,{va:np.array(uv.data[a].uv),vb:np.array(uv.data[b].uv)})
                edges.setdefault(tuple(sorted((va,vb))),[]).append(entry)
        for key,adj in edges.items():
            if len(adj)!=2:continue
            (a,au),(b,bu)=adj
            edge=au[key[1]]-au[key[0]]
            centers=[np.mean([uv.data[li].uv[:] for li in me.polygons[fi].loop_indices],axis=0) for fi in [a,b]]
            signs=[edge[0]*(c-au[key[0]])[1]-edge[1]*(c-au[key[0]])[0] for c in centers]
            if signs[0]*signs[1]<0 and me.polygons[a].material_index==me.polygons[b].material_index and all(np.max(abs(au[v]-bu[v]))<1e-6 for v in key):
                parent[root(a)]=root(b)
        groups={}
        for p in me.polygons:
            profile=(face_profiles or {}).get(ob.name,{}).get(str(p.index),{})
            group_key=(root(p.index),repr(sorted(profile.items())))
            groups.setdefault(group_key,[]).append(p.index)
        triangles={}
        for tri in me.loop_triangles:triangles.setdefault(root(tri.polygon_index),[]).append(tri)
        world=np.array([(ob.matrix_world@v.co)[:] for v in me.vertices])
        by_face={}
        for tri in me.loop_triangles:by_face.setdefault(tri.polygon_index,[]).append(tri)
        def append_chart(faces, project=False):
            profile=(face_profiles or {}).get(ob.name,{}).get(str(faces[0]),{})
            target=float(profile.get('density',density))
            if target<=0:raise ValueError('Chart density must be positive')
            loops=[li for pi in faces for li in me.polygons[pi].loop_indices]
            coords=np.array([uv.data[li].uv[:] for li in loops])
            if project:
                assert len(faces)==1
                p=me.polygons[faces[0]];pts=world[list(p.vertices)]
                normal=np.array(ob.matrix_world.to_3x3().inverted().transposed()@p.normal);normal/=np.linalg.norm(normal)
                u=pts[1]-pts[0];u-=normal*np.dot(u,normal);u/=np.linalg.norm(u);v=np.cross(normal,u)
                coords=np.column_stack((pts@u,pts@v))
            lo=coords.min(axis=0);lookup={li:co for li,co in zip(loops,coords)}
            area=0;pixel_area=0;records=[]
            for fi in faces:
                for tri in by_face[fi]:
                    r=metrics.triangle_metrics(world[list(tri.vertices)], [lookup[li] for li in tri.loops], [resolution,resolution])
                    area+=r['area'];pixel_area+=r['area']*r['equivalent']**2;records.append((fi,r))
            factor=target/math.sqrt(pixel_area/area)
            bad={fi for fi,r in records if r['low']*factor<target*.8 or r['high']*factor>target*1.2 or r['anisotropy']>1.5}
            if bad and repair_distorted_faces and not project:
                good=[fi for fi in faces if fi not in bad]
                if good:append_chart(good)
                for fi in sorted(bad):append_chart([fi],project=True)
                return
            pixels=(coords-lo)*resolution*factor;size=pixels.max(axis=0)
            charts.append(dict(key=len(charts),object=ob.name,faces=faces,loops=loops,pixels=pixels,
                               size=size,source_origin=lo.tolist(),source_to_pixel_scale=resolution*factor,area=area,
                               projection='metric_face_repair' if project else 'preserved_chart',
                               density=target,policy=profile))
        for faces in groups.values():append_chart(faces)
    placements=metrics.pack_rectangles([(c['key'],*c['size']) for c in charts],resolution,padding,max_pages)
    for ob in objects:ob.data.uv_layers.new(name=delivery_uv)
    assignments={ob.name:{} for ob in objects}
    for c in charts:
        p=placements[c['key']];coords=c['pixels'].copy()
        if p['rotated']:coords=np.column_stack((coords[:,1],c['size'][0]-coords[:,0]))
        coords=(coords+[p['x'],p['y']])/resolution
        uv=bpy.data.objects[c['object']].data.uv_layers[delivery_uv]
        for li,co in zip(c['loops'],coords):uv.data[li].uv=co
        for fi in c['faces']:assignments[c['object']][str(fi)]={'chart':c['key'],'page':p['page']}
    for ob in objects:ob.data.uv_layers.active=ob.data.uv_layers[delivery_uv];ob.data.uv_layers[delivery_uv].active_render=True
    serial=[{k:v for k,v in c.items() if k not in ['pixels','size','loops']} | {'pixel_size':c['size'].tolist(),'placement':placements[c['key']]} for c in charts]
    return {'profile':{'density':density,'resolution':resolution,'padding':padding,'max_pages':max_pages},
            'pages':max(p['page'] for p in placements.values())+1,'charts':serial,'objects':assignments,
            'surface_area':sum(c['area'] for c in charts),
            'padded_pixel_area':sum((p['padded_bounds'][2]-p['padded_bounds'][0])*(p['padded_bounds'][3]-p['padded_bounds'][1]) for p in placements.values())}


def validate_layout(objects, layout, uv_name, tolerance=.2, max_anisotropy=1.5):
    profile=layout['profile'];res=profile['resolution'];rows=[];ids=[];pages={};errors=[]
    for ob in objects:
        me=ob.data;me.calc_loop_triangles();uv=me.uv_layers[uv_name]
        for tri in me.loop_triangles:
            info=layout['objects'][ob.name][str(tri.polygon_index)]
            coords=[uv.data[li].uv[:] for li in tri.loops]
            try:r=metrics.triangle_metrics([(ob.matrix_world@me.vertices[i].co)[:] for i in tri.vertices],coords,[res,res])
            except ValueError as exc:errors.append({'object':ob.name,'triangle':tri.index,'error':str(exc)});continue
            r['target']=layout['charts'][info['chart']].get('density',profile['density'])
            rows.append(r);ids.append({'object':ob.name,'triangle':tri.index,'face':tri.polygon_index,'page':info['page']})
            # Reuse is validated by the companion context consolidation. Every
            # instance still gets a density check; only owners enter unique-area
            # intersections. Directly authored overlaps need their own proof.
            if info.get('owner',info['chart'])==info['chart']:
                pages.setdefault(info['page'],[]).append(coords)
    summary=metrics.density_summary(rows,profile['density'],tolerance,max_anisotropy)
    bad=[i for i,r in enumerate(rows) if r['low']<r['target']*(1-tolerance) or r['high']>r['target']*(1+tolerance) or r['anisotropy']>max_anisotropy]
    summary.pop('failing_triangles');summary['failing_area_fraction']=sum(rows[i]['area'] for i in bad)/sum(r['area'] for r in rows)
    summary['density_classes']={str(t):metrics.density_summary([r for r in rows if r['target']==t],t,tolerance,max_anisotropy) for t in sorted({r['target'] for r in rows})}
    summary['failures']=[ids[i]|rows[i] for i in bad]
    summary['invalid']=errors
    alias_errors=[]
    for chart in layout['charts']:
        owner=chart.get('owner',chart['key'])
        if owner==chart['key']:continue
        other=layout['charts'][owner]
        def points(c):
            mesh=bpy.data.objects[c['object']].data
            return np.array([mesh.uv_layers[uv_name].data[li].uv[:] for fi in c['faces'] for li in mesh.polygons[fi].loop_indices])*res
        a,b=points(chart),points(other)
        if len(a)!=len(b):
            alias_errors.append({'chart':chart['key'],'owner':owner,'error':'different corner count'});continue
        distance=np.linalg.norm(a[:,None,:]-b[None,:,:],axis=-1)
        if max(distance.min(0).max(),distance.min(1).max())>.05:
            alias_errors.append({'chart':chart['key'],'owner':owner,'error':'declared aliases do not coincide within 0.05 texel'})
    summary['alias_errors']=alias_errors
    # Exact positive-area triangle intersections, separately for every page.
    helper=Path(__file__).resolve().parents[2]/'blender-high-low-baking/scripts/audit_unique_uv.py'
    spec=importlib.util.spec_from_file_location('unique_uv',helper);mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    summary['overlap_area_tolerance_pixels']=.01
    summary['overlap']={str(p):mod.audit(ts,tolerance=.01/(res*res)) for p,ts in pages.items()}
    summary['passed']=not errors and not alias_errors and not summary['failures'] and all(r['passed'] for r in summary['overlap'].values())
    return summary
