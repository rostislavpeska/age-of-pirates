"""AoE3 DE .material and .materialdef reader for the animation viewer (bundle-schema.md section 8).

    import material as M
    recs = M.build_materials('units/asians/chinese/iron_flail/iron_rider_0.material', data, fetch)
    recs['records']['units/asians/chinese/iron_flail/iron_rider_0.material#mata']['slots']['BaseColor']

A `.material` names, per submaterial, a materialdef (`render/materialdefs/<name>.materialdef`, Render.bar) and overrides
some of its parameters (texture paths, floats, vector4s). The record merges the overrides over the materialdef
defaults and says where each value came from:
- slots: every texture the materialdef declares, plus any override for a slot it does not declare (kept, flagged);
  sRGB belongs to the slot (materialdef `srgb="true"`), never to the texture;
- floats: materialdef `<float>` and `<vector4>` defaults, overridden by the submaterial's values;
- flags: the materialdef switches (defines CUTOUT, DOUBLESIDED, EMISSIVE..., cullmode, blendmode, pass).

Inputs are bytes as read from any layer: plain XML (a mod's CRLF file) or compiled XMB (the archives), optionally
inside an alz4 wrapper. `fetch(logical_path) -> (bytes, provenance_index) | None` supplies materialdefs; the
caller's virtual file system decides the layer. The game ignores an LF-only runtime XML (AGENTS.md rule 1): such a
file still parses here and raises the warning `lf-only-runtime-xml`.

Facts this module relies on (Render.bar census, 2026-10-11, 91 materialdefs, 3840 vanilla unit submaterials):
- material elements: <material>/<submaterial name>/<materialdef name>/<parameters>/<texture name override>,
  <float name override>, <vector4 name override="r, g, b, a">; an empty `<material />` exists (d_musket.material);
- materialdef: <shader file> with <define>, <permutation>, <vertexformat>, <renderpass>, <cullmode>, <blendmode>,
  <depthmode>, <stencil>, <passstate>; <parameters> with <texture default name srgb requiresoverride depthonly>,
  <float default name min max control>, <vector4 default name>; float defaults may carry a C suffix ("1.0f");
- texture references have no extension and are relative to the Art root (`units\\...\\x_mata_BaseColor` ->
  `units/.../x_mata_basecolor.ddt`); materialdef names may hold a folder (`speedtree\\nonspeedtree_subsurface`).
"""
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402

MATERIALDEF_ROOT = 'render/materialdefs'
TEXTURE_EXT = '.ddt'
# materialdef defines -> record flags (the materialdefault shader permutations; names as written in Render.bar)
DEFINE_FLAGS = {'CUTOUT': 'cutout', 'DOUBLESIDED': 'double_sided', 'EMISSIVE': 'emissive',
                'EMISSIVE_ADVANCED': 'emissive_advanced', 'COLOR_ADJUSTMENTS': 'color_adjustments',
                'ALPHATOCOVERAGE': 'alpha_to_coverage', 'ALPHA_TO_COVERAGE': 'alpha_to_coverage'}


# ------------------------------------------------------------------------------------------------ private helpers
def _bartool():
    """aoe3de-bar-archives' bartool (alz4 and XMB decoding); a missing helper of av_common, kept private here."""
    if str(C.BARTOOL_DIR) not in sys.path:
        sys.path.insert(0, str(C.BARTOOL_DIR))
    import bartool
    return bartool


def warning(code, path, message, layer=None) -> dict:
    """a bundle warning record (bundle-schema.md section 13); the caller fills `layer` when it knows it."""
    return {'code': code, 'path': path, 'layer': layer, 'message': message}


