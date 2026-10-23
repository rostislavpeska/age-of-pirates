"""aoe3de-anim-viewer M3: lighting.py shader-model extensions and the numpy shader reference, checked by hand.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_shading.py -q

Synthetic and CI-safe (no game bytes): made-up lighting sets in the vanilla style, a made-up reflection cube.
- EnvBRDF table: column 0 is Schlick at NdotV = iy/8 (bias (1 - NdotV)^5 to 2e-6, scale 1 - bias to 3e-5: the game
  integrated it numerically), scale + bias <= 1 everywhere;
- lgt -> shader constants: every entry labelled; values recomputed by hand (sRGB decode x intensity, the sun line
  above the horizon for both signs of the inclination, skyCubeNormalize from the last refl mip);
- lighting packs: a bundle-schema v0 manifest with subject kind 'lighting', full f16 cube, reused when unchanged,
  refused inside a repository;
- reference maths: GGX D integrates to 1 over the hemisphere (with the cosine), the Fresnel and sun-disc constants,
  one fully hand-computed pixel of the lighting pass, the materialdefault remaps at chosen mask values, the post pass
  on the grey axis at the LUT texel centres (where the 2(i/31)^2 lookup meets the 2(i/32)^2 build), the legacy Hable
  curve, the shadow filter on a step edge.
"""
import math
import struct
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

BS = chr(92)
STATUS = {'measured', 'name-match', 'guess', 'unknown', 'omitted-measured', 'not-ported', 'measured-unused'}


def lgt_text(inclination, rotation, extra=''):
    return ('<lightingset>\r\n'
            '  <suncolor>250 240 220</suncolor>\r\n  <sunintensity>5.000000</sunintensity>\r\n'
            '  <suninclination>%f</suninclination>\r\n  <sunrotation>%f</sunrotation>\r\n'
            '  <shadowcolor>60 80 100</shadowcolor>\r\n'
            '  <skycubemap>lighting' + BS + 'environments' + BS + 'sky_m3</skycubemap>\r\n'
            '  <hemitopcolor>230 210 190</hemitopcolor>\r\n  <hemibottomcolor>100 120 160</hemibottomcolor>\r\n'
            '  <hemiintensity>0.800000</hemiintensity>\r\n  <exposure>1.500000</exposure>\r\n'
            '  <whitepoint>8.000000</whitepoint>\r\n  <mipmapbias>-1.000000</mipmapbias>\r\n'
            '  <skycubemaprotation>-1.500000</skycubemaprotation>\r\n'
            '  <tonemapluminance>0.250000</tonemapluminance>\r\n  <tonemapinfluence>0.750000</tonemapinfluence>\r\n'
            '  <dithernoiseintensity>0.040000</dithernoiseintensity>\r\n%s'
            '</lightingset>\r\n') % (inclination, rotation, extra)


def make_refl(size=8, mips=4, value=(0.5, 1.0, 1.5, 0.75)):
    parts = []
    for face in range(6):
        for k in range(mips):
            s = max(1, size >> k)
            a = np.empty((s, s, 4), np.float32)
            a[...] = value
            a[..., 0] += face * 0.125
            parts.append(a.tobytes())
    payload = b''.join(parts)
    return struct.pack('<4s5I4f', b'REFL', 3, size, mips, 2, len(payload), 0.0, 1.0, 0.0, 1.0) + payload


def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


# ------------------------------------------------------------------------------------------------ EnvBRDF table
def test_envbrdf_column_zero_is_schlick_and_energy_is_bounded():
    s, b = np.array(L.ENVBRDF_SCALE), np.array(L.ENVBRDF_BIAS)
    assert s.shape == b.shape == (8, 8)
    for iy in range(1, 8):
        f = (1 - iy / 8) ** 5
        assert b[iy, 0] == pytest.approx(f, abs=2e-6) and s[iy, 0] == pytest.approx(1 - f, abs=3e-5), iy
    assert s[0, 0] < 1e-3 and b[0, 0] > 0.999                    # grazing mirror: all Fresnel
    assert (s + b <= 1.0 + 5e-5).all() and (s >= 0).all() and (b >= 0).all()      # 1.000013 at (3, 0)
    assert (np.diff(b[:, 0]) < 0).all()                           # less Fresnel towards normal incidence
    rec = L.envbrdf_record()
    assert rec['status'] == 'measured' and len(rec['scale']) == len(rec['bias']) == 64
    assert rec['scale'][4 * 8 + 0] == 0.96875 and rec['bias'][4 * 8 + 0] == 0.03125


