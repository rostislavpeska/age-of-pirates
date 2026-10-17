"""List every rigid body of a *_damaged.hkt with its destruction properties.
keys: 0x12A001 type (0 stage piece, 1 on-death, 6 base proxy, 7 group proxy), 0x12A002 sim (3 dynamic, 4 keyframed,
0 base), 0x12A003 material (1 stone, 2 wood, 3 metal, 4 cloth), 0x12A004 parent body index.

    python hkt_props.py file.hkt [name-substring]
"""
import sys
from hkt_read import Tagfile

KEYS = {0x12A001: 'type', 0x12A002: 'sim', 0x12A003: 'mat', 0x12A004: 'parent'}


def bodies(tf):
    root = tf.read_item(1)[0]
    for v in tf.deref(root['namedVariants']):
        pd = tf.read_item(v['variant'][1])[0]
        for sysref in tf.deref(pd['systems']):
            s = tf.read_item(sysref[1])[0]
            for k, rbref in enumerate(tf.deref(s['rigidBodies'])):
                yield k, tf.read_item(rbref[1])[0]


def props(tf, rb):
    out = {}
    p = rb.get('properties')
    for e in (tf.deref(p) if p else []):
        key = e['key']; val = e['value']
        val = val.get('data', val) if isinstance(val, dict) else val
        out[KEYS.get(key, hex(key))] = val
    return out


if __name__ == '__main__':
    tf = Tagfile(sys.argv[1]); filt = sys.argv[2] if len(sys.argv) > 2 else ''
    names = {}
    rows = [(k, rb) for k, rb in bodies(tf)]
    for k, rb in rows: names[k] = rb['name']
    for k, rb in rows:
        if filt and filt not in rb['name']: continue
        pr = props(tf, rb); par = pr.get('parent')
        m = rb['motion']; inv = m['inertiaAndMassInv']; mass = 1 / inv[3] if inv[3] else 0
        print(f"[{k:3}] {rb['name']:36} motion={m['type']} mass={mass:7.2f} type={pr.get('type')} sim={pr.get('sim')} mat={pr.get('mat')} parent={par} ({names.get(par, '-') if par is not None else '-'})")
