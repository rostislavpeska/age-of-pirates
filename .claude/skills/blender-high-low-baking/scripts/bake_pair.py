"""Blender-only helpers for explicitly scoped high/low bakes.

Run in a dedicated scene owned by the task, through the verified Blender connection.
No file opening, model replacement, game export or application installation.
"""
import hashlib
import importlib.util
import json
from pathlib import Path

import bpy
import numpy as np


def mesh_hash(obj):
    me = obj.data
    uv = me.uv_layers.active
    data = dict(vertices=[list(v.co) for v in me.vertices],
                faces=[list(p.vertices) for p in me.polygons],
                uv=[list(x.uv) for x in uv.data] if uv else [],
                normals=[list(n.vector) for n in me.corner_normals],
                matrix=[list(r) for r in obj.matrix_world])
    return hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()


def validate_pair(low, highs, cage):
    assert bpy.context.scene.get('bake_scratch'), 'Use a dedicated, explicitly owned bake scene'
    assert low.type == 'MESH' and highs and low not in highs and cage not in highs
    assert all(h.type == 'MESH' for h in highs)
    assert low.data.uv_layers.active, 'Low mesh needs active UVs'
    assert not low.modifiers and not cage.modifiers, 'Freeze bake-copy topology first'
    assert len(low.data.vertices) == len(cage.data.vertices)
    assert [tuple(p.vertices) for p in low.data.polygons] == [tuple(p.vertices) for p in cage.data.polygons], 'Cage topology/order mismatch'
    low.data.calc_loop_triangles()
    uv = low.data.uv_layers.active.data
    for tri in low.data.loop_triangles:
        a, b, c = [uv[i].uv for i in tri.loops]
        area = abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))*.5
        assert area > 1e-12, 'Zero-area UV triangle'
        assert all(-1e-6 <= q <= 1+1e-6 for x in (a,b,c) for q in x), 'Pilot bake chart outside 0..1'
    assert all(o.name in bpy.context.scene.objects for o in [low, cage, *highs])
    spec=importlib.util.spec_from_file_location('unique_uv_audit',Path(__file__).with_name('audit_unique_uv.py'))
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    report=mod.audit([[list(uv[i].uv) for i in t.loops] for t in low.data.loop_triangles])
    assert report['passed'],report
    return report


def image_statistics(image, kind):
    px = np.empty(len(image.pixels), dtype=np.float32); image.pixels.foreach_get(px)
    rgba = px.reshape((-1,4)); rgb = rgba[:,:3]
    out = dict(size=list(image.size), finite=bool(np.isfinite(rgb).all()),
               rgb_min=rgb.min(axis=0).tolist(), rgb_max=rgb.max(axis=0).tolist())
    if kind == 'NORMAL':
        vec = 2*rgb-1; lengths=np.linalg.norm(vec,axis=1)
        out.update(vector_length_p01=float(np.quantile(lengths,.01)),
                   vector_length_p99=float(np.quantile(lengths,.99)),
                   tilted_pixel_fraction=float(np.mean(np.linalg.norm(vec[:,:2],axis=1)>.1)))
    return out


