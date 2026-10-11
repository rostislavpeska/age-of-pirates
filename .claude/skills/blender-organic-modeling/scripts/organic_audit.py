#!/usr/bin/env python
"""Audit a skinned organic mesh (normally the export copy) against its contract, in background Blender.

    python organic_audit.py --blend FILE.blend [options]            # relaunches itself in background Blender
    python organic_audit.py --blender-exe EXE ...                    # or --local-config FILE (tools.blender.path)
    blender -b --factory-startup --python-exit-code 2 --python organic_audit.py -- --blend FILE.blend [options]

    # once, on the freshly imported donor skeleton: snapshot bone heads, tails, rest matrices, armature matrix
    python organic_audit.py --blend donor.blend --write-reference SCRATCH/donor_ref.json

    # every export: the contract's numbers in place of the capitals (one command line)
    python organic_audit.py --blend body_export.blend --armature rig --mesh body --mesh weapon
        --max-tris CEILING --target-tris TARGET --max-verts VERTEX_CEILING --cap 4 --max-mean-influences MEAN
        --allowed-bones @allowed.txt --mesh-bones body=@body_bones.txt --mesh-bones weapon=@weapon_bones.txt
        --reference SCRATCH/donor_ref.json --symmetry body --report SCRATCH/audit.json

Checks (ids in the JSON report; FAIL fails the run, WARN and INFO do not):
  ngons, triangulated        no face with more than 4 corners; export stage: no quads either (explicit triangulation)
  triangle_budget            triangles (loop triangles) of all audited meshes <= --max-tris; WARN above --target-tris
  vertex_budget              Blender vertices <= --max-verts; GPU-vertex estimate reported
  modifiers                  export stage: no modifier other than the armature binding
  armature_binding           exactly one Armature modifier per mesh, pointing at the audited armature
  transforms_match           mesh and armature object matrices equal (WARN)
  preserve_volume            Preserve Volume off on every Armature modifier (linear-blend preview)
  unweighted                 every vertex has a bone weight
  influence_cap              nonzero bone influences per vertex <= --cap
  influence_mean             mean influences <= --max-mean-influences (when given)
  weight_sums                |sum of bone weights - 1| <= --sum-tol (1e-6)
  clean_limit                no bone weight in (0, --clean-limit)
  allowed_bones              weighted bone groups are a subset of --allowed-bones (exact strings), and each mesh
                             named by --mesh-bones carries only the bones of its own list
  group_hygiene              every vertex group names a bone and carries weight
  side_suffix                no leftover temporary .L/.R group name that is not a bone
  deform_flags               the Deform flag is on only for allowed bones
  nondeform_weights          no weight on a bone whose Deform flag is off (Blender ignores it, the game would not)
  ref_objects                export stage: no object named with --ref-prefix (REF_)
  donor_match                bone names, parents, heads, tails, rest matrices and armature matrix equal the
                             --reference snapshot within --donor-tol
  mirror_names               bpy.utils.flip_name on each side name: unchanged = Blender's mirror tools pair nothing
                             (INFO), different from the explicit partner (WARN), partner bone missing (WARN)
  weight_symmetry            for meshes named by --symmetry: mirrored vertex pairs (armature space, --mirror-tol)
                             carry mirrored weights within --symmetry-weight-tol (1/255); a vertex with no mirror
                             partner FAILs too (its weights cannot be compared), WARN with --symmetry-unpaired warn
  quantized_255              8-bit quantization of every vertex sums to 255 with no used slot at 0, descending, no
                             bone twice; --quantized-json checks weights read back from a game file the same way

Distances are in armature-space units (the armature's local frame, before its object scale). The report goes to
--report, default a new folder in the system temp directory; a path inside a git work tree is refused.
Exit 0 = no FAIL, 1 = at least one FAIL, 2 = setup error or the audit could not run (object missing, bad argument,
missing or malformed --reference / --allowed-bones / --mesh-bones / --quantized-json file, unreadable .blend,
refused path, no Blender, unexpected exception); exit 2 never writes a report. The direct form needs --python-exit-code 2 so that an
exception raised outside the audit (an import) cannot exit 0.
"""
import argparse
import hashlib
import json
import os
import sys
import time
import traceback
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import blender_env as E  # noqa: E402
import organic_weights as W  # noqa: E402

try:
    import bpy
    from mathutils.kdtree import KDTree
except ImportError:  # host Python: relaunch in Blender
    bpy = None
