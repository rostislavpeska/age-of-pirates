"""Build switchable, editable lab scenes and fixed-camera evidence."""
import bpy,json,math,os
from pathlib import Path
import numpy as np
from mathutils import Vector

out=Path(os.environ['TEMP'])/'codex-uv-scattering-20260927'
source=bpy.data.scenes['S12_Groups']
faces=json.loads((out/'faces.json').read_text());meta={f['id']:f for f in faces}
results=json.loads((out/'results.json').read_text())
manifest=[]
sewing=[]
edge_data=json.loads((out/'adjacency.json').read_text())['edges']
def sew_mesh(ob,ids,plan):
    old=ob.data;parent=list(range(len(old.vertices)));lookup={fid:i for i,fid in enumerate(ids)}
    def root(i):
        while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
        return i
    for e in edge_data:
        a,b=faces[e['a']],faces[e['b']]
        if a['id'] not in lookup or b['id'] not in lookup or a['hidden'] or b['hidden']:continue
        au=np.array(plan[str(a['id'])]['uv']);bu=np.array(plan[str(b['id'])]['uv'])
        if max(np.linalg.norm(au[e['ai']]-bu[e['bi']]),np.linalg.norm(au[e['aj']]-bu[e['bj']]))>2e-6:continue
        pa=old.polygons[lookup[a['id']]];pb=old.polygons[lookup[b['id']]]
        for ka,kb in [('ai','bi'),('aj','bj')]:parent[root(pb.vertices[e[kb]])]=root(pa.vertices[e[ka]])
    roots={};verts=[];mapping=[];drift=0
    for v in old.vertices:
        r=root(v.index)
        if r not in roots:roots[r]=len(verts);verts.append(old.vertices[r].co[:])
        mapping.append(roots[r]);drift=max(drift,(v.co-old.vertices[r].co).length)
    normals=[n.vector[:] for n in old.corner_normals]
    me=bpy.data.meshes.new(ob.name+'_sewn');me.from_pydata(verts,[],[[mapping[v] for v in p.vertices] for p in old.polygons]);me.update()
    for mat in old.materials:me.materials.append(mat)
    for p,q in zip(me.polygons,old.polygons):p.material_index=q.material_index;p.use_smooth=q.use_smooth
    for old_uv in old.uv_layers:
        new_uv=me.uv_layers.new(name=old_uv.name)
        for a,b in zip(new_uv.data,old_uv.data):a.uv=b.uv
    for a in old.attributes:
        if a.domain=='FACE' and a.data_type=='INT' and a.name not in me.attributes:
            dest=me.attributes.new(a.name,'INT','FACE')
            for x,y in zip(dest.data,a.data):x.value=y.value
    me.normals_split_custom_set(normals)
    error=max((Vector(a)-b.vector).length for a,b in zip(normals,me.corner_normals))
    sewing.append({'object':ob.name,'before_vertices':len(old.vertices),'after_vertices':len(me.vertices),'faces':len(me.polygons),'max_vertex_displacement_world':drift,'max_corner_normal_vector_error':error})
    ob.data=me
