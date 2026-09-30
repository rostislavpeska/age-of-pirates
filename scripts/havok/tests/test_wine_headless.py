"""Every Wine launch is headless (owner 2026-09-29 20:40, "EXTREMELY SERIOUS": Wine crash dialogs opened over his
running game). A static scan, read-only, of the tools that start Wine under WSL:

    python -m pytest scripts/havok/tests/test_wine_headless.py -q

A launch line (`wine ./x.exe`, `timeout 300 wine %s`, `['wine', ...]`) must have, on the line or in the 15 lines
before it in the same file, both
    unset DISPLAY WAYLAND_DISPLAY      no X / Wayland display: Wine cannot open a window on the owner's screen
    WINEDLLOVERRIDES=winedbg.exe=d     no winedbg crash dialog
An intentional GUI launch carries `wine-headless: exempt - <reason>` on the line or the one above (gxo_wine.sh gui).
Scanned: this repo's scripts/ and .claude/skills/, and the workspace tool folders (Export_CP1, Destruction_S18k/tools;
$KBB_RESEARCH or the owner's default path). A finding in a Codex-owned folder is reported to Codex as a task, never
fixed from here.
"""
from __future__ import annotations

import os
import re
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
RESEARCH = Path(os.environ.get("KBB_RESEARCH") or
                Path.home() / "Documents" / "WORKSPACE" / "korean-buildings-blender" / "research")
EXTS = {".py", ".sh", ".bat", ".cmd", ".ps1"}
WINDOW = 15
SKIP_DIRS = {"__pycache__", ".venv", "node_modules", ".git"}

# a command position, then wine/wine64, then something it runs
LAUNCH = re.compile(r"""(?:^|[\s;&|(`'"])(?:timeout\s+\d+\s+)?wine(?:64)?\s+(?:\./|\.\\|/|%s|\{|\$|"|'|[\w.-]+\.exe\b)""")
LAUNCH_LIST = re.compile(r"""(?:\[\s*|--exec['"]\s*,\s*)['"]wine(?:64)?['"]\s*[,\]]""")   # argv lists, not paths
EXEMPT = re.compile(r"wine-headless:\s*exempt\b.{8,}")   # on the line or the one above, with its reason
NO_DISPLAY = re.compile(r"unset\s+DISPLAY\s+WAYLAND_DISPLAY|unset\s+WAYLAND_DISPLAY\s+DISPLAY|env\s+-u\s+DISPLAY\s+-u\s+WAYLAND_DISPLAY")
NO_WINEDBG = re.compile(r"winedbg\.exe\s*=\s*d\b")
COMMENT = re.compile(r"^\s*(#|REM\b|::|//)", re.I)


def scan_file(path: Path) -> list[str]:
    """['file:line: reason'] for each Wine launch without the headless prefix"""
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return []
    out = []
    for i, line in enumerate(lines):
        if COMMENT.match(line) or not (LAUNCH.search(line) or LAUNCH_LIST.search(line)):
            continue
        if EXEMPT.search(line) or (i and EXEMPT.search(lines[i - 1])):
            continue
        ctx = "\n".join(lines[max(0, i - WINDOW):i + 1])
        miss = [name for name, rx in (("unset DISPLAY WAYLAND_DISPLAY", NO_DISPLAY),
                                      ("WINEDLLOVERRIDES=winedbg.exe=d", NO_WINEDBG)) if not rx.search(ctx)]
        if miss:
            out.append(f"{path}:{i + 1}: Wine launch without {' and '.join(miss)}: {line.strip()[:120]}")
    return out


def scan(roots) -> tuple[list[str], int]:
    """(findings, files scanned)"""
    found, n = [], 0
    for root in roots:
        if not root.is_dir():
            continue
        for d, dirs, files in os.walk(root):
            dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
            for f in files:
                p = Path(d) / f
                if p.suffix.lower() in EXTS and p.resolve() != Path(__file__).resolve():
                    n += 1
                    found += scan_file(p)
    return found, n


# ------------------------------------------------------------------------------------------------ the scanner itself
def test_a_bare_wine_launch_fails_naming_file_and_line(tmp_path):
    bad = tmp_path / "bad_tool.py"
    bad.write_text("import subprocess\n\n"
                   "cmd = 'cd /work && timeout 300 wine ./conv.exe in.gr2 out.gr2'\n"
                   "subprocess.run(['wsl.exe', '--exec', 'bash', '-c', cmd])\n", encoding="utf-8")
    found, n = scan([tmp_path])
    assert n == 1 and len(found) == 1
    assert f"{bad}:3:" in found[0] and "unset DISPLAY WAYLAND_DISPLAY" in found[0] and "winedbg" in found[0]


def test_half_a_prefix_still_fails(tmp_path):
    p = tmp_path / "half.sh"
    p.write_text("unset DISPLAY WAYLAND_DISPLAY\nwine64 \"$EXE\" --bang\n", encoding="utf-8")
    (found,), _ = scan([tmp_path])
    assert ":2:" in found and "winedbg" in found and "unset DISPLAY" not in found.split("without")[1]


