"""gr2_editmesh new meshes: native conversion metadata, no orphan fixups, multi-material source, existing material
(Korean HC lanterns 2026-10-17: the output converted under Wine but crashed the native DLL - INC-290 / INC-187)."""
from pathlib import Path
import json
import struct
import subprocess
import sys

import numpy as np

HAVOK = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HAVOK))
sys.path.insert(0, str(HAVOK.parents[1] / '.claude/skills/aoe3de-anim-viewer/tests'))
import gr2_synth as G
from gr2_appendmesh import mesh_arrays
from gr2_dump import refs
from gr2_fixups import orphan_fixups
from gr2_read import Gr2


def model(path):
    members = [('Position', 'real32', 3), ('Normal', 'binormal_int8', 3), ('BasicStaticPackedData0', 'uint8', 1),
               ('Tangent', 'binormal_int8', 3), ('BasicStaticPackedData1', 'uint8', 1), ('TextureCoordinates0', 'real16', 2)]
    columns = {'Position': [[10, 20, 30], [11, 20, 30], [10, 21, 30], [11, 21, 30]],
               'Normal': [[0, 0, 127]] * 4, 'BasicStaticPackedData0': [[0]] * 4,
               'Tangent': [[127, 0, 0]] * 4, 'BasicStaticPackedData1': [[0]] * 4,
               'TextureCoordinates0': [[0.1, 0.2], [0.3, 0.2], [0.1, 0.4], [0.3, 0.4]]}
    path.write_bytes(G.build_model(
        [dict(name='root', parent=-1, transform=G.transform(flags=0))],
        [dict(name='body', members=members, columns=columns, indices=[0, 1, 2, 1, 3, 2],
              groups=[(0, 0, 1), (1, 1, 1)], materials=['mat_a', 'mat_b'], bone_names=['root'])]))


def test_new_mesh_on_multimaterial_source_registers_array_and_leaves_no_orphans(tmp_path):
    src, plan, out = tmp_path / 'src.gr2', tmp_path / 'plan.json', tmp_path / 'out.gr2'
    model(src)
    plan.write_text(json.dumps({'mesh': 'body', 'reset_root': False, 'new': [{
        'name': 'added', 'bone': 'root', 'use_material': 'mat_b',
        'extra_verts': [{'src': 0, 'pos': [0, 0, 0], 'uv': [0, 0], 'nrm': [0, 1, 0]},
                        {'src': 0, 'pos': [1, 0, 0], 'uv': [1, 0], 'nrm': [0, 1, 0]},
                        {'src': 0, 'pos': [0, 0, 1], 'uv': [0, 1], 'nrm': [0, 1, 0]}],
        'extra_tris': [[0, 1, 2]]}]}))
    r = subprocess.run([sys.executable, str(HAVOK / 'gr2_editmesh.py'), str(src), str(plan), str(out)],
                       capture_output=True, text=True, cwd=str(HAVOK))
    assert r.returncode == 0, r.stdout + r.stderr
    before, after = Gr2(str(src)), Gr2(str(out))
    assert after.crc_check() and not orphan_fixups(str(out))['orphans']
    meshes = {m['Name']: m for m, _ in refs(after, after.root()['Meshes'])}
    old = {m['Name']: m for m, _ in refs(before, before.root()['Meshes'])}['body']
    np.testing.assert_array_equal(mesh_arrays(before, old)[5], mesh_arrays(after, meshes['body'])[5])
    va = mesh_arrays(after, meshes['added'])[1]
    vsec, voff = va[3]
    section = after.sections[vsec]; blob = out.read_bytes()
    records = [struct.unpack_from('<4I', blob, section['marsh_off'] + 16 * i) for i in range(section['marsh_count'])]
    assert records.count((3, voff, *va[1])) == 1
    mats = {rec['Name']: tuple(loc) for rec, loc in refs(after, after.root()['Materials'])}
    assert set(mats) == {'mat_a', 'mat_b'}                     # bound to the existing record, no clone
    mb = meshes['added']['MaterialBindings']
    assert all(after.deref(mb[2][0], mb[2][1] + k * after.struct_size(*mb[3])) == mats['mat_b'] for k in range(mb[1]))
