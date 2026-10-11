#!/usr/bin/env python
"""Reproduce the local Blender probes behind the skill's measured claims (sources.md keys L1-L16), in background.

    python organic_probe.py [--out SCRATCH_DIR] [--only skin,rings,...] [--list]   # relaunches in background Blender
    python organic_probe.py --blender-exe EXE ...              # or --local-config FILE (tools.blender.path)
    blender -b --factory-startup --python-exit-code 2 --python organic_probe.py -- [--out SCRATCH_DIR] [--only ...]

Every experiment builds synthetic geometry (Skin-modifier stick figures, a fixed game-like skeleton, an 8-sided
limb cage); nothing is read from a project. Results go to OUT/probe.json (keys per experiment plus `_lkeys`, the
sources key each experiment reproduces) with the .blend files and silhouette PNGs it saves. OUT defaults to a new
folder in the system temp directory; a folder inside a git work tree is refused. Experiments that need an earlier
one's saved file pull it in automatically. Numbers were first measured on Blender 5.1.2 (2026-10-10).
Exit 0 = every experiment ran, 1 = at least one experiment raised (traceback in probe.json `errors`), 2 = setup
error or the probe could not run (bad argument, refused folder, no Blender, unexpected exception outside an
experiment).

Experiment -> key: flip_name L1, operator_defaults L8, bone_deform_enum L16, skin L2 L9, autoweight_pitfalls L2,
shell_transfer L3 L4, remesh_decimate L6 L7, vertex_split L5, curves (strap counts), silhouette L10,
proportional L13, rings L2 L11 L15, shell_poke L4, unnormalized L2, skin_edge_rings (Skin ring spacing),
shrinkwrap L12 L14.
"""
import argparse
import json
import math
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
    import bmesh
    import bpy
    from mathutils import Matrix, Vector
    from mathutils.bvhtree import BVHTree
except ImportError:  # host Python: relaunch in Blender
    bpy = None
if bpy is not None and not hasattr(bpy, 'app'):  # a stub or namespace 'bpy' on the host is not Blender
    bpy = None

OUT = None
R = {}


def log(k, v):
    R[k] = v
    print('PROBE', k, json.dumps(v, default=str)[:600])


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def select_only(*obs, active=None):
    for o in list(bpy.context.selected_objects):
        o.select_set(False)
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or obs[0]


# ================================================================ shared geometry helpers (first probe)


def stick_mesh(name, elbow_loops=False, knee_loops=False):
    """Half (x>=0) stick figure for Mirror + Skin. Optional extra vertices around elbow/knee."""
    V = [(0, 0, 1.0), (0, 0, 1.2), (0, 0, 1.38), (0, 0, 1.52), (0, 0, 1.70),
         (0.17, 0, 1.40), (0.30, 0, 1.40), (0.55, 0, 1.40), (0.78, 0, 1.40),
         (0.10, 0, 0.95), (0.11, 0, 0.52), (0.12, 0, 0.08)]
    E_ = [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5), (5, 6), (6, 7), (7, 8), (0, 9), (9, 10), (10, 11)]
    if elbow_loops:
        a = len(V)
        V += [(0.51, 0, 1.40), (0.59, 0, 1.40)]
        E_.remove((6, 7))
        E_.remove((7, 8))
        E_ += [(6, a), (a, 7), (7, a + 1), (a + 1, 8)]
    if knee_loops:
        a = len(V)
        V += [(0.105, 0, 0.57), (0.115, 0, 0.47)]
        E_.remove((9, 10))
        E_.remove((10, 11))
        E_ += [(9, a), (a, 10), (10, a + 1), (a + 1, 11)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(V, E_, [])
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    m = ob.modifiers.new('Mirror', 'MIRROR')
    m.use_clip = True
    m.use_mirror_merge = True
    s = ob.modifiers.new('Skin', 'SKIN')
    s.use_smooth_shade = True
    sv = me.skin_vertices[0].data
    rad = {0: .13, 1: .12, 2: .15, 3: .05, 4: .10, 5: .06, 6: .055, 7: .045, 8: .035, 9: .08, 10: .06, 11: .045}
    for i, d in enumerate(sv):
        r = rad.get(i)
        if r is None:
            r = .045 if V[i][2] > 1.0 else .06
        d.radius = (r, r)
    sv[0].use_root = True
    return ob


def counts(me):
    me.calc_loop_triangles()
    return {'verts': len(me.vertices), 'faces': len(me.polygons),
            'quads': sum(1 for p in me.polygons if len(p.vertices) == 4),
            'tris': sum(1 for p in me.polygons if len(p.vertices) == 3),
            'ngons': sum(1 for p in me.polygons if len(p.vertices) > 4),
            'triangles': len(me.loop_triangles), 'uv_layers': len(me.uv_layers)}


def evaluated_copy(ob, name):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    o2 = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o2)
    return o2


def manifold(me):
    bm = bmesh.new()
    bm.from_mesh(me)
    r = {'non_manifold_edges': sum(1 for e in bm.edges if not e.is_manifold),
         'boundary_edges': sum(1 for e in bm.edges if e.is_boundary),
         'non_contiguous_edges': sum(1 for e in bm.edges if e.is_manifold and not e.is_contiguous),
         'wire_edges': sum(1 for e in bm.edges if e.is_wire),
         'non_manifold_verts': sum(1 for v in bm.verts if not v.is_manifold),
         'loose_verts': sum(1 for v in bm.verts if not v.link_edges),
         'zero_area_faces': sum(1 for f in bm.faces if f.calc_area() < 1e-10)}
    bm.free()
    return r


def self_intersections(verts, tris):
    """Triangle pairs that overlap and share no vertex (true self-intersections)."""
    t = BVHTree.FromPolygons(verts, tris, all_triangles=True)
    return sum(1 for a, b in t.overlap(t) if a < b and not (set(tris[a]) & set(tris[b])))


def mesh_tris(me, mat=None):
    me.calc_loop_triangles()
    vs = [(mat @ v.co) if mat else v.co.copy() for v in me.vertices]
    return vs, [tuple(lt.vertices) for lt in me.loop_triangles]


def signed_volume(vs, ts):
    return sum(vs[a].dot(vs[b].cross(vs[c])) for a, b, c in ts) / 6.0


def min_angle_deg(vs, ts):
    worst = 180
    for a, b, c in ts:
        for p, q, r in ((a, b, c), (b, c, a), (c, a, b)):
            u = vs[q] - vs[p]
            w = vs[r] - vs[p]
            if u.length < 1e-12 or w.length < 1e-12:
                return 0.0
            worst = min(worst, math.degrees(u.angle(w)))
    return worst


