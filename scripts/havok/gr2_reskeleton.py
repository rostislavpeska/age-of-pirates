"""Give a skinned model another model's skeleton, keeping every mesh byte: the DONOR's bone array (names, parents,
rest transforms, inverse-world matrices, LOD errors) replaces the TARGET's, and the target's skeleton and model take
the donor's names. Meshes, vertex and index bytes, materials and BoneBindings of the target stay identical: vertex
BoneIndices index the mesh's BoneBindings, which Granny binds to the skeleton BY NAME.

Why: animations drive bones by name with keys LOCAL to the parent, and bind their track group by the model/root name
(the Treasure Ship root rename made one animation pair drive both stages). A model whose joints already sit where the
donor's do but whose hierarchy differs (an infantry Disciple vs a cavalry rider) rides with the donor's animations
only on the donor's skeleton. Measured 2026-10-09: Disciple and yabusame rider joints identical (0.0000 m, < 0.05 deg).

    python scripts/havok/gr2_reskeleton.py DONOR.gr2 TARGET.gr2 OUT.gr2 [--tol 0.005]

Refuses when a bone the target's meshes are bound to is missing from the donor, or when such a joint differs by
more than --tol engine units (or 1 degree). Writes the donor bones into the first empty section (the pattern of
gr2_addbones.py), re-points the skeleton Bones/Name and model Name pointers, then drops the old bone array's now
orphan fixups (gr2_fixups.scrub, INC-187). Verify the output with gr2_dump.py, gr2_fixups.py, a converter GXO dump
(native loader) and skinned-model-check before any game test.
"""
import argparse
import os
import struct
import sys
import tempfile
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gr2_fixups import orphan_fixups, scrub  # noqa: E402
from gr2_read import Gr2  # noqa: E402

BONE = 164                       # Name@0 ParentIndex@8 Transform@12 InverseWorld4x4@80 LODError@144 ExtendedData@148


def member_off(g, tref, name):
    return next(off for m, off in g.layout(*tref)[0] if m['name'] == name)


def skeleton(g):
    r = g.root()
    _, n, sp, st = r['Skeletons']
    assert n == 1, 'expects one skeleton, found %d' % n
    loc = g.deref(sp[0], sp[1])
    sk = g.read(*st, *loc)
    _, nb, bp, bt = sk['Bones']
    assert g.struct_size(*bt) == BONE, 'unexpected bone record size'
    return dict(loc=loc, tref=st, rec=sk, nb=nb, bp=bp, bones=g.array(sk['Bones']))


def model(g):
    r = g.root()
    _, n, p, tref = r['Models']
    assert n == 1, 'expects one model, found %d' % n
    loc = g.deref(p[0], p[1])
    return dict(loc=loc, tref=tref, rec=g.read(*tref, *loc))


def bound_bones(g):
    r = g.root()
    names = set()
    _, n, p, tref = r['Meshes']
    for i in range(n):
        m = g.read(*tref, *g.deref(p[0], p[1] + i * g.ptr))
        names |= {b['BoneName'] for b in g.array(m['BoneBindings'])}
    return names


def world(g, sk):
    """name -> 4x4 column-vector world matrix, from InverseWorld4x4 (stored as inverse(world).T)."""
    out = {}
    for i, b in enumerate(sk['bones']):
        inv = np.array(struct.unpack_from('<16f', g.payload[sk['bp'][0]], sk['bp'][1] + i * BONE + 80)).reshape(4, 4)
        out[b['Name']] = np.linalg.inv(inv.T)
    return out


def set_reloc(d, g, sec, src_off, new_target):
    s = g.sections[sec]
    for k in range(s['reloc_count']):
        o = s['reloc_off'] + 12 * k
        if struct.unpack_from('<I', d, o)[0] == src_off:
            struct.pack_into('<III', d, o, src_off, *new_target)
            return
    raise RuntimeError('no relocation at section %d offset %d' % (sec, src_off))


