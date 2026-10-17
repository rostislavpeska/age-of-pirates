"""Extract everything the damaged-model rig needs from the vanilla damaged gr2 (read with gr2_read, no converter):
bones with world transforms, the four Combined meshes with per-vertex piece bone (BoneIndices), triangles, and a sail
label per vertex from the rig build's GXO (vanilla vertex coincides with a rig sail mesh vertex; engine = MIRROR . gxo).
One JSON feeds both the Blender verification scene (dmg_blender.py) and the Granny build.

    python dmg_extract.py damaged.gr2 rig.gxo out.json
"""
import sys, struct, json, itertools, collections
import numpy as np
from gr2_read import Gr2
from gr2_dump import refs
from gxo_sails import parse
from gr2_addbones import MAPS, quat_to_R


def main():
    src, rigp, outp = sys.argv[1:4]
    g = Gr2(src); r = g.root(); M = MAPS['mirror']
    _, _, rm = parse(rigp)
    grid = {}; rig_mb = {}
    for m in rm:
        if m['name'].startswith('sail_'):
            rig_mb[m['name']] = m['mb'][0]
            for p in m['v']: grid[tuple(np.round(np.array(p) / 0.01).astype(int))] = m['name']
    def look(p):
        k = tuple(np.round(p / 0.01).astype(int))
        if k in grid: return grid[k]
        for dd in itertools.product((-1, 0, 1), repeat=3):
            kk = (k[0] + dd[0], k[1] + dd[1], k[2] + dd[2])
            if kk in grid: return grid[kk]
        return None

    # --- bones: local transform -> world (engine frame), parent chain
    sk = refs(g, r['Skeletons'])[0][0]; bones = g.array(sk['Bones']); W = []; out_bones = []
    for b in bones:
        t = b['Transform']; L = np.eye(4); L[:3, :3] = quat_to_R(t[4:8]) @ np.array(t[8:17]).reshape(3, 3); L[:3, 3] = t[1:4]
        p = b['ParentIndex'][0]; Wb = (W[p] @ L) if p >= 0 else L; W.append(Wb)
        out_bones.append(dict(name=b['Name'], parent=p, world=Wb.tolist()))

    # --- meshes: positions, piece per vertex, triangles, sail label
    meshes = []; sail_mast = collections.defaultdict(collections.Counter)
    for m, _ in refs(g, r['Meshes']):
        vd = m['PrimaryVertexData']; vrec = g.read(*vd[2], *vd[1]); va = vrec['Vertices']
        lay, stride = g.layout(*va[1]); comps = {mm['name']: off for mm, off in lay}
        bb = [x['BoneName'] for x in g.array(m['BoneBindings'])]
        buf = g.payload[va[3][0]]; base = va[3][1]
        pos = np.array([struct.unpack_from('<3f', buf, base + i * stride + comps['Position']) for i in range(va[2])])
        piece = [bb[struct.unpack_from('<B', buf, base + i * stride + comps['BoneIndices'])[0]] for i in range(va[2])]
        top = g.read(*m['PrimaryTopology'][2], *m['PrimaryTopology'][1])
        if top['Indices'][1]:
            p = top['Indices'][2]; tri = np.frombuffer(bytes(g.payload[p[0]][p[1]:p[1] + 4 * top['Indices'][1]]), dtype='<i4').reshape(-1, 3)
        else:
            p = top['Indices16'][2]; tri = np.frombuffer(bytes(g.payload[p[0]][p[1]:p[1] + 2 * top['Indices16'][1]]), dtype='<u2').reshape(-1, 3)
        labels = [look(q) if not pc.startswith(('hull', 'bone_')) else None for q, pc in zip(pos @ M, piece)]
        for l, pc in zip(labels, piece):
            if l: sail_mast[l.split('_cloth')[0].split('_bar')[0]][pc] += 1
        meshes.append(dict(name=m['Name'], material=None, positions=pos.round(5).tolist(), piece=piece, tris=tri.tolist(), label=labels))
        print(f"mesh {m['Name']}: {len(pos)} verts, {len(tri)} tris, sail-labelled verts {sum(1 for l in labels if l)}")
    mast_of = {s: c.most_common(1)[0][0] for s, c in sail_mast.items()}
    print('SAIL -> mast piece:', mast_of)
    json.dump(dict(bones=out_bones, meshes=meshes, rig_mb=rig_mb, sail_mast=mast_of, map=M.tolist()), open(outp, 'w'))
    print('WROTE', outp, 'bones', len(out_bones))


if __name__ == '__main__':
    main()
