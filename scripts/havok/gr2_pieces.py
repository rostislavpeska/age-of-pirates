"""Per-piece geometry of a destruction model (meshes with BoneIndices): vertex count and bbox per bound bone,
and optionally a position match of selected pieces against the sail meshes of a converter GXO (rig build) to see
whether the damaged sails are the intact sails' geometry (frame = signed axis permutation x scale, measured).

    python gr2_pieces.py damaged.gr2 [name-substring] [rig.gxo]
"""
import sys, struct, itertools, collections
import numpy as np
from gr2_read import Gr2
from gr2_dump import refs


def pieces(g):
    """-> {bone name: array of positions}, plus the vertex layout per mesh"""
    r = g.root(); out = collections.defaultdict(list); layouts = []
    for m, _ in refs(g, r['Meshes']):
        vd = m['PrimaryVertexData']; vrec = g.read(*vd[2], *vd[1]); va = vrec['Vertices']
        lay, stride = g.layout(*va[1]); comps = {mm['name']: (mm, off) for mm, off in lay}
        layouts.append((m['Name'], [(mm['name'], mm['type'], mm['count']) for mm, off in lay], stride))
        bb = [b['BoneName'] for b in g.array(m['BoneBindings'])]
        buf = g.payload[va[3][0]]; base = va[3][1]
        pm, po = comps['Position']; bm, bo = comps['BoneIndices']
        bsize = {11: 'b', 12: 'B', 15: 'h', 16: 'H', 19: 'i', 20: 'I'}[bm['type']]
        for i in range(va[2]):
            o = base + i * stride
            p = struct.unpack_from('<3f', buf, o + po); bi = struct.unpack_from('<' + bsize, buf, o + bo)[0]
            out[bb[bi]].append(p)
    return {k: np.array(v) for k, v in out.items()}, layouts


def main():
    g = Gr2(sys.argv[1]); filt = sys.argv[2] if len(sys.argv) > 2 else ''; rig = sys.argv[3] if len(sys.argv) > 3 else None
    P, layouts = pieces(g)
    for name, lay, stride in layouts: print('MESH', name, 'stride', stride, lay)
    sel = {k: v for k, v in P.items() if filt in k}
    for k in sorted(sel): print(f'{k:36} nv={len(sel[k]):5d} bbox ' + ' '.join(f'{a:.2f}..{b:.2f}' for a, b in zip(sel[k].min(0), sel[k].max(0))))
    if not rig: return
    # rig GXO sail meshes -> grid; find the frame mapping gr2 -> rig that makes the selected pieces coincide
    from gxo_sails import parse
    _, _, rm = parse(rig)
    label = {}
    for m in rm:
        if m['name'].startswith('sail_'):
            for p in m['v']: label[tuple(np.round(np.array(p) / 0.01).astype(int))] = m['name']
    allp = np.concatenate(list(sel.values()))
    best = None
    for perm in itertools.permutations(range(3)):
        for signs in itertools.product((1, -1), repeat=3):
            for scale in (1.0, 2.54, 1 / 2.54):
                M = np.zeros((3, 3))
                for i in range(3): M[i, perm[i]] = signs[i] * scale
                q = allp @ M.T
                hit = sum(tuple(np.round(p / 0.01).astype(int)) in label for p in q) / len(q)
                if best is None or hit > best[0]: best = (hit, perm, signs, scale, M)
    hit, perm, signs, scale, M = best
    print(f'FRAME gr2->rig: perm {perm} signs {signs} scale {scale}: {hit*100:.1f}% of the selected vertices coincide with rig sail vertices')
    for k in sorted(sel):
        q = sel[k] @ M.T; labs = collections.Counter(label.get(tuple(np.round(p / 0.01).astype(int)), '-') for p in q)
        print(f'  {k:36} -> {dict(labs.most_common(4))}')


if __name__ == '__main__':
    main()