if bpy is not None and not hasattr(bpy, 'app'):  # a stub or namespace 'bpy' on the host is not Blender
    bpy = None

SCHEMA = 1


class SetupError(Exception):
    pass


def parse_args(argv):
    ap = argparse.ArgumentParser(prog='organic_audit.py', description=__doc__.splitlines()[0])
    ap.add_argument('--blend', help='.blend file to open (default: the file Blender already loaded)')
    ap.add_argument('--armature', help='armature object (default: the only armature in the file)')
    ap.add_argument('--mesh', action='append', default=[], help='mesh object to audit (repeatable; default: every '
                    'mesh bound to the armature, without --ref-prefix)')
    ap.add_argument('--collection', help='limit default meshes and the REF_ check to this collection (recursive)')
    ap.add_argument('--stage', choices=('export', 'working'), default='export',
                    help='export (default): triangulated copy, modifiers applied, no REF_ objects; working: quads, '
                         'live modifiers and REF_ objects allowed, counts from the evaluated mesh')
    ap.add_argument('--max-tris', type=int, help='triangle ceiling over all audited meshes')
    ap.add_argument('--target-tris', type=int, help='triangle target (WARN above it)')
    ap.add_argument('--max-verts', type=int, help='vertex ceiling (Blender vertices) over all audited meshes')
    ap.add_argument('--cap', type=int, default=4, help='influence cap per vertex (default 4)')
    ap.add_argument('--max-mean-influences', type=float, help='ceiling for the mean influences per vertex')
    ap.add_argument('--clean-limit', type=float, default=0.02, help='no weight in (0, limit) (default 0.02)')
    ap.add_argument('--sum-tol', type=float, default=1e-6, help='weight-sum tolerance (default 1e-6)')
    ap.add_argument('--allowed-bones', help="bones that may carry weight: 'A,B' or @file (.txt one per line, .json)")
    ap.add_argument('--mesh-bones', action='append', default=[], metavar='MESH=BONES',
                    help="the bones one mesh may carry ('A,B' or @file), a subset of --allowed-bones, checked by "
                         "allowed_bones; --allowed-bones stays the union the deform flags are checked against "
                         "(repeatable; e.g. a body and a skinned weapon on one armature)")
    ap.add_argument('--ref-prefix', default='REF_', help='scratch-object prefix never exported (default REF_)')
    ap.add_argument('--reference', help='armature snapshot JSON written by --write-reference')
    ap.add_argument('--donor-tol', type=float, default=1e-5, help='donor tolerance, armature units (default 1e-5)')
    ap.add_argument('--write-reference', help='write the armature snapshot JSON here and exit')
    ap.add_argument('--symmetry', action='append', default=[], help="mesh to test for mirrored weights (repeatable; "
                    "'*' = every audited mesh)")
    ap.add_argument('--mirror-axis', choices=('x', 'y', 'z'), default='x', help='left-right axis in armature space')
    ap.add_argument('--mirror-tol', type=float, default=1e-4, help='vertex pairing distance, armature units')
    ap.add_argument('--symmetry-weight-tol', type=float, default=1.0 / 255, help='mirrored weight tolerance')
    ap.add_argument('--symmetry-unpaired', choices=('fail', 'warn'), default='fail',
                    help='status when a --symmetry mesh has vertices without a mirror partner (default fail)')
    ap.add_argument('--quantized-json', help='quantized weights read back from a game file: {"vertices": '
                    '[[[bone, q], ...], ...]} or {"meshes": {name: vertices}}')
    ap.add_argument('--report', help='report JSON path (default: new temp folder)')
    E.add_blender_args(ap)
    return ap.parse_args(argv)


# ---------------------------------------------------------------- helpers


def vec(v):
    return [round(float(x), 9) for x in v]


def mat(m):
    return [[round(float(x), 9) for x in row] for row in m]


def mat_diff(a, b):
    return max(abs(a[i][j] - b[i][j]) for i in range(len(a)) for j in range(len(a[0])))


def vec_diff(a, b):
    return max(abs(x - y) for x, y in zip(a, b))


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def collection_objects(name):
    coll = bpy.data.collections.get(name)
    if coll is None:
        raise SetupError('collection not found: %s' % name)
    return list(coll.all_objects)


def find_armature(name):
    if name:
        ob = bpy.data.objects.get(name)
        if ob is None or ob.type != 'ARMATURE':
            raise SetupError('armature object not found: %s' % name)
        return ob
    arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    if len(arms) != 1:
        raise SetupError('%d armatures in the file; name one with --armature' % len(arms))
    return arms[0]


