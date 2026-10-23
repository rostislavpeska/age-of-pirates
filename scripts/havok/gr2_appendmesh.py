"""Append ONE mesh (taken from another .gr2) to a model's existing mesh bindings, with its own material record and one bone
binding; every existing mesh, vertex, material and bone stays as it is. For owned props embedded directly in a building
(owner 2026-10-11, Korean TC: "Thhe oprops are ours, why you can't add them directly?", "I mean why use attachments?").

    python gr2_appendmesh.py TARGET.gr2 SOURCE.gr2 OUT.gr2 --material matd --bone base [--mesh-name korean_tc_props]

SOURCE: a model whose first rendered mesh is the geometry to add, in the TARGET's frame (e.g. exported by the project writer).
Both use the 24-byte vertex (Position real32x3 @0, Normal int8x3 @12, byte @15, Tangent int8x3 @16, byte @19, UV real16x2
@20). The new vertex data reuses the TARGET's vertex type: for a skinned target the byte @15 is the bone index into the new
mesh's single bone binding, so it is set to 0 (= --bone); for a rigid target it is the static packed byte and is kept.
Unlike gr2_editmesh (which binds every root mesh to the model), only the model's CURRENT mesh bindings plus the new mesh are
bound - unbound donor leftovers in the root Meshes array stay unbound. The new material record is a clone of the first bound
mesh's material under --material (its maps are shared), so the .material file gives it its own textures.
"""
import argparse, struct, sys
from pathlib import Path
import numpy as np
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gr2_read import Gr2                              # noqa: E402
from gr2_dump import refs                             # noqa: E402
from gr2_splitmesh import Builder, member_offsets     # noqa: E402

P = 8
LAYOUT = [0, 12, 15, 16, 19, 20]


def mesh_arrays(g, mrec):
    vd = mrec['PrimaryVertexData']; vrec = g.read(*vd[2], *vd[1]); va = vrec['Vertices']
    assert g.struct_size(*va[1]) == 24 and [o for _, o in g.layout(*va[1])[0]] == LAYOUT, 'unsupported vertex layout'
    vsec, vbase = va[3]; raw = bytes(g.payload[vsec][vbase:vbase + 24 * va[2]])
    tt = mrec['PrimaryTopology']; top = g.read(*tt[2], *tt[1]); idx = top['Indices']
    assert idx[1] and top['Indices16'][1] == 0, '32-bit indices only'
    isec, ibase = idx[2]; tris = np.frombuffer(bytes(g.payload[isec][ibase:ibase + 4 * idx[1]]), '<i4').reshape(-1, 3)
    return vrec, va, raw, tt, top, tris


