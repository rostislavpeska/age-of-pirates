"""Rotate listed vertices of meshes in an uncompressed .gr2 IN PLACE (position, int8 normal and tangent), every other byte
identical, CRC recomputed. For a hinged part that must swing (Korean Barracks gate leaf, owner 2026-10-11: "Barracks gate
wings - both iopen outside same direction").

    python gr2_rotate_verts.py in.gr2 plan.json out.gr2
    plan.json: {"pivot": [x, y, z], "axis": [0, 1, 0], "degrees": -82.0, "meshes": {"<mesh name>": [vertex, ...]}}

Layout required (the vanilla 24-byte rigid/skinned vertex): Position real32x3 @0, Normal int8x3 @12, Tangent int8x3 @16
(the bytes at 15 and 19 - packed data / sign / bone index - are kept). Rotation keeps handedness, so the tangent sign stays.
"""
import json, struct, sys, zlib
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gr2_read import Gr2   # noqa: E402
from gr2_dump import refs  # noqa: E402


def rot(axis, deg):
    a = np.asarray(axis, float); a /= np.linalg.norm(a); t = np.radians(deg); K = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
    return np.eye(3) + np.sin(t) * K + (1 - np.cos(t)) * K @ K


def rotate(src, plan, out):
    g = Gr2(str(src)); assert g.crc_check(); assert all(s['compression'] == 0 for s in g.sections)
    d = bytearray(g.data); R = rot(plan['axis'], plan['degrees']); piv = np.asarray(plan['pivot'], float)
    fo = lambda sec, off: g.sections[sec]['data_off'] + off; meshes = {m['Name']: m for m, _ in refs(g, g.root()['Meshes'])}; rep = {}
    for name, verts in plan['meshes'].items():
        m = meshes[name]; vd = m['PrimaryVertexData']; va = g.read(*vd[2], *vd[1])['Vertices']
        stride = g.struct_size(*va[1]); lay = [(mm['name'], off) for mm, off in g.layout(*va[1])[0]]
        assert stride == 24 and [o for _, o in lay] == [0, 12, 15, 16, 19, 20], (name, lay)
        base = fo(*va[3])
        for v in verts:
            assert 0 <= v < va[2], (name, v)
            o = base + 24 * v
            p = np.array(struct.unpack_from('<3f', d, o)); struct.pack_into('<3f', d, o, *(R @ (p - piv) + piv))
            for off in (12, 16):
                n = np.array(struct.unpack_from('<3b', d, o + off), float)
                struct.pack_into('<3b', d, o + off, *np.clip(np.rint(R @ n), -127, 127).astype(int))
        rep[name] = len(verts)
    struct.pack_into('<I', d, 32 + 8, zlib.crc32(bytes(d[g.sec_table:])) & 0xffffffff)
    Path(out).write_bytes(d); return rep


if __name__ == '__main__':
    src, planp, out = sys.argv[1:4]
    print('ROTATED', json.dumps(rotate(src, json.loads(Path(planp).read_text()), out)))