def armature_snapshot(arm):
    return {'tool': 'organic_audit', 'kind': 'armature-reference', 'schema': SCHEMA,
            'blender': bpy.app.version_string, 'file': bpy.data.filepath, 'armature': arm.name,
            'units': 'armature-space units', 'matrix_world': mat(arm.matrix_world),
            'bones': [{'name': b.name, 'parent': b.parent.name if b.parent else None,
                       'head_local': vec(b.head_local), 'tail_local': vec(b.tail_local),
                       'matrix_local': mat(b.matrix_local)} for b in arm.data.bones]}


def gpu_vertices(me):
    """Distinct corner keys (vertex, material, UV winding sign, every UV layer, split normal)."""
    layers = [layer.data for layer in me.uv_layers]
    try:
        normals = [tuple(round(c, 4) for c in n.vector) for n in me.corner_normals]
    except AttributeError:  # Blender < 4.1
        me.calc_normals_split()
        normals = [tuple(round(c, 4) for c in lp.normal) for lp in me.loops]
    keys = set()
    for p in me.polygons:
        sign = 0
        if layers:
            uv = [layers[0][li].uv for li in p.loop_indices]
            area = sum(uv[k].x * uv[(k + 1) % len(uv)].y - uv[(k + 1) % len(uv)].x * uv[k].y for k in range(len(uv)))
            sign = (area > 0) - (area < 0)
        for li in p.loop_indices:
            k = (me.loops[li].vertex_index, p.material_index, sign, normals[li])
            k += tuple(tuple(round(c, 5) for c in layer[li].uv) for layer in layers)
            keys.add(k)
    return len(keys)


def mesh_counts(ob, stage):
    """Vertices, triangles, face sizes and GPU estimate: the mesh data at export, the evaluated mesh when working."""
    if stage == 'working':
        dg = bpy.context.evaluated_depsgraph_get()
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
    else:
        ev, me = None, ob.data
    me.calc_loop_triangles()
    sizes = [p.loop_total for p in me.polygons]
    out = {'vertices': len(me.vertices), 'triangles': len(me.loop_triangles), 'faces': len(sizes),
           'ngons': sum(1 for s in sizes if s > 4), 'quads': sum(1 for s in sizes if s == 4),
           'gpu_vertices_estimate': gpu_vertices(me), 'uv_layers': len(me.uv_layers)}
    if ev is not None:
        ev.to_mesh_clear()
    return out


def read_weights(ob, bone_names):
    """Per vertex [(bone, w)] with w > 0 for groups named after armature bones, plus group facts."""
    names = {g.index: g.name for g in ob.vertex_groups}
    weighted, zero_members = set(), 0
    per_vertex = []
    for v in ob.data.vertices:
        ent = []
        for g in v.groups:
            n = names.get(g.group)
            if n is None:
                continue
            if g.weight > 0:
                weighted.add(n)
                if n in bone_names:
                    ent.append((n, float(g.weight)))
            else:
                zero_members += 1
        per_vertex.append(ent)
    groups = [g.name for g in ob.vertex_groups]
    return per_vertex, {'groups': groups, 'weighted_groups': sorted(weighted), 'zero_weight_memberships': zero_members,
                        'empty_groups': [n for n in groups if n not in weighted],
                        'non_bone_groups': [n for n in groups if n not in bone_names]}


def symmetry(ob, arm, per_vertex, bone_names, axis, tol, wtol):
    m = arm.matrix_world.inverted() @ ob.matrix_world
    pts = [m @ v.co for v in ob.data.vertices]
    kd = KDTree(len(pts))
    for i, p in enumerate(pts):
        kd.insert(p, i)
    kd.balance()
    ax = 'xyz'.index(axis)
    partner = {n: W.mirror_name(n)[0] for n in bone_names}
    missing = sorted(n for n, p in partner.items() if p not in bone_names)
    pairs = bad = 0
    unpaired, seen = [], set()
    worst, worst_at = 0.0, None
    for i, p in enumerate(pts):
        q = p.copy()
        q[ax] = -q[ax]
        _co, j, d = kd.find(q)
        if j is None or d > tol:
            unpaired.append(i)
            continue
        key = (min(i, j), max(i, j))
        if key in seen:
            continue
        seen.add(key)
        pairs += 1
        wi, wj = dict(per_vertex[i]), dict(per_vertex[j])
        diffs = [abs(w - wj.get(partner.get(b, b), 0.0)) for b, w in wi.items()]
        diffs += [abs(w - wi.get(partner.get(b, b), 0.0)) for b, w in wj.items()]
        d_max = max(diffs, default=0.0)
        if d_max > wtol:
            bad += 1
        if d_max > worst:
            worst, worst_at = d_max, [i, j]
    return {'pairs': pairs, 'unpaired_vertices': len(unpaired), 'first_unpaired': unpaired[:20] or None,
            'pairs_over_tol': bad, 'max_weight_diff': round(worst, 7), 'worst_pair': worst_at,
            'bones_without_partner': missing}


