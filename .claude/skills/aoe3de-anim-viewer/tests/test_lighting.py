"""aoe3de-anim-viewer lighting.py: .lgt, .refl, .cube, playercolors and the tonemap LUT port.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_lighting.py -q

Synthetic and CI-safe: every lighting set, reflection cube, LUT and colour table is built inside the test with
made-up values. The tonemap LUT is checked against hand-computed points: with tonemapping disabled each texel is
srgb(min(2*(i/32)^2, 1)); on the grey axis the chroma terms vanish and each texel is srgb(f(c) / f(white)) with the
shoulder f(x) = x below 0.25, else 0.25 + 0.75*(1 - exp(-(x - 0.25)/0.75)).
"""
import math
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import av_common as C  # noqa: E402
import lighting as L  # noqa: E402

sys.path.insert(0, str(C.BARTOOL_DIR))
import xmbc  # noqa: E402

BS = chr(92)
STATUS = {'measured', 'name-match', 'guess', 'unknown', 'omitted-measured', 'not-ported'}

LGT = ('<lightingset>\r\n'
       '  <suncolor>250 240 230</suncolor>\r\n'
       '  <sunintensity>4.000000</sunintensity>\r\n'
       '  <suninclination>30.000000</suninclination>\r\n'
       '  <sunrotation>90.000000</sunrotation>\r\n'
       '  <shadowcolor>128 128 255</shadowcolor>\r\n'
       '  <skycubemap>lighting' + BS + 'environments' + BS + 'test_sky</skycubemap>\r\n'
       '  <hemitopcolor>255 0 0</hemitopcolor>\r\n'
       '  <hemibottomcolor>0 0 255</hemibottomcolor>\r\n'
       '  <hemiintensity>0.500000</hemiintensity>\r\n'
       '  <exposure>2.000000</exposure>\r\n'
       '  <whitepoint>1.000000</whitepoint>\r\n'
       '  <bloomiterations>3</bloomiterations>\r\n'
       '  <skycubemaprotation>0.500000</skycubemaprotation>\r\n'
       '  <colorgradetint_global>1.000000, 0.999900, 0.999900</colorgradetint_global>\r\n'
       '  <colorgradecustomlut>my_grade</colorgradecustomlut>\r\n'
       '  <fillintensity>3.000000</fillintensity>\r\n'
       '</lightingset>\r\n')

PLAYERCOLORS = ('<playercolors>\n'
                '  <player num="1" color1="10 20 30" color2="1 2 3" color3="4 5 6" minimap="7 8 9" />\n'
                '  <player num="0" color1="100 110 120" color2="0 0 0" color3="0 0 0" minimap="1 1 1" />\n'
                '  <friendorfoeself color1="75 75 230" color2="75 75 230" color3="75 75 230" minimap="0 0 255" />\n'
                '</playercolors>\n')


def xmb(text):
    root = ET.fromstring(text)
    return xmbc.Compiler(root).payload(root)


def make_refl(size, mips, fmt=2, floats=(0.0, 1.0, 0.0, 2.5), payload_fix=0):
    """face-major REFL: channel 0 = face, 1 = level, 2 = texel index, 3 = 1."""
    parts = []
    for face in range(6):
        for k in range(mips):
            s = max(1, size >> k)
            a = np.ones((s, s, 4), np.float32)
            a[..., 0], a[..., 1], a[..., 2] = face, k, np.arange(s * s).reshape(s, s)
            parts.append(a.tobytes())
    payload = b''.join(parts)
    return struct.pack('<4s5I4f', b'REFL', 3, size, mips, fmt, len(payload) + payload_fix, *floats) + payload


def make_cube(n, title='synthetic'):
    lines = ['# comment', 'TITLE "%s"' % title, 'LUT_3D_SIZE %d' % n, 'DOMAIN_MIN 0 0 0', 'DOMAIN_MAX 1 1 1', '']
    lines += ['%d.0 0.5 0.25' % i for i in range(n ** 3)]
    return ('\n'.join(lines) + '\n').encode()


def srgb(x):
    return x * 12.92 if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055


def f_shoulder(x):
    return x if x < 0.25 else 0.25 + 0.75 * (1 - math.exp(-(x - 0.25) / 0.75))


# ---------------------------------------------------------------- .lgt
def test_lgt_values_are_typed_as_read():
    p = L.parse_lgt(LGT.encode())
    f = p['fields']
    assert f['suncolor'] == [250, 240, 230] and f['sunintensity'] == 4.0 and f['bloomiterations'] == 3
    assert f['colorgradetint_global'] == [1.0, 0.9999, 0.9999]
    assert f['skycubemap'] == 'lighting' + BS + 'environments' + BS + 'test_sky'
    assert p['raw']['sunintensity'] == '4.000000' and p['order'][0] == 'suncolor'
    assert p['eol'] == 'crlf' and p['source_form'] == 'xml' and p['extra'] == []
    assert L.parse_value('') is None and L.parse_value('  ') is None


