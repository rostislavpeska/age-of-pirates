"""aoe3de-unit-model measurement and round-trip scripts.

    python -m pytest .claude/skills/aoe3de-unit-model/tests -q

Every case imports unit_gr2, which needs the consuming project's GR2 reader (`<consumer-root>/scripts/havok/gr2_read.py`
and `gr2_dump.py`, found by walking up from the scripts or through AOE3_UNIT_CONSUMER_ROOT); without it the whole
module is skipped. Beyond that reader the synthetic cases need only Python and numpy (Linux CI). The vanilla cases
read the retail archives (aoe3de-bar-archives' bartool, AOE3DE_GAME or the default Steam folder) into pytest's temp
folder and pin the numbers recorded in references/vanilla-unit-measurements.md and rider-skeleton.md; they carry the
consumer's `local("steam")` marker (CI deselects them with -m "not local") and skip where no game install is found.
The round-trip cases also need a background Blender (BLENDER, the consumer's config/tool-paths.local.json or PATH) and
skip without it. Nothing is written outside pytest's temp folder.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
SCRIPTS = HERE.parent / 'scripts'
sys.path.insert(0, str(SCRIPTS))
try:
    import unit_gr2 as U  # noqa: E402
except SystemExit as e:                                                 # no consumer GR2 reader (a public export)
    pytest.skip(str(e), allow_module_level=True)
import measure_units as MU  # noqa: E402
import vertex_fill as VF  # noqa: E402
import joint_metrics as JM  # noqa: E402
import shape_metrics as SM  # noqa: E402
import clip_angles as CA  # noqa: E402
import track_coverage as TC  # noqa: E402
import texture_pages as TP  # noqa: E402
import tangent_compare as TG  # noqa: E402
import clip_decode as CD  # noqa: E402

GAME = U.game_available()


def needs_game(f):
    """the consumer's local("steam") marker (registered in its pytest.ini) plus a skip where no archive is found."""
    return pytest.mark.local('steam')(pytest.mark.skipif(not GAME, reason='no AoE3 DE game archives (AOE3DE_GAME or '
                                                                          'the Steam folder)')(f))
IRON = 'Art/units/asians/chinese/iron_flail/iron_rider_0.gr2'
YAB = 'Art/units/asians/japanese/yabusame/yabusamerider_0.gr2'
CLIPS = ['Art/animation_library/cavalry/oprichnik_attack_A.gr2', 'Art/animation_library/cavalry/oprichnik_idle1.gr2']
CHAIN = {'bip01_attach_rt', 'bone_handle', 'bone_link1', 'bone_link2', 'bone_link3', 'bone_tip'}


# ---------------------------------------------------------------- synthetic, no game

def test_gxo_frame_mapping_is_the_converters():
    assert np.allclose(U.to_gxo_point([1.0, 2.0, 3.0]), np.array([-1.0, -3.0, 2.0]) / 2.54)
    assert np.isclose(np.linalg.det(U.A), -1.0) and np.allclose(U.A @ U.A.T, np.eye(3))
    W = np.eye(4)
    W[3, :3] = [0.0, 1.1418, 0.0]                                       # the yabusame root, engine units
    G = U.to_gxo_matrix(W)
    assert np.allclose(G[:3, :3], np.eye(3)) and np.allclose(G[3, :3], [0, 0, 1.1418 / 2.54])


def test_region_keeps_flail_bones_out_of_the_hands():
    assert U.region('bone_handle') == 'weapon' and U.region('Bip01_L_Hand') == 'hands'
    assert U.region('Bip01_L_ForeArm') == 'arms' and U.region('Bip01_R_Foot') == 'feet'
    assert U.legs_region('feet') == 'legs'