def test_envbrdf_lookup_is_nearest_lower_bin():
    f0 = np.array([[0.04, 0.5, 1.0]])
    got = R.envbrdf(f0, np.array([[0.124]]), np.array([[0.5]]))         # rough bin 0, NdotV bin 4
    assert got == pytest.approx(f0 * 0.96875 + 0.03125)
    got = R.envbrdf(f0, np.array([[1.0]]), np.array([[1.0]]))            # both clamp to bin 7
    assert got == pytest.approx(f0 * L.ENVBRDF_SCALE[7][7] + L.ENVBRDF_BIAS[7][7])


# ------------------------------------------------------------------------------------------------ lgt -> constants
def constants(inc=40.0, rot=90.0, refl=None):
    return L.shader_constants(L.parse_lgt(lgt_text(inc, rot).encode())['fields'], refl)


def test_shader_constants_are_labelled_and_hand_checkable():
    d = constants()
    e = d['entries']
    assert d['version'] == L.SHADER_MODEL == 'v1'
    assert all(v['status'] in STATUS and v['rule'] and 'target' in v for v in e.values())
    assert e['sun_color']['value'] == pytest.approx([srgb(c) * 5 for c in (250, 240, 220)], abs=1e-12)
    assert e['shadow_color']['value'] == pytest.approx([srgb(c) for c in (60, 80, 100)], abs=1e-12)
    assert e['hemi_top']['value'] == pytest.approx([srgb(c) * 0.8 for c in (230, 210, 190)], abs=1e-12)
    assert e['hemi_bottom']['value'] == pytest.approx([srgb(c) * 0.8 for c in (100, 120, 160)], abs=1e-12)
    assert e['sky_cube_rotation']['value']['sin'] == pytest.approx(math.sin(-1.5))
    assert (e['exposure']['value'], e['white_point']['value'], e['mip_bias']['value']) == (1.5, 8.0, -1.0)
    assert e['sky_cube_intensity'] == dict(e['sky_cube_intensity'], value=1.0, status='unknown')
    assert e['sky_cube_normalize']['value'] == 1.0                # no refl given
    assert e['grade_enabled']['value'] == 0.0 and e['dither_scale']['value'] == 1 / 256
    assert e['legacy_tonemap']['value']['luminance_based'] == 0.25 and e['legacy_tonemap']['value']['influence'] == 0.75
    assert e['fog']['status'] == e['contact_shadow']['status'] == e['fill']['status'] == 'omitted-measured'
    assert e['sky_cube_mip']['status'] == 'measured-unused'


@pytest.mark.parametrize('inc,rot', [(40.0, 90.0), (-40.0, 90.0), (-72.0, 10.0), (66.0, -150.0)])
def test_the_sun_is_always_above_the_horizon(inc, rot):
    d = constants(inc, rot)['entries']['sun_direction']['value']
    assert abs(np.linalg.norm(d) - 1) < 1e-12 and d[1] < 0          # light travels downward
    toward = -np.array(d)
    e = math.radians(abs(inc))
    assert toward[1] == pytest.approx(math.sin(e))                   # elevation = |inclination|
    v = np.array(L.sun_direction(inc, rot))
    assert np.allclose(toward, v if v[1] >= 0 else -v)               # the line read from the lgt angles


def test_sky_cube_normalize_comes_from_the_last_mip():
    w = C.BufferWriter('light')
    rec = L.refl_record('lighting/environments/sky_m3.refl', make_refl(), w)
    last = rec['level_stats'][-1]
    mean_rgb = np.array([0.5 + 0.125 * 2.5, 1.0, 1.5])                 # faces add 0, 1/8 .. 5/8 to red
    assert last['mean_rgb'] == pytest.approx(mean_rgb.tolist(), abs=1e-6)
    lum = float(mean_rgb @ np.array(L.REC709_LUMA))
    assert last['mean_luminance'] == pytest.approx(lum, abs=1e-6) and last['mean_alpha'] == pytest.approx(0.75)
    e = constants(refl=rec)['entries']['sky_cube_normalize']
    assert e['value'] == pytest.approx(1 / lum, rel=1e-6) and e['status'] == 'guess'


