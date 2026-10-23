"""Append attachment bones with explicit transforms (position, rotation AND scale) to an uncompressed 64-bit GR2.

    python add_bones.py IN.gr2 TABLE.json OUT.gr2 [--from-blender]

TABLE.json: [{"name": "bone_horse1", "parent": null, "pos": [x, y, z], "quat": [x, y, z, w], "scale": 0.8}, ...]
  parent  null = the model's root bone, or the name of an existing bone
  pos     engine frame by default; with --from-blender, Blender world (x right, y forward, z up) converted with
          engine = (-x, z, -y), and "rot_blender" (3x3 row-major, Blender world) may replace "quat"
  scale   uniform; written into the bone's scale-shear (vanilla stable horse bones carry 0.8)
Records: flags 7 (position | orientation | scale-shear), LODError 1304.65, InverseWorld = inverse(world incl. scale).T,
inserted in place by scripts/havok/gr2_addbones.build_inplace (meshes, skinning and existing bone order untouched).
Add the same bones to EVERY model the attaching component can show and to its simskeleton model (normally the
intact and the damaged GR2) - see ../SKILL.md. gr2_addbones.py itself (GXO tables) writes identity scale only.
"""
import argparse, json, struct, sys, types
from pathlib import Path
import numpy as np

REPO = Path(__file__).resolve().parents[4]   # .claude/skills/<skill>/scripts/<this>
sys.path.insert(0, str(REPO / 'scripts' / 'havok'))
from gr2_read import Gr2  # noqa: E402
from gr2_addbones import build_inplace, quat_to_R, R_to_quat  # noqa: E402

C = np.array([[-1, 0, 0], [0, 0, 1], [0, -1, 0]], float)      # Blender world -> engine raw (-X, Z, -Y)


def records(g, table, from_blender=False):
    r = g.root(); _, _, sp, stref = r['Skeletons']; sk_loc = g.deref(sp[0], sp[1]); sk = g.read(*stref, *sk_loc)
    _, nb, bp, btref = sk['Bones']; bsize = g.struct_size(*btref); assert bsize == 164, bsize
    bones = g.array(sk['Bones']); names = [b['Name'] for b in bones]
    off = next(o for m, o in g.layout(*stref)[0] if m['name'] == 'Bones'); count_field = (sk_loc[0], sk_loc[1] + off)
    world = {}
    for b in bones:                                               # existing world transforms (rotation part only)
        t = b['Transform']; R = quat_to_R(t[4:8]); p = np.array(t[1:4]); pi = b['ParentIndex'][0]
        world[b['Name']] = (world[names[pi]][0] @ R, world[names[pi]][1] + world[names[pi]][0] @ p) if pi >= 0 else (R, p)
    recs, new = [], []
    for row in table:
        assert row['name'] not in names and row['name'] not in new, f"bone {row['name']} already exists"
        parent = row.get('parent') or names[0]; pidx = names.index(parent)
        pos = np.array(row['pos'], float)
        if 'quat' in row:
            Rw = quat_to_R(row['quat'])
        else:
            Rw = np.array(row['rot_blender'], float).reshape(3, 3)
        if from_blender:
            pos = C @ pos
            if 'quat' not in row:
                Rw = C @ Rw @ C.T
        s = float(row.get('scale', 1.0))
        PR, pt = world[parent]
        Rl = PR.T @ Rw; tl = PR.T @ (pos - pt); q = R_to_quat(Rl)
        Mw = np.eye(4); Mw[:3, :3] = Rw * s; Mw[:3, 3] = pos
        rec = bytearray(164)
        struct.pack_into('<i', rec, 8, pidx)
        struct.pack_into('<I3f4f9f', rec, 12, 7, *tl, *q, s, 0, 0, 0, s, 0, 0, 0, s)
        struct.pack_into('<16f', rec, 80, *np.linalg.inv(Mw).T.flatten())
        struct.pack_into('<f', rec, 144, 1304.65)
        recs.append(rec); new.append(row['name'])
    return bp, nb, bsize, count_field, recs, new


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('gr2'); ap.add_argument('table'); ap.add_argument('out')
    ap.add_argument('--from-blender', action='store_true', help='pos / rot_blender are Blender world coordinates')
    a = ap.parse_args()
    assert not Path(a.out).exists(), 'refusing to overwrite an existing output'
    g = Gr2(a.gr2); assert g.ptr == 8 and g.crc_check(), 'expects an uncompressed 64-bit gr2 with a valid CRC'
    bp, nb, bsize, count_field, recs, new = records(g, json.loads(Path(a.table).read_text()), a.from_blender)
    build_inplace(g, types.SimpleNamespace(out=a.out), bp, nb, bsize, count_field, recs, new)
    assert Gr2(a.out).crc_check()


if __name__ == '__main__':
    main()
