"""aoe3de-anim-viewer M3: the game shader on the GPU against its numpy reference, pixel by pixel.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_shading_gpu.py -q

Local only (the `local` marker; skipped without Chrome). No window: headless.py runs Chrome with --headless=new and a
throwaway profile; the fixture, the browser profile and every readback live in pytest's temp folder (never a repository).
The page viewer/shading/selftest.html runs the SAME glsl.js functions the viewer draws with on a synthetic fixture
written here (random RGBA8 textures, exact synthetic cube maps, a random depth map, a random HDR image, the lighting.py
tonemap LUT, a synthetic grade LUT, random dither noise), and tests/shading_ref.py recomputes every pixel:
- the GPU's own sRGB decode of every byte (texelFetch of an SRGB8_ALPHA8 texture): the material reference decodes
  BaseColor through it, so the check below covers the shader maths; its distance to the exact formula is reported
  (3.75e-3 absolute on the RTX 4070 Ti SUPER through ANGLE D3D11, 8e-6 on SwiftShader, 2026-10-11);
- material + lighting (an analytic sphere per pixel: materialdefault -> G-buffer round trip -> lightingpass), three
  tiles (default / non-default parameters, quantised or not, double-sided, mip-ramp or six-face cube, sky rotation);
  tolerance: relative error <= 2e-3 for 99.5 % of the covered pixels and <= 0.05 for all (isolated pixels may fall into
  the neighbouring EnvBRDF or 8-bit bin: the lookups are discontinuous; a stored value within 3e-4 of an 8/10-bit
  rounding boundary is accepted on either side); pixels within a cube-face seam band are left out of the six-face
  tile (seamless filtering blends faces there). Measured 2026-10-11: p99.5 2.2e-4 on the hardware path (trilinear
  LOD weights are fixed point), 1.5e-6 on SwiftShader;
- the 25-tap shadow filter: 1e-5 absolute (dyadic coordinates, exact depths);
- the post pass, three modes: float result within 3e-3 for 99.9 % and 6e-3 for all (LUT trilinear weights are fixed
  point on GPUs), 8-bit result within 1 step for 99.9 % and 2 steps for all.
Runs on the hardware path (ANGLE D3D11) and on SwiftShader.
"""
import base64
import json
import sys
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402
import lighting as L  # noqa: E402
import shading_ref as R  # noqa: E402

pytestmark = pytest.mark.local

W = H = 128
TEX = 32
SH_SIZE = 64
SH_KERNEL = 128
POST = 96

DEFAULT_REI = [0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0.5]
CUSTOM_REI = [1, 1.5, 0.7, 0.4, 0.3, 0.2, 0.8, 0.1, 0.6, 0.05, 0.9, 0.5]
LIGHT_A = {'sun_direction': (-np.array([0.4, 0.8, 0.45]) / np.linalg.norm([0.4, 0.8, 0.45])).tolist(),
           'sun_color': [2.5, 2.4, 2.2], 'shadow_color': [0.4, 0.5, 0.7], 'hemi_top': [0.9, 0.85, 0.8],
           'hemi_bottom': [0.3, 0.35, 0.45], 'rot_sin': 0.0, 'rot_cos': 1.0, 'intensity': 1.0, 'normalize': 1.2,
           'exposure': 1.5}
LIGHT_B = dict(LIGHT_A, sun_direction=(-np.array([-0.6, 0.5, 0.62]) / np.linalg.norm([-0.6, 0.5, 0.62])).tolist(),
               rot_sin=float(np.sin(0.7)), rot_cos=float(np.cos(0.7)), intensity=0.8, normalize=0.9, exposure=2.0)
RAMP = {'levels': [{'size': 32 >> k, 'faces': [c] * 6} for k, c in enumerate(
    [[1.25, 1.0, 0.75, 1.0], [1.0, 0.875, 0.75, 0.875], [0.75, 0.75, 0.625, 0.75], [0.625, 0.625, 0.625, 0.625],
     [0.5, 0.5, 0.5625, 0.5], [0.4375, 0.5, 0.5625, 0.375]])]}
