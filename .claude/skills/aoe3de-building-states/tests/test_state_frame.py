"""aoe3de-building-states: every state model shares the intact model's frame.
Synthetic cases need only numpy; the installed-model cases read the Koreans add-on, the sibling folder
../age-of-pirates-koreans (the Korean models live only there, AGENTS.md rule 15), and skip where it is absent; the
TC cases also need this repo's git history (local; the DLL route or the raw damaged twin as reference)."""
import subprocess, sys, tempfile
from pathlib import Path
import numpy as np
import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'scripts'))
import state_frame_check as SF  # noqa: E402

REPO = SF.REPO
KOREANS = REPO.parent / 'age-of-pirates-koreans'
RY90 = np.array([[0., 0., 1.], [0., 1., 0.], [-1., 0., 0.]])


def korean_art(rel):
    """the add-on's installed file; skips where the add-on is absent, fails where it is present but the file moved"""
    if not KOREANS.is_dir():
        pytest.skip(f'NOT CHECKED (a skip is not a pass): no Koreans add-on at {KOREANS} - the Korean models live only there')
    p = KOREANS / rel
    assert p.is_file(), f'{rel} not in the Koreans add-on {KOREANS} - moved? point this test at its new path'
    return p


def git_blob(rev, rel, dest):
    """rel as of commit rev of this repo, written to dest (a temp folder); skips where the clone lacks that commit"""
    r = subprocess.run(['git', '-C', str(REPO), 'show', f'{rev}:{rel}'], capture_output=True)
    if r.returncode:
        pytest.skip(f'NOT CHECKED (a skip is not a pass): {rev} not in this clone')
    dest.write_bytes(r.stdout)
    return dest


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
        d = f'art/zbench_korean_military/{k}/korean_{k}_physics'
        intact = SF.model(korean_art(f'{d}.gr2'), None)
        for state in ('_con', '_damaged'):
            assert SF.solve(intact, SF.model(korean_art(f'{d}{state}.gr2'), None), 'mata')['status'] == 'PASS', (k, state)


@pytest.mark.local
def test_regression_2026_10_08_tc_construction_turned_90_degrees_fails(tmp_path):
    """7585fc4c: korean_tc_con.gr2 written with the military axis map; the TC exports through rotate_y 90."""
    old = git_blob('7585fc4c', 'art/buildings/korean_tc/korean_tc_con.gr2', tmp_path / 'tc_con_r71.gr2')
    tc, con = korean_art('art/buildings/korean_tc/korean_tc.gr2'), korean_art('art/buildings/korean_tc/korean_tc_con.gr2')
    with tempfile.TemporaryDirectory() as w:
        # the add-on's intact TC is raw; reference() would take a compressed one through the DLL or its damaged twin
        intact, _ = SF.reference(tc, w)
        rep = SF.solve(intact, SF.model(old, w), 'mata')
        assert rep['status'] == 'FAIL' and abs(abs(rep['angle_about_engine_y_deg']) - 90) < 0.5
        assert SF.solve(intact, SF.model(con, w), 'mata')['status'] == 'PASS'


def test_compressed_intact_without_dll_falls_back_to_the_raw_damaged_twin(tmp_path, monkeypatch):
    """a PC without the Wine/WSL DLL route still checks an Oodle-compressed intact model. The add-on's Korean TC is raw
    since the move, so the specimen is AoP's last compressed TC and its raw damaged twin (05b80b68)."""
    for f in ('korean_tc.gr2', 'korean_tc_damaged.gr2'):
        git_blob('05b80b68', f'art/buildings/korean_tc/{f}', tmp_path / f)
    tc = tmp_path / 'korean_tc.gr2'
    assert SF.L.header(tc).get('compressed')
    monkeypatch.setattr(SF.L, 'dll_read', lambda *a, **k: dict(status='SKIP', why='no DLL route (test)'))
    ref, used = SF.reference(tc, tmp_path)
    assert used.name == 'korean_tc_damaged.gr2' and ref['render']
