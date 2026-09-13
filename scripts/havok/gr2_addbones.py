"""Append bones to a vanilla (uncompressed, 64-bit) .gr2 skeleton without touching meshes or skinning.

    python gr2_addbones.py DMG.gr2 BASE.gxo OUT.gr2 [--map mirror|rot] [--scale 1.0] [--lod 1304.65]

Bones = every bone of BASE.gxo that DMG.gr2 lacks (minus Blender '_end' leaves and the GXO root),
placed at their world transform mapped from the converter's frame into the engine frame, parented
to the damaged model's root bone. Layout facts used here were measured on vanilla files:
  - pointers are 8 bytes at 4-byte alignment; bone record = 164 bytes (Name@0, ParentIndex@8,
    Transform@12 = flags,pos[3],quat[4],scaleshear[9], InverseWorld4x4@80, LODError@144, ExtendedData@148)
  - InverseWorld4x4 = inverse(column-vector world matrix).T   (verified on all 151 bones)
  - CRC32 covers the file from the section table to the end
Validation: re-read with gr2_read.py (CRC, bone list); the GXO converter must list the new bones.
"""
import argparse, os, struct, sys, zlib
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gr2_read import Gr2

MAPS = {'mirror': np.array([[-1, 0, 0], [0, 0, 1], [0, -1, 0]], float),   # base GXO -> engine, measured on the treasure ship
        'rot':    np.array([[1, 0, 0], [0, 0, 1], [0, -1, 0]], float)}


def quat_to_R(q):
    x, y, z, w = q
    return np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)], [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)], [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])


def R_to_quat(R):
    m = R; t = np.trace(m)
    if t > 0:
        s = np.sqrt(t + 1) * 2; w = 0.25 * s; x = (m[2, 1] - m[1, 2]) / s; y = (m[0, 2] - m[2, 0]) / s; z = (m[1, 0] - m[0, 1]) / s
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = np.sqrt(1 + m[0, 0] - m[1, 1] - m[2, 2]) * 2; w = (m[2, 1] - m[1, 2]) / s; x = 0.25 * s; y = (m[0, 1] + m[1, 0]) / s; z = (m[0, 2] + m[2, 0]) / s
    elif m[1, 1] > m[2, 2]:
        s = np.sqrt(1 + m[1, 1] - m[0, 0] - m[2, 2]) * 2; w = (m[0, 2] - m[2, 0]) / s; x = (m[0, 1] + m[1, 0]) / s; y = 0.25 * s; z = (m[1, 2] + m[2, 1]) / s
    else:
        s = np.sqrt(1 + m[2, 2] - m[0, 0] - m[1, 1]) * 2; w = (m[1, 0] - m[0, 1]) / s; x = (m[0, 2] + m[2, 0]) / s; y = (m[1, 2] + m[2, 1]) / s; z = 0.25 * s
    q = np.array([x, y, z, w]); return q / np.linalg.norm(q)


def gxo_world(path):
    """name -> (R 3x3, t) world transforms in the converter frame, walking the GXO parent chain"""
    order, raw = [], {}
    for l in open(path, encoding='utf-8', errors='replace'):
        t = l.split()
        if t and t[0] == 'b':
            name = t[1].strip('"'); par = int(t[2]); f = [float(x) for x in t[3:15]]
            order.append(name); raw[name] = (par, np.array(f[0:9]).reshape(3, 3), np.array(f[9:12]))
    world = {}
    for name in order:
        par, R, t = raw[name]
        if par == 0: world[name] = (np.eye(3), np.zeros(3))     # the GXO root carries the converter's axis conversion;
        else:                                                  # mesh vertices (our calibration) do not, so treat it as identity
            PR, pt = world[order[par - 1]]; world[name] = (PR @ R, pt + PR @ t)
    return order, world


