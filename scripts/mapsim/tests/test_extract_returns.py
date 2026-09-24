"""User-function return values, def identity by handle, unknown-handle warnings, and the per-player /
per-item counts on ResolvedPlacement (2026-09-24, minimap-twin review wf_twin_review.md F2 + F4).

Before the fix every user-function call evaluated to 0, so zplondon.xs's `int blockTowerS =
cityBlock("tower of london", "EU_SPC_London_Tower_01");` was handle 0 and rmPlaceGroupingInstanceAtLoc
on it placed nothing, silently: the Tower of London, the four player blocks and ~36 city blocks were
absent from mapsim (probe 2026-09-24, 4 players: 17 grouping placements, all walls / harbours / the
bridge; after: 78). The bridge also keyed defs by their creation LINE, which names every def a helper
creates on one line after the last one."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapsim.bridge import extraction_to_resolved  # noqa: E402
from scripts.mapsim.scene import Scenario, Scene  # noqa: E402
from scripts.mapsim.xs_extract import Extractor, extract  # noqa: E402

REPO = Path(__file__).resolve().parents[3]
FIXTURES = Path(__file__).resolve().parent / "fixtures"
LONDON = REPO / "randmaps" / "zplondon.xs"

HEADER = "void main(void){ rmSetMapSize(400, 400);\n"

# zplondon.xs's helper, verbatim shape (zplondon.xs 204-212): every grouping def is created on ONE line.
CITY_BLOCK = ('int cityBlock(string blockName = "", string blockFile = "")\n'
              "{\n"
              "\tint g = rmCreateGrouping(blockName, blockFile);\n"
              "\trmSetGroupingMinDistance(g, 0.00);\n"
              "\trmSetGroupingMaxDistance(g, 0.50);\n"
              "\treturn(g);\n"
              "}\n")


def run_src(src: str, sc: Scenario = Scenario(2, 2)):
    ex_obj = Extractor(sc)
    return ex_obj, ex_obj.run(src)


def nothing_placed(ex):
    return [w for w in ex.warnings if "nothing placed" in w]


class TestReturnValues:
    def test_return_expression_reaches_the_caller(self):
        src = ("int seven() { return(3 + 4); }\n"
               "float half(float v = 0.0) { return v * 0.5; }\n"
               "int nothing() { return; }\n"
               "void noReturn() { int x = 1; }\n"
               + HEADER +
               'int d = rmCreateObjectDef("n " + seven() + " " + half(3.0) + " " + nothing() + " " + noReturn());\n}')
        _, ex = run_src(src)
        # value carried (was "0 0 0 0"); a bare return / no return keeps the old 0
        assert next(iter(ex.defs.values())).name == "n 7 1.5 0 0"

    def test_helper_returned_grouping_handle_places(self):
        src = (CITY_BLOCK + HEADER +
               'int blockA = cityBlock("tower of london", "EU_SPC_London_Tower_01");\n'
               'int blockB = cityBlock("player london", "EU_SPC_Player_London");\n'
               "rmPlaceGroupingInstanceAtLoc(blockA, 0.1, 0.4, 0);\n"
               "for (i = 1; <= cNumberNonGaiaPlayers) {\n"
               "\trmPlaceGroupingInstanceAtLoc(blockB, 0.2 * i, 0.2, i);\n"
               "}\n}")
        _, ex = run_src(src, Scenario(2, 2))
        assert ex.warnings == []
        rs = extraction_to_resolved(ex)
        got = sorted((p.proto, p.name, round(p.x, 6), round(p.z, 6), tuple(p.players)) for p in rs.placements)
        assert got == [("EU_SPC_London_Tower_01", "tower of london", 0.1, 0.4, ()),
                       ("EU_SPC_Player_London", "player london", 0.2, 0.2, (1,)),
                       ("EU_SPC_Player_London", "player london", 0.4, 0.2, (2,))]
        assert all(p.is_grouping and p.line == 3 for p in rs.placements)     # one creation line for all

    def test_return_value_feeds_geometry(self):
        # the zpistanbulb.xs routeRealZ() idiom: a helper places a controller, reads it back and RETURNS the
        # fraction; before the fix every caller got 0 (Istanbul's whole city laid out around z = 0)
        src = ("float realZ() {\n"
               '\tint ctrl = rmCreateObjectDef("controller");\n'
               '\trmAddObjectDefItem(ctrl, "zpSPCWaterSpawnPoint", 1, 0.0);\n'
               "\trmPlaceObjectDefAtLoc(ctrl, 0, 0.5, 0.46);\n"
               "\tvector loc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(ctrl, 0));\n"
               "\treturn rmZMetersToFraction(xsVectorGetZ(loc));\n"
               "}\n" + HEADER +
               "float laneZ = realZ();\n"
               'int a = rmCreateArea("quay");\n'
               "rmSetAreaLocation(a, 0.5, laneZ + 0.05);\n}")
        _, ex = run_src(src)
        area = next(a for a in ex.areas.values() if a.name == "quay")
        assert area.z == pytest.approx(0.51)


class TestTaintedForkUnwinding:
    FN = ("int pick() {{\n"
          "\tif (rmRandInt(0, 1) == {arm}) {{ return(5); }} else {{ return(9); }}\n"
          "\treturn(1);\n"
          "}}\n")

    def test_nominal_arm_return_decides(self):
        # nominal = the lo-roll: rmRandInt(0, 1) -> 0, so `== 0` takes the then-arm, `== 1` the else-arm
        for arm, want in ((0, 5), (1, 9)):
            src = (self.FN.format(arm=arm) + HEADER +
                   'int d = rmCreateObjectDef("got " + pick());\n'
                   "rmPlaceObjectDefAtLoc(d, 0, 0.5, 0.5);\n}")
            ex_obj, ex = run_src(src)
            assert next(iter(ex.defs.values())).name == f"got {want}"
            # nothing leaks out of the fork: the later placement is nominal and unlabelled
            assert ex_obj.variant_stack == [] and ex_obj.alt_depth == 0
            assert ex.placements[0].nominal and ex.placements[0].variant == ""

    def test_non_nominal_return_does_not_end_the_function_and_both_arms_run(self):
        src = ("int probe = 0;\n"
               "int f() {\n"
               "\tif (rmRandInt(0, 1) == 1) { probe = 7; return(5); }\n"   # the ALT arm (lo-roll 0 != 1)
               "\treturn(1);\n"
               "}\n" + HEADER +
               'int d = rmCreateObjectDef("f " + f() + " probe " + probe);\n}')
        _, ex = run_src(src)
        # the alt arm ran for STATE (probe = 7, last write wins) but its return did not decide
        assert next(iter(ex.defs.values())).name == "f 1 probe 7"

    def test_break_in_the_nominal_arm_ends_the_loop(self):
        src = (HEADER +
               "int n = 0;\n"
               "for (i = 0; < 10) {\n"
               "\tn = n + 1;\n"
               "\tif (rmRandInt(0, 1) == 0) { break; }\n"
               "}\n"
               'int d = rmCreateObjectDef("n " + n);\n}')
        ex_obj, ex = run_src(src)
        assert next(iter(ex.defs.values())).name == "n 1"
        assert ex_obj.variant_stack == [] and ex_obj.alt_depth == 0


class TestDefIdentityByHandle:
    def test_defs_from_one_helper_line_keep_their_own_identity(self):
        src = ("int mk(string n = \"\", string proto = \"\") {\n"
               "\tint d = rmCreateObjectDef(n);\n"
               "\trmAddObjectDefItem(d, proto, 2, 0.0);\n"
               "\treturn(d);\n"
               "}\n" + HEADER +
               'int a = mk("alpha", "Deer");\n'
               'int b = mk("beta", "Elk");\n'
               "rmPlaceObjectDefAtLoc(a, 0, 0.5, 0.5);\n"
               "rmPlaceObjectDefAtLoc(b, 0, 0.5, 0.5);\n}")     # same line, same spot, different defs
        _, ex = run_src(src)
        assert [p.def_handle for p in ex.placements] == [a for a in ex.defs if ex.defs[a].name in ("alpha", "beta")]
        rs = extraction_to_resolved(ex)
        got = sorted((p.name, p.items, p.item_counts) for p in rs.placements)
        # the old line-keyed lookup labelled both 'beta' and the collapse merged them into one record
        assert got == [("alpha", ("Deer",), (("Deer", 2),)), ("beta", ("Elk",), (("Elk", 2),))]

    def test_loop_created_defs_are_separate_placements(self):
        # zpIceland.xs fish loop shape: a def per iteration, all searched from the map centre
        src = (HEADER +
               "for (i = 0; < 4) {\n"
               '\tint fishID = rmCreateObjectDef("fish" + i);\n'
               '\trmAddObjectDefItem(fishID, "FishSalmon", 3, 8.0);\n'
               "\trmPlaceObjectDefAtLoc(fishID, 0, 0.5, 0.5, 1);\n"
               "}\n}")
        _, ex = run_src(src)
        rs = extraction_to_resolved(ex)
        assert sorted(p.name for p in rs.placements) == ["fish0", "fish1", "fish2", "fish3"]
        assert all(p.item_counts == (("FishSalmon", 3),) for p in rs.placements)


class TestUnknownHandleWarning:
    def test_placement_on_an_unknown_handle_warns(self):
        src = (HEADER +
               "int ghost = 0;\n"
               "rmPlaceGroupingAtLoc(ghost, 0, 0.5, 0.5);\n"
               "int arr = xsArrayCreateInt(3, 0);\n"
               "rmPlaceObjectDefAtLoc(xsArrayGetInt(arr, rmRandInt(0, 2)), 0, 0.5, 0.5);\n}")
        _, ex = run_src(src)
        assert ex.placements == []
        warns = nothing_placed(ex)
        assert len(warns) == 2
        assert warns[0].startswith("line 3: rmPlaceGroupingAtLoc on unknown def handle 0")
        assert warns[1].startswith("line 5: rmPlaceObjectDefAtLoc on a runtime-dependent def handle")

    def test_monastery_builder_is_a_silent_documented_gap(self):
        src = (HEADER +
               "for (i = 1; <= cNumberNonGaiaPlayers) {\n"
               "\tif (ypIsAsian(i) && rmGetNomadStart() == false)\n"
               "\t\trmPlaceObjectDefAtLoc(ypMonasteryBuilder(i, 1), i, 0.5, 0.5);\n"
               "}\n}")
        _, ex = run_src(src)
        assert ex.placements == [] and ex.warnings == []


class TestPlayersAndItemCounts:
    def test_per_player_loop_at_one_spot(self):
        # zplondon.xs 'london bridge marker': one def, one spot, one call per player -> ONE record
        src = (HEADER +
               'int mark = rmCreateObjectDef("london bridge marker");\n'
               'rmAddObjectDefItem(mark, "zpAILondonBridge", 1, 0.0);\n'
               "for (i = 1; <= cNumberNonGaiaPlayers) { rmPlaceObjectDefAtLoc(mark, i, 0.78, 0.5); }\n}")
        _, ex = run_src(src, Scenario(4, 2))
        (p,) = extraction_to_resolved(ex).placements
        assert p.players == [1, 2, 3, 4] and p.per_player and p.player_id == 1 and p.count == 1
        assert p.item_counts == (("zpAILondonBridge", 1),)

    def test_gaia_and_runtime_players_are_not_listed(self):
        src = (HEADER +
               'int d = rmCreateObjectDef("mixed");\n'
               'rmAddObjectDefItem(d, "Deer", rmRandInt(6, 8), 6.0);\n'
               'rmAddObjectDefItem(d, "BerryBush", 5, 4.0);\n'
               'rmAddObjectDefItem(d, "Elk", xsArrayGetInt(1, 0), 4.0);\n'
               "rmPlaceObjectDefAtLoc(d, 0, 0.3, 0.3);\n"
               "rmPlaceObjectDefAtLoc(d, rmRandInt(1, 2), 0.3, 0.3);\n"
               "rmPlaceObjectDefAtLoc(d, 2, 0.3, 0.3);\n}")
        _, ex = run_src(src)
        (p,) = extraction_to_resolved(ex).placements
        assert p.players == [2] and p.player_id == 2 and p.per_player
        # rand count -> its HI bound (the placement-count rule); a runtime count -> 1; order kept, aligned with items
        assert p.items == ("Deer", "BerryBush", "Elk")
        assert p.item_counts == (("Deer", 8), ("BerryBush", 5), ("Elk", 1))

    def test_curated_scenes_leave_the_defaults(self):
        rs = Scene.load(FIXTURES / "independence_war.scene.json").resolve(Scenario(2, 2))
        assert all(p.players == [] and p.item_counts == () for p in rs.placements)


class TestLondon:
    """randmaps/zplondon.xs itself (tracked in the repository, no game install needed)."""

    @pytest.fixture(scope="class")
    def london4(self):
        ex = extract(LONDON, Scenario(4, 2))
        return ex, extraction_to_resolved(ex)

    def test_no_placement_is_lost_on_a_dead_handle(self, london4):
        ex, _ = london4
        assert nothing_placed(ex) == []

    def test_tower_of_london_both_banks(self, london4):
        _, rs = london4
        towers = {p.proto: p for p in rs.placements if p.proto.startswith("EU_SPC_London_Tower_")}
        assert sorted(towers) == ["EU_SPC_London_Tower_01", "EU_SPC_London_Tower_02"]
        south, north = towers["EU_SPC_London_Tower_01"], towers["EU_SPC_London_Tower_02"]
        assert south.is_grouping and north.is_grouping
        assert south.z < 0.5 < north.z                     # the south bank's Tower and the north bank's

    def test_player_blocks_one_per_player(self, london4):
        _, rs = london4
        seats = [p for p in rs.placements if p.proto == "EU_SPC_Player_London"]
        assert sorted(p.players for p in seats) == [[1], [2], [3], [4]]
        assert all(p.x is not None and p.z is not None for p in seats)

    def test_city_blocks_keep_their_own_grouping_files(self, london4):
        _, rs = london4
        tower = next(p for p in rs.placements if p.proto == "EU_SPC_London_Tower_01")
        # every cityBlock() def is created on the Tower's creation line; the grouping files stay distinct
        # (29 distinct files on 2026-09-24; the line-keyed bridge named them all after the last def)
        city = [p for p in rs.placements if p.is_grouping and p.line == tower.line]
        assert len({p.proto for p in city}) >= 20 and len({p.name for p in city}) >= 20

    def test_bridge_marker_counts_every_player(self, london4):
        _, rs = london4
        (mark,) = [p for p in rs.placements if p.name == "london bridge marker"]
        assert mark.players == [1, 2, 3, 4] and mark.item_counts == (("zpAILondonBridge", 1),)
