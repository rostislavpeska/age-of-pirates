#!/usr/bin/env python
"""Layered, read-only virtual file system of the anim viewer: the enabled mods, then the game archives.

    python vfs.py layers                                   # the lookup order of this profile
    python vfs.py find units/asians/chinese/iron_flail/iron_flail.xml [--all]
    python vfs.py cat  data/tactics/handcavalrysplash.tactics       # decoded XML on stdout (read only)

    import vfs as V
    fs = V.VFS()                                  # profile from this repository's location, game auto-detected
    f = fs.read_xml('units/asians/chinese/iron_flail/iron_flail.xml')   # VFile: .root, .layer, .eol, .provenance
    fs.layer_records(); fs.provenance.records; fs.warnings              # bundle-schema.md section 4 and 13

Layers (bundle-schema.md section 4): the enabled mods of `<profile>/mods/age3-mod-status.json`, the lower `Priority`
first (AoP has 1; the Koreans add-on is just another entry there, the sibling folder `mods/local/age-of-pirates-koreans`),
then `game` (every .bar of the install, read in place through aoe3de-bar-archives' bartool). The first layer holding a
file wins. The profile is found by walking up from this file to the folder holding `mods/age3-mod-status.json` (the
repository sits at `<profile>/mods/local/age-of-pirates`), or passed explicitly.

Paths: every call takes a logical id (`av_common.logical_path`: `units/x/y.gr2`, `data/tactics/z.tactics`) or a raw
game path (`Art\\units\\x\\y.gr2`, `units\\x\\y`). Art ids are looked up under `art/` of a mod and the archives' `Art\\`
root; ids starting with `data/`, `sound/`, `render/` or `rendercache/` keep their root. Mod folders are matched
case-insensitively, one directory listing at a time (the engine runs on Windows; CI on Linux).

Engine behaviours reproduced - and reported, never hidden (warnings, bundle-schema.md section 13):
- XML-ish files (.xml .material .materialdef .tactics .lgt .particle .composite) may have a compiled `.xmb` twin;
  inside one layer the twin wins (the engine prefers it). A twin whose tree differs from the plain file beside it
  adds `stale-xmb-twin` (content compared with xmbc.canon, never mtimes).
- A runtime XML read as plain text from a mod (animfiles and other `art/**.xml`, `sound/**.xml`, `.material`, `.lgt`,
  `.tactics`) with LF-only line endings is silently ignored by the game (AGENTS.md rule 1, measured 2026-09-17): the
  warning `lf-only-runtime-xml` is raised and the VFile is flagged `engine_ignored`. lf_policy='warn' (default) still
  returns it, so the viewer can show what the author wrote; lf_policy='engine' skips it and falls through to the next
  layer, as the engine does. Mixed line endings raise `mixed-eol-runtime-xml` (behaviour unknown, not flagged).
- A file that is nowhere raises `file-missing` (unless read quietly).

Every file read is added to the provenance table (layer, path inside the layer, sha256 of the bytes as read - before
XMB decoding -, the .bar name). Nothing is written except `materialize()`'s copies of archive files under the viewer
cache (system temp; av_common refuses a repository, an AoE3 profile or mods folder and the install).
"""
from __future__ import annotations

import argparse
import hashlib
import os
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402

BARTOOL_DIR = C.BARTOOL_DIR
MOD_STATUS = 'age3-mod-status.json'
NON_ART_ROOTS = ('data', 'sound', 'render', 'rendercache')
XMB_TWIN_EXT = ('.xml', '.material', '.materialdef', '.tactics', '.lgt', '.particle', '.composite')
LF_POLICIES = ('warn', 'engine')


def _bartool():
    """aoe3de-bar-archives' bartool (archive index, entry reader, XMB decoder) and xmbc (tree canon)."""
    if str(BARTOOL_DIR) not in sys.path:
        sys.path.insert(0, str(BARTOOL_DIR))
    import bartool
    import xmbc
    return bartool, xmbc


