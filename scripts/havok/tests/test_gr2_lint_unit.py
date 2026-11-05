"""gr2_lint unit profiles (2026-10-11): a skinned rider linted against references measured on vanilla riders, the
PROPOSED unit texture class kept apart from the owner's building classes, the universal UV density floor (no unit
exemption, INC-253) with the organic UV gate profile's higher minima on top, and the skeleton fit (INC-251).

    python -m pytest scripts/havok/tests/test_gr2_lint_unit.py -q          # CI: -m "not local"

Synthetic cases need no game bytes (the donor comes from test_skinned_gr2.make_donor). The local cases read vanilla
iron_rider_0 and keshik_rider_rank01, their horses and idle clips from the archives into the test's temp folder (never
the repository, AGENTS.md rule 3) and seat them as the reference measurement did.
"""
from __future__ import annotations

import copy
import json
import struct
import sys
import zlib
from pathlib import Path

import numpy as np
import pytest

HAVOK = Path(__file__).resolve().parents[1]
REPO = HAVOK.parents[1]
sys.path.insert(0, str(HAVOK))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import gr2_lint as L  # noqa: E402
import skinned_gr2 as S  # noqa: E402
from test_skinned_gr2 import GXO, make_donor, write_gxo  # noqa: E402

PROFILES = L.load_profiles()
QUOTE = "human unuts should have 1x 1024 texture, let's hold it"


def test_the_unit_profile_is_proposed_and_kept_apart_from_the_building_classes():
    prof = L.resolve_profile(PROFILES, 'unit_rider_1024')
    assert prof['kind'] == 'unit' and 'PROPOSED' in prof['_doc']
    assert prof['_texture_budget']['owner_quote'] == QUOTE
    assert prof['_texture_budget']['classes']['unit_human_1024']['ceiling'] == [1024]
    assert prof['texture_budget']['class'] == 'unit_human_1024' and not prof['texture_budget'].get('confirmed_by')
    assert set(PROFILES['texture_budget']['classes']) == {'small', 'medium', 'large', '4x2048'}      # buildings untouched (4x2048: the Korean House family, owner 2026-10-12)
    assert 'unit_rider_1024' not in PROFILES['profiles']
    assert prof['references'] == ['iron_rider_0', 'keshik_rider_rank01']
    for r in prof['references']:
        ref = PROFILES['unit_references'][r]
        assert ref['skeleton']['world_sha256'] and ref['density']['visible_weighted']['p10']
    lim, name, _ = L.uv_density_limits(prof)
    assert name == 'aoe3de-unit-body-1024' and set(lim) == {'density_p50', 'density_visible_p10'}
    vis_min = lim['density_visible_p10']['hard']['min']
    assert vis_min <= min(PROFILES['unit_references'][r]['density']['visible_weighted']['p10'] for r in prof['references'])
    assert lim['density_p50']['hard']['min'] <= min(PROFILES['unit_references'][r]['density']['all']['p50']
                                                     for r in prof['references'])


def test_an_extending_file_inherits_the_unit_profiles_and_cannot_redefine_their_classes(tmp_path):
    f = tmp_path / 'other.json'
    f.write_text(json.dumps({'extends': 'gr2_lint_profiles.json', 'profiles': {}}), encoding='utf-8')
    doc = L.load_profiles(f)
    assert L.resolve_profile(doc, 'unit_rider_1024')['_texture_budget'] == PROFILES['unit_texture_budget']
    f.write_text(json.dumps({'extends': 'gr2_lint_profiles.json', 'profiles': {},
                             'unit_texture_budget': {'classes': {'unit_human_1024': {'ceiling': [4096]}}}}),
                 encoding='utf-8')
    with pytest.raises(ValueError, match='texture_budget'):
        L.load_profiles(f)


def quad(z, up=True, size=1.0):
    P = np.array([[0, 0, z], [size, 0, z], [size, size, z], [0, size, z]], float)
    F = np.array([[0, 1, 2], [0, 2, 3]]) if up else np.array([[0, 2, 1], [0, 3, 2]])
    return P, F


