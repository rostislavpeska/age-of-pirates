"""Write an AoE3DE destruction .hkt (Havok 2018 TAG0, hkpPhysicsData) from a body list.

Byte-template strategy: the TYPE section and every record layout come from a vanilla file
(field_coffee_damaged.hkt); only DATA and the item index are generated. Pieces get real convex
hulls (hkpConvexVerticesShape: packed vertices + outward planes offset by the convex radius,
conventions verified against all 117 hulls of the vanilla sheriff); proxies get boxes.

    python hkt_write.py cube.gxo out.hkt          # bodies derived from a converter GXO (Z-up -> engine Y-up)
    python hkt_write.py vanilla.hkt out.hkt       # rebuild a vanilla file as AABB boxes (bisection test)
"""
import math, os, struct, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from hkt_read import Tagfile
from hkt_patch import Patcher, PROP_TYPE, PROP_SIM, PROP_MATERIAL, PROP_PARENT
from hull3d import convex_hull

TEMPLATE = os.path.join(HERE, 'vanilla-hkt', 'field_coffee_damaged.hkt')
KINDS = {  # kind -> (motion type, quality, deactivation class, prop type, prop sim)
    'base':  (4, 1, 1, 6, 0),
    'proxy': (4, 1, 1, 7, 4),
    'piece': (3, 4, 2, 1, 3),
}
CONVEX_RADIUS = 0.01


