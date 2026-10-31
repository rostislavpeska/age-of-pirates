"""Synthetic Granny 2 (.gr2) writer for the aoe3de-anim-viewer tests: fixtures are built inside the tests, no game bytes.

Writes the layout the consumer's reader (scripts/havok/gr2_read.py) parses in vanilla AoE3 DE files: the little-endian
64-bit magic, file format 7, a 72-byte file info block (section table at 32 + 72), one uncompressed section holding
type definitions and objects, pointers as relocation records (null = no record), member type definitions of 44 bytes
(type, name pointer, type pointer, count, 3 extra ints, an unused pointer), objects at natural alignment with 4-byte
aligned pointers, REF_TO_ARRAY = int32 count + pointer, VARIANT_REF = type pointer + object pointer, transforms as
uint32 flags + 16 floats. The header CRC is crc32 of everything after the file info block, as the reader checks.

The higher-level builders (build_model, build_clip) shape the records the way vanilla models and clips are shaped
(member names as in iron_rider_0.gr2 and oprichnik_attack_a.gr2). This module has its own maths (quat_matrix,
compose) so a test compares the reader against an independent construction.
"""
import struct
import zlib

import numpy as np

MAGIC64 = bytes.fromhex('e59b495e6f631f141e13eba990beedc4')
MAGIC32 = bytes.fromhex('29de6cc0baa4532b25f5b7a5f666e2ee')
MAGIC32_V6 = bytes.fromhex('b867b0caf86db10f84728c7e5e19001e')

(END, INLINE, REF, REF_TO_ARRAY, ARRAY_OF_REFS, VARIANT_REF, REMOVED, REF_TO_VARIANT_ARRAY, STRING, TRANSFORM, REAL32,
 INT8, UINT8, BINORMAL_INT8, NORMAL_UINT8, INT16, UINT16, BINORMAL_INT16, NORMAL_UINT16, INT32, UINT32, REAL16,
 EMPTY_REF) = range(23)
P = 8
SCALAR = {REAL32: ('f', 4), INT32: ('i', 4), UINT32: ('I', 4), INT16: ('h', 2), UINT16: ('H', 2),
          BINORMAL_INT16: ('h', 2), NORMAL_UINT16: ('H', 2), REAL16: ('e', 2), INT8: ('b', 1), UINT8: ('B', 1),
          BINORMAL_INT8: ('b', 1), NORMAL_UINT8: ('B', 1)}
CURVE_CODE = {'Keyframes32f': 0, 'K32fC32f': 1, 'Identity': 2, 'Constant32f': 3, 'D3Constant32f': 4,
              'D4Constant32f': 5, 'K16uC16u': 6, 'D4nK16uC15u': 8, 'D3K16uC16u': 10}


class Type:
    """a Granny struct type: members (name, member type, count, referenced Type or None)."""

    def __init__(self, *members):
        self.members = [m if len(m) == 4 else tuple(m) + (None,) * (4 - len(m)) for m in members]


def m(name, t, count=0, ref=None):
    return (name, t, count, ref)


def _align(x, a):
    return (x + a - 1) // a * a


def size_align(member):
    _, t, count, ref = member
    n = max(count, 1)
    if t == INLINE:
        return layout(ref)[1] * n, max([size_align(x)[1] for x in ref.members] or [4])
    if t == REF:
        return P, 4
    if t == VARIANT_REF:
        return 2 * P, 4
    if t in (REF_TO_ARRAY, ARRAY_OF_REFS):
        return 4 + P, 4
    if t == REF_TO_VARIANT_ARRAY:
        return P + 4 + P, 4
    if t in (STRING, EMPTY_REF):
        return P, 4
    if t == TRANSFORM:
        return 68, 4
    _, sz = SCALAR[t]
    return sz * n, min(sz, 4)


def layout(t):
    """([offset per member], struct size): natural alignment, size rounded to the largest member alignment."""
    pos, maxa, offs = 0, 1, []
    for mem in t.members:
        s, a = size_align(mem)
        maxa = max(maxa, a)
        pos = _align(pos, a)
        offs.append(pos)
        pos += s
    return offs, _align(pos, maxa)


class Raw:
    """the elements of a REF_TO_ARRAY given as bytes (count elements)."""

    def __init__(self, count, data):
        self.count, self.data = count, bytes(data)