FACES = {'levels': [{'size': 32, 'faces': [[1.5, 0.25, 0.25, 0.75], [0.25, 1.25, 0.25, 1.0], [1.75, 1.75, 1.5, 0.5],
                                           [0.125, 0.25, 0.125, 1.0], [0.25, 0.375, 1.5, 0.875],
                                           [0.75, 0.625, 0.5, 0.625]]}]}
TILES = [
    {'name': 'default_ramp_quant', 'rei': DEFAULT_REI, 'env': 'ramp', 'quant': True, 'double_sided': False,
     'lighting': LIGHT_A, 'pc': [0.05, 0.1, 0.8]},
    {'name': 'custom_faces_float_ds', 'rei': CUSTOM_REI, 'env': 'faces', 'quant': False, 'double_sided': True,
     'lighting': LIGHT_B, 'pc': [0.7, 0.05, 0.05]},
    {'name': 'custom_ramp_quant_ds', 'rei': CUSTOM_REI, 'env': 'ramp', 'quant': True, 'double_sided': True,
     'lighting': LIGHT_A, 'pc': [0.2, 0.6, 0.1]},
]
LEGACY = {'exposure': 0.6, 'luminance_based': 0.4, 'influence': 0.8, 'noise': 0.5, 'white_point': 4.0}
BACKGROUND = [0.2, 0.3, 0.4, 1.0]


def build_fixture(root):
    """the synthetic fixture as a bundle-schema folder under `root`; returns (bundle id, arrays dict)."""
    rng = np.random.default_rng(20261011)
    w = C.BufferWriter('fx')
    a = {}
    a['base'] = rng.integers(0, 256, (TEX, TEX, 4), np.uint8)
    a['lift'] = rng.integers(0, 256, (TEX, TEX, 4), np.uint8)
    nrm = np.zeros((TEX, TEX, 4), np.uint8)
    nrm[..., :2] = rng.integers(40, 216, (TEX, TEX, 2))
    nrm[..., 2] = rng.integers(180, 256, (TEX, TEX))
    nrm[..., 3] = 255
    a['normal'] = nrm
    a['masks'] = rng.integers(0, 256, (TEX, TEX, 4), np.uint8)
    a['details'] = rng.integers(0, 256, (TEX, TEX, 4), np.uint8)
    a['depth'] = rng.random((SH_SIZE, SH_SIZE)).astype(np.float32)
    hdr = rng.random((POST, POST, 4)).astype(np.float32)
    hdr[..., :3] = (hdr[..., :3] ** 2 * 6.0).astype(np.float32)
    hdr[:8, :8, :3] = 0.0
    hdr[..., 3] = np.where(hdr[..., 3] < 0.2, 0.0, np.where(hdr[..., 3] < 0.4, 0.5, 1.0))
    a['hdr'] = hdr
    a['tonemap_lut'] = L.bake_tonemap_lut(11.2)
    g = np.linspace(0, 1, 8)
    bb, gg, rr = np.meshgrid(g, g, g, indexing='ij')
    grade = np.stack([rr ** 1.2 * 0.95, gg ** 0.9, np.minimum(bb * 1.1, 1.0), np.ones_like(rr)], -1)
    a['grade_lut'] = grade.astype(np.float32)
    a['noise'] = rng.integers(0, 256, (64, 64, 4), np.uint8)
    views = {k: w.add(a[k].reshape(-1), 'u8' if a[k].dtype == np.uint8 else 'f32', 1)
             for k in ('base', 'lift', 'normal', 'masks', 'details', 'depth', 'hdr', 'tonemap_lut', 'grade_lut', 'noise')}
    fid = C.cache_key('shading-selftest', 1)
    manifest = {'schema': C.SCHEMA_NAME, 'schema_version': C.SCHEMA_VERSION, 'bundle_id': fid,
                'buffers': [w.record()], 'subject': {'kind': 'synthetic'},
                'shading_selftest': {
                    'size': [W, H], 'eye': [0.0, 0.0, 3.5],
                    'textures': {'size': [TEX, TEX], **{k: views[k] for k in ('base', 'lift', 'normal', 'masks', 'details')}},
                    'envs': {'ramp': RAMP, 'faces': FACES}, 'envbrdf': L.envbrdf_record(), 'tiles': TILES,
                    'shadow': {'size': SH_SIZE, 'depth': views['depth'], 'kernel': [SH_KERNEL, SH_KERNEL],
                               'bias': 0.01, 'softness': 40.0},
                    'post': {'size': [POST, POST], 'hdr': views['hdr'], 'tonemap_lut': views['tonemap_lut'],
                             'tonemap_size': 32, 'grade_lut': views['grade_lut'], 'grade_size': 8,
                             'noise': views['noise'], 'grade_enabled': 0.7, 'dither_scale': 1 / 256,
                             'legacy': LEGACY, 'background': BACKGROUND}}}
    folder = Path(root) / fid
    C.write_bytes(folder / 'fx.bin', w.data())
    C.write_json(folder / 'manifest.json', manifest)
    return fid, a