def test_xmb_lgt_reads_the_same():
    a, b = L.parse_lgt(LGT.encode()), L.parse_lgt(xmb(LGT))
    assert a['fields'] == b['fields'] and b['eol'] == 'xmb'


def test_lgt_names_and_paths():
    assert L.lgt_path('Tantalus Viewer') == 'lightsets/tantalus viewer.lgt'
    assert L.lgt_path('lightsets/x.lgt') == 'lightsets/x.lgt'
    assert L.refl_path('lighting' + BS + 'environments' + BS + 'Sky') == 'lighting/environments/sky.refl'
    assert L.refl_path(None) is None


def test_derived_constants_are_labelled_and_hand_checkable():
    d = L.derive_constants(L.parse_lgt(LGT.encode())['fields'])
    assert all(v['status'] in STATUS and 'rule' in v and 'target' in v for v in d.values())
    lin = [((c / 255 + 0.055) / 1.055) ** 2.4 * 4.0 for c in (250, 240, 230)]
    assert d['sun_color']['status'] == 'guess' and np.allclose(d['sun_color']['value'], lin, atol=1e-9)
    assert np.allclose(d['sun_color']['alternatives']['linear_255'], [c / 255 * 4 for c in (250, 240, 230)])
    e = math.radians(30)
    assert np.allclose(d['sun_direction']['value'], [math.cos(e), math.sin(e), 0], atol=1e-12)
    assert d['shadow_color']['value'] == [128 / 255, 128 / 255, 1.0]
    assert d['hemi_top']['value'] == [0.5, 0.0, 0.0] and d['hemi_bottom']['value'] == [0.0, 0.0, 0.5]
    assert d['sky_cube'] == dict(d['sky_cube'], value='lighting/environments/test_sky.refl', status='name-match')
    assert d['sky_cube_rotation']['value'] == {'raw': 0.5, 'sin': math.sin(0.5), 'cos': math.cos(0.5)}
    assert d['white_point']['value'] == 1.0 and d['fill']['status'] == 'omitted-measured'
    assert d['sky_cube_intensity'] == dict(d['sky_cube_intensity'], value=None, status='unknown')
    assert d['colour_grade']['status'] == 'not-ported' and 'colorgradetint_global' in d['colour_grade']['value']


def test_sun_direction_axes():
    assert np.allclose(L.sun_direction(90, 123), [0, 1, 0], atol=1e-12)
    assert np.allclose(L.sun_direction(0, 0), [0, 0, 1], atol=1e-12)
    assert np.allclose(L.sun_direction(0, 90), [1, 0, 0], atol=1e-12)


def test_missing_lgt_fields_derive_to_none_not_errors():
    d = L.derive_constants({})
    assert d['sun_color']['value'] is None and d['sun_direction']['value'] is None
    assert d['sky_cube']['value'] is None and d['sky_cube_rotation']['value'] is None


def test_lf_only_lgt_warns():
    rec = L.lgt_record('x', LGT.replace('\r\n', '\n').encode())
    assert rec['eol'] == 'lf' and [w['code'] for w in rec['warnings']] == ['lf-only-runtime-xml']
    assert rec['id'] == 'lightsets/x.lgt'
    C.json_text(rec)


# ---------------------------------------------------------------- .refl
def test_refl_header_and_face_major_regrouping():
    data = make_refl(16, 3)
    h = L.parse_refl_header(data)
    assert (h['version'], h['size'], h['mip_count'], h['format'], h['texel_bytes']) == (3, 16, 3, 'rgba32f', 16)
    assert h['header_floats'] == [0.0, 1.0, 0.0, 2.5] and h['problems'] == [] and h['header_size'] == 40
    for level, size, arr in L.refl_levels(data):
        assert arr.shape == (6, size, size, 4) and size == 16 >> level
        assert (arr[..., 0] == np.arange(6)[:, None, None]).all() and (arr[..., 1] == level).all()
        assert (arr[:, :, :, 2].reshape(6, -1) == np.arange(size * size)).all()


def test_refl_record_views_hold_six_faces_per_level():
    data = make_refl(8, 3)
    w = C.BufferWriter('env')
    rec = L.refl_record('lighting/environments/s.refl', data, w, provenance=4, max_size=4)
    assert rec['decodable'] and rec['levels_skipped'] == [0] and rec['mip_count'] == 3 and rec['size'] == 8
    assert [(m['level'], m['size']) for m in rec['mips']] == [(1, 4), (2, 2)]
    v = rec['mips'][0]['view']
    assert (v['dtype'], v['components'], v['count']) == ('f32', 4, 6 * 16)
    a = C.read_view(w.data(), v)
    assert (a[:16, 0] == 0).all() and (a[16:32, 0] == 1).all() and (a[:, 1] == 1).all()
    assert rec['face_order']['status'] == 'guess' and rec['header_floats']['status'] == 'guess'
    C.json_text(rec)


