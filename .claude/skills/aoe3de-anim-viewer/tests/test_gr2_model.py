"""aoe3de-anim-viewer model reader (scripts/gr2_model.py): header sniffing, the unavailable record, the skeleton with its
transform flags, raw vertex streams, indices, material and bone bindings.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_gr2_model.py -q      # CI: add -m "not local"

The synthetic cases build their gr2 bytes inside the test (tests/gr2_synth.py) and need Python, numpy and the
consumer's GR2 reader (scripts/havok/gr2_read.py, reached through aoe3de-unit-model's unit_gr2; without it the module is
skipped). The vanilla cases read the retail archives in memory (aoe3de-bar-archives' bartool; AOE3DE_GAME or the
Steam folder), carry the consumer's `local("steam")` marker (CI deselects them) and skip where no install is found.
Nothing is written outside pytest's temp folder: the viewer cache is redirected there (AOP_ANIM_VIEWER_CACHE).
"""
import struct
import sys
from functools import lru_cache
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402
try:
    import gr2_model as GM  # noqa: E402
except ImportError as e:                       # no consumer GR2 reader (a public export)
    pytest.skip(str(e), allow_module_level=True)
import gr2_synth as S  # noqa: E402
import unit_gr2 as U  # noqa: E402  (on sys.path through gr2_model)


@pytest.fixture(autouse=True)
def cache_in_tmp(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))
    return tmp_path / 'cache'


SKINNED = [('Position', 'real32', 3), ('Normal', 'binormal_int8', 4), ('Tangent', 'binormal_int8', 4),
           ('DiffuseColor0', 'normal_uint8', 4), ('TextureCoordinates0', 'real32', 2), ('BoneWeights', 'normal_uint8', 4),
           ('BoneIndices', 'uint8', 4)]
STATIC = [('Position', 'real32', 3), ('Normal', 'binormal_int8', 3), ('BasicStaticPackedData0', 'uint8', 1),
          ('Tangent', 'binormal_int8', 3), ('BasicStaticPackedData1', 'uint8', 1), ('TextureCoordinates0', 'real16', 2)]


def skeleton():
    """root: flags 2 (orientation only) with a stored position and a scale-shear 3e-7 off the identity, as vanilla
    iron_rider_0's root; pelvis: flags 3 with stored scale-shear 4e-4 off the identity, as the vanilla horse; spine:
    flags 7 with real scale-shear."""
    return [
        {'name': 'Bip01_Root', 'parent': -1,
         'transform': S.transform((5, 6, 7), S.axis_quat((0, 1, 0), 90), (0.9999997, 0, 0, 0, 1, 0, 0, 0, 0.9999997),
                                  flags=2)},
        {'name': 'Bip01_Pelvis', 'parent': 0,
         'transform': S.transform((0.0, 1.1, 0.2), S.axis_quat((1, 0, 0), -90), (1.0004, 0, 0, 0, 1, 0, 0, 0, 0.9996),
                                  flags=3)},
        {'name': 'Bip01_Spine', 'parent': 1,
         'transform': S.transform((0.12, 0, 0.01), S.axis_quat((0, 0, 1), 20), (1.1, 0.05, 0, 0, 0.95, 0, 0, 0.02, 1.2),
                                  flags=7)},
    ]


def skinned_mesh(n=6, name='bodyShape', indices16=False, materials=('mata',), groups=None,
                 bone_names=('Bip01_Root', 'Bip01 Pelvis', 'bip01_spine')):
    rng = np.random.default_rng(7)
    cols = {'Position': rng.uniform(-1, 2, (n, 3)).astype(np.float32),
            'Normal': rng.integers(-127, 128, (n, 4)).astype(np.int8),
            'Tangent': np.column_stack([rng.integers(-127, 128, (n, 3)), np.where(np.arange(n) % 2, 127, -127)]
                                       ).astype(np.int8),
            'DiffuseColor0': np.full((n, 4), 255, np.uint8),
            'TextureCoordinates0': rng.uniform(0, 1, (n, 2)).astype(np.float32),
            'BoneWeights': np.tile(np.array([200, 55, 0, 0], np.uint8), (n, 1)),
            'BoneIndices': (np.arange(n * 4).reshape(n, 4) % 3).astype(np.uint8)}
    tris = [(i, (i + 1) % n, (i + 2) % n) for i in range(n - 2)]
    return {'name': name, 'members': SKINNED, 'columns': cols, 'indices': [x for t in tris for x in t],
            'indices16': indices16, 'groups': groups or [(0, 0, len(tris))], 'materials': list(materials),
            'bone_names': list(bone_names)}


