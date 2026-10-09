"""Orphan pointer fixups in an uncompressed .gr2: relocation entries whose source is not a pointer slot of any object
reachable from the root (the type tree included).

Why (2026-10-09, INC-187): an append-only writer that re-points a root array (Meshes, VertexDatas, TriTopologies,
Materials) or Model.MeshBindings to a NEW array leaves the old array in the section WITH its pointer fixups. The game's
32-bit granny2_age3de.dll then mis-sizes the 64 -> 32-bit conversion of that section and writes live memory pointers past
its end, over the next section's vertex/index data: the converted output changes with the process memory layout (a
different working-folder length), or the DLL crashes (0xC0000005). One DLL run can pass such a file. Measured on the
vanilla Shrine: re-pointing root.Meshes alone (same two pointers) made the output layout-dependent; dropping the old
array's two fixups made it identical in every layout. Vanilla files have no orphan fixups.

    python scripts/havok/gr2_fixups.py FILE.gr2 [...]          # exit 1 when any file has orphan fixups
    python scripts/havok/gr2_fixups.py --scrub IN.gr2 OUT.gr2   # drop orphan fixups (+ zero their slots), new CRC

Only the relocation table and the orphan 8-byte slots change; every reachable byte stays identical.
"""
import struct
import sys
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from gr2_read import (Gr2, T_ARRAY_OF_REFS, T_EMPTY_REF, T_INLINE, T_REF, T_REF_TO_ARRAY,  # noqa: E402
                      T_REF_TO_VARIANT_ARRAY, T_STRING, T_VARIANT_REF)

POINTERISH = (T_REF, T_REF_TO_ARRAY, T_ARRAY_OF_REFS, T_VARIANT_REF, T_REF_TO_VARIANT_ARRAY, T_STRING, T_EMPTY_REF)


class Walker:
    def __init__(self, g):
        self.g, self.P = g, g.ptr
        self.slots = set()                # (sec, off) of every legitimate pointer field
        self._lay, self._ptrs, self._types, self._objs = {}, {}, set(), set()

    def layout(self, tref):
        if tref not in self._lay:
            self._lay[tref] = self.g.layout(*tref)
        return self._lay[tref]

    def has_pointers(self, tref, _stack=()):
        if tref not in self._ptrs:
            if tref in _stack:
                return True
            lay, _ = self.layout(tref)
            self._ptrs[tref] = any(m['type'] in POINTERISH or (m['type'] == T_INLINE and
                                   self.has_pointers(m['ref'], _stack + (tref,))) for m, _ in lay)
        return self._ptrs[tref]

    def walk_type(self, tref):
        """a type definition is itself data: each member record has a name pointer and a ref-type pointer"""
        if tref is None or tref in self._types:
            return
        self._types.add(tref)
        stride = 4 + self.P + self.P + 4 + 12 + self.P
        sec, off = tref
        for i, m in enumerate(self.g.typedef(*tref)):
            o = off + i * stride
            for slot in (o + 4, o + 4 + self.P):
                if self.g.deref(sec, slot):
                    self.slots.add((sec, slot))
            if m['ref']:
                self.walk_type(m['ref'])

    def walk_obj(self, tref, sec, off):
        key = (tref, sec, off)
        if tref is None or key in self._objs:
            return
        self._objs.add(key)
        self.walk_type(tref)
        if not self.has_pointers(tref):
            return
        g, P = self.g, self.P
        for m, mo in self.layout(tref)[0]:
            t, o = m['type'], off + mo
            if t in (T_STRING, T_EMPTY_REF):
                self.slots.add((sec, o))
            elif t == T_REF:
                self.slots.add((sec, o))
                p = g.deref(sec, o)
                if p and m['ref']:
                    self.walk_obj(m['ref'], *p)
            elif t == T_REF_TO_ARRAY:
                self.slots.add((sec, o + 4))
                n, p = g.i32(sec, o), g.deref(sec, o + 4)
                if p and n > 0 and m['ref']:
                    self.walk_type(m['ref'])
                    if self.has_pointers(m['ref']):
                        size = g.struct_size(*m['ref'])
                        for k in range(n):
                            self.walk_obj(m['ref'], p[0], p[1] + k * size)
            elif t == T_ARRAY_OF_REFS:
                self.slots.add((sec, o + 4))
                n, p = g.i32(sec, o), g.deref(sec, o + 4)
                if p and n > 0:
                    for k in range(n):
                        self.slots.add((p[0], p[1] + k * P))
                        q = g.deref(p[0], p[1] + k * P)
                        if q and m['ref']:
                            self.walk_obj(m['ref'], *q)
            elif t == T_VARIANT_REF:
                self.slots.update({(sec, o), (sec, o + P)})
                tp, op = g.deref(sec, o), g.deref(sec, o + P)
                self.walk_type(tp)
                if tp and op:
                    self.walk_obj(tp, *op)
            elif t == T_REF_TO_VARIANT_ARRAY:
                self.slots.update({(sec, o), (sec, o + P + 4)})
                tp, n, dp = g.deref(sec, o), g.i32(sec, o + P), g.deref(sec, o + P + 4)
                self.walk_type(tp)
                if tp and dp and n > 0 and self.has_pointers(tp):
                    size = g.struct_size(*tp)
                    for k in range(n):
                        self.walk_obj(tp, dp[0], dp[1] + k * size)
            elif t == T_INLINE and m['ref']:
                size = g.struct_size(*m['ref'])
                for k in range(max(m['count'], 1)):
                    self.walk_obj(m['ref'], sec, o + k * size)


