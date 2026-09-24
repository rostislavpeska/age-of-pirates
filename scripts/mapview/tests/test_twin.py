"""mapview.twin: the expected side from mapsim (grouping members at anchor + offset, counts x items x players,
unjudged / unmodelled lists, coin worlds, the save's map size, the lobby's team layout), the member-vote join on
synthetic census units (case-insensitive names, per-def search radius, owners), the report files and the CLI's save
checks (wf_twin_review F2-F5, F7, F9-F11; wf verify M1-M4, L1-L8; 2026-09-24).

Offline everywhere: synthetic census units, the committed samples and the repo's randmaps + grouping exports. The
acceptance runs on <profile>/Scenario/LondonIndivUnitIDs.age3Yscn and mapview_london4p_live.age3Yscn are
local("profile"), each against the script and exports of a pinned git revision (no mtime asserts)."""
import json
import math
import random
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
from scripts.mapview import twin as TW  # noqa: E402

LONDON = REPO / "randmaps" / "zplondon.xs"
GROUPINGS = REPO / "game" / "randmaps" / "groupings"
BENCH = REPO / "sandbox" / "census" / "samples" / "bench" / "ub_unitbench_unit_s4242.age3Yscn"
INMATCH = REPO / "sandbox" / "census" / "samples" / "Carib-afterPirates.age3Ysav"
PROFILE = REPO.parents[2]
LONDON_SAVE = PROFILE / "Scenario" / "LondonIndivUnitIDs.age3Yscn"
LIVE_SAVE = PROFILE / "Scenario" / "mapview_london4p_live.age3Yscn"
SAVE_REV = "cc050ea4"          # 2026-09-22 18:29, the commit before the save (18:30): its script and exports
LIVE_REV = "94577656"          # 2026-09-24 11:23, the last commit before the live save (12:07): its script and exports
LOBBY = "1,2/3,4"              # both London saves: players 1 and 2 on the north bank (TC owners 1 / 2 there)


# ----------------------------------------------------------------------------- helpers
def _spot(x, z, arm=""):
    return {"arm": arm, "x_m": x, "z_m": z, "players": []}


def _unit(proto, x, z, cid, player=None):
    return TW.TwinObject("actual", proto, x, z, x / 400.0, z / 400.0, player, status="unjudged", census_id=str(cid))


def _gi(members, spots, gid="village#1", coin="", group="", cap=None, max_dist=0.0, variants=None, players=None,
        owner_worlds=None):
    return TW.GroupingInstance(id=gid, name=gid.split("#")[0], line=10, ref="Village", players=list(players or []),
                               spots=[dict(s) for s in spots], variants=variants or [("Village", members, "test")],
                               allow_m=4.0, max_dist_m=max_dist, coin=coin, coin_group=group, capacity=cap or {},
                               owner_worlds=dict(owner_worlds or {}))


def _def(proto, x, z, oid, judged=True, spots=None, note="", player=None, max_dist=0.0, instance=None):
    o = TW.TwinObject("expected", proto, x, z, x / 400.0, z / 400.0, player, anchor=oid, line=20,
                      instance=instance or oid, judged=judged, status="" if judged else "unjudged", note=note,
                      reason="" if judged else note, id=oid, max_dist_m=max_dist)
    if spots:
        o.spots = [dict(s, fx=s["x_m"] / 400.0, fz=s["z_m"] / 400.0) for s in spots]
    return o


# an asymmetric village: no member lands on another member's spot under a 90 degree turn
VILLAGE = [("House", -6.0, 3.0), ("House", 6.0, 3.5), ("Well", 0.0, 0.0), ("SocketTradeRoute", 0.5, -8.0),
           ("PropsPoles", -3.0, -2.0), ("PropsPoles", 4.0, -3.0), ("TownCenter", 1.0, 10.0), ("Tree", 9.0, -9.5)]


def _place(members, ax, az, start=0, rot90=False):
    out = []
    for j, (p, dx, dz) in enumerate(members):
        if rot90:
            dx, dz = -dz, dx
        out.append(_unit(p, ax + dx, az + dz, start + j))
    return out


def _state(expected, actual, groupings):
    return ([(e.id, e.status, e.match_id, e.match_dist_m, e.reason, e.x_m, e.z_m) for e in expected],
            [(a.census_id, a.status, a.match_id, a.match_dist_m, a.reason) for a in actual],
            [json.dumps(g.summary(), sort_keys=True) for g in groupings],
            [[(m.id, m.status, m.match_id) for m in g.members] for g in groupings])


# ----------------------------------------------------------------------------- the join on synthetic units
class TestGroupingVote:
    def test_snapped_anchor_is_measured_and_budgeted(self):
        # mapsim asks (100.3, 200.7); the engine lays the grouping at the even-metre anchor (102, 202)
        g = _gi(VILLAGE, [_spot(100.3, 200.7)])
        actual = _place(VILLAGE, 102.0, 202.0)
        counts = TW.join([], actual, 4.0, [g], 1.0)
        assert g.verdict == "matched" and g.votes == g.n_members == len(VILLAGE)
        assert (g.measured_x_m, g.measured_z_m) == (102.0, 202.0)
        assert g.offset_m == pytest.approx(math.hypot(1.7, 1.3))
        assert all(m.status == "matched" and m.dist_measured_m == 0.0 for m in g.members)
        # match_dist_m is from the ASKED spot (anchor + offset), so it carries the snap
        assert all(m.match_dist_m == pytest.approx(math.hypot(1.7, 1.3), abs=1e-3) for m in g.members)
        assert counts["groupings"]["matched"] == 1 and counts["extra"] == 0

    def test_member_offsets_are_world_axes_not_rotated(self):
        g = _gi(VILLAGE, [_spot(100.0, 200.0)])
        TW.join([], _place(VILLAGE, 100.0, 200.0, rot90=True), 4.0, [g], 1.0)
        assert g.verdict == "missing" and g.votes == 0
        assert all(m.status == "missing" and "grouping missing" in m.reason for m in g.members)

    def test_partial_missing_and_moved(self):
        rnd = random.Random(3)
        big = [("Prop%d" % (j % 5), rnd.uniform(-20, 20), rnd.uniform(-20, 20)) for j in range(40)]
        g = _gi(big, [_spot(300.0, 300.0)])
        TW.join([], _place(big[:20], 300.0, 300.0), 4.0, [g], 1.0)
        assert g.verdict == "partial" and g.votes == 20
        TW.join([], _place(big[:6], 300.0, 300.0), 4.0, [g], 1.0)
        assert g.verdict == "missing" and g.votes == 0          # 6/40 < VOTE_MIN: nothing is claimed
        TW.join([], _place(big, 312.0, 300.0), 4.0, [g], 1.0)    # the whole block 12 m away: outside tol 4
        assert g.verdict == "missing"
        TW.join([], _place(big, 312.0, 300.0), 14.0, [g], 1.0)   # a 14 m tolerance finds it
        assert g.verdict == "matched" and g.offset_m == pytest.approx(12.0)

    def test_the_best_variant_wins(self):
        other = [("Barn", 5.0, 5.0), ("Barn", -5.0, 5.0), ("Fence", 0.0, -6.0)]
        g = _gi(None, [_spot(50.0, 50.0)], variants=[("Village_01", VILLAGE, "test"), ("Village_02", other, "test")])
        TW.join([], _place(other, 50.0, 50.0), 4.0, [g], 1.0)
        assert g.stem == "Village_02" and g.verdict == "matched" and g.votes == 3

    def test_either_arm_instances_share_their_spots_one_to_one(self):
        spots = [_spot(100.0, 100.0, "H"), _spot(100.0, 300.0, "L"), _spot(300.0, 300.0, "L")]
        cap = {TW._sk(s["x_m"], s["z_m"]): 1 for s in spots}
        g1 = _gi(VILLAGE, spots, "park#1", "either-arm", "20:park:Village", cap)
        g2 = _gi(VILLAGE, [spots[1], spots[0], spots[2]], "park#2", "either-arm", "20:park:Village", cap)
        actual = _place(VILLAGE, 100.0, 300.0) + _place(VILLAGE, 300.0, 300.0, start=100)
        TW.join([], actual, 4.0, [g1, g2], 1.0)
        assert {(g1.x_m, g1.z_m), (g2.x_m, g2.z_m)} == {(100.0, 300.0), (300.0, 300.0)}
        assert g1.verdict == g2.verdict == "matched" and g1.arm == g2.arm == "L"
        assert TW._coin_tally([], [g1, g2]) == {"detected": "L", "L": 2, "H": 0}


