"""AoE3 DE lighting inputs for the animation viewer (bundle-schema.md section 14): .lgt lighting sets, .refl
reflection cubes, .cube colour LUTs, playercolors.xml, and the 32^3 tonemap LUT baked in numpy.

    import lighting as L, av_common as C
    lgt = L.lgt_record('Tantalus Viewer', data)            # fields as read + derived shader-constant guesses
    w = C.BufferWriter('env')
    refl = L.refl_record('lighting/environments/x.refl', refl_bytes, w)
    lut = L.tonemap_lut_record(w, white_point=lgt['fields']['whitepoint'])

Status words used in every mapping (`derived[...]['status']`, record `status` blocks):
- `measured`: read from the game's data or its disassembled shaders;
- `name-match`: a lgt field and a shader constant share a name, nothing more proves the link;
- `guess`: our reading, with the rule spelled out;
- `unknown`: no source found; the value is None;
- `omitted-measured`: the game computes nothing from it for units (design section 2);
- `not-ported`: a later slice.
Calibration (design section 8 items 2-5: one RenderDoc capture or a screenshot fit) turns guesses into measured.

Formats (measured 2026-10-11 on the retail archives):
- `.lgt` (Art/lightsets/*.lgt, XMB in Art.bar; "Tantalus Viewer.lgt" is the developers' viewer set): one flat
  <lightingset> of value elements: colours "255 254 254" (0..255), floats, lists "1.0, 0.9999, 0.9999", paths,
  empty elements. 513 sets, no attributes, no nesting.
- `.refl` (Art/lighting/environments, raw in ArtLighting.bar): a 40-byte header 'REFL', u32 version 3, u32 face
  size (256 or 512), u32 mip count (6 or 7, down to 8 px), u32 format 2 (16 bytes per texel = RGBA32F by size math),
  u32 payload bytes, then 4 floats (a unit vector and a positive scalar: a dominant light direction and intensity is
  a guess). The texels are face-major (all mips of face 0, then face 1...): mip k of a face is the prefiltered
  (blurred) mip k-1, not a box filter of another face (mean levels agree per face, a box filter of the face-major
  reading has 0.19 relative error against 1.02 for the mip-major one). Face order +X -X +Y -Y +Z -Z (the D3D cube
  subresource order) is a guess; face 2 is the brightest in every file checked.
- `.cube` (Art/lighting/luts): Adobe text LUTs, LUT_3D_SIZE 64 or 25, red fastest.
- `data/playercolors.xml`: <player num color1 color2 color3 minimap/> plus friendorfoe* entries.

Tonemap LUT: a numpy port of `fxaacolorgradetonemap.hlsl BuildTonemapLUT` (cs_5_0) with every literal copied as
its float32 bit pattern (D3DDisassemble with hex literals): texel i holds c = 2*(i/32)^2 per channel; when
tonemapping is enabled it goes Rec.709 -> XYZ -> LMS -> PQ (x0.01) -> ICtCp, desaturates chroma by
smoothstep((1-I)/0.7)^1.3, applies a shoulder f(x) = x below 0.25, else 0.25 + 0.75*(1 - exp(-(x-0.25)/0.75)), 60%
on the max channel and 40% per channel, restores 30% * smoothstep((1-I)/0.5) of the chroma, returns to Rec.709 and
divides by the red channel of the same chain applied to the white point; then saturate and sRGB encode. The pixel
shader samples it at uvw = sqrt(min(c/2, 1)) * 31/32 + 1/64 (measured), i.e. it assumes c = 2*(i/31)^2: the build
and the lookup disagree slightly, as in the game.
"""
from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402
import material as MAT  # noqa: E402  (load_xml, detect_eol, warning: the shared runtime-XML reader)

LGT_ROOT = 'lightsets'
REFL_ROOT = 'lighting/environments'
LUT_ROOT = 'lighting/luts'
PLAYERCOLORS_PATH = 'data/playercolors.xml'
LUT_SIZE = 32                                   # the PS lookup constants 31/32 and 1/64 fix N = 32
REFL_HEADER = struct.Struct('<4s5I4f')          # 40 bytes
REFL_FORMATS = {2: ('rgba32f', 16)}
CUBE_FACES = ('+x', '-x', '+y', '-y', '+z', '-z')
REC709_LUMA = (0.2126, 0.7152, 0.0722)          # the weights the game's shaders use (lightingpass height fog, HISTOGRAM)
HALF_MAX = 65504.0


# ------------------------------------------------------------------------------------------------ small maths
def srgb_to_linear(c):
    """exact sRGB decode of values in 0..1 (scalar, list or numpy array)."""
    import numpy as np
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    import numpy as np
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(np.maximum(c, 0), 1 / 2.4) - 0.055)


def sun_direction(inclination_deg, rotation_deg):
    """GUESS: unit vector toward the sun, +Y up: elevation = inclination, azimuth = rotation about +Y measured from
    +Z toward +X. The lgt convention is unknown (inclination spans -72..66 degrees across the 513 vanilla sets)."""
    e, a = math.radians(inclination_deg), math.radians(rotation_deg)
    return [math.cos(e) * math.sin(a), math.sin(e), math.cos(e) * math.cos(a)]


# ------------------------------------------------------------------------------------------------ .lgt
def lgt_path(name) -> str:
    """logical path of a lighting set name: 'Tantalus Viewer' -> 'lightsets/tantalus viewer.lgt'."""
    n = C.logical_path(name)
    if not n.startswith(LGT_ROOT + '/'):
        n = '%s/%s' % (LGT_ROOT, n)
    return n if n.endswith('.lgt') else n + '.lgt'


def refl_path(skycubemap) -> str | None:
    """logical path of a lgt skycubemap ('lighting\\environments\\x' -> 'lighting/environments/x.refl')."""
    if not skycubemap:
        return None
    n = C.logical_path(skycubemap)
    return n if n.endswith('.refl') else n + '.refl'


def parse_value(text):
    """a lgt value: None (empty), int, float, a list of numbers (spaces or commas), or the text."""
    t = (text or '').strip()
    if not t:
        return None
    parts = t.replace(',', ' ').split()
    vals = []
    for p in parts:
        try:
            vals.append(int(p) if p.lstrip('+-').isdigit() else float(p))
        except ValueError:
            return t
    return vals[0] if len(vals) == 1 else vals


def parse_lgt(data) -> dict:
    """{fields: {name: value}, raw: {name: text}, order: [names], source_form, eol, extra: [...]}."""
    root, form, eol = MAT.load_xml(data)
    if root.tag != 'lightingset':
        raise ValueError('not a lighting set: <%s>' % root.tag)
    fields, raw, order, extra = {}, {}, [], []
    for el in root:
        if len(el) or el.attrib:
            extra.append(MAT.generic(el))
        text = (el.text or '').strip()
        raw[el.tag], fields[el.tag] = text, parse_value(text)
        order.append(el.tag)
    return {'fields': fields, 'raw': raw, 'order': order, 'source_form': form, 'eol': eol, 'extra': extra}


def _rgb01(v):
    return [x / 255.0 for x in v] if isinstance(v, list) and len(v) == 3 else None


def _scaled(v, s):
    return [x * s for x in v] if v is not None and isinstance(s, (int, float)) else None


