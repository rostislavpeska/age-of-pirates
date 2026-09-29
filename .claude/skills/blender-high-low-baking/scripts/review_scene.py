"""STANDARD review deliverable after the UV freeze: a live scene in the owner's open Blender.

Run inside the OPEN Blender (through the MCP: exec this file with CONFIG set, or `run(config_path)`):
    exec(compile(open(p).read(), p, 'exec'), {'__name__': 'review', 'CONFIG': r'...\\review_config.json'})
config = {
  "scene": "Review_Pilot",
  "variants": [{"label": "LP + bake C", "recipe": "bake/pilot_C.json"},            # first = the candidate
               {"label": "LP + bake A (reference)", "recipe": "bake/pilot_A.json"}],
  "hp": {"label": "HP C (bake source)", "recipe": "bake/pilot_C.json"},          # highs of that recipe
  "pages": {"Claude_page_P2048": {"page": "P2048", "assembly_ao": "sp/AO_mata_2048.png"},
            "Claude_page_P1024": {"page": "P1024", "assembly_ao": "sp/AO_matb_1024.png"}},
  "spacing": 10.0, "snapshot": "optional path: OpenGL image of the framed view, for the agent's own check"
}
Relative paths resolve against the config's folder. Built from the bake recipes (bake_owner_maps.py), so the
scene shows exactly what was baked: every variant is the FULL low model (owners + members, as the game draws
it) with that recipe's maps on its uv_name (normal; AO = assembly x local; alpha from OPACITY on the recipe's
'only' faces, everywhere if it has none), in grey clay; the HP is an appended copy of the recipe's highs,
their own shaders kept (bump variants show), base colour set to the same grey. Copies stand side by side
across the view; labels above; one grazing sun; Material Preview with scene lights; framed on the 'only'
faces from the side they face. Rebuilding removes only this scene's own objects and data. Saves the file.
"""
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

GREY = (0.55, 0.55, 0.55, 1)


def _img(path):
    im = bpy.data.images.load(str(path), check_existing=True); im.colorspace_settings.name = 'Non-Color'; return im


