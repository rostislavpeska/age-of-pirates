"""Independent readback of saved review geometry, normals, UVs and native islands."""
import bpy,json,os
from pathlib import Path
from collections import defaultdict
import numpy as np
out=Path(os.environ['TEMP'])/'codex-uv-scattering-20260927'
source={o['atlas']:o for o in bpy.data.scenes['S12_Groups'].objects if o.type=='MESH'}
report={}
for sc in bpy.data.scenes:
    if not sc.name.startswith('LAB_'):continue
    checks=[];total=0;single=0
    plan=json.loads((out/(sc.name[4:]+'.json')).read_text())
    for ob in sc.objects:
        if ob.type!='MESH':continue
        me=ob.data;old=source[ob['atlas']].data
        same_topology=len(me.vertices)==len(old.vertices) and all(tuple(p.vertices)==tuple(q.vertices) for p,q in zip(me.polygons,old.polygons))
        if same_topology:
            position_error=max((a.co-b.co).length for a,b in zip(me.vertices,old.vertices))
        else:
            position_error=max((me.vertices[me.loops[i].vertex_index].co-old.vertices[old.loops[i].vertex_index].co).length for i in range(len(me.loops)))
        normal_error=max((a.vector-b.vector).length for a,b in zip(me.corner_normals,old.corner_normals))
        old_uv_error=max((a.uv-b.uv).length for a,b in zip(me.uv_layers['UVMap'].data,old.uv_layers['UVMap'].data))
        uv=me.uv_layers['CandidateUV'];links=defaultdict(list);parent=list(range(len(me.polygons)))
        ids=json.loads(ob['source_face_ids'])
        write_error=max(np.linalg.norm(np.array(uv.data[l].uv)-plan[str(fid)]['uv'][j]) for p,fid in zip(me.polygons,ids) for j,l in enumerate(p.loop_indices))
        def root(i):
            while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
            return i
        for p in me.polygons:
            loops=list(p.loop_indices)
            for l,n in zip(loops,loops[1:]+loops[:1]):
                a,b=me.loops[l].vertex_index,me.loops[n].vertex_index
                links[tuple(sorted((a,b)))].append((p.index,{a:uv.data[l].uv.copy(),b:uv.data[n].uv.copy()}))
        for key,records in links.items():
            if len(records)!=2:continue
            (a,ua),(b,ub)=records
            if max((ua[v]-ub[v]).length for v in key)<=2e-6:parent[root(b)]=root(a)
        counts=defaultdict(int)
        for p in me.polygons:counts[root(p.index)]+=1
        if ob['atlas']!='H':total+=len(counts);single+=sum(v==1 for v in counts.values())
        checks.append(dict(page=ob['atlas'],same_topology=same_topology,faces=len(me.polygons),vertices=len(me.vertices),position_error=position_error,normal_error=normal_error,original_uv_error=old_uv_error,planned_uv_write_error=float(write_error),authored_triangles=sum(len(p.vertices)==3 for p in me.polygons)))
    report[sc.name]={'native_visible_charts':total,'native_singletons':single,'checks':checks}
(out/'saved_file_audit.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:{'charts':v['native_visible_charts'],'singletons':v['native_singletons'],'max_position_error':max(x['position_error'] for x in v['checks']),'max_normal_error':max(x['normal_error'] for x in v['checks'])} for k,v in report.items()},indent=2))