@pytest.mark.parametrize("body", [
    # the shipped pattern (converter.py / gr2_lint.py / gr2_to_raw.py): prefix a few lines above the launch
    "cmd = (f'set -e; unset DISPLAY WAYLAND_DISPLAY; export WINEDLLOVERRIDES=winedbg.exe=d WINEARCH=win32; '\n"
    "       f'cd {WORK}; '\n"
    "       f'set +e; timeout 300 wine ./gr2raw.exe >/dev/null 2>&1; rc=$?')\n",
    "args = ['env', '-u', 'DISPLAY']\n# unset DISPLAY WAYLAND_DISPLAY; WINEDLLOVERRIDES=winedbg.exe=d\n"
    "subprocess.run(['wine', exe])\n",
    "# never run: wine ./x.exe (a comment)\n",
    "print('the exe runs under Wine inside WSL; command -v wine >/dev/null')\n",
])
def test_headless_launches_comments_and_prose_pass(tmp_path, body):
    (tmp_path / "ok.py").write_text(body, encoding="utf-8")
    assert scan([tmp_path])[0] == []


def test_list_form_launch_is_seen(tmp_path):
    (tmp_path / "lst.py").write_text("subprocess.run(['wsl.exe', '--exec', 'wine', 'x.exe'])\n", encoding="utf-8")
    assert len(scan([tmp_path])[0]) == 1


def test_an_exempt_gui_launch_needs_its_reason(tmp_path):
    (tmp_path / "gui.sh").write_text("# wine-headless: exempt - the owner opens the converter window\n"
                                     "exec wine ./GXOConverterAge3DE.exe\n", encoding="utf-8")
    assert scan([tmp_path])[0] == []
    (tmp_path / "gui.sh").write_text("exec wine ./GXOConverterAge3DE.exe  # wine-headless: exempt\n", encoding="utf-8")
    assert len(scan([tmp_path])[0]) == 1                      # a bare marker without a reason does not count


def test_path_joins_are_not_launches(tmp_path):
    (tmp_path / "paths.py").write_text('F = [os.path.join("wine", "gxo_wine.sh"), os.path.join(d, "wine", "x.sh")]\n',
                                       encoding="utf-8")
    assert scan([tmp_path])[0] == []


def test_a_prefix_far_above_does_not_count(tmp_path):
    body = "P = 'unset DISPLAY WAYLAND_DISPLAY; export WINEDLLOVERRIDES=winedbg.exe=d'\n" + "x = 1\n" * 30 + \
           "cmd = 'wine ./a.exe'\n"
    (tmp_path / "far.py").write_text(body, encoding="utf-8")
    assert len(scan([tmp_path])[0]) == 1


# ------------------------------------------------------------------------------------------------ the real tools
def test_this_repos_wine_launches_are_headless():
    found, n = scan([REPO / "scripts", REPO / ".claude" / "skills"])
    assert n > 50, f"only {n} files scanned: wrong root?"
    assert found == [], "\n".join(found)


def test_workspace_tool_wine_launches_are_headless():
    """Export_CP1 and Destruction_S18k/tools are Codex's: a finding here becomes a task for Codex"""
    roots = [RESEARCH / "Texturing_11" / "Export_CP1", RESEARCH / "Destruction_S18k" / "tools"]
    if not any(r.is_dir() for r in roots):
        pytest.skip(f"workspace tools not on this machine: {RESEARCH} (set KBB_RESEARCH)")
    found, n = scan(roots)
    assert n > 0
    assert found == [], "\n".join(found)


def test_deployed_converter_scripts_match_the_template():
    """the Wine scripts that actually run live in the converter folder (gxo.py CONVERTER_DIR, OneDrive), deployed from
    .claude/skills/gxo-convert/templates by `gxo.py --deploy`. A copy that differs from the (scanned) template is
    unscanned code: redeploy when no conversion is running."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("gxo_cli", REPO / ".claude/skills/gxo-convert/scripts/gxo.py")
    g = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(g)
    live = Path(os.environ.get("GXO_CONVERTER_DIR") or g.CONVERTER_DIR) / "wine"
    if not live.is_dir():
        pytest.skip(f"converter folder not on this machine: {live}")
    tpl = REPO / ".claude/skills/gxo-convert/templates/wine"
    lf = lambda b: b.replace(b"\r\n", b"\n")  # noqa: E731
    stale = [f.name for f in sorted(tpl.glob("*.sh"))
             if not (live / f.name).is_file() or lf((live / f.name).read_bytes()) != lf(f.read_bytes())]
    assert stale == [], (f"{live} differs from the template for {stale}: redeploy with python .claude/skills/"
                         f"gxo-convert/scripts/gxo.py --deploy <converter folder> when no conversion runs")
