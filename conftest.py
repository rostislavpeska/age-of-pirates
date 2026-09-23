"""Repository-wide pytest plumbing (every suite under this folder picks it up).

@pytest.mark.local("steam") / local("profile") / bare local = both: the test reads the owner's machine -
the Steam install (Game/RandMaps twins, vanilla maps and groupings) or the profile folder
(RandMaps/Age3DERM*.dmp.txt, Trigger/trigtemp.xs). It runs where that folder exists and is skipped,
naming the missing folder, everywhere else. CI deselects them with -m "not local".
"""
from __future__ import annotations

import os
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent
PROFILE = REPO.parents[2]                     # <profile>/mods/local/age-of-pirates
STEAM_GAME = Path(os.environ.get("AOE3DE_GAME") or r"C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\Game")
LOCAL_NEEDS = {"steam": STEAM_GAME / "RandMaps", "profile": PROFILE / "RandMaps"}


def pytest_runtest_setup(item):
    for mark in item.iter_markers(name="local"):
        for need in mark.args or ("steam", "profile"):
            path = LOCAL_NEEDS[need]
            if not path.is_dir():
                pytest.skip(f"local ({need}): needs {path} - the owner's machine only")


@pytest.fixture
def steam_twin():
    """steam_twin(repo_file, name): byte identity with Game/RandMaps/<name> of the Steam install. Skips where that
    copy is absent, so call it AFTER a test's repo-side assertions - those then still run everywhere."""
    def check(repo_file, name):
        twin = STEAM_GAME / "RandMaps" / name
        if not twin.is_file():
            pytest.skip(f"local (steam): no {twin} - every repo-side assertion before this line passed")
        assert Path(repo_file).read_bytes() == twin.read_bytes(), f"{twin} differs from {repo_file} - copy the repo file over"
    return check