class TestObjectDefs:
    def test_tolerance_is_metres_and_missing_names_the_nearest(self):
        e = _def("Well", 50.0, 50.0, "20:well#1/Well")
        TW.join([e], [_unit("Well", 53.0, 50.0, "u1")], 4.0)
        assert e.status == "matched" and e.match_dist_m == pytest.approx(3.0) and e.match_id == "u1"
        TW.join([e], [_unit("Well", 56.0, 50.0, "u1")], 4.0)
        assert e.status == "missing" and "nearest Well (census u1) at 6.00 m" in e.reason
        TW.join([e], [_unit("Well", 56.0, 50.0, "u1")], 8.0)
        assert e.status == "matched"

    def test_one_unit_serves_one_object(self):
        a, b = _def("Well", 50.0, 50.0, "w#1/Well"), _def("Well", 50.0, 50.0, "w#2/Well")
        counts = TW.join([a, b], [_unit("Well", 50.5, 50.0, "u1")], 4.0)
        assert sorted([a.status, b.status]) == ["matched", "missing"] and counts["matched"] == 1

    def test_candidate_spots_of_an_either_arm_def(self):
        e = _def("Well", 100.0, 100.0, "w#1/Well", spots=[_spot(100.0, 100.0, "H"), _spot(100.0, 300.0, "L")])
        e.coin = "either-arm"
        TW.join([e], [_unit("Well", 101.0, 300.0, "u1")], 4.0)
        assert e.status == "matched" and e.arm == "L" and (e.x_m, e.z_m) == (100.0, 300.0)
        TW.join([e], [], 4.0)
        assert e.status == "missing" and "either-arm: none of the 2 candidate spots matched" in e.reason
        assert (e.x_m, e.z_m) == (100.0, 100.0)                # reset to the nominal spot

    def test_a_generic_item_matches_the_concrete_unit_the_engine_placed(self):
        # LondonIndivUnitIDs: 'harbour guard north 1' asks for a 'Nugget'; the save holds ypNuggetTradingPost
        e = _def("Nugget", 40.2, 389.0, "353:harbour guard north 1#1/Nugget")
        TW.join([e], [_unit("ypNuggetTradingPost", 43.0, 391.0, "363")], 4.0)
        assert e.status == "matched" and e.match_id == "363" and e.match_dist_m == pytest.approx(3.44, abs=0.01)


class TestNamesRadiusVariants:
    def test_names_match_case_insensitively(self):
        """The engine resolves XS item / grouping unit names case-insensitively (14 randmaps spell a proto
        differently, 2026-09-24)."""
        members = [("towncenter", 0.0, 0.0), ("HOUSE", 6.0, 0.0), ("House", -6.0, 0.0), ("well", 0.0, 6.0)]
        g = _gi(members, [_spot(100.0, 100.0)])
        e = _def("WELL", 150.0, 150.0, "20:well#1/WELL")
        actual = [_unit("TownCenter", 100.0, 100.0, "tc"), _unit("House", 106.0, 100.0, "h1"),
                  _unit("House", 94.0, 100.0, "h2"), _unit("Well", 100.0, 106.0, "w1"), _unit("Well", 150.5, 150.0, "w2"),
                  _unit("house", 104.0, 99.0, "stray")]
        counts = TW.join([e], actual, 4.0, [g], 1.0, excluded_protos=set())
        assert g.verdict == "matched" and g.votes == 4 and e.status == "matched" and e.match_id == "w2"
        assert counts["extra"] == 1 and next(a for a in actual if a.census_id == "stray").status == "extra"
        assert TW.key_label("TOWNCENTER") == "town centre" and TW.key_label("zpspcportSOCKET") == "socket"
        assert TW.save_checks([_unit("towncenter", 1.0, 1.0, 1)], 1, 10.0, 10.0)["tc_ok"] is True

    def test_a_search_radius_widens_the_def_tolerance(self):
        """wf verify M4: LondonIndivUnitIDs 'harbour guard south 1' (radius 3 m) is 5.72 m from mapsim's spot:
        judged within tol_m + max_dist_m."""
        e = _def("Nugget", 40.22, 296.0, "353:harbour guard south 1#1/Nugget", max_dist=3.0)
        TW.join([e], [_unit("ypNuggetTradingPost", 43.0, 301.0, "373")], 4.0)
        assert e.status == "matched" and e.match_dist_m == pytest.approx(5.72, abs=0.01)
        TW.join([e], [_unit("ypNuggetTradingPost", 40.22 + 7.1, 296.0, "373")], 4.0)
        assert e.status == "missing" and "at 7.10 m" in e.reason
        pinned = _def("Nugget", 40.22, 296.0, "1#1/Nugget")
        TW.join([pinned], [_unit("ypNuggetTradingPost", 43.0, 301.0, "373")], 4.0)
        assert pinned.status == "missing"                                  # no radius: tol_m alone

    def test_grouping_allow(self):
        assert TW.grouping_allow(4.0, 0.0) == 4.0 and TW.grouping_allow(4.0, 0.5) == 4.0
        assert TW.grouping_allow(4.0, 22.0) == 22.0 + TW.SNAP_M
        g = _gi(VILLAGE, [_spot(100.0, 100.0)], max_dist=10.0)
        TW.join([], _place(VILLAGE, 111.0, 104.0), 4.0, [g], 1.0)          # 11.7 m off: inside 10 + snap
        assert g.allow_m == 13.0 and g.verdict == "matched"

    def test_the_largest_supported_variant_wins(self):
        """wf verify L4: a 2-member prefix variant at 100 % must not beat the real 40-member file at 97.5 %."""
        rnd = random.Random(7)
        big = [("Prop%d" % (j % 7), rnd.uniform(-20, 20), rnd.uniform(-20, 20)) for j in range(40)]
        small = big[:2]
        g = _gi(None, [_spot(200.0, 200.0)], variants=[("Village_a", small, "test"), ("Village_b", big, "test")])
        TW.join([], _place(big[:-1], 200.0, 200.0), 4.0, [g], 1.0)
        assert g.stem == "Village_b" and g.votes == 39 and g.verdict == "matched"
        assert TW._rank(2, 2, 0, 0) > TW._rank(39, 40, 0, 1)             # sorted ascending: the big one first
        assert TW._rank(40, 100, 0, 0) > TW._rank(10, 10, 0, 1)          # unsupported 40 % loses to 100 %


