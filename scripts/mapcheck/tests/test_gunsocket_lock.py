"""Spec for the Istanbul anti-ship gun socket conversion lock - VANILLA
primitives only (no custom triggerdata: that would need multiplayer testing).

Per socket S in NW/NE/SW/SE, per non-gaia player k:
  GunSocketLock<S>_Plr<k>   active   : player k's zpAntiShipGun within 5 m
                                       -> suspend the socket's AutoConvert,
                                          Fire Event -> GunSocketRelease<S>
and one
  GunSocketRelease<S>       inactive : NO player's gun within 5 m (one
                                       Units-in-Area == 0 per player, ANDed)
                                       -> release, Fire Event -> every Lock<S>_Plr<k>

No lock ever deactivates another lock: suspending twice is idempotent and
enabling an enabled rule is a no-op, so the only re-armer is Release. That is
what the model proves below, exhaustively.

Layers: 1 static (parse, law, params vs triggerdata) - 2 model (named cases
and every event sequence up to length 6 with two builders, for 2, 3 and 8
players, both enable timings) - 3 oracle (trigtemp.xs ids) - 4 deploy.
"""
from __future__ import annotations

import itertools
import re
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapcheck import triggerdsl as dsl  # noqa: E402

REPO = Path(__file__).resolve().parents[3]
MAP = REPO / "randmaps" / "zpistanbulb.xs"
ROOT_MAP = Path(r"C:/Program Files (x86)/Steam/steamapps/common/AoE3DE/Game/RandMaps/000_istanbul.xs")
TRIGGERDATA = REPO / "data" / "trigger" / "triggerdata.xml"
TRIGTEMP = Path(r"C:/Users/TIGO/Games/Age of Empires 3 DE/76561198347905238/Trigger/trigtemp.xs")

BEGIN = "// >>> GUN SOCKET CONVERSION LOCK BEGIN"
END = "// <<< GUN SOCKET CONVERSION LOCK END"
SOCKETS = ("NW", "NE", "SW", "SE")
SYM = {s: f"gunSocket{s}" for s in SOCKETS}
LOCK = lambda s, k: f"GunSocketLock{s}_Plr{k}"  # noqa: E731
REL = {s: f"GunSocketRelease{s}" for s in SOCKETS}
DIST = 5


def _text():
    return MAP.read_text(encoding="utf-8", errors="replace")


@pytest.fixture(scope="module")
def td():
    return dsl.load_triggerdata(TRIGGERDATA)


def _by(triggers, name):
    hit = [t for t in triggers if t.name == name]
    assert hit, f"trigger {name!r} not created"
    return hit[0]


