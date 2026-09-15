"""Tidy the built Treasure Ship scene for a human: named collections (Rig / Sails / Hull), armature named
zptreasureship, packed placeholder textures (nothing missing on disk), orphan data purged, bones as sticks.
The armature keeps its 0.01 object scale with mesh/bone data in engine units - that is exactly how the
converter's own FBX imports, and what the proven export settings expect.

usage: blender -b --python sails_clean.py -- build.blend out.blend
"""
import bpy, sys

args = sys.argv[sys.argv.index('--') + 1:]
src, dst = args[0], args[1]
bpy.ops.wm.open_mainfile(filepath=src)
sc = bpy.context.scene

arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
arm.name = 'zptreasureship'; arm.data.name = 'zptreasureship'
arm.data.display_type = 'STICK'; arm.show_in_front = True

# collections
root = sc.collection
for c in list(root.children): root.children.unlink(c)
cols = {n: bpy.data.collections.new(n) for n in ('Rig', 'Sails', 'Hull')}
for c in cols.values(): root.children.link(c)
for o in list(root.objects): root.objects.unlink(o)
for o in bpy.data.objects:
    for c in list(o.users_collection): c.objects.unlink(o)
    (cols['Rig'] if o.type == 'ARMATURE' else cols['Sails'] if o.name.startswith('sail_') else cols['Hull']).objects.link(o)

# hull objects get readable names (the mesh bones keep the vanilla names the converter needs)
for o in cols['Hull'].objects:
    o.name = {'spc_treasure_ship_stage_finalShape': 'hull_mata', 'spc_treasure_ship_stage_final_matbShape': 'hull_matb',
              'spc_treasure_ship_stage_final_matcShape': 'hull_matc'}.get(o.name, o.name); o.data.name = o.name

# materials: distinct flat colours, packed 4x4 images (the converter needs an image node to keep material names)
colours = {'mata': (0.55, 0.42, 0.28, 1), 'matb': (0.80, 0.72, 0.50, 1), 'matc': (0.75, 0.15, 0.10, 1)}
for m in bpy.data.materials:
    m.use_nodes = True; nt = m.node_tree
    bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    tex = next((n for n in nt.nodes if n.type == 'TEX_IMAGE'), None)
    img = tex.image if tex else None
    if img:
        col = colours.get(m.name, (0.6, 0.6, 0.6, 1)); img.pixels[:] = list(col) * (img.size[0] * img.size[1])
        img.filepath_raw = ''; img.pack(); img.name = m.name + '_placeholder'
    if bsdf: bsdf.inputs['Base Color'].default_value = colours.get(m.name, (0.6, 0.6, 0.6, 1))
    m.diffuse_color = colours.get(m.name, (0.6, 0.6, 0.6, 1))

bpy.ops.object.select_all(action='DESELECT')
bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
sc.frame_start, sc.frame_end = 1, 1
print('OBJECTS', [(c.name, [o.name for o in c.objects]) for c in cols.values()])
print('BONES', len(arm.data.bones), 'IMAGES', [(i.name, i.packed_file is not None) for i in bpy.data.images])
bpy.ops.wm.save_as_mainfile(filepath=dst); print('SAVED', dst)
