"""Rest-pose Idle for the converter: a GXO animation whose every key is the model's REST local transform, read from
the model's own skeleton, optionally with a gentle vertical sine heave on listed bones (moored boats). Rendered
vertices then sit exactly where the model's vertex data puts them, for every frame; a heaved bone moves its meshes by
the heave alone.

Why not edit a converter dump of the vanilla anim: the GXO dump of homecity/china/docks01/docks01_anim.gr2 is valid only
for its first frames (frame 600: BONE_MAIN scale 1.74, translation (40, -354, 2.6); frame 1264: scale 11.2), and even
its key 0 is 0.30 m / 2.64 m off rest on the two boat roots - freezing it moved the boats away from their mesh data
(Korean HC docks01, 2026-10-17).

    python gr2_rest_anim.py MODEL.gr2 OUT.gxo --seconds 21 --fps 30 [--tracks-from REF.gxo]
                            [--heave BONE=AMPLITUDE_M[,PHASE_RAD] ...] [--cycles 1]
    python scripts/havok/converter.py --format gr2 OUT.gxo                 # -> OUT.gr2 next to it

Frame (measured on vanilla docks01 against the converter's own dump: key 0 == rest to 2e-6 on 42 of its 44 tracks, all
but the two animated boat roots):
GXO 3x3 = transpose of P^T (ScaleShear . R) P with R the column-vector rotation of the bone quaternion - the order
matters on non-uniformly scaled bones (Dock05, wokou_junk, dockpost32: R . ScaleShear is 0.40 off, ScaleShear . R
exact); translation = P^T position / 2.54 (metres), P = [[-1,0,0],[0,0,1],[0,-1,0]] (engine = P . gxo, the converter's
mirror map), z up. Heave: + A sin(2 pi cycles f / (N - 1) + phase) on the local z translation, so the
last frame equals the first (a seamless loop); N = seconds * fps + 1 frames.
Tracks: every skeleton bone, or the track list (and order) of a reference anim (GXO, or an uncompressed .gr2 anim).

NOT GAME-PROVEN for placement (Korean HC docks01, 2026-10-17): with this Idle (converter-built) the moved junks came out
misplaced or missing in three game tests although model and anim each checked exact, and the owner's accepted fix keeps
the VANILLA Idle (one track renamed with gr2_rename.py so a moved part stays static). Prefer an in-place edit of a vanilla
anim; test a converter-built Idle in game before relying on it.
"""
import argparse, math, sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gr2_read import Gr2   # noqa: E402
from gr2_dump import refs  # noqa: E402

P = np.array([[-1, 0, 0], [0, 0, 1], [0, -1, 0]], float)


def qmat(x, y, z, w):
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def rest_keys(model):
    """{bone: (3x3 row-major key matrix, translation)} in the GXO frame, plus the root bone name"""
    g = Gr2(str(model)); sk = refs(g, g.root()['Skeletons'])[0][0]; bones = g.array(sk['Bones']); out = {}
    for b in bones:
        t = b['Transform']; L = np.array(t[8:17]).reshape(3, 3) @ qmat(*t[4:8])      # ScaleShear . R (see the doc)
        out[b['Name']] = ((P.T @ L @ P).T, P.T @ np.array(t[1:4]) / 2.54)
    return out, bones[0]['Name']


def tracks_of(ref):
    """transform-track names (in order) of a reference anim: a GXO text anim or an uncompressed .gr2 anim"""
    if str(ref).lower().endswith('.gr2'):
        g = Gr2(str(ref)); names = []
        for an, _ in refs(g, g.root().get('Animations')):
            for tg, _ in refs(g, an.get('TrackGroups')):
                names += [t['Name'] for t in (g.array(tg['TransformTracks']) if tg.get('TransformTracks') else [])]
        return names
    names = []
    with open(ref, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            if line.startswith('c "'):
                names.append(line.split('"')[1])
    return names


def write(model, out, seconds, fps, tracks=None, heave=None, cycles=1.0):
    keys, root = rest_keys(model); heave = heave or {}
    tracks = tracks or list(keys)
    missing = [n for n in list(tracks) + list(heave) if n not in keys]
    assert not missing, f'not in the model skeleton: {missing}'
    assert all(h in tracks for h in heave), 'a heaved bone must be one of the tracks'
    n = int(round(seconds * fps)) + 1
    lines = [f'a {n} {fps:g}', f'cg "{root}"']
    for name in tracks:
        M, t = keys[name]; amp, phase = heave.get(name, (0.0, 0.0)); lines.append(f'c "{name}"')
        rot = ' '.join(f'{x:.9g}' for x in M.reshape(-1))
        for f in range(n):
            dz = amp * math.sin(2 * math.pi * cycles * f / (n - 1) + phase) if amp else 0.0
            lines.append(f'k {rot} {t[0]:.9g} {t[1]:.9g} {t[2] + dz:.9g}')
    Path(out).write_text('\n'.join(lines) + '\n', encoding='utf-8', newline='\n')
    return dict(frames=n, fps=fps, seconds=(n - 1) / fps, tracks=len(tracks), root=root, heave=heave)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('model'); ap.add_argument('out'); ap.add_argument('--seconds', type=float, required=True)
    ap.add_argument('--fps', type=float, default=30.0); ap.add_argument('--cycles', type=float, default=1.0)
    ap.add_argument('--tracks-from', help='reference anim (.gxo or uncompressed .gr2): use its track list and order')
    ap.add_argument('--heave', action='append', default=[], metavar='BONE=AMPLITUDE_M[,PHASE_RAD]')
    a = ap.parse_args(argv)
    heave = {}
    for h in a.heave:
        bone, v = h.split('='); amp, *ph = v.split(','); heave[bone] = (float(amp), float(ph[0]) if ph else 0.0)
    rep = write(a.model, a.out, a.seconds, a.fps, tracks_of(a.tracks_from) if a.tracks_from else None, heave, a.cycles)
    print('REST_ANIM', rep)


if __name__ == '__main__':
    main()