def vfs_fetch(fs, quiet=True):
    """the fetch protocol of the LOOK modules (material, ddt, lighting) over a vfs.VFS: fetch(logical_path) ->
    (bytes as read, provenance index) | None. quiet=True leaves the `file-missing` warnings to these modules, which
    raise them with their own context; the VFS still records provenance and its layer warnings.
    A miss is retried under the compiled name (`<path>.xmb`): Render.bar holds only `*.materialdef.XMB`, and
    vfs.XMB_TWIN_EXT (2026-10-11) does not list `.materialdef`, so the plain id alone finds nothing."""
    def fetch(path):
        vf = fs.read(path, quiet=quiet)
        if vf is None and not path.lower().endswith('.xmb'):
            vf = fs.read(path + '.xmb', quiet=quiet)
        return (vf.data, vf.provenance) if vf is not None else None
    return fetch


# ------------------------------------------------------------------------------------------------ runtime XML
def unwrap(data) -> bytes:
    """bytes without an alz4 wrapper (loose XMB files and some archive entries carry one)."""
    data = bytes(data)
    return _bartool().unwrap_alz4(data) if data[:4] == b'alz4' else data


def detect_eol(data) -> str:
    """`xmb` for compiled XML, else `crlf`, `lf`, `mixed` or `none` (no line break at all) for XML text."""
    data = unwrap(data)
    if data[:2] == b'X1':
        return 'xmb'
    crlf = data.count(b'\r\n')
    lf = data.count(b'\n') - crlf
    if crlf and not lf:
        return 'crlf'
    if lf and not crlf:
        return 'lf'
    return 'mixed' if crlf else 'none'


def load_xml(data):
    """(root Element, source_form 'xml' | 'xmb', eol) of runtime XML bytes (XML text, XMB, alz4-wrapped either)."""
    data = unwrap(data)
    if data[:2] == b'X1':
        return _bartool().xmb_to_element(data), 'xmb', 'xmb'
    eol = detect_eol(data)
    if data[:3] == b'\xef\xbb\xbf':
        data = data[3:]
    return ET.fromstring(data), 'xml', eol


def number(text):
    """float of a materialdef or material value ('0.0000', '1.0f', '1'); None when it is not a number."""
    if text is None:
        return None
    t = str(text).strip()
    if t[-1:] in ('f', 'F') and len(t) > 1:
        t = t[:-1]
    try:
        return float(t)
    except ValueError:
        return None


def vector(text):
    """list of floats of a vector4 value ('1, 1, 1, 1', '0,0,0.18,1'); None when a part is not a number."""
    if text is None:
        return None
    parts = [p for p in str(text).replace(',', ' ').split() if p]
    vals = [number(p) for p in parts]
    return None if not vals or any(v is None for v in vals) else vals


def bool_attr(value):
    return str(value).strip().lower() in ('1', 'true', 'yes') if value is not None else False


def generic(el) -> dict:
    """an element nothing else understands, kept whole: {tag, attrs, text, children}."""
    out = {'tag': el.tag, 'attrs': dict(el.attrib)}
    if (el.text or '').strip():
        out['text'] = el.text.strip()
    kids = [generic(c) for c in el]
    if kids:
        out['children'] = kids
    return out


# ------------------------------------------------------------------------------------------------ paths
def materialdef_path(name) -> str:
    """logical path of a materialdef name: 'default' -> 'render/materialdefs/default.materialdef'."""
    n = C.logical_path(name)
    if not n.endswith('.materialdef'):
        n += '.materialdef'
    return '%s/%s' % (MATERIALDEF_ROOT, n)


def texture_path(reference) -> str:
    """logical texture id of a material texture reference (Art-relative, no extension) -> '<...>.ddt'."""
    p = C.logical_path(reference)
    return p if p.endswith(('.ddt', '.tga', '.png', '.dds')) else p + TEXTURE_EXT


