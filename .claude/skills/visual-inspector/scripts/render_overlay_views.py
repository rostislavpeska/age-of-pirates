"""Render flat false-colour overlay views of a model for visual inspectors (background Blender, nothing saved).

    blender -b FILE.blend --python render_overlay_views.py -- --scene SCENE --collections A,B --attr ATTR \\
        --colors '{"4": [1, 0, 1]}' --default 0.72,0.72,0.72 --views game --out DIR --tag NAME \\
        [--control-object OBJ --control-color 1,0,1] [--res 1000x750]

Each face is coloured by an INT face attribute (value -> RGB; anything else -> default), as flat emission on a neutral
grey background: no lighting, no texture, so a vision model only has to see colour. --views:
  game   8 azimuths at 40 deg + 4 azimuths at 15 deg (the game camera envelope and grazing views)
  below  4 azimuths at -20 deg (informational: undersides)
  or a list "az:el,az:el".
--control-object paints one named object in the control colour for a PLANTED positive control render (CONTROL_*.png),
which an inspector must report; the views themselves stay untouched. Controls use their own camera (22.5 deg off a view,
35 deg up), so no inspected view is the control's twin. The clean control keeps the legend colours and only redraws the
control colour's classes in another legend colour, so it looks like any defect-free view (an all-grey model was reported
as 'not following the legend' by 9 of 16 inspectors, 2026-10-10). --clean-control adds CLEAN_*.png: the same model in its legend colours with nothing to report, which catches inspectors
that invent findings. Writes <tag>_<view>.png and VIEWS.json (camera,
framing). Labels, legend and grid are burned in afterwards by annotate_views.py (outside Blender).
"""
import argparse, json, math, sys
from pathlib import Path
import bpy
from mathutils import Vector

ap = argparse.ArgumentParser()
ap.add_argument('--scene', required=True); ap.add_argument('--collections', required=True); ap.add_argument('--attr', required=True)
ap.add_argument('--colors', default='{}'); ap.add_argument('--default', default='0.72,0.72,0.72'); ap.add_argument('--views', default='game')
ap.add_argument('--out', required=True); ap.add_argument('--tag', required=True); ap.add_argument('--res', default='1000x750')
ap.add_argument('--control-object', default=None); ap.add_argument('--control-color', default='1,0,1'); ap.add_argument('--margin', type=float, default=1.12)
ap.add_argument('--clean-control', action='store_true')
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:]); out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
sc = bpy.data.scenes[a.scene]; bpy.context.window.scene = sc
for vl in sc.view_layers:
    vl.update()
W, H = (int(x) for x in a.res.split('x'))
colors = {int(k): v for k, v in json.loads(a.colors).items()}; default = [float(x) for x in a.default.split(',')]
objs = sorted({o for cn in a.collections.split(',') for o in bpy.data.collections[cn].all_objects if o.type == 'MESH' and not o.get('export_exclude')},
              key=lambda o: o.name)


def overlay_material(name, attr, cmap, dflt, force=None):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    outn = nt.nodes.new('ShaderNodeOutputMaterial'); em = nt.nodes.new('ShaderNodeEmission')
    if force is not None:
        em.inputs['Color'].default_value = (*force, 1)
    else:
        at = nt.nodes.new('ShaderNodeAttribute'); at.attribute_type = 'GEOMETRY'; at.attribute_name = attr
        prev = None
        base = nt.nodes.new('ShaderNodeRGB'); base.outputs[0].default_value = (*dflt, 1); prev = base.outputs[0]
        for v, rgb in sorted(cmap.items()):
            cmp = nt.nodes.new('ShaderNodeMath'); cmp.operation = 'COMPARE'; cmp.inputs[1].default_value = float(v); cmp.inputs[2].default_value = .25
            mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.inputs['B'].default_value = (*rgb, 1)
            nt.links.new(at.outputs['Fac'], cmp.inputs[0]); nt.links.new(cmp.outputs[0], mix.inputs['Factor']); nt.links.new(prev, mix.inputs['A'])
            prev = mix.outputs['Result']
        nt.links.new(prev, em.inputs['Color'])
    nt.links.new(em.outputs['Emission'], outn.inputs['Surface'])
    return m


