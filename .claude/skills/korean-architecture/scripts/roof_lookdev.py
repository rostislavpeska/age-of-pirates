"""Canonical roof look-dev rig: the SAME light, sky, view transform, pitch and metres-per-pixel for the accepted Town
Center and every derived building, so a roof is judged against the canon like for like (golden renders).

    blender -b FILE.blend --python roof_lookdev.py -- --cfg CFG.json
CFG: {"scene": name or null (new scene), "objects": [names...] and/or "collection": name (render set; others hidden),
      "bind": [{"object": name, "slot": i, "uv": layer, "basecolor": png, "normal": png, "masks": png, "opacity": png|null,
                "normal_flip_r": bool}],   # optional: bind runtime maps into one material slot (TC exporter: R-flipped normals)
      "close": [{"name": tag, "xy": [x, y], "az": deg}],   # close-ups: roof point found by a ray from above at x, y
      "out": dir, "label": text}
Rig (= the Dock review rig): sun 4.0 W/m2, 2 deg, rot (50, 0, 35) deg; sky (.55, .62, .70) x .6; Standard view; Cycles
48 spp. Shots: overview (orthographic, fitted, el 40 deg, az 200) and each close-up orthographic 4.0 m wide at el 40 deg
(about 240 px per metre at 960 px) - identical framing scale for every building.
"""
import bpy, json, sys, math
from mathutils import Vector

cfg = json.load(open(sys.argv[sys.argv.index('--') + 1:][1]))
sc = bpy.data.scenes[cfg['scene']] if cfg.get('scene') else bpy.context.scene
objs = [bpy.data.objects[n] for n in cfg.get('objects', [])] + ([o for o in bpy.data.collections[cfg['collection']].objects if o.type == 'MESH'] if cfg.get('collection') else [])
for o in sc.objects:
    o.hide_render = o not in objs and o.type != 'CAMERA'
    if o.type == 'LIGHT':
        o.hide_render = True


def img(path, data):
    im = bpy.data.images.load(path, check_existing=True)
    im.colorspace_settings.name = 'Non-Color' if data else 'sRGB'
    return im


for b in cfg.get('bind', []):
    o = bpy.data.objects[b['object']]; m = bpy.data.materials.new('LOOKDEV ' + o.name); m.use_nodes = True
    nt = m.node_tree; N, L = nt.nodes, nt.links; bs = next(n for n in N if n.type == 'BSDF_PRINCIPLED')
    uv = N.new('ShaderNodeUVMap'); uv.uv_map = b['uv']
    tb = N.new('ShaderNodeTexImage'); tb.image = img(b['basecolor'], False); L.new(uv.outputs[0], tb.inputs['Vector'])
    col = tb.outputs['Color']
    if b.get('masks'):
        tm = N.new('ShaderNodeTexImage'); tm.image = img(b['masks'], True); L.new(uv.outputs[0], tm.inputs['Vector'])
        sp = N.new('ShaderNodeSeparateColor'); L.new(tm.outputs['Color'], sp.inputs['Color'])
        mu = N.new('ShaderNodeMix'); mu.data_type = 'RGBA'; mu.blend_type = 'MULTIPLY'; mu.inputs[0].default_value = 1.
        L.new(col, mu.inputs[6]); L.new(sp.outputs[0], mu.inputs[7]); col = mu.outputs[2]
        L.new(sp.outputs[1], bs.inputs['Roughness']); L.new(sp.outputs[2], bs.inputs['Metallic'])
    L.new(col, bs.inputs['Base Color'])
    if b.get('normal'):
        tn = N.new('ShaderNodeTexImage'); tn.image = img(b['normal'], True); L.new(uv.outputs[0], tn.inputs['Vector'])
        ns = tn.outputs['Color']
        if b.get('normal_flip_r'):
            sp2 = N.new('ShaderNodeSeparateColor'); L.new(ns, sp2.inputs['Color']); inv = N.new('ShaderNodeMath'); inv.operation = 'SUBTRACT'
            inv.inputs[0].default_value = 1.; L.new(sp2.outputs[0], inv.inputs[1]); cc = N.new('ShaderNodeCombineColor')
            L.new(inv.outputs[0], cc.inputs[0]); L.new(sp2.outputs[1], cc.inputs[1]); L.new(sp2.outputs[2], cc.inputs[2]); ns = cc.outputs[0]
        nm = N.new('ShaderNodeNormalMap'); nm.uv_map = b['uv']; L.new(ns, nm.inputs['Color']); L.new(nm.outputs['Normal'], bs.inputs['Normal'])
    if b.get('opacity'):                       # a separate opacity map, or 'alpha' = the BaseColor's own alpha (DXT5 cutout)
        th = N.new('ShaderNodeMath'); th.operation = 'GREATER_THAN'; th.inputs[1].default_value = .5
        if b['opacity'] == 'alpha':
            tb.image.alpha_mode = 'STRAIGHT'; L.new(tb.outputs['Alpha'], th.inputs[0])
        else:
            to = N.new('ShaderNodeTexImage'); to.image = img(b['opacity'], True); L.new(uv.outputs[0], to.inputs['Vector']); L.new(to.outputs['Color'], th.inputs[0])
        L.new(th.outputs[0], bs.inputs['Alpha'])
    o.material_slots[b.get('slot', 0)].link = 'OBJECT'; o.material_slots[b.get('slot', 0)].material = m   # face indices untouched