class Writer:
    def __init__(self):
        self.buf = bytearray()
        self.relocs = []
        self._types = {}
        self._strings = {}

    def alloc(self, size, align=8):
        off = _align(len(self.buf), align)
        self.buf.extend(b'\0' * (off + size - len(self.buf)))
        return off

    def raw(self, data, align=8):
        off = self.alloc(len(data), align)
        self.buf[off:off + len(data)] = data
        return off

    def ptr(self, at, target):
        if target is not None:
            self.relocs.append((at, target))

    def cstr(self, s):
        if s not in self._strings:
            self._strings[s] = self.raw(s.encode('utf-8') + b'\0', 1)
        return self._strings[s]

    def typedef(self, t):
        key = id(t)
        if key in self._types:
            return self._types[key]
        stride = 4 + P + P + 4 + 12 + P
        off = self.alloc(stride * (len(t.members) + 1), 8)
        self._types[key] = off
        for i, (name, typ, count, ref) in enumerate(t.members):
            at = off + i * stride
            struct.pack_into('<i', self.buf, at, typ)
            self.ptr(at + 4, self.cstr(name))
            if ref is not None:
                self.ptr(at + 4 + P, self.typedef(ref))
            struct.pack_into('<i', self.buf, at + 4 + 2 * P, count)
        return off

    def obj(self, t, values):
        _, size = layout(t)
        off = self.alloc(size, 8)
        self.fill(t, off, values)
        return off

    def fill(self, t, base, values):
        offs, _ = layout(t)
        for (name, typ, count, ref), off in zip(t.members, offs):
            v = values.get(name)
            at = base + off
            if v is None:
                continue
            if typ == STRING:
                self.ptr(at, self.cstr(v))
            elif typ == REF:
                self.ptr(at, v)
            elif typ == REF_TO_ARRAY:
                if isinstance(v, Raw):
                    n, doff = v.count, (self.raw(v.data) if v.count else None)
                else:
                    n = len(v)
                    esize = layout(ref)[1]
                    doff = self.alloc(esize * n, 8) if n else None
                    for i, e in enumerate(v):
                        self.fill(ref, doff + i * esize, e)
                struct.pack_into('<i', self.buf, at, n)
                self.ptr(at + 4, doff)
            elif typ == ARRAY_OF_REFS:
                doff = self.alloc(P * len(v), 8) if v else None
                for i, o in enumerate(v):
                    self.ptr(doff + i * P, o)
                struct.pack_into('<i', self.buf, at, len(v))
                self.ptr(at + 4, doff)
            elif typ == VARIANT_REF:
                vt, vo = v
                self.ptr(at, self.typedef(vt))
                self.ptr(at + P, vo)
            elif typ == REF_TO_VARIANT_ARRAY:
                vt, n, doff = v
                self.ptr(at, self.typedef(vt))
                struct.pack_into('<i', self.buf, at + P, n)
                self.ptr(at + P + 4, doff)
            elif typ == TRANSFORM:
                struct.pack_into('<I16f', self.buf, at, int(v[0]), *[float(x) for x in v[1:17]])
            elif typ == INLINE:
                self.fill(ref, at, v)
            elif typ in SCALAR:
                code, _ = SCALAR[typ]
                vals = list(v) if isinstance(v, (list, tuple, np.ndarray)) else [v]
                struct.pack_into('<%d%s' % (len(vals), code), self.buf, at, *vals)

    def file(self, root_type, root_off, *, compression=0, magic=MAGIC64, version=7):
        root_type_off = self.typedef(root_type)
        data = bytes(self.buf) + b'\0' * ((-len(self.buf)) % 4)
        relocs = sorted(self.relocs)
        n_sec = 1
        header_size = 32 + 72 + 44 * n_sec
        data_off = header_size
        reloc_off = data_off + len(data)
        marsh_off = reloc_off + 12 * len(relocs)
        section = struct.pack('<11I', compression, data_off, len(data), len(data), 4, len(data), len(data),
                              reloc_off, len(relocs), marsh_off, 0)
        tail = section + data + b''.join(struct.pack('<3I', s, 0, t) for s, t in relocs)
        file_size = 32 + 72 + len(tail)
        crc = zlib.crc32(tail) & 0xffffffff
        info = struct.pack('<10I', version, file_size, crc, 72, n_sec, 0, root_type_off, 0, root_off, 0x80000039) \
            + b'\0' * 32
        head = magic + struct.pack('<II', header_size, 0) + b'\0' * 8
        return head + info + tail


