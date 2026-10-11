"""Reference tests (skipped unless the environment names the inputs, conftest.py): the CC0 hm08 passes every rule, the
accepted realistic calibration set passes the reference grade except its recorded defects, the negative controls fail,
our G1 r2 squat head fails its head metrics under a game profile, the estimator agrees with the assets' rigs, and the
step-2 verifier's corrected numbers on S15, S14 and S01 are reproduced."""
import glob
import json
import os

import numpy as np
import pytest

from conftest import load_item, item_path
import toplib as TL
import rules as RU
import tl_io

KEYS = ['l_shoulder', 'l_elbow', 'l_wrist', 'l_hip', 'l_knee', 'l_ankle', 'r_shoulder', 'r_elbow', 'r_wrist', 'r_hip',
        'r_knee', 'r_ankle', 'neck', 'head']


def roots(library_root=None, mpfb=None):
    r = {}
    if library_root:
        r['library_root'] = library_root
    if mpfb:
        r['mpfb'] = mpfb
    return r


def analyse_item(it, rts, exclude, blender=None):
    d = load_item(it, rts, exclude=exclude, need_t2q=it.get('face_source') == 't2q', blender=blender)
    return TL.analyse(d, kind=it.get('kind', 'body'), skeleton=it.get('skeleton', 'auto'),
                      face_source=it.get('face_source', 'native'), declared_caps=it.get('inputs', {}).get('declared_caps'))


def hm08_item(items):
    return [i for i in items['items'] if i['id'] == 'hm08'][0]


# ---------------------------------------------------------------------------------------------------------------- hm08
def test_hm08_passes_every_rule(mpfb_data, calibration_items):
    rep = analyse_item(hm08_item(calibration_items), roots(mpfb=mpfb_data), calibration_items['exclude'])
    res = RU.check(rep, inputs=dict(subject='reference', declared_openings=0))
    assert res['grade'] == 'PASS', res['must_fail'] + res['should_fail']
    assert rep['face_kinds']['ngons'] == 0 and rep['poles']['v6plus'] == 0
    assert rep['face']['eyes_found'] and min(rep['face']['eye_rings']) >= 2 and rep['face']['mouth_rings'] >= 2
    # the shoulder / hip flow measure reads the arm-root and thigh-root loops the ring metric missed (D20)
    assert rep['flow']['shoulder_l']['arm_root_wrapping'] >= 2 and rep['flow']['hip_l']['wrapping_loops'] >= 2


def test_estimator_matches_rigs(mpfb_data, library_root, calibration_items):
    rts = roots(library_root, mpfb_data)
    for sid, med, mx in (('hm08', 0.03, 0.06), ('S07', 0.03, 0.06)):
        it = [i for i in calibration_items['items'] if i['id'] == sid][0]
        d = load_item(it, rts, exclude=calibration_items['exclude'])
        fs = it.get('face_source', 'native')
        Ja = TL.analyse(d, kind='body', skeleton='rig', face_source=fs)['_ctx']
        Je = TL.analyse(d, kind='body', skeleton='estimate', face_source=fs)['_ctx']
        H = Ja['H']
        err = [np.linalg.norm(Ja['skel']['J'][k] - Je['skel']['J'][k]) / H for k in KEYS]
        assert np.median(err) <= med and max(err) <= mx, (sid, np.round(err, 3))


# ---------------------------------------------------------------------------------------------------------------- calibration set
def test_calibration_set_reference_grade(mpfb_data, library_root, calibration_items):
    rts = roots(library_root, mpfb_data)
    bad = {}
    for it in calibration_items['items']:
        if it['role'] != 'calibration':
            continue
        rep = analyse_item(it, rts, calibration_items['exclude'])
        inputs = dict(it.get('inputs', {}), subject='reference', recorded_defects=it.get('recorded_defects', []))
        res = RU.check(rep, inputs=inputs)
        if res['unexpected_fail']:
            bad[it['id']] = res['unexpected_fail']
    assert not bad, bad


def test_never_loads_stylized(library_root, calibration_items):
    for it in calibration_items['items']:
        if not it['path'].endswith('.blend'):
            continue
        d = load_item(it, roots(library_root), exclude=calibration_items['exclude'])
        names = [o['name'] for o in d['source']['objects']]
        assert names and not any('styliz' in n.lower() for n in names), (it['id'], names)


