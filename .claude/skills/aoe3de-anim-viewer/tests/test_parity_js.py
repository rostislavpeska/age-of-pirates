"""aoe3de-anim-viewer M2 parity: the browser's skeleton maths (viewer/lib/skeleton.js, rig.js) against the Python
references, under Node's built-in test runner (tests/js/parity/*.test.mjs; skipped without Node 18+).

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_parity_js.py -q      # CI: add -m "not local"

CI-safe cases (fixtures built inside the test, no game bytes):
- B-spline: random K32fC32f curves (degrees 0..3, dims 3/4/9, repeated knots, times outside the knot range) evaluated
  in Python by gr2_curves.evaluate (= aoe3de-unit-model clip_decode.bspline), both methods; the Newton-step quaternion
  normalisation. JS must agree within 1e-6.
- Rig: the synthetic mounted unit (av_unit_fixture: horse, rider seated on ATTACHPOINT with syncanims=1, a rigid torch
  in the rider's hand with syncanims=0), its bundle written by bundle.py; JS world matrices against
  (a) gr2_model + gr2_curves composition in the gr2 frame (same Newton rule), and
  (b) aoe3de-unit-animation's pose_sim in the converter frame (frame A), the rider seated on the posed mount the way
      pose_sim seats it, keys from clip_decode (exact normalisation, so JS runs with 'exact' there), converted back to
      the gr2 frame.
Owner's machine (local marker): the same two references on the vanilla Iron Flail bundle (ypIronFlail) at the rider's
oprichnik idle key 0 and oprichnik attack key 133 (192 fps), the horse at the same time.
Bundles go to pytest's temp folder (av_common refuses a repository).
"""
import json
import os
import shutil
import subprocess
import sys
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
import bundle as B  # noqa: E402
import clip_decode as CD  # noqa: E402
import unit_gr2 as U  # noqa: E402
import av_unit_fixture as UF  # noqa: E402

NODE = shutil.which('node')
JS = HERE / 'js' / 'parity'
pytestmark = pytest.mark.skipif(not NODE, reason='node not on PATH')


def node_major():
    try:
        out = subprocess.run([NODE, '--version'], capture_output=True, text=True, timeout=30).stdout
        return int(out.strip().lstrip('v').split('.')[0])
    except (OSError, ValueError, subprocess.SubprocessError):
        return 0


def run_node(test_file, env_name, fixture):
    if node_major() < 18:
        pytest.skip('node --test needs Node 18 or newer')
    r = subprocess.run([NODE, '--test', '--test-reporter=tap', str(test_file)], capture_output=True, text=True,
                       encoding='utf-8', errors='replace', timeout=600, cwd=str(HERE.parent),
                       env=dict(os.environ, **{env_name: str(fixture)}))
    out = r.stdout + r.stderr
    assert r.returncode == 0, out[-8000:]
    assert '# fail 0' in out and '# skipped 0' in out, out[-4000:]
    return out


def write_fixture(path, obj):
    C.write_json(path, obj, indent=None)
    return path


# ---------------------------------------------------------------- B-spline
def random_curve(rng, degree, dim, repeated):
    n = int(rng.integers(1, 10)) if degree else int(rng.integers(1, 4))
    knots = np.cumsum(rng.uniform(0.05, 0.5, n)) - 0.05
    knots[0] = 0.0
    if repeated and n > 3:
        knots[2] = knots[1]
    K = knots.astype(np.float32)
    Cn = rng.uniform(-2, 2, (n, dim)).astype(np.float32)
    return GC.Curve('bspline', dim, 'K32fC32f', degree=degree, knots=K, controls=Cn)


