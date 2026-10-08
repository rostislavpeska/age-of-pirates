"""aoe3de-building-states: every state model shares the intact model's frame.
Synthetic cases need only numpy; the TC regression needs this repo's git history (local; the DLL route or the
raw damaged twin as reference)."""
import subprocess, sys, tempfile
from pathlib import Path
import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import state_frame_check as SF  # noqa: E402

REPO = SF.REPO
RY90 = np.array([[0., 0., 1.], [0., 1., 0.], [-1., 0., 0.]])


def mesh(P, UV, mat='mata'):
    n = len(P) // 3 * 3
    return {'render': [{'pos': np.asarray(P[:n], float), 'uv': np.asarray(UV[:n], float),
                        'tris': np.arange(n).reshape(-1, 3), 'groups': [(0, 0, n // 3)], 'mats': [mat]}]}


def sample(n=300, seed=1):
    rng = np.random.default_rng(seed)
    return rng.uniform(-5, 5, (n, 3)), rng.uniform(0, 1, (n, 2)).round(4)


def test_same_frame_passes():
    P, UV = sample()
    assert SF.solve(mesh(P, UV), mesh(P, UV), 'mata')['status'] == 'PASS'


def test_a_state_turned_90_degrees_fails_with_the_angle():
    P, UV = sample()
    rep = SF.solve(mesh(P @ RY90.T, UV), mesh(P, UV), 'mata')
    assert rep['status'] == 'FAIL' and abs(abs(rep['angle_about_engine_y_deg']) - 90) < 0.01


def test_stacked_uv_islands_do_not_fake_a_rotation():
    P, UV = sample()
    Q = P.copy(); Q[:20] += np.array([3.0, 0, -2.0])     # 20 corners whose UV pairs them with another wall
    rep = SF.solve(mesh(P, UV), mesh(Q, UV), 'mata')
    assert rep['status'] == 'PASS' and rep['inlier_fraction'] > 0.9


def test_no_retained_surfaces_is_inconclusive_not_pass():
    P, UV = sample(30)
    assert SF.solve(mesh(P, UV), mesh(P, UV), 'mata')['status'] == 'INCONCLUSIVE'


def test_installed_military_states_share_the_intact_frame():
    for k in ('barracks', 'stable'):
        d = REPO / 'art/zbench_korean_military' / k
        intact = SF.model(d / f'korean_{k}_physics.gr2', None)
        for state in ('_con', '_damaged'):
            assert SF.solve(intact, SF.model(d / f'korean_{k}_physics{state}.gr2', None), 'mata')['status'] == 'PASS', (k, state)


@pytest.mark.local
def test_regression_2026_10_08_tc_construction_turned_90_degrees_fails(tmp_path):
    """7585fc4c: korean_tc_con.gr2 written with the military axis map; the TC exports through rotate_y 90."""
    r = subprocess.run(['git', '-C', str(REPO), 'show', '7585fc4c:art/buildings/korean_tc/korean_tc_con.gr2'], capture_output=True)
    if r.returncode:
        pytest.skip('7585fc4c not in this clone')
    old = tmp_path / 'tc_con_r71.gr2'; old.write_bytes(r.stdout)
    with tempfile.TemporaryDirectory() as w:
        # Oodle-compressed intact: DLL flat route, or the raw damaged twin on a PC without that route
        intact, _ = SF.reference(REPO / 'art/buildings/korean_tc/korean_tc.gr2', w)
        rep = SF.solve(intact, SF.model(old, w), 'mata')
        assert rep['status'] == 'FAIL' and abs(abs(rep['angle_about_engine_y_deg']) - 90) < 0.5
        assert SF.solve(intact, SF.model(REPO / 'art/buildings/korean_tc/korean_tc_con.gr2', w), 'mata')['status'] == 'PASS'


def test_compressed_intact_without_dll_falls_back_to_the_raw_damaged_twin(tmp_path, monkeypatch):
    """a PC without the Wine/WSL DLL route still checks the Korean TC (its intact GR2 is Oodle-compressed)."""
    tc = REPO / 'art/buildings/korean_tc/korean_tc.gr2'
    if not tc.exists():
        pytest.skip('Korean TC not in this checkout')
    monkeypatch.setattr(SF.L, 'dll_read', lambda *a, **k: dict(status='SKIP', why='no DLL route (test)'))
    ref, used = SF.reference(tc, tmp_path)
    assert used.name == 'korean_tc_damaged.gr2' and ref['render']
