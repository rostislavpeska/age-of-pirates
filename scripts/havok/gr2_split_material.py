"""Move listed triangles of one mesh into a NEW mesh with its own material and new UVs, in an uncompressed .gr2 (rigid or
skinned): every other mesh, vertex and bone stays as it is. For destruction cut caps put on the vanilla destruction sheet
after the fact (owner 2026-10-11: "Destriction models for the chipped parts (between derbis) use the dedicated destruction
map - same as the Castle model and Dock").

    python gr2_split_material.py IN.gr2 PLAN.json OUT.gr2
    PLAN.json: {"mesh": <index into the model's mesh bindings>, "material": "matz", "name": "<new mesh name>",
                "tris": [t, ...], "uvs": [[[u, v] x3] per listed triangle]}     # raw GR2 UVs (image x/W, y/H)

The new mesh gets 3 vertices per moved triangle: the source vertex bytes (position, normal, bone index @15) with the new UV,
a tangent recomputed from the new UV gradient (orthogonal to the vertex normal) and its handedness sign (byte @19: 128 right,
0 left - as the source). Its bone bindings are a copy of the source mesh's (same order, so the bone indices stay valid); its
material is a clone of the source's under the new name. The source keeps the remaining triangles (compacted in place,
counts updated). Root arrays and the model's mesh bindings gain the new mesh; orphan fixups are scrubbed (INC-187).
"""
import json, struct, sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gr2_read import Gr2                              # noqa: E402
from gr2_dump import refs                             # noqa: E402
from gr2_splitmesh import Builder, member_offsets     # noqa: E402
from gr2_fixups import orphan_fixups, scrub           # noqa: E402

P = 8


