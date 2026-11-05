"""AGENTS.md rule 1 (runtime XML is CRLF; an LF-only animfile is silently ignored, ten game restarts on 2026-09-17):
the PostToolUse hook scripts/tools/hook_art_eol.py and the audit scripts/tools/check_art_eol.py, on temporary repos.

    python -m pytest scripts/tools/tests/test_art_eol.py -q

The hook runs as Claude Code runs it: a subprocess reading the hook JSON on stdin, cwd = the project. Nothing in the
real repo is written.
"""
from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
TOOLS = REPO / "scripts" / "tools"
sys.path.insert(0, str(TOOLS))

import check_art_eol as C  # noqa: E402
import hook_art_eol as H  # noqa: E402

LF_TEXT = '<?xml version="1.0"?>\n<animfile>\n  <component>x</component>\n</animfile>\n'

# every kind of file the game reads from the mod folder (rule 1) -> must end up CRLF
GAME_FILES = [
    "art/buildings/korean_tc/korean_tc.xml",         # animfile: the LF one never renders
    "art/buildings/korean_tc/korean_tc.material",
    "art/buildings/korean_tc/korean_tc.lgt",
    "sound/buildings/korean_tc_snds.xml",
    "data/tactics/zpkoreantc.tactics",
    "data/protomods.xml",
    "game/ai/core/aipiraterules.xs",
    "randmaps/zplondon.xs",
    "randmaps/zplondon.xml",
]
# never touched: not a game file, or not under a game root
OTHER_FILES = ["docs/notes.md", "scripts/tools/x.py", "art/readme.txt", "tools/config.xml", ".claude/skills/a/b.xml"]


def text_hash(b: bytes) -> str:
    return hashlib.sha256(b.replace(b"\r\n", b"\n")).hexdigest()


def hook(repo: Path, payload: dict | str, cwd: Path | None = None):
    data = payload if isinstance(payload, str) else json.dumps(payload)
    return subprocess.run([sys.executable, str(TOOLS / "hook_art_eol.py")], input=data.encode(), capture_output=True,
                          cwd=cwd or repo, timeout=60)


def write(repo: Path, rel: str, data: bytes) -> Path:
    p = repo / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(data)
    return p


def lone_lf(b: bytes) -> int:
    return b.count(b"\n") - b.count(b"\r\n")


@pytest.mark.parametrize("rel", GAME_FILES)
def test_write_of_an_lf_game_file_ends_crlf_with_the_same_text(tmp_path, rel):
    p = write(tmp_path, rel, LF_TEXT.encode())
    before = text_hash(p.read_bytes())
    r = hook(tmp_path, {"tool_name": "Write", "cwd": str(tmp_path), "tool_input": {"file_path": str(p)}})
    assert r.returncode == 0, r.stderr
    b = p.read_bytes()
    assert lone_lf(b) == 0 and b.count(b"\r\n") == 4 and b"\r\r\n" not in b
    assert text_hash(b) == before
    assert rel in r.stdout.decode() and "converted to CRLF" in r.stdout.decode()


@pytest.mark.parametrize("rel", OTHER_FILES)
def test_other_files_are_left_byte_for_byte(tmp_path, rel):
    p = write(tmp_path, rel, LF_TEXT.encode())
    r = hook(tmp_path, {"tool_name": "Write", "cwd": str(tmp_path), "tool_input": {"file_path": str(p)}})
    assert r.returncode == 0 and r.stdout == b""
    assert p.read_bytes() == LF_TEXT.encode()


def test_crlf_file_is_untouched_and_the_hook_is_silent(tmp_path):
    """the common case costs nothing: no rewrite, 0 bytes of output (hook output reaches the model's context)"""
    p = write(tmp_path, GAME_FILES[0], LF_TEXT.replace("\n", "\r\n").encode())
    mtime = p.stat().st_mtime_ns
    r = hook(tmp_path, {"tool_name": "Edit", "cwd": str(tmp_path), "tool_input": {"file_path": str(p)}})
    assert r.returncode == 0 and r.stdout == b"" and r.stderr == b""
    assert p.stat().st_mtime_ns == mtime


