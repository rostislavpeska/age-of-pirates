"""skinned_gr2.py (2026-10-11): the donor-preserving writer for NEW skinned unit geometry.

    python -m pytest scripts/havok/tests/test_skinned_gr2.py -q          # CI: -m "not local"

Synthetic cases build their donor inside the test with the anim viewer's Granny writer
(.claude/skills/aoe3de-anim-viewer/tests/gr2_synth.py, vanilla-shaped types defined here) - no game bytes. The local
cases read vanilla iron_rider_0.gr2 from the archives into the test's temp folder (never the repository, AGENTS.md
rule 3) and, where Blender is configured, check the MikkTSpace route against the tangents vanilla stores.
Repair round 2026-10-11 (INC-251 scale gate, INC-252 clean proof beyond bytes, no output left by a failed build, the
refusal cases, hard edges and mirrored UVs = Tangent.w -127).
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
import skeleton_fit as F  # noqa: E402
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


def make_donor(path, *, normal=('binormal_int8', 4), skeletons=1, models=1, compression=0, magic=None):
    """a vanilla-shaped skinned donor in ONE section (the writer's per-type copy mode): 3 bones (Root at 0, Spine at
    y 1, Head at y 1.5), one 40-byte skinned mesh ON its bones, a material with a colour map and a texture record,
    exporter info and root extended data. The options build the donors the writer must refuse."""
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
    members = [('Position', 'real32', 3), ('Normal',) + tuple(normal), ('Tangent', 'binormal_int8', 4),
               ('DiffuseColor0', 'normal_uint8', 4), ('TextureCoordinates0', 'real32', 2),
               ('BoneWeights', 'normal_uint8', 4), ('BoneIndices', 'uint8', 4)]
    n = 4
    nrm = np.tile([0, 0, 127, 127], (n, 1)) if normal[0] == 'binormal_int8' else np.tile([0.0, 0.0, 1.0], (n, 1))
    cols = {'Position': np.array([[0.03, 1.05, 0.0], [0.05, 1.45, 0.02], [-0.06, 1.1, 0.05], [0.04, 1.58, 0.03]]),
            'Normal': nrm, 'Tangent': np.tile([127, 0, 0, 127], (n, 1)),
            'DiffuseColor0': np.full((n, 4), 255),
            'TextureCoordinates0': np.array([[0.12, 0.07], [0.93, 0.11], [0.08, 0.88], [0.91, 0.95]]),
            'BoneWeights': np.tile([255, 0, 0, 0], (n, 1)), 'BoneIndices': np.array([[0] * 4, [1] * 4, [0] * 4, [1] * 4])}
    vbytes, stride, vtype = G.pack_vertices(members, cols)
    assert stride == (40 if normal[0] == 'binormal_int8' else 48)
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
    mos = [w.obj(model, {'Name': 'Bip01_Root', 'Skeleton': skel, 'InitialPlacement': G.transform(flags=0),
                         'MeshBindings': [{'Mesh': me}]}) for _ in range(models)]
    rt = w.obj(root, {'ArtToolInfo': w.obj(G.ART_TOOL, G.VANILLA_ART_TOOL),
                      'ExporterInfo': w.obj(exporter, {'ExporterName': 'synthetic exporter', 'ExporterMajorRevision': 2}),
                      'FromFileName': 'T:/donor_source/donor.mb', 'Textures': [tex], 'Materials': [filem, mat],
                      'Skeletons': [skel] * skeletons, 'VertexDatas': [vd], 'TriTopologies': [topo], 'Meshes': [me],
                      'Models': mos, 'Animations': [],
                      'ExtendedData': (rootext, w.obj(rootext, {'FromArtToolName': 'synthetic', 'MajorVersion': 1}))})
    Path(path).write_bytes(w.file(root, rt, compression=compression, magic=magic or G.MAGIC64))
    return Path(path)


# our quad on the synthetic donor's Spine -> Head segment (engine x = -GXO x, y = GXO z): it sits on its skeleton
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
v 0.1 0 1
vn 0 -1 0
vt 1 0
vw 0.6 0.4 0 0 1 2 1 1
v 0 0 1.6
vn 0 -1 0
vt 0 1
vw 0.749019608 0.250980392 0 0 2 1 2 2
v 0.1 0 1.6
vn 0 -1 0
vt 1 1
vw 1 0 0 0 2 2 2 2
fg 1
f 1 2 3
f 3 2 4
'''


def write_gxo(tmp_path, text=GXO, name='model.gxo'):
    p = tmp_path / name
    p.write_text(text, encoding='utf-8')
    return p


def scale_gxo(text, k, joints=True, mesh=True):
    """the GXO with its bone translations and / or vertex positions multiplied by k (a wrong-unit export)"""
    out = []
    for line in text.splitlines():
        t = line.split()
        if joints and t and t[0] == 'b':
            head, rest = line.rsplit('"', 1)
            r = rest.split()
            r[10:13] = ['%.9g' % (float(x) * k) for x in r[10:13]]
            line = head + '" ' + ' '.join(r)
        elif mesh and t and t[0] == 'v':
            line = 'v ' + ' '.join('%.9g' % (float(x) * k) for x in t[1:4])
        out.append(line)
    return '\n'.join(out) + '\n'


def build(donor, gxo, out, **kw):
    kw.setdefault('tangent_fn', S.uv_tangents)
    return S.build(donor, gxo, out, **kw)


def no_output(out):
    return not Path(out).exists() and not Path(str(out) + '.partial').exists()


# ------------------------------------------------------------------------------------------------- pure parts
def test_from_gxo_maps_the_frame_reverses_corners_and_flips_v(tmp_path):
    ms = S.from_gxo(S.parse_gxo(write_gxo(tmp_path)))
    m = ms[0]
    assert m.name == 'our_body' and m.material == 'our_mat' and m.bones == ['Bip01_Spine', 'Bip01_Head']
    assert np.allclose(m.pos[1], [-0.1, 1.0, 0.0])                     # (-x, z, -y)
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


def test_skeleton_fit_passes_a_mesh_on_its_bones_and_fails_a_shrunk_one():
    names, parents = ['Root', 'Spine', 'Head'], [-1, 0, 1]
    J = np.array([[0, 0, 0], [0, 1.0, 0], [0, 1.5, 0]])
    mesh = dict(name='q', pos=np.array([[0, 1.0, 0], [-0.1, 1.0, 0], [0, 1.6, 0], [-0.1, 1.6, 0]]),
                w=np.tile([255, 0, 0, 0], (4, 1)), bi=np.array([[0] * 4, [0] * 4, [1] * 4, [1] * 4]),
                palette=['Spine', 'Head'])
    rep = F.fit([mesh], names, parents, J)
    assert F.judge(rep) == [] and rep['height_ratio'] == 1.2 and rep['dist_p50'] == 0.1
    small = dict(mesh, pos=mesh['pos'] * 0.3937)
    bad = F.judge(F.fit([small], names, parents, J))
    assert any('wrong scale' in b for b in bad) and any('p50' in b for b in bad)
    assert F.judge(F.fit([dict(mesh, palette=['Spine', 'Hat'])], names, parents, J))     # a bone the skeleton lacks


def grid(nx, ny):
    P = np.array([[x * 0.1, y * 0.1, 0.0] for y in range(ny) for x in range(nx)])
    T = []
    for y in range(ny - 1):
        for x in range(nx - 1):
            a = y * nx + x
            T += [(a, a + 1, a + nx), (a + nx, a + 1, a + nx + 1)]
    return P, np.array(T)


def test_topology_signature_ignores_order_scale_and_splits_but_not_a_new_triangulation():
    P, T = grid(6, 5)
    sig = S.topology_signature(P, T)
    assert sig['faces'] == 40 and sig['vertices'] == 30
    perm = np.random.default_rng(1).permutation(len(P))
    inv = np.argsort(perm)
    P2 = P[perm] * 1.0001 + 0.3                                        # reordered, scaled, moved
    T2 = inv[T][:, [1, 2, 0]]
    P3 = np.vstack([P2, P2[T2[0]]])                                    # one face split off (a UV seam copy)
    T3 = T2.copy()
    T3[0] = [len(P2), len(P2) + 1, len(P2) + 2]
    assert S.topology_signature(P2, T2) == sig and S.topology_signature(P3, T3) == sig
    Tf = T.copy()                                                      # one quad flipped to the other diagonal
    a = 0
    Tf[0], Tf[1] = (a, a + 1, a + 6 + 1), (a, a + 7, a + 6)
    assert S.topology_signature(P, Tf) != sig


def test_near_share_and_normalized_find_a_moved_scaled_copy():
    P, _ = grid(6, 5)
    Q = P * 1.05 + [0.2, -0.1, 0.03]
    assert S.near_share(Q, P, 1e-3) == 0.0
    for how in ('rms', 'box'):
        assert S.near_share(S.normalized(Q, how), S.normalized(P, how), 1e-3) == 1.0
    assert S.near_share(S.normalized(P[:-1], 'box'), S.normalized(P, 'box'), 1e-3) == 1.0   # one corner-safe drop


# ------------------------------------------------------------------------------------------- written files
def test_writes_a_clean_file_around_a_synthetic_donor(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    out = tmp_path / 'out.gr2'
    rep = build(donor, write_gxo(tmp_path), out)
    assert rep['write']['type_section'] == 'copied per type' and rep['write']['path'] == str(out)
    v = rep['verify']
    assert v['crc_ok'] and all(v['skeleton'].values()) and v['orphan_fixups'] == 0 and not v['fails']
    assert [x['layout_vanilla'] for x in v['meshes']] == [True]
    c = rep['clean']
    assert c['clean'] and c['donor_vertex_records_found'] == 0 and c['donor_positions_found'] == 0
    g0 = c['geometry']['meshes'][0]
    assert g0['positions_share'] == 0 and g0['positions_share_normalized'] == 0 and g0['uv_share'] == 0
    blob = out.read_bytes()
    for s in (b'donor_meshShape', b'donor_mata', b'donor_file9', b'donor_tex.png', b'donor.mb'):
        assert s not in blob
    for s in (b'Bip01_Head', b'synthetic exporter', b'our_body', b'our_mat', b'skinned_gr2.py out'):
        assert s in blob
    g = Gr2(str(out))
    assert [s['data_size'] > 0 for s in g.sections] == [True, False, False, True, True, False, True, False]
    info = L.read_raw(out)
    assert [x['name'] for x in info['render']] == ['our_body'] and info['render'][0]['mats'] == ['our_mat']
    assert info['render'][0]['bone_names'] == ['Bip01_Spine', 'Bip01_Head']
    assert rep['donor_bind']['same_names_and_order'] and rep['donor_bind']['joint_max_abs_diff'] < 1e-6
    assert rep['skeleton_fit']['fails'] == [] and rep['tangent_recheck'][0]['sign_agree'] == 1.0
    assert not Path(str(out) + '.partial').exists()


def test_second_generation_copies_the_type_section_verbatim(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    gxo = write_gxo(tmp_path)
    out1, out2 = tmp_path / 'out1.gr2', tmp_path / 'out2.gr2'
    build(donor, gxo, out1)
    moved = GXO.replace('v 0 0 1\n', 'v 0.01 0.02 1.01\n').replace('v 0.1 0 1.6\n', 'v 0.12 0.01 1.59\n') \
        .replace('v 0.1 0 1\n', 'v 0.09 0.03 1.02\n').replace('v 0 0 1.6\n', 'v 0.02 0.01 1.62\n') \
        .replace('vt 0 0\n', 'vt 0.05 0.04\n').replace('vt 1 0\n', 'vt 0.96 0.03\n') \
        .replace('vt 0 1\n', 'vt 0.04 0.97\n').replace('vt 1 1\n', 'vt 0.95 0.94\n')     # other geometry and UVs:
    rep = build(out1, write_gxo(tmp_path, moved, 'moved.gxo'), out2)                     # out1's mesh is donor data
    assert rep['write']['type_section'] == 'verbatim' and rep['clean']['clean']
    g1, g2 = Gr2(str(out1)), Gr2(str(out2))
    assert g1.payload[S.SEC_TYPES] == g2.payload[S.SEC_TYPES]
    assert S.bone_records(g1)[0] == S.bone_records(g2)[0]
    assert not orphan_fixups(out2)['orphans']


def test_prove_clean_finds_donor_data_in_the_donor_itself(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    rep = S.prove_clean(donor, donor)
    assert not rep['clean'] and rep['donor_vertex_records_found'] == 4 and 'donor_meshShape' in rep['donor_strings_found']
    assert rep['meshes_on_donor_geometry'] == ['donor_meshShape']


def test_bone_binding_obb_is_the_bone_local_box_of_its_weighted_vertices(tmp_path):
    m = S.from_gxo(S.parse_gxo(write_gxo(tmp_path)))[0]
    lo, hi = S.obb(m, 1, np.eye(4))                                  # Bip01_Head weights vertices 1, 2, 3
    assert np.allclose(lo, m.pos[[1, 2, 3]].min(0)) and np.allclose(hi, m.pos[[1, 2, 3]].max(0))


# ------------------------------------------------------------------------- the scale gate (INC-251)
def test_refuses_a_gxo_written_at_the_wrong_scale_before_writing(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    out = tmp_path / 'o.gr2'
    with pytest.raises(S.WriteError, match='GXO joint .* units from the donor joint'):
        build(donor, write_gxo(tmp_path, scale_gxo(GXO, 0.393700787)), out)          # the pose-test GXO
    assert no_output(out)


def test_refuses_a_mesh_that_does_not_sit_on_the_donor_skeleton(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    out = tmp_path / 'o.gr2'
    with pytest.raises(S.WriteError, match='skeleton_fit'):                          # right joints, shrunk mesh
        build(donor, write_gxo(tmp_path, scale_gxo(GXO, 0.393700787, joints=False)), out)
    assert no_output(out)
    with pytest.raises(S.WriteError, match='skeleton_fit'):                          # mesh 2 units to the side
        build(donor, write_gxo(tmp_path, GXO.replace('v 0 0 1\n', 'v 2 0 1\n').replace('v 0.1 0 1\n', 'v 2.1 0 1\n')
                               .replace('v 0 0 1.6\n', 'v 2 0 1.6\n').replace('v 0.1 0 1.6\n', 'v 2.1 0 1.6\n')), out)
    assert no_output(out)


def test_refuses_a_gxo_without_a_bone_table_or_with_unlisted_palette_bones(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    no_table = ''.join(line + '\n' for line in GXO.splitlines() if not line.startswith('b '))
    with pytest.raises(S.WriteError, match='no bone table'):
        build(donor, write_gxo(tmp_path, no_table), tmp_path / 'o.gr2')
    no_head = ''.join(line + '\n' for line in GXO.splitlines() if not line.startswith('b "Bip01_Head"'))
    with pytest.raises(S.WriteError, match='palette bones absent'):
        build(donor, write_gxo(tmp_path, no_head), tmp_path / 'o.gr2')


def test_the_scale_option_scales_joints_and_mesh_together(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    rep = build(donor, write_gxo(tmp_path, scale_gxo(GXO, 0.5)), tmp_path / 'o.gr2', scale=2.0)
    assert rep['donor_bind']['joint_max_abs_diff'] < 1e-6 and rep['skeleton_fit']['height_ratio'] == 1.2


# --------------------------------------------------------------- donor data beyond exact bytes (INC-252)
def relaunder_gxo(donor, k=1.0001):
    """the donor's own mesh as a re-export would hand it back: scaled, vertices reordered, UVs as Blender shows them"""
    g = Gr2(str(donor))
    d = S.mesh_arrays(g)[0]
    rec = S.decode(donor)[0]
    order = [2, 0, 3, 1]
    lines = [line for line in GXO.splitlines() if line.startswith(('mt ', 'b '))] + \
        ['m "our_body"', 'mb "Bip01_Spine"', 'mb "Bip01_Head"', 'mm 1']
    for i in order:
        gx = (d['pos'][i] @ S.A.T) * k
        n = rec.nrm[i, :3] / 127.0 @ S.A.T
        lines += ['v %.9g %.9g %.9g' % tuple(gx), 'vn %.6g %.6g %.6g' % tuple(n),
                  'vt %.9g %.9g' % (d['uv'][i, 0], 1.0 - d['uv'][i, 1]), 'vw 1 0 0 0 %d %d %d %d' % ((rec.bi[i, 0] + 1,) * 4)]
    pos = {v: k2 + 1 for k2, v in enumerate(order)}
    lines += ['fg 1'] + ['f %d %d %d' % tuple(pos[int(x)] for x in t[[0, 2, 1]]) for t in d['tris']]
    return '\n'.join(lines) + '\n'


