"""Granny 2 (.gr2) reader for AoE3DE models - enough to list sections, relocations, the type
tree and the skeleton, and to verify the header CRC. Uncompressed sections only (vanilla).

    python gr2_read.py file.gr2            # summary + skeleton
"""
import struct, sys, zlib

MAGIC64 = bytes.fromhex('e59b495e6f631f141e13eba990beedc4')
MAGIC32 = bytes.fromhex('29de6cc0baa4532b25f5b7a5f666e2ee')
COMP = {0: 'none', 1: 'oodle0', 2: 'oodle1', 4: 'bitknit'}

# granny member types (granny_member_type)
T_END, T_INLINE, T_REF, T_REF_TO_ARRAY, T_ARRAY_OF_REFS, T_VARIANT_REF, T_REMOVED6, T_REF_TO_VARIANT_ARRAY, T_STRING, \
    T_TRANSFORM, T_REAL32, T_INT8, T_UINT8, T_BINORMAL_INT8, T_NORMAL_UINT8, T_INT16, T_UINT16, T_BINORMAL_INT16, \
    T_NORMAL_UINT16, T_INT32, T_UINT32, T_REAL16, T_EMPTY_REF = range(23)   # 6 is Granny's removed/unsupported slot


class Gr2:
    def __init__(self, path):
        self.data = d = open(path, 'rb').read()
        self.magic = d[:16]
        self.ptr = 8 if self.magic == MAGIC64 else 4
        assert self.magic in (MAGIC64, MAGIC32), 'not a gr2'
        self.header_size, self.header_fmt = struct.unpack_from('<II', d, 16)
        h = 32
        (self.version, self.file_size, self.crc, self.sec_off, self.sec_count,
         self.root_type_sec, self.root_type_off, self.root_sec, self.root_off, self.user_tag) = struct.unpack_from('<10I', d, h)
        self.sections = []
        self.sec_table = 32 + self.sec_off          # SectionArrayOffset is relative to the 32-byte magic block
        for i in range(self.sec_count):
            o = self.sec_table + 44 * i
            f = struct.unpack_from('<11I', d, o)
            self.sections.append(dict(compression=f[0], data_off=f[1], data_size=f[2], expanded=f[3], align=f[4],
                                      first16=f[5], first8=f[6], reloc_off=f[7], reloc_count=f[8], marsh_off=f[9], marsh_count=f[10]))
        # section payloads (raw only) and relocation maps: (sec, off) -> (target_sec, target_off)
        self.payload = []; self.reloc = {}
        for i, s in enumerate(self.sections):
            if s['compression'] != 0 and s['data_size']:
                raise NotImplementedError(f"section {i} is {COMP.get(s['compression'], s['compression'])}-compressed")
            self.payload.append(bytearray(d[s['data_off']:s['data_off'] + s['data_size']]))
            for k in range(s['reloc_count']):
                so, ts, to = struct.unpack_from('<III', d, s['reloc_off'] + 12 * k)
                self.reloc[(i, so)] = (ts, to)

    # --- CRC: Granny stores crc32 of everything after the header (section table + payloads)
    def crc_check(self):
        return zlib.crc32(self.data[self.sec_table:]) & 0xffffffff == self.crc

    # --- pointer following: a pointer FIELD at (sec, off) resolves through the relocation table
    def deref(self, sec, off):
        return self.reloc.get((sec, off))

    def u32(self, sec, off): return struct.unpack_from('<I', self.payload[sec], off)[0]
    def i32(self, sec, off): return struct.unpack_from('<i', self.payload[sec], off)[0]
    def f32(self, sec, off): return struct.unpack_from('<f', self.payload[sec], off)[0]
    def cstr(self, sec, off):
        b = self.payload[sec]; e = b.index(b'\0', off); return b[off:e].decode('utf-8', 'replace')

    # --- type definitions: array of members, each: type i32, name ptr, ref-type ptr, arraySize i32, extra[3] i32, unused (ptr)
    def typedef(self, sec, off):
        members = []; P = self.ptr
        stride = 4 + P + P + 4 + 12 + P
        while True:
            t = self.i32(sec, off)
            if t == T_END: break
            name = self.deref(sec, off + 4); ref = self.deref(sec, off + 4 + P)
            n = self.i32(sec, off + 4 + 2 * P)
            members.append(dict(type=t, name=self.cstr(*name) if name else None, ref=ref, count=n, off=off))
            off += stride
        return members

    def member_size(self, m):
        P = self.ptr
        if m['type'] == T_INLINE: return self.struct_size(*m['ref']) * max(m['count'], 1)
        if m['type'] in (T_REF, T_VARIANT_REF): return P if m['type'] == T_REF else 2 * P
        if m['type'] in (T_REF_TO_ARRAY, T_ARRAY_OF_REFS):
            return 4 + P                        # int32 count then the pointer - no padding (relocation table proves it)
        if m['type'] == T_REF_TO_VARIANT_ARRAY:
            return P + 4 + P                    # type pointer, count, data pointer
        if m['type'] == T_STRING: return P
        if m['type'] == T_TRANSFORM: return 4 + 12 + 16 + 36
        if m['type'] in (T_REAL32, T_INT32, T_UINT32): return 4 * max(m['count'], 1)
        if m['type'] in (T_INT16, T_UINT16, T_BINORMAL_INT16, T_NORMAL_UINT16, T_REAL16): return 2 * max(m['count'], 1)
        if m['type'] in (T_INT8, T_UINT8, T_BINORMAL_INT8, T_NORMAL_UINT8): return 1 * max(m['count'], 1)
        if m['type'] == T_EMPTY_REF: return P
        raise ValueError(f"unknown member type {m['type']}")

    def member_align(self, m):
        P = self.ptr
        if m['type'] == T_INLINE: return max((self.member_align(x) for x in self.typedef(*m['ref'])), default=4)
        if m['type'] in (T_REF, T_VARIANT_REF, T_REF_TO_ARRAY, T_ARRAY_OF_REFS, T_REF_TO_VARIANT_ARRAY, T_STRING, T_EMPTY_REF): return 4   # 8-byte pointers at 4-byte alignment in gr2 files
        if m['type'] in (T_INT8, T_UINT8, T_BINORMAL_INT8, T_NORMAL_UINT8): return 1
        if m['type'] in (T_INT16, T_UINT16, T_BINORMAL_INT16, T_NORMAL_UINT16, T_REAL16): return 2
        return 4

    def layout(self, sec, off):
        """-> list of (member, offset) with natural alignment, and total struct size"""
        out = []; pos = 0; maxa = 1
        for m in self.typedef(sec, off):
            a = self.member_align(m); maxa = max(maxa, a)
            pos = (pos + a - 1) // a * a
            out.append((m, pos)); pos += self.member_size(m)
        return out, (pos + maxa - 1) // maxa * maxa

    def struct_size(self, sec, off): return self.layout(sec, off)[1]

    # --- generic record read
    def read(self, tsec, toff, dsec, doff, depth=0):
        out = {}
        for m, mo in self.layout(tsec, toff)[0]:
            t = m['type']; o = doff + mo; name = m['name']
            if t == T_STRING:
                p = self.deref(dsec, o); out[name] = self.cstr(*p) if p else None
            elif t == T_REF:
                p = self.deref(dsec, o); out[name] = ('ref', p, m['ref'])
            elif t == T_REF_TO_ARRAY:
                n = self.i32(dsec, o); p = self.deref(dsec, o + 4); out[name] = ('array', n, p, m['ref'])
            elif t == T_ARRAY_OF_REFS:
                n = self.i32(dsec, o); p = self.deref(dsec, o + 4); out[name] = ('refarray', n, p, m['ref'])
            elif t == T_REF_TO_VARIANT_ARRAY:
                tp = self.deref(dsec, o); n = self.i32(dsec, o + self.ptr); dp = self.deref(dsec, o + self.ptr + 4)
                out[name] = ('varray', tp, n, dp)
            elif t == T_VARIANT_REF:
                tp = self.deref(dsec, o); op = self.deref(dsec, o + self.ptr); out[name] = ('variant', tp, op)
            elif t == T_INLINE:
                out[name] = self.read(*m['ref'], dsec, o, depth + 1) if m['count'] <= 1 else '<inline array>'
            elif t == T_TRANSFORM:
                out[name] = struct.unpack_from('<I3f4f9f', self.payload[dsec], o)
            elif t == T_INT32: out[name] = struct.unpack_from('<%di' % max(m['count'], 1), self.payload[dsec], o)
            elif t == T_UINT32: out[name] = struct.unpack_from('<%dI' % max(m['count'], 1), self.payload[dsec], o)
            elif t == T_REAL32: out[name] = struct.unpack_from('<%df' % max(m['count'], 1), self.payload[dsec], o)
            else: out[name] = f'<type {t}>'
        return out

    def array(self, arr):
        """('array', n, (sec,off), (tsec,toff)) -> list of records"""
        _, n, p, tref = arr
        if not p or n == 0: return []
        size = self.struct_size(*tref)
        return [self.read(*tref, p[0], p[1] + i * size) for i in range(n)]

    def root(self):
        return self.read(self.root_type_sec, self.root_type_off, self.root_sec, self.root_off)