def static_mesh(n=4):
    cols = {'Position': np.arange(n * 3, dtype=np.float32).reshape(n, 3) + 10,
            'Normal': np.tile(np.array([-126, 8, 5], np.int8), (n, 1)),
            'BasicStaticPackedData0': np.full((n, 1), 255, np.uint8),
            'Tangent': np.tile(np.array([0, 0, 127], np.int8), (n, 1)),
            'BasicStaticPackedData1': np.full((n, 1), 255, np.uint8),
            'TextureCoordinates0': np.linspace(0, 1, n * 2).reshape(n, 2).astype(np.float16)}
    return {'name': 'propShape', 'members': STATIC, 'columns': cols, 'indices': [0, 1, 2, 2, 1, 3], 'indices16': True,
            'groups': [(0, 0, 2)], 'materials': ['matb'], 'bone_names': ['Bip01_Spine']}


def build(**kw):
    meshes = kw.pop('meshes', None) or [skinned_mesh(), static_mesh()]
    return S.build_model(kw.pop('bones', None) or skeleton(), meshes, **kw)


def record(data, **kw):
    w = C.BufferWriter('geo')
    rec, warnings = GM.model_record(data, w, model_id=kw.pop('model_id', 'units/test/x.gr2'), **kw)
    return rec, warnings, w


def test_unbound_donor_mesh_is_excluded_by_pointer_not_name():
    donor = skinned_mesh(name='sameShape')
    owned = skinned_mesh(name='sameShape')
    donor['columns']['Position'] += 1000
    data = build(meshes=[donor, owned], mesh_bindings=[1])
    rec, warnings, writer = record(data)
    assert len(rec['meshes']) == 1
    assert rec['bounds']['max'][0] < 10
    assert any(w['code'] == 'gr2-unbound-meshes-excluded' for w in warnings)
    pos = rec['meshes'][0]['streams']['Position']['view']
    np.testing.assert_array_equal(C.read_view(writer.data(), pos), owned['columns']['Position'])


def test_explicitly_empty_mesh_bindings_draw_nothing():
    rec, warnings, writer = record(build(mesh_bindings=[]))
    assert rec['meshes'] == [] and rec['bounds'] is None


# ---------------------------------------------------------------- header sniffing and unavailable files
def test_sniff_reads_pointer_size_format_and_compression():
    info = GM.sniff(build())
    assert (info['pointer_size'], info['format'], info['version'], info['compression'], info['reason']) == \
        (64, 7, 7, 'none', None)
    for code, name in ((1, 'oodle0'), (2, 'oodle1'), (4, 'bitknit'), (9, 'unknown-9')):
        info = GM.sniff(build(compression=code))
        assert info['compression'] == name and info['reason'] == 'gr2-compressed-' + name
    info = GM.sniff(build(magic=S.MAGIC32))
    assert (info['pointer_size'], info['format'], info['reason']) == (32, 7, 'gr2-32bit')
    info = GM.sniff(build(magic=S.MAGIC32_V6))
    assert (info['pointer_size'], info['format'], info['reason']) == (32, 6, 'gr2-32bit')
    info = GM.sniff(build(magic=S.MAGIC32, compression=2))
    assert info['reason'] == 'gr2-compressed-oodle1' and info['pointer_size'] == 32
    assert GM.sniff(b'\x01' * 64)['reason'] == 'gr2-bad-magic'
    data = build()
    assert GM.sniff(data[:20])['reason'] == 'gr2-truncated'
    assert GM.sniff(data[:-200])['reason'] == 'gr2-truncated'


