"""Blender side of character-topology-analysis (runs ONLY inside background Blender; started by tl_io.run_blender with
--factory-startup --disable-autoexec --python-exit-code 2). Never saves a .blend, writes only the named output files.

    blender -b --factory-startup --disable-autoexec --python-exit-code 2 --python tl_blender.py -- \
        append FILE.blend OUT.npz [--select REGEX] [--collection NAME] [--exclude REGEX]
    blender -b --factory-startup --disable-autoexec --python-exit-code 2 --python tl_blender.py -- \
        names FILE.blend OUT.json [--exclude REGEX]
    blender -b --factory-startup --disable-autoexec --python-exit-code 2 --python tl_blender.py -- import FILE OUT.npz [--select REGEX] [--exclude REGEX]
    blender -b --factory-startup --disable-autoexec --python-exit-code 2 --python tl_blender.py -- t2q IN.npz OUT.npz
    blender -b --factory-startup --disable-autoexec --python-exit-code 2 --python tl_blender.py -- \
        control IN.npz OUT.npz --method decimate|quadriflow [--ratio R] [--faces N] [--seed S]

append   the .blend is NOT opened: only the matching objects (or the named collection) are appended from it into the
         factory scene (bpy.data.libraries.load), so excluded assets of a mixed file are never loaded. Then the base cage
         of those mesh objects (object.data, modifiers ignored) in world space; armature bone heads (world) as the rig;
         per vertex the dominant vertex group. OUT.npz + OUT.npz.json (object list).
names    collection and object names of a .blend read from its library directory (no datablock is loaded), excluded
         names left out.
import   the Blender importer (glTF merge_vertices off, FBX, OBJ, ...) then the same export of every imported mesh.
t2q      definitions.md D15: bmesh from the triangles, normal_update(), join_triangles 180/180 deg, topology 1.15.
control  negative controls for the tests: Decimate (collapse, ratio) or QuadriFlow remesh (target faces) of a mesh.
"""
import json
import math
import re
import sys

import bpy
import bmesh
import numpy as np

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []


def opt(name, default=None):
    if name in argv:
        return argv[argv.index(name) + 1]
    return default


def write(path, V, faces, extra=None, meta=None):
    flat = np.array([i for f in faces for i in f], dtype=np.int64)
    off = np.cumsum([0] + [len(f) for f in faces]).astype(np.int64)
    np.savez_compressed(path, V=np.asarray(V, float), F=flat, off=off, **(extra or {}))
    with open(path + '.json', 'w') as fh:
        json.dump(meta or {}, fh, indent=1)


def export_objects(out, objs):
    Vs, faces, fobj, vdom, names = [], [], [], [], []
    base = 0
    for k, o in enumerate(objs):
        me = o.data
        M = np.array(o.matrix_world)
        co = np.array([v.co[:] for v in me.vertices]).reshape(-1, 3)
        cw = (np.c_[co, np.ones(len(co))] @ M.T)[:, :3]
        Vs.append(cw)
        gname = {g.index: g.name for g in o.vertex_groups}
        for v in me.vertices:
            best, bw = '', 0.0
            for g in v.groups:
                if g.weight > bw and g.group in gname:
                    best, bw = gname[g.group], g.weight
            vdom.append(best)
        for p in me.polygons:
            faces.append([int(i) + base for i in p.vertices])
            fobj.append(k)
        base += len(co)
        names.append(dict(name=o.name, verts=len(co), faces=len(me.polygons),
                          modifiers=[m.type for m in o.modifiers], vertex_groups=len(o.vertex_groups)))
    bones_n, bones_h = [], []
    for a in bpy.data.objects:
        if a.type != 'ARMATURE':
            continue
        Ma = np.array(a.matrix_world)
        for b in a.data.bones:
            h = Ma @ np.append(np.array(b.head_local), 1.0)
            bones_n.append(b.name)
            bones_h.append(h[:3])
    V = np.vstack(Vs) if Vs else np.zeros((0, 3))
    extra = dict(fobj=np.array(fobj, np.int64), vdom=np.array(vdom, dtype='U64'))
    if bones_n:
        extra.update(bone_names=np.array(bones_n, dtype='U64'), bone_heads=np.array(bones_h, float))
    write(out, V, faces, extra, dict(objects=names, blender=bpy.app.version_string))
    print('TL_EXPORT', out, len(names), 'objects', len(V), 'verts', len(faces), 'faces')


def excluded(name):
    """exclusion regexes match case-insensitively (definitions.md D0)."""
    ex = opt('--exclude')
    return bool(ex) and re.search(ex, name, re.IGNORECASE) is not None


def pick(objs):
    sel = opt('--select')
    col = opt('--collection')
    if col:
        objs = [o for o in bpy.data.collections[col].all_objects if o.type == 'MESH']
    if sel:
        objs = [o for o in objs if re.search(sel, o.name)]
    objs = [o for o in objs if not excluded(o.name) and not any(excluded(c.name) for c in o.users_collection)]
    return sorted(objs, key=lambda o: o.name)


def cmd_append():
    """append only the wanted datablocks from a .blend that is never opened as the main file."""
    src, out = argv[1], argv[2]
    sel, col = opt('--select'), opt('--collection')
    if not sel and not col:
        raise SystemExit('append needs --select or --collection')
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    with bpy.data.libraries.load(src, link=False) as (data_from, data_to):
        if col:
            if excluded(col):
                raise SystemExit('collection %r is excluded' % col)
            if col not in data_from.collections:
                raise SystemExit('no collection %r in the file' % col)
            data_to.collections = [col]
        else:
            data_to.objects = [n for n in data_from.objects if re.search(sel, n) and not excluded(n)]
    scene = bpy.context.scene
    if col:
        c = bpy.data.collections[col]
        scene.collection.children.link(c)
        objs = [o for o in c.all_objects if o.type == 'MESH']
        if sel:
            objs = [o for o in objs if re.search(sel, o.name)]
    else:
        objs = [o for o in data_to.objects if o is not None]
        for o in objs:
            scene.collection.objects.link(o)
        objs = [o for o in objs if o.type == 'MESH']
    bpy.context.view_layer.update()
    objs = [o for o in objs if not excluded(o.name)]
    export_objects(out, sorted(objs, key=lambda o: o.name))