def test_mixed_endings_and_multiedit_paths(tmp_path):
    """an Edit that inserted LF lines into a CRLF file; MultiEdit's per-edit file paths are converted too"""
    a = write(tmp_path, "art/a.xml", b"<a>\r\n<b/>\n<c/>\r\n</a>\n")
    b = write(tmp_path, "art/b.material", b"x\ny\n")
    r = hook(tmp_path, {"tool_name": "MultiEdit", "cwd": str(tmp_path),
                        "tool_input": {"edits": [{"file_path": str(a)}, {"file_path": str(b)}, "junk"]}})
    assert r.returncode == 0, r.stderr
    assert a.read_bytes() == b"<a>\r\n<b/>\r\n<c/>\r\n</a>\r\n" and b.read_bytes() == b"x\r\ny\r\n"


def test_relative_path_resolves_against_the_project(tmp_path):
    """the settings command cd's into the project; a relative file_path is taken from there"""
    p = write(tmp_path, "art/rel.xml", b"a\nb\n")
    r = hook(tmp_path, {"tool_name": "Write", "cwd": str(tmp_path), "tool_input": {"file_path": "art/rel.xml"}})
    assert r.returncode == 0 and p.read_bytes() == b"a\r\nb\r\n"


@pytest.mark.parametrize("payload", ["", "not json", "[]", '{"tool_input": null}',
                                     '{"tool_input": {"file_path": "art/missing.xml"}}'])
def test_bad_or_empty_input_never_fails_the_tool_call(tmp_path, payload):
    r = hook(tmp_path, payload)
    assert r.returncode == 0 and r.stdout == b""


def test_a_file_on_another_drive_than_the_project_does_not_crash(tmp_path):
    """Windows: os.path.relpath raises ValueError across drives (a Write to D:\\ while the project is on C:). The
    hook must stay silent and exit 0 instead of printing a traceback into the session."""
    p = write(tmp_path, "art/x.xml", b"a\n")
    other = "Z:\\nowhere" if sys.platform == "win32" else "/"
    r = hook(tmp_path, {"tool_name": "Write", "cwd": other, "tool_input": {"file_path": str(p)}})
    assert r.returncode == 0 and b"Traceback" not in r.stderr


def test_audit_exit_codes_and_fix(tmp_path, monkeypatch, capsys):
    """check_art_eol.py: exit 1 and the file named on LF; --fix converts (text unchanged); then exit 0"""
    lf = write(tmp_path, "art/units/u.xml", LF_TEXT.encode())
    ok = write(tmp_path, "sound/s_snds.xml", LF_TEXT.replace("\n", "\r\n").encode())
    doc = write(tmp_path, "docs/d.md", b"a\nb\n")
    before = text_hash(lf.read_bytes())
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(sys, "argv", ["check_art_eol.py"])
    assert C.main() == 1
    out = capsys.readouterr().out
    assert "u.xml" in out and "s_snds.xml" not in out and "1 file(s)" in out
    monkeypatch.setattr(sys, "argv", ["check_art_eol.py", "--fix"])
    assert C.main() == 0
    assert lone_lf(lf.read_bytes()) == 0 and text_hash(lf.read_bytes()) == before
    monkeypatch.setattr(sys, "argv", ["check_art_eol.py"])
    assert C.main() == 0 and doc.read_bytes() == b"a\nb\n" and ok.read_bytes().count(b"\r\n") == 4


def test_hook_audit_and_gitattributes_agree():
    """one rule, three places: the hook, the audit and .gitattributes list the same extensions and roots"""
    assert H.EXT == C.EXT and H.ROOTS == C.ROOTS
    ga = (REPO / ".gitattributes").read_text(encoding="utf-8")
    crlf = set(re.findall(r"^\*(\.\w+)\s+text eol=crlf", ga, re.M))
    assert set(H.EXT) <= crlf, f".gitattributes lacks eol=crlf for {sorted(set(H.EXT) - crlf)}"


def test_the_hook_is_registered_for_every_file_writing_tool():
    """the automatic conversion only exists while .claude/settings.json runs the hook after Write / Edit / MultiEdit"""
    s = json.loads((REPO / ".claude" / "settings.json").read_text(encoding="utf-8"))
    groups = [g for g in s.get("hooks", {}).get("PostToolUse", [])
              if any("hook_art_eol.py" in h.get("command", "") for h in g.get("hooks", []))]
    assert groups, "hook_art_eol.py is not registered as a PostToolUse hook"
    tools = set(groups[0].get("matcher", "").split("|"))
    assert {"Write", "Edit", "MultiEdit"} <= tools
