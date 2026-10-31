"""aoe3de-anim-viewer LOOK modules on the live game archives (owner's machine only): the Iron Flail rider and horse
materials and textures, the "Tantalus Viewer" lighting set, its reflection cube, playercolors and a .cube LUT.

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_look_local.py -q

Marked local("steam"): skipped where the Steam install is absent (CI deselects with -m "not local"). Reads the
archives in place through aoe3de-bar-archives' bartool (game layer only; layering is the VFS module's job) and
writes only into pytest's temp folder.
"""
import sys
from pathlib import Path

import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import av_common as C  # noqa: E402
import ddt as D  # noqa: E402
import lighting as L  # noqa: E402
import material as M  # noqa: E402

pytestmark = pytest.mark.local('steam')

IRON = 'units/asians/chinese/iron_flail/'
MATERIALS = ['iron_rider_0.material', 'iron_rider_2.material', 'iron_flail_horse_0.material',
             'iron_flail_horse_1.material']
TANTALUS = 'Tantalus Viewer'


@pytest.fixture(scope='module')
def game():
    sys.path.insert(0, str(C.BARTOOL_DIR))
    import bartool
    try:
        root = bartool.find_game_dir()
    except SystemExit as exc:
        pytest.skip('no AoE3 DE install: %s' % exc)
    return bartool, bartool.build_index(root)


@pytest.fixture(scope='module')
def fetch(game):
    """fetch(logical_path) -> (bytes, None) | None over the game archives (the .xmb twin and the Art root tried)."""
    bt, idx = game

    def get(path):
        for k in (path, path + '.xmb', 'art/' + path, 'art/' + path + '.xmb'):
            if k in idx:
                return bt.read_entry(idx[k]), None
        return None
    return get


@pytest.fixture(scope='module')
def iron_materials(fetch):
    cache = M.MaterialdefCache(fetch)
    out = {}
    for name in MATERIALS:
        data, _ = fetch(IRON + name)
        out[name] = M.build_materials(IRON + name, data, fetch, cache=cache)
    return out


# ---------------------------------------------------------------- materials
def test_iron_flail_rider_material(iron_materials):
    out = iron_materials['iron_rider_0.material']
    assert out['warnings'] == [] and out['source_form'] == 'xmb'
    a = out['records'][IRON + 'iron_rider_0.material#mata']
    b = out['records'][IRON + 'iron_rider_0.material#matb']
    assert a['materialdef'] == 'default' and b['materialdef'] == 'default'
    assert a['slots']['BaseColor']['texture'] == IRON + 'textures/iron_rider_0_mata_basecolor.ddt'
    assert a['slots']['BaseColor']['srgb'] is True and a['slots']['Normals']['srgb'] is False
    assert a['slots']['Details']['source'] == 'override'
    assert b['slots']['BaseColor']['texture'] == 'units/cavalry/oprichnik/textures/oprichnik_whip_mata_basecolor.ddt'
    assert b['slots']['Details'] == dict(b['slots']['Details'], texture=None, source='materialdef', default='black',
                                         unavailable_reason=None)
    assert a['floats']['AO Intensity'] == 1.0 and a['float_sources']['AO Intensity'] == 'materialdef'
    assert a['floats']['Roughness Max'] == 1.0 and a['floats']['Metallic Min'] == 0.0
    assert not a['flags']['cutout'] and not a['flags']['double_sided'] and a['flags']['color_adjustments']
    assert a['flags']['shader_file'] == 'material/materialdefault.hlsl'


def test_iron_flail_horse_material_is_double_sided_cutout(iron_materials):
    rec = iron_materials['iron_flail_horse_0.material']['records'][IRON + 'iron_flail_horse_0.material#mata']
    assert rec['materialdef'] == 'default_doublesided_cutout'
    assert rec['flags']['cutout'] and rec['flags']['double_sided'] and rec['flags']['cullface'] == 'none'
    assert rec['floats']['CutoutThreshold'] == 0.5 and rec['flags']['cutout_threshold'] == 0.5
    assert set(rec['slots']) == {'BaseColor', 'Normals', 'Masks', 'Details'}
    assert all(s['source'] == 'override' for s in rec['slots'].values())


def test_every_iron_flail_texture_exists_and_uploads_raw(iron_materials, fetch, tmp_path):
    uses = {}
    for out in iron_materials.values():
        for tid, u in out['texture_uses'].items():
            uses.setdefault(tid, []).extend(u)
    assert len(uses) == 19                                   # 4 materials x 4 maps + 3 shared whip maps
    w = C.BufferWriter('tex')
    seen = {}
    for tid in sorted(uses):
        got = fetch(tid)
        assert got is not None, tid
        rec = D.texture_record(tid, got[0], w)
        assert rec['decodable'], (tid, rec['unavailable_reason'], rec.get('problems'))
        assert rec['max_level'] == rec['mip_count'] - 1 and not rec['complete_to_1x1']
        last = rec['mips'][-1]
        assert (last['width'], last['height']) == (4, 4) and last['view']['byteLength'] == (8 if rec['bc'] == 'BC1'
                                                                                             else 16)
        seen[tid.rsplit('/', 1)[1]] = (rec['ddt_format'], rec['bc'], rec['width'], rec['mip_count'])
    assert seen['iron_rider_0_mata_basecolor.ddt'] == (5, 'BC1', 1024, 9)
    assert seen['iron_flail_horse_0_mata_basecolor.ddt'] == (9, 'BC3', 1024, 9)
    assert seen['iron_rider_0_mata_normals.ddt'][:2] == (4, 'BC1')
    assert seen['iron_rider_0_mata_details.ddt'][:2] == (5, 'BC1')
    data = fetch(IRON + 'textures/iron_rider_0_mata_normals.ddt')[0]
    rgba = D.decode_rgba(data, level=0)
    assert rgba.shape == (1024, 1024, 4)
    png = D.write_png(data, tmp_path / 'rider_normals_l3.png', level=3)
    assert png.is_file() and not C.is_repo_path(png)