def gpu_vertex_count(me):
    """Unique (vertex, uv, corner normal) per corner = what a game vertex buffer holds."""
    uv = me.uv_layers.active.uv if me.uv_layers else None
    cn = me.corner_normals
    keys = set()
    for li, lp in enumerate(me.loops):
        keys.add((lp.vertex_index, tuple(round(c, 5) for c in uv[li].vector) if uv else None,
                  tuple(round(c, 4) for c in cn[li].vector)))
    return len(keys)


def weight_report(ob, arm, max_inf=4):
    names = {g.index: g.name for g in ob.vertex_groups}
    deform = {b.name for b in arm.data.bones if b.use_deform}
    unweighted = over = 0
    sums, dom, maxinf = [], {}, 0
    for v in ob.data.vertices:
        ws = [(names[g.group], g.weight) for g in v.groups if names[g.group] in deform and g.weight > 0]
        maxinf = max(maxinf, len(ws))
        if not ws:
            unweighted += 1
            continue
        over += len(ws) > max_inf
        sums.append(sum(w for _, w in ws))
        dom[v.index] = max(ws, key=lambda x: x[1])[0]
    M = arm.matrix_world
    seg = {b.name: (M @ b.head_local, M @ b.tail_local) for b in arm.data.bones}

    def dseg(p, a, b):
        ab = b - a
        t = max(0, min(1, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
        return (p - (a + ab * t)).length
    per = {}
    Wm = ob.matrix_world
    for vi, bn in dom.items():
        per.setdefault(bn, []).append((vi, dseg(Wm @ ob.data.vertices[vi].co, *seg[bn])))
    distant = 0
    for bn, lst in per.items():
        ds = sorted(d for _, d in lst)
        med = ds[len(ds) // 2]
        distant += sum(1 for _, d in lst if d > 3.0 * max(med, 1e-6))
    return {'unweighted': unweighted, 'over_%d' % max_inf: over, 'max_influences': maxinf,
            'sum_dev_max': round(max((abs(s - 1) for s in sums), default=0), 4),
            'distant_dominant': distant, 'deform_bones_without_dominant_verts': len(deform - set(dom.values()))}


def joint_rings(ob, arm, bone, child, frac=0.35):
    """Distinct vertex rings (clusters along the parent bone axis) within +-frac*min(len) of the joint."""
    b = arm.data.bones[bone]
    c = arm.data.bones[child]
    M = arm.matrix_world
    j = M @ b.tail_local
    ax = (M @ b.tail_local - M @ b.head_local).normalized()
    w = frac * min(b.length, c.length) * M.to_scale()[0]
    gi = {ob.vertex_groups[bone].index if bone in ob.vertex_groups else -1,
          ob.vertex_groups[child].index if child in ob.vertex_groups else -2}
    ts = []
    for v in ob.data.vertices:
        if not any(g.group in gi and g.weight > 0.01 for g in v.groups):
            continue
        p = ob.matrix_world @ v.co
        t = (p - j).dot(ax)
        if abs(t) <= w and ((p - j) - ax * t).length < 3 * w + 0.2:
            ts.append(t)
    ts.sort()
    rings, last = 0, None
    for t in ts:
        if last is None or t - last > 0.08 * w:
            rings += 1
        last = t
    return rings


def pose_metrics(ob_rest, ob_posed_eval_mesh, mat):
    vs0, ts = mesh_tris(ob_rest.data, mat)
    vs1, _ = mesh_tris(ob_posed_eval_mesh, mat)
    elen = []
    for e in ob_rest.data.edges:
        a, b = e.vertices
        l0 = (vs0[a] - vs0[b]).length
        if l0 > 1e-9:
            elen.append((vs1[a] - vs1[b]).length / l0)
    arear = []
    for a, b, c in ts:
        n0 = (vs0[b] - vs0[a]).cross(vs0[c] - vs0[a])
        n1 = (vs1[b] - vs1[a]).cross(vs1[c] - vs1[a])
        if n0.length > 1e-12:
            arear.append(n1.length / n0.length)
    return {'edge_ratio_min': round(min(elen), 3), 'edge_ratio_max': round(max(elen), 3),
            'tri_area_ratio_min': round(min(arear), 3),
            'volume_ratio': round(signed_volume(vs1, ts) / signed_volume(vs0, ts), 4),
            'self_intersections_posed': self_intersections(vs1, ts),
            'self_intersections_rest': self_intersections(vs0, ts)}


# ================================================================ L1, L8, bone_deform_enum


def exp_flip_name():
    names = ['Bip01_L_Thigh', 'Bip01 L Thigh', 'Bip01_R_Calf', 'Bip01_L_UpperArm', 'L_Thigh', 'Thigh_L', 'Thigh.L']
    out = {}
    for n in names:
        flipped = bpy.utils.flip_name(n)
        out[n] = {'flip_name': flipped, 'unchanged': flipped == n, 'explicit_partner': W.mirror_name(n)[0]}
    log('L1_flip_name', out)


def exp_operator_defaults():
    def props(op, keys):
        rna = op.get_rna_type()
        return {k: getattr(rna.properties[k], 'default', None) for k in keys if k in rna.properties}
    log('L8_operator_defaults', {
        'uv.unwrap': props(bpy.ops.uv.unwrap, ['method']),
        'object.vertex_group_clean': props(bpy.ops.object.vertex_group_clean,
                                           ['group_select_mode', 'limit', 'keep_single']),
        'object.vertex_group_limit_total': props(bpy.ops.object.vertex_group_limit_total,
                                                 ['group_select_mode', 'limit']),
        'object.vertex_group_normalize_all': props(bpy.ops.object.vertex_group_normalize_all,
                                                   ['group_select_mode', 'lock_active'])})


def exp_bone_deform_enum():
    """The BONE_DEFORM choice of the vertex-group operators exists only once the mesh is bound to an armature."""
    reset()
    bpy.ops.mesh.primitive_cube_add(size=0.2)
    ob = bpy.context.active_object
    ad = bpy.data.armatures.new('a')
    arm = bpy.data.objects.new('a', ad)
    bpy.context.collection.objects.link(arm)
    select_only(arm)
    bpy.ops.object.mode_set(mode='EDIT')
    e = ad.edit_bones.new('A')
    e.head, e.tail = (0, 0, 0), (0, 0, 1)
    bpy.ops.object.mode_set(mode='OBJECT')
    ob.vertex_groups.new(name='A').add(list(range(8)), 0.5, 'REPLACE')
    select_only(ob)
    out = {}

    def attempt(call):
        try:
            return list(call())
        except TypeError as exc:
            return 'TypeError: ' + str(exc)[:200]

    def chain():  # the hygiene chain of skinning-pose-tests section 2, on the active object
        return {'clean': attempt(lambda: bpy.ops.object.vertex_group_clean(
                    group_select_mode='BONE_DEFORM', limit=0.02, keep_single=True)),
                'limit_total': attempt(lambda: bpy.ops.object.vertex_group_limit_total(
                    group_select_mode='BONE_DEFORM', limit=4)),
                'normalize_all': attempt(lambda: bpy.ops.object.vertex_group_normalize_all(
                    group_select_mode='BONE_DEFORM', lock_active=False))}

    r = attempt(lambda: bpy.ops.object.vertex_group_normalize_all(group_select_mode='BONE_DEFORM', lock_active=False))
    out['unbound'] = 'accepted' if isinstance(r, list) else r
    out['unbound_limit_total'] = attempt(lambda: bpy.ops.object.vertex_group_limit_total(
        group_select_mode='BONE_DEFORM', limit=4))
    ob.modifiers.new('Arm', 'ARMATURE').object = arm
    out['bound'] = attempt(lambda: bpy.ops.object.vertex_group_normalize_all(
        group_select_mode='BONE_DEFORM', lock_active=False))
    out['weight_after'] = round(ob.data.vertices[0].groups[0].weight, 4)
    out['bound_chain'] = chain()
    # the other binding: parent with empty groups (adds the Armature modifier, keeps the weights)
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=(0.5, 0, 0))
    ob2 = bpy.context.active_object
    ob2.vertex_groups.new(name='A').add(list(range(8)), 0.5, 'REPLACE')
    select_only(ob2, arm, active=arm)
    bpy.ops.object.parent_set(type='ARMATURE_NAME')
    select_only(ob2)
    out['parent_empty_groups_modifiers'] = [m.type for m in ob2.modifiers]
    out['parent_empty_groups_chain'] = chain()
    log('bone_deform_enum', out)


# ================================================================ first probe: Skin figure, weights, shells, remesh


def exp_skin():
    for variant in ('plain', 'joint_loops'):
        reset()
        ob = stick_mesh('fig', elbow_loops=(variant == 'joint_loops'), knee_loops=(variant == 'joint_loops'))
        ev = evaluated_copy(ob, 'fig_eval')
        c = counts(ev.data)
        c.update(manifold(ev.data))
        vs, ts = mesh_tris(ev.data)
        c['self_intersections'] = self_intersections(vs, ts)
        log('A_skin_%s' % variant, c)
        ob.modifiers.new('Sub', 'SUBSURF').levels = 1
        ev2 = evaluated_copy(ob, 'fig_eval_sub')
        c2 = counts(ev2.data)
        vs, ts = mesh_tris(ev2.data)
        c2['self_intersections'] = self_intersections(vs, ts)
        log('A_skin_sub1_%s' % variant, c2)
        ob.modifiers.remove(ob.modifiers['Sub'])
        bpy.data.objects.remove(ev2)
        select_only(ob)
        r = bpy.ops.object.skin_armature_create(modifier='Skin')
        arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
        log('B_skin_armature_%s' % variant, {'op': list(r), 'bones': len(arm.data.bones),
                                             'modifier_order': [m.type for m in ob.modifiers],
                                             'vertex_groups_on_input': len(ob.vertex_groups)})
        ev.vertex_groups.clear()
        select_only(ev, arm, active=arm)
        r = bpy.ops.object.parent_set(type='ARMATURE_AUTO')
        wr = weight_report(ev, arm)
        wr['op'] = list(r)
        log('C_autoweights_%s' % variant, wr)

        def bone_at(x, z, tail=True):
            best = None
            for b in arm.data.bones:
                p = arm.matrix_world @ (b.tail_local if tail else b.head_local)
                d = (p - Vector((x, 0, z))).length
                if best is None or d < best[0]:
                    best = (d, b.name)
            return best[1]
        up, lo = bone_at(0.55, 1.40, tail=True), bone_at(0.55, 1.40, tail=False)
        thigh, shin = bone_at(0.11, 0.52, tail=True), bone_at(0.11, 0.52, tail=False)
        log('C_joint_rings_%s' % variant, {'elbow_rings': joint_rings(ev, arm, up, lo),
                                           'knee_rings': joint_rings(ev, arm, thigh, shin),
                                           'elbow_bones': [up, lo], 'knee_bones': [thigh, shin]})
        res = {}
        for label, bname in (('elbow', lo), ('knee', shin)):
            for pb in arm.pose.bones:
                pb.rotation_mode = 'XYZ'
                pb.rotation_euler = (0, 0, 0)
            pb = arm.pose.bones[bname]
            pb.rotation_euler = (math.radians(100), 0, 0)
            for m in ev.modifiers:
                if m.type == 'ARMATURE':
                    m.use_deform_preserve_volume = False
            bpy.context.view_layer.update()
            dg = bpy.context.evaluated_depsgraph_get()
            pm = bpy.data.meshes.new_from_object(ev.evaluated_get(dg), depsgraph=dg)
            arm.data.pose_position = 'REST'
            bpy.context.view_layer.update()
            dg = bpy.context.evaluated_depsgraph_get()
            rm = bpy.data.meshes.new_from_object(ev.evaluated_get(dg), depsgraph=dg)
            arm.data.pose_position = 'POSE'
            tmp = bpy.data.objects.new('rest_tmp', rm)
            res[label] = pose_metrics(tmp, pm, ev.matrix_world)
            pb.rotation_euler = (0, 0, 0)
        log('D_pose_%s' % variant, res)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'skin_%s.blend' % variant))


