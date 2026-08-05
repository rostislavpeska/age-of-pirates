"""Smoke tests for the preview renderer (guarded: matplotlib is optional)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

pytest.importorskip("matplotlib")

from scripts.mapsim.checks import run_checks  # noqa: E402
from scripts.mapsim.render import render  # noqa: E402
from scripts.mapsim.scene import Scenario, Scene  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures"


@pytest.mark.parametrize("sc", [Scenario(2, 2), Scenario(8, 8)])
def test_render_real_scene_smoke(tmp_path, sc):
    scene = Scene.load(FIXTURES / "independence_war.scene.json")
    rs = scene.resolve(sc)
    findings = run_checks(rs)
    out = render(rs, findings, tmp_path / f"preview_{sc.players}.png", title="test")
    assert out.is_file()
    assert out.stat().st_size > 50_000  # a real image, not an empty canvas
