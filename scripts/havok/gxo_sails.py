"""Build the sail-rigged Treasure Ship model from the ORIGINAL vanilla GXO instead of a Blender re-export.
Vertex data (positions, normals, uvs, faces) come straight from the converter's GXO of the vanilla gr2; the mesh
split and the bones come from the rig build's GXO (converter output of the Blender-built model), which is used
only as a look-up table: every vanilla vertex that coincides with a vertex of a rig sail mesh gets that mesh's
label, triangles whose three corners agree become that sail mesh (bound to the rig's bone), the rest stays in the
three vanilla meshes. The frame/scale between the two GXOs is measured (signed axis permutation x scale), not assumed.

usage: python gxo_sails.py vanilla.gxo rig.gxo out.gxo
"""
import sys, itertools, collections
import numpy as np


def parse(path):
    """-> header lines, bones [(name, parent, floats)], meshes [dict(name, mb, mm, v, vn, vt, vw, f, fg_lines)]"""
    header, bones, meshes = [], [], []
    cur = None
    for line in open(path, encoding='utf-8', errors='replace'):
        line = line.rstrip('\n')
        if not line: continue
        tag, _, rest = line.partition(' ')
        if tag == 'm':
            cur = dict(name=rest.strip().strip('"'), mb=[], mm=None, v=[], vn=[], vt=[], vw=[], f=[], fg=[]); meshes.append(cur)
        elif cur is None:
            if tag == 'b':
                q = rest.rindex('"'); name = rest[1:q]; nums = rest[q + 1:].split()
                bones.append((name, int(nums[0]), [float(x) for x in nums[1:]]))
            else: header.append(line)
        elif tag == 'mb': cur['mb'].append(rest.strip().strip('"'))
        elif tag == 'mm': cur['mm'] = int(rest)
        elif tag in ('v', 'vn', 'vt', 'vw'): cur[tag].append([float(x) for x in rest.split()])
        elif tag == 'f': cur['f'].append([int(x) for x in rest.split()])
        elif tag == 'fg': cur['fg'].append(line)
        else: raise ValueError('unknown line in mesh block: ' + line[:40])
    return header, bones, meshes


def fmt(x): return ('%.9g' % x)


