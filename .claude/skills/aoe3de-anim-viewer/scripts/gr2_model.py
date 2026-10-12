#!/usr/bin/env python
"""Model reader of the aoe3de-anim-viewer backend: a unit's .gr2 -> the bundle's model record (references/bundle-schema.md
section 7), with the raw vertex streams and indices in a binary buffer.

    import av_common as C, gr2_model as GM
    geo = C.BufferWriter('geo')
    rec, warnings = GM.model_record(path_or_bytes, geo, model_id='units/asians/chinese/iron_flail/iron_rider_0.gr2',
                                    provenance=3, material_file='units/asians/chinese/iron_flail/iron_rider_0.material')
    m = GM.read_model(path_or_bytes)      # the Python form: bones, rest/world matrices, meshes with numpy streams

    python gr2_model.py FILE.gr2 [...]    # summary per file (nothing is written)

Reuse, by import (companion skill aoe3de-unit-model): unit_gr2.Model/Mesh copy every vertex member byte for byte and
read groups, material and bone bindings; clip_decode.q2m builds the rotation; through unit_gr2 the consumer's reader
scripts/havok/gr2_read.py (Gr2, COMP) and gr2_dump.refs. Read-only: the source is never written. A source given as
bytes is parsed from a temporary copy under the viewer cache (av_common.cache_root()/tmp), deleted at once.

What a record holds (all as stored, in the gr2's own frame, engine units, +Y up):
- skeleton: bone names, parents, `rest` (the bone's LocalTransform) and `inverse_world` (InverseWorldTransform, the 16
  stored numbers), `flags` (the Granny transform flags).
- meshes: every vertex member as its own stream, the bytes of each element unchanged (Tangent keeps its 4th byte, the
  bitangent sign: binormal_int8 w = +-127 on vanilla skinned meshes; static packed meshes store 3-component Normal and
  Tangent plus BasicStaticPackedData0/1 bytes, kept as `uint8` streams, meaning unknown); indices as stored (Indices16 ->
  u16, Indices -> u32); groups -> material bindings; bone bindings resolved to skeleton indices by the engine's name
  rule (a space equals an underscore, case-insensitive).

Measured 2026-10-11 (vanilla iron_rider_0.gr2 and iron_flail_horse_0.gr2, ArtUnits.bar):
- `rest` is the flags-APPLIED transform: a component whose flag bit is clear (1 position, 2 orientation, 4 scale-shear)
  is the identity, whatever numbers are stored. The horse stores scale-shear numbers up to 4e-4 off the identity
  under flags 3; composed raw they miss the file's own InverseWorld by 4.1e-4, flags applied by 7.5e-7 (rider 6.2e-7).
  The raw stored triple stays available in the Python form (`bones[i]['raw']`).
- root axis matrix = identity (ROOT): W(bone) = L(bone) @ W(parent), root bones W = L @ ROOT, reproduces every
  stored InverseWorld within 1e-6. The bundle applies no Granny basis conversion. Vanilla ArtToolInfo declares Right
  -X, Up +Y, Back +Z, UnitsPerMeter 1.5625; a file declaring another basis gets the warning `gr2-basis-differs`
  (whether the engine converts is unknown). unit_gr2's frame A (the converter GXO frame, g = e @ A.T / 2.54) maps this
  frame to the converter's; tests/test_gr2_curves.py checks the posed rider at key 0 against pose_sim in frame A.

Unavailable files are reported, never dropped (bundle-schema section 5): Oodle- or otherwise compressed sections
(`gr2-compressed-<name>`, names from gr2_read.COMP: 1 oodle0, 2 oodle1, 4 bitknit - the code-4 name is gr2_read's
label, not confirmed), 32-bit files (`gr2-32bit`, format 7 or the legacy format 6 magic), and - codes this module
adds - `gr2-bad-magic`, `gr2-truncated`, `gr2-parse-failed`.
"""
from __future__ import annotations

import argparse
import os
import struct
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
UNIT_MODEL_SCRIPTS = HERE.parents[1] / 'aoe3de-unit-model' / 'scripts'
for _p in (str(HERE), str(UNIT_MODEL_SCRIPTS)):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import av_common as C  # noqa: E402
try:
    import unit_gr2 as U  # noqa: E402  (companion aoe3de-unit-model; puts the consumer's scripts/havok on sys.path)
