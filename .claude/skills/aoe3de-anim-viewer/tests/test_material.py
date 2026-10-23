"""aoe3de-anim-viewer material.py: .material + .materialdef merge (bundle-schema.md section 8).

    python -m pytest .claude/skills/aoe3de-anim-viewer/tests/test_material.py -q

Synthetic and CI-safe: every material and materialdef is written inside the test, as CRLF XML, LF XML, XMB
(compiled with aoe3de-bar-archives' xmbc) and alz4-wrapped XMB. No game bytes.
"""
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import av_common as C  # noqa: E402
import material as M  # noqa: E402

sys.path.insert(0, str(C.BARTOOL_DIR))
import xmbc  # noqa: E402

BS = chr(92)

MDEF_CUTOUT_DS = """<materialdef pass="opaque" showinviewer="true">
  <shader file="material/materialdefault.hlsl">
    <define name="CUTOUT" />
    <define name="DOUBLESIDED" />
    <define name="COLOR_ADJUSTMENTS" />
    <cullmode cullface="none" />
    <vertexformat name="SkinnedPackedVertex" />
    <stencil func="always" wmask="255" rmask="255" fail="keep" zfail="keep" pass="replace" ref="0" />
  </shader>
  <parameters>
    <texture default="missingbasecolor" name="BaseColor" requiresoverride="true" srgb="true" depthonly="true" />
    <texture default="missingnormal" name="Normals" requiresoverride="true" />
    <texture default="missingmasks" name="Masks" requiresoverride="true" />
    <texture default="black" name="Details" />
    <float default="0" name="pixelxformColor" showineditor="false" />
    <float default="0.5" name="CutoutThreshold" />
    <float default="1.0f" name="AO Intensity" min="0" max="2" control="slider" />
    <float default="0.0f" name="Roughness Min" min="0" max="1" control="slider" />
    <vector4 default="1, 1, 1, 1" name="EmissiveColor" />
  </parameters>
</materialdef>"""

MDEF_DEFAULT = """<materialdef pass="opaque" showinviewer="true">
  <shader file="material/materialdefault.hlsl">
    <vertexformat name="StaticPackedVertex" />
    <define name="COLOR_ADJUSTMENTS" />
  </shader>
  <parameters>
    <texture default="missingbasecolor" name="BaseColor" requiresoverride="true" srgb="true" />
    <texture default="missingnormal" name="Normals" requiresoverride="true" />
    <texture default="missingmasks" name="Masks" requiresoverride="true" />
    <texture default="black" name="Details" />
    <float default="1.0f" name="AO Intensity" />
    <float default="0.0f" name="Lift Metallic" />
  </parameters>
</materialdef>"""

MDEF_DECAL = """<materialdef pass="transparent">
  <shader file="material/decal.hlsl">
    <blendmode preset="alphablend" />
    <depthmode write="false" test="true" />
    <permutation name="SHADER_VARIATION_Soft" />
    <renderpass name="BasePass" />
    <renderpass name="UserPass0" />
    <passstate pass="UserPass0"><depthmode write="false" test="false" /></passstate>
    <optionalstage name="Something" />
  </shader>
  <parameters>
    <texture default="missing" name="BaseColor" srgb="true" />
    <vector4 default="0,0,0.18,1" name="deepColor" tooltip="???" />
    <int default="3" name="Odd" />
  </parameters>
  <renderpass name="Outer" />
</materialdef>"""


def tex(name):
    return 'units' + BS + 'test' + BS + 'textures' + BS + name


MATERIAL = ('<material>\n'
            '  <submaterial name="mata">\n'
            '    <materialdef name="default_doublesided_cutout" />\n'
            '    <parameters>\n'
            '      <texture name="BaseColor" override="%s" />\n'
            '      <texture name="Normals" override="%s" />\n'
            '      <texture name="Masks" override="%s" />\n'
            '      <texture name="Details" override="%s" />\n'
            '      <float name="AO Intensity" override="0.2000" />\n'
            '      <vector4 name="EmissiveColor" override="1.000, 0.958, 0.000, 1.000" />\n'
            '    </parameters>\n'
            '  </submaterial>\n'
            '  <submaterial name="matb">\n'
            '    <materialdef name="default" />\n'
            '    <parameters>\n'
            '      <texture name="BaseColor" override="%s" />\n'
            '      <texture name="Normals" override="%s" />\n'
            '    </parameters>\n'
            '  </submaterial>\n'
            '</material>\n') % (tex('Unit_matA_BaseColor'), tex('Unit_matA_Normals'), tex('Unit_matA_Masks'),
                                tex('Unit_matA_Details'), tex('Whip_BaseColor'), tex('Unit_matA_Normals'))


