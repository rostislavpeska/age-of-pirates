"""Check a skinned model (an FBX from the GR2 converter, or any FBX/GLB) in background Blender and, with
--baseline, prove what an edit changed against the untouched original.

    blender -b --factory-startup --python skin_check.py -- --model EDITED.fbx [--baseline VANILLA.fbx]
            --out DIR [--max-influences 4] [--expect-dropped MESH ...]

Writes DIR/skin_check.json and DIR/skin_check_views.png (clay renders, model next to baseline) and prints a
summary. Exit code 1 when a FAIL is present.

FAIL  unweighted or over-influenced vertices on a bound mesh, a mesh not bound to the armature, zero-length bones,
      negative scale; with --baseline: a bone added, removed, renamed or re-parented, a mesh dropped that is not
      listed in --expect-dropped, any vertex whose bone set or weights changed (an in-place edit keeps skinning).
WARN  weights not summing to 1, vertex groups with no bone, more than one armature, ngons, zero-area faces, loose
      vertices, edges shared by more than two faces.
INFO  converter FBX scale on the armature, vertices doubled along UV seams (game meshes are split there), tiny
      vanilla weights - expected for AoE3 converter output, compared against the baseline instead of warned.

Adapted from blender-game-skills (scripts/validate.py and scripts/roundtrip.py),
Copyright (c) 2026 Majid Manzarpour, MIT License - see ../THIRD_PARTY_NOTICES.md. Rig checks (armature present,
mesh bound, single armature) follow the checklist idea of the public blender-rig-audit skill (no code taken).
"""
import argparse
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector


def parse():
    p = argparse.ArgumentParser()
    p.add_argument('--model', required=True)
    p.add_argument('--baseline')
    p.add_argument('--out', required=True)
    p.add_argument('--max-influences', type=int, default=4)
    p.add_argument('--expect-dropped', nargs='*', default=[], help='mesh names the edit removes on purpose')
    p.add_argument('--weight-tol', type=float, default=1e-3)
    p.add_argument('--res', type=int, default=512)
    return p.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])


