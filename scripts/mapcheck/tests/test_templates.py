"""G4 gate tests: the three starter templates green on correct params and
red on deliberately-wrong ones, and the unregistered-template guard."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapcheck.templates import TemplateContext, run_template  # noqa: E402
from scripts.mapcheck.universal import run  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"


def _scenario(players=2, teams=2):
    from scripts.mapsim.scene import Scenario
    return Scenario(players=players, teams=teams)


def _ctx(stem: str, players=2, teams=2) -> TemplateContext:
    sc = _scenario(players, teams)
    res = run(FIXTURES / f"{stem}.xs", sc)
    assert res.tg is not None
    return TemplateContext(stem=stem, scenario=sc,
                           scenario_tag=f"P{players}T{teams}", ex=res.ex,
                           rs=res.rs, tg=res.tg, ring=res.ring)


class TestAreaClassProbe:
    def test_correct_probes_green(self):
        ctx = _ctx("two_islands")
        out = run_template("area_class_probe", {"probes": [
            {"probe": [0.85, 0.5], "class": "LAND", "why": "east island"},
            {"probe": [0.5, 0.5], "class": "DEEP", "why": "open sea"},
        ]}, ctx)
        assert out == []

    def test_wrong_probe_red(self):
        ctx = _ctx("two_islands")
        out = run_template("area_class_probe", {"probes": [
            {"probe": [0.85, 0.5], "class": "DEEP",
             "why": "deliberately wrong"},
        ]}, ctx)
        assert len(out) == 1 and out[0].severity == "FAIL"
        assert out[0].details["got"] == "LAND"


class TestPlayerSpawnComplete:
    def test_islands_spawn_green(self):
        ctx = _ctx("two_islands")
        assert run_template("player_spawn_complete",
                            {"spawn_classes": ["LAND"]}, ctx) == []

    def test_spacing_violation_red(self):
        ctx = _ctx("two_islands")
        out = run_template("player_spawn_complete",
                           {"spawn_classes": ["LAND"],
                            "min_spacing_m": 500}, ctx)
        assert len(out) == 1 and out[0].severity == "FAIL"
        assert "apart" in out[0].message

    def test_wrong_class_red(self):
        # ok_min players stand on grass — demanding SHALLOW-only must fail
        ctx = _ctx("ok_min")
        out = run_template("player_spawn_complete",
                           {"spawn_classes": ["SHALLOW"]}, ctx)
        assert len(out) == 2  # both players on LAND
        assert all(f.severity == "FAIL" for f in out)


class TestGroupingSpawnComplete:
    def test_expected_count_green(self):
        ctx = _ctx("bad_names")
        assert run_template("grouping_spawn_complete",
                            {"pattern": "bad grouping", "expected": 1},
                            ctx) == []

    def test_pattern_matches_file_ref(self):
        ctx = _ctx("bad_names")
        assert run_template("grouping_spawn_complete",
                            {"pattern": "Rogue_Factory_*", "expected": 1},
                            ctx) == []

    def test_count_mismatch_red(self):
        ctx = _ctx("bad_names")
        out = run_template("grouping_spawn_complete",
                           {"pattern": "bad grouping", "expected": 2}, ctx)
        assert len(out) == 1 and out[0].severity == "FAIL"
        assert out[0].details == {"found": 1, "expected": 2}


class TestRegistryGuard:
    def test_unregistered_template_fails_with_guidance(self):
        ctx = _ctx("ok_min")
        out = run_template("my_bespoke_check", {}, ctx)
        assert len(out) == 1 and out[0].severity == "FAIL"
        assert "generalize" in out[0].message

    def test_profile_tests_flow_through_run(self, tmp_path):
        import json
        prof_dir = tmp_path / "profiles"
        prof_dir.mkdir()
        (prof_dir / "ok_min.json").write_text(json.dumps({
            "map": "ok_min", "version": 1,
            "tests": [{"template": "nonexistent_template", "params": {},
                       "why": "guard"}],
        }), encoding="utf-8")
        res = run(FIXTURES / "ok_min.xs", _scenario(), profiles_dir=prof_dir)
        assert any(f.check == "T:unregistered" and f.severity == "FAIL"
                   for f in res.findings)
