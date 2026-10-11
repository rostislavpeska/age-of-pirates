"""Shared helpers of the aoe3de-anim-viewer backend (standard library; numpy only for BufferWriter / read_view).

    import av_common as C
    C.refuse_repo_path(p)          # RepoPathError when p lies in a git work tree, an AoE3 profile/mods folder or the install
    d = C.cache_dir('bundle', 'ypIronFlail', layers_hash)   # %TEMP%/aop-anim-viewer/<16 hex>, created
    prov = C.Provenance(); i = prov.add('game:ArtUnits.bar', 'units/asians/chinese/iron_flail/iron_rider_0.gr2', data=b)
    C.write_json(d / 'manifest.json', manifest)                # atomic, refuses protected folders

Everything this tool writes - bundle caches, vanilla-derived buffers, PNG exports, logs, browser profiles - lives under
cache_root() (default `<system temp>/aop-anim-viewer`, override AOP_ANIM_VIEWER_CACHE) or an explicit output folder, and
every write goes through refuse_repo_path first (AGENTS.md rules 3 and 8: no vanilla extraction and no image in a
repository; the game and the mods are read-only). The bundle format these helpers serve is references/bundle-schema.md.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKILL_DIR = HERE.parent
VIEWER_DIR = SKILL_DIR / 'viewer'
BARTOOL_DIR = HERE.parents[1] / 'aoe3de-bar-archives' / 'scripts'

TOOL_NAME = 'aoe3de-anim-viewer'
TOOL_VERSION = '0.1.0'
SCHEMA_NAME = 'aop-anim-viewer/bundle'
SCHEMA_VERSION = 0
CACHE_ENV = 'AOP_ANIM_VIEWER_CACHE'
CACHE_DIRNAME = 'aop-anim-viewer'
BUFFER_ALIGN = 16                       # every buffer view starts on a 16-byte boundary (bundle-schema.md section 3)

# (marker, test, label): a folder holding the marker is protected, and so is everything below it
PROTECTED_MARKERS = (
    ('.git', 'exists', 'git work tree'),
    ('age3-mod-status.json', 'file', 'AoE3 mods folder'),
    ('mods/age3-mod-status.json', 'file', 'AoE3 profile folder'),
    ('AoE3DE_s.exe', 'file', 'AoE3 DE install'),
)


class RepoPathError(ValueError):
    """a write target inside a protected folder (git work tree, AoE3 profile or mods folder, AoE3 install)."""


# ------------------------------------------------------------------------------------------------ protected folders
def _bartool_git_root():
    """aoe3de-bar-archives' bartool.git_root (the same check its extract command enforces), or None when absent."""
    if not (BARTOOL_DIR / 'bartool.py').is_file():
        return None
    sys.path.insert(0, str(BARTOOL_DIR))
    try:
        import bartool
        return bartool.git_root
    except ImportError:
        return None
    finally:
        sys.path.remove(str(BARTOOL_DIR))


_GIT_ROOT = _bartool_git_root()


def git_root(path) -> Path | None:
    """the git work tree that contains `path` (bartool's walk up to a `.git` entry), else None."""
    if _GIT_ROOT is not None:
        r = _GIT_ROOT(str(path))
        return Path(r) if r else None
    p = Path(os.path.abspath(path))
    for q in (p, *p.parents):
        if (q / '.git').exists():
            return q
    return None


def protected_owner(path) -> tuple[Path, str] | None:
    """(folder, label) of the first protected folder at or above `path` (absolute and resolved forms), else None."""
    seen = []
    for form in (Path(os.path.abspath(path)), Path(path).resolve()):
        if form in seen:
            continue
        seen.append(form)
        for q in (form, *form.parents):
            for marker, test, label in PROTECTED_MARKERS:
                m = q / marker
                if (m.exists() if test == 'exists' else m.is_file()):
                    return q, label
    return None


def is_repo_path(path) -> bool:
    return protected_owner(path) is not None


def refuse_repo_path(path, why='viewer output') -> Path:
    """the absolute path, or RepoPathError when it lies in a git work tree, an AoE3 profile or mods folder, or the AoE3
    install. Every write of this tool calls it first; the game and the mods stay read-only, repositories image-free."""
    hit = protected_owner(path)
    if hit:
        folder, label = hit
        raise RepoPathError('refusing to write %s into a %s (%s): %s - use the cache (%s) or a scratch folder'
                            % (why, label, folder, Path(os.path.abspath(path)), cache_root(create=False)))
    return Path(os.path.abspath(path))


