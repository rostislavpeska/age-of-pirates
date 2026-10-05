"""Unit names exact - spelling and case (scripts/tools/check_unit_names.py).

2026-10-05: zpistanbulb.mods.xml named the Dry Dock 'zpDryDock' (the proto is zpDrydock); the AI constant
cUnitTypezpDrydock vanished on Istanbul and every AI died at aiBuildings.xs 123. These tests run the checker on the repo
and prove it would have caught that line."""
import importlib.util
import os

import pytest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
spec = importlib.util.spec_from_file_location("check_unit_names", os.path.join(REPO, "scripts", "tools", "check_unit_names.py"))
cun = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cun)


def test_repo_names_are_exact_snapshot():
    # CI form: no game install - a case mismatch or an unknown mod name still fails; vanilla gaps only warn
    errors, warns, used_live, n_mods, n_ai = cun.run(live=False)
    assert n_mods >= 18 and n_ai >= 10
    assert not errors, "\n".join(errors)


@pytest.mark.local("steam")
def test_repo_names_are_exact_live():
    errors, warns, used_live, n_mods, n_ai = cun.run(live=True)
    if not used_live:
        pytest.skip("live protoy not readable on this device")
    assert not errors and not warns, "\n".join(errors + warns)


def _known():
    mod, vanilla, _ = cun.known_names(live=False)
    return mod, vanilla


def test_the_check_catches_the_drydock_line(tmp_path):
    mods = tmp_path / "zptest.mods.xml"
    mods.write_text('<mods>\n\t<protomods>\n\t\t<unit name="zpDryDock">\n\t\t\t<placementfile>dock_city.xml</placementfile>\n'
                    '\t\t</unit>\n\t</protomods>\n</mods>\n', encoding="utf-8")
    mod, vanilla = _known()
    errors, warns = cun.check([str(mods)], [], mod, vanilla, False)
    assert len(errors) == 1 and "'zpDryDock' does not exist" in errors[0] and "zpDrydock" in errors[0] and ":3:" in errors[0]


def test_the_check_catches_an_ai_constant_typo_and_ignores_comments(tmp_path):
    ai = tmp_path / "aitest.xs"
    ai.write_text("// cUnitTypezpDryDock in a comment is fine\n"
                  "   if (puid == cUnitTypezpDryDock)\n"
                  "   if (puid == cUnitTypezpNoSuchUnitAtAll)\n"
                  "   if (puid == cUnitTypezpDrydock)\n", encoding="utf-8")
    mod, vanilla = _known()
    errors, warns = cun.check([], [str(ai)], mod, vanilla, False)
    assert len(errors) == 2
    assert ":2 cUnitTypezpDryDock" in errors[0] and "zpDrydock" in errors[0]
    assert ":3 cUnitTypezpNoSuchUnitAtAll" in errors[1] and "not a unit or unit type" in errors[1]


def test_ci_runs_the_check_on_every_push():
    wf = open(os.path.join(REPO, ".github", "workflows", "unit_names.yml"), encoding="utf-8").read()
    assert "on: push" in wf and "python scripts/tools/check_unit_names.py --no-live" in wf
