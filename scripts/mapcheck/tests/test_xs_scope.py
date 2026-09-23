"""S6 - XS scope errors the compiler stops on and the simulator never saw (user 2026-09-22: "xs is extremely sensitive
for undefined / double defined variables - 99% of these errors"): every map script in randmaps/ must pass
scripts/mapcheck/xs_scope_check.py, and the checker must fail on each injected error class (a clean check that
cannot fail is worth nothing)."""
import glob, os, re, subprocess, sys
from pathlib import Path
import pytest

REPO = Path(__file__).resolve().parents[3]
CHECK = REPO / "scripts/mapcheck/xs_scope_check.py"
sys.path.insert(0, str(CHECK.parent))
import xs_scope_check as xsc

PROFILE = REPO.parents[2]                     # <profile>/mods/local/age-of-pirates

# The only dump facts the checker consults. Measured 2026-09-23 on Age3DERM00000_zplondon.dmp.txt (397 syscalls,
# 24 user functions, 206 constants): every other syscall is rm/xs/tr/ai/kb-prefixed and every constant c[A-Z], both
# exempt in xs_scope_check.check. Pinned so the test no longer reads whichever dump the game wrote last (2026-09-23:
# an Istanbul dump without the includes made 18 maps fail on chooseMercs()) and no dumped map's own functions count.
MATH_SYSCALLS = {"abs", "acos", "asin", "atan", "atan2", "ceil", "cos", "pow", "round", "sin", "sqrt", "tan"}
INCLUDES = {"mercenaries.xs": {"chooseMercs"},
            "ypAsianInclude.xs": {"ypIsAsian", "ypTCChooser", "ypMonasteryBuilder", "ypRicePaddyBuilder"},
            "ypKOTHInclude.xs": {"ypKingsHillPlacer", "ypKingsHillLandfill"}}


def _builtins():
    return MATH_SYSCALLS.union(*INCLUDES.values()), set()


@pytest.mark.parametrize("path", sorted(glob.glob(str(REPO / "randmaps" / "*.xs"))))
def test_every_map_script_has_no_scope_error(path):
    funcs, consts = _builtins()
    res = xsc.check(Path(path), funcs, consts)
    assert not res, "\n".join("line %d %s [%s] %s" % f for f in res[:20])


def test_checker_catches_each_injected_error(tmp_path):
    funcs, consts = _builtins()
    src = (REPO / "randmaps/zplondon.xs").read_text(encoding="utf-8", errors="replace")
    anchor = "\tint harbourN1PostDef = rmCreateObjectDef(\"harbour post N1\");"
    assert src.count(anchor) == 1
    cases = {
        "DOUBLE": src.replace(anchor, anchor + "\r\n\tint harbourN2PostDef = 5;", 1),
        "UNDEFINED": src.replace(anchor, "\trmEchoInfo(\"\" + notDeclaredAnywhere);\r\n" + anchor, 1),
        "ORDER": src.replace(anchor, anchor + "\r\n\tlaterDefined();", 1) + "\r\nvoid laterDefined()\r\n{\r\n\trmEchoInfo(\"x\");\r\n}\r\n",
        "UNKNOWN_FN": src.replace(anchor, anchor + "\r\n\tchooseMercz();", 1),
    }
    for kind, text in cases.items():
        p = tmp_path / ("inject_%s.xs" % kind); p.write_text(text, encoding="utf-8")
        res = xsc.check(p, funcs, consts)
        assert any(f[2] == kind for f in res), (kind, res)


@pytest.mark.local("profile")
def test_pinned_builtins_still_match_the_game():
    """The pin against the newest dump whose Files table holds all three includes (a map without them lacks the
    include functions, which is what broke the newest-dump rule). Fails when an engine update renames a pinned
    function or adds a constant the checker would not exempt."""
    dumps = [p for p in (PROFILE / "RandMaps").glob("Age3DERM*.dmp.txt")
             if all(i.lower() in p.read_text(encoding="utf-8", errors="replace")[:8000].lower() for i in INCLUDES)]
    if not dumps:
        pytest.skip("no CXSDump with all three includes in the profile folder - generate London or Paris once")
    funcs, consts = xsc.builtins_from_dump(max(dumps, key=lambda p: p.stat().st_mtime))
    pinned, _ = _builtins()
    assert pinned <= funcs, sorted(pinned - funcs)
    assert all(re.fullmatch(r"c[A-Z]\w*", c) for c in consts), sorted(c for c in consts if not re.fullmatch(r"c[A-Z]\w*", c))