def test_rings_cluster_the_blended_rows_of_a_limb():
    J = {'bip01 l thigh': np.array([0, 0, 1.0]), 'bip01 l calf': np.array([0, 0, 0.5]), 'bip01 l foot': np.zeros(3)}
    V = []
    for z, w in ((0.7, {'bip01 l thigh': 1.0}), (0.55, {'bip01 l thigh': 0.6, 'bip01 l calf': 0.4}),
                 (0.5, {'bip01 l thigh': 0.5, 'bip01 l calf': 0.5}), (0.45, {'bip01 l thigh': 0.25, 'bip01 l calf': 0.75}),
                 (0.3, {'bip01 l calf': 1.0})):
        for k in range(6):
            a = 2 * np.pi * k / 6
            V.append((np.array([0.05 * np.cos(a), 0.05 * np.sin(a), z]), w))
    L, res = JM.rings(V, J, 'l thigh', 'l calf', 'l foot')
    assert L == 0.5 and [r[1] for r in res] == [6, 6, 6]                # rows at 0.7 and 0.3 lie outside the window
    assert [r[0] for r in res] == [-0.1, 0.0, 0.1] and [r[3] for r in res] == [0.4, 0.5, 0.75]
    assert all(r[2] == 1.0 for r in res)


def test_blend_counts_name_the_joint_by_its_two_largest_bones():
    V = [(None, {'bip01 l thigh': 0.55, 'bip01 l calf': 0.45}), (None, {'bip01 l calf': 0.7, 'bip01 l thigh': 0.3}),
         (None, {'bip01 head': 0.6, 'bip01 spine1': 0.4}), (None, {'bip01 r forearm': 0.9, 'bip01 r hand': 0.1}),
         (None, {'bip01 pelvis': 1.0})]
    out = JM.blend_counts(V)
    assert out['knee l'] == {'positions': 2, 'median_minor': 0.38}
    assert out['head-chest']['positions'] == 1 and out['wrist r']['median_minor'] == 0.1
    assert len(out) == 3


class FakeMesh:
    def __init__(self, W, B):
        self.comps = {'BoneWeights': np.array(W, np.uint8), 'BoneIndices': np.array(B, np.uint8)}


def test_weight_storage_reports_sums_order_and_zero_slots():
    m = FakeMesh([[255, 0, 0, 0], [200, 55, 0, 0], [100, 155, 0, 0]], [[3, 3, 3, 3], [1, 2, 1, 0], [4, 5, 4, 4]])
    w = VF.weight_storage(m)
    assert w['sums'] == {255: 3} and w['descending'] == 2 and w['dup_bone'] == 0
    assert w['zero_slot_index'] == {'slot0': 6, 'zero': 1} and w['min_weight'] == 55


