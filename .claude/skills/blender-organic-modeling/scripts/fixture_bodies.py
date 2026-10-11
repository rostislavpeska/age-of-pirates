"""Synthetic skinned bodies for the organic_audit tests: one clean export copy and one file per seeded defect.

    blender -b --factory-startup --python-exit-code 2 --python fixture_bodies.py -- OUTDIR

Writes OUTDIR/<variant>.blend, OUTDIR/allowed.txt and OUTDIR/fixtures.json (variant -> the checks it must fail).
The body is a Mirror+Skin stick figure (182 vertices, 360 triangles, triangulated) on a Biped-style rig whose names
carry the side marker mid-name (Bip01_L_Thigh), weighted deterministically (inverse distance to the allowed bone
segments, top 3, then the clean / limit / normalize chain), so left and right weights mirror exactly.
Background only; OUTDIR must be outside every git work tree. Exit 0 = written, 2 = refused folder, missing
argument or an exception (also without --python-exit-code).
"""
import json
import math
import os
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import blender_env as E  # noqa: E402

P = {'pelvis': (0, 0, 1.0), 'spine': (0, 0, 1.2), 'chest': (0, 0, 1.38), 'neck': (0, 0, 1.52), 'head': (0, 0, 1.70),
     'clav': (0.17, 0, 1.40), 'shoulder': (0.30, 0, 1.40), 'elbow': (0.55, 0, 1.40), 'wrist': (0.78, 0, 1.40),
     'hip': (0.10, 0, 0.95), 'knee': (0.11, 0, 0.52), 'ankle': (0.12, 0, 0.08)}
RAD = {'pelvis': .13, 'spine': .12, 'chest': .15, 'neck': .05, 'head': .10, 'clav': .06, 'shoulder': .055,
       'elbow': .045, 'wrist': .035, 'hip': .08, 'knee': .06, 'ankle': .045}
EDGES = [('pelvis', 'spine'), ('spine', 'chest'), ('chest', 'neck'), ('neck', 'head'), ('chest', 'clav'),
         ('clav', 'shoulder'), ('shoulder', 'elbow'), ('elbow', 'wrist'), ('pelvis', 'hip'), ('hip', 'knee'),
         ('knee', 'ankle')]
# (bone, head point, tail point, parent, mirrored)
BONES = [('Bip01', (0, 0, 0), (0, 0, 0.5), None, False),
         ('Bip01_Pelvis', 'pelvis', 'spine', 'Bip01', False),
         ('Bip01_Spine', 'spine', 'chest', 'Bip01_Pelvis', False),
         ('Bip01_Neck', 'chest', 'neck', 'Bip01_Spine', False),
         ('Bip01_Head', 'neck', 'head', 'Bip01_Neck', False),
         ('Bip01_%s_Clavicle', 'chest', 'shoulder', 'Bip01_Spine', True),
         ('Bip01_%s_UpperArm', 'shoulder', 'elbow', 'Bip01_%s_Clavicle', True),
         ('Bip01_%s_Forearm', 'elbow', 'wrist', 'Bip01_%s_UpperArm', True),
         ('Bip01_%s_Thigh', 'hip', 'knee', 'Bip01_Pelvis', True),
         ('Bip01_%s_Calf', 'knee', 'ankle', 'Bip01_%s_Thigh', True),
         ('Bip01_Prop1', (-0.78, 0, 1.40), (-0.9, 0, 1.40), 'Bip01_R_Forearm', False)]
# the root, the neck and the prop carry no weight (the neck mirrors a rig whose neck stays unweighted)
NOT_ALLOWED = {'Bip01', 'Bip01_Neck', 'Bip01_Prop1'}


def point(p, side):
    v = Vector(P[p]) if isinstance(p, str) else Vector(p)
    if side == 'R' and isinstance(p, str):
        v.x = -v.x
    return v


def bone_rows():
    rows = []
    for name, h, t, parent, mirrored in BONES:
        for side in (('L', 'R') if mirrored else (None,)):
            n = name % side if side else name
            par = (parent % side if '%s' in parent else parent) if parent else None
            rows.append((n, point(h, side), point(t, side), par))
    return rows