class TestOwners:
    def test_def_owner_verdicts(self):
        for owner, want in ((2, "ok"), (3, "mismatch"), (0, "gaia")):
            e = _def("Well", 50.0, 50.0, "w#1/Well", player=2)
            counts = TW.join([e], [_unit("Well", 50.5, 50.0, "u", owner)], 4.0)
            assert e.status == "matched" and e.owner == want and e.census_player == owner
            assert counts["owners"]["defs"][want] == 1
        gaia = _def("Well", 50.0, 50.0, "w#1/Well")                         # no player: not judged
        assert TW.join([gaia], [_unit("Well", 50.5, 50.0, "u", 3)], 4.0)["owners"]["mismatch"] == 0 and gaia.owner == ""

    def test_a_shared_spot_claims_the_units_of_the_right_owners(self):
        """'london bridge marker': one spot, one zpAILondonBridge per player - the owner decides, not 0.8 m."""
        a = _def("zpAILondonBridge", 50.0, 50.0, "m#1/zpAILondonBridge", player=1, instance="1385:marker")
        b = _def("zpAILondonBridge", 50.0, 50.0, "m#2/zpAILondonBridge", player=2, instance="1385:marker")
        units = [_unit("zpAILondonBridge", 50.2, 50.0, "u2", 2), _unit("zpAILondonBridge", 51.0, 50.0, "u1", 1)]
        counts = TW.join([a, b], units, 4.0)
        assert (a.match_id, b.match_id) == ("u1", "u2") and a.owner == b.owner == "ok"
        assert counts["owners"]["mismatch"] == 0

    def test_grouping_owner_from_its_owned_members(self):
        def run(owners, players=(1,)):
            g = _gi(VILLAGE, [_spot(100.0, 100.0)], players=players)
            units = _place(VILLAGE, 100.0, 100.0)
            for u, o in zip(units, owners):
                u.player = o
            TW.join([], units, 4.0, [g], 1.0)
            return g
        g = run([1, 0, 0, 0, 0, 0, 1, 0])                                 # the TownCenter and a House owned
        assert g.owner == "ok" and g.owners_seen == {1: 2} and g.owners_expected == [1]
        assert sorted(m.owner for m in g.members) == ["gaia"] * 6 + ["ok"] * 2
        assert run([1, 0, 0, 0, 0, 0, 2, 0]).owner == "mismatch"
        assert run([0] * 8).owner == "gaia"                                 # no owned member: no evidence
        assert run([2] * 8, players=()).owner == ""                         # a gaia placement is not judged

    def test_an_owner_flip_is_judged_in_the_detected_world(self):
        g = _gi(VILLAGE, [_spot(100.0, 100.0)], players=[1], owner_worlds={"L": [2], "H": [1]})
        units = _place(VILLAGE, 100.0, 100.0)
        units[6].player = 2                                                 # the TownCenter
        TW.join([], units, 4.0, [g], 1.0)
        TW.check_owners([], [g], units, "L")
        assert g.owner == "ok" and g.owners_expected == [2]
        TW.check_owners([], [g], units, "H")
        assert g.owner == "mismatch"
        TW.check_owners([], [g], units, None)                               # undetected: either world's owners
        assert g.owner == "ok" and g.owners_expected == [1, 2]

    def test_suggest_team_layout(self):
        """Seats of the alternating model (1,3 / 2,4) owned 1, 3, 2, 4 in the census: the lobby was 1,2 / 3,4."""
        gs = []
        for p, q in ((1, 1), (2, 3), (3, 2), (4, 4)):
            g = _gi(VILLAGE, [_spot(100.0 * p, 100.0)], gid="seat#%d" % p, players=[p])
            g.owners_expected, g.owners_seen, g.verdict = [p], {q: 10}, "matched"
            gs.append(g)
        assert TW.suggest_team_layout([], gs, 4, 2) == {1: 0, 2: 0, 3: 1, 4: 1}
        assert TW.format_team_layout({1: 0, 2: 0, 3: 1, 4: 1}) == "1,2/3,4"
        gs[1].owners_seen = {1: 10}                                         # player 1 on two teams: no hint
        assert TW.suggest_team_layout([], gs, 4, 2) is None

    def test_parse_team_layout(self):
        assert TW.parse_team_layout("1,2/3,4", 4, 2) == {1: 0, 2: 0, 3: 1, 4: 1}
        assert TW.parse_team_layout(" 3,1 / 2,4 ", 4, 2) == {3: 0, 1: 0, 2: 1, 4: 1}
        assert TW.parse_team_layout(None, 4, 2) is None and TW.parse_team_layout("", 4, 2) is None
        for bad in ("1,2/3", "1,2,3,4", "1,1/3,4", "1,2/3,5", "1/2/3,4"):
            with pytest.raises(ValueError):
                TW.parse_team_layout(bad, 4, 2)


