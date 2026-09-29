"""UV freeze fingerprint: record the owner-frozen UV layer, check that nothing moved since.

blender -b file.blend --python uv_fingerprint.py -- record|check config.json
config = {
  "objects": ["Claude_S18_Pages_A", "Claude_S18_Pages_B"],   # the bake sources
  "uv_name": "UV_Final",
  "freeze": "uv_freeze.json",          # record writes it, check reads it
  "bakes": ["bake/bake_report.json"]   # check only: reports whose "uv_fingerprint" must match
}
The fingerprint covers the loop UVs (rounded to 1e-6), the polygon loop layout and the
material indices (the page split) of every object. check exits 3 on any difference.
Importable: fingerprint(objects, uv_name) -> {"uv_name", "objects": {name: sha256}, "combined"}.
"""
import hashlib
import json
import sys

import bpy
import numpy as np


def object_hash(ob, uv_name):
    me = ob.data
    uv = me.uv_layers.get(uv_name)
    assert uv, f'{ob.name}: no UV layer {uv_name}'
    co = np.empty(len(uv.data) * 2, dtype=np.float32); uv.data.foreach_get('uv', co)
    n = len(me.polygons)
    starts = np.empty(n, dtype=np.int32); me.polygons.foreach_get('loop_start', starts)
    totals = np.empty(n, dtype=np.int32); me.polygons.foreach_get('loop_total', totals)
    mats = np.empty(n, dtype=np.int32); me.polygons.foreach_get('material_index', mats)
    h = hashlib.sha256()
    for a in (np.round(co.astype(np.float64), 6) + 0.0, starts, totals, mats):
        h.update(np.ascontiguousarray(a).tobytes())
    return h.hexdigest()


def fingerprint(objects, uv_name):
    per = {name: object_hash(bpy.data.objects[name], uv_name) for name in objects}
    combined = hashlib.sha256(json.dumps(per, sort_keys=True).encode()).hexdigest()
    return {'uv_name': uv_name, 'objects': per, 'combined': combined}


def main(mode, cfg):
    fp = fingerprint(cfg['objects'], cfg.get('uv_name', 'UV_Final'))
    if mode == 'record':
        with open(cfg['freeze'], 'w') as f:
            json.dump(dict(fp, blend=bpy.data.filepath), f, indent=2)
        print('RECORDED', fp['combined'])
        return 0
    frozen = json.load(open(cfg['freeze']))
    bad = [f'layout changed since the freeze: {n}' for n in fp['objects']
           if frozen['objects'].get(n) != fp['objects'][n]]
    for path in cfg.get('bakes', []):
        if json.load(open(path)).get('uv_fingerprint') != frozen['combined']:
            bad.append(f'stale bake (made on another layout): {path}')
    print('CHECK FAIL' if bad else 'CHECK PASS', *bad, sep='\n  ')
    return 3 if bad else 0


if __name__ == '__main__' and '--' in sys.argv:
    args = sys.argv[sys.argv.index('--') + 1:]
    sys.exit(main(args[0], json.load(open(args[1]))))
