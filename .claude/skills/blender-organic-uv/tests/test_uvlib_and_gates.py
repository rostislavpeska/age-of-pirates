"""uvlib metrics against analytic answers, the bone-region estimator and the gate checker (pure Python + numpy; no
Blender, CI-safe).

    python -B -m pytest .claude/skills/blender-organic-uv/tests -q -p no:cacheprovider
"""
import json
import math
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest

TESTS = Path(__file__).resolve().parent
SCRIPTS = TESTS.parent / 'scripts'
sys.path[:0] = [str(SCRIPTS), str(TESTS)]
import uv_gates as G  # noqa: E402
import uvlib as L  # noqa: E402

PAGE = 1024


def grid(n, uvf, tri=True):
    """1 x 1 plane in XZ facing -Y, n x n quads split into triangles; uvf(x, z) -> (u, v)."""
    P, F = [], []
    idx = {}
    for i in range(n + 1):
        for j in range(n + 1):
            idx[(i, j)] = len(P)
            P.append((i / n - 0.5, 0.0, j / n))
    for i in range(n):
        for j in range(n):
            q = [idx[(i, j)], idx[(i + 1, j)], idx[(i + 1, j + 1)], idx[(i, j + 1)]]
            F += [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]
    P, F = np.array(P, float), np.array(F, int)
    UV = np.array([[uvf(P[v][0], P[v][2]) for v in f] for f in F], float)
    return P, F, UV


def page_l2(P, F, UV):
    fm = L.face_metrics(P, F, UV, PAGE)
    ok, A3 = fm['ok'], fm['area3d']
    return math.sqrt(float((fm['L2'][ok] ** 2 * A3[ok]).sum() / A3[ok].sum())) * fm['k'], \
        float(fm['Gamma'][ok].max() * fm['k']), fm


def test_isometric_plane_is_ideal():
    P, F, UV = grid(4, lambda x, z: (0.25 + 0.5 * (x + 0.5), 0.25 + 0.5 * z))
    l2, linf, fm = page_l2(P, F, UV)
    assert l2 == pytest.approx(1.0) and linf == pytest.approx(1.0)
    assert np.allclose(fm['aniso'], 1.0) and np.allclose(fm['density'], 512.0)
    assert not fm['flipped'].any()


def test_anisotropic_plane_matches_sander_formulas():
    P, F, UV = grid(4, lambda x, z: (0.1 + 0.5 * (x + 0.5), 0.1 + 0.25 * z))
    l2, linf, fm = page_l2(P, F, UV)
    assert l2 == pytest.approx(math.sqrt(5 / 4), rel=1e-6)
    assert linf == pytest.approx(math.sqrt(2), rel=1e-6)
    assert np.allclose(fm['aniso'], 2.0)
    assert np.allclose(fm['density'], PAGE * math.sqrt(0.125))


def test_mirrored_uv_is_flipped():
    P, F, UV = grid(1, lambda x, z: (0.5 - 0.4 * x, 0.1 + 0.4 * z))
    fm = L.face_metrics(P, F, UV, PAGE)
    assert fm['flipped'].all()


def test_seams_islands_gaps_and_overlaps():
    # two quads sharing the edge x = 0, separate UV islands 3 texels apart
    P = np.array([(-1, 0, 0), (0, 0, 0), (0, 0, 1), (-1, 0, 1), (1, 0, 0), (1, 0, 1)], float)
    F = np.array([[0, 1, 2], [0, 2, 3], [1, 4, 5], [1, 5, 2]])
    g = 3.0 / PAGE
    Lf = lambda x, z: (0.05 + 0.25 * (x + 1), 0.05 + 0.25 * z)  # noqa: E731
    Rf = lambda x, z: (0.30 + g + 0.5 * x, 0.05 + 0.5 * z)  # noqa: E731
    UV = np.array([[Lf(P[v][0], P[v][2]) for v in f] for f in F[:2]] +
                  [[Rf(P[v][0], P[v][2]) for v in f] for f in F[2:]])
    real = {(0, 1), (1, 2), (2, 3), (0, 3), (1, 4), (4, 5), (2, 5)}
    edges = L.edge_table(F, UV, real_edges=real)
    kinds = [e['kind'] for e in edges]
    assert kinds.count('seam') == 1 and kinds.count('diagonal') == 2
    lab = L.islands(len(F), edges)
    assert len(set(lab)) == 2
    seg, sid = L.outline_segments(edges, lab)
    gaps = L.island_gaps(seg, sid)
    assert min(v[0] for v in gaps.values()) * PAGE == pytest.approx(3.0, abs=1e-6)
    sq = lambda x0, y0, s: [[(x0, y0), (x0 + s, y0), (x0 + s, y0 + s)], [(x0, y0), (x0 + s, y0 + s), (x0, y0 + s)]]  # noqa
    UV2 = np.array(sq(0.1, 0.1, 0.4) + sq(0.2, 0.2, 0.4), float)
    ov = L.tri_overlaps(UV2, 1e-12)
    assert sum(a for _, _, a in ov) == pytest.approx(0.3 * 0.3, rel=1e-6)


def test_raster_cover_and_orientation():
    P, F, UV = grid(2, lambda x, z: (0.1 + 0.5 * z, 0.6 - 0.5 * (x + 0.5)))       # up -> +U
    edges = L.edge_table(F, UV)
    lab = L.islands(len(F), edges)
    unit, w = L.up_in_uv(P, F, UV)
    (ang, coh, _), = L.island_orientation(unit, w, lab, 1)
    assert ang == pytest.approx(90.0) and coh == pytest.approx(1.0)
    P, F, UV = grid(2, lambda x, z: (0.5 * (x + 0.5), 0.5 * z))
    cnt, first, multi = L.raster_cover(UV, np.zeros(len(F), int), 64)
    assert int((cnt > 0).sum()) == 32 * 32 and not multi.any()


