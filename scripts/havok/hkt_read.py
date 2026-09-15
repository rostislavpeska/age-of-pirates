"""Havok 2018 TAG0 tagfile reader (hkpPhysicsData as used by AoE3DE *_damaged.hkt)."""
import sys, struct, json

class Tagfile:
    def __init__(self, path):
        self.data = open(path,'rb').read()
        self.secs = {}
        self._walk(0, len(self.data))
        self.tstr = [x.decode() for x in self._sec('TSTR').split(b'\0')]
        self.fstr = [x.decode() for x in self._sec('FSTR').split(b'\0')]
        self._types(); self._bodies(); self._items()
        do, de = self.secs['DATA']; self.D = self.data[do:de]

    def _walk(self, off, end):
        d=self.data
        while off + 8 <= end:
            hdr = struct.unpack('>I', d[off:off+4])[0]
            flags = hdr >> 30; size = hdr & 0x3FFFFFFF
            tag = d[off+4:off+8].decode('ascii','replace')
            self.secs[tag] = (off+8, off+size)
            if not (flags & 1): self._walk(off+8, off+size)
            off += size
    def _sec(self, tag):
        o,e = self.secs[tag]; return self.data[o:e]

    class R:
        def __init__(s, b): s.b=b; s.o=0
        def packed(s):
            b=s.b; o=s.o; b0=b[o]
            if b0 & 0x80 == 0: s.o+=1; return b0
            if b0 & 0xC0 == 0x80: s.o+=2; return ((b0&0x3F)<<8)|b[o+1]
            if b0 & 0xE0 == 0xC0: s.o+=3; return ((b0&0x1F)<<16)|(b[o+1]<<8)|b[o+2]
            if b0 & 0xF0 == 0xE0: s.o+=4; return ((b0&0x0F)<<24)|(b[o+1]<<16)|(b[o+2]<<8)|b[o+3]
            if b0 & 0xF8 == 0xF0: s.o+=5; return (b[o+1]<<24)|(b[o+2]<<16)|(b[o+3]<<8)|b[o+4]
            raise Exception('bad packed')
        def done(s): return s.o >= len(s.b)

    def _types(self):
        r = self.R(self._sec('TNA1')); n = r.packed()
        self.types = [None]*n
        for i in range(1,n):
            name = self.tstr[r.packed()]; np_ = r.packed()
            params = [(self.tstr[r.packed()], r.packed()) for _ in range(np_)]
            self.types[i] = dict(name=name, params=params, members=[], parent=0, sub=None)
    def _bodies(self):
        r = self.R(self._sec('TBDY'))
        while not r.done():
            ti = r.packed()
            if ti == 0: continue
            t = self.types[ti]; t['parent'] = r.packed(); fl = r.packed()
            if fl & 1: t['sub'] = r.packed()
            if fl & 2: t['pointee'] = r.packed()
            if fl & 4: t['version'] = r.packed()
            if fl & 8: t['size'] = r.packed(); t['align'] = r.packed()
            if fl & 16: t['abstract'] = r.packed()
            if fl & 32:
                for _ in range(r.packed() & 0xFFFF):
                    t['members'].append((self.fstr[r.packed()], r.packed(), r.packed(), r.packed()))
            if fl & 64: t['ifaces'] = [(r.packed(), r.packed()) for _ in range(r.packed())]
            if fl & 128: t['attr'] = r.packed()
    def _items(self):
        b = self._sec('ITEM'); self.items=[]
        for k in range(len(b)//12):
            tf, off, cnt = struct.unpack('<III', b[12*k:12*k+12])
            self.items.append((tf & 0xFFFFFF, tf >> 24, off, cnt))

    # --- type helpers ---
    def resolved(self, ti):
        """follow alias chain (types with no sub, e.g. hkReal -> float)"""
        while self.types[ti]['sub'] is None and self.types[ti]['parent']:
            ti = self.types[ti]['parent']
        return ti
    def tname(self, ti):
        if ti==0: return 'void'
        t=self.types[ti]
        if t['params']:
            return t['name']+'<'+','.join(f'{self.tname(v) if n.startswith("t") else v}' for n,v in t['params'])+'>'
        return t['name']
    def all_members(self, ti):
        t=self.types[ti]; ms=[]
        if t['parent']: ms += self.all_members(t['parent'])
        return ms + t['members']
    def size(self, ti):
        ti=self.resolved(ti); return self.types[ti]['size']

    # --- data readers ---
    def read_value(self, ti, off, depth=0):
        ti = self.resolved(ti); t = self.types[ti]; sub = t['sub']; kind = sub & 0x1F if sub is not None else 7
        D = self.D
        if kind == 2: return bool(D[off])
        if kind == 4:
            bits = 8 if sub & 0x2000 else 16 if sub & 0x4000 else 32 if sub & 0x8000 else 64
            signed = bool(sub & 0x200)
            return int.from_bytes(D[off:off+bits//8], 'little', signed=signed)
        if kind == 5:
            if t['size'] == 2:  # hkHalf16 = top 16 bits of a float32, not IEEE half
                return struct.unpack('<f', bytes(2) + D[off:off+2])[0]
            return struct.unpack('<f', D[off:off+4])[0]
        if kind == 3:
            idx = struct.unpack('<I', D[off:off+4])[0]
            return self.read_string(idx)
        if kind == 6:
            idx = struct.unpack('<I', D[off:off+4])[0]
            return ('ptr', idx)
        if kind == 8:
            if sub & 0x20:  # fixed tuple
                n = sub >> 8; et = t['pointee']; es = self.size(et)
                return [self.read_value(et, off+i*es, depth+1) for i in range(n)]
            idx = struct.unpack('<I', D[off:off+4])[0]
            return ('arr', idx)
        if kind == 7:
            return self.read_record(ti, off, depth+1)
        return f'<kind {kind}>'
    def read_record(self, ti, off, depth=0):
        out = {'__type': self.tname(ti)}
        for name, fl, moff, mti in self.all_members(ti):
            out[name] = self.read_value(mti, off+moff, depth)
        return out
    def read_string(self, idx):
        if idx == 0: return None
        ti, fl, off, cnt = self.items[idx]
        return self.D[off:off+cnt].split(b'\0')[0].decode('utf-8','replace')
    def read_item(self, idx):
        if idx == 0: return []
        ti, fl, off, cnt = self.items[idx]
        es = self.size(ti)
        return [self.read_value(ti, off+i*es) for i in range(cnt)]
    def deref(self, ref):
        """ref = ('ptr', idx) or ('arr', idx) -> list of python objects (records resolved one level)"""
        if ref is None or ref[1] == 0: return []
        return self.read_item(ref[1])

def summarize(path, limit=12):
    tf = Tagfile(path)
    print(f'{path}: {len(tf.items)} items, DATA {len(tf.D)} bytes')
    root = tf.read_item(1)[0]
    nv = tf.deref(root['namedVariants'])
    for v in nv:
        print('namedVariant:', v['name'], v['className'])
        pd = tf.read_item(v['variant'][1])[0]
        wcl = tf.read_item(pd['worldCinfo'][1])
        if wcl:
            wc = wcl[0]
            print('  worldCinfo: gravity', [round(x,3) for x in wc['gravity']], 'simType', wc['simulationType'], 'solverIter', wc['solverIterations'], 'collTol', wc['collisionTolerance'], 'broadPhaseAabb', wc['broadPhaseWorldAabb']['min'][:3], wc['broadPhaseWorldAabb']['max'][:3])
        else:
            print('  worldCinfo: <null>')
        for sysref in tf.deref(pd['systems']):
            s = tf.read_item(sysref[1])[0]
            rbs = tf.deref(s['rigidBodies'])
            print(f"  system name={s['name']!r} active={s['active']} rigidBodies={len(rbs)} constraints={len(tf.deref(s['constraints']))} actions={len(tf.deref(s['actions']))} phantoms={len(tf.deref(s['phantoms']))}")
            for k, rbref in enumerate(rbs):
                rb = tf.read_item(rbref[1])[0]
                m = rb['motion']; ms = m['motionState']; T = ms['transform']
                shp_ref = rb['collidable']['shape']
                sti = tf.items[shp_ref[1]][0]
                shape = tf.read_item(shp_ref[1])[0]
                mat = rb['material']
                inv = m['inertiaAndMassInv']
                mass = 1/inv[3] if inv[3] else 0
                pos = T[12:15]
                extra = ''
                if 'halfExtents' in shape: extra = f"halfExt={[round(x,3) for x in shape['halfExtents'][:3]]}"
                elif 'numVertices' in shape: extra = f"verts={shape['numVertices']}"
                elif 'cylRadius' in shape: extra = f"r={shape['cylRadius']:.3f}"
                elif 'childInfo' in shape: extra = f"children={len(tf.deref(shape['childInfo']))}"
                if k < limit or k >= len(rbs)-3:
                    print(f"    [{k:3}] {rb['name']!r:40} motion={m['type']} mass={mass:8.2f} pos=({pos[0]:7.2f},{pos[1]:7.2f},{pos[2]:7.2f}) shape={tf.tname(sti)} {extra} fric={mat['friction']:.2f} rest={mat['restitution']:.2f} cfi={rb['collidable']['broadPhaseHandle']['collisionFilterInfo']:#x} qt={rb['collidable']['broadPhaseHandle']['objectQualityType']} linDamp={ms['linearDamping']:.3f} angDamp={ms['angularDamping']:.3f} gravF={m['gravityFactor']:.2f} maxLinV={ms['maxLinearVelocity']['value']} maxAngV={ms['maxAngularVelocity']['value']} deact={ms['deactivationClass']} penD={rb['collidable']['allowedPenetrationDepth']:.3f} rad={ms['objectRadius']:.2f}")
                elif k == limit: print('    ...')
    return tf

if __name__ == '__main__':
    summarize(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 12)