def main():
    vpath, rpath, opath = sys.argv[1:4]
    vh, vb, vm = parse(vpath); rh, rb, rm = parse(rpath)
    print(f'vanilla: {len(vb)} bones, {len(vm)} meshes, {sum(len(m["v"]) for m in vm)} verts; rig: {len(rb)} bones, {len(rm)} meshes')

    # --- frame: find (signed permutation, scale) that maps vanilla hull vertices onto the rig's hull vertices
    vhull = np.array([v for m in vm for v in m['v']])
    rhull = np.array([v for m in rm for v in m['v']])                      # every rig vertex (hull + sails)
    rgrid = {tuple(np.round(p / 0.01).astype(int)) for p in rhull}
    sample = vhull[np.random.RandomState(1).choice(len(vhull), 3000, replace=False)]
    best = None
    for perm in itertools.permutations(range(3)):
        for signs in itertools.product((1, -1), repeat=3):
            for scale in (1.0, 2.54):
                M = np.zeros((3, 3))
                for i in range(3): M[i, perm[i]] = signs[i] * scale
                q = sample @ M.T
                hit = sum(tuple(np.round(p / 0.01).astype(int)) in rgrid for p in q) / len(q)
                if best is None or hit > best[0]: best = (hit, perm, signs, scale, M)
    hit, perm, signs, scale, M = best
    print(f'FRAME vanilla->rig: perm {perm} signs {signs} scale {scale} : {hit*100:.1f}% of sampled vertices coincide (1 cm grid)')
    assert hit > 0.9, 'no consistent frame between the two GXOs - stop'
    det = np.linalg.det(M); print('det', round(det, 3), '(negative = mirrored: face winding flipped)')

    # --- labels from the rig's sail meshes (exact position lookup on a fine grid, then a 1-cell neighbourhood)
    label = {}; rig_mb = {}
    for m in rm:
        if not m['name'].startswith('sail_'): continue
        rig_mb[m['name']] = m['mb'][0]
        for p in m['v']: label[tuple(np.round(np.array(p) / 0.002).astype(int))] = m['name']
    def look(p):
        k = tuple(np.round(p / 0.002).astype(int))
        if k in label: return label[k]
        for d in itertools.product((-1, 0, 1), repeat=3):
            kk = (k[0] + d[0], k[1] + d[1], k[2] + d[2])
            if kk in label: return label[kk]
        return None

    # --- split every vanilla mesh by triangle
    out_meshes = collections.OrderedDict()             # name -> dict(mb, mm, tris [(srcmesh, (i,j,k))])
    stats = collections.Counter()
    for m in vm:
        P = np.array(m['v']) @ M.T
        lab = [look(p) for p in P]
        for tri in m['f']:
            l = {lab[i - 1] for i in tri}
            name = l.pop() if len(l) == 1 and None not in l else None
            if name is None:
                if len(l) > 1 and None not in l: stats['mixed'] += 1
                name = m['name']; mb = m['mb'][0]
            else: mb = rig_mb[name]
            key = name if name == m['name'] or name not in out_meshes or out_meshes[name]['mm'] == m['mm'] else name + '_' + str(m['mm'])
            om = out_meshes.setdefault(key, dict(mb=mb, mm=m['mm'], tris=[]))
            om['tris'].append((m, tri))
            stats[key] += 1
    print('TRIANGLES per output mesh:', dict(stats))

    # --- write: header verbatim, rig bones verbatim (rig frame), meshes with re-indexed vertices
    order = [n for n in rig_mb if n in out_meshes] + [n for n in out_meshes if n not in rig_mb]
    R = M / scale                                   # rotation/mirror part for normals
    # materials: the vanilla GXO lists Maya file nodes as materials and binds no textures; the converter's importer
    # keeps a material only when a tb line binds it to a t line (measured: mt without tb vanish in its own round trip)
    tex = [l for l in vh if l.startswith('t ')]; mats = [l.split('"')[1] for l in vh if l.startswith('mt ')]
    TEX_OF = {'matc': 'hulldragon', 'mata': 'stage_final_matA', 'matb': 'stage_final_matB'}      # treasure ship only
    keep = [n for n in mats if n in TEX_OF]; mm_map = {mats.index(n) + 1: keep.index(n) + 1 for n in keep}
    tb = {n: next(i + 1 for i, l in enumerate(tex) if TEX_OF[n] in l) for n in keep}
    print('MATERIALS', [(n, 'tb', tb[n]) for n in keep], 'mm remap', mm_map)
    with open(opath, 'w', encoding='utf-8', newline='\n') as f:
        for line in tex: f.write(line + '\n')
        for n in keep: f.write('mt "%s"\ntb %d\n' % (n, tb[n]))
        for name, par, nums in rb: f.write('b "%s" %d %s\n' % (name, par, ' '.join(fmt(x) for x in nums)))
        for name in order:
            om = out_meshes[name]; index = {}; verts = []
            for src, tri in om['tris']:
                for i in tri:
                    k = (id(src), i)
                    if k not in index: index[k] = len(verts) + 1; verts.append((src, i - 1))
            f.write('m "%s"\nmb "%s"\nmm %d\n' % (name, om['mb'], mm_map[om['mm']]))
            for src, i in verts:                    # interleaved per vertex, exactly as the converter writes and reads it
                f.write('v %s\n' % ' '.join(fmt(x) for x in (np.array(src['v'][i]) @ M.T)))
                n = np.array(src['vn'][i]) @ R.T; n = n / (np.linalg.norm(n) or 1.0)     # the converter dumps packed int8 normals as value/254
                f.write('vn %s\n' % ' '.join(fmt(x) for x in n))                          # (half length -> half-bright lighting); write unit normals
                f.write('vt %s\n' % ' '.join(fmt(x) for x in src['vt'][i]))
            f.write('fg 1\n')
            for src, tri in om['tris']:
                a, b, c = (index[(id(src), i)] for i in tri)
                f.write('f %d %d %d\n' % ((a, c, b) if det < 0 else (a, b, c)))
            print(f"  {name:40} mb={om['mb']:36} mm={om['mm']} verts={len(verts)} tris={len(om['tris'])}")
    print('WROTE', opath)


if __name__ == '__main__':
    main()
