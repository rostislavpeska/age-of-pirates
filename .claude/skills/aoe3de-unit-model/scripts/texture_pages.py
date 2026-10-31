#!/usr/bin/env python
"""Texture pages of unit models (read-only): DDT headers, .material pages with archive sizes, Details coverage.

    python texture_pages.py ddt FILE.ddt|FOLDER [...] [--archive REL ...]
    python texture_pages.py material FILE.material[.XMB] [...] [--archive REL ...]
    python texture_pages.py details FILE_Details.ddt [...] [--archive REL ...]
    python texture_pages.py gr2 FILE.gr2 [...]          # textures named inside the gr2 (legacy LP files)

ddt: width x height, format byte, mip count, bytes (RTS3 header; archive entries are read in memory).
material: per submaterial the materialdef and each map's page size from the game archive's DDT header (consumer's
  gr2_lint.read_material / vanilla_texture), plus variant names.
details: top mip of a DXT1 (format 4/5) page decoded with the consumer's ddt_read: share of texels with R > 200 and
  R > 25 (player-colour weight), mean G and B and their share above 25.
Backs materials-textures.md sections 2 and 4 and lod-lowpoly.md section 3.
"""
import argparse
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import unit_gr2 as U  # noqa: E402


def ddt_header(data):
    if data[:4] == b'alz4':
        bt, _ = U.game_index()
        data = bt.unwrap_alz4(data)
    if data[:4] != b'RTS3':
        return None
    usage, alpha, fmt, mips = data[4], data[5], data[6], data[7]
    w, h = struct.unpack_from('<II', data, 8)
    return dict(W=w, H=h, format=fmt, mips=mips, usage=usage, alpha=alpha)


def inputs(a, suffixes):
    paths = []
    for f in a.files:
        p = Path(f)
        if p.is_dir():
            paths += sorted(x for x in p.rglob('*') if x.suffix.lower() in suffixes or x.name.lower().endswith(suffixes))
        else:
            paths.append(p)
    if a.archive:
        paths += U.fetch(a.archive, a.extract_to)
    if not paths:
        raise SystemExit('no input')
    return paths


def cmd_ddt(a):
    for p in inputs(a, ('.ddt',)):
        b = p.read_bytes()
        h = ddt_header(b)
        print('%s: %s' % (p.name, ('%d x %d fmt %d mips %d usage %d alpha %d, %d bytes' % (
            h['W'], h['H'], h['format'], h['mips'], h['usage'], h['alpha'], len(b))) if h else 'not RTS3'))


def cmd_material(a):
    import gr2_lint
    for p in inputs(a, ('.material', '.material.xmb')):
        for s in gr2_lint.read_material(p):
            maps = []
            for k, v in s['textures'].items():
                t = gr2_lint.vanilla_texture(v.replace(chr(92), '/'))
                maps.append('%s=%sx%s' % (k, t['W'] if t else '?', t['H'] if t else '?'))
            var = sorted({x for _, _, x in s['all_textures'] if x != '0'})
            print('%s [%s] %s %s%s | %s' % (p.name, s['name'], s['shader'], ' '.join(maps),
                                           (' variants %s' % var) if var else '',
                                           ' '.join(sorted({v.split(chr(92))[-1] for v in s['textures'].values()}))))


def cmd_details(a):
    from ddt_read import decode_dxt1
    for p in inputs(a, ('.ddt',)):
        b = p.read_bytes()
        if b[:4] == b'alz4':
            bt, _ = U.game_index()
            b = bt.unwrap_alz4(b)
        h = ddt_header(b)
        if not h or h['format'] not in (4, 5):
            print('%s: SKIP (%s)' % (p.name, 'format %d' % h['format'] if h else 'not RTS3'))
            continue
        off, ln = struct.unpack('<II', b[16:24])
        img = np.asarray(decode_dxt1(b[off:off + ln], h['W'], h['H'])).astype(np.int32)
        r, g, bb = img[..., 0], img[..., 1], img[..., 2]
        n = float(r.size)
        print('%-40s %4dx%-4d fmt %d  R>200 %5.1f%%  R>25 %5.1f%%  meanG %5.1f meanB %5.1f  G>25 %5.1f%% B>25 %5.1f%%' % (
            p.name, h['W'], h['H'], h['format'], 100 * (r > 200).sum() / n, 100 * (r > 25).sum() / n, g.mean(), bb.mean(),
            100 * (g > 25).sum() / n, 100 * (bb > 25).sum() / n))


def cmd_gr2(a):
    for p in inputs(a, ('.gr2',)):
        try:
            m = U.Model(p)
        except U.Unreadable as e:
            print('%s: UNREADABLE %s' % (p.stem, e))
            continue
        tex = ['%s(%sx%s)' % ((t.get('FromFileName') or '').replace(chr(92), '/').split('/')[-1],
                              t.get('Width', ('?',))[0], t.get('Height', ('?',))[0]) for t in m.textures]
        print('%s: %s' % (m.name, tex))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('cmd', choices=('ddt', 'material', 'details', 'gr2'))
    U.add_input_args(ap)
    a = ap.parse_args(argv)
    {'ddt': cmd_ddt, 'material': cmd_material, 'details': cmd_details, 'gr2': cmd_gr2}[a.cmd](a)


if __name__ == '__main__':
    main()