def exp_autoweight_pitfalls():
    out = {}
    for case in ('scale_1', 'scale_0.008', 'scale_0.008_applied_x100', 'loose_plume'):
        reset()
        ob = stick_mesh('fig', elbow_loops=True, knee_loops=True)
        bpy.ops.object.skin_armature_create(modifier='Skin')
        arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
        ev = evaluated_copy(ob, 'body')
        ev.vertex_groups.clear()
        bpy.data.objects.remove(ob)
        if case == 'loose_plume':
            bm = bmesh.new()
            bm.from_mesh(ev.data)
            bmesh.ops.create_cube(bm, size=0.06, matrix=Matrix.Translation((0, 0, 1.95)))
            bm.to_mesh(ev.data)
            bm.free()
        if case.startswith('scale_0.008'):
            for o in (ev, arm):
                o.scale = (0.008, 0.008, 0.008)
            bpy.context.view_layer.update()
            select_only(ev, arm, active=arm)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            if case.endswith('x100'):
                for o in (ev, arm):
                    o.scale = (100, 100, 100)
                bpy.context.view_layer.update()
                bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        select_only(ev, arm, active=arm)
        r = bpy.ops.object.parent_set(type='ARMATURE_AUTO')
        wr = weight_report(ev, arm)
        wr['op'] = list(r)
        wr['dims'] = [round(x, 4) for x in ev.dimensions]
        out[case] = wr
    log('C2_autoweight_pitfalls', out)