def bake_pair(low, highs, cage, out_dir, name, resolution=1024, margin=16, samples=16,
              kind='NORMAL', ao_distance=.15):
    """Bake one unique-UV receiver. Highs are the ONLY selected projection sources.

    AO uses an explicit-distance AO shader emitted from selected high geometry.
    Export channel packing and target tangent validation remain separate.
    """
    uv_report=validate_pair(low,highs,cage)
    assert kind in {'NORMAL','AO'}
    assert resolution > 0 and 0 < margin < resolution//8
    scene=bpy.context.scene; scene.render.engine='CYCLES';scene.cycles.samples=samples
    out_dir=Path(out_dir);out_dir.mkdir(parents=True,exist_ok=True)
    key=f'{name}_{kind}'
    assert bpy.data.images.get(key) is None, 'Use a new output name/version; do not overwrite a manual image'
    image=bpy.data.images.new(key,width=resolution,height=resolution,alpha=False,float_buffer=True)
    image.colorspace_settings.name='Non-Color'
    image.generated_color=(.5,.5,1,1) if kind=='NORMAL' else (1,1,1,1)
    mats=[]
    if not low.data.materials:
        mat=bpy.data.materials.new(key+'_Receiver');mat.use_nodes=True;low.data.materials.append(mat)
    for mat in low.data.materials:
        assert mat and mat.use_nodes
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.name='BAKE_TARGET_'+key;node.image=image
        for n in mat.node_tree.nodes:n.select=False
        node.select=True;mat.node_tree.nodes.active=node;mats.append((mat,node))
    original_high_materials={}
    if kind=='AO':
        ao_mat=bpy.data.materials.new(key+'_AO_Source');ao_mat.use_nodes=True
        nt=ao_mat.node_tree;nt.nodes.clear();ao=nt.nodes.new('ShaderNodeAmbientOcclusion')
        ao.inputs['Distance'].default_value=ao_distance;ao.samples=samples;ao.only_local=True
        em=nt.nodes.new('ShaderNodeEmission');out=nt.nodes.new('ShaderNodeOutputMaterial')
        nt.links.new(ao.outputs['AO'],em.inputs['Color']);nt.links.new(em.outputs[0],out.inputs[0])
        for high in highs:
            original_high_materials[high.name]=(list(high.data.materials),[p.material_index for p in high.data.polygons])
            high.data.materials.clear();high.data.materials.append(ao_mat)
            for p in high.data.polygons:p.material_index=0
    try:
        for ob in scene.objects:ob.select_set(False)
        for ob in [low,*highs]:ob.hide_set(False);ob.hide_render=False;ob.select_set(True)
        cage.hide_render=True;cage.hide_set(True);bpy.context.view_layer.objects.active=low
        b=scene.render.bake;b.use_selected_to_active=True;b.use_cage=True;b.cage_object=cage
        b.cage_extrusion=0;b.max_ray_distance=0;b.margin=margin;b.margin_type='EXTEND';b.use_clear=False
        b.normal_space='TANGENT';b.normal_r='POS_X';b.normal_g='POS_Y';b.normal_b='POS_Z'
        bpy.ops.object.bake(type='NORMAL' if kind=='NORMAL' else 'EMIT',use_selected_to_active=True,
                            use_cage=True,cage_object=cage.name,margin=margin,margin_type='EXTEND',use_clear=False)
        image.filepath_raw=str(out_dir/(key+'.exr'));image.file_format='OPEN_EXR';image.save()
        # EXR is the linear editable master. PNG is a 16-bit data preview, no view transform.
        settings=scene.render.image_settings
        old=(settings.file_format,settings.color_mode,settings.color_depth,scene.view_settings.view_transform)
        settings.file_format='PNG';settings.color_mode='RGB';settings.color_depth='16';scene.view_settings.view_transform='Raw'
        image.save_render(str(out_dir/(key+'.png')),scene=scene)
        settings.file_format,settings.color_mode,settings.color_depth,scene.view_settings.view_transform=old
        stats=image_statistics(image,kind)
        report=dict(blender=bpy.app.version_string,low=low.name,highs=[o.name for o in highs],
                    cage=cage.name,low_hash=mesh_hash(low),cage_hash=mesh_hash(cage),
                    high_hashes={o.name:mesh_hash(o) for o in highs},resolution=resolution,margin_px=margin,
                    samples=samples,kind=kind,normal_axes=['+X','+Y','+Z'],normal_space='TANGENT',
                    ao_distance=ao_distance if kind=='AO' else None,stats=stats,uv_audit=uv_report,
                    master=str(out_dir/(key+'.exr')),preview=str(out_dir/(key+'.png')),
                    limitations=['Selected-to-active bake only; no target-engine certification',
                                 'Unique UV overlap checked; cage intersections and semantic/density checks require separate evidence'])
        (out_dir/(key+'.json')).write_text(json.dumps(report,indent=2))
        return image,report
    finally:
        for high in highs:
            if high.name in original_high_materials:
                old_mats,indices=original_high_materials[high.name];high.data.materials.clear()
                for m in old_mats:high.data.materials.append(m)
                for p,i in zip(high.data.polygons,indices):p.material_index=i
        # Bake targets are retained for reproducibility, never wired into the shader implicitly.


def wire_normal(mat,image,uv_name):
    assert mat.use_nodes
    nt=mat.node_tree;im=nt.nodes.new('ShaderNodeTexImage');im.image=image;im.interpolation='Linear'
    uv=nt.nodes.new('ShaderNodeUVMap');uv.uv_map=uv_name
    normal=nt.nodes.new('ShaderNodeNormalMap');normal.space='TANGENT';normal.uv_map=uv_name
    normal.inputs['Strength'].default_value=1
    nt.links.new(uv.outputs['UV'],im.inputs['Vector']);nt.links.new(im.outputs['Color'],normal.inputs['Color'])
    nt.links.new(normal.outputs['Normal'],nt.nodes.get('Principled BSDF').inputs['Normal'])
    return normal
