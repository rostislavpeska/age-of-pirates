"""skinned_gr2.py (2026-10-11): the donor-preserving writer for NEW skinned unit geometry.

    python -m pytest scripts/havok/tests/test_skinned_gr2.py -q          # CI: -m "not local"

Synthetic cases build their donor inside the test with the anim viewer's Granny writer
(.claude/skills/aoe3de-anim-viewer/tests/gr2_synth.py, vanilla-shaped types defined here) - no game bytes. The local
cases read vanilla iron_rider_0.gr2 from the archives into the test's temp folder (never the repository, AGENTS.md
rule 3) and, where Blender is configured, check the MikkTSpace route against the tangents vanilla stores.
"""
from __future__ import annotations

import struct
import sys
from pathlib import Path

import numpy as np
import pytest

HAVOK = Path(__file__).resolve().parents[1]
REPO = HAVOK.parents[1]
sys.path.insert(0, str(HAVOK))
import skinned_gr2 as S  # noqa: E402
from gr2_fixups import orphan_fixups  # noqa: E402
from gr2_read import Gr2  # noqa: E402
import gr2_lint as L  # noqa: E402

SYNTH = REPO / '.claude' / 'skills' / 'aoe3de-anim-viewer' / 'tests'
IRON = 'art/units/asians/chinese/iron_flail/iron_rider_0.gr2'


def synth():
    if not (SYNTH / 'gr2_synth.py').is_file():
        pytest.skip('gr2_synth.py (aoe3de-anim-viewer tests) not found')
    if str(SYNTH) not in sys.path:
        sys.path.insert(0, str(SYNTH))
    import gr2_synth as G
    return G