for name in results:
    plan=json.loads((out/(name+'.json')).read_text())
    sc=bpy.data.scenes.new('LAB_'+name);sc['purpose']='Chart-continuity experiment; not approved texture coordinates'
    sc['diagnostic_uv']='CandidateUV is current for this experiment; UVMap preserves S12'
    sc.world=source.world.copy() if source.world else bpy.data.worlds.new('LabWorld')
    for old in source.objects:
        if old.type!='MESH':continue
        ob=old.copy();ob.data=old.data.copy();ob.name=name+'_'+old['atlas'];sc.collection.objects.link(ob)
        me=ob.data;ids=json.loads(ob['source_face_ids'])
        if name=='Sewn100':
            sew_mesh(ob,ids,plan);me=ob.data
        uv=me.uv_layers.new(name='CandidateUV');me.uv_layers.active=uv
        attr=me.color_attributes.new(name='UV_Island_Color',type='BYTE_COLOR',domain='CORNER');me.color_attributes.active_color=attr
        ca=me.attributes.new(name='Measured_Chart_ID',type='INT',domain='FACE')
        # Attribute creation may reallocate CustomData; reacquire RNA handles.
        uv=me.uv_layers['CandidateUV'];attr=me.color_attributes['UV_Island_Color'];ca=me.attributes['Measured_Chart_ID']
        for p,fid in zip(me.polygons,ids):
            item=plan[str(fid)];ca.data[p.index].value=item['chart']
            for j,l in enumerate(p.loop_indices):
                uv.data[l].uv=item['uv'][j]
                attr.data[l].color=(*item['color'],1)
        ob['chart_color_legend']='Different measured UV chart; shared texture address does not mean connected. Hidden faces black.'
    bpy.context.window.scene=sc
    sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=1400;sc.render.resolution_y=1050;sc.render.resolution_percentage=100
    sc.render.image_settings.file_format='PNG';sc.view_settings.view_transform='Standard'
    sh=sc.display.shading;sh.light='FLAT';sh.color_type='VERTEX';sh.show_shadows=False;sh.show_cavity=False;sh.show_specular_highlight=False
    sh.show_object_outline=True;sh.background_type='WORLD';sc.world.color=(.035,.04,.05)
    cam=bpy.data.objects.new(name+'_Camera',bpy.data.cameras.new(name+'_Camera'));sc.collection.objects.link(cam);sc.camera=cam;cam.data.type='ORTHO';cam.data.clip_start=.01
    pts=np.array([list(o.matrix_world@v.co) for o in sc.objects if o.type=='MESH' for v in o.data.vertices])
    subsets={'Overview':pts,'Rear':pts,'Under':pts,'Joinery':np.array([p for f in faces if 'RearHall_Front' in f['part'] or 'WestHall_CourtJoinery' in f['part'] for p in f['points']])}
    dirs={'Overview':(22,-30,22),'Rear':(-25,28,20),'Under':(20,-30,-16),'Joinery':(15,-25,12)}
    for label,ps in subsets.items():
        d=Vector(dirs[label]);cam.rotation_euler=(-d).to_track_quat('-Z','Y').to_euler();basis=np.asarray(cam.rotation_euler.to_matrix())
        pr=ps@basis;lo=pr.min(0);hi=pr.max(0);center=Vector(basis@((lo+hi)*.5));cam.location=center+d*2
        cam.data.ortho_scale=max(hi[0]-lo[0],(hi[1]-lo[1])*1400/1050)*1.1
        sc.render.filepath=str(out/(name+'_'+label+'.png'));bpy.ops.render.render(write_still=True)
        manifest.append({'method':name,'view':label,'file':str(out/(name+'_'+label+'.png'))})
    # A real bitmap sampled with CandidateUV, not Generated/Object coordinates.
    checker=bpy.data.images.get('LAB_Orientation_Checker')
    if checker is None:
        checker=bpy.data.images.new('LAB_Orientation_Checker',width=1024,height=1024)
        checker.generated_type='COLOR_GRID';checker.pack()
    cm=bpy.data.materials.get('LAB_CheckerMaterial')
    if cm is None:
        cm=bpy.data.materials.new('LAB_CheckerMaterial');cm.use_nodes=True
        nt=cm.node_tree;tx=nt.nodes.new('ShaderNodeTexImage');tx.image=checker
        co=nt.nodes.new('ShaderNodeUVMap');co.uv_map='CandidateUV';nt.links.new(co.outputs['UV'],tx.inputs['Vector'])
        nt.links.new(tx.outputs['Color'],nt.nodes.get('Principled BSDF').inputs['Base Color']);nt.nodes.active=tx
    saved=[]
    for ob in sc.objects:
        if ob.type!='MESH':continue
        saved.append((ob,list(ob.data.materials),[p.material_index for p in ob.data.polygons]))
        ob.data.materials.clear();ob.data.materials.append(cm)
        for p in ob.data.polygons:p.material_index=0
    sh.color_type='TEXTURE'
    sc.render.filepath=str(out/(name+'_Checker.png'));bpy.ops.render.render(write_still=True)
    manifest.append({'method':name,'view':'Checker','file':str(out/(name+'_Checker.png'))})
    for ob,mats,indices in saved:
        ob.data.materials.clear()
        for mat in mats:ob.data.materials.append(mat)
        for p,i in zip(ob.data.polygons,indices):p.material_index=i
    sh.color_type='VERTEX'
    # Review begins at the same useful overall angle, with editable overlays.
    d=Vector(dirs['Overview']);center=Vector((pts.min(0)+pts.max(0))*.5)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                space=area.spaces.active;space.shading.type='SOLID';space.shading.color_type='VERTEX';space.shading.light='FLAT'
                space.overlay.show_overlays=True;space.region_3d.view_rotation=(-d).to_track_quat('-Z','Y');space.region_3d.view_location=center;space.region_3d.view_distance=26;space.region_3d.view_perspective='ORTHO'
    cam.hide_set(True)
    sc['metrics']=json.dumps(results[name]['metrics'])
    (out/'render_progress.json').write_text(json.dumps({'last_completed':name}))
bpy.context.window.scene=bpy.data.scenes['LAB_Strip100']
for ob in bpy.context.scene.objects:ob.select_set(False)
ob=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('atlas')=='A');ob.select_set(True);bpy.context.view_layer.objects.active=ob
readme=bpy.data.texts.new('SCATTERING_README');readme.write('Switch scenes LAB_Baseline, LAB_Planar, LAB_Strip65, LAB_Strip100, LAB_Xatlas and native solver comparisons.\nColors identify ACTUAL UV-connected charts, not reuse groups.\nUVMap preserves S12; CandidateUV holds each experiment. Diagnostic sheets are outside 0..1 by design. No runtime packing.\nStrip100 crosses hard folds and needs tangent/material review. Existing UV overlap defects are retained by rigid methods.\nGeometry and custom normals are unchanged. See external results.json and research report.\n')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'Scattering_Comparison.blend'),compress=True)
(out/'photo_manifest.json').write_text(json.dumps(manifest,indent=2))
(out/'review_done.json').write_text(json.dumps({'pid':os.getpid(),'file':bpy.data.filepath,'scene':bpy.context.scene.name,'images':len(manifest)}))
(out/'sewing_validation.json').write_text(json.dumps(sewing,indent=2))