except SystemExit as _e:                       # no consumer GR2 reader (a public export without scripts/havok)
    raise ImportError(str(_e)) from None
import clip_decode as CD  # noqa: E402
from gr2_dump import refs  # noqa: E402
from gr2_read import COMP, MAGIC32, MAGIC64  # noqa: E402

MAGIC32_V6 = bytes.fromhex('b867b0caf86db10f84728c7e5e19001e')    # legacy file format 6, 32-bit little-endian
MAGICS = {MAGIC64: (64, 7), MAGIC32: (32, 7), MAGIC32_V6: (32, 6)}
HEADER = 32                                   # magic (16) + header size, format, 8 reserved bytes
SECTION = 44                                  # one section record: 11 uint32

HAS_POSITION, HAS_ORIENTATION, HAS_SCALE_SHEAR = 1, 2, 4
IDENTITY_SS = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]
ROOT = np.eye(4)                              # root axis matrix (see the module notes)
ROOT16 = [float(x) for x in ROOT.ravel()]
VANILLA_BASIS = {'RightVector': (-1.0, 0.0, 0.0), 'UpVector': (0.0, 1.0, 0.0), 'BackVector': (0.0, 0.0, 1.0)}

# Granny vertex member type name -> (bundle dtype, decode rule, GL normalized flag); bundle-schema section 7
GR2_TYPES = {
    'real32': ('f32', 'float', False), 'real16': ('f16', 'float', False),
    'binormal_int8': ('i8', 'snorm', True), 'binormal_int16': ('i16', 'snorm', True),
    'normal_uint8': ('u8', 'unorm', True), 'normal_uint16': ('u16', 'unorm', True),
    'uint8': ('u8', 'uint', False), 'uint16': ('u16', 'uint', False), 'uint32': ('u32', 'uint', False),
    'int8': ('i8', 'sint', False), 'int16': ('i16', 'sint', False), 'int32': ('i32', 'sint', False),
}
PARSE_ERRORS = (struct.error, KeyError, IndexError, ValueError, TypeError, AssertionError, UnicodeDecodeError,
                ZeroDivisionError, AttributeError, RecursionError, OverflowError, U.Unreadable, NotImplementedError)


class Gr2Unavailable(Exception):
    """the file cannot be decoded: `reason` is a bundle-schema reason code, `info` the sniff() result."""

    def __init__(self, reason, info=None, detail=None):
        super().__init__('%s%s' % (reason, ': %s' % detail if detail else ''))
        self.reason, self.info, self.detail = reason, info or {}, detail


# ------------------------------------------------------------------------------------------------ header sniffing
def compression_name(code) -> str:
    return COMP.get(int(code), 'unknown-%d' % int(code))


def sniff(data) -> dict:
    """header facts of a gr2 without parsing it: {size, pointer_size, format, version, sections [{compression, size}],
    compression ('none', 'oodle0', 'oodle1', 'bitknit' or 'unknown-<code>'), reason (None or a reason code)}.
    A section counts as compressed only when it holds data (gr2_read's own rule)."""
    info = {'size': len(data), 'pointer_size': None, 'format': None, 'version': None, 'sections': [],
            'compression': None, 'reason': None}
    if len(data) < HEADER:
        info['reason'] = 'gr2-truncated'
        return info
    kind = MAGICS.get(bytes(data[:16]))
    if kind is None:
        info['reason'] = 'gr2-bad-magic'
        return info
    info['pointer_size'], info['format'] = kind
    if info['format'] == 7:                    # format 7 file info: version, size, crc, section table offset, count
        if len(data) < HEADER + 20:
            info['reason'] = 'gr2-truncated'
            return info
        version, file_size, _crc, sec_off, count = struct.unpack_from('<5I', data, HEADER)
        info['version'] = version
        table = HEADER + sec_off
        if count > 4096 or table + SECTION * count > len(data) or file_size > len(data):
            info['reason'] = 'gr2-truncated'
            return info
        active = []
        for i in range(count):
            code, off, size = struct.unpack_from('<3I', data, table + SECTION * i)
            info['sections'].append({'compression': compression_name(code), 'size': size})
            if size and off + size > len(data):
                info['reason'] = 'gr2-truncated'
            if code and size:
                active.append(code)
        info['compression'] = compression_name(active[0]) if active else 'none'
        if info['reason']:
            return info
        if active:
            info['reason'] = 'gr2-compressed-' + info['compression']
            return info
    if info['pointer_size'] == 32:
        info['reason'] = 'gr2-32bit'
    return info


