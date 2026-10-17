"""Synthetic game installs and AoE3 profiles for the data-module tests (no game bytes, CI-safe).

    g = av_fixtures.Game(tmp_path / 'game')
    g.add('Art', 'units/x/x.xml', '<animfile>...</animfile>', xmb=True)      # stored as units/x/x.xml.XMB, alz4
    g.write()                                                               # one ESPN v6 .bar per root
    p = av_fixtures.Profile(tmp_path / 'profile')
    m = p.mod('age-of-pirates', priority=1)                                 # mods/local/age-of-pirates
    m.write('art/units/x/x.xml', text, eol='crlf')
    p.write()                                                               # mods/age3-mod-status.json

The .bar layout is the one aoe3de-bar-archives' bartool reads (header 'ESPN', version 6, entry count and table
offset at 0x118, a table of {u64 offset, u32 raw, u32 stored, u32 stored2, u32 name length, utf-16 name, u32 flag}).
Compressed entries are alz4 around an LZ4 block made of literals only (valid LZ4; no lz4 package needed). XMB is
compiled with aoe3de-bar-archives' xmbc.Compiler.
"""
from __future__ import annotations

import json
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
BARTOOL_DIR = HERE.parents[1] / 'aoe3de-bar-archives' / 'scripts'
if str(BARTOOL_DIR) not in sys.path:
    sys.path.insert(0, str(BARTOOL_DIR))
import xmbc  # noqa: E402


def lz4_literals(data: bytes) -> bytes:
    """one LZ4 block holding `data` as a single literal run (the last sequence of a block has no match)."""
    n = len(data)
    if n < 15:
        return bytes([n << 4]) + data
    rest = n - 15
    return bytes([0xF0]) + b'\xff' * (rest // 255) + bytes([rest % 255]) + data


def alz4(data: bytes) -> bytes:
    comp = lz4_literals(data)
    return b'alz4' + struct.pack('<III', len(data), len(comp), 1) + comp


def to_xmb(xml_text) -> bytes:
    """XMB bytes (X1/XR v4) of an XML text, compiled by xmbc."""
    root = ET.fromstring(xml_text)
    return xmbc.Compiler(root).payload(root)


def crlf(text) -> bytes:
    return text.replace('\r\n', '\n').replace('\n', '\r\n').encode('utf-8')


def lf(text) -> bytes:
    return text.replace('\r\n', '\n').encode('utf-8')


def write_bar(path, root, files):
    """files: [(name relative to root with '\\', bytes, compress)]."""
    body = bytearray(0x130)
    body[0:4] = b'ESPN'
    struct.pack_into('<I', body, 4, 6)
    entries = []
    for name, data, comp in files:
        stored = alz4(data) if comp else data
        entries.append((len(body), len(data), len(stored), name))
        body += stored
    table_off = len(body)
    t = struct.pack('<I', len(root)) + root.encode('utf-16-le') + struct.pack('<I', len(entries))
    for off, raw, stored, name in entries:
        t += struct.pack('<QIIII', off, raw, stored, stored, len(name)) + name.encode('utf-16-le')
        t += struct.pack('<I', 1 if raw != stored else 0)
    struct.pack_into('<QQ', body, 0x118, len(entries), table_off)
    body += t
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(bytes(body))


class Game:
    """a fake AoE3DE Game folder: Data/ exists (bartool.find_game_dir wants it); one .bar per root."""

    def __init__(self, folder):
        self.folder = Path(folder)
        self.files = {}

    def add(self, root, rel, content, xmb=False, compress=True, bar=None):
        """root 'Art' | 'Data' | 'Sound'; rel with '/'; content str or bytes; xmb=True stores '<rel>.XMB' compiled."""
        data = content.encode('utf-8') if isinstance(content, str) else content
        name = rel
        if xmb:
            data, name = to_xmb(content if isinstance(content, str) else content.decode('utf-8')), rel + '.XMB'
        key = bar or ('%s.bar' % root)
        self.files.setdefault((key, root), []).append((name.replace('/', chr(92)), data, compress))
        return self

    def write(self):
        (self.folder / 'Data').mkdir(parents=True, exist_ok=True)
        for (bar, root), files in self.files.items():
            write_bar(self.folder / bar, root + chr(92), files)
        return self.folder


class Mod:
    def __init__(self, folder, title, priority, enabled, rel):
        self.folder, self.title, self.priority, self.enabled, self.rel = Path(folder), title, priority, enabled, rel

    def write(self, rel, content, eol='crlf'):
        p = self.folder / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, bytes):
            p.write_bytes(content)
        else:
            p.write_bytes(crlf(content) if eol == 'crlf' else lf(content))
        return p


class Profile:
    """a fake AoE3 profile: mods/age3-mod-status.json plus mods/local/<title> folders."""

    def __init__(self, folder):
        self.folder = Path(folder)
        self.mods = []

    def mod(self, title, priority, enabled=True, create=True):
        rel = 'local' + chr(92) + title
        m = Mod(self.folder / 'mods' / 'local' / title, title, priority, enabled, rel)
        if create:
            m.folder.mkdir(parents=True, exist_ok=True)
        self.mods.append(m)
        return m

    def write(self):
        rows = [{'Title': m.title, 'Author': '', 'Description': '', 'Path': m.rel, 'WorkshopID': 0,
                 'Priority': m.priority, 'Enabled': m.enabled} for m in self.mods]
        (self.folder / 'mods').mkdir(parents=True, exist_ok=True)
        (self.folder / 'mods' / 'age3-mod-status.json').write_text(json.dumps({'Actions': [], 'Mods': rows}),
                                                                   encoding='utf-8')
        return self.folder