def test_a_broken_refl_keeps_its_id_and_says_why():
    rec = L.refl_record('r.refl', make_refl(8, 2, payload_fix=4), C.BufferWriter('env'))
    assert not rec['decodable'] and rec['unavailable_reason'] == 'refl-unreadable' and rec['problems']
    rec = L.refl_record('r.refl', make_refl(8, 2, fmt=9), C.BufferWriter('env'))
    assert rec['unavailable_reason'] == 'refl-unreadable'
    with pytest.raises(ValueError):
        L.parse_refl_header(b'DDS ' + bytes(60))


# ---------------------------------------------------------------- .cube and player colours
def test_cube_lut_is_red_fastest():
    c = L.parse_cube(make_cube(3))
    assert c['size'] == 3 and c['title'] == 'synthetic' and c['domain_max'] == [1.0, 1.0, 1.0]
    t = c['table']
    assert t.shape == (3, 3, 3, 3) and t.dtype == np.float32
    assert t[2, 1, 0, 0] == 0 + 3 * 1 + 9 * 2 and t[0, 0, 2, 0] == 2 and (t[..., 1] == 0.5).all()
    w = C.BufferWriter('env')
    rec = L.grade_lut_record('lighting/luts/x.cube', make_cube(2), w)
    a = C.read_view(w.data(), rec['view'])
    assert a.shape == (8, 4) and (a[:, 0] == np.arange(8)).all() and (a[:, 3] == 1).all()


def test_bad_cube_files_are_refused():
    with pytest.raises(ValueError):
        L.parse_cube(b'LUT_3D_SIZE 2\n0 0 0\n')
    with pytest.raises(ValueError):
        L.parse_cube(b'LUT_1D_SIZE 4\n0 0 0\n')
    with pytest.raises(ValueError):
        L.parse_cube(b'0 0 0\n')


def test_player_colours():
    rec = L.player_colors_record(PLAYERCOLORS.encode())
    assert [p['index'] for p in rec] == [0, 1]
    assert rec[1] == {'index': 1, 'rgb': [10, 20, 30], 'color2': [1, 2, 3], 'color3': [4, 5, 6],
                      'minimap': [7, 8, 9], 'rgb_source': 'color1 (guess)'}
    assert L.parse_playercolors(xmb(PLAYERCOLORS))['special']['friendorfoeself']['minimap'] == [0, 0, 255]


# ---------------------------------------------------------------- tonemap LUT: hand-computed points
def test_shader_literals_are_the_published_constants():
    k = L.K
    assert k['pq_m1'] == 2610 / 16384 and k['pq_m2'] == 2523 / 32 and k['pq_c1'] == 3424 / 4096
    assert k['pq_c2'] == 2413 / 128 and k['pq_c3'] == 2392 / 128 and k['pq_in'] == pytest.approx(0.01)
    assert k['shoulder_k'] == pytest.approx(-1 / (0.75 * math.log(2)), rel=1e-7)
    assert k['desat_a'] == pytest.approx(-1 / 0.7, rel=1e-7)
    assert k['lookup_scale'] == 31 / 32 and k['lookup_bias'] == 1 / 64 and k['dither'] == 1 / 256
    for a, b in ((L._RGB_TO_XYZ, L._XYZ_TO_RGB), (L._XYZ_TO_LMS, L._LMS_TO_XYZ), (L._LMS_TO_ICTCP, L._ICTCP_TO_LMS)):
        assert np.abs(L._m(a) @ L._m(b) - np.eye(3)).max() < 1e-6


def test_lut_grid_and_lookup_formulas():
    i = np.arange(32)
    assert np.array_equal(L.lut_input(i), (2 * (i / 32) ** 2).astype(np.float32))
    assert np.allclose(L.lut_lookup(2 * (i / 31) ** 2), (i + 0.5) / 32, atol=1e-6)
    assert L.lut_lookup(5.0) == pytest.approx(31 / 32 + 1 / 64)


def test_disabled_tonemap_is_srgb_of_the_grid():
    lut = L.bake_tonemap_lut(11.2, enabled=False)
    assert lut.shape == (32, 32, 32, 4) and lut.dtype == np.float32 and (lut[..., 3] == 1).all()
    for i in (0, 1, 4, 8, 16, 22, 23, 31):
        assert lut[0, 0, i, 0] == pytest.approx(srgb(min(2 * (i / 32) ** 2, 1.0)), abs=2e-6), i
    assert lut[5, 3, 7].tolist()[:3] == pytest.approx([srgb(2 * (k / 32) ** 2) for k in (7, 3, 5)], abs=2e-6)