def make_donor(path):
    """a vanilla-shaped skinned donor in ONE section (the writer's per-type copy mode): 3 bones, one 40-byte skinned
    mesh, a material with a colour map and a texture record, exporter info and root extended data."""
    G = synth()
    T, m = G.Type, G.m
    tex_layout = T(m('BytesPerPixel', G.INT32), m('ShiftForComponent', G.INT32, 4), m('BitsForComponent', G.INT32, 4))
    texture = T(m('FromFileName', G.STRING), m('TextureType', G.INT32), m('Width', G.INT32), m('Height', G.INT32),
                m('Encoding', G.INT32), m('SubFormat', G.INT32), m('Layout', G.INLINE, 0, tex_layout),
                m('Images', G.REF_TO_ARRAY, 0, G.INT32_ELEM), m('ExtendedData', G.VARIANT_REF))
    material = T()
    mapt = T(m('Usage', G.STRING), m('Map', G.REF, 0, material))
    material.members = [m('Name', G.STRING), m('Maps', G.REF_TO_ARRAY, 0, mapt), m('Texture', G.REF, 0, texture),
                        m('ExtendedData', G.VARIANT_REF)]
    string_elem = T(m('String', G.STRING))
    vdata = T(m('Vertices', G.REF_TO_VARIANT_ARRAY), m('VertexComponentNames', G.REF_TO_ARRAY, 0, string_elem),
              m('VertexAnnotationSets', G.REF_TO_ARRAY, 0, G.INT32_ELEM))
    mbind = T(m('Material', G.REF, 0, material))
    mesh = T(m('Name', G.STRING), m('PrimaryVertexData', G.REF, 0, vdata),
             m('MorphTargets', G.REF_TO_ARRAY, 0, G.INT32_ELEM), m('PrimaryTopology', G.REF, 0, G.TOPOLOGY),
             m('MaterialBindings', G.REF_TO_ARRAY, 0, mbind), m('BoneBindings', G.REF_TO_ARRAY, 0, G.BONE_BINDING),
             m('ExtendedData', G.VARIANT_REF))
    meshref = T(m('Mesh', G.REF, 0, mesh))
    model = T(m('Name', G.STRING), m('Skeleton', G.REF, 0, G.SKELETON), m('InitialPlacement', G.TRANSFORM),
              m('MeshBindings', G.REF_TO_ARRAY, 0, meshref), m('ExtendedData', G.VARIANT_REF))
    exporter = T(m('ExporterName', G.STRING), m('ExporterMajorRevision', G.INT32), m('ExtendedData', G.VARIANT_REF))
    rootext = T(m('FromArtToolName', G.STRING), m('MajorVersion', G.INT32))
    optext = T(m('OptimizerVersion', G.INT32))
    root = T(m('ArtToolInfo', G.REF, 0, G.ART_TOOL), m('ExporterInfo', G.REF, 0, exporter), m('FromFileName', G.STRING),
             m('Textures', G.ARRAY_OF_REFS, 0, texture), m('Materials', G.ARRAY_OF_REFS, 0, material),
             m('Skeletons', G.ARRAY_OF_REFS, 0, G.SKELETON), m('VertexDatas', G.ARRAY_OF_REFS, 0, vdata),
             m('TriTopologies', G.ARRAY_OF_REFS, 0, G.TOPOLOGY), m('Meshes', G.ARRAY_OF_REFS, 0, mesh),
             m('Models', G.ARRAY_OF_REFS, 0, model), m('TrackGroups', G.ARRAY_OF_REFS, 0, G.TRACK_GROUP),
             m('Animations', G.ARRAY_OF_REFS, 0, G.ANIMATION), m('ExtendedData', G.VARIANT_REF))
    w = G.Writer()
    bones = [dict(name='Bip01_Root', parent=-1, transform=G.transform(flags=0)),
             dict(name='Bip01_Spine', parent=0, transform=G.transform((0.0, 1.0, 0.0), flags=1)),
             dict(name='Bip01_Head', parent=1, transform=G.transform((0.0, 0.5, 0.0), flags=1))]
    W = G.compose(bones)
    bvals = [{'Name': b['name'], 'ParentIndex': b['parent'], 'Transform': b['transform'],
              'InverseWorldTransform': list(np.linalg.inv(Wb).ravel()), 'LODError': 3.5} for b, Wb in zip(bones, W)]
    skel = w.obj(G.SKELETON, {'Name': 'Bip01_Root', 'Bones': bvals, 'LODType': 1})
    members = [n[:3] for n in [('Position', 'real32', 3), ('Normal', 'binormal_int8', 4), ('Tangent', 'binormal_int8', 4),
                                ('DiffuseColor0', 'normal_uint8', 4), ('TextureCoordinates0', 'real32', 2),
                                ('BoneWeights', 'normal_uint8', 4), ('BoneIndices', 'uint8', 4)]]
    n = 4
    cols = {'Position': np.array([[0.11, 1.0, 0.0], [0.21, 1.5, 0.0], [0.31, 1.0, 0.1], [0.41, 1.6, 0.2]]),
            'Normal': np.tile([0, 0, 127, 127], (n, 1)), 'Tangent': np.tile([127, 0, 0, 127], (n, 1)),
            'DiffuseColor0': np.full((n, 4), 255), 'TextureCoordinates0': np.array([[0, 0], [1, 0], [0, 1], [1, 1.0]]),
            'BoneWeights': np.tile([255, 0, 0, 0], (n, 1)), 'BoneIndices': np.array([[0] * 4, [1] * 4, [0] * 4, [1] * 4])}
    vbytes, stride, vtype = G.pack_vertices(members, cols)
    assert stride == 40
    vd = w.obj(vdata, {'Vertices': (vtype, n, w.raw(vbytes, 4)),
                       'VertexComponentNames': [{'String': s} for s in ('Position', 'Normal', 'map1')]})
    topo = w.obj(G.TOPOLOGY, {'Groups': [{'MaterialIndex': 0, 'TriFirst': 0, 'TriCount': 2}],
                              'Indices': G.Raw(6, struct.pack('<6i', 0, 1, 2, 2, 1, 3))})
    tex = w.obj(texture, {'FromFileName': 'T:/donor_source/donor_tex.png', 'Encoding': 1,
                          'Layout': {'BytesPerPixel': 4, 'ShiftForComponent': [0, 8, 16, 24],
                                     'BitsForComponent': [8, 8, 8, 8]}})
    filem = w.obj(material, {'Name': 'donor_file9', 'Texture': tex})
    mat = w.obj(material, {'Name': 'donor_mata', 'Maps': [{'Usage': 'color', 'Map': filem}]})
    me = w.obj(mesh, {'Name': 'donor_meshShape', 'PrimaryVertexData': vd, 'PrimaryTopology': topo,
                      'MaterialBindings': [{'Material': mat}],
                      'BoneBindings': [{'BoneName': 'Bip01_Spine', 'OBBMin': [0, 0, 0], 'OBBMax': [1, 1, 1]},
                                       {'BoneName': 'Bip01_Head', 'OBBMin': [0, 0, 0], 'OBBMax': [1, 1, 1]}],
                      'ExtendedData': (optext, w.obj(optext, {'OptimizerVersion': 2}))})
    mo = w.obj(model, {'Name': 'Bip01_Root', 'Skeleton': skel, 'InitialPlacement': G.transform(flags=0),
                       'MeshBindings': [{'Mesh': me}]})
    rt = w.obj(root, {'ArtToolInfo': w.obj(G.ART_TOOL, G.VANILLA_ART_TOOL),
                      'ExporterInfo': w.obj(exporter, {'ExporterName': 'synthetic exporter', 'ExporterMajorRevision': 2}),
                      'FromFileName': 'T:/donor_source/donor.mb', 'Textures': [tex], 'Materials': [filem, mat],
                      'Skeletons': [skel], 'VertexDatas': [vd], 'TriTopologies': [topo], 'Meshes': [me],
                      'Models': [mo], 'Animations': [],
                      'ExtendedData': (rootext, w.obj(rootext, {'FromArtToolName': 'synthetic', 'MajorVersion': 1}))})
    Path(path).write_bytes(w.file(root, rt))
    return Path(path)


