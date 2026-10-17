"""Shared parsing for grouping XML files (units, cliffgroups, tilegroups, heights).

A grouping file is a flat XML: <units> holds <unit variation posx posz orientx orienty orientz>proto</unit>
in METRES (2 m per tile, origin at the grouping centre), <tiles> holds <tilegroup type subtype> and
<cliffgroup type> with <block startx startz endx endz> in TILES, <heights> holds one <tiles x z> row of
vertex heights per tile row. Text edits are done on the raw string so formatting, ordering and line
endings survive byte-for-byte; only the touched attributes change.
"""
import re

CRLF = '\r\n'

BLOCK_RE = re.compile(r'<block startx="(-?\d+)" startz="(-?\d+)" endx="(-?\d+)" endz="(-?\d+)"></block>')
UNIT_RE = re.compile(r'<unit variation="(\d+)" posx="(-?\d+\.\d+)" posz="(-?\d+\.\d+)" orientx="(-?\d+\.\d+)" orienty="(-?\d+\.\d+)" orientz="(-?\d+\.\d+)">([^<]*)</unit>')


def read(path):
    raw = open(path, 'rb').read().decode('utf-8')
    return raw, (CRLF if CRLF in raw else '\n')


def write(path, text):
    open(path, 'wb').write(text.encode('utf-8'))


def groups(text, tag):
    """{type: [(sx, sz, ex, ez), ...]} for <cliffgroup type=..> or <tilegroup type=..>."""
    out = {}
    for m in re.finditer(r'<%s [^>]*type="([^"]*)"[^>]*>(.*?)</%s>' % (tag, tag), text, re.S):
        out[m.group(1)] = [tuple(int(v) for v in b) for b in BLOCK_RE.findall(m.group(2))]
    return out


def tiles_of(blocks):
    return {(x, z) for sx, sz, ex, ez in blocks for x in range(sx, ex + 1) for z in range(sz, ez + 1)}


def units(text):
    """[(variation, posx, posz, orientx, orienty, orientz, proto), ...] with floats."""
    return [(int(v), float(x), float(z), float(ox), float(oy), float(oz), n) for v, x, z, ox, oy, oz, n in UNIT_RE.findall(text)]


def heights(text):
    """{(x, z): [floats]} per <tiles x z> row inside <heights>."""
    h = re.search(r'<heights>.*?</heights>', text, re.S)
    if not h:
        return {}
    return {(int(x), int(z)): [float(v) for v in vals.split()] for x, z, vals in re.findall(r'<tiles x="(-?\d+)" z="(-?\d+)">([^<]*)</tiles>', h.group(0))}


def block_line(x, z, nl, indent='\t\t\t'):
    return '%s<block startx="%d" startz="%d" endx="%d" endz="%d"></block>%s' % (indent, x, z, x, z, nl)


def move_tiles(text, nl, src_type, dst_type, wanted):
    """Move tile set `wanted` from cliffgroup src_type to dst_type. Multi-tile blocks that contain a wanted
    tile are split into single-tile blocks; everything else is left verbatim. Returns new text."""
    src_m = re.search(r'<cliffgroup type="%s">.*?</cliffgroup>' % re.escape(src_type), text, re.S)
    dst_m = re.search(r'<cliffgroup type="%s">.*?</cliffgroup>' % re.escape(dst_type), text, re.S)
    assert src_m, 'no cliffgroup ' + src_type
    src = src_m.group(0)
    dst = dst_m.group(0) if dst_m else None
    have = tiles_of(groups(src, 'cliffgroup')[src_type])
    missing = [t for t in wanted if t not in have]
    assert not missing, 'not in %s: %s' % (src_type, missing)
    add = ''
    for x, z in wanted:
        single = block_line(x, z, nl)
        if single in src:
            src = src.replace(single, '', 1)
        else:
            hits = [b for b in re.finditer(r'\t*<block startx="(-?\d+)" startz="(-?\d+)" endx="(-?\d+)" endz="(-?\d+)"></block>' + re.escape(nl), src)
                    if int(b.group(1)) <= x <= int(b.group(3)) and int(b.group(2)) <= z <= int(b.group(4))]
            assert len(hits) == 1, (x, z)
            b = hits[0]; sx, sz, ex, ez = map(int, b.groups())
            rest = ''.join(block_line(xx, zz, nl) for xx in range(sx, ex + 1) for zz in range(sz, ez + 1) if (xx, zz) != (x, z))
            src = src.replace(b.group(0), rest, 1)
        add += single
    text = text.replace(src_m.group(0), src, 1)
    if dst is None:
        # new cliffgroup right after the source one
        new = '\t\t<cliffgroup type="%s">%s%s\t\t</cliffgroup>%s' % (dst_type, nl, add, nl)
        text = text.replace(src, src + nl + new, 1)
    else:
        text = text.replace(dst, dst.replace('\t\t</cliffgroup>', add + '\t\t</cliffgroup>', 1), 1)
    return text