def decode(path, key='data', dtype=np.float32):
    d = json.loads(Path(path).read_text())
    arr = np.frombuffer(base64.b64decode(d[key]), dtype)
    return arr.reshape(d['h'], d['w'], 4)


# ------------------------------------------------------------------------------------------------ CPU side
def env_fn(env, half):
    """env(dir, lod) of a cube with one colour per face and level: the face of the major axis, levels lerped
    (LINEAR_MIPMAP_LINEAR); colours rounded to half when the page had to upload RGBA16F."""
    cols = np.array([lv['faces'] for lv in env['levels']], np.float64)          # (levels, 6, 4)
    if half:
        cols = cols.astype(np.float16).astype(np.float64)
    n = cols.shape[0]

    def fn(d, lod):
        major = np.argmax(np.abs(d), axis=-1)
        comp = np.take_along_axis(d, major[..., None], -1)[..., 0]
        face = major * 2 + (comp < 0)
        lod = np.clip(lod[..., 0], 0, n - 1)
        lo = np.floor(lod).astype(int)
        hi = np.minimum(lo + 1, n - 1)
        f = (lod - lo)[..., None]
        return cols[lo, face] * (1 - f) + cols[hi, face] * f
    return fn


def seam_mask(d, size):
    s = np.sort(np.abs(d), axis=-1)
    return s[..., 1] / s[..., 2] > 1 - 2.0 / size


BOUNDARY = 3e-4          # a stored value this close to an 8/10-bit rounding boundary may round either way on the GPU


def material_reference(a, tile, half, bias=0.0, srgb=None):
    px, py = np.meshgrid(np.arange(W), np.arange(H))
    x = (px + 0.5) / W * 2 - 1
    y = (py + 0.5) / H * 2 - 1
    r2 = x * x + y * y
    cover = r2 <= 0.98
    z = np.sqrt(np.maximum(1 - r2, 0))
    N = np.stack([x, y, z], -1)
    nv = N * (1 + 0.25 * x)[..., None]
    tv = np.stack([z, np.zeros_like(z), -x], -1) * 1.1
    tw = np.where((((px >> 4) + (py >> 4)) & 1) == 0, 1.0, -1.0)[..., None]
    tcx, tcy = px * TEX // W, py * TEX // H
    tex = {k: a[k][tcy, tcx].astype(np.float64) / 255 for k in ('base', 'lift', 'normal', 'masks', 'details')}
    decode_srgb = (lambda b: srgb[b]) if srgb is not None else (lambda b: R.srgb_decode(b / 255.0))
    lin = {k: decode_srgb(a[k][tcy, tcx][..., :3].astype(int)) for k in ('base', 'lift')}
    rei = tile['rei']
    params = dict(zip(['playerColorIndex', 'aoIntensity', 'aoGamma', 'liftMetallic', 'liftNonMetallic', 'roughnessMin',
                       'roughnessMax', 'roughnessMetallicMin', 'roughnessMetallicMax', 'metallicMin', 'metallicMax',
                       'cutoutThreshold'], rei))
    eye = np.array([0.0, 0.0, 3.5])
    with np.errstate(all='ignore'):
        surf = R.material(lin['base'], lin['lift'], tex['normal'][..., :3],
                          tex['masks'][..., :3], tex['details'][..., 0:1], nv, tv, tw, np.array(tile['pc']), params,
                          front=(x >= 0)[..., None], double_sided=tile['double_sided'], pos=N, eye=eye)
        g = R.gbuffer(surf, quantise=tile['quant'], bias=bias)
        shadow = np.where((((px >> 3) + (py >> 3)) & 1) == 0, 1.0, 0.3)[..., None]
        env = RAMP if tile['env'] == 'ramp' else FACES
        lc = tile['lighting']
        out = R.lighting(g, N, eye, shadow, lc, env_fn(env, half), len(env['levels']) - 1)
    mask = cover.copy()
    if tile['env'] == 'faces':
        V = R.normalize(N - eye)
        Rv = V - 2 * R.dot(V, g['n']) * g['n']
        for d in (g['n'], Rv):
            mask &= ~seam_mask(R.rotate_y(d, lc['rot_sin'], lc['rot_cos']), FACES['levels'][0]['size'])
    return out, cover, mask