def cmd_names():
    src, out = argv[1], argv[2]
    with bpy.data.libraries.load(src, link=False) as (data_from, data_to):
        cols = [n for n in data_from.collections if not excluded(n)]
        objs = [n for n in data_from.objects if not excluded(n)]
    with open(out, 'w') as fh:
        json.dump(dict(collections=sorted(cols), objects=sorted(objs)), fh, indent=1)
    print('TL_NAMES', out, len(cols), 'collections', len(objs), 'objects')


def cmd_import():
    src, out = argv[1], argv[2]
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    low = src.lower()
    if low.endswith(('.glb', '.gltf')):
        try:
            bpy.ops.import_scene.gltf(filepath=src, merge_vertices=False)
        except TypeError:
            bpy.ops.import_scene.gltf(filepath=src)
    elif low.endswith('.fbx'):
        bpy.ops.import_scene.fbx(filepath=src)
    elif low.endswith('.obj'):
        bpy.ops.wm.obj_import(filepath=src)
    else:
        raise SystemExit('unsupported format: %s' % src)
    export_objects(out, pick([o for o in bpy.data.objects if o.type == 'MESH']))


def load_npz(path):
    z = np.load(path)
    V = z['V']
    F, off = z['F'], z['off']
    return V, [[int(x) for x in F[off[i]:off[i + 1]]] for i in range(len(off) - 1)]


def build_bm(V, faces):
    bm = bmesh.new()
    for p in V:
        bm.verts.new(tuple(float(c) for c in p))
    bm.verts.ensure_lookup_table()
    bad = 0
    for f in faces:
        try:
            bm.faces.new([bm.verts[i] for i in f])
        except ValueError:
            bad += 1
    bm.faces.ensure_lookup_table()
    return bm, bad


def cmd_t2q():
    inp, out = argv[1], argv[2]
    V, T = load_npz(inp)
    bm, bad = build_bm(V, T)
    bm.normal_update()       # D15: the step-2 defect - join_triangles on zero normals - is avoided here
    zero = sum(1 for f in bm.faces if f.normal.length < 1e-12)
    bmesh.ops.join_triangles(bm, faces=bm.faces[:], cmp_seam=False, cmp_sharp=False, cmp_uvs=False, cmp_vcols=False,
                             cmp_materials=False, angle_face_threshold=math.pi, angle_shape_threshold=math.pi,
                             topology_influence=1.15)
    bm.verts.index_update()
    faces = [[v.index for v in f.verts] for f in bm.faces]
    write(out, V, faces, meta=dict(op='bmesh.ops.join_triangles after normal_update', face_threshold_deg=180,
                                   shape_threshold_deg=180, topology_influence=1.15, rejected_faces=bad,
                                   zero_normals_after_update=zero, blender=bpy.app.version_string))
    print('TL_T2Q', out, len(faces), 'faces', sum(1 for f in faces if len(f) == 4), 'quads')


def cmd_control():
    inp, out = argv[1], argv[2]
    method = opt('--method')
    V, F = load_npz(inp)
    me = bpy.data.meshes.new('ctl_src')
    me.from_pydata([tuple(map(float, v)) for v in V], [], F)
    me.validate(clean_customdata=False)
    ob = bpy.data.objects.new('ctl_src', me)
    bpy.context.scene.collection.objects.link(ob)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    meta = dict(method=method, blender=bpy.app.version_string)
    if method == 'decimate':
        md = ob.modifiers.new('dec', 'DECIMATE')
        md.decimate_type = 'COLLAPSE'
        md.ratio = float(opt('--ratio', '0.1'))
        md.use_symmetry = True
        md.symmetry_axis = 'X'
        md.use_collapse_triangulate = False
        dg = bpy.context.evaluated_depsgraph_get()
        me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        meta.update(ratio=md.ratio, symmetry='X', triangulate=False)
    elif method == 'quadriflow':
        ob.data.use_mirror_x = True
        r = bpy.ops.object.quadriflow_remesh(use_mesh_symmetry=True, use_preserve_sharp=False, use_preserve_boundary=False,
                                             preserve_attributes=False, smooth_normals=False, mode='FACES',
                                             target_faces=int(opt('--faces', '1000')), seed=int(opt('--seed', '0')))
        if 'FINISHED' not in r:
            raise SystemExit('quadriflow failed: %s' % list(r))
        me2 = ob.data
        meta.update(target_faces=int(opt('--faces', '1000')), seed=int(opt('--seed', '0')), symmetry=True)
    else:
        raise SystemExit('unknown --method %s' % method)
    Vo = np.array([v.co[:] for v in me2.vertices])
    Fo = [list(p.vertices) for p in me2.polygons]
    meta.update(faces=len(Fo), verts=len(Vo))
    write(out, Vo, Fo, meta=meta)
    print('TL_CONTROL', out, meta)


CMDS = dict(append=cmd_append, names=cmd_names, import_=cmd_import, t2q=cmd_t2q, control=cmd_control)
if not argv:
    raise SystemExit('usage: see the module docstring')
CMDS['import_' if argv[0] == 'import' else argv[0]]()
