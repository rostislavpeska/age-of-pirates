"""G2 gate tests: one synthetic fixture per Part-F failure class, plus the
Independence War snapshot as the real-map golden smoke test."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapcheck.universal import (  # noqa: E402
    _duplicate_declarations,
    _strip,
    run,
)

REPO = Path(__file__).resolve().parents[3]
FIXTURES = Path(__file__).resolve().parent / "fixtures"


def _scenario(players=2, teams=2):
    from scripts.mapsim.scene import Scenario
    return Scenario(players=players, teams=teams)


def _run(stem: str, **kw):
    return run(FIXTURES / f"{stem}.xs", _scenario(), **kw)


def _by_check(res, check):
    return [f for f in res.findings if f.check == check]


def _fails(res):
    return [f for f in res.findings if f.severity == "FAIL"]


class TestStrip:
    def test_comments_and_strings_blanked_newlines_kept(self):
        src = 'int a = 1; // c "x"\n/* b\nb */ string s = "y";\n'
        out = _strip(src)
        assert len(out) == len(src)
        assert out.count("\n") == src.count("\n")
        assert '"y"' not in out and "b */" not in out
        assert "int a = 1;" in out and "string s =" in out

    def test_commented_out_code_invisible(self):
        # the Arsenal lesson: dead code must not reach the checkers
        out = _strip("// int dead = 1;\nint live = 2;\n")
        assert "dead" not in out and "live" in out


class TestDuplicateDeclarations:
    def test_same_block_duplicate_fires(self):
        dups = _duplicate_declarations("{ int a = 1; int a = 2; }")
        assert [(d[0]) for d in dups] == ["a"]

    def test_sibling_blocks_ok(self):
        assert _duplicate_declarations(
            "{ { int b = 1; } { int b = 2; } }") == []

    def test_for_header_ok(self):
        assert _duplicate_declarations(
            "{ for (int i = 0; i < 2; i++) { } "
            "for (int i = 0; i < 3; i++) { } }") == []

    def test_different_names_ok(self):
        assert _duplicate_declarations("{ int a = 1; int b = 2; }") == []


class TestStaticTier:
    def test_ok_min_clean(self):
        res = _run("ok_min")
        assert _fails(res) == [], [f.message for f in _fails(res)]

    def test_dup_var(self):
        res = _run("dup_var", static_only=True)
        s2 = _by_check(res, "S2")
        assert len(s2) == 1 and s2[0].severity == "FAIL"
        assert "'a'" in s2[0].message

    def test_no_terrain_init(self):
        res = _run("no_terrain_init", static_only=True)
        s3 = [f for f in _by_check(res, "S3") if f.severity == "FAIL"]
        assert any("rmTerrainInitialize" in f.message for f in s3)

    def test_water_order_warn(self):
        res = _run("water_order", static_only=True)
        s3 = _by_check(res, "S3")
        assert any(f.severity == "WARN" and "AFTER" in f.message for f in s3)

    def test_bad_names(self):
        res = _run("bad_names", static_only=True)
        s4 = _by_check(res, "S4")
        assert len(s4) == 3
        msgs = " | ".join(f.message for f in s4)
        assert "Musketeeer" in msgs and "did you mean 'Musketeer'" in msgs
        assert "Rogue_Factory_Japan" in msgs
        assert "Atlantis Lake" in msgs

    def test_missing_xml_is_fail(self, tmp_path):
        orphan = tmp_path / "orphan.xs"
        orphan.write_text(
            (FIXTURES / "ok_min.xs").read_text(encoding="utf-8"),
            encoding="utf-8")
        res = run(orphan, _scenario(), static_only=True)
        s5 = _by_check(res, "S5")
        assert any(f.severity == "FAIL" for f in s5)


class TestGridTier:
    def test_river_split_unreachable_players_fail(self):
        res = _run("river_split")
        g5 = _by_check(res, "G5")
        assert len(g5) == 1 and g5[0].severity == "FAIL"
        assert g5[0].details["deep_fraction"] < 0.10

    def test_two_islands_naval_info(self):
        res = _run("two_islands")
        g5 = _by_check(res, "G5")
        assert len(g5) == 1 and g5[0].severity == "INFO"
        assert g5[0].details["deep_fraction"] >= 0.10

    def test_two_islands_players_on_land(self):
        res = _run("two_islands")
        assert not [f for f in _by_check(res, "G2")
                    if f.severity == "FAIL"], "ring anchors must hit islands"


class TestGoldenSmoke:
    """The real-map determinism lock for the EXTRACTION path. NOTE: the
    goldens in scripts/mapsim/tests/goldens/ lock the CURATED-SCENE path;
    the two pipelines resolve anchors differently (ring nominal vs curated
    runtime), so mapcheck has its own goldens in scripts/maps/goldens/ —
    and G1 must discover them by stem+scenario automatically."""

    @pytest.mark.parametrize("players,teams", [(2, 2), (8, 8)])
    def test_independence_war_digest(self, players, teams):
        path = REPO / "scripts" / "mapsim" / "tests" / "fixtures" / \
            "independence_war.snapshot.xs"
        res = run(path, _scenario(players, teams))
        golden = json.loads(
            (REPO / "scripts" / "maps" / "goldens" /
             f"independence_war.snapshot_P{players}T{teams}.json").read_text(
                encoding="utf-8"))
        assert res.tg is not None
        assert res.tg.digest() == golden
        # G1 found the golden on its own and did not fail it
        g1 = [f for f in res.findings if f.check == "G1"]
        assert g1 == [] or all(f.severity != "FAIL" for f in g1)
        assert not any("no golden" in f.message for f in g1)
