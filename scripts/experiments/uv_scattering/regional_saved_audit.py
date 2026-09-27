"""Independently check saved review geometry, UVs and island color membership."""
import bpy, json
from pathlib import Path
from collections import defaultdict
root=Path(bpy.data.filepath).parent
result={}
for variant in ('Previous','Regional','RegionalBroad'):
    scene=bpy.data.scenes['REVIEW_'+variant]
    seen=[];roof_counts={};max_uv_error=0.
    plan=json.loads((root/(variant+'.json')).read_text()) if variant!='Previous' else None
    for ob in scene.objects:
        if ob.type!='MESH':continue
        me=ob.data;uv=me.uv_layers['CandidateUV'];ids=me.attributes['SourceFaceID']
        seen.extend(v.value for v in ids.data)
        assert all(len(p.vertices)>=4 for p in me.polygons)
        links=defaultdict(list);parent=list(range(len(me.polygons)))
        def find(a):
            while parent[a]!=a:a=parent[a]
            return a
        for p in me.polygons:
            ls=list(p.loop_indices);fid=ids.data[p.index].value
            if plan:
                for j,l in enumerate(ls):
                    max_uv_error=max(max_uv_error,max(abs(uv.data[l].uv[k]-plan[str(fid)]['uv'][j][k]) for k in (0,1)))
            for a,b in zip(ls,ls[1:]+ls[:1]):
                va,vb=me.loops[a].vertex_index,me.loops[b].vertex_index
                links[tuple(sorted((va,vb)))].append((p.index,{va:uv.data[a].uv.copy(),vb:uv.data[b].uv.copy()}))
        for key,rows in links.items():
            if len(rows)!=2:continue
            (a,ua),(b,ub)=rows
            if max((ua[v]-ub[v]).length for v in key)<=2e-6:parent[find(b)]=find(a)
        if plan and plan[str(ids.data[0].value)]['policy_region']:
            native_to_color=defaultdict(set);color_to_native=defaultdict(set)
            for p in me.polygons:
                native=find(p.index);label=me.attributes['ChartID'].data[p.index].value
                native_to_color[native].add(label);color_to_native[label].add(native)
            assert all(len(v)==1 for v in native_to_color.values())
            assert all(len(v)==1 for v in color_to_native.values())
            roof_counts[ob['source_part']]=len(native_to_color)
    assert len(seen)==5234 and len(set(seen))==5234
    assert max_uv_error<1e-6
    result[variant]={'faces':len(seen),'unique_face_ids':len(set(seen)),'max_uv_error':max_uv_error,'roof_native_islands':roof_counts,'roof_color_membership':'matches native islands'}
(root/'saved_regional_audit.json').write_text(json.dumps(result,indent=2))
print('SAVED_REGIONAL_AUDIT_PASS',json.dumps(result))