def read_json(path, what):
    try:
        return json.loads(Path(path).read_text(encoding='utf-8-sig'))
    except (OSError, ValueError) as exc:  # missing, unreadable, not UTF-8, not JSON
        raise SetupError('%s %s: %s' % (what, path, exc))


def load_quantized(path):
    """{mesh: [[(bone, q), ...] per vertex]} from a game-file readback; SetupError on any other shape."""
    data = read_json(path, '--quantized-json')
    if isinstance(data, dict) and 'meshes' in data:
        meshes = data['meshes']
    elif isinstance(data, dict) and 'vertices' in data:
        meshes = {'(file)': data['vertices']}
    else:
        raise SetupError('--quantized-json %s: expected {"vertices": [...]} or {"meshes": {...}}' % path)
    if not isinstance(meshes, dict):
        raise SetupError('--quantized-json %s: "meshes" must map mesh names to vertex lists' % path)
    out = {}
    for name, verts in meshes.items():
        if not isinstance(verts, list):
            raise SetupError('--quantized-json %s: mesh %s is not a vertex list' % (path, name))
        rows = []
        for i, entries in enumerate(verts):
            ok = isinstance(entries, list) and all(
                isinstance(e, list) and len(e) == 2 and isinstance(e[0], str) and isinstance(e[1], int)
                and not isinstance(e[1], bool) for e in entries)
            if not ok:
                raise SetupError('--quantized-json %s: mesh %s vertex %d is not [["bone", integer q], ...]'
                                 % (path, name, i))
            rows.append([(b, q) for b, q in entries])
        out[str(name)] = rows
    return out


def load_reference(path):
    """An armature snapshot written by --write-reference; SetupError on any other shape."""
    ref = read_json(path, '--reference')
    try:
        ok = (ref.get('kind') == 'armature-reference' and len(ref['matrix_world']) == 4
              and all(len(r) == 4 for r in ref['matrix_world']))
        for b in ref['bones'] if ok else ():
            ok = ok and (isinstance(b['name'], str) and 'parent' in b and len(b['head_local']) == 3
                         and len(b['tail_local']) == 3 and len(b['matrix_local']) == 4)
    except (AttributeError, KeyError, TypeError):
        ok = False
    if not ok:
        raise SetupError('--reference %s is not an armature snapshot written by --write-reference' % path)
    return ref


def load_allowed(arg, option='--allowed-bones'):
    try:
        return W.parse_name_list(arg)
    except (OSError, ValueError, TypeError) as exc:
        raise SetupError('%s %s: %s' % (option, arg, exc))


def load_mesh_bones(specs, allowed):
    """--mesh-bones MESH=BONES entries -> {mesh: set of bones}; each list must lie inside --allowed-bones."""
    out = {}
    for spec in specs:
        name, sep, names = spec.partition('=')
        if not sep or not name.strip() or not names.strip():
            raise SetupError('--mesh-bones %s: expected MESH=BONES' % spec)
        if allowed is None:
            raise SetupError('--mesh-bones %s: needs --allowed-bones (the union of every mesh list)' % spec)
        bones = set(load_allowed(names.strip(), '--mesh-bones'))
        outside = sorted(bones - set(allowed))
        if outside:
            raise SetupError('--mesh-bones %s: not in --allowed-bones: %s' % (name, outside))
        out[name.strip()] = bones
    return out


# ---------------------------------------------------------------- audit