def derive_constants(fields) -> dict:
    """the lgt fields mapped onto the game's shader constants (LightingConstants cb4, the tonemap Constants cb7).
    Every entry: {value, target, status, rule}; see the module docstring for the status words."""
    f = fields
    d = {}

    def put(key, value, target, status, rule, **extra):
        d[key] = dict({'value': value, 'target': target, 'status': status, 'rule': rule}, **extra)

    sc = _rgb01(f.get('suncolor'))
    sun_lin = _scaled(srgb_to_linear(sc).tolist() if sc else None, f.get('sunintensity'))
    put('sun_color', sun_lin, 'LightingConstants.sunColor', 'guess',
        'sRGB decode of suncolor/255, times sunintensity',
        alternatives={'linear_255': _scaled(sc, f.get('sunintensity'))})
    inc, rot = f.get('suninclination'), f.get('sunrotation')
    put('sun_direction', sun_direction(inc, rot) if isinstance(inc, (int, float)) and isinstance(rot, (int, float))
        else None, 'LightingConstants.sunDirection', 'guess',
        'toward the sun, +Y up: elevation suninclination, azimuth sunrotation about +Y from +Z toward +X (degrees)')
    put('shadow_color', _rgb01(f.get('shadowcolor')), 'LightingConstants.shadowColor', 'guess',
        'shadowcolor/255 (absent in 89 of 513 vanilla sets; the engine default is unknown)')
    hi = f.get('hemiintensity')
    put('hemi_top', _scaled(_rgb01(f.get('hemitopcolor')), hi), 'LightingConstants.hemiTopColor', 'guess',
        'hemitopcolor/255 times hemiintensity')
    put('hemi_bottom', _scaled(_rgb01(f.get('hemibottomcolor')), hi), 'LightingConstants.hemiBottomColor', 'guess',
        'hemibottomcolor/255 times hemiintensity')
    put('fog', {'color': _rgb01(f.get('fogcolor')), 'density': f.get('fogdensity'), 'start': f.get('fogstart')},
        'LightingConstants.fogColor/fogParams', 'guess',
        'fogcolor/255, fogdensity and fogstart as read; the design keeps fog off for an isolated unit')
    put('height_fog', {'enabled': f.get('heightfogenabled'), 'top': f.get('heightfogtop'),
                       'bottom': f.get('heightfogbottom'), 'density': f.get('heightfogdensity'),
                       'color': _rgb01(f.get('heightfogcolor'))},
        'LightingConstants.heightFogParams/heightFogColor', 'guess', 'as read')
    put('sky_cube', refl_path(f.get('skycubemap')), 'reflection cube (IBL)', 'name-match',
        'skycubemap + .refl; the file exists under Art/lighting/environments for the vanilla sets checked')
    r = f.get('skycubemaprotation')
    put('sky_cube_rotation', {'raw': r, 'sin': math.sin(r), 'cos': math.cos(r)} if isinstance(r, (int, float))
        else None, 'LightingConstants.skyCubeRotationSin/Cos', 'guess',
        'sin/cos of skycubemaprotation read as radians (skycubemapwaterrotation spans -3.14..4.01, which suggests '
        'radians; skycubemaprotation spans -7.97..30, so degrees are possible)')
    put('exposure', f.get('exposure'), 'LightingConstants.exposure and tonemap Constants.exposure', 'name-match',
        'as read')
    put('white_point', f.get('whitepoint'), 'tonemap Constants.whitePoint (BuildTonemapLUT)', 'name-match',
        'as read; the HISTOGRAM tonemap permutation clamps at a literal 11.2, the vanilla median whitepoint')
    put('tonemap_luminance', f.get('tonemapluminance'), 'tonemap Constants.luminanceBased', 'name-match',
        'unused by the BuildTonemapLUT and PSMain permutations disassembled (measured)')
    put('tonemap_influence', f.get('tonemapinfluence'), 'tonemap Constants.influence', 'name-match',
        'unused by the BuildTonemapLUT and PSMain permutations disassembled (measured)')
    put('dither_noise', f.get('dithernoiseintensity'), 'tonemap Constants.noiseIntensity', 'name-match',
        'the disassembled PSMain adds (2n-1)/256 from the noise texture at a fixed scale (measured)')
    put('mipmap_bias', f.get('mipmapbias'), 'texture LOD bias', 'guess', 'texture() bias argument (critic P2-8)')
    put('contact_shadow', f.get('contactshadowintensity'), 'LightingConstants.contactShadowIntensity',
        'omitted-measured', 'contact shadows are computed on terrain and grass only, never on units')
    put('fill', {'color': _rgb01(f.get('fillcolor')), 'intensity': f.get('fillintensity'),
                 'inclination': f.get('fillinclination'), 'rotation': f.get('fillrotation')},
        'LightingConstants.fillDirection/fillColor', 'omitted-measured',
        'no lightingpass shader reads the fill constants')
    put('lighting_balance', f.get('lightingbalance'), None, 'unknown', 'no shader constant of that name')
    for key, target in (('sky_cube_intensity', 'LightingConstants.skyCubeIntensity'),
                        ('sky_cube_normalize', 'LightingConstants.skyCubeNormalize'),
                        ('sky_cube_mip', 'LightingConstants.skyCubeMapMip')):
        put(key, None, target, 'unknown', 'no lgt field found for it')
    put('display', {'gamma': f.get('displaygamma'), 'brightness': f.get('displaybrightness')}, None, 'unknown',
        'no shader constant found')
    put('colour_grade', {k: v for k, v in f.items() if k.startswith('colorgrade')},
        'colorgrading_CSGenerateLUT inputs', 'not-ported', 'the grade LUT generator is not ported yet')
    put('bloom', {k: v for k, v in f.items() if k.startswith('bloom')}, 'bloom passes', 'not-ported', 'later slice')
    return d


def lgt_record(name, data, *, path=None, provenance=None) -> dict:
    """the bundle `lighting.lgt` record: {name, id, provenance, fields, raw, derived, source_form, eol, warnings}."""
    parsed = parse_lgt(data)
    lid = path or lgt_path(name)
    warns = []
    if parsed['eol'] == 'lf':
        warns.append(MAT.warning('lf-only-runtime-xml', lid,
                                 '%s has LF-only line endings: the game ignores it (AGENTS.md rule 1)' % lid))
    return {'name': name, 'id': lid, 'provenance': provenance, 'fields': parsed['fields'], 'raw': parsed['raw'],
            'derived': derive_constants(parsed['fields']), 'source_form': parsed['source_form'],
            'eol': parsed['eol'], 'warnings': warns}


# ------------------------------------------------------------------------------------------------ .refl
def parse_refl_header(data) -> dict:
    """{version, size, mip_count, format_code, format, texel_bytes, payload_bytes, header_floats, header_size,
    problems}; ValueError when it is not a REFL file."""
    if len(data) < REFL_HEADER.size or bytes(data[:4]) != b'REFL':
        raise ValueError('not a REFL file (magic %r)' % bytes(data[:4]))
    magic, ver, size, mips, fmt, payload, *floats = REFL_HEADER.unpack_from(data, 0)
    problems = []
    name, texel = REFL_FORMATS.get(fmt, ('format-%d' % fmt, None))
    if ver != 3:
        problems.append('version %d (3 expected)' % ver)
    if texel is None:
        problems.append('unknown texel format %d' % fmt)
    if payload != len(data) - REFL_HEADER.size:
        problems.append('payload field %d, file holds %d bytes after the header' % (payload, len(data) - 40))
    if texel:
        need = 6 * texel * sum(max(1, size >> k) ** 2 for k in range(mips))
        if need != payload:
            problems.append('%d faces x %d mips of %d px need %d bytes, payload is %d' % (6, mips, size, need, payload))
    return {'version': ver, 'size': size, 'mip_count': mips, 'format_code': fmt, 'format': name,
            'texel_bytes': texel, 'payload_bytes': payload, 'header_floats': [float(x) for x in floats],
            'header_size': REFL_HEADER.size, 'problems': problems}