# ------------------------------------------------------------------------------------------------ paths
def physical(path) -> str:
    """the game-root form of a logical id or raw path: lower case, '/', with its root folder (`art/units/x.gr2`,
    `data/tactics/y.tactics`)."""
    p = C.logical_path(path)
    head = p.split('/', 1)[0]
    return p if head in NON_ART_ROOTS else 'art/' + p


def logical(path) -> str:
    return C.logical_path(path)


def ref_id(ref, ext) -> str:
    """the logical id of an animfile reference written without extension (`units\\x\\iron_rider_0` + '.gr2')."""
    p = C.logical_path(ref)
    return p if p.endswith(ext) else p + ext


def twin_able(path) -> bool:
    return physical(path).endswith(XMB_TWIN_EXT)


def is_runtime_xml(phys) -> bool:
    """the files the engine parses as plain text at run time from a mod folder (AGENTS.md rule 1)."""
    p = phys.lower()
    if p.endswith(('.material', '.lgt', '.tactics')):
        return True
    return p.endswith('.xml') and p.startswith(('art/', 'sound/'))


def eol_of(data: bytes) -> str:
    """crlf | lf | mixed | none (no line break at all)."""
    crlf = data.count(b'\r\n')
    lone = data.count(b'\n') - crlf
    if not crlf and not lone:
        return 'none'
    if not lone:
        return 'crlf'
    return 'lf' if not crlf else 'mixed'


# ------------------------------------------------------------------------------------------------ small XML helpers
def tag(el) -> str:
    return el.tag.lower() if isinstance(el.tag, str) else ''


def text(el) -> str:
    """the element's own leading text, stripped; only its first line (`<anim>Walk<assetreference>...`)."""
    t = (el.text or '').strip() if el is not None else ''
    return t.split('\n', 1)[0].strip()


def kids(el, name=None):
    """child elements, optionally only those whose tag equals `name` (case-insensitive)."""
    name = name.lower() if name else None
    return [c for c in el if isinstance(c.tag, str) and (name is None or c.tag.lower() == name)]


def kid(el, name):
    for c in kids(el, name):
        return c
    return None


def kid_text(el, name, default=None):
    c = kid(el, name)
    return text(c) if c is not None else default


def attr(el, name, default=None):
    """attribute value, the name matched case-insensitively (`mergeMode` = `mergemode`)."""
    name = name.lower()
    for k, v in el.attrib.items():
        if k.lower() == name:
            return v
    return default


def number(s, default=None):
    """float of a text value ('1.0 ' -> 1.0), int when it is integral and written without a point; else default."""
    if s is None:
        return default
    s = str(s).strip()
    try:
        return int(s)
    except ValueError:
        pass
    try:
        return float(s)
    except ValueError:
        return default


def fnum(s, default=None):
    v = number(s, None)
    return float(v) if v is not None else default


def flag(s, default=None):
    """'1'/'true' -> True, '0'/'false' -> False, else default."""
    if s is None:
        return default
    s = str(s).strip().lower()
    if s in ('1', 'true', 'yes'):
        return True
    if s in ('0', 'false', 'no'):
        return False
    return default


def record(el) -> dict:
    """one element as read: {tag, attrs, text[, children]} (tag and attribute names as written)."""
    r = {'tag': el.tag, 'attrs': dict(el.attrib), 'text': (el.text or '').strip()}
    ch = kids(el)
    if ch:
        r['children'] = [record(c) for c in ch]
    return r


def fields(el) -> list:
    """every child element as read, in file order (bundle-schema 'fields')."""
    return [record(c) for c in kids(el)]