class TestExtraAndIdempotence:
    def _scene(self):
        g = _gi(VILLAGE, [_spot(100.0, 100.0)])
        start = _def("startingUnits", 200.0, 200.0, "30:startingUnits#1/startingUnits", judged=False,
                     note="civ starting units")
        well = _def("Well", 150.0, 100.0, "20:well#1/Well")
        actual = _place(VILLAGE, 100.0, 100.0) + [
            _unit("Well", 150.5, 100.0, "w"),
            _unit("House", 104.0, 96.0, "stray-in"),          # a member proto inside the village footprint
            _unit("House", 350.0, 350.0, "stray-far"),        # the same proto far from every footprint (a forest)
            _unit("Deer", 101.0, 101.0, "deer"),               # an unmodelled placement's item
            _unit("Explorer", 214.0, 207.0, "explorer"),       # a Hero near the startingUnits seat
            _unit("Foo", 100.0, 100.0, "foo")]
        return [well, start], actual, [g]

    def test_extra_only_inside_an_expected_footprint(self):
        expected, actual, groupings = self._scene()
        counts = TW.join(expected, actual, 4.0, groupings, 1.0, excluded_protos={"Deer"})
        st = {a.census_id: (a.status, a.reason) for a in actual}
        assert st["stray-in"][0] == "extra" and counts["extra"] == 1
        assert st["stray-far"] == ("unjudged", "outside every expected footprint of its proto (areas, unmodelled code)")
        assert st["deer"][0] == "unjudged" and "unmodelled" in st["deer"][1]
        assert st["explorer"][0] == "unjudged" and "starting units" in st["explorer"][1]
        assert st["foo"] == ("unjudged", "")
        assert expected[1].status == "unjudged" and expected[1].reason == "civ starting units"

    def test_join_is_idempotent_and_keeps_census_ids(self):
        expected, actual, groupings = self._scene()
        TW.join(expected, actual, 4.0, groupings, 1.0, excluded_protos={"Deer"})
        first = _state(expected, actual, groupings)
        TW.join(expected, actual, 4.0, groupings, 1.0, excluded_protos={"Deer"})
        assert _state(expected, actual, groupings) == first
        by_cid = {a.census_id: a for a in actual}
        for e in expected + [m for g in groupings for m in g.members]:
            if e.status == "matched":
                assert by_cid[e.match_id].match_id == e.id        # census_id and match_id cross-reference
        assert sorted(a.census_id for a in actual)[:3] == ["0", "1", "2"]   # census ids never overwritten


# ----------------------------------------------------------------------------- the expected side on London
@pytest.fixture(scope="module")
def london4():
    return TW.expected_scene(LONDON, 4, 2)


def _export_units(stem):
    root = ET.parse(GROUPINGS / (stem + ".xml")).getroot()
    return [(u.text.strip(), float(u.get("posx")), float(u.get("posz"))) for u in root.iter("unit")
            if (u.text or "").strip() and u.get("posx") is not None]


class TestExpectedLondon:
    def test_scene_basics(self, london4):
        e = london4
        assert (e.size_x_m, e.size_z_m) == (360.0, 685.0)        # 4 players (zplondon.xs 397-408)
        assert e.solve_error is None and not any("nothing placed" in w for w in e.mapsim_warnings)
        stems = [g.variants[0][0] for g in e.groupings]
        for s in ("EU_SPC_London_Tower_01", "EU_SPC_London_Tower_02", "EU_SPC_London_Bridge"):
            assert stems.count(s) == 1
        assert stems.count("EU_SPC_Player_London") == 4
        assert sorted(g.players for g in e.groupings if g.variants[0][0] == "EU_SPC_Player_London") == [[1], [2], [3], [4]]

    def test_members_sit_at_anchor_plus_offset_unrotated(self, london4):
        sx, sz = london4.size_x_m, london4.size_z_m
        for stem, key in (("EU_SPC_London_Tower_01", "zpSPCTowerOfLondon"), ("EU_SPC_London_Tower_02", "zpSPCTowerOfLondon"),
                          ("EU_SPC_London_Bridge", "zpSPCPortSocket"), ("EU_SPC_Player_London", "TownCenter")):
            g = next(g for g in london4.groupings if g.variants[0][0] == stem)
            members = TW.materialize(g, 0, 0, sx, sz)
            units = _export_units(stem)                          # an independent parse of the export
            assert len(members) == len(units)
            for m, (p, dx, dz) in zip(members, units):
                assert m.proto == p and m.x_m == pytest.approx(g.spots[0]["x_m"] + dx)
                assert m.z_m == pytest.approx(g.spots[0]["z_m"] + dz)
            assert any(m.key and m.proto == key for m in members)

    def test_counts_are_count_x_items_x_players(self, london4):
        marker = [o for o in london4.objects if o.anchor == "london bridge marker"]
        assert len(marker) == 4 and {o.proto for o in marker} == {"zpAILondonBridge"}   # players [1, 2, 3, 4]
        assert len({o.id for o in london4.objects}) == len(london4.objects)

    def test_unjudged_and_unmodelled_are_listed(self, london4):
        bass = [o for o in london4.objects if o.anchor == "bass"]
        assert len(bass) == 63 and all(o.status == "unjudged" and o.note == "search radius 324 m" for o in bass)
        start = [o for o in london4.objects if o.proto == "startingUnits"]
        assert len(start) == 4 and not any(o.judged for o in start)
        unj = {(u["name"], u["reason"].split(" (")[0]) for u in london4.unjudged}
        assert ("bass", "search radius 324 m") in unj and ("startingUnits", "civ starting units") in unj
        unm = {u["name"]: u["reason"] for u in london4.unmodelled}
        assert unm["Academy"].startswith("runtime anchor") and unm["countryside deer"].startswith("in_area")
        assert {"deer", "berrybush", "minetin"} <= london4.excluded_protos        # lower case: names match so

    def test_the_landmark_coin_is_either_arm(self, london4):
        """defenderBank (zplondon.xs 519): world L = coin 0, H = coin 1; mapsim's nominal is H for these spots."""
        eap = {(p["name"], p["proto"]): p for p in london4.coin["either_arm_placements"]}
        for name, stem in (("st paul", "EU_SPC_London_StPaul"), ("minster", "EU_SPC_London_Minster"),
                           ("stuart natives", "EU_Native_Block_Stuart_01"), ("parliament natives", "EU_Native_Block_Parlam_01"),
                           ("stuart 2", "EU_Native_Block_Stuart_02"), ("parliament 2", "EU_Native_Block_Parlam_02")):
            p = eap[(name, stem)]
            assert p["spot"] and sorted(c["arm"] for c in p["candidates"]) == ["H", "L"]
            g = next(g for g in london4.groupings if g.name == name)
            assert g.coin == "either-arm" and len(g.spots) == 2
        paul = next(g for g in london4.groupings if g.name == "st paul")
        minster = next(g for g in london4.groupings if g.name == "minster")
        assert {(s["x_m"], s["z_m"]) for s in paul.spots} == {(s["x_m"], s["z_m"]) for s in minster.spots}
        assert not eap[("wall se", "EU_SPC_London_Wall_SE_01")]["spot"]     # the walls: only the owner flips
        assert not any(g.coin for g in london4.groupings if g.name.startswith("tower of london"))

    def test_expected_objects_without_a_census(self):
        objs, rs, warnings = TW.expected_objects(LONDON, 2, 2)
        assert rs.grid.size_x_m == 360 and rs.grid.size_z_m == 645          # 2 players
        assert any(o.proto == "zpSPCTowerOfLondon" and o.member is not None for o in objs)
        assert all(abs(o.x_m - o.fx * 360) < 1e-6 and abs(o.z_m - o.fz * 645) < 1e-6 for o in objs)

    def test_grouping_members_helper(self):
        m = TW.grouping_members("EU_SPC_London_Bridge")
        assert "zpSPCPortSocket" in m and "zpInvisibleGateSocket" in m
        assert TW.grouping_members("no_such_grouping_xyz") == []

    def test_the_saves_map_size_drives_the_extraction(self, london4):
        """The engine holds whole tiles (360 x 686 m for the asked 360 x 685) and converts fractions with that size:
        with size_m every spot is re-extracted; a spot moves by at most its z fraction x 1 m, x never moves."""
        e = TW.expected_scene(LONDON, 4, 2, size_m=(360.0, 686.0))
        assert (e.size_x_m, e.size_z_m, e.script_size_m, e.size_source) == (360.0, 686.0, (360.0, 685.0), "save")
        assert (london4.script_size_m, london4.size_source) == ((360.0, 685.0), "script")
        a = {g.id: g.spots[0] for g in london4.groupings}
        b = {g.id: g.spots[0] for g in e.groupings}
        assert a.keys() == b.keys()
        dz = [b[k]["z_m"] - a[k]["z_m"] for k in a]
        assert all(abs(b[k]["x_m"] - a[k]["x_m"]) < 1e-6 for k in a)
        assert all(-1e-6 <= d <= 1.0 + 1e-6 for d in dz) and max(dz) > 0.25

    def test_the_lobby_team_layout_moves_the_seats(self, london4):
        """Same team = same bank: under mapsim's (p-1) % teams model players 1 and 3 share a bank, under the lobby
        layout 1,2/3,4 of both London saves players 1 and 2 do."""
        def seats(exp):
            return {g.players[0]: g.spots[0]["z_m"] for g in exp.groupings if g.name == "player london"}
        model = seats(london4)
        lobby_scene = TW.expected_scene(LONDON, 4, 2, team_layout={1: 0, 2: 0, 3: 1, 4: 1})
        lobby = seats(lobby_scene)
        assert model[1] == model[3] != model[2] == model[4]
        assert lobby[1] == lobby[2] != lobby[3] == lobby[4]
        assert lobby_scene.team_layout == {1: 0, 2: 0, 3: 1, 4: 1} and london4.team_layout is None

    def test_in_area_groupings_are_unmodelled_not_judged_at_the_solvers_guess(self):
        """wf verify M3: zpcaribbeanwars 2p places its island cities in_area; gsolve gives them a spot, the engine
        picks its own - they are unmodelled, never judged at gsolve's guess."""
        e = TW.expected_scene(REPO / "randmaps" / "zpcaribbeanwars.xs", 2, 2)
        unm = {u["name"]: u["reason"] for u in e.unmodelled}
        for name in ("maltese4 city", "maltese5 city", "caribs2 city", "caribs3 city"):
            assert unm[name].startswith("in_area") and "is not judged" in unm[name]
            assert not any(g.name == name for g in e.groupings)


