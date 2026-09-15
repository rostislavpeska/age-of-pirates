"""Compare a static-pose animation (constant curves, e.g. fuchuan_idle.gr2) with the model's rest skeleton:
per track prints the rest local transform and the posed one, the rotation delta as axis/angle in the bone's
rest frame, and the scale/shear matrix. Used to read the Fuchuan furled pose before copying its style.

    python gr2_pose.py model.gr2 anim.gr2 [name-substring]
"""
import sys, struct, math
import numpy as np
from gr2_read import Gr2
from gr2_dump import refs


def q2m(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def curve_const(g, cv, dim):
    """constant curve -> list of floats (None for identity)"""
    v = cv.get('CurveData')
    if not v or v[0] != 'variant' or not v[1] or not v[2]: return None
    tp, op = v[1], v[2]; fmt = g.payload[op[0]][op[1]]
    rec = g.read(*tp, *op)
    if fmt == 2: return None                                   # identity
    c = rec.get('Controls')
    if isinstance(c, tuple) and c and c[0] == 'array':          # DaConstant32f: Controls is a real32 array
        _, n, p, _ = c; return list(struct.unpack_from('<%df' % n, g.payload[p[0]], p[1]))
    if isinstance(c, tuple): return list(c)                     # D3/D4Constant32f: inline floats
    return f'<format {fmt}>'


def main():
    model, anim = Gr2(sys.argv[1]), Gr2(sys.argv[2]); filt = sys.argv[3] if len(sys.argv) > 3 else ''
    rest = {}
    for sk, _ in refs(model, model.root()['Skeletons']):
        bones = model.array(sk['Bones'])
        for i, b in enumerate(bones):
            t = b['Transform']; rest[b['Name']] = dict(par=bones[b['ParentIndex'][0]]['Name'] if b['ParentIndex'][0] >= 0 else None,
                                                       pos=np.array(t[1:4]), quat=t[4:8], ss=np.array(t[8:17]).reshape(3, 3))
    for an, _ in refs(anim, anim.root()['Animations']):
        for tg, _ in refs(anim, an['TrackGroups']):
            for t in anim.array(tg['TransformTracks']):
                n = t['Name']
                if filt and filt not in n: continue
                rot = curve_const(anim, t['OrientationCurve'], 4); pos = curve_const(anim, t['PositionCurve'], 3); ss = curve_const(anim, t['ScaleShearCurve'], 9)
                r = rest.get(n)
                line = f"{n:22} par={r['par'] if r else '?':14}"
                if r is not None:
                    line += f" rest pos=({r['pos'][0]:6.2f},{r['pos'][1]:6.2f},{r['pos'][2]:6.2f})"
                    if pos is not None: d = np.array(pos) - r['pos']; line += f" dpos=({d[0]:5.2f},{d[1]:5.2f},{d[2]:5.2f})"
                    else: line += " dpos=identity"
                    if rot is not None:
                        R = q2m(r['quat']).T @ q2m(rot)          # delta in the rest frame
                        ang = math.degrees(math.acos(max(-1, min(1, (np.trace(R) - 1) / 2))))
                        ax = np.array([R[2, 1] - R[1, 2], R[0, 2] - R[2, 0], R[1, 0] - R[0, 1]]); ax = ax / (np.linalg.norm(ax) or 1)
                        line += f" drot={ang:6.1f} deg about ({ax[0]:5.2f},{ax[1]:5.2f},{ax[2]:5.2f})"
                    else: line += " drot=identity"
                if ss is not None and not isinstance(ss, str):
                    M = np.array(ss).reshape(3, 3); line += "  scale/shear=\n" + '\n'.join('      ' + ' '.join(f'{x:7.3f}' for x in row) for row in M)
                print(line)


if __name__ == '__main__':
    main()
