"""Plan-driven in-place edit of ONE rigid mesh in a vanilla .gr2 (vertex bytes stay vanilla, nothing is re-encoded):
    - rewrite UVs of listed vertices, recompute the tangent (+dU, int8) and its sign byte for listed triangles
    - drop triangles from the source mesh (replacement TriTopology, as gr2_splitmesh does)
    - append NEW rigid meshes made of transformed copies of source triangles (groups, each with its own R/t) plus
      hand-placed extra vertices/triangles (copied vertex bytes with position/UV overrides)
    - finally bake a frame change + uniform scale into every vertex (position, int8 normal/tangent), scale the bone
      positions / inverse-world translations, reset the root bind matrix + model placement to identity, recompute OBBs
Vertex layout required: 24 B = Position f32x3 @0, Normal int8x3+pad @12, Tangent int8x3+sign @16, UV f16x2 @20
(the vanilla rigid layout; sign byte -128 = right-handed, 0 = left-handed - measured on british_tol).

plan.json:
{"mesh": "british_tol", "scale": 0.65, "bake": "zup_to_yup" | null, "reset_root": true,
 "bones": [{"name": "bone_main", "parent": -1, "pos": [0, 0, 0]}, {"name": "bone_flag_civ", "parent": 0, "pos": [x, y, z]}],   # optional skeleton rewrite
 "uv": [[vertex, u, v], ...], "retangent": [tri, ...], "drop": [tri, ...],
 "new": [{"name": "...", "bone": "bone_main", "material": "matb" (optional: own material record, cloned),
          "groups": [{"R": [[..3x3..]], "t": [x, y, z], "tris": [tri, ...], "flip": false}, ...],   # flip = back-face copy
          "extra_verts": [{"src": vertex, "pos": [x, y, z], "uv": [u, v], "nrm": [x, y, z]}, ...], "extra_tris": [[a, b, c], ...]}]}
Coordinates in the plan are the SOURCE mesh space (before bake/scale). Extra verts are welded by index only.

usage: python gr2_editmesh.py vanilla.gr2 plan.json out.gr2
"""
import sys, json, struct
import numpy as np
from gr2_read import Gr2
from gr2_dump import refs
from gr2_splitmesh import Builder, member_offsets

P = 8
STRIDE = 24
BAKES = {None: np.eye(3), 'none': np.eye(3),
         'zup_to_yup': np.array([[1, 0, 0], [0, 0, 1], [0, -1, 0]], float)}   # out = R @ v : (x, y, z) -> (x, z, -y)


def i8(v):
    return np.clip(np.rint(v), -127, 127).astype(np.int8)


def unpack(raw):
    n = len(raw) // STRIDE
    r = np.frombuffer(bytes(raw), dtype=np.uint8).reshape(n, STRIDE)
    pos = r[:, 0:12].copy().view('<f4').reshape(n, 3).astype(np.float64)
    nrm = r[:, 12:16].copy().view(np.int8).reshape(n, 4)
    tan = r[:, 16:20].copy().view(np.int8).reshape(n, 4)
    uv = r[:, 20:24].copy().view('<f2').reshape(n, 2).astype(np.float64)
    return r.copy(), pos, nrm, tan, uv


def pack(r, pos, nrm, tan, uv):
    r[:, 0:12] = pos.astype('<f4').view(np.uint8).reshape(len(r), 12)
    r[:, 12:16] = nrm.astype(np.int8).view(np.uint8).reshape(len(r), 4)
    r[:, 16:20] = tan.astype(np.int8).view(np.uint8).reshape(len(r), 4)
    r[:, 20:24] = uv.astype('<f2').view(np.uint8).reshape(len(r), 4)
    return r


