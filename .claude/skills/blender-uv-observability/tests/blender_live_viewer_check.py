"""Blender smoke check (background): blender -b --factory-startup --python-exit-code 1 --python blender_live_viewer_check.py
The open file has UNSAVED edits when a newer version is published. The viewer must stash the edits to a recovery copy,
load the new file at once (never wait) and write a heartbeat that live_publish.py accepts as delivery."""
import importlib.util
import json
import sys
import tempfile
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parents[1] / 'scripts'
tmp = Path(tempfile.mkdtemp()); live = tmp / 'live'; live.mkdir()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.name = 'Review'
a, b = tmp / 'A.blend', tmp / 'B.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(b))                    # the newer checkpoint
bpy.data.objects.new('only in A', None); bpy.ops.wm.save_as_mainfile(filepath=str(a))
bpy.data.objects.new('unsaved owner edit', None)               # dirty
assert bpy.data.is_dirty

spec = importlib.util.spec_from_file_location('live_viewer', HERE / 'live_viewer.py'); LV = importlib.util.module_from_spec(spec)
spec.loader.exec_module(LV)
spec2 = importlib.util.spec_from_file_location('live_publish', HERE / 'live_publish.py'); LP = importlib.util.module_from_spec(spec2)
spec2.loader.exec_module(LP)
ptr = LP.publish(live, b, 'v2', 'Review')
LV.STATE['version'] = 'v1'
LV.tick(live / 'PUBLISHED.json')
st = json.loads((live / 'VIEWER_STATE.json').read_text())
ok, why = LP.readback_ok(ptr, st)
stashed = [Path(p) for p in LV.STATE['stashed']]
res = {'loaded': Path(bpy.data.filepath).name, 'state_ok': ok, 'why': why, 'stash_exists': bool(stashed) and stashed[0].exists()}
good = ok and res['stash_exists'] and Path(bpy.data.filepath).resolve() == Path(ptr['file']).resolve()
print('LIVE_VIEWER_CHECK', 'PASS' if good else 'FAIL', json.dumps(res))
sys.exit(0 if good else 1)
