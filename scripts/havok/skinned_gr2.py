"""Donor-preserving writer for NEW skinned unit geometry (AoE3 DE .gr2, the vanilla 40-byte skinned vertex).

    python scripts/havok/skinned_gr2.py DONOR.gr2 MODEL.gxo OUT.gr2 [--json REPORT.json]
           [--scale 1.0] [--material GXO_NAME=RUNTIME_NAME ...] [--mesh-name GXO_NAME=NAME ...]
           [--texture RUNTIME_NAME=TEXTURE_NAME ...] [--blender EXE] [--no-recheck] [--overwrite]
    python scripts/havok/skinned_gr2.py --prove-clean DONOR.gr2 OUT.gr2      # donor data left in OUT? exit 1 if any

Input: MODEL.gxo written from the working scene by `rig_table.py --skinned --quantize` at --scale 1 (the armature
space of a donor_to_blend.py scene = the GXO frame in engine units; aoe3de-unit-model export-routes.md). One material
per mesh. DONOR.gr2: an uncompressed 64-bit vanilla skinned model whose skeleton the clips drive (e.g. iron_rider_0).

What the output holds (a new file, every object written fresh; nothing is appended to the donor):
- the donor's skeleton BYTE FOR BYTE (bone records copied verbatim: names, parents, order, Transform, InverseWorld,
  LODError), its ArtToolInfo / ExporterInfo / root ExtendedData (basis, units), the donor's type definitions verbatim
  (section 6 in a standard Granny layout), the donor model's name and InitialPlacement;
- our meshes only: the vanilla skinned vertex type of the donor (Position real32x3 @0, Normal binormal_int8x4 @12,
  Tangent binormal_int8x4 @16, DiffuseColor0 normal_uint8x4 @20, TextureCoordinates0 real32x2 @24, BoneWeights
  normal_uint8x4 @32, BoneIndices uint8x4 @36; refused if the donor's differs) with the DE full-LOD fill: colour
  (255,255,255,255), Normal.w 127, Tangent.w +-127 = the MikkTSpace bitangent sign;
- tangents: MikkTSpace (Blender's Mesh.calc_tangents, run headless) on the FINAL serialized data - stored triangles,
  the int8 normals as stored, the raw stored UVs - per corner; a vertex whose corners get different tangent frames is
  split (a tangent-only split, as vanilla buffers have); vertex data in section 3 (deformable vertices) with one
  marshalling record per array, int32 indices in section 4, metadata and strings in section 0;
- weights exactly as the GXO's 8-bit values (the generic recipe: sum 255, descending, no bone twice, unused slots
  repeat slot 0's index; a non-quantized GXO is refused); BoneIndices index the mesh's own BoneBindings palette (the
  GXO `mb` list), bound to the skeleton BY NAME; bone-local OBBs from the vertices each bone weights (the vanilla rule,
  reproduced on iron_rider_0 at 4e-7);
- one material per mesh named as the runtime .material submaterial (default: the GXO `mt` name), with a colour map
  and a texture record named by --texture (default <material>_BaseColor) - the vanilla shape, our names;
- frame: GXO (x across, y along, z up) -> engine (x, y up, z) = (-x, z, -y) times --scale; the map mirrors, so every
  triangle's corner order is reversed; V flipped once (gr2_uv_convention.blender_to_gr2_uv) before the tangents.
- uncompressed; every pointer fixup reachable from the root (0 orphans by construction, checked: INC-187/INC-203).

Checks after writing (in the report; a failing check raises): CRC, the repo reader reopens the file, skeleton bone
records byte-identical to the donor's, vertex type identical to the donor's, vertex and index bytes equal what was
packed, materials / palettes / triangle counts, 0 orphan fixups, the winding of >= 97 % of the face area along the
stored normals, MikkTSpace recomputed on the written file against the stored tangents (median dot, sign agreement),
and prove_clean: no donor vertex record, position, index run, mesh / material / texture name or source path in OUT.
The game's own DLL read is NOT here: run gr2_lint (dll_read) and the unit ladder (aoe3de-unit-model export-routes.md
section 7) on the output.

Blender: --blender, else env BLENDER, else config/tool-paths.local.json tools.blender.path. Without Blender the
writer stops (no silent fallback to another tangent rule); tests inject their own tangent function.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
from gr2_read import (Gr2, MAGIC64, T_ARRAY_OF_REFS, T_EMPTY_REF, T_INLINE, T_REF,  # noqa: E402
                      T_REF_TO_ARRAY, T_REF_TO_VARIANT_ARRAY, T_STRING, T_TRANSFORM, T_VARIANT_REF)
from gr2_dump import refs  # noqa: E402

REPO = HERE.parents[1]
P = 8
STRIDE = 40
VANILLA_LAYOUT = [('Position', 10, 3, 0), ('Normal', 13, 4, 12), ('Tangent', 13, 4, 16), ('DiffuseColor0', 14, 4, 20),
                  ('TextureCoordinates0', 10, 2, 24), ('BoneWeights', 14, 4, 32), ('BoneIndices', 12, 4, 36)]
SEC_MAIN, SEC_VERTEX, SEC_INDEX, SEC_TYPES, N_SEC = 0, 3, 4, 6, 8      # Granny's standard sections
A = np.array([[-1.0, 0, 0], [0, 0, -1.0], [0, 1.0, 0]])               # engine row vector = gxo @ A (det -1)
SCALAR = {10: ('f', 4), 19: ('i', 4), 20: ('I', 4), 15: ('h', 2), 16: ('H', 2), 17: ('h', 2), 18: ('H', 2),
          21: ('e', 2), 11: ('b', 1), 12: ('B', 1), 13: ('b', 1), 14: ('B', 1)}
TANGENT_SAME = 0.9999          # corners of one vertex whose MikkTSpace tangents agree this well share it
WINDING_MIN = 0.97


class WriteError(Exception):
    pass


# --------------------------------------------------------------------------------------------------- GXO input
def parse_gxo(path):
    """rig_table --skinned GXO -> {materials, bones [names], meshes [{name, mb, mm, v, vn, vt, vw, faces [(fg, a, b,
    c) 0-based]}]}"""
    out = dict(materials=[], bones=[], meshes=[])
    cur, fg = None, 1
    for line in open(path, encoding='utf-8', errors='replace'):
        t = line.split()
        if not t:
            continue
        k = t[0]
        if k == 'mt':
            out['materials'].append(line.split('"')[1])
        elif k == 'b':
            rest = line.split('"')[2].split()
            out['bones'].append(line.split('"')[1])
            out.setdefault('bone_t', []).append([float(x) for x in rest[10:13]])
        elif k == 'm':
            cur = dict(name=line.split('"')[1], mb=[], mm=[], v=[], vn=[], vt=[], vw=[], faces=[])
            out['meshes'].append(cur)
            fg = 1
        elif cur is None:
            continue
        elif k == 'mb':
            cur['mb'].append(line.split('"')[1])
        elif k == 'mm':
            cur['mm'].append(int(t[1]))
        elif k == 'v':
            cur['v'].append([float(x) for x in t[1:4]])
        elif k == 'vn':
            cur['vn'].append([float(x) for x in t[1:4]])
        elif k == 'vt':
            cur['vt'].append([float(x) for x in t[1:3]])
        elif k == 'vw':
            cur['vw'].append([float(x) for x in t[1:9]])
        elif k == 'fg':
            fg = int(t[1])
        elif k == 'f':
            cur['faces'].append((fg, int(t[1]) - 1, int(t[2]) - 1, int(t[3]) - 1))
    return out


class MeshIn:
    """one skinned mesh in the engine frame, ready to pack (tangents filled by assign_tangents)."""

    def __init__(self, name, material, bones, pos, nrm, uv, w, bi, tris, tan=None):
        self.name, self.material, self.bones = name, material, list(bones)
        self.pos = np.asarray(pos, np.float32).reshape(-1, 3)
        self.nrm = np.asarray(nrm, np.int8).reshape(-1, 4)            # int8 x 4, w = 127
        self.uv = np.asarray(uv, np.float32).reshape(-1, 2)            # raw gr2 convention
        self.w = np.asarray(w, np.uint8).reshape(-1, 4)
        self.bi = np.asarray(bi, np.uint8).reshape(-1, 4)
        self.tris = np.asarray(tris, np.int64).reshape(-1, 3)
        self.tan = None if tan is None else np.asarray(tan, np.int8).reshape(-1, 4)

    @property
    def n(self):
        return len(self.pos)


def quantize_normals(n):
    n = np.asarray(n, float)
    n = n / np.maximum(np.linalg.norm(n, axis=1), 1e-12)[:, None]
    out = np.zeros((len(n), 4), np.int8)
    out[:, :3] = np.clip(np.rint(n * 127.0), -127, 127)
    out[:, 3] = 127
    return out


def check_weights(w, bi, palette_size, where):
    """the 8-bit weight convention (export-routes.md section 1); raises WriteError naming the first offence."""
    w, bi = np.asarray(w, int), np.asarray(bi, int)
    bad = np.where(w.sum(1) != 255)[0]
    if len(bad):
        raise WriteError('%s: vertex %d weights sum to %d, not 255' % (where, bad[0], w[bad[0]].sum()))
    bad = np.where((w[:, :-1] < w[:, 1:]).any(1))[0]
    if len(bad):
        raise WriteError('%s: vertex %d weights not in descending order %s' % (where, bad[0], w[bad[0]].tolist()))
    for i in range(len(w)):
        used = [int(b) for x, b in zip(w[i], bi[i]) if x > 0]
        if len(used) != len(set(used)):
            raise WriteError('%s: vertex %d names a bone twice %s' % (where, i, bi[i].tolist()))
        if any(b >= palette_size for b in used):
            raise WriteError('%s: vertex %d indexes past its palette of %d bones' % (where, i, palette_size))
        if any(bi[i, k] != bi[i, 0] for k in range(4) if w[i, k] == 0):
            raise WriteError('%s: vertex %d: an unused slot does not repeat slot 0\'s index %s' % (where, i,
                                                                                                 bi[i].tolist()))


def from_gxo(gxo, scale=1.0, material_names=None, mesh_names=None):
    """parsed GXO -> [MeshIn] in the engine frame (no tangents yet)."""
    material_names, mesh_names = material_names or {}, mesh_names or {}
    out = []
    for m in gxo['meshes']:
        where = 'mesh %s' % m['name']
        n = len(m['v'])
        if not n or not m['faces']:
            raise WriteError('%s: no vertices or faces' % where)
        if not (len(m['vn']) == len(m['vt']) == len(m['vw']) == n):
            raise WriteError('%s: v/vn/vt/vw counts differ (%d/%d/%d/%d): write it with rig_table.py --skinned'
                             % (where, n, len(m['vn']), len(m['vt']), len(m['vw'])))
        mats = sorted(set(m['mm']))
        if len(mats) != 1 or len({f[0] for f in m['faces']}) != 1:
            raise WriteError('%s: %d materials / face groups - one material per mesh (split the mesh)' %
                             (where, len(mats)))
        mat = gxo['materials'][mats[0] - 1]
        vw = np.asarray(m['vw'], float)
        q = vw[:, :4] * 255.0
        if np.abs(q - np.rint(q)).max() > 2e-3:
            raise WriteError('%s: weights are not k/255 (max off %.4f units): write the GXO with rig_table.py '
                             '--quantize (the generic recipe)' % (where, np.abs(q - np.rint(q)).max()))
        w = np.rint(q).astype(int)
        bi = vw[:, 4:].astype(int) - 1
        if (bi < 0).any():
            raise WriteError('%s: a vw bone index is below 1' % where)
        check_weights(w, bi, len(m['mb']), where)
        pos = (np.asarray(m['v'], float) @ A) * scale
        nrm = np.asarray(m['vn'], float) @ A
        uv = np.asarray(m['vt'], float).copy()
        uv[:, 1] = 1.0 - uv[:, 1]                                     # gr2_uv_convention.blender_to_gr2_uv
        tris = np.asarray([(a, c, b) for _, a, b, c in m['faces']], np.int64)   # mirror map: reverse corners
        if tris.max() >= n:
            raise WriteError('%s: a face indexes past the vertices' % where)
        out.append(MeshIn(mesh_names.get(m['name'], m['name']), material_names.get(mat, mat), m['mb'], pos,
                          quantize_normals(nrm), uv, w, bi, tris))
    return out


# ---------------------------------------------------------------------------------------------------- tangents
def stored_normals(mesh):
    n = mesh.nrm[:, :3].astype(float) / 127.0
    return n / np.maximum(np.linalg.norm(n, axis=1), 1e-12)[:, None]


def find_blender(explicit=None):
    for c in (explicit, os.environ.get('BLENDER')):
        if c and Path(c).is_file():
            return str(c)
    cfg = REPO / 'config' / 'tool-paths.local.json'
    try:
        p = json.loads(cfg.read_text(encoding='utf-8'))['tools']['blender']['path']
        if p and Path(p).is_file():
            return p
    except (OSError, KeyError, ValueError, TypeError):
        pass
    return None


def mikktspace(meshes, blender=None, workdir=None):
    """MikkTSpace per corner on the final data of each mesh, in background Blender -> [(T (M,3,3), S (M,3))]."""
    exe = find_blender(blender)
    if not exe:
        raise WriteError('Blender not found (--blender, env BLENDER, config/tool-paths.local.json tools.blender.path): '
                         'MikkTSpace tangents need it; no other tangent rule is substituted')
    own = None
    if workdir is None:
        own = tempfile.TemporaryDirectory(prefix='skinned_gr2_mikk_')
        workdir = own.name
    try:
        src, dst = Path(workdir) / 'mikk_in.npz', Path(workdir) / 'mikk_out.npz'
        arrays = {'count': np.array(len(meshes))}
        for k, m in enumerate(meshes):
            arrays.update({'P%d' % k: m.pos.astype(np.float64), 'N%d' % k: stored_normals(m),
                           'UV%d' % k: m.uv.astype(np.float64), 'I%d' % k: m.tris})
        np.savez(src, **arrays)
        r = subprocess.run([exe, '-b', '--factory-startup', '--python-exit-code', '2', '--python', str(Path(__file__)),
                            '--', '--mikk', str(src), str(dst)], capture_output=True, text=True, timeout=600)
        if r.returncode != 0 or not dst.exists():
            raise WriteError('Blender MikkTSpace run failed (rc %s): %s' % (r.returncode, (r.stdout + r.stderr)[-800:]))
        with np.load(dst) as d:                                # closes the file (Windows cannot delete it open)
            return [(d['T%d' % k].copy(), d['S%d' % k].copy()) for k in range(len(meshes))]
    finally:
        if own is not None:
            own.cleanup()


def _blender_mikk(src, dst):
    """inside Blender: build each mesh from the final arrays, stored normals as custom normals, raw UVs, MikkTSpace."""
    import bpy
    with np.load(src) as f:
        d = {k: f[k].copy() for k in f.files}
    res = {}
    for k in range(int(d['count'])):
        Pk, Nk, UVk, Ik = d['P%d' % k], d['N%d' % k], d['UV%d' % k], d['I%d' % k]
        me = bpy.data.meshes.new('mikk%d' % k)
        me.from_pydata(Pk.tolist(), [], Ik.tolist())
        if len(me.polygons) != len(Ik) or len(me.loops) != 3 * len(Ik):
            raise SystemExit('mesh %d: Blender built %d faces / %d loops for %d triangles' % (k, len(me.polygons),
                                                                                         len(me.loops), len(Ik)))
        uvl = me.uv_layers.new(name='UV')
        normals = []
        for poly in me.polygons:
            for li in poly.loop_indices:
                vi = me.loops[li].vertex_index
                uvl.data[li].uv = (float(UVk[vi, 0]), float(UVk[vi, 1]))
                normals.append(tuple(float(x) for x in Nk[vi]))
            poly.use_smooth = True
        me.normals_split_custom_set(normals)
        me.calc_tangents(uvmap='UV')
        T = np.zeros((len(Ik), 3, 3))
        S = np.zeros((len(Ik), 3))
        for fi, poly in enumerate(me.polygons):
            verts = list(poly.vertices)
            if verts != [int(x) for x in Ik[fi]]:
                raise SystemExit('mesh %d face %d: corner order changed %s -> %s' % (k, fi, Ik[fi].tolist(), verts))
            for c, li in enumerate(poly.loop_indices):
                lp = me.loops[li]
                T[fi, c] = tuple(lp.tangent)
                S[fi, c] = lp.bitangent_sign
        res['T%d' % k], res['S%d' % k] = T, S
        bpy.data.meshes.remove(me)
    np.savez(dst, **res)


def uv_tangents(meshes):
    """the per-triangle +dU tangent orthogonalised to the stored normal, sign from the UV handedness (NOT MikkTSpace:
    tests only, injected through build(tangent_fn=...))."""
    out = []
    for m in meshes:
        N = stored_normals(m)
        T = np.zeros((len(m.tris), 3, 3))
        S = np.ones((len(m.tris), 3))
        for f, (a, b, c) in enumerate(m.tris):
            p0, p1, p2 = m.pos[[a, b, c]].astype(float)
            u0, u1, u2 = m.uv[[a, b, c]].astype(float)
            e1, e2, d1, d2 = p1 - p0, p2 - p0, u1 - u0, u2 - u0
            det = d1[0] * d2[1] - d2[0] * d1[1]
            t = (e1 * d2[1] - e2 * d1[1]) / (det if abs(det) > 1e-12 else 1e-12)
            bvec = (e2 * d1[0] - e1 * d2[0]) / (det if abs(det) > 1e-12 else 1e-12)
            for ci, v in enumerate((a, b, c)):
                tt = t - N[v] * np.dot(N[v], t)
                tt /= np.linalg.norm(tt) or 1.0
                T[f, ci] = tt
                S[f, ci] = 1.0 if np.dot(np.cross(N[v], tt), bvec) >= 0 else -1.0
        out.append((T, S))
    return out


def assign_tangents(mesh, T, S, same=TANGENT_SAME):
    """per-corner tangents -> per-vertex int8 tangents; a vertex whose corners disagree (sign, or dot < same) is split.
    Returns (new MeshIn, tangent-only splits)."""
    groups = {}
    for f in range(len(mesh.tris)):
        for c in range(3):
            groups.setdefault(int(mesh.tris[f, c]), []).append((f, c))
    unused = sorted(set(range(mesh.n)) - set(groups))
    if unused:
        raise WriteError('mesh %s: %d vertices are in no triangle (first %s)' % (mesh.name, len(unused), unused[:5]))
    src = list(range(mesh.n))
    tangents = [None] * mesh.n
    tris = mesh.tris.copy()
    splits = 0
    for v in range(mesh.n):
        clusters = []                                          # [sign, [vectors], [(f, c)]]
        for f, c in groups[v]:
            t = np.asarray(T[f, c], float)
            t /= np.linalg.norm(t) or 1.0
            s = 1.0 if S[f, c] >= 0 else -1.0
            for cl in clusters:
                if cl[0] == s and np.dot(cl[1][0], t) >= same:
                    cl[1].append(t)
                    cl[2].append((f, c))
                    break
            else:
                clusters.append([s, [t], [(f, c)]])
        for k, (s, vecs, corners) in enumerate(clusters):
            mean = np.sum(vecs, axis=0)
            mean /= np.linalg.norm(mean) or 1.0
            q = np.zeros(4, np.int8)
            q[:3] = np.clip(np.rint(mean * 127.0), -127, 127)
            q[3] = 127 if s > 0 else -127
            if k == 0:
                tangents[v] = q
                continue
            splits += 1
            src.append(v)
            tangents.append(q)
            for f, c in corners:
                tris[f, c] = len(src) - 1
    src = np.asarray(src)
    out = MeshIn(mesh.name, mesh.material, mesh.bones, mesh.pos[src], mesh.nrm[src], mesh.uv[src], mesh.w[src],
                 mesh.bi[src], tris, np.asarray(tangents, np.int8))
    zero = int((np.linalg.norm(out.tan[:, :3].astype(float), axis=1) < 0.5).sum())
    if zero:
        raise WriteError('mesh %s: %d zero tangents after MikkTSpace (degenerate UVs?)' % (mesh.name, zero))
    return out, splits


# ----------------------------------------------------------------------------------------------------- packing
def pack(mesh):
    """MeshIn -> the 40-byte vanilla skinned vertex bytes."""
    if mesh.tan is None:
        raise WriteError('mesh %s: no tangents' % mesh.name)
    r = np.zeros((mesh.n, STRIDE), np.uint8)
    r[:, 0:12] = mesh.pos.astype('<f4').view(np.uint8).reshape(mesh.n, 12)
    r[:, 12:16] = mesh.nrm.view(np.uint8)
    r[:, 16:20] = mesh.tan.view(np.uint8)
    r[:, 20:24] = 255
    r[:, 24:32] = mesh.uv.astype('<f4').view(np.uint8).reshape(mesh.n, 8)
    r[:, 32:36] = mesh.w
    r[:, 36:40] = mesh.bi
    return r.tobytes()


def winding_share(mesh):
    """face area whose winding normal agrees with the mean stored normal of its corners (gr2_lint 'winding')."""
    Pt = mesh.pos.astype(float)[mesh.tris]
    N = stored_normals(mesh)[mesh.tris].mean(1)
    fn = np.cross(Pt[:, 1] - Pt[:, 0], Pt[:, 2] - Pt[:, 0])
    area = 0.5 * np.linalg.norm(fn, axis=1)
    agree = (fn * N).sum(1) > 0
    return float(area[agree].sum() / area.sum()) if area.sum() else 0.0


# ------------------------------------------------------------------------------------------------- the writer
class Out:
    """a new gr2 built from scratch around donor objects that are copied by value (never appended in place)."""

    def __init__(self, g):
        self.g = g
        self.main = bytearray()
        self.pool = bytearray()
        self.vert = bytearray()
        self.idx = bytearray()
        self.types = bytearray()
        self.relocs = {s: [] for s in range(N_SEC)}
        self.marsh = []
        self._strings, self._str_src, self._objs, self._types = {}, {}, {}, {}
        self.type_sec_donor = g.root_type_sec
        self.verbatim = g.root_type_sec != g.root_sec and g.sec_count > g.root_type_sec
        if self.verbatim:                                      # the donor's type section, same offsets
            self.types = bytearray(g.payload[g.root_type_sec])
            for (s, o), (ts, to) in sorted(g.reloc.items()):
                if s != g.root_type_sec:
                    continue
                if ts == g.root_type_sec:
                    self.relocs[SEC_TYPES].append((o, (SEC_TYPES, to)))
                elif ts == g.root_sec:                         # member names live in the main section
                    self.relocs[SEC_TYPES].append((o, self.copy_string((ts, to))))
                else:
                    raise WriteError('donor type section points into section %d (%s): unknown layout' % (ts, (s, o)))

    # --- allocation and pointers
    def alloc(self, size, align=4):
        while len(self.main) % align:
            self.main.append(0)
        off = len(self.main)
        self.main.extend(bytes(size))
        return off

    def ptr(self, sec, at, target):
        if target is not None:
            self.relocs[sec].append((at, target))

    def string(self, text):
        if text not in self._strings:
            self._strings[text] = len(self.pool)
            self.pool.extend(text.encode('utf-8') + b'\0')
        return ('S', self._strings[text])

    def copy_string(self, loc):
        return self.string(self.g.cstr(*loc))

    def type_ref(self, tref):
        """a donor type definition in the output: the same offset (verbatim section) or a fresh copy."""
        if tref is None:
            return None
        if self.verbatim:
            if tref[0] != self.g.root_type_sec:
                raise WriteError('donor type outside its type section: %s' % (tref,))
            return (SEC_TYPES, tref[1])
        if tref in self._types:
            return self._types[tref]
        stride = 4 + P + P + 4 + 12 + P
        nmem = len(self.g.typedef(*tref)) + 1
        while len(self.types) % 4:
            self.types.append(0)
        off = len(self.types)
        self.types.extend(self.g.payload[tref[0]][tref[1]:tref[1] + nmem * stride])
        self._types[tref] = (SEC_TYPES, off)
        for i in range(nmem):
            so = tref[1] + i * stride
            name, ref = self.g.deref(tref[0], so + 4), self.g.deref(tref[0], so + 4 + P)
            if name:
                self.relocs[SEC_TYPES].append((off + i * stride + 4, self.copy_string(name)))
            if ref:
                self.relocs[SEC_TYPES].append((off + i * stride + 4 + P, self.type_ref(ref)))
        return (SEC_TYPES, off)

    # --- deep copy of donor objects (skeleton, art tool info, extended data ...)
    def copy_obj(self, tref, loc):
        key = ('o', tref, loc)
        if key in self._objs:
            return self._objs[key]
        size = self.g.struct_size(*tref)
        dst = self.alloc(size)
        self._objs[key] = (SEC_MAIN, dst)
        self.main[dst:dst + size] = self.g.payload[loc[0]][loc[1]:loc[1] + size]
        self._translate(tref, loc, dst)
        return (SEC_MAIN, dst)

    def copy_array(self, tref, loc, n):
        size = self.g.struct_size(*tref)
        dst = self.alloc(size * n)
        self.main[dst:dst + size * n] = self.g.payload[loc[0]][loc[1]:loc[1] + size * n]
        for k in range(n):
            self._translate(tref, (loc[0], loc[1] + k * size), dst + k * size)
        return (SEC_MAIN, dst)

    def _translate(self, tref, loc, dst):
        g = self.g
        sec, off = loc
        for m, mo in g.layout(*tref)[0]:
            t, so, do = m['type'], off + mo, dst + mo
            if t == T_STRING:
                p = g.deref(sec, so)
                self.ptr(SEC_MAIN, do, self.copy_string(p) if p else None)
            elif t == T_REF:
                p = g.deref(sec, so)
                if p and m['ref']:
                    self.ptr(SEC_MAIN, do, self.copy_obj(m['ref'], p))
            elif t == T_REF_TO_ARRAY:
                n, p = g.i32(sec, so), g.deref(sec, so + 4)
                if p and n > 0 and m['ref']:
                    self.ptr(SEC_MAIN, do + 4, self.copy_array(m['ref'], p, n))
            elif t == T_ARRAY_OF_REFS:
                n, p = g.i32(sec, so), g.deref(sec, so + 4)
                if p and n > 0:
                    arr = self.alloc(P * n)
                    for k in range(n):
                        q = g.deref(p[0], p[1] + k * P)
                        if q and m['ref']:
                            self.ptr(SEC_MAIN, arr + k * P, self.copy_obj(m['ref'], q))
                    self.ptr(SEC_MAIN, do + 4, (SEC_MAIN, arr))
            elif t == T_VARIANT_REF:
                tp, op = g.deref(sec, so), g.deref(sec, so + P)
                self.ptr(SEC_MAIN, do, self.type_ref(tp))
                if tp and op:
                    self.ptr(SEC_MAIN, do + P, self.copy_obj(tp, op))
            elif t == T_REF_TO_VARIANT_ARRAY:
                if g.deref(sec, so + P + 4):
                    raise WriteError('refusing to copy a donor variant array (vertex data) at %s' % (loc,))
                self.ptr(SEC_MAIN, do, self.type_ref(g.deref(sec, so)))
            elif t == T_EMPTY_REF:
                if g.deref(sec, so):
                    raise WriteError('donor object holds an empty-ref pointer at %s' % (loc,))
            elif t == T_INLINE and m['ref']:
                size = g.struct_size(*m['ref'])
                for k in range(max(m['count'], 1)):
                    self._translate(m['ref'], (sec, so + k * size), do + k * size)

    # --- new objects, set member by member on the donor's own type layout
    def obj(self, tref, values):
        dst = self.alloc(self.g.struct_size(*tref))
        self.fill(tref, dst, values)
        return (SEC_MAIN, dst)

    def fill(self, tref, dst, values):
        lay = {m['name']: (m, mo) for m, mo in self.g.layout(*tref)[0]}
        for name, v in values.items():
            if name not in lay or v is None:
                continue
            m, mo = lay[name]
            t, at = m['type'], dst + mo
            if t == T_STRING:
                self.ptr(SEC_MAIN, at, self.string(v))
            elif t in (T_REF, T_EMPTY_REF):
                self.ptr(SEC_MAIN, at, v)
            elif t == T_REF_TO_ARRAY:
                n, target = v
                struct.pack_into('<i', self.main, at, n)
                self.ptr(SEC_MAIN, at + 4, target if n else None)
            elif t == T_ARRAY_OF_REFS:
                arr = self.alloc(P * len(v)) if v else None
                for k, target in enumerate(v):
                    self.ptr(SEC_MAIN, arr + k * P, target)
                struct.pack_into('<i', self.main, at, len(v))
                self.ptr(SEC_MAIN, at + 4, (SEC_MAIN, arr) if v else None)
            elif t == T_VARIANT_REF:
                self.ptr(SEC_MAIN, at, v[0])
                self.ptr(SEC_MAIN, at + P, v[1])
            elif t == T_REF_TO_VARIANT_ARRAY:
                self.ptr(SEC_MAIN, at, v[0])
                struct.pack_into('<i', self.main, at + P, v[1])
                self.ptr(SEC_MAIN, at + P + 4, v[2])
            elif t == T_TRANSFORM:
                struct.pack_into('<I16f', self.main, at, int(v[0]), *[float(x) for x in v[1:17]])
            elif t == T_INLINE:
                self.fill(m['ref'], at, v)
            elif t in SCALAR:
                code, _ = SCALAR[t]
                vals = list(v) if isinstance(v, (list, tuple, np.ndarray)) else [v]
                struct.pack_into('<%d%s' % (len(vals), code), self.main, at, *vals)
            else:
                raise WriteError('cannot set member %s (type %d)' % (name, t))

    def array_of(self, tref, records):
        """a REF_TO_ARRAY value: n records of type tref laid out contiguously."""
        if not records:
            return (0, None)
        size = self.g.struct_size(*tref)
        dst = self.alloc(size * len(records))
        for k, rec in enumerate(records):
            self.fill(tref, dst + k * size, rec)
        return (len(records), (SEC_MAIN, dst))

    def vertices(self, raw, count, vtype):
        while len(self.vert) % 4:
            self.vert.append(0)
        off = len(self.vert)
        self.vert.extend(raw)
        self.marsh.append((count, off) + vtype)
        return (SEC_VERTEX, off)

    def indices(self, raw):
        while len(self.idx) % 4:
            self.idx.append(0)
        off = len(self.idx)
        self.idx.extend(raw)
        return (SEC_INDEX, off)

    # --- the file
    def write(self, path, root_type, root_loc):
        g = self.g
        while len(self.main) % 4:
            self.main.append(0)
        base = len(self.main)
        main = bytes(self.main) + bytes(self.pool)

        def resolve(target):
            if target[0] == 'S':
                return (SEC_MAIN, base + target[1])
            return target
        payload = {SEC_MAIN: main, SEC_VERTEX: bytes(self.vert), SEC_INDEX: bytes(self.idx),
                   SEC_TYPES: bytes(self.types)}
        firsts = {SEC_MAIN: base, SEC_INDEX: len(self.idx), SEC_TYPES: len(self.types)}
        header_size = 32 + 72 + 44 * N_SEC
        o = bytearray(header_size)
        cur = header_size
        entries = []
        blobs = []
        for s in range(N_SEC):
            data = payload.get(s, b'')
            data = data + bytes((-len(data)) % 4)
            entries.append([0, cur, len(data), len(data), 4, firsts.get(s, 0), firsts.get(s, 0), 0, 0, 0, 0])
            blobs.append(data)
            cur += len(data)
        tail = bytearray()
        for s in range(N_SEC):
            rel = sorted((at, *resolve(t)) for at, t in self.relocs[s])
            if len({r[0] for r in rel}) != len(rel):
                raise WriteError('two fixups on one pointer slot in section %d' % s)
            entries[s][7], entries[s][8] = cur + len(tail), len(rel)
            tail.extend(b''.join(struct.pack('<III', *r) for r in rel))
            marsh = self.marsh if s == SEC_VERTEX else []
            entries[s][9], entries[s][10] = cur + len(tail), len(marsh)
            tail.extend(b''.join(struct.pack('<4I', *mm) for mm in marsh))
        o[0:16] = MAGIC64
        struct.pack_into('<II', o, 16, header_size, 0)
        o[24:32] = g.data[24:32]
        rt, rl = root_type, root_loc
        struct.pack_into('<10I', o, 32, g.version, 0, 0, 72, N_SEC, rt[0], rt[1], rl[0], rl[1], g.user_tag)
        o[72:104] = g.data[72:104]
        for s, e in enumerate(entries):
            struct.pack_into('<11I', o, 104 + 44 * s, *e)
        o.extend(b''.join(blobs))
        o.extend(tail)
        struct.pack_into('<I', o, 36, len(o))
        struct.pack_into('<I', o, 40, zlib.crc32(bytes(o[104:])) & 0xffffffff)
        Path(path).write_bytes(bytes(o))
        return len(o)


def _member(g, tref, name):
    for m, _ in g.layout(*tref)[0]:
        if m['name'] == name:
            return m
    return None


def donor_parts(g):
    """the donor records the writer reads: root, skeleton, model, first skinned mesh and its vertex type."""
    if g.ptr != 8 or g.magic != MAGIC64:
        raise WriteError('donor must be an uncompressed 64-bit gr2')
    if not g.crc_check():
        raise WriteError('donor CRC does not match')
    root = g.root()
    sks, mos = refs(g, root.get('Skeletons')), refs(g, root.get('Models'))
    if len(sks) != 1 or len(mos) != 1:
        raise WriteError('donor needs exactly one skeleton and one model (%d / %d)' % (len(sks), len(mos)))
    skinned = None
    for rec, loc in refs(g, root.get('Meshes')):
        vd = g.read(*rec['PrimaryVertexData'][2], *rec['PrimaryVertexData'][1])
        vt = vd['Vertices'][1]
        lay = [(m['name'], m['type'], max(m['count'], 1), o) for m, o in g.layout(*vt)[0]]
        if any(n == 'BoneWeights' for n, *_ in lay):
            skinned = dict(rec=rec, loc=loc, vd=vd, vtype=vt, layout=lay, stride=g.struct_size(*vt))
            break
    if skinned is None:
        raise WriteError('donor has no skinned mesh: its vertex type cannot be proven vanilla')
    if skinned['layout'] != VANILLA_LAYOUT or skinned['stride'] != STRIDE:
        raise WriteError('donor vertex type is not the vanilla 40-byte skinned layout: %s' % skinned['layout'])
    return dict(root=root, skeleton=sks[0], model=mos[0], skinned=skinned)


def obb(mesh, k, inverse_world):
    sel = ((mesh.bi == k) & (mesh.w > 0)).any(1)
    if not sel.any():
        return [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]
    p = mesh.pos[sel].astype(float)
    loc = (np.c_[p, np.ones(len(p))] @ inverse_world)[:, :3]
    return loc.min(0).tolist(), loc.max(0).tolist()


def write(donor, meshes, out, *, textures=None, from_file_name=None, overwrite=False):
    """meshes (with tangents) -> OUT.gr2 around the donor skeleton. Returns the write record."""
    donor, out = Path(donor), Path(out)
    if out.resolve() == donor.resolve():
        raise WriteError('refusing to overwrite the donor')
    if out.exists() and not overwrite:
        raise WriteError('output exists: %s (pass overwrite)' % out)
    textures = textures or {}
    g = Gr2(str(donor))
    d = donor_parts(g)
    root_t = (g.root_type_sec, g.root_type_off)
    W = Out(g)
    root_dst = W.alloc(g.struct_size(*root_t))                 # the root object first, at offset 0
    rt = {m['name']: m for m, _ in g.layout(*root_t)[0]}

    def eltype(name):
        return rt[name]['ref'] if name in rt else None
    bones = g.array(d['skeleton'][0]['Bones'])
    bone_index = {b['Name']: i for i, b in enumerate(bones)}
    inverse_world = {b['Name']: np.array(b['InverseWorldTransform'], float).reshape(4, 4) for b in bones}
    skel = W.copy_obj(d['root']['Skeletons'][3], d['skeleton'][1])
    # materials (vanilla shape: material -> Maps[color] -> file material -> texture record), one set per name
    mat_t, tex_t = eltype('Materials'), eltype('Textures')
    maps_m = _member(g, mat_t, 'Maps') if mat_t else None
    map_t = maps_m['ref'] if maps_m and maps_m['type'] == T_REF_TO_ARRAY else None
    map_ok = map_t is not None and _member(g, map_t, 'Usage') is not None and _member(g, map_t, 'Map') is not None
    tex_ok = tex_t is not None and _member(g, tex_t, 'FromFileName') is not None
    tex_m = _member(g, mat_t, 'Texture') if mat_t else None
    mats, mat_list, tex_list = {}, [], []
    for m in meshes:
        if m.material in mats:
            continue
        tname = textures.get(m.material, m.material + '_BaseColor')
        tex = None
        if tex_ok:
            tex = W.obj(tex_t, dict(FromFileName=tname, TextureType=0, Width=0, Height=0, Encoding=1, SubFormat=0,
                                    Layout=dict(BytesPerPixel=4, ShiftForComponent=[0, 8, 16, 24],
                                                BitsForComponent=[8, 8, 8, 8])))
            tex_list.append(tex)
        if map_ok and tex is not None and tex_m is not None and tex_m['type'] == T_REF:
            filem = W.obj(mat_t, dict(Name=m.material + '_file', Texture=tex))
            mat = W.obj(mat_t, dict(Name=m.material, Maps=W.array_of(map_t, [dict(Usage='color', Map=filem)])))
            mat_list += [filem, mat]
        else:
            mat = W.obj(mat_t, dict(Name=m.material))
            mat_list.append(mat)
        mats[m.material] = mat
    # meshes
    vd_t, topo_t, mesh_t = eltype('VertexDatas'), eltype('TriTopologies'), eltype('Meshes')
    vcn = d['skinned']['vd'].get('VertexComponentNames')
    vtype_out = W.type_ref(d['skinned']['vtype'])
    group_t = _member(g, topo_t, 'Groups')['ref']
    mb_t = _member(g, mesh_t, 'MaterialBindings')['ref']
    bb_t = _member(g, mesh_t, 'BoneBindings')['ref']
    ext = d['skinned']['rec'].get('ExtendedData')
    vds, topos, mesh_locs, records = [], [], [], []
    for m in meshes:
        missing = [b for b in m.bones if b not in bone_index]
        if missing:
            raise WriteError('mesh %s binds bones the donor skeleton lacks: %s' % (m.name, missing))
        raw = pack(m)
        vloc = W.vertices(raw, m.n, vtype_out)
        vd = W.obj(vd_t, dict(Vertices=(vtype_out, m.n, vloc),
                              VertexComponentNames=(vcn[1], W.copy_array(vcn[3], vcn[2], vcn[1]))
                              if vcn and vcn[0] == 'array' and vcn[1] else None))
        iraw = m.tris.astype('<i4').tobytes()
        topo = W.obj(topo_t, dict(Groups=W.array_of(group_t, [dict(MaterialIndex=0, TriFirst=0,
                                                                   TriCount=len(m.tris))]),
                                  Indices=(3 * len(m.tris), W.indices(iraw))))
        bbs = []
        for k, b in enumerate(m.bones):
            lo, hi = obb(m, k, inverse_world[b])
            bbs.append(dict(BoneName=b, OBBMin=lo, OBBMax=hi))
        ext_v = None
        if ext and ext[0] == 'variant' and ext[1]:
            ext_v = (W.type_ref(ext[1]), W.copy_obj(ext[1], ext[2]) if ext[2] else None)
        mesh = W.obj(mesh_t, dict(Name=m.name, PrimaryVertexData=vd, PrimaryTopology=topo,
                                  MaterialBindings=W.array_of(mb_t, [dict(Material=mats[m.material])]),
                                  BoneBindings=W.array_of(bb_t, bbs), ExtendedData=ext_v))
        vds.append(vd)
        topos.append(topo)
        mesh_locs.append(mesh)
        records.append(dict(name=m.name, material=m.material, vertices=m.n, triangles=len(m.tris), bones=m.bones,
                            vertex_sha256=hashlib.sha256(raw).hexdigest(), index_sha256=hashlib.sha256(iraw).hexdigest()))
    model_rec, _ = d['model']
    model_t = eltype('Models')
    mbind_t = _member(g, model_t, 'MeshBindings')['ref']
    model = W.obj(model_t, dict(Name=model_rec['Name'], Skeleton=skel, InitialPlacement=model_rec['InitialPlacement'],
                                MeshBindings=W.array_of(mbind_t, [dict(Mesh=x) for x in mesh_locs])))
    root = d['root']
    vals = dict(FromFileName=from_file_name or ('skinned_gr2.py ' + out.stem), Textures=tex_list, Materials=mat_list,
                Skeletons=[skel], VertexDatas=vds, TriTopologies=topos, Meshes=mesh_locs, Models=[model],
                TrackGroups=[], Animations=[])
    for name in ('ArtToolInfo', 'ExporterInfo'):
        if name in rt and root.get(name) and root[name][1]:
            vals[name] = W.copy_obj(root[name][2], root[name][1])
    if 'ExtendedData' in rt and root.get('ExtendedData') and root['ExtendedData'][1]:
        e = root['ExtendedData']
        vals['ExtendedData'] = (W.type_ref(e[1]), W.copy_obj(e[1], e[2]) if e[2] else None)
    W.fill(root_t, root_dst, vals)
    size = W.write(out, W.type_ref(root_t), (SEC_MAIN, root_dst))
    return dict(path=str(out), bytes=size, sha256=hashlib.sha256(out.read_bytes()).hexdigest(), donor=str(donor),
                donor_sha256=hashlib.sha256(donor.read_bytes()).hexdigest(), type_section='verbatim' if W.verbatim
                else 'copied per type', meshes=records, materials=list(mats), textures=[textures.get(k, k + '_BaseColor')
                                                                                       for k in mats])


# ------------------------------------------------------------------------------------------------ verification
def bone_records(g):
    """the raw bytes of every bone record of the first skeleton (pointer slots are zero in the file bytes)."""
    sk = refs(g, g.root()['Skeletons'])[0][0]
    _, n, loc, tref = sk['Bones']
    size = g.struct_size(*tref)
    return [bytes(g.payload[loc[0]][loc[1] + k * size:loc[1] + (k + 1) * size]) for k in range(n)], sk


def verify(out, donor, meshes):
    """re-open OUT with the repo reader and compare it with the donor and the packed meshes; raises on a failure."""
    from gr2_fixups import orphan_fixups
    go, gd = Gr2(str(out)), Gr2(str(donor))
    rep = {'crc_ok': go.crc_check()}
    bo, sko = bone_records(go)
    bd, skd = bone_records(gd)
    names_o = [b['Name'] for b in go.array(sko['Bones'])]
    names_d = [b['Name'] for b in gd.array(skd['Bones'])]
    rep['skeleton'] = dict(bones=len(bo), records_identical=bo == bd, names_identical=names_o == names_d,
                           skeleton_name=sko['Name'] == skd['Name'], lod_type=sko['LODType'] == skd['LODType'])
    root = go.root()
    rep['orphan_fixups'] = len(orphan_fixups(out)['orphans'])
    rep['sections'] = [dict(size=s['data_size'], compression=s['compression'], relocs=s['reloc_count'],
                            marsh=s['marsh_count']) for s in go.sections]
    got = []
    for (rec, _), m in zip(refs(go, root['Meshes']), meshes):
        vd = go.read(*rec['PrimaryVertexData'][2], *rec['PrimaryVertexData'][1])
        _, vt, nv, dp = vd['Vertices']
        lay = [(x['name'], x['type'], max(x['count'], 1), o) for x, o in go.layout(*vt)[0]]
        top = go.read(*rec['PrimaryTopology'][2], *rec['PrimaryTopology'][1])
        (s, o), ni = top['Indices'][2], top['Indices'][1]
        tris = np.frombuffer(bytes(go.payload[s][o:o + 4 * ni]), '<i4').reshape(-1, 3)
        vbytes = bytes(go.payload[dp[0]][dp[1]:dp[1] + STRIDE * nv])
        mats = [go.read(*x['Material'][2], *x['Material'][1])['Name'] for x in go.array(rec['MaterialBindings'])]
        bbs = [x['BoneName'] for x in go.array(rec['BoneBindings'])]
        got.append(dict(name=rec['Name'], layout_vanilla=lay == VANILLA_LAYOUT, vertices=nv, vertex_bytes_equal=vbytes
                        == pack(m), indices_equal=bool(np.array_equal(tris, m.tris)), materials=mats,
                        palette=bbs == m.bones, vertex_section=dp[0], index_section=s,
                        winding_share=round(winding_share(m), 4)))
    rep['meshes'] = got
    rep['marshalling'] = [tuple(struct.unpack_from('<4I', go.data, go.sections[SEC_VERTEX]['marsh_off'] + 16 * k))
                          for k in range(go.sections[SEC_VERTEX]['marsh_count'])]
    fails = []
    if not rep['crc_ok']:
        fails.append('crc')
    if not all(rep['skeleton'].values()):
        fails.append('skeleton %s' % rep['skeleton'])
    if rep['orphan_fixups']:
        fails.append('%d orphan fixups' % rep['orphan_fixups'])
    if len(got) != len(meshes):
        fails.append('mesh count %d != %d' % (len(got), len(meshes)))
    for r, m in zip(got, meshes):
        if not (r['layout_vanilla'] and r['vertex_bytes_equal'] and r['indices_equal'] and r['palette']
                and r['materials'] == [m.material] and r['vertex_section'] == SEC_VERTEX
                and r['index_section'] == SEC_INDEX):
            fails.append('mesh %s: %s' % (m.name, r))
        if r['winding_share'] < WINDING_MIN:
            fails.append('mesh %s: winding along the stored normals on %.1f %% of the area only' %
                         (m.name, 100 * r['winding_share']))
    rep['fails'] = fails
    if fails:
        raise WriteError('verification failed: ' + '; '.join(fails))
    return rep


def decode(path):
    """the meshes of a written file as MeshIn (with tangents), straight from its bytes."""
    g = Gr2(str(path))
    root = g.root()
    out = []
    for rec, _ in refs(g, root['Meshes']):
        vd = g.read(*rec['PrimaryVertexData'][2], *rec['PrimaryVertexData'][1])
        _, vt, nv, dp = vd['Vertices']
        r = np.frombuffer(bytes(g.payload[dp[0]][dp[1]:dp[1] + STRIDE * nv]), np.uint8).reshape(nv, STRIDE)
        top = g.read(*rec['PrimaryTopology'][2], *rec['PrimaryTopology'][1])
        (s, o), ni = top['Indices'][2], top['Indices'][1]
        tris = np.frombuffer(bytes(g.payload[s][o:o + 4 * ni]), '<i4').reshape(-1, 3)
        mats = [g.read(*x['Material'][2], *x['Material'][1])['Name'] for x in g.array(rec['MaterialBindings'])]
        out.append(MeshIn(rec['Name'], mats[0] if mats else None, [x['BoneName'] for x in g.array(rec['BoneBindings'])],
                          r[:, 0:12].copy().view('<f4'), r[:, 12:16].copy().view(np.int8), r[:, 24:32].copy().view('<f4'),
                          r[:, 32:36], r[:, 36:40], tris, r[:, 16:20].copy().view(np.int8)))
    return out


def tangent_recheck(path, blender=None):
    """MikkTSpace recomputed on the WRITTEN file's data, compared per corner with the stored tangents."""
    meshes = decode(path)
    res = []
    for m, (T, S) in zip(meshes, mikktspace(meshes, blender)):
        st = m.tan[:, :3].astype(float)
        st /= np.linalg.norm(st, axis=1)[:, None]
        dots, agree = [], []
        for f in range(len(m.tris)):
            for c in range(3):
                v = m.tris[f, c]
                t = T[f, c] / (np.linalg.norm(T[f, c]) or 1.0)
                dots.append(float(np.dot(st[v], t)))
                agree.append((m.tan[v, 3] > 0) == (S[f, c] >= 0))
        dots = np.sort(dots)
        res.append(dict(mesh=m.name, corners=len(dots), dot_median=round(float(np.median(dots)), 5),
                        dot_p01=round(float(dots[len(dots) // 100]), 5), share_dot_gt_099=round(float((dots > 0.99).mean()), 5),
                        sign_agree=round(float(np.mean(agree)), 5)))
    return res


# ---------------------------------------------------------------------------------------------- clean proof
def _strings_of(g):
    """every string a pointer fixup targets (STRING members, type member names): printable, NUL-terminated."""
    out = set()
    for ts, to in set(g.reloc.values()):
        buf = g.payload[ts]
        end = buf.find(b'\0', to, to + 1024)
        if end <= to:
            continue
        s = bytes(buf[to:end])
        if all(32 <= b < 127 for b in s):
            out.add(s.decode('ascii'))
    return out


def prove_clean(donor, out, own=()):
    """what of the donor's mesh, vertex, index and texture data is left in OUT (all counts must be 0).
    Allowed donor strings: bone, skeleton and model names, type member names, vertex component names and the
    ArtToolInfo / ExporterInfo / root ExtendedData strings (what the writer copies on purpose). `own`: strings the
    writer authored from its own inputs (mesh, material and texture names, the map usage 'color'); a donor string equal
    to one of them is listed as coincident, not as leaked."""
    gd, go = Gr2(str(donor)), Gr2(str(out))
    blob = go.data
    out_vert = bytes(go.payload[SEC_VERTEX]) if go.sec_count > SEC_VERTEX else b''
    rootd = gd.root()
    vert_hits = pos_hits = 0
    vert_total = 0
    index_windows = index_hits = 0
    out_idx = bytes(go.payload[SEC_INDEX]) if go.sec_count > SEC_INDEX else b''
    for rec, _ in refs(gd, rootd['Meshes']):
        vd = gd.read(*rec['PrimaryVertexData'][2], *rec['PrimaryVertexData'][1])
        _, vt, nv, dp = vd['Vertices']
        stride = gd.struct_size(*vt)
        raw = bytes(gd.payload[dp[0]][dp[1]:dp[1] + stride * nv])
        for i in range(nv):
            rec_b = raw[i * stride:(i + 1) * stride]
            vert_total += 1
            vert_hits += rec_b in blob
            p = rec_b[:12]
            if p != bytes(12):                                 # positions: in the vertex section (a round triple
                pos_hits += p in out_vert                      # like (0, 1, 0) also sits in transform matrices)
        top = gd.read(*rec['PrimaryTopology'][2], *rec['PrimaryTopology'][1])
        if top['Indices'][1]:
            (s, o), n, w = top['Indices'][2], top['Indices'][1], 4
        else:
            (s, o), n, w = top['Indices16'][2], top['Indices16'][1], 2
        ib = bytes(gd.payload[s][o:o + n * w])
        win = 16 * w                                            # 16 indices in a row
        for k in range(0, max(len(ib) - win, 0) + 1, 3 * w):
            index_windows += 1
            index_hits += ib[k:k + win] in out_idx
    allowed = set()
    sk = refs(gd, rootd['Skeletons'])[0][0]
    allowed |= {b['Name'] for b in gd.array(sk['Bones'])} | {sk['Name']}
    allowed |= {mo['Name'] for mo, _ in refs(gd, rootd['Models'])}
    for name in ('ArtToolInfo', 'ExporterInfo'):
        if rootd.get(name) and rootd[name][1]:
            allowed |= {v for v in gd.read(*rootd[name][2], *rootd[name][1]).values() if isinstance(v, str)}
    e = rootd.get('ExtendedData')
    if e and e[1] and e[2]:
        allowed |= {v for v in gd.read(*e[1], *e[2]).values() if isinstance(v, str)}
    from gr2_fixups import Walker
    walker = Walker(gd)                                        # every type reachable, variant types included
    walker.walk_obj((gd.root_type_sec, gd.root_type_off), gd.root_sec, gd.root_off)
    allowed |= {m['name'] for t in walker._types for m in gd.typedef(*t) if m['name']}
    for rec, _ in refs(gd, rootd['Meshes']):
        vd = gd.read(*rec['PrimaryVertexData'][2], *rec['PrimaryVertexData'][1])
        vcn = vd.get('VertexComponentNames')
        if vcn and vcn[0] == 'array' and vcn[1]:
            allowed |= {x.get('String') for x in gd.array(vcn) if isinstance(x.get('String'), str)}
    donor_strings, out_strings = _strings_of(gd), _strings_of(go)
    own = set(own)
    shared = donor_strings & out_strings
    leaked = sorted(s for s in shared if s not in allowed and s not in own)
    coincident = sorted(s for s in shared if s not in allowed and s in own)
    texture_images = 0
    for t, _ in refs(go, go.root().get('Textures')):
        texture_images += t['Images'][1] if isinstance(t.get('Images'), tuple) else 0
    rep = dict(donor_vertex_records=vert_total, donor_vertex_records_found=vert_hits, donor_positions_found=pos_hits,
               donor_index_windows=index_windows, donor_index_windows_found=index_hits,
               donor_strings=len(donor_strings), donor_strings_copied_by_design=len(shared) - len(leaked) - len(coincident),
               donor_strings_found=leaked, coincident_with_own_names=coincident, texture_images_in_out=texture_images,
               texture_section_bytes=go.sections[5]['data_size'] if go.sec_count > 5 else 0)
    rep['clean'] = (vert_hits == 0 and pos_hits == 0 and index_hits == 0 and not leaked and texture_images == 0
                    and rep['texture_section_bytes'] == 0)
    return rep


# ------------------------------------------------------------------------------------------------------ driver
def donor_bind_check(donor, parsed, scale=1.0):
    """the GXO's bone table against the donor skeleton: same names and order, joint positions (engine frame)."""
    g = Gr2(str(donor))
    bones = g.array(refs(g, g.root()['Skeletons'])[0][0]['Bones'])
    names = [b['Name'] for b in bones]
    world = {b['Name']: np.linalg.inv(np.array(b['InverseWorldTransform'], float).reshape(4, 4))[3, :3] for b in bones}
    gx = parsed.get('bones') or []
    diff = [float(np.abs((np.asarray(t) @ A) * scale - world[n]).max()) for n, t in zip(gx, parsed.get('bone_t', []))
            if n in world]
    return dict(gxo_bones=len(gx), donor_bones=len(names), same_names_and_order=gx == names,
                missing_in_donor=[n for n in gx if n not in world],
                joint_max_abs_diff=round(max(diff), 7) if diff else None)


def build(donor, gxo, out, *, scale=1.0, material_names=None, mesh_names=None, textures=None, blender=None,
          tangent_fn=None, recheck=True, overwrite=False):
    """GXO + donor -> OUT.gr2 with every check; returns the report (raises WriteError on any failure)."""
    parsed = parse_gxo(gxo)
    meshes = from_gxo(parsed, scale, material_names, mesh_names)
    bind = donor_bind_check(donor, parsed, scale)
    if bind['missing_in_donor']:
        raise WriteError('GXO bones missing from the donor skeleton: %s' % bind['missing_in_donor'])
    pre = [dict(name=m.name, gxo_vertices=m.n, triangles=len(m.tris)) for m in meshes]
    corner = tangent_fn(meshes) if tangent_fn else mikktspace(meshes, blender)
    final, splits = [], []
    for m, (T, S) in zip(meshes, corner):
        fm, k = assign_tangents(m, T, S)
        final.append(fm)
        splits.append(k)
    for r, m, k in zip(pre, final, splits):
        r.update(vertices=m.n, tangent_only_splits=k, winding_share=round(winding_share(m), 4),
                 influences={str(i): int(((m.w > 0).sum(1) == i).sum()) for i in range(1, 5)})
    rep = dict(tool='skinned_gr2', donor=str(donor), gxo=str(gxo), scale=scale,
               tangents='injected (%s)' % getattr(tangent_fn, '__name__', 'fn') if tangent_fn else 'MikkTSpace (Blender)',
               donor_bind=bind, prepared=pre)
    rep['write'] = write(donor, final, out, textures=textures, overwrite=overwrite)
    rep['verify'] = verify(out, donor, final)
    own = {m.name for m in final} | {m.material for m in final} | {m.material + '_file' for m in final} | \
        set(rep['write']['textures']) | {'color'}
    rep['clean'] = prove_clean(donor, out, own)
    if not rep['clean']['clean']:
        raise WriteError('donor data left in the output: %s' % rep['clean'])
    if recheck and not tangent_fn:
        rep['tangent_recheck'] = tangent_recheck(out, blender)
    return rep


def _pairs(items):
    out = {}
    for s in items or []:
        if '=' not in s:
            raise SystemExit('expected NAME=VALUE: %s' % s)
        k, v = s.split('=', 1)
        out[k] = v
    return out


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if '--mikk' in argv:                                       # inside Blender
        i = argv.index('--mikk')
        _blender_mikk(argv[i + 1], argv[i + 2])
        return 0
    if argv[:1] == ['--prove-clean']:
        go = Gr2(argv[2])
        r = go.root()
        own = {m['Name'] for m, _ in refs(go, r['Meshes'])} | {m['Name'] for m, _ in refs(go, r['Materials'])} | \
            {t['FromFileName'] for t, _ in refs(go, r.get('Textures'))} | {'color'}
        rep = prove_clean(argv[1], argv[2], own)            # OUT's own names count as coincident, listed apart
        print(json.dumps(rep, indent=1))
        return 0 if rep['clean'] else 1
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('donor')
    ap.add_argument('gxo')
    ap.add_argument('out')
    ap.add_argument('--json')
    ap.add_argument('--scale', type=float, default=1.0)
    ap.add_argument('--material', nargs='*', default=[], help='GXO_NAME=RUNTIME_NAME (the .material submaterial)')
    ap.add_argument('--mesh-name', nargs='*', default=[], help='GXO_NAME=NAME')
    ap.add_argument('--texture', nargs='*', default=[], help='RUNTIME_NAME=TEXTURE_NAME (the texture record)')
    ap.add_argument('--blender')
    ap.add_argument('--no-recheck', action='store_true')
    ap.add_argument('--overwrite', action='store_true')
    a = ap.parse_args(argv)
    try:
        rep = build(a.donor, a.gxo, a.out, scale=a.scale, material_names=_pairs(a.material),
                    mesh_names=_pairs(a.mesh_name), textures=_pairs(a.texture), blender=a.blender,
                    recheck=not a.no_recheck, overwrite=a.overwrite)
    except WriteError as e:
        print('FAILED: %s' % e)
        return 1
    text = json.dumps(rep, indent=1, default=str)
    if a.json:
        Path(a.json).write_text(text, encoding='utf-8')
    for m in rep['prepared']:
        print('MESH %(name)s: %(gxo_vertices)d GXO vertices -> %(vertices)d (tangent-only splits %(tangent_only_splits)d), '
              '%(triangles)d triangles, winding %(winding_share).4f, influences %(influences)s' % m)
    print('WROTE %s (%d bytes, sha256 %s), type section %s' % (rep['write']['path'], rep['write']['bytes'],
                                                               rep['write']['sha256'][:16], rep['write']['type_section']))
    v = rep['verify']
    print('VERIFY crc %s, skeleton %s, orphan fixups %d, meshes %s' % (v['crc_ok'], v['skeleton'], v['orphan_fixups'],
                                                                     [(x['name'], x['layout_vanilla'],
                                                                       x['vertex_bytes_equal']) for x in v['meshes']]))
    print('CLEAN %s' % rep['clean'])
    for t in rep.get('tangent_recheck', []):
        print('TANGENTS %s' % t)
    return 0


if __name__ == '__main__':
    if '--' in sys.argv and '--mikk' in sys.argv:            # launched by Blender: args after '--'
        sys.exit(main(sys.argv[sys.argv.index('--') + 1:]))
    sys.exit(main())
