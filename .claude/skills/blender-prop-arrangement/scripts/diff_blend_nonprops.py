"""Compare two blends object by object, ignoring prop collections (name contains '| PROPS'): matrix_world (after a view-layer
refresh), mesh vertex hash, collection membership. Run: blender -b A.blend --python diff_blend_nonprops.py -- --other B.blend --out x.json"""
import bpy, sys, json, hashlib, argparse
ap = argparse.ArgumentParser(); ap.add_argument('--other', required=True); ap.add_argument('--out', required=True)
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:])


def snap():
    for sc in bpy.data.scenes:
        for vl in sc.view_layers:
            vl.update()
    props = {o.name for c in bpy.data.collections if '| PROPS' in c.name for o in c.objects}
    out = {}
    for o in bpy.data.objects:
        if o.name in props:
            continue
        h = hashlib.sha256()
        if o.type == 'MESH':
            for v in o.data.vertices:
                h.update(('%.5f %.5f %.5f' % tuple(v.co)).encode())
        out[o.name] = {'m': [round(x, 5) for r in o.matrix_world for x in r], 'mesh': h.hexdigest()[:16],
                       'cols': sorted(c.name for c in o.users_collection)}
    return out, sorted(props)


A, pa = snap(); fa = bpy.data.filepath
bpy.ops.wm.open_mainfile(filepath=a.other); B, pb = snap()
diff = {'only_in_a': sorted(set(A) - set(B)), 'only_in_b': sorted(set(B) - set(A)),
        'matrix': [k for k in A if k in B and A[k]['m'] != B[k]['m']], 'mesh': [k for k in A if k in B and A[k]['mesh'] != B[k]['mesh']],
        'collections': [k for k in A if k in B and A[k]['cols'] != B[k]['cols']]}
rep = {'a': fa, 'b': a.other, 'objects_a': len(A), 'objects_b': len(B), 'props_a': len(pa), 'props_b': len(pb),
       'counts': {k: len(v) for k, v in diff.items()}, 'diff': diff, 'identical_nonprops': not any(diff.values())}
json.dump(rep, open(a.out, 'w'), indent=1); print('DIFF_DONE', json.dumps({k: rep[k] for k in ('objects_a', 'objects_b', 'props_a', 'props_b', 'counts', 'identical_nonprops')}))