class TestLondonSynthetic:
    """A census laid out by hand the way the engine did on LondonIndivUnitIDs: world L (coin 0), every grouping
    anchor on even metres, every member at anchor + offset, every object def near its spot."""

    @staticmethod
    def _census(exp, drop=()):
        units = []

        def arm_l(spots):
            return next((s for s in spots if "L" in s["arm"].split("+")), spots[0])

        # a coin group's instances take world L's spots one each (the park pair, the menagerie pair)
        l_spots, seen = {}, {}
        for g in exp.groupings:
            if g.coin_group:
                pool = l_spots.setdefault(g.coin_group, [])
                for s in g.spots:
                    if "L" in s["arm"].split("+") and (s["x_m"], s["z_m"]) not in pool:
                        pool.append((s["x_m"], s["z_m"]))
        for g in exp.groupings:
            if g.coin_group:
                k = seen[g.coin_group] = seen.get(g.coin_group, -1) + 1
                x, z = sorted(l_spots[g.coin_group])[k]
            else:
                x, z = g.spots[0]["x_m"], g.spots[0]["z_m"]
            if g.id in drop:
                continue
            ax, az = 2 * round(x / 2), 2 * round(z / 2)
            units += _place(g.variants[0][1], ax, az, start=len(units))
        for e in exp.objects:
            if e.judged:
                s = arm_l(e.spots) if e.spots else {"x_m": e.x_m, "z_m": e.z_m}
                units.append(_unit(e.proto, s["x_m"] + 0.7, s["z_m"] - 0.4, len(units)))
        return units

    def test_world_l_generation_matches_everything(self, london4):
        e = london4
        actual = self._census(e)
        counts = TW.join(e.objects, actual, 4.0, e.groupings, 1.0, e.excluded_protos, e.size_x_m, e.size_z_m)
        assert counts["groupings"]["matched"] == counts["groupings"]["total"] == len(e.groupings)
        assert counts["missing"] == 0 and counts["extra"] == 0
        assert TW._coin_tally(e.objects, e.groupings)["detected"] == "L"
        keys = TW.key_objects(e.groupings)
        assert {k["label"] for k in keys} >= {"Keep", "town centre", "socket"}
        assert all(k["status"] == "matched" and k["dist_m"] <= 4.0 for k in keys)
        assert sum(1 for k in keys if k["label"] == "Keep") == 2 and sum(1 for k in keys if k["label"] == "town centre") == 4

    def test_a_dropped_harbour_is_missing_and_nothing_else(self, london4):
        e = london4
        harbour = next(g for g in e.groupings if g.name == "harbour north 1")
        counts = TW.join(e.objects, self._census(e, drop={harbour.id}), 4.0, e.groupings, 1.0, e.excluded_protos,
                         e.size_x_m, e.size_z_m)
        assert harbour.verdict == "missing" and counts["groupings"]["missing"] == 1
        assert counts["missing"] == harbour.n_members