# ------------------------------------------------------------------------------------------------ layers and stores
class ModStore:
    """a mod folder, looked up case-insensitively one directory listing at a time (cached)."""

    def __init__(self, root):
        self.root = Path(root)
        self._dirs = {}

    def _listing(self, d):
        key = str(d)
        if key not in self._dirs:
            names = {}
            try:
                with os.scandir(d) as it:
                    for e in sorted(it, key=lambda x: x.name):
                        names.setdefault(e.name.lower(), e.name)
            except OSError:
                pass
            self._dirs[key] = names
        return self._dirs[key]

    def lookup(self, phys):
        """(name as stored, relative to the mod root with '/', absolute Path) or None."""
        cur, parts = self.root, phys.lower().split('/')
        real = []
        for part in parts:
            name = self._listing(cur).get(part)
            if name is None:
                return None
            real.append(name)
            cur = cur / name
        return ('/'.join(real), cur) if cur.is_file() else None

    def read(self, local):
        return Path(local).read_bytes()


_GAME_INDEX = {}


class GameStore:
    """every .bar of the install, through bartool's index (path -> entry; a later archive wins, as in bartool)."""

    def __init__(self, game_dir):
        self.root = Path(game_dir)
        bartool, _ = _bartool()
        key = os.path.abspath(str(game_dir))
        if key not in _GAME_INDEX:
            bars = []
            for d, _dirs, files in os.walk(key):
                for f in files:
                    if f.lower().endswith('.bar'):
                        p = os.path.join(d, f)
                        st = os.stat(p)
                        bars.append((os.path.relpath(p, key).replace(os.sep, '/'), st.st_size, st.st_mtime_ns))
            _GAME_INDEX[key] = (bartool.build_index(key), sorted(bars))
        self.index, self.bars = _GAME_INDEX[key]

    def lookup(self, phys):
        e = self.index.get(phys.lower())
        return (e.name, e) if e is not None else None

    def read(self, entry):
        bartool, _ = _bartool()
        return bartool.read_entry(entry)

    def fingerprint(self):
        return C.cache_key('game', self.bars)


@dataclass
class Layer:
    id: str
    kind: str                       # 'mod' | 'game'
    title: str
    priority: int | None
    enabled: bool
    source: str
    root: Path | None = None
    store: object = None
    fingerprint: str = ''

    def record(self) -> dict:
        """the manifest's layer record (bundle-schema.md section 4)."""
        return {'id': self.id, 'kind': self.kind, 'title': self.title, 'priority': self.priority,
                'enabled': self.enabled, 'source': self.source}


@dataclass
class VFile:
    """one file as found and read in one layer."""
    path: str                        # logical id asked for
    layer: str                       # layer id
    name: str                        # the stored name inside the layer ('Art/units/.../x.xml.XMB', 'art/units/x.xml')
    form: str                        # 'xmb' | 'xml' | 'raw'
    data: bytes
    provenance: int
    container: str | None = None     # .bar file name (game layer)
    local: Path | None = None        # absolute path of a mod file
    eol: str | None = None           # 'crlf' | 'lf' | 'mixed' | 'none' | 'xmb'; None for a binary
    engine_ignored: bool = False     # LF-only runtime XML in a mod: the game would not read it
    shadowed: list = field(default_factory=list)   # layers whose copy was skipped (lf_policy='engine')
    root: object = None              # Element after read_xml
    unavailable_reason: str | None = None

    @property
    def source_form(self):
        return 'xmb' if self.form == 'xmb' else 'xml'


def find_profile(start=HERE) -> Path | None:
    """the AoE3 profile folder: the first folder at or above `start` holding mods/age3-mod-status.json."""
    for q in (Path(start), *Path(start).parents):
        if (q / 'mods' / MOD_STATUS).is_file():
            return q
    return None