# ------------------------------------------------------------------------------------------------ materialdef
def parse_materialdef(data, name=None) -> dict:
    """a materialdef as data: {name, pass, attrs, shader, textures, floats, vectors, flags, extra, source_form, eol}.
    textures: slot -> {default, srgb, requiresoverride, depthonly, attrs}; floats: name -> {default, attrs};
    vectors: name -> {default: [4], attrs}. Unknown elements are kept in `extra` (never dropped)."""
    root, form, eol = load_xml(data)
    if root.tag != 'materialdef':
        raise ValueError('not a materialdef: <%s>' % root.tag)
    shader = {'file': None, 'defines': [], 'permutations': [], 'vertexformats': [], 'renderpasses': [],
              'states': {}, 'passstates': [], 'other': []}
    textures, floats, vectors, extra = {}, {}, {}, []
    for el in root:
        if el.tag == 'shader':
            shader['file'] = el.get('file')
            for s in el:
                n = s.get('name')
                if s.tag == 'define':
                    shader['defines'].append(n)
                elif s.tag == 'permutation':
                    shader['permutations'].append(n)
                elif s.tag == 'vertexformat':
                    shader['vertexformats'].append(n)
                elif s.tag == 'renderpass':
                    shader['renderpasses'].append(n)
                elif s.tag in ('cullmode', 'blendmode', 'depthmode', 'stencil'):
                    shader['states'][s.tag] = dict(s.attrib)
                elif s.tag == 'passstate':
                    shader['passstates'].append({'pass': s.get('pass'),
                                                 'states': {c.tag: dict(c.attrib) for c in s}})
                else:
                    shader['other'].append(generic(s))
        elif el.tag == 'parameters':
            for p in el:
                n = p.get('name')
                rest = {k: v for k, v in p.attrib.items() if k not in ('name', 'default')}
                if p.tag == 'texture':
                    textures[n] = {'default': p.get('default'), 'srgb': bool_attr(p.get('srgb')),
                                   'requiresoverride': bool_attr(p.get('requiresoverride')),
                                   'depthonly': bool_attr(p.get('depthonly')), 'attrs': rest}
                elif p.tag == 'float':
                    floats[n] = {'default': number(p.get('default')), 'attrs': rest}
                elif p.tag == 'vector4':
                    vectors[n] = {'default': vector(p.get('default')), 'attrs': rest}
                else:
                    extra.append(generic(p))
        else:
            extra.append(generic(el))
    mdef = {'name': name, 'pass': root.get('pass'), 'attrs': dict(root.attrib), 'shader': shader,
            'textures': textures, 'floats': floats, 'vectors': vectors, 'extra': extra,
            'source_form': form, 'eol': eol}
    mdef['flags'] = materialdef_flags(mdef)
    return mdef


def materialdef_flags(mdef) -> dict:
    """the switches the viewer needs, read from the materialdef: cutout, double_sided (DOUBLESIDED define or
    cullface none), emissive..., the render pass and the blend, depth and cull states as written."""
    sh = mdef.get('shader') or {}
    defines = [d for d in sh.get('defines', []) if d]
    states = sh.get('states', {})
    flags = {v: False for v in DEFINE_FLAGS.values()}
    for d in defines:
        if d.upper() in DEFINE_FLAGS:
            flags[DEFINE_FLAGS[d.upper()]] = True
    cull = (states.get('cullmode') or {}).get('cullface')
    if cull and cull.lower() == 'none':
        flags['double_sided'] = True
    flags.update({'pass': mdef.get('pass'), 'shader_file': sh.get('file'), 'defines': defines,
                  'cullface': cull, 'blendmode': states.get('blendmode'), 'depthmode': states.get('depthmode'),
                  'cutout_threshold': (mdef.get('floats', {}).get('CutoutThreshold') or {}).get('default')})
    return flags