@pytest.mark.parametrize('white', [11.2, 1.0, 4.0])
def test_grey_axis_matches_the_hand_formula(white):
    lut = L.bake_tonemap_lut(white)
    for i in (0, 2, 4, 8, 11, 16, 20, 24, 31):
        c = 2 * (i / 32) ** 2
        want = srgb(min(f_shoulder(c) / f_shoulder(white), 1.0))
        assert lut[i, i, i, :3] == pytest.approx([want] * 3, abs=1e-3), (white, i)


def test_black_stays_black_through_the_nan_path():
    assert L.bake_tonemap_lut(11.2)[0, 0, 0].tolist() == [0.0, 0.0, 0.0, 1.0]


def test_ictcp_round_trip_and_neutral_grey():
    x = np.array([[0.18, 0.18, 0.18], [0.5, 0.2, 0.1], [1.5, 0.9, 0.3]], np.float32)
    ictcp = L.rgb_to_ictcp(x)
    assert abs(ictcp[0, 1]) < 1e-3 and abs(ictcp[0, 2]) < 1e-3
    assert np.abs(L.ictcp_to_rgb(ictcp) - x).max() < 1e-4


def test_shoulder_is_continuous_and_bounded():
    assert L.shoulder(0.25) == pytest.approx(0.25) and L.shoulder(0.2) == pytest.approx(0.2)
    assert L.shoulder(0.2500001) == pytest.approx(0.25, abs=1e-6)
    assert 0.999 < float(L.shoulder(20.0)) <= 1.0
    assert L.shoulder(1.0) == pytest.approx(f_shoulder(1.0), abs=1e-6)


def test_bright_saturated_colours_desaturate_and_dim_ones_do_not():
    hi = L.tonemap_linear(np.array([1.8, 0.02, 0.02], np.float32), 11.2)
    lo = L.tonemap_linear(np.array([0.2, 0.01, 0.01], np.float32), 11.2)
    assert hi[0] > hi[1] > 0 and hi[1] / hi[0] > 2 * (0.02 / 1.8)
    assert lo == pytest.approx([0.2, 0.01, 0.01], rel=2e-3)


def test_tonemap_lut_record():
    w = C.BufferWriter('env')
    rec = L.tonemap_lut_record(w, 11.2)
    v = rec['view']
    assert rec['size'] == 32 and (v['dtype'], v['components'], v['count']) == ('f32', 4, 32 ** 3)
    assert v['byteLength'] == 32 ** 3 * 16 and rec['status']['formula'] == 'measured'
    a = C.read_view(w.data(), v).reshape(32, 32, 32, 4)
    assert np.array_equal(a, L.bake_tonemap_lut(11.2))
    C.json_text(rec)


# ---------------------------------------------------------------- the whole section
def fake_fetch(files):
    return lambda path: (files[path], 9) if path in files else None


def test_build_lighting_assembles_every_part():
    files = {'lightsets/test.lgt': LGT.encode(), 'lighting/environments/test_sky.refl': make_refl(8, 2),
             'lighting/luts/my_grade.cube': make_cube(2), 'data/playercolors.xml': PLAYERCOLORS.encode()}
    w = C.BufferWriter('env')
    out = L.build_lighting('test', fake_fetch(files), w, player_color_index=0)
    s = out['section']
    assert out['warnings'] == []
    assert s['lgt']['id'] == 'lightsets/test.lgt' and s['lgt']['provenance'] == 9 and 'warnings' not in s['lgt']
    assert s['refl']['id'] == 'lighting/environments/test_sky.refl' and len(s['refl']['mips']) == 2
    assert s['grade_lut']['id'] == 'lighting/luts/my_grade.cube' and s['grade_lut']['size'] == 2
    assert s['tonemap_lut']['white_point'] == 1.0 and s['player_color_index'] == 0
    assert [p['index'] for p in s['player_colors']] == [0, 1] and 'friendorfoeself' in s['player_colors_special']
    C.json_text(s)


def test_build_lighting_reports_missing_inputs():
    out = L.build_lighting('test', fake_fetch({'lightsets/test.lgt': LGT.encode()}), C.BufferWriter('env'))
    missing = sorted(w['path'] for w in out['warnings'] if w['code'] == 'file-missing')
    assert missing == ['data/playercolors.xml', 'lighting/environments/test_sky.refl', 'lighting/luts/my_grade.cube']
    s = out['section']
    assert s['refl'] is None and s['grade_lut'] is None and s['tonemap_lut'] is not None


def test_cli_prints_the_grey_axis(capsys):
    assert L.main(['lut', '--white', '1.0']) == 0
    lines = capsys.readouterr().out.splitlines()
    assert len(lines) == 32 and lines[0].startswith(' 0  c=0.00000') and lines[31].startswith('31  c=1.87695')