# ------------------------------------------------------------------- 1 static
class TestStatic:
    @pytest.mark.parametrize("n", [1, 2, 3, 8])
    def test_block_creates_locks_then_release_per_socket(self, n):
        names = [t.name for t in dsl.parse_block(_text(), BEGIN, END, players=n)]
        want = [x for s in SOCKETS for x in [LOCK(s, k) for k in range(1, n + 1)] + [REL[s]]]
        assert names == want

    def test_names_obey_create_lookup_law(self):
        for t in dsl.parse_block(_text(), BEGIN, END, players=3):
            assert " " not in t.name and t.lookups and all(k == t.name for k in t.lookups), t.name

    def test_every_condition_effect_and_param_is_vanilla(self, td):
        assert dsl.check_against_triggerdata(dsl.parse_block(_text(), BEGIN, END, players=3), td) == []

    def test_no_custom_condition_is_referenced(self):
        for t in dsl.parse_block(_text(), BEGIN, END, players=3):
            for it in t.conditions + t.effects:
                assert not it.name.startswith("ZP "), f"{t.name} uses custom trigger data: {it.name}"

    @pytest.mark.parametrize("s", SOCKETS)
    @pytest.mark.parametrize("k", [1, 3])
    def test_lock_shape(self, s, k):
        t = _by(dsl.parse_block(_text(), BEGIN, END, players=3), LOCK(s, k))
        assert t.active is True and t.run_immediately is True and t.loop is False and t.priority == 4
        [c] = t.conditions
        assert c.name == "Units in Area" and c.get("DstObject") == {"sym": SYM[s]} and c.get("Player") == k
        assert c.get("UnitType") == "zpAntiShipGun" and c.get("Dist") == DIST and c.get("Op") == ">=" and c.get("Count") == 1
        sus, fire = t.effects
        assert sus.name == "Unit Action Suspend" and sus.get("SrcObject") == {"sym": SYM[s]}
        assert sus.get("ActionName") == "AutoConvert" and str(sus.get("Suspend")).lower() == "true"
        assert fire.name == "Fire Event" and fire.get("EventID") == {"trigger": REL[s]}

    @pytest.mark.parametrize("s", SOCKETS)
    def test_release_shape(self, s):
        n = 3
        t = _by(dsl.parse_block(_text(), BEGIN, END, players=n), REL[s])
        assert t.active is False and t.run_immediately is True and t.loop is False and t.priority == 4
        assert [c.get("Player") for c in t.conditions] == list(range(1, n + 1))
        for c in t.conditions:
            assert c.name == "Units in Area" and c.get("DstObject") == {"sym": SYM[s]}
            assert c.get("UnitType") == "zpAntiShipGun" and c.get("Dist") == DIST and c.get("Op") == "==" and c.get("Count") == 0
        sus, *fires = t.effects
        assert sus.name == "Unit Action Suspend" and sus.get("SrcObject") == {"sym": SYM[s]}
        assert sus.get("ActionName") == "AutoConvert" and str(sus.get("Suspend")).lower() == "false"
        assert [f.get("EventID") for f in fires] == [{"trigger": LOCK(s, k)} for k in range(1, n + 1)]

    def test_socket_ids_and_placement(self):
        text = _text()
        for s in SOCKETS:
            assert f'int {SYM[s]} = rmGetGroupingInstanceUnitByType(gun{s}Placement, "zpSocketAntiShipGun") + instanceIdShift;' in text
        assert text.find("int gunSocketSE = ") < text.find(BEGIN)
        assert text.find('rmCreateTrigger("AntiShipGunsPrebuilt"') < text.find(BEGIN)
        assert text.find("int gk = 0;") < text.find(BEGIN), "the block reuses gk; it must already be declared"


# -------------------------------------------------------------------- 2 model
EVENTS = ("place1", "place2", "cancel", "complete", "destroy", "rebuild2", "wait")


def _event(w, s, ev):
    if ev == "place1":
        w.gun[s] = {1: 1}
    elif ev == "place2":
        w.gun[s] = {2: 1}
    elif ev in ("cancel", "destroy"):
        w.gun[s] = {}
    elif ev == "rebuild2":
        w.gun[s] = {2: 1}          # destroyed and re-placed by the other side within one tick


def _check(sim, s, n):
    w = sim.world
    assert w.suspended[s] == w.any_gun(s), (w.gun[s], w.suspended[s], w.log[-3:])
    rel = sim.enabled[REL[s.replace('gunSocket', '')]]
    assert rel == w.suspended[s], "Release must be armed exactly while locked"
    if not w.suspended[s]:
        assert all(sim.enabled[LOCK(s.replace('gunSocket', ''), k)] for k in range(1, n + 1)), "all locks re-armed when unlocked"


_PARSED = {}


def _triggers(n):
    if n not in _PARSED:
        _PARSED[n] = dsl.parse_block(_text(), BEGIN, END, players=n)
    return _PARSED[n]


def _run(n, s, events, same_tick, prebuilt_by=0):
    triggers = _triggers(n)
    w = dsl.World(list(SYM.values()))
    key = SYM[s]
    if prebuilt_by:
        w.gun[key] = {prebuilt_by: 1}
    sim = dsl.Sim(triggers, w, same_tick=same_tick)
    sim.settle(3); _check(sim, key, n)
    for ev in events:
        _event(w, key, ev); sim.settle(3); _check(sim, key, n)
    return sim