def refl_levels(data):
    """[(level, size, float32 array (6, size, size, 4))] - the face-major file regrouped per mip level."""
    import numpy as np
    hdr = parse_refl_header(data)
    if hdr['problems']:
        raise ValueError('unreadable REFL: ' + '; '.join(hdr['problems']))
    size, mips = hdr['size'], hdr['mip_count']
    sizes = [max(1, size >> k) for k in range(mips)]
    per_face = sum(s * s * 4 for s in sizes)
    flat = np.frombuffer(data, '<f4', count=6 * per_face, offset=REFL_HEADER.size)
    faces = flat.reshape(6, per_face)
    out, o = [], 0
    for k, s in enumerate(sizes):
        out.append((k, s, faces[:, o:o + s * s * 4].reshape(6, s, s, 4)))
        o += s * s * 4
    return out


def refl_record(refl_id, data, writer, *, provenance=None, max_size=None, dtype='f32') -> dict:
    """the bundle `lighting.refl` record. Each kept level becomes one f32 x4 view (f16 x4 with dtype='f16', values
    clamped to the half range: the lighting packs, M3) holding the six faces in file order (face 0 rows first).
    max_size drops the levels above that face size (their level numbers stay, so the game's IBL mip rule,
    mip = (mip_count - 1) * r^(1/1.3), keeps working on `mip_count`). Every record also carries `level_stats`
    (per level: mean rgb, mean Rec.709 luminance, max) - the input of the skyCubeNormalize guess (shader_constants)."""
    import numpy as np
    if dtype not in ('f32', 'f16'):
        raise ValueError('refl views are f32 or f16, not %r' % dtype)
    hdr = parse_refl_header(data)
    rec = {'id': refl_id, 'provenance': provenance, 'size': hdr['size'], 'mip_count': hdr['mip_count'],
           'format': hdr['format'], 'decodable': not hdr['problems'], 'unavailable_reason': None,
           'layout': 'face-major in the file (measured); each view holds the six faces of one level',
           'face_order': {'value': list(CUBE_FACES), 'status': 'guess'},
           'header_floats': {'value': hdr['header_floats'], 'status': 'guess',
                             'rule': 'a unit vector and a positive scalar: dominant light direction and intensity'},
           'mips': [], 'levels_skipped': [], 'problems': hdr['problems'], 'dtype': dtype, 'level_stats': []}
    if hdr['problems']:
        rec['unavailable_reason'] = 'refl-unreadable'
        return rec
    for level, size, arr in refl_levels(data):
        rgb = arr[..., :3].astype(np.float64)
        mean = rgb.reshape(-1, 3).mean(axis=0)
        rec['level_stats'].append({'level': level, 'size': size, 'mean_rgb': [float(x) for x in mean],
                                   'mean_luminance': float(mean @ np.array(REC709_LUMA)),
                                   'max': float(rgb.max()), 'mean_alpha': float(arr[..., 3].mean())})
        if max_size and size > max_size:
            rec['levels_skipped'].append(level)
            continue
        flat = arr.reshape(-1, 4)
        if dtype == 'f16':
            flat = np.clip(flat, -HALF_MAX, HALF_MAX)
        rec['mips'].append({'level': level, 'size': size, 'view': writer.add(flat, dtype, 4)})
    return rec


# ------------------------------------------------------------------------------------------------ .cube LUTs
def parse_cube(data) -> dict:
    """{title, size, domain_min, domain_max, table: float32 (N, N, N, 3) indexed [b, g, r]} of an Adobe .cube."""
    import numpy as np
    text = data.decode('utf-8', 'replace') if isinstance(data, (bytes, bytearray)) else str(data)
    title, size, dmin, dmax, rows = None, None, [0.0, 0.0, 0.0], [1.0, 1.0, 1.0], []
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith('#'):
            continue
        key = s.split(None, 1)[0].upper()
        if key == 'TITLE':
            title = s[5:].strip().strip('"')
        elif key == 'LUT_3D_SIZE':
            size = int(s.split()[1])
        elif key == 'LUT_1D_SIZE':
            raise ValueError('1D .cube LUTs are not supported')
        elif key == 'DOMAIN_MIN':
            dmin = [float(x) for x in s.split()[1:4]]
        elif key == 'DOMAIN_MAX':
            dmax = [float(x) for x in s.split()[1:4]]
        elif key[0].isalpha():
            continue
        else:
            rows.append(s)
    if not size:
        raise ValueError('no LUT_3D_SIZE')
    vals = np.array(' '.join(rows).split(), dtype=np.float32)
    if vals.size != size ** 3 * 3:
        raise ValueError('%d values, LUT_3D_SIZE %d needs %d' % (vals.size, size, size ** 3 * 3))
    return {'title': title, 'size': size, 'domain_min': dmin, 'domain_max': dmax,
            'table': vals.reshape(size, size, size, 3)}


def grade_lut_record(lut_id, data, writer, *, provenance=None) -> dict:
    """the bundle `lighting.grade_lut` record: one f32 x4 view (rgb + 1), red fastest (the WebGL texImage3D order).
    The tonemap PS samples its colour LUT at uvw = c*(N-1)/N + 0.5/N and lerps by colorGradingEnabled (measured);
    that this .cube is what it samples, rather than a LUT colorgrading_CSGenerateLUT builds from it, is a guess."""
    import numpy as np
    cube = parse_cube(data)
    n = cube['size']
    rgba = np.concatenate([cube['table'].reshape(-1, 3), np.ones((n ** 3, 1), np.float32)], axis=1)
    return {'id': lut_id, 'provenance': provenance, 'size': n, 'view': writer.add(rgba, 'f32', 4),
            'title': cube['title'], 'domain_min': cube['domain_min'], 'domain_max': cube['domain_max'],
            'order': 'r fastest, then g, then b', 'lookup': 'uvw = c * (N - 1) / N + 0.5 / N (measured)',
            'status': {'source': 'guess'}}


# ------------------------------------------------------------------------------------------------ player colours
def _ints(text):
    v = parse_value(text)
    return v if isinstance(v, list) else None


def parse_playercolors(data) -> dict:
    """{players: [{index, color1, color2, color3, minimap}], special: {tag: {color1, ...}}} as read."""
    root, form, eol = MAT.load_xml(data)
    players, special = [], {}
    for el in root:
        entry = {k: _ints(v) for k, v in el.attrib.items() if k != 'num'}
        if el.tag == 'player':
            players.append(dict({'index': int(el.get('num'))}, **entry))
        else:
            special[el.tag] = entry
    return {'players': sorted(players, key=lambda p: p['index']), 'special': special, 'source_form': form}


def player_colors_record(data) -> list:
    """the bundle `lighting.player_colors` list: [{index, rgb, color2, color3, minimap, rgb_source}] with rgb =
    color1 in 0..255 (which of color1..3 the unit shader receives, and whether it is linearised, is unknown)."""
    out = []
    for p in parse_playercolors(data)['players']:
        out.append({'index': p['index'], 'rgb': p.get('color1'), 'color2': p.get('color2'),
                    'color3': p.get('color3'), 'minimap': p.get('minimap'), 'rgb_source': 'color1 (guess)'})
    return out