def audit(a):
    # input files first: a missing or malformed one is a setup error before any work
    if not a.write_reference:
        allowed = load_allowed(a.allowed_bones)
        mesh_bones = load_mesh_bones(a.mesh_bones, allowed)
        ref = load_reference(a.reference) if a.reference else None
        quantized = load_quantized(a.quantized_json) if a.quantized_json else None
    if a.blend:
        if not Path(a.blend).is_file():
            raise SetupError('blend file not found: %s' % a.blend)
        try:
            bpy.ops.wm.open_mainfile(filepath=str(Path(a.blend).resolve()))
        except RuntimeError as exc:
            raise SetupError('cannot open %s: %s' % (a.blend, str(exc).strip()))
    bpy.context.view_layer.update()
    arm = find_armature(a.armature)

    if a.write_reference:
        err = E.refuse_in_worktree(a.write_reference, 'reference')
        if err:
            raise SetupError(err)
        Path(a.write_reference).parent.mkdir(parents=True, exist_ok=True)
        snap = armature_snapshot(arm)
        Path(a.write_reference).write_text(json.dumps(snap, indent=1), encoding='utf-8')
        print('REFERENCE %s: %d bones of %s' % (a.write_reference, len(snap['bones']), arm.name))
        return None, 0

    scope = collection_objects(a.collection) if a.collection else list(bpy.data.objects)
    if a.mesh:
        meshes = []
        for n in a.mesh:
            ob = bpy.data.objects.get(n)
            if ob is None or ob.type != 'MESH':
                raise SetupError('mesh object not found: %s' % n)
            meshes.append(ob)
    else:
        meshes = [o for o in scope if o.type == 'MESH' and not o.name.startswith(a.ref_prefix)
                  and any(m.type == 'ARMATURE' and m.object == arm for m in o.modifiers)]
    if not meshes:
        raise SetupError('no mesh bound to %s; name meshes with --mesh' % arm.name)
    unknown = sorted(set(mesh_bones) - {ob.name for ob in meshes})
    if unknown:
        raise SetupError('--mesh-bones names meshes that are not audited: %s' % unknown)
    allowed_set = set(allowed) if allowed is not None else None
    bones = list(arm.data.bones)
    bone_names = {b.name for b in bones}
    deform = {b.name for b in bones if b.use_deform}
    if allowed_set is not None and not allowed_set <= bone_names:
        raise SetupError('allowed bones not in %s: %s' % (arm.name, sorted(allowed_set - bone_names)))
    export = a.stage == 'export'
    checks = []

    def add(cid, status, value=None, limit=None, detail=None, **extra):
        row = {'id': cid, 'status': status, 'value': value, 'limit': limit, 'detail': detail}
        row.update(extra)
        checks.append(row)

    # counts
    per_mesh = {ob.name: mesh_counts(ob, a.stage) for ob in meshes}
    tot = {k: sum(c[k] for c in per_mesh.values()) for k in ('vertices', 'triangles', 'ngons', 'quads',
                                                              'gpu_vertices_estimate')}
    add('ngons', 'pass' if tot['ngons'] == 0 else ('fail' if export else 'warn'), tot['ngons'], 0,
        {n: c['ngons'] for n, c in per_mesh.items() if c['ngons']} or None)
    add('triangulated', ('pass' if tot['quads'] == 0 else 'fail') if export else 'info', tot['quads'], 0 if export else None,
        'faces with 4 corners' if tot['quads'] else None)
    if a.max_tris is not None and tot['triangles'] > a.max_tris:
        st = 'fail'
    elif a.target_tris is not None and tot['triangles'] > a.target_tris:
        st = 'warn'
    else:
        st = 'pass' if (a.max_tris is not None or a.target_tris is not None) else 'info'
    add('triangle_budget', st, tot['triangles'], a.max_tris, {'target': a.target_tris,
        'per_mesh': {n: c['triangles'] for n, c in per_mesh.items()}})
    st = 'info' if a.max_verts is None else ('pass' if tot['vertices'] <= a.max_verts else 'fail')
    add('vertex_budget', st, tot['vertices'], a.max_verts, {'gpu_vertices_estimate': tot['gpu_vertices_estimate'],
        'per_mesh': {n: c['vertices'] for n, c in per_mesh.items()}})

    # binding and modifiers
    extra_mods = {ob.name: [m.type for m in ob.modifiers if m.type != 'ARMATURE'] for ob in meshes}
    extra_mods = {k: v for k, v in extra_mods.items() if v}
    add('modifiers', ('fail' if extra_mods else 'pass') if export else 'info', extra_mods or None, None,
        'apply every modifier except the armature binding on the export copy' if extra_mods and export else None)
    bad_bind = {}
    for ob in meshes:
        ams = [m for m in ob.modifiers if m.type == 'ARMATURE']
        if len(ams) != 1 or ams[0].object != arm:
            bad_bind[ob.name] = [m.object.name if m.object else None for m in ams]
    add('armature_binding', 'fail' if bad_bind else 'pass', bad_bind or None, None,
        'need exactly one Armature modifier targeting %s' % arm.name if bad_bind else None)
    off = [ob.name for ob in meshes
           if max(abs(x - y) for r1, r2 in zip(ob.matrix_world, arm.matrix_world) for x, y in zip(r1, r2)) > 1e-6]
    add('transforms_match', 'warn' if off else 'pass', off or None, None,
        'mesh and armature object matrices differ' if off else None)
    pv = [ob.name for ob in meshes for m in ob.modifiers if m.type == 'ARMATURE' and m.use_deform_preserve_volume]
    add('preserve_volume', 'fail' if pv else 'pass', pv or None, None,
        'Preserve Volume hides the linear-blend collapse a game skin shows' if pv else None)

    # weights
    weights, groups = {}, {}
    for ob in meshes:
        weights[ob.name], groups[ob.name] = read_weights(ob, bone_names)
    all_v = [ent for ob in meshes for ent in weights[ob.name]]
    unweighted = {n: [i for i, e in enumerate(w) if not e][:20] for n, w in weights.items()}
    n_unw = sum(1 for e in all_v if not e)
    add('unweighted', 'fail' if n_unw else 'pass', n_unw, 0, {k: v for k, v in unweighted.items() if v} or None)
    infl = [len(e) for e in all_v if e]
    over = sum(1 for c in infl if c > a.cap)
    add('influence_cap', 'fail' if over else 'pass', max(infl, default=0), a.cap,
        {'vertices_over_cap': over, 'histogram': W.histogram(infl)})
    mean = round(sum(infl) / len(infl), 4) if infl else 0.0
    if a.max_mean_influences is None:
        add('influence_mean', 'info', mean, None)
    else:
        add('influence_mean', 'pass' if mean <= a.max_mean_influences else 'fail', mean, a.max_mean_influences)
    devs = [abs(sum(w for _, w in e) - 1.0) for e in all_v if e]
    dmax = max(devs, default=0.0)
    add('weight_sums', 'pass' if dmax <= a.sum_tol else 'fail', float('%.3g' % dmax), a.sum_tol,
        {'vertices_off': sum(1 for d in devs if d > a.sum_tol)})
    tiny = sum(1 for e in all_v for _, w in e if 0 < w < a.clean_limit)
    zero_members = sum(g['zero_weight_memberships'] for g in groups.values())
    add('clean_limit', 'fail' if tiny else 'pass', tiny, a.clean_limit,
        {'zero_weight_memberships': zero_members} if zero_members else None)
    weighted_bones = sorted({b for e in all_v for b, _ in e})
    if allowed_set is None:
        add('allowed_bones', 'skip', weighted_bones, None, 'no --allowed-bones given')
    else:
        extra = sorted(set(weighted_bones) - allowed_set)
        per_mesh_extra = {}
        for ob in meshes:
            if ob.name in mesh_bones:
                x = sorted({b for e in weights[ob.name] for b, _ in e} - mesh_bones[ob.name])
                if x:
                    per_mesh_extra[ob.name] = x
        detail = {'weighted_bones': weighted_bones}
        if mesh_bones:
            detail['outside_mesh_lists'] = per_mesh_extra or None
        add('allowed_bones', 'fail' if extra or per_mesh_extra else 'pass', extra or per_mesh_extra or None, None,
            detail)
    hyg = {n: {k: g[k] for k in ('non_bone_groups', 'empty_groups') if g[k]} for n, g in groups.items()}
    hyg = {k: v for k, v in hyg.items() if v}
    add('group_hygiene', ('fail' if export else 'warn') if hyg else 'pass', hyg or None, None,
        'delete empty groups and groups that are not bones before export' if hyg else None)
    suff = sorted({n for g in groups.values() for n in g['groups'] if W.side_suffix(n) and n not in bone_names})
    add('side_suffix', 'fail' if suff else 'pass', suff or None, None,
        'restore the exact target bone names after a temporary mirror rename' if suff else None)
    if allowed_set is None:
        add('deform_flags', 'skip', sorted(deform), None, 'no --allowed-bones given')
    else:
        extra = sorted(deform - allowed_set)
        add('deform_flags', 'fail' if extra else 'pass', extra or None, None,
            'turn Deform off on every bone outside the allowed list' if extra else None)
    nd = sorted(set(weighted_bones) - deform)
    add('nondeform_weights', 'fail' if nd else 'pass', nd or None, None,
        'weights on bones with Deform off: invisible in Blender, exported to the game' if nd else None)

    # REF_ objects
    refs = sorted(o.name for o in scope if o.name.startswith(a.ref_prefix))
    if export:
        add('ref_objects', 'fail' if refs else 'pass', refs or None, None,
            'scratch references never go into the export file' if refs else None)
    else:
        add('ref_objects', 'info', refs or None, None, 'working stage: REF_ objects allowed')

    # donor skeleton
    if ref is None:
        add('donor_match', 'skip', None, a.donor_tol, 'no --reference given')
    else:
        cur = armature_snapshot(arm)
        rb = {b['name']: b for b in ref['bones']}
        cb = {b['name']: b for b in cur['bones']}
        problems = []
        missing = sorted(set(rb) - set(cb))
        added = sorted(set(cb) - set(rb))
        if missing:
            problems.append({'missing_bones': missing})
        if added:
            problems.append({'added_bones': added})
        worst = {'head': 0.0, 'tail': 0.0, 'matrix_local': 0.0}
        moved = []
        for n in sorted(set(rb) & set(cb)):
            r, c = rb[n], cb[n]
            if r['parent'] != c['parent']:
                problems.append({'reparented': n, 'was': r['parent'], 'now': c['parent']})
            dh = vec_diff(r['head_local'], c['head_local'])
            dt = vec_diff(r['tail_local'], c['tail_local'])
            dm = mat_diff(r['matrix_local'], c['matrix_local'])
            worst = {'head': max(worst['head'], dh), 'tail': max(worst['tail'], dt),
                     'matrix_local': max(worst['matrix_local'], dm)}
            if max(dh, dt, dm) > a.donor_tol:
                moved.append(n)
        if moved:
            problems.append({'moved_bones': moved[:20], 'count': len(moved)})
        dw = mat_diff(ref['matrix_world'], cur['matrix_world'])
        if dw > a.donor_tol:
            problems.append({'armature_matrix_world_changed': round(dw, 9)})
        order = [b['name'] for b in ref['bones'] if b['name'] in cb] != [b['name'] for b in cur['bones'] if b['name'] in rb]
        st = 'fail' if problems else ('warn' if order else 'pass')
        add('donor_match', st, {k: float('%.3g' % v) for k, v in worst.items()} | {'matrix_world': float('%.3g' % dw)},
            a.donor_tol, problems or ('bone order changed' if order else None), reference=a.reference)

    # mirror names
    scope_names = sorted(allowed_set) if allowed_set is not None else sorted(deform)
    blind, mismatch, no_partner = [], [], []
    for n in scope_names:
        partner, side = W.mirror_name(n)
        if not side:
            continue
        flipped = bpy.utils.flip_name(n)
        if flipped == n:
            blind.append(n)
        elif flipped != partner:
            mismatch.append({'name': n, 'flip_name': flipped, 'partner': partner})
        if partner not in bone_names:
            no_partner.append(n)
    st = 'warn' if (mismatch or no_partner) else 'info'
    add('mirror_names', st, {'flip_name_blind': len(blind)}, None,
        {'flip_name_blind': blind, 'flip_name_mismatch': mismatch, 'partner_missing': no_partner,
         'meaning': 'blind names: Blender mirror tools pair nothing; mirror weights with an explicit map'
         if blind else None})

    # symmetry
    sym_names = [ob.name for ob in meshes] if '*' in a.symmetry else list(a.symmetry)
    if not sym_names:
        add('weight_symmetry', 'skip', None, a.symmetry_weight_tol, 'no --symmetry mesh given')
    else:
        res, fail, unpaired = {}, False, 0
        for n in sym_names:
            ob = bpy.data.objects.get(n)
            if ob is None or ob not in meshes:
                raise SetupError('--symmetry mesh is not an audited mesh: %s' % n)
            res[n] = symmetry(ob, arm, weights[n], bone_names, a.mirror_axis, a.mirror_tol, a.symmetry_weight_tol)
            fail = fail or res[n]['pairs_over_tol'] > 0 or res[n]['pairs'] == 0
            unpaired += res[n]['unpaired_vertices']
        if fail or (unpaired and a.symmetry_unpaired == 'fail'):
            st = 'fail'
        else:
            st = 'warn' if unpaired else 'pass'
        add('weight_symmetry', st, max(r['max_weight_diff'] for r in res.values()), a.symmetry_weight_tol, res,
            axis=a.mirror_axis, mirror_tol=a.mirror_tol, unpaired_vertices=unpaired, unpaired_rule=a.symmetry_unpaired)

    # quantized
    issues, dropped, qerr = 0, 0, 0.0
    first = []
    for n, w in weights.items():
        for i, e in enumerate(w):
            if not e:
                continue
            entries, drop = W.quantize(e)
            probs = W.check_quantized(entries)
            if drop:
                dropped += 1
                probs = probs + ['influence below 0.5/255 dropped: %s' % drop]
            if probs:
                issues += 1
                if len(first) < 10:
                    first.append({'mesh': n, 'vertex': i, 'problems': probs})
            qerr = max(qerr, W.quantization_error(e, entries))
    detail = {'simulated_vertices_with_issues': issues, 'max_quantization_error': round(qerr, 6),
              'first_issues': first or None}
    if quantized is not None:
        fissues, fcount, ffirst = 0, 0, []
        for n, verts in quantized.items():
            for i, entries in enumerate(verts):
                fcount += 1
                probs = W.check_quantized(entries)
                if probs:
                    fissues += 1
                    if len(ffirst) < 10:
                        ffirst.append({'mesh': n, 'vertex': i, 'problems': probs})
        detail.update({'file': a.quantized_json, 'file_vertices': fcount, 'file_vertices_with_issues': fissues,
                       'file_first_issues': ffirst or None})
        issues += fissues
    add('quantized_255', 'fail' if issues else 'pass', issues, 0, detail)

    failed = [c['id'] for c in checks if c['status'] == 'fail']
    report = {'tool': 'organic_audit', 'schema': SCHEMA, 'blender': bpy.app.version_string,
              'date': time.strftime('%Y-%m-%dT%H:%M:%S'), 'file': bpy.data.filepath,
              'file_sha256': sha256(bpy.data.filepath) if bpy.data.filepath else None,
              'stage': a.stage, 'armature': arm.name, 'meshes': [ob.name for ob in meshes],
              'units': {'distances': 'armature-space units', 'weights': '0..1'},
              'thresholds': {'cap': a.cap, 'clean_limit': a.clean_limit, 'sum_tol': a.sum_tol,
                             'max_tris': a.max_tris, 'target_tris': a.target_tris, 'max_verts': a.max_verts,
                             'max_mean_influences': a.max_mean_influences, 'donor_tol': a.donor_tol,
                             'mirror_tol': a.mirror_tol, 'symmetry_weight_tol': a.symmetry_weight_tol,
                             'symmetry_unpaired': a.symmetry_unpaired},
              'allowed_bones': allowed, 'mesh_bones': {k: sorted(v) for k, v in mesh_bones.items()} or None,
              'counts': {'per_mesh': per_mesh, 'total': tot},
              'groups': groups, 'checks': checks, 'failed': failed,
              'result': 'fail' if failed else 'pass', 'exit_code': 1 if failed else 0}
    return report, report['exit_code']


