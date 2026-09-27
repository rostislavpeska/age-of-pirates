"""Inside Blender: apply a conjoin plan as a review scene with a real UV layer.

    import runpy; runpy.run_path(path, init_globals=dict(ARGS=dict(
        plan='C:/.../plan.json', objects=['House_A'], scene='Claude_Conjoin_T3',
        uv_name='UV_T3', extra_objects=['House_H'])))

Copies each object (mesh data copied; sources untouched) into a new scene, adds
uv_name with the plan's packed coordinates (active + render), and assigns flat
family materials: same colour = same texels, grey = unique chart, black = objects
listed in extra_objects (e.g. hidden-material pages). Faces missing from the plan
keep their old UVs and are reported.
"""
import bpy, json, colorsys, zlib

A = globals().get('ARGS') or {}
plan = json.load(open(A['plan']))['faces']
scn = A.get('scene', 'Claude_Conjoin'); uv_name = A.get('uv_name', 'UV_Conjoin')


def linear(c):
    return tuple(x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in c)


def mat(key, rgb):
    m = bpy.data.materials.get(key) or bpy.data.materials.new(key)
    m.diffuse_color = (*linear(rgb), 1)
    return m


old = bpy.data.scenes.get(scn)
if old:
    bpy.data.scenes.remove(old)
sc = bpy.data.scenes.new(scn); sc.use_fake_user = True
report = {}
for name in A['objects'] + A.get('extra_objects', []):
    src = bpy.data.objects[name]
    me = src.data.copy(); me.name = f'{scn}_{name}'
    ob = bpy.data.objects.new(f'{scn}_{name}', me); ob.matrix_world = src.matrix_world
    sc.collection.objects.link(ob)
    me.materials.clear()
    if name in A.get('extra_objects', []):
        me.materials.append(mat(f'{scn}_black', (.004, .004, .004)))
        for p in me.polygons:
            p.material_index = 0
        continue
    while len(me.uv_layers) >= 8:
        me.uv_layers.remove(me.uv_layers[-1])
    uvl = me.uv_layers.new(name=uv_name, do_init=True)
    slots = {}; missing = 0
    for p in me.polygons:
        x = plan.get(f'{name}:{p.index}')
        if x is None:
            missing += 1; key, rgb = f'{scn}_missing', (1., 0., 1.)
        else:
            for j, li in enumerate(p.loop_indices):
                uvl.data[li].uv = x['uv'][j]
            if x['family_size'] > 1:
                h = (zlib.crc32(x['family'].encode()) % 1000) / 1000.
                key, rgb = f"{scn}_{x['family']}", colorsys.hsv_to_rgb(h, .72, .9)
            else:
                key, rgb = f'{scn}_unique', (.52, .54, .58)
        if key not in slots:
            slots[key] = len(me.materials); me.materials.append(mat(key, rgb))
        p.material_index = slots[key]
    uvl.active_render = True; me.uv_layers.active = uvl
    report[name] = dict(missing=missing, materials=len(slots))
sc.display.shading.color_type = 'MATERIAL'
print('applied', report)
