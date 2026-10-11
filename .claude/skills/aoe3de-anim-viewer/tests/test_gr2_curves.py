"""aoe3de-anim-viewer clip reader (scripts/gr2_curves.py): curve normalisation per format, the clip record, the buffer
round trip and the Python reference evaluator; on the owner's machine, parity with clip_decode and pose_sim.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_gr2_curves.py -q     # CI: add -m "not local"

The synthetic cases build their gr2 bytes inside the test (tests/gr2_synth.py) and need Python, numpy and the
consumer's GR2 reader (skipped without it). The vanilla cases read the retail archives in memory, carry the consumer's
`local("steam")` marker and skip where no install is found: oprichnik_attack_a.gr2 must equal aoe3de-unit-model's
clip_decode at every key, and iron_rider_0 posed at its key 0 must equal aoe3de-unit-animation's pose_sim in the
converter frame (frame A), within 1e-6. Nothing is written outside pytest's temp folder.
"""
import sys
from functools import lru_cache
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
SKILLS = HERE.parents[1]
sys.path.insert(0, str(HERE.parent / 'scripts'))
sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402
try:
    import gr2_model as GM  # noqa: E402
    import gr2_curves as GC  # noqa: E402
except ImportError as e:                       # no consumer GR2 reader (a public export)
    pytest.skip(str(e), allow_module_level=True)
import clip_decode as CD  # noqa: E402  (aoe3de-unit-model, on sys.path through gr2_model)
import unit_gr2 as U  # noqa: E402
import gr2_synth as S  # noqa: E402


@pytest.fixture(autouse=True)
def cache_in_tmp(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))


Q90Y = S.axis_quat((0, 1, 0), 90)
ROT_KNOTS = [0.0, 0.25, 0.5, 1.0]
ROT_CONTROLS = [c for q in ((0, 0, 0, 1), S.axis_quat((0, 1, 0), 30), S.axis_quat((0, 1, 0), 60), Q90Y) for c in q]


def tracks():
    return [
        ('Bip01_Root', {'OrientationCurve': ('K32fC32f', 2, ROT_KNOTS, ROT_CONTROLS),
                        'PositionCurve': ('D3Constant32f', [0.0, 1.1418, 0.0]),
                        'ScaleShearCurve': ('Identity', 9)}),
        ('Bip01_Pelvis', {'OrientationCurve': ('D4Constant32f', [0, 0, 0, 1]),
                          'PositionCurve': ('K32fC32f', 1, [0.0, 0.5, 1.0], [0, 0, 0, 1, 2, 3, 2, 2, 2]),
                          'ScaleShearCurve': ('K32fC32f', 2, [], [])}),
        ('Bip01_Spine', {'OrientationCurve': None, 'PositionCurve': ('Constant32f', [4, 5, 6]),
                         'ScaleShearCurve': ('K32fC32f', 2, [0.0, 1.0], [1, 0, 0, 0, 1, 0, 0, 0, 1,
                                                                          2, 0, 0, 0, 1, 0, 0, 0, 1])}),
    ]


def clip_bytes(trs=None, **kw):
    placement = kw.pop('placement', S.transform((9, 9, 9), Q90Y, flags=0))
    return S.build_clip([('Bip01_Root', placement, trs or tracks())] + kw.pop('more_groups', []), **kw)


def record(data, clip_id='animation_library/test/clip.gr2'):
    w = C.BufferWriter('anim')
    rec, warnings = GC.clip_record(data, w, clip_id=clip_id)
    return rec, warnings, w