def append(target, source, out, material, bone, name):
    g = Gr2(str(target)); assert g.crc_check(); r = g.root(); B = Builder(g)
    s = Gr2(str(source)); sr = s.root()
    # the source model's first BOUND mesh (root Meshes may hold unbound donor leftovers)
    smodel = refs(s, sr['Models'])[0][0]; smbind = smodel['MeshBindings']
    s_ptr0 = s.deref(smbind[2][0], smbind[2][1]); s_meshes = dict(((loc[0], loc[1]), m) for m, loc in refs(s, sr['Meshes']))
    s_bound = [s_meshes[s_ptr0]]
    model, model_loc = refs(g, r['Models'])[0]; MODEL_MB = member_offsets(g, r['Models'][3], ['MeshBindings'])[0]
    mbind = model['MeshBindings']; bound_ptrs = [g.deref(mbind[2][0], mbind[2][1] + i * P) for i in range(mbind[1])]
    meshes = dict(((loc[0], loc[1]), m) for m, loc in refs(g, r['Meshes']))
    tmpl = meshes[bound_ptrs[0]]
    _, tva, _, _, _, _ = mesh_arrays(g, tmpl)
    skinned = any(m['name'] == 'BoneIndices' for m, _ in g.layout(*tva[1])[0])
    src = next(m for m in s_bound)
    _, _, sraw, _, _, stris = mesh_arrays(s, src)
    v = np.frombuffer(sraw, np.uint8).reshape(-1, 24).copy()
    if skinned:
        v[:, 15] = 0                                                         # bone index 0 = the single binding (--bone)
    pos = v[:, 0:12].copy().view('<f4').reshape(-1, 3)
    vsec = tva[3][0]
    voff = B.alloc(vsec, v.tobytes(), 4)
    tvd = tmpl['PrimaryVertexData']; tvrec = g.read(*tvd[2], *tvd[1])
    vdo = B.alloc(0, bytes(44)); B.ptr(0, vdo, tva[1]); B.i32(0, vdo + 8, len(v)); B.ptr(0, vdo + 12, (vsec, voff))
    vcn = tvrec['VertexComponentNames']; vcn_arr = B.alloc(0, bytes(P * max(vcn[1], 1)))
    for k in range(vcn[1]): B.ptr(0, vcn_arr + k * P, g.deref(vcn[2][0], vcn[2][1] + k * P))
    B.i32(0, vdo + 20, vcn[1]); B.ptr(0, vdo + 24, (0, vcn_arr))
    ttop = tmpl['PrimaryTopology']; isec = g.read(*ttop[2], *ttop[1])['Indices'][2][0]
    ioff = B.alloc(isec, stris.astype('<i4').tobytes(), 4)
    grp = B.alloc(0, struct.pack('<3i', 0, 0, len(stris)))
    tpo = B.alloc(0, bytes(132)); B.i32(0, tpo, 1); B.ptr(0, tpo + 4, (0, grp)); B.i32(0, tpo + 12, 3 * len(stris)); B.ptr(0, tpo + 16, (isec, ioff))
    bones = {b['Name']: b for sk, _ in refs(g, r['Skeletons']) for b in g.array(sk['Bones'])}
    assert bone in bones, f'no bone {bone}'
    inverse = np.asarray(bones[bone]['InverseWorldTransform']).reshape(4, 4)
    local = (np.c_[pos, np.ones(len(pos))] @ inverse)[:, :3]
    bbo = B.alloc(0, bytes(44)); B.ptr(0, bbo, B.string(bone)); struct.pack_into('<6f', B.sec[0], bbo + 8, *local.min(0), *local.max(0))
    # material: clone of the template mesh's first material under the new name
    mat_t = r['Materials'][3]
    assert dict(zip(['Name', 'Maps', 'Texture', 'ExtendedData'], member_offsets(g, mat_t, ['Name', 'Maps', 'Texture', 'ExtendedData']))) == {'Name': 0, 'Maps': 8, 'Texture': 20, 'ExtendedData': 28} and g.struct_size(*mat_t) == 44
    tmb = tmpl['MaterialBindings']; src_mat = g.deref(tmb[2][0], tmb[2][1]); srec = g.read(*mat_t, *src_mat); maps = srec['Maps']; msz = g.struct_size(*maps[3]) if maps[1] else 0
    marr = B.alloc(0, bytes(max(msz * maps[1], P)))
    for k in range(maps[1]):
        for m_, off_ in g.layout(*maps[3])[0]:
            B.ptr(0, marr + k * msz + off_, g.deref(maps[2][0], maps[2][1] + k * msz + off_))
    mo = B.alloc(0, bytes(44)); B.ptr(0, mo, B.string(material)); B.i32(0, mo + 8, maps[1]); B.ptr(0, mo + 12, (0, marr))
    mesh_t = r['Meshes'][3]
    assert dict(zip(['Name', 'PrimaryVertexData', 'PrimaryTopology', 'MaterialBindings', 'BoneBindings', 'ExtendedData'],
                    member_offsets(g, mesh_t, ['Name', 'PrimaryVertexData', 'PrimaryTopology', 'MaterialBindings', 'BoneBindings', 'ExtendedData']))) == \
        {'Name': 0, 'PrimaryVertexData': 8, 'PrimaryTopology': 28, 'MaterialBindings': 36, 'BoneBindings': 48, 'ExtendedData': 60}
    me = B.alloc(0, bytes(76)); B.ptr(0, me, B.string(name)); B.ptr(0, me + 8, (0, vdo)); B.ptr(0, me + 28, (0, tpo))
    mb_size = g.struct_size(*tmb[3]); mb_arr = B.alloc(0, bytes(mb_size))
    for m_, off_ in g.layout(*tmb[3])[0]:
        if m_['name'] == 'Material': B.ptr(0, mb_arr + off_, (0, mo))
    B.i32(0, me + 36, 1); B.ptr(0, me + 40, (0, mb_arr)); B.i32(0, me + 48, 1); B.ptr(0, me + 52, (0, bbo))
    ext = tmpl['ExtendedData']
    if ext and ext[0] == 'variant' and ext[1]:
        esz = g.struct_size(*ext[1]); eo = B.alloc(0, bytes(g.payload[ext[2][0]][ext[2][1]:ext[2][1] + esz])); B.ptr(0, me + 60, ext[1]); B.ptr(0, me + 68, (0, eo))

    def refarray(field_sec, field_off, old, new_ptrs):
        ptrs = [g.deref(old[2][0], old[2][1] + i * P) for i in range(old[1])] + new_ptrs
        arr = B.alloc(0, bytes(P * len(ptrs)))
        for i, tp in enumerate(ptrs): B.ptr(0, arr + i * P, tp)
        B.i32(field_sec, field_off, len(ptrs))
        if g.deref(field_sec, field_off + 4) is None:
            B.ptr(field_sec, field_off + 4, (0, arr))
        else:
            B.repoint(field_sec, field_off + 4, (0, arr))
    RM, RT, RV, RMAT = member_offsets(g, (g.root_type_sec, g.root_type_off), ['Meshes', 'TriTopologies', 'VertexDatas', 'Materials'])
    refarray(g.root_sec, g.root_off + RMAT, r['Materials'], [(0, mo)])
    refarray(g.root_sec, g.root_off + RM, r['Meshes'], [(0, me)])
    refarray(g.root_sec, g.root_off + RT, r['TriTopologies'], [(0, tpo)])
    refarray(g.root_sec, g.root_off + RV, r['VertexDatas'], [(0, vdo)])
    new_bound = bound_ptrs + [(0, me)]; mbs = B.alloc(0, bytes(P * len(new_bound)))
    for i, tp in enumerate(new_bound): B.ptr(0, mbs + i * P, tp)
    B.i32(model_loc[0], model_loc[1] + MODEL_MB, len(new_bound)); B.repoint(model_loc[0], model_loc[1] + MODEL_MB + 4, (0, mbs))
    B.write(str(out))
    # Granny's native 64->32 conversion needs a marshalling record for the new
    # packed vertex array, even when every pointer fixup is reachable (INC-290).
    # Without it Wine can succeed while native layouts crash or read past data.
    packed = bytearray(Path(out).read_bytes()); temp = Gr2(str(out)); section = temp.sections[vsec]
    prior = packed[section['marsh_off']:section['marsh_off'] + 16 * section['marsh_count']]
    offset = len(packed)
    packed.extend(prior + struct.pack('<4I', len(v), voff, *tva[1]))
    struct.pack_into('<II', packed, temp.sec_table + 44 * vsec + 36, offset, section['marsh_count'] + 1)
    struct.pack_into('<I', packed, 36, len(packed))
    struct.pack_into('<I', packed, 40, zlib.crc32(packed[temp.sec_table:]) & 0xffffffff)
    Path(out).write_bytes(packed)
    # re-pointed root arrays leave their old arrays' fixups behind: orphans crash / mis-convert in the game's 32-bit DLL
    # (INC-187) - scrub them, every reachable byte stays identical
    from gr2_fixups import orphan_fixups, scrub
    if orphan_fixups(str(out))['orphans']:
        tmp = str(out) + '.tmp'; Path(out).replace(tmp); scrub(tmp, str(out)); Path(tmp).unlink()
    assert not orphan_fixups(str(out))['orphans'], 'orphan fixups left'
    return dict(skinned=skinned, vertices=len(v), triangles=len(stris), bound_before=len(bound_ptrs), bound_after=len(new_bound))


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('target'); ap.add_argument('source'); ap.add_argument('out')
    ap.add_argument('--material', required=True); ap.add_argument('--bone', required=True); ap.add_argument('--mesh-name', default='appended')
    a = ap.parse_args()
    rep = append(a.target, a.source, a.out, a.material, a.bone, a.mesh_name)
    g2 = Gr2(a.out); print('APPENDED', rep, 'crc', g2.crc_check())