def _clear(name):
    old = bpy.data.scenes.get(name)
    if not old:
        return
    data = [o.data for o in old.objects if o.data is not None]
    mats = {s.material for o in old.objects for s in o.material_slots if s.material}
    for o in list(old.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.scenes.remove(old)
    for d in data:
        for coll in (bpy.data.meshes, bpy.data.curves, bpy.data.lights):
            if d.users == 0 and d.name in coll and coll[d.name] == d:
                coll.remove(d); break
    for m in mats:
        if m.users == 0:
            bpy.data.materials.remove(m)


def _variant(sc, var, recipe, pages, root, offset, extra=()):
    bdir = Path(recipe['out_dir']); uv = recipe.get('uv_name', 'UV_Final')
    only = set(recipe.get('only') or [])
    objs = []
    for key, name in recipe['sources'].items():
        src = bpy.data.objects[name]
        ob = bpy.data.objects.new(f'{var["label"]} | {name}', src.data.copy()); sc.collection.objects.link(ob)
        ob.matrix_world = src.matrix_world; ob.location += offset; objs.append((key, ob))
        me = ob.data; att = me.attributes.new('review_alpha', 'FLOAT', 'FACE')
        for p in me.polygons:
            att.data[p.index].value = 1.0 if (not only or f'{key}:{p.index}' in only) else 0.0
        new = []
        for m in me.materials:
            pg = pages[m.name]; page = pg['page']
            nm = bpy.data.materials.new(f'Review {var["label"]} {page}'); N, L = nm.node_tree.nodes, nm.node_tree.links
            bsdf = N['Principled BSDF']; bsdf.inputs['Roughness'].default_value = 0.8
            uvn = N.new('ShaderNodeUVMap'); uvn.uv_map = uv; tex = {}
            files = {'n': bdir / f'NORMAL_{page}.exr', 'ao': bdir / f'AO_{page}.exr', 'op': bdir / f'OPACITY_{page}.exr'}
            if pg.get('assembly_ao'):
                files['aa'] = root / pg['assembly_ao']
            for lab, path in files.items():
                if path.exists():
                    t = N.new('ShaderNodeTexImage'); t.image = _img(path); L.new(uvn.outputs['UV'], t.inputs['Vector']); tex[lab] = t
            if 'n' in tex:
                nmap = N.new('ShaderNodeNormalMap'); nmap.uv_map = uv
                L.new(tex['n'].outputs['Color'], nmap.inputs['Color']); L.new(nmap.outputs['Normal'], bsdf.inputs['Normal'])
            col = N.new('ShaderNodeRGB'); col.outputs[0].default_value = GREY; out = col.outputs[0]
            for lab in ('aa', 'ao'):
                if lab in tex:
                    mix = N.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
                    mix.inputs['Factor'].default_value = 1; L.new(out, mix.inputs['A']); L.new(tex[lab].outputs['Color'], mix.inputs['B'])
                    out = mix.outputs['Result']
            L.new(out, bsdf.inputs['Base Color'])
            if 'op' in tex:
                at = N.new('ShaderNodeAttribute'); at.attribute_type = 'GEOMETRY'; at.attribute_name = 'review_alpha'
                al = N.new('ShaderNodeMix'); al.data_type = 'FLOAT'; al.inputs['A'].default_value = 1.0
                L.new(at.outputs['Fac'], al.inputs['Factor']); L.new(tex['op'].outputs['Color'], al.inputs['B'])
                L.new(al.outputs['Result'], bsdf.inputs['Alpha'])
            new.append(nm)
        # Clearing slots resets polygon indices. Keep the frozen atlas-page split.
        page_indices = [p.material_index for p in me.polygons]
        me.materials.clear()
        for nm in new:
            me.materials.append(nm)
        for p, index in zip(me.polygons, page_indices):
            p.material_index = index
        assert [p.material_index for p in me.polygons] == page_indices
    for name in extra:  # hidden / backing parts without bakes: grey clay, so the model has no holes
        src = bpy.data.objects[name]
        ob = bpy.data.objects.new(f'{var["label"]} | {name}', src.data.copy()); sc.collection.objects.link(ob)
        ob.matrix_world = src.matrix_world; ob.location += offset
        ob.data.materials.clear(); ob.data.materials.append(_clay())
    return objs


def _clay():
    m = bpy.data.materials.get('Review clay')
    if m is None:
        m = bpy.data.materials.new('Review clay'); b = m.node_tree.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = GREY; b.inputs['Roughness'].default_value = 0.8
    return m


def _highs(sc, recipe, offset):
    out = []
    for h in recipe['highs']:
        if h.get('file'):
            with bpy.data.libraries.load(h['file'], link=False) as (s, d):
                d.objects = list(h['objects'])
            obs = list(d.objects)
        else:  # an object of this file: a new object on its mesh, so it can move
            obs = []
            for n in h['objects']:
                src = bpy.data.objects[n]; o = bpy.data.objects.new(n, src.data); o.matrix_world = src.matrix_world; obs.append(o)
        for o in obs:
            o.name = 'HP | ' + o.name; sc.collection.objects.link(o); o.location += offset
            for slot in o.material_slots:
                m = slot.material
                outn = next((n for n in m.node_tree.nodes if n.type == 'OUTPUT_MATERIAL' and n.is_active_output), None) if m and not m.library else None
                src = outn.inputs['Surface'].links[0].from_node if outn and outn.inputs['Surface'].links else None
                if src is None or src.type != 'BSDF_PRINCIPLED':
                    # linked, emission/ID or other shader (e.g. GPT's paper-ID windows): object-level grey clay
                    clay = bpy.data.materials.new('Review HP clay'); cb = clay.node_tree.nodes['Principled BSDF']
                    cb.inputs['Base Color'].default_value = GREY; cb.inputs['Roughness'].default_value = 0.8
                    slot.link = 'OBJECT'; slot.material = clay
                    continue
                for lk in list(src.inputs['Base Color'].links):   # keep its normal/bump chain, grey the colour
                    m.node_tree.links.remove(lk)
                src.inputs['Base Color'].default_value = GREY; src.inputs['Roughness'].default_value = 0.8
            out.append(o)
    return out


def run(config_path):
    cfg_path = Path(config_path); root = cfg_path.parent; cfg = json.loads(cfg_path.read_text())
    load = lambda p: json.loads((root / p).read_text())
    name = cfg.get('scene', 'Review'); _clear(name)
    sc = bpy.data.scenes.new(name)
    sc.world = bpy.data.worlds.new(name + ' world')
    bg = sc.world.node_tree.nodes['Background']; bg.inputs['Color'].default_value = (0.55, 0.6, 0.66, 1); bg.inputs['Strength'].default_value = 0.35
    first = load(cfg['variants'][0]['recipe'])
    only = first.get('only') or []
    # focus: the 'only' faces (or the whole model): centre and the side they face
    pts, nrm = [], Vector()
    for key, name_ in first['sources'].items():
        ob = bpy.data.objects[name_]; nm = ob.matrix_world.to_3x3().inverted().transposed()
        for p in ob.data.polygons:
            if not only or f'{key}:{p.index}' in only:
                pts.append(ob.matrix_world @ p.center); nrm += nm @ p.normal
    target = sum(pts, Vector()) / len(pts)
    face = Vector((nrm.x, nrm.y, 0)).normalized() if Vector((nrm.x, nrm.y)).length > 1e-6 else Vector((0, -1, 0))
    view_dir = (-face + Vector((0, 0, -0.58))).normalized()
    across = Vector((-face.y, face.x, 0)); step = float(cfg.get('spacing', 10.0))
    slots = [Vector((0, 0, 0))] + [across * step * k for k in (1, 2, 3, 4)]
    placed = []
    for i, var in enumerate(cfg['variants']):
        _variant(sc, var, load(var['recipe']), cfg['pages'], root, slots[len(placed)], cfg.get('extra', []))
        placed.append(var['label'])
    if cfg.get('hp'):
        hp_off = -across * step
        _highs(sc, load(cfg['hp']['recipe']), hp_off); placed.append(cfg['hp']['label'])
    top = max(p.z for p in pts) + 5.0
    labels = [(v['label'], slots[i]) for i, v in enumerate(cfg['variants'])] + ([(cfg['hp']['label'], -across * step)] if cfg.get('hp') else [])
    for text, off in labels:
        cu = bpy.data.curves.new('Review label', 'FONT'); cu.body = text; cu.size = 0.6; cu.align_x = 'CENTER'
        lo = bpy.data.objects.new('Label | ' + text, cu); sc.collection.objects.link(lo)
        lo.location = Vector((target.x, target.y, top)) + off + face * 1.5
        # upright text (X 90 deg) reads from -Y; turn it about Z until its front faces the viewer's side
        lo.rotation_euler = (math.pi / 2, 0, math.atan2(face.x, -face.y))
    if only:  # say what was baked: everything else is still flat until the production bake
        cu = bpy.data.curves.new('Review label', 'FONT'); cu.body = cfg.get('focus_label', 'baked in this review'); cu.size = 0.35
        cu.align_x = 'CENTER'; lo = bpy.data.objects.new('Label | focus', cu); sc.collection.objects.link(lo)
        lo.location = target + face * 1.2 + Vector((0, 0, 1.6)); lo.rotation_euler = (math.pi / 2, 0, math.atan2(face.x, -face.y))
    # No scene lights in the review: a sun in Material Preview draws real-time shadow artifacts (black arcs)
    # and blows out upward faces (owner: "looks broken", 2026-09-28). Studio HDRI shows relief evenly.
    bpy.context.window.scene = sc
    for area in bpy.context.window.screen.areas:
        if area.type == 'VIEW_3D':
            sp = area.spaces.active; sp.shading.type = 'MATERIAL'
            sp.shading.use_scene_lights = False; sp.shading.use_scene_world = False
            r3 = sp.region_3d; r3.view_perspective = 'PERSP'; r3.view_rotation = view_dir.to_track_quat('-Z', 'Y')
            r3.view_location = target; r3.view_distance = step * 3.2
            if cfg.get('snapshot'):
                region = next(r for r in area.regions if r.type == 'WINDOW')
                with bpy.context.temp_override(window=bpy.context.window, area=area, region=region):
                    bpy.ops.render.opengl(write_still=False, view_context=True)
                bpy.data.images['Render Result'].save_render(str(cfg['snapshot']))
            break
    bpy.ops.wm.save_mainfile()
    print('REVIEW_SCENE', name, placed)
    return sc


if __name__ != '__main__' and 'CONFIG' in globals():
    run(CONFIG)