def test_refl_f16_views_and_clamp():
    data = make_refl(4, 3, value=(70000.0, 1.0, 0.5, 1.0))
    w = C.BufferWriter('light')
    rec = L.refl_record('r.refl', data, w, dtype='f16')
    assert rec['dtype'] == 'f16' and [m['view']['dtype'] for m in rec['mips']] == ['f16'] * 3
    a = C.read_view(w.data(), rec['mips'][0]['view'])
    assert a.dtype == np.float16 and float(a[:, 0].max()) == 65504.0 and float(a[0, 2]) == 0.5
    with pytest.raises(ValueError):
        L.refl_record('r.refl', data, w, dtype='u8')


def test_build_lighting_adds_shader_block_and_envbrdf():
    files = {'lightsets/m3.lgt': lgt_text(30, 10, '  <colorgradecustomlut>my_lut</colorgradecustomlut>\r\n').encode(),
             'lighting/environments/sky_m3.refl': make_refl()}
    out = L.build_lighting('m3', lambda p: (files[p], 3) if p in files else None, C.BufferWriter('light'))
    s = out['section']
    assert s['shader']['entries']['grade_enabled']['value'] == 1.0
    assert s['shader']['entries']['sky_cube_normalize']['value'] != 1.0
    assert s['envbrdf']['status'] == 'measured' and s['refl']['level_stats']
    assert L.lighting_section()['envbrdf']['size'] == 8 and L.lighting_section()['shader'] is None


# ------------------------------------------------------------------------------------------------ lighting packs
class FakeVFS:
    """the VFS surface build_lighting_pack uses, over a dict of logical paths."""

    def __init__(self, files):
        self.files = files
        self.provenance = C.Provenance()
        self.warnings = []

    def read(self, path, quiet=False):
        if path not in self.files:
            return None
        data = self.files[path]

        class VF:
            pass
        vf = VF()
        vf.data, vf.provenance = data, self.provenance.add('synthetic', path, data=data)
        return vf

    def inputs(self):
        return [{'id': 'synthetic', 'files': sorted(self.files)}]

    def layer_records(self):
        return [{'id': 'synthetic', 'kind': 'game', 'title': 'synthetic', 'priority': 0, 'enabled': True,
                 'source': 'test'}]


def pack_files():
    return {'lightsets/m3.lgt': lgt_text(30, 10).encode(), 'lighting/environments/sky_m3.refl': make_refl(16, 5)}


def test_lighting_pack_is_a_lighting_only_bundle(tmp_path):
    fs = FakeVFS(pack_files())
    res = L.build_lighting_pack('m3', fs=fs, out_root=tmp_path)
    m = C.read_json(Path(res['folder']) / 'manifest.json')
    assert m['schema'] == C.SCHEMA_NAME and m['schema_version'] == C.SCHEMA_VERSION and m['bundle_id'] == res['bundle_id']
    assert m['subject'] == {'kind': 'lighting', 'proto': None, 'animfile': None, 'lgt': 'm3'}
    lt = m['lighting']
    assert [x['level'] for x in lt['refl']['mips']] == [0, 1, 2, 3, 4] and lt['refl']['dtype'] == 'f16'
    assert lt['shader']['version'] == 'v1' and lt['tonemap_lut']['white_point'] == 8.0
    assert m['fidelity']['shader_model'] == 'v1' and m['fidelity']['stages']['brdf'] == 'M'
    assert set(m['fidelity']['stages']) == set(L.SHADING_FIDELITY)
    assert all(v in 'MAUH' for v in m['fidelity']['stages'].values())
    data = (Path(res['folder']) / 'light.bin').read_bytes()
    assert len(data) == m['buffers'][0]['byteLength'] == res['bytes']
    again = L.build_lighting_pack('m3', fs=FakeVFS(pack_files()), out_root=tmp_path)
    assert again['reused'] and again['bundle_id'] == res['bundle_id']
    files = pack_files()
    files['lightsets/m3.lgt'] = lgt_text(31, 10).encode()
    changed = L.build_lighting_pack('m3', fs=FakeVFS(files), out_root=tmp_path)
    assert not changed['reused'] and changed['bundle_id'] == res['bundle_id']     # same inputs, new content