def retangent(pos, nrm, tan, uv, tris):
    """per-corner tangent = +dU direction of the triangle (orthogonalised to the stored normal), sign byte from handedness"""
    acc = {}
    for a, b, c in tris:
        p0, p1, p2 = pos[a], pos[b], pos[c]; u0, u1, u2 = uv[a], uv[b], uv[c]
        e1, e2 = p1 - p0, p2 - p0
        du1, dv1 = u1 - u0; du2, dv2 = u2 - u0
        det = du1 * dv2 - du2 * dv1
        if abs(det) < 1e-12: continue
        T = (e1 * dv2 - e2 * dv1) / det; B = (e2 * du1 - e1 * du2) / det
        for v in (a, b, c):
            acc.setdefault(v, []).append((T, B))
    for v, lst in acc.items():
        T = sum(t for t, _ in lst); B = sum(b for _, b in lst)
        N = nrm[v, :3].astype(float) / 127.0; N /= np.linalg.norm(N) + 1e-12
        T = T - N * np.dot(N, T); T /= np.linalg.norm(T) + 1e-12
        hand = np.dot(np.cross(N, T), B)
        tan[v, :3] = i8(T * 127.0); tan[v, 3] = -128 if hand >= 0 else 0
    return tan


def main():
    src, planp, outp = sys.argv[1:4]
    plan = json.load(open(planp, encoding='utf-8'))
    g = Gr2(src); assert g.ptr == 8 and g.crc_check(); r = g.root()
    meshes = refs(g, r['Meshes'])
    mrec, mloc = next((m, l) for m, l in meshes if m['Name'] == plan['mesh'])
    vd = mrec['PrimaryVertexData']; vrec = g.read(*vd[2], *vd[1]); va = vrec['Vertices']
    vtype, nverts, vdata = va[1], va[2], va[3]; assert g.struct_size(*vtype) == STRIDE
    lay = [(m['name'], off) for m, off in g.layout(*vtype)[0]]
    assert [o for _, o in lay] == [0, 12, 15, 16, 19, 20], lay
    vsec, vbase = vdata
    tt = mrec['PrimaryTopology']; top = g.read(*tt[2], *tt[1]); idx = top['Indices']
    assert idx[0] == 'array' and idx[1] and top['Indices16'][1] == 0
    isec, ibase = idx[2]
    tris = np.frombuffer(bytes(g.payload[isec][ibase:ibase + 4 * idx[1]]), dtype='<i4').reshape(-1, 3).copy()
    groups = g.array(top['Groups']); assert len(groups) == 1 and groups[0]['TriCount'][0] == len(tris)

    B = Builder(g)
    raw, pos, nrm, tan, uv = unpack(B.sec[vsec][vbase:vbase + nverts * STRIDE])
    # 1. UV rewrites + tangents of the existing mesh
    for vi, u, v in plan.get('uv', []): uv[vi] = (u, v)
    if plan.get('retangent'): tan = retangent(pos, nrm, tan, uv, tris[plan['retangent']])
    # 2. replacement topology without the dropped triangles
    drop = set(plan.get('drop', [])); keep = np.array([t for i, t in enumerate(tris) if i not in drop], dtype='<i4')
    mesh_t = r['Meshes'][3]
    MESH = dict(zip(['Name', 'PrimaryVertexData', 'PrimaryTopology', 'MaterialBindings', 'BoneBindings', 'ExtendedData'],
                    member_offsets(g, mesh_t, ['Name', 'PrimaryVertexData', 'PrimaryTopology', 'MaterialBindings', 'BoneBindings', 'ExtendedData'])))
    assert MESH == {'Name': 0, 'PrimaryVertexData': 8, 'PrimaryTopology': 28, 'MaterialBindings': 36, 'BoneBindings': 48, 'ExtendedData': 60}
    new_topo_ptrs = []; new_mesh_ptrs = []; new_vd_ptrs = []; report = []
    if drop:
        ioff = B.alloc(isec, keep.tobytes(), 4)
        grp = B.alloc(0, struct.pack('<3i', 0, 0, len(keep)))
        tpo = B.alloc(0, bytes(132)); B.i32(0, tpo, 1); B.ptr(0, tpo + 4, (0, grp)); B.i32(0, tpo + 12, 3 * len(keep)); B.ptr(0, tpo + 16, (isec, ioff))
        B.repoint(mloc[0], mloc[1] + 28, (0, tpo)); new_topo_ptrs.append((0, tpo))
    # 3. bake for everything that follows
    RB = BAKES[plan.get('bake')]; s = float(plan.get('scale', 1.0))
    def bake(pos_, nrm_, tan_):
        pos_ = (pos_ @ RB.T) * s
        nrm_ = nrm_.copy(); tan_ = tan_.copy()
        nrm_[:, :3] = i8(nrm_[:, :3].astype(float) @ RB.T); tan_[:, :3] = i8(tan_[:, :3].astype(float) @ RB.T)
        return pos_, nrm_, tan_
    def obb(bbo, p):
        struct.pack_into('<6f', B.sec[0], bbo + 8, *p.min(0), *p.max(0))
    # 4. new meshes (optional "material": "<name>" = a clone of the source mesh's material record under a new name,
    #    so the .material file can give those faces their own textures; the clone shares the map/texture records)
    mat_t = r['Materials'][3]; MAT = dict(zip(['Name', 'Maps', 'Texture', 'ExtendedData'], member_offsets(g, mat_t, ['Name', 'Maps', 'Texture', 'ExtendedData'])))
    assert MAT == {'Name': 0, 'Maps': 8, 'Texture': 20, 'ExtendedData': 28} and g.struct_size(*mat_t) == 44
    src_mb = mrec['MaterialBindings']; src_mat = g.deref(src_mb[2][0], src_mb[2][1])          # (sec, off) of the source material
    new_mat_ptrs = []; mats = {}
    def material_named(name):
        if name in mats: return mats[name]
        srec = g.read(*mat_t, *src_mat); maps = srec['Maps']; msz = g.struct_size(*maps[3])
        marr = B.alloc(0, bytes(msz * maps[1]))
        for k in range(maps[1]):
            for m_, off_ in g.layout(*maps[3])[0]:
                B.ptr(0, marr + k * msz + off_, g.deref(maps[2][0], maps[2][1] + k * msz + off_))
        mo = B.alloc(0, bytes(44)); B.ptr(0, mo, B.string(name)); B.i32(0, mo + 8, maps[1]); B.ptr(0, mo + 12, (0, marr))
        mats[name] = (0, mo); new_mat_ptrs.append((0, mo)); return mats[name]
    for nm in plan.get('new', []):
        vb = []; vpos = []; vnrm = []; vtan = []; vuv = []; ltris = []
        for grp_ in nm.get('groups', []):
            R = np.array(grp_['R'], float); t = np.array(grp_.get('t', [0, 0, 0]), float)
            flip = bool(grp_.get('flip', False))              # back-face copy: normals negated, winding reversed, handedness toggled
            rev = flip ^ (np.linalg.det(R) < 0)               # a reflection (det<0) also reverses the winding
            remap = {}
            for ti in grp_['tris']:
                tri = []
                for vi in tris[ti]:
                    if vi not in remap:
                        remap[vi] = len(vb); vb.append(raw[vi].copy())
                        vpos.append(R @ pos[vi] + t); vuv.append(uv[vi].copy())
                        n_ = nrm[vi].copy(); n_[:3] = i8((-1 if flip else 1) * (R @ nrm[vi, :3].astype(float))); vnrm.append(n_)
                        t_ = tan[vi].copy(); t_[:3] = i8(R @ tan[vi, :3].astype(float))
                        if rev: t_[3] = 0 if t_[3] == -128 else -128
                        vtan.append(t_)
                    tri.append(remap[vi])
                ltris.append([tri[0], tri[2], tri[1]] if rev else tri)
        base = len(vb); ex = []
        for ev in nm.get('extra_verts', []):
            vi = ev['src']; vb.append(raw[vi].copy()); vpos.append(np.array(ev.get('pos', pos[vi]), float))
            n_ = nrm[vi].copy()
            if 'nrm' in ev: n_[:3] = i8(np.array(ev['nrm'], float) / (np.linalg.norm(ev['nrm']) + 1e-12) * 127.0)
            vnrm.append(n_); vtan.append(tan[vi].copy()); vuv.append(np.array(ev.get('uv', uv[vi]), float))
        for a, b, c in nm.get('extra_tris', []): ltris.append([base + a, base + b, base + c]); ex.append(len(ltris) - 1)
        if not vb: continue
        vb = np.array(vb); vpos = np.array(vpos); vnrm = np.array(vnrm); vtan = np.array(vtan); vuv = np.array(vuv); ltris = np.array(ltris, dtype='<i4')
        if ex and nm.get('retangent_extra', True): vtan = retangent(vpos, vnrm, vtan, vuv, ltris[ex])
        bp, bn, bt = bake(vpos, vnrm, vtan)
        vbytes = pack(vb, bp, bn, bt, vuv).tobytes()
        voff = B.alloc(vsec, vbytes, 4); ioff = B.alloc(isec, ltris.tobytes(), 4)
        vdo = B.alloc(0, bytes(44)); B.ptr(0, vdo, vtype); B.i32(0, vdo + 8, len(vb)); B.ptr(0, vdo + 12, (vsec, voff))
        # own VertexComponentNames array (the strings stay shared, as between vanilla meshes) - sharing the array
        # itself between two meshes crashed the 32-bit converter's tree conversion intermittently
        vcn = vrec['VertexComponentNames']; vcn_arr = B.alloc(0, bytes(P * vcn[1]))
        for k in range(vcn[1]): B.ptr(0, vcn_arr + k * P, g.deref(vcn[2][0], vcn[2][1] + k * P))
        B.i32(0, vdo + 20, vcn[1]); B.ptr(0, vdo + 24, (0, vcn_arr))
        grp = B.alloc(0, struct.pack('<3i', 0, 0, len(ltris)))
        tpo = B.alloc(0, bytes(132)); B.i32(0, tpo, 1); B.ptr(0, tpo + 4, (0, grp)); B.i32(0, tpo + 12, 3 * len(ltris)); B.ptr(0, tpo + 16, (isec, ioff))
        bbo = B.alloc(0, bytes(44)); B.ptr(0, bbo, B.string(nm.get('bone', 'bone_main'))); obb(bbo, bp)
        mo = B.alloc(0, bytes(76)); B.ptr(0, mo, B.string(nm['name'])); B.ptr(0, mo + 8, (0, vdo)); B.ptr(0, mo + 28, (0, tpo))
        # own MaterialBindings array (each entry = pointer to the shared Material record) and own ExtendedData record
        mb = mrec['MaterialBindings']; mb_size = g.struct_size(*mb[3]); mb_arr = B.alloc(0, bytes(mb_size * mb[1]))
        for k in range(mb[1]):
            src_off = mb[2][1] + k * mb_size
            for m_, off_ in g.layout(*mb[3])[0]:
                if m_['name'] == 'Material':
                    B.ptr(0, mb_arr + k * mb_size + off_, material_named(nm['material']) if nm.get('material') else g.deref(mb[2][0], src_off + off_))
        B.i32(0, mo + 36, mb[1]); B.ptr(0, mo + 40, (0, mb_arr))
        B.i32(0, mo + 48, 1); B.ptr(0, mo + 52, (0, bbo))
        ext = mrec['ExtendedData']
        if ext and ext[0] == 'variant' and ext[1]:
            esz = g.struct_size(*ext[1]); eo = B.alloc(0, bytes(g.payload[ext[2][0]][ext[2][1]:ext[2][1] + esz]))
            B.ptr(0, mo + 60, ext[1]); B.ptr(0, mo + 68, (0, eo))
        new_mesh_ptrs.append((0, mo)); new_topo_ptrs.append((0, tpo)); new_vd_ptrs.append((0, vdo))
        report.append((nm['name'], len(vb), len(ltris)))
    # 5. the source mesh: baked vertex bytes in place, OBB
    bp, bn, bt = bake(pos, nrm, tan)
    B.sec[vsec][vbase:vbase + nverts * STRIDE] = pack(raw, bp, bn, bt, uv).tobytes()
    bb = mrec['BoneBindings']; assert bb[0] == 'array' and bb[1] == 1
    used = np.unique(keep) if len(keep) else np.arange(nverts)
    obb(bb[2][1], bp[used])
    report.append((mrec['Name'], nverts, len(keep)))
    # 6. skeleton: bone positions and inverse-world translations scaled; root bind matrix reset
    #    plan 'bones' = [{name, parent, pos (source mesh space)}, ...]: the skeleton is rewritten IN PLACE to exactly these
    #    bones (count shrinks, records reused; every listed bone gets identity rotation/scale, flags 1 = position only,
    #    0 for the root; parents must precede children)
    for sk, sloc in refs(g, r['Skeletons']):
        arr = sk['Bones']; bsize = g.struct_size(*arr[3]); bsec, boff = arr[2]
        assert bsize == 164 and bsec == 0
        if plan.get('bones'):
            nb = plan['bones']; assert 1 <= len(nb) <= arr[1], 'the rewrite only shrinks the bone array'
            world = []
            for i, b in enumerate(nb):
                o = boff + i * bsize; par = int(b.get('parent', -1)); assert par < i
                p = (RB @ np.array(b.get('pos', [0, 0, 0]), float)) * s
                wp = p + (world[par] if par >= 0 else 0)
                world.append(wp)
                B.repoint(bsec, o, B.string(b['name'])); B.i32(bsec, o + 8, par)
                struct.pack_into('<i3f4f9f', B.sec[bsec], o + 12, 0 if par < 0 else 1, *p, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1)
                struct.pack_into('<16f', B.sec[bsec], o + 80, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, *(-wp), 1)
            BONES_OFF = member_offsets(g, r['Skeletons'][3], ['Bones'])[0]
            B.i32(sloc[0], sloc[1] + BONES_OFF, len(nb))
            report.append(('skeleton', len(nb), 0)); continue
        for i in range(arr[1]):
            o = boff + i * bsize
            p = list(struct.unpack_from('<3f', B.sec[0], o + 16)); struct.pack_into('<3f', B.sec[0], o + 16, *[x * s for x in p])
            m = list(struct.unpack_from('<16f', B.sec[0], o + 80))
            if i == 0 and plan.get('reset_root', True): m = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
            m[12] *= s; m[13] *= s; m[14] *= s
            struct.pack_into('<16f', B.sec[0], o + 80, *m)
    if plan.get('reset_root', True):
        model_t = r['Models'][3]; IP = member_offsets(g, model_t, ['InitialPlacement'])[0]
        for m, ml in refs(g, r['Models']):
            assert ml[0] == 0
            struct.pack_into('<i3f4f9f', B.sec[0], ml[1] + IP, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    # 7. root arrays + model mesh bindings
    ROOT_MESHES, ROOT_TOPOS, ROOT_VDS = member_offsets(g, (g.root_type_sec, g.root_type_off), ['Meshes', 'TriTopologies', 'VertexDatas'])
    def refarray(field_sec, field_off, old, new_ptrs):
        n = old[1]; ptrs = [g.deref(old[2][0], old[2][1] + i * P) for i in range(n)] + new_ptrs
        arr = B.alloc(0, bytes(P * len(ptrs)))
        for i, tp in enumerate(ptrs): B.ptr(0, arr + i * P, tp)
        B.i32(field_sec, field_off, len(ptrs)); B.repoint(field_sec, field_off + 4, (0, arr))
        return ptrs
    if new_mat_ptrs:
        ROOT_MATS = member_offsets(g, (g.root_type_sec, g.root_type_off), ['Materials'])[0]
        refarray(g.root_sec, g.root_off + ROOT_MATS, r['Materials'], new_mat_ptrs)
    if new_mesh_ptrs or new_topo_ptrs:
        all_meshes = refarray(g.root_sec, g.root_off + ROOT_MESHES, r['Meshes'], new_mesh_ptrs)
        refarray(g.root_sec, g.root_off + ROOT_TOPOS, r['TriTopologies'], new_topo_ptrs)
        refarray(g.root_sec, g.root_off + ROOT_VDS, r['VertexDatas'], new_vd_ptrs)
        model, model_loc = refs(g, r['Models'])[0]; MODEL_MB = member_offsets(g, r['Models'][3], ['MeshBindings'])[0]
        mbs = B.alloc(0, bytes(P * len(all_meshes)))
        for i, tp in enumerate(all_meshes): B.ptr(0, mbs + i * P, tp)
        B.i32(model_loc[0], model_loc[1] + MODEL_MB, len(all_meshes)); B.repoint(model_loc[0], model_loc[1] + MODEL_MB + 4, (0, mbs))
    B.write(outp)
    for n, nv, nt in report: print(f'   {n:32} verts={nv:6d} tris={nt:6d}')
    g2 = Gr2(outp); r2 = g2.root()
    print(f'wrote {outp}: crc ok {g2.crc_check()}, meshes {r2["Meshes"][1]}, topologies {r2["TriTopologies"][1]}, vertexdatas {r2["VertexDatas"][1]}, sections',
          [(i, s_["data_size"]) for i, s_ in enumerate(g2.sections) if s_["data_size"]])


if __name__ == '__main__':
    main()