def exp_shell_transfer():
    reset()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT, 'skin_joint_loops.blend'))
    ev = bpy.data.objects['fig_eval']
    arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
    me = ev.data.copy()
    sh = bpy.data.objects.new('robe', me)
    bpy.context.collection.objects.link(sh)
    sh.modifiers.clear()
    sh.vertex_groups.clear()
    bm = bmesh.new()
    bm.from_mesh(me)
    kill = [f for f in bm.faces if not all(0.9 < v.co.z < 1.45 and abs(v.co.x) < 0.2 for v in f.verts)]
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    bm.to_mesh(me)
    bm.free()
    so = sh.modifiers.new('Solid', 'SOLIDIFY')
    so.thickness = 0.015
    so.offset = 1.0
    out = {'shell_counts_before_solidify': counts(me)}
    dt = sh.modifiers.new('DT', 'DATA_TRANSFER')
    dt.object = ev
    dt.use_vert_data = True
    dt.data_types_verts = {'VGROUP_WEIGHTS'}
    dt.vert_mapping = 'POLYINTERP_NEAREST'
    select_only(sh)
    bpy.ops.object.datalayout_transfer(modifier='DT')
    for name in ('Solid', 'DT'):
        bpy.ops.object.modifier_apply(modifier=name)
    out['weights_after_transfer'] = weight_report(sh, arm, 4)
    bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=2)
    out['after_limit2_no_normalize'] = weight_report(sh, arm, 2)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
    out['after_limit2_normalize'] = weight_report(sh, arm, 2)
    sh.modifiers.new('Arm', 'ARMATURE').object = arm
    chest, best = None, 9
    for b in arm.data.bones:
        d = (arm.matrix_world @ b.head_local - Vector((0, 0, 1.2))).length
        if d < best:
            best, chest = d, b.name
    res = {}
    for ang in (0, 35):
        for pb in arm.pose.bones:
            pb.rotation_mode = 'XYZ'
            pb.rotation_euler = (0, 0, 0)
        arm.pose.bones[chest].rotation_euler = (math.radians(ang), 0, 0)
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        bme = bpy.data.meshes.new_from_object(ev.evaluated_get(dg), depsgraph=dg)
        sme = bpy.data.meshes.new_from_object(sh.evaluated_get(dg), depsgraph=dg)
        vb, tb = mesh_tris(bme)
        vsh, tsh = mesh_tris(sme)
        tB = BVHTree.FromPolygons(vb, tb, all_triangles=True)
        tS = BVHTree.FromPolygons(vsh, tsh, all_triangles=True)
        res['bend_%d' % ang] = len(tS.overlap(tB))
    out['shell_body_intersections'] = res
    out['chest_bone'] = chest
    log('E_shell_transfer', out)


def exp_remesh_decimate():
    reset()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT, 'skin_joint_loops.blend'))
    ev = bpy.data.objects['fig_eval']
    base = counts(ev.data)
    q = ev.copy()
    q.data = ev.data.copy()
    bpy.context.collection.objects.link(q)
    q.modifiers.clear()
    q.parent = None
    select_only(q)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project()
    bpy.ops.object.mode_set(mode='OBJECT')
    before = {'vgroups': len(q.vertex_groups), 'uv': len(q.data.uv_layers), 'faces': len(q.data.polygons),
              'weighted_verts': sum(1 for v in q.data.vertices if v.groups)}
    r = bpy.ops.object.quadriflow_remesh(mode='FACES', target_faces=600, use_mesh_symmetry=False, seed=0)
    after = counts(q.data)
    after['vgroups'] = len(q.vertex_groups)
    after['weighted_verts'] = sum(1 for v in q.data.vertices if v.groups)
    after['op'] = list(r)
    after.update(manifold(q.data))
    log('F_quadriflow_manifold', {'before': before, 'after': after})
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, end_fill_type='NOTHING')
    cyl = bpy.context.active_object
    try:
        r = bpy.ops.object.quadriflow_remesh(mode='FACES', target_faces=200)
        log('F_quadriflow_open_tube', {'op': list(r), 'faces_after': len(cyl.data.polygons)})
    except Exception as e:
        log('F_quadriflow_open_tube', {'exception': str(e)[:400]})
    d = ev.copy()
    d.data = ev.data.copy()
    bpy.context.collection.objects.link(d)
    d.modifiers.clear()
    d.parent = None
    d.modifiers.new('Sub', 'SUBSURF').levels = 1
    hi = evaluated_copy(d, 'hi')
    d.modifiers.clear()
    vs, ts = mesh_tris(hi.data)
    hic = counts(hi.data)
    hic['min_angle'] = round(min_angle_deg(vs, ts), 2)
    hi.modifiers.new('Dec', 'DECIMATE').ratio = 0.5
    lo = evaluated_copy(hi, 'lo')
    vs, ts = mesh_tris(lo.data)
    loc = counts(lo.data)
    loc['min_angle'] = round(min_angle_deg(vs, ts), 2)
    loc['weighted_verts'] = sum(1 for v in lo.data.vertices if v.groups)
    loc['vgroups'] = len(lo.vertex_groups)
    hi.modifiers.clear()
    un = hi.modifiers.new('Un', 'DECIMATE')
    un.decimate_type = 'UNSUBDIV'
    un.iterations = 2
    uns = evaluated_copy(hi, 'uns')
    log('G_decimate', {'base_lowpoly': base, 'subdiv1': hic, 'collapse_0.5': loc, 'unsubdiv_2': counts(uns.data)})


def exp_vertex_split():
    reset()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT, 'skin_joint_loops.blend'))
    ev = bpy.data.objects['fig_eval']
    o = ev.copy()
    o.data = ev.data.copy()
    bpy.context.collection.objects.link(o)
    o.modifiers.clear()
    o.parent = None
    select_only(o)
    res = {'verts': len(o.data.vertices)}
    bpy.ops.object.shade_smooth()
    res['smooth_no_uv'] = gpu_vertex_count(o.data)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66))
    bpy.ops.object.mode_set(mode='OBJECT')
    res['smooth_smartuv66'] = gpu_vertex_count(o.data)
    bpy.ops.object.shade_flat()
    res['flat_smartuv66'] = gpu_vertex_count(o.data)
    res['triangles'] = counts(o.data)['triangles']
    log('H_vertex_split', res)