def test_lighting_pack_refuses_a_repository():
    with pytest.raises(C.RepoPathError):
        L.build_lighting_pack('m3', fs=FakeVFS(pack_files()), out_root=HERE / 'pack_out')


def test_build_presets_reports_missing_sets(tmp_path):
    out = L.build_presets(fs_factory=lambda: FakeVFS(pack_files()), out_root=tmp_path, names=['m3', 'absent'])
    assert [o['status'] for o in out] == ['ok', 'missing'] and out[0]['bundle_id'] and out[1]['bundle_id'] is None
    assert [p['name'] for p in L.PRESETS] == ['Tantalus Viewer', 'NewEngland_Skirmish']


def test_shading_fidelity_flags():
    f = L.SHADING_FIDELITY
    assert all(v[0] in 'MAUH' and v[1] for v in f.values())
    assert f['brdf'][0] == f['envbrdf'][0] == f['material'][0] == 'M'
    assert f['lgt_mapping'][0] == f['sun_direction'][0] == f['tonemap'][0] == f['player_colour'][0] == 'U'
    assert f['shadows'][0] == f['gbuffer'][0] == f['ssao'][0] == 'A'


# ------------------------------------------------------------------------------------------------ reference maths
def test_ggx_distribution_integrates_to_one():
    for rough in (0.08, 0.3, 0.7, 1.0):
        alpha = max(rough, 0.08) ** 2
        th = np.linspace(0, math.pi / 2, 200001)
        c = np.cos(th)
        d = (alpha / (c * c * (alpha * alpha - 1) + 1)) ** 2 * R.PI_INV
        integral = np.trapezoid(d * c * np.sin(th), th) * 2 * math.pi
        assert integral == pytest.approx(1.0, abs=2e-3), rough


def test_fresnel_and_sun_disc_constants():
    assert R.SUN_COS ** 2 + R.SUN_SIN ** 2 == pytest.approx(1.0, abs=1e-6)
    assert math.degrees(math.acos(R.SUN_COS)) == pytest.approx(1.7186, abs=1e-3)
    f = lambda v: 2 ** (v * (R.FRESNEL[0] * v + R.FRESNEL[1]))                      # noqa: E731
    assert f(1.0) < 2e-4 and f(0.0) == 1.0
    assert abs(f(0.5) - 0.5 ** 5) < 0.01                                               # close to Schlick's (1-x)^5


def flat_env(rgba):
    return lambda d, lod: np.broadcast_to(np.array(rgba, np.float64), d.shape[:-1] + (4,))


