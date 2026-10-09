"""Inside Blender (background): bake high-poly maps once per family OWNER into the real page images.

blender -b file.blend --python bake_owner_maps.py -- recipe.json
recipe = {
  "plan": "plan.json",                       # faces: "<key>:<polygon>" -> {owner, page}
  "sources": {"S12_Groups_A": "Claude_S18_Pages_A"},   # plan key prefix -> low object (carries uv_name)
  "highs": [{"file": "roofs.blend", "objects": ["R0_f_HIGH"]},   # appended from another file
            {"objects": ["Local_HIGH"]}],                        # or already in this file
  "pages": {"P2048": 2048, "P1024": 1024},   # plan page id -> resolution
  "maps": ["NORMAL", "AO", "OPACITY"],
  "uv_name": "UV_Final", "extrusion": 0.05, "max_ray_distance": 0.25,
  "margin": 4, "samples": 16, "ao_distance": 0.15, "device": "CPU",
  "only": ["S12_Groups_A:12"],               # optional: restrict the targets (pilot bay / slope)
  "scope": {"mode": "pilot", "regions": [
      {"id": "roof", "faces": ["S12_Groups_A:12"], "highs": ["R0_f_HIGH"]}]},
  "opacity_classes": ["EAVE_CUTOUT"],        # optional: only these plan 'material' classes take opacity from
                                             # the highs; every other owner face is baked solid white
                                             # (a missed ray on a solid roof face must never become a hole)
  "freeze": "uv_freeze.json",                # optional: refuse unless the layer matches the freeze
  "input_contract": "low_contract.json",     # geometry/normals/triangles, separate from UV freeze
  "assembly": "roof_assembly_spec.json",     # REQUIRED when a scoped face is a roof material: the whole roof bakes
                                             # together (assembly_scope.py; owner 2026-10-09)
  "out_dir": "..."
}
Every recipe declares exact scope and allowed source pairs. Production mode requires
both freeze and input_contract. Expanding a pilot requires a new explicit scope, not
deleting "only". See references/bake-contract.md for migration and preflight-only use.

Targets = owner faces only, one copy per source/page/pair; members are never targets, so no
member overwrites its owner's texels. Highs are the only projection sources (no cage object:
rays start `extrusion` above the low surface and travel at most `max_ray_distance`).
- NORMAL: tangent space of uv_name, axes +X +Y +Z. The game's convention is separate validation.
- AO: local AO emitted from the highs (finite distance); multiply it with the assembly AO
  from blender-uv-ao-separation/bake_owner_ao.py.
- OPACITY: the page starts black, the highs emit white; texels whose ray misses stay black.
Writes <MAP>_<page>.exr (linear master) + .png (16-bit preview) and bake_report.json with the
recipe, the UV fingerprint, target and high bounds, and per-image statistics. The .blend is never saved.
"""
import importlib.util
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent


def _load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f'{name}.py')
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    return mod


fp_mod, pair, contract, assembly = _load('uv_fingerprint'), _load('bake_pair'), _load('bake_contract'), _load('assembly_scope')
cfg = json.load(open(sys.argv[sys.argv.index('--') + 1]))
plan = json.load(open(cfg['plan']))['faces']
pages = cfg['pages']; UV = cfg.get('uv_name', 'UV_Final'); out = Path(cfg['out_dir'])
maps = cfg.get('maps', ['NORMAL'])
scope = contract.validate_scope(cfg, plan, {key: len(bpy.data.objects[name].data.polygons)
                                          for key, name in cfg['sources'].items()})
# Assembly gate (owner 2026-10-09): a roof scope must hold its whole roof - field, eave fronts, undersides, caps.
asm = assembly.check(cfg, plan, Path(sys.argv[sys.argv.index('--') + 1]).parent)
if asm['verdict'] != 'PASS':
    raise ValueError('ASSEMBLY GATE FAIL: ' + ' | '.join(asm['errors']))
input_fp = contract.fingerprint(list(cfg['sources'].values()))
contract.check_contract(cfg, input_fp)

for name in cfg['sources'].values():
    assert not bpy.data.objects[name].modifiers, f'{name}: apply modifiers first (the bake uses mesh data)'
