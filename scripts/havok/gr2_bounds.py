"""Bone-binding bounds of a .gr2: every Mesh.BoneBindings[k] stores OBBMin/OBBMax = the box of the mesh's REFERENCED
vertices bound to binding k, in that bone's rest-local frame (row vector [p, 1] . InverseWorldTransform). Measured, not
assumed: exact (1e-5) on all five meshes of vanilla homecity/china/docks01, rest-posed and offset bones alike.

An in-place edit that moves, adds or drops vertices leaves the stored boxes where the old geometry was (Korean HC
docks01, 2026-10-17: pier, collision mesh and a junk boat moved ~20 m while their boxes stayed vanilla - the meshes were
also misplaced, and neither was visible in game). gr2_droptris / gr2_rotate_verts / gr2_editmesh call refresh() on
their output; gr2_lint check `bounds` fails a model whose referenced vertices lie outside their stored box.

    python gr2_bounds.py FILE...            # report per binding; exit 1 when a referenced vertex lies outside its box
    python gr2_bounds.py --fix IN OUT       # rewrite every box from its referenced vertices (CRC recomputed)

Membership: a rigid mesh (no BoneIndices) puts every referenced vertex on its one binding; an indexed mesh without
BoneWeights (destruction pieces) on its BoneIndices[0] binding - both exact on vanilla (china_towncenter_age2_damaged:
312/312 boxes, 15 homecity/building models). WEIGHTED (skinned) meshes are left alone and reported as such: their vanilla
boxes are no AABB of the rest vertices (blue_guard: 0/18 boxes reproduced by any-weight, dominant-bone, weight >= .25 /
.5 or all-vertex membership; up to 1.78 units off). A binding without referenced vertices keeps its stored box.
"""
import argparse, struct, sys, zlib
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gr2_read import Gr2   # noqa: E402
from gr2_dump import refs  # noqa: E402

TYPE_NP = {10: '<f4', 11: 'i1', 12: 'u1', 13: 'i1', 14: 'u1', 15: '<i2', 16: '<u2', 17: '<i2', 18: '<u2', 19: '<i4',
           20: '<u4', 21: '<f2'}


def tolerance(lo, hi):
    """float32 storage + a float64 recomputation through a float32 inverse-world matrix"""
    return 1e-3 + 1e-5 * float(np.abs(np.concatenate([lo, hi])).max(initial=0.0))


def extents(pos, tris, iws, bone_idx=None, bone_w=None):
    """-> [(lo, hi, n) or None] per binding: box of the referenced vertices in each binding's bone-local frame.
    pos (n,3) model space; tris (t,3); iws = one 4x4 InverseWorldTransform per binding (row-vector convention);
    bone_idx/bone_w (n,k) for skinned meshes (None = rigid)."""
    used = np.unique(np.asarray(tris, np.int64)) if len(tris) else np.zeros(0, np.int64)
    out = []
    for k, iw in enumerate(iws):
        if bone_idx is None:
            sel = used if len(iws) == 1 else np.zeros(0, np.int64)
        else:
            bi = bone_idx[used].astype(np.int64)
            on = (bi == k) & (bone_w[used] > 0) if bone_w is not None else (bi[:, :1] == k)
            sel = used[on.any(axis=1)]
        if not len(sel):
            out.append(None); continue
        local = (np.c_[pos[sel], np.ones(len(sel))] @ np.asarray(iw, float))[:, :3]
        out.append((local.min(0), local.max(0), int(len(sel))))
    return out


def _mesh_arrays(g, rec, data):
    """positions, triangles, bone indices / weights of one mesh, read from `data` (bytes of the whole file)"""
    fo = lambda sec, off: g.sections[sec]['data_off'] + off                     # noqa: E731
    va = g.read(*rec['PrimaryVertexData'][2], *rec['PrimaryVertexData'][1])['Vertices']
    vtype, nv, vptr = va[1], va[2], va[3]
    comps = {}
    if nv:
        lay, stride = g.layout(*vtype)
        buf = np.frombuffer(data, np.uint8, nv * stride, fo(*vptr)).reshape(nv, stride)
        for m, off in lay:
            if m['name'] in ('Position', 'BoneIndices', 'BoneWeights') and m['type'] in TYPE_NP:
                dt = np.dtype(TYPE_NP[m['type']]); c = max(m['count'], 1)
                comps[m['name']] = buf[:, off:off + dt.itemsize * c].copy().view(dt).reshape(nv, c).astype(np.float64)
    top = g.read(*rec['PrimaryTopology'][2], *rec['PrimaryTopology'][1])
    for key, dt in (('Indices', '<i4'), ('Indices16', '<u2')):
        n = struct.unpack_from('<i', data, fo(*rec['PrimaryTopology'][1]) + _member_off(g, rec['PrimaryTopology'][2], key))[0]
        if n:
            p = top[key][2]
            tris = np.frombuffer(data, dt, n, fo(*p)).astype(np.int64).reshape(-1, 3); break
    else:
        tris = np.zeros((0, 3), np.int64)
    return comps.get('Position', np.zeros((nv, 3))), tris, comps.get('BoneIndices'), comps.get('BoneWeights')