def test_bspline_evaluation_matches_python(tmp_path):
    rng = np.random.default_rng(20261011)
    curves = []
    for degree in (0, 1, 2, 3):
        for dim in (3, 4, 9):
            for rep in range(4):
                c = random_curve(rng, degree, dim, repeated=(rep == 3))
                K = [float(x) for x in c.knots]
                times = sorted(set(K + [(a + b) / 2 for a, b in zip(K, K[1:])] + [-0.3, K[-1] + 0.4] +
                                   [float(x) for x in rng.uniform(-0.1, K[-1] + 0.1, 7)]))
                curves.append({'id': '%d-%d-%d' % (degree, dim, rep), 'degree': degree, 'dim': dim, 'knots': K,
                               'controls': [float(x) for x in c.controls.ravel()], 'times': times,
                               'expect': {m: [[float(v) for v in GC.evaluate(c, t, m)] for t in times]
                                          for m in ('bspline', 'knots')}})
    quats = []
    for _ in range(40):
        q = rng.normal(size=4)
        q = q / np.linalg.norm(q) * rng.uniform(0.99, 1.01)
        quats.append({'q': [float(x) for x in q],
                      'newton1': [float(x) for x in GC.normalize_quaternion(q, 'newton1')]})
    fx = write_fixture(tmp_path / 'bspline.json', {'tolerance': 1e-6, 'curves': curves, 'quaternions': quats})
    out = run_node(JS / 'bspline.test.mjs', 'AV_BSPLINE_FIXTURE', fx)
    assert 'bspline parity' in out


# ---------------------------------------------------------------- Python references for the rig
def to_gxo(M):
    return U.to_gxo_matrix(M)


def from_gxo(Mg, units=U.GXO_PER_ENGINE):
    """inverse of unit_gr2.to_gxo_matrix: converter frame -> gr2 frame."""
    out = np.eye(4)
    out[:3, :3] = U.A.T @ Mg[:3, :3] @ U.A
    out[3, :3] = Mg[3, :3] @ U.A / units
    return out


def gc_world(model, clip, t, placement=None, normalize='newton1'):
    """gr2_model + gr2_curves: tracks by the engine name rule, rest locals elsewhere, W = L @ W(parent) @ placement."""
    by = {U.nm(tr.bone): tr for tr in clip.tracks} if clip else {}
    L = model.rest_local()
    for i, b in enumerate(model.bones):
        tr = by.get(U.nm(b['name']))
        if tr is not None:
            L[i] = GC.track_matrix(tr.curves, t, normalize=normalize)
    W = GM.compose_world(L, model.parents)
    return W if placement is None else np.array([w @ placement for w in W])


def pose_sim():
    sys.path.insert(0, str(SKILLS / 'aoe3de-unit-animation' / 'scripts'))
    try:
        import pose_sim as PS
    finally:
        sys.path.pop(0)
    return PS


def pose_sim_world(PS, model, clip_path, frame, fps=None):
    """pose_sim.pose of a model (rest from its stored InverseWorld, frame A) at key `frame` of a clip decoded by
    clip_decode (GXO frame, exact normalisation); returns the GXO world matrices."""
    bones = [{'name': b['name'], 'parent': b['parent'],
              'W0': to_gxo(np.linalg.inv(np.array(b['inverse_world']).reshape(4, 4)))} for b in model.bones]
    keys = {}
    if clip_path is not None:
        ref = CD.decode(clip_path, fps=fps)
        keys = {PS.norm(name): k[min(frame, len(k) - 1)] for name, k in ref['tracks']}
    return PS.pose(bones, keys)


def pose_sim_vertices(PS, model, Wp, folder, seat=None):
    """pose_sim.skin of every mesh (the model written as converter GXO text by crosscheck.gxo_model_text, read back by
    pose_sim.parse_model), seated by `seat` (GXO) when given; positions converted back to the gr2 frame."""
    import crosscheck as XC
    path = Path(folder) / ('%s.gxo' % abs(hash(model.skeleton_name)))
    C.write_bytes(path, XC.gxo_model_text(model).encode('utf-8'), 'pose_sim inputs')
    bones, meshes = PS.parse_model(str(path))
    out = []
    for m in meshes:
        P = PS.skin(bones, Wp, m)
        if seat is not None:
            P = (np.c_[P, np.ones(len(P))] @ seat)[:, :3]
        out.append([float(x) for x in (P @ U.A / U.GXO_PER_ENGINE).ravel()])
    return out


def seat_index(model):
    return next(i for i, b in enumerate(model.bones) if b['name'].lower().replace('_', '').endswith('attachpoint'))


def flat(W):
    return [float(x) for x in np.asarray(W).reshape(-1)]