def post_reference(a, mode, half):
    hdr = a['hdr'].astype(np.float64)
    px, py = np.meshgrid(np.arange(POST), np.arange(POST))
    noise = a['noise'][py & 63, px & 63, :3].astype(np.float64) / 255
    lut, grade = a['tonemap_lut'].astype(np.float64), a['grade_lut'].astype(np.float64)
    if half:
        lut, grade = lut.astype(np.float16).astype(np.float64), grade.astype(np.float16).astype(np.float64)
    if mode == 'lut':
        t = R.post_lut(hdr[..., :3], lut, noise, grade, 0.7, 1 / 256)
    elif mode == 'legacy':
        t = R.post_legacy(hdr[..., :3], noise, exposure=LEGACY['exposure'], luminance_based=LEGACY['luminance_based'],
                          influence=LEGACY['influence'], white_point=LEGACY['white_point'], noise_scale=LEGACY['noise'])
    else:
        t = L.linear_to_srgb(np.clip(hdr[..., :3], 0, 1))
    return R.composite(t, np.clip(hdr[..., 3:4], 0, 1), BACKGROUND)


# ------------------------------------------------------------------------------------------------ the run
@pytest.fixture(scope='module', params=['auto', 'swiftshader'])
def run(request, tmp_path_factory):
    import headless as H
    browsers = H.select_browsers()
    if not browsers:
        pytest.skip('no Chrome (config tools.chrome.path, AOP_ANIM_VIEWER_BROWSER or PATH)')
    root = tmp_path_factory.mktemp('shading-' + request.param)
    mp = pytest.MonkeyPatch()
    mp.setenv(C.CACHE_ENV, str(root / 'cache'))
    fid, arrays = build_fixture(root / 'bundles')
    rec = H.run_page('shading/selftest.html', query={'bundle': fid}, browser=browsers[0], gpu=request.param,
                     timeout=120, bundle_root=root / 'bundles', out_dir=root / 'out', log=lambda m: None,
                     label='shading')
    mp.undo()
    assert rec['status'] == 'done', (rec.get('error'), rec.get('events'))
    assert rec['profile_deleted'] is not False and not rec.get('leftover_processes'), rec
    out = Path(rec['out_dir'])
    srgb = decode(out / 'srgb_table.json')[0, :, 0].astype(np.float64)
    return {'rec': rec, 'out': out, 'a': arrays, 'mode': request.param, 'srgb': srgb}


def test_page_ran_clean(run):
    r = run['rec']['result']
    assert r['status'] == 'ok', r
    assert all(r['targets'].values()) and r['extensions']['cbf']
    want = {'material_%s.json' % t['name'] for t in TILES} | {'shadow.json', 'post_lut.json', 'post_legacy.json',
                                                               'post_off.json'}
    assert want <= set(r['files'])
    assert not C.is_repo_path(run['out'])


def test_the_gpu_srgb_decode_table(run):
    """the page's texelFetch of an SRGB8_ALPHA8 texture for every byte value: monotonic, 0 -> 0, 255 -> 1, close to the
    exact sRGB curve. The material reference decodes BaseColor through THIS table, so the parity check covers the
    shader maths; how far the hardware decode is from the formula is reported (a property of the GPU, which the game
    meets on the same GPU too)."""
    tab = run['srgb']
    exact = R.srgb_decode(np.arange(256) / 255.0)
    dev = np.abs(tab - exact) / np.maximum(exact, 1e-3)
    print('%s sRGB decode: max relative deviation from the formula %.2e (byte %d), max absolute %.2e'
          % (run['mode'], dev.max(), int(dev.argmax()), np.abs(tab - exact).max()))
    assert tab[0] == 0 and abs(tab[255] - 1) < 1e-6 and (np.diff(tab) > 0).all()
    assert np.abs(tab - exact).max() < 6e-3        # RTX 4070 Ti SUPER (ANGLE D3D11) 2026-10-11: 3.75e-3; SwiftShader 8e-6