# ------------------------------------------------------------------------------------------------ tonemap LUT
def _f32(bits):
    return struct.unpack('<f', struct.pack('<I', bits))[0]


def _m(rows):
    import numpy as np
    return np.array([[_f32(b) for b in r] for r in rows], dtype=np.float32)


# literals of BuildTonemapLUT as float32 bit patterns (rows = the shader's dp3 rows)
_RGB_TO_XYZ = [[0x3ed32d7c, 0x3eb71437, 0x3e38c49c], [0x3e59c6ed, 0x3f371437, 0x3d93d07d],
               [0x3c9e6221, 0x3df41aef, 0x3f734721]]
_XYZ_TO_LMS = [[0x3eb7e910, 0x3f3295ea, 0xbd12a305], [0xbe44d014, 0x3f8cd9e8, 0x3d9a9fbe],
               [0x3be56042, 0x3d99652c, 0x3f57e910]]
_LMS_TO_ICTCP = [[0x3f000000, 0x3f000000, 0x00000000], [0x3fce8db9, 0xc054b296, 0x3fdad773],
                 [0x408c1893, 0xc087db23, 0xbe07ae14]]
_ICTCP_TO_LMS = [[0x3f800000, 0x3c0cfc99, 0x3de366a3], [0x3f800000, 0xbc0cfc99, 0xbde366a3],
                 [0x3f800000, 0x3f0f5f5d, 0xbea42a98]]
_LMS_TO_XYZ = [[0x40047dd4, 0xbfa9c957, 0x3e539326], [0x3ebadfbd, 0x3f2e331c, 0xbd3a0c29],
               [0xbd4b24b2, 0xbd4a6dd8, 0x3f981040]]
_XYZ_TO_RGB = [[0x404f639d, 0xbfc4c0f7, 0xbeff3f87], [0xbf7821d8, 0x3ff02120, 0x3d2a36b6],
               [0x3d63ea5b, 0xbe50ec27, 0x3f875327]]
K = {name: _f32(bits) for name, bits in {
    'step': 0x3d800000, 'cap': 0x40000000, 'half': 0x3f000000,                       # grid: 2*(min(i/16,2)/2)^2
    'pq_in': 0x3c23d70a, 'pq_m1': 0x3e232000, 'pq_c2': 0x4196d000, 'pq_c1': 0x3f560000,
    'pq_c3': 0x41958000, 'pq_m2': 0x429db000, 'pq_inv_m2': 0x3c4fcdac, 'pq_inv_m1': 0x40c8e06b,
    'pq_out': 0x42c80000,
    'desat_a': 0xbfb6db6e, 'desat_b': 0xc0000000, 'smooth_3': 0x40400000, 'smooth_m2': 0xc0000000,
    'desat_pow': 0x3fa66666, 'knee': 0x3e800000, 'shoulder_k': 0xbff6384f, 'shoulder_s': 0x3f400000,
    'mix': 0x3f19999a, 'restore': 0x3e99999a, 'i_min': 0x3a83126f,
    'srgb_t': 0x3b4d2e1c, 'srgb_lin': 0x414eb852, 'srgb_pow': 0x3ed55555, 'srgb_a': 0x3f870a3d,
    'srgb_b': 0xbd6147ae,
    'lookup_scale': 0x3f780000, 'lookup_bias': 0x3c800000, 'dither': 0x3b800000}.items()}


def _sat(x):
    """D3D saturate: clamp to 0..1, NaN -> 0."""
    import numpy as np
    return np.where(np.isnan(x), np.float32(0), np.clip(x, 0, 1)).astype(np.float32)


def _pq_encode(lms):
    import numpy as np
    f = np.float32
    p = np.exp2(np.log2(np.maximum(lms, f(0)) * f(K['pq_in'])) * f(K['pq_m1']))
    return np.exp2(np.log2((p * f(K['pq_c2']) + f(K['pq_c1'])) / (p * f(K['pq_c3']) + f(1))) * f(K['pq_m2']))


def _pq_decode(e):
    import numpy as np
    f = np.float32
    p = np.exp2(np.log2(np.abs(e)) * f(K['pq_inv_m2']))
    num = np.maximum(p - f(K['pq_c1']), f(0))
    den = -p * f(K['pq_c3']) + f(K['pq_c2'])
    return np.exp2(np.log2(np.abs(num / den)) * f(K['pq_inv_m1'])) * f(K['pq_out'])


def rgb_to_ictcp(rgb):
    """the shader's Rec.709 -> XYZ -> LMS -> PQ(x0.01) -> ICtCp, float32, last axis = 3."""
    import numpy as np
    rgb = np.asarray(rgb, np.float32)
    return _pq_encode(rgb @ _m(_RGB_TO_XYZ).T @ _m(_XYZ_TO_LMS).T) @ _m(_LMS_TO_ICTCP).T


def ictcp_to_rgb(ictcp):
    import numpy as np
    ictcp = np.asarray(ictcp, np.float32)
    return _pq_decode(ictcp @ _m(_ICTCP_TO_LMS).T) @ _m(_LMS_TO_XYZ).T @ _m(_XYZ_TO_RGB).T


def shoulder(x):
    """f(x) = x below 0.25, else 0.25 + 0.75 * (1 - 2^((x - 0.25) * -1.9235934)) = 0.25 + 0.75*(1 - e^-((x-0.25)/0.75))."""
    import numpy as np
    f = np.float32
    x = np.asarray(x, f)
    return np.where(x < f(K['knee']), x,
                    (f(1) - np.exp2((x - f(K['knee'])) * f(K['shoulder_k']))) * f(K['shoulder_s']) + f(K['knee']))


def _smooth(a):
    import numpy as np
    return a * a * (a * np.float32(K['smooth_m2']) + np.float32(K['smooth_3']))


def _tonemap_core(rgb):
    """the shader's tonemap chain before the white-point division (float32; NaN where the max channel is 0)."""
    import numpy as np
    f = np.float32
    ictcp = rgb_to_ictcp(rgb)
    i = ictcp[..., 0:1]
    a = _sat((i - f(1)) * f(K['desat_a']))
    b = _sat((i - f(1)) * f(K['desat_b']))
    k = np.exp2(np.log2(_smooth(a)) * f(K['desat_pow']))
    rgb1 = ictcp_to_rgb(np.concatenate([i, ictcp[..., 1:3] * k], axis=-1))
    m = np.maximum(np.maximum(rgb1[..., 2:3], rgb1[..., 1:2]), rgb1[..., 0:1])
    t_max = shoulder(m) * rgb1 / m
    t_per = shoulder(rgb1)
    t = (t_max - t_per) * f(K['mix']) + t_per
    ictcp_t = rgb_to_ictcp(t)
    restore = _smooth(b) * f(K['restore'])
    target = ictcp[..., 1:3] * ictcp_t[..., 0:1] / np.maximum(i, f(K['i_min']))
    chroma = restore * (target - ictcp_t[..., 1:3]) + ictcp_t[..., 1:3]
    return ictcp_to_rgb(np.concatenate([ictcp_t[..., 0:1], chroma], axis=-1))


def tonemap_linear(rgb, white_point):
    """the tonemapped linear colour before saturate and sRGB: core(rgb) / core(white).red."""
    import numpy as np
    with np.errstate(all='ignore'):
        core = _tonemap_core(np.asarray(rgb, np.float32))
        white = _tonemap_core(np.full(3, white_point, np.float32))
        return (core / white[0]).astype(np.float32)