class Writer:
    def __init__(self, template=TEMPLATE):
        self.tf = tf = Tagfile(template)
        self.pt = Patcher(template)
        names = {}
        for i in range(1, len(tf.types)):
            if tf.types[i] and 'size' in tf.types[i]: names.setdefault(tf.tname(i), i)   # skip size-less forward declarations
        self.T = {k: names[k] for k in ('hkRootLevelContainer', 'hkRootLevelContainer::NamedVariant', 'hkpPhysicsData',
                                        'char', 'T*<hkpPhysicsSystem>', 'hkpPhysicsSystem', 'T*<hkpRigidBody>',
                                        'hkpRigidBody', 'hkpBoxShape', 'hkSimpleProperty', 'hkpConvexVerticesShape')}
        D = tf.D
        def rec(idx):
            ti, fl, off, cnt = tf.items[idx]; return bytes(D[off:off + tf.size(ti) * max(cnt, 1)])
        self.rec_root, self.rec_nv, self.rec_pd, self.rec_sys = rec(1), rec(2), rec(3), rec(7)
        pd = tf.read_item(tf.deref(tf.read_item(1)[0]['namedVariants'])[0]['variant'][1])[0]
        s = tf.read_item(tf.deref(pd['systems'])[0][1])[0]
        self.rec_dyn = self.rec_key = None
        for r in tf.deref(s['rigidBodies']):
            rb = tf.read_item(r[1])[0]
            if rb['motion']['type'] == 3 and self.rec_dyn is None: self.rec_dyn = rec(r[1])
            if rb['motion']['type'] == 4 and 'proxy' in rb['name'] and self.rec_key is None: self.rec_key = rec(r[1])
        box_idx = next(k for k, it in enumerate(tf.items) if it[0] == self.T['hkpBoxShape'])
        self.rec_box = rec(box_idx)
        cvs_idx = next(k for k, it in enumerate(tf.items) if it[0] == self.T['hkpConvexVerticesShape'])
        self.rec_cvs = rec(cvs_idx)
        cvs = tf.read_item(cvs_idx)[0]
        self.T_rv = tf.items[cvs['rotatedVertices'][1]][0]        # exact item type indices vanilla uses for the arrays
        self.T_pe = tf.items[cvs['planeEquations'][1]][0]
        assert self.rec_dyn and self.rec_key and len(self.rec_box) == 48 and len(self.rec_cvs) == 80
        rbt = self.T['hkpRigidBody']
        self.m = {p: self.pt.member(rbt, p)[0] for p in (
            'name', 'properties', 'collidable.shape', 'collidable.broadPhaseHandle.objectQualityType',
            'motion.type', 'motion.motionState.transform', 'motion.motionState.sweptTransform',
            'motion.motionState.deltaAngle', 'motion.motionState.objectRadius', 'motion.motionState.deactivationClass',
            'motion.inertiaAndMassInv', 'motion.linearVelocity', 'motion.angularVelocity',
            'motion.deactivationRefPosition', 'motion.deactivationRefOrientation', 'motion.deactivationNumInactiveFrames')}
        self.bm = {p: self.pt.member(self.T['hkpBoxShape'], p)[0] for p in ('halfExtents', 'radius')}
        self.cm = {p: self.pt.member(self.T['hkpConvexVerticesShape'], p)[0] for p in (
            'radius', 'aabbHalfExtents', 'aabbCenter', 'rotatedVertices', 'numVertices', 'planeEquations', 'connectivity')}
        to, te = tf.secs['TYPE']; self.type_section = bytes(tf.data[to - 8:te])   # verbatim, header included

    # ------------------------------------------------------------------ shapes
    @staticmethod
    def hull_data(local_pts, radius=CONVEX_RADIUS):
        """-> (verts, planes) in the body frame; planes (nx,ny,nz,w) with w = -n.p - radius (vanilla convention)"""
        verts, planes = convex_hull(local_pts)
        merged = []
        for n in planes:                                   # merge near-coplanar faces like the vanilla exporter does
            if not any(n[0]*q[0] + n[1]*q[1] + n[2]*q[2] > 0.9995 and abs(n[3] - q[3]) < 0.01 for q in merged):
                merged.append(n)
        return verts, [(n[0], n[1], n[2], n[3] - radius) for n in merged]

    # ------------------------------------------------------------------ building
    def build(self, bodies):
        """bodies: dicts {name, kind, center[3], half[3], mass, material, parent(name|None), verts[optional, body-local]}"""
        data = bytearray(); items = [(0, 0, 0, 0)]      # item 0 = null
        def put_raw(rec, tindex, flags, align, count=1):
            while len(data) % align: data.append(0)
            items.append((tindex, flags, len(data), count)); data.extend(rec); return len(items) - 1
        def put(rec, typ, flags, align, count=1): return put_raw(rec, self.T[typ], flags, align, count)
        N = len(bodies)
        root = put(self.rec_root, 'hkRootLevelContainer', 0x10, 4)
        nv = put(self.rec_nv, 'hkRootLevelContainer::NamedVariant', 0x20, 4)
        s1 = put(b'Physics Data\0', 'char', 0x20, 1, 13)
        s2 = put(b'hkpPhysicsData\0', 'char', 0x20, 1, 15)
        pd = put(self.rec_pd, 'hkpPhysicsData', 0x10, 4)
        sysptr = put(b'\0' * 4, 'T*<hkpPhysicsSystem>', 0x20, 4, 1)
        sysrec = put(self.rec_sys, 'hkpPhysicsSystem', 0x10, 4)
        rbptr = put(b'\0' * (4 * N), 'T*<hkpRigidBody>', 0x20, 4, N)
        sysname = put(b'Default Physics System\0', 'char', 0x20, 1, 23)
        struct.pack_into('<I', data, items[root][2], nv)
        struct.pack_into('<III', data, items[nv][2], s1, s2, pd)
        struct.pack_into('<II', data, items[pd][2] + 4, 0, sysptr)
        struct.pack_into('<I', data, items[sysptr][2], sysrec)
        struct.pack_into('<I', data, items[sysrec][2] + 4, rbptr)
        struct.pack_into('<I', data, items[sysrec][2] + 20, sysname)
        rb_items, later = [], []
        index_of = {b['name']: i for i, b in enumerate(bodies)}
        for b in bodies:
            mt, qt, dc, ptype, psim = KINDS[b['kind']]
            ptype, psim = b.get('ptype', ptype), b.get('psim', psim)
            rec = bytearray(self.rec_dyn if b['kind'] == 'piece' else self.rec_key)
            m = self.m; cx, cy, cz = b['center']; hx, hy, hz = b['half']
            struct.pack_into('<B', rec, m['motion.type'], mt)
            struct.pack_into('<b', rec, m['collidable.broadPhaseHandle.objectQualityType'], qt)
            struct.pack_into('<B', rec, m['motion.motionState.deactivationClass'], dc)
            struct.pack_into('<16f', rec, m['motion.motionState.transform'], 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, cx, cy, cz, 1)
            comw = 1.0 if b['kind'] == 'piece' else 0.0
            struct.pack_into('<20f', rec, m['motion.motionState.sweptTransform'], cx, cy, cz, 0, cx, cy, cz, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, comw)
            struct.pack_into('<4f', rec, m['motion.motionState.deltaAngle'], 0, 0, 0, 0)
            reach = max((math.sqrt(v[0]**2 + v[1]**2 + v[2]**2) for v in b.get('verts', [])), default=math.sqrt(hx*hx + hy*hy + hz*hz))
            struct.pack_into('<f', rec, m['motion.motionState.objectRadius'], reach + CONVEX_RADIUS)
            if b['kind'] == 'piece':
                mass = b['mass']; ex, ey, ez = 2 * hx, 2 * hy, 2 * hz
                ix, iy, iz = mass / 12 * (ey * ey + ez * ez), mass / 12 * (ex * ex + ez * ez), mass / 12 * (ex * ex + ey * ey)
                struct.pack_into('<4f', rec, m['motion.inertiaAndMassInv'], 1 / ix, 1 / iy, 1 / iz, 1 / mass)
                struct.pack_into('<HH', rec, m['motion.deactivationNumInactiveFrames'], 49152, 49152)
            else:
                struct.pack_into('<4f', rec, m['motion.inertiaAndMassInv'], 0, 0, 0, 0)
                struct.pack_into('<HH', rec, m['motion.deactivationNumInactiveFrames'], 0, 0)
            struct.pack_into('<8f', rec, m['motion.linearVelocity'], 0, 0, 0, 0, 0, 0, 0, 0)
            struct.pack_into('<8f', rec, m['motion.deactivationRefPosition'], 0, 0, 0, 0, 0, 0, 0, 0)
            struct.pack_into('<II', rec, m['motion.deactivationRefOrientation'], 0, 0)
            rb = put(rec, 'hkpRigidBody', 0x10, 16)
            parent = index_of[b['parent']] if b.get('parent') else -1
            props = struct.pack('<IqIqIqIq', PROP_TYPE, ptype, PROP_SIM, psim, PROP_MATERIAL, b.get('material', 2), PROP_PARENT, parent)
            pr = put(props, 'hkSimpleProperty', 0x20, 4, 4)
            nm = put(b['name'].encode() + b'\0', 'char', 0x20, 1, len(b['name']) + 1)
            rb_items.append(rb); later.append((rb, pr, nm, b))
        for i, rb in enumerate(rb_items):
            struct.pack_into('<I', data, items[rbptr][2] + 4 * i, rb)
        for rb, pr, nm, b in later:                       # shapes after all bodies, each followed by its arrays
            if b.get('verts'):
                verts, planes = self.hull_data(b['verts'])
                rec = bytearray(self.rec_cvs); c = self.cm
                lo = [min(v[i] for v in verts) for i in range(3)]; hi = [max(v[i] for v in verts) for i in range(3)]
                struct.pack_into('<f', rec, c['radius'], CONVEX_RADIUS)
                struct.pack_into('<4f', rec, c['aabbHalfExtents'], *[(hi[i] - lo[i]) / 2 for i in range(3)], 0.0)
                struct.pack_into('<4f', rec, c['aabbCenter'], *[(hi[i] + lo[i]) / 2 for i in range(3)], 0.0)
                struct.pack_into('<i', rec, c['numVertices'], len(verts))
                struct.pack_into('<I', rec, c['connectivity'], 0)
                sh = put(rec, 'hkpConvexVerticesShape', 0x10, 16)
                padded = verts + [verts[-1]] * (-len(verts) % 4)
                blocks = b''.join(struct.pack('<12f', *[padded[k + j][0] for j in range(4)], *[padded[k + j][1] for j in range(4)],
                                              *[padded[k + j][2] for j in range(4)]) for k in range(0, len(padded), 4))
                rv = put_raw(blocks, self.T_rv, 0x20, 16, len(padded) // 4)
                pe = put_raw(b''.join(struct.pack('<4f', *p) for p in planes), self.T_pe, 0x20, 16, len(planes))
                struct.pack_into('<I', data, items[sh][2] + c['rotatedVertices'], rv)
                struct.pack_into('<I', data, items[sh][2] + c['planeEquations'], pe)
            else:
                box = bytearray(self.rec_box); hx, hy, hz = b['half']
                struct.pack_into('<4f', box, self.bm['halfExtents'], hx, hy, hz, hz)
                struct.pack_into('<f', box, self.bm['radius'], 0.03)
                sh = put(box, 'hkpBoxShape', 0x10, 16)
            off = items[rb][2]
            struct.pack_into('<I', data, off + self.m['collidable.shape'], sh)
            struct.pack_into('<I', data, off + self.m['properties'], pr)
            struct.pack_into('<I', data, off + self.m['name'], nm)
        while len(data) % 16: data.append(0)
        def sec(tag, body, container):
            return struct.pack('>I', (len(body) + 8) | (0 if container else 0x40000000)) + tag + body
        item_bytes = b''.join(struct.pack('<III', (t | (f << 24)), o, c) for t, f, o, c in items)
        indx = sec(b'INDX', sec(b'ITEM', item_bytes, False), True)
        body = sec(b'SDKV', b'20180200', False) + sec(b'DATA', bytes(data), False) + self.type_section + indx
        return sec(b'TAG0', body, True)


def bodies_from_gxo(path, density=0.35, to_engine=lambda v: (v[0], v[2], -v[1])):
    """One hull body per bone-bound mesh; base + on-death proxies as boxes from the AABBs. GXO is
    Z-up (Max frame); the gr2/engine frame is Y-up: default mapping is the -90 deg X rotation."""
    g = open(path, encoding='utf-8', errors='replace').read().split('\n')
    meshes, cur = [], None
    for l in g:
        t = l.split()
        if not t: continue
        if t[0] == 'm': cur = {'mesh': t[1].strip('"'), 'bones': [], 'v': []}; meshes.append(cur)
        elif t[0] == 'mb' and cur: cur['bones'].append(t[1].strip('"'))
        elif t[0] == 'v' and cur: cur['v'].append(to_engine(tuple(float(x) for x in t[1:4])))
    def aabb(vs):
        lo = [min(v[i] for v in vs) for i in range(3)]; hi = [max(v[i] for v in vs) for i in range(3)]
        return [(lo[i] + hi[i]) / 2 for i in range(3)], [max((hi[i] - lo[i]) / 2, 0.02) for i in range(3)]
    allv = [v for m in meshes for v in m['v']]
    c, h = aabb(allv)
    bodies = [{'name': 'base_proxy', 'kind': 'base', 'center': c, 'half': h, 'mass': 0, 'material': 2, 'parent': None},
              {'name': 'ondeath_0_proxy', 'kind': 'proxy', 'center': c, 'half': h, 'mass': 0, 'material': 2, 'parent': None}]
    for m in meshes:
        c, h = aabb(m['v'])
        local = sorted({(round(v[0] - c[0], 5), round(v[1] - c[1], 5), round(v[2] - c[2], 5)) for v in m['v']})
        bodies.append({'name': m['bones'][0], 'kind': 'piece', 'center': c, 'half': h, 'verts': local,
                       'mass': max(0.2, 8 * h[0] * h[1] * h[2] * density), 'material': 2, 'parent': 'ondeath_0_proxy'})
    return bodies


def bodies_from_hkt(path):
    """Rebuild a vanilla file's bodies as world-space AABB boxes (same names, kinds, parents, masses)."""
    tf = Tagfile(path)
    pd = tf.read_item(tf.deref(tf.read_item(1)[0]['namedVariants'])[0]['variant'][1])[0]
    s = tf.read_item(tf.deref(pd['systems'])[0][1])[0]
    refs = tf.deref(s['rigidBodies'])

    def shape_points(idx):
        ti = tf.items[idx][0]; sh = tf.read_item(idx)[0]; name = tf.tname(ti); pts = []
        if name == 'hkpBoxShape':
            hx, hy, hz = sh['halfExtents'][:3]
            pts = [(sx * hx, sy * hy, sz * hz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        elif name == 'hkpConvexVerticesShape':
            n = sh['numVertices']
            for blk in tf.deref(sh['rotatedVertices']):
                for k in range(4):
                    if len(pts) < n: pts.append((blk[k], blk[4 + k], blk[8 + k]))
        elif name == 'hkpCylinderShape':
            a, b, r = sh['vertexA'][:3], sh['vertexB'][:3], sh['cylRadius']
            for p in (a, b):
                pts += [(p[0] + dx, p[1] + dy, p[2] + dz) for dx in (-r, r) for dy in (-r, r) for dz in (-r, r)]
        elif name == 'hkpConvexTranslateShape':
            t = sh['translation'][:3]
            pts = [(p[0] + t[0], p[1] + t[1], p[2] + t[2]) for p in shape_points(sh['childShape']['childShape'][1])]
        elif name == 'hkpListShape':
            for ch in tf.deref(sh['childInfo']): pts += shape_points(ch['shape'][1])
        return pts

    names = [tf.read_item(r[1])[0]['name'] for r in refs]
    bodies = []
    for r in refs:
        rb = tf.read_item(r[1])[0]; T = rb['motion']['motionState']['transform']
        R = [T[0:3], T[4:7], T[8:11]]; t = T[12:15]
        pts = shape_points(rb['collidable']['shape'][1])
        world = [(t[0] + R[0][0] * p[0] + R[1][0] * p[1] + R[2][0] * p[2],
                  t[1] + R[0][1] * p[0] + R[1][1] * p[1] + R[2][1] * p[2],
                  t[2] + R[0][2] * p[0] + R[1][2] * p[1] + R[2][2] * p[2]) for p in pts] or [tuple(t)]
        lo = [min(p[i] for p in world) for i in range(3)]; hi = [max(p[i] for p in world) for i in range(3)]
        props = {p['key']: p['value']['data'] for p in tf.deref(rb['properties'])}
        ptype, psim, mat, parent = props[PROP_TYPE], props[PROP_SIM], props[PROP_MATERIAL], props[PROP_PARENT]
        kind = 'piece' if psim == 3 else ('base' if psim == 0 else 'proxy')
        inv = rb['motion']['inertiaAndMassInv'][3]
        bodies.append({'name': rb['name'], 'kind': kind, 'center': [(lo[i] + hi[i]) / 2 for i in range(3)],
                       'half': [max((hi[i] - lo[i]) / 2, 0.02) for i in range(3)], 'mass': (1 / inv) if inv else 0,
                       'material': mat, 'parent': names[parent] if 0 <= parent < len(names) else None,
                       'ptype': ptype, 'psim': psim})
    return bodies


if __name__ == '__main__':
    src, out = sys.argv[1], sys.argv[2]
    bodies = bodies_from_hkt(src) if src.lower().endswith('.hkt') else bodies_from_gxo(src)
    for b in bodies:
        print(f"{b['kind']:6} {b['name']:28} center={[round(x,3) for x in b['center']]} half={[round(x,3) for x in b['half']]} mass={b['mass']:.2f} verts={len(b.get('verts', []))} parent={b['parent']}")
    blob = Writer().build(bodies)
    open(out, 'wb').write(blob)
    print(f'wrote {out} ({len(blob)} bytes)')