def mod_layers(profile, warn=None) -> list:
    """the enabled mods of <profile>/mods/age3-mod-status.json as layers, the lower Priority first."""
    status = Path(profile) / 'mods' / MOD_STATUS
    data = C.read_json(status)
    rows = [m for m in data.get('Mods', []) if m.get('Enabled')]
    rows = sorted(enumerate(rows), key=lambda im: (im[1].get('Priority', 1 << 30), im[0]))
    layers, seen = [], set()
    for _, m in rows:
        rel = str(m.get('Path', '')).replace(chr(92), '/').strip('/')
        root = Path(profile) / 'mods' / rel
        title = m.get('Title') or Path(rel).name
        lid = 'mod:' + title
        n = 2
        while lid in seen:
            lid, n = 'mod:%s#%d' % (title, n), n + 1
        seen.add(lid)
        if not root.is_dir():
            if warn:
                warn('mod-folder-missing', rel, lid, 'enabled in %s but the folder is missing; layer skipped' % MOD_STATUS)
            continue
        layers.append(Layer(lid, 'mod', title, m.get('Priority'), True, 'mods/' + MOD_STATUS, root, ModStore(root),
                            C.cache_key('mod', title, rel, m.get('Priority'))))
    return layers


def game_layer(game_dir=None, warn=None):
    bartool, _ = _bartool()
    try:
        g = bartool.find_game_dir(str(game_dir) if game_dir else None)
    except SystemExit as e:
        if warn:
            warn('game-unavailable', None, 'game', str(e).splitlines()[0])
        return None
    store = GameStore(g)
    return Layer('game', 'game', 'game archives', None, True, 'archives', Path(g), store, store.fingerprint())


