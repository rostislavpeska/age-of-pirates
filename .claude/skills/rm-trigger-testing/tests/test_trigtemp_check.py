"""trigtemp_check.py against a trimmed copy of the real London trigtemp.xs (2026-09-22 20:54) plus two
synthetic defects (a Towers_ON1 <-> Towers_ON2 ping-pong and a dead trUnitSelect("262148"))."""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "scripts"))
sys.dont_write_bytecode = True
import trigtemp_check as tc  # noqa: E402

FIXTURE = HERE / "fixtures" / "trigtemp_sample.xs"
TEXT = FIXTURE.read_text(encoding="utf-8")
LONDON = ["_TowerSUnlock", "_TowerConvS_Plr1", "_TowerConvS_Plr2", "_Bridge_ON_Plr1", "_Bridge_OFF_Plr1",
          "_BuildTowerS1_ON_Plr1", "_BuildTowerS1_OFF_Plr1", "_BridgeTowers_Setup0", "_BridgeTowers_Setup1"]


def findings(text=TEXT):
    return tc.check(text)


def test_failing_findings_are_exactly_the_synthetic_cycle_and_dead():
    failing = [f for f in findings() if f[0] in tc.FAILING]
    assert len(failing) == 2
    kinds = {f[0]: f for f in failing}
    assert kinds["DEAD"][1] == "_DeadSelect" and 'trUnitSelect("262148")' in kinds["DEAD"][2]
    assert kinds["CYCLE"][1] == "_Towers_ON1"
    assert "_Towers_ON1 -> _Towers_ON2 -> _Towers_ON1" in kinds["CYCLE"][2]


def test_london_rules_raise_no_failing_finding():
    for kind, rule, detail in findings():
        if rule in LONDON:
            # the only London line is the timer-throttled socket-build re-check, reported as info
            assert kind == "POLL", (kind, rule, detail)
            assert "_BuildTowerS1_OFF_Plr1 -> _BuildTowerS1_ON_Plr1" in detail


def test_exclusive_toggles_are_not_cycles():
    rules = tc.parse_rules(TEXT)
    # the same unit owned by different players
    assert tc.exclusive(rules["_TowerConvS_Plr1"], rules["_TowerConvS_Plr2"])
    # the same area count, >= 1 against == 0
    assert tc.exclusive(rules["_Bridge_ON_Plr1"], rules["_Bridge_OFF_Plr1"])
    # team counts of two different teams prove nothing
    assert not tc.exclusive(rules["_Towers_ON1"], rules["_Towers_ON2"])
    # timers are per-rule (cActivationTime): never exclusive
    assert not tc.exclusive(rules["_BridgeTowers_Setup0"], rules["_BridgeTowers_Setup1"])


def test_rule_parsing_state_loop_and_conditions():
    rules = tc.parse_rules(TEXT)
    assert list(rules) == LONDON + ["_Towers_ON1", "_Towers_ON2", "_DeadSelect"]
    assert rules["_TowerSUnlock"].active and not rules["_TowerConvS_Plr1"].active
    assert all(not r.loop for r in rules.values())
    c = rules["_TowerConvS_Plr1"].real_conds
    assert len(c) == 1 and c[0].expr == "trUnitIsOwnedBy(1)" and c[0].select == 1012
    assert rules["_BuildTowerS1_OFF_Plr1"].timed and not rules["_BuildTowerS1_ON_Plr1"].timed
    assert 'trSocketBuild(1, "281", "zpSPCCityTowerFlat");' in rules["_BridgeTowers_Setup1"].effects


def test_loop_detection():
    looping = TEXT.replace('      xsDisableRule("_Towers_ON2");\n', "")
    assert tc.parse_rules(looping)["_Towers_ON2"].loop
    rearmed = TEXT.replace('      xsDisableRule("_Towers_ON2");\n',
                           '      xsDisableRule("_Towers_ON2");\n      trDelayedRuleActivation("_Towers_ON2");\n')
    r = tc.parse_rules(rearmed)["_Towers_ON2"]
    assert r.loop and tc.edges(tc.parse_rules(rearmed), tc.parse_handler(rearmed))["_Towers_ON2"] == ["_Towers_ON1"]


def test_handler_mapping():
    h = tc.parse_handler(TEXT)
    assert h[2377] == ["_TowerConvS_Plr1"]
    assert h[2371] == ["_TowerConvS_Plr2"]
    assert h[2406] == ["_Bridge_OFF_Plr1"] and h[2410] == ["_Bridge_ON_Plr1"]
    assert h[2484] == ["_BuildTowerS1_OFF_Plr1"] and h[2472] == ["_BuildTowerS1_ON_Plr1"]
    assert h[2426] == ["_BridgeTowers_Setup1"]
    assert h[9001] == ["_Towers_ON2"] and h[9002] == ["_Towers_ON1"]
    g = tc.edges(tc.parse_rules(TEXT), h)
    assert g["_TowerSUnlock"] == ["_TowerConvS_Plr1", "_TowerConvS_Plr2"]


def test_always_gaiabuild_undefined_disabled_target():
    extra = TEXT + """
rule _Spin
highFrequency
active
{
   bool bVar0 = (true);
   bool tempExp = (bVar0);
   if (tempExp)
   {
      trSocketBuild(0, "281", "zpSPCCityTowerFlat");
      trEventFire(7777);
      xsEnableRule("_Nowhere");
      trDisableTrigger(8888);
   }
}
"""
    got = {(k, r) for k, r, _d in tc.check(extra)}
    assert ("ALWAYS", "_Spin") in got
    assert ("GAIABUILD", "_Spin") in got
    assert ("UNDEFINED", "_Spin") in got
    assert ("DISABLED-TARGET", "_Spin") in got
    undefined = [d for k, r, d in tc.check(extra) if k == "UNDEFINED"]
    assert any("7777" in d for d in undefined) and any("_Nowhere" in d for d in undefined)


def test_crlf_and_min_interval_header():
    crlf = TEXT.replace("\n", "\r\n")
    assert [f[:2] for f in tc.check(crlf)] == [f[:2] for f in tc.check(TEXT)]
    mi = TEXT.replace("rule _DeadSelect\nhighFrequency\n", "rule _DeadSelect\nminInterval 4\n")
    r = tc.parse_rules(mi)["_DeadSelect"]
    assert r.header == ["minInterval", "4", "inactive", "runImmediately"] and r.timed


def test_cli_exit_codes(capsys):
    assert tc.main([str(FIXTURE)]) == 1
    out = capsys.readouterr().out
    assert out.splitlines()[-1].startswith("# ") and "2 failing" in out
    assert tc.main([str(FIXTURE), "--rule", "Bridge_ON_Plr1"]) == 0
    assert capsys.readouterr().out.startswith("rule _Bridge_ON_Plr1")
    assert tc.main([str(FIXTURE), "--list"]) == 0
    assert "_TowerConvS_Plr1  inactive  once  if trUnitIsOwnedBy(1)@1012" in capsys.readouterr().out
    assert tc.main([str(HERE / "no_such_file.xs")]) == 2
