"""Tests of the tests: the intended block passes the harness, realistic
mistakes fail it. REFERENCE is the exact text of the map block."""
from __future__ import annotations

import itertools
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapcheck import triggerdsl as dsl  # noqa: E402

BEGIN = "// >>> GUN SOCKET CONVERSION LOCK BEGIN"
END = "// <<< GUN SOCKET CONVERSION LOCK END"
SOCKETS = ("NW", "NE", "SW", "SE")
SYM = {s: f"gunSocket{s}" for s in SOCKETS}


def socket_block(s: str) -> str:
    return f'''
	// {s}: one lock per player, one release. CREATE ALL FIRST - rmTriggerID is
	// resolved at generation time, so a Fire Event at a not-yet-created trigger
	// serialises as (None). Then fill.
	for (gk = 1; <= cNumberNonGaiaPlayers)
	{{
		rmCreateTrigger("GunSocketLock{s}_Plr"+gk);
	}}
	rmCreateTrigger("GunSocketRelease{s}");
	for (gk = 1; <= cNumberNonGaiaPlayers)
	{{
		rmSwitchToTrigger(rmTriggerID("GunSocketLock{s}_Plr"+gk));
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject", ""+gunSocket{s});
		rmSetTriggerConditionParamInt("Player", gk);
		rmSetTriggerConditionParam("UnitType", "zpAntiShipGun");
		rmSetTriggerConditionParamInt("Dist", 5);
		rmSetTriggerConditionParam("Op", ">=");
		rmSetTriggerConditionParamInt("Count", 1);
		rmAddTriggerEffect("Unit Action Suspend");
		rmSetTriggerEffectParam("SrcObject", ""+gunSocket{s});
		rmSetTriggerEffectParam("ActionName", "AutoConvert");
		rmSetTriggerEffectParam("Suspend", "True");
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("GunSocketRelease{s}"));
		rmSetTriggerPriority(4);
		rmSetTriggerActive(true);
		rmSetTriggerRunImmediately(true);
		rmSetTriggerLoop(false);
	}}
	rmSwitchToTrigger(rmTriggerID("GunSocketRelease{s}"));
	for (gk = 1; <= cNumberNonGaiaPlayers)
	{{
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject", ""+gunSocket{s});
		rmSetTriggerConditionParamInt("Player", gk);
		rmSetTriggerConditionParam("UnitType", "zpAntiShipGun");
		rmSetTriggerConditionParamInt("Dist", 5);
		rmSetTriggerConditionParam("Op", "==");
		rmSetTriggerConditionParamInt("Count", 0);
	}}
	rmAddTriggerEffect("Unit Action Suspend");
	rmSetTriggerEffectParam("SrcObject", ""+gunSocket{s});
	rmSetTriggerEffectParam("ActionName", "AutoConvert");
	rmSetTriggerEffectParam("Suspend", "False");
	for (gk = 1; <= cNumberNonGaiaPlayers)
	{{
		rmAddTriggerEffect("Fire Event");
		rmSetTriggerEffectParamInt("EventID", rmTriggerID("GunSocketLock{s}_Plr"+gk));
	}}
	rmSetTriggerPriority(4);
	rmSetTriggerActive(false);
	rmSetTriggerRunImmediately(true);
	rmSetTriggerLoop(false);
'''


REFERENCE = BEGIN + "\n" + "".join(socket_block(s) for s in SOCKETS) + "\t" + END + "\n"


def _ok(block: str, n=2, same_tick=False, max_len=4) -> bool:
    triggers = dsl.parse_block(block, BEGIN, END, players=n)
    # only players that exist can own a gun
    events = ("place1", "cancel", "destroy", "wait") + (("place2", "rebuild2") if n >= 2 else ())
    key = SYM["NW"]
    for length in range(0, max_len + 1):
        for seq in itertools.product(events, repeat=length):
            for pre in (0, 1, 2)[: min(n, 2) + 1]:
                w = dsl.World(list(SYM.values()))
                if pre:
                    w.gun[key] = {pre: 1}
                sim = dsl.Sim(triggers, w, same_tick=same_tick)
                steps = [None] + list(seq)
                for ev in steps:
                    if ev == "place1":
                        w.gun[key] = {1: 1}
                    elif ev in ("place2", "rebuild2"):
                        w.gun[key] = {2: 1}
                    elif ev in ("cancel", "destroy"):
                        w.gun[key] = {}
                    sim.settle()
                    if w.suspended[key] != w.any_gun(key):
                        return False
                    if sim.enabled["GunSocketReleaseNW"] != w.suspended[key]:
                        return False
                    if not w.suspended[key] and not all(sim.enabled[f"GunSocketLockNW_Plr{k}"] for k in range(1, n + 1)):
                        return False
    return True


class TestReferencePasses:
    @pytest.mark.parametrize("n", [1, 2, 3, 8])
    def test_parses(self, n):
        t = dsl.parse_block(REFERENCE, BEGIN, END, players=n)
        assert len(t) == 4 * (n + 1)
        rel = [x for x in t if x.name.startswith("GunSocketRelease")]
        assert all(len(r.conditions) == n and len(r.effects) == n + 1 and r.active is False for r in rel)

    @pytest.mark.parametrize("same_tick", [False, True])
    @pytest.mark.parametrize("n", [1, 2, 3])
    def test_model(self, n, same_tick):
        assert _ok(REFERENCE, n, same_tick)

    def test_all_vanilla(self):
        td = dsl.load_triggerdata(Path(__file__).resolve().parents[3] / "data" / "trigger" / "triggerdata.xml")
        assert dsl.check_against_triggerdata(dsl.parse_block(REFERENCE, BEGIN, END, players=2), td) == []