fp = fp_mod.fingerprint(list(cfg['sources'].values()), UV)
if cfg.get('freeze'):
    frozen = json.load(open(cfg['freeze']))['combined']
    assert frozen == fp['combined'], f'{UV} differs from the freeze: re-freeze with the owner or restore the layer'
out.mkdir(parents=True, exist_ok=True)

bs = bpy.data.scenes.new('Bake_owner_maps'); vl = bs.view_layers[0]
if bpy.context.window:
    bpy.context.window.scene = bs
bs.render.engine = 'CYCLES'; bs.cycles.samples = int(cfg.get('samples', 16))
bs.cycles.device = cfg.get('device', 'CPU')


def copy(src, name):
    ob = bpy.data.objects.new(name, src.data.copy()); ob.matrix_world = src.matrix_world
    bs.collection.objects.link(ob); return ob


def world_bbox(ob):
    pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    return [[min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)]]


targets, target_classes, target_pairs, receiver_checks = {}, {}, {}, {}
cut_classes = set(cfg['opacity_classes']) if cfg.get('opacity_classes') else None
for key, name in cfg['sources'].items():
    src = bpy.data.objects[name]
    for pg in pages:
        for rid, allowed in scope['allowed_highs'].items():
            idx = {int(face.rsplit(':', 1)[1]) for face in scope['required']
                   if face.rsplit(':', 1)[0] == key and scope['face_region'][face] == rid
                   and str(plan[face].get('page', 'P')) == pg}
            if not idx:
                continue
            t = copy(src, f'T_{key}_{pg}_{rid}')
            check = contract.keep_faces(t, idx); receiver_checks[t.name] = check
            target_pairs[t.name] = allowed
            target_classes[t.name] = [plan[f'{key}:{i}'].get('material') for i in check['face_ids']]
            for uv_name in [u.name for u in t.data.uv_layers if u.name != UV]:
                t.data.uv_layers.remove(t.data.uv_layers[uv_name])
            t.data.uv_layers[UV].active = True; t.data.uv_layers[UV].active_render = True
            m = bpy.data.materials.new(f'M_{t.name}'); m.use_nodes = True
            m.node_tree.nodes.active = m.node_tree.nodes.new('ShaderNodeTexImage')
            t.data.materials.clear(); t.data.materials.append(m)
            targets.setdefault(pg, []).append(t)
assert targets, 'No owner faces matched the plan, pages and "only"'
preflight = dict(scope=scope, assembly=asm, low_contract=input_fp, uv_fingerprint=fp, receivers=receiver_checks)
(out / 'preflight.json').write_text(json.dumps(preflight, indent=2))
if cfg.get('preflight_only'):
    print('PREFLIGHT_PASS', out / 'preflight.json')
    sys.exit(0)

highs, highs_by_name = [], {}
for h in cfg['highs']:
    if h.get('file'):
        with bpy.data.libraries.load(h['file'], link=False) as (src_lib, dst_lib):
            missing = set(h['objects']) - set(src_lib.objects)
            assert not missing, f'{h["file"]}: missing {sorted(missing)}'
            dst_lib.objects = list(h['objects'])
        objs = list(dst_lib.objects)
    else:
        objs = [bpy.data.objects[n] for n in h['objects']]
    for requested, o in zip(h['objects'], objs):
        if o.name not in bs.collection.objects:
            bs.collection.objects.link(o)
        highs.append(o)
        highs_by_name[requested] = o


def emission_material(name, ao=False):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    em = nt.nodes.new('ShaderNodeEmission'); o = nt.nodes.new('ShaderNodeOutputMaterial')
    if ao:
        a = nt.nodes.new('ShaderNodeAmbientOcclusion'); a.only_local = True
        a.samples = int(cfg.get('samples', 16)); a.inputs['Distance'].default_value = float(cfg.get('ao_distance', .15))
        nt.links.new(a.outputs['AO'], em.inputs['Color'])
    nt.links.new(em.outputs[0], o.inputs[0])
    return m


def use_on_highs(mat):
    # The session is never saved, so the highs' own materials need no restoring.
    for h in highs:
        if not h.material_slots:
            h.data.materials.append(mat)
        for slot in h.material_slots:
            slot.material = mat