def orphan_fixups(path):
    """-> dict(fixups, reachable_slots, orphans=[(sec, off, target_sec, target_off)], bits)"""
    g = Gr2(str(path))
    if g.ptr != 8 and g.ptr != 4:
        raise ValueError('unknown pointer size')
    w = Walker(g)
    w.walk_obj((g.root_type_sec, g.root_type_off), g.root_sec, g.root_off)
    orphans = sorted((s, o, t[0], t[1]) for (s, o), t in g.reloc.items() if (s, o) not in w.slots)
    return dict(fixups=len(g.reloc), reachable_slots=len(w.slots), orphans=orphans, bits=8 * g.ptr)


def scrub(src, dst):
    """drop orphan fixups, zero their pointer slots, rewrite the CRC. Reachable bytes are untouched."""
    src, dst = Path(src), Path(dst)
    if dst.exists() or dst.resolve() == src.resolve():
        raise ValueError('output must be a new file')
    rep = orphan_fixups(src)
    g = Gr2(str(src))
    b = bytearray(src.read_bytes())
    drop = {(s, o) for s, o, _, _ in rep['orphans']}
    for i, s in enumerate(g.sections):
        rel = [struct.unpack_from('<III', b, s['reloc_off'] + 12 * k) for k in range(s['reloc_count'])]
        keep = [r for r in rel if (i, r[0]) not in drop]
        if len(keep) == len(rel):
            continue
        for r in rel:
            if (i, r[0]) in drop:
                b[s['data_off'] + r[0]:s['data_off'] + r[0] + g.ptr] = bytes(g.ptr)
        b[s['reloc_off']:s['reloc_off'] + 12 * len(rel)] = b''.join(struct.pack('<III', *r) for r in keep) + \
            bytes(12 * (len(rel) - len(keep)))
        struct.pack_into('<I', b, g.sec_table + 44 * i + 32, len(keep))
    struct.pack_into('<I', b, 40, zlib.crc32(bytes(b[g.sec_table:])) & 0xffffffff)
    dst.write_bytes(b)
    after = orphan_fixups(dst)
    if after['orphans'] or not Gr2(str(dst)).crc_check():
        raise RuntimeError(f'scrub failed: {len(after["orphans"])} orphans left')
    return dict(dropped=len(drop), fixups_before=rep['fixups'], fixups_after=after['fixups'])


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv[:1] == ['--scrub'] and len(argv) == 3:
        print(scrub(argv[1], argv[2]))
        return 0
    bad = 0
    for p in argv:
        r = orphan_fixups(p)
        bad += bool(r['orphans'])
        print(f"{'FAIL' if r['orphans'] else 'PASS'}  {len(r['orphans']):5d} orphan of {r['fixups']:6d} fixups  {Path(p).name}"
              + (f"  first {r['orphans'][:3]}" if r['orphans'] else ''))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