# ---------------------------------------------------------------- normalisation
def test_every_decoded_format_normalises_to_its_kind():
    rec, warnings, w = record(clip_bytes(duration=1.0, timestep=1 / 60))
    assert warnings == [] and rec['decodable'] and rec['unavailable_reason'] is None
    assert rec['formats'] == ['Constant32f', 'D3Constant32f', 'D4Constant32f', 'Identity', 'K32fC32f', 'none']
    root, pelvis, spine = rec['tracks']
    assert [t['bone'] for t in rec['tracks']] == ['Bip01_Root', 'Bip01_Pelvis', 'Bip01_Spine']
    o = root['orientation']
    assert (o['kind'], o['degree'], o['dim'], o['format']) == ('bspline', 2, 4, 'K32fC32f')
    anim = w.data()
    assert C.read_view(anim, o['knots']).tobytes() == np.array(ROT_KNOTS, '<f4').tobytes()
    assert C.read_view(anim, o['controls']).tobytes() == np.array(ROT_CONTROLS, '<f4').tobytes()
    assert o['controls']['components'] == 4 and o['controls']['count'] == 4 and o['knots']['components'] == 1
    assert root['position'] == {'kind': 'constant', 'dim': 3, 'format': 'D3Constant32f',
                                'value': [0.0, float(np.float32(1.1418)), 0.0]}
    assert root['scale_shear'] == {'kind': 'identity', 'dim': 9, 'format': 'Identity', 'inferred': False}
    assert pelvis['orientation'] == {'kind': 'constant', 'dim': 4, 'format': 'D4Constant32f',
                                     'value': [0.0, 0.0, 0.0, 1.0]}
    assert pelvis['position']['kind'] == 'bspline' and pelvis['position']['degree'] == 1
    assert pelvis['scale_shear'] == {'kind': 'identity', 'dim': 9, 'format': 'K32fC32f', 'inferred': True}
    assert spine['orientation'] == {'kind': 'identity', 'dim': 4, 'format': 'none', 'inferred': True}
    assert spine['position'] == {'kind': 'constant', 'dim': 3, 'format': 'Constant32f', 'value': [4.0, 5.0, 6.0]}
    assert spine['scale_shear']['controls']['components'] == 9
    for t in rec['tracks']:
        for key in ('position', 'orientation', 'scale_shear'):
            for v in ('knots', 'controls'):
                if v in t[key]:
                    assert t[key][v]['byteOffset'] % C.BUFFER_ALIGN == 0 and t[key][v]['dtype'] == 'f32'
    C.json_text(rec)


@pytest.mark.parametrize('spec, reason', [
    (('D4nK16uC15u',), 'curve-format-d4nk16uc15u'),
    (('raw', 0), 'curve-format-keyframes32f'),
    (('raw', 6), 'curve-format-k16uc16u'),
    (('raw', 99), 'curve-format-99'),
    (('Constant32f', [1.0, 2.0]), 'curve-malformed'),                       # 2 controls for a 4-vector
    (('K32fC32f', 2, [0.0, 1.0, 0.5], [0, 0, 0, 1] * 3), 'curve-malformed'),  # knots not ascending
])
def test_an_unsupported_curve_is_unavailable_and_the_clip_keeps_its_other_curves(spec, reason):
    trs = tracks() + [('Bip01_Head', {'OrientationCurve': spec})]
    rec, warnings, _ = record(clip_bytes(trs))
    head = rec['tracks'][-1]['orientation']
    assert head['kind'] == 'unavailable' and head['reason'] == reason and head['dim'] == 4
    assert rec['decodable'] is False and rec['unavailable_reason'] == reason
    assert rec['tracks'][0]['orientation']['kind'] == 'bspline'               # nothing else is dropped
    code = 'curve-malformed' if reason == 'curve-malformed' else 'curve-format-unsupported'
    assert [x['code'] for x in warnings] == [code] and 'Bip01_Head.orientation' in warnings[0]['message']


def test_timing_fields_and_the_initial_placement():
    rec, _, _ = record(clip_bytes(duration=1.5, timestep=1 / 192, oversampling=8.0))
    step = float(np.float32(1 / 192))
    assert rec['duration'] == 1.5 and rec['timestep'] == step and rec['oversampling'] == 8.0
    assert rec['fps_declared'] == 1.0 / step and rec['key_count'] == 289
    assert rec['track_group'] == {'name': 'Bip01_Root', 'initial_placement': {
        'position': [0.0, 0.0, 0.0], 'orientation': [0.0, 0.0, 0.0, 1.0], 'scale_shear': GM.IDENTITY_SS}}
    assert rec['precomp'] is None
    clip = GC.read_clip(clip_bytes(duration=0.05, timestep=1 / 60))
    assert clip.key_count == 4 and clip.key_times() == [0.0, 1 / 60, 2 / 60, 0.05]


def test_extra_track_groups_and_animations_are_named_not_hidden():
    second = ('bone_master', S.transform(flags=0), [('Bip01_Head', {'OrientationCurve': ('D4nK16uC15u',)})])
    rec, warnings, _ = record(clip_bytes(more_groups=[second], animations=2))
    assert rec['track_group']['name'] == 'Bip01_Root' and rec['decodable']     # the first group is complete
    msg = next(x for x in warnings if x['code'] == 'clip-extra-track-groups')['message']
    assert 'bone_master: 1 tracks, D4nK16uC15u' in msg and 'animation 1 group Bip01_Root' in msg


