"""Read-only original-mesh UV export for uv_island_paint.py; run with Blender -b.

blender -b source.blend --python blender_uv_to_json.py -- --object ObjectName
  --uv UVMap --out triangles.json [--resource-attribute page --resource 1]
Optional --owner-attribute excludes the integer member value (default 2).
No scene save, evaluated geometry, UV rewriting, or generator invocation.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path
import bpy

ap = argparse.ArgumentParser()
ap.add_argument('--object', action='append', required=True)
ap.add_argument('--uv', required=True)
ap.add_argument('--out', required=True)
ap.add_argument('--resource-attribute')
ap.add_argument('--resource', type=int)
ap.add_argument('--owner-attribute')
ap.add_argument('--member-value', type=int, default=2)
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])
if bool(a.resource_attribute) != (a.resource is not None):
    ap.error('resource attribute and resource value must be given together')
triangles = []
for name in a.object:
    ob = bpy.data.objects[name]
    if ob.type != 'MESH':
        raise ValueError(f'{name} is not a mesh')
    me = ob.data
    uv = me.uv_layers[a.uv].data
    resource = me.attributes[a.resource_attribute].data if a.resource_attribute else None
    owner = me.attributes[a.owner_attribute].data if a.owner_attribute else None
    me.calc_loop_triangles()
    for t in me.loop_triangles:
        fi = t.polygon_index
        if resource and resource[fi].value != a.resource:
            continue
        if owner and owner[fi].value == a.member_value:
            continue
        triangles.append([[float(uv[l].uv.x), 1.0-float(uv[l].uv.y)] for l in t.loops])
if not triangles:
    raise ValueError('Selection has no eligible triangles; no empty mask is written')
source = Path(bpy.data.filepath)
record = dict(origin='top-left', source_id=hashlib.sha256(source.read_bytes()).hexdigest(),
              source_file=source.name, objects=a.object, uv_layer=a.uv,
              resource_attribute=a.resource_attribute, resource=a.resource,
              owner_attribute=a.owner_attribute, member_value=a.member_value,
              triangles=triangles)
Path(a.out).parent.mkdir(parents=True, exist_ok=True)
Path(a.out).write_text(json.dumps(record, indent=1), encoding='utf-8')
print('UV_JSON', len(triangles), 'triangles ->', a.out, flush=True)