# ------------------------------------------------------------------------------------------------ Granny-shaped types
REAL32_ELEM = Type(m('Real32', REAL32))
INT32_ELEM = Type(m('Int32', INT32))
UINT16_ELEM = Type(m('UInt16', UINT16))
ART_TOOL = Type(m('FromArtToolName', STRING), m('ArtToolMajorRevision', INT32), m('ArtToolMinorRevision', INT32),
                m('ArtToolPointerSize', INT32), m('UnitsPerMeter', REAL32), m('Origin', REAL32, 3),
                m('RightVector', REAL32, 3), m('UpVector', REAL32, 3), m('BackVector', REAL32, 3),
                m('ExtendedData', VARIANT_REF))
BONE = Type(m('Name', STRING), m('ParentIndex', INT32), m('Transform', TRANSFORM),
            m('InverseWorldTransform', REAL32, 16), m('LODError', REAL32), m('ExtendedData', VARIANT_REF))
SKELETON = Type(m('Name', STRING), m('Bones', REF_TO_ARRAY, 0, BONE), m('LODType', INT32), m('ExtendedData', VARIANT_REF))
MATERIAL = Type(m('Name', STRING), m('Maps', REF_TO_ARRAY, 0, INT32_ELEM), m('Texture', EMPTY_REF),
                m('ExtendedData', VARIANT_REF))
MATERIAL_BINDING = Type(m('Material', REF, 0, MATERIAL))
BONE_BINDING = Type(m('BoneName', STRING), m('OBBMin', REAL32, 3), m('OBBMax', REAL32, 3),
                    m('TriangleIndices', REF_TO_ARRAY, 0, INT32_ELEM))
GROUP = Type(m('MaterialIndex', INT32), m('TriFirst', INT32), m('TriCount', INT32))
TOPOLOGY = Type(m('Groups', REF_TO_ARRAY, 0, GROUP), m('Indices', REF_TO_ARRAY, 0, INT32_ELEM),
                m('Indices16', REF_TO_ARRAY, 0, UINT16_ELEM))
VERTEX_DATA = Type(m('Vertices', REF_TO_VARIANT_ARRAY), m('VertexComponentNames', REF_TO_ARRAY, 0, INT32_ELEM),
                   m('VertexAnnotationSets', REF_TO_ARRAY, 0, INT32_ELEM))
MESH = Type(m('Name', STRING), m('PrimaryVertexData', REF, 0, VERTEX_DATA), m('MorphTargets', REF_TO_ARRAY, 0, INT32_ELEM),
            m('PrimaryTopology', REF, 0, TOPOLOGY), m('MaterialBindings', REF_TO_ARRAY, 0, MATERIAL_BINDING),
            m('BoneBindings', REF_TO_ARRAY, 0, BONE_BINDING), m('ExtendedData', VARIANT_REF))
MESH_BINDING = Type(m('Mesh', REF, 0, MESH))
MODEL = Type(m('Name', STRING), m('Skeleton', REF, 0, SKELETON), m('InitialPlacement', TRANSFORM),
             m('MeshBindings', REF_TO_ARRAY, 0, MESH_BINDING), m('ExtendedData', VARIANT_REF))
CURVE_HEADER = Type(m('Format', UINT8), m('Degree', UINT8))
CURVE_K32F = Type(m('CurveDataHeader_DaK32fC32f', INLINE, 0, CURVE_HEADER), m('Padding', INT16),
                  m('Knots', REF_TO_ARRAY, 0, REAL32_ELEM), m('Controls', REF_TO_ARRAY, 0, REAL32_ELEM))
CURVE_IDENTITY = Type(m('CurveDataHeader_DaIdentity', INLINE, 0, CURVE_HEADER), m('Dimension', INT16))
CURVE_CONST = Type(m('CurveDataHeader_DaConstant32f', INLINE, 0, CURVE_HEADER), m('Padding', INT16),
                   m('Controls', REF_TO_ARRAY, 0, REAL32_ELEM))
CURVE_D3CONST = Type(m('CurveDataHeader_D3Constant32f', INLINE, 0, CURVE_HEADER), m('Padding', INT16),
                     m('Controls', REAL32, 3))
CURVE_D4CONST = Type(m('CurveDataHeader_D4Constant32f', INLINE, 0, CURVE_HEADER), m('Padding', INT16),
                     m('Controls', REAL32, 4))
CURVE_QUANT = Type(m('CurveDataHeader_D4nK16uC15u', INLINE, 0, CURVE_HEADER), m('ScaleOffsetTableEntries', UINT16),
                   m('OneOverKnotScale', REAL32), m('KnotsControls', REF_TO_ARRAY, 0, UINT16_ELEM))
