"""scripts/tools/local_env.py on temporary folders (env file parsing, precedence, $VARIABLE expansion, --init, the
check), plus the guard behind AGENTS.md "Local environment": no tracked file carries a device path - a user folder
(C:/Users/<name>), the old ~/Documents/WORKSPACE default or a Claude project slug of one user. Historical records
(briefs, plans, captured samples, converter outputs) are listed exclusions. No game install needed."""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "scripts" / "tools"))

import local_env as E  # noqa: E402

KEYS = ("AOP_KOREAN_REPO", "AOP_TASKS_DIR", "AOP_KOREAN_ASSETS", "AOP_AITEST_DIR", "GR2_LINT_SPECIMENS")


@pytest.fixture(autouse=True)
def clean_env(monkeypatch, tmp_path):
    for k in KEYS:
        monkeypatch.delenv(k, raising=False)
    monkeypatch.setenv("CLAUDE_CONFIG_DIR", str(tmp_path / "claude-config"))


def fake_repo(tmp_path, env_text=None):
    repo = tmp_path / "repo"
    for local, example, _who in E.LOCAL_FILES:
        src = REPO / example
        dst = repo / example
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes(src.read_bytes())
    if env_text is not None:
        (repo / "config" / "aop.local.env").write_bytes(env_text.encode("utf-8"))
    return repo


def test_env_file_parsing(tmp_path):
    p = tmp_path / "x.env"
    p.write_bytes("\ufeff# c\r\nA=C:/one two\r\n\r\nB=\"q\"\r\nC=\r\nD=x=y".encode("utf-8"))
    assert E.read_env_file(p) == {"A": "C:/one two", "B": "q", "C": "", "D": "x=y"}
    assert E.read_env_file(tmp_path / "absent.env") == {}


def test_environment_wins_over_the_file(tmp_path, monkeypatch):
    repo = fake_repo(tmp_path, "AOP_KOREAN_REPO=%s/k\n" % tmp_path.as_posix())
    assert E.value("AOP_KOREAN_REPO", str(repo)) == "%s/k" % tmp_path.as_posix()
    monkeypatch.setenv("AOP_KOREAN_REPO", "Z:/env")
    assert E.value("AOP_KOREAN_REPO", str(repo)) == "Z:/env"
    assert E.value("AOP_AITEST_DIR", str(repo)) is None


def test_expand_names_what_is_not_set(tmp_path):
    repo = fake_repo(tmp_path, "AOP_KOREAN_REPO=K:/repo/\n")
    assert E.expand("$AOP_KOREAN_REPO/research/x.py", str(repo)) == ("K:/repo/research/x.py", [])
    assert E.expand("${AOP_KOREAN_REPO}/a", str(repo)) == ("K:/repo/a", [])
    assert E.expand("$AOP_AITEST_DIR/a", str(repo)) == ("$AOP_AITEST_DIR/a", ["AOP_AITEST_DIR"])


def test_tasks_dir_falls_back_to_the_claude_config_dir(tmp_path):
    repo = fake_repo(tmp_path, "AOP_TASKS_DIR=\n")
    assert Path(E.tasks_dir(str(repo))) == tmp_path / "claude-config" / "aop-tasks"
    (repo / "config" / "aop.local.env").write_text("AOP_TASKS_DIR=T:/tasks\n")
    assert E.tasks_dir(str(repo)) == "T:/tasks"


def test_init_copies_examples_once_and_never_the_secrets(tmp_path):
    repo = fake_repo(tmp_path)
    E.init(str(repo), out=lambda *_: None)
    for local, example, who in E.LOCAL_FILES:
        assert (repo / local).is_file() == (who == "agent"), local
    (repo / "config" / "aop.local.env").write_text("AOP_KOREAN_REPO=mine\n")
    E.init(str(repo), out=lambda *_: None)
    assert (repo / "config" / "aop.local.env").read_text() == "AOP_KOREAN_REPO=mine\n"     # never overwritten