def build(donor, target, out, tol):
    gd, gt = Gr2(donor), Gr2(target)
    for g, p in ((gd, donor), (gt, target)):
        assert g.ptr == 8 and g.crc_check(), '%s: expects an uncompressed 64-bit gr2 with a valid CRC' % p
    skd, skt = skeleton(gd), skeleton(gt)
    md, mt = model(gd), model(gt)
    donor_names = [b['Name'] for b in skd['bones']]
    bound = bound_bones(gt)
    missing = sorted(bound - set(donor_names))
    if missing:
        raise SystemExit('REFUSED: bones bound by the target meshes are missing from the donor: %s' % missing)
    wd, wt = world(gd, skd), world(gt, skt)
    worst = []
    for n in sorted(bound):
        dp = float(np.linalg.norm(wd[n][:3, 3] - wt[n][:3, 3]))
        Rd = wd[n][:3, :3] / np.linalg.norm(wd[n][:3, :3], axis=0)
        Rt = wt[n][:3, :3] / np.linalg.norm(wt[n][:3, :3], axis=0)
        ang = float(np.degrees(np.arccos(np.clip((np.trace(Rd.T @ Rt) - 1) / 2, -1, 1))))
        worst.append((dp, ang, n))
    bad = [w for w in worst if w[0] > tol or w[1] > 1.0]
    print('joint check over %d bound bones: max position diff %.5f, max rotation diff %.3f deg' % (
        len(worst), max(w[0] for w in worst), max(w[1] for w in worst)))
    if bad:
        raise SystemExit('REFUSED: joints differ beyond tolerance: %s' % [(n, round(p, 4), round(a, 2)) for p, a, n in bad])

    # new section: donor bone records, then the name strings they and the renamed skeleton/model point at
    empty = next(i for i, s in enumerate(gt.sections) if s['data_size'] == 0)
    recs = bytearray(gd.payload[skd['bp'][0]][skd['bp'][1]:skd['bp'][1] + skd['nb'] * BONE])
    for i in range(skd['nb']):
        recs[i * BONE:i * BONE + 8] = bytes(8)                       # name pointer: set through the relocation
        recs[i * BONE + 148:i * BONE + BONE] = bytes(16)             # no ExtendedData (none on vanilla bones)
    sec = bytearray(recs)
    strings_start = len(sec)
    str_off = {}
    for name in donor_names + [skd['rec']['Name'], md['rec']['Name']]:
        if name not in str_off:
            str_off[name] = len(sec)
            sec.extend(name.encode() + b'\0')
    while len(sec) % 4:
        sec.append(0)
    relocs = [(i * BONE, empty, str_off[n]) for i, n in enumerate(donor_names)]

    d = bytearray(gt.data)
    sloc, mloc = skt['loc'], mt['loc']
    bones_off = member_off(gt, skt['tref'], 'Bones')
    struct.pack_into('<i', d, gt.sections[sloc[0]]['data_off'] + sloc[1] + bones_off, skd['nb'])
    set_reloc(d, gt, sloc[0], sloc[1] + bones_off + 4, (empty, 0))
    set_reloc(d, gt, sloc[0], sloc[1] + member_off(gt, skt['tref'], 'Name'), (empty, str_off[skd['rec']['Name']]))
    set_reloc(d, gt, mloc[0], mloc[1] + member_off(gt, mt['tref'], 'Name'), (empty, str_off[md['rec']['Name']]))
    data_off = len(d)
    d.extend(sec)
    while len(d) % 4:
        d.append(0)
    reloc_off = len(d)
    for so, ts, to in relocs:
        d.extend(struct.pack('<III', so, ts, to))
    struct.pack_into('<11I', d, gt.sec_table + 44 * empty, 0, data_off, len(sec), len(sec), 4,
                     strings_start, strings_start, reloc_off, len(relocs), 0, 0)
    struct.pack_into('<I', d, 32 + 4, len(d))
    struct.pack_into('<I', d, 32 + 8, zlib.crc32(bytes(d[gt.sec_table:])) & 0xffffffff)

    tmp = os.path.join(tempfile.mkdtemp(prefix='reskeleton_'), 'stage.gr2')
    open(tmp, 'wb').write(d)
    if os.path.exists(out):
        os.remove(out)
    res = scrub(tmp, out) if orphan_fixups(tmp)['orphans'] else None
    if res is None:
        open(out, 'wb').write(d)
    g2 = Gr2(out)
    sk2, m2 = skeleton(g2), model(g2)
    assert g2.crc_check() and not orphan_fixups(out)['orphans']
    assert [b['Name'] for b in sk2['bones']] == donor_names
    assert bound <= {b['Name'] for b in sk2['bones']}
    print('wrote %s: crc ok, skeleton %r %d bones (was %r %d), model %r, orphan fixups dropped %s' % (
        out, sk2['rec']['Name'], sk2['nb'], skt['rec']['Name'], skt['nb'], m2['rec']['Name'],
        res['dropped'] if res else 0))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('donor')
    ap.add_argument('target')
    ap.add_argument('out')
    ap.add_argument('--tol', type=float, default=0.005, help='max joint position difference, engine units')
    a = ap.parse_args()
    build(a.donor, a.target, a.out, a.tol)


if __name__ == '__main__':
    main()
