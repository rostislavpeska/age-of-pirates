"""Inside Blender (background): bake AO once per family OWNER into the real page images.

blender -b file.blend --python bake_owner_ao.py -- config.json
config = {
  "plan": "plan.json",                 # faces: key -> {uv, owner, page?}
  "sources": {"House_A": "House_A_object", ...},   # plan key prefix -> Blender object
  "extra_occluders": ["House_H_object"],
  "pages": {"P2048": 2048, "P1024": 1024},        # plans without 'page' use "P"
  "uv_name": "UV_Final", "radius": 0.5, "samples": 128, "margin": 4, "out_dir": "..."
}
Bake targets = owner faces only (grouped per page); every other face of the assembly is
present exactly once as an occluder. Members therefore show their owner's AO exactly as
the game will. Compare against a unique-texel bake (every face owner) to find artifacts.
"""
import bpy, bmesh, json, sys
from pathlib import Path

cfg = json.load(open(sys.argv[sys.argv.index('--') + 1]))
plan = json.load(open(cfg['plan']))['faces']
pages = cfg.get('pages', {'P': 4096}); UV = cfg.get('uv_name', 'UV_Final'); out = Path(cfg['out_dir'])
bs = bpy.data.scenes.new('Bake_owner_ao'); bpy.context.window.scene = bs
bs.render.engine = 'CYCLES'; bs.cycles.samples = int(cfg.get('samples', 128)); bs.cycles.device = 'CPU'
bs.world = bpy.data.worlds.new('W_owner_ao'); bs.world.light_settings.distance = float(cfg.get('radius', .5))
images = {pg: bpy.data.images.new(f'AO_{pg}', n, n) for pg, n in pages.items()}
for img in images.values():
    img.generated_color = (1, 1, 1, 1)


def copy(src, name):
    me = src.data.copy(); ob = bpy.data.objects.new(name, me); ob.matrix_world = src.matrix_world
    bs.collection.objects.link(ob); return ob


def keep(ob, idx):
    bm = bmesh.new(); bm.from_mesh(ob.data); bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in idx], context='FACES'); bm.to_mesh(ob.data); bm.free()


def set_uv(ob, key):
    ul = ob.data.uv_layers.new(name=UV, do_init=True)
    for p in ob.data.polygons:
        x = plan.get(f'{key}:{p.index}')
        if x:
            for j, li in enumerate(p.loop_indices):
                ul.data[li].uv = x['uv'][j]
    ul.active_render = True; ob.data.uv_layers.active = ul


targets = []
for key, name in cfg['sources'].items():
    src = bpy.data.objects[name]; n = len(src.data.polygons)
    owned_all = set()
    for pg in pages:
        idx = {i for i in range(n) if plan.get(f'{key}:{i}', {}).get('owner') and plan[f'{key}:{i}'].get('page', 'P') == pg}
        owned_all |= idx
        if not idx:
            continue
        t = copy(src, f'T_{key}_{pg}'); set_uv(t, key); keep(t, idx)
        m = bpy.data.materials.new(f'M_{key}_{pg}'); m.use_nodes = True; nt = m.node_tree
        tx = nt.nodes.new('ShaderNodeTexImage'); tx.image = images[pg]; uvn = nt.nodes.new('ShaderNodeUVMap'); uvn.uv_map = UV
        nt.links.new(uvn.outputs['UV'], tx.inputs['Vector']); nt.nodes.active = tx
        t.data.materials.clear(); t.data.materials.append(m); targets.append(t)
    o = copy(src, f'O_{key}'); keep(o, set(range(n)) - owned_all)
for name in cfg.get('extra_occluders', []):
    copy(bpy.data.objects[name], f'O_{name}')
for o in bs.objects:
    o.select_set(o in targets)
bpy.context.view_layer.objects.active = targets[0]
bpy.ops.object.bake(type='AO', margin=int(cfg.get('margin', 4)), use_clear=False)
for pg, img in images.items():
    img.filepath_raw = str(out / f'AO_{pg}.png'); img.file_format = 'PNG'; img.save()
print('BAKED', list(images))
