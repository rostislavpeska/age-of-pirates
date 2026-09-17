"""Rename a material / mesh / bone string inside a .gr2 IN PLACE (same length or shorter; section-0 string, CRC
recomputed, nothing else moves). Usage: python gr2_rename.py IN.gr2 OUT.gr2 material OLD NEW [material OLD NEW ...]
kinds: material | mesh | bone"""
import sys
from gr2_read import Gr2
from gr2_dump import refs
from gr2_splitmesh import Builder


def main():
    src, outp = sys.argv[1:3]; ops = sys.argv[3:]; assert len(ops) % 3 == 0 and ops
    g = Gr2(src); assert g.crc_check(); r = g.root(); B = Builder(g); done = []
    for kind, old, new in zip(ops[::3], ops[1::3], ops[2::3]):
        assert len(new.encode()) <= len(old.encode()), 'in-place rename cannot grow'
        if kind == 'material': recs = refs(g, r['Materials'])
        elif kind == 'mesh': recs = refs(g, r['Meshes'])
        elif kind == 'bone':
            recs = []
            for sk, sl in refs(g, r['Skeletons']):
                arr = sk['Bones']; bs = g.struct_size(*arr[3])
                recs += [(g.read(*arr[3], arr[2][0], arr[2][1] + i * bs), (arr[2][0], arr[2][1] + i * bs)) for i in range(arr[1])]
        else: raise SystemExit('kind must be material|mesh|bone')
        hits = [loc for rec, loc in recs if rec['Name'] == old]
        assert hits, f'{kind} {old!r} not found'
        for loc in hits:
            ssec, soff = g.deref(loc[0], loc[1])                      # Name pointer -> string
            assert ssec == 0
            B.sec[0][soff:soff + len(old.encode()) + 1] = new.encode() + b'\0' * (len(old.encode()) - len(new.encode()) + 1)
            done.append((kind, old, new, loc))
    B.write(outp)
    g2 = Gr2(outp); assert g2.crc_check()
    print('wrote', outp, '| crc ok |', done)


if __name__ == '__main__':
    main()
