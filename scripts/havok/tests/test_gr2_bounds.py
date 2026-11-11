"""Bone-binding boxes after in-place edits (2026-10-17, Korean HC docks01: pier, collision mesh and a junk boat moved in
place 83-87 units outside their unchanged boxes, none visible in game).

    python -m pytest scripts/havok/tests/test_gr2_bounds.py -q

Synthetic models built with the anim viewer's Granny writer (.claude/skills/aoe3de-anim-viewer/tests/gr2_synth.py) - no
game bytes. Its boxes are written as zeros, i.e. stale for any geometry: exactly the defect under test.
"""
from __future__ import annotations

import math
import struct
import sys
from pathlib import Path

import numpy as np
import pytest

HAVOK = Path(__file__).resolve().parents[1]
REPO = HAVOK.parents[1]
SYNTH = REPO / '.claude' / 'skills' / 'aoe3de-anim-viewer' / 'tests'
sys.path.insert(0, str(HAVOK))
import gr2_bounds as B  # noqa: E402
import gr2_droptris as D  # noqa: E402
import gr2_lint as L  # noqa: E402
import gr2_rest_anim as A  # noqa: E402
import gr2_rotate_verts as RV  # noqa: E402

POS = np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0], [1, 1, 0], [0, 2, 0], [1, 2, 0]], float)
TRIS = [0, 1, 2, 2, 1, 3, 2, 3, 4, 4, 3, 5]                       # 4 triangles: group 0 = tris 0-1, group 1 = tris 2-3


def synth():
    if not (SYNTH / 'gr2_synth.py').is_file():
        pytest.skip('gr2_synth.py (aoe3de-anim-viewer tests) not found')
    sys.path.insert(0, str(SYNTH))
    import gr2_synth as G
    return G


def model(path, bone_pos=(5, 0, 0)):
    """root + one offset child bone 'b'; a 24-byte vanilla-layout rigid mesh bound to 'b'"""
    G = synth()
    n = len(POS)
    members = [('Position', 'real32', 3), ('Normal', 'binormal_int8', 3), ('BasicStaticPackedData0', 'uint8', 1),
               ('Tangent', 'binormal_int8', 3), ('BasicStaticPackedData1', 'uint8', 1), ('TextureCoordinates0', 'real16', 2)]
    cols = {'Position': POS, 'Normal': np.tile([0, 0, 127], (n, 1)), 'BasicStaticPackedData0': np.full((n, 1), 7),
            'Tangent': np.tile([127, 0, 0], (n, 1)), 'BasicStaticPackedData1': np.full((n, 1), 128),
            'TextureCoordinates0': np.c_[POS[:, 0], POS[:, 1] / 2]}
    bones = [dict(name='root', parent=-1, transform=G.transform(flags=0)),
             dict(name='b', parent=0, transform=G.transform(position=bone_pos, flags=1))]
    data = G.build_model(bones, [dict(name='m', members=members, columns=cols, indices=TRIS, groups=[(0, 0, 2), (1, 2, 2)],
                                      materials=['mata', 'matb'], bone_names=['b'])])
    Path(path).write_bytes(data)


def box(path):
    (b,) = [x for x in B.bindings(path) if x['mesh'] == 'm']
    return b


def test_stale_box_is_found_and_refresh_makes_it_bone_local(tmp_path):
    src, out = tmp_path / 'a.gr2', tmp_path / 'b.gr2'
    model(src)
    assert box(src)['outside']                                    # zero box, vertices up to (1, 2, 0)
    assert L.check_bounds('intact', L.read_raw(src))['status'] == 'FAIL'
    B.refresh(src, out)
    b = box(out)
    assert not b['outside'] and b['box'][2] == 6
    assert np.allclose(b['stored'][0], [-5, 0, 0]) and np.allclose(b['stored'][1], [-4, 2, 0])   # model - bone position
    assert L.check_bounds('intact', L.read_raw(out))['status'] == 'PASS'


def test_drop_refreshes_the_box_to_the_kept_vertices(tmp_path):
    src, out = tmp_path / 'a.gr2', tmp_path / 'b.gr2'
    model(src)
    D.drop(src, {'meshes': {'m': [2, 3]}}, out)                   # keeps vertices 0-3 (y <= 1)
    b = box(out)
    assert np.allclose(b['stored'][1], [-4, 1, 0]) and b['box'][2] == 4


def test_zero_triangle_mesh_reads_and_keeps_its_box(tmp_path):
    src, out = tmp_path / 'a.gr2', tmp_path / 'b.gr2'
    model(src)
    B.refresh(src, src)
    D.drop(src, {'meshes': {'m': [0, 1, 2, 3]}}, out)
    info = L.read_raw(out)                                        # crashed before 2026-10-17 (Indices16 None)
    assert len(info['meshes'][0]['tris']) == 0
    assert box(out)['box'] is None and np.allclose(box(out)['stored'][1], [-4, 2, 0])


def test_dup_refuses_without_free_slots(tmp_path):
    src = tmp_path / 'a.gr2'
    model(src)
    # tri 3 dropped frees only vertex 5; a copy of tri 0 needs 3 slots: refused, nothing written
    with pytest.raises(AssertionError):
        D.drop(src, {'meshes': {'m': [3]}, 'dup': {'m': [{'tris': [0], 'translate': [0, 0, 1]}]}}, tmp_path / 'b.gr2')
    assert not (tmp_path / 'b.gr2').exists()


