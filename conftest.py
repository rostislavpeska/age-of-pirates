"""Repository-wide pytest plumbing (every suite under this folder picks it up).

@pytest.mark.local("steam") / local("profile") / bare local = both: the test reads the owner's machine -
the Steam install (Game/RandMaps twins, vanilla maps and groupings) or the profile folder
(RandMaps/Age3DERM*.dmp.txt, Trigger/trigtemp.xs). It runs where that folder exists and is skipped,
naming the missing folder, everywhere else. CI deselects them with -m "not local".
"""
from __future__ import annotations

import hashlib
import importlib.util
import os
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent
PROFILE = REPO.parents[2]                     # <profile>/mods/local/age-of-pirates
STEAM_GAME = Path(os.environ.get("AOE3DE_GAME") or r"C:\Program Files (x86)\Steam\steamapps\common\AoE3DE\Game")
LOCAL_NEEDS = {"steam": STEAM_GAME / "RandMaps", "profile": PROFILE / "RandMaps"}
XMB_TOOLS = REPO / ".claude" / "skills" / "aoe3de-bar-archives" / "scripts"


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


@pytest.fixture(scope="session")
def xmb_current():
    """xmb_current("data/protomods.xml"): the .xml.xmb twin decodes to the same tree as the .xml (xmbc's canon: tags,
    attributes, stripped text) - content, not mtime, which a checkout, a copy or a touch flips either way.
    Standard library only; ~0.35 s for protomods, cached per file content for the session."""
    if str(XMB_TOOLS) not in sys.path:
        sys.path.insert(0, str(XMB_TOOLS))
    import bartool
    import xmbc
    done = set()

    def check(rel):
        xml, xmb = REPO / rel, REPO / (rel + ".xmb")
        assert xmb.is_file(), f"{rel}.xmb missing - python .claude/skills/aoe3de-bar-archives/scripts/xmbc.py build {rel}"
        key = (rel, hashlib.sha1(xml.read_bytes()).digest(), hashlib.sha1(xmb.read_bytes()).digest())
        if key in done:
            return
        back = bartool.xmb_to_element(bartool.unwrap_alz4(xmb.read_bytes()))
        assert xmbc.canon(back) == xmbc.canon(ET.parse(xml).getroot()), \
            f"{rel}.xmb is stale - python .claude/skills/aoe3de-bar-archives/scripts/xmbc.py build {rel}"
        done.add(key)
    return check


@pytest.fixture
def language_twins_current():
    """language_twins_current(): scripts/tools/stringsync.py's audit - every language's stringmods.xml.xmb holds its
    rewrites plus the current English new strings. The audit compiles, so it needs the lz4 package: without it the
    call skips (call it last, after the checks that do not need it)."""
    def check():
        if importlib.util.find_spec("lz4") is None:
            pytest.skip("no lz4 package: the language-twin audit (stringsync.py) cannot compile here")
        r = subprocess.run([sys.executable, str(REPO / "scripts" / "tools" / "stringsync.py")], cwd=REPO,
                           capture_output=True, text=True, encoding="utf-8", errors="replace")
        assert r.returncode == 0, (r.stdout + r.stderr)[-1500:] + "\n-> python scripts/tools/stringsync.py --build"
    return check