def split(src, plan, out):
    g = Gr2(str(src)); assert g.crc_check(); r = g.root(); B = Builder(g)
    fo = lambda sec, off: (sec, off)
    model, model_loc = refs(g, r['Models'])[0]; MODEL_MB = member_offsets(g, r['Models'][3], ['MeshBindings'])[0]
    mbind = model['MeshBindings']; bound = [g.deref(mbind[2][0], mbind[2][1] + i * P) for i in range(mbind[1])]
    meshes = dict(((l[0], l[1]), m) for m, l in refs(g, r['Meshes'])); mloc = bound[plan['mesh']]; m = meshes[mloc]
    vd = m['PrimaryVertexData']; vrec = g.read(*vd[2], *vd[1]); va = vrec['Vertices']
    assert g.struct_size(*va[1]) == 24 and [o for _, o in g.layout(*va[1])[0]] == [0, 12, 15, 16, 19, 20]
    vsec, vbase = va[3]; raw = np.frombuffer(bytes(g.payload[vsec][vbase:vbase + 24 * va[2]]), np.uint8).reshape(-1, 24)
    tt = m['PrimaryTopology']; top = g.read(*tt[2], *tt[1]); idx = top['Indices']; assert top['Indices16'][1] == 0
    isec, ibase = idx[2]; T = np.frombuffer(bytes(g.payload[isec][ibase:ibase + 4 * idx[1]]), '<i4').reshape(-1, 3)
    groups = g.array(top['Groups']); assert len(groups) == 1, 'single-group meshes only'
    S = np.array(sorted(set(plan['tris'])), int); uvs = np.asarray(plan['uvs'], float).reshape(-1, 3, 2)
    order = np.argsort(np.asarray(plan['tris'])); uvs = uvs[order]; assert len(S) == len(uvs) == len(plan['tris'])
    # new vertices: 3 per moved triangle
    pos = raw[:, 0:12].copy().view('<f4').reshape(-1, 3).astype(float); nrm = raw[:, 12:15].view(np.int8).astype(float) / 127.
    nv = []; ntris = []
    for k, t in enumerate(T[S]):
        p = pos[t]; uv = uvs[k]
        e1, e2 = p[1] - p[0], p[2] - p[0]; d1, d2 = uv[1] - uv[0], uv[2] - uv[0]
        det = d1[0] * d2[1] - d2[0] * d1[1]
        if abs(det) < 1e-12: tu, tv = e1, np.cross(np.cross(e1, e2), e1)
        else: tu = (e1 * d2[1] - e2 * d1[1]) / det; tv = (e2 * d1[0] - e1 * d2[0]) / det
        base = len(nv)
        for c in range(3):
            b = raw[t[c]].copy(); n = nrm[t[c]]; tg = tu - n * (n @ tu); tg /= np.linalg.norm(tg) + 1e-12
            b[16:19] = np.clip(np.rint(tg * 127), -127, 127).astype(np.int8).view(np.uint8)
            b[19] = 128 if np.dot(np.cross(n, tg), tv) >= 0 else 0
            b[20:24] = np.array(uv[c], '<f2').view(np.uint8); nv.append(b)
        ntris.append([base, base + 1, base + 2])
    nv = np.array(nv, np.uint8); ntris = np.array(ntris, '<i4')
    # 1. source: remaining triangles compacted in place, counts updated
    keep = np.setdiff1d(np.arange(len(T)), S)
    B.sec[isec][ibase:ibase + 4 * idx[1]] = T[keep].astype('<i4').tobytes() + bytes(4 * 3 * len(S))
    lay = {mm['name']: off for mm, off in g.layout(*tt[2])[0]}
    B.i32(tt[1][0], tt[1][1] + lay['Indices'], 3 * len(keep))
    gsec, goff = top['Groups'][2]; mi, tf, tc = struct.unpack_from('<3i', B.sec[gsec], goff); struct.pack_into('<3i', B.sec[gsec], goff, mi, 0, len(keep))
    # 2. new vertex data / topology
    voff = B.alloc(vsec, nv.tobytes(), 4)
    vdo = B.alloc(0, bytes(44)); B.ptr(0, vdo, va[1]); B.i32(0, vdo + 8, len(nv)); B.ptr(0, vdo + 12, (vsec, voff))
    vcn = vrec['VertexComponentNames']; vcn_arr = B.alloc(0, bytes(P * max(vcn[1], 1)))
    for k in range(vcn[1]): B.ptr(0, vcn_arr + k * P, g.deref(vcn[2][0], vcn[2][1] + k * P))
    B.i32(0, vdo + 20, vcn[1]); B.ptr(0, vdo + 24, (0, vcn_arr))
    ioff = B.alloc(isec, ntris.tobytes(), 4); grp = B.alloc(0, struct.pack('<3i', 0, 0, len(ntris)))
    tpo = B.alloc(0, bytes(132)); B.i32(0, tpo, 1); B.ptr(0, tpo + 4, (0, grp)); B.i32(0, tpo + 12, 3 * len(ntris)); B.ptr(0, tpo + 16, (isec, ioff))
    # 3. bone bindings: a copy of the source's (names re-pointed, OBBs copied, triangle index arrays dropped)
    bb = m['BoneBindings']; bsz = g.struct_size(*bb[3]); blay = {mm['name']: off for mm, off in g.layout(*bb[3])[0]}
    assert bsz == 44 and blay == {'BoneName': 0, 'OBBMin': 8, 'OBBMax': 20, 'TriangleIndices': 32}
    barr = B.alloc(0, bytes(bsz * bb[1]))
    for k in range(bb[1]):
        so = bb[2][1] + k * bsz
        B.sec[0][barr + k * bsz + 8:barr + k * bsz + 32] = g.payload[bb[2][0]][so + 8:so + 32]
        B.ptr(0, barr + k * bsz, g.deref(bb[2][0], so))
    # 4. material clone under the new name
    mat_t = r['Materials'][3]; mbs = m['MaterialBindings']; src_mat = g.deref(mbs[2][0], mbs[2][1]); srec = g.read(*mat_t, *src_mat); maps = srec['Maps']
    msz = g.struct_size(*maps[3]) if maps[1] else 0; marr = B.alloc(0, bytes(max(msz * maps[1], P)))
    for k in range(maps[1]):
        for m_, off_ in g.layout(*maps[3])[0]:
            B.ptr(0, marr + k * msz + off_, g.deref(maps[2][0], maps[2][1] + k * msz + off_))
    mo = B.alloc(0, bytes(44)); B.ptr(0, mo, B.string(plan['material'])); B.i32(0, mo + 8, maps[1]); B.ptr(0, mo + 12, (0, marr))
    # 5. mesh record
    me = B.alloc(0, bytes(76)); B.ptr(0, me, B.string(plan.get('name', 'split'))); B.ptr(0, me + 8, (0, vdo)); B.ptr(0, me + 28, (0, tpo))
    mb_size = g.struct_size(*mbs[3]); mb_arr = B.alloc(0, bytes(mb_size))
    for m_, off_ in g.layout(*mbs[3])[0]:
        if m_['name'] == 'Material': B.ptr(0, mb_arr + off_, (0, mo))
    B.i32(0, me + 36, 1); B.ptr(0, me + 40, (0, mb_arr)); B.i32(0, me + 48, bb[1]); B.ptr(0, me + 52, (0, barr))
    ext = m['ExtendedData']
    if ext and ext[0] == 'variant' and ext[1]:
        esz = g.struct_size(*ext[1]); eo = B.alloc(0, bytes(g.payload[ext[2][0]][ext[2][1]:ext[2][1] + esz])); B.ptr(0, me + 60, ext[1]); B.ptr(0, me + 68, (0, eo))

    def refarray(field_sec, field_off, old, new_ptrs):
        ptrs = [g.deref(old[2][0], old[2][1] + i * P) for i in range(old[1])] + new_ptrs
        arr = B.alloc(0, bytes(P * len(ptrs)))
        for i, tp in enumerate(ptrs): B.ptr(0, arr + i * P, tp)
        B.i32(field_sec, field_off, len(ptrs)); B.repoint(field_sec, field_off + 4, (0, arr))
    RM, RT, RV, RMAT = member_offsets(g, (g.root_type_sec, g.root_type_off), ['Meshes', 'TriTopologies', 'VertexDatas', 'Materials'])
    refarray(g.root_sec, g.root_off + RMAT, r['Materials'], [(0, mo)]); refarray(g.root_sec, g.root_off + RM, r['Meshes'], [(0, me)])
    refarray(g.root_sec, g.root_off + RT, r['TriTopologies'], [(0, tpo)]); refarray(g.root_sec, g.root_off + RV, r['VertexDatas'], [(0, vdo)])
    nb = bound + [(0, me)]; mbs_arr = B.alloc(0, bytes(P * len(nb)))
    for i, tp in enumerate(nb): B.ptr(0, mbs_arr + i * P, tp)
    B.i32(model_loc[0], model_loc[1] + MODEL_MB, len(nb)); B.repoint(model_loc[0], model_loc[1] + MODEL_MB + 4, (0, mbs_arr))
    B.write(str(out))
    if orphan_fixups(str(out))['orphans']:
        tmp = str(out) + '.tmp'; Path(out).replace(tmp); scrub(tmp, str(out)); Path(tmp).unlink()
    assert not orphan_fixups(str(out))['orphans']
    return dict(moved=len(S), source_tris_after=len(keep), new_vertices=len(nv))


if __name__ == '__main__':
    src, planp, out = sys.argv[1:4]
    rep = split(src, json.loads(Path(planp).read_text()), out); print('SPLIT', json.dumps(rep), 'crc', Gr2(out).crc_check())