@pytest.mark.parametrize('kw, reason', [({'compression': 2}, 'gr2-compressed-oodle1'),
                                        ({'magic': S.MAGIC32}, 'gr2-32bit')])
def test_an_unreadable_clip_gives_the_unavailable_record(kw, reason):
    rec, warnings, w = record(clip_bytes(**kw))
    assert rec['decodable'] is False and rec['unavailable_reason'] == reason and rec['tracks'] == []
    assert rec['track_group'] is None and rec['key_count'] is None and w.data() == b''
    assert warnings[0]['code'] in ('gr2-compressed', 'gr2-32bit')


def test_a_model_without_animation_is_not_a_clip():
    model = S.build_model([{'name': 'Bip01_Root', 'parent': -1, 'transform': S.transform(flags=0)}], [])
    rec, warnings, _ = record(model)
    assert rec['unavailable_reason'] == 'clip-no-animation' and warnings[0]['code'] == 'clip-no-animation'


# ---------------------------------------------------------------- buffer round trip and reference evaluator
def test_curves_come_back_from_their_records_unchanged():
    data = clip_bytes()
    clip = GC.read_clip(data)
    rec, _, w = record(data)
    buffers = {'anim': w.data()}
    for tr, out in zip(clip.tracks, rec['tracks']):
        for key, _, _ in GC.TRACK_CURVES:
            a, b = tr.curves[key], GC.curve_from_record(out[key], buffers)
            assert (a.kind, a.dim, a.format, a.degree) == (b.kind, b.dim, b.format, b.degree)
            if a.kind == 'bspline':
                assert a.knots.tobytes() == b.knots.tobytes() and a.controls.tobytes() == b.controls.tobytes()
            for t in (0.0, 0.3, 0.77, 1.0):
                assert np.array_equal(GC.evaluate(a, t), GC.evaluate(b, t))


def test_the_reference_evaluator_is_clip_decodes_bspline_with_clamping():
    clip = GC.read_clip(clip_bytes())
    rot = clip.tracks[0].curves['orientation']
    K, Cn = np.array(ROT_KNOTS, np.float32).astype(float), np.array(ROT_CONTROLS, np.float32).astype(float).reshape(4, 4)
    for t in np.linspace(0, 1, 23):
        assert np.array_equal(GC.evaluate(rot, t), CD.bspline(K, Cn, 2, t))
        assert np.array_equal(GC.evaluate(rot, t, 'knots'), CD.bspline(K, Cn, 1, t))
    assert np.array_equal(GC.evaluate(rot, -5.0), Cn[0]) and np.array_equal(GC.evaluate(rot, 5.0), Cn[-1])
    pos = clip.tracks[1].curves['position']                                 # degree 1: a linear key at each knot
    assert np.allclose(GC.evaluate(pos, 0.25), [0.5, 1.0, 1.5]) and np.allclose(GC.evaluate(pos, 0.75), [1.5, 2, 2.5])
    assert GC.evaluate(clip.tracks[2].curves['orientation'], 0.4).tolist() == [0, 0, 0, 1]
    assert GC.evaluate(clip.tracks[0].curves['scale_shear'], 0.4).tolist() == GM.IDENTITY_SS
    bad = GC.Curve('unavailable', 4, 'D4nK16uC15u', reason='curve-format-d4nk16uc15u')
    with pytest.raises(ValueError):
        GC.evaluate(bad, 0.0)


def test_newton_normalisation_is_one_step_and_close_to_exact():
    q = np.array([0.0, 0.0, 0.0, 0.99])
    assert np.isclose(GC.normalize_quaternion(q, 'newton1')[3], 0.99 * (3 - 0.99 ** 2) / 2)
    assert np.isclose(GC.normalize_quaternion(q, 'exact')[3], 1.0)
    unit = np.array(S.axis_quat((1, 2, 3), 40))
    assert np.allclose(GC.normalize_quaternion(unit, 'newton1'), unit, atol=1e-15)
    e = 0.005                                                                # |q|^2 = 1 - e: the error is O(e^2)
    q = unit * np.sqrt(1 - e)
    dev = np.abs(GC.normalize_quaternion(q, 'newton1') - GC.normalize_quaternion(q, 'exact')).max()
    assert 1e-6 < dev < 1e-5


