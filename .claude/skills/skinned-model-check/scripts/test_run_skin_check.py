"""Pure-logic tests for run_skin_check.py (no Blender, no WSL; runs on Linux CI).

    python -m pytest .claude/skills/skinned-model-check/scripts -q
"""
import subprocess
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import run_skin_check as R  # noqa: E402


@pytest.mark.parametrize('registered, wanted, expected', [
    (['Ubuntu', 'docker-desktop'], None, 'Ubuntu'),                  # the converter's own setup
    (['Ubuntu-24.04', 'docker-desktop'], None, 'Ubuntu-24.04'),      # INC-195: a versioned distro name
    (['docker-desktop', 'Ubuntu-22.04', 'Ubuntu'], None, 'Ubuntu'),  # an exact name wins
    (['Ubuntu-24.04'], 'Debian', None),                              # an explicit choice must exist
    (['docker-desktop'], None, None),
])
def test_pick_distro(registered, wanted, expected):
    assert R.pick_distro(registered, wanted) == expected


def test_out_inside_the_repo_is_refused():
    r = subprocess.run([sys.executable, str(HERE / 'run_skin_check.py'), 'x.fbx', '--out', str(R.REPO / 'tmp_skin')],
                       capture_output=True, text=True)
    assert r.returncode != 0 and 'outside the repository' in r.stderr
    assert not (R.REPO / 'tmp_skin').exists()


def test_skin_check_documents_its_origin():
    text = (HERE / 'skin_check.py').read_text(encoding='utf-8')
    assert 'Majid Manzarpour' in text and 'MIT' in text
    assert (HERE.parent / 'THIRD_PARTY_NOTICES.md').is_file()