# ------------------------------------------------------------------------------------------------ material
def parse_material(data) -> dict:
    """a .material as data: {submaterials: [{name, materialdef, textures, floats, vectors, other}], source_form,
    eol}. textures: slot -> override reference as written; floats: name -> number (or the text when not numeric);
    vectors: name -> [4]."""
    root, form, eol = load_xml(data)
    if root.tag != 'material':
        raise ValueError('not a material: <%s>' % root.tag)
    subs = []
    for sm in root:
        if sm.tag != 'submaterial':
            continue
        sub = {'name': sm.get('name'), 'materialdef': None, 'textures': {}, 'floats': {}, 'vectors': {},
               'other': []}
        for el in sm:
            if el.tag == 'materialdef':
                sub['materialdef'] = el.get('name')
            elif el.tag == 'parameters':
                for p in el:
                    n, ov = p.get('name'), p.get('override')
                    if p.tag == 'texture':
                        sub['textures'][n] = ov
                    elif p.tag == 'float':
                        v = number(ov)
                        sub['floats'][n] = v if v is not None else ov
                    elif p.tag == 'vector4':
                        v = vector(ov)
                        sub['vectors'][n] = v if v is not None else ov
                    else:
                        sub['other'].append(generic(p))
            else:
                sub['other'].append(generic(el))
        subs.append(sub)
    return {'submaterials': subs, 'source_form': form, 'eol': eol}


def material_record(material_file, sub, mdef, *, provenance=None, mdef_provenance=None, eol=None):
    """(record, warnings): one bundle material record (bundle-schema.md section 8) for submaterial `sub` of
    `material_file` (logical path) merged over the parsed materialdef `mdef` (None when the materialdef is missing).
    Extra fields beyond the schema: materialdef_path, materialdef_provenance, unknown_overrides, vectors."""
    mid = '%s#%s' % (material_file, sub['name'])
    warns = []
    slots, floats, sources, unknown = {}, {}, {}, []
    mdef_name = sub.get('materialdef')
    if mdef is None:
        warns.append(warning('file-missing', materialdef_path(mdef_name or ''),
                             'materialdef %r of %s not found: slots and floats come from the overrides only'
                             % (mdef_name, mid)))
    mtex = (mdef or {}).get('textures', {})
    for slot, decl in mtex.items():
        ov = sub['textures'].get(slot)
        if ov:
            slots[slot] = {'texture': texture_path(ov), 'srgb': decl['srgb'], 'source': 'override',
                           'unavailable_reason': None, 'reference': ov, 'default': decl['default']}
        else:
            missing = decl['requiresoverride']
            slots[slot] = {'texture': None, 'srgb': decl['srgb'], 'source': 'materialdef',
                           'unavailable_reason': 'override-missing' if missing else None,
                           'reference': None, 'default': decl['default']}
            if missing:
                warns.append(warning('material-override-missing', material_file,
                                     '%s: slot %s requires an override; the engine shows its default %r'
                                     % (mid, slot, decl['default'])))
    for slot, ov in sub['textures'].items():
        if slot in slots:
            continue
        slots[slot] = {'texture': texture_path(ov) if ov else None, 'srgb': None, 'source': 'override',
                       'unavailable_reason': None if ov else 'override-empty', 'reference': ov, 'default': None}
        if mdef is not None:
            unknown.append(slot)
    for name, decl in (mdef or {}).get('floats', {}).items():
        floats[name], sources[name] = decl['default'], 'materialdef'
    for name, decl in (mdef or {}).get('vectors', {}).items():
        floats[name], sources[name] = decl['default'], 'materialdef'
    for table in (sub['floats'], sub['vectors']):
        for name, value in table.items():
            if mdef is not None and name not in floats:
                unknown.append(name)
            floats[name], sources[name] = value, 'override'
    if unknown:
        warns.append(warning('material-unknown-parameter', material_file,
                             '%s overrides %s, which materialdef %r does not declare'
                             % (mid, ', '.join(sorted(set(unknown))), mdef_name)))
    if eol == 'lf':
        warns.append(warning('lf-only-runtime-xml', material_file,
                             '%s has LF-only line endings: the game ignores it (AGENTS.md rule 1)' % material_file))
    rec = {'id': mid, 'material_file': material_file, 'submaterial': sub['name'], 'provenance': provenance,
           'materialdef': mdef_name, 'materialdef_path': materialdef_path(mdef_name) if mdef_name else None,
           'materialdef_provenance': mdef_provenance, 'slots': slots, 'floats': floats, 'float_sources': sources,
           'flags': dict((mdef or {}).get('flags') or {}), 'eol': eol, 'unknown_overrides': sorted(set(unknown))}
    return rec, warns