def build_inplace(g, a, bp, nb, bsize, count_field, new_recs, new_names):
    """Grow section 0 instead of moving the array: insert the new records right after the existing
    bones, append their name strings at the end of the section, shift every offset that follows
    (relocation sources and targets in every section, the 16/8-bit markers, all later file offsets)."""
    assert bp[0] == 0 and count_field[0] == 0
    X = bp[1] + nb * bsize; ins = b''.join(new_recs); delta = len(ins)
    old = bytes(g.payload[0]); d = g.data
    strings = b''; name_off = []
    for n in new_names:
        name_off.append(len(old) + delta + len(strings)); strings += n.encode() + b'\0'
    while len(strings) % 4: strings += b'\0'
    sec0 = bytearray(old[:X] + ins + old[X:] + strings)
    struct.pack_into('<i', sec0, count_field[1], nb + len(new_recs))
    relocs = {i: [] for i in range(g.sec_count)}
    for i, s in enumerate(g.sections):
        for k in range(s['reloc_count']):
            so, ts, to = struct.unpack_from('<III', d, s['reloc_off'] + 12 * k)
            if i == 0 and so >= X: so += delta
            if ts == 0 and to >= X: to += delta
            relocs[i].append((so, ts, to))
    for i in range(len(new_names)): relocs[0].append((X + i * bsize, 0, name_off[i]))
    relocs[0].sort()
    payloads = [bytes(sec0)] + [bytes(g.payload[i]) for i in range(1, g.sec_count)]
    marsh = [bytes(d[s['marsh_off']:s['marsh_off'] + 16 * s['marsh_count']]) if s['marsh_count'] else b'' for s in g.sections]
    out = bytearray(d[:g.sec_table + 44 * g.sec_count])
    hdr = []
    for i, s in enumerate(g.sections):
        while len(out) % 4: out.append(0)
        data_off = len(out); out.extend(payloads[i])
        hdr.append([0, data_off, len(payloads[i]), len(payloads[i]), s['align'], s['first16'], s['first8'], 0, len(relocs[i]), 0, s['marsh_count']])
    hdr[0][5] = s0 = g.sections[0]['first16'] + (delta if g.sections[0]['first16'] >= X else 0)
    hdr[0][6] = g.sections[0]['first8'] + (delta if g.sections[0]['first8'] >= X else 0)
    for i in range(g.sec_count):
        while len(out) % 4: out.append(0)
        hdr[i][7] = len(out)
        for so, ts, to in relocs[i]: out.extend(struct.pack('<III', so, ts, to))
        while len(out) % 4: out.append(0)
        hdr[i][9] = len(out); out.extend(marsh[i])
    for i, h in enumerate(hdr): struct.pack_into('<11I', out, g.sec_table + 44 * i, *h)
    struct.pack_into('<I', out, 32 + 4, len(out))
    struct.pack_into('<I', out, 32 + 8, zlib.crc32(bytes(out[g.sec_table:])) & 0xffffffff)
    open(a.out, 'wb').write(out)
    g2 = Gr2(a.out); r2 = g2.root(); _, _, sp2, st2 = r2['Skeletons']; sk2 = g2.read(*st2, *g2.deref(sp2[0], sp2[1])); b2 = g2.array(sk2['Bones'])
    meshes = [g2.read(*r2['Meshes'][3], *g2.deref(r2['Meshes'][2][0], r2['Meshes'][2][1] + i * g2.ptr))['Name'] for i in range(r2['Meshes'][1])]
    print(f'wrote {a.out} (in place): crc ok {g2.crc_check()}, bones {len(b2)} (was {nb}), last: {[b["Name"] for b in b2[-2:]]}, meshes {meshes}')


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('dmg'); ap.add_argument('gxo'); ap.add_argument('out')
    ap.add_argument('--inplace', action='store_true', help='grow section 0 instead of moving the bone array to an empty section')
    ap.add_argument('--map', default='mirror', choices=MAPS); ap.add_argument('--scale', type=float, default=1.0)
    ap.add_argument('--lod', type=float, default=1304.65); ap.add_argument('--only', nargs='*', help='bone names to add (default: all missing)')
    a = ap.parse_args()
    g = Gr2(a.dmg); assert g.ptr == 8 and g.crc_check(), 'expects an uncompressed 64-bit gr2 with a valid CRC'
    r = g.root(); _, nsk, sp, stref = r['Skeletons']; sk_loc = g.deref(sp[0], sp[1]); sk = g.read(*stref, *sk_loc)
    _, nb, bp, btref = sk['Bones']; bsize = g.struct_size(*btref); assert bsize == 164
    bones = g.array(sk['Bones']); names = [b['Name'] for b in bones]
    bones_member_off = next(off for m, off in g.layout(*stref)[0] if m['name'] == 'Bones')
    count_field = (sk_loc[0], sk_loc[1] + bones_member_off); ptr_field = (sk_loc[0], sk_loc[1] + bones_member_off + 4)
    assert g.deref(*ptr_field) == bp, 'Bones pointer relocation not where expected'
    # engine-frame world transform of the root bone (parent of the new bones)
    root = bones[0]; assert root['ParentIndex'][0] == -1
    R_root = quat_to_R(root['Transform'][4:8]); t_root = np.array(root['Transform'][1:4])
    order, gw = gxo_world(a.gxo)
    todo = [n for n in order if n not in names and not n.endswith('_end') and gw[n] is not None]
    todo = [n for n in todo if order.index(n) != 0]                      # drop the GXO root
    if a.only: todo = [n for n in todo if n in a.only]
    M = MAPS[a.map]
    print(f'{len(names)} bones in {os.path.basename(a.dmg)}; adding {len(todo)}: {todo}')
    # ---- build the new bone records
    new_recs, new_names = [], []
    for n in todo:
        Rg, tg = gw[n]
        Rw = M @ Rg @ M.T; tw = a.scale * (M @ tg)                       # world in the engine frame
        Rl = R_root.T @ Rw; tl = R_root.T @ (tw - t_root)                  # local to the root bone
        q = R_to_quat(Rl)
        Mc = np.eye(4); Mc[:3, :3] = Rw; Mc[:3, 3] = tw; inv = np.linalg.inv(Mc).T
        rec = bytearray(164)
        struct.pack_into('<i', rec, 8, 0)                                  # parent = root
        struct.pack_into('<I3f4f9f', rec, 12, 3, *tl, *q, 1, 0, 0, 0, 1, 0, 0, 0, 1)
        struct.pack_into('<16f', rec, 80, *inv.flatten())
        struct.pack_into('<f', rec, 144, a.lod)
        new_recs.append(rec); new_names.append(n)
        print(f'   + {n:26} world pos {np.round(tw, 3)}  local pos {np.round(tl, 3)} quat {np.round(q, 3)}')
    if a.inplace:
        return build_inplace(g, a, bp, nb, bsize, count_field, new_recs, new_names)
    # ---- new section (reuse the first empty one): [old bone bytes][new bones][name strings]
    empty = next(i for i, s in enumerate(g.sections) if s['data_size'] == 0)
    old_bytes = bytes(g.payload[bp[0]][bp[1]:bp[1] + nb * bsize])
    sec = bytearray(old_bytes); relocs = []
    for i in range(nb):                                                    # carry each old bone's pointer relocations
        for field in (0, 148, 156):
            tgt = g.deref(bp[0], bp[1] + i * bsize + field)
            if tgt: relocs.append((i * bsize + field, tgt[0], tgt[1]))
    for rec in new_recs: sec.extend(rec)
    strings_start = len(sec)
    for i, n in enumerate(new_names):
        relocs.append(((nb + i) * bsize, empty, len(sec))); sec.extend(n.encode() + b'\0')
    while len(sec) % 4: sec.append(0)
    # ---- assemble the file
    d = bytearray(g.data)
    struct.pack_into('<i', d, g.sections[count_field[0]]['data_off'] + count_field[1], nb + len(new_recs))
    s0 = g.sections[ptr_field[0]]; fixed = False
    for k in range(s0['reloc_count']):                                     # redirect the Bones pointer relocation
        o = s0['reloc_off'] + 12 * k
        if struct.unpack_from('<I', d, o)[0] == ptr_field[1]:
            struct.pack_into('<III', d, o, ptr_field[1], empty, 0); fixed = True
    assert fixed
    data_off = len(d); d.extend(sec)
    reloc_off = len(d)
    for so, ts, to in relocs: d.extend(struct.pack('<III', so, ts, to))
    struct.pack_into('<11I', d, g.sec_table + 44 * empty, 0, data_off, len(sec), len(sec), 4, strings_start, strings_start, reloc_off, len(relocs), 0, 0)
    struct.pack_into('<I', d, 32 + 4, len(d))                              # TotalSize
    struct.pack_into('<I', d, 32 + 8, zlib.crc32(bytes(d[g.sec_table:])) & 0xffffffff)
    open(a.out, 'wb').write(d)
    # ---- validate by re-reading
    g2 = Gr2(a.out); r2 = g2.root(); _, _, sp2, st2 = r2['Skeletons']; sk2 = g2.read(*st2, *g2.deref(sp2[0], sp2[1])); b2 = g2.array(sk2['Bones'])
    print(f'wrote {a.out}: crc ok {g2.crc_check()}, bones {len(b2)} (was {nb}), last: {[b["Name"] for b in b2[-3:]]}, meshes {r2["Meshes"][1]}')


if __name__ == '__main__':
    main()
