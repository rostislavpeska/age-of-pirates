"""Loading for character-topology-analysis (definitions.md sections D0, D14, D15).

One loader per format, all returning the same dict:
    V            raw positions (float64, Z up, the character facing -Y), one row per file vertex
    faces        polygons over raw vertex ids (file order)
    source       dict(path basename, format, selection)
    prims        GLB only: per primitive the raw triangle index array (for the OGT read-back, D14)
    ogt_faces    GLB only, when the triangle order survived: source polygons read back from the fan runs (raw ids)
    ogt          GLB only: the read-back report (strict pair share, splits, ambiguous six-runs)
    rig          joint name -> position (the asset's own rig: GLB skin nodes, Blender armature, given joints)
    vgroup_dom   per raw vertex the dominant joint / vertex-group name ('' when unweighted)
    t2q_V, t2q_faces  after request: Tris-to-Quads on the welded triangle mesh (Blender, normals computed, D15)

Formats: .obj (own parser, groups/objects), .glb (own glTF 2.0 binary reader: raw indices, node transforms, skins),
.npz (V + F/off or V + T), .blend (background Blender: the base cage = mesh data with modifiers off, world transform)
and anything else Blender imports (background Blender importer, merge off). Downloaded files are only ever read.

Axis rule: OBJ and glTF are Y-up and are turned Z-up with (x, y, z) -> (x, -z, y) (the Blender importer's rule);
--up z keeps an OBJ as written; --rot RX,RY,RZ (degrees, XYZ order) is applied afterwards.
"""
import json
import math
import os
import re
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
_COMPANION = HERE.parents[1] / 'blender-organic-modeling' / 'scripts'
if str(_COMPANION) not in sys.path:
    sys.path.append(str(_COMPANION))
try:
    import blender_env as BE  # noqa: E402
except ImportError:  # pragma: no cover
    BE = None

OGT_MIN_PAIR_SHARE = 0.90     # D14: the read-back is used only when >= 90 % of strict pairs share an edge


# ---------------------------------------------------------------------------------------------------------------- axes
def y_up_to_z_up(P):
    P = np.asarray(P, float)
    return np.c_[P[:, 0], -P[:, 2], P[:, 1]]


def euler_xyz(deg):
    rx, ry, rz = (math.radians(float(a)) for a in deg)
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rz @ Ry @ Rx


def apply_rot(d, rot):
    if rot is None or not any(float(a) for a in rot):
        return d
    R = euler_xyz(rot)
    d['V'] = d['V'] @ R.T
    if d.get('rig'):
        d['rig'] = {k: (R @ np.asarray(v)).tolist() for k, v in d['rig'].items()}
    if d.get('t2q_V') is not None:
        d['t2q_V'] = d['t2q_V'] @ R.T
    d['source']['rot_deg'] = [float(a) for a in rot]
    return d