def build_body():
    V, rad, idx = [], [], {}
    for k, p in P.items():
        idx[k] = len(V)
        V.append(p)
        rad.append(RAD[k])
    E_ = [(idx[a], idx[b]) for a, b in EDGES]
    for j, (pa, pb) in (('elbow', ('shoulder', 'wrist')), ('knee', ('hip', 'ankle'))):
        J, A, B = Vector(P[j]), Vector(P[pa]), Vector(P[pb])
        ia = len(V)
        V.append(tuple(J + (A - J).normalized() * 0.04))
        rad.append(RAD[j])
        ib = len(V)
        V.append(tuple(J + (B - J).normalized() * 0.04))
        rad.append(RAD[j])
        E_.remove((idx[pa], idx[j]))
        E_.remove((idx[j], idx[pb]))
        E_ += [(idx[pa], ia), (ia, idx[j]), (idx[j], ib), (ib, idx[pb])]
    me = bpy.data.meshes.new('graph')
    me.from_pydata(V, E_, [])
    ob = bpy.data.objects.new('graph', me)
    bpy.context.collection.objects.link(ob)
    m = ob.modifiers.new('Mirror', 'MIRROR')
    m.use_clip = True
    m.use_mirror_merge = True
    ob.modifiers.new('Skin', 'SKIN')
    for i, d in enumerate(me.skin_vertices[0].data):
        d.radius = (rad[i], rad[i])
    me.skin_vertices[0].data[0].use_root = True
    dg = bpy.context.evaluated_depsgraph_get()
    out = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), depsgraph=dg)
    bpy.data.objects.remove(ob)
    body = bpy.data.objects.new('body', out)
    bpy.context.collection.objects.link(body)
    # exact mirror symmetry: rebuild -X from +X
    activate(body)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.symmetrize(direction='POSITIVE_X', threshold=1e-4)
    bpy.ops.object.mode_set(mode='OBJECT')
    bm = bmesh.new()
    bm.from_mesh(body.data)
    for v in bm.verts:
        if abs(v.co.x) < 1e-6:
            v.co.x = 0.0
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method='FIXED', ngon_method='BEAUTY')
    bm.to_mesh(body.data)
    bm.free()
    return body


def activate(ob):
    for o in list(bpy.context.selected_objects):
        o.select_set(False)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)


def build_rig():
    ad = bpy.data.armatures.new('rig')
    arm = bpy.data.objects.new('rig', ad)
    bpy.context.collection.objects.link(arm)
    activate(arm)
    bpy.ops.object.mode_set(mode='EDIT')
    for n, h, t, par in bone_rows():
        b = ad.edit_bones.new(n)
        b.head, b.tail = h, t
        if par:
            b.parent = ad.edit_bones[par]
    bpy.ops.object.mode_set(mode='OBJECT')
    for b in ad.bones:
        b.use_deform = b.name not in NOT_ALLOWED
    return arm


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
    return (p - (a + ab * t)).length


def weight_body(body, arm):
    allowed = [b for b in arm.data.bones if b.name not in NOT_ALLOWED]
    segs = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in allowed}
    groups = {n: body.vertex_groups.new(name=n) for n in segs}
    for v in body.data.vertices:
        ranked = sorted((max(seg_dist(v.co, *s), 1e-4), n) for n, s in segs.items())
        # the three nearest bones; a left/right tie at the third place is kept or dropped as a pair, so mirrored
        # (and centre) vertices get mirrored weights and Limit Total never has to break a tie
        third = ranked[2][0]
        d = [r for r in ranked if r[0] <= third * (1 + 1e-9)]
        if len(d) > 4:
            d = [r for r in ranked if r[0] < third * (1 - 1e-9)]
        ws = [(n, 1.0 / dist ** 4) for dist, n in d]
        s = sum(w for _, w in ws)
        for n, w in ws:
            groups[n].add([v.index], w / s, 'REPLACE')
    # bind first: the BONE_DEFORM choice of the vertex-group operators exists only on a mesh bound to an armature
    body.parent = arm
    mod = body.modifiers.new('Armature', 'ARMATURE')
    mod.object = arm
    mod.use_deform_preserve_volume = False
    activate(body)
    bpy.ops.object.vertex_group_clean(group_select_mode='BONE_DEFORM', limit=0.02, keep_single=True)
    bpy.ops.object.vertex_group_limit_total(group_select_mode='BONE_DEFORM', limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode='BONE_DEFORM', lock_active=False)


