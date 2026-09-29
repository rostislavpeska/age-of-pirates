"""Specimen proof for reposition_island.py on a tiny synthetic page (no Blender, no project data).

python -m pytest .claude/skills/blender-uv-conjoin/scripts/test_reposition_island.py -q

Page P64 (64 texels, 20 texels per metre): left half WOOD texels, right half PLASTER. A wooden frame board F
(0.2 x 1.0 m, facing +x) is carried as a PLASTER owner (it renders white); its authored class says WOOD. WOOD owners:
W1 congruent (facing -y: a proper rotation about z), W2 wider (0.3 m), W3 congruent but with a mirrored UV.
"""
import json
import sys
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import reposition_island as RI  # noqa: E402

S = 64
CLASSES = ['WOOD', 'PLASTER']


def quad(p0, e1, e2):
    p0, e1, e2 = (np.asarray(x, float) for x in (p0, e1, e2))
    return [p0, p0 + e1, p0 + e1 + e2, p0 + e2]


def uvq(u0, v0, du, dv, mirror=False):
    q = [(u0, v0), (u0 + du, v0), (u0 + du, v0 + dv), (u0, v0 + dv)]
    if mirror:
        q = [(u0 + du, v0), (u0, v0), (u0, v0 + dv), (u0 + du, v0 + dv)]
    return [[a / S, b / S] for a, b in q]


def specimen(with_member=False, ao_w1=0.9, owners=('W1', 'W2', 'W3'), g_face=False):
    geo, plan = {}, {}

    def add(k, verts, uv, fam, owner, mat):
        v = np.asarray(verts, float); n = RI.newell(v)
        geo[k] = dict(v=v.tolist(), n=n.tolist()); plan[k] = dict(page='P64', uv=uv, family=fam, family_size=1, owner=owner, material=mat)
    add('F', quad((0, 0, 0), (0, 0.2, 0), (0, 0, 1)), uvq(40, 10, 4, 20), 'wall', True, 'PLASTER')          # the frame
    add('P', quad((0, 1, 0), (0, 1, 0), (0, 0, 1)), uvq(48, 10, 12, 20), 'panel', True, 'PLASTER')          # a real panel
    if with_member:                                                                                            # reads F's texels
        add('M', quad((0, 3, 0), (0, 0.2, 0), (0, 0, 1)), uvq(40, 10, 4, 20), 'wall', False, 'PLASTER')
        plan['F']['family_size'] = plan['M']['family_size'] = 2
    if 'W1' in owners:
        add('W1', quad((0.8, 5, 0), (0.2, 0, 0), (0, 0, 1)), uvq(4, 10, 4, 20), 'frames', True, 'WOOD')
    if 'W2' in owners:
        add('W2', quad((2.7, 5, 0), (0.3, 0, 0), (0, 0, 1)), uvq(12, 10, 6, 20), 'planks', True, 'WOOD')
    if 'W3' in owners:
        add('W3', quad((4.8, 5, 0), (0.2, 0, 0), (0, 0, 1)), uvq(22, 10, 4, 20, mirror=True), 'mirrored', True, 'WOOD')
    if g_face:                                                                                                 # a half-height board
        add('G', quad((0, 7, 0), (0, 0.2, 0), (0, 0, 0.5)), uvq(40, 40, 4, 10), 'short', True, 'PLASTER')
    cm = np.zeros((S, S), int); cm[:, 32:] = 1
    tri = [([0, 1, 2], [w, (1 - w) / 2, (1 - w) / 2], 0) for w in (0.2, 0.4, 0.6, 0.8)] + \
          [([0, 2, 3], [(1 - w) / 2, w, (1 - w) / 2], 0) for w in (0.2, 0.4, 0.6, 0.8)]
    ao = {k: [list(c) + [0.9 if k != 'W1' else ao_w1] for c in tri] for k in plan}
    cfg = dict(_geo=geo, _classmap={'P64': cm}, _ao=ao, _painted=None, _charts=None, pages={'P64': S}, classes=CLASSES,
               equivalent=[], expected={'F': 'WOOD', 'G': 'WOOD', 'M': 'WOOD'}, density_tol=0.03, directional=['WOOD'],
               sources={'Obj_A': 'X'}, uv_layer='UV_Final', base_version='T0')
    return plan, cfg