# ------------------------------------------------------------------------------------------------ cache and outputs
def cache_root(create=True) -> Path:
    """AOP_ANIM_VIEWER_CACHE, else <system temp>/aop-anim-viewer; refused when protected."""
    root = Path(os.environ.get(CACHE_ENV) or (Path(tempfile.gettempdir()) / CACHE_DIRNAME))
    if create:
        refuse_repo_path(root, 'the viewer cache')
        root.mkdir(parents=True, exist_ok=True)
    return Path(os.path.abspath(root))


def canonical_json(obj) -> str:
    """deterministic JSON text (sorted keys, no spaces) - the input of cache keys and content hashes."""
    return json.dumps(obj, sort_keys=True, separators=(',', ':'), ensure_ascii=False, default=str)


def cache_key(*parts) -> str:
    """16 hex digits of sha256 over the canonical JSON of `parts` (strings, numbers, lists, dicts, paths)."""
    return hashlib.sha256(canonical_json([str(p) if isinstance(p, Path) else p for p in parts]).encode('utf-8')
                          ).hexdigest()[:16]


def cache_dir(*parts, create=True) -> Path:
    """cache_root()/<cache_key(*parts)>: one folder per bundle input set (bundle_id = that key)."""
    d = cache_root(create=create) / cache_key(*parts)
    if create:
        d.mkdir(parents=True, exist_ok=True)
    return d


def output_dir(path=None, label='out') -> Path:
    """an export folder: `path` when given, else cache_root()/out/<label>-<YYYYmmdd-HHMMSS>; refused when protected,
    created. PNGs, sheets and their JSON sidecars go only here (AGENTS.md rule 8)."""
    if path is None:
        path = cache_root() / 'out' / ('%s-%s' % (safe_stem(label), time.strftime('%Y%m%d-%H%M%S')))
    p = refuse_repo_path(path, 'exports')
    p.mkdir(parents=True, exist_ok=True)
    return p


_SAFE = re.compile(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$')


def safe_stem(label) -> str:
    """a folder-name fragment: letters, digits, '_' and '-' only."""
    s = re.sub(r'[^A-Za-z0-9_-]+', '_', str(label)).strip('_-') or 'out'
    return s[:64]


def safe_name(name, allowed_ext=('.png', '.json', '.txt')) -> str:
    """a bare file name for a server-side write: letters, digits, '.', '_', '-', no separators or '..', an allowed
    extension; ValueError otherwise."""
    name = str(name)
    if not _SAFE.match(name) or '..' in name:
        raise ValueError('unsafe file name: %r' % name)
    if allowed_ext and not name.lower().endswith(tuple(e.lower() for e in allowed_ext)):
        raise ValueError('file type not allowed: %r (allowed: %s)' % (name, ', '.join(allowed_ext)))
    return name


# ------------------------------------------------------------------------------------------------ hashing and provenance
def sha256_bytes(data) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path, chunk=1 << 20) -> str:
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(chunk), b''):
            h.update(block)
    return h.hexdigest()


def logical_path(path) -> str:
    """the bundle's id form of a game path: forward slashes, lower case, no leading slash or `art/` root
    (`Art\\units\\X.gr2` -> `units/x.gr2`). Animfile references (`units\\asians\\...\\iron_rider_0`) map the same way."""
    p = str(path).replace(chr(92), '/').strip().lstrip('/').lower()
    while '//' in p:
        p = p.replace('//', '/')
    return p[4:] if p.startswith('art/') else p


def provenance_record(layer, path, *, data=None, file=None, sha256=None, size=None, container=None, note=None) -> dict:
    """{layer, path, sha256, size, container, note} for one source file (bundle-schema.md section 4).
    layer: 'mod:<mod folder title>' | 'game' | 'synthetic' | 'tool'; path: the file's logical path inside that layer;
    container: the .bar archive name for the game layer, else None. The hash comes from `data`, `file` or `sha256`."""
    if data is not None:
        sha256, size = sha256_bytes(data), len(data)
    elif file is not None:
        sha256, size = sha256_file(file), Path(file).stat().st_size
    if not sha256:
        raise ValueError('provenance_record needs data, file or sha256')
    return {'layer': str(layer), 'path': str(path), 'sha256': sha256, 'size': size, 'container': container,
            'note': note}


class Provenance:
    """the bundle's provenance table: add() returns the record's index (records with the same layer, path and hash are
    stored once), records is the list written to manifest['provenance']."""

    def __init__(self):
        self.records = []
        self._index = {}

    def add(self, layer, path, **kw) -> int:
        rec = provenance_record(layer, path, **kw)
        key = (rec['layer'], rec['path'], rec['sha256'])
        if key not in self._index:
            self._index[key] = len(self.records)
            self.records.append(rec)
        return self._index[key]

    def to_json(self):
        return list(self.records)