@pytest.mark.parametrize('kw, reason, code', [
    ({'compression': 2}, 'gr2-compressed-oodle1', 'gr2-compressed'),
    ({'compression': 4}, 'gr2-compressed-bitknit', 'gr2-compressed'),
    ({'magic': S.MAGIC32}, 'gr2-32bit', 'gr2-32bit'),
])
def test_an_undecodable_file_gives_the_unavailable_record_and_writes_nothing(kw, reason, code):
    rec, warnings, w = record(build(**kw))
    assert rec['decodable'] is False and rec['unavailable_reason'] == reason
    assert rec['id'] == rec['path'] == 'units/test/x.gr2' and rec['meshes'] == [] and rec['skeleton'] is None
    assert rec['root'] == GM.ROOT16 and rec['pointer_size'] == (32 if 'magic' in kw else 64)
    assert [x['code'] for x in warnings] == [code] and reason in warnings[0]['message']
    assert w.data() == b''
    C.json_text(rec)


def test_a_broken_structure_is_reported_not_raised():
    data = bytearray(build())
    struct.pack_into('<I', data, 32 + 32, 0x00FFFFF0)          # root object offset far past the section
    rec, warnings, w = record(bytes(data))
    assert rec['decodable'] is False and rec['unavailable_reason'] == 'gr2-parse-failed'
    assert warnings[0]['code'] == 'gr2-parse-failed' and w.data() == b''
    with pytest.raises(GM.Gr2Unavailable) as e:
        GM.read_model(bytes(data))
    assert e.value.reason == 'gr2-parse-failed'


# ---------------------------------------------------------------- skeleton
def test_rest_is_the_flags_applied_transform_and_composes_to_the_stored_inverse_world():
    bones = skeleton()
    data = build(bones=bones)
    rec, warnings, _ = record(data)
    assert warnings == [] and rec['decodable'] and rec['root_count'] == 1 and rec['root'] == GM.ROOT16
    out = rec['skeleton']['bones']
    assert [b['name'] for b in out] == ['Bip01_Root', 'Bip01_Pelvis', 'Bip01_Spine'] and rec['skeleton']['name'] \
        == 'Bip01_Root'
    assert [b['parent'] for b in out] == [-1, 0, 1] and [b['flags'] for b in out] == [2, 3, 7]
    assert out[0]['rest']['position'] == [0.0, 0.0, 0.0]                     # flag 1 clear: the stored 5, 6, 7 ignored
    assert out[0]['rest']['scale_shear'] == GM.IDENTITY_SS and out[1]['rest']['scale_shear'] == GM.IDENTITY_SS
    assert np.allclose(out[1]['rest']['position'], [0, 1.1, 0.2], atol=1e-7)
    f32 = lambda v: [float(np.float32(x)) for x in v]                        # noqa: E731
    assert out[2]['rest']['scale_shear'] == f32(bones[2]['transform'][8:17])
    m = GM.read_model(data)
    assert m.bones[1]['raw']['scale_shear'][0] == float(np.float32(1.0004))    # the stored numbers stay readable
    expect_iw = [np.linalg.inv(W) for W in S.compose(bones)]
    for b, iw in zip(out, expect_iw):
        assert b['inverse_world'] == f32(iw.ravel())                         # the 16 stored numbers
    assert np.abs(m.rest_world() - np.linalg.inv(m.inverse_world())).max() < 1e-6
    raw = GM.compose_world(np.array([GM.local_matrix({k: b['raw'][k] for k in ('position', 'orientation',
                                                                                 'scale_shear')}) for b in m.bones]),
                           m.parents)
    assert np.abs(raw - np.linalg.inv(m.inverse_world())).max() > 1e-4    # why the flags matter (the vanilla horse)


