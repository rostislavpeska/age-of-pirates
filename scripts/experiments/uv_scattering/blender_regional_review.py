"""Create editable regional prototype scenes from the isolated comparison file."""
import bpy,json,os,math
from pathlib import Path
from collections import defaultdict
import numpy as np
from mathutils import Vector

source=Path(os.environ['OneDrive'])/'Korean Buildings Blender/snapshots/2026-09-27-scattering-lab'
out=Path(os.environ['TEMP'])/'codex-regional-uv-20260927'
faces=json.loads((source/'faces.json').read_text());meta={f['id']:f for f in faces};edges=json.loads((source/'adjacency.json').read_text())['edges']
regions=json.loads((out/'policy.json').read_text())['regions']
oldscene=bpy.data.scenes['LAB_Sewn100'];records={}
for ob in oldscene.objects:
    if ob.type!='MESH':continue
    for p,fid in zip(ob.data.polygons,json.loads(ob['source_face_ids'])):
        records[fid]={'points':[list(ob.matrix_world@ob.data.vertices[v].co) for v in p.vertices],'keys':[(ob.name,v) for v in p.vertices],'normals':[ob.data.corner_normals[l].vector[:] for l in p.loop_indices],'smooth':p.use_smooth}
checker=bpy.data.images.new('REGION_Checker',width=1024,height=1024);checker.generated_type='COLOR_GRID';checker.pack()
cm=bpy.data.materials.new('REGION_Checker');cm.use_nodes=True;nt=cm.node_tree;tx=nt.nodes.new('ShaderNodeTexImage');tx.image=checker
uc=nt.nodes.new('ShaderNodeUVMap');uc.uv_map='CandidateUV';nt.links.new(uc.outputs['UV'],tx.inputs['Vector']);nt.links.new(tx.outputs['Color'],nt.nodes.get('Principled BSDF').inputs['Base Color']);nt.nodes.active=tx
audit={}
for name in ['Previous','Regional','RegionalBroad']:
    plan=json.loads((source/'Sewn100.json' if name=='Previous' else out/(name+'.json')).read_text())
    sc=bpy.data.scenes.new('REVIEW_'+name);sc.world=oldscene.world;sc['review_version']=name
    sc['scope']='Regional UV construction prototype; new underside allocation and normal-channel validation pending'
    bypart=defaultdict(list)
    for f in faces:bypart[f['part']].append(f['id'])
    parts=[]
    for part,fids in bypart.items():
        keymap={};verts=[];poly=[];parent=[]
        for fid in fids:
            row=[]
            for key,point in zip(records[fid]['keys'],records[fid]['points']):
                if key not in keymap:keymap[key]=len(verts);verts.append(point);parent.append(len(parent))
                row.append(keymap[key])
            poly.append(row)
        def root(i):
            while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
            return i
        lookup={fid:i for i,fid in enumerate(fids)}
        if name!='Previous' and part in regions:
            for e in edges:
                a,b=faces[e['a']]['id'],faces[e['b']]['id']
                if a not in lookup or b not in lookup:continue
                ua,ub=np.array(plan[str(a)]['uv']),np.array(plan[str(b)]['uv'])
                if max(np.linalg.norm(ua[e['ai']]-ub[e['bi']]),np.linalg.norm(ua[e['aj']]-ub[e['bj']]))>2e-6:continue
                for ka,kb in [('ai','bi'),('aj','bj')]:
                    ia,ib=poly[lookup[a]][e[ka]],poly[lookup[b]][e[kb]]
                    if np.linalg.norm(np.array(verts[ia])-verts[ib])<=2e-5:parent[root(ib)]=root(ia)
        compact={};points=[]
        for i in range(len(verts)):
            r=root(i)
            if r not in compact:compact[r]=len(points);points.append(verts[r])
        newpolys=[[compact[root(v)] for v in row] for row in poly]
        me=bpy.data.meshes.new(name+'_'+part);me.from_pydata(points,[],newpolys);me.update()
        ob=bpy.data.objects.new(part.replace('N8_N1_K22_',''),me);sc.collection.objects.link(ob);ob['source_part']=part;ob['source_face_ids']=json.dumps(fids)
        me.materials.append(cm)
        me.uv_layers.new(name='CandidateUV');me.uv_layers.new(name='OriginalUVMap')
        me.color_attributes.new(name='UV_Island_Color',type='BYTE_COLOR',domain='CORNER')
        for field,typ in [('SourceFaceID','INT'),('MaterialFamily','INT'),('OriginalHidden','BOOLEAN'),('ChartID','INT')]:me.attributes.new(field,typ,'FACE')
        uv=me.uv_layers['CandidateUV'];orig=me.uv_layers['OriginalUVMap'];color=me.color_attributes['UV_Island_Color'];normals=[]
        for p,fid in zip(me.polygons,fids):
            item=plan[str(fid)];f=meta[fid];p.use_smooth=records[fid]['smooth']
            for j,l in enumerate(p.loop_indices):
                uv.data[l].uv=item['uv'][j];orig.data[l].uv=f['uv'][j];color.data[l].color=(*item['color'],1);normals.append(records[fid]['normals'][j])
            me.attributes['SourceFaceID'].data[p.index].value=fid;me.attributes['MaterialFamily'].data[p.index].value=f['physical_family'];me.attributes['OriginalHidden'].data[p.index].value=f['hidden'];me.attributes['ChartID'].data[p.index].value=item['chart']
        me.normals_split_custom_set(normals);me.uv_layers.active=me.uv_layers['CandidateUV'];me.uv_layers['CandidateUV'].active_render=True;me.color_attributes.active_color=me.color_attributes['UV_Island_Color']
        links=defaultdict(list);uf=list(range(len(me.polygons)))
        def find(i):
            while uf[i]!=i:uf[i]=uf[uf[i]];i=uf[i]
            return i
        uv=me.uv_layers['CandidateUV']
        for p in me.polygons:
            ls=list(p.loop_indices)
            for a,b in zip(ls,ls[1:]+ls[:1]):
                va,vb=me.loops[a].vertex_index,me.loops[b].vertex_index
                links[tuple(sorted((va,vb)))].append((p.index,{va:uv.data[a].uv.copy(),vb:uv.data[b].uv.copy()}))
        for key,rs in links.items():
            if len(rs)!=2:continue
            (a,ua),(b,ub)=rs
            if max((ua[v]-ub[v]).length for v in key)<=2e-6:uf[find(b)]=find(a)
        charts=defaultdict(list)
        for p in me.polygons:charts[find(p.index)].append(p.index)
        visible_charts=sum(any(not meta[fids[i]]['hidden'] for i in g) for g in charts.values())
        poserr=max((Vector(records[fid]['points'][j])-me.vertices[p.vertices[j]].co).length for p,fid in zip(me.polygons,fids) for j in range(len(p.vertices)))
        normerr=max((Vector(a)-b.vector).length for a,b in zip(normals,me.corner_normals))
        uverr=max(np.linalg.norm(np.array(uv.data[l].uv)-plan[str(fid)]['uv'][j]) for p,fid in zip(me.polygons,fids) for j,l in enumerate(p.loop_indices))
        assert poserr<=2e-5 and normerr<.001 and uverr<1e-6
        parts.append({'part':part,'faces':len(fids),'native_charts_all_faces':len(charts),'charts_touching_original_visible_faces':visible_charts,'max_position_delta_from_previous':poserr,'max_normal_delta':normerr,'uv_write_error':float(uverr)})
    audit[name]=parts
    bpy.context.window.scene=sc
    sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=1400;sc.render.resolution_y=1100;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.view_settings.view_transform='Standard'
    sh=sc.display.shading;sh.color_type='VERTEX';sh.light='FLAT';sh.show_shadows=False;sh.show_cavity=False;sh.show_specular_highlight=False
    cam=bpy.data.objects.new('ReviewCamera',bpy.data.cameras.new('ReviewCamera'));sc.collection.objects.link(cam);sc.camera=cam;cam.data.type='ORTHO';cam.data.clip_start=.001
    def render(label,select,direction):
        obs=[o for o in sc.objects if o.type=='MESH']
        for o in obs:o.hide_render=not select(o)
        pts=np.array([v.co[:] for o in obs if not o.hide_render for v in o.data.vertices]);d=Vector(direction);cam.rotation_euler=(-d).to_track_quat('-Z','Y').to_euler();basis=np.array(cam.rotation_euler.to_matrix());pr=pts@basis;lo=pr.min(0);hi=pr.max(0)
        cam.location=Vector(basis@((lo+hi)*.5))+d*2;cam.data.ortho_scale=max(hi[0]-lo[0],(hi[1]-lo[1])*1400/1100)*1.1
        sc.render.filepath=str(out/(name+'_'+label+'.png'));bpy.ops.render.render(write_still=True)
    render('Overview',lambda o:True,(22,-30,22))
    render('TowerUnderside',lambda o:'Tower_' in o.get('source_part',''),(18,-28,-16))
    render('LowerEave',lambda o:o.get('source_part','')=='N8_N1_K22_Tower_LowerEave',(12,-20,-12))
    render('UpperRoof',lambda o:o.get('source_part','')=='N8_N1_K22_Tower_UpperPaljakRoof',(12,-20,-12))
    sh.color_type='TEXTURE';render('LowerChecker',lambda o:o.get('source_part','')=='N8_N1_K22_Tower_LowerEave',(12,-20,-12));sh.color_type='VERTEX'
    for o in sc.objects:o.hide_render=False
    cam.hide_set(True)
bpy.context.window.scene=bpy.data.scenes['REVIEW_Regional']
readme=bpy.data.texts.new('REGIONAL_REVIEW_README');readme.write('Use the UV Review sidebar in the dedicated launched review window. Previous / Regional / Broader search. Roof undersides are now included in diagnostic charts; visibility, atlas rebake and tangent-normal approval are still pending. Other assemblies preserve the previous candidate. SourceFaceID and OriginalHidden attributes preserve provenance. CandidateUV is the editable prototype map.\n')
(out/'native_audit.json').write_text(json.dumps(audit,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(out/'Regional_Roof_Review.blend'),compress=True)
(out/'build_complete.json').write_text(json.dumps({'file':bpy.data.filepath,'scenes':['REVIEW_'+x for x in audit],'faces_per_version':sum(x['faces'] for x in audit['Regional'])}))