# ---------------------------------------------------------------------------------------------------------------- OBJ
def load_obj(path, group=None, select=None, up='y', joints_from_groups=None, exclude=None):
    """OBJ: v / f (v, v/vt, v/vt/vn, v//vn, negative ids), g / o names. group = exact name, select = regex on the
    name, exclude = regex of names never taken; joints_from_groups = prefix: every group with that prefix becomes a
    joint at the mean of its vertices."""
    V, faces, names = [], [], []
    gname = None
    gfaces = {}
    wire = 0
    with open(path, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            if line.startswith('v '):
                p = line.split()
                V.append((float(p[1]), float(p[2]), float(p[3])))
            elif line.startswith(('g ', 'o ')):
                gname = line[2:].strip()
            elif line.startswith('f '):
                ids = []
                for t in line.split()[1:]:
                    i = int(t.split('/')[0])
                    ids.append(i - 1 if i > 0 else len(V) + i)
                gfaces.setdefault(gname, []).append(ids)
            elif line.startswith('l '):
                wire += len(line.split()) - 2
    V = np.array(V, dtype=float).reshape(-1, 3)
    sel = []
    for g, fl in gfaces.items():
        if group is not None and g != group:
            continue
        if select is not None and not re.search(select, g or ''):
            continue
        if exclude and re.search(exclude, g or '', re.IGNORECASE):
            continue
        if joints_from_groups and g and g.startswith(joints_from_groups):
            continue
        sel.append(g)
        faces += [tuple(f) for f in fl]
    rig = None
    if joints_from_groups:
        rig = {}
        for g, fl in gfaces.items():
            if g and g.startswith(joints_from_groups):
                idx = sorted({i for f in fl for i in f})
                rig[g[len(joints_from_groups):]] = V[idx].mean(axis=0)
    if up == 'y':
        V = y_up_to_z_up(V)
        if rig:
            rig = {k: y_up_to_z_up(np.asarray(v)[None])[0] for k, v in rig.items()}
    if rig:
        rig = {k: np.asarray(v).tolist() for k, v in rig.items()}
    return dict(V=V, faces=faces, source=dict(path=os.path.basename(path), format='obj', groups=sel, up=up),
                rig=rig, vgroup_dom=None, wire_edges=wire)


# ---------------------------------------------------------------------------------------------------------------- GLB
_CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
_NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def read_glb(path):
    b = open(path, 'rb').read()
    magic, ver, length = struct.unpack_from('<4sII', b, 0)
    if magic != b'glTF' or ver != 2:
        raise ValueError('not a glTF 2.0 binary: %s' % path)
    off, js, bn = 12, None, None
    while off < length:
        clen, ctype = struct.unpack_from('<II', b, off)
        off += 8
        ch = b[off:off + clen]
        off += clen
        if ctype == 0x4E4F534A:
            js = json.loads(ch.decode('utf-8'))
        elif ctype == 0x004E4942:
            bn = ch
    return js, bn


def _acc(js, bn, i):
    a = js['accessors'][i]
    if 'sparse' in a:
        raise ValueError('sparse accessors are not supported by the direct reader (use --via blender)')
    bv = js['bufferViews'][a['bufferView']]
    if 'extensions' in bv:
        raise ValueError('compressed buffer views are not supported by the direct reader (use --via blender)')
    dt = np.dtype(_CT[a['componentType']]).newbyteorder('<')
    nc = _NC[a['type']]
    start = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = bv.get('byteStride') or dt.itemsize * nc
    arr = np.ndarray(shape=(a['count'], nc), dtype=dt, buffer=bn, offset=start, strides=(stride, dt.itemsize))
    out = np.array(arr)
    if a.get('normalized') and np.issubdtype(dt, np.integer):
        out = out.astype(float) / np.iinfo(dt).max
    return out


def _qmat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def _local(n):
    if 'matrix' in n:
        return np.array(n['matrix'], float).reshape(4, 4).T
    M = np.eye(4)
    M[:3, :3] = _qmat(n.get('rotation', [0, 0, 0, 1])) @ np.diag(n.get('scale', [1, 1, 1]))
    M[:3, 3] = n.get('translation', [0, 0, 0])
    return M


def load_glb(path, select=None, exclude=None):
    """GLB: every triangle primitive of every mesh node in the default scene whose 'node|mesh' name matches select
    (and not exclude);
    node world transforms applied; raw indices kept per primitive for the OGT read-back; skins give the rig (joint node
    world positions) and the dominant joint per vertex."""
    js, bn = read_glb(path)
    nodes = js.get('nodes', [])
    W = {}
    sc = js['scenes'][js.get('scene', 0)]

    def walk(i, M):
        Mi = M @ _local(nodes[i])
        W[i] = Mi
        for c in nodes[i].get('children', []):
            walk(c, Mi)
    for rt in sc['nodes']:
        walk(rt, np.eye(4))
    P, prims, names, vdom = [], [], [], []
    base = 0
    for ni, n in enumerate(nodes):
        if 'mesh' not in n or ni not in W:
            continue
        mesh = js['meshes'][n['mesh']]
        nm = n.get('name', '') + '|' + mesh.get('name', '')
        names.append(nm)
        if select is not None and not re.search(select, nm):
            continue
        if exclude and re.search(exclude, nm, re.IGNORECASE):
            continue
        M = W[ni]
        skin = js['skins'][n['skin']] if 'skin' in n and js.get('skins') else None
        for pi, pr in enumerate(mesh['primitives']):
            if pr.get('mode', 4) != 4:
                continue
            pos = _acc(js, bn, pr['attributes']['POSITION']).astype(float)
            pw = (np.c_[pos, np.ones(len(pos))] @ M.T)[:, :3]
            idx = _acc(js, bn, pr['indices']).reshape(-1) if 'indices' in pr else np.arange(len(pos))
            T = idx.reshape(-1, 3).astype(np.int64)
            dom = [''] * len(pos)
            if skin and 'JOINTS_0' in pr['attributes'] and 'WEIGHTS_0' in pr['attributes']:
                jj = _acc(js, bn, pr['attributes']['JOINTS_0']).astype(np.int64)
                ww = _acc(js, bn, pr['attributes']['WEIGHTS_0']).astype(float)
                k = np.argmax(ww, axis=1)
                jn = [nodes[j].get('name', 'joint%d' % j) for j in skin['joints']]
                dom = [jn[jj[i, k[i]]] if ww[i, k[i]] > 0 else '' for i in range(len(pos))]
            prims.append(dict(node=nm, prim=pi, T=T, base=base, n=len(pos), neg_det=bool(np.linalg.det(M[:3, :3]) < 0)))
            P.append(pw)
            vdom += dom
            base += len(pos)
    if not P:
        raise ValueError('no triangle primitive matches %r in %s (nodes: %s)' % (select, path, names[:20]))
    V = y_up_to_z_up(np.vstack(P))
    faces = [tuple(int(v) for v in (t + p['base'])) for p in prims for t in p['T']]
    rig = None
    if js.get('skins'):
        # D17: the bind-pose joints, in the frame of the vertices they were bound to: mesh-node world @ inverse(IBM_j).
        # The scene pose of the joint nodes can differ from the bind pose (S07: 0.83 m), so it is used only without IBMs.
        rig = {}
        skin_world = {}
        for ni, n in enumerate(nodes):
            if 'skin' in n and 'mesh' in n and ni in W:
                skin_world.setdefault(n['skin'], W[ni])
        for si, sk in enumerate(js['skins']):
            ibm = None
            if 'inverseBindMatrices' in sk:
                ibm = _acc(js, bn, sk['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)
            for k, j in enumerate(sk['joints']):
                name = nodes[j].get('name', 'joint%d' % j)
                if ibm is not None and si in skin_world:
                    p = (skin_world[si] @ np.linalg.inv(ibm[k]))[:3, 3]
                elif j in W:
                    p = W[j][:3, 3]
                else:
                    continue
                rig.setdefault(name, y_up_to_z_up(np.asarray(p)[None])[0].tolist())
    d = dict(V=V, faces=faces, prims=prims, rig=rig, vgroup_dom=vdom if any(vdom) else None, wire_edges=0,
             source=dict(path=os.path.basename(path), format='glb', selected=[p['node'] + '#%d' % p['prim'] for p in prims],
                         nodes=names))
    ogt_faces, ogt = ogt_read_back(V, prims)
    d['ogt'] = ogt
    if ogt_faces is not None:
        d['ogt_faces'] = ogt_faces
    return d


# ---------------------------------------------------------------------------------------------------------------- D14 OGT
def fan_runs(T):
    """D14: fan runs in file order on RAW indices: triangle k+1 continues the run when it shares the run's first corner
    and its second corner is triangle k's third corner. Returns [(polygon, triangle ids)]."""
    runs = []
    i, n = 0, len(T)
    while i < n:
        s = i
        poly = [int(T[i][0]), int(T[i][1]), int(T[i][2])]
        ti = [i]
        j = i + 1
        while j < n and T[j][0] == T[s][0] and T[j][1] == T[j - 1][2]:
            poly.append(int(T[j][2]))
            ti.append(j)
            j += 1
        runs.append((poly, ti))
        i = j
    return runs


def strict_pair_share(prims):
    ok = tot = 0
    for p in prims:
        T = p['T']
        for k in range(0, len(T) - 1, 2):
            tot += 1
            ok += len(set(T[k].tolist()) & set(T[k + 1].tolist())) == 2
    return ok / max(1, tot)


def ogt_read_back(V, prims, weld_rel=None):
    """D14: source polygons from the triangle order. Runs are cut on raw indices; a run of even length > 2 is split into
    consecutive pairs (quads) when its polygon repeats a WELDED vertex or when its primitive is a pure quad stream (every
    strict pair (0,1), (2,3), ... shares an edge). A remaining six-sided run is ambiguous (a hexagon or two quads fanned
    from one corner); it is read as two quads (a,b,c,d) + (a,d,e,f) and counted. Other runs are polygons.
    Returns (polygons over raw ids or None, report)."""
    import toplib as TL
    share = strict_pair_share(prims)
    rep = dict(method='fan runs on raw glTF indices (D14)', strict_pair_share=round(share, 4),
               used=bool(share >= OGT_MIN_PAIR_SHARE), min_pair_share=OGT_MIN_PAIR_SHARE)
    if share < OGT_MIN_PAIR_SHARE:
        rep['skipped'] = 'triangle order not preserved'
        return None, rep
    rel = TL.WELD_REL if weld_rel is None else weld_rel
    wid, _ = TL.weld_map(V, rel * TL.bbox_diag(V))
    polys = []
    split_repeat = split_pure = amb6 = 0
    for p in prims:
        T = p['T']
        ok = sum(1 for k in range(0, len(T) - 1, 2) if len(set(T[k].tolist()) & set(T[k + 1].tolist())) == 2)
        pure = len(T) % 2 == 0 and ok == len(T) // 2
        for poly, ti in fan_runs(T):
            pw = [int(wid[v + p['base']]) for v in poly]
            L = len(ti)
            rep_v = len(set(pw)) < len(pw)
            if L > 2 and L % 2 == 0 and (rep_v or pure):
                if rep_v:
                    split_repeat += 1
                else:
                    split_pure += 1
                for k in range(0, L, 2):
                    a, b = T[ti[k]], T[ti[k + 1]]
                    polys.append(tuple(int(x) + p['base'] for x in (a[0], a[1], a[2], b[2])))
            elif len(poly) == 6 and not rep_v:
                # an unsplit six-run: read as the two quads (a,b,c,d) + (a,d,e,f) of a fan triangulated from one corner
                amb6 += 1
                a, b, c, d_, e, g = (int(x) + p['base'] for x in poly)
                polys += [(a, b, c, d_), (a, d_, e, g)]
            else:
                polys.append(tuple(int(x) + p['base'] for x in poly))
    hist = {}
    for q in polys:
        hist[len(q)] = hist.get(len(q), 0) + 1
    rep.update(polygons=len(polys), sides_hist={str(k): hist[k] for k in sorted(hist)}, split_repeat_vertex=split_repeat,
               split_pure_quad_stream=split_pure, ambiguous_six_runs=amb6)
    return polys, rep


def six_runs_as_pairs(faces):
    """the alternative OGT reading: every hexagon run read as two quads (a,b,c,d) + (a,d,e,f)."""
    out = []
    for f in faces:
        if len(f) == 6:
            a, b, c, d, e, g = f
            out += [(a, b, c, d), (a, d, e, g)]
        else:
            out.append(tuple(f))
    return out


# ---------------------------------------------------------------------------------------------------------------- NPZ
def load_npz(path):
    z = np.load(path, allow_pickle=False)
    V = np.asarray(z['V'], float)
    if 'F' in z and 'off' in z:
        F, off = z['F'], z['off']
        faces = [tuple(int(x) for x in F[off[i]:off[i + 1]]) for i in range(len(off) - 1)]
    elif 'F' in z and 'foff' in z:
        F, off = z['F'], z['foff']
        faces = [tuple(int(x) for x in F[off[i]:off[i + 1]]) for i in range(len(off) - 1)]
    elif 'T' in z:
        faces = [tuple(int(x) for x in t) for t in z['T']]
    else:
        raise ValueError('npz needs V and F+off, F+foff or T: %s' % path)
    rig = None
    if 'bone_names' in z and 'bone_heads' in z:
        rig = {str(n): np.asarray(p, float).tolist() for n, p in zip(z['bone_names'], z['bone_heads'])}
    vdom = [str(x) for x in z['vdom']] if 'vdom' in z else None
    return dict(V=V, faces=faces, rig=rig, vgroup_dom=vdom if vdom and any(vdom) else None, wire_edges=0,
                source=dict(path=os.path.basename(path), format='npz'))


def save_npz(path, V, faces, **extra):
    flat = np.array([i for f in faces for i in f], dtype=np.int64)
    off = np.cumsum([0] + [len(f) for f in faces]).astype(np.int64)
    np.savez_compressed(path, V=np.asarray(V, float), F=flat, off=off, **extra)


# ---------------------------------------------------------------------------------------------------------------- Blender adapter
def blender_exe(explicit=None, local_config=None):
    if BE is None:
        return explicit if explicit and os.path.isfile(explicit) else None
    return BE.find_blender(explicit, local_config)


def run_blender(args, blend=None, exe=None, local_config=None, log=None):
    """background Blender with factory startup and autoexec disabled; tl_blender.py is the script."""
    exe = blender_exe(exe, local_config)
    if not exe:
        raise RuntimeError('MISSING Blender: pass --blender EXE, set BLENDER, or put blender on PATH')
    cmd = [exe, '-b', '--factory-startup', '--disable-autoexec']
    if blend:
        cmd.append(str(blend))
    cmd += ['--python-exit-code', '2', '--python', str(HERE / 'tl_blender.py'), '--'] + [str(a) for a in args]
    res = subprocess.run(cmd, capture_output=True, text=True, errors='replace')
    if log:
        with open(log, 'a', encoding='utf-8') as fh:
            fh.write(' '.join(cmd) + '\n' + res.stdout[-20000:] + '\n' + res.stderr[-5000:] + '\n')
    if res.returncode != 0:
        tail = (res.stdout + res.stderr)[-3000:]
        raise RuntimeError('Blender failed (exit %d): %s' % (res.returncode, tail))
    return res


def load_blend(path, select=None, collection=None, exclude=None, exe=None, local_config=None, log=None):
    """.blend: the base cage (mesh data, modifiers off) of the matching mesh objects in world space. Background Blender
    (--factory-startup --disable-autoexec) APPENDS only the selected objects or the named collection from the file -
    the file itself is never opened, so excluded assets of a mixed file are never loaded; nothing is saved."""
    if not select and not collection:
        raise ValueError('a .blend needs --select REGEX or --collection NAME (the file is never loaded whole)')
    tmp = tempfile.mkdtemp(prefix='cta_blend_')
    out = os.path.join(tmp, 'cage.npz')
    args = ['append', path, out]
    if select:
        args += ['--select', select]
    if collection:
        args += ['--collection', collection]
    if exclude:
        args += ['--exclude', exclude]
    run_blender(args, exe=exe, local_config=local_config, log=log)
    d = load_npz(out)
    meta = json.load(open(out + '.json'))
    d['source'] = dict(path=os.path.basename(path), format='blend', objects=meta['objects'], cage='modifiers off',
                       route='appended, file not opened')
    return d


def blend_names(path, exclude=None, exe=None, local_config=None, log=None):
    """collection and object names of a .blend (library directory only, nothing loaded; excluded names left out)."""
    tmp = tempfile.mkdtemp(prefix='cta_names_')
    out = os.path.join(tmp, 'names.json')
    args = ['names', path, out] + (['--exclude', exclude] if exclude else [])
    run_blender(args, exe=exe, local_config=local_config, log=log)
    return json.load(open(out))


def load_via_blender(path, select=None, exclude=None, exe=None, local_config=None, log=None):
    tmp = tempfile.mkdtemp(prefix='cta_imp_')
    out = os.path.join(tmp, 'imp.npz')
    args = ['import', path, out]
    if select:
        args += ['--select', select]
    if exclude:
        args += ['--exclude', exclude]
    run_blender(args, exe=exe, local_config=local_config, log=log)
    d = load_npz(out)
    meta = json.load(open(out + '.json'))
    d['source'] = dict(path=os.path.basename(path), format=Path(path).suffix.lstrip('.') + ' via Blender importer',
                       objects=meta['objects'])
    return d


def tris_to_quads(V, tris, exe=None, local_config=None, log=None):
    """D15: Blender's Tris to Quads (bmesh join_triangles, 180 deg / 180 deg, topology influence 1.15, no seam/sharp/
    UV/colour/material compare) on the given triangles AFTER the face normals are computed. Returns polygons."""
    tmp = tempfile.mkdtemp(prefix='cta_t2q_')
    inp, out = os.path.join(tmp, 'in.npz'), os.path.join(tmp, 'out.npz')
    save_npz(inp, V, tris)
    run_blender(['t2q', inp, out], exe=exe, local_config=local_config, log=log)
    z = np.load(out)
    F, off = z['F'], z['off']
    return [tuple(int(x) for x in F[off[i]:off[i + 1]]) for i in range(len(off) - 1)], json.load(open(out + '.json'))


# ---------------------------------------------------------------------------------------------------------------- front door
def load(path, select=None, group=None, up=None, rot=None, joints_from_groups=None, collection=None, via=None,
         blender=None, local_config=None, need_t2q=False, log=None, exclude=None):
    """the front door: one loader per format (module docstring); exclude = regex of object / node / group / collection
    names that are never loaded (e.g. the registry's excluded assets of a mixed bundle)."""
    ext = Path(path).suffix.lower()
    if via == 'blender' and ext != '.blend':
        d = load_via_blender(path, select, exclude, blender, local_config, log)
    elif ext == '.obj':
        d = load_obj(path, group=group, select=select, up=up or 'y', joints_from_groups=joints_from_groups, exclude=exclude)
    elif ext == '.glb':
        d = load_glb(path, select=select, exclude=exclude)
    elif ext == '.npz':
        d = load_npz(path)
        if up == 'y':
            d['V'] = y_up_to_z_up(d['V'])
    elif ext == '.blend':
        d = load_blend(path, select=select, collection=collection, exclude=exclude, exe=blender,
                       local_config=local_config, log=log)
    else:
        d = load_via_blender(path, select, exclude, blender, local_config, log)
    d = apply_rot(d, rot)
    if need_t2q:
        add_t2q(d, exe=blender, local_config=local_config, log=log)
    return d


def add_t2q(d, exe=None, local_config=None, log=None):
    """weld + clean the loaded triangles (D2, D3), then Tris to Quads (D15). Polygons are first cut into fans so a
    mixed mesh is judged from its triangles."""
    import toplib as TL
    tris = []
    for f in d['faces']:
        for k in range(1, len(f) - 1):
            tris.append((f[0], f[k], f[k + 1]))
    WV, WF, wrep, _ = TL.weld_and_clean(d['V'], tris)
    faces, meta = tris_to_quads(WV, WF, exe=exe, local_config=local_config, log=log)
    d['t2q_V'], d['t2q_faces'], d['t2q'] = WV, faces, meta
    return d


def add_load_args(ap):
    ap.add_argument('mesh')
    ap.add_argument('--select', help='regex: GLB "node|mesh" names, .blend object names, OBJ group names')
    ap.add_argument('--exclude', help='regex of names never loaded (objects, nodes, groups, .blend collections)')
    ap.add_argument('--group', help='OBJ: exact group name')
    ap.add_argument('--collection', help='.blend: collection name')
    ap.add_argument('--up', choices=['y', 'z'], help='OBJ / NPZ up axis (OBJ default y)')
    ap.add_argument('--rot', help='RX,RY,RZ degrees applied after the up conversion')
    ap.add_argument('--joints-from-groups', help='OBJ: groups with this prefix are joints (mean of their vertices)')
    ap.add_argument('--via', choices=['direct', 'blender'], default='direct')
    ap.add_argument('--blender', help='Blender executable (else BLENDER, PATH, standard folder)')
    ap.add_argument('--local-config', help='local tool-path JSON (tools.blender.path)')


def load_from_args(a, need_t2q=False):
    rot = [float(x) for x in a.rot.split(',')] if a.rot else None
    return load(a.mesh, select=a.select, group=a.group, up=a.up, rot=rot, joints_from_groups=a.joints_from_groups,
                collection=a.collection, via=a.via, blender=a.blender, local_config=a.local_config, need_t2q=need_t2q,
                exclude=a.exclude)
