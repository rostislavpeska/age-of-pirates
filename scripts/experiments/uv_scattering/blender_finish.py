"""Additional roof-only inspection and persistent checker scenes for the lab."""
import bpy,json,os
from pathlib import Path
import numpy as np
from mathutils import Vector
out=Path(os.environ['TEMP'])/'codex-uv-scattering-20260927'
meta={f['id']:f for f in json.loads((out/'faces.json').read_text())}
names=list(json.loads((out/'results.json').read_text()))
for name in names:
    src=bpy.data.scenes['LAB_'+name]
    sc=bpy.data.scenes.new('CUT_'+name);sc.world=src.world;sc.render.engine='BLENDER_WORKBENCH'
    sc['purpose']='Presentation cutaway: only the unchanged WestHall roof component is shown'
    points=[]
    for old in src.objects:
        if old.type!='MESH':continue
        ids=json.loads(old['source_face_ids']);selected=[p for p,fid in zip(old.data.polygons,ids) if meta[fid]['part']=='N8_N1_K22_WestHall_PaljakRoof']
        if not selected:continue
        vis=sorted({v for p in selected for v in p.vertices});remap={v:i for i,v in enumerate(vis)}
        verts=[old.data.vertices[v].co[:] for v in vis];points.extend([list(old.matrix_world@Vector(v)) for v in verts])
        me=bpy.data.meshes.new('Roof_Cutaway');me.from_pydata(verts,[],[[remap[v] for v in p.vertices] for p in selected]);me.update()
        ob=bpy.data.objects.new(name+'_RoofCutaway',me);sc.collection.objects.link(ob);ob.matrix_world=old.matrix_world
        ca=me.color_attributes.new(name='UV_Island_Color',type='BYTE_COLOR',domain='CORNER');me.color_attributes.active_color=ca
        for p,q in zip(me.polygons,selected):
            for a,b in zip(p.loop_indices,q.loop_indices):ca.data[a].color=old.data.color_attributes['UV_Island_Color'].data[b].color
    sc.render.resolution_x=1400;sc.render.resolution_y=900;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.view_settings.view_transform='Standard'
    sh=sc.display.shading;sh.light='FLAT';sh.color_type='VERTEX';sh.show_shadows=False;sh.show_cavity=False;sh.show_specular_highlight=False
    cam=bpy.data.objects.new('CutawayCamera',bpy.data.cameras.new('CutawayCamera'));sc.collection.objects.link(cam);sc.camera=cam;cam.data.type='ORTHO'
    d=Vector((12,-20,-14));cam.rotation_euler=(-d).to_track_quat('-Z','Y').to_euler();basis=np.array(cam.rotation_euler.to_matrix());pts=np.array(points);pr=pts@basis;lo=pr.min(0);hi=pr.max(0)
    cam.location=Vector(basis@((lo+hi)*.5))+d;cam.data.ortho_scale=max(hi[0]-lo[0],(hi[1]-lo[1])*1400/900)*1.12
    bpy.context.window.scene=sc;sc.render.filepath=str(out/(name+'_Eaves.png'));bpy.ops.render.render(write_still=True);cam.hide_set(True)
cm=bpy.data.materials.new('LAB_CheckerMaterial');cm.use_nodes=True
checker=bpy.data.images.new('LAB_Orientation_Checker',width=1024,height=1024);checker.generated_type='COLOR_GRID';checker.pack()
nt=cm.node_tree;tx=nt.nodes.new('ShaderNodeTexImage');tx.image=checker;co=nt.nodes.new('ShaderNodeUVMap');co.uv_map='CandidateUV'
nt.links.new(co.outputs['UV'],tx.inputs['Vector']);nt.links.new(tx.outputs['Color'],nt.nodes.get('Principled BSDF').inputs['Base Color']);nt.nodes.active=tx
for name in ['Baseline','Protected','Sewn100']:
    src=bpy.data.scenes['LAB_'+name];sc=bpy.data.scenes.new('CHECK_'+name);sc.world=src.world
    for old in src.objects:
        if old.type!='MESH':continue
        ob=old.copy();ob.data=old.data.copy();sc.collection.objects.link(ob)
        if old['atlas']!='H':
            ob.data.materials.clear();ob.data.materials.append(cm)
            for p in ob.data.polygons:p.material_index=0
        ob.data.uv_layers.active=ob.data.uv_layers['CandidateUV']
    sc['purpose']='Persistent bitmap checker using CandidateUV; H remains hidden-class material'
bpy.context.window.scene=bpy.data.scenes['LAB_Sewn100']
bpy.ops.wm.save_as_mainfile(filepath=str(out/'Scattering_Comparison.blend'),compress=True)