def test_local_matrix_is_rotation_then_scale_shear_in_row_vectors():
    tr = {'position': [1.0, 2.0, 3.0], 'orientation': list(S.axis_quat((0, 0, 1), 90)),
          'scale_shear': [2.0, 0, 0, 0, 1.0, 0, 0, 0, 1.0]}
    L = GM.local_matrix(tr)
    assert np.allclose(L[:3, :3], S.quat_matrix(tr['orientation']) @ np.diag([2.0, 1, 1]))
    assert np.allclose(np.array([1.0, 0, 0, 1]) @ L, [1.0, 3.0, 3.0, 1.0])  # x turns to y, y is not scaled (S then
    #                                                                        R would scale x first: 1, 4, 3)
    assert np.allclose(L[3, :3], [1, 2, 3])


def test_two_roots_another_basis_and_extra_skeletons_warn():
    bones = skeleton() + [{'name': 'bone_extra_root', 'parent': -1, 'transform': S.transform(flags=0)}]
    tool = dict(S.VANILLA_ART_TOOL, RightVector=[1, 0, 0])
    rec, warnings, _ = record(build(bones=bones, art_tool=tool, extra_skeletons=1))
    codes = sorted(x['code'] for x in warnings)
    assert codes == ['gr2-basis-differs', 'gr2-multiple-skeletons', 'gr2-two-roots'] and rec['root_count'] == 2
    assert 'bone_extra_root' in next(x for x in warnings if x['code'] == 'gr2-two-roots')['message']


# ---------------------------------------------------------------- meshes
def test_every_vertex_member_is_its_own_stream_with_the_stored_bytes():
    meshes = [skinned_mesh(), static_mesh()]
    rec, warnings, w = record(build(meshes=meshes))
    geo = w.data()
    expect = {'real32': ('f32', 'float', False), 'binormal_int8': ('i8', 'snorm', True),
              'normal_uint8': ('u8', 'unorm', True), 'uint8': ('u8', 'uint', False), 'real16': ('f16', 'float', False)}
    for src, out in zip(meshes, rec['meshes']):
        lay, stride, _ = S.vertex_layout(src['members'])
        interleaved, _, _ = S.pack_vertices(src['members'], src['columns'])
        n = len(src['columns']['Position'])
        assert out['vertex_count'] == n and list(out['streams']) == [x[0] for x in src['members']]
        for name, tname, count, off in lay:
            st = out['streams'][name]
            size = st['view']['byteLength'] // n
            stored = b''.join(interleaved[i * stride + off:i * stride + off + size] for i in range(n))
            got = C.read_view(geo, st['view'])
            assert got.tobytes() == stored, name
            assert (st['view']['dtype'], st['decode'], st['view']['normalized']) == expect[tname], name
            assert st['gr2_type'] == tname and st['view']['components'] == count and st['view']['count'] == n
            assert st['view']['byteOffset'] % C.BUFFER_ALIGN == 0
    tangent = C.read_view(geo, rec['meshes'][0]['streams']['Tangent']['view'])
    assert sorted(set(tangent[:, 3].tolist())) == [-127, 127]                # the bitangent sign survives
    assert [x[3] for x in S.vertex_layout(STATIC)[0]] == [0, 12, 15, 16, 19, 20]   # the vanilla static packing
    assert warnings == []


def test_indices_keep_their_stored_width_and_values():
    m16, m32 = skinned_mesh(indices16=True, name='a'), skinned_mesh(indices16=False, name='b')
    rec, _, w = record(build(meshes=[m16, m32]))
    geo = w.data()
    for src, out, dtype in zip((m16, m32), rec['meshes'], ('u16', 'u32')):
        assert out['indices']['dtype'] == dtype and out['indices']['components'] == 1
        assert C.read_view(geo, out['indices']).tolist() == src['indices']
        assert out['triangle_count'] == len(src['indices']) // 3