def run(plan, cfg, faces, **kw):
    D = RI.Data(cfg, plan=plan)
    return D, RI.build_plan(D, faces, 'T1', cfg['density_tol'], **kw)


def test_frame_carried_as_plaster_becomes_member_of_congruent_wood_owner():
    plan, cfg = specimen()
    D, (new, rep, cand, det0, det1) = run(plan, cfg, ['F'])
    assert rep['verdict'] == 'PASS', rep['gates']
    mv = rep['moved']['F']
    assert (mv['owner'], mv['mode'], mv['cls']) == ('W1', 'corner', 'WOOD')
    assert new['F']['family'] == 'frames' and new['F']['owner'] is False and new['F']['material'] == 'WOOD'
    assert sorted(map(tuple, new['F']['uv'])) == sorted(map(tuple, plan['W1']['uv']))         # the owner's texels, no new ones
    assert mv['density_ratio_per_axis'] == [1.0, 1.0] and mv['handedness'] == mv['owner_handedness']
    assert all(new[k]['uv'] == plan[k]['uv'] for k in plan if k != 'F')                       # nothing else moved
    assert {k for k in plan if new[k] != plan[k]} == {'F', 'W1'} and new['W1']['family_size'] == 2   # the family counts F
    # class_mismatch: flagged before (wood reading plaster), clean after; role registration clean
    assert det0['cls_P64']['flagged_faces'] == ['F'] and det1['cls_P64']['flagged_faces'] == []
    assert rep['gates']['role_registration'] and rep['gates']['class_mismatch']
    # the candidates: W2 is wider (no corner registration); W3's own UV is mirrored and the member follows it
    d = cand['F']['details']
    assert 'corner' not in d['W2']['modes'] and 'contain' in d['W2']['modes']              # 50 % wider: a window only
    w3 = d['W3']['modes']['corner']                     # proper rotations only: a member never reads its owner flipped
    assert w3['handedness'] == w3['owner_handedness'] == -1 and d['W1']['modes']['corner']['handedness'] == 1


def test_live_patch_carries_from_and_to_and_chains(tmp_path):
    plan, cfg = specimen()
    D, (new, rep, *_) = run(plan, cfg, ['F'])
    prev = tmp_path / 'prev.json'
    prev.write_text(json.dumps(dict(object_hint='Obj_A', uv_layer='UV_Final', faces={'7': {'from': [[0, 0]], 'to': [[1, 1]]}})))
    cfg['sources'] = {'Obj_A': 'X'}
    plan2 = {f'X:{i}': v for i, v in enumerate(plan.values())}; new2 = {f'X:{i}': v for i, v in enumerate(new.values())}
    plan2['X:7'] = dict(plan2['X:0'], uv=[[1, 1]]); new2['X:7'] = plan2['X:7']
    lp = RI.live_patch(D, plan2, new2, ['X:0'], [prev])
    assert lp['object_hint'] == 'Obj_A' and lp['uv_layer'] == 'UV_Final'
    assert lp['faces']['0']['from'] == plan['F']['uv'] and lp['faces']['0']['to'] == new['F']['uv']
    assert lp['faces']['7'] == {'from': [[0, 0]], 'to': [[1, 1]]}                             # the earlier batch rides along


def test_moved_owner_hands_its_texels_to_the_member_that_reads_them():
    plan, cfg = specimen(with_member=True)
    D, (new, rep, *_) = run(plan, cfg, ['F'])
    assert rep['verdict'] == 'PASS'
    assert new['M']['owner'] is True and rep['promoted_owners']['M']['replaces'] == 'F'
    assert rep['promoted_owners']['M']['footprint_cover'] >= 0.999 and rep['promoted_owners']['M']['handedness_same']
    assert rep['family_size_changes']['wall'] == dict(convention='faces', before=2, after=1, faces_before=2, faces_after=1)
    assert new['M']['family_size'] == 1