def load(src):
    """(bytes, path or None) of a source given as a path or as bytes."""
    if isinstance(src, (bytes, bytearray, memoryview)):
        return bytes(src), None
    p = Path(src)
    return p.read_bytes(), p


@contextmanager
def as_file(data, path=None):
    """a path holding `data`: `path` itself, or a temporary copy under cache_root()/tmp, removed on exit (gr2_read
    reads a whole file in its constructor, so the copy lives only for the parse)."""
    if path is not None:
        yield Path(path)
        return
    tmp_dir = C.cache_root() / 'tmp'
    C.refuse_repo_path(tmp_dir, 'a temporary gr2 copy')
    tmp_dir.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(suffix='.gr2', dir=str(tmp_dir))
    try:
        with os.fdopen(fd, 'wb') as f:
            f.write(data)
        yield Path(name)
    finally:
        try:
            os.unlink(name)
        except OSError:
            pass


def open_gr2(src):
    """(gr2_read.Gr2, sniff info) for a decodable file; Gr2Unavailable otherwise."""
    data, path = load(src)
    info = sniff(data)
    if info['reason']:
        raise Gr2Unavailable(info['reason'], info)
    with as_file(data, path) as p:
        try:
            g = U.Gr2(str(p))
        except PARSE_ERRORS as e:
            raise Gr2Unavailable('gr2-parse-failed', info, '%s: %s' % (type(e).__name__, e))
    return g, info


# ------------------------------------------------------------------------------------------------ transforms
def transform(t) -> dict:
    """Granny transform tuple (flags, 3 position, 4 orientation xyzw, 9 scale-shear) -> the bundle's
    {position, orientation, scale_shear} with the flags applied (a clear bit = that component is the identity)."""
    f = int(t[0])
    return {'position': [float(x) for x in t[1:4]] if f & HAS_POSITION else [0.0, 0.0, 0.0],
            'orientation': [float(x) for x in t[4:8]] if f & HAS_ORIENTATION else [0.0, 0.0, 0.0, 1.0],
            'scale_shear': [float(x) for x in t[8:17]] if f & HAS_SCALE_SHEAR else list(IDENTITY_SS)}


def raw_transform(t) -> dict:
    """the stored numbers of a Granny transform tuple, flags not applied."""
    return {'flags': int(t[0]), 'position': [float(x) for x in t[1:4]], 'orientation': [float(x) for x in t[4:8]],
            'scale_shear': [float(x) for x in t[8:17]]}


def local_matrix(tr) -> np.ndarray:
    """bundle transform -> row-vector 4x4: upper 3x3 L = R @ S (R = the row-vector rotation of the quaternion, S the
    scale-shear as stored), translation row = position. clip_decode.local_matrix without its GXO frame change."""
    M = np.eye(4)
    M[:3, :3] = CD.q2m(np.asarray(tr['orientation'], float)).T @ np.asarray(tr['scale_shear'], float).reshape(3, 3)
    M[3, :3] = tr['position']
    return M


def compose_world(locals_, parents, root=ROOT) -> np.ndarray:
    """world matrices (n, 4, 4): W(b) = L(b) @ W(parent), root bones L @ root; parents in any order (cycle-safe)."""
    n = len(locals_)
    W = [None] * n

    def world(i, depth=0):
        if W[i] is None:
            p = parents[i]
            if p < 0 or p >= n or depth > n:
                W[i] = locals_[i] @ root
            else:
                W[i] = locals_[i] @ world(p, depth + 1)
        return W[i]
    for i in range(n):
        world(i)
    return np.array(W) if n else np.zeros((0, 4, 4))


def warning(code, path, message, layer=None) -> dict:
    """a bundle warning record (bundle-schema section 13)."""
    return {'code': code, 'path': path, 'layer': layer, 'message': message}


