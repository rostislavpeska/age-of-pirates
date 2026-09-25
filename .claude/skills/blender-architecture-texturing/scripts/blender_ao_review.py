"""Neutral checker/AO review and explicit-scope AO baking in Blender.

Use on task-owned candidate meshes, after blender_uv_layout.validate_layout passes.
Body textures/patterns are not evaluated. Source UV is used only for the supplied
opacity map. A dedicated bake scene excludes reference/high meshes automatically.
"""
from pathlib import Path
import json
import bpy
import numpy as np


def review_materials(objects, layout, source_uv, delivery_uv, opacity_image=None,
                     alpha_material_names=(), prefix='UV_AO', distance=.3, samples=64):
    res=layout['profile']['resolution']
    if distance<=0 or samples<1:raise ValueError('Invalid AO profile')
    checker=bpy.data.images.new(prefix+'_Checker',res,res);checker.generated_type='COLOR_GRID'
    mats={};roles={}
    for ob in objects:
        old=list(ob.data.materials)
        for m in old:
            if m:m.use_fake_user=True
        roles[ob.name]={str(p.index):old[p.material_index].name for p in ob.data.polygons}
        slots={}
        ob.data.materials.clear()
        for p in ob.data.polygons:
            page=layout['objects'][ob.name][str(p.index)]['page'];alpha=roles[ob.name][str(p.index)] in alpha_material_names
            key=(page,alpha)
            if key not in mats:
                mat=bpy.data.materials.new(f'{prefix}_Page{page}'+('_Cutout' if alpha else ''));mat.use_nodes=True;ns=mat.node_tree.nodes;ns.clear();lk=mat.node_tree.links
                uv=ns.new('ShaderNodeUVMap');uv.name='Delivery coordinates';uv.uv_map=delivery_uv
                grid=ns.new('ShaderNodeTexImage');grid.name='Orientation checker';grid.image=checker;lk.new(uv.outputs['UV'],grid.inputs['Vector'])
                ao=ns.new('ShaderNodeAmbientOcclusion');ao.name='Contact AO';ao.inputs['Distance'].default_value=distance;ao.samples=samples;ao.only_local=False
                im=ns.new('ShaderNodeTexImage');im.name='Baked contact AO';lk.new(uv.outputs['UV'],im.inputs['Vector'])
                em=ns.new('ShaderNodeEmission');em.name='Review emission';lk.new(grid.outputs['Color'],em.inputs['Color'])
                out=ns.new('ShaderNodeOutputMaterial');out.name='Material Output';surface=em.outputs[0]
                if alpha:
                    if opacity_image is None:raise ValueError('Alpha role requires the verified opacity image')
                    su=ns.new('ShaderNodeUVMap');su.name='Original cutout coordinates';su.uv_map=source_uv
                    tex=ns.new('ShaderNodeTexImage');tex.name='Approved opacity';tex.image=opacity_image;lk.new(su.outputs['UV'],tex.inputs['Vector'])
                    tr=ns.new('ShaderNodeBsdfTransparent');mix=ns.new('ShaderNodeMixShader');mix.name='Preserved cutout';lk.new(tex.outputs['Color'],mix.inputs[0]);lk.new(tr.outputs[0],mix.inputs[1]);lk.new(surface,mix.inputs[2]);surface=mix.outputs[0];mat.surface_render_method='DITHERED'
                lk.new(surface,out.inputs['Surface']);mat['page']=page;mat['alpha_role']=alpha;mat['workflow_prefix']=prefix;mats[key]=mat
            if key not in slots:slots[key]=len(ob.data.materials);ob.data.materials.append(mats[key])
            p.material_index=slots[key]
    return {'materials':[m.name for m in mats.values()],'source_material_roles':roles,'checker':checker.name,'distance':distance,'samples':samples}


def set_review_mode(review, mode, distance=None, images=None):
    if mode not in ['checker','live_ao','baked_ao']:raise ValueError(mode)
    for name in review['materials']:
        mat=bpy.data.materials[name];ns=mat.node_tree.nodes
        if distance is not None:ns['Contact AO'].inputs['Distance'].default_value=distance
        if images is not None:ns['Baked contact AO'].image=images[int(mat['page'])]
        source={'checker':('Orientation checker','Color'),'live_ao':('Contact AO','AO'),'baked_ao':('Baked contact AO','Color')}[mode]
        mat.node_tree.links.new(ns[source[0]].outputs[source[1]],ns['Review emission'].inputs['Color'])


