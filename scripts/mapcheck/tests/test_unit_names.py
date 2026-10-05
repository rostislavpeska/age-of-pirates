"""Unit and tech names exact - spelling and case (scripts/tools/check_unit_names.py).

2026-10-05: zpistanbulb.mods.xml named the Dry Dock 'zpDryDock' (the proto is zpDrydock); the AI constant
cUnitTypezpDrydock vanished on Istanbul and every AI died at aiBuildings.xs 123. 2026-10-06 (owner): extended to the
protomods / techtreemods rewrites and to tech names in the per-map mods files. These tests run the checker on the repo
and prove every check would fire."""
import importlib.util
import os

import pytest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
spec = importlib.util.spec_from_file_location("check_unit_names", os.path.join(REPO, "scripts", "tools", "check_unit_names.py"))
cun = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cun)


@pytest.fixture(scope="module")
def known():
    return cun.Known(live=False)


def test_repo_names_are_exact_snapshot():
    # CI form: no game install - case mismatches, unknown mod names and broken rewrites still fail; vanilla gaps warn
    errors, warns, used_live, n_mods, n_ai = cun.run(live=False)
    assert n_mods >= 18 and n_ai >= 10
    assert not errors, "\n".join(errors)


@pytest.mark.local("steam")
def test_repo_names_are_exact_live():
    errors, warns, used_live, n_mods, n_ai = cun.run(live=True)
    if not used_live:
        pytest.skip("live protoy / techtreey not readable on this device")
    assert not errors and not warns, "\n".join(errors + warns)


def test_the_check_catches_the_drydock_line(tmp_path, known):
    mods = tmp_path / "zptest.mods.xml"
    mods.write_text('<mods>\n\t<protomods>\n\t\t<unit name="zpDryDock">\n\t\t\t<placementfile>dock_city.xml</placementfile>\n'
                    '\t\t</unit>\n\t</protomods>\n</mods>\n', encoding="utf-8")
    rep = cun.Report(False)
    cun.check_mods_files(rep, [str(mods)], known)
    assert len(rep.errors) == 1 and "'zpDryDock' does not exist" in rep.errors[0] and "zpDrydock" in rep.errors[0]
    assert ":3:" in rep.errors[0]


def test_a_tech_in_a_mods_file_is_checked_and_warned(tmp_path, known):
    mods = tmp_path / "zptest.mods.xml"
    mods.write_text('<mods>\n<techtreemods>\n<tech name="zpLondonSetup"></tech>\n<tech name="zplondonsetup"></tech>\n'
                    '</techtreemods>\n</mods>\n', encoding="utf-8")
    rep = cun.Report(False)
    cun.check_mods_files(rep, [str(mods)], known)
    assert len(rep.errors) == 1 and "'zplondonsetup' does not exist" in rep.errors[0] and "zpLondonSetup" in rep.errors[0]
    assert sum("not reliable" in w for w in rep.warns) == 2


def test_the_check_catches_ai_constant_typos_and_ignores_comments(tmp_path, known):
    ai = tmp_path / "aitest.xs"
    ai.write_text("// cUnitTypezpDryDock in a comment is fine\n"
                  "   if (puid == cUnitTypezpDryDock)\n"
                  "   if (puid == cUnitTypezpNoSuchUnitAtAll)\n"
                  "   if (puid == cUnitTypezpDrydock)\n"
                  "   xsSetTech(cTechzplondonsetup);\n", encoding="utf-8")
    rep = cun.Report(False)
    cun.check_ai(rep, [str(ai)], known)
    assert len(rep.errors) == 3
    assert ":2 cUnitTypezpDryDock" in rep.errors[0] and "zpDrydock" in rep.errors[0]
    assert ":3 cUnitTypezpNoSuchUnitAtAll" in rep.errors[1] and "not defined" in rep.errors[1]
    assert ":5 cTechzplondonsetup" in rep.errors[2] and "zpLondonSetup" in rep.errors[2]


def test_the_check_catches_broken_protomods_rewrites(tmp_path, known):
    pm = tmp_path / "protomods.xml"
    pm.write_text('<protomods>\n'
                  '  <unit name="WallConnector"><maxhitpoints>1</maxhitpoints></unit>\n'      # exact vanilla rewrite: fine
                  '  <unit name="wallconnector"><maxhitpoints>1</maxhitpoints></unit>\n'      # case: a NEW unit, not a rewrite
                  '  <unit id="99990" name="zpTestUnit"><dbid>99990</dbid></unit>\n'
                  '  <unit name="zpTestUnit"><maxhitpoints>2</maxhitpoints></unit>\n'         # partial rewrite of a mod unit: fine
                  '  <unit name="zptestunit"><maxhitpoints>3</maxhitpoints></unit>\n'         # rewrites nothing (case)
                  '  <unit id="99991" name="zpTESTUNIT"><dbid>99991</dbid></unit>\n'          # a case twin of zpTestUnit
                  '</protomods>\n', encoding="utf-8")
    rep = cun.Report(False)
    cun.check_rewrites(rep, str(pm), "unit", "id", known.van_units, "unit")
    text = "\n".join(rep.errors)
    assert "protomods.xml:3: unit 'wallconnector' differs from the vanilla WallConnector only by case" in text
    assert "protomods.xml:6: unit 'zptestunit' rewrites nothing" in text
    assert "differ only by case: zpTESTUNIT / zpTestUnit" in text
    assert len(rep.errors) == 3


def test_the_check_catches_broken_techtreemods_rewrites(tmp_path, known):
    tt = tmp_path / "techtreemods.xml"
    tt.write_text('<techtreemods>\n'
                  '  <tech name="Bastion" type="Normal"><effects/></tech>\n'                  # exact vanilla rewrite: fine
                  '  <tech name="bastion" type="Normal"><effects/></tech>\n'                  # case
                  '  <tech name="zpTestTech" type="Normal"><dbid>1</dbid><effects/></tech>\n'
                  '  <tech name="zpTestTech" type="Normal"><effects/></tech>\n'               # partial rewrite: fine
                  '</techtreemods>\n', encoding="utf-8")
    rep = cun.Report(False)
    cun.check_rewrites(rep, str(tt), "tech", "dbid", known.van_techs, "tech")
    assert len(rep.errors) == 1 and "techtreemods.xml:3: tech 'bastion' differs from the vanilla Bastion only by case" in rep.errors[0]


def test_ci_runs_the_check_on_every_push():
    wf = open(os.path.join(REPO, ".github", "workflows", "unit_names.yml"), encoding="utf-8").read()
    assert "on: push" in wf and "python scripts/tools/check_unit_names.py --no-live" in wf
