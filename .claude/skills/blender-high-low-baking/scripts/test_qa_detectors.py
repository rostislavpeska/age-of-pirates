"""Specimen proof for qa_detectors.py: every detector FAILS a small synthetic specimen that has the defect and
PASSES the clean twin. Specimens are built in pytest's tmp_path / in memory - never images in the repo.

python -m pytest .claude/skills/blender-high-low-baking/scripts/test_qa_detectors.py -q
(plain Python + numpy + PIL; OpenCV optional; no Blender - EXR input is covered by the real-data check.)
"""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import qa_detectors as Q  # noqa: E402

# ------------------------------------------------------------------------------------------ specimen builders
def encode_normal(h, strength=1.0):
    """height field -> encoded tangent normal (0..1), OpenGL +Y (y up = row decreasing)"""
    gy, gx = np.gradient(h.astype(np.float64))
    n = np.stack([-gx * strength, gy * strength, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return (n * 0.5 + 0.5).astype(np.float32)


def whiteout(a, b, s=1.0):
    x = a * 2 - 1; y = b * 2 - 1; y = y * s + np.array([0, 0, 1]) * (1 - s)
    c = np.stack([x[..., 0] + y[..., 0], x[..., 1] + y[..., 1], x[..., 2] * y[..., 2]], -1)
    return (c / np.linalg.norm(c, axis=-1, keepdims=True) * 0.5 + 0.5).astype(np.float32)


def roof(n=288, rows=31.0, cols=29.0, course=None, seed=7):
    """tiled roof relief: sharp-lipped rows along y (period `rows`), round rolls along x (period `cols`);
    course: an unlocked procedural course groove every `course` texels, phase random per tile column
    (Astra's defect: 0.12 units = 13 texels over ~31-texel modelled rows)."""
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    h = 1.2 * ((y / rows) % 1.0) + 1.5 * np.abs(np.sin(np.pi * x / cols))
    if course:
        ph = np.random.default_rng(seed).uniform(0, course, int(n / cols) + 2)[(x // cols).astype(int)]
        h -= 0.6 * np.exp(-(((y + ph) % course) - course / 2) ** 2 / 1.5)
    return encode_normal(h, 1.0)


def lattice(n=240, pitch=24, bar=5):
    y, x = np.mgrid[0:n, 0:n]
    bx = np.clip(bar / 2 - np.abs((x % pitch) - pitch / 2 + 0.5) + 1, 0, 1.5)
    by = np.clip(bar / 2 - np.abs((y % pitch) - pitch / 2 + 0.5) + 1, 0, 1.5)
    return encode_normal(3 * np.maximum(bx, by), 1.0)


def planks(n=240, seam=40, seed=7):
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    grain = np.cumsum(np.random.default_rng(seed).normal(0, 1, (n, n)), 0) * 0.02   # streaks along y
    h = -2.0 * np.exp(-(((x % seam) - seam / 2) ** 2) / 2.0) + grain
    return encode_normal(h, 1.0)


def save_png16(path, a):
    a = np.clip(a, 0, 1)
    if a.ndim == 3:
        try:
            import cv2
            cv2.imwrite(str(path), (a[..., ::-1] * 65535).astype(np.uint16)); return
        except ImportError:
            a = a[..., 0]
    Image.fromarray((a * 65535).astype(np.uint16)).save(path)


# ------------------------------------------------------------------------------------------ D1 rhythms
@pytest.mark.parametrize('seed', range(6))
def test_d1_roof_second_rhythm_fails_locked_roof_passes(seed):
    clean = Q.rhythm_check(roof(seed=seed))
    bad = Q.rhythm_check(roof(course=13.0, seed=seed))
    assert clean['verdict'] == 'PASS', clean
    assert bad['verdict'] == 'FAIL' and bad['two_rhythm_windows'] > 0, bad


def test_d1_short_period_fails():
    assert Q.rhythm_check(roof(rows=10.0, cols=29.0))['verdict'] == 'FAIL'
    assert Q.rhythm_check(roof(rows=20.0, cols=29.0))['verdict'] == 'PASS'


def test_d1_small_mask_is_skip_not_pass():
    m = np.zeros((288, 288), bool); m[:40, :40] = True
    assert Q.rhythm_check(roof(), m)['verdict'] == 'SKIP'


# ------------------------------------------------------------------------------------------ D2 stacking
def test_d2_planks_over_baked_lattice_fails_bake_alone_passes():
    bake = lattice(); stacked = whiteout(bake, planks(), 0.8)
    assert Q.stacked_normal_check(bake, bake)['verdict'] == 'PASS'
    s = Q.slopes(bake) * 0.7; scaled = np.dstack([s, np.sqrt(1 - (s ** 2).sum(-1).clip(0, 1))]) * 0.5 + 0.5
    assert Q.stacked_normal_check(scaled.astype(np.float32), bake)['verdict'] == 'PASS'   # a strength change is not a stack
    r = Q.stacked_normal_check(stacked, bake)
    assert r['verdict'] == 'FAIL' and r['added'] > 0.35, r


# ------------------------------------------------------------------------------------------ D3 UV members
S = 256


def _quad_uv(u0, v0, u1, v1):
    return [[u0, v0], [u1, v0], [u1, v1], [u0, v1]]


def _eave_chart(origin, rot, rows, uv_rows, key_prefix, start, owner, fam='S:Eave', material='EAVE_CUTOUT',
                scale_u=1.0, mirror=False):
    """a strip of `rows` faces folding along one edge; rows = [(tilt_deg), ...] from bottom to top.
    Geometry in the chart frame: u along x (4 units), each row 1 unit long in its own tilted direction."""
    faces, geo = {}, {}
    c, s_ = np.cos(np.radians(rot)), np.sin(np.radians(rot))
    R = np.array([[c, -s_, 0], [s_, c, 0], [0, 0, 1]])
    p0 = np.zeros(3)
    for i, (tilt, (v0, v1)) in enumerate(zip(rows, uv_rows)):
        d = np.array([0, np.cos(np.radians(tilt)), np.sin(np.radians(tilt))])   # row direction in the y/z plane
        a, b = p0, p0 + d
        w = 4.0 * scale_u
        verts = [a, a + [w, 0, 0], b + [w, 0, 0], b]
        nrm = np.cross(np.array([w, 0, 0]), d); nrm /= np.linalg.norm(nrm)
        k = f'{key_prefix}:{start + i}'
        u0, u1 = (0.5, 0.1) if mirror else (0.1, 0.5)
        faces[k] = dict(page='P', uv=_quad_uv(u0, v0, u1, v1), family=fam, owner=owner, material=material)
        geo[k] = dict(v=[list(R @ q + origin) for q in verts], n=list(R @ nrm))
        p0 = b
    return faces, geo


def _plan(member_shift=0.0, mirror=False, scale_u=1.0, rows=(-35, 0, 45)):
    uv_rows = [(0.30, 0.40), (0.40, 0.50), (0.50, 0.60)]
    f1, g1 = _eave_chart(np.zeros(3), 0, rows, uv_rows, 'O', 0, True)
    m_uv = [(a + member_shift, b + member_shift) for a, b in uv_rows[:2]]
    f2, g2 = _eave_chart(np.array([10.0, 3.0, 0.0]), 90, rows[:2], m_uv, 'M', 10, False, mirror=mirror, scale_u=scale_u)
    return {**f1, **f2}, {**g1, **g2}


def test_d3_registered_members_pass():
    plan, geo = _plan()
    r = Q.uv_registration_check(plan, geo, 'P', S, directional=('EAVE_CUTOUT',))
    assert r['verdict'] == 'PASS', r['faces']


def test_d3_half_row_shift_fails():
    plan, geo = _plan(member_shift=0.05)
    r = Q.uv_registration_check(plan, geo, 'P', S)
    assert r['verdict'] == 'FAIL' and set(r['flagged_faces']) == {'M:10', 'M:11'}, r['faces']


def test_d3_full_row_shift_onto_next_fold_fails():
    """UNDER member reads 100 % FRONT texels, FRONT member 100 % TOP: every share is 1.0 - only the fold
    registration (next owner fold has another dihedral) catches it, like the 52 tower-eave members."""
    plan, geo = _plan(member_shift=0.10)
    r = Q.uv_registration_check(plan, geo, 'P', S)
    f = r['faces']
    assert f['M:10']['share'] > 0.95 and f['M:11']['share'] > 0.95
    assert r['verdict'] == 'FAIL' and {'M:10', 'M:11'} <= set(r['flagged_faces']), f


def test_d3_mirrored_member_on_directional_material_fails():
    plan, geo = _plan(mirror=True)
    assert Q.uv_registration_check(plan, geo, 'P', S, directional=())['verdict'] == 'PASS'
    r = Q.uv_registration_check(plan, geo, 'P', S, directional=('EAVE_CUTOUT',))
    assert r['verdict'] == 'FAIL' and r['by_flag'].get('MIRRORED') == 2, r


def test_d3_stretched_member_fails():
    plan, geo = _plan(scale_u=1.6)
    r = Q.uv_registration_check(plan, geo, 'P', S)
    assert r['verdict'] == 'FAIL' and r['by_flag'].get('STRETCHED') == 2, r
    plan, geo = _plan(scale_u=1.2)
    assert Q.uv_registration_check(plan, geo, 'P', S)['verdict'] == 'PASS'


# ------------------------------------------------------------------------------------------ D4 masks
def _blocks(n=256, seed=3):
    rng = np.random.default_rng(seed); h = np.zeros((n, n)); valid = np.zeros((n, n), bool)
    for _ in range(14):
        y0, x0 = rng.integers(8, n - 60, 2); hh, ww = rng.integers(20, 50, 2)
        yy, xx = np.mgrid[0:hh, 0:ww]
        d = np.minimum.reduce([yy, xx, hh - 1 - yy, ww - 1 - xx]).astype(float)
        h[y0:y0 + hh, x0:x0 + ww] = np.maximum(h[y0:y0 + hh, x0:x0 + ww], np.clip(d / 3, 0, 1) * 3)
        valid[y0 - 4:y0 + hh + 4, x0 - 4:x0 + ww + 4] = True
    return h, valid


def _edge_wear(h):
    gy, gx = np.gradient(h); e = np.hypot(gx, gy)
    noise = np.random.default_rng(5).uniform(0.4, 1.0, h.shape)
    return np.clip(e * 1.5, 0, 1) * noise


def test_d4_edge_wear_registered_passes_offset_fails():
    h, valid = _blocks(); nrm = encode_normal(h); wear = _edge_wear(h)
    assert Q.mask_offset_check(wear, nrm, valid)['verdict'] == 'PASS'
    r = Q.mask_offset_check(np.roll(wear, (0, 4), (0, 1)), nrm, valid)
    assert r['verdict'] == 'FAIL' and r['best_offset'][0] == 0 and abs(r['best_offset'][1] - 4) <= 1, r


def test_d4_mask_from_other_layout_fails():
    h, valid = _blocks(); nrm = encode_normal(h)
    h2, valid2 = _blocks(seed=11); foreign = _edge_wear(h2)
    assert Q.mask_offset_check(foreign, nrm, valid)['verdict'] == 'FAIL'
    assert Q.mask_layout_check(_edge_wear(h) * valid, valid)['verdict'] == 'PASS'
    assert Q.mask_layout_check(foreign, valid)['verdict'] == 'FAIL'


def test_d4_dirt_follows_ao():
    h, valid = _blocks()
    ao = 1 - 0.6 * np.clip(Q.box_blur((h > 0).astype(np.float32), 3) - (h > 0), 0, 1) - 0.2 * (h < 0.5)
    dirt = np.clip((1 - ao) * np.random.default_rng(9).uniform(0.5, 1, h.shape), 0, 1)
    assert Q.mask_offset_check(dirt, ao, valid, 'inverse')['verdict'] == 'PASS'
    assert Q.mask_offset_check(np.roll(dirt, 3, 0), ao, valid, 'inverse')['verdict'] == 'FAIL'


def test_d4_channel_packing_swap_fails():
    n = 128; cls = np.zeros((n, n), int); cls[:, 96:] = 1; valid = np.ones((n, n), bool)
    ao = np.random.default_rng(1).uniform(0.5, 1, (n, n)); rough = np.random.default_rng(2).uniform(0.45, 0.9, (n, n))
    metal = (cls == 1) * 0.85
    good = np.dstack([ao, rough, metal]).astype(np.float32)
    assert Q.channel_packing_check(good, cls, ['WOOD', 'METAL'], valid)['verdict'] == 'PASS'
    r = Q.channel_packing_check(good[..., [0, 2, 1]], cls, ['WOOD', 'METAL'], valid)
    assert r['verdict'] == 'FAIL' and len(r['reasons']) == 2, r


# ------------------------------------------------------------------------------------------ D5 classes
def test_d5_class_pattern_short_period_and_flat():
    n = 256; y, x = np.mgrid[0:n, 0:n]; cls = np.zeros((n, n), int); cls[:, 128:] = 1
    grain = np.random.default_rng(4).normal(0, 0.03, (n, n))
    wood_ok = 0.4 + 0.08 * np.sin(2 * np.pi * x / 32) + grain                       # 32-texel boards
    wood_bad = 0.4 + 0.08 * np.sin(2 * np.pi * x / 8) + grain                       # 8-texel stripes
    tile = 0.3 + 0.05 * np.sin(2 * np.pi * y / 30) + grain
    img_ok = np.where(cls == 0, wood_ok, tile)[..., None].repeat(3, -1).astype(np.float32)
    img_bad = np.where(cls == 0, wood_bad, tile)[..., None].repeat(3, -1).astype(np.float32)
    img_flat = np.where(cls == 0, wood_ok, 0.3)[..., None].repeat(3, -1).astype(np.float32)
    C = ['WOOD', 'ROOF_TILE']
    assert Q.class_pattern_check(img_ok, cls, C)['verdict'] == 'PASS'
    r = Q.class_pattern_check(img_bad, cls, C)
    assert r['verdict'] == 'FAIL' and r['reasons'][0].startswith('WOOD'), r['reasons']
    r = Q.class_pattern_check(img_flat, cls, C)
    assert r['verdict'] == 'FAIL' and 'flat' in r['reasons'][0] and r['reasons'][0].startswith('ROOF_TILE'), r['reasons']


# ------------------------------------------------------------------------------------------ D6 eave alpha
def _eave_specimen(alpha_kind, n=256, tpu=200.0):
    """one straight eave lip, 1 m long: FRONT (end-tile face, y=0, z .10-.40), UNDER (tilted closure y .03->0,
    z 0->.12) and BACK (inner face, y=.04, z 0-.40), each on its own UV strip at tpu texels/m. The FRONT carries
    modelled end tiles in its normal map: discs r .07 (bottoms at z .15) every .27 m with pan-tile arcs between.
    alpha_kind: 'opaque' (the regression), 'scalloped' (outline cut on FRONT, BACK/UNDER cut to match),
    'back_opaque' (scalloped FRONT, opaque back lip = the S18i West Hall south bug)."""
    u0, u1 = 0.1, 0.1 + tpu / n
    strips = {'F': (0.70, 0.30), 'U': (0.55, 0.1237), 'B': (0.10, 0.40)}           # v0 and face height (m)
    verts = {'F': [(0, 0, .10), (1, 0, .10), (1, 0, .40), (0, 0, .40)],
             'U': [(0, .03, 0), (1, .03, 0), (1, 0, .12), (0, 0, .12)],
             'B': [(0, .04, 0), (1, .04, 0), (1, .04, .40), (0, .04, .40)]}
    normals = {'F': (0, -1, 0), 'U': tuple(np.array([0, -.12, -.03]) / np.hypot(.12, .03)), 'B': (0, 1, 0)}
    plan, geo = {}, {}
    for i, k in enumerate('FUB'):
        v0, hgt = strips[k]; v1 = v0 + hgt * tpu / n
        plan[f'S:{i}'] = dict(page='P1024', uv=[[u0, v0], [u1, v0], [u1, v1], [u0, v1]], family=f'S:Eave_{k}',
                              owner=True, material='EAVE_CUTOUT')
        geo[f'S:{i}'] = dict(v=[list(p) for p in verts[k]], n=list(normals[k]))
    # world position of every texel centre of each strip
    cc = np.arange(n); cols = cc[((cc + 0.5) / n >= u0) & ((cc + 0.5) / n <= u1)]    # texel centres inside the strip
    xw = ((cols + 0.5) / n - u0) * n / tpu
    normal = np.zeros((n, n, 3), np.float32); normal[..., 2] = 1.0; normal = normal * 0.5 + 0.5
    alpha = np.ones((n, n), np.float32)

    def rows_of(k):
        v0, hgt = strips[k]; vc = 1 - (cc + 0.5) / n; rr = cc[(vc >= v0) & (vc <= v0 + hgt * tpu / n)]
        t = ((1 - (rr + 0.5) / n) - v0) * n / tpu / hgt                             # 0 bottom .. 1 top of the face
        return rr, np.clip(t, 0, 1)
    rF, tF = rows_of('F'); zF = .10 + .30 * tF
    X, Z = np.meshgrid(xw, zF)
    pitch, first = 0.27, 0.095
    dx = (X - first + pitch / 2) % pitch - pitch / 2; zc = 0.22                     # disc centres
    r = np.hypot(dx, Z - zc); hm = 0.019 * np.clip((0.07 - r) / 0.013, 0, 1)
    pdx = (X - first) % pitch - pitch / 2; rp = np.hypot(pdx, Z - (zc + 0.06))
    hm = hm + 0.016 * np.exp(-((rp - 0.12) / 0.012) ** 2) * (Z < zc + 0.06) * (np.abs(pdx) < 0.12)
    normal[rF[:, None], cols[None, :]] = encode_normal(hm * tpu)
    tile = hm > 0.003                                           # rows run top-down: the LAST tile row is the lowest
    outline = np.array([Z[np.nonzero(tile[:, j])[0].max(), j] if tile[:, j].any() else .10 for j in range(len(cols))])
    if alpha_kind != 'opaque':
        alpha[rF[:, None], cols[None, :]] = (Z >= outline[None, :]).astype(np.float32)
        for k in ('U', 'B'):
            rr, t = rows_of(k); z = (0.12 * t) if k == 'U' else (0.40 * t)
            cut = (z[:, None] < outline[None, :]).astype(np.float32)          # below the tile outline: see-through
            alpha[rr[:, None], cols[None, :]] = 1 - cut if not (alpha_kind == 'back_opaque' and k == 'B') else 1.0
    return plan, geo, alpha, normal


@pytest.mark.parametrize('kind,verdict,culprit', [('opaque', 'FAIL', 'Eave_F'), ('scalloped', 'PASS', None),
                                                 ('back_opaque', 'FAIL', 'Eave_B')])
def test_d6_eave_alpha_opaque_strip_fails_scalloped_passes_opaque_back_lip_fails(kind, verdict, culprit):
    plan, geo, alpha, normal = _eave_specimen(kind)
    r = Q.eave_alpha_check(plan, geo, alpha, normal, 'P1024')
    assert r['verdict'] == verdict, r['reasons']
    if culprit:
        assert any(x.startswith(culprit) for x in r['reasons']), r['reasons']
    else:
        f = r['charts']['Eave_F | FRONT']
        assert 0.15 <= f['cut'] <= 0.35 and f['edge_median_texels'] <= 1.0, f


# ------------------------------------------------------------------------------------------ CLI + image IO
@pytest.mark.parametrize('course,code', [(None, 0), (13.0, 3)])
def test_cli_reads_16bit_png_and_exits_on_fail(tmp_path, course, code):
    nrm = roof(course=course); save_png16(tmp_path / 'n.png', nrm)
    m = np.ones(nrm.shape[:2], np.uint8) * 255; Image.fromarray(m).save(tmp_path / 'm.png')
    back = Q.read_map(tmp_path / 'n.png')
    assert back.shape == nrm.shape and np.abs(back - nrm).max() < 1e-4        # channel order + 16-bit scale
    cfg = dict(out=str(tmp_path / 'r.json'), checks=[dict(id='roof', type='rhythm', normal=str(tmp_path / 'n.png'),
                                                         mask=str(tmp_path / 'm.png'))])
    (tmp_path / 'c.json').write_text(json.dumps(cfg))
    p = subprocess.run([sys.executable, str(HERE / 'qa_detectors.py'), str(tmp_path / 'c.json')], capture_output=True, text=True)
    assert p.returncode == code, p.stdout + p.stderr
    assert json.loads((tmp_path / 'r.json').read_text())['checks']['roof']['verdict'] == ('PASS' if code == 0 else 'FAIL')


# ------------------------------------------------------------------------------------------ D7 class mismatch
CLS7 = ['WOOD', 'PLASTER', 'STONE', 'GABLE_DECOR']
PAL7 = {'WOOD': [0.6, 0.3, 0.1], 'PLASTER': [0.9, 0.88, 0.8], 'STONE': [0.5, 0.5, 0.52], 'GABLE_DECOR': '#20a050'}


def _class_specimen():
    """64x64 page: left half WOOD texels, right half PLASTER, a black (unbaked) strip at the bottom rows. Faces:
    W  wood owner on wood; P  plaster owner on plaster; F  a wooden frame the plan carries as PLASTER (white on screen);
    M  a WOOD member whose UV sits on plaster texels; G  a GABLE_DECOR face on wood texels; T  a 2x2-texel wood speck
    on plaster; U  a face on the unbaked strip."""
    cm = np.zeros((64, 64), int); cm[:, 32:] = 1; cm[56:, :] = -1
    q = lambda x0, y0, x1, y1: [[x0 / 64, 1 - y1 / 64], [x1 / 64, 1 - y1 / 64], [x1 / 64, 1 - y0 / 64], [x0 / 64, 1 - y0 / 64]]  # noqa: E731
    f = lambda uv, m, own=True: dict(page='P64', uv=uv, family='fam_' + m, owner=own, material=m)  # noqa: E731
    plan = {'W': f(q(2, 2, 20, 12), 'WOOD'), 'P': f(q(40, 2, 60, 12), 'PLASTER'), 'F': f(q(36, 20, 44, 50), 'PLASTER'),
            'M': f(q(40, 20, 60, 30), 'WOOD', False), 'G': f(q(4, 30, 20, 40), 'GABLE_DECOR'), 'T': f(q(50, 40, 52, 42), 'WOOD'),
            'U': f(q(4, 57, 30, 63), 'WOOD')}
    return plan, cm


def test_d7_class_mismatch_flags_wood_on_plaster_through_plan_and_expected():
    plan, cm = _class_specimen()
    r = Q.class_mismatch_check(plan, cm, CLS7, 'P64', 64, expected={'F': 'WOOD'}, equivalent=[['WOOD', 'GABLE_DECOR']])
    assert r['verdict'] == 'FAIL' and set(r['flagged_faces']) == {'F', 'M', 'U'}, r
    assert r['faces']['F']['cls'] == 'WOOD' and r['faces']['F']['reads'] == 'PLASTER' and r['faces']['F']['source'] == 'expected'
    assert r['faces']['M']['reads'] == 'PLASTER' and r['faces']['M']['owner'] is False
    assert r['faces']['U']['flags'] == ['NO_CLASS'] and r['tiny'] == 1                  # T: 4 texels, never flagged
    assert r['by_pair'] == {'WOOD->PLASTER': 2, 'WOOD->none': 1}
    # without the independent truth the plaster-carried frame is consistent with its (wrong) plan material
    r0 = Q.class_mismatch_check(plan, cm, CLS7, 'P64', 64, equivalent=[['WOOD', 'GABLE_DECOR']])
    assert 'F' not in r0['flagged_faces'] and 'G' not in r0['flagged_faces']
    # GABLE_DECOR on wood texels is a mismatch unless declared equivalent
    assert 'G' in Q.class_mismatch_check(plan, cm, CLS7, 'P64', 64)['flagged_faces']


def test_d7_fixed_plan_passes_and_palette_classmap_roundtrip(tmp_path):
    plan, cm = _class_specimen()
    for k in ('F', 'M'):                                   # the repositioned islands: onto the wood owner's texels
        plan[k]['uv'] = [list(p) for p in plan['W']['uv']]
    del plan['U']
    r = Q.class_mismatch_check(plan, cm, CLS7, 'P64', 64, expected={'F': 'WOOD'}, equivalent=[['WOOD', 'GABLE_DECOR']])
    assert r['verdict'] == 'PASS', r['reasons']
    srgb = np.zeros((64, 64, 3), np.uint8)
    for i, c in enumerate(CLS7):
        col = PAL7[c] if not isinstance(PAL7[c], str) else [int(PAL7[c][j:j + 2], 16) / 255 for j in (1, 3, 5)]
        srgb[cm == i] = np.round(np.asarray(col) * 255).astype(np.uint8)
    Image.fromarray(srgb).save(tmp_path / 'P64_ClassID.png')
    back = Q.read_palette_classmap({'path': str(tmp_path / 'P64_ClassID.png'), 'palette': PAL7}, CLS7)
    assert np.array_equal(back, cm)
    (tmp_path / 'plan.json').write_text(json.dumps({'faces': _class_specimen()[0]}))
    cfg = dict(checks=[dict(id='cls', type='class_mismatch', plan=str(tmp_path / 'plan.json'), classes=CLS7, pages={'P64': 64},
                            classmap={'path': str(tmp_path / '{page}_ClassID.png'), 'palette': PAL7}, expected={'F': 'WOOD'},
                            equivalent=[['WOOD', 'GABLE_DECOR']])])
    (tmp_path / 'c.json').write_text(json.dumps(cfg))
    p = subprocess.run([sys.executable, str(HERE / 'qa_detectors.py'), str(tmp_path / 'c.json')], capture_output=True, text=True)
    assert p.returncode == 3 and 'WOOD->PLASTER' in p.stdout, p.stdout + p.stderr


# ------------------------------------------------------------------------------------------ D8 relief gate
# Owner 2026-09-29: plank seams drawn in the BaseColor over a flat Normal ("planks not on the model"), window frames
# with no normal, and a notice-board paper sheet whose only relief is the board's grain running under it.
FLAT = np.full((96, 96, 3), (0.5, 0.5, 1.0), np.float32)


def plank_albedo(n=96, seam=16, seed=3, vertical=False):
    """plank photo: horizontal seams (2 texels, luma -0.15) every `seam` rows + grain streaked along the planks
    (line response: seams 0.07-0.13, grain 0.02-0.03, as measured on the HEAD window planks)"""
    rng = np.random.default_rng(seed)
    grain = np.cumsum(rng.normal(0, 0.006, (n, n)), 1) * 0.3 + rng.normal(0, 0.015, (n, n))   # HEAD grain: 0.02-0.03
    y = np.mgrid[0:n, 0:n][0]
    L = 0.35 + grain - 0.15 * (((y % seam) == 0) | ((y % seam) == 1))
    L = L.T if vertical else L
    return np.repeat(np.clip(L, 0, 1)[..., None], 3, -1).astype(np.float32)


def plank_grooves(n=96, seam=16, depth=1.5):
    y = np.mgrid[0:n, 0:n][0].astype(np.float64)
    d = np.minimum(np.abs((y % seam) - 0.5), seam - np.abs((y % seam) - 0.5))
    return encode_normal(-depth * np.exp(-d ** 2 / 2.0), 1.0)


def test_d8_relief_missing_planks_flat_normal_fail_grooved_pass():
    bad = Q.relief_missing_check(plank_albedo(), FLAT)
    assert bad['verdict'] == 'FAIL' and bad['flagged_faces'] == [0] and bad['flagged_tiles'] >= 20, bad['reasons']
    good = Q.relief_missing_check(plank_albedo(), plank_grooves())
    assert good['verdict'] == 'PASS' and good['unsupported_texels'] < 50, good['reasons']


def test_d8_flat_by_design_passes_plaster_mottled_stone_paper_cells():
    rng = np.random.default_rng(5)
    plaster = np.repeat((0.8 + rng.normal(0, 0.02, (96, 96)))[..., None], 3, -1).astype(np.float32)
    blobs = Q.box_blur(rng.normal(0, 1, (96, 96)).astype(np.float32), 2)          # granite: 3-6 texel mottling
    stone = np.repeat((0.5 + 0.35 * blobs / blobs.std() * 0.1)[..., None], 3, -1).astype(np.float32)
    cells = np.full((96, 96, 3), 0.85, np.float32)                                    # a uniform hanji cell
    for img in (plaster, stone, cells):
        r = Q.relief_missing_check(img, FLAT)
        assert r['verdict'] == 'PASS', (r['reasons'], r['unsupported_texels'])


def test_d8_paper_sheet_on_grained_board_fails_until_its_edge_has_relief():
    n = 96; rng = np.random.default_rng(9); y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    board_h = -1.5 * np.exp(-((x % 32) - 4) ** 2 / 2.0) + np.cumsum(rng.normal(0, 0.05, (n, n)), 0) * 0.05
    L = 0.25 + rng.normal(0, 0.02, (n, n)); sheet = (x >= 14) & (x < 34) & (y >= 20) & (y < 76)
    L[sheet] = 0.85
    bc = np.repeat(L[..., None], 3, -1).astype(np.float32)
    bad = Q.relief_missing_check(bc, encode_normal(board_h, 1.0))       # the board's grooves/grain run under the sheet
    assert bad['verdict'] == 'FAIL', bad['reasons']
    raised = Q.box_blur(sheet.astype(np.float32), 1) * 1.2              # a raised paper sheet with a soft edge
    good = Q.relief_missing_check(bc, encode_normal(board_h + raised, 1.0))
    assert good['verdict'] == 'PASS', (good['reasons'], good['unsupported_texels'])


def test_d8_relief_missing_names_faces_and_honours_owner_waiver():
    lab = np.zeros((96, 96), int); lab[:, 48:] = 1                       # face 0 flat planks, face 1 grooved planks
    nrm = FLAT.copy(); nrm[:, 48:] = plank_grooves()[:, 48:]
    r = Q.relief_missing_check(plank_albedo(), nrm, lab, ['A:1', 'A:2'])
    assert r['flagged_faces'] == ['A:1'] and all(set(t['faces']) == {'A:1'} for t in r['tiles'])
    assert all(t['box'][2] <= 48 for t in r['tiles'])
    w = Q.relief_missing_check(plank_albedo(), nrm, lab, ['A:1', 'A:2'], waive_faces={'A:1'})
    assert w['verdict'] == 'PASS' and w['waived_faces'] == ['A:1']


def test_d8_relief_drop_undeclared_fails_declared_passes():
    base = plank_grooves(); cand = base.copy(); cand[:, :48] = FLAT[:, :48]  # the job flattened the left half
    lab = np.zeros((96, 96), int); lab[:, 48:] = 1
    r = Q.relief_drop_check(cand, base, lab, ['A:1', 'A:2'])
    assert r['verdict'] == 'FAIL' and r['flagged_faces'] == ['A:1'] and r['undeclared_tiles'], r
    dec = np.zeros((96, 96), bool); dec[:, :50] = True
    ok = Q.relief_drop_check(cand, base, lab, ['A:1', 'A:2'], declared=dec)
    assert ok['verdict'] == 'PASS' and ok['declared_tiles'] >= 12, ok
    wrong = np.zeros((96, 96), bool); wrong[:, 50:] = True                   # declared the other face: still FAIL
    assert Q.relief_drop_check(cand, base, lab, ['A:1', 'A:2'], declared=wrong)['verdict'] == 'FAIL'
    assert Q.relief_drop_check(base, base, lab, ['A:1', 'A:2'])['verdict'] == 'PASS'


def test_d8_cli_relief_types(tmp_path):
    save_png16(tmp_path / 'n.png', FLAT); save_png16(tmp_path / 'g.png', plank_grooves())
    Image.fromarray((plank_albedo() * 255).astype(np.uint8)).save(tmp_path / 'bc.png')
    cfg = dict(checks=[dict(id='miss', type='relief_missing', basecolor=str(tmp_path / 'bc.png'), normal=str(tmp_path / 'n.png')),
                       dict(id='drop', type='relief_drop', normal=str(tmp_path / 'n.png'), base=str(tmp_path / 'g.png'))])
    (tmp_path / 'c.json').write_text(json.dumps(cfg))
    p = subprocess.run([sys.executable, str(HERE / 'qa_detectors.py'), str(tmp_path / 'c.json')], capture_output=True, text=True)
    assert p.returncode == 3 and "['miss', 'drop']" in p.stdout, p.stdout + p.stderr