class MaterialdefCache:
    """parses each materialdef once per bundle. fetch(logical_path) -> (bytes, provenance_index) | None."""

    def __init__(self, fetch):
        self.fetch = fetch
        self._parsed = {}

    def get(self, name):
        """(parsed materialdef or None, provenance index or None, warnings)."""
        path = materialdef_path(name)
        if path not in self._parsed:
            got = self.fetch(path) if name else None
            if got is None:
                self._parsed[path] = (None, None, [])
            else:
                data, prov = got
                try:
                    self._parsed[path] = (parse_materialdef(data, name), prov, [])
                except (ET.ParseError, ValueError) as exc:
                    self._parsed[path] = (None, prov, [warning('xmb-decode-failed', path,
                                                               'materialdef unreadable: %s' % exc)])
        return self._parsed[path]


def build_materials(material_file, data, fetch, *, provenance=None, cache=None) -> dict:
    """every submaterial of one .material as bundle records.
    material_file: logical path (`units/.../iron_rider_0.material`); data: its bytes; fetch: materialdef reader
    (MaterialdefCache protocol). Returns {records: {material id: record}, texture_uses: {texture id: [{material,
    slot, srgb}]}, warnings: [...], empty: bool}. A texture used by an sRGB slot and a linear slot appears with both
    uses, so the viewer uploads it twice (bundle-schema.md section 8)."""
    cache = cache or MaterialdefCache(fetch)
    parsed = parse_material(data)
    out = {'records': {}, 'texture_uses': {}, 'warnings': [], 'empty': not parsed['submaterials'],
           'eol': parsed['eol'], 'source_form': parsed['source_form']}
    if parsed['eol'] == 'lf' and not parsed['submaterials']:
        out['warnings'].append(warning('lf-only-runtime-xml', material_file,
                                       '%s has LF-only line endings: the game ignores it (AGENTS.md rule 1)'
                                       % material_file))
    for sub in parsed['submaterials']:
        mdef, mprov, mwarn = cache.get(sub.get('materialdef'))
        out['warnings'].extend(mwarn)
        rec, warns = material_record(material_file, sub, mdef, provenance=provenance, mdef_provenance=mprov,
                                     eol=parsed['eol'])
        out['records'][rec['id']] = rec
        out['warnings'].extend(warns)
        for slot, s in rec['slots'].items():
            if s['texture']:
                out['texture_uses'].setdefault(s['texture'], []).append(
                    {'material': rec['id'], 'slot': slot, 'srgb': s['srgb']})
    seen, uniq = set(), []
    for w in out['warnings']:
        key = (w['code'], w['path'], w['message'])
        if key not in seen:
            seen.add(key)
            uniq.append(w)
    out['warnings'] = uniq
    return out


# ------------------------------------------------------------------------------------------------ CLI
def _read_spec(spec):
    """bytes of a local file, or of a game archive path ('art/...', 'render/...'; the .xmb twin is tried)."""
    p = Path(spec)
    if p.is_file():
        return p.read_bytes()
    bt = _bartool()
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
    ap = argparse.ArgumentParser(description='Print a .material merged over its materialdefs as bundle JSON '
                                             '(reads a local file or the game archives; writes nothing).')
    ap.add_argument('material', help='a local .material file or an archive path such as '
                                     'art/units/asians/chinese/iron_flail/iron_rider_0.material')
    a = ap.parse_args(argv)
    data = _read_spec(a.material)

    def fetch(path):
        try:
            return _read_spec(path), None
        except FileNotFoundError:
            return None
    out = build_materials(C.logical_path(a.material), data, fetch)
    sys.stdout.write(C.json_text(out))
    return 0


if __name__ == '__main__':
    sys.exit(main())
