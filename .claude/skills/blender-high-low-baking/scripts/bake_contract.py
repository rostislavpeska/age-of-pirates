"""Explicit bake scope and LOW geometry/normal identity; no scene/UI mutations.

Inside Blender: bake_contract.py -- record|check recipe.json contract.json
Recording a contract records current data, not visual acceptance. UV freeze is separate.
"""
import hashlib
import json
import sys
from pathlib import Path


def validate_scope(cfg, plan, face_counts):
    """Validate declared scope before loading HIGHs, allocating images or baking."""
    scope = cfg.get('scope')
    if not isinstance(scope, dict) or scope.get('mode') not in ('pilot', 'production'):
        raise ValueError('Recipe needs scope.mode (pilot/production) and scope.regions; '
                         'migrate by declaring intended faces and allowed HIGH names, not copying a failed selection.')
    if scope['mode'] == 'production' and (not cfg.get('freeze') or not cfg.get('input_contract')):
        raise ValueError('Production needs both freeze (UV/pages) and input_contract (LOW geometry/normals).')
    high_names = [n for h in cfg['highs'] for n in h['objects']]
    if len(high_names) != len(set(high_names)):
        raise ValueError('HIGH object names must be unique across recipe libraries for explicit pairing.')
    region_ids, face_region, pairs = set(), {}, {}
    regions = scope.get('regions')
    if not isinstance(regions, list) or not regions:
        raise ValueError('scope.regions must contain explicit named face/HIGH pairs.')
    for region in regions:
        rid, faces, highs = region.get('id'), region.get('faces'), region.get('highs')
        if not isinstance(rid, str) or not rid or rid in region_ids:
            raise ValueError('Each scope region needs a unique nonempty id.')
        if not isinstance(faces, list) or not faces or len(faces) != len(set(faces)):
            raise ValueError(f'{rid}: faces must be a nonempty list without duplicates.')
        if not isinstance(highs, list) or not highs or len(highs) != len(set(highs)) or set(highs) - set(high_names):
            raise ValueError(f'{rid}: highs must name existing recipe HIGHs, without duplicates.')
        region_ids.add(rid); pairs[rid] = list(highs)
        for key in faces:
            if key in face_region:
                raise ValueError(f'{key}: belongs to more than one scope region.')
            try:
                prefix, idx = key.rsplit(':', 1); idx = int(idx)
            except (AttributeError, ValueError):
                raise ValueError(f'{rid}: invalid face id {key!r}') from None
            e = plan.get(key)
            if prefix not in face_counts or not 0 <= idx < face_counts[prefix] or not e or not e.get('owner') or str(e.get('page', 'P')) not in cfg['pages']:
                raise ValueError(f'{rid}: {key} is not an eligible owner on a declared source/page.')
            face_region[key] = rid
    eligible = {f'{prefix}:{idx}' for prefix, count in face_counts.items() for idx in range(count)
                if (e := plan.get(f'{prefix}:{idx}')) and e.get('owner') and str(e.get('page', 'P')) in cfg['pages']}
    only = cfg.get('only')
    if only is not None:
        if not isinstance(only, list) or len(only) != len(set(only)) or set(only) - eligible:
            raise ValueError('only must contain unique eligible owner ids; unknown/member faces are not silently ignored.')
        actual = set(only)
    else:
        actual = eligible
    required = set(face_region)
    missing, unexpected = sorted(required - actual), sorted(actual - required)
    if missing or unexpected:
        raise ValueError(f'Scope mismatch: missing={missing}; unexpected={unexpected}')
    return dict(mode=scope['mode'], required=sorted(required), actual=sorted(actual), missing=[], unexpected=[],
                face_region=face_region, allowed_highs=pairs)