def test_check_counts_missing_files_and_broken_paths(tmp_path):
    repo = fake_repo(tmp_path)
    lines = []
    assert E.check(str(repo), out=lines.append) == 5                     # five agent files missing
    E.init(str(repo), out=lambda *_: None)
    (repo / "config" / "skill-sync.local.json").write_text(
        '{"repositories": {"a": "%s"}}' % tmp_path.as_posix())          # the example's D:\Workspace paths replaced
    assert E.check(str(repo), out=lines.append) == 0                     # unset values are not problems
    (repo / "config" / "aop.local.env").write_text("AOP_KOREAN_REPO=%s/nowhere\n" % tmp_path.as_posix())
    lines.clear()
    assert E.check(str(repo), out=lines.append) == 1
    assert any("BROKEN" in ln and "AOP_KOREAN_REPO" in ln for ln in lines)


def test_the_example_carries_no_values():
    ex = E.read_env_file(REPO / "config" / "aop.example.env")
    assert set(KEYS) <= set(ex) and all(v == "" for v in ex.values()), ex
    hints = E.example_hints(str(REPO / "config" / "aop.example.env"))
    assert all(hints[k] for k in KEYS)


# ------------------------------------------------------------------------------------------ guard: no device paths
PLACEHOLDER = r"(?!(?:x|you|user|username|name|owner)[\\/-])"          # fixtures' fake user names
USER_DIR = re.compile(r"(?i)\b[a-z]:[\\/]+users[\\/]+(?![\[<%{$])" + PLACEHOLDER + r"[^\\/\s\"'`<>\[\]]+[\\/]")
OLD_DEFAULT = re.compile(r"(?i)documents\W{1,8}workspace")
SLUG = re.compile(r"(?i)\b[a-z]--users-" + PLACEHOLDER + r"[a-z0-9_.]+-")
# historical records (briefs, plans, captured samples, logs, converter outputs); the intentional non-portable fixture;
# this file; .claude/settings.json, which agents never write (harness_status.py reports its drift from
# .claude/hooks/settings_entries.json until the owner applies the proposed file)
EXCLUDED = re.compile(r"^(docs/briefs/|docs/plans/|docs/skill-library-refactor-handoff\.md$|sandbox/census/samples/"
                      r"|.*\.gxo$|.*\.jsonl$|scripts/refdata/tests/test_catalogs\.py$"
                      r"|scripts/tools/tests/test_local_env\.py$|\.claude/settings\.json$)")
EXAMPLES = re.compile(r"^config/[^/]+\.example\.")        # may name typical locations (<home>/Documents/WORKSPACE)
XS_COMMENT = re.compile(r"^\s*//")                         # a commented-out line of a map script reaches no device


def tracked_text_files():
    out = subprocess.run(["git", "-C", str(REPO), "ls-files", "-z"], capture_output=True, check=True).stdout
    for rel in out.decode("utf-8").split("\0"):
        if not rel or EXCLUDED.match(rel):
            continue
        p = REPO / rel
        try:
            b = p.read_bytes()
        except OSError:
            continue
        if b"\0" in b[:8192]:
            continue
        yield rel, b.decode("utf-8", errors="replace")


def test_no_tracked_file_carries_a_device_path():
    found = []
    for rel, text in tracked_text_files():
        for pat in (USER_DIR, SLUG) + (() if EXAMPLES.match(rel) else (OLD_DEFAULT,)):
            for m in pat.finditer(text):
                start = text.rfind("\n", 0, m.start()) + 1
                if rel.endswith(".xs") and XS_COMMENT.match(text[start:m.start()]):
                    continue
                line = text.count("\n", 0, m.start()) + 1
                found.append(f"{rel}:{line}: {m.group(0)}")
    assert found == [], ("device paths belong in an ignored local file (python scripts/tools/local_env.py), never in "
                         "a tracked one:\n" + "\n".join(found[:50]))