def test_a_reexported_donor_mesh_is_refused_and_leaves_no_output(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    out = tmp_path / 'laundered.gr2'
    with pytest.raises(S.WriteError, match='meshes on donor geometry'):
        build(donor, write_gxo(tmp_path, relaunder_gxo(donor)), out)
    assert no_output(out)


def test_a_failed_overwrite_keeps_the_existing_output(tmp_path, monkeypatch):
    donor = make_donor(tmp_path / 'donor.gr2')
    out = tmp_path / 'keep.gr2'
    out.write_bytes(b'keep')
    with pytest.raises(S.WriteError, match='meshes on donor geometry'):
        build(donor, write_gxo(tmp_path, relaunder_gxo(donor)), out, overwrite=True)
    assert out.read_bytes() == b'keep' and not Path(str(out) + '.partial').exists()

    def broken_verify(*a, **k):
        raise S.WriteError('verification failed: simulated')
    monkeypatch.setattr(S, 'verify', broken_verify)
    with pytest.raises(S.WriteError, match='simulated'):
        build(donor, write_gxo(tmp_path), tmp_path / 'v.gr2')
    assert no_output(tmp_path / 'v.gr2')


def test_a_tangent_recheck_that_disagrees_removes_the_output(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    calls = []

    def flipping(meshes):                                            # honest first, then every sign flipped
        res = S.uv_tangents(meshes)
        calls.append(1)
        return res if len(calls) == 1 else [(T, -Sg) for T, Sg in res]
    with pytest.raises(S.WriteError, match='disagree with the recomputed'):
        S.build(donor, write_gxo(tmp_path), tmp_path / 't.gr2', tangent_fn=flipping)
    assert no_output(tmp_path / 't.gr2')


# --------------------------------------------------------------------------------------- refusals
def test_refuses_the_donor_as_output_and_an_existing_output(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    before = donor.read_bytes()
    with pytest.raises(S.WriteError, match='overwrite the donor'):
        build(donor, write_gxo(tmp_path), donor, overwrite=True)
    assert donor.read_bytes() == before
    out = tmp_path / 'y.gr2'
    out.write_bytes(b'keep')
    with pytest.raises(S.WriteError, match='output exists'):
        build(donor, write_gxo(tmp_path), out)
    assert out.read_bytes() == b'keep'
    with pytest.raises(S.WriteError, match='missing from the donor'):
        build(donor, write_gxo(tmp_path, GXO.replace('Bip01_Head', 'Bip01_Hat')), tmp_path / 'x.gr2')


@pytest.mark.parametrize('kind', ['compressed', '32-bit', 'bad crc', 'normal real32x3', 'two skeletons', 'two models',
                                  'not a gr2'])
def test_refuses_a_donor_it_cannot_prove_vanilla(tmp_path, kind):
    G = synth()
    p = tmp_path / 'donor.gr2'
    if kind == 'compressed':
        make_donor(p, compression=1)
    elif kind == '32-bit':
        make_donor(p, magic=G.MAGIC32)
    elif kind == 'bad crc':
        make_donor(p)
        b = bytearray(p.read_bytes())
        b[-1] ^= 0xFF
        p.write_bytes(bytes(b))
    elif kind == 'normal real32x3':
        make_donor(p, normal=('real32', 3))
    elif kind == 'two skeletons':
        make_donor(p, skeletons=2)
    elif kind == 'two models':
        make_donor(p, models=2)
    else:
        p.write_bytes(b'not a granny file' * 20)
    msg = {'compressed': 'cannot be read', '32-bit': 'cannot be read|64-bit', 'bad crc': 'CRC',
           'normal real32x3': 'not the vanilla 40-byte', 'two skeletons': 'one skeleton and one model',
           'two models': 'one skeleton and one model', 'not a gr2': 'cannot be read'}[kind]
    out = tmp_path / 'o.gr2'
    with pytest.raises(S.WriteError, match=msg):
        build(p, write_gxo(tmp_path), out)
    assert no_output(out)


TWO_MATS = GXO.replace('mt "our_mat"\n', 'mt "our_mat"\nmt "m2"\n').replace('mm 1\n', 'mm 1\nmm 2\n') \
    .replace('f 3 2 4\n', 'fg 2\nf 3 2 4\n')


@pytest.mark.parametrize('text, msg', [
    pytest.param(TWO_MATS, 'materials / face groups', id='two materials'),
    pytest.param(GXO.replace('vn 0 -1 0\nvt 1 1', 'vt 1 1'), 'counts differ', id='count mismatch'),
    pytest.param(GXO.replace('f 3 2 4', 'f 3 2 9'), 'past the vertices', id='face past the vertices'),
    pytest.param(GXO.replace('fg 1\n', 'v 0.05 0 1.3\nvn 0 -1 0\nvt 0.5 0.5\nvw 1 0 0 0 1 1 1 1\nfg 1\n'),
                 'in no triangle', id='unreferenced vertex'),
    pytest.param(GXO.replace('vt 1 0\n', 'vt 0 0\n').replace('vt 0 1\n', 'vt 0 0\n').replace('vt 1 1\n', 'vt 0 0\n'),
                 'zero tangents', id='degenerate UVs'),
])
def test_refuses_a_gxo_it_cannot_write(tmp_path, text, msg):
    donor = make_donor(tmp_path / 'donor.gr2')
    out = tmp_path / 'o.gr2'
    with pytest.raises(S.WriteError, match=msg):
        build(donor, write_gxo(tmp_path, text), out)
    assert no_output(out)


def test_without_blender_the_writer_stops_instead_of_using_another_tangent_rule(tmp_path, monkeypatch):
    monkeypatch.setattr(S, 'find_blender', lambda explicit=None: None)
    donor = make_donor(tmp_path / 'donor.gr2')
    out = tmp_path / 'o.gr2'
    with pytest.raises(S.WriteError, match='Blender not found'):
        S.build(donor, write_gxo(tmp_path), out)                        # no tangent_fn: MikkTSpace or nothing
    assert no_output(out)


# ------------------------------------------------------------- hard edges and mirrored UVs (Tangent.w -127)
# two quads side by side on the Spine -> Head segment; the shared column is split (a hard edge: the left quad's normals
# lean to -x, the right quad's to +x) and the right quad's UVs are mirrored in U (its tangent frame is left-handed)
EDGE_GXO = '''mt "our_mat"
b "Bip01_Root" 0 1 0 0 0 1 0 0 0 1 0 0 0
b "Bip01_Spine" 1 1 0 0 0 1 0 0 0 1 0 0 1
b "Bip01_Head" 2 1 0 0 0 1 0 0 0 1 0 0 1.5
m "our_edge"
mb "Bip01_Spine"
mb "Bip01_Head"
mm 1
''' + ''.join('v %s 0 %s\nvn %s -0.954 0\nvt %s %s\nvw 1 0 0 0 %d %d %d %d\n' % (x, z, nx, u, v, b, b, b, b)
              for x, z, nx, u, v, b in (
                  ('0', '1', '-0.3', '0.1', '0.1', 1), ('0.05', '1', '-0.3', '0.4', '0.1', 1),
                  ('0', '1.6', '-0.3', '0.1', '0.9', 2), ('0.05', '1.6', '-0.3', '0.4', '0.9', 2),
                  ('0.05', '1', '0.3', '0.9', '0.1', 1), ('0.1', '1', '0.3', '0.6', '0.1', 1),
                  ('0.05', '1.6', '0.3', '0.9', '0.9', 2), ('0.1', '1.6', '0.3', '0.6', '0.9', 2))) + \
    'fg 1\nf 1 2 3\nf 3 2 4\nf 5 6 7\nf 7 6 8\n'


def check_edge_file(out):
    m = S.decode(out)[0]
    w = m.tan[:, 3].astype(int)
    left, right = np.unique(m.tris[:2]), np.unique(m.tris[2:])
    assert set(w[left]) == {127} and set(w[right]) == {-127}            # one sign per quad, the mirror is -127
    shared = [(i, j) for i in left for j in right if np.array_equal(m.pos[i], m.pos[j])]
    assert len(shared) == 2 and all(m.nrm[i, 0] != m.nrm[j, 0] for i, j in shared)       # the hard edge is kept
    return m


def test_hard_edges_and_mirrored_uvs_write_tangent_w_minus_127(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    out = tmp_path / 'edge.gr2'
    rep = build(donor, write_gxo(tmp_path, EDGE_GXO), out)
    m = check_edge_file(out)
    assert m.n == 8 and rep['prepared'][0]['tangent_only_splits'] == 0
    assert rep['tangent_recheck'][0]['sign_agree'] == 1.0


def test_mikktspace_writes_tangent_w_minus_127_on_mirrored_uvs(tmp_path):
    if not S.find_blender():
        pytest.skip('Blender not configured (config/tool-paths.local.json tools.blender.path)')
    donor = make_donor(tmp_path / 'donor.gr2')
    out = tmp_path / 'edge_mikk.gr2'
    rep = S.build(donor, write_gxo(tmp_path, EDGE_GXO), out)          # MikkTSpace in background Blender
    check_edge_file(out)
    r = rep['tangent_recheck'][0]
    assert r['sign_agree'] == 1.0 and r['dot_median'] > 0.999


# ------------------------------------------------------------------------------------- the owner's machine
def vanilla(tmp_path, rel):
    bt, index = L._bartool()
    entry = index.get(rel.lower()) if bt else None
    if entry is None:
        pytest.skip(f'game archives not readable here ({rel})')
    p = tmp_path / Path(rel).name
    p.write_bytes(bt.read_entry(entry))
    return p


def donor_gxo(donor, palette=('Bip01_Spine1', 'Bip01_Head')):
    """a quad on a real donor's skeleton: every donor bone in the table (joints from the donor), the quad from the first
    palette joint to just above the second"""
    names, parents, J = S.donor_skeleton(S.open_donor(donor))
    lines = ['mt "our_mat"'] + ['b "%s" %d 1 0 0 0 1 0 0 0 1 %.9g %.9g %.9g' % ((n, p + 1) + tuple(j @ S.A.T))
                                for n, p, j in zip(names, parents, J)]
    j1, j2 = J[names.index(palette[0])], J[names.index(palette[1])]
    up, dx = np.array([0, 0.1, 0]), np.array([-0.1, 0, 0])
    lines += ['m "our_body"', 'mb "%s"' % palette[0], 'mb "%s"' % palette[1], 'mm 1']
    for v, w, t in zip((j1, j1 + dx, j2 + up, j2 + up + dx),
                       ('1 0 0 0 1 1 1 1', '0.6 0.4 0 0 1 2 1 1', '0.749019608 0.250980392 0 0 2 1 2 2', '1 0 0 0 2 2 2 2'),
                       ('0.21 0.13', '0.83 0.17', '0.24 0.77', '0.86 0.81')):
        lines += ['v %.9g %.9g %.9g' % tuple(v @ S.A.T), 'vn 0 -1 0', 'vt ' + t, 'vw ' + w]
    return '\n'.join(lines + ['fg 1', 'f 1 2 3', 'f 3 2 4']) + '\n'


@pytest.mark.local('steam')
def test_vanilla_iron_rider_donor_keeps_its_skeleton_byte_for_byte(tmp_path):
    donor = vanilla(tmp_path, IRON)
    out = tmp_path / 'spec.gr2'
    rep = build(donor, write_gxo(tmp_path, donor_gxo(donor)), out)
    assert rep['write']['type_section'] == 'verbatim'
    assert rep['verify']['skeleton']['records_identical'] and rep['verify']['skeleton']['bones'] == 32
    assert rep['clean']['clean'] and rep['clean']['donor_strings_found'] == []
    assert rep['donor_bind']['joint_max_abs_diff'] < 1e-5
    assert Gr2(str(out)).payload[S.SEC_TYPES] == Gr2(str(donor)).payload[6]


@pytest.mark.local('steam')
def test_vanilla_iron_rider_at_the_pose_test_scale_is_refused(tmp_path):
    donor = vanilla(tmp_path, IRON)
    out = tmp_path / 'wrong.gr2'
    with pytest.raises(S.WriteError, match='GXO joint'):
        build(donor, write_gxo(tmp_path, scale_gxo(donor_gxo(donor), 0.393700787)), out)
    assert no_output(out)


@pytest.mark.local('steam')
def test_mikktspace_route_reproduces_the_tangents_vanilla_stores(tmp_path):
    if not S.find_blender():
        pytest.skip('Blender not configured (config/tool-paths.local.json tools.blender.path)')
    res = S.tangent_recheck(vanilla(tmp_path, IRON))
    assert [r['mesh'] for r in res] == ['iron_rider_0Shape', 'iron_rider_0_whipShape']
    for r in res:                                                    # measured 2026-10-11: 0.99997 / 0.9997 and 1.0
        assert r['dot_median'] > 0.999 and r['sign_agree'] > 0.99


@pytest.mark.local('steam')
def test_the_vanilla_body_and_whip_reexported_are_found_beyond_bytes(tmp_path):
    """INC-252: the vanilla meshes handed back through a re-export (scaled 1.0001, reordered) hold no donor byte run,
    yet sit on donor positions and UVs, and the whip keeps the donor's welded topology"""
    donor = vanilla(tmp_path, IRON)
    d = Gr2(str(donor))
    arrays = S.mesh_arrays(d)
    for a in arrays:
        perm = np.random.default_rng(7).permutation(len(a['pos']))
        inv = np.argsort(perm)
        P2, T2 = a['pos'][perm] * 1.0001, inv[a['tris']]
        assert S.near_share(P2, a['pos'], S.CLEAN_POS_TOL) == 1.0
        assert S.near_share(a['uv'][perm], a['uv'], S.CLEAN_UV_TOL) == 1.0
        assert S.topology_signature(P2, T2) == S.topology_signature(a['pos'], a['tris'])