def base_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    arm = build_rig()
    body = build_body()
    weight_body(body, arm)
    return body, arm


def left_vertex(body, min_x=0.2):
    """A vertex on the +X side (arm) with at least two influences, deterministic."""
    for v in body.data.vertices:
        if v.co.x > min_x and len([g for g in v.groups if g.weight > 0]) >= 2:
            return v
    raise RuntimeError('no two-influence vertex on the arm')


def set_weights(body, v, pairs):
    for g in list(v.groups):
        body.vertex_groups[g.group].remove([v.index])
    for n, w in pairs:
        grp = body.vertex_groups.get(n) or body.vertex_groups.new(name=n)
        grp.add([v.index], w, 'REPLACE')


def variants():
    """name -> (edit function, checks it must fail). The clean file must fail none."""
    def ngon(body, arm):
        bm = bmesh.new()
        bm.from_mesh(body.data)
        vs = [bm.verts.new((0.05 + 0.02 * math.cos(2 * math.pi * k / 5), 0.3, 1.0 + 0.02 * math.sin(2 * math.pi * k / 5)))
              for k in range(5)]
        bm.faces.new(vs)
        bm.to_mesh(body.data)
        bm.free()
        g = body.vertex_groups['Bip01_Pelvis']
        g.add([v.index for v in body.data.vertices][-5:], 1.0, 'REPLACE')

    def quads(body, arm):
        bm = bmesh.new()
        bm.from_mesh(body.data)
        bmesh.ops.join_triangles(bm, faces=bm.faces[:], angle_face_threshold=math.radians(40),
                                 angle_shape_threshold=math.radians(40))
        bm.to_mesh(body.data)
        bm.free()

    def five_influences(body, arm):
        v = left_vertex(body)
        set_weights(body, v, [(n, 0.2) for n in ('Bip01_Pelvis', 'Bip01_Spine', 'Bip01_Head', 'Bip01_L_Clavicle',
                                                 'Bip01_L_UpperArm')])

    def unnormalized(body, arm):
        v = left_vertex(body)
        set_weights(body, v, [(body.vertex_groups[g.group].name, g.weight * 0.9) for g in v.groups])

    def tiny_weight(body, arm):
        v = left_vertex(body)
        set_weights(body, v, [('Bip01_L_UpperArm', 0.99), ('Bip01_L_Forearm', 0.01)])

    def neck_weight(body, arm):
        g = body.vertex_groups.new(name='Bip01_Neck')
        for v in body.data.vertices:
            if 1.45 < v.co.z < 1.6:
                for gg in list(v.groups):
                    body.vertex_groups[gg.group].remove([v.index])
                g.add([v.index], 1.0, 'REPLACE')

    def deform_flag(body, arm):
        arm.data.bones['Bip01_Prop1'].use_deform = True

    def ref_object(body, arm):
        me = bpy.data.meshes.new('REF_overlay')
        me.from_pydata([(0, 0, 0), (0.1, 0, 0), (0, 0.1, 0)], [], [(0, 1, 2)])
        bpy.context.collection.objects.link(bpy.data.objects.new('REF_overlay', me))

    def preserve_volume(body, arm):
        body.modifiers['Armature'].use_deform_preserve_volume = True

    def bone_moved(body, arm):
        activate(arm)
        bpy.ops.object.mode_set(mode='EDIT')
        arm.data.edit_bones['Bip01_L_Forearm'].head.z += 0.01
        bpy.ops.object.mode_set(mode='OBJECT')

    def armature_moved(body, arm):
        arm.location.x += 0.1

    def asymmetric(body, arm):
        v = left_vertex(body)
        ws = sorted(((body.vertex_groups[g.group].name, g.weight) for g in v.groups if g.weight > 0),
                    key=lambda t: -t[1])
        (a, wa), (b, wb) = ws[0], ws[1]
        shift = min(0.1, wa - 0.05)
        set_weights(body, v, [(a, wa - shift), (b, wb + shift)] + ws[2:])

    def side_suffix(body, arm):
        body.vertex_groups['Bip01_L_Thigh'].name = 'Thigh.L'

    def empty_group(body, arm):
        body.vertex_groups.new(name='Bip01_Prop1')

    def helper_group(body, arm):
        g = body.vertex_groups.new(name='cloth_mask')
        g.add([v.index for v in body.data.vertices][:10], 1.0, 'REPLACE')

    def unweighted(body, arm):
        v = left_vertex(body)
        set_weights(body, v, [])

    def unbound(body, arm):
        body.modifiers.remove(body.modifiers['Armature'])

    def unpaired(body, arm):
        # three +X arm vertices moved 0.01 in Y: they and their -X partners lose their mirror partner (6 unpaired)
        moved = [v for v in body.data.vertices if v.co.x > 0.2][:3]
        for v in moved:
            v.co.y += 0.01

    return {
        'clean': (None, []),
        'ngon': (ngon, ['ngons']),
        'quads': (quads, ['triangulated']),
        'five_influences': (five_influences, ['influence_cap']),
        'unnormalized': (unnormalized, ['weight_sums']),
        'tiny_weight': (tiny_weight, ['clean_limit']),
        'neck_weight': (neck_weight, ['allowed_bones', 'nondeform_weights']),
        'deform_flag': (deform_flag, ['deform_flags']),
        'ref_object': (ref_object, ['ref_objects']),
        'preserve_volume': (preserve_volume, ['preserve_volume']),
        'bone_moved': (bone_moved, ['donor_match']),
        'armature_moved': (armature_moved, ['donor_match']),
        'asymmetric': (asymmetric, ['weight_symmetry']),
        'side_suffix': (side_suffix, None),       # several checks; the test names the ones that must fail
        'empty_group': (empty_group, ['group_hygiene']),
        'helper_group': (helper_group, ['group_hygiene']),
        'unweighted': (unweighted, ['unweighted']),
        'unbound': (unbound, ['armature_binding']),
        'unpaired': (unpaired, ['weight_symmetry']),
    }


