"""Drop listed triangles from meshes of an uncompressed .gr2 IN PLACE: the kept triangles are compacted inside the
existing index buffer (order kept), the buffer tail is zeroed, the topology's index count and every material group's
TriFirst/TriCount are rewritten, and the header CRC is recomputed. Nothing else changes: vertices, materials, skeleton,
relocations and the file size stay byte-identical, so the patch is provably minimal (--check prints the changed ranges).

Optional "dup": translated COPIES of existing triangles (a duplicated post, a repeated plank), written into the SAME
buffers - every copied vertex is the source vertex's bytes (normal, tangent, UV, packed bytes) with only its Position
moved, placed in a vertex slot no kept triangle references (freed by the drop); the copies follow the kept triangles
of their source's material group. The file size still never changes: the edit is refused when the freed slots or
the index buffer cannot hold it. First use: the Korean HC pier, where the owner duplicated a vanilla post in Blender
(53 vertices / 76 triangles, translation exact to 5e-6) while shortening the pier (2026-10-17).

The bone-binding boxes of every edited mesh are recomputed from its referenced vertices (gr2_bounds.py): a box left
at the old geometry is what gr2_lint check `bounds` fails (Korean HC docks01, 2026-10-17).

    python gr2_droptris.py in.gr2 drop.json out.gr2 [--check]
    drop.json: {"meshes": {"<mesh name>": [tri, ...], ...},                (triangle indices as gr2_lint.read_raw numbers them)
                "dup": {"<mesh name>": [{"tris": [tri, ...], "translate": [x, y, z]}, ...]}}   (optional; SOURCE numbering)
"""
import argparse, json, struct, sys, zlib
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gr2_read import Gr2          # noqa: E402
from gr2_dump import refs         # noqa: E402
import gr2_bounds                 # noqa: E402


def drop(src, plan, out):
    g = Gr2(str(src)); assert g.crc_check(), 'source CRC'
    assert all(s['compression'] == 0 for s in g.sections), 'compressed sections are not supported'
    d = bytearray(g.data); r = g.root(); report = {}
    fo = lambda sec, off: g.sections[sec]['data_off'] + off                       # payload (sec, off) -> file offset
    meshes = {m['Name']: m for m, _ in refs(g, r['Meshes'])}
    dups = plan.get('dup', {}); edited = []
    for name in list(plan.get('meshes', {})) + [n for n in dups if n not in plan.get('meshes', {})]:
        tris = plan.get('meshes', {}).get(name, [])
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
        gcount, (gsec, goff) = top['Groups'][1], top['Groups'][2]
        groups = [struct.unpack_from('<3i', d, fo(gsec, goff) + 12 * k) for k in range(gcount)]
        added = [[] for _ in groups]; slots_used = 0
        if dups.get(name):
            va = g.read(*m['PrimaryVertexData'][2], *m['PrimaryVertexData'][1])['Vertices']
            vlay, stride = g.layout(*va[1]); nv = va[2]; vbase = fo(*va[3])
            ppos = next((off for mm, off in vlay if mm['name'] == 'Position' and mm['type'] == 10 and mm['count'] == 3), None)
            assert ppos is not None, f'{name}: no real32x3 Position to translate'
            snap = bytes(d[vbase:vbase + nv * stride])                            # source vertex bytes before any copy
            free = sorted(set(range(nv)) - set(T[keep].ravel().tolist()))
            group_of = np.zeros(len(T), int)
            for gi, (_, tf, tc) in enumerate(groups):
                group_of[tf:tf + tc] = gi
            for op in dups[name]:
                st = [int(t) for t in op['tris']]; assert all(0 <= t < len(T) for t in st), f'{name}: dup triangle out of range'
                move = np.asarray(op.get('translate', [0, 0, 0]), float); remap = {}
                for t in st:
                    for v in T[t]:
                        if int(v) in remap:
                            continue
                        assert free, f'{name}: no free vertex slot left for the copies (in place only)'
                        s = free.pop(0); remap[int(v)] = s; slots_used += 1
                        rec = bytearray(snap[int(v) * stride:(int(v) + 1) * stride])
                        p = np.array(struct.unpack_from('<3f', rec, ppos)) + move
                        struct.pack_into('<3f', rec, ppos, *p); d[vbase + s * stride:vbase + (s + 1) * stride] = rec
                    added[group_of[t]].append([remap[int(v)] for v in T[t]])
        # kept triangles of each group, then that group's copies; groups stay contiguous and in order
        out_tris, first, new_groups = [], 0, []
        for gi, (mi, tf, tc) in enumerate(groups):
            part = [T[i] for i in range(tf, tf + tc) if keep[i]] + [np.array(x, '<i4') for x in added[gi]]
            out_tris += part; new_groups.append((mi, tf, tc, first, len(part)))
            struct.pack_into('<3i', d, fo(gsec, goff) + 12 * gi, mi, first, len(part)); first += len(part)
        n_dup = sum(len(a) for a in added)
        assert first == int(keep.sum()) + n_dup, f'{name}: groups do not cover the triangles'
        assert first <= len(T), f'{name}: {first} triangles do not fit the {len(T)}-triangle index buffer (in place only)'
        body = np.array(out_tris, '<i4').reshape(-1, 3).tobytes() if out_tris else b''
        a = fo(isec, ibase); d[a:a + 4 * n3] = body + bytes(4 * n3 - len(body))
        struct.pack_into('<i', d, fo(*tt[1]) + lay['Indices'], 3 * first)
        report[name] = dict(tris_before=len(T), dropped=int((~keep).sum()), duplicated=n_dup, copied_vertices=slots_used,
                            tris_after=first, groups=new_groups)
        if dropset or n_dup:
            edited.append(name)
    struct.pack_into('<I', d, 32 + 8, zlib.crc32(bytes(d[g.sec_table:])) & 0xffffffff)
    Path(out).write_bytes(d)
    if edited:
        gr2_bounds.refresh(out, out, meshes=set(edited))
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