# EMIT: the highs' OWN emission shaders projected as they are (e.g. per-tile colour / ID shaders that
# follow the same course frames as the relief). It runs before AO/OPACITY, which replace those shaders.
START = {'NORMAL': (.5, .5, 1, 1), 'EMIT': (0, 0, 0, 1), 'AO': (1, 1, 1, 1), 'OPACITY': (0, 0, 0, 1)}
report = dict(recipe=cfg, blender=bpy.app.version_string, uv_fingerprint=fp['combined'], uv_objects=fp['objects'],
              preflight=preflight,
              targets={pg: {t.name: dict(faces=len(t.data.polygons), bbox=world_bbox(t)) for t in ts} for pg, ts in targets.items()},
              highs={h.name: dict(mesh_faces=len(h.data.polygons), modifiers=[m.type for m in h.modifiers], bbox=world_bbox(h)) for h in highs},
              images={})
for kind in [k for k in ('NORMAL', 'EMIT', 'AO', 'OPACITY') if k in maps]:
    if kind == 'AO':
        use_on_highs(emission_material('Bake_AO_source', ao=True))
    elif kind == 'OPACITY':
        use_on_highs(emission_material('Bake_opacity_source'))
    for pg, ts in targets.items():
        n = int(pages[pg]); img = bpy.data.images.new(f'{kind}_{pg}', n, n, alpha=False, float_buffer=True)
        img.colorspace_settings.name = 'Non-Color'; img.generated_color = START[kind]
        for t in ts:
            t.active_material.node_tree.nodes.active.image = img
        passes = [(t, True, target_pairs[t.name]) for t in ts]
        if kind == 'OPACITY' and cut_classes is not None:
            passes = []
            for t in ts:
                cls = target_classes[t.name]
                solid = {i for i, c in enumerate(cls) if c not in cut_classes}
                if solid:  # solid faces: self-bake white into their own islands, no rays to the highs
                    s = bpy.data.objects.new(t.name + '_solid', t.data.copy()); s.matrix_world = t.matrix_world
                    bs.collection.objects.link(s); contract.keep_faces(s, solid)
                    wm = emission_material('Bake_opacity_solid'); wm.node_tree.nodes.active = wm.node_tree.nodes.new('ShaderNodeTexImage')
                    wm.node_tree.nodes.active.image = img; s.data.materials.clear(); s.data.materials.append(wm)
                    passes.append((s, False, []))
                if len(solid) < len(cls):
                    c = bpy.data.objects.new(t.name + '_cut', t.data.copy()); c.matrix_world = t.matrix_world
                    bs.collection.objects.link(c); contract.keep_faces(c, set(range(len(cls))) - solid)
                    passes.append((c, True, target_pairs[t.name]))
        for t, from_highs, allowed in passes:
            selected_highs = [highs_by_name[n] for n in allowed]
            for o in bs.objects:
                o.select_set(o is t or (from_highs and o in selected_highs), view_layer=vl)
            vl.objects.active = t
            with bpy.context.temp_override(scene=bs, view_layer=vl):
                bpy.ops.object.bake(type='NORMAL' if kind == 'NORMAL' else 'EMIT', use_selected_to_active=from_highs,
                                    use_cage=False, cage_extrusion=float(cfg.get('extrusion', .05)),
                                    max_ray_distance=float(cfg.get('max_ray_distance', .25)),
                                    normal_space='TANGENT', normal_r='POS_X', normal_g='POS_Y', normal_b='POS_Z',
                                    margin=int(cfg.get('margin', 4)), margin_type='EXTEND', use_clear=False)
        stem = f'{kind}_{pg}'
        img.filepath_raw = str(out / f'{stem}.exr'); img.file_format = 'OPEN_EXR'; img.save()
        s = bs.render.image_settings
        s.file_format = 'PNG'; s.color_mode = 'RGB' if kind in ('NORMAL', 'EMIT') else 'BW'; s.color_depth = '16'
        bs.view_settings.view_transform = 'Raw'
        img.save_render(str(out / f'{stem}.png'), scene=bs)
        report['images'][stem] = dict(stats=pair.image_statistics(img, kind if kind == 'NORMAL' else 'AO'),
                                      master=str(out / f'{stem}.exr'), preview=str(out / f'{stem}.png'))
        print('BAKED', stem)
(out / 'bake_report.json').write_text(json.dumps(report, indent=2))
print('REPORT', out / 'bake_report.json')