def bake_contact_ao(objects, layout, review, output, prefix, uv_name, samples=64, distance=.3,
                    extra_occluders=()):
    """Join temporary world-space copies, bake AO through Emission, restore context.

    All receiver geometry is also an occluder; unique owner UVs are required.
    Explicit extra_occluders are copied unselected into the isolated scene. Their
    materials (including cutouts) are retained; they never become bake receivers.
    Internal faces remain unique in this diagnostic layout. No scene-wide AO or
    second multiplication of existing texture AO. Runtime consolidation is separate.
    """
    objects=list(objects);extra_occluders=list(extra_occluders)
    if not objects or set(objects)&set(extra_occluders):
        raise ValueError('Nonempty receiver scope and disjoint extra occluders required')
    out=Path(output);out.mkdir(parents=True,exist_ok=True)
    res=layout['profile']['resolution'];padding=layout['profile']['padding']
    if bpy.data.scenes.get(prefix+'_Bake'):raise ValueError('Use a fresh bake checkpoint prefix')
    scene0=bpy.context.window.scene;scene=bpy.data.scenes.new(prefix+'_Bake');scene['bake_scratch']=True;scene.render.engine='CYCLES';scene.cycles.samples=samples
    verts=[];faces=[];normals=[];uv_values={u.name:[] for u in objects[0].data.uv_layers};mats=[];indices=[]
    for ob in objects:
        me=ob.data;offset=len(verts);verts.extend([ob.matrix_world@v.co for v in me.vertices]);normal_matrix=ob.matrix_world.to_3x3().inverted().transposed()
        normals.extend([(normal_matrix@n.vector).normalized() for n in me.corner_normals])
        for u in uv_values:uv_values[u].extend([loop.uv[:] for loop in me.uv_layers[u].data])
        for p in me.polygons:
            faces.append([offset+v for v in p.vertices]);mat=me.materials[p.material_index]
            if mat not in mats:mats.append(mat)
            indices.append(mats.index(mat))
    mesh=bpy.data.meshes.new(prefix+'_Receiver');mesh.from_pydata(verts,[],faces);mesh.update();mesh.normals_split_custom_set(normals)
    ob=bpy.data.objects.new(prefix+'_Receiver',mesh);scene.collection.objects.link(ob)
    for source in extra_occluders:
        copy=source.copy();copy.data=source.data.copy();copy.animation_data_clear()
        copy.name=prefix+'_Occluder_'+source.name;scene.collection.objects.link(copy)
        copy.hide_render=False;copy.hide_viewport=False
    for mat in mats:mesh.materials.append(mat)
    for p,mi in zip(mesh.polygons,indices):p.material_index=mi
    for name,values in uv_values.items():
        uv=mesh.uv_layers.new(name=name)
        for loop,val in zip(uv.data,values):loop.uv=val
    mesh.uv_layers.active=mesh.uv_layers[uv_name];mesh.uv_layers[uv_name].active_render=True
    images=[];targets=[]
    for page in range(layout['pages']):
        im=bpy.data.images.new(f'{prefix}_AO_{page}',res,res,float_buffer=True,alpha=False);im.colorspace_settings.name='Non-Color';im.generated_color=(1,1,1,1);images.append(im)
    for mat in mats:
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.name='ACTIVE_AO_BAKE_TARGET';node.image=images[int(mat['page'])]
        for n in mat.node_tree.nodes:n.select=False
        node.select=True;mat.node_tree.nodes.active=node;targets.append((mat,node))
    try:
        set_review_mode(review,'live_ao',distance=distance)
        bpy.context.window.scene=scene;ob.select_set(True);bpy.context.view_layer.objects.active=ob
        scene.render.bake.use_selected_to_active=False;scene.render.bake.use_clear=True;scene.render.bake.margin=padding;scene.render.bake.margin_type='EXTEND'
        bpy.ops.object.bake(type='EMIT',use_clear=True,margin=padding,uv_layer=uv_name)
        stats=[]
        for im in images:
            buf=np.empty(len(im.pixels),np.float32);im.pixels.foreach_get(buf);rgb=buf.reshape(-1,4)[:,:3]
            assert np.isfinite(rgb).all() and rgb.min()>=-1e-5 and rgb.max()<=1.00001
            im.filepath_raw=str(out/(im.name+'.exr'));im.file_format='OPEN_EXR';im.save()
            scene.view_settings.view_transform='Raw';scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGB';scene.render.image_settings.color_depth='16';im.save_render(str(out/(im.name+'.png')),scene=scene)
            stats.append({'name':im.name,'size':list(im.size),'min':float(rgb.min()),'max':float(rgb.max()),'finite':True,'image':im.filepath_raw})
        report={'distance':distance,'samples':samples,'receiver_objects':[o.name for o in objects],'extra_occluders':[o.name for o in extra_occluders],'occluder_scope':'explicit receivers plus listed extra occluders; no scene-wide collection traversal','pages':stats,'uv_name':uv_name,'margin':padding,'scope':'Structural AO only. Whole-image min/max includes internal faces and background, not an exposure-quality certificate.'}
        (out/(prefix+'_bake.json')).write_text(json.dumps(report,indent=2))
    finally:
        bpy.context.window.scene=scene0
        for mat,node in targets:mat.node_tree.nodes.remove(node)
    set_review_mode(review,'baked_ao',images=images)
    return report
