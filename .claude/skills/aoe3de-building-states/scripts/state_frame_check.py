"""Every state model of a building must share the intact model's frame (construction, damaged, lowpoly).

    python state_frame_check.py --intact art/buildings/korean_tc/korean_tc.gr2 --state art/buildings/korean_tc/korean_tc_con.gr2 [--material mata] [--json out.json]

Pairs corners of the two SERIALIZED models that sit on the same own texture page at the same UV (a retained
surface keeps its UVs), solves the rigid transform state -> intact (Kabsch, trimmed: stacked UV islands can pair
two different walls) and requires identity on >= 80 % inliers: rotation within 1e-3, translation within 2 mm, median
inlier residual within 1 mm. A state exported through a different
frame (converter rotate_y, mirror, wrong axis map) fails with the measured angle, e.g. "90.0 deg about engine
Y". Oodle-compressed models are read through the game DLL flat route (gr2_lint.dll_read), as the lint does. Where
that route is missing (no Wine/WSL DLL setup on this PC) a compressed intact model is replaced by the building's raw
`<stem>_damaged.gr2`: the assembled damaged model shares the intact frame and own-page UVs (gr2_lint
assembled_rest_bounds; Korean TC 1,402 pairs, 99.7 % inliers) - the report names the reference actually used.
Exit 0 PASS, 1 FAIL, 2 INCONCLUSIVE (too few unique UV pairs: no retained surfaces on that page).
Found 2026-10-08: the Korean TC construction model came out 90 deg about Y from the intact TC (TC export
config rotate_y_deg 90; construction written with the military axis map), and nothing checked it.
"""
import argparse, json, sys, tempfile
from collections import defaultdict
from pathlib import Path
import numpy as np

REPO = Path(__file__).resolve().parents[4]   # .claude/skills/<skill>/scripts/<this>
sys.path.insert(0, str(REPO / 'scripts' / 'havok'))
import gr2_lint as L  # noqa: E402


def model(path, workdir):
    h = L.header(path)
    dll = None
    if h.get('compressed'):
        tdir = L.find_tools(json.loads((REPO / 'config' / 'gr2_lint_military.json').read_text(encoding='utf-8')))
        dll = L.dll_read(path, tdir, workdir)
    return L.load(path, dll)


def reference(intact, workdir):
    """(model, path actually used): the intact model, or its raw _damaged twin when the intact one is compressed and
    this PC has no DLL route."""
    intact = Path(intact)
    try:
        return model(intact, workdir), intact
    except ValueError:
        twin = intact.with_name(intact.stem + '_damaged.gr2')
        if not twin.exists() or L.header(twin).get('compressed'):
            raise
        return model(twin, workdir), twin


def corners(info, material):
    out = defaultdict(list)
    for m in info['render']:
        for gi, (mi, start, count) in enumerate(m['groups']):
            if m['mats'][gi] != material:
                continue
            for tri in m['tris'][start:start + count]:
                for v in tri:
                    out[(round(float(m['uv'][v][0]), 4), round(float(m['uv'][v][1]), 4))].append(m['pos'][v])
    return out


def solve(intact, state, material, min_pairs=50):
    A, B = corners(intact, material), corners(state, material)
    pairs = []
    for k in set(A) & set(B):
        a = np.unique(np.round(np.array(A[k], float), 4), axis=0); b = np.unique(np.round(np.array(B[k], float), 4), axis=0)
        if len(a) == 1 and len(b) == 1:
            pairs.append((b[0], a[0]))
    rep = dict(material=material, unique_uv_pairs=len(pairs))
    if len(pairs) < min_pairs:
        rep.update(status='INCONCLUSIVE', why=f'fewer than {min_pairs} unique UV pairs on {material}')
        return rep
    X = np.array([p[0] for p in pairs]); Y = np.array([p[1] for p in pairs])
    keep = np.ones(len(X), bool)
    for _ in range(6):                     # trimmed fit: stacked UV islands can pair two different walls
        cx, cy = X[keep].mean(0), Y[keep].mean(0); U, _, Vt = np.linalg.svd((X[keep] - cx).T @ (Y[keep] - cy))
        D = np.diag([1, 1, np.sign(np.linalg.det(Vt.T @ U.T))]); R = Vt.T @ D @ U.T; t = cy - R @ cx
        allres = np.linalg.norm(X @ R.T + t - Y, axis=1)
        keep = allres <= max(0.01, 3 * float(np.median(allres)))
    res = allres[keep]
    rep['inlier_fraction'] = round(float(keep.mean()), 4)
    rep.update(rotation=np.round(R, 5).tolist(), translation=np.round(t, 5).tolist(),
               angle_about_engine_y_deg=round(float(np.degrees(np.arctan2(R[0, 2], R[0, 0]))), 2),
               residual_median=float(np.median(res)), residual_max=float(res.max()),
               max_corner_distance_as_is=float(np.linalg.norm(X - Y, axis=1).max()))
    ok = rep['inlier_fraction'] >= 0.8 and np.abs(R - np.eye(3)).max() < 1e-3 and np.abs(t).max() < 2e-3 and rep['residual_median'] < 1e-3
    rep['status'] = 'PASS' if ok else 'FAIL'
    return rep


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--intact', required=True); ap.add_argument('--state', required=True)
    ap.add_argument('--material', default='mata', help='the own page both models keep (default mata)')
    ap.add_argument('--json')
    a = ap.parse_args()
    with tempfile.TemporaryDirectory() as w1, tempfile.TemporaryDirectory() as w2:
        ref, used = reference(a.intact, w1)
        if Path(used).resolve() == Path(a.state).resolve():
            rep = dict(material=a.material, unique_uv_pairs=0, status='INCONCLUSIVE',
                       why='the intact model is unreadable here and its damaged twin is the state itself')
        else:
            rep = solve(ref, model(Path(a.state), w2), a.material)
    rep.update(intact=a.intact, reference_used=str(used), state=a.state)
    if a.json:
        Path(a.json).write_text(json.dumps(rep, indent=2))
    msg = {'PASS': 'same frame', 'FAIL': f"state model is NOT in the intact frame: {rep.get('angle_about_engine_y_deg')} deg about engine Y, "
           f"translation {rep.get('translation')}, corners up to {rep.get('max_corner_distance_as_is', 0):.3f} apart as installed",
           'INCONCLUSIVE': rep.get('why')}[rep['status']]
    print(f"{rep['status']:12} {Path(a.state).name} vs {Path(rep['reference_used']).name} [{a.material}, {rep['unique_uv_pairs']} pairs, inliers {rep.get('inlier_fraction')}]: {msg}")
    sys.exit({'PASS': 0, 'FAIL': 1, 'INCONCLUSIVE': 2}[rep['status']])


if __name__ == '__main__':
    main()
