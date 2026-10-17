"""S8 / S9 and the Danube's build order (owner 2026-10-07: "you build trade route after the bridges!!! The build order
needs FORENSIC ANALYSIS AND REINSPECTION. BUG CATCH AND added to test suite").

Two bugs broke Danube v8b / v9 in game:
- S8: the land trade route was built AFTER the bridges were placed (every other repo map builds its land routes first;
  a bridge goes onto a finished road).
- S9: the river was drawn through rmGetTradeRouteWayPoint reads every 1/60 of each route; in game route 1 returned the
  map origin at both ends, the river discs ran to the map corner and across the inner shore, and 15% of the map stayed
  water (saves "Danube - total fsailure" and "Broken"; scratchpad hypo_test.py: the same best hypothesis out of 64 on
  both saves). mapsim now reads route ends as unknown and records them; S9 fails on any such read that is used.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapcheck.universal import _build_order_findings, _placement_findings, _strip  # noqa: E402

REPO = Path(__file__).resolve().parents[3]
DANUBE = REPO / "game" / "randmaps" / "zpdanube.xs"

HEAD = """void main(void) {
   rmSetStatusText("", 0.1);
   rmSetSeaLevel(0.0);
   rmTerrainInitialize("grass", 2.0);
   rmSetMapSize(512, 512);
   rmPlacePlayersCircular(0.35, 0.4, 0);
   int bridgeID = rmCreateGrouping("bridge north", "Bridge_Universal_03");
   int riverRoute = rmCreateTradeRoute();
   rmAddTradeRouteWaypoint(riverRoute, 0.0, 0.5);
   rmAddTradeRouteWaypoint(riverRoute, 1.0, 0.5);
   int landRoute = rmCreateTradeRoute();
   rmAddTradeRouteWaypoint(landRoute, 0.5, 0.0);
   rmAddTradeRouteWaypoint(landRoute, 0.5, 1.0);
   int mark = rmCreateObjectDef("mark");
   rmAddObjectDefItem(mark, "zpSPCWaterSpawnPoint", 1, 0.0);
"""
TAIL = """   rmSetStatusText("", 1.0);
}
"""


def _findings(tmp_path, body, name="fixture"):
    from scripts.mapsim.scene import Scenario
    from scripts.mapsim.xs_extract import extract
    p = tmp_path / f"{name}.xs"
    src = HEAD + body + TAIL
    p.write_text(src, encoding="utf-8")
    return _build_order_findings(src, extract(p, Scenario(players=2, teams=2)), name)


class TestS8LandRouteBeforeBridges:
    def test_land_route_after_the_bridge_fails(self, tmp_path):
        f = _findings(tmp_path, """   rmBuildTradeRoute(riverRoute, "river_trail");
   rmPlaceGroupingAtLoc(bridgeID, 0, 0.5, 0.5, 1);
   rmBuildTradeRoute(landRoute, "dirt");
""")
        assert [x.check for x in f] == ["S8"] and f[0].severity == "FAIL" and "landRoute" in f[0].message

    def test_land_route_before_the_bridge_passes(self, tmp_path):
        assert _findings(tmp_path, """   rmBuildTradeRoute(riverRoute, "river_trail");
   rmBuildTradeRoute(landRoute, "dirt");
   rmPlaceGroupingAtLoc(bridgeID, 0, 0.5, 0.5, 1);
""") == []

    def test_a_water_route_after_the_bridge_is_fine(self, tmp_path):
        # zpriverina.xs 696: an australia_river_trail built after its bridges - boats, not wagons
        assert _findings(tmp_path, """   rmBuildTradeRoute(landRoute, "dirt");
   rmPlaceGroupingAtLoc(bridgeID, 0, 0.5, 0.5, 1);
   rmBuildTradeRoute(riverRoute, "australia_river_trail");
""") == []


class TestS9RouteEndReads:
    def test_a_read_at_a_route_end_that_is_used_fails(self, tmp_path):
        f = _findings(tmp_path, """   rmBuildTradeRoute(landRoute, "dirt");
   vector endLoc = rmGetTradeRouteWayPoint(landRoute, 1.0);
   rmPlaceObjectDefAtPoint(mark, 0, endLoc);
""")
        assert [x.check for x in f] == ["S9"] and f[0].severity == "FAIL"

    def test_sampling_a_route_in_a_loop_reaches_its_ends(self, tmp_path):
        # the Danube v9 pattern: every 1/60 of a route, 0 and 1 included
        f = _findings(tmp_path, """   rmBuildTradeRoute(landRoute, "dirt");
   float walkF = 0.0;
   vector walkPos = xsVectorSet(0.0, 0.0, 0.0);
   for (ws=0; <= 4) {
      walkPos = rmGetTradeRouteWayPoint(landRoute, walkF);
      rmPlaceObjectDefAtPoint(mark, 0, walkPos);
      walkF = walkF + 0.25;
   }
