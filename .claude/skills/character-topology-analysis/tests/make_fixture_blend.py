"""Background Blender only: write a fixture .blend with two synthetic cubes, one named for exclusion (the test that an
excluded object of a mixed file is never appended).

    blender -b --factory-startup --disable-autoexec --python-exit-code 2 --python make_fixture_blend.py -- OUT.blend
"""
import sys

import bpy

out = sys.argv[sys.argv.index('--') + 1]
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
for name, x in (('Cube - Keep', 0.0), ('Cube - Excluded', 3.0)):
    me = bpy.data.meshes.new(name)
    v = [(x + a, b, c) for c in (0, 1) for b in (0, 1) for a in (0, 1)]
    f = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    me.from_pydata(v, [], f)
    ob = bpy.data.objects.new(name, me)
    col = bpy.data.collections.new(name + ' col')
    bpy.context.scene.collection.children.link(col)
    col.objects.link(ob)
bpy.ops.wm.save_as_mainfile(filepath=out)
print('FIXTURE', out)