mat = overlay_material('OVERLAY', a.attr, colors, default)
for o in objs:
    if not o.material_slots:
        o.data.materials.append(None)
    for s in o.material_slots:
        s.link = 'OBJECT'; s.material = mat
world = bpy.data.worlds.new('OVERLAY world'); world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND'); bg.inputs['Color'].default_value = (.38, .38, .40, 1)
sc.world = world
for o in sc.objects:                                     # only the model and the camera render
    if o.type in ('MESH', 'CURVE', 'FONT') and o not in objs:
        o.hide_render = True
sc.render.engine = 'BLENDER_EEVEE'; sc.render.resolution_x, sc.render.resolution_y = W, H; sc.render.film_transparent = False
sc.view_settings.view_transform = 'Standard'
cam = bpy.data.objects.new('OVERLAY cam', bpy.data.cameras.new('OVERLAY cam')); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = 'ORTHO'
pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)]); ctr = (lo + hi) / 2
if a.views == 'game':
    views = [(az, 40) for az in range(0, 360, 45)] + [(az, 15) for az in (20, 110, 200, 290)]
elif a.views == 'below':
    views = [(az, -20) for az in (20, 110, 200, 290)]
else:
    views = [tuple(float(x) for x in v.split(':')) for v in a.views.split(',')]


def shoot(name, az, el):
    d = Vector((math.cos(math.radians(el)) * math.cos(math.radians(az)), math.cos(math.radians(el)) * math.sin(math.radians(az)), math.sin(math.radians(el))))
    cam.location = ctr + d * 200; cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    R = cam.rotation_euler.to_matrix(); rx, ry = R.col[0], R.col[1]
    ext_x = max(abs((p - ctr).dot(rx)) for p in pts) * 2; ext_y = max(abs((p - ctr).dot(ry)) for p in pts) * 2
    cam.data.ortho_scale = max(ext_x, ext_y * W / H) * a.margin
    sc.render.filepath = str(out / f'{name}.png'); bpy.ops.render.render(write_still=True)
    return {'file': f'{name}.png', 'azimuth': az, 'elevation': el, 'ortho_scale': cam.data.ortho_scale}


rec = {'tag': a.tag, 'attr': a.attr, 'colors': colors, 'default': default, 'views': []}
for az, el in views:
    rec['views'].append(shoot(f'{a.tag}_az{int(az):03d}_el{int(el):+03d}', az, el))
if a.control_object:
    ctrl = bpy.data.objects[a.control_object]; cm = overlay_material('OVERLAY control', a.attr, colors, default, [float(x) for x in a.control_color.split(',')])
    for s in ctrl.material_slots:
        s.material = cm
    az, el = (views[0][0] + 22.5) % 360, 35            # own camera, never an inspection view: no twin gives the plant away
    rec['control'] = shoot(f'CONTROL_{a.tag}_az{int(az):03d}_el{int(el):+03d}', az, el); rec['control']['planted_object'] = a.control_object
if a.clean_control:                                   # a NORMAL-looking view with nothing to report: the control colour's
    ctl_rgb = [float(x) for x in a.control_color.split(',')]  # classes drawn in the first other legend colour (an all-grey model
    other = next((v for v in colors.values() if [round(x, 3) for x in v] != [round(x, 3) for x in ctl_rgb]), default)   # broke the
    cm = overlay_material('OVERLAY clean', a.attr, {k: (other if [round(x, 3) for x in v] == [round(x, 3) for x in ctl_rgb] else v)
                                                  for k, v in colors.items()}, default)                                  # legend: H3)
    for o in objs:
        for s in o.material_slots:
            s.material = cm
    az, el = (views[len(views) // 2][0] + 22.5) % 360, 35
    rec['clean_control'] = shoot(f'CLEAN_{a.tag}_az{int(az):03d}_el{int(el):+03d}', az, el)
json.dump(rec, open(out / f'VIEWS_{a.tag}.json', 'w'), indent=1)
print('OVERLAY_DONE', len(rec['views']), 'views', 'control' if a.control_object else '')