GXO = '''mt "our_mat"
b "Bip01_Root" 0 1 0 0 0 1 0 0 0 1 0 0 0
b "Bip01_Spine" 1 1 0 0 0 1 0 0 0 1 0 0 1
b "Bip01_Head" 2 1 0 0 0 1 0 0 0 1 0 0 1.5
m "our_body"
mb "Bip01_Spine"
mb "Bip01_Head"
mm 1
v 0 0 1
vn 0 -1 0
vt 0 0
vw 1 0 0 0 1 1 1 1
v 0.5 0 1
vn 0 -1 0
vt 1 0
vw 0.6 0.4 0 0 1 2 1 1
v 0 0 1.5
vn 0 -1 0
vt 0 1
vw 0.749019608 0.250980392 0 0 2 1 2 2
v 0.5 0 1.5
vn 0 -1 0
vt 1 1
vw 1 0 0 0 2 2 2 2
fg 1
f 1 2 3
f 3 2 4
'''


def write_gxo(tmp_path, text=GXO):
    p = tmp_path / 'model.gxo'
    p.write_text(text, encoding='utf-8')
    return p


# ------------------------------------------------------------------------------------------------- pure parts
def test_from_gxo_maps_the_frame_reverses_corners_and_flips_v(tmp_path):
    ms = S.from_gxo(S.parse_gxo(write_gxo(tmp_path)))
    m = ms[0]
    assert m.name == 'our_body' and m.material == 'our_mat' and m.bones == ['Bip01_Spine', 'Bip01_Head']
    assert np.allclose(m.pos[1], [-0.5, 1.0, 0.0])                     # (-x, z, -y)
    assert np.array_equal(m.nrm[0], [0, 0, 127, 127])                 # GXO -y -> engine +z, w 127
    assert np.allclose(m.uv[2], [0.0, 0.0]) and np.allclose(m.uv[0], [0.0, 1.0])
    assert m.tris.tolist() == [[0, 2, 1], [2, 3, 1]]                 # corner order reversed (det -1 map)
    assert m.w[1].tolist() == [153, 102, 0, 0] and m.bi[1].tolist() == [0, 1, 0, 0]
    assert m.w[2].tolist() == [191, 64, 0, 0] and m.bi[2].tolist() == [1, 0, 1, 1]
    assert S.winding_share(m) == 1.0


def test_refuses_weights_that_are_not_8_bit(tmp_path):
    with pytest.raises(S.WriteError, match='not k/255'):
        S.from_gxo(S.parse_gxo(write_gxo(tmp_path, GXO.replace('vw 0.6 0.4', 'vw 0.61 0.39'))))