# ---------------------------------------------------------------- synthetic rig
def test_rig_matches_gr2_composition_and_pose_sim_on_a_synthetic_unit(tmp_path, monkeypatch):
    monkeypatch.setenv(C.CACHE_ENV, str(tmp_path / 'cache'))
    u = UF.write_unit(tmp_path)
    res = B.build_bundle(animfile=u['horse'], fs=UF.vfs(u), out_root=tmp_path / 'bundles', lighting=False,
                         log=lambda m: None)
    mod = Path(u['mod']) / 'art'
    horse = GM.read_model(mod / u['horse_model'])
    rider = GM.read_model(mod / u['rider_model'])
    torch = GM.read_model(mod / u['torch_model'])
    clips = {k: GC.read_clip(mod / v) for k, v in u['clips'].items()}
    seat = seat_index(horse)
    hand = rider.bone_index('Bip01_R_Hand')
    cases = []

    def case(name, anim, t, horse_clip, rider_clip, rider_t, variant=0, sync='absolute', torch_on=False):
        Wh = gc_world(horse, clips[horse_clip], min(t, clips[horse_clip].duration))
        Wr = gc_world(rider, clips[rider_clip], rider_t, Wh[seat])
        exp = [{'source': 'gr2_curves', 'role': 'main', 'model': u['horse_model'], 'worlds': flat(Wh),
                'clip': u['clips'][horse_clip]},
               {'source': 'gr2_curves', 'role': 'child', 'model': u['rider_model'], 'worlds': flat(Wr),
                'clip': u['clips'][rider_clip]}]
        if torch_on:
            exp.append({'source': 'gr2_curves', 'role': 'attachment', 'model': u['torch_model'],
                        'worlds': flat(gc_world(torch, None, 0, Wr[hand])), 'clip': None})
        cases.append({'name': name, 'anim': anim, 'variant': variant, 'sync': sync, 'time': t, 'tolerance': 1e-9,
                      'expect': exp})

    case('idle t0', 'Idle', 0.0, 'horse_idle', 'rider_idle', 0.0)
    case('idle t0.7313', 'Idle', 0.7313, 'horse_idle', 'rider_idle', 0.7313)
    case('idle t2.3 (horse holds its end)', 'Idle', 2.3, 'horse_idle', 'rider_idle', 2.3)
    case('idle phase t1.0', 'Idle', 1.0, 'horse_idle', 'rider_idle',
         1.0 / clips['horse_idle'].duration * clips['rider_idle'].duration, sync='phase')
    case('attack t0.4 + torch', 'Attack', 0.4, 'horse_attack', 'rider_attack', 0.4, torch_on=True)
    case('highstep: rider falls back to Idle', 'Highstep', 0.2, 'horse_attack', 'rider_idle', 0.2)

    # pose_sim in the converter frame at clip keys (60 fps for the idle clips), exact normalisation on both sides
    PS = pose_sim()
    for frame in (0, 31, 77):
        t = frame / 60.0
        Mp = pose_sim_world(PS, horse, mod / u['clips']['horse_idle'], frame)
        Rp = pose_sim_world(PS, rider, mod / u['clips']['rider_idle'], frame)
        # pose_sim rebuilds rest locals from the float32 InverseWorld, the bundle from the float32 rest transforms:
        # untracked bones differ at that storage precision (5e-8 here), hence 1e-6 (the converter parity level)
        verts = [{'source': 'pose_sim', 'role': role, 'model': mid, 'mesh': i, 'positions': pos, 'tolerance': 1e-6}
                 for role, mid, model, Wp, st in (('main', u['horse_model'], horse, Mp, None),
                                                  ('child', u['rider_model'], rider, Rp, Mp[seat]))
                 for i, pos in enumerate(pose_sim_vertices(PS, model, Wp, tmp_path, st))]
        cases.append({'name': 'pose_sim idle key %d' % frame, 'anim': 'Idle', 'time': t, 'normalize': 'exact',
                      'tolerance': 1e-6, 'vertices': verts,
                      'expect': [{'source': 'pose_sim', 'role': 'main', 'model': u['horse_model'],
                                  'worlds': flat([from_gxo(w) for w in Mp])},
                                 {'source': 'pose_sim', 'role': 'child', 'model': u['rider_model'],
                                  'worlds': flat([from_gxo(w @ Mp[seat]) for w in Rp])}]})
    fx = write_fixture(tmp_path / 'pose.json', {'bundle_dir': str(res.folder), 'cases': cases})
    out = run_node(JS / 'pose.test.mjs', 'AV_POSE_FIXTURE', fx)
    assert out.count('max |JS - Python|') == sum(len(c['expect']) + len(c.get('vertices', [])) for c in cases)