def test_bone_regions_and_tie_rule():
    assert L.bone_region('Bip01_Head') == 'head' and L.bone_region('Bip01 L Hand') == 'hands'
    assert L.bone_region('bone_handle') == 'weapon' and L.bone_region('Bip01_L_Calf') == 'legs'
    assert L.bone_region('Root') == 'other' and L.bone_region(None) == 'none'
    W = [[('Bip01_Spine1', 0.65), ('Bip01_Head', 0.35)], [('Bip01_Head', 0.8), ('Bip01_Spine1', 0.2)]]
    # exact tie (0.65 + 0.2 + 0.65 = 0.35 + 0.8 + 0.35): the bone met first wins, walking corners heaviest first
    assert L.dominant_bone([0, 1, 0], W) == 'Bip01_Spine1'
    assert L.dominant_bone([1, 0, 0], W) == 'Bip01_Head'
    W32 = [[('Bip01_Spine1', 0.6499999761581421), ('Bip01_Head', 0.3499999940395355)],
           [('Bip01_Head', 0.800000011920929), ('Bip01_Spine1', 0.20000000298023224)]]
    assert L.dominant_bone([0, 1, 0], W32) == 'Bip01_Spine1'       # float32 noise (4e-8) is still a tie
    assert L.dominant_bone([2], [[], [], []]) is None


def test_region_densities_ratio():
    P, F, UV = grid(2, lambda x, z: (0.5 * (x + 0.5), 0.5 * z))
    regions = ['head' if P[f].mean(0)[2] > 0.5 else 'torso' for f in F]
    UV = UV.copy()
    for t, rg in enumerate(regions):
        if rg == 'head':
            UV[t] = 0.6 + (UV[t] - 0.25) * 1.3                    # head triangles 1.3x linear density
    d = L.region_densities(P, F, UV, PAGE, regions)
    assert d['torso']['density_t_per_m'] == pytest.approx(512.0)
    assert L.region_ratio(d) == pytest.approx(1.3)


# ---------------------------------------------------------------- gates
PROFILE = {'schema': G.SCHEMA, 'name': 'test', 'checks': [
    {'id': 'flips', 'run': 'page', 'metric': 'flips.flipped_faces', 'hard': {'max': 0}, 'target': {'max': 0}},
    {'id': 'gap', 'run': 'page', 'metric': 'packing.min_island_gap_px', 'hard': {'min': 8}, 'target': {'min': 16}},
    {'id': 'head', 'run': 'body', 'metric': 'bone_regions.head_torso', 'hard': None, 'target': {'min': 1.25, 'max': 1.35}},
]}


def metrics(flips=0, gap=16.5, head=1.3):
    return {'flips': {'flipped_faces': flips}, 'packing': {'min_island_gap_px': gap},
            'bone_regions': {'head_torso': head}}


def test_gates_pass_fail_and_missing():
    r = G.evaluate(PROFILE, {'page': metrics(), 'body': metrics()})
    assert r['hard_pass'] and not r['targets_missed']
    r = G.evaluate(PROFILE, {'page': metrics(gap=10.0), 'body': metrics(head=1.12)})
    assert r['hard_pass'] and r['targets_missed'] == ['gap', 'head']
    r = G.evaluate(PROFILE, {'page': metrics(flips=2), 'body': metrics()})
    assert not r['hard_pass'] and r['rows'][0]['status'] == 'FAIL'
    r = G.evaluate(PROFILE, {'page': metrics()})                  # body run missing: head is a target only
    assert r['hard_pass'] and r['rows'][2]['status'] == 'n/a'
    r = G.evaluate(PROFILE, {'body': metrics()})                  # page run missing: hard checks are MISSING
    assert not r['hard_pass'] and r['rows'][0]['status'] == 'MISSING'
    with pytest.raises(SystemExit):
        G.evaluate({'schema': 'other', 'checks': []}, {})


def test_template_profile_is_valid():
    prof = json.loads((TESTS.parent / 'profiles' / 'template_unit_body.json').read_text(encoding='utf-8'))
    assert prof['schema'] == G.SCHEMA
    ids = [c['id'] for c in prof['checks']]
    assert len(ids) == len(set(ids))
    for c in prof['checks']:
        assert c['run'] in prof['runs'] and c['metric'] and c.get('evidence')
        assert c['hard'] or c['target'] or c['evidence'].startswith('information')
    r = G.evaluate(prof, {'page': metrics(), 'body': metrics()})
    assert r['rows'][0]['status'] == 'PASS'


def test_gate_cli_exit_codes_and_refusal(tmp_path):
    run = tmp_path / 'run'
    run.mkdir()
    (run / 'metrics.json').write_text(json.dumps(metrics()), encoding='utf-8')
    prof = tmp_path / 'p.json'
    prof.write_text(json.dumps(PROFILE), encoding='utf-8')
    cmd = [sys.executable, '-B', str(SCRIPTS / 'uv_gates.py'), '--profile', str(prof), '--run', 'page=%s' % run,
           '--run', 'body=%s' % run]
    r = subprocess.run(cmd + ['--out', str(tmp_path / 'g.json')], capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr
    assert json.loads((tmp_path / 'g.json').read_text())['hard_pass']
    (run / 'metrics.json').write_text(json.dumps(metrics(flips=1)), encoding='utf-8')
    assert subprocess.run(cmd, capture_output=True, text=True).returncode == 1
    inside = TESTS / '_refused_gates.json'
    r = subprocess.run(cmd + ['--out', str(inside)], capture_output=True, text=True)
    assert r.returncode == 2 and 'git work tree' in r.stderr and not inside.exists()