def test_check_weights_names_each_offence():
    ok_w, ok_i = np.array([[200, 55, 0, 0]]), np.array([[1, 0, 1, 1]])
    S.check_weights(ok_w, ok_i, 2, 'x')
    for w, i, msg in (([[200, 54, 0, 0]], [[1, 0, 1, 1]], 'sum'), ([[55, 200, 0, 0]], [[1, 0, 1, 1]], 'descending'),
                      ([[200, 55, 0, 0]], [[1, 1, 1, 1]], 'twice'), ([[200, 55, 0, 0]], [[1, 0, 0, 1]], 'slot 0'),
                      ([[255, 0, 0, 0]], [[5, 5, 5, 5]], 'palette')):
        with pytest.raises(S.WriteError, match=msg):
            S.check_weights(np.array(w), np.array(i), 2, 'x')


def test_assign_tangents_splits_a_vertex_whose_corners_disagree(tmp_path):
    m = S.from_gxo(S.parse_gxo(write_gxo(tmp_path)))[0]
    T = np.tile([1.0, 0, 0], (2, 3, 1))
    Sg = np.ones((2, 3))
    out, k = S.assign_tangents(m, T, Sg)
    assert k == 0 and out.n == 4 and np.array_equal(out.tan[:, 3], [127] * 4)
    Sg[1, :] = -1                                                      # face 2 mirrored: vertices 1 and 2 split
    out, k = S.assign_tangents(m, T, Sg)
    assert k == 2 and out.n == 6
    assert out.tan[out.tris[1]][:, 3].tolist() == [-127, -127, -127] and out.tan[out.tris[0]][:, 3].tolist() == [127] * 3
    assert np.allclose(out.pos[4:], m.pos[[1, 2]]) and np.array_equal(out.w[4:], m.w[[1, 2]])


def test_pack_is_the_vanilla_40_byte_vertex(tmp_path):
    m = S.from_gxo(S.parse_gxo(write_gxo(tmp_path)))[0]
    m, _ = S.assign_tangents(m, *S.uv_tangents([m])[0])
    r = np.frombuffer(S.pack(m), np.uint8).reshape(-1, 40)
    assert np.allclose(r[:, 0:12].copy().view('<f4'), m.pos)
    assert (r[:, 15] == 127).all() and (r[:, 20:24] == 255).all() and set(r[:, 19].view(np.int8)) <= {127, -127}
    assert np.allclose(r[:, 24:32].copy().view('<f4'), m.uv) and (r[:, 32:36].astype(int).sum(1) == 255).all()


