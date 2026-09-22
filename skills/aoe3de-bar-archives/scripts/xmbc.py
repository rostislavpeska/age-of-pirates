"""xmbc - compile AoE3DE XML to .xml.xmb (X1/XR v4 inside an alz4 wrapper), the inverse of
bartool's decoder, so data/*.xml edits can be compiled without Resource Manager.

    python xmbc.py check  data/protomods.xml          # compile in memory, decode back, compare trees
    python xmbc.py build  data/protomods.xml [...]    # write data/protomods.xml.xmb (after the same check)
    python xmbc.py probe  data/protomods.xml.xmb      # report the length conventions of an existing file

Standard library + the `lz4` package (pip install lz4). Layout mirrors bartool.xmb_to_element:
  X1 u32(payload) XR u32(4) u32(8) u32(nElem) wstr* u32(nAttr) wstr* node
  node = XN u32(len) wstr(text) u32(elem) u32(line) u32(nAttr) (u32(attr) wstr)* u32(nChild) node*
  wstr = u32(chars) utf-16-le
"""
import os, struct, sys, xml.etree.ElementTree as ET
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bartool


def wstr(s):
    b = s.encode('utf-16-le'); return struct.pack('<I', len(b) // 2) + b


class Compiler:
    def __init__(self, root):
        self.elems, self.attrs = [], []
        self.ei, self.ai = {}, {}
        self._collect(root)
        self.line = 0

    def _collect(self, e):
        if e.tag not in self.ei: self.ei[e.tag] = len(self.elems); self.elems.append(e.tag)
        for a in e.attrib:
            if a not in self.ai: self.ai[a] = len(self.attrs); self.attrs.append(a)
        for c in e: self._collect(c)

    def node(self, e):
        self.line += 1
        body = wstr((e.text or '').strip())
        body += struct.pack('<II', self.ei[e.tag], self.line)
        body += struct.pack('<I', len(e.attrib))
        for a, v in e.attrib.items():
            body += struct.pack('<I', self.ai[a]) + wstr(v)
        body += struct.pack('<I', len(e))
        for c in e: body += self.node(c)
        return b'XN' + struct.pack('<I', len(body)) + body

    def payload(self, root):
        p = b'XR' + struct.pack('<II', 4, 8)
        p += struct.pack('<I', len(self.elems)) + b''.join(wstr(s) for s in self.elems)
        p += struct.pack('<I', len(self.attrs)) + b''.join(wstr(s) for s in self.attrs)
        p += self.node(root)
        return b'X1' + struct.pack('<I', len(p)) + p


def compile_xml(path):
    root = ET.parse(path).getroot()
    return Compiler(root).payload(root), root


def wrap_alz4(raw):
    import lz4.block
    comp = lz4.block.compress(raw, mode='high_compression', store_size=False)
    return b'alz4' + struct.pack('<III', len(raw), len(comp), 1) + comp


def canon(e):
    """tree -> nested tuples the way the decoder sees it (stripped text, attrs, children)"""
    return (e.tag, (e.text or '').strip(), tuple(sorted(e.attrib.items())), tuple(canon(c) for c in e))


def check(path):
    xmb, root = compile_xml(path)
    back = bartool.xmb_to_element(xmb)
    ok = canon(back) == canon(root)
    wrapped = wrap_alz4(xmb)
    assert bartool.unwrap_alz4(wrapped) == xmb, 'alz4 round trip failed'
    print(f'{path}: {len(xmb)} bytes XMB, {len(wrapped)} bytes alz4; decode-back tree {"MATCHES" if ok else "DIFFERS"} the source')
    return ok, wrapped


def probe(path):
    d = bartool.unwrap_alz4(open(path, 'rb').read())
    r = bartool._R(d); assert r.tag() == b'X1'; payload = r.u32()
    print(f'payload field {payload} vs actual bytes after it {len(d) - 6}')
    assert r.tag() == b'XR'; print('version', r.u32(), 'unknown', r.u32())
    ne = r.u32(); [r.wstr() for _ in range(ne)]; na = r.u32(); [r.wstr() for _ in range(na)]
    start = r.p; assert r.tag() == b'XN'; n = r.u32()
    print(f'elems {ne} attrs {na}; root node length field {n} vs actual {len(d) - (start + 6)}')
    r2 = bartool._R(d[start + 6:]); r2.wstr(); r2.u32(); print('root line number field', r2.u32())


if __name__ == '__main__':
    cmd, files = sys.argv[1], sys.argv[2:]
    if cmd == 'probe':
        for f in files: probe(f)
    elif cmd in ('check', 'build'):
        for f in files:
            ok, wrapped = check(f)
            if cmd == 'build':
                if not ok: sys.exit('refusing to write: round trip differs')
                out = f + '.xmb'; open(out, 'wb').write(wrapped); print('wrote', out)
    else:
        print(__doc__)