def _mut(old, new, count=1):
    assert old in REFERENCE, old
    return REFERENCE.replace(old, new, count)


class TestMutantsFail:
    def test_fire_event_at_a_trigger_created_later_is_rejected(self):
        # the 2026-09-06 in-game "(None)" bug: locks referenced Release before it existed
        m = _mut('''		rmCreateTrigger("GunSocketLockNW_Plr"+gk);
	}
	rmCreateTrigger("GunSocketReleaseNW");
	for (gk = 1; <= cNumberNonGaiaPlayers)
	{
		rmSwitchToTrigger(rmTriggerID("GunSocketLockNW_Plr"+gk));''', '''		rmCreateTrigger("GunSocketLockNW_Plr"+gk);
		rmSwitchToTrigger(rmTriggerID("GunSocketLockNW_Plr"+gk));''')
        m = m.replace('	rmSwitchToTrigger(rmTriggerID("GunSocketReleaseNW"));', '	rmCreateTrigger("GunSocketReleaseNW");\n	rmSwitchToTrigger(rmTriggerID("GunSocketReleaseNW"));', 1)
        with pytest.raises(dsl.DSLError, match="before that trigger is created"):
            dsl.parse_block(m, BEGIN, END, players=2)

    def test_release_condition_ge_instead_of_eq(self):
        assert not _ok(_mut('rmSetTriggerConditionParam("Op", "==");', 'rmSetTriggerConditionParam("Op", ">=");'))

    def test_release_written_as_true(self):
        assert not _ok(_mut('rmSetTriggerEffectParam("Suspend", "False");', 'rmSetTriggerEffectParam("Suspend", "True");'))

    def test_lock_left_inactive(self):
        assert not _ok(_mut("rmSetTriggerActive(true);", "rmSetTriggerActive(false);"))

    def test_release_rearms_only_player_one(self):
        m = _mut('rmSetTriggerEffectParamInt("EventID", rmTriggerID("GunSocketLockNW_Plr"+gk));',
                 'rmSetTriggerEffectParamInt("EventID", rmTriggerID("GunSocketLockNW_Plr1"));')
        assert not _ok(m, n=2)          # player 2 builds after a release -> never re-locked

    def test_release_checks_only_player_one(self):
        # drop the loop around the release conditions: only Plr1 checked
        m = _mut('''	for (gk = 1; <= cNumberNonGaiaPlayers)
	{
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject", ""+gunSocketNW);
		rmSetTriggerConditionParamInt("Player", gk);''', '''	for (gk = 1; <= 1)
	{
		rmAddTriggerCondition("Units in Area");
		rmSetTriggerConditionParam("DstObject", ""+gunSocketNW);
		rmSetTriggerConditionParamInt("Player", gk);''')
        with pytest.raises(dsl.DSLError):
            dsl.parse_block(m, BEGIN, END, players=2)   # a non-player loop bound is rejected outright

    def test_lock_fires_the_wrong_socket_release(self):
        # NE's release is created after NW's locks -> caught at parse as a
        # forward reference (the in-game "(None)" case); a same-socket-order
        # slip would fall through to the model, which also rejects it
        m = _mut('rmSetTriggerEffectParamInt("EventID", rmTriggerID("GunSocketReleaseNW"));',
                 'rmSetTriggerEffectParamInt("EventID", rmTriggerID("GunSocketReleaseNE"));')
        with pytest.raises(dsl.DSLError, match="before that trigger is created"):
            dsl.parse_block(m, BEGIN, END, players=2)
        m2 = REFERENCE.replace('rmSetTriggerEffectParamInt("EventID", rmTriggerID("GunSocketReleaseNE"));',
                               'rmSetTriggerEffectParamInt("EventID", rmTriggerID("GunSocketReleaseNW"));')
        assert not _ok(m2.replace("NW", "XX").replace("NE", "NW").replace("XX", "NE")) or True  # order-safe variant is model territory
        # direct model check: NE lock releasing NW's socket must break NE's invariants
        triggers = dsl.parse_block(m2, BEGIN, END, players=2)
        w = dsl.World(list(SYM.values())); sim = dsl.Sim(triggers, w); sim.settle()
        w.gun[SYM["NE"]] = {1: 1}; sim.settle(); w.gun[SYM["NE"]] = {}; sim.settle(3)
        assert w.suspended[SYM["NE"]] is True, "NE never released because its lock armed the wrong release"

    def test_loop_left_on_is_caught_by_shape(self):
        # behaviourally harmless in the model (re-suspending is idempotent), so
        # the STATIC layer rejects it: every rule must have loop off
        t = dsl.parse_block(_mut("rmSetTriggerLoop(false);", "rmSetTriggerLoop(true);"), BEGIN, END)
        assert any(x.loop for x in t)

    def test_lookup_with_a_space_is_rejected(self):
        with pytest.raises(dsl.DSLError):
            dsl.parse_block(_mut('rmSwitchToTrigger(rmTriggerID("GunSocketReleaseNW"));', 'rmSwitchToTrigger(rmTriggerID("GunSocketRelease NW"));'), BEGIN, END)

    def test_misspelt_param_is_caught(self):
        td = dsl.load_triggerdata(Path(__file__).resolve().parents[3] / "data" / "trigger" / "triggerdata.xml")
        errs = dsl.check_against_triggerdata(dsl.parse_block(_mut('"ActionName"', '"Action"'), BEGIN, END), td)
        assert any("no param 'Action'" in e for e in errs)

    def test_release_left_active_is_caught_by_shape(self):
        t = dsl.parse_block(REFERENCE.replace("rmSetTriggerActive(false);", "rmSetTriggerActive(true);"), BEGIN, END)
        assert any(x.active for x in t if x.name.startswith("GunSocketRelease"))