# ------------------------------------------------------------------------------------------- written files
def test_writes_a_clean_file_around_a_synthetic_donor(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    out = tmp_path / 'out.gr2'
    rep = S.build(donor, write_gxo(tmp_path), out, tangent_fn=S.uv_tangents)
    assert rep['write']['type_section'] == 'copied per type'
    v = rep['verify']
    assert v['crc_ok'] and all(v['skeleton'].values()) and v['orphan_fixups'] == 0 and not v['fails']
    assert [x['layout_vanilla'] for x in v['meshes']] == [True]
    c = rep['clean']
    assert c['clean'] and c['donor_vertex_records_found'] == 0 and c['donor_positions_found'] == 0
    blob = out.read_bytes()
    for s in (b'donor_meshShape', b'donor_mata', b'donor_file9', b'donor_tex.png', b'donor.mb'):
        assert s not in blob
    for s in (b'Bip01_Head', b'synthetic exporter', b'our_body', b'our_mat'):
        assert s in blob
    g = Gr2(str(out))
    assert [s['data_size'] > 0 for s in g.sections] == [True, False, False, True, True, False, True, False]
    info = L.read_raw(out)
    assert [x['name'] for x in info['render']] == ['our_body'] and info['render'][0]['mats'] == ['our_mat']
    assert info['render'][0]['bone_names'] == ['Bip01_Spine', 'Bip01_Head']
    assert rep['donor_bind']['same_names_and_order'] and rep['donor_bind']['joint_max_abs_diff'] < 1e-6


def test_second_generation_copies_the_type_section_verbatim(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    gxo = write_gxo(tmp_path)
    out1, out2 = tmp_path / 'out1.gr2', tmp_path / 'out2.gr2'
    S.build(donor, gxo, out1, tangent_fn=S.uv_tangents)
    moved = tmp_path / 'moved'                                      # other geometry, so out1's mesh is donor data
    moved.mkdir()
    text = GXO.replace('v 0 0 1\n', 'v 0.01 0.02 1.01\n').replace('v 0.5 0 1.5\n', 'v 0.52 0.01 1.49\n')
    rep = S.build(out1, write_gxo(moved, text.replace('v 0.5 0 1\n', 'v 0.49 0.03 1.02\n')
                                  .replace('v 0 0 1.5\n', 'v 0.02 0.01 1.52\n')), out2, tangent_fn=S.uv_tangents)
    assert rep['write']['type_section'] == 'verbatim' and rep['clean']['clean']
    g1, g2 = Gr2(str(out1)), Gr2(str(out2))
    assert g1.payload[S.SEC_TYPES] == g2.payload[S.SEC_TYPES]
    assert S.bone_records(g1)[0] == S.bone_records(g2)[0]
    assert not orphan_fixups(out2)['orphans']


def test_prove_clean_finds_donor_data_in_the_donor_itself(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    rep = S.prove_clean(donor, donor)
    assert not rep['clean'] and rep['donor_vertex_records_found'] == 4 and 'donor_meshShape' in rep['donor_strings_found']


def test_refuses_bones_the_donor_lacks_and_an_existing_output(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    with pytest.raises(S.WriteError, match='missing from the donor'):
        S.build(donor, write_gxo(tmp_path, GXO.replace('Bip01_Head', 'Bip01_Hat')), tmp_path / 'x.gr2',
                tangent_fn=S.uv_tangents)
    out = tmp_path / 'y.gr2'
    out.write_bytes(b'keep')
    with pytest.raises(S.WriteError, match='output exists'):
        S.build(donor, write_gxo(tmp_path), out, tangent_fn=S.uv_tangents)
    assert out.read_bytes() == b'keep'


def test_bone_binding_obb_is_the_bone_local_box_of_its_weighted_vertices(tmp_path):
    m = S.from_gxo(S.parse_gxo(write_gxo(tmp_path)))[0]
    lo, hi = S.obb(m, 1, np.eye(4))                                  # Bip01_Head weights vertices 1, 2, 3
    assert np.allclose(lo, m.pos[[1, 2, 3]].min(0)) and np.allclose(hi, m.pos[[1, 2, 3]].max(0))


# ------------------------------------------------------------------------------------- the owner's machine
def vanilla(tmp_path, rel):
    bt, index = L._bartool()
    entry = index.get(rel.lower()) if bt else None
    if entry is None:
        pytest.skip(f'game archives not readable here ({rel})')
    p = tmp_path / Path(rel).name
    p.write_bytes(bt.read_entry(entry))
    return p


IRON_GXO = GXO.replace('Bip01_Spine', 'Bip01_Spine1').replace('b "Bip01_Root" 0 1 0 0 0 1 0 0 0 1 0 0 0\n', '') \
    .replace('b "Bip01_Spine1" 1', 'b "Bip01_Spine1" 0').replace('b "Bip01_Head" 2', 'b "Bip01_Head" 1')


@pytest.mark.local('steam')
def test_vanilla_iron_rider_donor_keeps_its_skeleton_byte_for_byte(tmp_path):
    donor = vanilla(tmp_path, IRON)
    out = tmp_path / 'spec.gr2'
    rep = S.build(donor, write_gxo(tmp_path, IRON_GXO), out, tangent_fn=S.uv_tangents)
    assert rep['write']['type_section'] == 'verbatim'
    assert rep['verify']['skeleton']['records_identical'] and rep['verify']['skeleton']['bones'] == 32
    assert rep['clean']['clean'] and rep['clean']['donor_strings_found'] == []
    assert Gr2(str(out)).payload[S.SEC_TYPES] == Gr2(str(donor)).payload[6]


@pytest.mark.local('steam')
def test_mikktspace_route_reproduces_the_tangents_vanilla_stores(tmp_path):
    if not S.find_blender():
        pytest.skip('Blender not configured (config/tool-paths.local.json tools.blender.path)')
    res = S.tangent_recheck(vanilla(tmp_path, IRON))
    assert [r['mesh'] for r in res] == ['iron_rider_0Shape', 'iron_rider_0_whipShape']
    for r in res:                                                    # measured 2026-10-11: 0.99997 / 0.9997 and 1.0
        assert r['dot_median'] > 0.999 and r['sign_agree'] > 0.99