class TestModel:
    @pytest.mark.parametrize("same_tick", [False, True])
    @pytest.mark.parametrize("n", [1, 2, 3])
    @pytest.mark.parametrize("s", SOCKETS)
    def test_start_states(self, n, s, same_tick):
        sim = _run(n, s, [], same_tick)
        assert sim.world.suspended[SYM[s]] is False
        sim = _run(n, s, [], same_tick, prebuilt_by=1)
        assert sim.world.suspended[SYM[s]] is True

    @pytest.mark.parametrize("same_tick", [False, True])
    @pytest.mark.parametrize("events", [
        ["place1", "complete", "destroy"],
        ["place1", "cancel"],
        ["place1", "complete", "destroy", "place2", "complete"],     # captured and rebuilt by the enemy
        ["place1", "complete", "rebuild2"],                          # swapped within one tick
        ["place1", "destroy", "place1", "destroy", "place2", "destroy", "place1"],
        ["wait", "wait", "place2", "wait", "destroy", "wait"],
    ])
    def test_named_edge_cases(self, events, same_tick):
        _run(2, "NW", events, same_tick)

    @pytest.mark.parametrize("same_tick", [False, True])
    @pytest.mark.parametrize("n", [2, 3])
    def test_every_event_sequence_up_to_length_5(self, n, same_tick):
        """Exhaustive: 7 events, every sequence of length 1..5 (19,607 runs)."""
        count = 0
        for length in range(1, 6):
            for ev in itertools.product(EVENTS, repeat=length):
                _run(n, "NE", list(ev), same_tick); count += 1
        assert count == sum(7 ** k for k in range(1, 6))

    def test_eight_players_named_cases(self):
        _run(8, "SW", ["place1", "complete", "destroy", "place2", "rebuild2", "destroy"], False)

    def test_sockets_are_independent(self):
        triggers = dsl.parse_block(_text(), BEGIN, END, players=2)
        w = dsl.World(list(SYM.values())); sim = dsl.Sim(triggers, w); sim.settle()
        w.gun[SYM["SW"]] = {2: 1}; sim.settle()
        assert w.suspended[SYM["SW"]] is True and all(w.suspended[SYM[x]] is False for x in ("NW", "NE", "SE"))


# ------------------------------------------------------------------- 3 oracle
@pytest.mark.slow
class TestTrigtempOracle:
    """Needs the game to have generated trigtemp.xs from THIS map."""

    def _text(self):
        if not TRIGTEMP.exists():
            pytest.skip("no generated trigtemp.xs")
        if TRIGTEMP.stat().st_mtime < MAP.stat().st_mtime:
            pytest.skip("trigtemp.xs older than the map - regenerate in game first")
        return TRIGTEMP.read_text(encoding="utf-8", errors="replace")

    @pytest.mark.parametrize("s", SOCKETS)
    def test_rules_use_the_same_socket_id_as_the_ai_family(self, s):
        text = self._text()
        m = re.search(r'rule _ASGun%s_ON_Plr1.*?trCountUnitsInArea\("(\d+)",1,"zpSocketAntiShipGun"' % s, text, re.S)
        assert m, f"ASGun{s}_ON_Plr1 not in trigtemp"
        sid = m.group(1)
        lock = re.search(r'rule _%s\s+highFrequency\s+active\s+runImmediately\s*\{(.*?)\n\}' % LOCK(s, 1), text, re.S)
        rel = re.search(r'rule _%s\s+highFrequency\s+inactive\s+runImmediately\s*\{(.*?)\n\}' % REL[s], text, re.S)
        assert lock and rel, "lock rules missing from trigtemp"
        assert f'trCountUnitsInArea("{sid}",1,"zpAntiShipGun",5) >= 1' in lock.group(1)
        assert f'trUnitSelectByID({sid});' in lock.group(1) and 'trUnitSuspendAction("AutoConvert",True);' in lock.group(1)
        assert f'trCountUnitsInArea("{sid}",1,"zpAntiShipGun",5) == 0' in rel.group(1)
        assert 'trUnitSuspendAction("AutoConvert",False);' in rel.group(1)


# ------------------------------------------------------------------- 4 deploy
class TestDeploy:
    def test_repo_map_is_one_to_one_with_the_game_root_copy(self):
        if not ROOT_MAP.exists():
            pytest.skip("no Game-root working copy on this machine")
        assert ROOT_MAP.read_bytes() == MAP.read_bytes()

    def test_triggerdata_untouched(self):
        import subprocess
        out = subprocess.run(["git", "-C", str(REPO), "status", "--short", "--", "data/trigger"], capture_output=True, text=True).stdout
        assert out.strip() == "", "this design must not touch trigger data"
