"""In-place patcher for AoE3DE Havok 2018 tagfiles (*_damaged.hkt).

Rewrites fixed-size fields inside hkpRigidBody records without re-serializing
the file. Safe because the TAG0 container carries no checksum and every field
touched here has a fixed size and offset given by the file's own type table.

Usage:
  python hkt_patch.py IN OUT --freeze [REGEX]        dynamic pieces -> keyframed (never fall)
  python hkt_patch.py IN OUT --prop KEY=VAL [REGEX]  set an hkSimpleProperty value (KEY hex/dec)
  python hkt_patch.py IN OUT --velocity X,Y,Z [REGEX] initial linear velocity on matching bodies
  python hkt_patch.py IN OUT --mass FACTOR [REGEX]   scale mass (inverse mass /= FACTOR)
REGEX (optional, last) restricts the change to bodies whose name matches.
"""
import re, struct, sys
from hkt_read import Tagfile

PROP_TYPE, PROP_SIM, PROP_MATERIAL, PROP_PARENT = 0x12A001, 0x12A002, 0x12A003, 0x12A004


class Patcher:
    def __init__(self, path):
        self.tf = Tagfile(path)
        self.buf = bytearray(self.tf.data)
        self.base = self.tf.secs['DATA'][0]          # DATA section start in the file
        self.changed = 0

    # -- type-table navigation -------------------------------------------------
    def member(self, ti, path):
        """('motion.motionState.transform') -> (offset within record, member type index)"""
        off = 0
        for part in path.split('.'):
            for name, _fl, moff, mti in self.tf.all_members(self.tf.resolved(ti)):
                if name == part:
                    off += moff; ti = mti; break
            else:
                raise KeyError(f'{part} not in {self.tf.tname(ti)}')
        return off, ti

    # -- raw writers (absolute file offsets) -----------------------------------
    def w(self, fmt, off, *vals):
        struct.pack_into(fmt, self.buf, self.base + off, *vals); self.changed += 1

    # -- bodies ----------------------------------------------------------------
    def bodies(self):
        tf = self.tf
        root = tf.read_item(1)[0]
        pd = tf.read_item(tf.deref(root['namedVariants'])[0]['variant'][1])[0]
        for sysref in tf.deref(pd['systems']):
            s = tf.read_item(sysref[1])[0]
            for k, rbref in enumerate(tf.deref(s['rigidBodies'])):
                ti, _fl, off, _cnt = tf.items[rbref[1]]
                rb = tf.read_item(rbref[1])[0]
                yield k, rb['name'], ti, off, rb

    def props(self, rb):
        """-> list of (key, value, absolute DATA offset of the u64 value)"""
        arr = rb['properties']
        if arr[1] == 0: return []
        _ti, _fl, off, cnt = self.tf.items[arr[1]]
        out = []
        for i in range(cnt):
            key = struct.unpack_from('<I', self.buf, self.base + off + i*12)[0]
            val = struct.unpack_from('<q', self.buf, self.base + off + i*12 + 4)[0]
            out.append((key, val, off + i*12 + 4))
        return out

    # -- operations ------------------------------------------------------------
    def freeze(self, rx):
        """dynamic (sim 3) -> keyframed (sim 4): the piece is placed but never simulated"""
        for k, name, ti, off, rb in self.bodies():
            if rx and not re.search(rx, name): continue
            props = {key: (val, poff) for key, val, poff in self.props(rb)}
            if props.get(PROP_SIM, (None,))[0] != 3: continue
            self.w('<q', props[PROP_SIM][1], 4)
            mo, _ = self.member(ti, 'motion.type');                          self.w('<B', off + mo, 4)
            mo, _ = self.member(ti, 'motion.deactivationNumInactiveFrames'); self.w('<HH', off + mo, 0, 0)
            mo, _ = self.member(ti, 'motion.motionState.deactivationClass'); self.w('<B', off + mo, 1)
            mo, _ = self.member(ti, 'motion.inertiaAndMassInv');             self.w('<4f', off + mo, 0, 0, 0, 0)
            mo, _ = self.member(ti, 'collidable.broadPhaseHandle.objectQualityType'); self.w('<b', off + mo, 1)
            print(f'  froze [{k}] {name}')

    def set_prop(self, key, val, rx):
        for k, name, ti, off, rb in self.bodies():
            if rx and not re.search(rx, name): continue
            for pk, pv, poff in self.props(rb):
                if pk == key and pv != val:
                    self.w('<q', poff, val); print(f'  [{k}] {name}: {key:#x} {pv} -> {val}')

    def velocity(self, v, rx):
        for k, name, ti, off, rb in self.bodies():
            if rx and not re.search(rx, name): continue
            if rb['motion']['type'] != 3: continue
            mo, _ = self.member(ti, 'motion.linearVelocity'); self.w('<4f', off + mo, *v, 0.0)
            print(f'  [{k}] {name}: linearVelocity={v}')

    def mass(self, factor, rx):
        for k, name, ti, off, rb in self.bodies():
            if rx and not re.search(rx, name): continue
            inv = rb['motion']['inertiaAndMassInv']
            if inv[3] == 0: continue
            mo, _ = self.member(ti, 'motion.inertiaAndMassInv')
            self.w('<4f', off + mo, *(x / factor for x in inv))
            print(f'  [{k}] {name}: mass {1/inv[3]:.3f} -> {factor/inv[3]:.3f}')

    def save(self, path):
        open(path, 'wb').write(self.buf)
        print(f'{self.changed} field writes -> {path}')


if __name__ == '__main__':
    a = sys.argv[1:]
    if len(a) < 3: print(__doc__); sys.exit(1)
    p = Patcher(a[0]); op = a[2]; rest = a[3:]
    if op == '--freeze':
        p.freeze(rest[0] if rest else None)
    elif op == '--prop':
        key, val = rest[0].split('='); p.set_prop(int(key, 0), int(val, 0), rest[1] if len(rest) > 1 else None)
    elif op == '--velocity':
        p.velocity(tuple(float(x) for x in rest[0].split(',')), rest[1] if len(rest) > 1 else None)
    elif op == '--mass':
        p.mass(float(rest[0]), rest[1] if len(rest) > 1 else None)
    else:
        print(__doc__); sys.exit(1)
    p.save(a[1])