def test_face_visibility_counts_only_camera_facing_occluders():
    P, F = quad(0.0)
    d = [np.array([0.0, 0.0, 1.0])]
    assert L.face_visibility(P, F, P, F, d).tolist() == [[1.0, 1.0]]              # its own faces never block it
    for up, want in ((True, 0.0), (False, 1.0)):                                     # back faces do not occlude
        O, G = quad(1.0, up, size=3.0)
        O = O - [1.0, 1.0, 0.0]
        occP, occF = np.vstack([P, O]), np.vstack([F, G + 4])
        assert L.face_visibility(P, F, occP, occF, d).tolist() == [[want, want]]
    assert len(L.cam_dirs([0, -1, 0], 8, 47.0)) == 8
    assert np.allclose(L.cam_dirs([0, -1, 0], 8, 47.0)[0], [0, -np.cos(np.radians(47)), np.sin(np.radians(47))])


def synthetic_unit(tmp_path):
    donor = make_donor(tmp_path / 'donor.gr2')
    out = tmp_path / 'unit.gr2'
    S.build(donor, write_gxo(tmp_path), out, tangent_fn=S.uv_tangents)
    ref = L.measure_unit_reference(out)
    prof = {'name': 'synthetic', 'kind': 'unit', 'references': [],
            'unit': {'skeletons': ['synthetic_ref'], 'allowed_weighted_bones': ref['weighted_bones'], 'max_influences': 4,
                     'zero_slot_slot0_min': 1.0, 'max_triangles': 10, 'max_welded_vertices': 10, 'page': 1024},
            '_unit_refs': {'synthetic_ref': {'skeleton': ref['skeleton']}}}
    return out, prof, ref


def test_a_synthetic_unit_passes_the_unit_checks_and_a_broken_weight_fails(tmp_path):
    out, prof, ref = synthetic_unit(tmp_path)
    info = L.read_raw(out)
    for check in (L.check_unit_skeleton, L.check_unit_weights, L.check_unit_vertex, L.check_unit_budget):
        assert check('intact', info, prof)['status'] == 'PASS', check.__name__
    assert ref['triangles'] == 2 and ref['layouts_vanilla'] == [True]
    d = L.unit_density(info, None, 1024)
    assert d['page'] == '(our_mat)' and d['faces'] == 2 and d['all']['p50'] > 0 and 'visible_weighted' not in d
    other = dict(prof, unit=dict(prof['unit'], allowed_weighted_bones=['Bip01_Spine'], max_triangles=1))
    assert L.check_unit_weights('intact', info, other)['status'] == 'FAIL'
    assert L.check_unit_budget('intact', info, other)['status'] == 'FAIL'
    assert L.check_unit_skeleton('intact', info, dict(prof, _unit_refs={}))['status'] == 'FAIL'
    g = S.Gr2(str(out))                                             # one weight byte off: sum 254
    b = bytearray(out.read_bytes())
    base = g.sections[S.SEC_VERTEX]['data_off']
    b[base + 32] -= 1
    struct.pack_into('<I', b, 40, zlib.crc32(bytes(b[104:])) & 0xffffffff)
    broken = tmp_path / 'broken.gr2'
    broken.write_bytes(bytes(b))
    r = L.check_unit_weights('intact', L.read_raw(broken), prof)
    assert r['status'] == 'FAIL' and r['data']['meshes'][0]['sums_not_255'] == 1


