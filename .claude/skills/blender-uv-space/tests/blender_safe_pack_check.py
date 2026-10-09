"""Blender smoke check (background):  blender -b --factory-startup --python-exit-code 1 --python blender_safe_pack_check.py
A cube whose five side/top faces are packed and whose bottom face belongs to another page. Its four vertices are all
selected by the five targets, so a VERTEX-mode pack flushes it in and moves it (the hazard is reproduced first);
safe_pack must leave it untouched, and must raise when a forced flush would move it."""
import sys
from pathlib import Path
import bpy
import bmesh
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import safe_pack as SP  # noqa: E402


def cube():
    me = bpy.data.meshes.new('c'); bm = bmesh.new(); bmesh.ops.create_cube(bm, size=2.0); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new('cube', me); bpy.context.scene.collection.objects.link(o)
    me.uv_layers.new(name='UV')
    bpy.context.view_layer.objects.active = o; o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(island_margin=.02); bpy.ops.object.mode_set(mode='OBJECT')
    bottom = min(me.polygons, key=lambda p: p.center.z).index
    return o, bottom


def uvs(o, i):
    ul = o.data.uv_layers['UV'].data
    return [tuple(round(c, 6) for c in ul[l].uv) for l in o.data.polygons[i].loop_indices]


bpy.ops.wm.read_factory_settings(use_empty=True)
o, bottom = cube()
targets = {o.name: {p.index for p in o.data.polygons if p.index != bottom}}
# 1. the hazard: vertex mode + polygon.select + pack moves the non-target bottom face
ts = bpy.context.scene.tool_settings; ts.use_uv_select_sync = True; ts.mesh_select_mode = (True, False, False)
b0 = uvs(o, bottom)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='DESELECT'); bpy.ops.object.mode_set(mode='OBJECT')
for p in o.data.polygons:
    p.select = p.index in targets[o.name]
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.uv.pack_islands(rotate=True, scale=True, margin=.01); bpy.ops.object.mode_set(mode='OBJECT')
hazard = uvs(o, bottom) != b0
# 2. safe_pack on a fresh cube: the bottom face never moves
bpy.data.objects.remove(o)
o, bottom = cube()
targets = {o.name: {p.index for p in o.data.polygons if p.index != bottom}}
b0 = uvs(o, bottom)
rep = SP.safe_pack([o], targets, 1024, margin_px=4)
safe_ok = uvs(o, bottom) == b0 and rep['moved_non_targets'] == 0 and rep['targets'] == 5
ok = hazard and safe_ok
print('SAFE_PACK_CHECK', 'PASS' if ok else 'FAIL', {'hazard_reproduced': hazard, 'safe_pack_kept_non_target': safe_ok, 'report': rep})
sys.exit(0 if ok else 1)