def srgb_encode_shader(x):
    """the shader's sRGB encode of saturated values (threshold 0.0031308, exponent 0.41666666)."""
    import numpy as np
    f = np.float32
    x = np.asarray(x, f)
    with np.errstate(all='ignore'):
        curve = np.exp2(np.log2(x) * f(K['srgb_pow'])) * f(K['srgb_a']) + f(K['srgb_b'])
    return np.where(f(K['srgb_t']) >= x, x * f(K['srgb_lin']), curve).astype(f)


def lut_input(i):
    """the linear colour texel index i encodes: 2 * (min(i/16, 2) / 2)^2 = 2 * (i/32)^2."""
    import numpy as np
    f = np.float32
    c = np.minimum(np.asarray(i, f) * f(K['step']), f(K['cap'])) * f(K['half'])
    c = c * c
    return c + c


def lut_lookup(c):
    """the PS texture coordinate of linear colour c: sqrt(min(c/2, 1)) * 31/32 + 1/64 (measured)."""
    import numpy as np
    f = np.float32
    return np.sqrt(np.minimum(np.asarray(c, f) * f(K['half']), f(1))) * f(K['lookup_scale']) + f(K['lookup_bias'])


def bake_tonemap_lut(white_point, enabled=True):
    """float32 (32, 32, 32, 4) indexed [b, g, r]: texel (x=r, y=g, z=b) of the game's tonemap LUT (sRGB, alpha 1)."""
    import numpy as np
    c = lut_input(np.arange(LUT_SIZE))
    b, g, r = np.meshgrid(c, c, c, indexing='ij')
    rgb = np.stack([r, g, b], axis=-1)
    lin = tonemap_linear(rgb, white_point) if enabled else rgb
    out = srgb_encode_shader(_sat(lin))
    return np.concatenate([out, np.ones(out.shape[:-1] + (1,), np.float32)], axis=-1)


def tonemap_lut_record(writer, white_point, *, enabled=True, white_point_source=None) -> dict:
    """the bundle `lighting.tonemap_lut` record: {size: 32, view (f32 x4, r fastest), ...} with the build and lookup
    formulas and their status."""
    lut = bake_tonemap_lut(white_point, enabled)
    return {'size': LUT_SIZE, 'view': writer.add(lut.reshape(-1, 4), 'f32', 4), 'white_point': white_point,
            'enabled': bool(enabled), 'encoding': 'srgb', 'order': 'r fastest, then g, then b',
            'build_input': 'c(i) = 2 * (i / 32)^2', 'lookup': 'uvw = sqrt(min(c / 2, 1)) * 31/32 + 1/64',
            'after': 'grade LUT at uvw = t*(N-1)/N + 0.5/N lerped by colorGradingEnabled, then + (2n-1)/256 dither',
            'source': 'numpy port of fxaacolorgradetonemap BuildTonemapLUT; literals bit-exact',
            'status': {'formula': 'measured',
                       'enabled': 'unknown: which tonemap path the game runs (the legacy Hable shader also ships)',
                       'white_point': white_point_source or 'name-match: lgt whitepoint',
                       'storage': 'unknown: the UAV is unorm4; no 8-bit quantisation applied here'},
            'notes': ['the LUT grid is built at 2*(i/32)^2 while the lookup assumes 2*(i/31)^2 (both measured)']}


# ------------------------------------------------------------------------------------------------ M3 shader model
# references/shader-model.md describes every formula below in words and maths, with the RenderCache blob names.
SHADER_MODEL = 'v1'

# The EnvBRDF (split-sum) table of lightingpass_PSDirectIndirectLighting (RenderCache blob ..._ps_7b3db7808 and the
# forward permutation materialdefault_PSMain ..._ps_cd8fde98), re-entered as numbers from the shader's immediate
# constant buffer: entry 4 + 16*iy + 2*ix holds (scale, -, bias, -) at NdotV = iy/8 and roughness = ix/8 (row 4,
# column 0 = NdotV 0.5 on a mirror: Schlick's 1 - 0.5^5 = 0.96875 and 0.5^5 = 0.03125). The odd entries and the
# second / fourth components repeat the next row / column (room for a bilinear lookup the shaders do not use).
# Lookup (measured): ix = min(floor(saturate(roughness) * 8), 7), iy = min(floor(saturate(NdotV) * 8), 7), nearest;
# specular IBL *= F0 * scale + bias.
ENVBRDF_SCALE = (
    (0.000500, 0.208271, 0.455328, 0.621765, 0.705148, 0.727765, 0.708211, 0.660026),
    (0.487091, 0.450133, 0.437102, 0.507972, 0.580220, 0.629400, 0.631046, 0.594081),
    (0.762695, 0.730426, 0.659521, 0.607995, 0.610398, 0.612639, 0.593553, 0.548443),
    (0.904646, 0.881628, 0.814917, 0.728485, 0.667910, 0.624407, 0.577538, 0.516339),
    (0.968750, 0.953948, 0.900345, 0.819376, 0.728309, 0.648757, 0.572876, 0.491947),
    (0.992569, 0.983568, 0.946989, 0.880284, 0.782860, 0.678858, 0.575321, 0.473744),
    (0.999023, 0.994084, 0.971614, 0.918097, 0.827278, 0.709018, 0.582177, 0.459480),
    (0.999954, 0.997915, 0.985430, 0.946296, 0.864845, 0.738831, 0.591672, 0.449249),
)
ENVBRDF_BIAS = (
    (0.999393, 0.634250, 0.401866, 0.237781, 0.138327, 0.081379, 0.049152, 0.030648),
    (0.512908, 0.447820, 0.277325, 0.156997, 0.091211, 0.053868, 0.032389, 0.019776),
    (0.237305, 0.224179, 0.173509, 0.106425, 0.060852, 0.035106, 0.020591, 0.012337),
    (0.095367, 0.092897, 0.081972, 0.059136, 0.036382, 0.021313, 0.012456, 0.007357),
    (0.031250, 0.031128, 0.030422, 0.026127, 0.018554, 0.011610, 0.006962, 0.004128),
    (0.007416, 0.007536, 0.008369, 0.008907, 0.007675, 0.005464, 0.003472, 0.002118),
    (0.000977, 0.001024, 0.001463, 0.002096, 0.002368, 0.002039, 0.001450, 0.000934),
    (0.000031, 0.000035, 0.000114, 0.000282, 0.000467, 0.000517, 0.000435, 0.000315),
)

# lgt sets offered as presets in the viewer (lighting packs, build_presets). Names as in Art/lightsets.
PRESETS = (
    {'name': 'Tantalus Viewer', 'title': "the developers' viewer set (Art/lightsets/Tantalus Viewer.lgt)"},
    {'name': 'NewEngland_Skirmish', 'title': 'New England skirmish map (Art/lightsets/NewEngland_Skirmish.lgt)'},
)

