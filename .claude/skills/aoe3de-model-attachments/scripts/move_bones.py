"""Move EXISTING attachment bones of an uncompressed 64-bit GR2 to explicit transforms (position, rotation AND scale).

    python move_bones.py IN.gr2 TABLE.json OUT.gr2 [--from-blender]

The companion of add_bones.py (same TABLE format and frames, without "parent"): a donor model's own flag or garrison bone
sits where the DONOR had its flag (Korean castle 2026-10-09: the Japanese castle's bone_garrisonflag on the donor's
front, our pole on the ridge). Adding a second bone of the same name in another case would make the engine's
case-insensitive lookup ambiguous, so the donor's bone is moved instead.
Rewrites, in place, only the bone record's local Transform (flags 7, position, orientation, scale-shear) and its
InverseWorld4x4; the file layout, the parent index, the LODError and every other byte stay; the CRC is recomputed.
A bone with children is refused (their world transforms would move with it). Names match case-insensitively; a missing
name is an error.
"""
import argparse, json, struct, sys, zlib
from pathlib import Path
import numpy as np

REPO = Path(__file__).resolve().parents[4]   # .claude/skills/<skill>/scripts/<this>
sys.path.insert(0, str(REPO / 'scripts' / 'havok'))
from gr2_read import Gr2  # noqa: E402
from gr2_addbones import quat_to_R, R_to_quat  # noqa: E402

C = np.array([[-1, 0, 0], [0, 0, 1], [0, -1, 0]], float)      # Blender world -> engine raw (-X, Z, -Y)
BSIZE = 164


def move(g, table, from_blender=False):
    r = g.root(); _, _, sp, stref = r['Skeletons']; sk_loc = g.deref(sp[0], sp[1]); sk = g.read(*stref, *sk_loc)
    _, nb, bp, btref = sk['Bones']; assert g.struct_size(*btref) == BSIZE
    bones = g.array(sk['Bones']); names = [b['Name'] for b in bones]; low = [n.lower() for n in names]
    world = {}
    for b in bones:
        t = b['Transform']; R = quat_to_R(t[4:8]); p = np.array(t[1:4]); pi = b['ParentIndex'][0]
        world[b['Name']] = (world[names[pi]][0] @ R, world[names[pi]][1] + world[names[pi]][0] @ p) if pi >= 0 else (R, p)
    data = bytearray(g.data); sec = bp[0]; base = g.sections[sec]['data_off'] + bp[1]; done = []
    for row in table:
        assert row['name'].lower() in low, f"no bone {row['name']} in the model"
        i = low.index(row['name'].lower())
        assert not any(b['ParentIndex'][0] == i for b in bones), f'{names[i]} has children'
        pos = np.array(row['pos'], float)
        Rw = quat_to_R(row['quat']) if 'quat' in row else np.array(row.get('rot_blender', np.eye(3)), float).reshape(3, 3)
        if from_blender:
            pos = C @ pos
            if 'quat' not in row:
                Rw = C @ Rw @ C.T
        s = float(row.get('scale', 1.0)); pi = bones[i]['ParentIndex'][0]
        PR, pt = world[names[pi]] if pi >= 0 else (np.eye(3), np.zeros(3))
        Rl = PR.T @ Rw; tl = PR.T @ (pos - pt); q = R_to_quat(Rl)
        Mw = np.eye(4); Mw[:3, :3] = Rw * s; Mw[:3, 3] = pos
        o = base + i * BSIZE
        struct.pack_into('<I3f4f9f', data, o + 12, 7, *tl, *q, s, 0, 0, 0, s, 0, 0, 0, s)
        struct.pack_into('<16f', data, o + 80, *np.linalg.inv(Mw).T.flatten())
        done.append(dict(name=names[i], old=world[names[i]][1].round(4).tolist(), new=pos.round(4).tolist(), scale=s))
    struct.pack_into('<I', data, 32 + 8, zlib.crc32(bytes(data[g.sec_table:])) & 0xffffffff)
    return bytes(data), done


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('gr2'); ap.add_argument('table'); ap.add_argument('out')
    ap.add_argument('--from-blender', action='store_true', help='pos / rot_blender are Blender world coordinates')
    a = ap.parse_args()
    assert not Path(a.out).exists(), 'refusing to overwrite an existing output'
    g = Gr2(a.gr2); assert g.ptr == 8 and g.crc_check(), 'expects an uncompressed 64-bit gr2 with a valid CRC'
    assert all(s['compression'] == 0 for s in g.sections), 'expects uncompressed sections'
    data, done = move(g, json.loads(Path(a.table).read_text()), a.from_blender)
    Path(a.out).write_bytes(data); assert Gr2(a.out).crc_check()
    print('MOVED', json.dumps(done))


if __name__ == '__main__':
    main()