def test_unit_fit_fails_a_unit_written_at_the_wrong_scale(tmp_path):
    """INC-251: a 0.3937x model keeps every byte check green; unit_fit fails it (written with write(), which has no
    gates, because build() refuses it)"""
    out, prof, _ = synthetic_unit(tmp_path)
    assert L.check_unit_fit('intact', L.read_raw(out), prof)['status'] == 'PASS'
    donor = tmp_path / 'donor.gr2'
    ms = S.from_gxo(S.parse_gxo(write_gxo(tmp_path)), scale=0.393700787)
    ms = [S.assign_tangents(m, *tc)[0] for m, tc in zip(ms, S.uv_tangents(ms))]
    small = tmp_path / 'small.gr2'
    S.write(donor, ms, small)
    info = L.read_raw(small)
    for check in (L.check_unit_skeleton, L.check_unit_weights, L.check_unit_vertex):
        assert check('intact', info, prof)['status'] == 'PASS', check.__name__
    r = L.check_unit_fit('intact', info, prof)
    assert r['status'] == 'FAIL' and 'wrong scale' in r['summary']


def test_unit_profiles_run_the_universal_density_floor(tmp_path):
    """INC-253: no unit exemption from the universal floor - a unit whose page cannot be measured is INCOMPLETE = FAIL,
    exactly as a building"""
    out, prof, _ = synthetic_unit(tmp_path)
    res = L.lint(dict(prof, _texture_budget={}), intact=str(out), use_dll=False)
    td = [r for r in res if r['check'] == 'texel_density']
    assert len(td) == 1 and td[0]['status'] == 'FAIL' and 'INCOMPLETE' in td[0]['summary']
    assert [r['check'] for r in res].count('unit_fit') == 1


def test_unit_density_of_a_uniform_sheet_is_page_times_the_uv_scale():
    info = dict(render=[dict(name='sheet', nv=4, pos=quad(0.0)[0], tris=quad(0.0)[1], mats=['m'], groups=[(0, 0, 2)],
                             uv=np.array([[0, 0], [0.5, 0], [0.5, 0.5], [0, 0.5]], float))])
    d = L.unit_density(info, None, 1024)
    assert d['all'] == {'p10': 512.0, 'p50': 512.0, 'p90': 512.0}


# ------------------------------------------------------------------------------------- the owner's machine
VAN = {'iron_rider_0': ('art/units/asians/chinese/iron_flail/iron_rider_0.gr2',
                        'art/animation_library/cavalry/oprichnik_idle1.gr2',
                        'art/units/asians/chinese/iron_flail/iron_flail_horse_0.gr2',
                        'art/animation_library/cavalry/horse_idle_a.gr2'),
       'keshik_rider_rank01': ('art/units/asians/chinese/keshik/keshik_rider_rank01.gr2',
                               'art/animation_library/cavalry/sword_idle_a.gr2',
                               'art/units/asians/chinese/keshik/keshik_horse_rank01.gr2',
                               'art/animation_library/cavalry/horse_idle_a.gr2')}


def vanilla(tmp_path, rel):
    bt, index = L._bartool()
    entry = index.get(rel.lower()) if bt else None
    if entry is None:
        pytest.skip(f'game archives not readable here ({rel})')
    p = tmp_path / Path(rel).name
    p.write_bytes(bt.read_entry(entry))
    return p


