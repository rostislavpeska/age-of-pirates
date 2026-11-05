"""AOP-TEST-ONLY lines never reach a beta or prod zip (owner 2026-10-19: "flag as test unit to be removed before
exporting to Beta or production"). The audit blocks on them and make_zip.py refuses to build.

    python -m pytest .claude/skills/mod-deploy-check/tests -q
"""
import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.dont_write_bytecode = True
sys.path.insert(0, str(SCRIPTS))

import prezip_check  # noqa: E402
from release_marker import TEST_ONLY_MARK, marked_lines  # noqa: E402

HOOK = ("   // %s: zpHCUnlockTest bench for player 1; remove before a beta or prod export\r\n"
        "   rmAddObjectDefItem(id, \"zpHCUnlockTest\", 1, 6.0);\r\n" % TEST_ONLY_MARK)


def mod(tmp, marked=True):
    maps = tmp / "mod" / "game" / "randmaps"
    maps.mkdir(parents=True)
    (maps / "zpclean.xs").write_bytes(b"void main(void)\r\n{\r\n}\r\n")
    (maps / "zptestmap.xs").write_bytes(("void main(void)\r\n{\r\n" + (HOOK if marked else "") + "}\r\n").encode())
    tex = tmp / "mod" / "art" / "x"
    tex.mkdir(parents=True)
    (tex / "page.ddt").write_bytes(b"RTS3" + TEST_ONLY_MARK.encode())     # a binary that holds the bytes
    return tmp / "mod"


def test_the_marker_is_found_with_its_line_and_binaries_are_never_read(tmp_path):
    root = mod(tmp_path)
    xs = (root / "game/randmaps/zptestmap.xs").read_bytes
    assert marked_lines("game/randmaps/zptestmap.xs", xs) == [
        "game/randmaps/zptestmap.xs:3: // %s: zpHCUnlockTest bench for player 1; remove before a beta or prod export"
        % TEST_ONLY_MARK]
    assert marked_lines("game/randmaps/zpclean.xs", (root / "game/randmaps/zpclean.xs").read_bytes) == []
    assert marked_lines("art/x/page.ddt", lambda: (_ for _ in ()).throw(AssertionError("binary read"))) == []


def test_the_audit_blocks_a_marked_line(tmp_path):
    root = mod(tmp_path)
    rep = prezip_check.Report()
    prezip_check.audit(prezip_check.walk_disk(str(root)), rep, on_disk_root=str(root))
    hits = [i for cat, items in rep.block.items() if TEST_ONLY_MARK in cat for i in items]
    assert hits == ["game/randmaps/zptestmap.xs:3: // %s: zpHCUnlockTest bench for player 1; remove before a beta "
                    "or prod export" % TEST_ONLY_MARK]


def make_zip(root, out, *args):
    return subprocess.run([sys.executable, str(SCRIPTS / "make_zip.py"), str(out), "--root", str(root), *args],
                          capture_output=True, text=True)


def test_make_zip_refuses_and_writes_nothing(tmp_path):
    root = mod(tmp_path)
    out = tmp_path / "out" / "aop-beta.zip"
    out.parent.mkdir()
    r = make_zip(root, out)
    assert r.returncode == 1, r.stdout + r.stderr
    assert "zptestmap.xs:3" in r.stdout and "nothing written" in r.stdout
    assert list(out.parent.iterdir()) == []


def test_make_zip_builds_once_the_marked_map_is_stripped_or_clean(tmp_path):
    root = mod(tmp_path)
    out = tmp_path / "out" / "aop-prod.zip"
    out.parent.mkdir()
    r = make_zip(root, out, "--strip-map", "zptestmap")
    assert r.returncode == 0, r.stdout + r.stderr
    assert out.is_file()
    clean = mod(tmp_path / "clean", marked=False)
    r = make_zip(clean, tmp_path / "out" / "aop-beta.zip")
    assert r.returncode == 0, r.stdout + r.stderr