# ------------------------------------------------------------------------------------------------ the VFS
class VFS:
    """read-only layered file system (module docstring)."""

    def __init__(self, layers=None, *, profile=None, game_dir=None, include_mods=True, include_game=True,
                 lf_policy='warn', check_twins=True):
        if lf_policy not in LF_POLICIES:
            raise ValueError('lf_policy must be one of %s' % (LF_POLICIES,))
        self.lf_policy = lf_policy
        self.check_twins = check_twins
        self.warnings = []
        self._wkeys = set()
        self.provenance = C.Provenance()
        self._xml_cache = {}
        if layers is not None:
            self.layers = list(layers)
            self.profile = Path(profile) if profile else None
        else:
            self.layers = []
            self.profile = Path(profile) if profile else (find_profile() if include_mods else None)
            if include_mods:
                if self.profile is None:
                    self.warn('mods-unavailable', None, None,
                              'no AoE3 profile found above %s (mods/%s); mod layers left out' % (HERE.name, MOD_STATUS))
                else:
                    self.layers += mod_layers(self.profile, self.warn)
            if include_game:
                g = game_layer(game_dir, self.warn)
                if g is not None:
                    self.layers.append(g)

    # ---------------------------------------------------------------- bookkeeping
    def warn(self, code, path=None, layer=None, message=''):
        """append {code, path, layer, message} once (bundle-schema.md section 13)."""
        key = (code, path, layer, message)
        if key not in self._wkeys:
            self._wkeys.add(key)
            self.warnings.append({'code': code, 'path': path, 'layer': layer, 'message': message})

    def layer_records(self):
        return [lay.record() for lay in self.layers]

    def layer(self, layer_id):
        for lay in self.layers:
            if lay.id == layer_id:
                return lay
        raise KeyError(layer_id)

    def inputs(self):
        """the layer part of a bundle's cache-key inputs: [{id, kind, priority, fingerprint}]. A game fingerprint
        covers the archive list (names, sizes, mtimes); a mod's covers its status entry - file contents are covered by
        the provenance hashes."""
        return [{'id': lay.id, 'kind': lay.kind, 'priority': lay.priority, 'fingerprint': lay.fingerprint}
                for lay in self.layers]

    # ---------------------------------------------------------------- lookup
    def _candidates(self, phys):
        return [phys + '.xmb', phys] if phys.endswith(XMB_TWIN_EXT) else [phys]

    def hits(self, path, layers=None):
        """every (layer, stored name, handle, form, twin) holding `path`, in lookup order (no read)."""
        phys = physical(path)
        out = []
        for lay in (layers or self.layers):
            found = [(c, lay.store.lookup(c)) for c in self._candidates(phys)]
            found = [(c, h) for c, h in found if h is not None]
            if not found:
                continue
            cand, (name, handle) = found[0]
            form = 'xmb' if cand.endswith('.xmb') else ('xml' if phys.endswith(XMB_TWIN_EXT) else 'raw')
            twin = found[1][1] if len(found) > 1 else None
            out.append((lay, name, handle, form, twin))
        return out

    def find(self, path):
        """(layer id, stored name, form) of the winning copy, or None. Does not read the file, so it cannot apply
        lf_policy='engine' (read() does)."""
        h = self.hits(path)
        return (h[0][0].id, h[0][1], h[0][3]) if h else None

    def exists(self, path) -> bool:
        return bool(self.hits(path))

    # ---------------------------------------------------------------- reading
    def _open(self, path, hit):
        lay, name, handle, form, twin = hit
        data = lay.store.read(handle)
        container = os.path.basename(handle.bar) if lay.kind == 'game' else None
        local = handle if lay.kind == 'mod' else None
        prov = self.provenance.add(lay.id, C.logical_path(name), data=data, container=container)
        vf = VFile(logical(path), lay.id, name, form, data, prov, container, local)
        if form == 'xmb':
            vf.eol = 'xmb'
        elif form == 'xml':
            vf.eol = eol_of(data)
            if lay.kind == 'mod' and is_runtime_xml(physical(path)):
                if vf.eol == 'lf':
                    vf.engine_ignored = True
                    self.warn('lf-only-runtime-xml', vf.path, lay.id,
                              '%s has LF-only line endings: the game silently ignores it (AGENTS.md rule 1; '
                              'convert with scripts/tools/check_art_eol.py --fix)' % name)
                elif vf.eol == 'mixed':
                    self.warn('mixed-eol-runtime-xml', vf.path, lay.id,
                              '%s mixes CRLF and LF line endings; whether the game reads it is unknown '
                              '(AGENTS.md rule 1 wants CRLF)' % name)
        return vf

    def read(self, path, *, quiet=False, layers=None):
        """the winning VFile (bytes as read), or None with a `file-missing` warning (none when quiet)."""
        skipped = []
        for hit in self.hits(path, layers):
            vf = self._open(path, hit)
            if vf.engine_ignored and self.lf_policy == 'engine':
                skipped.append(vf.layer)
                continue
            vf.shadowed = skipped
            return vf
        if not quiet:
            self.warn('file-missing', logical(path), None,
                      'not found in any layer (%s)' % ', '.join(lay.id for lay in (layers or self.layers))
                      + ('; LF-only copies skipped in %s' % ', '.join(skipped) if skipped else ''))
        return None

    def read_each(self, path, *, decode_xml=True):
        """one VFile per layer holding `path` (every enabled mod's protomods, say), in lookup order; XML decoded."""
        out = []
        for lay in self.layers:
            vf = (self.read_xml if decode_xml and twin_able(path) else self.read)(path, quiet=True, layers=[lay])
            if vf is not None:
                out.append(vf)
        return out

    def read_xml(self, path, *, quiet=False, layers=None):
        """read() plus the decoded tree in .root (XMB through bartool, plain XML through ElementTree). A file that does
        not decode keeps .root None and .unavailable_reason, with a warning. Cached per layer and path."""
        key = (logical(path), tuple(lay.id for lay in layers) if layers else None)
        if key in self._xml_cache:
            return self._xml_cache[key]
        vf = self.read(path, quiet=quiet, layers=layers)
        if vf is not None:
            bartool, xmbc = _bartool()
            try:
                raw = bartool.unwrap_alz4(vf.data)
                vf.root = bartool.xmb_to_element(raw) if bartool.is_xmb(raw) else ET.fromstring(raw)
                if vf.form != 'xmb' and bartool.is_xmb(raw):
                    vf.form, vf.eol = 'xmb', 'xmb'             # an XMB stored under a plain name (the archives do it)
            except Exception as e:                              # noqa: BLE001 - reported, never raised
                vf.unavailable_reason = 'xmb-decode-failed' if vf.form == 'xmb' else 'xml-parse-failed'
                self.warn(vf.unavailable_reason, vf.path, vf.layer, '%s: %s' % (vf.name, e))
            if vf.root is not None and vf.form == 'xmb' and self.check_twins:
                self._check_twin(vf, layers)
        self._xml_cache[key] = vf
        return vf

    def _check_twin(self, vf, layers):
        """an .xmb that won over a plain file in the same layer: same tree, or `stale-xmb-twin`."""
        for lay, name, handle, form, twin in self.hits(vf.path, layers or [self.layer(vf.layer)]):
            if lay.id != vf.layer or twin is None:
                continue
            bartool, xmbc = _bartool()
            tname, thandle = twin
            tdata = lay.store.read(thandle)
            self.provenance.add(lay.id, C.logical_path(tname), data=tdata,
                                container=os.path.basename(thandle.bar) if lay.kind == 'game' else None,
                                note='plain twin beside the winning .xmb (not loaded by the engine)')
            try:
                same = xmbc.canon(ET.fromstring(tdata)) == xmbc.canon(vf.root)
            except ET.ParseError as e:
                same, why = False, 'the plain file does not parse (%s)' % e
            else:
                why = 'its tree differs from %s beside it' % tname
            if not same:
                self.warn('stale-xmb-twin', vf.path, lay.id,
                          '%s wins (the engine prefers the compiled twin) but %s: rebuild it (xmbc.py build)'
                          % (vf.name, why))
            return

    def materialize(self, path) -> Path | None:
        """a local file holding the winning copy (for readers that want a path, e.g. gr2_read): the mod file itself, or
        an archive copy under <cache>/vfs/<sha256 prefix>/<name> (never inside a repository)."""
        vf = self.read(path)
        if vf is None:
            return None
        if vf.local is not None:
            return Path(vf.local)
        sha = hashlib.sha256(vf.data).hexdigest()
        out = C.cache_root() / 'vfs' / sha[:16] / Path(vf.name.replace(chr(92), '/')).name
        if not (out.is_file() and out.stat().st_size == len(vf.data)):
            C.write_bytes(out, vf.data, 'archive copies')
        return out