def seated_pose(tmp_path, rider, rclip, horse, hclip):
    """the reference measurement's pose NPZ: rider clip key 0 on the horse clip key 0, seated at bone_attachpoint,
    gr2-handed z-up frame (engine (x, y, z) -> (x, -z, y)), the horse as occluder, forward = horse head direction"""
    sk = REPO / '.claude' / 'skills'
    for p in (sk / 'aoe3de-unit-animation' / 'scripts', sk / 'aoe3de-anim-viewer' / 'scripts',
              sk / 'aoe3de-unit-model' / 'scripts'):
        if str(p) not in sys.path:
            sys.path.insert(0, str(p))
    import pose_sim as PS
    import gr2_model as GM
    import clip_decode as CD
    from crosscheck import gxo_model_text
    A = np.array([[-1.0, 0, 0], [0, 0, -1.0], [0, 1.0, 0]])
    Z = np.array([[1.0, 0, 0], [0, 0, 1.0], [0, -1.0, 0]])

    def posed(gr2, clip_rel, tol):
        model = GM.read_model(str(gr2))
        mf = tmp_path / (gr2.stem + '.gxo')
        mf.write_text(gxo_model_text(model), encoding='utf-8')
        bones, meshes = PS.parse_model(str(mf))
        cf = tmp_path / (Path(clip_rel).stem + '.gxo')
        cf.write_text(CD.gxo_text(CD.decode(vanilla(tmp_path, clip_rel))), encoding='utf-8')
        keys = PS.parse_anim(str(cf), 0)
        PS.check_keys(keys, bones, tol, cf.name)
        Wp = PS.pose(bones, PS.orthonormalize(keys))
        live = [x for x in model.meshes if x.streams.get('Position') is not None and x.vertex_count]
        return bones, Wp, [(me, PS.skin(bones, Wp, m), np.asarray(me.indices).reshape(-1, 3)) for me, m in zip(live, meshes)]
    hb, Mp, hm = posed(horse, hclip, 1e-2)
    seat = Mp[next(i for i, b in enumerate(hb) if b['name'].lower().replace('_', '').endswith('attachpoint'))]
    head = Mp[next(i for i, b in enumerate(hb) if b['name'] == 'head_x')]
    _, _, rm = posed(rider, rclip, 1e-3)
    conv = lambda P: (np.asarray(P, float) * 2.54) @ A @ Z  # noqa: E731
    out = {'pose__' + me.name: conv((np.c_[P, np.ones(len(P))] @ seat)[:, :3]) for me, P, _ in rm}
    HP, HF, base = [], [], 0
    for me, P, F in hm:
        HP.append(conv(P))
        HF.append(F + base)
        base += len(P)
    HP, HF = np.vstack(HP), np.vstack(HF)
    if np.einsum('ij,ij->i', HP[HF[:, 0]], np.cross(HP[HF[:, 1]], HP[HF[:, 2]])).sum() < 0:
        HF = HF[:, [0, 2, 1]]
    fwd = head[3, :3] - seat[3, :3]
    fwd[2] = 0
    out.update(occluder_P=HP, occluder_F=HF, forward=(fwd / np.linalg.norm(fwd)) @ A @ Z)
    return out


@pytest.mark.local('steam')
@pytest.mark.parametrize('model', sorted(VAN))
def test_the_vanilla_references_pass_their_own_unit_profile(tmp_path, model):
    rider_rel, rclip, horse_rel, hclip = VAN[model]
    rider = vanilla(tmp_path, rider_rel)
    raw = vanilla(tmp_path, rider_rel[:-4] + '.material.xmb').read_bytes()           # the archive holds XMB
    bt = L._bartool()[0]
    raw = bt.unwrap_alz4(raw) if raw[:4] == b'alz4' else raw
    mat = tmp_path / (Path(rider_rel).stem + '.material')
    mat.write_text(bt.xmb_to_xml(raw) if bt.is_xmb(raw) else raw.decode('utf-8-sig'), encoding='utf-8')
    pose = seated_pose(tmp_path, rider, rclip, vanilla(tmp_path, horse_rel), hclip)
    prof = L.resolve_profile(PROFILES, 'unit_rider_1024')
    res = L.lint(prof, intact=str(rider), intact_material=str(mat), tools=L.find_tools(PROFILES), use_dll=False,
                 pose=pose)
    status = {r['check']: r['status'] for r in res}
    assert status.pop('dll_read') == 'SKIP'                                          # --no-dll here; the lint run
    assert set(status.values()) == {'PASS'}, status                                 # with the DLL is in the report
    assert {'texel_density', 'unit_fit', 'unit_density'} <= set(status)            # the universal floor runs too
    d = next(r for r in res if r['check'] == 'unit_density')['data']['density']
    ref = PROFILES['unit_references'][model]['density']
    assert d['all'] == ref['all'] and d['visible_weighted']['p10'] == ref['visible_weighted']['p10']
    sig = next(r for r in res if r['check'] == 'unit_skeleton')['data']['signature']
    assert sig == PROFILES['unit_references'][model]['skeleton']