# ---------------------------------------------------------------- lighting
def test_tantalus_viewer_lgt(fetch):
    assert L.lgt_path(TANTALUS) == 'lightsets/tantalus viewer.lgt'
    got = fetch(L.lgt_path(TANTALUS))
    assert got is not None, 'Art/lightsets/Tantalus Viewer.lgt(.XMB) not in the archives'
    rec = L.lgt_record(TANTALUS, got[0])
    f = rec['fields']
    assert rec['source_form'] == 'xmb' and rec['warnings'] == []
    assert f['suncolor'] == [255, 254, 254] and f['whitepoint'] == pytest.approx(11.2)
    assert f['mipmapbias'] == pytest.approx(-1.0) and f['colorgradecustomlut'] is None
    assert len(f) >= 70
    sky = rec['derived']['sky_cube']['value']
    assert sky == 'lighting/environments/df360_006_4k_reloaded_srgb_us.refl' and fetch(sky) is not None
    C.json_text(rec)


def test_tantalus_reflection_cube_is_face_major(fetch):
    data = fetch('lighting/environments/df360_006_4k_reloaded_srgb_us.refl')[0]
    h = L.parse_refl_header(data)
    assert (h['version'], h['size'], h['mip_count'], h['format']) == (3, 512, 7, 'rgba32f') and h['problems'] == []
    assert np.linalg.norm(h['header_floats'][:3]) == pytest.approx(1.0, abs=1e-4)
    levels = L.refl_levels(data)
    m0 = levels[0][2][..., :3].reshape(6, -1, 3).mean(1)
    m1 = levels[1][2][..., :3].reshape(6, -1, 3).mean(1)
    assert np.abs(m1 - m0).max() / np.abs(m0).max() < 0.05      # each face keeps its mean down the chain
    rec = L.refl_record('lighting/environments/df360_006_4k_reloaded_srgb_us.refl', data, C.BufferWriter('env'),
                        max_size=64)
    assert rec['levels_skipped'] == [0, 1, 2] and [m['size'] for m in rec['mips']] == [64, 32, 16, 8]


def test_tonemap_lut_from_the_tantalus_white_point(fetch):
    wp = L.lgt_record(TANTALUS, fetch(L.lgt_path(TANTALUS))[0])['fields']['whitepoint']
    lut = L.bake_tonemap_lut(wp)
    import math
    f = lambda x: x if x < 0.25 else 0.25 + 0.75 * (1 - math.exp(-(x - 0.25) / 0.75))     # noqa: E731
    s = lambda x: x * 12.92 if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055          # noqa: E731
    for i in (4, 16, 31):
        c = 2 * (i / 32) ** 2
        assert lut[i, i, i, 0] == pytest.approx(s(min(f(c) / f(wp), 1)), abs=1e-3)


def test_playercolors_and_a_cube_lut(fetch):
    rec = L.player_colors_record(fetch('data/playercolors.xml')[0])
    assert [p['index'] for p in rec] == list(range(13))
    assert all(len(p['rgb']) == 3 and all(0 <= v <= 255 for v in p['rgb']) for p in rec)
    cube = L.parse_cube(fetch('lighting/luts/age304a_caribbean.cube')[0])
    assert cube['size'] == 25 and cube['table'].shape == (25, 25, 25, 3)
    assert 0.0 <= float(cube['table'].min()) and float(cube['table'].max()) <= 1.0


def test_build_lighting_for_tantalus(fetch):
    out = L.build_lighting(TANTALUS, fetch, C.BufferWriter('env'), refl_max_size=32)
    s = out['section']
    assert out['warnings'] == []
    assert s['lgt']['name'] == TANTALUS and s['refl']['size'] == 512 and s['grade_lut'] is None
    assert s['tonemap_lut']['white_point'] == pytest.approx(11.2) and len(s['player_colors']) == 13
    C.json_text(s)


def test_the_vfs_adapter_reads_the_same_material(fetch, iron_materials):
    try:
        import vfs as V
        fs = V.VFS()
    except Exception as exc:                               # noqa: BLE001 - the VFS stage may be mid-build
        pytest.skip('vfs.VFS unavailable: %s' % exc)
    vf = M.vfs_fetch(fs)
    got = vf(IRON + 'iron_rider_0.material')
    assert got is not None and isinstance(got[1], int)
    out = M.build_materials(IRON + 'iron_rider_0.material', got[0], vf)
    ref = iron_materials['iron_rider_0.material']['records']
    for mid, rec in out['records'].items():
        assert rec['slots'] == ref[mid]['slots'] and rec['floats'] == ref[mid]['floats']
        assert isinstance(rec['materialdef_provenance'], int)


def test_build_lighting_through_the_vfs():
    try:
        import vfs as V
        fs = V.VFS()
    except Exception as exc:                               # noqa: BLE001 - the VFS stage may be mid-build
        pytest.skip('vfs.VFS unavailable: %s' % exc)
    out = L.build_lighting(TANTALUS, M.vfs_fetch(fs), C.BufferWriter('env'), refl_max_size=16)
    s = out['section']
    assert out['warnings'] == []
    assert all(isinstance(s[k]['provenance'], int) for k in ('lgt', 'refl'))
    layers = {fs.provenance.records[s[k]['provenance']]['layer'] for k in ('lgt', 'refl')}
    assert layers <= {lay['id'] for lay in fs.layer_records()}