def _member_off(g, tref, name):
    return next(off for m, off in g.layout(*tref)[0] if m['name'] == name)


def bindings(path_or_g, data=None, meshes=None):
    """-> list of dict(mesh, bone, k, stored=(lo, hi), box=(lo, hi, n) or None, outside, excess, off_min, off_max)"""
    g = path_or_g if isinstance(path_or_g, Gr2) else Gr2(str(path_or_g))
    data = bytes(g.data if data is None else data)
    fo = lambda sec, off: g.sections[sec]['data_off'] + off                     # noqa: E731
    r = g.root(); sks = refs(g, r['Skeletons'])
    iw = {}
    for sk, _ in sks[:1]:
        for b in g.array(sk['Bones']):
            iw.setdefault(b['Name'], np.array(b['InverseWorldTransform'], float).reshape(4, 4))
    out = []
    for rec, _ in refs(g, r['Meshes']):
        if meshes is not None and rec['Name'] not in meshes:
            continue
        bb = rec['BoneBindings']
        if not bb[1]:
            continue
        lay = {m['name']: off for m, off in g.layout(*bb[3])[0]}; size = g.struct_size(*bb[3])
        recs = g.array(bb); names = [x['BoneName'] for x in recs]
        if any(n not in iw for n in names):
            out.append(dict(mesh=rec['Name'], bone=None, k=-1, error=f'bone(s) {[n for n in names if n not in iw]} not in the skeleton'))
            continue
        pos, tris, bi, bw = _mesh_arrays(g, rec, data)
        if bw is not None:
            out.append(dict(mesh=rec['Name'], bone=None, k=-1, skinned=True)); continue
        boxes = extents(pos, tris, [iw[n] for n in names], bi, bw)
        for k, (x, box) in enumerate(zip(recs, boxes)):
            base = fo(*bb[2]) + k * size
            lo, hi = np.array(struct.unpack_from('<3f', data, base + lay['OBBMin'])), np.array(struct.unpack_from('<3f', data, base + lay['OBBMax']))
            ex = 0.0
            if box is not None:
                ex = float(max((lo - box[0]).max(), (box[1] - hi).max(), 0.0))
            out.append(dict(mesh=rec['Name'], bone=names[k], k=k, stored=(lo, hi), box=box, excess=ex,
                            outside=box is not None and ex > tolerance(lo, hi),
                            off_min=base + lay['OBBMin'], off_max=base + lay['OBBMax']))
    return out


def refresh(src, out=None, meshes=None):
    """rewrite the stored box of every binding (or of the named meshes) from its referenced vertices; CRC recomputed.
    Writes `out` (default: in place). -> the bindings() report of the input."""
    g = Gr2(str(src)); assert all(s['compression'] == 0 for s in g.sections if s['data_size']), 'compressed sections'
    d = bytearray(g.data); rep = bindings(g, d, meshes)
    for b in rep:
        if b.get('box') is not None:
            struct.pack_into('<3f', d, b['off_min'], *b['box'][0]); struct.pack_into('<3f', d, b['off_max'], *b['box'][1])
    struct.pack_into('<I', d, 32 + 8, zlib.crc32(bytes(d[g.sec_table:])) & 0xffffffff)
    Path(out or src).write_bytes(d)
    return rep


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0]); ap.add_argument('files', nargs='+')
    ap.add_argument('--fix', action='store_true', help='IN OUT: rewrite every box from its referenced vertices')
    a = ap.parse_args(argv)
    if a.fix:
        assert len(a.files) == 2, '--fix IN OUT'
        refresh(*a.files); a.files = a.files[1:]
    bad = 0
    for f in a.files:
        for b in bindings(f):
            if b.get('skinned'):
                print(f"{Path(f).name}: {b['mesh']:30} weighted (skinned) mesh: boxes not checked"); continue
            if b.get('error'):
                print(f"{f}: {b['mesh']}: {b['error']}"); bad += 1; continue
            box = b['box']; lo, hi = b['stored']
            state = 'no referenced vertices' if box is None else (f"OUTSIDE by {b['excess']:.4f}" if b['outside'] else 'ok')
            bad += bool(b['outside'])
            print(f"{Path(f).name}: {b['mesh']:30} {b['bone']:24} stored {np.round(lo, 3).tolist()}..{np.round(hi, 3).tolist()}"
                  + ('' if box is None else f" verts {box[2]} box {np.round(box[0], 3).tolist()}..{np.round(box[1], 3).tolist()}") + f"  {state}")
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
