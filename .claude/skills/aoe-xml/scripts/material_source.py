#!/usr/bin/env python
"""A retexture keeps its source model's materialdef: the check, and the vanilla facts behind it.

The materialdef decides what the BaseColor alpha does. Only the cutting defs (`*cutout*`, `speedtree\\*`) and the
blending ones (`alphablend*`) use it; under every other def the alpha is ignored and a card that should be cut out
draws as a solid square (Gakgung Archer 2026-10-09: the Changdao bodies' plume cards drew solid because one
`default_doublesided` was written for the whole unit, while vanilla changdao_1 and changdao_2 are
`default_doublesided_cutout` and changdao_0 is `default_doublesided`). Alpha alone does not tell the def: 269 vanilla
unit materials carry a cut-out alpha under a def that ignores it (changdao_0, trade ships, travois), and a cutting def
on them would make half of the model vanish. So the rule is per model and per submaterial: a retexture copies the
def of the vanilla material it retextures.

Only a BaseColor that cuts out matters (alpha < 128 on >= 1 % of the texels of its <= 256 px mip). Its source, from
the vanilla facts of the game archives (cached in the temp folder):
  1. a vanilla BaseColor named by the mod material itself -> the vanilla submaterials that use it;
  2. a mod BaseColor -> the vanilla BaseColor of the same size whose cut-out mask (32 px mip) overlaps it with an
     intersection over union >= 0.8 (a retexture keeps the source's alpha, or edits a little of it: Gakgung age 2,
     0.95); among several, the one whose submaterial the mod material also names by a vanilla Normals / Masks map.
A borrowed vanilla Normals or Masks map alone is no source (AoP's Flying Dutchman borrows a galleon's Masks and cuts
its own torn sails).
ERROR: the def and the source's def treat the alpha differently, both of a proven kind: 'cut' (*cutout*,
       speedtree\\*) or 'ignore' (default, default_doublesided, destructible, destructible_doublesided).
WARN:  the same with an unproven kind on either side ('blend' alphablend*, 'other' emissive, water, scroll ...: the
       alpha may mean something else there), several sources that disagree, or no source under an 'ignore' def.
--verbose adds every other def difference from the source (sidedness, destructible ...).

    python material_source.py [--root DIR] [PATH ...]    # .material files or folders; default DIR/art (DIR = cwd)
    python material_source.py --explain changdao_2       # the vanilla submaterials, their defs and BaseColor cut
Exit 1 on an ERROR. xmlcheck.py runs it on every .material it checks (KNOWN: AoP findings reported to the owner).
"""
import argparse
import hashlib
import io
import json
import os
import re
import struct
import sys
import tempfile
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'aoe3de-bar-archives', 'scripts'))
BS = chr(92)
MIP = 32                # fingerprint mip size (px)
CUT_MIP = 256           # cut share measured on the largest mip up to this size (thin cut-outs survive)
CUT = 0.01              # a BaseColor "cuts out" when this share of its texels has alpha < 128
IOU = 0.8               # fingerprint match (0.60 was chance: an armored wagon against an explorer)
INDEX_VERSION = 2
IGNORE = {'default', 'default_doublesided', 'destructible', 'destructible_doublesided'}
PROVEN = ('cut', 'ignore')
# AoP findings of the first sweep (2026-10-10), reported to the owner, untouched until he decides: printed as WARN
KNOWN = {('art/buildings/basilica/venice_basilica_age4_con.material', 'matc'),
         ('art/buildings/props/pirate_harbor/fishingnet_01.material', 'matA'),
         ('art/buildings/props/pirate_harbor/fishingnet_02.material', 'matA'),
         ('art/buildings/spc/cherokee_warhut/cherokee_warhut_con.material', 'mata')}


def alpha_use(md):
    """What a materialdef does with the BaseColor alpha: 'cut', 'ignore' (both proven in game), 'blend' or 'other'."""
    m = (md or '').lower()
    if 'cutout' in m or m.startswith('speedtree'):
        return 'cut'
    if m in IGNORE:
        return 'ignore'
    if 'alphablend' in m:
        return 'blend'
    return 'other'


def norm(p):
    return p.strip().replace(BS, '/').lower()