def unavailable_warning(reason, path, detail=None, layer=None) -> dict:
    code = 'gr2-compressed' if reason.startswith('gr2-compressed') else reason
    text = {'gr2-32bit': '32-bit gr2: not decoded by this viewer yet; shown as unavailable',
            'gr2-bad-magic': 'not a little-endian Granny 2 file (unknown magic)',
            'gr2-truncated': 'the file is shorter than its header says',
            'gr2-parse-failed': 'the Granny structure could not be parsed'}.get(reason)
    if code == 'gr2-compressed':
        text = '%s sections: not decoded by this viewer yet; shown as unavailable' % reason[len('gr2-compressed-'):]
    return warning(code, path, '%s (%s)%s' % (text or reason, reason, ': %s' % detail if detail else ''), layer)


# ------------------------------------------------------------------------------------------------ the Python form
class Gr2Mesh:
    """one mesh: members [(name, gr2 type name, components, offset)], streams {name: (n, components) array as stored},
    unsupported [member names without a numpy type], indices (flat), index_dtype 'u16'|'u32', groups
    [(material index, first triangle, triangle count)], materials [binding names], bone_names [palette names]."""

    def __init__(self, um, rec, g):
        self.name = um.name
        self.vertex_count = int(um.n)
        self.stride = int(um.stride)
        self.members = list(um.layout)
        self.streams = dict(um.comps)
        self.unsupported = [m[0] for m in self.members if m[0] not in self.streams and self.vertex_count]
        top = g.read(*rec['PrimaryTopology'][2], *rec['PrimaryTopology'][1])
        self.index_dtype = 'u32' if top['Indices'][1] else 'u16'
        self.indices = um.tris.reshape(-1)
        self.triangle_count = int(len(um.tris))
        self.groups = [(int(m), int(f), int(c)) for m, f, c in um.groups]
        self.materials = list(um.materials)
        self.bone_names = list(um.bones)


class Gr2Model:
    """the Python form of a decodable model gr2 (read_model)."""

    def __init__(self, um, info, path=None):
        g = um.g
        r = g.root()
        self.path, self.info, self.crc_ok = path, info, bool(um.crc_ok)
        self.art_tool = None
        at = r.get('ArtToolInfo')
        if at and at[0] == 'ref' and at[1]:
            rec = g.read(*at[2], *at[1])
            self.art_tool = {k: (tuple(float(x) for x in rec[k]) if isinstance(rec.get(k), tuple) else rec.get(k))
                             for k in ('FromArtToolName', 'UnitsPerMeter', 'Origin', 'RightVector', 'UpVector',
                                       'BackVector') if k in rec}
        skels = refs(g, r.get('Skeletons'))
        self.skeleton_count = len(skels)
        self.skeleton_name = skels[0][0]['Name'] if skels else None
        self.bones = []
        for b in (g.array(skels[0][0]['Bones']) if skels else []):
            t = b['Transform']
            self.bones.append({'name': b['Name'], 'parent': int(b['ParentIndex'][0]), 'flags': int(t[0]),
                               'rest': transform(t), 'raw': raw_transform(t),
                               'inverse_world': [float(x) for x in b['InverseWorldTransform'][:16]]})
        # The file mesh table may retain an unused donor mesh after an append
        # export. Only meshes referenced by Models.MeshBindings are drawable.
        bound = set()
        for model, _ in refs(g, r.get('Models')):
            bindings = model.get('MeshBindings')
            if not bindings:
                continue
            if bindings[0] == 'array':
                locations = [x['Mesh'][1] for x in g.array(bindings)]
            elif bindings[0] == 'refarray':
                locations = [x['Mesh'][1] if 'Mesh' in x else loc for x, loc in refs(g, bindings)]
            else:
                raise ValueError('unsupported Models.MeshBindings representation: %s' % bindings[0])
            bound.update(tuple(loc) for loc in locations if loc)
        mesh_rows = list(zip(um.meshes, refs(g, r.get('Meshes'))))
        self.meshes = [Gr2Mesh(um_mesh, rec, g) for um_mesh, (rec, loc) in mesh_rows if tuple(loc) in bound]
        self.unbound_meshes = [rec['Name'] for _, (rec, loc) in mesh_rows if tuple(loc) not in bound]
        self.bone_lookup = {}
        for i, b in enumerate(self.bones):
            self.bone_lookup.setdefault(U.nm(b['name']), i)

    @property
    def parents(self):
        return [b['parent'] for b in self.bones]

    @property
    def root_count(self):
        return sum(1 for b in self.bones if b['parent'] < 0)

    def bone_index(self, name) -> int:
        """skeleton index of a bone name by the engine's rule, -1 when absent."""
        return self.bone_lookup.get(U.nm(name), -1)

    def rest_local(self) -> np.ndarray:
        return np.array([local_matrix(b['rest']) for b in self.bones]) if self.bones else np.zeros((0, 4, 4))

    def rest_world(self) -> np.ndarray:
        """the rest pose composed from the LocalTransforms (flags applied) with ROOT."""
        return compose_world(self.rest_local(), self.parents)

    def inverse_world(self) -> np.ndarray:
        return np.array([np.array(b['inverse_world']).reshape(4, 4) for b in self.bones]) if self.bones \
            else np.zeros((0, 4, 4))

    def bounds(self):
        pts = [m.streams['Position'][:, :3].astype(np.float64) for m in self.meshes
               if 'Position' in m.streams and m.vertex_count]
        if not pts:
            return None
        P = np.vstack(pts)
        return {'min': [float(x) for x in P.min(0)], 'max': [float(x) for x in P.max(0)]}