""")
        assert {x.check for x in f} == {"S9"} and len(f) >= 2      # fraction 0 and 1

    def test_interior_reads_pass(self, tmp_path):
        assert _findings(tmp_path, """   rmBuildTradeRoute(landRoute, "dirt");
   rmPlaceObjectDefAtPoint(mark, 0, rmGetTradeRouteWayPoint(landRoute, 0.5));
   rmPlaceObjectDefAtPoint(mark, 0, rmGetTradeRouteWayPoint(landRoute, 0.12));
""") == []

    def test_an_overwritten_initializer_is_harmless(self, tmp_path):
        # zpkingofbohemia.xs 738
        assert _findings(tmp_path, """   rmBuildTradeRoute(landRoute, "dirt");
   vector socketLoc2 = rmGetTradeRouteWayPoint(landRoute, 0.0);
   socketLoc2 = rmGetTradeRouteWayPoint(landRoute, 0.12);
   rmPlaceObjectDefAtPoint(mark, 0, socketLoc2);
""") == []


def _repo_maps():
    return sorted(list((REPO / "randmaps").glob("*.xs")) + list((REPO / "game" / "randmaps").glob("*.xs")))


@pytest.mark.parametrize("path", _repo_maps(), ids=lambda p: p.relative_to(REPO).as_posix())
def test_no_repo_map_breaks_the_build_order(path):
    from scripts.mapsim.scene import Scenario
    from scripts.mapsim.xs_extract import extract
    src = path.read_text(encoding="utf-8", errors="replace")
    found = _build_order_findings(src, extract(path, Scenario(players=4, teams=2)), path.stem)
    assert found == [], "\n".join(f"line {f.line}: {f.check} {f.message}" for f in found)


class TestDanubeBuildOrder:
    """The Danube's terrain order, pinned: river routes -> land route defined -> channel -> shores -> land route BUILT
    -> bridges -> docks -> sockets; the channel never reads a route back."""

    @pytest.fixture(scope="class")
    def code(self):
        return _strip(DANUBE.read_text(encoding="utf-8"), keep_strings=True)

    def _at(self, code, pattern):
        m = re.search(pattern, code)
        assert m, pattern
        return m.start()

    def test_the_order(self, code):
        steps = [
            r'rmBuildTradeRoute\(tradeRoute3ID, "river_trail"\)',          # the river routes, first
            r'int landRouteID = rmCreateTradeRoute\(\)',                    # the land route defined
            r'int skelX = xsArrayCreateFloat',                               # the channel
            r'int northShoreID = rmCreateArea\("north outer shore"\)',      # the shores
            r'rmBuildTradeRoute\(landRouteID, "dirt"\)',                     # the land route BUILT
            r'rmPlaceGroupingAtLoc\(bridgeNorthID',                          # the bridges, on it
            r'int bridgeDockID = rmCreateArea',                              # the cliff docks
            r'rmCreateGrouping\("harbour "\+sn',                            # the harbours, sockets inside
        ]
        at = [self._at(code, s) for s in steps]
        assert at == sorted(at), [s for s, a in zip(steps, at)]

    def test_the_channel_reads_no_route_back(self, code):
        channel = code[self._at(code, r'int skelX = xsArrayCreateFloat'):
                       self._at(code, r'int northShoreID = rmCreateArea\("north outer shore"\)')]
        assert "rmGetTradeRouteWayPoint" not in channel
        assert channel.count("xsArraySetFloat(skelX,") == 10        # the authored waypoints, edge to edge


@pytest.mark.parametrize("path", _repo_maps(), ids=lambda p: p.relative_to(REPO).as_posix())
def test_no_repo_map_places_players_on_a_section_of_no_length(path):
    # S10 (Danube v12, 2026-10-07): a lone player's section (c, c) placed nobody - 1v1 and 2v1 had no Town Center for
    # the lone players. The layouts that make lone players: 1v1, 2v1, 1v7
    from scripts.mapsim.scene import Scenario
    from scripts.mapsim.xs_extract import extract
    found = []
    for sc in (Scenario(2, 2), Scenario(3, 2, team_sizes=(2, 1)), Scenario(8, 2, team_sizes=(1, 7))):
        found += [f"{sc.players}p {sc.team_sizes}: {f.message}" for f in _placement_findings(extract(path, sc), path.stem)]
    assert found == [], "\n".join(found)