def crlf(text):
    return text.replace('\r\n', '\n').replace('\n', '\r\n').encode('utf-8')


def xmb(text):
    root = ET.fromstring(text)
    return xmbc.Compiler(root).payload(root)


def alz4_literal(raw):
    """an alz4 wrapper around an LZ4 block of literals only (valid LZ4; no lz4 package needed)."""
    n = len(raw)
    if n < 15:
        head = bytes([n << 4])
    else:
        rest = n - 15
        head = bytes([0xF0]) + b'\xff' * (rest // 255) + bytes([rest % 255])
    block = head + raw
    return b'alz4' + struct.pack('<III', n, len(block), 1) + block


def fetcher(defs):
    """fetch(logical_path) over {materialdef name: bytes}, provenance index = position."""
    table = {M.materialdef_path(k): (v, i) for i, (k, v) in enumerate(defs.items())}
    return lambda path: table.get(path)


DEFS = {'default_doublesided_cutout': crlf(MDEF_CUTOUT_DS), 'default': crlf(MDEF_DEFAULT)}


# ---------------------------------------------------------------- paths and small parsers
def test_paths_follow_the_bundle_id_rules():
    assert M.materialdef_path('default') == 'render/materialdefs/default.materialdef'
    assert M.materialdef_path('speedtree' + BS + 'nonspeedtree_subsurface') == \
        'render/materialdefs/speedtree/nonspeedtree_subsurface.materialdef'
    assert M.texture_path(tex('Unit_matA_BaseColor')) == 'units/test/textures/unit_mata_basecolor.ddt'
    assert M.texture_path('units/x/already.ddt') == 'units/x/already.ddt'


def test_numbers_vectors_and_line_endings():
    assert M.number('1.0f') == 1.0 and M.number('0.0000') == 0.0 and M.number('0') == 0.0
    assert M.number('abc') is None and M.number(None) is None
    assert M.vector('1, 1, 0, 0') == [1.0, 1.0, 0.0, 0.0] and M.vector('0,0,0.18,1') == [0, 0, 0.18, 1]
    assert M.vector('1, x') is None
    assert M.detect_eol(b'<a>\r\n</a>\r\n') == 'crlf'
    assert M.detect_eol(b'<a>\n</a>\n') == 'lf'
    assert M.detect_eol(b'<a>\r\n</a>\n') == 'mixed'
    assert M.detect_eol(b'<a/>') == 'none'
    assert M.detect_eol(xmb('<a/>')) == 'xmb'
    assert M.detect_eol(alz4_literal(xmb('<a/>'))) == 'xmb'


# ---------------------------------------------------------------- materialdef
def test_materialdef_textures_floats_vectors_and_flags():
    d = M.parse_materialdef(crlf(MDEF_CUTOUT_DS), 'default_doublesided_cutout')
    assert d['pass'] == 'opaque' and d['eol'] == 'crlf' and d['source_form'] == 'xml'
    bc = d['textures']['BaseColor']
    assert bc['srgb'] and bc['requiresoverride'] and bc['depthonly'] and bc['default'] == 'missingbasecolor'
    assert not d['textures']['Normals']['srgb'] and d['textures']['Details']['default'] == 'black'
    assert d['floats']['AO Intensity']['default'] == 1.0
    assert d['floats']['AO Intensity']['attrs'] == {'min': '0', 'max': '2', 'control': 'slider'}
    assert d['vectors']['EmissiveColor']['default'] == [1, 1, 1, 1]
    f = d['flags']
    assert f['cutout'] and f['double_sided'] and f['color_adjustments'] and not f['emissive']
    assert f['cullface'] == 'none' and f['cutout_threshold'] == 0.5 and f['pass'] == 'opaque'
    assert d['shader']['states']['stencil']['func'] == 'always'


def test_cullface_none_alone_makes_a_material_double_sided():
    text = MDEF_DEFAULT.replace('<define name="COLOR_ADJUSTMENTS" />', '<cullmode cullface="none" />')
    assert M.parse_materialdef(text.encode())['flags']['double_sided']
    assert not M.parse_materialdef(MDEF_DEFAULT.encode())['flags']['double_sided']


def test_materialdef_keeps_every_construct_it_does_not_model():
    d = M.parse_materialdef(MDEF_DECAL.encode(), 'decals/decal')
    sh = d['shader']
    assert sh['permutations'] == ['SHADER_VARIATION_Soft'] and sh['renderpasses'] == ['BasePass', 'UserPass0']
    assert sh['passstates'] == [{'pass': 'UserPass0', 'states': {'depthmode': {'write': 'false', 'test': 'false'}}}]
    assert sh['states']['blendmode'] == {'preset': 'alphablend'}
    assert sh['other'] == [{'tag': 'optionalstage', 'attrs': {'name': 'Something'}}]
    assert d['vectors']['deepColor']['default'] == [0, 0, 0.18, 1]
    assert {'tag': 'int', 'attrs': {'default': '3', 'name': 'Odd'}} in d['extra']
    assert {'tag': 'renderpass', 'attrs': {'name': 'Outer'}} in d['extra']
    assert d['flags']['blendmode'] == {'preset': 'alphablend'}


def test_xml_xmb_and_alz4_materialdefs_parse_alike():
    a = M.parse_materialdef(crlf(MDEF_CUTOUT_DS))
    b = M.parse_materialdef(xmb(MDEF_CUTOUT_DS))
    c = M.parse_materialdef(alz4_literal(xmb(MDEF_CUTOUT_DS)))
    assert b['source_form'] == 'xmb' and b['eol'] == 'xmb'
    for d in (b, c):
        assert {k: d[k] for k in ('textures', 'floats', 'vectors', 'flags', 'shader')} == \
               {k: a[k] for k in ('textures', 'floats', 'vectors', 'flags', 'shader')}


def test_not_a_materialdef_is_refused():
    with pytest.raises(ValueError):
        M.parse_materialdef(b'<material/>')
    with pytest.raises(ValueError):
        M.parse_material(b'<materialdef/>')


# ---------------------------------------------------------------- material merge
def test_material_merges_overrides_over_materialdef_defaults():
    out = M.build_materials('units/test/unit.material', crlf(MATERIAL), fetcher(DEFS), provenance=7)
    recs = out['records']
    assert list(recs) == ['units/test/unit.material#mata', 'units/test/unit.material#matb']
    a = recs['units/test/unit.material#mata']
    assert a['materialdef'] == 'default_doublesided_cutout' and a['provenance'] == 7
    assert a['materialdef_path'] == 'render/materialdefs/default_doublesided_cutout.materialdef'
    assert a['materialdef_provenance'] == 0 and a['eol'] == 'crlf'
    assert a['slots']['BaseColor'] == {'texture': 'units/test/textures/unit_mata_basecolor.ddt', 'srgb': True,
                                       'source': 'override', 'unavailable_reason': None,
                                       'reference': tex('Unit_matA_BaseColor'), 'default': 'missingbasecolor'}
    assert a['slots']['Normals']['srgb'] is False
    assert a['floats']['AO Intensity'] == 0.2 and a['float_sources']['AO Intensity'] == 'override'
    assert a['floats']['Roughness Min'] == 0.0 and a['float_sources']['Roughness Min'] == 'materialdef'
    assert a['floats']['CutoutThreshold'] == 0.5
    assert a['floats']['EmissiveColor'] == [1.0, 0.958, 0.0, 1.0]
    assert a['flags']['cutout'] and a['flags']['double_sided']
    b = recs['units/test/unit.material#matb']
    assert b['slots']['Details'] == {'texture': None, 'srgb': False, 'source': 'materialdef',
                                     'unavailable_reason': None, 'reference': None, 'default': 'black'}
    assert b['slots']['Masks']['unavailable_reason'] == 'override-missing'
    assert not b['flags']['cutout'] and not b['flags']['double_sided']
    codes = [w['code'] for w in out['warnings']]
    assert codes == ['material-override-missing']
    assert 'Masks' in out['warnings'][0]['message']
    uses = out['texture_uses']['units/test/textures/unit_mata_normals.ddt']
    assert [(u['material'].split('#')[1], u['slot'], u['srgb']) for u in uses] == \
        [('mata', 'Normals', False), ('matb', 'Normals', False)]
    C.json_text(out)                                            # serialisable, no NaN


def test_an_xmb_material_gives_the_same_records():
    a = M.build_materials('units/test/unit.material', crlf(MATERIAL), fetcher(DEFS))
    b = M.build_materials('units/test/unit.material', xmb(MATERIAL), fetcher(DEFS))
    for rec in b['records'].values():
        assert rec['eol'] == 'xmb'
        rec['eol'] = 'crlf'
    assert a['records'] == b['records']


def test_lf_only_material_warns_that_the_game_ignores_it():
    out = M.build_materials('units/test/unit.material', MATERIAL.encode(), fetcher(DEFS))
    assert any(w['code'] == 'lf-only-runtime-xml' for w in out['warnings'])
    assert all(r['eol'] == 'lf' for r in out['records'].values())


def test_missing_materialdef_keeps_the_overrides_and_warns():
    out = M.build_materials('units/test/unit.material', crlf(MATERIAL), fetcher({'default': DEFS['default']}))
    a = out['records']['units/test/unit.material#mata']
    assert a['slots']['BaseColor']['texture'] == 'units/test/textures/unit_mata_basecolor.ddt'
    assert a['slots']['BaseColor']['srgb'] is None
    assert a['floats'] == {'AO Intensity': 0.2, 'EmissiveColor': [1.0, 0.958, 0.0, 1.0]}
    assert a['flags'] == {} and a['unknown_overrides'] == []
    missing = [w for w in out['warnings'] if w['code'] == 'file-missing']
    assert missing and missing[0]['path'] == 'render/materialdefs/default_doublesided_cutout.materialdef'


def test_overrides_the_materialdef_does_not_declare_are_kept_and_flagged():
    text = MATERIAL.replace('<float name="AO Intensity" override="0.2000" />',
                            '<float name="Not A Param" override="3" /><texture name="Glow" override="%s" />'
                            % tex('Glow'))
    out = M.build_materials('units/test/unit.material', crlf(text), fetcher(DEFS))
    a = out['records']['units/test/unit.material#mata']
    assert a['floats']['Not A Param'] == 3.0 and a['float_sources']['Not A Param'] == 'override'
    assert a['slots']['Glow']['source'] == 'override' and a['slots']['Glow']['srgb'] is None
    assert a['unknown_overrides'] == ['Glow', 'Not A Param']
    assert any(w['code'] == 'material-unknown-parameter' for w in out['warnings'])


def test_an_empty_material_has_no_records():
    out = M.build_materials('units/attachments/d_musket.material', b'<material />', fetcher(DEFS))
    assert out['empty'] and out['records'] == {} and out['texture_uses'] == {}


def test_a_broken_materialdef_is_reported_not_raised():
    out = M.build_materials('units/test/unit.material', crlf(MATERIAL),
                            fetcher({'default_doublesided_cutout': b'<materialdef', 'default': DEFS['default']}))
    codes = {w['code'] for w in out['warnings']}
    assert 'xmb-decode-failed' in codes and 'file-missing' in codes


def test_materialdefs_are_parsed_once_per_cache():
    calls = []
    base = fetcher(DEFS)

    def counting(path):
        calls.append(path)
        return base(path)
    cache = M.MaterialdefCache(counting)
    for _ in range(3):
        M.build_materials('units/test/unit.material', crlf(MATERIAL), None, cache=cache)
    assert sorted(calls) == sorted(set(calls)) and len(calls) == 2


def test_cli_prints_the_records_of_a_local_file(tmp_path, capsys, monkeypatch):
    p = tmp_path / 'unit.material'
    p.write_bytes(crlf(MATERIAL))
    monkeypatch.setattr(M, '_read_spec', lambda spec: p.read_bytes() if spec == str(p) else
                        (_ for _ in ()).throw(FileNotFoundError(spec)))
    assert M.main([str(p)]) == 0
    text = capsys.readouterr().out
    assert '"records"' in text and 'file-missing' in text


def test_vfs_adapter_returns_bytes_and_provenance():
    class VF:
        def __init__(self, data, prov):
            self.data, self.provenance = data, prov

    class FakeVFS:
        def __init__(self):
            self.calls = []

        def read(self, path, quiet=False):
            self.calls.append((path, quiet))
            return VF(DEFS['default'], 5) if path == M.materialdef_path('default') else None
    fs = FakeVFS()
    fetch = M.vfs_fetch(fs)
    assert fetch(M.materialdef_path('default')) == (DEFS['default'], 5)
    assert fetch('render/materialdefs/nope.materialdef') is None
    assert all(q is True for _, q in fs.calls)
    assert fs.calls[-2:] == [('render/materialdefs/nope.materialdef', True),
                             ('render/materialdefs/nope.materialdef.xmb', True)]   # the compiled name is retried
