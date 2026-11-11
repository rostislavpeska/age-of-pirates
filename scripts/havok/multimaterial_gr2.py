"""Bounded append-only r58 candidate writer. No Blender, deployment, HKT mutation or donor rebuilding.

Input parts have material, bone, vertices [{p,n,uv, optional weights}], triangle faces.
p/n are already in the accepted raw engine frame; split vertices at EVERY loop UV/normal seam.
One rigid donor body owns each part. Non-rigid weights are rejected, never silently collapsed.
Material keys map to {runtime_name, resource_class}; classes own/shared_mod/vanilla are descriptive
and must separately pass the texture-budget/material lint. Preserve accepted r03 HKT verbatim.

Provenance: the r62/r71 writer of the Korean TC/Barracks/Stable exports, until 2026-10-09 only in unversioned work
folders (C:/work/... copies, sha256 edc5a38b6505987e48b37597dd8bb9418ca127de71130e6b6422ce09faa7ae4d). Versioned
here with one fix (INC-187): the root arrays and Model.MeshBindings it re-points to new arrays keep NO pointer fixups in
their old place. Those orphan fixups made the game's granny2_age3de.dll convert every output out of bounds
(layout-dependent bytes, 0xC0000005 crashes) while single DLL runs passed. The output must have zero orphan fixups
(gr2_fixups.py); a donor that already has some is refused - scrub it first.
"""
from collections import defaultdict
from pathlib import Path
import hashlib
import re
import struct
import sys
import zlib

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gr2_fixups import orphan_fixups
from gr2_read import Gr2
from gr2_dump import refs
from gr2_splitmesh import Builder, member_offsets
from gr2_editmesh import retangent, i8, pack
from gr2_lint import read_raw
from gr2_uv_convention import blender_to_gr2_uv


def validate_tangent_basis(material):
    basis=material.get('tangent_basis','uv_derivative')
    if basis not in ('uv_derivative','negate_t_and_b'):
        raise ValueError('unrecognized tangent basis')
    if basis=='negate_t_and_b':
        evidence=material.get('tangent_basis_evidence',{})
        path=Path(evidence.get('path',''))
        if (material.get('resource_class')!='shared_mod' or not path.is_file()
                or hashlib.sha256(path.read_bytes()).hexdigest()!=evidence.get('sha256')):
            raise ValueError('shared normal tangent compensation requires pinned evidence')
    return basis


def apply_tangent_basis(tangent, material):
    """Opposite normal-map XY conventions need -T/-B with unchanged handedness.

    B = handedness * cross(N,T); flipping T while preserving the fourth packed
    component therefore flips B as well. Never change UV or geometric normal.
    """
    result=tangent.copy()
    if validate_tangent_basis(material)=='negate_t_and_b':
        result[:,:3]=(-result[:,:3].astype(np.int16)).astype(np.int8)
    return result


def partition(parts, materials, bones, damaged, max_vertices=65535, max_bones=256):
    if not 3 <= max_vertices <= 65535 or not 1 <= max_bones <= 256:
        raise ValueError('unsafe mesh limits')
    batches, pending = [], {}
    for part in parts:
        key, bone = part.get('material'), part.get('bone')
        if key not in materials or bone not in bones:
            raise ValueError(f'unknown material or donor bone: {key}, {bone}')
        verts, faces = part.get('vertices'), part.get('faces')
        if not verts or not faces:
            raise ValueError('empty part')
        for v in verts:
            for field, n in [('p', 3), ('n', 3), ('uv', 2)]:
                if len(v.get(field, [])) != n or not np.isfinite(v[field]).all():
                    raise ValueError(f'incomplete/nonfinite {field}')
            if np.linalg.norm(v['n']) < 1e-8 or max(abs(x) for x in v['uv']) > 65504:
                raise ValueError('zero normal or UV outside packed half-float range')
            if 'weights' in v and v['weights'] not in ([[bone, 1]], [[bone, 1.0]]):
                raise ValueError('donor layout requires exactly one unit-weight body per vertex')
        # Static layouts have no vertex BoneIndices: each mesh is also partitioned by bone.
        batchkey = (key, None if damaged else bone)
        for face in faces:
            if len(face) != 3 or any(type(i) is not int or i < 0 or i >= len(verts) for i in face):
                raise ValueError('faces must contain three valid integer indices')
            batch = pending.get(batchkey)
            # Per-part identity retains distinct loop corners even at identical positions.
            ids = [(id(part), i) for i in face]
            needed = sum(i not in batch['lookup'] for i in set(ids)) if batch else 3
            if (batch is None or len(batch['vertices']) + needed > max_vertices
                    or (bone not in batch['bones'] and len(batch['bones']) >= max_bones)):
                batch = dict(material=key, vertices=[], faces=[], bone_indices=[], bones=[], lookup={})
                batches.append(batch)
                pending[batchkey] = batch
            if bone not in batch['bones']:
                batch['bones'].append(bone)
            f = []
            for vi, ident in zip(face, ids):
                if ident not in batch['lookup']:
                    batch['lookup'][ident] = len(batch['vertices'])
                    batch['vertices'].append(verts[vi])
                    batch['bone_indices'].append(batch['bones'].index(bone))
                f.append(batch['lookup'][ident])
            batch['faces'].append(f)
    if not batches:
        raise ValueError('no geometry')
    return batches


