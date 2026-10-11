"""Drop listed triangles from meshes of an uncompressed .gr2 IN PLACE: the kept triangles are compacted inside the
existing index buffer (order kept), the buffer tail is zeroed, the topology's index count and every material group's
TriFirst/TriCount are rewritten, and the header CRC is recomputed. Nothing else changes: vertices, materials, skeleton,
relocations and the file size stay byte-identical, so the patch is provably minimal (--check prints the changed ranges).

    python gr2_droptris.py in.gr2 drop.json out.gr2 [--check]
    drop.json: {"meshes": {"<mesh name>": [tri, ...], ...}}   (triangle indices as gr2_lint.read_raw numbers them)
"""
import argparse, json, struct, sys, zlib
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gr2_read import Gr2          # noqa: E402
from gr2_dump import refs         # noqa: E402


def drop(src, plan, out):
    g = Gr2(str(src)); assert g.crc_check(), 'source CRC'
    assert all(s['compression'] == 0 for s in g.sections), 'compressed sections are not supported'
    d = bytearray(g.data); r = g.root(); report = {}
    fo = lambda sec, off: g.sections[sec]['data_off'] + off                       # payload (sec, off) -> file offset
    meshes = {m['Name']: m for m, _ in refs(g, r['Meshes'])}
    for name, tris in plan['meshes'].items():
        m = meshes[name]; tt = m['PrimaryTopology']; top = g.read(*tt[2], *tt[1])
        assert top['Indices16'][1] == 0, f'{name}: 16-bit indices not supported'
        for k in top:
            if k not in ('Groups', 'Indices', 'Indices16') and isinstance(top[k], tuple) and top[k] and top[k][0] == 'array':
                assert top[k][1] == 0, f'{name}: per-triangle array {k} would need compacting'
        lay = {mm['name']: off for mm, off in g.layout(*tt[2])[0]}
        n3, (isec, ibase) = top['Indices'][1], top['Indices'][2]
        T = np.frombuffer(bytes(d[fo(isec, ibase):fo(isec, ibase) + 4 * n3]), '<i4').reshape(-1, 3)
        dropset = set(int(t) for t in tris); assert all(0 <= t < len(T) for t in dropset), f'{name}: triangle out of range'
        keep = np.array([i not in dropset for i in range(len(T))])
        a = fo(isec, ibase); d[a:a + 4 * n3] = T[keep].astype('<i4').tobytes() + bytes(4 * 3 * int((~keep).sum()))
        struct.pack_into('<i', d, fo(*tt[1]) + lay['Indices'], 3 * int(keep.sum()))
        gcount, (gsec, goff) = top['Groups'][1], top['Groups'][2]; first = 0; groups = []
        for k in range(gcount):
            mi, tf, tc = struct.unpack_from('<3i', d, fo(gsec, goff) + 12 * k)
            kept = int(keep[tf:tf + tc].sum()); struct.pack_into('<3i', d, fo(gsec, goff) + 12 * k, mi, first, kept)
            groups.append((mi, tf, tc, first, kept)); first += kept
        assert first == int(keep.sum()), f'{name}: groups do not cover the triangles'
        report[name] = dict(tris_before=len(T), dropped=int((~keep).sum()), tris_after=int(keep.sum()), groups=groups)
    struct.pack_into('<I', d, 32 + 8, zlib.crc32(bytes(d[g.sec_table:])) & 0xffffffff)
    Path(out).write_bytes(d)
    return report


def changed_ranges(a, b):
    a, b = np.frombuffer(a, np.uint8), np.frombuffer(b, np.uint8); assert len(a) == len(b)
    idx = np.nonzero(a != b)[0]; out = []
    for i in idx:
        if out and i <= out[-1][1] + 16: out[-1][1] = int(i)
        else: out.append([int(i), int(i)])
    return out


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('src'); ap.add_argument('plan'); ap.add_argument('out'); ap.add_argument('--check', action='store_true')
    x = ap.parse_args()
    rep = drop(x.src, json.loads(Path(x.plan).read_text()), x.out)
    print('DROPTRIS', json.dumps(rep))
    if x.check:
        rng = changed_ranges(Path(x.src).read_bytes(), Path(x.out).read_bytes())
        print('CHANGED', len(rng), 'ranges', sum(e - s + 1 for s, e in rng), 'bytes', rng[:12])
