"""Run one builder script in an empty scene and save what it built (background Blender).

    blender -b --factory-startup --python build_runner.py -- BUILD.py OUT.blend

Removes every default object and data block first, runs BUILD.py as __main__ (its sys.argv is just its own path),
then saves OUT.blend even when the script raised, so a partial build can be inspected. Exit 2 when the script
raised (the traceback is printed), 0 otherwise.
"""
import runpy
import sys
import time
import traceback

import bpy

build, out = sys.argv[sys.argv.index('--') + 1:][:2]
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
for data in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights, bpy.data.curves):
    for d in list(data):
        data.remove(d)
code, t0, argv = 0, time.time(), sys.argv
sys.argv = [build]
try:
    runpy.run_path(build, run_name='__main__')
except SystemExit as e:
    code = 2 if e.code not in (None, 0) else 0
except Exception:
    traceback.print_exc(); code = 2
finally:
    sys.argv = argv
bpy.ops.wm.save_as_mainfile(filepath=out)
print('BUILD_RUNNER', 'ok' if code == 0 else 'error', '%.1fs' % (time.time() - t0), out)
sys.exit(code)