def test_groups_name_material_bindings_and_bone_bindings_follow_the_engine_name_rule():
    mesh = skinned_mesh(n=8, materials=('mata', 'matb'), groups=[(0, 0, 4), (1, 4, 2), (5, 6, 0)],
                        bone_names=('bip01_root', 'Bip01 Pelvis', 'BIP01_SPINE', 'Bip01_Tail'))
    rec, warnings, _ = record(build(meshes=[mesh]), material_file='units/test/x.material')
    out = rec['meshes'][0]
    assert out['groups'] == [
        {'material': 'units/test/x.material#mata', 'material_binding': 'mata', 'first_triangle': 0, 'triangle_count': 4},
        {'material': 'units/test/x.material#matb', 'material_binding': 'matb', 'first_triangle': 4, 'triangle_count': 2},
        {'material': None, 'material_binding': None, 'first_triangle': 6, 'triangle_count': 0}]
    assert out['bone_bindings'] == [{'name': 'bip01_root', 'bone': 0}, {'name': 'Bip01 Pelvis', 'bone': 1},
                                    {'name': 'BIP01_SPINE', 'bone': 2}, {'name': 'Bip01_Tail', 'bone': -1}]
    assert sorted(x['code'] for x in warnings) == ['bone-unresolved', 'material-unbound']
    rec2, _, _ = record(build(meshes=[skinned_mesh()]))
    assert rec2['meshes'][0]['groups'][0]['material'] is None                # no .material named: left to the caller


def test_bounds_cover_every_mesh():
    meshes = [skinned_mesh(), static_mesh()]
    rec, _, _ = record(build(meshes=meshes))
    P = np.vstack([mm['columns']['Position'].astype(np.float64) for mm in meshes])
    assert rec['bounds'] == {'min': P.min(0).tolist(), 'max': P.max(0).tolist()}


def test_a_path_and_bytes_give_the_same_record_and_no_temp_copy_remains(tmp_path, cache_in_tmp):
    data = build()
    p = tmp_path / 'x.gr2'
    p.write_bytes(data)
    a, wa, ga = record(data)
    b, wb, gb = record(p)
    assert C.canonical_json(a) == C.canonical_json(b) and wa == wb and ga.data() == gb.data()
    assert not list((cache_in_tmp / 'tmp').glob('*'))
    assert C.json_text(a)                                                    # plain JSON, no NaN, no numpy types


def test_a_bad_crc_warns_but_the_model_still_reads():
    data = bytearray(build())
    i = data.index(b'synthetic.mb')
    data[i] = ord('S')                                                       # a string byte: the structure is intact
    rec, warnings, _ = record(bytes(data))
    assert rec['decodable'] and [x['code'] for x in warnings] == ['gr2-crc-mismatch']


# ---------------------------------------------------------------- vanilla (the owner's machine)
@lru_cache(maxsize=1)
def game():
    try:
        return U.game_index()
    except (FileNotFoundError, ImportError, OSError):
        return None


def needs_game(f):
    return pytest.mark.local('steam')(f)


def vanilla(rel):
    g = game()
    if g is None:
        pytest.skip('no AoE3 DE game archives (AOE3DE_GAME or the Steam folder)')
    bartool, idx = g
    return bartool.read_entry(idx[rel.lower()])


IRON_RIDER = 'art/units/asians/chinese/iron_flail/iron_rider_0.gr2'
IRON_HORSE = 'art/units/asians/chinese/iron_flail/iron_flail_horse_0.gr2'