def replace(donor, parts, out, materials, *, damaged=False, max_vertices=65535, max_bones=256):
    donor, out = Path(donor), Path(out)
    if out.exists() or out.resolve() == donor.resolve():
        raise ValueError('candidate output must be new; donor overwrite prohibited')
    g = Gr2(donor)
    if g.ptr != 8 or not g.crc_check():
        raise ValueError('requires valid 64-bit uncompressed accepted donor')
    donor_orphans = orphan_fixups(donor)['orphans']
    if donor_orphans:
        raise ValueError(f'donor has {len(donor_orphans)} orphan pointer fixups (INC-187): '
                         'python scripts/havok/gr2_fixups.py --scrub DONOR CLEAN, then use CLEAN')
    root = g.root()
    if len(refs(g, root['Models'])) != 1 or len(refs(g, root['Skeletons'])) != 1:
        raise ValueError('exactly one accepted donor model/skeleton required')
    bones = {b['Name']: b for b in g.array(refs(g, root['Skeletons'])[0][0]['Bones'])}
    for key, mat in materials.items():
        validate_tangent_basis(mat)
        if (not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]*', mat.get('runtime_name', ''))
                or mat.get('resource_class') not in ('own', 'shared_mod', 'vanilla')):
            raise ValueError(f'invalid explicit material declaration: {key}')
    names = [m['runtime_name'].lower() for m in materials.values()]
    if len(set(names)) != len(names):
        raise ValueError('runtime material names must be distinct')
    batches = partition(parts, materials, bones, damaged, max_vertices, max_bones)
    template, _ = refs(g, root['Meshes'])[0]
    vd = template['PrimaryVertexData']; vr = g.read(*vd[2], *vd[1]); va = vr['Vertices']
    vtype, vsec = va[1], va[3][0]
    top = g.read(*template['PrimaryTopology'][2], *template['PrimaryTopology'][1])
    idx = top['Indices'] if top['Indices'][1] else top['Indices16']; isec = idx[2][0]
    expected = [('Position', 0), ('Normal', 12), ('BoneIndices' if damaged else 'BasicStaticPackedData0', 15),
                ('Tangent', 16), ('BasicSkinnedPackedData1' if damaged else 'BasicStaticPackedData1', 19),
                ('TextureCoordinates0', 20)]
    if g.struct_size(*vtype) != 24 or [(m['name'], o) for m, o in g.layout(*vtype)[0]] != expected:
        raise ValueError('unproven donor vertex layout/stage')
    # Native stress: the r03 section-5 shortcut crashes 64->32 conversion once
    # damaged Barracks is split to eight meshes. Section 0 is the donor metadata
    # section and passes both small and full-size native conversion fixtures.
    meta = 0
    if meta >= g.sec_count:
        raise ValueError('unproven donor metadata section')
    B = Builder(g)
    B.string = lambda text: (meta, B.alloc(meta, text.encode() + b'\0', 1))
    appended = defaultdict(list)
    material_ptrs = {}
    original_materials = refs(g, root['Materials'])
    matrec, matloc = original_materials[0]
    matsize = g.struct_size(*root['Materials'][3])
    nameoff = member_offsets(g, root['Materials'][3], ['Name'])[0]
    for serial, batch in enumerate(batches):
        key = batch['material']
        # Clone ALL material pointers, not merely the string. Root resource arrays remain intact.
        off = B.alloc(meta, bytes(g.payload[matloc[0]][matloc[1]:matloc[1] + matsize]))
        for so, ts, to in list(B.relocs[matloc[0]]):
            if matloc[1] <= so < matloc[1] + matsize:
                B.ptr(meta, off + so - matloc[1], (ts, to))
        B.repoint(meta, off + nameoff, B.string(materials[key]['runtime_name']))
        maps = matrec['Maps']
        if maps[1]:
            size = g.struct_size(*maps[3]) * maps[1]; loc = maps[2]
            array = B.alloc(meta, bytes(g.payload[loc[0]][loc[1]:loc[1] + size]))
            for so, ts, to in list(B.relocs[loc[0]]):
                if loc[1] <= so < loc[1] + size: B.ptr(meta, array + so - loc[1], (ts, to))
            mapoff = member_offsets(g, root['Materials'][3], ['Maps'])[0]
            B.repoint(meta, off + mapoff + 4, (meta, array))
        material_ptrs[serial] = (meta, off)
        appended['Materials'].append((meta, off))
    records, marsh = [], []
    for serial, batch in enumerate(batches):
        p = np.asarray([v['p'] for v in batch['vertices']], dtype=float)
        n = np.asarray([v['n'] for v in batch['vertices']], dtype=float)
        uv = blender_to_gr2_uv([v['uv'] for v in batch['vertices']])
        n /= np.linalg.norm(n, axis=1)[:, None]
        tri = np.asarray(batch['faces'], dtype='<i4')
        bi = np.asarray(batch['bone_indices'], dtype=np.uint8)
        nr = np.zeros((len(p), 4), dtype=np.int8); nr[:, :3] = i8(n * 127)
        tn = retangent(p, nr, np.zeros_like(nr), uv, tri)
        for i in np.where(np.linalg.norm(tn[:, :3].astype(float), axis=1) < .5)[0]:
            axis = np.eye(3)[np.argmin(abs(n[i]))]; tangent = np.cross(n[i], axis)
            tn[i, :3] = i8(tangent / np.linalg.norm(tangent) * 127); tn[i, 3] = -128
        tn=apply_tangent_basis(tn,materials[batch['material']])
        raw = pack(np.zeros((len(p), 24), dtype=np.uint8), p, nr, tn, uv)
        if damaged: raw[:, 15] = bi
        vo, io = B.alloc(vsec, raw.tobytes()), B.alloc(isec, tri.tobytes())
        marsh.append((len(p), vo, *vtype))
        vdo = B.alloc(meta, bytes(44)); B.ptr(meta, vdo, vtype)
        B.i32(meta, vdo + 8, len(p)); B.ptr(meta, vdo + 12, (vsec, vo))
        # Native 64->32 conversion has historically failed with aliased component-name arrays.
        vcn = vr['VertexComponentNames']; vcn_array = B.alloc(meta, bytes(8 * vcn[1]))
        for i in range(vcn[1]): B.ptr(meta, vcn_array + 8 * i, g.deref(vcn[2][0], vcn[2][1] + 8 * i))
        B.i32(meta, vdo + 20, vcn[1]); B.ptr(meta, vdo + 24, (meta, vcn_array))
        group = B.alloc(meta, struct.pack('<3i', 0, 0, len(tri)))
        tpo = B.alloc(meta, bytes(132)); B.i32(meta, tpo, 1); B.ptr(meta, tpo + 4, (meta, group))
        B.i32(meta, tpo + 12, 3 * len(tri)); B.ptr(meta, tpo + 16, (isec, io))
        bbo = B.alloc(meta, bytes(44 * len(batch['bones'])))
        for i, bone in enumerate(batch['bones']):
            sub = p[bi == i]; inverse = np.asarray(bones[bone]['InverseWorldTransform']).reshape(4, 4)
            local = (np.c_[sub, np.ones(len(sub))] @ inverse)[:, :3]
            off = bbo + i * 44; B.ptr(meta, off, B.string(bone))
            struct.pack_into('<6f', B.sec[meta], off + 8, *local.min(0), *local.max(0))
        mb = B.alloc(meta, bytes(8)); B.ptr(meta, mb, material_ptrs[serial])
        mo = B.alloc(meta, bytes(76)); B.ptr(meta, mo, B.string(f'r58_{batch["material"]}_{serial}'))
        B.ptr(meta, mo + 8, (meta, vdo)); B.ptr(meta, mo + 28, (meta, tpo))
        B.i32(meta, mo + 36, 1); B.ptr(meta, mo + 40, (meta, mb))
        B.i32(meta, mo + 48, len(batch['bones'])); B.ptr(meta, mo + 52, (meta, bbo))
        ext = template['ExtendedData']
        if ext and ext[0] == 'variant' and ext[1] and ext[2]:
            esz = g.struct_size(*ext[1]); eloc = ext[2]
            eo = B.alloc(meta, bytes(g.payload[eloc[0]][eloc[1]:eloc[1] + esz]))
            for so, ts, to in list(B.relocs[eloc[0]]):
                if eloc[1] <= so < eloc[1] + esz: B.ptr(meta, eo + so - eloc[1], (ts, to))
            B.ptr(meta, mo + 60, ext[1]); B.ptr(meta, mo + 68, (meta, eo))
        for key, off in [('Meshes', mo), ('VertexDatas', vdo), ('TriTopologies', tpo)]:
            appended[key].append((meta, off))
        records.append(dict(material=batch['material'], runtime_name=materials[batch['material']]['runtime_name'],
                            tangent_basis=materials[batch['material']].get('tangent_basis','uv_derivative'),
                            tangent_basis_evidence=materials[batch['material']].get('tangent_basis_evidence'),
                            resource_class=materials[batch['material']]['resource_class'], vertices=len(p),
                            triangles=len(tri), bones=batch['bones'], max_uv_half_error=float(abs(uv - uv.astype('<f2')).max())))
    def orphan(loc, nbytes):
        """the array a re-point replaces: drop its pointer fixups and zero it (INC-187)"""
        if loc and nbytes:
            s, o = loc
            B.relocs[s] = [x for x in B.relocs[s] if not (o <= x[0] < o + nbytes)]
            B.sec[s][o:o + nbytes] = bytes(nbytes)
    for key, pointers in appended.items():
        old = [loc for _, loc in refs(g, root[key])]; allptrs = old + pointers
        off = member_offsets(g, (g.root_type_sec, g.root_type_off), [key])[0]
        array = B.alloc(meta, bytes(8 * len(allptrs)))
        for i, ptr in enumerate(allptrs): B.ptr(meta, array + 8 * i, ptr)
        B.i32(g.root_sec, g.root_off + off, len(allptrs)); B.repoint(g.root_sec, g.root_off + off + 4, (meta, array))
        orphan(root[key][2], 8 * root[key][1])
    model, model_loc = refs(g, root['Models'])[0]
    off = member_offsets(g, root['Models'][3], ['MeshBindings'])[0]
    array = B.alloc(meta, bytes(8 * len(batches)))
    for i, ptr in enumerate(appended['Meshes']): B.ptr(meta, array + 8 * i, ptr)
    B.i32(model_loc[0], model_loc[1] + off, len(batches)); B.repoint(model_loc[0], model_loc[1] + off + 4, (meta, array))
    mbind = model['MeshBindings']
    orphan(mbind[2], mbind[1] * (g.struct_size(*mbind[3]) if mbind[3] else 8))
    out.parent.mkdir(parents=True, exist_ok=True)
    B.write(out)
    # Each appended packed vertex array needs its own native conversion marshalling record.
    packed = bytearray(out.read_bytes()); temp = Gr2(out); sec = temp.sections[vsec]
    prior = packed[sec['marsh_off']:sec['marsh_off'] + 16 * sec['marsh_count']]; offset = len(packed)
    packed.extend(prior + b''.join(struct.pack('<4I', *entry) for entry in marsh))
    struct.pack_into('<II', packed, temp.sec_table + 44 * vsec + 36, offset, sec['marsh_count'] + len(marsh))
    struct.pack_into('<I', packed, 36, len(packed)); struct.pack_into('<I', packed, 40, zlib.crc32(packed[temp.sec_table:]) & 0xffffffff)
    out.write_bytes(packed)
    decoded = read_raw(out)
    assert Gr2(out).crc_check() and len(decoded['render']) == len(batches)
    left = orphan_fixups(out)['orphans']
    assert not left, f'{len(left)} orphan pointer fixups in the output (INC-187): {left[:5]}'
    for mesh, batch in zip(decoded['render'], batches):
        assert mesh['mats'] == [materials[batch['material']]['runtime_name']]
        assert mesh['bone_names'] == batch['bones']
        assert np.array_equal(mesh['bone'], batch['bone_indices'])
        assert np.array_equal(mesh['tris'], batch['faces'])
        assert np.max(abs(mesh['pos'] - [v['p'] for v in batch['vertices']])) < 1e-5
        assert np.array_equal(mesh['uv'], blender_to_gr2_uv([v['uv'] for v in batch['vertices']]).astype('<f2').astype(float))
    return dict(path=str(out), sha256=hashlib.sha256(out.read_bytes()).hexdigest(),
                donor=str(donor), donor_sha256=hashlib.sha256(donor.read_bytes()).hexdigest(),
                meshes=records, material_partitions=len({b['material'] for b in batches}), native_dll_read='REQUIRED',
                physics='No HKT or existing skeleton/rest/attachment bytes modified',
                status='scratch candidate; not deployed or game tested')
