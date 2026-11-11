"""Packed mesh append regression: conversion metadata and bone-local bounds (INC-290)."""
from pathlib import Path
import struct
import sys

import numpy as np
import pytest

HAVOK = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HAVOK))
sys.path.insert(0, str(HAVOK.parents[1] / '.claude/skills/aoe3de-anim-viewer/tests'))
import gr2_synth as G
from gr2_appendmesh import append, mesh_arrays
from gr2_dump import refs
from gr2_fixups import orphan_fixups
from gr2_read import Gr2


def model(path, skinned):
    byte_name = 'BoneIndices' if skinned else 'BasicStaticPackedData0'
    members = [('Position', 'real32', 3), ('Normal', 'binormal_int8', 3),
               (byte_name, 'uint8', 1), ('Tangent', 'binormal_int8', 3),
               ('BasicStaticPackedData1', 'uint8', 1), ('TextureCoordinates0', 'real16', 2)]
    columns = {'Position': [[10, 20, 30], [11, 20, 30], [10, 21, 30]],
               'Normal': [[0, 0, 127]] * 3, byte_name: [[0]] * 3,
               'Tangent': [[127, 0, 0]] * 3, 'BasicStaticPackedData1': [[0]] * 3,
               'TextureCoordinates0': [[0.1, 0.2], [0.3, 0.2], [0.1, 0.4]]}
    path.write_bytes(G.build_model(
        [dict(name='root', parent=-1, transform=G.transform(flags=0)),
         dict(name='part', parent=0, transform=G.transform(position=(10, 20, 30)))],
        [dict(name='body', members=members, columns=columns, indices=[0, 1, 2],
              groups=[(0, 0, 1)], materials=['body_mat'], bone_names=['root'])]))


@pytest.mark.parametrize('skinned', [False, True])
def test_append_preserves_source_and_registers_packed_array(tmp_path, skinned):
    target, source, out = [tmp_path / f'{n}.gr2' for n in ('target', 'source', 'out')]
    model(target, skinned); model(source, False)
    original = target.read_bytes()
    append(target, source, out, 'prop_mat', 'part', 'prop')
    assert target.read_bytes() == original
    before, after = Gr2(str(target)), Gr2(str(out))
    assert after.crc_check() and not orphan_fixups(str(out))['orphans']
    old = refs(before, before.root()['Meshes'])[0][0]
    meshes = refs(after, after.root()['Meshes'])
    assert len(meshes) == 2
    old_arrays, retained = mesh_arrays(before, old), mesh_arrays(after, meshes[0][0])
    assert old_arrays[2] == retained[2]
    np.testing.assert_array_equal(old_arrays[5], retained[5])
    added = meshes[1][0]
    va = mesh_arrays(after, added)[1]
    vsec, voff = va[3]
    section = after.sections[vsec]
    blob = out.read_bytes()
    records = [struct.unpack_from('<4I', blob, section['marsh_off'] + 16 * i)
               for i in range(section['marsh_count'])]
    assert records.count((3, voff, *va[1])) == 1
    binding = after.array(added['BoneBindings'])[0]
    assert binding['BoneName'] == 'part'
    np.testing.assert_allclose(binding['OBBMin'], [0, 0, 0], atol=1e-6)
    np.testing.assert_allclose(binding['OBBMax'], [1, 1, 0], atol=1e-6)