# rig
sun = bpy.data.lights.new('LOOKDEV sun', 'SUN'); sun.energy = 4.0; sun.angle = math.radians(2)
so = bpy.data.objects.new('LOOKDEV sun', sun); so.rotation_euler = (math.radians(50), 0, math.radians(35)); sc.collection.objects.link(so)
w = bpy.data.worlds.new('LOOKDEV sky'); w.use_nodes = True; w.node_tree.nodes['Background'].inputs['Color'].default_value = (.55, .62, .70, 1)
w.node_tree.nodes['Background'].inputs['Strength'].default_value = .6; sc.world = w
sc.view_settings.view_transform = 'Standard'; sc.render.engine = 'CYCLES'; sc.cycles.samples = 48
sc.render.resolution_x, sc.render.resolution_y = 960, 640
try:
    pr = bpy.context.preferences.addons['cycles'].preferences; pr.compute_device_type = 'OPTIX'; pr.get_devices()
    for d_ in pr.devices:
        d_.use = True
    sc.cycles.device = 'GPU'
except Exception as e:
    print('gpu', e)
dg = bpy.context.evaluated_depsgraph_get()
pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)]); C = (lo + hi) / 2


def shoot(name, target, width, az, el=40.):
    cam = bpy.data.objects.new('LOOKDEV ' + name, bpy.data.cameras.new('LOOKDEV ' + name)); sc.collection.objects.link(cam)
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = width
    d = Vector((math.cos(math.radians(el)) * math.cos(math.radians(az)), math.cos(math.radians(el)) * math.sin(math.radians(az)), math.sin(math.radians(el))))
    cam.location = target + d * 60; cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler(); cam.data.clip_end = 200
    sc.camera = cam; sc.render.filepath = f"{cfg['out']}/LOOKDEV_{name}.png"; bpy.ops.render.render(write_still=True); print('LOOKDEV', sc.render.filepath)


shoot('overview', C, max(hi.x - lo.x, hi.y - lo.y) * 1.25, 200)
for c in cfg.get('close', []):
    org = Vector((c['xy'][0], c['xy'][1], hi.z + 5)); hit, loc, n, idx, ob, _ = sc.ray_cast(dg, org, Vector((0, 0, -1)))
    if not hit:
        print('LOOKDEV miss', c); continue
    shoot(c['name'], loc, 4.0, c.get('az', 200))