# ---------------------------------------------------------------------------------------------------------------- controls
@pytest.fixture(scope='module')
def controls(mpfb_data, blender, tmp_path_factory):
    out = tmp_path_factory.mktemp('controls')
    d = tl_io.load(os.path.join(mpfb_data, '3dobjs', 'base.obj'), group='body', joints_from_groups='joint-')
    src = os.path.join(out, 'hm08_body.npz')
    tl_io.save_npz(src, d['V'], d['faces'])
    import tl_skeleton as SK
    J, _ = SK.canon_from_rig(d['rig'])
    sk = os.path.join(out, 'hm08_skeleton.json')
    json.dump({k: [float(x) for x in v] for k, v in J.items()}, open(sk, 'w'))
    made = {}
    for name, args in (('decimate', ['--method', 'decimate', '--ratio', '0.10']),
                       ('quadriflow', ['--method', 'quadriflow', '--faces', '2000', '--seed', '0'])):
        p = os.path.join(out, name + '.npz')
        tl_io.run_blender(['control', src, p] + args, exe=blender)
        made[name] = p
    return made, sk


def test_negative_controls_fail(controls):
    made, sk = controls
    for name, p in made.items():
        rep = TL.analyse(tl_io.load(p), kind='body', skeleton=sk)
        res = RU.check(rep, inputs=dict(subject='build', stage='reduction'))
        assert res['grade'] == 'FAIL', name
        if name == 'decimate':
            assert {'M1', 'P1', 'P3'} <= set(res['must_fail'])
        if name == 'quadriflow':
            assert 'M4' in res['must_fail'] and {'L1', 'P2'} <= set(res['should_fail'])


def test_g1_squat_head_fails_head_metrics(blender):
    g1, prof = os.environ.get('CTA_OWN_G1'), os.environ.get('CTA_GAME_PROFILE')
    if not g1 or not prof or not os.path.isfile(g1) or not os.path.isfile(prof):
        pytest.skip('CTA_OWN_G1 / CTA_GAME_PROFILE not set')
    rep = TL.analyse(tl_io.load(g1, select='^Pyeongon_G1_LOW_Body$', blender=blender), kind='body')
    res = RU.check(rep, RU.load_profile(prof), dict(subject='build'))
    assert res['rules']['F5']['verdict'] == 'FAIL', res['rules']['F5']
    assert 'F5' in res['must_fail']


# ---------------------------------------------------------------------------------------------------------------- step-2 verifier
def _ours(d, fs):
    jt = TL.judged_topology(d, fs)
    t = jt['topo']
    fk = TL.face_kinds(t)
    pc, _, _ = TL.pole_census(t)
    excl = pc['excluded_off_boundary'].get('nonmanifold', {})
    return dict(faces=fk['faces'], quads=fk['quads'], tris=fk['tris'], v3=pc['v3'], v5=pc['v5'], v6=pc['v6plus'],
                v3_nm=excl.get('3', 0), v5_nm=excl.get('5', 0), v6_nm=excl.get('6', 0), nonman=t.n_nonmanifold,
                verts=jt['weld']['verts_final'])


@pytest.mark.parametrize('sid,select', [('S15', 'Cube_Material'), ('S14', None), ('S01', None)])
def test_verifier_numbers_reproduced(sid, select, library_root, verifier_data, blender):
    g = json.load(open(os.path.join(verifier_data, sid + '_glb.json')))
    m = json.load(open(os.path.join(verifier_data, 'my_t2q_measures.json')))[sid]
    path = glob.glob(os.path.join(library_root, 'sketchfab-%s-*' % sid, 'model.glb'))[0]
    d = tl_io.load(path, select=select, need_t2q=True, blender=blender)
    assert _ours(d, 'native')['verts'] == g['welded_verts']
    # OGT, six-sided runs read as two quads (the verifier's 'ogt_6runs_as_quad_pairs' reading): exact
    o = _ours(d, 'ogt')
    v = g.get('ogt_6runs_as_quad_pairs') or g['ogt']
    assert o['faces'] == sum(v['sides_hist'].values()) and o['quads'] == v['sides_hist'].get('4', 0)
    assert o['nonman'] == v['nonmanifold_edges']
    # poles: the library does not count vertices on non-manifold edges as inner (D7); added back they match
    assert o['v3'] + o['v3_nm'] == v['poles']['v3'] and o['v5'] + o['v5_nm'] == v['poles']['v5']
    assert o['v6'] + o['v6_nm'] == v['poles']['v6plus']
    # Tris to Quads with normals: join_triangles breaks ties by face order, so counts agree within 0.5 % (faces,
    # quads) and 6 % (poles); the non-manifold count exactly
    t = _ours(d, 't2q')
    assert abs(t['faces'] - m['faces']) <= max(3, 0.005 * m['faces']) and abs(t['quads'] - m['quads']) <= max(3, 0.005 * m['quads'])
    assert t['nonman'] == m['nonmanifold_edges']
    for k, key in (('v3', 'v3'), ('v5', 'v5'), ('v6', 'v6plus')):
        assert abs(t[k] - m['poles'][key]) <= max(2, 0.07 * m['poles'][key]), (k, t[k], m['poles'][key])
