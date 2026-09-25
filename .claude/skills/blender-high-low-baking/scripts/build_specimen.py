"""Create original roof/panel bake specimens in the live Blender session.

Call run(output_directory) through the existing Blender connection. Restores the
active scene; does not open/save over the operator's model. Images stay outside repo.
"""
import importlib.util
import json
import math
from pathlib import Path

import bpy,bmesh
from mathutils import Vector


def smoothstep(x):
    x=max(0,min(1,x));return x*x*(3-2*x)


def roof_relief(x,y,pitch=.30,course=.34):
    cap=(.5+.5*math.cos(2*math.pi*x/pitch))**4
    r=(y/course)%1
    lip=(1-r)*smoothstep(r/.055)
    return .006+.052*cap+.012*lip


def panel_relief(x,y):
    def bar(cx,cy,w,h):
        d=min(w/2-abs(x-cx),h/2-abs(y-cy))
        return .035*smoothstep(d/.015)
    return .004+max(bar(-.5,0,.085,1.3),bar(.5,0,.085,1.3),
                    bar(0,-.61,1,.085),bar(0,.61,1,.085),
                    bar(-.12,.08,.09,.76),bar(.08,-.26,.48,.09))


def material(name,color):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.6
    return m


def slab(scene,name,height,nx,ny,mat):
    v=[];f=[];top_faces=[]
    for layer in (0,1):
        for j in range(ny+1):
            y=-.8+1.6*j/ny
            for i in range(nx+1):
                x=-.9+1.8*i/nx;v.append((x,y,height(x,y) if layer==0 else -.18))
    n=(nx+1)*(ny+1)
    for j in range(ny):
        for i in range(nx):
            a=j*(nx+1)+i;b=a+1;c=b+nx+1;d=a+nx+1
            top_faces.extend([(a,b,c),(a,c,d)])
    f.extend(top_faces);f.extend([tuple(n+i for i in reversed(t)) for t in top_faces])
    boundary=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+[ny*(nx+1)+i for i in reversed(range(nx))]+[j*(nx+1) for j in reversed(range(1,ny))]
    for a,b in zip(boundary,boundary[1:]+boundary[:1]):f.extend([(a,n+a,n+b),(a,n+b,b)])
    me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.materials.append(mat);me.materials.append(material(name+'_Sides',(.24,.26,.28)));me.update()
    uv=me.uv_layers.new(name='BakeUV')
    for p in me.polygons:
        p.material_index=0 if p.index<len(top_faces) else 1;p.use_smooth=p.material_index==0
        if p.material_index==0:
            for li in p.loop_indices:
                co=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(.07+.86*(co.x+.9)/1.8,.07+.86*(co.y+.8)/1.6)
    bm=bmesh.new();bm.from_mesh(me)
    for e in bm.edges:
        if len({f.material_index for f in e.link_faces})>1:e.smooth=False
    bm.to_mesh(me);bm.free();me.update()
    ob=bpy.data.objects.new(name,me);scene.collection.objects.link(ob)
    return ob,n,top_faces