def read_model(src) -> Gr2Model:
    """the Python form of a model gr2 (path or bytes); Gr2Unavailable when it cannot be decoded."""
    return _read_model(*load(src))


def _read_model(data, path):
    info = sniff(data)
    if info['reason']:
        raise Gr2Unavailable(info['reason'], info)
    with as_file(data, path) as p:
        try:
            um = U.Model(p)
            return Gr2Model(um, info, path)
        except PARSE_ERRORS as e:
            raise Gr2Unavailable('gr2-parse-failed', info, '%s: %s' % (type(e).__name__, e))


# ------------------------------------------------------------------------------------------------ the bundle record
def unavailable_model_record(model_id, reason, info=None, provenance=None) -> dict:
    info = info or {}
    return {'id': model_id, 'path': model_id, 'provenance': provenance, 'decodable': False,
            'unavailable_reason': reason, 'compression': info.get('compression'),
            'pointer_size': info.get('pointer_size'), 'root': ROOT16, 'skeleton': None, 'meshes': [],
            'bounds': None, 'root_count': None}


def record_from_model(m, writer, *, model_id, provenance=None, material_file=None, layer=None):
    """(model record, warnings) of a read Gr2Model; streams and indices are appended to `writer`
    (av_common.BufferWriter). material_file: the logical id of the .material whose submaterials the mesh material
    bindings name (`<material_file>#<binding>`); None leaves `material` null (the material module fills it)."""
    warnings = []
    if m.unbound_meshes:
        warnings.append(warning('gr2-unbound-meshes-excluded', model_id,
                                'File-table meshes not referenced by any Model.MeshBindings: '
                                + ', '.join(m.unbound_meshes), layer))
    if not m.crc_ok:
        warnings.append(warning('gr2-crc-mismatch', model_id, 'the header CRC does not match the file (the '
                                'engine\'s reaction is unknown)', layer))
    if m.art_tool:
        diff = [k for k, v in VANILLA_BASIS.items() if k in m.art_tool and
                any(abs(a - b) > 1e-6 for a, b in zip(m.art_tool[k], v))]
        if diff:
            warnings.append(warning('gr2-basis-differs', model_id, 'ArtToolInfo %s differ from vanilla (Right -X, '
                                    'Up +Y, Back +Z); the bundle keeps the gr2 frame as stored' % ', '.join(
                                        '%s %s' % (k, m.art_tool[k]) for k in diff), layer))
    if m.skeleton_count > 1:
        warnings.append(warning('gr2-multiple-skeletons', model_id, '%d skeletons; only the first (%s) is used'
                                % (m.skeleton_count, m.skeleton_name), layer))
    if m.root_count > 1:
        warnings.append(warning('gr2-two-roots', model_id, '%d root bones (%s): the engine does not draw such a '
                                'model' % (m.root_count, ', '.join(b['name'] for b in m.bones if b['parent'] < 0)),
                                layer))
    bones = [{'name': b['name'], 'parent': b['parent'], 'rest': b['rest'], 'inverse_world': b['inverse_world'],
              'flags': b['flags']} for b in m.bones]
    meshes = []
    for me in m.meshes:
        streams = {}
        for name, tname, count, _off in me.members:
            spec = GR2_TYPES.get(tname) if isinstance(tname, str) else None
            if name in me.streams and spec:
                dtype, decode, normalized = spec
                view = writer.add(me.streams[name], dtype, components=int(count), normalized=normalized)
                streams[name] = {'view': view, 'gr2_type': tname, 'decode': decode}
            elif me.vertex_count:
                streams[name] = {'view': None, 'gr2_type': str(tname), 'decode': None,
                                 'unavailable_reason': 'vertex-member-type-%s' % tname}
                warnings.append(warning('vertex-member-unsupported', model_id, 'mesh %s: vertex member %s of type '
                                        '%s is not read' % (me.name, name, tname), layer))
        indices = writer.add(me.indices, me.index_dtype, components=1)
        groups = []
        for mat_index, first, count in me.groups:
            binding = me.materials[mat_index] if 0 <= mat_index < len(me.materials) else None
            if binding is None:
                warnings.append(warning('material-unbound', model_id, 'mesh %s: triangle group %d..%d names material '
                                        'binding %d, which is missing' % (me.name, first, first + count, mat_index),
                                        layer))
            groups.append({'material': '%s#%s' % (material_file, binding) if material_file and binding else None,
                           'material_binding': binding, 'first_triangle': first, 'triangle_count': count})
        bindings = []
        for name in me.bone_names:
            i = m.bone_index(name)
            if i < 0:
                warnings.append(warning('bone-unresolved', model_id, 'mesh %s: bone binding %r names no bone of the '
                                        'skeleton' % (me.name, name), layer))
            bindings.append({'name': name, 'bone': i})
        meshes.append({'name': me.name, 'vertex_count': me.vertex_count, 'triangle_count': me.triangle_count,
                       'streams': streams, 'indices': indices, 'groups': groups, 'bone_bindings': bindings})
    rec = {'id': model_id, 'path': model_id, 'provenance': provenance, 'decodable': True, 'unavailable_reason': None,
           'compression': m.info.get('compression') or 'none', 'pointer_size': m.info.get('pointer_size') or 64,
           'root': ROOT16, 'skeleton': {'name': m.skeleton_name, 'bones': bones} if m.skeleton_count else None,
           'meshes': meshes, 'bounds': m.bounds(), 'root_count': m.root_count}
    return rec, warnings


