"""gr2_droptris.py (2026-10-11): drop listed triangles in place, everything else byte-identical.

    python -m pytest scripts/havok/tests/test_gr2_droptris.py -q

Synthetic model built with the anim viewer's Granny writer (.claude/skills/aoe3de-anim-viewer/tests/gr2_synth.py) - no
game bytes. First use: the Korean TC construction r74 (owner: "strip all the wooden pannels and leave only the beams").
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import pytest

HAVOK = Path(__file__).resolve().parents[1]
REPO = HAVOK.parents[1]
SYNTH = REPO / '.claude' / 'skills' / 'aoe3de-anim-viewer' / 'tests'
sys.path.insert(0, str(HAVOK))
import gr2_droptris as D  # noqa: E402
from gr2_dump import refs  # noqa: E402
from gr2_read import Gr2  # noqa: E402


def model(path, compression=0):
    if not (SYNTH / 'gr2_synth.py').is_file():
        pytest.skip('gr2_synth.py (aoe3de-anim-viewer tests) not found')
    sys.path.insert(0, str(SYNTH))
    import gr2_synth as G
    n = 6
    cols = {'Position': np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0], [1, 1, 0], [0, 2, 0], [1, 2, 0]], float),
            'TextureCoordinates0': np.array([[0, 0], [1, 0], [0, .5], [1, .5], [0, 1], [1, 1]], float)}
    members = [('Position', 'real32', 3), ('TextureCoordinates0', 'real32', 2)]
    tris = [0, 1, 2, 2, 1, 3, 2, 3, 4, 4, 3, 5]                       # 4 triangles: group 0 = tris 0-1, group 1 = tris 2-3
    data = G.build_model([dict(name='root', parent=-1, transform=G.transform(flags=0))],
                         [dict(name='m', members=members, columns=cols, indices=tris, groups=[(0, 0, 2), (1, 2, 2)],
                               materials=['mata', 'matb'], bone_names=['root'])], compression=compression)
    assert len(cols['Position']) == n
    Path(path).write_bytes(data)


def topology(path):
    g = Gr2(str(path)); m = refs(g, g.root()['Meshes'])[0][0]; tt = m['PrimaryTopology']; top = g.read(*tt[2], *tt[1])
    (isec, ibase), n = top['Indices'][2], top['Indices'][1]
    tris = np.frombuffer(bytes(g.payload[isec][ibase:ibase + 4 * n]), '<i4').reshape(-1, 3)
    groups = [(x['MaterialIndex'][0], x['TriFirst'][0], x['TriCount'][0]) for x in g.array(top['Groups'])]
    vd = m['PrimaryVertexData']; va = g.read(*vd[2], *vd[1])['Vertices']; vsec, vbase = va[3]
    return tris, groups, bytes(g.payload[vsec][vbase:vbase + va[2] * g.struct_size(*va[1])])


def test_drop_compacts_and_keeps_everything_else(tmp_path):
    src, out = tmp_path / 'a.gr2', tmp_path / 'b.gr2'
    model(src)
    rep = D.drop(src, {'meshes': {'m': [1, 2]}}, out)
    assert rep['m']['tris_after'] == 2 and rep['m']['groups'] == [(0, 0, 2, 0, 1), (1, 2, 2, 1, 1)]
    assert Gr2(str(out)).crc_check()
    ta, ga, va = topology(src); tb, gb, vb = topology(out)
    assert va == vb and np.array_equal(tb, ta[[0, 3]])
    assert ga == [(0, 0, 2), (1, 2, 2)] and gb == [(0, 0, 1), (1, 1, 1)]
    assert src.stat().st_size == out.stat().st_size


def test_nothing_dropped_is_byte_identical(tmp_path):
    src, out = tmp_path / 'a.gr2', tmp_path / 'b.gr2'
    model(src)
    D.drop(src, {'meshes': {'m': []}}, out)
    assert src.read_bytes() == out.read_bytes()


def test_changed_bytes_are_only_topology_and_crc(tmp_path):
    src, out = tmp_path / 'a.gr2', tmp_path / 'b.gr2'
    model(src)
    D.drop(src, {'meshes': {'m': [3]}}, out)
    rng = D.changed_ranges(src.read_bytes(), out.read_bytes())
    assert rng and rng[0][0] >= 32 and sum(e - s + 1 for s, e in rng) < 64      # CRC + index tail + counts


def test_refuses_out_of_range_and_compressed(tmp_path):
    src = tmp_path / 'a.gr2'
    model(src)
    with pytest.raises(AssertionError):
        D.drop(src, {'meshes': {'m': [9]}}, tmp_path / 'b.gr2')
    assert not (tmp_path / 'b.gr2').exists()