def main(out):
    err = E.refuse_in_worktree(out, 'fixture folder')
    if err:
        print(err, file=sys.stderr)
        return 2
    os.makedirs(out, exist_ok=True)
    manifest = {}
    for name, (fn, fails) in variants().items():
        body, arm = base_scene()
        if fn:
            fn(body, arm)
        bpy.context.view_layer.update()
        path = os.path.join(out, name + '.blend')
        bpy.ops.wm.save_as_mainfile(filepath=path)
        manifest[name] = {'file': path, 'must_fail': fails}
        if name == 'clean':
            allowed = [b.name for b in arm.data.bones if b.name not in NOT_ALLOWED]
            Path(out, 'allowed.txt').write_text('# bones that may carry weight\n' + '\n'.join(allowed) + '\n',
                                                encoding='utf-8')
            manifest['_body'] = {'vertices': len(body.data.vertices),
                                 'triangles': sum(len(p.vertices) - 2 for p in body.data.polygons),
                                 'allowed': allowed}
    Path(out, 'fixtures.json').write_text(json.dumps(manifest, indent=1), encoding='utf-8')
    print('FIXTURES', len(manifest) - 1, out)
    return 0


if __name__ == '__main__':
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    if len(argv) != 1:
        print('usage: blender -b --factory-startup --python-exit-code 2 --python fixture_bodies.py -- OUTDIR',
              file=sys.stderr)
        sys.exit(2)
    try:
        code = main(argv[0])
    except Exception:  # never exit 0 on a half-written fixture set
        import traceback
        traceback.print_exc()
        code = 2
    sys.exit(code)