def model_record(src, writer, *, model_id=None, provenance=None, material_file=None, layer=None):
    """(model record, warnings) for a gr2 given as a path or bytes. An undecodable file gives the unavailable record
    (decodable false, unavailable_reason) and one warning; `writer` is then left untouched."""
    data, path = load(src)
    mid = model_id or (C.logical_path(path) if path is not None else 'synthetic.gr2')
    try:
        m = _read_model(data, path)
    except Gr2Unavailable as e:
        return unavailable_model_record(mid, e.reason, e.info, provenance), [
            unavailable_warning(e.reason, mid, e.detail, layer)]
    return record_from_model(m, writer, model_id=mid, provenance=provenance, material_file=material_file,
                             layer=layer)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('files', nargs='+', help='gr2 files on disk (read only)')
    a = ap.parse_args(argv)
    for f in a.files:
        try:
            m = read_model(f)
        except Gr2Unavailable as e:
            print('%s: unavailable (%s)' % (f, e))
            continue
        dev = float(np.abs(m.rest_world() - np.linalg.inv(m.inverse_world())).max()) if m.bones else 0.0
        print('%s: %d bones (%d root), %d meshes, compression %s, rest vs InverseWorld %.1e'
              % (f, len(m.bones), m.root_count, len(m.meshes), m.info['compression'], dev))
        for me in m.meshes:
            print('  %s: %d vertices, %d triangles, members %s, %d bone bindings, materials %s'
                  % (me.name, me.vertex_count, me.triangle_count,
                     ', '.join('%s %s[%d]' % (n, t, c) for n, t, c, _ in me.members), len(me.bone_names),
                     me.materials))


if __name__ == '__main__':
    main()