def run(output_dir,version='01'):
    output_dir=Path(output_dir);output_dir.mkdir(parents=True,exist_ok=True)
    spec=importlib.util.spec_from_file_location('bake_pair',Path(__file__).with_name('bake_pair.py'));lib=importlib.util.module_from_spec(spec);spec.loader.exec_module(lib)
    original=bpy.context.scene
    assert bpy.data.scenes.get('Baking_Specimen_'+version) is None, 'Specimen already exists; use its saved evidence or choose a new version'
    s=bpy.data.scenes.new('Baking_Specimen_'+version);s['bake_scratch']=True;bpy.context.window.scene=s
    s.render.engine='CYCLES';s.cycles.samples=24;s.render.resolution_x=768;s.render.resolution_y=768;s.render.resolution_percentage=100
    s.world=bpy.data.worlds.new('Specimen_World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.18,.18,.18,1);s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.4
    s.view_settings.view_transform='AgX'
    camdata=bpy.data.cameras.new('Specimen_Camera');cam=bpy.data.objects.new('Specimen_Camera',camdata);s.collection.objects.link(cam);s.camera=cam;cam.location=(2,-3,4.8);cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=2.5
    ld=bpy.data.lights.new('Specimen_Key','SUN');ld.energy=3;ld.angle=.05;light=bpy.data.objects.new('Specimen_Key',ld);s.collection.objects.link(light)
    reports=[];all_objects=[]
    try:
        for kind,relief in [('Roof',roof_relief),('Panel',panel_relief)]:
            base=lambda x,y:.055*y*y if kind=='Roof' else 0
            low,n,faces=slab(s,kind+'_Solid_Low',base,12,10,material(kind+'_Low_Mat',(.36,.39,.42)))
            high,_,_=slab(s,kind+'_Solid_High',lambda x,y:base(x,y)+relief(x,y),240,216,material(kind+'_High_Mat',(.36,.39,.42)))
            # Receiver is an exact top-surface proxy of the closed solid, with its corner normals.
            me=bpy.data.meshes.new(kind+'_Receiver');me.from_pydata([list(v.co) for v in low.data.vertices[:n]],[],faces);me.materials.append(low.data.materials[0]);me.update();uv=me.uv_layers.new(name='BakeUV')
            normals=[]
            for p in me.polygons:
                p.use_smooth=True
                src=low.data.polygons[p.index]
                for dst_li,src_li in zip(p.loop_indices,src.loop_indices):
                    uv.data[dst_li].uv=low.data.uv_layers.active.data[src_li].uv;normals.append(low.data.corner_normals[src_li].vector)
            me.normals_split_custom_set(normals)
            receiver=bpy.data.objects.new(kind+'_Receiver',me);s.collection.objects.link(receiver)
            cage=receiver.copy();cage.data=receiver.data.copy();cage.name=kind+'_Cage';s.collection.objects.link(cage)
            for v in cage.data.vertices:v.co.z+=.16
            for o in all_objects:o.hide_render=True;o.hide_set(True)
            low.hide_render=True
            normal,nr=lib.bake_pair(receiver,[high],cage,output_dir,kind+'_'+version,1024,16,16,'NORMAL')
            ao,ar=lib.bake_pair(receiver,[high],cage,output_dir,kind+'_'+version,1024,16,32,'AO',.12)
            node=lib.wire_normal(low.data.materials[0],normal,'BakeUV')
            receiver.hide_render=True;cage.hide_render=True
            low.hide_set(False);high.hide_set(False)
            for light_id,vec in [('A',(3,-4,6)),('B',(-4,3,6))]:
                light.rotation_euler=Vector(vec).to_track_quat('Z','Y').to_euler()
                for mode in ['High','Flat','Baked']:
                    low.hide_render=mode=='High';high.hide_render=mode!='High';node.inputs['Strength'].default_value=1 if mode=='Baked' else 0
                    s.render.filepath=str(output_dir/f'{kind}_{light_id}_{mode}.png');bpy.ops.render.render(write_still=True)
            node.inputs['Strength'].default_value=1
            reports.append(dict(kind=kind,low_vertices=len(low.data.vertices),low_triangles=len(low.data.polygons),high_vertices=len(high.data.vertices),high_triangles=len(high.data.polygons),normal=nr,ao=ar))
            all_objects.extend([low,high,receiver,cage])
        for o in all_objects:o.hide_render=True;o.hide_set(True)
        low.hide_render=False;low.hide_set(False)
        (output_dir/'specimen_results.json').write_text(json.dumps({'blender':bpy.app.version_string,'specimens':reports,'status':'Baked; image/data review required','engine_validation':'Not performed'},indent=2))
        bpy.ops.wm.save_as_mainfile(filepath=str(output_dir/('Baking_Specimens_'+version+'.blend')),copy=True)
        return {'scene':s.name,'output':str(output_dir),'specimens':[{k:r[k] for k in ['kind','low_vertices','low_triangles','high_vertices','high_triangles']} for r in reports]}
    finally:
        bpy.context.window.scene=original