def main_blender(argv):
    try:
        a = parse_args(argv)
    except SystemExit as exc:
        return 2 if exc.code else 0
    report_path = a.report
    if not a.write_reference:
        if report_path is None:
            report_path = str(Path(E.scratch_dir('organic_audit_')) / 'organic_audit.json')
        err = E.refuse_in_worktree(report_path, 'report')
        if err:
            print('SETUP ERROR: ' + err, file=sys.stderr)
            return 2
    try:
        report, code = audit(a)
        if report is not None:
            text = json.dumps(report, indent=1, default=str)
            Path(report_path).parent.mkdir(parents=True, exist_ok=True)
            Path(report_path).write_text(text, encoding='utf-8')
    except SetupError as exc:
        print('SETUP ERROR: %s' % exc, file=sys.stderr)
        return 2
    except Exception as exc:  # last resort: never let a crash read as a pass
        traceback.print_exc()
        print('SETUP ERROR: the audit could not run: %s: %s' % (type(exc).__name__, exc), file=sys.stderr)
        return 2
    if report is None:
        return code
    for c in report['checks']:
        val = json.dumps(c['value'], default=str)
        print('%-5s %-18s %s%s' % (c['status'].upper(), c['id'], val[:100],
                                   '' if c['limit'] is None else '  (limit %s)' % c['limit']))
    print('RESULT %s  report %s' % (report['result'].upper(), report_path))
    return code


if __name__ == '__main__':
    if bpy is None:
        sys.exit(E.relaunch_in_blender(Path(__file__).resolve(), sys.argv[1:]))
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    sys.exit(main_blender(args))