def _mip_cut(data, size_limit):
    """Boolean alpha<128 array of the largest mip of an RTS3 DXT1a/DXT5 DDT that fits size_limit, or None."""
    import numpy as np
    from PIL import Image
    fmt, nm = data[6], data[7]
    w, h = struct.unpack_from('<II', data, 8)
    lvl = 0
    while max(w >> lvl, h >> lvl) > size_limit and lvl < nm - 1:
        lvl += 1
    off, size = struct.unpack_from('<II', data, 16 + 8 * lvl)
    mw, mh = max(1, w >> lvl), max(1, h >> lvl)
    four = b'DXT5' if fmt == 9 else b'DXT1'
    dds = struct.pack('<4sI', b'DDS ', 124) + struct.pack('<IIIIII', 0x1007 | 0x80000, mh, mw, size, 0, 1) + bytes(44)
    dds += struct.pack('<II4sIIIII', 32, 4, four, 0, 0, 0, 0, 0) + struct.pack('<IIII', 0x1000, 0, 0, 0) + bytes(4)
    try:
        return np.asarray(Image.open(io.BytesIO(dds + data[off:off + size])).convert('RGBA'))[..., 3] < 128
    except Exception:
        return None


def ddt_alpha(data):
    """{w, h, fmt, cut, mask} of an RTS3 DDT: cut = share of alpha<128 texels on the <= 256 px mip, mask = hex of the
    packed alpha<128 bits of the <= 32 px mip (None without an alpha channel: format 4 = DXT1)."""
    if data[:4] != b'RTS3':
        return None
    import numpy as np
    w, h = struct.unpack_from('<II', data, 8)
    info = dict(w=w, h=h, fmt=data[6], cut=0.0, mask=None)
    if data[6] not in (5, 9):
        return info
    big, small = _mip_cut(data, CUT_MIP), _mip_cut(data, MIP)
    if big is None or small is None:
        return info
    info.update(cut=float(big.mean()), mask=np.packbits(small.ravel()).tobytes().hex())
    return info


def submaterials(text):
    """[(sub name, materialdef, {channel: texture path})] of a .material text."""
    out = []
    for s in ET.fromstring(text).iter('submaterial'):
        md = s.find('materialdef')
        tex = {}
        for t in s.iter('texture'):
            if t.get('name') and t.get('override') and t.get('name') not in tex:   # the base parameters, not variants
                tex[t.get('name')] = t.get('override')
        out.append((s.get('name') or '', md.get('name') if md is not None else None, tex))
    return out


# ---------------------------------------------------------------- vanilla facts
def _archive():
    import bartool
    return bartool, bartool.build_index(bartool.find_game_dir())


def load_index(rebuild=False):
    """Vanilla facts: subs = [[material, sub, def, {channel: tex}]], tex = {texture: [sub indices]},
    base = {BaseColor texture: ddt_alpha}. Cached per archive state in the temp folder (first build ~1 min)."""
    bt, idx = _archive()
    bars = sorted({e.bar for e in idx.values()})
    key = hashlib.sha1(json.dumps([INDEX_VERSION, MIP] + [[b, os.path.getsize(b), int(os.path.getmtime(b))] for b in bars])
                       .encode()).hexdigest()[:16]
    cache = os.path.join(tempfile.gettempdir(), 'aoe3de_material_index_%s.json' % key)
    if os.path.isfile(cache) and not rebuild:
        return json.load(open(cache))
    subs, tex, base = [], {}, {}
    for path in sorted(p for p in idx if p.startswith('art/') and p.endswith('.material.xmb')):
        try:
            text = bt.decode(bt.read_entry(idx[path]), True, 'lf')[0].decode('utf-8-sig')
            parsed = submaterials(text)
        except Exception:
            continue
        for sub, md, t in parsed:
            i = len(subs)
            subs.append([path[len('art/'):-len('.material.xmb')], sub, md, {k: norm(v) for k, v in t.items()}])
            for v in t.values():
                tex.setdefault(norm(v), []).append(i)
            b = t.get('BaseColor')
            if b and norm(b) not in base:
                e = idx.get('art/%s.ddt' % norm(b))
                base[norm(b)] = ddt_alpha(bt.read_entry(e)) if e else None
    data = dict(subs=subs, tex=tex, base=base)
    tmp = cache + '.tmp'
    json.dump(data, open(tmp, 'w'))
    os.replace(tmp, cache)
    return data


def _iou(a, b):
    x, y = int(a, 16), int(b, 16)
    union = bin(x | y).count('1')
    return bin(x & y).count('1') / union if union else 0.0