def test_track_matrix_is_the_local_rotation_then_scale_shear():
    clip = GC.read_clip(clip_bytes())
    spine = clip.tracks[2].curves                                            # scale-shear 1 -> 2 along x, at t = 1: 2
    M = GC.track_matrix(spine, 1.0)
    assert np.allclose(M[:3, :3], np.diag([2.0, 1, 1])) and np.allclose(M[3, :3], [4, 5, 6])
    root = clip.tracks[0].curves                                             # at t = 1 the last control: 90 deg about y
    assert np.allclose(GC.track_matrix(root, 1.0)[:3, :3], S.quat_matrix(Q90Y), atol=1e-6)


# ---------------------------------------------------------------- vanilla (the owner's machine)
@lru_cache(maxsize=1)
def game():
    try:
        return U.game_index()
    except (FileNotFoundError, ImportError, OSError):
        return None


def vanilla(rel):
    g = game()
    if g is None:
        pytest.skip('no AoE3 DE game archives (AOE3DE_GAME or the Steam folder)')
    bartool, idx = g
    return bartool.read_entry(idx[rel.lower()])


OPRICHNIK = 'art/animation_library/cavalry/oprichnik_attack_a.gr2'
IRON_RIDER = 'art/units/asians/chinese/iron_flail/iron_rider_0.gr2'


def gxo(M):
    return U.to_gxo_matrix(M)


@pytest.mark.local('steam')
def test_oprichnik_attack_a_equals_clip_decode_at_every_key(tmp_path):
    data = vanilla(OPRICHNIK)
    p = tmp_path / 'oprichnik_attack_a.gr2'
    p.write_bytes(data)
    ref = CD.decode(p)                                                       # GXO frame, exact normalisation
    rec, warnings, w = record(data, C.logical_path(OPRICHNIK))
    assert warnings == [] and rec['decodable'] and rec['formats'] == ['K32fC32f']
    assert rec['key_count'] == ref['keys'] == 289 and round(rec['fps_declared']) == 192 and rec['duration'] == 1.5
    assert len(rec['tracks']) == len(ref['tracks']) == 32
    buffers = {'anim': w.data()}
    clip = GC.read_clip(data)
    times = clip.key_times()
    dev_exact, dev_key0, dev_newton = 0.0, 0.0, 0.0
    for out, (name, keys) in zip(rec['tracks'], ref['tracks']):
        assert out['bone'] == name
        curves = {k: GC.curve_from_record(out[k], buffers) for k, _, _ in GC.TRACK_CURVES}
        for f, t in enumerate(times):
            exact = gxo(GC.track_matrix(curves, t, normalize='exact'))
            newton = gxo(GC.track_matrix(curves, t, normalize='newton1'))
            dev_exact = max(dev_exact, np.abs(exact - keys[f]).max())
            dev_newton = max(dev_newton, np.abs(newton - exact).max())
            if f == 0:
                dev_key0 = max(dev_key0, np.abs(newton - keys[0]).max())
    assert dev_exact < 1e-6 and dev_key0 < 1e-6
    assert dev_newton < 1e-4          # 1.6e-5 measured (7.9e-6 in quaternion terms): the rules differ off key 0


@pytest.mark.local('steam')
def test_iron_rider_posed_at_key_0_equals_pose_sim_in_the_converter_frame(tmp_path):
    sys.path.insert(0, str(SKILLS / 'aoe3de-unit-animation' / 'scripts'))
    try:
        import pose_sim as PS
    finally:
        sys.path.pop(0)
    model = GM.read_model(vanilla(IRON_RIDER))
    data = vanilla(OPRICHNIK)
    clip = GC.read_clip(data)
    p = tmp_path / 'oprichnik_attack_a.gr2'
    p.write_bytes(data)
    ref = CD.decode(p)
    # ours: gr2 frame, tracks bound by the engine's name rule, untracked bones keep their rest local
    by_name = {U.nm(tr.bone): tr for tr in clip.tracks}
    L = model.rest_local()
    driven = 0
    for i, b in enumerate(model.bones):
        tr = by_name.get(U.nm(b['name']))
        if tr is not None:
            L[i] = GC.track_matrix(tr.curves, 0.0)
            driven += 1
    W = GM.compose_world(L, model.parents)
    # pose_sim: frame A, rest worlds from the stored InverseWorld, keys from clip_decode
    bones = [{'name': b['name'], 'parent': b['parent'], 'W0': gxo(np.linalg.inv(np.array(b['inverse_world'])
                                                                                .reshape(4, 4)))}
             for b in model.bones]
    keys = {PS.norm(name): k[0] for name, k in ref['tracks']}
    Wp = PS.pose(bones, keys)
    assert driven >= 20
    dev = max(np.abs(gxo(W[i]) - Wp[i]).max() for i in range(len(bones)))
    assert dev < 1e-6, dev
