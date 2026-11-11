"""Pivot canonization (gr2_bones.py) and gr2_lint check root_identity (2026-10-17, Korean HC docks01: "dock has broken
pivot", "for complex scenes pivot canonization should be the first step").

    python -m pytest scripts/havok/tests/test_gr2_bones.py -q

Synthetic models built with the anim viewer's Granny writer (.claude/skills/aoe3de-anim-viewer/tests/gr2_synth.py) - no
game bytes. Bones carry no scale/shear here (the writer composes scale in its own order; vanilla is checked by the tool's
own convention self-check).
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pytest

HAVOK = Path(__file__).resolve().parents[1]
SYNTH = HAVOK.parents[1] / '.claude' / 'skills' / 'aoe3de-anim-viewer' / 'tests'
sys.path.insert(0, str(HAVOK))
import gr2_bones as GB  # noqa: E402
import gr2_lint as L  # noqa: E402

POS = np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0]], float)


def model(path, root_pos=(3, 0.5, -6), root_deg=10.8, bad_inverse=False, post='post'):
    if not (SYNTH / 'gr2_synth.py').is_file():
        pytest.skip('gr2_synth.py (aoe3de-anim-viewer tests) not found')
    sys.path.insert(0, str(SYNTH))
    import gr2_synth as G
    bones = [dict(name='root', parent=-1, transform=G.transform(position=root_pos, quaternion=G.axis_quat([0, 1, 0], root_deg), flags=3)),
             dict(name='pivot', parent=0, transform=G.transform(position=(-30, 1, -11), quaternion=G.axis_quat([0, 1, 0], 80), flags=3)),
             dict(name='hull', parent=1, transform=G.transform(position=(-12, 0.1, 31), flags=1)),
             dict(name=post, parent=0, transform=G.transform(position=(5, 0, 2), flags=1))]
    if bad_inverse:
        bones[3]['inverse_world'] = list(np.eye(4).ravel())
    Path(path).write_bytes(G.build_model(bones, [dict(name='m', members=[('Position', 'real32', 3)], columns={'Position': POS},
                                                      indices=[0, 1, 2], groups=[(0, 0, 1)], materials=['mata'], bone_names=['hull'])]))


def worlds(path):
    return {b['name']: b['world'] for b in L.read_raw(path)['bones']}


def test_canonize_root_keeps_every_child_world(tmp_path):
    src, out = tmp_path / 'a.gr2', tmp_path / 'b.gr2'
    model(src)
    assert L.check_root_identity('intact', L.read_raw(src))['status'] == 'FAIL'
    rep = GB.edit(src, {'canonize_root': True}, out)
    assert rep['convention_error'] < 1e-4 and rep['root'] == 'root'
    a, b = worlds(src), worlds(out)
    assert np.allclose(b['root'], np.eye(4)) and all(np.allclose(a[n], b[n], atol=1e-5) for n in ('pivot', 'hull', 'post'))
    assert L.check_root_identity('intact', L.read_raw(out))['status'] == 'PASS'
    assert np.array_equal(L.read_raw(src)['meshes'][0]['pos'], L.read_raw(out)['meshes'][0]['pos'])   # vertices untouched
    assert src.stat().st_size == out.stat().st_size


def test_move_carries_the_subtree_and_nothing_else(tmp_path):
    src, out = tmp_path / 'a.gr2', tmp_path / 'b.gr2'
    model(src)
    Rz = GB.qmat(*np.r_[np.sin(np.radians(36.5)) * np.array([0, 1, 0]), np.cos(np.radians(36.5))])     # 73 deg about y
    GB.edit(src, {'canonize_root': True, 'move': [{'bones': ['pivot'], 'matrix': Rz.tolist(), 'translate': [62.8, 0, 0]}]}, out)
    a, b = worlds(src), worlds(out)
    M = np.eye(4); M[:3, :3] = Rz; M[:3, 3] = [62.8, 0, 0]
    for n in ('pivot', 'hull'):                                  # row-vector worlds: new = old . M^T
        assert np.allclose(b[n], a[n] @ M.T, atol=1e-4), n
    assert np.allclose(b['post'], a['post'], atol=1e-5)


def test_refuses_a_skeleton_whose_inverse_worlds_are_not_its_rest(tmp_path):
    src = tmp_path / 'a.gr2'
    model(src, bad_inverse=True)
    with pytest.raises(AssertionError, match='convention'):
        GB.edit(src, {'canonize_root': True}, tmp_path / 'b.gr2')
    assert not (tmp_path / 'b.gr2').exists()


def test_identity_root_passes_untouched(tmp_path):
    src = tmp_path / 'a.gr2'
    model(src, root_pos=(0, 0, 0), root_deg=0)
    assert L.check_root_identity('intact', L.read_raw(src))['status'] == 'PASS'


def test_rename_track_unbinds_one_track_in_place(tmp_path):
    """the accepted docks01 fix (owner 2026-10-17): the vanilla Idle with the moved junk's track renamed - it drives
    nothing, so that junk stays static; same length, same sort slot, every other byte but the name and the CRC kept"""
    import subprocess
    from gr2_rest_anim import tracks_of
    if not (SYNTH / 'gr2_synth.py').is_file():
        pytest.skip('gr2_synth.py (aoe3de-anim-viewer tests) not found')
    sys.path.insert(0, str(SYNTH))
    import gr2_synth as G
    rest = {'OrientationCurve': ('D4Constant32f', [0, 0, 0, 1]), 'PositionCurve': ('D3Constant32f', [0, 0, 0])}
    src, out = tmp_path / 'a.gr2', tmp_path / 'b.gr2'
    src.write_bytes(G.build_clip([('root', G.transform(flags=0), [('junk', rest), ('junk1', rest), ('root', rest)])]))
    r = subprocess.run([sys.executable, str(HAVOK / 'gr2_rename.py'), str(src), str(out), 'track', 'junk', 'jun_'],
                       capture_output=True, text=True, cwd=str(HAVOK))
    assert r.returncode == 0, r.stdout + r.stderr
    assert tracks_of(src) == ['junk', 'junk1', 'root'] and tracks_of(out) == ['jun_', 'junk1', 'root']
    a, b = src.read_bytes(), out.read_bytes()
    assert len(a) == len(b) and sum(x != y for x, y in zip(a, b)) <= 5                 # one letter + the CRC


def test_untouched_bone_records_stay_byte_identical(tmp_path):
    """a move rewrites only the moved subtree (2026-10-17: a re-run once re-rounded 6 untouched ground bones by 2.5e-6)"""
    from gr2_read import Gr2
    from gr2_dump import refs
    src, out = tmp_path / 'a.gr2', tmp_path / 'b.gr2'
    model(src)
    rep = GB.edit(src, {'move': [{'bones': ['post'], 'translate': [1, 0, 0]}]}, out)
    assert rep['rewritten'] == ['post']
    def records(p):
        g = Gr2(str(p)); arr = refs(g, g.root()['Skeletons'])[0][0]['Bones']; o = g.sections[arr[2][0]]['data_off'] + arr[2][1]
        return [g.data[o + i * 164:o + (i + 1) * 164] for i in range(arr[1])]
    a, b = records(src), records(out)
    assert a[0] == b[0] and a[1] == b[1] and a[2] == b[2] and a[3] != b[3]