# ----------------------------------------------------------------------------- report, CLI, save checks
class TestBuild:
    def test_report_without_census(self, tmp_path):
        rep = TW.build(LONDON, 2, 2, None, tmp_path, png=False)
        j = json.loads((tmp_path / "twin.json").read_text(encoding="utf-8"))
        assert j["census"] is None and j["size_x_m"] == 360 and j["counts"]["expected"] == len(j["expected"])
        for k in ("unmodelled", "unjudged", "groupings", "key_objects", "coin", "warnings", "solve_error"):
            assert k in j
        assert all({"proto", "x_m", "z_m", "fx", "fz", "status", "pixels", "census_id", "match_id"} <= set(o)
                   for o in j["expected"])
        assert rep["calibrations"] == {} or all(Path(p).is_file() for p in rep["calibrations"].values())

    def test_default_output_is_a_fresh_temp_folder(self):
        rep = TW.build(LONDON, 2, 2, None, None, png=False)
        out = Path(rep["out"])
        try:
            assert (out / "twin.json").is_file()
            assert REPO.resolve() not in out.resolve().parents
        finally:
            shutil.rmtree(out, ignore_errors=True)

    def test_png_then_json(self, tmp_path):
        pytest.importorskip("matplotlib")
        rep = TW.build(LONDON, 2, 2, None, tmp_path, png=True)
        assert rep["png"] is True and (tmp_path / "twin.png").stat().st_size > 10000
        assert json.loads((tmp_path / "twin.json").read_text(encoding="utf-8"))["png"] is True

    def test_actual_units_keep_their_census_ids(self):
        units = TW.actual_objects(BENCH, 200.0, 200.0)
        assert len(units) == 7 and [u.census_id for u in units] == [str(i) for i in range(7)]
        assert all(u.status == "unjudged" and u.match_id == "" for u in units)

    def test_save_checks(self):
        tcs = [_unit("TownCenter", 40.0 + i, 150.0, i) for i in range(4)]
        assert TW.save_checks(tcs, 4, 360.0, 685.0)["ok"]
        bad = TW.save_checks(tcs, 2, 360.0, 685.0)
        assert not bad["ok"] and "4 TownCenter but --players is 2" in bad["messages"][0]
        far = tcs[:2] + [_unit("Tree", 100.0, 670.0, "t%d" % i) for i in range(10)]
        chk = TW.save_checks(far, 2, 360.0, 645.0)            # a 4p London save read at the 2p size
        assert chk["outside"] == 10 and not chk["ok"]

    def test_save_checks_refuse_what_cannot_be_judged(self):
        """wf verify M2: nothing decoded (hard), > 0.5 % undecoded, no TownCenter while players >= 1."""
        tcs = [_unit("TownCenter", 40.0 + i, 150.0, i) for i in range(4)] + \
              [_unit("Tree", 10.0 + i % 30, 10.0 + i // 30, "t%d" % i) for i in range(996)]
        none = TW.save_checks([], 4, 360.0, 686.0, stats={"records": 2698, "decoded": 0, "undecoded": 2698})
        assert none["hard"] and not none["ok"] and ".age3Yscn" in none["messages"][0]
        few = TW.save_checks(tcs, 4, 360.0, 686.0, stats={"records": 1003, "decoded": 1000, "undecoded": 3})
        assert few["ok"] and few["undecoded_ok"] and any("3 of 1003" in m for m in few["messages"])
        many = TW.save_checks(tcs, 4, 360.0, 686.0, stats={"records": 1010, "decoded": 1000, "undecoded": 10})
        assert not many["ok"] and not many["undecoded_ok"] and not many["hard"]
        no_tc = TW.save_checks(tcs[4:], 4, 360.0, 686.0)
        assert not no_tc["ok"] and no_tc["tc_ok"] is False and "no TownCenter" in no_tc["messages"][0]

    def test_an_in_match_save_is_refused_even_with_force(self, tmp_path, capsys):
        """The committed Carib-afterPirates.age3Ysav decodes nothing (census_reader): refused, --force cannot help."""
        with pytest.raises(TW.TwinInputError) as ei:
            TW.build(LONDON, 4, 2, INMATCH, tmp_path, png=False, strict=False)
        assert not ei.value.forceable and "decodes no unit" in str(ei.value)
        args = [str(LONDON), "--players", "4", "--census", str(INMATCH), "--no-png", "--out", str(tmp_path), "--force"]
        assert TW.main(args) == 2
        out = capsys.readouterr().out
        assert "REFUSED" in out and "--force cannot judge it" in out and not (tmp_path / "twin.json").exists()

    @staticmethod
    def _fake_census(monkeypatch, units, size=(360.0, 686.0), undecoded=0):
        stats = {"records": len(units) + undecoded, "decoded": len(units), "undecoded": undecoded, "skewed": 0,
                 "map_size_m": list(size) if size else None, "warnings": []}
        monkeypatch.setattr(TW, "census_facts", lambda save: dict(stats))
        monkeypatch.setattr(TW, "actual_objects", lambda save, sx, sz: [TW.TwinObject(**vars(u)) for u in units])

    def test_cli_refuses_a_save_that_does_not_fit(self, tmp_path, monkeypatch, capsys):
        fake = [_unit("TownCenter", 40.0, 150.0 + 10 * i, i) for i in range(4)]
        self._fake_census(monkeypatch, fake, size=None)
        args = [str(LONDON), "--players", "2", "--census", str(tmp_path / "x.age3Yscn"), "--no-png", "--out", str(tmp_path)]
        assert TW.main(args) == 2 and "REFUSED" in capsys.readouterr().out
        assert not (tmp_path / "twin.json").exists()
        assert TW.main(args + ["--force"]) == 0 and (tmp_path / "twin.json").is_file()

    def test_the_saves_size_is_used_and_a_gap_warned(self, tmp_path, monkeypatch):
        fake = [_unit("TownCenter", 40.0, 150.0 + 10 * i, i) for i in range(4)]
        self._fake_census(monkeypatch, fake)
        rep = TW.build(LONDON, 4, 2, tmp_path / "x.age3Yscn", tmp_path / "a", png=False)
        assert (rep["size_x_m"], rep["size_z_m"]) == (360.0, 686.0)
        assert rep["size"] == {"save_m": [360.0, 686.0], "script_m": [360.0, 685.0], "used": "save", "gap_m": 1.0}
        assert not any("script asks" in w for w in rep["warnings"])        # 1 m: the tile rounding, not warned
        self._fake_census(monkeypatch, fake, size=(360.0, 645.0))          # a 2p London size under --players 4
        rep = TW.build(LONDON, 4, 2, tmp_path / "x.age3Yscn", tmp_path / "b", png=False)
        assert rep["size_z_m"] == 645.0 and rep["size"]["gap_m"] == 40.0
        assert any("the save's map is 360 x 645 m but the script asks 360 x 685 m" in w for w in rep["warnings"])
        self._fake_census(monkeypatch, fake, size=None)                    # no terrain header: the script's size
        rep = TW.build(LONDON, 4, 2, tmp_path / "x.age3Yscn", tmp_path / "c", png=False)
        assert rep["size"]["used"] == "script" and rep["size_z_m"] == 685.0
        assert any("no single terrain header" in w for w in rep["warnings"])

    def test_undecoded_records_are_warned(self, tmp_path, monkeypatch):
        fake = [_unit("TownCenter", 40.0, 150.0 + 10 * i, i) for i in range(4)] + \
               [_unit("Tree", 10.0 + i % 30, 10.0 + i // 30, "t%d" % i) for i in range(996)]
        self._fake_census(monkeypatch, fake, undecoded=2)
        rep = TW.build(LONDON, 4, 2, tmp_path / "x.age3Yscn", tmp_path, png=False, strict=True)
        assert any("2 of 1002 census records are undecoded" in w for w in rep["warnings"])

    def test_pixels_only_from_checked_calibrations(self, monkeypatch, tmp_path):
        """wf verify L7: accepted-but-unchecked records draw nothing (transform.load_calibration refuses them)."""
        from types import SimpleNamespace
        recs = {"ok.json": SimpleNamespace(accepted=True, checked=True, method="disc", screen="editor"),
                "unchecked.json": SimpleNamespace(accepted=True, checked=False, method="disc", screen="editor"),
                "legacy.json": SimpleNamespace(accepted=False, checked=False, method="", screen="editor", measured=True)}
        paths = []
        for name in recs:
            (tmp_path / name).write_text(name, encoding="utf-8")
            paths.append(tmp_path / name)
        monkeypatch.setattr(TW, "list_calibrations", lambda: paths)
        monkeypatch.setattr(TW.Calibration, "from_json", staticmethod(lambda text: recs[text]))
        monkeypatch.setattr(TW, "frac_to_minimap", lambda fx, fz, cal, aspect: (1.0, 2.0))
        objs, skipped = [_unit("Well", 1.0, 1.0, "u")], []
        used = TW.add_pixels(objs, 1.0, None, skipped)
        assert list(used) == ["ok"] and objs[0].pixels == {"ok": (1.0, 2.0)}
        assert any(s.startswith("unchecked.json: accepted but never passed") for s in skipped)
        assert any(s.startswith("legacy.json: not an accepted calibration") for s in skipped)

    def test_repo_output_folder_is_ignored(self):
        lines = (REPO / ".gitignore").read_text(encoding="utf-8").splitlines()
        assert "scripts/mapview/out/" in lines
        if shutil.which("git"):
            r = subprocess.run(["git", "-C", str(REPO), "check-ignore", "-q", "scripts/mapview/out/x/twin.json"])
            assert r.returncode == 0


class TestGroupingsRev:
    def test_exports_of_a_git_revision(self):
        if not TW.git_rev_available(SAVE_REV):
            pytest.skip("git history without %s (shallow clone)" % SAVE_REV)
        then = TW.grouping_variants("EU_SPC_Player_London", SAVE_REV)[0]
        now = TW.grouping_variants("EU_SPC_Player_London")[0]
        assert then[2] == "git %s" % SAVE_REV and now[2] == "mod"
        tc_then = next((dx, dz) for p, dx, dz in then[1] if p == "TownCenter")
        assert tc_then == (-1.9046, -2.2394) and len(then[1]) == 258   # the export LondonIndivUnitIDs was made with


# ----------------------------------------------------------------------------- the London save (profile)
def _rev_build(tmp_path_factory, save, rev, layout, name):
    """build() on a profile save against the script and grouping exports of a git revision (local)."""
    if not save.is_file():
        pytest.skip("local (profile): no %s" % save)
    if not TW.git_rev_available(rev):
        pytest.skip("git history without %s" % rev)
    d = tmp_path_factory.mktemp(name)
    xs = d / ("zplondon_%s.xs" % rev)
    xs.write_bytes(subprocess.run(["git", "-C", str(REPO), "show", "%s:randmaps/zplondon.xs" % rev],
                                  capture_output=True, check=True).stdout)
    return TW.build(xs, 4, 2, save, d / "out", png=False, groupings_rev=rev, strict=True, team_layout=layout)


def _assert_london_acceptance(rep, keep_ids, port_id, tc_ids, post_ids, full_votes):
    """Keeps, bridge, harbour posts and TCs matched within 4 m; the guards within tol + their 3 m radius; owners
    consistent with the lobby layout; the London grouping families voted (module docstring of the test)."""
    assert rep["save_checks"]["ok"] and rep["save_checks"]["town_centres"] == 4
    assert rep["size"]["save_m"] == [360.0, 686.0] and rep["size"]["used"] == "save" and rep["size_z_m"] == 686.0
    keys = rep["key_objects"]
    keep = [k for k in keys if k["label"] == "Keep"]
    assert sorted(k["census_id"] for k in keep) == keep_ids
    assert all(k["status"] == "matched" and k["dist_m"] <= 4.0 for k in keep)
    bridge = [k for k in keys if k["anchor"] == "london bridge"]
    assert all(k["status"] == "matched" and k["dist_m"] <= 4.0 for k in bridge)
    assert next(k for k in bridge if k["proto"] == "zpSPCPortSocket")["census_id"] == port_id
    tcs = [k for k in keys if k["label"] == "town centre"]
    assert sorted(k["census_id"] for k in tcs) == tc_ids
    assert all(k["status"] == "matched" and k["dist_m"] <= 4.0 and k["owner"] == "ok" for k in tcs)
    assert sorted(k["census_player"] for k in tcs) == [1, 2, 3, 4]
    posts = [o for o in rep["expected"] if o["proto"] == "zpOrientalFerry"]
    assert sorted(o["match_id"] for o in posts) == post_ids
    assert all(o["status"] == "matched" and o["match_dist_m"] <= 4.0 for o in posts)
    guards = [o for o in rep["expected"] if o["anchor"].startswith("harbour guard")]
    assert len(guards) == 4 and all(o["status"] == "matched" and o["match_dist_m"] <= 7.0 for o in guards)
    own = rep["counts"]["owners"]
    assert own["mismatch"] == 0 and own["world"] == "L" and own["groupings"]["ok"] == 10 and own["defs"]["ok"] == 4
    assert rep["owner_mismatches"] == []
    votes = {}
    for g in rep["groupings"]:
        if any(s in g["stem"] for s in ("London_Tower_0", "London_Bridge", "London_Harbour", "Player_London")):
            votes.setdefault(g["stem"], []).append(g["vote_frac"])
            assert g["verdict"] == "matched" and g["offset_m"] <= 4.0
    assert len(votes["EU_SPC_Player_London"]) == 4 and len(votes["EU_SPC_London_Harbour_NW_01"]) == 2
    assert all(f >= full_votes for fr in votes.values() for f in fr), votes
    walls = [g for g in rep["groupings"] if g["name"] in ("wall se", "wall nw")]
    assert len(walls) == 6 and all(g["owner"] == "ok" for g in walls)
    assert rep["coin"]["detected"] == "L"
    assert rep["counts"]["groupings"]["matched"] == 67 and rep["counts"]["groupings"]["missing"] == 2
    assert {g["name"] for g in rep["groupings"] if g["verdict"] == "missing"} == {"riverside south", "riverside north"}
    assert rep["counts"]["extra"] == 0


@pytest.mark.local("profile")
class TestLondonSave:
    """<profile>/Scenario/LondonIndivUnitIDs.age3Yscn: 4 players / 2 teams, generated 2026-09-22 18:30, 360 x 686 m
    (180 x 343 tiles for rmSetMapSize(360, 685)). Measured 2026-09-24 against the script and exports of SAVE_REV,
    lobby layout 1,2/3,4: groupings 67/69 matched (the two riverside blocks at x = 12 m have no member within
    reach), key objects 17/17, owners 0 mismatches (4 defs, 10 groupings ok), extra 0, coin world L; Keeps 1.02 /
    2.04 m, the port socket 0.60 m, TCs 1.02-2.04 m, posts 0.58-2.59 m, guards 2.62-5.29 m."""

    @pytest.fixture(scope="class")
    def rev_report(self, tmp_path_factory):
        return _rev_build(tmp_path_factory, LONDON_SAVE, SAVE_REV, LOBBY, "twin_rev")

    def test_acceptance_on_the_save_time_inputs(self, rev_report):
        _assert_london_acceptance(rev_report, ["1050", "1762"], "227", ["7862", "8124", "8385", "8647"],
                                  ["169", "170", "171", "172"], 0.99)
        assert rev_report["counts"]["key_objects"] == {"total": 17, "matched": 17}

    def test_without_the_layout_the_owners_point_to_it(self, tmp_path_factory):
        rep = _rev_build(tmp_path_factory, LONDON_SAVE, SAVE_REV, None, "twin_rev_model")
        assert rep["counts"]["owners"]["mismatch"] == 5                      # both seats 2 / 3 and the three SE walls
        assert {(o["name"], tuple(o["expected"])) for o in rep["owner_mismatches"]} == \
               {("player london", (2,)), ("player london", (3,)), ("wall se", (2,))}
        assert any("the census owners fit --team-layout 1,2/3,4" in w for w in rep["warnings"])

    def test_later_exports_are_seen_in_the_votes(self, tmp_path_factory):
        """(wf verify L8: content, not mtimes.) The same save against LIVE_REV's script and exports: the player block
        (258 -> 385 members) and the Tower exports changed after the generation - their votes drop to partial - while
        the Keeps, the port socket, the TCs and the posts still match within 4 m."""
        then = TW.grouping_variants("EU_SPC_Player_London", SAVE_REV)[0][1]
        later = TW.grouping_variants("EU_SPC_Player_London", LIVE_REV)[0][1]
        assert (len(then), len(later)) == (258, 385)
        rep = _rev_build(tmp_path_factory, LONDON_SAVE, LIVE_REV, LOBBY, "twin_rev_later")
        verdicts = {(g["stem"], g["verdict"]) for g in rep["groupings"]
                    if g["stem"] in ("EU_SPC_Player_London", "EU_SPC_London_Tower_01", "EU_SPC_London_Tower_02")}
        assert verdicts == {("EU_SPC_Player_London", "partial"), ("EU_SPC_London_Tower_01", "partial"),
                            ("EU_SPC_London_Tower_02", "partial")}
        keys = rep["key_objects"]
        assert all(k["status"] == "matched" and k["dist_m"] <= 4.0 for k in keys
                   if k["label"] in ("Keep", "town centre") or k["proto"] == "zpSPCPortSocket")
        assert all(o["status"] == "matched" and o["match_dist_m"] <= 4.0
                   for o in rep["expected"] if o["proto"] == "zpOrientalFerry")

    def test_cli_refuses_the_wrong_player_count(self, tmp_path, capsys):
        if not LONDON_SAVE.is_file():
            pytest.skip("local (profile): no %s" % LONDON_SAVE)
        rc = TW.main([str(LONDON), "--players", "2", "--census", str(LONDON_SAVE), "--no-png", "--out", str(tmp_path)])
        out = capsys.readouterr().out
        assert rc == 2 and "4 TownCenter but --players is 2" in out
        assert "the save's map is 360 x 686 m but the script asks 360 x 645 m" in out


@pytest.mark.local("profile")
class TestLiveSave:
    """<profile>/Scenario/mapview_london4p_live.age3Yscn: London 4p / 2 teams from the post-September-patch editor,
    2026-09-24 12:07 (random seed, 10375 records, 360 x 686 m). Measured 2026-09-24 against LIVE_REV, lobby layout
    1,2/3,4: groupings 67/69 (the riverside blocks again), key objects 35/35, owners 0 mismatches, extra 0, coin
    world L; Keeps 1.02 / 2.04 m, bridge sockets 0.60 m, TCs 2.04 m, posts 2.36-3.98 m, guards 0.93-6.95 m."""

    @pytest.fixture(scope="class")
    def rev_report(self, tmp_path_factory):
        return _rev_build(tmp_path_factory, LIVE_SAVE, LIVE_REV, LOBBY, "twin_live")

    def test_acceptance(self, rev_report):
        _assert_london_acceptance(rev_report, ["1052", "1767"], "226", ["7884", "8273", "8661", "9050"],
                                  ["169", "170", "171", "172"], 0.99)
        assert rev_report["counts"]["key_objects"] == {"total": 35, "matched": 35}
        tcs = {k["census_id"]: k["census_player"] for k in rev_report["key_objects"] if k["label"] == "town centre"}
        assert tcs == {"7884": 1, "8273": 2, "8661": 3, "9050": 4}



# EU_SPC_London_Harbour_NW_01 as the XML lists it (2026-09-24): two zpHarbourPlatform 0.54 m apart,
# (-9.2402, -9.1243) and (-9.7146, -8.8550)
HARBOUR_NW = [
    ("zpHarbourShip", -14.7988, -11.6212),
    ("zpHarbourPlatform", -9.2402, -9.1243),
    ("zpHarbourPlatform", -1.5160, -9.7194),
    ("zpHarbourPlatform", -3.5726, -10.0892),
    ("zpHarbourPlatform", 7.4057, -9.2673),
    ("zpHarbourPlatform", 7.1765, -9.1928),
    ("zpHarbourPlatform", 12.1783, -9.0225),
    ("zpHarbourPlatform", 2.1682, -10.0028),
    ("zpHarbourPlatform", -14.2435, -8.9938),
    ("zpHCFisherman", -10.7817, -11.9980),
    ("NativePirates", 7.0151, -12.7161),
    ("zpHarbourPlatform", -9.7146, -8.8550),
    ("zpHarbourPlatform", -10.0714, -1.6820),
    ("zpHarbourPlatform", 7.6733, -2.4893),
    ("zpPropMarketStall", 4.9722, 2.0613),
    ("zpPropMarketStall", -7.9050, 3.5114),
    ("zpPropMarketStall", -4.2134, 5.1357),
    ("zpPropMarketStall", 4.6576, 4.5095),
    ("zpNativeStatueVenetian", 3.9947, 8.0153),
    ("zpNativeStatueVenetian", -6.2264, 8.1172),
]


def test_a_vote_tie_goes_to_the_exact_anchor():
    """The 2880x1800 device's London save (2026-09-24): harbour north 1 lay exactly at (40.0, 378.0) (every member's
    census offset equals its XML offset to 4 decimals), mapsim asked (40.22, 379.0). Pairing one platform's unit with
    its 0.54 m twin's offset seeded the anchor (39.53, 378.27): with the 1 m member tolerance it also drew 20 votes,
    and the old tie-break (nearest to the asked spot, by 0.02 m) chose it. The claim then left one platform unclaimed:
    1 member missing + 1 census unit 'extra' on a grouping that spawned whole. Ties now go to the smallest residual."""
    g = _gi(HARBOUR_NW, [_spot(40.22, 379.0)], gid="harbour north 1#1")
    actual = _place(HARBOUR_NW, 40.0, 378.0)
    counts = TW.join([], actual, 4.0, [g], 1.0)
    assert g.hyp == pytest.approx((40.0, 378.0), abs=1e-6)
    assert g.verdict == "matched" and g.votes == g.n_members == 20
    assert counts["extra"] == 0 and all(m.dist_measured_m == 0.0 for m in g.members)