# ---------------------------------------------------------------- the vanilla Iron Flail (owner's machine)
@pytest.fixture(scope='module')
def iron_flail(tmp_path_factory):
    mp = pytest.MonkeyPatch()
    root = tmp_path_factory.mktemp('iron')
    mp.setenv(C.CACHE_ENV, str(root / 'cache'))
    import vfs as V
    fs = V.VFS()
    if not any(lay.kind == 'game' for lay in fs.layers):
        mp.undo()
        pytest.skip('no AoE3 DE install found')
    try:
        res = B.build_bundle(proto='ypIronFlail', fs=fs, out_root=root / 'bundles', log=lambda m: None)
    except LookupError as e:
        mp.undo()
        pytest.skip(str(e))
    yield fs, res, root
    mp.undo()


IDLE_KEY, ATTACK_KEY = 0, 133


@pytest.mark.local
def test_iron_flail_rig_matches_gr2_composition_and_pose_sim(iron_flail):
    fs, res, root = iron_flail
    m = res.manifest
    horse_af = m['animfiles'][m['composition']['main']]
    rider_af = m['animfiles'][m['composition']['pairing']['child']]
    horse_id, rider_id = (m['animfiles'][a]['components'][0]['resolved'][0]['models'][0]
                          for a in (m['composition']['main'], m['composition']['pairing']['child']))
    horse = GM.read_model(fs.read(horse_id).data)
    rider = GM.read_model(fs.read(rider_id).data)
    seat = seat_index(horse)
    PS = pose_sim()
    cases = []
    for anim, key in (('Idle', IDLE_KEY), ('Attack_melee', ATTACK_KEY)):
        hclip_id = horse_af['anims'][anim]['variants'][0]['clip']
        rclip_id = rider_af['anims'][anim]['variants'][0]['clip']
        hpath, rpath = fs.materialize(hclip_id), fs.materialize(rclip_id)
        hclip, rclip = GC.read_clip(hpath), GC.read_clip(rpath)
        fps = round(rclip.fps_declared)
        t = min(key / fps, rclip.duration)
        assert 'oprichnik' in rclip_id
        Wh = gc_world(horse, hclip, min(t, hclip.duration))
        Wr = gc_world(rider, rclip, t, Wh[seat])
        cases.append({'name': '%s rider key %d (t %.5f)' % (anim, key, t), 'anim': anim, 'time': t, 'tolerance': 1e-9,
                      'expect': [{'source': 'gr2_curves', 'role': 'main', 'model': horse_id, 'worlds': flat(Wh),
                                  'clip': hclip_id, 'bones': [b['name'] for b in horse.bones]},
                                 {'source': 'gr2_curves', 'role': 'child', 'model': rider_id, 'worlds': flat(Wr),
                                  'clip': rclip_id, 'bones': [b['name'] for b in rider.bones]}]})
        # pose_sim: both clips decoded at the rider's key rate, so key `key` is the same time on the horse
        Mp = pose_sim_world(PS, horse, hpath, key, fps=fps)
        Rp = pose_sim_world(PS, rider, rpath, key, fps=fps)
        verts = [{'source': 'pose_sim', 'role': role, 'model': mid, 'mesh': i, 'positions': pos, 'tolerance': 1e-6}
                 for role, mid, model, Wp, st in (('main', horse_id, horse, Mp, None),
                                                  ('child', rider_id, rider, Rp, Mp[seat]))
                 for i, pos in enumerate(pose_sim_vertices(PS, model, Wp, root, st))]
        cases.append({'name': 'pose_sim %s key %d' % (anim, key), 'anim': anim, 'time': t, 'normalize': 'exact',
                      'tolerance': 1e-6, 'vertices': verts,
                      'expect': [{'source': 'pose_sim', 'role': 'main', 'model': horse_id,
                                  'worlds': flat([from_gxo(w) for w in Mp])},
                                 {'source': 'pose_sim', 'role': 'child', 'model': rider_id,
                                  'worlds': flat([from_gxo(w @ Mp[seat]) for w in Rp])}]})
    fx = write_fixture(root / 'pose_iron.json', {'bundle_dir': str(res.folder), 'cases': cases})
    out = run_node(JS / 'pose.test.mjs', 'AV_POSE_FIXTURE', fx)
    devs = [line for line in out.splitlines() if 'max |JS - Python|' in line]
    print('\n'.join(devs))
    assert len(devs) == 8 + sum(len(c.get('vertices', [])) for c in cases)