def fingerprint(objects):
    """LOW-only signature: positions, transform, winding, triangles and corner normals.

    Exact float32 arrays intentionally catch small edits. Not a replacement for UV/page
    freeze, a semantic correctness check, or a version-independent geometry canonicalizer.
    """
    import bpy
    import numpy as np
    per = {}
    for name in sorted(objects):
        ob = bpy.data.objects[name]; me = ob.data; me.calc_loop_triangles()
        h = hashlib.sha256()
        for coll, attr, size, dtype in (
            (me.vertices, 'co', 3, np.float32), (me.loops, 'vertex_index', 1, np.int32),
            (me.polygons, 'loop_start', 1, np.int32), (me.polygons, 'loop_total', 1, np.int32),
            (me.polygons, 'use_smooth', 1, np.bool_), (me.loop_triangles, 'loops', 3, np.int32),
        ):
            a = np.empty(len(coll) * size, dtype); coll.foreach_get(attr, a); h.update(a.tobytes())
        a = np.empty(len(me.corner_normals) * 3, np.float32); me.corner_normals.foreach_get('vector', a)
        h.update(a.tobytes()); h.update(np.asarray(ob.matrix_world, np.float32).tobytes())
        per[name] = h.hexdigest()
    return dict(schema=1, blender=bpy.app.version_string, objects=per,
                combined=hashlib.sha256(json.dumps(per, sort_keys=True).encode()).hexdigest())


def check_contract(cfg, current):
    if cfg.get('input_contract'):
        frozen = json.loads(Path(cfg['input_contract']).read_text())
        if frozen.get('schema') != current['schema'] or frozen.get('combined') != current['combined']:
            raise ValueError('LOW geometry/normals/triangles differ from input_contract; restore or review and record a new contract.')


def keep_faces(ob, indices, normal_tolerance=1e-4):
    """Extract faces on an owned copy, preserving original per-corner shading normals.

    Stable CORNER/FACE integer attributes survive BMesh deletion; order is verified
    rather than assumed. Source/destination triangle winding is compared in original
    loop coordinates. The passed object is mutated, never its authoring source.
    """
    import bpy
    import bmesh
    me = ob.data; indices = set(indices)
    if not indices or min(indices) < 0 or max(indices) >= len(me.polygons):
        raise ValueError('Receiver selection is empty or outside the source mesh.')
    names = ('__bake_loop_id', '__bake_face_id')
    if any(me.attributes.get(n) for n in names):
        raise ValueError('Reserved bake provenance attribute already exists.')
    me.calc_loop_triangles()
    normals = [v.vector.copy() for v in me.corner_normals]
    def cyclic(tri):
        t = tuple(tri); return min(t, t[1:] + t[:1], t[2:] + t[:2])
    triangles = {cyclic(t.loops) for t in me.loop_triangles if t.polygon_index in indices}
    li = me.attributes.new(names[0], 'INT', 'CORNER')
    for i, v in enumerate(li.data): v.value = i
    fi = me.attributes.new(names[1], 'INT', 'FACE')
    for i, v in enumerate(fi.data): v.value = i
    bm = bmesh.new()
    try:
        bm.from_mesh(me); bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in indices], context='FACES')
        bm.to_mesh(me)
    finally:
        bm.free()
    loop_ids = [v.value for v in me.attributes[names[0]].data]
    face_ids = [v.value for v in me.attributes[names[1]].data]
    if set(face_ids) != indices or len(face_ids) != len(indices):
        raise ValueError('Receiver extraction lost/duplicated original faces.')
    wanted = [normals[i] for i in loop_ids]
    before = max((v.vector - n).length for v, n in zip(me.corner_normals, wanted))
    # Avoid quantizing an already correct shading frame just to copy it back.
    if before > normal_tolerance:
        me.normals_split_custom_set(wanted)
    for n in names: me.attributes.remove(me.attributes[n])
    me.update(); me.calc_loop_triangles()
    after = max((v.vector - n).length for v, n in zip(me.corner_normals, wanted))
    if after > normal_tolerance:
        raise ValueError(f'Receiver corner normals changed by vector length {after:g} (limit {normal_tolerance:g}).')
    got = {cyclic(loop_ids[l] for l in t.loops) for t in me.loop_triangles}
    if got != triangles:
        raise ValueError('Receiver extraction changed destination triangulation/winding.')
    return dict(face_ids=face_ids, loops=len(loop_ids), normal_error_before=before,
                normal_error_after=after, normal_tolerance=normal_tolerance, triangles_equal=True)


if __name__ == '__main__':
    args = sys.argv[sys.argv.index('--') + 1:]
    mode, recipe, path = args
    cfg = json.loads(Path(recipe).read_text()); current = fingerprint(list(cfg['sources'].values()))
    if mode == 'record':
        Path(path).write_text(json.dumps(current, indent=2)); print('CONTRACT_RECORDED', current['combined'])
    elif mode == 'check':
        check_contract(dict(cfg, input_contract=path), current); print('CONTRACT_PASS', current['combined'])
    else:
        raise ValueError('Use record or check.')
