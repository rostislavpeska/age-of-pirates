"""Top-view picture of a host model with an attached model drawn at each attach bone (placement + facing check).

    python attach_plot.py HOST.gr2 ATTACHED --bones bone_horse1,bone_horse2 --out view.png [--slice 0.3,1.6]

HOST is a raw .gr2 path. ATTACHED is a raw .gr2 path or an archive reference such as
units\\natives\\iroquois\\axe_rider\\axe_rider_1_horse (read from the game's BAR archives).
The host is sampled as surface points between the slice heights; the attached model is placed with each bone's rest
world matrix (rotation, scale, translation), exactly where the engine puts the attachment's origin when the bone
resolves. The arrow is the attached model's "forward": the end of its longest horizontal axis whose top is higher
(a horse's head). View = game display frame (display x = -raw x, display y = -raw z), north up.
Machine pictures are review evidence, not in-game acceptance.
"""
import argparse, os, sys
from pathlib import Path
import numpy as np


def find_repo(start):
    for p in [start, *start.parents]:
        if (p / 'scripts' / 'havok' / 'gr2_lint.py').exists():
            return p
    raise SystemExit('run from inside the Age of Pirates repository')


REPO = find_repo(Path(__file__).resolve().parent)
sys.path[:0] = [str(REPO / 'scripts' / 'havok'), str(REPO / '.claude' / 'skills' / 'aoe3de-bar-archives' / 'scripts')]
from gr2_lint import read_raw  # noqa: E402


def load(ref):
    p = Path(ref)
    if p.exists():
        return read_raw(str(p))
    import bartool
    idx = bartool.build_index(bartool.find_game_dir(None))
    rel = 'art/' + ref.replace(chr(92), '/').lower()
    e = idx.get(rel if rel.endswith('.gr2') else rel + '.gr2')
    if e is None:
        raise SystemExit(f'{ref}: not a file and not in the archives')
    tmp = Path(os.environ.get('TEMP', '/tmp')) / f'attach_plot_{os.getpid()}.gr2'
    tmp.write_bytes(bartool.read_entry(e))
    try:
        return read_raw(str(tmp))
    finally:
        tmp.unlink(missing_ok=True)


def surface_points(info, lo, hi, density=400, seed=0):
    rng = np.random.default_rng(seed); pts = []
    for m in info['render']:
        T = np.asarray(m['pos'])[:, :3][np.asarray(m['tris'])]
        A = np.linalg.norm(np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0]), axis=1) / 2
        k = np.minimum((A * density).astype(int) + 1, density)
        i = np.repeat(np.arange(len(T)), k); u = rng.random((len(i), 2)); f = u.sum(1) > 1; u[f] = 1 - u[f]
        pts.append(T[i, 0] + u[:, :1] * (T[i, 1] - T[i, 0]) + u[:, 1:] * (T[i, 2] - T[i, 0]))
    P = np.concatenate(pts)
    return P[(P[:, 1] > lo) & (P[:, 1] < hi)]


def bone_world(b):
    """rest world matrix as (R, t) acting on column vectors, from the stored row-vector inverse."""
    W = np.asarray(b['world'])                     # inv(InverseWorldTransform) in stored (row-vector) layout
    return W[:3, :3].T, W[3, :3]


def forward(H):
    ax = 0 if np.ptp(H[:, 0]) >= np.ptp(H[:, 2]) else 2
    lo, hi = H[:, ax].min(), H[:, ax].max()
    top_lo = H[H[:, ax] < lo + 0.3, 1].max(); top_hi = H[H[:, ax] > hi - 0.3, 1].max()
    f = np.zeros(3); f[ax] = 1.0 if top_hi > top_lo else -1.0
    return f


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('host'); ap.add_argument('attached')
    ap.add_argument('--bones', required=True); ap.add_argument('--out', required=True)
    ap.add_argument('--slice', default='0.3,1.6')
    a = ap.parse_args(argv)
    import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
    host, att = load(a.host), load(a.attached)
    lo, hi = (float(x) for x in a.slice.split(','))
    H = np.concatenate([np.asarray(m['pos'])[:, :3] for m in att['render']]); fwd = forward(H)
    disp = lambda P: np.stack([-P[:, 0], -P[:, 2]], 1)  # noqa: E731
    fig, ax = plt.subplots(figsize=(9, 9)); d = disp(surface_points(host, lo, hi)); ax.scatter(d[:, 0], d[:, 1], s=0.2, c='0.6')
    bones = {b['name'].lower(): b for b in host['bones']}
    for name in a.bones.split(','):
        b = bones.get(name.lower())
        if b is None:
            print(f'{name}: NOT IN {a.host}'); continue
        R, t = bone_world(b); Hw = H @ R.T + t; dh = disp(Hw)
        ax.scatter(dh[:, 0], dh[:, 1], s=0.5, label=name)
        f = disp(np.array([t, t + R @ fwd]))
        ax.annotate('', xy=f[1] + (f[1] - f[0]), xytext=f[0], arrowprops=dict(arrowstyle='->', lw=2))
        print(f'{name}: origin raw {np.round(t, 3).tolist()} forward raw {np.round(R @ fwd, 3).tolist()} '
              f'bbox raw {np.round(Hw.min(0), 2).tolist()} .. {np.round(Hw.max(0), 2).tolist()}')
    ax.set_aspect('equal'); ax.legend(); ax.set_title(f'{Path(a.host).name}: slice {lo}-{hi} m, top view (display frame)')
    plt.savefig(a.out, dpi=90); print('wrote', a.out)


if __name__ == '__main__':
    main()
