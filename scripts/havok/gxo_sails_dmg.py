"""Furling sails for the DAMAGED Treasure Ship, built from its own GXO (vanilla battleship pattern).
In the damaged model every mast piece (mast_wood_solid_N) is mast + sail cloth + bars welded together. This script
- takes the converter's GXO of the damaged gr2 (vertex data verbatim; the converter keeps the per-mesh bone lists
  but drops the per-vertex binding, which is restored from the gr2 with gr2_read),
- moves the cloth/bar vertices of each mast piece into their own rigid meshes bound to the rig's sail bones
  (labels by position against the rig build's sail meshes),
- adds, per sail, an `animtrans_sailX` bone under the sail's mast piece whose rest transform cancels the piece's
  world transform, and hangs the rig's sail chain and bar bones under it with their intact-model local transforms
  (= the animtransNN trick of battleship_damaged.gr2: one anim file serves both models; simskeleton = this model),
- rebinds banner/flag bones under the nearest mast's animtrans, keeps all other bones and the hull pieces as they are.
Output frame = the rig GXO frame (engine units), so the sail bones' numbers are copied verbatim.

usage: python gxo_sails_dmg.py damaged.gr2 damaged.gxo rig.gxo out.gxo
"""
import sys, struct, itertools, collections
import numpy as np
from gr2_read import Gr2
from gr2_dump import refs
from gxo_sails import parse, fmt

TEX_OF = {'matc': 'hulldragon', 'mata': 'stage_final_matA', 'matb': 'stage_final_matB', 'matz': 'destructionsheet'}


def gr2_vertices(g):
    """per mesh: (positions array, bone name per vertex) in file order"""
    out = []
    for m, _ in refs(g, g.root()['Meshes']):
        vd = m['PrimaryVertexData']; vrec = g.read(*vd[2], *vd[1]); va = vrec['Vertices']
        lay, stride = g.layout(*va[1]); comps = {mm['name']: (mm, off) for mm, off in lay}
        bb = [b['BoneName'] for b in g.array(m['BoneBindings'])]
        buf = g.payload[va[3][0]]; base = va[3][1]; pm, po = comps['Position']; bm, bo = comps['BoneIndices']
        P = np.array([struct.unpack_from('<3f', buf, base + i * stride + po) for i in range(va[2])])
        B = [bb[struct.unpack_from('<B', buf, base + i * stride + bo)[0]] for i in range(va[2])]
        out.append((m['Name'], P, B))
    return out


def find_frame(A, Bgrid, cell, scales=(1.0, 2.54, 1 / 2.54)):
    best = None
    for perm in itertools.permutations(range(3)):
        for signs in itertools.product((1, -1), repeat=3):
            for s in scales:
                M = np.zeros((3, 3))
                for i in range(3): M[i, perm[i]] = signs[i] * s
                q = A @ M.T
                hit = sum(tuple(np.round(p / cell).astype(int)) in Bgrid for p in q) / len(q)
                if best is None or hit > best[0]: best = (hit, perm, signs, s, M)
    return best


def std(nums):
    """GXO b/k line floats -> (R standard column-vector convention incl. scale, t)"""
    return np.array(nums[0:9]).reshape(3, 3).T, np.array(nums[9:12])


def line(R, t):
    return ' '.join(fmt(x) for x in list(R.T.flatten()) + list(t))


