"""Map facts the minimap tools need, read from the map script through mapsim - never typed by hand.

    python scripts/mapview/mapinfo.py randmaps/zplondon.xs --players 4 [--teams 2]            -> 360x686
    python scripts/mapview/mapinfo.py randmaps/zplondon.xs --players 4 --script               -> 360x685

map_size() runs mapsim's extractor (scripts/mapsim/xs_extract.py) for one Scenario (players, teams), takes the size
rmSetMapSize receives with the script's player-count branches folded (script_map_size), and returns the ENGINE size:
the terrain is whole 2 m tiles, a half tile rounded up (engine_size_m). The minimap draws that terrain, and the saved
positions are metres on it, so every pixel prediction uses the engine size.

Evidence (2026-09-24): a save's terrain header holds int32 tiles_x, int32 tiles_z, float32 2.0, float32 8.0 right
after a UTF-16 terrain name (one hit per file; reader: session scratch offcal/mapsize.py). 16 saves read:
- zplondon 3-5 players, rmSetMapSize(360, 685): 180 x 343 tiles = 360 x 686 m (mapview_london4p_live 2026-09-24,
  LondonIndivUnitIDs and Census_LondonHarbours 2026-09-22);
- zpparis 4 players, rmSetMapSize(653, 360): 327 x 180 tiles = 654 x 360 m (census_paris_s4242, 2026-09-20);
- even sizes come back exact: zpflorence 360 x 620 -> 180 x 310, zpverseilles 360 x 560 -> 180 x 280 (both
  census_*_s4242, 2026-09-20);
- the other 9 (older London versions, Istanbul, Elbe, Tortuga, two test scenarios) have whole tile counts too; their
  script sizes were not re-derived.
Integer script sizes only ever leave a remainder of 0 or 1 m, so the saves cannot tell "half up" from "ceiling";
a fractional rmSetMapSize value is unmeasured. The live London frame agrees: the four Explorer stars sit
0.75 / 1.22 / 0.80 / 0.81 px from their predicted pixels at 686 m, 1.04 / 1.52 / 0.90 / 0.90 px at 685 m.

Script sizes (zplondon.xs:401-408): London 360 x 645 for 2 players, 360 x 685 for 3-5, 360 x 765 for 6+ (engine 646 /
686 / 766); zpparis.xs 653 x 360 for 4 (engine 654). A wrong player count is the silent failure this exists for
(review F1): 645 instead of 685 moves a London pixel 7-14 px while a fit on the same wrong size still reports 0 px.
"""
from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path
from typing import Tuple, Union

REPO = Path(__file__).resolve().parents[2]
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))
RANDMAPS = REPO / "randmaps"
TILE_M = 2.0                  # metres per terrain tile (the save header's float32 2.0)


def resolve_map(ref: Union[str, Path]) -> Path:
    """A map script from a path, or a name under randmaps/ ('zplondon' or 'zplondon.xs')."""
    p = Path(ref)
    if p.is_file():
        return p
    name = str(ref) if str(ref).endswith(".xs") else str(ref) + ".xs"
    q = RANDMAPS / name
    if q.is_file():
        return q
    raise FileNotFoundError("no map script %r (looked at %s and %s)" % (str(ref), p, q))


def engine_size_m(size_m: float) -> float:
    """rmSetMapSize metres -> the engine's terrain length: whole 2 m tiles, a half tile rounded up
    (685 -> 686, 653 -> 654, 645 -> 646, 360 -> 360; measured on 16 saves 2026-09-24, see the module docstring)."""
    v = float(size_m)
    if not (math.isfinite(v) and v > 0):
        raise ValueError("a map size must be positive and finite, got %r" % (size_m,))
    return TILE_M * math.floor(v / TILE_M + 0.5)


def script_map_size(xs_path: Union[str, Path], players: int, teams: int = 2) -> Tuple[float, float]:
    """(size_x_m, size_z_m) exactly as rmSetMapSize receives them for this player setup, from mapsim's extraction.
    Raises ValueError when the script sets no size, mapsim's ExtractError when the size is runtime-dependent."""
    from scripts.mapsim.scene import Scenario
    from scripts.mapsim.xs_extract import extract
    path = resolve_map(xs_path)
    ex = extract(path, Scenario(int(players), int(teams)))
    if ex.map_size_x is None or ex.map_size_z is None:
        raise ValueError("%s: no rmSetMapSize reached for %d players / %d teams" % (path.name, players, teams))
    return float(ex.map_size_x), float(ex.map_size_z)


def map_size(xs_path: Union[str, Path], players: int, teams: int = 2, engine: bool = True) -> Tuple[float, float]:
    """(size_x_m, size_z_m) of the map the engine builds for this player setup: rmSetMapSize rounded to whole 2 m
    tiles (engine_size_m). engine=False returns the script's own value (script_map_size)."""
    sx, sz = script_map_size(xs_path, players, teams)
    if not engine:
        return sx, sz
    return engine_size_m(sx), engine_size_m(sz)


def parse_size(text: str) -> Tuple[float, float]:
    """'360x685' -> (360.0, 685.0). Both positive."""
    m = re.fullmatch(r"\s*([0-9]+(?:\.[0-9]+)?)\s*[xX]\s*([0-9]+(?:\.[0-9]+)?)\s*", str(text))
    if not m:
        raise ValueError("a map size is XxZ in metres, e.g. 360x686, got %r" % (text,))
    sx, sz = float(m.group(1)), float(m.group(2))
    if sx <= 0 or sz <= 0:
        raise ValueError("a map size must be positive, got %r" % (text,))
    return sx, sz


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("map"); ap.add_argument("--players", type=int, required=True)
    ap.add_argument("--teams", type=int, default=2)
    ap.add_argument("--script", action="store_true", help="print rmSetMapSize's own value, not the engine size")
    a = ap.parse_args(argv)
    sx, sz = script_map_size(a.map, a.players, a.teams)
    ex, ez = engine_size_m(sx), engine_size_m(sz)
    if a.script:
        print("%gx%g" % (sx, sz))
    else:
        print("%gx%g" % (ex, ez))
        if (ex, ez) != (sx, sz):
            print("note: rmSetMapSize receives %gx%g; the engine builds whole 2 m tiles: %gx%g" % (sx, sz, ex, ez),
                  file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
