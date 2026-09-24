"""scripts/tools/sync_local_maps.py on temporary folders: a fake repo with a map (.xs, .xml, .mods.xml) and a fake
Game/RandMaps. The repo copy always wins; a .mods.xml never reaches the game root; the hook syncs only the edited
map's entry. No game install needed."""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "scripts" / "tools"))

import sync_local_maps as S  # noqa: E402

ENTRY = {"repo": "randmaps/zplondon", "local": "00000_zplondon"}


def _repo(tmp_path):
    repo, rm = tmp_path / "repo", tmp_path / "RandMaps"
    (repo / "randmaps").mkdir(parents=True)
    rm.mkdir()
    (repo / "randmaps" / "zplondon.xs").write_bytes(b"void main() {}\r\n")
    (repo / "randmaps" / "zplondon.xml").write_bytes(b"<mapinfo/>\r\n")
    (repo / "randmaps" / "zplondon.mods.xml").write_bytes(b"<mods/>\r\n")
    return repo, rm


def test_missing_then_synced_then_ok(tmp_path):
    repo, rm = _repo(tmp_path)
    assert [r["state"] for r in S.status([ENTRY], rm, repo)] == ["MISSING", "MISSING"]
    S.sync([ENTRY], rm, repo)
    assert sorted(p.name for p in rm.iterdir()) == ["00000_zplondon.xml", "00000_zplondon.xs"]   # no .mods.xml
    assert (rm / "00000_zplondon.xs").read_bytes() == b"void main() {}\r\n"
    assert [r["state"] for r in S.status([ENTRY], rm, repo)] == ["OK", "OK"]


def test_the_repo_wins_over_a_stale_copy(tmp_path):
    repo, rm = _repo(tmp_path)
    S.sync([ENTRY], rm, repo)
    (repo / "randmaps" / "zplondon.xs").write_bytes(b"void main() { edited on another device }\r\n")
    (rm / "00000_zplondon.xml").write_bytes(b"<local edit/>")
    assert [r["state"] for r in S.status([ENTRY], rm, repo)] == ["STALE", "STALE"]
    rows = S.sync([ENTRY], rm, repo)
    assert [r["state"] for r in rows] == ["SYNCED", "SYNCED"]
    assert (rm / "00000_zplondon.xs").read_bytes() == (repo / "randmaps" / "zplondon.xs").read_bytes()
    assert (rm / "00000_zplondon.xml").read_bytes() == b"<mapinfo/>\r\n"


def test_hook_syncs_only_the_edited_map(tmp_path):
    repo, rm = _repo(tmp_path)
    (repo / "randmaps" / "zpparis.xs").write_bytes(b"paris\r\n")
    other = {"repo": "randmaps/zpparis", "local": "0000_paris"}
    edit = {"tool_name": "Edit", "tool_input": {"file_path": str(repo / "randmaps" / "zplondon.xs")}}
    S.hook(edit, [ENTRY, other], rm, repo)
    assert sorted(p.name for p in rm.iterdir()) == ["00000_zplondon.xml", "00000_zplondon.xs"]
    assert S.hook({"tool_input": {"file_path": str(repo / "README.md")}}, [ENTRY, other], rm, repo) == []
    assert S.hook({"tool_input": {"file_path": str(tmp_path / "elsewhere" / "x.xs")}}, [ENTRY], rm, repo) == []


def test_registry_is_created_from_the_example(tmp_path):
    ex, loc = tmp_path / "local-maps.example.json", tmp_path / "local-maps.local.json"
    ex.write_text(json.dumps({"maps": [ENTRY]}), encoding="utf-8")
    assert S.load_registry(loc, ex)["maps"] == [ENTRY] and loc.is_file()
    loc.write_text(json.dumps({"maps": [{"repo": "randmaps/zplondon.xs", "local": "x"}]}), encoding="utf-8")
    try:
        S.load_registry(loc, ex)
    except ValueError as e:
        assert "stems" in str(e)
    else:
        raise AssertionError("an entry with an extension must be refused")


def test_the_tracked_example_pairs_london_with_the_conftest_twin():
    # conftest.steam_twin and the London tests compare randmaps/zplondon.xs with Game/RandMaps/00000_zplondon.xs
    ex = json.loads(S.EXAMPLE.read_text(encoding="utf-8"))
    assert ENTRY in ex["maps"]