# ------------------------------------------------------------------------------------------------ writing
def write_bytes(path, data, why='viewer output') -> Path:
    """atomic write (temporary sibling, then os.replace) after refuse_repo_path; the bytes exist before the target is
    touched, so a failure never leaves a truncated file."""
    p = refuse_repo_path(path, why)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_name('.%s.%d.tmp' % (p.name, os.getpid()))
    with open(tmp, 'wb') as f:
        f.write(data)
    os.replace(tmp, p)
    return p


def json_text(obj, indent=1) -> str:
    return json.dumps(obj, indent=indent, ensure_ascii=False, allow_nan=False, default=_json_default) + '\n'


def _json_default(o):
    if isinstance(o, Path):
        return str(o)
    tolist = getattr(o, 'tolist', None)                 # numpy scalars and arrays
    if tolist is not None:
        return tolist()
    raise TypeError('not JSON serialisable: %r' % type(o))


def write_json(path, obj, indent=1, why='viewer output') -> Path:
    """UTF-8 JSON, LF, NaN refused; the text is built completely before the atomic write."""
    return write_bytes(path, json_text(obj, indent).encode('utf-8'), why)


def read_json(path):
    with open(path, encoding='utf-8-sig') as f:
        return json.load(f)


# ------------------------------------------------------------------------------------------------ binary buffers
# dtype names of bundle-schema.md section 3 -> numpy little-endian codes and JS typed arrays
DTYPES = {'f32': '<f4', 'f16': '<f2', 'u8': 'u1', 'i8': 'i1', 'u16': '<u2', 'i16': '<i2', 'u32': '<u4', 'i32': '<i4'}


class BufferWriter:
    """one binary buffer of the bundle: add() appends an array at the next 16-byte boundary and returns its view record
    {buffer, byteOffset, byteLength, dtype, count, components, normalized}; data() returns the bytes."""

    def __init__(self, buffer_id):
        self.id = buffer_id
        self._parts = []
        self._size = 0

    def add(self, array, dtype, components=1, normalized=False) -> dict:
        import numpy as np
        if dtype not in DTYPES:
            raise ValueError('unknown dtype %r (one of %s)' % (dtype, ', '.join(DTYPES)))
        a = np.ascontiguousarray(np.asarray(array).astype(DTYPES[dtype], copy=False))
        if a.size % components:
            raise ValueError('%d values do not split into %d components' % (a.size, components))
        pad = (-self._size) % BUFFER_ALIGN
        if pad:
            self._parts.append(b'\0' * pad)
            self._size += pad
        raw = a.tobytes()
        view = {'buffer': self.id, 'byteOffset': self._size, 'byteLength': len(raw), 'dtype': dtype,
                'count': a.size // components, 'components': components, 'normalized': bool(normalized)}
        self._parts.append(raw)
        self._size += len(raw)
        return view

    def data(self) -> bytes:
        return b''.join(self._parts)

    def record(self, uri=None) -> dict:
        """the manifest['buffers'] entry of this buffer (after the last add)."""
        d = self.data()
        return {'id': self.id, 'uri': uri or (self.id + '.bin'), 'byteLength': len(d), 'sha256': sha256_bytes(d)}


def read_view(buf, view):
    """numpy array (count, components) - or (count,) for one component - of a view inside `buf` (bytes)."""
    import numpy as np
    a = np.frombuffer(buf, dtype=DTYPES[view['dtype']], count=view['count'] * view['components'],
                      offset=view['byteOffset'])
    return a.reshape(view['count'], view['components']) if view['components'] > 1 else a


# ------------------------------------------------------------------------------------------------ local tool paths
def find_tool_config(start=HERE) -> Path | None:
    """the consumer's ignored config/tool-paths.local.json, found by walking up from `start`, else None."""
    for q in (Path(start), *Path(start).parents):
        c = q / 'config' / 'tool-paths.local.json'
        if c.is_file():
            return c
    return None


def local_tool_path(tool_id, config=None) -> str | None:
    """tools.<tool_id>.path of the device's tool-paths config (schema: skill-library-audit
    assets/tool-paths.example.json); None when unset or there is no config."""
    config = Path(config) if config else find_tool_config()
    if not config or not config.is_file():
        return None
    try:
        tools = read_json(config).get('tools', {})
    except (OSError, ValueError):
        return None
    item = tools.get(tool_id)
    value = item.get('path') if isinstance(item, dict) else item
    return value or None
