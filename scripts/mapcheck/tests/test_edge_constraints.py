"""S7: scattered objects need the map-edge constraints (rm-objects-herds "Map-edge constraints").

Owner 2026-10-06: "you miss world circle constraint for objects like treasures - this is system bug". A square map
needs a circle on every scattered object (a box alone leaves the corners open); a rectangular map needs a corner circle
AND an edge box (London's insideWorld + insideFrameRes / insideFrameTreasure). The fixtures pin the rule; the
baseline ratchet keeps the 2026-10-06 offenders from growing and every new or fixed map clean."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.mapcheck.universal import _edge_constraint_findings  # noqa: E402

REPO = Path(__file__).resolve().parents[3]
BASELINE = REPO / "scripts" / "mapcheck" / "s7_edge_baseline.json"

SPINE = """void main(void) {{
   rmSetStatusText("", 0.1);
   rmSetSeaLevel(0.0);
   rmTerrainInitialize("grass", 2.0);
   rmSetMapSize({sx}, {sz});
   rmSetWorldCircleConstraint(true);
   rmPlacePlayersCircular(0.35, 0.4, 0);
   int circleRes = rmCreatePieConstraint("inside the world circle", 0.5, 0.5, 0.0, rmXFractionToMeters(0.5)-8.0, rmDegreesToRadians(0), rmDegreesToRadians(360));
   int halfCircle = rmCreatePieConstraint("north half", 0.5, 0.5, 0.0, rmZFractionToMeters(0.5), rmDegreesToRadians(270), rmDegreesToRadians(90));
   int edgeBox = rmCreateBoxConstraint("edge box", rmXMetersToFraction(20.0), rmZMetersToFraction(20.0), 1.0-rmXMetersToFraction(20.0), 1.0-rmZMetersToFraction(20.0), 0.01);
   int mineID = rmCreateObjectDef("random mine");
   rmAddObjectDefItem(mineID, "Mine", 1, 0.0);
   rmSetObjectDefMinDistance(mineID, 0.0);
   rmSetObjectDefMaxDistance(mineID, rmXFractionToMeters(0.45));
{constraints}
   rmPlaceObjectDefAtLoc(mineID, 0, 0.5, 0.5, 4);
   rmSetStatusText("", 1.0);
}}
"""


def _findings(tmp_path, sx, sz, constraints, name="fixture"):
    from scripts.mapsim.scene import Scenario
    from scripts.mapsim.xs_extract import extract
    lines = "\n".join(f"   rmAddObjectDefConstraint(mineID, {c});" for c in constraints)
    p = tmp_path / f"{name}.xs"
    p.write_text(SPINE.format(sx=sx, sz=sz, constraints=lines), encoding="utf-8")
    return _edge_constraint_findings(extract(p, Scenario(players=2, teams=2)), name)


class TestSquare:
    def test_no_edge_constraint_fails(self, tmp_path):
        f = _findings(tmp_path, 512, 512, [])
        assert len(f) == 1 and f[0].check == "S7" and f[0].severity == "FAIL"

    def test_box_alone_fails(self, tmp_path):
        # King of Bohemia's box on a square map: the Danube's treasures left the circle (2026-10-06)
        f = _findings(tmp_path, 512, 512, ["edgeBox"])
        assert len(f) == 1 and "box alone" in f[0].message

    def test_half_circle_at_the_rim_is_not_an_edge(self, tmp_path):
        # a cardinal-direction pie reaches the rim itself: no margin, not an edge constraint
        assert len(_findings(tmp_path, 512, 512, ["halfCircle"])) == 1

    def test_circle_passes(self, tmp_path):
        assert _findings(tmp_path, 512, 512, ["circleRes"]) == []


class TestRectangular:
    def test_circle_alone_fails(self, tmp_path):
        f = _findings(tmp_path, 360, 686, ["circleRes"])
        assert len(f) == 1 and "edge box" in f[0].message

    def test_box_alone_fails(self, tmp_path):
        f = _findings(tmp_path, 360, 686, ["edgeBox"])
        assert len(f) == 1 and "corner circle" in f[0].message

    def test_circle_and_box_pass(self, tmp_path):
        assert _findings(tmp_path, 360, 686, ["circleRes", "edgeBox"]) == []


def test_route_docked_sockets_are_not_scattered(tmp_path):
    from scripts.mapsim.scene import Scenario
    from scripts.mapsim.xs_extract import extract
    src = SPINE.format(sx=512, sz=512, constraints="").replace(
        '   rmPlaceObjectDefAtLoc(mineID, 0, 0.5, 0.5, 4);',
        '   int routeID = rmCreateTradeRoute();\n'
        '   rmAddTradeRouteWaypoint(routeID, 0.1, 0.5);\n'
        '   rmAddTradeRouteWaypoint(routeID, 0.9, 0.5);\n'
        '   rmBuildTradeRoute(routeID, "dirt");\n'
        '   int socketID = rmCreateObjectDef("socket");\n'
        '   rmSetObjectDefTradeRouteID(socketID, routeID);\n'
        '   rmAddObjectDefItem(socketID, "SocketTradeRoute", 1, 0.0);\n'
        '   rmSetObjectDefMaxDistance(socketID, 60.0);\n'
        '   rmPlaceObjectDefAtLoc(socketID, 0, 0.5, 0.5);\n'
        '   rmAddObjectDefConstraint(mineID, circleRes);\n'
        '   rmPlaceObjectDefAtLoc(mineID, 0, 0.5, 0.5, 4);')
    p = tmp_path / "docked.xs"
    p.write_text(src, encoding="utf-8")
    assert _edge_constraint_findings(extract(p, Scenario(players=2, teams=2)), "docked") == []


def _repo_maps():
    return sorted(list((REPO / "randmaps").glob("*.xs")) + list((REPO / "game" / "randmaps").glob("*.xs")))


@pytest.mark.parametrize("path", _repo_maps(), ids=lambda p: p.relative_to(REPO).as_posix())
def test_ratchet_no_map_gets_worse(path):
    from scripts.mapsim.scene import Scenario
    from scripts.mapsim.xs_extract import extract
    counts = json.loads(BASELINE.read_text(encoding="utf-8"))["counts"]
    key = path.relative_to(REPO).as_posix()
    found = _edge_constraint_findings(extract(path, Scenario(players=4, teams=2)), path.stem)
    allowed = counts.get(key, 0)
    assert len(found) <= allowed, (
        f"{key}: {len(found)} scattered objects without the map-edge constraints (baseline {allowed}):\n  "
        + "\n  ".join(f"line {f.line}: {f.message}" for f in found))


def test_danube_is_clean():
    assert "game/randmaps/zpdanube.xs" not in json.loads(BASELINE.read_text(encoding="utf-8"))["counts"]


def test_baselined_legacy_maps_warn_and_new_offenders_fail(tmp_path, monkeypatch):
    # the roster stays readable: a map in the 2026-10-06 baseline gets its findings as WARN up to its count, a new map
    # (or a baselined one that got worse) FAILs
    from scripts.mapcheck import universal
    from scripts.mapcheck.runner import run
    from scripts.mapsim.scene import Scenario
    p = tmp_path / "zpedgefixture.xs"
    p.write_text(SPINE.format(sx=512, sz=512, constraints=""), encoding="utf-8")
    sev = lambda: [f.severity for f in run(p, Scenario(players=2, teams=2), static_only=True).findings if f.check == "S7"]
    monkeypatch.setattr(universal, "_edge_baseline", lambda: {})
    assert sev() == ["FAIL"]
    monkeypatch.setattr(universal, "_edge_baseline", lambda: {"zpedgefixture": 1})
    assert sev() == ["WARN"]
    monkeypatch.setattr(universal, "_edge_baseline", lambda: {"zpedgefixture": 0})
    assert sev() == ["FAIL"]