def load(path):
    """Fresh scene with only this file. Returns (meshes, armatures)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ext = os.path.splitext(path)[1].lower()
    if ext == '.fbx':
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext in ('.glb', '.gltf'):
        bpy.ops.import_scene.gltf(filepath=path)
    else:
        raise SystemExit('unsupported model type: %s (convert a .gr2 with run_skin_check.py)' % path)
    objs = list(bpy.context.scene.objects)
    return [o for o in objs if o.type == 'MESH'], [o for o in objs if o.type == 'ARMATURE']


def snapshot(meshes, arms):
    """Everything the baseline diff compares, in plain Python."""
    snap = {'bones': {}, 'meshes': {}}
    for a in arms:
        for b in a.data.bones:
            snap['bones'][b.name] = b.parent.name if b.parent else None
    for o in meshes:
        names = {g.index: g.name for g in o.vertex_groups}
        me = o.data
        snap['meshes'][o.name] = {
            'verts': len(me.vertices),
            'tris': sum(len(p.vertices) - 2 for p in me.polygons),
            'pos': [tuple(v.co) for v in me.vertices],
            'weights': [sorted((names.get(g.group, '?'), round(g.weight, 5)) for g in v.groups if g.weight > 0)
                        for v in me.vertices]}
    return snap


def mesh_checks(o, arms, a, rec):
    W, F, I = rec['warn'].append, rec['fail'].append, rec['info']
    me = o.data
    if any(s < 0 for s in o.scale):
        F('negative scale')
    bm = bmesh.new()
    bm.from_mesh(me)
    I['verts'], I['faces'] = len(bm.verts), len(bm.faces)
    I['tris'] = sum(len(f.verts) - 2 for f in bm.faces)
    ngons = sum(1 for f in bm.faces if len(f.verts) > 4)
    zero = sum(1 for f in bm.faces if f.calc_area() < 1e-14)
    loose = sum(1 for v in bm.verts if not v.link_edges)
    nonmani = sum(1 for e in bm.edges if len(e.link_faces) > 2)
    for n, msg in ((ngons, 'ngons'), (zero, 'zero-area faces'), (loose, 'loose vertices'),
                   (nonmani, 'edges shared by more than two faces')):
        if n:
            W('%d %s' % (n, msg))
    d = bmesh.ops.find_doubles(bm, verts=bm.verts, dist=1e-7 * max(o.dimensions) if max(o.dimensions) else 1e-9)
    I['seam_doubles'] = len(d['targetmap'])                  # expected: game meshes split vertices at UV seams
    bm.free()
    I['uv_layers'] = [l.name for l in me.uv_layers]
    if not me.uv_layers:
        W('no UV layer')
    mods = [m for m in o.modifiers if m.type == 'ARMATURE']
    if not mods or not mods[0].object:
        F('not bound to an armature (no armature modifier with an object)')
        return
    arm = mods[0].object
    I['armature'] = arm.name
    deform = {b.name for b in arm.data.bones if b.use_deform} or {b.name for b in arm.data.bones}
    names = {g.index: g.name for g in o.vertex_groups}
    orphan = sorted(n for n in names.values() if n not in arm.data.bones)
    unweighted = over = unnorm = tiny = most = 0
    for v in me.vertices:
        ws = [(names.get(g.group, ''), g.weight) for g in v.groups]
        ws = [(n, w) for n, w in ws if n in deform and w > 0.0]
        total = sum(w for _, w in ws)
        most = max(most, len(ws))
        unweighted += total < 1e-6
        over += len(ws) > a.max_influences
        unnorm += total > 1e-6 and abs(total - 1.0) > 0.01
        tiny += sum(1 for _, w in ws if w < 0.01)
    I['skin'] = {'unweighted': unweighted, 'over_influences': over, 'max_influences_seen': most,
                 'not_normalised': unnorm, 'tiny_weights': tiny, 'orphan_groups': orphan}
    if unweighted:
        F('%d unweighted vertices' % unweighted)
    if over:
        F('%d vertices exceed %d influences' % (over, a.max_influences))
    if unnorm:
        W('%d vertices with weights not summing to 1' % unnorm)
    if orphan:
        W('vertex groups with no bone: %s' % ', '.join(orphan[:8]))


def armature_checks(arm, rec):
    W, F, I = rec['warn'].append, rec['fail'].append, rec['info']
    bones = arm.data.bones
    I['bones'] = len(bones)
    I['roots'] = [b.name for b in bones if b.parent is None]
    if len(I['roots']) > 1:
        W('multiple root bones: %s' % ', '.join(I['roots'][:6]))
    if any(s < 0 for s in arm.scale):
        F('negative scale on armature')
    I['object_scale'] = [round(s, 6) for s in arm.scale]      # converter FBX: a uniform scale is expected
    short = [b.name for b in bones if (b.head_local - b.tail_local).length < 1e-9]
    if short:
        F('zero-length bones: %s' % ', '.join(short[:6]))


def check(path, a):
    meshes, arms = load(path)
    report = []
    for arm in arms:
        rec = {'name': arm.name, 'type': 'ARMATURE', 'warn': [], 'fail': [], 'info': {}}
        armature_checks(arm, rec)
        report.append(rec)
    for o in meshes:
        rec = {'name': o.name, 'type': 'MESH', 'warn': [], 'fail': [], 'info': {}}
        mesh_checks(o, arms, a, rec)
        report.append(rec)
    top = {'warn': [], 'fail': []}
    if not arms:
        top['fail'].append('no armature in the file')
    elif len(arms) > 1:
        top['warn'].append('%d armatures (one expected)' % len(arms))
    return report, top, snapshot(meshes, arms), meshes


def diff(model, base, a):
    out = {'fail': [], 'warn': [], 'info': []}
    mb, bb = model['bones'], base['bones']
    added, removed = sorted(set(mb) - set(bb)), sorted(set(bb) - set(mb))
    reparented = sorted(n for n in set(mb) & set(bb) if mb[n] != bb[n])
    if added or removed or reparented:
        out['fail'].append('skeleton changed: added %s removed %s re-parented %s' % (added, removed, reparented))
    else:
        out['info'].append('skeleton identical (%d bones)' % len(bb))
    for name in sorted(set(base['meshes']) - set(model['meshes'])):
        (out['info'] if name in a.expect_dropped else out['fail']).append('mesh dropped: %s' % name)
    for name in sorted(set(model['meshes']) - set(base['meshes'])):
        out['warn'].append('mesh added: %s' % name)
    for name in sorted(set(model['meshes']) & set(base['meshes'])):
        m, b = model['meshes'][name], base['meshes'][name]
        line = '%s: verts %d -> %d, tris %d -> %d' % (name, b['verts'], m['verts'], b['tris'], m['tris'])
        if m['verts'] != b['verts']:
            out['warn'].append(line + ' (vertex count changed: weights not compared one-to-one)')
            continue
        moved = [i for i, (p, q) in enumerate(zip(m['pos'], b['pos']))
                 if (Vector(p) - Vector(q)).length > 1e-9]
        reweighted = [i for i, (p, q) in enumerate(zip(m['weights'], b['weights']))
                      if [n for n, _ in p] != [n for n, _ in q]
                      or any(abs(x - y) > a.weight_tol for (_, x), (_, y) in zip(p, q))]
        out['info'].append(line + ', %d vertices moved' % len(moved))
        if reweighted:
            out['fail'].append('%s: %d vertices changed bones or weights (first %s)' % (name, len(reweighted), reweighted[:8]))
    return out


def clay_views(path, png_prefix, res):
    meshes, _ = load(path)
    if not meshes:
        return []
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'SINGLE'
    sc.view_settings.view_transform = 'Standard'
    sc.render.resolution_x = sc.render.resolution_y = res
    sc.world = bpy.data.worlds.new('w')
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in meshes:
        ev = o.evaluated_get(dg)
        pts += [ev.matrix_world @ v.co for v in ev.to_mesh().vertices]
        ev.to_mesh_clear()
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    c, size = (lo + hi) / 2, max(hi - lo)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = size * 1.1
    cam.data.clip_start, cam.data.clip_end = size * 0.01, size * 100
    files = []
    for label, az in (('front', 0), ('threequarter', 35), ('side', 90), ('back', 180)):
        r = math.radians(az)
        cam.location = c + Vector((math.sin(r), -math.cos(r), 0.15)).normalized() * size * 3
        cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = '%s_%s.png' % (png_prefix, label)
        bpy.ops.render.render(write_still=True)
        files.append(sc.render.filepath)
    return files


def main():
    a = parse()
    os.makedirs(a.out, exist_ok=True)
    report, top, snap, _ = check(a.model, a)
    result = {'model': os.path.abspath(a.model), 'objects': report, 'file': top}
    fails = top['fail'] + ['%s: %s' % (r['name'], f) for r in report for f in r['fail']]
    warns = top['warn'] + ['%s: %s' % (r['name'], w) for r in report for w in r['warn']]
    if a.baseline:
        breport, btop, bsnap, _ = check(a.baseline, a)
        result['baseline'] = {'model': os.path.abspath(a.baseline), 'objects': breport, 'file': btop}
        d = diff(snap, bsnap, a)
        result['diff'] = d
        fails += ['diff: ' + x for x in d['fail']]
        warns += ['diff: ' + x for x in d['warn']]
    views = clay_views(a.model, os.path.join(a.out, 'model'), a.res)
    if a.baseline:
        views += clay_views(a.baseline, os.path.join(a.out, 'baseline'), a.res)
    result['views'] = views
    result['summary'] = {'fail': fails, 'warn': warns}
    with open(os.path.join(a.out, 'skin_check.json'), 'w', encoding='utf-8') as fh:
        json.dump(result, fh, indent=1)
    for r in report:
        print('%-28s %-8s %s' % (r['name'], r['type'], {k: r['info'][k] for k in ('verts', 'tris', 'bones', 'skin') if k in r['info']}))
    for x in result.get('diff', {}).get('info', []):
        print('DIFF ', x)
    print('WARN %d' % len(warns)); [print('   ' + w) for w in warns]
    print('FAIL %d' % len(fails)); [print('   ' + f) for f in fails]
    print('report', os.path.join(a.out, 'skin_check.json'))
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