@needs_game
def test_iron_rider_0_reads_byte_for_byte_with_its_skeleton_and_bindings(tmp_path):
    data = vanilla(IRON_RIDER)
    rec, warnings, w = record(data, model_id='units/asians/chinese/iron_flail/iron_rider_0.gr2',
                              material_file='units/asians/chinese/iron_flail/iron_rider_0.material')
    assert warnings == [] and rec['decodable'] and rec['compression'] == 'none' and rec['pointer_size'] == 64
    bones = rec['skeleton']['bones']
    assert len(bones) == 32 and rec['skeleton']['name'] == 'Bip01_Root' and rec['root_count'] == 1
    assert [(x['name'], x['vertex_count'], x['triangle_count']) for x in rec['meshes']] == \
        [('iron_rider_0Shape', 838, 1182), ('iron_rider_0_whipShape', 147, 146)]
    assert [x['groups'][0]['material'] for x in rec['meshes']] == \
        ['units/asians/chinese/iron_flail/iron_rider_0.material#mata',
         'units/asians/chinese/iron_flail/iron_rider_0.material#matb']
    assert all(b['bone'] >= 0 for x in rec['meshes'] for b in x['bone_bindings'])
    assert [len(x['bone_bindings']) for x in rec['meshes']] == [18, 5]
    geo = w.data()
    p = tmp_path / 'iron_rider_0.gr2'
    p.write_bytes(data)
    um = U.Model(p)                                                          # aoe3de-unit-model's reader, independent
    for me, out in zip(um.meshes, rec['meshes']):
        assert list(out['streams']) == [x[0] for x in me.layout]
        for name, arr in me.comps.items():
            assert C.read_view(geo, out['streams'][name]['view']).tobytes() == arr.tobytes(), name
        assert out['indices']['dtype'] == 'u32' and np.array_equal(C.read_view(geo, out['indices']), me.tris.ravel())
    tangent = C.read_view(geo, rec['meshes'][0]['streams']['Tangent']['view'])
    assert tangent.shape == (838, 4) and sorted(set(tangent[:, 3].tolist())) == [-127, 127]
    m = GM.read_model(data)
    assert np.abs(m.rest_world() - np.linalg.inv(m.inverse_world())).max() < 1e-6     # 6.2e-7 measured


@needs_game
def test_iron_flail_horse_needs_its_transform_flags_and_keeps_the_static_packing():
    data = vanilla(IRON_HORSE)
    rec, warnings, w = record(data, model_id='units/asians/chinese/iron_flail/iron_flail_horse_0.gr2')
    assert warnings == [] and rec['decodable'] and rec['skeleton']['name'] == 'root_x'
    assert len(rec['skeleton']['bones']) == 32 and rec['root_count'] == 1
    assert [(x['name'], x['vertex_count'], x['triangle_count']) for x in rec['meshes']] == \
        [('iron_flail_horse_0Shape', 3771, 1326), ('iron_flail_horse_0_1Shape', 39, 20)]
    static = rec['meshes'][1]['streams']
    assert [(k, v['gr2_type'], v['view']['components']) for k, v in static.items()] == [
        ('Position', 'real32', 3), ('Normal', 'binormal_int8', 3), ('BasicStaticPackedData0', 'uint8', 1),
        ('Tangent', 'binormal_int8', 3), ('BasicStaticPackedData1', 'uint8', 1), ('TextureCoordinates0', 'real16', 2)]
    assert len(rec['meshes'][1]['bone_bindings']) == 1                       # a rigid mesh on one bone
    m = GM.read_model(data)
    IW = np.linalg.inv(m.inverse_world())
    assert np.abs(m.rest_world() - IW).max() < 1e-6                         # flags applied: 7.5e-7 measured
    raw = GM.compose_world(np.array([GM.local_matrix(b['raw']) for b in m.bones]), m.parents)
    assert np.abs(raw - IW).max() > 1e-4                                    # raw stored numbers: 4.1e-4 measured


@needs_game
@pytest.mark.parametrize('rel, reason', [
    ('art/units/africans/ethiopians/ras/queen_warrior.gr2', 'gr2-compressed-oodle1'),
    ('art/animation_library/cavalry/horse_mount.gr2', 'gr2-compressed-bitknit'),
])
def test_compressed_vanilla_files_are_unavailable_not_crashed(rel, reason):
    rec, warnings, w = record(vanilla(rel), model_id=C.logical_path(rel))
    assert rec['decodable'] is False and rec['unavailable_reason'] == reason
    assert [x['code'] for x in warnings] == ['gr2-compressed'] and w.data() == b''