def exp_curves():
    reset()
    res = {}
    for bres in (0, 1, 2):
        for ures in (1, 2, 4):
            cu = bpy.data.curves.new('c', 'CURVE')
            cu.dimensions = '3D'
            sp = cu.splines.new('BEZIER')
            sp.bezier_points.add(2)
            for i, p in enumerate(sp.bezier_points):
                p.co = (i * 0.2, 0.05 * (i % 2), 0)
                p.handle_left_type = p.handle_right_type = 'AUTO'
            cu.bevel_mode = 'ROUND'
            cu.bevel_depth = 0.01
            cu.bevel_resolution = bres
            cu.resolution_u = ures
            cu.use_fill_caps = False
            ob = bpy.data.objects.new('c', cu)
            bpy.context.collection.objects.link(ob)
            dg = bpy.context.evaluated_depsgraph_get()
            me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), depsgraph=dg)
            res['bevel_res%d_u%d' % (bres, ures)] = {'verts': len(me.vertices), 'faces': len(me.polygons)}
            bpy.data.objects.remove(ob)
    cu = bpy.data.curves.new('s', 'CURVE')
    cu.dimensions = '3D'
    sp = cu.splines.new('POLY')
    sp.points.add(3)
    for i, p in enumerate(sp.points):
        p.co = (i * 0.1, 0, 0.02 * (i % 2), 1)
    cu.extrude = 0.02
    cu.bevel_depth = 0
    ob = bpy.data.objects.new('s', cu)
    bpy.context.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), depsgraph=dg)
    res['poly_ribbon_4pts'] = {'verts': len(me.vertices), 'faces': len(me.polygons),
                               'non_manifold': manifold(me)['boundary_edges']}
    log('I_curves', res)


def exp_silhouette():
    reset()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT, 'skin_joint_loops.blend'))
    sc = bpy.context.scene
    for o in list(bpy.data.objects):
        if o.name != 'fig_eval' and o.type != 'ARMATURE':
            bpy.data.objects.remove(o)
    sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading
    sh.light = 'FLAT'
    sh.color_type = 'SINGLE'
    sh.single_color = (0, 0, 0)
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = 128
    sc.render.resolution_percentage = 100
    cam_d = bpy.data.cameras.new('cam')
    cam_d.type = 'ORTHO'
    cam_d.ortho_scale = 2.2
    cam = bpy.data.objects.new('cam', cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    res = {}
    for view, (loc, rot) in {'front': ((0, -5, 0.95), (math.radians(90), 0, 0)),
                             'rts45': ((0, -3.6, 4.55), (math.radians(38), 0, 0))}.items():
        cam.location = loc
        cam.rotation_euler = rot
        p = os.path.join(OUT, 'sil_%s.png' % view)
        sc.render.filepath = p
        t = time.time()
        bpy.ops.render.render(write_still=True)
        dt = time.time() - t
        img = bpy.data.images.load(p)
        px = list(img.pixels)
        cov = sum(1 for i in range(3, len(px), 4) if px[i] > 0.5) / (len(px) / 4)
        res[view] = {'coverage': round(cov, 4), 'seconds': round(dt, 2), 'file': p}
    log('J_silhouette', res)


def exp_proportional():
    reset()
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=10, y_subdivisions=10, size=2)
    ob = bpy.context.active_object
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.object.mode_set(mode='OBJECT')
    ob.data.vertices[60].select = True
    bpy.ops.object.mode_set(mode='EDIT')
    try:
        r = bpy.ops.transform.translate(value=(0, 0, 0.5), use_proportional_edit=True,
                                        proportional_edit_falloff='SMOOTH', proportional_size=0.6,
                                        use_proportional_connected=True)
        bpy.ops.object.mode_set(mode='OBJECT')
        moved = sum(1 for v in ob.data.vertices if abs(v.co.z) > 1e-6)
        log('K_proportional_translate', {'op': list(r), 'moved_verts': moved})
    except Exception as e:
        log('K_proportional_translate', {'exception': str(e)[:400]})


# ================================================================ second probe: fixed skeleton, rings, shells

RAD2 = {'pelvis': .13, 'spine': .12, 'chest': .15, 'neck': .05, 'head': .10, 'clav': .06, 'shoulder': .055,
        'elbow': .045, 'wrist': .035, 'hip': .08, 'knee': .06, 'ankle': .045}
P2 = {'pelvis': (0, 0, 1.0), 'spine': (0, 0, 1.2), 'chest': (0, 0, 1.38), 'neck': (0, 0, 1.52), 'head': (0, 0, 1.70),
      'clav': (0.17, 0, 1.40), 'shoulder': (0.30, 0, 1.40), 'elbow': (0.55, 0, 1.40), 'wrist': (0.78, 0, 1.40),
      'hip': (0.10, 0, 0.95), 'knee': (0.11, 0, 0.52), 'ankle': (0.12, 0, 0.08)}
EDGES2 = [('pelvis', 'spine'), ('spine', 'chest'), ('chest', 'neck'), ('neck', 'head'), ('chest', 'clav'),
          ('clav', 'shoulder'), ('shoulder', 'elbow'), ('elbow', 'wrist'), ('pelvis', 'hip'), ('hip', 'knee'),
          ('knee', 'ankle')]


def body2(name, rings):
    """Skin body; rings=1: only the joint vertex; rings=3: joint vertex +-0.04 m along the limb."""
    V, idx = [], {}
    for k, p in P2.items():
        idx[k] = len(V)
        V.append(p)
    E_ = [(idx[a], idx[b]) for a, b in EDGES2]
    rad = [RAD2[k] for k in P2]
    if rings == 3:
        for j, (pa, pb) in (('elbow', ('shoulder', 'wrist')), ('knee', ('hip', 'ankle'))):
            J, A, B = Vector(P2[j]), Vector(P2[pa]), Vector(P2[pb])
            ia = len(V)
            V.append(tuple(J + (A - J).normalized() * 0.04))
            rad.append(RAD2[j])
            ib = len(V)
            V.append(tuple(J + (B - J).normalized() * 0.04))
            rad.append(RAD2[j])
            E_.remove((idx[pa], idx[j]))
            E_.remove((idx[j], idx[pb]))
            E_ += [(idx[pa], ia), (ia, idx[j]), (idx[j], ib), (ib, idx[pb])]
    me = bpy.data.meshes.new(name)
    me.from_pydata(V, E_, [])
    ob = bpy.data.objects.new(name, me)
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
    o2 = bpy.data.objects.new(name, out)
    bpy.context.collection.objects.link(o2)
    return o2