CURVE2 = Type(m('CurveData', VARIANT_REF))
TRANSFORM_TRACK = Type(m('Name', STRING), m('Flags', INT32), m('OrientationCurve', INLINE, 0, CURVE2),
                       m('PositionCurve', INLINE, 0, CURVE2), m('ScaleShearCurve', INLINE, 0, CURVE2))
TRACK_GROUP = Type(m('Name', STRING), m('VectorTracks', REF_TO_ARRAY, 0, INT32_ELEM),
                   m('TransformTracks', REF_TO_ARRAY, 0, TRANSFORM_TRACK),
                   m('TransformLODErrors', REF_TO_ARRAY, 0, REAL32_ELEM), m('TextTracks', REF_TO_ARRAY, 0, INT32_ELEM),
                   m('InitialPlacement', TRANSFORM), m('AccumulationFlags', INT32), m('LoopTranslation', REAL32, 3),
                   m('PeriodicLoop', EMPTY_REF), m('ExtendedData', VARIANT_REF))
ANIMATION = Type(m('Name', STRING), m('Duration', REAL32), m('TimeStep', REAL32), m('Oversampling', REAL32),
                 m('TrackGroups', ARRAY_OF_REFS, 0, TRACK_GROUP), m('DefaultLoopCount', INT32), m('Flags', INT32),
                 m('ExtendedData', VARIANT_REF))
FILE_INFO = Type(m('ArtToolInfo', REF, 0, ART_TOOL), m('FromFileName', STRING),
                 m('Textures', ARRAY_OF_REFS, 0, INT32_ELEM), m('Materials', ARRAY_OF_REFS, 0, MATERIAL),
                 m('Skeletons', ARRAY_OF_REFS, 0, SKELETON), m('VertexDatas', ARRAY_OF_REFS, 0, VERTEX_DATA),
                 m('TriTopologies', ARRAY_OF_REFS, 0, TOPOLOGY), m('Meshes', ARRAY_OF_REFS, 0, MESH),
                 m('Models', ARRAY_OF_REFS, 0, MODEL), m('TrackGroups', ARRAY_OF_REFS, 0, TRACK_GROUP),
                 m('Animations', ARRAY_OF_REFS, 0, ANIMATION), m('ExtendedData', VARIANT_REF))

VERTEX_TYPES = {'real32': REAL32, 'real16': REAL16, 'binormal_int8': BINORMAL_INT8, 'normal_uint8': NORMAL_UINT8,
                'uint8': UINT8, 'int8': INT8, 'int16': INT16, 'uint16': UINT16, 'binormal_int16': BINORMAL_INT16,
                'normal_uint16': NORMAL_UINT16, 'int32': INT32, 'uint32': UINT32}
VANILLA_ART_TOOL = {'FromArtToolName': 'synthetic', 'ArtToolMajorRevision': 1, 'ArtToolMinorRevision': 9,
                    'ArtToolPointerSize': 64, 'UnitsPerMeter': 1.5625, 'Origin': [0, 0, 0],
                    'RightVector': [-1, 0, 0], 'UpVector': [0, 1, 0], 'BackVector': [0, 0, 1]}