def test_dup_copies_vertex_bytes_into_freed_slots(tmp_path):
    src, out = tmp_path / 'a.gr2', tmp_path / 'b.gr2'
    model(src)
    # drop tris 0-2 (kept: tri 3 = (4, 3, 5), so vertices 0, 1, 2 are free) and copy tri 1 = (2, 1, 3) one unit up z:
    # its source vertex 2 is itself a free slot that gets overwritten - the copy must read the ORIGINAL bytes
    rep = D.drop(src, {'meshes': {'m': [0, 1, 2]}, 'dup': {'m': [{'tris': [1], 'translate': [0, 0, 1]}]}}, out)
    assert rep['m']['tris_after'] == 2 and rep['m']['duplicated'] == 1 and rep['m']['copied_vertices'] == 3
    m = L.read_raw(out)['meshes'][0]
    assert m['groups'] == [(0, 0, 1), (1, 1, 1)]                                       # the copy stays in tri 1's group
    copy, kept = m['tris']
    assert kept.tolist() == [4, 3, 5] and sorted(copy.tolist()) == [0, 1, 2]
    assert np.allclose(m['pos'][copy], POS[[2, 1, 3]] + [0, 0, 1])
    assert np.allclose(m['uv'][copy], np.c_[POS[[2, 1, 3], 0], POS[[2, 1, 3], 1] / 2])  # source UVs, unmoved
    assert np.allclose(m['pos'][[3, 4, 5]], POS[[3, 4, 5]])                              # kept vertices untouched
    assert Path(src).stat().st_size == Path(out).stat().st_size                         # in place
    assert box(out)['box'][2] == 6 and not box(out)['outside']


def test_rotate_verts_translate_and_matrix_refresh_the_box(tmp_path):
    src, mid, out = tmp_path / 'a.gr2', tmp_path / 'b.gr2', tmp_path / 'c.gr2'
    model(src)
    RV.rotate(src, {'ops': [{'translate': [10, 0, 0], 'meshes': {'m': 'all'}}]}, mid)
    assert np.allclose(L.read_raw(mid)['meshes'][0]['pos'], POS + [10, 0, 0])
    assert np.allclose(box(mid)['stored'][0], [5, 0, 0]) and not box(mid)['outside']
    Rz = [[0, -1, 0], [1, 0, 0], [0, 0, 1]]                                               # +90 degrees about z
    RV.rotate(mid, {'matrix': Rz, 'meshes': {'m': 'all'}}, out)
    m = L.read_raw(out)['meshes'][0]
    assert np.allclose(m['pos'], (POS + [10, 0, 0]) @ np.array(Rz, float).T, atol=1e-5)
    assert np.allclose(m['tan'][0], [0, 1, 0], atol=0.01)                               # tangent (1,0,0) turned too
    assert not box(out)['outside']


def test_rest_anim_keys_are_the_skeleton_rest_and_heave_only_moves_z(tmp_path):
    G = synth()
    q = G.axis_quat([0, 1, 0], 30)
    bones = [dict(name='root', parent=-1, transform=G.transform(flags=0)),
             dict(name='b', parent=0, transform=G.transform(position=(2.54, 5.08, -7.62), quaternion=q,
                                                            scale_shear=(2, 0, 0, 0, 1, 0, 0, 0, 1)))]
    src = tmp_path / 'a.gr2'
    Path(src).write_bytes(G.build_model(bones, [dict(name='m', members=[('Position', 'real32', 3)], columns={'Position': POS},
                                                     indices=TRIS, groups=[(0, 0, 4)], materials=['mata'], bone_names=['b'])]))
    gxo = tmp_path / 'a.gxo'
    rep = A.write(src, gxo, seconds=2, fps=10, heave={'b': (0.02, 0.0)})
    assert rep['frames'] == 21 and rep['root'] == 'root'
    lines = gxo.read_text().splitlines()
    assert lines[0] == 'a 21 10' and lines[1] == 'cg "root"' and lines[2] == 'c "root"'
    keys = {}; cur = None
    for l in lines:
        if l.startswith('c "'): cur = l.split('"')[1]; keys[cur] = []
        elif l.startswith('k '): keys[cur].append([float(x) for x in l.split()[1:]])
    kb = np.array(keys['b'])
    Pm = A.P; Rc = A.qmat(*q); S = np.diag([2.0, 1.0, 1.0])
    assert np.allclose(kb[0, :9].reshape(3, 3), (Pm.T @ S @ Rc @ Pm).T, atol=1e-7)      # ScaleShear . R, mirrored
    assert np.allclose(kb[0, 9:], Pm.T @ np.array([2.54, 5.08, -7.62]) / 2.54)           # metres: (-1, 3, 2)
    assert np.allclose(kb[:, :11], kb[0, :11]) and np.allclose(kb[-1], kb[0])           # only z moves; seamless loop
    assert math.isclose(kb[5, 11] - kb[0, 11], 0.02, abs_tol=1e-7)                       # quarter period = +amplitude
    assert np.allclose(np.array(keys['root']), np.array(keys['root'])[0])               # unheaved: constant
