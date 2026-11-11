"""Structural dump of a .gr2: skeletons, meshes (vertex layout, bone bindings, skinning),
models (mesh bindings) and animations (track groups, per-bone tracks with curve formats).

    python gr2_dump.py file.gr2 [--bones] [--tracks]
"""
import sys
from gr2_read import Gr2, COMP

# granny_curve_data_format (CurveDataHeader.Format)
CURVE_FMT = {0: 'Keyframes32f', 1: 'K32fC32f', 2: 'Identity', 3: 'Constant32f', 4: 'D3Constant32f',
             5: 'D4Constant32f', 6: 'K16uC16u', 7: 'K8uC8u', 8: 'D4nK16uC15u', 9: 'D4nK8uC7u',
             10: 'D3K16uC16u', 11: 'D3K8uC8u', 12: 'D9I1K16uC16u', 13: 'D9I3K16uC16u', 14: 'D9I1K8uC8u',
             15: 'D9I3K8uC8u', 16: 'D3I1K32fC32f', 17: 'D3I1K16uC16u', 18: 'D3I1K8uC8u'}


def refs(g, arr):
    """('refarray', n, (sec,off), tref) -> list of (record, (sec,off))"""
    if not arr or arr[0] != 'refarray': return []
    _, n, p, tref = arr
    out = []
    for i in range(n):
        sp = g.deref(p[0], p[1] + i * g.ptr)
        out.append((g.read(*tref, *sp), sp))
    return out


def curve_info(g, cv):
    """inline granny_curve2 record -> 'Format[knots]'"""
    v = cv.get('CurveData')
    if not v or v[0] != 'variant' or not v[1] or not v[2]: return 'none'
    tp, op = v[1], v[2]
    rec = g.read(*tp, *op)
    fmt = g.payload[op[0]][op[1]]            # CurveDataHeader.Format is the first uint8 of every curve data struct
    name = CURVE_FMT.get(fmt, str(fmt))
    counts = [f"{k}={v[1]}" for k, v in rec.items() if isinstance(v, tuple) and v and v[0] == 'array']
    if fmt in (3, 4, 5) and isinstance(rec.get('Controls'), tuple) and rec['Controls'] and not isinstance(rec['Controls'][0], str):
        counts = ['(' + ','.join(f'{x:.3g}' for x in rec['Controls']) + ')']   # inline constant controls
    return name + ('[' + ','.join(counts) + ']' if counts else '')


def main():
    path = sys.argv[1]; show_bones = '--bones' in sys.argv; show_tracks = '--tracks' in sys.argv
    g = Gr2(path); r = g.root()
    print(f"{path}: crc ok {g.crc_check()}; sections " + ' '.join(f"{i}:{s['data_size']}" for i, s in enumerate(g.sections) if s['data_size']))
    print('root:', r.get('FromFileName'))

    skel_names = {}
    for sk, sp in refs(g, r.get('Skeletons')):
        bones = g.array(sk['Bones']); skel_names[sp] = sk['Name']
        print(f"\nskeleton '{sk['Name']}': {len(bones)} bones")
        if show_bones:
            for i, b in enumerate(bones):
                t = b['Transform']
                print(f"  {i:3} {b['Name']:34} par={b['ParentIndex'][0]:3} pos=({t[1]:.2f},{t[2]:.2f},{t[3]:.2f})")

    mesh_names = {}
    for m, mp in refs(g, r.get('Meshes')):
        mesh_names[mp] = m['Name']
        vd = m.get('PrimaryVertexData'); comps = []; nverts = 0; bbox = ''
        if vd and vd[0] == 'ref' and vd[1]:
            vrec = g.read(*vd[2], *vd[1]); va = vrec.get('Vertices')
            if va and va[0] == 'varray' and va[1]:
                comps = [x['name'] for x in g.typedef(*va[1])]; nverts = va[2]
                if va[3] and nverts and comps and comps[0] == 'Position':      # Position is real32[3] at offset 0 of every vertex
                    stride = g.struct_size(*va[1]); buf = g.payload[va[3][0]]; base = va[3][1]
                    import struct as _s
                    pts = [_s.unpack_from('<3f', buf, base + i * stride) for i in range(nverts)]
                    lo = [min(p[k] for p in pts) for k in range(3)]; hi = [max(p[k] for p in pts) for k in range(3)]
                    bbox = ' bbox ' + ' '.join(f'{a:.1f}..{b:.1f}' for a, b in zip(lo, hi))
        bb = g.array(m['BoneBindings']) if m.get('BoneBindings') else []
        kind = 'SKINNED (weights)' if 'BoneWeights' in comps else ('indexed (1 bone/vertex)' if 'BoneIndices' in comps else 'rigid')
        print(f"\nmesh '{m['Name']}': {nverts} verts, {kind}{bbox}, components {comps}")
        print(f"  bound to {len(bb)} bone(s): {[b['BoneName'] for b in bb][:40]}{' ...' if len(bb) > 40 else ''}")

    for mo, _ in refs(g, r.get('Models')):
        sk = mo.get('Skeleton'); mb = g.array(mo['MeshBindings']) if mo.get('MeshBindings') else []
        names = []
        for b in mb:
            mr = b.get('Mesh'); names.append(mesh_names.get(mr[1], '?') if mr and mr[0] == 'ref' else '?')
        print(f"\nmodel '{mo['Name']}': skeleton {skel_names.get(sk[1], '?') if sk and sk[0]=='ref' else None}, meshes {names}")

    for an, _ in refs(g, r.get('Animations')):
        print(f"\nanimation '{an['Name']}': duration {an['Duration'][0]:.3f}s timestep {an['TimeStep'][0]:.4f} oversampling {an['Oversampling'][0]}")
        for tg, _ in refs(g, an.get('TrackGroups')):
            tt = g.array(tg['TransformTracks']) if tg.get('TransformTracks') else []
            vt = tg['VectorTracks'][1] if tg.get('VectorTracks') and tg['VectorTracks'][0] == 'array' else 0
            tx = tg['TextTracks'][1] if tg.get('TextTracks') and tg['TextTracks'][0] == 'array' else 0
            print(f"  trackgroup '{tg['Name']}': {len(tt)} transform tracks, {vt} vector tracks, {tx} text tracks, flags {tg.get('Flags')}")
            if show_tracks:
                for t in tt:
                    print(f"    {t['Name']:34} rot {curve_info(g, t['OrientationCurve']):24} pos {curve_info(g, t['PositionCurve']):24} scl {curve_info(g, t['ScaleShearCurve'])}")
            else:
                anim = [t['Name'] for t in tt if 'Identity' not in curve_info(g, t['OrientationCurve']) or 'Identity' not in curve_info(g, t['PositionCurve'])]
                print(f"    animated (non-identity) tracks: {len(anim)}: {anim[:60]}{' ...' if len(anim) > 60 else ''}")


if __name__ == '__main__':
    main()
