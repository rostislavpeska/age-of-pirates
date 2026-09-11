"""G3 gate tests: schema validation, the evidence guard rail, override
plumbing (digest-equal when override matches the catalog, digest-differs
when it does not), known-issue demotion, and the two pilot profiles."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapcheck import profile as profmod  # noqa: E402
from scripts.mapcheck.finding import Finding  # noqa: E402
from scripts.mapcheck.universal import run  # noqa: E402

REPO = Path(__file__).resolve().parents[3]
FIXTURES = Path(__file__).resolve().parent / "fixtures"


def _scenario(players=2, teams=2):
    from scripts.mapsim.scene import Scenario
    return Scenario(players=players, teams=teams)


def _valid(**extra):
    base = {"map": "x", "version": 1}
    base.update(extra)
    return base


class TestValidation:
    def test_minimal_valid(self):
        assert profmod.validate(_valid(), "x") == []

    def test_unknown_top_key(self):
        errs = profmod.validate(_valid(extra_key=1), "x")
        assert any("unknown top-level key" in e for e in errs)

    def test_stem_mismatch(self):
        errs = profmod.validate(_valid(), "other")
        assert any("file stem" in e for e in errs)

    def test_override_without_evidence_fails(self):
        data = _valid(overrides={"water_depth_m": {
            "Some River": {"value": 1.0, "evidence": "nope"}}})
        errs = profmod.validate(data, "x")
        assert any("no evidence, no override" in e for e in errs)

    def test_override_with_evidence_ok(self):
        data = _valid(
            evidence=[{"id": "e1", "date": "2026-08-09",
                       "source": "in-game", "claim": "c"}],
            overrides={"water_depth_m": {
                "Some River": {"value": 1.0, "evidence": "e1"}}})
        assert profmod.validate(data, "x") == []

    def test_unknown_override_kind(self):
        errs = profmod.validate(_valid(overrides={"terrain": {}}), "x")
        assert any("unknown key 'terrain'" in e for e in errs)

    def test_bad_expectation_class(self):
        data = _valid(expectations=[
            {"probe": [0.5, 0.5], "class": "WET", "why": "w"}])
        errs = profmod.validate(data, "x")
        assert any("'class' must be one of" in e for e in errs)

    def test_known_issue_needs_why(self):
        data = _valid(known_issues=[{"check": "G2", "match": "m"}])
        errs = profmod.validate(data, "x")
        assert any("missing 'why'" in e for e in errs)


class TestKnownIssueDemotion:
    def test_matching_fail_becomes_labeled_info(self):
        prof = profmod.Profile(
            map="x", path=Path("x.json"),
            known_issues=[{"check": "G2", "match": "anchor", "why": "verified"}])
        f = Finding("G2", "FAIL", "model", "player 2 nominal anchor on DEEP")
        out = profmod.apply_known_issues([f], prof)
        assert out[0].severity == "INFO"
        assert out[0].message.startswith("[known: verified]")
        assert out[0].details["suppressed_severity"] == "FAIL"

    def test_non_matching_untouched(self):
        prof = profmod.Profile(
            map="x", path=Path("x.json"),
            known_issues=[{"check": "G5", "match": "zzz", "why": "w"}])
        f = Finding("G2", "FAIL", "model", "player 2 nominal anchor on DEEP")
        assert profmod.apply_known_issues([f], prof)[0].severity == "FAIL"


class TestOverridePlumbing:
    """The G3 digest gate, on the two_islands fixture: an override equal to
    the catalog depth (Amazon Rainforest River Muddy = 5.0) must leave the
    classified grid byte-identical; a shallow override must change it."""

    EV = [{"id": "syn", "date": "2026-08-09", "source": "measurement",
           "claim": "synthetic fixture override"}]

    def _digest(self, tmp_path, depth):
        prof_dir = tmp_path / f"profiles_{depth}"
        prof_dir.mkdir()
        if depth is not None:
            (prof_dir / "two_islands.json").write_text(json.dumps({
                "map": "two_islands", "version": 1, "evidence": self.EV,
                "overrides": {"water_depth_m": {
                    "Amazon Rainforest River Muddy":
                        {"value": depth, "evidence": "syn"}}},
            }), encoding="utf-8")
        res = run(FIXTURES / "two_islands.xs", _scenario(),
                  profiles_dir=prof_dir)
        assert not [f for f in res.findings if f.check == "P0"]
        return res.tg.digest()

    def test_matching_override_is_identity(self, tmp_path):
        assert self._digest(tmp_path, 5.0) == self._digest(tmp_path, None)

    def test_different_override_changes_grid(self, tmp_path):
        base = self._digest(tmp_path, None)
        shallow = self._digest(tmp_path, 0.5)
        assert base != shallow
        # 0.5 m sea floor is walkable-buildable -> SHALLOW replaces DEEP
        assert shallow["hist"][1] > 0 and shallow["hist"][2] < base["hist"][2]

    def test_invalid_profile_is_p0_fail(self, tmp_path):
        prof_dir = tmp_path / "p"
        prof_dir.mkdir()
        (prof_dir / "two_islands.json").write_text(
            json.dumps({"map": "two_islands", "version": 1, "bogus": 1}),
            encoding="utf-8")
        res = run(FIXTURES / "two_islands.xs", _scenario(),
                  profiles_dir=prof_dir, static_only=True)
        p0 = [f for f in res.findings if f.check == "P0"]
        assert p0 and p0[0].severity == "FAIL"


class TestPilotProfiles:
    def test_civilwar_profile_valid(self):
        prof, errs = profmod.load("zp_z_z_zcivilwar2")
        assert errs == [] and prof is not None
        assert len(prof.expectations) == 2

    def test_tortuga_profile_valid(self):
        prof, errs = profmod.load("zptortuga")
        assert errs == [] and prof is not None
        assert len(prof.known_issues) == 3

    @pytest.mark.slow
    def test_civilwar_expectations_hold(self):
        from scripts.mapcheck.locate import resolve_map
        try:
            path = resolve_map("zp_z_z_zcivilwar2")
        except FileNotFoundError:
            pytest.skip("game install not available")
        res = run(path, _scenario())
        tmpl = [f for f in res.findings
                if f.check.startswith("T:") and f.severity == "FAIL"]
        assert tmpl == [], [f"{f.check}: {f.message}" for f in tmpl]

    @pytest.mark.slow
    def test_tortuga_known_issues_suppress_gate(self):
        from scripts.mapcheck.locate import resolve_map
        res = run(resolve_map("zptortuga"), _scenario())
        fails = [f for f in res.findings if f.severity == "FAIL"]
        assert fails == [], [f"{f.check}: {f.message}" for f in fails]
        known = [f for f in res.findings
                 if f.message.startswith("[known:")]
        # 2 controllers + 3 per-player starting defs (TC/silver/deer).
        # The G2 anchor entry stopped firing at P2 when the ring adopted
        # the true engine convention (north-zero clockwise, 2026-08-10)
        # — it still fires at P7, so the profile entry stays.
        assert len(known) == 5
