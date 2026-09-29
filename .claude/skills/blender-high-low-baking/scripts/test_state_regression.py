"""Specimen proof for state_regression.py: a small synthetic building (one eave run with FRONT / UNDER / BACK rows,
a FRONT member elsewhere, a roof bank above, a three-segment ridge run) is fingerprinted as the accepted state; every
seeded regression FAILS against it (opaque band, straight band that keeps the cut, blanked ridge normal, member off
its role, a partial BaseColor hole, a partial flat normal patch), the unchanged state and a re-laid-out twin PASS. Built in pytest's tmp_path -
never images in the repo.

python -m pytest .claude/skills/blender-high-low-baking/scripts/test_state_regression.py -q
(plain Python + numpy + PIL/OpenCV; no Blender.)
"""
import json
import struct
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import state_regression as SR  # noqa: E402

SIZE, TPU = 256, 100.0          # 100 texels per metre on a 256 page

# chart rectangles in texels (col0, row0 bottom-up) and their world placement
CH = dict(FRONT=(10, 20), UNDER=(10, 40), BACK=(10, 80), ROOF=(10, 110), R0=(10, 210), R1=(80, 210), R2=(150, 210))


def encode_normal(h, strength):
    gy, gx = np.gradient(h.astype(np.float64))
    n = np.stack([-gx * strength, gy * strength, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


PERIOD = 0.15                   # disc spacing (the Korean TC eave: ~7 scallops per metre)
MEAN_CUT = 0.02 + 0.035 * 2 / np.pi


def edge(xl, band='scallops'):
    """cut height (m) of the FRONT alpha along the eave: disc arcs, a straight edge at the SAME mean cut (level or
    sloping 1 cm per metre - the scallops lost while the cut fraction stays), or no cut at all (opaque)."""
    if band == 'scallops':
        return 0.02 + 0.035 * np.abs(np.sin(np.pi * xl / PERIOD))
    if band == 'straight':
        return np.full_like(xl, MEAN_CUT)
    if band == 'sloped':
        return MEAN_CUT + 0.01 * (xl - 1.0)
    return np.zeros_like(xl) - 1


def quad(c0, r0, w, h):
    return [[c0 / SIZE, r0 / SIZE], [(c0 + w) / SIZE, r0 / SIZE], [(c0 + w) / SIZE, (r0 + h) / SIZE], [c0 / SIZE, (r0 + h) / SIZE]]


def build(tmp, band='scallops', shift=0, member_on='FRONT', blank_ridge=False, hole=0, flat_roof=0.0, name='state'):
    """-> (state_dir, plan.json, geometry.json). shift moves every chart right by `shift` texels (another UV layout
    with the same content per element class). hole = side (texels) of a black BaseColor square in the roof chart;
    flat_roof = share of the roof chart (bottom rows) whose normal is blanked flat."""
    d = Path(tmp) / name; d.mkdir(parents=True, exist_ok=True)
    faces, plan, k = [], {}, 0

    def add(v, n, uv, fam, mat, owner=True):
        nonlocal k
        faces.append(dict(i=k, v=v, n=n, c=list(np.mean(v, 0))))
        plan[f'S:{k}'] = dict(page='P256', uv=uv, family=f'S:{fam}', family_size=1, owner=owner, material=mat); k += 1
    s = shift
    for j in range(4):                                     # eave run along x, out = -y
        x0, x1 = 0.5 * j, 0.5 * (j + 1)
        add([[x0, 0, 3.0], [x1, 0, 3.0], [x1, 0, 3.16], [x0, 0, 3.16]], [0, -1, 0], quad(CH['FRONT'][0] + s + 50 * j, CH['FRONT'][1], 50, 16), 'eave_front', 'EAVE_CUTOUT')
        q = quad(CH['UNDER'][0] + s + 50 * j, CH['UNDER'][1], 50, 32)     # soffit descending inward: normal down-out
        add([[x1, 0.3, 2.9], [x0, 0.3, 2.9], [x0, 0, 3.0], [x1, 0, 3.0]], [0, -0.3162, -0.9487], [q[2], q[3], q[0], q[1]], 'eave_under', 'EAVE_CUTOUT')
        q = quad(CH['BACK'][0] + s + 50 * j, CH['BACK'][1], 50, 16)      # back lip 5 cm behind the front, facing in
        add([[x1, 0.05, 3.0], [x0, 0.05, 3.0], [x0, 0.05, 3.16], [x1, 0.05, 3.16]], [0, 1, 0], [q[1], q[0], q[3], q[2]], 'eave_back', 'EAVE_CUTOUT')
        add([[x0, 0, 3.16], [x1, 0, 3.16], [x1, 0.8, 3.5], [x0, 0.8, 3.5]], [0, -0.391, 0.920], quad(CH['ROOF'][0] + s + 50 * j, CH['ROOF'][1], 50, 87), 'roof', 'ROOF_TILE')
    # a FRONT member on another stretch of the same eave line, reading FRONT owner texels (or, seeded, UNDER texels)
    tgt = dict(FRONT=quad(CH['FRONT'][0] + s + 50, CH['FRONT'][1], 50, 16), UNDER=quad(CH['UNDER'][0] + s + 50, CH['UNDER'][1] + 8, 50, 16))[member_on]
    add([[2.5, 0, 3.0], [3.0, 0, 3.0], [3.0, 0, 3.16], [2.5, 0, 3.16]], [0, -1, 0], tgt, 'eave_front', 'EAVE_CUTOUT', owner=False)
    for j, key in enumerate(('R0', 'R1', 'R2')):             # ridge run: three straight segments, one chart each
        x0, x1 = 0.6 * j, 0.6 * (j + 1)
        add([[x0, 0.4, 4.0], [x1, 0.4, 4.0], [x1, 0.5, 4.0], [x0, 0.5, 4.0]], [0, 0, 1], quad(CH[key][0] + s, CH[key][1], 60, 10), f'ridge_{j}', 'ROOF_TRIM')
    # maps (top-down arrays; texel (col, y bottom-up) -> row SIZE - 1 - y)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]; ybu = SIZE - 1 - yy
    op = np.ones((SIZE, SIZE)); h = np.zeros((SIZE, SIZE)); st = np.zeros((SIZE, SIZE)); rng = np.random.default_rng(3)
    col = 0.45 + 0.08 * np.kron(rng.random((SIZE // 4, SIZE // 4)), np.ones((4, 4)))

    def region(key, w, hgt):
        c0, r0 = CH[key]; c0 += s
        m = (xx >= c0) & (xx < c0 + w) & (ybu >= r0) & (ybu < r0 + hgt)
        return m, (xx + 0.5 - c0) / TPU, (ybu + 0.5 - r0) / TPU
    m, xl, zl = region('FRONT', 200, 16)
    op[m] = np.clip((zl - edge(xl, band)) * TPU + 0.5, 0, 1)[m]
    h[m] = (np.cos(2 * np.pi * xl / PERIOD) * np.sin(np.pi * zl / 0.16))[m]; st[m] = 1.5
    m, xl, zl = region('BACK', 200, 16)
    op[m] = np.clip((zl - edge(xl, band)) * TPU + 0.5, 0, 1)[m]               # the same silhouette behind the front
    m, xl, zl = region('UNDER', 200, 32); op[m] = 0.0; h[m] = (0.3 * np.cos(2 * np.pi * xl / PERIOD))[m]; st[m] = 1.0
    m, xl, zl = region('ROOF', 200, 87); h[m] = np.cos(2 * np.pi * xl / PERIOD)[m]; st[m] = 2.0
    for key in ('R0', 'R1', 'R2'):
        m, xl, zl = region(key, 60, 10); h[m] = np.cos(2 * np.pi * xl / 0.1)[m]; st[m] = 1.5
    nrm = encode_normal(h * 4, 1.0)
    nrm = np.where(st[..., None] > 0, nrm, np.array([0.5, 0.5, 1.0]))
    if blank_ridge:
        m, _, _ = region('R1', 60, 10); nrm[m] = [0.5, 0.5, 1.0]
    if flat_roof:
        m, _, zl = region('ROOF', 200, 87); nrm[m & (zl < flat_roof * 0.87)] = [0.5, 0.5, 1.0]
    base = np.stack([col, col * 0.9, col * 0.8], -1)
    if hole:
        c0, r0 = CH['ROOF']; c0 += s + 60; base[(xx >= c0) & (xx < c0 + hole) & (ybu >= r0 + 30) & (ybu < r0 + 30 + hole)] = 0
    Image.fromarray((np.clip(nrm, 0, 1) * 255 + 0.5).astype(np.uint8)).save(d / 'P256_Normal.png')
    Image.fromarray((np.clip(base, 0, 1) * 255 + 0.5).astype(np.uint8)).save(d / 'P256_BaseColor.png')
    Image.fromarray((np.repeat(op[..., None], 3, -1) * 255 + 0.5).astype(np.uint8)).save(d / 'P256_Opacity.png')
    (d / 'plan.json').write_text(json.dumps(dict(faces=plan)))
    (d / 'geometry.json').write_text(json.dumps({'Obj': dict(faces=faces)}))
    return d, d / 'plan.json', d / 'geometry.json'


def fp_of(tmp, **kw):
    d, plan, geo = build(tmp, **kw)
    st, src = SR.build_state(d, plan, geo, {'Obj': 'S'})
    return SR.fingerprint(st, kw.get('name', 'state'), src)


@pytest.fixture(scope='module')
def accepted(tmp_path_factory):
    return fp_of(tmp_path_factory.mktemp('acc'), name='accepted')


def fail_ids(rep):
    return {r['id'] for r in rep['fails']}


def test_specimen_measures(accepted):
    e = accepted['eave']['FRONT']
    assert 5.5 <= e['scallops_per_m'] <= 7.5, e                 # 6.7 discs per metre on the specimen
    assert e['amplitude_m'] >= 0.015 and e['rms_m'] >= 0.005, e
    c = accepted['classes']
    assert c['EAVE_CUTOUT.FRONT']['maps']['Opacity']['cut'] > 0.15
    assert c['EAVE_CUTOUT.UNDER']['maps']['Opacity']['cut'] == 1.0
    assert 95 <= c['ROOF_TILE']['density']['median'] <= 105
    assert c['EAVE_CUTOUT.FRONT']['registration']['checked'] == 1 and not c['EAVE_CUTOUT.FRONT']['registration']['flagged']
    assert accepted['eave']['back_agreement'] >= 0.95
    assert accepted['eave']['gate']['per_role']                 # qa_detectors.eave_alpha_check was called


def test_unchanged_state_is_clean(accepted, tmp_path):
    rep = SR.compare(accepted, fp_of(tmp_path, name='again'))
    assert rep['verdict'] == 'PASS', rep['fails']
    assert rep['same_layout'] and rep['checked'] > 20


def test_lost_scallops_fail(accepted, tmp_path):
    rep = SR.compare(accepted, fp_of(tmp_path, band='opaque', name='opaque'))
    assert rep['verdict'] == 'FAIL'
    ids = fail_ids(rep)
    assert {'eave.FRONT.scallops_per_m', 'eave.FRONT.amplitude_m', 'eave.FRONT.rms_m', 'alpha.cut[EAVE_CUTOUT.FRONT]'} <= ids, ids


@pytest.mark.parametrize('band', ['straight', 'sloped'])
def test_straight_band_with_the_same_cut_fails(accepted, tmp_path, band):
    """the scallops removed while the FRONT stays cut by the same fraction (a level or sloping straight edge): the cut
    fraction passes, the silhouette measure fails - the case the owner found by eye."""
    new = fp_of(tmp_path, band=band, name=band)
    e = new['eave']['FRONT']
    assert e['scallops_per_m'] <= 0.5 and e['rms_m'] <= 0.3 * accepted['eave']['FRONT']['rms_m'], e
    rep = SR.compare(accepted, new)
    ids = fail_ids(rep)
    assert {'eave.FRONT.scallops_per_m', 'eave.FRONT.amplitude_m', 'eave.FRONT.rms_m'} <= ids, ids
    assert 'alpha.cut[EAVE_CUTOUT.FRONT]' not in ids                  # same cut: only the silhouette tells
    rep2 = SR.compare(accepted, fp_of(tmp_path / 'relaid', band=band, shift=20, name=band + '_relaid'))
    assert not rep2['same_layout'] and {'eave.FRONT.scallops_per_m', 'eave.FRONT.rms_m'} <= fail_ids(rep2)


def test_partial_hole_in_one_chart_fails(accepted, tmp_path):
    """a 16 x 16 black BaseColor square = 1.5 % of the roof chart: under the class tolerance, caught per chart."""
    rep = SR.compare(accepted, fp_of(tmp_path, hole=16, name='hole'))
    ids = fail_ids(rep)
    assert 'chart.empty[S:roof.BaseColor]' in ids, ids
    assert 'map.empty[ROOF_TILE.BaseColor]' not in ids


def test_flat_normal_patch_fails(accepted, tmp_path):
    """20 % of the roof chart's normal blanked flat: per chart in the same layout, as a world-m2 patch across layouts."""
    rep = SR.compare(accepted, fp_of(tmp_path, flat_roof=0.2, name='flatpatch'))
    ids = fail_ids(rep)
    assert {'chart.flat[S:roof.Normal]', 'chart.normal.presence[S:roof]'} <= ids, ids
    rep2 = SR.compare(accepted, fp_of(tmp_path / 'relaid', flat_roof=0.2, shift=20, name='flatpatch_relaid'))
    assert not rep2['same_layout']
    assert {'flat.area[ROOF_TILE.Normal]', 'flat.max_m2[ROOF_TILE.Normal]'} <= fail_ids(rep2), fail_ids(rep2)


def test_blank_ridge_normal_fails(accepted, tmp_path):
    rep = SR.compare(accepted, fp_of(tmp_path, blank_ridge=True, name='blank'))
    ids = fail_ids(rep)
    assert rep['verdict'] == 'FAIL' and 'chart.normal.presence[S:ridge_1]' in ids, ids
    assert 'chart.content[S:ridge_1.Normal]' in ids


def test_member_off_its_role_fails(accepted, tmp_path):
    new = fp_of(tmp_path, member_on='UNDER', name='moved')
    flagged = new['classes']['EAVE_CUTOUT.FRONT']['registration']['flagged']
    assert list(flagged.values())[0]['flags'] == ['WRONG_ROLE']
    rep = SR.compare(accepted, new)
    assert 'registration[EAVE_CUTOUT.FRONT]' in fail_ids(rep)


def test_other_layout_compares_per_class(accepted, tmp_path):
    rep = SR.compare(accepted, fp_of(tmp_path, shift=20, name='relaid'))
    assert not rep['same_layout'] and rep['layout_overlap'] == 0.0
    assert rep['verdict'] == 'PASS', rep['fails']
    assert not any(r['id'].startswith('chart.') for r in rep['rows'])      # no per-texel checks across layouts
    rep2 = SR.compare(accepted, fp_of(tmp_path / 'b', shift=20, band='opaque', name='relaid_opaque'))
    assert 'eave.FRONT.scallops_per_m' in fail_ids(rep2)


def test_stale_baseline_schema_fails(accepted):
    """a baseline from an older tool version lacks newer measures, so their rules would skip silently: FAIL instead."""
    rep = SR.compare(dict(accepted, schema=SR.SCHEMA - 1), accepted)
    assert fail_ids(rep) == {'fingerprint.schema'}


def test_waiver_is_the_only_way_to_accept(accepted, tmp_path):
    new = fp_of(tmp_path, band='straight', name='straight')
    rep = SR.compare(accepted, new)
    W = {'waived': {i: {'reason': 'test', 'owner': 'test', 'date': '2026-09-29'} for i in fail_ids(rep)}}
    rep2 = SR.compare(accepted, new, W)
    assert rep2['verdict'] == 'PASS' and rep2['waived'] == len(fail_ids(rep))
    rep3 = SR.compare(accepted, new, {'waived': {}})
    assert rep3['verdict'] == 'FAIL'


def test_cli_exit_codes(accepted, tmp_path):
    a = tmp_path / 'a.fp.json'; a.write_text(json.dumps(accepted, default=float))
    d, plan, geo = build(tmp_path, band='straight', name='cli')
    b = tmp_path / 'b.fp.json'
    r = subprocess.run([sys.executable, str(HERE / 'state_regression.py'), 'fingerprint', str(d), '--plan', str(plan),
                        '--geometry', str(geo), '--sources', 'Obj=S', '-o', str(b)], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    r = subprocess.run([sys.executable, str(HERE / 'state_regression.py'), 'compare', str(a), str(b)], capture_output=True, text=True)
    assert r.returncode == 3 and 'eave.FRONT.scallops_per_m' in r.stdout
    r = subprocess.run([sys.executable, str(HERE / 'state_regression.py'), 'compare', str(a), str(a)], capture_output=True, text=True)
    assert r.returncode == 0, r.stdout


def test_ddt_dxt5_alpha(tmp_path):
    """8x8 DXT5 page: block (0,0) all 255, block (0,1) all 0 (code 1), blocks below interpolate (code 2 = 6/7 a0)."""
    def block(a0, a1, code):
        bits = 0
        for i in range(16):
            bits |= code << (3 * i)
        return bytes([a0, a1]) + bits.to_bytes(6, 'little') + b'\0' * 8
    data = block(255, 0, 0) + block(255, 0, 1) + block(210, 70, 2) + block(40, 200, 6)
    head = b'RTS3' + bytes([0, 4, 9, 1]) + struct.pack('<II', 8, 8) + struct.pack('<II', 24, len(data))
    p = tmp_path / 'x_matb_BaseColor.ddt'; p.write_bytes(head + data)
    a = SR.read_ddt_alpha(p)
    assert a.shape == (8, 8)
    assert np.allclose(a[:4, :4], 1) and np.allclose(a[:4, 4:], 0)
    assert np.allclose(a[4:, :4], (6 * 210 + 70) / 7 / 255, atol=1e-3)
    assert np.allclose(a[4:, 4:], 0)                               # a0 <= a1 mode: code 6 = 0


def write_ddt_alpha(path, alpha):
    """DXT5 .ddt whose alpha is 255 where alpha >= 0.5, else 0 (colour blocks black)."""
    h, w = alpha.shape; out = b''
    for by in range(0, h, 4):
        for bx in range(0, w, 4):
            bits = 0
            for i, v in enumerate((alpha[by:by + 4, bx:bx + 4] < 0.5).ravel()):
                bits |= int(v) << (3 * i)
            out += bytes([255, 0]) + bits.to_bytes(6, 'little') + b'\0' * 8
    path.write_bytes(b'RTS3' + bytes([0, 4, 9, 1]) + struct.pack('<II', w, h) + struct.pack('<II', 24, len(out)) + out)


def test_export_alpha_must_match_the_state(accepted, tmp_path):
    d, plan, geo = build(tmp_path, name='exp')
    op = np.asarray(Image.open(d / 'P256_Opacity.png'))[..., 0] / 255.0
    good = tmp_path / 'good'; good.mkdir(); write_ddt_alpha(good / 'x_matb_BaseColor.ddt', op)
    stale = tmp_path / 'stale'; stale.mkdir(); write_ddt_alpha(stale / 'x_matb_BaseColor.ddt', np.ones_like(op))
    st, src = SR.build_state(d, plan, geo, {'Obj': 'S'})
    fp = SR.fingerprint(st, 'exp', src)
    fp['export'] = SR.export_agreement(st, good, {'P256': 'matb'})
    assert fp['export']['P256']['all'] == 1.0
    assert SR.compare(accepted, fp, only=['export.*'])['verdict'] == 'PASS'
    fp['export'] = SR.export_agreement(st, stale, {'P256': 'matb'})
    rep = SR.compare(accepted, fp, only=['export.*'])
    assert rep['verdict'] == 'FAIL' and fail_ids(rep) == {'export.alpha[P256]'}


def test_plan_from_geometry_v15_style(tmp_path):
    """a UV-less layout (the v15 roof atlas): a Blender face dump becomes a plan - roof material faces that stand
    vertical are the eave FRONT band, the backing material is eave, charts = UV-connected islands."""
    faces = [dict(i=0, mat='Giwa_v15', n=[0, 0.4, 0.9], v=[[0, 0, 3], [1, 0, 3], [1, 1, 3.4], [0, 1, 3.4]], uv=[[0, 0], [.1, 0], [.1, .1], [0, .1]]),
             dict(i=1, mat='Giwa_v15', n=[0, -1, 0], v=[[0, 0, 2.8], [1, 0, 2.8], [1, 0, 3], [0, 0, 3]], uv=[[0, -.02], [.1, -.02], [.1, 0], [0, 0]]),
             dict(i=2, mat='Backing_v15', n=[0, -0.3, -0.95], v=[[0, 0, 2.8], [1, 0, 2.8], [1, .3, 2.7], [0, .3, 2.7]], uv=[[.5, .5], [.6, .5], [.6, .6], [.5, .6]]),
             dict(i=3, mat='Timber', n=[0, 0, 1], v=[[0, 0, 0], [1, 0, 0], [1, 1, 0]], uv=[[.9, .9], [1, .9], [1, 1]])]
    g = tmp_path / 'geo.json'; g.write_text(json.dumps(dict(objects={'Roof': dict(faces=faces)}, summary={})))
    plan = SR.plan_from_geometry(g, 'ATLAS', 2048, {'Giwa': 'ROOF_TILE', 'Backing': 'EAVE_CUTOUT'}, {'ROOF_TILE': 'EAVE_CUTOUT'})['faces']
    assert set(plan) == {'Roof:0', 'Roof:1', 'Roof:2'}                               # the timber face is not on the atlas
    assert [plan[k]['material'] for k in ('Roof:0', 'Roof:1', 'Roof:2')] == ['ROOF_TILE', 'EAVE_CUTOUT', 'EAVE_CUTOUT']
    assert plan['Roof:0']['family'] == plan['Roof:1']['family'] != plan['Roof:2']['family']   # shared UV edge = one island
    assert all(x['owner'] and x['page'] == 'ATLAS' for x in plan.values())
    geo = SR.load_geometry(g)
    assert set(geo) == {'Roof:0', 'Roof:1', 'Roof:2', 'Roof:3'}


def test_geometry_that_misses_the_plan_stops(tmp_path):
    d, plan, geo = build(tmp_path, name='nogeo')
    with pytest.raises(SystemExit, match='--sources'):
        SR.build_state(d, plan, geo, {'Obj': 'WRONG_PREFIX'})