def test_shorter_board_goes_into_a_longer_owner_as_a_one_to_one_window():
    plan, cfg = specimen(owners=('W1',), g_face=True)
    D, (new, rep, *_) = run(plan, cfg, ['G'])
    mv = rep['moved']['G']
    assert (mv['owner'], mv['mode']) == ('W1', 'contain') and rep['verdict'] == 'PASS'
    assert all(abs(x - 1) < 1e-3 for x in mv['density_ratio_per_axis']) and mv['inside_owner_footprint'] >= 0.999
    v = np.asarray(new['G']['uv']) * S
    assert v[:, 0].min() >= 4 - 1e-6 and v[:, 0].max() <= 8 + 1e-6 and np.ptp(v[:, 1]) == pytest.approx(10, abs=1e-6)
    assert v[:, 1].min() == pytest.approx(10, abs=1e-6)                          # sits on the owner's bottom edge


def test_ao_gate_blocks_then_accept_ao_takes_it_as_a_waived_gate():
    plan, cfg = specimen(ao_w1=0.3, owners=('W1',))
    D, (new, rep, cand, *_) = run(plan, cfg, ['F'])
    assert new is None and rep['verdict'] == 'NO_PLACEMENT' and rep['failed'] == ['F']
    assert cand['F']['closest'][0]['fails'] == ['ao']
    D, (new, rep, *_) = run(plan, cfg, ['F'], accept_ao=True)
    assert new['F']['family'] == 'frames' and 'F' in rep['ao_gate_waived']['faces']


def test_no_owner_free_texels_of_the_class_are_used():
    plan, cfg = specimen(owners=())
    D, (new, rep, *_) = run(plan, cfg, ['F'], allow_free=True)
    assert rep['moved']['F']['mode'] == 'free' and new['F']['owner'] is True and new['F']['material'] == 'WOOD'
    v = np.asarray(new['F']['uv']) * S
    assert v[:, 0].max() <= 32 and np.ptp(v[:, 0]) == pytest.approx(4) and np.ptp(v[:, 1]) == pytest.approx(20)
    assert rep['gates']['class_mismatch'] and rep['gates']['no_new_cross_family_overlap']


def test_verify_arrays_catches_a_change_outside_the_fix():
    uv = np.arange(16, dtype=np.float32).reshape(8, 2) / 16
    base = {'Obj_A|uv': uv, 'Obj_A|start': np.array([0, 4], np.int32), 'Obj_A|total': np.array([4, 4], np.int32),
            'Obj_A|mat': np.array([0, 0], np.int32)}
    plan = {'X:0': dict(uv=(uv[:4] + 0.5).tolist()), 'X:1': dict(uv=uv[4:].tolist())}
    new = dict(base, **{'Obj_A|uv': np.r_[uv[:4] + 0.5, uv[4:]].astype(np.float32)})
    ok, per = RI.verify_arrays(base, new, {'X': {0}}, plan, {'Obj_A': 'X'})
    assert ok and per['Obj_A']['changed'] == 1
    bad = dict(new, **{'Obj_A|uv': np.r_[uv[:4] + 0.5, uv[4:] + 0.1].astype(np.float32)})
    ok, per = RI.verify_arrays(base, bad, {'X': {0}}, plan, {'Obj_A': 'X'})
    assert not ok and per['Obj_A']['changed_outside_fix'] == [1]


def test_config_paths_resolve_and_templates_fill(tmp_path):
    (tmp_path / 'cfg.json').write_text(json.dumps(dict(base_plan='a/plan.json', expected={'X:1': 'WOOD'}, factory_out='{out}/F_{version}.blend',
                                                       classmap={'path': 'maps/{page}_ClassID.png', 'palette': {'WOOD': '#ff0000'}},
                                                       plain_pairs=[['dec', 'base']], handoff={'inputs': ['../h/HANDOFF.json'], 'why': 'a/b'})))
    c = RI.load_config(tmp_path / 'cfg.json', 'T9', tmp_path / 'out')
    assert c['base_plan'] == str((tmp_path / 'a/plan.json').resolve()) and c['expected'] == {'X:1': 'WOOD'}
    assert c['factory_out'] == str(tmp_path / 'out') + '/F_T9.blend'
    assert c['classmap']['path'].endswith('{page}_ClassID.png') and Path(c['classmap']['path']).is_absolute()
    assert c['classmap']['palette'] == {'WOOD': '#ff0000'} and Path(c['plain_pairs'][0][0]).is_absolute()
    assert c['handoff']['why'] == 'a/b' and Path(c['handoff']['inputs'][0]).is_absolute()