# M/A/U/H per render stage of the M3 game shader (bundle.py merges this into manifest.fidelity; the page badge shows
# it). Keys shared with the M2 table replace its placeholder entries.
SHADING_FIDELITY = {
    'material': ('M', 'materialdefault BasePass maths ported: Masks remaps (AO intensity and gamma, roughness and '
                      'metallic ranges), Lift by the brightest BaseColor channel (sampled 2 mips finer), cutout at '
                      'CutoutThreshold, double-sided flip by the front-face flag (blobs d24973898, 781ce36f8); the '
                      'engine default textures of missing slots (missingnormal, missingmasks) are stand-ins'),
    'normal_map': ('M', 'tangent-space normal from stored tangents: B = sign(Tangent.w) * cross(N, T), raw UV'),
    'player_colour': ('U', 'formula measured: lerp(base, base * PC, Details.R); PC = playercolors color[k + 1] with k = '
                           'pixelxformColor (order match with the REIConstants), decoded as sRGB/255: a guess'),
    'brdf': ('M', 'lightingpass ported: GGX with alpha = max(r, 0.08)^2, Smith-Schlick k = alpha/2, Fresnel '
                  'F0 + (1 - F0) exp2((-5.55473 VdotH - 6.98316) VdotH), sun disc (cos 0.99955) representative '
                  'point, diffuse albedo(1 - metal)/pi, sun x shadow x AO'),
    'ibl': ('A', 'formulas measured (irradiance = last mip at N, specular mip (levels - 1) r^(1/1.3), sky rotation '
                 'about +Y, alpha = unshadowed share, hemi tint by N.y / R.y, shadow-colour tint, no 1/pi); refl face '
                 'order guessed; the unit bundle keeps levels up to 128 px (the lighting packs keep all)'),
    'envbrdf': ('M', '8x8 split-sum table re-entered from the shader, nearest lookup as in the game'),
    'specular_occlusion': ('M', 'saturate(pow(saturate(NdotV + AO), r) + AO - 1) x horizon(1 + 1.5 dot(Nvertex, R))'),
    'gbuffer': ('A', 'deferred storage emulated: albedo pow(1/2.2) in 8 bits, normal *0.5+0.5 in 10 bits, roughness, '
                     'AO and horizon in 8 bits (saturated); the formats are inferred from the encodings'),
    'shadows': ('A', 'one directional depth map fitted to the unit, the game kernel shape (25 bilinear soft-compare '
                     'taps / 25); resolution, bias, softness and cascades unknown'),
    'ssao': ('A', 'not computed (factor 1); the game multiplies sun and ambient by SSAO'),
    'lgt_mapping': ('U', 'lgt fields -> LightingConstants: sRGB-decoded colours x intensities, skyCubeIntensity 1, '
                         'skyCubeNormalize 1/mean luminance of the last refl mip (guesses; lighting.shader_constants)'),
    'sun_direction': ('U', 'the lgt angles read as a line, the sun at its end above the horizon (guess)'),
    'tonemap': ('U', 'which path runs is unknown: fxaacolorgradetonemap LUT (default; formula measured, '
                     'lighting.bake_tonemap_lut) or the legacy tonemap.hlsl Hable (selectable); both ship in '
                     'RenderCache.bar'),
    'colour_grade': ('A', 'the lgt custom .cube LUT at uvw = t (N-1)/N + 0.5/N (lookup measured); the generator from '
                          'the colorgrade* parameters is not ported (neutral in both presets)'),
    'dither': ('A', '(2n - 1)/256 as in the game; n from a fixed-seed 64x64 noise texture, not the game noise texture'),
    'fog': ('A', 'off: distance and height fog and terrain height shading are map-level, not applied to a lone unit'),
    'antialiasing': ('A', 'MSAA x4 (the game: TAA / FXAA)'),
}


def envbrdf_record() -> dict:
    """the bundle `lighting.envbrdf` record: the game's 8x8 split-sum table as 64 scale and 64 bias numbers."""
    return {'size': 8, 'scale': [v for row in ENVBRDF_SCALE for v in row],
            'bias': [v for row in ENVBRDF_BIAS for v in row],
            'order': 'index iy * 8 + ix; iy = NdotV bin (value at iy/8), ix = roughness bin (value at ix/8)',
            'lookup': 'ix = min(floor(saturate(roughness) * 8), 7); iy = min(floor(saturate(NdotV) * 8), 7); '
                      'nearest; F0 * scale + bias',
            'source': 'lightingpass_PSDirectIndirectLighting immediate constant buffer entries 4 + 16 iy + 2 ix',
            'status': 'measured'}


def sun_light_direction(inclination_deg, rotation_deg):
    """GUESS (M3): LightingConstants.sunDirection, the direction sunlight TRAVELS (the shader lights with
    L = -sunDirection: measured), engine frame, +Y up. The lgt angles are read as a line through the origin
    (sun_direction) and the sun sits at its end above the horizon: toward = v if v.y >= 0 else -v. Reason: 311 of 513
    vanilla sets (51 of 80 skirmish sets) have a negative inclination and are daylight maps."""
    v = sun_direction(inclination_deg, rotation_deg)
    toward = v if v[1] >= 0 else [-x for x in v]
    return [-x for x in toward]


def _srgb01(v, scale=1.0):
    return (srgb_to_linear([x / 255.0 for x in v]) * scale).tolist() if isinstance(v, list) and len(v) == 3 else None