@pytest.mark.parametrize('tile', TILES, ids=[t['name'] for t in TILES])
def test_material_and_lighting_match_the_reference(run, tile):
    half = not run['rec']['result']['extensions']['floatLinear']
    gpu = decode(run['out'] / ('material_%s.json' % tile['name']))
    srgb = run['srgb']
    ref, cover, mask = material_reference(run['a'], tile, half, srgb=srgb)
    assert np.array_equal(gpu[..., 3] > 0.5, cover), 'sphere coverage differs'
    g, c = gpu[..., :3][mask].astype(np.float64), ref[mask]
    assert np.isfinite(g).all() and np.isfinite(c).all()
    rel = np.abs(g - c) / np.maximum(1.0, np.abs(c))
    raw995 = float(np.percentile(rel.max(axis=-1), 99.5))
    if tile['quant']:                    # either side of a rounding boundary is the same shader: keep the closer one
        for b in (BOUNDARY, -BOUNDARY):
            alt = material_reference(run['a'], tile, half, bias=b, srgb=srgb)[0][mask]
            rel = np.minimum(rel, np.abs(g - alt) / np.maximum(1.0, np.abs(alt)))
    p995, worst = float(np.percentile(rel.max(axis=-1), 99.5)), float(rel.max())
    print('%s %s: %d px compared (%d left out at cube seams), relative error p99.5 %.2e (%.2e before the rounding-'
          'boundary allowance), max %.2e, mean value %.3f'
          % (run['mode'], tile['name'], mask.sum(), cover.sum() - mask.sum(), p995, raw995, worst, c.mean()))
    assert mask.sum() > 0.6 * cover.sum()
    assert p995 <= 2e-3 and worst <= 0.05, (p995, worst)
    assert c.max() > 0.3 and c.std() > 0.05                            # the scene is lit and varied, not a flat field


def test_shadow_filter_matches_the_reference(run):
    gpu = decode(run['out'] / 'shadow.json')
    px, py = np.meshgrid(np.arange(SH_KERNEL), np.arange(SH_KERNEL))
    uv = np.stack([(px * 0.0078125 + 0.00390625) * 1.25 - 0.125, (py * 0.0078125 + 0.00390625) * 1.25 - 0.125], -1)
    z = (((px * 7 + py * 13) & 63) / 64.0 * 1.125)[..., None]
    assert np.allclose(gpu[..., 1:3], uv, atol=0) and np.allclose(gpu[..., 3:4], z, atol=0)
    ref = R.pcf25(run['a']['depth'].astype(np.float64), uv, z, 0.01, 40.0)
    err = np.abs(gpu[..., 0:1] - ref)
    print('%s shadow: max error %.2e, lit fraction %.3f' % (run['mode'], err.max(), ref.mean()))
    assert err.max() <= 1e-5
    assert 0.05 < ref.mean() < 0.95 and (ref == 1).any()               # partly shadowed, some outside-the-map pixels


@pytest.mark.parametrize('mode', ['lut', 'legacy', 'off'])
def test_post_pass_matches_the_reference(run, mode):
    half = not run['rec']['result']['extensions']['floatLinear']
    path = run['out'] / ('post_%s.json' % mode)
    gf = decode(path, 'f32')[..., :3].astype(np.float64)
    g8 = decode(path, 'u8', np.uint8)[..., :3].astype(np.int64)
    ref = post_reference(run['a'], mode, half)
    err = np.abs(gf - ref)
    d8 = np.abs(g8 - R.to_unorm8(ref))
    print('%s post %s: float p99.9 %.2e max %.2e; 8-bit within 1: %.4f, max %d'
          % (run['mode'], mode, np.percentile(err, 99.9), err.max(), (d8 <= 1).mean(), d8.max()))
    assert np.percentile(err, 99.9) <= 3e-3 and err.max() <= 6e-3
    assert (d8 <= 1).mean() >= 0.999 and d8.max() <= 2