if __name__ == '__main__':
    g = Gr2(sys.argv[1])
    print(f'{sys.argv[1]}: {"64" if g.ptr == 8 else "32"}-bit, version {g.version}, {g.sec_count} sections, crc ok: {g.crc_check()}')
    for i, s in enumerate(g.sections):
        print(f"  sec {i}: {COMP.get(s['compression'])} size {s['data_size']} first16 {s['first16']} first8 {s['first8']} relocs {s['reloc_count']} marsh {s['marsh_count']}")
    r = g.root()
    print('root members:', list(r.keys()))
    for sk in g.array(r['Skeletons'] if r['Skeletons'][0] == 'array' else ('array', 0, None, None)):
        pass
    skels = r.get('Skeletons')
    if skels and skels[0] == 'refarray':
        _, n, p, tref = skels
        for i in range(n):
            sp = g.deref(p[0], p[1] + i * g.ptr)
            sk = g.read(*tref, *sp)
            bones = g.array(sk['Bones'])
            print(f"skeleton '{sk['Name']}': {len(bones)} bones, LODType {sk.get('LODType')}")
            for b in bones[:8] + bones[-3:]:
                lt = b['LocalTransform']; print(f"   {b['Name']:34} parent={b['ParentIndex'][0]:4} pos={tuple(round(x,3) for x in lt[1:4])} quat={tuple(round(x,3) for x in lt[4:8])} lod={b.get('LODError')}")
    print('meshes:', r['Meshes'][1] if r.get('Meshes') else None, '| models:', r['Models'][1] if r.get('Models') else None)
