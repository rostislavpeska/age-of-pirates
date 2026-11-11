"""Versailles' main street (user 2026-09-24): the owner's EU_Deco_Main_Street export down the palace axis, its palace end
mainStreetStartTiles (1) into the city - placed after the last placement."""
from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
VERSAILLES = REPO / "randmaps/zpverseilles.xs"
GROUPING = REPO / "game/randmaps/groupings/EU_Deco_Main_Street.xml"


def _text(p: Path) -> str:
    return p.read_bytes().decode("utf-8").replace(chr(13), "")


def test_main_street_on_the_palace_axis_one_tile_into_the_city(steam_twin):
    g = _text(GROUPING)
    zs = [int(v) for v in re.findall(r'(?:start|end)z="(-?[0-9]+)"', g)]
    assert max(zs) == 56 and "<ignoreplacementrules>1</ignoreplacementrules>" in g
    # user 2026-09-24: the flowers from the owner's re-export "Versailles - added flowers" (three clusters of four, frame (1, -2) m)
    assert g.count(">zpPropsFlowers</unit>") == 31 and g.count("<unit ") == 168 and "zpSPCWaterSpawnPoint" not in g
    assert GROUPING.read_bytes().count(b"\r\n") == GROUPING.read_bytes().count(b"\n")          # runtime XML: CRLF
    t = _text(VERSAILLES)
    for line in ("int mainStreetStartTiles = 1;",
                 'int blockMainStreet = rmCreateGrouping("main street", "EU_Deco_Main_Street");',
                 "rmSetGroupingMaxDistance(blockMainStreet, 0.00);",
                 "float mainStreetOffXM = 1.0;",
                 "rmPlaceGroupingAtLoc(blockMainStreet, 0, (locX4 + locX5) * 0.5 + rmXMetersToFraction(mainStreetOffXM), locZ1 - rmZTilesToFraction(56 + mainStreetStartTiles - 7));"):
        assert line in t, line
    i = t.index("rmPlaceGroupingAtLoc(blockMainStreet")
    later = t[i + 1:t.index("//----- Define Variables -----")]
    assert not re.search(r"rmPlace(?:GroupingAtLoc|GroupingInstanceAtLoc|ObjectDefAtLoc|ObjectDefInArea)\(", later)   # placed last
    steam_twin(VERSAILLES, "00000_zpverseilles.xs")