def test_one_pixel_of_the_lighting_pass_by_hand():
    # n up, camera straight above, sun straight down, rough 1, non-metal, AO 1, horizon 1, no shadow
    g = {'albedo': np.array([[0.5, 0.25, 0.1]]), 'metal': np.array([[0.0]]), 'rough': np.array([[1.0]]),
         'ao': np.array([[1.0]]), 'n': np.array([[0.0, 1.0, 0.0]]), 'horizon': np.array([[1.0]])}
    lc = {'sun_direction': [0.0, -1.0, 0.0], 'sun_color': [3.0, 3.0, 3.0], 'shadow_color': [0.5, 0.5, 0.5],
          'hemi_top': [1.0, 1.0, 1.0], 'hemi_bottom': [0.0, 0.0, 0.0], 'rot_sin': 0.0, 'rot_cos': 1.0,
          'intensity': 1.0, 'normalize': 1.0, 'exposure': 2.0}
    out = R.lighting(g, np.array([[0.0, 0.0, 0.0]]), np.array([[0.0, 5.0, 0.0]]), np.array([[1.0]]), lc,
                     flat_env([0.4, 0.4, 0.4, 1.0]), 5)
    albedo = np.array([0.5, 0.25, 0.1])
    # direct: NdotL = NdotV = NdotH = VdotH = 1, alpha = 1, k = 0.5: D = 1/pi, Vis = 1/(4 * 1 * 1), F = F0 + (1-F0) f
    fr = 2 ** (1 * (R.FRESNEL[0] + R.FRESNEL[1]))
    spec = (0.04 + 0.96 * fr) * 0.25 * R.PI_INV * 3.0
    diff = albedo * R.PI_INV * 3.0
    # ambient: irradiance 0.4 * hemi(top, n.y = 1) = 0.4; specular env 0.4 * hemi(R.y = 1); occlusion
    # saturate(pow(saturate(1 + 1), 1) + 1 - 1) * 1 = 1; EnvBRDF bin (7, 7); the sun-side pixel is not tinted
    eb = 0.04 * L.ENVBRDF_SCALE[7][7] + L.ENVBRDF_BIAS[7][7]
    want = (diff + spec + albedo * 0.4 + 0.4 * eb) * 2.0
    assert out[0] == pytest.approx(want, rel=1e-6)
    # in full shadow: direct gone, the cube keeps its unshadowed share (alpha 1 here), ambient tinted by shadow_color
    out2 = R.lighting(g, np.array([[0.0, 0.0, 0.0]]), np.array([[0.0, 5.0, 0.0]]), np.array([[0.0]]), lc,
                      flat_env([0.4, 0.4, 0.4, 1.0]), 5)
    assert out2[0] == pytest.approx((albedo * 0.4 + 0.4 * eb) * 0.5 * 2.0, rel=1e-6)


def test_materialdefault_remaps_by_hand():
    one = lambda *v: np.array([v], np.float64)                                          # noqa: E731
    params = {'aoIntensity': 0.5, 'aoGamma': 1.0, 'liftMetallic': 0.5, 'liftNonMetallic': 0.25, 'roughnessMin': 0.2,
              'roughnessMax': 0.6, 'roughnessMetallicMin': 0.1, 'roughnessMetallicMax': 0.3, 'metallicMin': 0.0,
              'metallicMax': 0.8}
    s = R.material(one(0.4, 0.4, 0.4), one(0.5, 0.25, 0.2), one(0.5, 0.5, 1.0), one(0.2, 0.5, 0.5), one(1.0),
                   one(0, 0, 2.0), one(3.0, 0, 0), one(1.0), one(0.5, 1.0, 0.0), params, pos=one(0, 0, 0),
                   eye=one(0, 0, 4))
    ao = (1 - 0.8 * 0.5) ** 2.0
    r1 = 0.2 + 0.5 * 0.4
    r1 = r1 + 0.5 * (0.5 - r1)
    rough = r1 + 0.5 * ((0.1 + r1 * 0.2) - r1)
    metal = 0.4
    base = np.array([0.4 * 0.5, 0.4, 0.0])                                             # player colour through Details
    k = 1 + 0.25 * (0.5 - 1)
    base = base / (k + metal * (1 - k))
    base = np.clip(base / (1 + metal * 0.5 * (0.5 - 1)), 0, 1)
    assert s['ao'][0, 0] == pytest.approx(ao) and s['rough'][0, 0] == pytest.approx(rough)
    assert s['metal'][0, 0] == pytest.approx(metal) and s['albedo'][0] == pytest.approx(base)
    assert s['n'][0] == pytest.approx([0, 0, 1])                                        # flat normal map = vertex normal
    assert s['horizon'][0, 0] == pytest.approx(2.0 * 1.5 + 1.0)                         # R = +z, raw nv length 2