def game_skeleton():
    """One bone per anatomical segment, mirrored (like a Bip01 rig: no extra bones at joints)."""
    ad = bpy.data.armatures.new('rig')
    arm = bpy.data.objects.new('rig', ad)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = ad.edit_bones

    def bone(n, a, b, parent=None, mirror=1):
        x = eb.new(n)
        x.head = Vector(a) * Vector((mirror, 1, 1))
        x.tail = Vector(b) * Vector((mirror, 1, 1))
        if parent:
            x.parent = eb[parent]
            x.use_connect = (x.head - eb[parent].tail).length < 1e-6
        return x
    bone('pelvis', P2['pelvis'], P2['spine'])
    bone('chest', P2['spine'], P2['chest'], 'pelvis')
    bone('neck', P2['chest'], P2['neck'], 'chest')
    bone('head', P2['neck'], P2['head'], 'neck')
    for s, m in (('L', 1), ('R', -1)):
        bone('clav.' + s, P2['chest'], P2['shoulder'], 'chest', m)
        bone('upperarm.' + s, P2['shoulder'], P2['elbow'], 'clav.' + s, m)
        bone('forearm.' + s, P2['elbow'], P2['wrist'], 'upperarm.' + s, m)
        bone('thigh.' + s, P2['hip'], P2['knee'], 'pelvis', m)
        bone('shin.' + s, P2['knee'], P2['ankle'], 'thigh.' + s, m)
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


def autoweight(ob, arm, limit=4, normalize=True):
    select_only(ob, arm, active=arm)
    r = bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    select_only(ob)
    sums = [sum(g.weight for g in v.groups) for v in ob.data.vertices]
    raw = {'op': list(r), 'verts_sum_off_by_gt_0.01': sum(1 for s in sums if abs(s - 1) > 0.01),
           'max_influences': max(len([g for g in v.groups if g.weight > 0]) for v in ob.data.vertices)}
    if limit:
        bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=limit)
    if normalize:
        bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
    return raw


def tris(me):
    me.calc_loop_triangles()
    return [v.co.copy() for v in me.vertices], [tuple(t.vertices) for t in me.loop_triangles]


def eval_mesh(ob):
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    return bpy.data.meshes.new_from_object(ob.evaluated_get(dg), depsgraph=dg)


def seg_dist(p, a, b):
    ab = b - a
    t = max(0, min(1, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
    return (p - (a + ab * t)).length


def joint_rings_axis(ob, j, axis, w):
    ts = sorted((v.co - j).dot(axis) for v in ob.data.vertices
                if abs((v.co - j).dot(axis)) <= w and ((v.co - j) - axis * (v.co - j).dot(axis)).length < 0.12)
    rings, last = 0, None
    for t in ts:
        if last is None or t - last > 0.005:
            rings += 1
        last = t
    return rings


def bend_test(ob, arm, parent, child, joint, angle=100):
    for pb in arm.pose.bones:
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (0, 0, 0)
    vs0, ts = tris(eval_mesh(ob))
    pb = arm.pose.bones[child]
    pb.rotation_euler = (math.radians(angle), 0, 0)
    vs1, _ = tris(eval_mesh(ob))
    bpy.context.view_layer.update()
    P0, C0 = arm.pose.bones[parent], arm.pose.bones[child]
    segs1 = [(P0.head.copy(), P0.tail.copy()), (C0.head.copy(), C0.tail.copy())]
    b0, c0 = arm.data.bones[parent], arm.data.bones[child]
    segs0 = [(b0.head_local.copy(), b0.tail_local.copy()), (c0.head_local.copy(), c0.tail_local.copy())]
    J = Vector(joint)
    win = 0.12
    ratios = []
    for i, v in enumerate(vs0):
        if (v - J).length < win:
            r0 = min(seg_dist(v, *s) for s in segs0)
            r1 = min(seg_dist(vs1[i], *s) for s in segs1)
            if r0 > 1e-4:
                ratios.append(r1 / r0)
    pb.rotation_euler = (0, 0, 0)
    sx = self_intersections(vs1, ts) - self_intersections(vs0, ts)
    return {'radius_ratio_min': round(min(ratios), 3), 'radius_ratio_p10': round(sorted(ratios)[len(ratios) // 10], 3),
            'new_self_intersections': sx, 'joint_verts': len(ratios)}


def exp_rings():
    out = {}
    for rings in (1, 3):
        reset()
        b = body2('body', rings)
        arm = game_skeleton()
        raw = autoweight(b, arm)
        res = {'raw_autoweights': raw, 'verts': len(b.data.vertices), 'triangles': len(tris(b.data)[1])}
        res['elbow_rings'] = joint_rings_axis(b, Vector(P2['elbow']), Vector((1, 0, 0)), 0.06)
        res['knee_rings'] = joint_rings_axis(b, Vector(P2['knee']),
                                             (Vector(P2['ankle']) - Vector(P2['hip'])).normalized(), 0.06)
        for ang in (60, 100, 130):
            res['elbow_%d' % ang] = bend_test(b, arm, 'upperarm.L', 'forearm.L', P2['elbow'], ang)
            res['knee_%d' % ang] = bend_test(b, arm, 'thigh.L', 'shin.L', P2['knee'], -ang)
        out['rings_%d' % rings] = res
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'rings_%d.blend' % rings))
    log('D2_fixed_skeleton_rings', out)


def exp_shell_poke():
    out = {}
    for strategy in ('same_limit4', 'shell_limit2', 'shell_rigid1'):
        for gap in (0.0, 0.01):
            reset()
            b = body2('body', 3)
            arm = game_skeleton()
            autoweight(b, arm, 4, True)
            me = b.data.copy()
            sh = bpy.data.objects.new('robe', me)
            bpy.context.collection.objects.link(sh)
            sh.vertex_groups.clear()
            bm = bmesh.new()
            bm.from_mesh(me)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if not all(0.85 < v.co.z < 1.45 and abs(v.co.x) < 0.22
                                                                      for v in f.verts)], context='FACES')
            bm.normal_update()
            for v in bm.verts:
                v.co += v.normal * gap
            bm.to_mesh(me)
            bm.free()
            so = sh.modifiers.new('Solid', 'SOLIDIFY')
            so.thickness = 0.012
            so.offset = 1.0
            dt = sh.modifiers.new('DT', 'DATA_TRANSFER')
            dt.object = b
            dt.use_vert_data = True
            dt.data_types_verts = {'VGROUP_WEIGHTS'}
            dt.vert_mapping = 'POLYINTERP_NEAREST'
            select_only(sh)
            bpy.ops.object.datalayout_transfer(modifier='DT')
            bpy.ops.object.modifier_apply(modifier='Solid')
            bpy.ops.object.modifier_apply(modifier='DT')
            lim = {'same_limit4': 4, 'shell_limit2': 2, 'shell_rigid1': 1}[strategy]
            bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=lim)
            bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
            sh.modifiers.new('Arm', 'ARMATURE').object = arm
            res = {}
            for ang in (0, 30, 60):
                for pb in arm.pose.bones:
                    pb.rotation_mode = 'XYZ'
                    pb.rotation_euler = (0, 0, 0)
                arm.pose.bones['chest'].rotation_euler = (math.radians(ang), 0, 0)
                arm.pose.bones['thigh.L'].rotation_euler = (math.radians(-ang * 1.5), 0, 0)
                vb, tb = tris(eval_mesh(b))
                vsh, tsh = tris(eval_mesh(sh))
                TB = BVHTree.FromPolygons(vb, tb, all_triangles=True)
                TS = BVHTree.FromPolygons(vsh, tsh, all_triangles=True)
                res['bend_%d' % ang] = len(TS.overlap(TB))
            out['%s_gap%.3f' % (strategy, gap)] = res
    log('E2_shell_poke', out)