class FakeSkinned:
    """boxes (centre, half size, bone) as one skinned mesh, every triangle wound outward; engine frame, y up."""
    def __init__(self, boxes):
        P, T, W = [], [], []
        for centre, half, bone in boxes:
            c = np.array(centre, float)
            base = len(P)
            corners = [c + half * np.array([x, y, z]) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
            P += corners
            W += [{bone: 1.0}] * 8
            for axis in range(3):
                for sign in (-1, 1):
                    q = [i for i in range(8) if (np.sign(corners[i][axis] - c[axis]) == sign)]
                    q = sorted(q, key=lambda i: np.arctan2(*np.delete(corners[i] - c, axis)[::-1]))
                    for tri in ((q[0], q[1], q[2]), (q[0], q[2], q[3])):
                        a, b, cc = (corners[i] for i in tri)
                        n = np.cross(b - a, cc - a)
                        T.append([base + i for i in (tri if n[axis] * sign > 0 else tri[::-1])])
        self.pos, self.tris, self.skinned, self._w = np.array(P), np.array(T, np.int64), True, W

    def vertex_weights(self):
        return self._w


def test_seat_counts_downward_and_inner_thigh_faces_only():
    me = FakeSkinned([((0, 1.0, 0), 0.1, 'Bip01_Pelvis'), ((0.3, 0.6, 0), 0.1, 'Bip01_R_Thigh'),
                      ((0, 1.8, 0), 0.1, 'Bip01_Head')])
    s = SM.seat(me)
    # pelvis bottom (2) and thigh bottom (2) face down; the thigh's -x side faces the mid-plane (2); the head is not
    # in the zone
    assert s == dict(tris=36, pelvis_thigh=24, seat_down=4, inner_thigh=2, share=16.7)


def joint_matrices(pos):
    out = []
    for p in pos:
        M = np.eye(4)
        M[3, :3] = p
        out.append(M)
    return out


def test_clip_angles_of_a_standing_and_a_bent_skeleton():
    names = ['pelvis', 'spine', 'spine1', 'neck', 'l_thigh', 'l_calf', 'l_foot', 'r_thigh', 'r_calf', 'r_foot',
             'l_upperarm', 'l_forearm', 'l_hand', 'r_upperarm', 'r_forearm', 'r_hand']
    P = {'pelvis': (0, 0, 1), 'spine': (0, 0, 1.1), 'spine1': (0, 0, 1.3), 'neck': (0, 0, 1.5), 'l_thigh': (0.1, 0, 1),
         'l_calf': (0.1, 0, 0.5), 'l_foot': (0.1, 0, 0), 'r_thigh': (-0.1, 0, 1), 'r_calf': (-0.1, 0, 0.5),
         'r_foot': (-0.1, 0, 0), 'l_upperarm': (0.2, 0, 1.45), 'l_forearm': (0.2, 0, 1.15), 'l_hand': (0.2, 0, 0.85),
         'r_upperarm': (-0.2, 0, 1.45), 'r_forearm': (-0.2, 0, 1.15), 'r_hand': (-0.2, 0, 0.85)}
    bones = [{'name': 'Bip01_' + n.title().replace('Upperarm', 'UpperArm').replace('Forearm', 'ForeArm')} for n in names]
    W = joint_matrices([P[n] for n in names])
    r = CA.angles(bones, W)
    assert all(abs(r[k]) < 1e-6 for k in ('hipflex_l', 'knee_l', 'arm_from_down_l', 'elbow_l', 'thigh_spread', 'spine_bend'))
    P['l_calf'], P['l_foot'] = (0.1, -0.5, 1.0), (0.1, -0.5, 0.5)        # thigh forward (hip 90), shin down (knee 90)
    W = joint_matrices([P[n] for n in names])
    r = CA.angles(bones, W)
    assert round(r['hipflex_l']) == 90 and round(r['knee_l']) == 90


def test_clip_angles_refuses_a_near_singular_key(tmp_path):
    names = ['Pelvis', 'Spine', 'Spine1', 'Neck', 'L_Thigh', 'L_Calf', 'L_Foot', 'R_Thigh', 'R_Calf', 'R_Foot',
             'L_UpperArm', 'L_ForeArm', 'L_Hand', 'R_UpperArm', 'R_ForeArm', 'R_Hand']
    bones = [{'name': 'Bip01_' + n, 'parent': -1, 'W0': M}
             for n, M in zip(names, joint_matrices([(0.01 * i, 0.02 * i, 0.03 * i * i) for i in range(len(names))]))]
    clip = tmp_path / 'clip.gxo'
    clip.write_text('a 2 30\ncg "Bip01_Root"\nc "Bip01_Pelvis"\nk 1 0 0 0 1 0 0 0 1 0 0 0\n'
                    'k 0.0019 -0.0128 -0.2591 0.0194 -0.0019 -0.0153 -0.0009 -0.0146 0.2293 0 0 0\n')
    with pytest.raises(SystemExit, match='key 1 of clip.gxo.*Bip01_Pelvis.*clip_decode.py'):
        CA.clip_rows(bones, clip)


class FakeDonor:
    def __init__(self, names):
        self.skeleton = [{'name': n} for n in names]


def test_coverage_lists_tracks_without_a_bone_and_the_root_track():
    clips = [('a', 'Bip01_Root', [('Bip01_Root', True, True), ('Bip01 Pelvis', True, False), ('bone_tip', True, True)]),
             ('b', 'Bip01_Root', [('Bip01_Root', True, True), ('Bip01_Pelvis', True, False)])]
    r = TC.coverage(FakeDonor(['Bip01_Root', 'Bip01_Pelvis', 'Bip01_Neck']), clips)
    assert r['fully_covered'] == 1 and r['orphan_tracks'] == {'bone_tip': ['a']}
    assert r['unkeyed_bones'] == ['Bip01_Neck'] and len(r['root_track']) == 2


def test_summary_finds_the_extremes():
    rows = [dict(name='a', tris=10, welded=5, unique_positions=4, gpu_verts=6),
            dict(name='b', tris=30, welded=9, unique_positions=8, gpu_verts=12), dict(name='c', unreadable='x')]
    s = MU.summary(rows)
    assert s['tris']['min_file'] == 'a' and s['tris']['max'] == 30 and s['tris']['median'] == 20


def test_ddt_header_reads_size_format_and_mips():
    h = TP.ddt_header(b'RTS3' + bytes([0, 1, 5, 9]) + (1024).to_bytes(4, 'little') + (512).to_bytes(4, 'little'))
    assert h == dict(W=1024, H=512, format=5, mips=9, usage=0, alpha=1)


def test_fetch_refuses_a_git_working_tree_before_reading_anything(tmp_path):
    repo = tmp_path / 'some_repo'
    (repo / '.git').mkdir(parents=True)
    with pytest.raises(SystemExit, match='git working tree'):
        U.fetch(['Art/units/x.gr2'], repo / 'extract', index=(None, {}))   # a fake index: refused before any lookup
    assert not (repo / 'extract').exists()
    with pytest.raises(SystemExit):
        U.refuse_repo_target(U.ROOT / 'scratch_copy')                    # the consumer root itself
    U.refuse_repo_target(tmp_path / 'plain')                              # a folder outside every repository passes
    with pytest.raises(SystemExit, match='git working tree'):
        CD.main(['--out-dir', str(repo / 'clips'), str(tmp_path / 'missing.gr2')])


# ---------------------------------------------------------------- clip_decode, synthetic curves

def test_bspline_degree_1_is_a_linear_key_at_each_knot():
    K = np.array([0.0, 1.0, 3.0])
    C = np.array([[0.0], [10.0], [30.0]])
    assert np.allclose([CD.bspline(K, C, 1, t)[0] for t in (0.0, 0.5, 1.0, 2.0, 3.0, 9.0)], [0, 5, 10, 20, 30, 30])
    assert np.allclose(CD.bspline(K, C, 0, 0.5), [10.0])                 # degree 0 holds control i until knot i


def test_bspline_degree_2_holds_constants_hits_the_ends_and_is_continuous():
    K = np.array([0.0, 0.00065, 0.0124, 0.0241, 0.0475, 0.1, 0.15])
    assert np.allclose(CD.bspline(K, np.ones((7, 4)) * [0.1, 0.2, 0.3, 0.9], 2, 0.07), [0.1, 0.2, 0.3, 0.9])
    rng = np.random.default_rng(3)
    C = rng.random((7, 3))
    assert np.allclose(CD.bspline(K, C, 2, 0.0), C[0]) and np.allclose(CD.bspline(K, C, 2, 0.15), C[-1])
    for k in K[1:-1]:
        assert np.allclose(CD.bspline(K, C, 2, k - 1e-9), CD.bspline(K, C, 2, k + 1e-9), atol=1e-6)
    lo = C.min(0) - 1e-12
    hi = C.max(0) + 1e-12
    for t in np.linspace(0, 0.15, 61):                                   # convex hull of the controls
        v = CD.bspline(K, C, 2, t)
        assert np.all(v >= lo) and np.all(v <= hi)
    curve = ('K32fC32f', 2, K, C)
    assert np.allclose(CD.sample(curve, 0.05, 'knots'), CD.bspline(K, C, 1, 0.05))


def test_local_matrix_maps_engine_keys_to_the_converter_frame():
    s = np.sqrt(0.5)
    M = CD.local_matrix([0, s, 0, s], [0.0, 2.54, 0.0], np.eye(3))      # 90 deg about engine y (up), 1 unit up
    assert np.allclose(M[:3, :3], [[0, -1, 0], [1, 0, 0], [0, 0, 1]], atol=1e-12)   # the oprichnik root at key 0
    assert np.allclose(M[3, :3], [0, 0, 1])
    S = np.diag([1.2, 1.0, 1.0])
    R = CD.q2m(np.array([0, s, 0, s])).T
    M = CD.local_matrix([0, s, 0, s], [0, 0, 0], S)
    assert np.allclose(M[:3, :3], U.A @ (R @ S) @ U.A.T)                # rotation then scale-shear, the converter's order
    assert np.isclose(np.linalg.det(M[:3, :3]), 1.2)


def test_decoded_text_reads_in_pose_sim(tmp_path):
    sys.path.insert(0, str(HERE.parents[1] / 'aoe3de-unit-animation' / 'scripts'))
    import pose_sim
    keys = [CD.local_matrix([0, 0, 0, 1], [0, 0, 0], np.eye(3)), CD.local_matrix([0, 0, np.sqrt(0.5), np.sqrt(0.5)],
                                                                                [1.0, 0, 0], np.eye(3))]
    res = dict(keys=2, fps=192, group='Bip01_Root', tracks=[('Bip01 Pelvis', keys)])
    p = tmp_path / 'clip.gxo'
    p.write_text(CD.gxo_text(res))
    assert p.read_text().splitlines()[:3] == ['a 2 192', 'cg "Bip01_Root"', 'c "Bip01 Pelvis"']
    k1 = pose_sim.parse_anim(p, 1)['Bip01_Pelvis']                       # the engine's space = underscore rule
    assert np.allclose(k1, keys[1], atol=1e-8)
    assert pose_sim.bad_tracks({'Bip01_Pelvis': k1}, [{'name': 'Bip01_Pelvis'}]) == []


# ---------------------------------------------------------------- vanilla archive

@pytest.fixture(scope='module')
def vanilla(tmp_path_factory):
    if not GAME:
        pytest.skip('no AoE3 DE game archives')
    d = tmp_path_factory.mktemp('vanilla')
    idx = U.game_index()
    paths = U.fetch([IRON, YAB, IRON.replace('.gr2', '.material.XMB'),
                     'Art/units/asians/chinese/iron_flail/textures/iron_rider_0_mata_Details.ddt'] + CLIPS, d, idx)
    return dict(zip(['iron', 'yab', 'iron_mat', 'iron_details', 'clip_a', 'clip_idle'], paths)), d


@needs_game
def test_census_reproduces_the_full_table_rows(vanilla):
    v, _ = vanilla
    r = MU.measure(U.Model(v['iron']))
    assert (r['gpu_verts'], r['welded'], r['unique_positions'], r['tris'], len(r['meshes']), r['mat_slots'],
            r['skeleton_bones'], len(r['weighted_bones']), r['max_infl'], r['mean_infl']) == \
        (985, 976, 694, 1328, 2, 2, 32, 23, 4, 1.419)
    assert r['hist'] == {1: 633, 2: 295, 3: 53, 4: 4}
    y = MU.measure(U.Model(v['yab']))
    assert (y['gpu_verts'], y['welded'], y['unique_positions'], y['tris'], y['skeleton_bones'], len(y['weighted_bones']),
            y['max_infl'], y['mean_infl']) == (779, 765, 590, 1110, 30, 18, 3, 1.363)
    assert MU.material_text(v['iron']) == 'mata 4 @1024 (default); matb 3 @1024 (default)'


@needs_game
def test_vertex_fill_reproduces_splits_and_weight_storage(vanilla):
    v, _ = vanilla
    body, whip = VF.measure(U.Model(v['iron']))
    assert body['splits']['split_positions'] == {'uv': 94, 'normal': 58, 'normal+uv': 30}
    assert body['splits']['welded'] == 829 and whip['splits']['welded'] == 147
    w = body['weights']
    assert w['sums'] == {255: 838} and w['dup_bone'] == 0 and w['descending'] == 838 and w['min_weight'] == 10
    assert body['colour_top'] == [[[255, 255, 255, 255], 838]] and body['normal_w'] == {127: 838}
    yb = VF.measure(U.Model(v['yab']))[0]['weights']
    assert yb['min_weight'] == 1 and yb['under5'] == 14


@needs_game
def test_joint_metrics_reproduce_bind_rings_and_blends(vanilla):
    v, _ = vanilla
    iron, yab = U.Model(v['iron']), U.Model(v['yab'])
    b = JM.bind(iron)
    assert (b['l']['hip'], b['r']['hip'], b['l']['knee'], b['l']['elbow'], b['l']['arm_from_down'], b['thigh_spread']) == \
        (8.3, 8.1, 0.1, 26.5, 26.2, 16.4)
    by = JM.bind(yab)
    assert (by['l']['hip'], by['l']['knee'], by['thigh_spread'], by['root'][1]) == (5.4, 8.1, 7.2, 1.1418)
    s = JM.segments(iron)
    assert s['l thigh -> l calf'] == 0.506 and s['l upperarm -> l forearm'] == 0.304 and s['spine1 -> head'] == 0.328
    ri, ry = JM.joint_rings(iron), JM.joint_rings(yab)
    assert ri['knee l']['row_weights'] == [0.34, 0.43, 0.71] and ri['elbow l']['rings'] == []
    assert ry['knee l']['row_weights'] == [0.4, 0.45, 0.75, 0.8] and ry['elbow l']['row_weights'] == [0.5]
    bl = JM.blends(iron)
    assert bl['knee l'] == {'positions': 28, 'median_minor': 0.42} and bl['elbow l']['positions'] == 10
    assert bl['head-chest']['positions'] == 38
    ax = JM.axes(iron)['iron_rider_0Shape']                             # thighs and calves near vertical: standing
    assert ax['Bip01_L_Thigh']['deg_from_vertical'] == 17.7 and ax['Bip01_L_Calf']['deg_from_vertical'] == 18.2


@needs_game
def test_shape_metrics_reproduce_shells_symmetry_hands_and_texel_density(vanilla):
    v, _ = vanilla
    m = U.Model(v['iron'])
    body = m.meshes[0]
    sh = SM.shells(body)
    assert sh['boundary_edges'] == 49 and sh['edges_over_2_faces'] == 1 and sh['largest'][0] == 1096
    assert SM.symmetry(body)['mirrored']['X'] > 95
    assert abs(SM.uv(body, 1024)['texel_density'] - 356.3) < 0.2 and SM.uv(body, 1024)['negative_winding'] == 0
    h = SM.hands(m)
    assert h['l']['tris'] == h['r']['tris'] == 52
    assert SM.seat(body) == dict(tris=1182, pelvis_thigh=172, seat_down=12, inner_thigh=30, share=3.6)
    assert SM.seat(U.Model(v['yab']).meshes[0])['seat_down'] == 6                # the mount-covered faces are kept


@needs_game
def test_track_coverage_shows_the_flail_chain_needs_the_iron_skeleton(vanilla):
    v, _ = vanilla
    clips = TC.tracks(v['clip_a']) + TC.tracks(v['clip_idle'])
    iron = TC.coverage(U.Model(v['iron']), clips)
    yab = TC.coverage(U.Model(v['yab']), clips)
    assert iron['fully_covered'] == 2 and not iron['orphan_tracks']
    assert set(yab['orphan_tracks']) == CHAIN and yab['fully_covered'] == 0
    assert all(rot and pos for _, rot, pos in iron['root_track'])     # the clips key the root: rest height is moot


@needs_game
def test_decoded_attack_clip_is_a_pose_at_every_key_and_reaches_the_recorded_extremes(vanilla):
    v, d = vanilla
    res = CD.decode(v['clip_a'])
    assert (res['keys'], res['fps'], len(res['tracks'])) == (289, 192, 32)
    assert res['formats'] == {'K32fC32f deg 2': 96} and res['ss_keys'] == 0
    for name, keys in res['tracks']:
        for M in keys:
            R = M[:3, :3]
            assert np.allclose(R @ R.T, np.eye(3), atol=1e-6), name    # every key a rotation (the converter's drift)
    clav = dict(res['tracks'])['Bip01_L_Clavicle']
    assert max(np.abs(M - clav[0]).max() for M in clav) < 1e-5           # a constant curve (controls within 4e-6)
    out = d / 'decoded'
    CD.main([str(v['clip_a']), '--out-dir', str(out)])
    bones = CA.load_bones(v['iron'])
    rows = CA.clip_rows(bones, out / (v['clip_a'].stem + '.gxo'))
    ext = CA.extremes(rows)
    assert ext['hipflex_r'] == (105.2, 133) and ext['knee_l'] == (87.4, 209) and ext['knee_r'] == (85.2, 201)
    assert ext['spine_bend'] == (57.7, 139) and ext['elbow_r'] == (111.2, 130)
    assert ext['arm_from_down_r'] == (115.0, 125) and ext['arm_from_down_l'] == (80.9, 134)
    f0 = {k: round(rows[0][k], 1) for k in ('hipflex_l', 'hipflex_r', 'knee_l', 'elbow_l', 'elbow_r', 'thigh_spread')}
    assert f0 == dict(hipflex_l=53.0, hipflex_r=56.6, knee_l=49.4, elbow_l=51.7, elbow_r=55.0, thigh_spread=62.9)


@needs_game
def test_details_coverage_of_the_iron_rider_page(vanilla, capsys):
    v, _ = vanilla
    TP.main(['details', str(v['iron_details'])])
    out = capsys.readouterr().out
    assert re.search(r'R>200\s+33\.3%', out) and 'meanG   0.0' in out


# ---------------------------------------------------------------- Blender round trip

BLENDER = TG.blender_exe()


def needs_blender(f):
    return pytest.mark.local('steam')(pytest.mark.skipif(not (GAME and BLENDER),
                                                         reason='needs the game archives and a background Blender')(f))


def gxo_keyset(m):
    out = set()
    for p, t, w in zip(m['v'], m['vt'], m['vw']):
        ws = tuple(sorted((m['mb'][int(w[4 + k]) - 1], round(w[k] * 255)) for k in range(4) if w[k] > 0))
        out.add((tuple(np.round(p, 4)), tuple(np.round(t, 4)), ws))
    return out


def gr2_keyset(me):
    P = U.to_gxo_point(me.pos)
    UVc = me.comps['TextureCoordinates0'].astype(float)
    out = set()
    for i, w in enumerate(me.vertex_weights()):
        ws = tuple(sorted((b, round(x * 255)) for b, x in w.items()))
        out.add((tuple(np.round(P[i], 4)), tuple(np.round([UVc[i][0], 1 - UVc[i][1]], 4)), ws))
    return out


def oriented(tris, P):
    out = set()
    for f in tris:
        q = [tuple(np.round(P[i], 4)) for i in f]
        k = q.index(min(q))
        out.add(tuple(q[k:] + q[:k]))
    return out


@needs_blender
def test_donor_scene_round_trips_through_rig_table_to_the_donors_data(vanilla):
    v, d = vanilla
    sys.path.insert(0, str(HERE.parents[1] / 'aoe3de-unit-animation' / 'scripts'))
    import pose_sim
    blend, gxo = d / 'donor.blend', d / 'donor_rt.gxo'
    r = subprocess.run([BLENDER, '-b', '--factory-startup', '--python-exit-code', '1', '--python',
                        str(SCRIPTS / 'donor_to_blend.py'), '--', str(v['iron']), str(blend)],
                       capture_output=True, text=True, errors='replace', timeout=600)
    assert r.returncode == 0, (r.stdout + r.stderr)[-3000:]
    assert '32 bones (23 deforming: weighted)' in r.stdout
    r = subprocess.run([BLENDER, '-b', str(blend), '--factory-startup', '--python-exit-code', '1', '--python',
                        str(U.ROOT / 'scripts' / 'havok' / 'rig_table.py'), '--', str(gxo), '--skinned', '--objects',
                        'REF_iron_rider_0Shape', 'REF_iron_rider_0_whipShape', '--scale', '0.393700787', '--quantize'],
                       capture_output=True, text=True, errors='replace', timeout=600)
    assert r.returncode == 0, (r.stdout + r.stderr)[-3000:]
    m = U.Model(v['iron'])
    bones, meshes = pose_sim.parse_model(gxo)
    assert [b['name'] for b in bones] == [b['name'] for b in m.skeleton]
    assert [b['parent'] for b in bones] == [b['parent'] for b in m.skeleton]
    assert max(np.abs(b['W0'] - U.to_gxo_matrix(s['world'])).max() for b, s in zip(bones, m.skeleton)) < 2e-5
    for g, me in zip(meshes, m.meshes):
        assert len(g['v']) == me.welded_count()                         # 829 and 147: split only at UV / normal seams
        assert gxo_keyset(g) == gr2_keyset(me)
        P = U.to_gxo_point(me.pos)
        assert oriented([[i - 1 for i in f] for f in g['f']], np.array(g['v'])) == oriented(me.tris[:, ::-1], P)
        assert np.allclose(pose_sim.skin(bones, pose_sim.pose(bones, {}), g), g['v'], atol=1e-5)


@needs_blender
def test_stored_tangents_are_mikktspace_with_blenders_uv_convention(vanilla, tmp_path):
    v, _ = vanilla
    res = TG.main([str(v['iron']), '--work', str(tmp_path)])
    body = res[0]
    assert body['v']['tangent_dot_median'] > 0.999 and body['v']['sign_agree'] > 0.97
    assert body['1-v']['sign_agree'] < 0.05
    out = json.loads((tmp_path / 'mikk_compare.json').read_text(encoding='utf-8'))      # the generic tool's report
    assert out['tool'] == 'tangent_compare' and out['results'][0]['mesh'] == 'iron_rider_0Shape'