# ------------------------------------------------------------------------------------------------ independent maths
def quat_matrix(q):
    """unit quaternion (x, y, z, w) -> ROW-vector rotation matrix (p' = p @ R)."""
    x, y, z, w = q
    col = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                    [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                    [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    return col.T


def effective(t):
    """a transform tuple with Granny's flags applied: (position, quaternion, 3x3 scale-shear)."""
    f = int(t[0])
    p = np.array(t[1:4], float) if f & 1 else np.zeros(3)
    q = np.array(t[4:8], float) if f & 2 else np.array([0, 0, 0, 1.0])
    s = np.array(t[8:17], float).reshape(3, 3) if f & 4 else np.eye(3)
    return p, q, s


def local4(t):
    p, q, s = effective(t)
    M = np.eye(4)
    M[:3, :3] = quat_matrix(q) @ s
    M[3, :3] = p
    return M


def compose(bones):
    """world rest matrices of bone dicts {transform, parent} (parents first)."""
    W = []
    for b in bones:
        L = local4(b['transform'])
        W.append(L @ W[b['parent']] if b['parent'] >= 0 else L)
    return W


def transform(position=(0, 0, 0), quaternion=(0, 0, 0, 1), scale_shear=(1, 0, 0, 0, 1, 0, 0, 0, 1), flags=7):
    return (flags,) + tuple(float(x) for x in position) + tuple(float(x) for x in quaternion) + \
        tuple(float(x) for x in scale_shear)


def axis_quat(axis, degrees):
    a = np.radians(degrees) / 2
    v = np.asarray(axis, float) / np.linalg.norm(axis)
    return tuple(np.append(v * np.sin(a), np.cos(a)))


# ------------------------------------------------------------------------------------------------ vertex packing
def vertex_layout(members):
    """[(name, gr2 type name, count, offset)], stride - the natural layout gr2_read computes for a vertex type."""
    t = Type(*[m(n, VERTEX_TYPES[tn], c) for n, tn, c in members])
    offs, stride = layout(t)
    return [(n, tn, c, o) for (n, tn, c), o in zip(members, offs)], stride, t


def pack_vertices(members, columns):
    """interleaved vertex bytes: columns {member name: (n, count) array} in the member types."""
    lay, stride, t = vertex_layout(members)
    n = len(next(iter(columns.values())))
    buf = bytearray(stride * n)
    for name, tn, c, off in lay:
        code, _ = SCALAR[VERTEX_TYPES[tn]]
        col = np.asarray(columns[name]).reshape(n, c)
        for i in range(n):
            struct.pack_into('<%d%s' % (c, code), buf, i * stride + off, *col[i].tolist())
    return bytes(buf), stride, t


# ------------------------------------------------------------------------------------------------ files
def build_model(bones, meshes, *, art_tool=VANILLA_ART_TOOL, compression=0, magic=MAGIC64, skeleton='Bip01_Root',
                extra_skeletons=0, mesh_bindings=None):
    """a model gr2. bones: [{name, parent, transform (17-tuple), inverse_world (16) or None = from compose()}];
    meshes: [{name, members [(name, gr2 type, count)], columns {name: array}, indices [ints], indices16 bool,
    groups [(material index, first, count)], materials [names], bone_names [names]}]."""
    w = Writer()
    W = compose(bones)
    bone_vals = []
    for b, Wb in zip(bones, W):
        iw = b.get('inverse_world')
        iw = list(np.linalg.inv(Wb).ravel()) if iw is None else list(iw)
        bone_vals.append({'Name': b['name'], 'ParentIndex': b['parent'], 'Transform': b['transform'],
                          'InverseWorldTransform': iw, 'LODError': 1.0})
    skels = [w.obj(SKELETON, {'Name': skeleton, 'Bones': bone_vals, 'LODType': 1})
             for _ in range(1 + extra_skeletons)]
    materials = {}
    mesh_offs = []
    for me in meshes:
        vbytes, stride, vtype = pack_vertices(me['members'], me['columns'])
        n = len(next(iter(me['columns'].values())))
        vd = w.obj(VERTEX_DATA, {'Vertices': (vtype, n, w.raw(vbytes, 4))})
        idx = [int(x) for x in me['indices']]
        topo_vals = {'Groups': [{'MaterialIndex': g[0], 'TriFirst': g[1], 'TriCount': g[2]} for g in me['groups']]}
        if me.get('indices16'):
            topo_vals['Indices16'] = Raw(len(idx), struct.pack('<%dH' % len(idx), *idx))
        else:
            topo_vals['Indices'] = Raw(len(idx), struct.pack('<%di' % len(idx), *idx))
        topo = w.obj(TOPOLOGY, topo_vals)
        mb = []
        for name in me['materials']:
            if name not in materials:
                materials[name] = w.obj(MATERIAL, {'Name': name})
            mb.append({'Material': materials[name]})
        mesh_offs.append(w.obj(MESH, {'Name': me['name'], 'PrimaryVertexData': vd, 'PrimaryTopology': topo,
                                      'MaterialBindings': mb,
                                      'BoneBindings': [{'BoneName': b, 'OBBMin': [0, 0, 0], 'OBBMax': [0, 0, 0]}
                                                       for b in me['bone_names']]}))
    bound = range(len(mesh_offs)) if mesh_bindings is None else mesh_bindings
    model = w.obj(MODEL, {'Name': skeleton, 'Skeleton': skels[0], 'InitialPlacement': transform(flags=0),
                         'MeshBindings': [{'Mesh': mesh_offs[i]} for i in bound]})
    root_vals = {'FromFileName': 'synthetic.mb', 'Materials': list(materials.values()), 'Skeletons': skels,
                 'Meshes': mesh_offs, 'Models': [model], 'Animations': []}
    if art_tool:
        root_vals['ArtToolInfo'] = w.obj(ART_TOOL, art_tool)
    root = w.obj(FILE_INFO, root_vals)
    return w.file(FILE_INFO, root, compression=compression, magic=magic)


def curve_object(w, spec):
    """spec: None (no curve data) | ('K32fC32f', degree, knots, controls flat) | ('Identity', dim) |
    ('Constant32f', values) | ('D3Constant32f', [3]) | ('D4Constant32f', [4]) | ('D4nK16uC15u',) |
    ('raw', format code)."""
    if spec is None:
        return {}
    kind = spec[0]
    if kind == 'K32fC32f':
        _, degree, K, Cn = spec
        o = w.obj(CURVE_K32F, {'CurveDataHeader_DaK32fC32f': {'Format': 1, 'Degree': degree},
                               'Knots': Raw(len(K), struct.pack('<%df' % len(K), *K)),
                               'Controls': Raw(len(Cn), struct.pack('<%df' % len(Cn), *Cn))})
        return {'CurveData': (CURVE_K32F, o)}
    if kind == 'Identity':
        o = w.obj(CURVE_IDENTITY, {'CurveDataHeader_DaIdentity': {'Format': 2, 'Degree': 0}, 'Dimension': spec[1]})
        return {'CurveData': (CURVE_IDENTITY, o)}
    if kind == 'Constant32f':
        vals = spec[1]
        o = w.obj(CURVE_CONST, {'CurveDataHeader_DaConstant32f': {'Format': 3, 'Degree': 0},
                                'Controls': Raw(len(vals), struct.pack('<%df' % len(vals), *vals))})
        return {'CurveData': (CURVE_CONST, o)}
    if kind in ('D3Constant32f', 'D4Constant32f'):
        t = CURVE_D3CONST if kind == 'D3Constant32f' else CURVE_D4CONST
        o = w.obj(t, {t.members[0][0]: {'Format': CURVE_CODE[kind], 'Degree': 0}, 'Controls': list(spec[1])})
        return {'CurveData': (t, o)}
    if kind == 'D4nK16uC15u':
        o = w.obj(CURVE_QUANT, {'CurveDataHeader_D4nK16uC15u': {'Format': 8, 'Degree': 1},
                                'ScaleOffsetTableEntries': 0, 'OneOverKnotScale': 1.0,
                                'KnotsControls': Raw(4, struct.pack('<4H', 0, 1, 2, 3))})
        return {'CurveData': (CURVE_QUANT, o)}
    if kind == 'raw':
        o = w.obj(CURVE_IDENTITY, {'CurveDataHeader_DaIdentity': {'Format': spec[1], 'Degree': 0}, 'Dimension': 0})
        return {'CurveData': (CURVE_IDENTITY, o)}
    raise ValueError(spec)


def build_clip(groups, *, duration=1.0, timestep=1 / 60, oversampling=8.0, name='synthetic.mb', compression=0,
               magic=MAGIC64, animations=1):
    """an animation gr2. groups: [(group name, initial placement 17-tuple, [(track name, {'OrientationCurve': spec,
    'PositionCurve': spec, 'ScaleShearCurve': spec})])]; animations > 1 repeats the animation."""
    w = Writer()
    tg_offs = []
    for gname, placement, tracks in groups:
        tvals = []
        for tname, specs in tracks:
            tvals.append({'Name': tname, 'Flags': 0,
                          **{f: curve_object(w, specs.get(f)) for f in ('OrientationCurve', 'PositionCurve',
                                                                       'ScaleShearCurve')}})
        tg_offs.append(w.obj(TRACK_GROUP, {'Name': gname, 'TransformTracks': tvals, 'InitialPlacement': placement,
                                           'LoopTranslation': [0, 0, 0]}))
    anims = [w.obj(ANIMATION, {'Name': name, 'Duration': duration, 'TimeStep': timestep, 'Oversampling': oversampling,
                               'TrackGroups': tg_offs, 'Flags': 1}) for _ in range(animations)]
    root = w.obj(FILE_INFO, {'ArtToolInfo': w.obj(ART_TOOL, VANILLA_ART_TOOL), 'FromFileName': name,
                             'Skeletons': [], 'Meshes': [], 'Models': [], 'TrackGroups': tg_offs,
                             'Animations': anims})
    return w.file(FILE_INFO, root, compression=compression, magic=magic)