def shader_constants(fields, refl=None) -> dict:
    """the uniforms the M3 game shader takes from a lgt (and its refl record), each {value, target, status, rule}.
    Status words as in derive_constants; 'measured-unused' = the disassembled shaders never read it. The viewer
    (viewer/shading/model.js) reads `.value` only; every value here is overridable in the page."""
    f = fields or {}
    d = {}

    def put(key, value, target, status, rule, **extra):
        d[key] = dict({'value': value, 'target': target, 'status': status, 'rule': rule}, **extra)

    def num(key, default=None):
        v = f.get(key)
        return float(v) if isinstance(v, (int, float)) else default

    inc, rot = num('suninclination'), num('sunrotation')
    put('sun_direction', sun_light_direction(inc, rot) if inc is not None and rot is not None else None,
        'LightingConstants.sunDirection (light travel direction, engine frame)', 'guess',
        'sun_light_direction(suninclination, sunrotation): the line read from the lgt angles, sun above the horizon')
    si = num('sunintensity', 1.0)
    put('sun_color', _srgb01(f.get('suncolor'), si), 'LightingConstants.sunColor', 'guess',
        'sRGB decode of suncolor/255, times sunintensity (the shader divides the diffuse by pi)',
        alternatives={'linear_255': _scaled(_rgb01(f.get('suncolor')), si)})
    sc = _srgb01(f.get('shadowcolor'))
    put('shadow_color', sc if sc is not None else [1.0, 1.0, 1.0], 'LightingConstants.shadowColor', 'guess',
        'sRGB decode of shadowcolor/255; absent in 89 vanilla sets: white (no tint) assumed',
        alternatives={'linear_255': _rgb01(f.get('shadowcolor')) or [1.0, 1.0, 1.0]})
    hi = num('hemiintensity', 1.0)
    put('hemi_top', _srgb01(f.get('hemitopcolor'), hi), 'LightingConstants.hemiTopColor', 'guess',
        'sRGB decode of hemitopcolor/255, times hemiintensity',
        alternatives={'linear_255': _scaled(_rgb01(f.get('hemitopcolor')), hi)})
    put('hemi_bottom', _srgb01(f.get('hemibottomcolor'), hi), 'LightingConstants.hemiBottomColor', 'guess',
        'sRGB decode of hemibottomcolor/255, times hemiintensity',
        alternatives={'linear_255': _scaled(_rgb01(f.get('hemibottomcolor')), hi)})
    r = num('skycubemaprotation', 0.0)
    put('sky_cube_rotation', {'sin': math.sin(r), 'cos': math.cos(r), 'raw': r},
        'LightingConstants.skyCubeRotationSin/Cos', 'guess', 'skycubemaprotation read as radians; the shader turns '
        'the lookup direction about +Y: (x cos + z sin, y, -x sin + z cos) (measured)')
    put('sky_cube_intensity', 1.0, 'LightingConstants.skyCubeIntensity', 'unknown',
        'no lgt field found: 1 (lightingbalance, unread by any shader, is a candidate)')
    norm, rule = 1.0, 'no reflection cube: 1'
    stats = (refl or {}).get('level_stats') or []
    if stats and stats[-1].get('mean_luminance'):
        norm = 1.0 / stats[-1]['mean_luminance']
        rule = ('1 / mean Rec.709 luminance of the last refl mip (level %d, %d px): the cube then averages 1 and the '
                'hemi colours set the level' % (stats[-1]['level'], stats[-1]['size']))
    put('sky_cube_normalize', norm, 'LightingConstants.skyCubeNormalize', 'guess', rule)
    put('sky_cube_mip', None, 'LightingConstants.skyCubeMapMip', 'measured-unused',
        'the lighting pass takes the mip count from the bound cube (resinfo), not from this constant')
    put('exposure', num('exposure', 1.0), 'LightingConstants.exposure (lighting output scale)', 'name-match',
        'lgt exposure; the lighting pass multiplies its output by it (measured)')
    put('white_point', num('whitepoint', 11.2), 'tonemap Constants.whitePoint (BuildTonemapLUT)', 'name-match',
        'lgt whitepoint (vanilla median 11.2)')
    put('mip_bias', num('mipmapbias', 0.0), 'material texture LOD bias (sampler DefaultWrap)', 'guess',
        'lgt mipmapbias added to every material texture lookup; the Lift lookup adds -2 more (measured)')
    custom = f.get('colorgradecustomlut')
    put('grade_enabled', 1.0 if custom else 0.0, 'tonemap Constants.colorGradingEnabled', 'guess',
        'on when the lgt names a custom .cube LUT; the LUT generator from the colorgrade* parameters is not ported')
    put('tonemap_enabled', 1.0, 'tonemap Constants.tonemappingenabled (BuildTonemapLUT)', 'unknown',
        'assumed on; the LUT path is the default, the legacy Hable path is selectable')
    put('dither_scale', 1.0 / 256.0, 'tonemap PSMain dither (2n - 1)/256', 'measured',
        'fixed in the shader; noiseIntensity is unread by that permutation')
    put('legacy_tonemap', {'luminance_based': num('tonemapluminance', 0.0), 'influence': num('tonemapinfluence', 1.0),
                           'noise': num('dithernoiseintensity', 0.0), 'exposure': 0.5,
                           'white_point': num('whitepoint', 11.2)},
        'tonemap.hlsl PSMain Constants (exposure, noiseIntensity, luminanceBased, whitePoint, influence)',
        'name-match', 'lgt tonemapluminance, tonemapinfluence, dithernoiseintensity, whitepoint; its own exposure '
        '(it scales by 2 x exposure) is unknown: 0.5 keeps the lighting output as is')
    put('fog', {'enabled': False, 'color': _srgb01(f.get('fogcolor')), 'density': num('fogdensity'),
                'start': num('fogstart')}, 'LightingConstants.fogColor/fogParams', 'omitted-measured',
        'distance fog f = x/(1+x), x = max((depth - fogstart) * fogdensity * 1e-5, 0) (forward shader); off for a '
        'lone unit')
    put('height_fog', {'enabled': False, 'lgt_enabled': f.get('heightfogenabled')},
        'LightingConstants.heightFogParams', 'omitted-measured', 'map-level; off for a lone unit')
    put('terrain_height_shading', {'enabled': False, 'intensity': num('terrainheightshadeintensity')},
        'TerrainConstants.terrainHeightShading', 'omitted-measured',
        '1 + intensity * (smoothstep(minH, maxH, y) - 0.5) multiplies every lit pixel; needs the map heights')
    put('contact_shadow', num('contactshadowintensity'), 'LightingConstants.contactShadowIntensity',
        'omitted-measured', 'the lighting pass applies contact shadows to terrain and grass classes only')
    put('fill', {'color': _rgb01(f.get('fillcolor')), 'intensity': num('fillintensity')},
        'LightingConstants.fillDirection/fillColor', 'omitted-measured', 'no lighting pass shader reads them')
    put('ssao', 1.0, 'tSSAOTexture', 'omitted-measured', 'not computed; factor 1')
    put('flat_colour', [0.0, 0.0, 0.0], 'InstanceConstants.flatColour', 'guess',
        'an additive instance colour (selection or damage flash, inferred); 0')
    return {'version': SHADER_MODEL, 'entries': d}


# ------------------------------------------------------------------------------------------------ the section
def lighting_section(lgt=None, refl=None, tonemap_lut=None, grade_lut=None, player_colors=None,
                     player_color_index=1, player_colors_special=None, shader=None) -> dict:
    """manifest['lighting'] (bundle-schema.md section 14) from the records above; missing parts stay null.
    `shader` (shader_constants) and `envbrdf` are the M3 additions (section 18)."""
    return {'lgt': lgt, 'refl': refl, 'tonemap_lut': tonemap_lut, 'grade_lut': grade_lut,
            'player_colors': player_colors, 'player_color_index': player_color_index,
            'player_colors_special': player_colors_special, 'shader': shader, 'envbrdf': envbrdf_record()}


def build_lighting(name, fetch, writer, *, player_color_index=1, refl_max_size=None, enabled=True,
                   refl_dtype='f32') -> dict:
    """the whole lighting section for lgt `name`. fetch(logical_path) -> (bytes, provenance_index) | None.
    Returns {section, warnings}; a missing input stays null and raises a `file-missing` warning."""
    warns = []

    def get(path):
        got = fetch(path) if path else None
        if got is None and path:
            warns.append(MAT.warning('file-missing', path, 'lighting input not found: %s' % path))
        return got

    lgt = refl = lut = grade = colours = special = shader = None
    got = get(lgt_path(name))
    if got:
        lgt = lgt_record(name, got[0], provenance=got[1])
        warns.extend(lgt.pop('warnings'))
        rp = lgt['derived']['sky_cube']['value']
        rg = get(rp)
        if rg:
            refl = refl_record(rp, rg[0], writer, provenance=rg[1], max_size=refl_max_size, dtype=refl_dtype)
        custom = lgt['fields'].get('colorgradecustomlut')
        if custom:
            cp = C.logical_path(custom)
            cp = cp if cp.endswith('.cube') else cp + '.cube'
            if '/' not in cp:
                cp = '%s/%s' % (LUT_ROOT, cp)
            cg = get(cp)
            if cg:
                grade = grade_lut_record(cp, cg[0], writer, provenance=cg[1])
        wp = lgt['fields'].get('whitepoint')
        if isinstance(wp, (int, float)):
            lut = tonemap_lut_record(writer, float(wp), enabled=enabled)
        shader = shader_constants(lgt['fields'], refl)
    pc = get(PLAYERCOLORS_PATH)
    if pc:
        colours = player_colors_record(pc[0])
        special = parse_playercolors(pc[0])['special']
    return {'section': lighting_section(lgt, refl, lut, grade, colours, player_color_index, special, shader),
            'warnings': warns}


