"""Edit a grouping's terrain and units in place, byte-preserving everything you don't touch.

    python grouping_edit.py <grouping.xml> list
    python grouping_edit.py <grouping.xml> cliff --from "ZP City" --to "ZP Bridge" --tiles "-11,-4 -10,-4 -9,-4"
    python grouping_edit.py <grouping.xml> cliff --from "ZP City" --to "ZP Bridge" --row z=-4 --x -13..-9
    python grouping_edit.py <grouping.xml> height --from 5.250 --to 5.050
    python grouping_edit.py <grouping.xml> shift --dx 1.0 --dz 0.5 [--protos zpBridgeFace,PropsPoles | --all]
    python grouping_edit.py <grouping.xml> socket-last --proto zpSocketPirates

Add --also <other folder> to write the same result to a second copy (the user's RandMaps/groupings).
`cliff` moves tiles between cliff groups (creating the target group if absent). `height` rewrites one
vertex height value everywhere in <heights> (plateau tops are all one value). `shift` moves unit
positions in METRES (tiles/cliffs/heights are NOT moved - they are on a 2 m grid and cannot shift by
fractions; say so to the user). `socket-last` makes the named unit the last <unit> (map scripts that
resolve sockets by consecutive ids rely on it).
"""
import sys, os, re, argparse, hashlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import grouping_lib as G

ap = argparse.ArgumentParser()
ap.add_argument('src'); ap.add_argument('cmd', choices=['list', 'cliff', 'height', 'shift', 'socket-last'])
ap.add_argument('--from', dest='src_val'); ap.add_argument('--to', dest='dst_val')
ap.add_argument('--tiles'); ap.add_argument('--row'); ap.add_argument('--x'); ap.add_argument('--z')
ap.add_argument('--dx', type=float, default=0.0); ap.add_argument('--dz', type=float, default=0.0)
ap.add_argument('--protos'); ap.add_argument('--all', action='store_true'); ap.add_argument('--proto')
ap.add_argument('--also')
# values that start with '-' (negative tiles/offsets) must not be mistaken for options: join them as --opt=value
argv = sys.argv[1:]; joined = []
i = 0
while i < len(argv):
    if argv[i] in ('--tiles', '--x', '--z', '--dx', '--dz', '--from', '--to') and i + 1 < len(argv) and argv[i + 1].startswith('-'):
        joined.append(argv[i] + '=' + argv[i + 1]); i += 2
    else:
        joined.append(argv[i]); i += 1
a = ap.parse_args(joined)

text, nl = G.read(a.src)

def parse_range(s):
    if '..' in s:
        lo, hi = s.split('..'); return list(range(int(lo), int(hi) + 1))
    return [int(v) for v in s.split(',')]

if a.cmd == 'list':
    for typ, bl in G.groups(text, 'cliffgroup').items():
        print('cliffgroup %-16s %3d blocks %3d tiles' % (typ, len(bl), len(G.tiles_of(bl))))
    for typ, bl in G.groups(text, 'tilegroup').items():
        print('tilegroup  %-16s %3d blocks %3d tiles' % (typ, len(bl), len(G.tiles_of(bl))))
    hts = G.heights(text)
    if hts:
        vals = sorted({v for row in hts.values() for v in row}); print('heights: %d rows, distinct values %s' % (len(hts), vals[:12]))
    from collections import Counter
    c = Counter(u[6] for u in G.units(text)); print('units: %d  %s' % (sum(c.values()), dict(c.most_common(8))))
    last = G.units(text)[-1][6] if G.units(text) else None; print('last unit:', last)
    sys.exit(0)

if a.cmd == 'cliff':
    if a.tiles:
        wanted = [tuple(int(v) for v in t.split(',')) for t in a.tiles.split()]
    else:
        assert a.row and (a.x or a.z), 'need --tiles or --row z=N --x A..B (or --row x=N --z A..B)'
        axis, val = a.row.split('='); val = int(val)
        wanted = [(x, val) for x in parse_range(a.x)] if axis == 'z' else [(val, z) for z in parse_range(a.z)]
    new = G.move_tiles(text, nl, a.src_val, a.dst_val, wanted)
    print('moved %d tiles %s -> %s: %s' % (len(wanted), a.src_val, a.dst_val, wanted))
elif a.cmd == 'height':
    h = re.search(r'<heights>.*?</heights>', text, re.S).group(0)
    n = h.count(a.src_val); assert n, 'value %s not in heights' % a.src_val
    new = text.replace(h, h.replace(a.src_val, a.dst_val), 1); print('height %s -> %s on %d vertices' % (a.src_val, a.dst_val, n))
elif a.cmd == 'shift':
    protos = None if a.all else set((a.protos or '').split(','))
    assert a.all or protos, 'give --protos or --all'
    n = [0]
    def rep(m):
        if protos and m.group(7) not in protos: return m.group(0)
        n[0] += 1
        return '<unit variation="%s" posx="%.4f" posz="%.4f" orientx="%s" orienty="%s" orientz="%s">%s</unit>' % (
            m.group(1), float(m.group(2)) + a.dx, float(m.group(3)) + a.dz, m.group(4), m.group(5), m.group(6), m.group(7))
    new = G.UNIT_RE.sub(rep, text); print('shifted %d units by dx=%.4f dz=%.4f (metres); tiles/cliffs/heights untouched' % (n[0], a.dx, a.dz))
elif a.cmd == 'socket-last':
    lines = text.split(nl)
    idx = [i for i, l in enumerate(lines) if '>%s</unit>' % a.proto in l]; assert len(idx) == 1, idx
    s = lines.pop(idx[0]); end = [i for i, l in enumerate(lines) if l.strip() == '</units>']; assert len(end) == 1
    lines.insert(end[0], s); new = nl.join(lines); print('%s is now the last unit' % a.proto)

assert new != text or a.cmd == 'socket-last', 'nothing changed'
G.write(a.src, new)
import xml.etree.ElementTree as ET; ET.parse(a.src)
if a.also:
    dst = os.path.join(a.also, os.path.basename(a.src)); G.write(dst, new)
    assert hashlib.md5(open(dst, 'rb').read()).hexdigest() == hashlib.md5(open(a.src, 'rb').read()).hexdigest(); print('also written:', dst)