def test_double_sided_flip_and_tangent_sign():
    one = lambda *v: np.array([v], np.float64)                                          # noqa: E731
    p = {'aoIntensity': 1, 'aoGamma': 0, 'liftMetallic': 0, 'liftNonMetallic': 0, 'roughnessMin': 0, 'roughnessMax': 1,
         'roughnessMetallicMin': 0, 'roughnessMetallicMax': 1, 'metallicMin': 0, 'metallicMax': 1}
    def n_of(nrm, tw, front=None):
        return R.material(one(0.5, 0.5, 0.5), one(0.5, 0.5, 0.5), one(*nrm), one(1, 0.5, 0), one(0.0), one(0, 0, 1),
                          one(1, 0, 0), one(tw), one(1, 1, 1), p, front=front, double_sided=front is not None,
                          pos=one(0, 0, 0), eye=one(0, 0, 4))['n'][0]
    assert n_of((0.5, 1.0, 0.5), 1.0) == pytest.approx([0, 1, 0])                      # B = sign(w) cross(N, T) = +y
    assert n_of((0.5, 1.0, 0.5), -1.0) == pytest.approx([0, -1, 0])
    back = np.array([[False]])
    assert n_of((0.5, 1.0, 0.5), 1.0, back) == pytest.approx([0, 1, 0])                # N and T flip: B does not
    assert n_of((0.5, 0.5, 1.0), 1.0, back) == pytest.approx([0, 0, -1])               # a back face faces back
    assert n_of((1.0, 0.5, 0.5), 1.0, back) == pytest.approx([-1, 0, 0])


@pytest.mark.parametrize('white', [11.2, 4.0])
def test_post_lut_on_the_grey_axis_at_texel_centres(white):
    lut = L.bake_tonemap_lut(white).astype(np.float64)
    noise = np.full((32, 3), 0.5)                                                      # (2n - 1) = 0: no dither
    i = np.arange(32)
    c = 2 * (i / 31) ** 2                                                               # the lookup's grid
    out = R.post_lut(np.repeat(c[:, None], 3, 1), lut, noise)
    for k in (0, 3, 9, 16, 24, 31):
        cb = 2 * (k / 32) ** 2                                                          # the build's grid
        f = lambda x: x if x < 0.25 else 0.25 + 0.75 * (1 - math.exp(-(x - 0.25) / 0.75))   # noqa: E731
        lin = min(f(cb) / f(white), 1.0)
        want = lin * 12.92 if lin <= 0.0031308 else 1.055 * lin ** (1 / 2.4) - 0.055
        assert out[k] == pytest.approx([want] * 3, abs=1.5e-3), (white, k)
    dith = R.post_lut(np.zeros((1, 3)), lut, np.ones((1, 3)))
    assert dith[0] == pytest.approx([1 / 256] * 3)


def test_legacy_hable_curve():
    assert R.hable(0.0) == pytest.approx(0.004 / 0.06 - 0.066667, abs=1e-6)
    white = 11.2
    out = R.post_legacy(np.array([[white / 2, white / 2, white / 2]]) * 1.0, np.full((1, 3), 0.5), exposure=1.0,
                        luminance_based=0.0, influence=1.0, white_point=white)
    want = min(R.hable(white) / R.hable(white), 1.0) ** (1 / 2.2)                      # 2 * 0.5 * white = white
    assert out[0] == pytest.approx([want] * 3, abs=1e-6)
    keep = R.post_legacy(np.array([[0.25, 0.5, 0.75]]), np.full((1, 3), 0.5), influence=0.0)
    assert keep[0] == pytest.approx(np.array([0.25, 0.5, 0.75]) ** (1 / 2.2))          # influence 0: untonemapped


def test_pcf25_on_a_step_edge():
    depth = np.ones((16, 16))
    depth[:, :8] = 0.2                                                                  # left half: an occluder
    z = np.array([[0.5]])
    lit = lambda u: float(R.pcf25(depth, np.array([[u, 0.5]]), z, 0.01, 1000.0)[0, 0])  # noqa: E731
    assert lit(0.1) == 0.0 and lit(0.95) == 1.0
    # p = 8.5: texels 5..10 with weights .5 1 1 1 1 .5; 5, 6, 7 occluded, 8, 9, 10 lit -> (1 + 1 + .5) / 5
    assert lit(8.5 / 16) == pytest.approx(0.5, abs=1e-12)
    assert R.pcf25(depth, np.array([[1.2, 0.5]]), z, 0.0, 1.0)[0, 0] == 1.0             # outside the map