# ------------------------------------------------------------------------------------------------ lighting packs
def shading_fidelity_block(viewer='m3') -> dict:
    """the fidelity block of a lighting pack: the M3 shading stages only."""
    return {'calibration': 'none', 'shader_model': SHADER_MODEL, 'viewer': viewer,
            'stages': {k: v[0] for k, v in SHADING_FIDELITY.items()},
            'notes': {k: v[1] for k, v in SHADING_FIDELITY.items()}}


def build_lighting_pack(name, *, fs=None, out_root=None, log=None, refl_dtype='f16', player_color_index=1) -> dict:
    """a lighting pack: one lgt with its full reflection cube (every level, f16 by default), tonemap and grade LUTs,
    shader constants and player colours, written as a bundle-schema v0 manifest with subject kind 'lighting'
    (bundle-schema.md section 18) under the cache root, so the server's /bundle/<id>/ route and bundle.js serve it as
    is. fs: a vfs.VFS (default: a fresh one, so the pack's provenance holds only its own files).
    Returns {name, bundle_id, folder, reused, warnings, bytes}; an unchanged pack (same inputs and content hash) is
    not rewritten."""
    import time as _time
    import vfs as V
    log = log or (lambda msg: None)
    root = C.refuse_repo_path(out_root or C.cache_root(), 'a lighting pack')
    fs = fs or V.VFS()
    w = C.BufferWriter('light')
    res = build_lighting(name, MAT.vfs_fetch(fs), w, player_color_index=player_color_index, refl_max_size=None,
                         refl_dtype=refl_dtype)
    inputs = [{'lighting_pack': name}, {'layers': fs.inputs()}, {'refl_dtype': refl_dtype},
              {'tool': C.TOOL_VERSION, 'schema': C.SCHEMA_VERSION, 'shader_model': SHADER_MODEL}]
    pid = C.cache_key(*inputs)
    prov = fs.provenance.to_json()
    content = C.sha256_bytes(C.canonical_json([[p['layer'], p['path'], p['sha256']] for p in prov]).encode('utf-8'))
    folder = root / pid
    old = folder / 'manifest.json'
    warns = res['warnings'] + [x for x in fs.warnings if x not in res['warnings']]
    out = {'name': name, 'bundle_id': pid, 'folder': str(folder), 'reused': False, 'warnings': warns,
           'bytes': len(w.data())}
    if old.is_file():
        try:
            prev = C.read_json(old)
        except (OSError, ValueError):
            prev = {}
        if prev.get('content_sha256') == content and prev.get('inputs') == json.loads(C.json_text(inputs)) \
                and (folder / 'light.bin').is_file():
            out['reused'] = True
            log('lighting pack %s (%s): unchanged, reused' % (name, pid))
            return out
    manifest = {
        'schema': C.SCHEMA_NAME, 'schema_version': C.SCHEMA_VERSION, 'bundle_id': pid,
        'created': _time.strftime('%Y-%m-%dT%H:%M:%SZ', _time.gmtime()),
        'tool': {'name': C.TOOL_NAME, 'version': C.TOOL_VERSION, 'shader_model': SHADER_MODEL, 'calibration': 'none'},
        'inputs': inputs, 'subject': {'kind': 'lighting', 'proto': None, 'animfile': None, 'lgt': name},
        'conventions': {'frame': 'gr2', 'up': '+y', 'vectors': 'row', 'matrix_order': 'row-major'},
        'buffers': [w.record()], 'layers': fs.layer_records(), 'provenance': prov, 'content_sha256': content,
        'warnings': warns, 'logic': {'types': {}, 'default': {}}, 'composition': None, 'animfiles': {},
        'models': {}, 'materials': {}, 'textures': {}, 'clips': {}, 'proto': None, 'tactics': None, 'timing': None,
        'lighting': res['section'], 'fidelity': shading_fidelity_block(), 'oracles': {'precomp': None},
    }
    C.write_bytes(folder / 'light.bin', w.data(), 'a lighting pack')
    C.write_json(folder / 'manifest.json', manifest, why='a lighting pack')
    log('lighting pack %s: %s (%.1f MB)' % (name, folder, len(w.data()) / 1e6))
    return out


def build_presets(*, fs_factory=None, out_root=None, log=None, names=None) -> list:
    """the lighting packs of PRESETS (or `names`): [{name, title, bundle_id, status, warnings}] for
    manifest.lighting.presets. status: 'ok', 'missing' (the lgt is in no layer) or 'error: <reason>'. Each pack reads
    through its own VFS (fs_factory(), default vfs.VFS())."""
    import vfs as V
    fs_factory = fs_factory or V.VFS
    titles = {p['name']: p['title'] for p in PRESETS}
    out = []
    for name in names or [p['name'] for p in PRESETS]:
        rec = {'name': name, 'title': titles.get(name, name), 'bundle_id': None, 'status': 'ok', 'warnings': []}
        try:
            got = build_lighting_pack(name, fs=fs_factory(), out_root=out_root, log=log)
        except (OSError, ValueError, LookupError) as e:          # RepoPathError is a ValueError
            rec['status'] = 'error: %s' % e
        else:
            rec['warnings'] = [x['code'] + ' ' + str(x.get('path')) for x in got['warnings']]
            if any(x['code'] == 'file-missing' and x.get('path') == lgt_path(name) for x in got['warnings']):
                rec['status'] = 'missing'
            else:
                rec['bundle_id'] = got['bundle_id']
        out.append(rec)
    return out


# ------------------------------------------------------------------------------------------------ CLI
def _read_spec(spec):
    p = Path(spec)
    if p.is_file():
        return p.read_bytes()
    bt = MAT._bartool()
    try:
        game = bt.find_game_dir()
    except SystemExit as exc:                    # bartool exits when no install is found
        raise FileNotFoundError('%s: no such local file, and no game archives (%s)' % (spec, exc)) from None
    idx = bt.build_index(game)
    key = spec.replace(chr(92), '/').lower()
    for k in (key, key + '.xmb', 'art/' + key, 'art/' + key + '.xmb'):
        if k in idx:
            return bt.read_entry(idx[k])
    raise FileNotFoundError(spec)


def main(argv=None):
    import argparse
    import numpy as np
    ap = argparse.ArgumentParser(description='Inspect AoE3 DE lighting inputs (reads local files or the game '
                                             'archives; writes nothing).')
    sub = ap.add_subparsers(dest='cmd', required=True)
    g = sub.add_parser('lgt', help='a lighting set as JSON, with the derived shader-constant guesses')
    g.add_argument('name', help="a lgt name ('Tantalus Viewer'), an archive path or a local file")
    r = sub.add_parser('refl', help='the header of a .refl reflection cube')
    r.add_argument('path')
    t = sub.add_parser('lut', help='print tonemap LUT texels along the grey axis')
    t.add_argument('--white', type=float, default=11.2)
    t.add_argument('--disabled', action='store_true')
    a = ap.parse_args(argv)
    if a.cmd == 'lgt':
        spec = a.name if Path(a.name).is_file() or '/' in a.name or chr(92) in a.name else 'art/' + lgt_path(a.name)
        rec = lgt_record(a.name, _read_spec(spec))
        sys.stdout.write(C.json_text(rec))
    elif a.cmd == 'refl':
        sys.stdout.write(C.json_text(parse_refl_header(_read_spec(a.path))))
    else:
        lut = bake_tonemap_lut(a.white, not a.disabled)
        for i in range(LUT_SIZE):
            print('%2d  c=%.5f  out=%s' % (i, float(lut_input(i)), np.round(lut[i, i, i, :3], 5).tolist()))
    return 0


if __name__ == '__main__':
    sys.exit(main())