def exp_unnormalized():
    """A single-bone weight of 0.5 against a weight of 1.0: the Armature modifier normalizes at evaluation."""
    centres = {}
    for weight in (0.5, 1.0):
        reset()
        bpy.ops.mesh.primitive_cube_add(size=0.2, location=(1, 0, 0))
        ob = bpy.context.active_object
        ad = bpy.data.armatures.new('a')
        arm = bpy.data.objects.new('a', ad)
        bpy.context.collection.objects.link(arm)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode='EDIT')
        e = ad.edit_bones.new('A')
        e.head, e.tail = (0, 0, 0), (0, 0, 1)
        bpy.ops.object.mode_set(mode='OBJECT')
        ob.vertex_groups.new(name='A').add(list(range(8)), weight, 'REPLACE')
        ob.modifiers.new('Arm', 'ARMATURE').object = arm
        pb = arm.pose.bones['A']
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (0, 0, math.radians(90))
        me = eval_mesh(ob)
        c = sum((ob.matrix_world @ v.co for v in me.vertices), Vector()) / 8
        centres[weight] = [round(x, 3) + 0.0 for x in c]
    log('L_unnormalized_weight_preview', {'single_bone_weight': 0.5, 'cube_center_after_90deg': centres[0.5],
                                          'control_weight_1_center': centres[1.0],
                                          'follows_fully': centres[0.5] == centres[1.0]})


# ================================================================ third and fourth probes


def exp_skin_edge_rings():
    """Does the Skin modifier add rings along long edges? Ring positions along the arm of the rings bodies."""
    out = {}

    def skin_edge(L, r):
        reset()
        me = bpy.data.meshes.new('e')
        me.from_pydata([(0, 0, 0), (L, 0, 0)], [(0, 1)], [])
        ob = bpy.data.objects.new('e', me)
        bpy.context.collection.objects.link(ob)
        ob.modifiers.new('Skin', 'SKIN')
        for d in me.skin_vertices[0].data:
            d.radius = (r, r)
        dg = bpy.context.evaluated_depsgraph_get()
        m = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), depsgraph=dg)
        return {'verts': len(m.vertices), 'faces': len(m.polygons),
                'ring_x': sorted({round(v.co.x, 4) for v in m.vertices})}
    for L, r in ((1, .05), (1, .1), (1, .25), (0.25, .045), (0.23, .045), (0.5, .1)):
        out['edge_L%g_r%g' % (L, r)] = skin_edge(L, r)
    for n in (1, 3):
        bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT, 'rings_%d.blend' % n))
        b = bpy.data.objects['body']
        out['arm_ring_x_rings_%d' % n] = sorted({round(v.co.x, 3) for v in b.data.vertices
                                                 if abs(v.co.z - 1.40) < 0.06 and v.co.x > 0.25})
    log('P3_skin_edge_rings', out)


CAGE_RINGS = [0.32, 0.40, 0.47, 0.51, 0.55, 0.59, 0.63, 0.70, 0.76]
CAGE_SIDES = 8


def exp_shrinkwrap():
    """Shrinkwrap of an 8-sided arm cage onto a smooth Skin+Subsurf arm per wrap method; inverted-shell volume."""
    out = {}
    reset()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT, 'rings_3.blend'))
    body = bpy.data.objects['body']
    for m in list(body.modifiers):
        body.modifiers.remove(m)
    body.parent = None
    body.modifiers.new('Sub', 'SUBSURF').levels = 2
    dg = bpy.context.evaluated_depsgraph_get()
    tme = bpy.data.meshes.new_from_object(body.evaluated_get(dg), depsgraph=dg)
    target = bpy.data.objects.new('target', tme)
    bpy.context.collection.objects.link(target)
    bpy.data.objects.remove(body)
    tme.calc_loop_triangles()
    TV = [v.co.copy() for v in tme.vertices]
    TT = [tuple(t.vertices) for t in tme.loop_triangles]
    TB = BVHTree.FromPolygons(TV, TT, all_triangles=True)

    def cage():
        bm = bmesh.new()
        rings = []
        for x in CAGE_RINGS:
            rings.append([bm.verts.new((x, 0.09 * math.cos(2 * math.pi * k / CAGE_SIDES),
                                        1.40 + 0.09 * math.sin(2 * math.pi * k / CAGE_SIDES)))
                          for k in range(CAGE_SIDES)])
        for a, b in zip(rings, rings[1:]):
            for k in range(CAGE_SIDES):
                bm.faces.new((a[k], a[(k + 1) % CAGE_SIDES], b[(k + 1) % CAGE_SIDES], b[k]))
        bm.normal_update()
        me = bpy.data.meshes.new('cage')
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new('cage', me)
        bpy.context.collection.objects.link(ob)
        return ob

    for method, extra in (('NEAREST_SURFACEPOINT', {}), ('TARGET_PROJECT', {}),
                          ('PROJECT', {'use_negative_direction': True, 'use_positive_direction': True})):
        ob = cage()
        sw = ob.modifiers.new('SW', 'SHRINKWRAP')
        sw.target = target
        sw.wrap_method = method
        for k, v in extra.items():
            setattr(sw, k, v)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), depsgraph=dg)
        vs = [v.co.copy() for v in me.vertices]
        spread = [max(vs[i * CAGE_SIDES + k].x for k in range(CAGE_SIDES)) -
                  min(vs[i * CAGE_SIDES + k].x for k in range(CAGE_SIDES)) for i in range(len(CAGE_RINGS))]
        dist = [TB.find_nearest(v)[3] for v in vs]
        me.calc_loop_triangles()
        CB = BVHTree.FromPolygons(vs, [tuple(t.vertices) for t in me.loop_triangles], all_triangles=True)
        arm = [v for v in TV if CAGE_RINGS[1] <= v.x <= CAGE_RINGS[-2] and abs(v.z - 1.40) < 0.1]
        fit = sorted(CB.find_nearest(v)[3] for v in arm)
        out[method] = {'ring_axial_spread_max_m': round(max(spread), 4), 'ring_axial_spread_elbow_m': round(spread[4], 4),
                       'cage_to_target_max_m': round(max(dist), 4),
                       'target_to_cage_p95_m': round(fit[int(len(fit) * 0.95)], 4),
                       'target_to_cage_max_m': round(fit[-1], 4)}
        bpy.data.objects.remove(ob)

    def svol(me):
        me.calc_loop_triangles()
        V = [v.co for v in me.vertices]
        return sum(V[a].dot(V[b].cross(V[c])) for a, b, c in (t.vertices for t in me.loop_triangles)) / 6
    v0 = svol(tme)
    bm = bmesh.new()
    bm.from_mesh(tme)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(tme)
    bm.free()
    v1 = svol(tme)
    bm = bmesh.new()
    bm.from_mesh(tme)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(tme)
    bm.free()
    v2 = svol(tme)
    out['inverted_shell_signed_volume'] = {'original': round(v0, 5), 'all_flipped': round(v1, 5),
                                           'after_recalc_normals': round(v2, 5)}
    log('P4_shrinkwrap', out)