def main():
    gr2p, dgp, rgp, outp = sys.argv[1:5]
    g = Gr2(gr2p); dh, db, dm = parse(dgp); rh, rb, rm = parse(rgp)
    gv = gr2_vertices(g)
    assert [len(P) for _, P, _ in gv] == [len(m['v']) for m in dm], 'vertex counts differ between gr2 and its GXO'

    # --- frame gr2 -> damaged GXO, and per-index order check (the converter keeps the vertex order)
    P3 = np.array(dm[2]['v']); grid = {tuple(np.round(p / 0.01).astype(int)) for p in P3}
    hit, perm, signs, s, M_g2d = find_frame(gv[2][1][::7], grid, 0.01)
    print(f'FRAME gr2->dmgGXO perm {perm} signs {signs} scale {s}: {hit*100:.1f}%')
    same = np.mean(np.linalg.norm(gv[2][1] @ M_g2d.T - P3, axis=1) < 0.01)
    print(f'vertex order gr2 == GXO: {same*100:.2f}% per index'); assert same > 0.99

    # --- frame damaged GXO -> rig GXO, measured on the mast pieces against the rig's sail meshes
    rig_grid = {}; rig_mb = {}
    for m in rm:
        if m['name'].startswith('sail_'):
            rig_mb[m['name']] = m['mb'][0]
            for p in m['v']: rig_grid[tuple(np.round(np.array(p) / 0.01).astype(int))] = m['name']
    mastP = np.array([p for (_, P, B), m in zip(gv, dm) for p, b in zip(m['v'], B) if b.startswith('mast_wood')])
    hit, perm, signs, s, M = find_frame(mastP, set(rig_grid), 0.01)
    print(f'FRAME dmgGXO->rig perm {perm} signs {signs} scale {s}: {hit*100:.1f}% of mast-piece vertices lie on rig sail vertices')
    assert hit > 0.6
    C = M / s; det = np.linalg.det(M); print('det', round(det, 3))

    # --- labels: mast-piece vertices that coincide with a rig sail mesh
    def look(p):
        k = tuple(np.round(p / 0.01).astype(int))
        if k in rig_grid: return rig_grid[k]
        for d in itertools.product((-1, 0, 1), repeat=3):
            kk = (k[0] + d[0], k[1] + d[1], k[2] + d[2])
            if kk in rig_grid: return rig_grid[kk]
        return None
    labels = []; sail_mast = collections.defaultdict(collections.Counter)
    for (_, P, B), m in zip(gv, dm):
        L = []
        for p, b in zip(np.array(m['v']) @ M.T, B):
            l = look(p) if not b.startswith(('hull', 'bone_')) else None      # any piece may carry sail geometry (a stern sail is a 'wall' piece)
            if l: sail_mast[l.split('_cloth')[0].split('_bar')[0]][b] += 1
            L.append(l)
        labels.append(L)
    mast_of = {sail: c.most_common(1)[0][0] for sail, c in sail_mast.items()}
    print('SAIL -> mast piece:'); [print('   ', k, '->', v, dict(sail_mast[k])) for k, v in sorted(mast_of.items())]

    # --- output meshes: sail meshes (rigid, one bone) + the four hull meshes with per-vertex bindings
    mats = [l.split('"')[1] for l in dh if l.startswith('mt ')]; tex = [l for l in dh if l.startswith('t ')]
    keep = [n for n in mats if n in TEX_OF]; mm_new = {mats.index(n) + 1: keep.index(n) + 1 for n in keep}
    tb = {n: next(i + 1 for i, l in enumerate(tex) if TEX_OF[n] in l) for n in keep}
    out = collections.OrderedDict(); stats = collections.Counter()
    for mi, ((_, P, B), m) in enumerate(zip(gv, dm)):
        L = labels[mi]; hull_key = f"{m['name']}#{mi}"
        for tri in m['f']:
            ls = {L[i - 1] for i in tri}
            if len(ls) == 1 and None not in ls:
                key = ls.pop(); om = out.setdefault(key, dict(name=key, mb=[rig_mb[key]], mm=mm_new[m['mm']], src=mi, tris=[], skinned=False))
            else:
                if None not in ls or len(ls) > 1 and any(ls): stats['mixed'] += 1
                om = out.setdefault(hull_key, dict(name=m['name'], mb=list(m['mb']), mm=mm_new[m['mm']], src=mi, tris=[], skinned=True))
            om['tris'].append(tri); stats[om['name']] += 1
    print('TRIANGLES: mixed', stats['mixed'], '| sail meshes', sum(1 for k in stats if k.startswith('sail_')))

    # --- bones: damaged bones converted into the rig frame, then animtrans + rig sail/banner bones
    names = [b[0] for b in db]; idx = {n: i + 1 for i, n in enumerate(names)}
    L = {}; W = {}
    for name, par, nums in db:
        R, t = std(nums); R2 = C @ R @ C.T; t2 = M @ t
        L[name] = (par, R2, t2)
        A = np.eye(4); A[:3, :3] = R2; A[:3, 3] = t2
        W[name] = (W[names[par - 1]] @ A) if par else A
    blines = [(name, par, line(R2, t2)) for name, (par, R2, t2) in L.items()]
    rig_par = {b[0]: b[1] for b in rb}; rig_num = {b[0]: b[2] for b in rb}; rig_names = [b[0] for b in rb]
    sails = sorted(mast_of)
    for sail in sails:                                     # animtrans under the mast piece: world = identity
        mast = mast_of[sail]; Wi = np.linalg.inv(W[mast])
        blines.append((f'animtrans_{sail}', idx[mast], line(Wi[:3, :3], Wi[:3, 3]))); idx[f'animtrans_{sail}'] = len(blines)
    letter = {sail: rig_mb[sail + '_cloth'].replace('bone_sail', '').replace('_bottom', '') for sail in sails}
    order = [n for n in rig_names if n.startswith('bone_sail')]
    for n in order:
        Lt = next((s for s in sails if n.startswith('bone_sail' + letter[s]) and n[len('bone_sail' + letter[s]):][:1] in ('', '_', 'm')), None)
        if Lt is None: continue
        par_name = rig_names[rig_par[n] - 1]
        par = idx[f'animtrans_{Lt}'] if par_name == 'Object02' else idx[par_name]
        blines.append((n, par, ' '.join(fmt(x) for x in rig_num[n]))); idx[n] = len(blines)
    roots = {s: np.array(rig_num['bone_sail' + letter[s] + '_rot'][9:12]) for s in sails}
    for n in ('bone_banner_a1', 'bone_banner_a2', 'bone_banner_a3', 'bone_flag_civ'):
        if n not in rig_num: continue
        t = np.array(rig_num[n][9:12]); near = min(sails, key=lambda s: np.linalg.norm((roots[s] - t)[:2]))
        blines.append((n, idx[f'animtrans_{near}'], ' '.join(fmt(x) for x in rig_num[n]))); idx[n] = len(blines)
    print('BONES', len(blines), '(damaged', len(db), '+ animtrans', len(sails), '+ sail/banner', len(blines) - len(db) - len(sails), ')')

    # --- write
    with open(outp, 'w', encoding='utf-8', newline='\n') as f:
        for l in tex: f.write(l + '\n')
        for n in keep: f.write('mt "%s"\ntb %d\n' % (n, tb[n]))
        for name, par, nums in blines: f.write('b "%s" %d %s\n' % (name, par, nums))
        for key, om in out.items():
            m = dm[om['src']]; B = gv[om['src']][2]; index = {}; verts = []
            for tri in om['tris']:
                for i in tri:
                    if i not in index: index[i] = len(verts) + 1; verts.append(i - 1)
            mb = om['mb'] if not om['skinned'] else [b for b in om['mb'] if any(B[v] == b for v in verts)]
            if om['skinned']: mb = list(dict.fromkeys(mb + [B[v] for v in verts]))
            f.write('m "%s"\n' % om['name'])
            for b in mb: f.write('mb "%s"\n' % b)
            f.write('mm %d\n' % om['mm'])
            mbi = {b: i + 1 for i, b in enumerate(mb)}
            for v in verts:
                f.write('v %s\n' % ' '.join(fmt(x) for x in (np.array(m['v'][v]) @ M.T)))
                f.write('vn %s\n' % ' '.join(fmt(x) for x in (np.array(m['vn'][v]) @ C.T)))
                f.write('vt %s\n' % ' '.join(fmt(x) for x in m['vt'][v]))
                if om['skinned']: k = mbi[B[v]]; f.write('vw 1 0 0 0 %d %d %d %d\n' % (k, k, k, k))
            f.write('fg 1\n')
            for tri in om['tris']:
                a, b, c = (index[i] for i in tri)
                f.write('f %d %d %d\n' % ((a, c, b) if det < 0 else (a, b, c)))
            print(f"  {om['name']:36} bones={len(mb):3d} verts={len(verts):6d} tris={len(om['tris']):6d}{' skinned' if om['skinned'] else ''}")
    print('WROTE', outp)


if __name__ == '__main__':
    main()