# ---------------------------------------------------------------- the check
def source_of(tex, root, data):
    """(BaseColor alpha info, vanilla source submaterial indices, how found) of one mod submaterial's textures."""
    own = {ch for ch, p in tex.items() if os.path.isfile(os.path.join(root, 'art', norm(p) + '.ddt'))}
    b = norm(tex['BaseColor'])
    if 'BaseColor' not in own:                                   # 1. the vanilla BaseColor itself
        return data['base'].get(b), set(data['tex'].get(b, [])), 'its BaseColor is vanilla ' + b
    info = ddt_alpha(open(os.path.join(root, 'art', b + '.ddt'), 'rb').read())
    if not info or not info.get('mask') or info['cut'] < CUT:
        return info, set(), None
    named = set()                                                # subs the material also names by a vanilla map
    for ch, p in tex.items():
        if ch not in own:
            named |= set(data['tex'].get(norm(p), []))
    hits = []                                                    # 2. the alpha fingerprint
    for name, v in data['base'].items():
        if v and v.get('mask') and (v['w'], v['h']) == (info['w'], info['h']) and v['cut'] >= CUT:
            s = _iou(info['mask'], v['mask'])
            if s >= IOU:
                hits.append((s, name))
    if not hits:
        return info, set(), None
    pref = [h for h in hits if named & set(data['tex'].get(h[1], []))] or hits
    score, name = max(pref)
    return info, set(data['tex'].get(name, [])), 'its BaseColor alpha matches %s (IoU %.2f)' % (name, score)


def check_file(path, root, data, verbose=False):
    """(errors, warnings) for one mod .material; root = the mod folder (its art/ holds the mod textures)."""
    errors, warns = [], []
    try:
        subs = submaterials(open(path, encoding='utf-8-sig').read())
    except (OSError, ET.ParseError) as e:
        return [], ['%s: not checked (%s)' % (path, e)]
    for sub, md, tex in subs:
        if 'BaseColor' not in tex:
            continue
        tag = '%s [%s]' % (path, sub)
        info, cands, how = source_of(tex, root, data)
        cut = (info or {}).get('cut', 0.0)
        if cut < CUT and not verbose:
            continue                                             # nothing cut out: the def cannot change the look
        defs = sorted({data['subs'][i][2] for i in cands if data['subs'][i][2]})
        if not defs:
            if cut >= CUT and alpha_use(md) == 'ignore':
                warns.append('%s: the BaseColor cuts out %.0f%% of its texels but %s ignores the alpha (cards draw '
                             'solid); no vanilla source found' % (tag, 100 * cut, md))
            continue
        src = sorted('%s [%s]' % (data['subs'][i][0], data['subs'][i][1]) for i in cands)
        srcs = src[0] + (' and %d more' % (len(src) - 1) if len(src) > 1 else '')
        uses = {alpha_use(d) for d in defs}
        mine = alpha_use(md)
        if cut >= CUT and mine not in uses:
            msg = ('%s: materialdef %s (%s the BaseColor alpha, %.0f%% cut-out texels), its source %s (%s) is %s'
                   % (tag, md, mine, 100 * cut, srcs, how, ' / '.join(defs)))
            rel = os.path.relpath(os.path.abspath(path), os.path.abspath(root)).replace(os.sep, '/')
            if len(uses) == 1 and mine in PROVEN and uses <= set(PROVEN) and (rel, sub) in KNOWN:
                warns.append('KNOWN (reported 2026-10-10, the owner decides) ' + msg)
            elif len(uses) == 1 and mine in PROVEN and uses <= set(PROVEN):
                errors.append(msg + ' - copy the source def (a card drawn solid, or the model cut away)')
            else:
                warns.append(msg)
        elif verbose and md not in defs:
            warns.append('%s: materialdef %s, its source %s (%s) is %s' % (tag, md, srcs, how, ' / '.join(defs)))
    return errors, warns


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('paths', nargs='*')
    ap.add_argument('--root', default='.', help='the mod folder (default: the current folder)')
    ap.add_argument('--rebuild-index', action='store_true')
    ap.add_argument('--verbose', action='store_true', help='also every def difference from the source')
    ap.add_argument('--explain', metavar='TEXT', help='list the vanilla submaterials whose material path contains TEXT')
    a = ap.parse_args()
    data = load_index(a.rebuild_index)
    if a.explain:
        for m, sub, md, tex in data['subs']:
            if a.explain.lower() in m:
                info = data['base'].get(tex.get('BaseColor', ''), None) or {}
                print('%-60s %-6s %-32s %-6s cut %.3f' % (m, sub, md, alpha_use(md), info.get('cut', 0.0)))
        return 0
    files = []
    for p in a.paths or [os.path.join(a.root, 'art')]:
        if os.path.isfile(p):
            files.append(p)
        for d, _, fs in os.walk(p):
            files += [os.path.join(d, f) for f in fs if f.lower().endswith('.material')]
    errors, warns = [], []
    for f in sorted(files):
        e, w = check_file(f, a.root, data, a.verbose)
        errors += e
        warns += w
    for w in warns:
        print('WARN ', w)
    for e in errors:
        print('ERROR', e)
    print('%d material(s) checked - %d error(s), %d warning(s)' % (len(files), len(errors), len(warns)))
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