# ================================================================ registry and entry point

# name -> (function, {sources key: result keys that reproduce it}, experiments whose saved files it opens)
EXPERIMENTS = {
    'flip_name': (exp_flip_name, {'L1': ['L1_flip_name']}, []),
    'operator_defaults': (exp_operator_defaults, {'L8': ['L8_operator_defaults']}, []),
    'bone_deform_enum': (exp_bone_deform_enum, {'L16': ['bone_deform_enum']}, []),
    'skin': (exp_skin, {'L2': ['C_autoweights_plain', 'C_autoweights_joint_loops'],
                        'L9': ['A_skin_plain', 'A_skin_joint_loops', 'C_joint_rings_plain',
                               'C_joint_rings_joint_loops']}, []),
    'autoweight_pitfalls': (exp_autoweight_pitfalls, {'L2': ['C2_autoweight_pitfalls']}, []),
    'shell_transfer': (exp_shell_transfer, {'L3': ['E_shell_transfer'], 'L4': ['E_shell_transfer']}, ['skin']),
    'remesh_decimate': (exp_remesh_decimate, {'L6': ['F_quadriflow_manifold'], 'L7': ['G_decimate']}, ['skin']),
    'vertex_split': (exp_vertex_split, {'L5': ['H_vertex_split']}, ['skin']),
    'curves': (exp_curves, {}, []),
    'silhouette': (exp_silhouette, {'L10': ['J_silhouette']}, ['skin']),
    'proportional': (exp_proportional, {'L13': ['K_proportional_translate']}, []),
    'rings': (exp_rings, {'L2': ['D2_fixed_skeleton_rings'], 'L11': ['D2_fixed_skeleton_rings'],
                          'L15': ['D2_fixed_skeleton_rings']}, []),
    'shell_poke': (exp_shell_poke, {'L4': ['E2_shell_poke']}, []),
    'unnormalized': (exp_unnormalized, {'L2': ['L_unnormalized_weight_preview']}, []),
    'skin_edge_rings': (exp_skin_edge_rings, {}, ['rings']),
    'shrinkwrap': (exp_shrinkwrap, {'L12': ['P4_shrinkwrap'], 'L14': ['P4_shrinkwrap']}, ['rings']),
}


def plan(only):
    """Requested experiments plus the ones whose saved files they open, in registry order."""
    want = set(only or EXPERIMENTS)
    unknown = want - set(EXPERIMENTS)
    if unknown:
        raise ValueError('unknown experiments: %s' % ', '.join(sorted(unknown)))
    changed = True
    while changed:
        changed = False
        for n in list(want):
            for dep in EXPERIMENTS[n][2]:
                if dep not in want:
                    want.add(dep)
                    changed = True
    return [n for n in EXPERIMENTS if n in want]


def parse_args(argv):
    ap = argparse.ArgumentParser(prog='organic_probe.py', description=__doc__.splitlines()[0])
    ap.add_argument('--out', help='scratch folder (default: new temp folder; refused inside a git work tree)')
    ap.add_argument('--only', help='comma-separated experiments (dependencies are added)')
    ap.add_argument('--list', action='store_true', help='list experiments and the sources keys they reproduce')
    E.add_blender_args(ap)
    return ap.parse_args(argv)


def main_blender(argv):
    try:
        a = parse_args(argv)
    except SystemExit as exc:
        return 2 if exc.code else 0
    try:
        return run(a)
    except Exception as exc:  # last resort: never let a crash read as a pass
        traceback.print_exc()
        print('SETUP ERROR: the probe could not run: %s: %s' % (type(exc).__name__, exc), file=sys.stderr)
        return 2


def run(a):
    global OUT
    if a.list:
        for n, (_, keys, deps) in EXPERIMENTS.items():
            print('%-20s %-12s %s' % (n, ' '.join(keys) or '-', ('needs ' + ', '.join(deps)) if deps else ''))
        return 0
    try:
        order = plan([x.strip() for x in a.only.split(',') if x.strip()] if a.only else None)
    except ValueError as exc:
        print('SETUP ERROR: %s' % exc, file=sys.stderr)
        return 2
    OUT = a.out or E.scratch_dir('organic_probe_')
    err = E.refuse_in_worktree(OUT, 'probe folder')
    if err:
        print('SETUP ERROR: ' + err, file=sys.stderr)
        return 2
    os.makedirs(OUT, exist_ok=True)
    R.clear()
    R.update({'tool': 'organic_probe', 'blender': bpy.app.version_string, 'date': time.strftime('%Y-%m-%dT%H:%M:%S'),
              'out': OUT, 'experiments': order, 'errors': {}})
    lkeys = {}
    for n in order:
        fn, keys, _ = EXPERIMENTS[n]
        t = time.time()
        try:
            fn()
        except Exception:
            R['errors'][n] = traceback.format_exc()[-2000:]
            print('PROBE ERROR', n, R['errors'][n], file=sys.stderr)
        R.setdefault('seconds', {})[n] = round(time.time() - t, 2)
        for k, written in keys.items():
            lkeys.setdefault(k, []).extend(x for x in written if x not in lkeys.get(k, []))
    R['_lkeys'] = lkeys
    path = os.path.join(OUT, 'probe.json')
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(R, fh, indent=1, default=str)
    print('PROBE DONE %s (%d experiments, %d errors)' % (path, len(order), len(R['errors'])))
    return 1 if R['errors'] else 0


if __name__ == '__main__':
    if bpy is None:
        sys.exit(E.relaunch_in_blender(Path(__file__).resolve(), sys.argv[1:]))
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    sys.exit(main_blender(args))