# ------------------------------------------------------------------------------------------------ CLI
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--profile', help='AoE3 profile folder (default: found above this repository)')
    ap.add_argument('--game', help='...\\AoE3DE\\Game (default: bartool auto-detection or AOE3DE_GAME)')
    ap.add_argument('--lf-policy', choices=LF_POLICIES, default='warn')
    sub = ap.add_subparsers(dest='cmd', required=True)
    sub.add_parser('layers', help='print the lookup order')
    p = sub.add_parser('find', help='where a file comes from')
    p.add_argument('path')
    p.add_argument('--all', action='store_true', help='every layer holding it')
    p = sub.add_parser('cat', help='print a file (XML decoded) to stdout')
    p.add_argument('path')
    a = ap.parse_args(argv)
    fs = VFS(profile=a.profile, game_dir=a.game, lf_policy=a.lf_policy)
    if a.cmd == 'layers':
        for lay in fs.layers:
            print('%-34s %-5s priority=%-5s %s' % (lay.id, lay.kind, lay.priority, lay.root))
    elif a.cmd == 'find':
        hits = fs.hits(a.path)
        for lay, name, _h, form, twin in (hits if a.all else hits[:1]):
            print('%-34s %-4s %s%s' % (lay.id, form, name, ('  (plain twin %s)' % twin[0]) if twin else ''))
        if not hits:
            print('not found: %s' % physical(a.path))
    elif a.cmd == 'cat':
        vf = fs.read_xml(a.path) if twin_able(a.path) else fs.read(a.path)
        if vf is None:
            print('not found: %s' % physical(a.path), file=sys.stderr)
        elif vf.root is not None:
            ET.indent(vf.root, '  ')
            sys.stdout.write(ET.tostring(vf.root, encoding='unicode') + '\n')
        else:
            sys.stdout.buffer.write(vf.data)
    for w in fs.warnings:
        print('warning %s: %s %s' % (w['code'], w['path'] or '', w['message']), file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main())
