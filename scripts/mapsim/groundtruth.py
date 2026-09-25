"""The game's own map, read from a saved Scenario Editor generation (.age3Yscn): the exact ground truth mapsim is
compared against. Terrain comes from the save's tile data, objects from its unit census (scripts/mapview/census_reader).

Terrain (measured 2026-09-25 on 117 editor saves of 49 mod maps, P2T2 / P6T2 / KotH):
  * after the terrain header come tagged blocks TT, TS, WC, WI, WT; WT holds one byte per tile, the tile's water
    body index (255 = no water);
  * right after WT: u32 V = (tiles_x + 1) * (tiles_z + 1), V float32 ground heights, then V float32 water-surface
    heights; both x-major (vertex i along x, j along z: k = i * (tiles_z + 1) + j - fish sit on wet vertices 5346/5346
    x-major against 3646 z-major, Town Centers on dry ones 354/393 against 263);
  * the open-sea depth (surface - ground) equals waterdata's depth for the sea type on 80 of 80 water-map saves.
A tile is water where WT != 255, DEEP where its mean depth over its 4 vertices exceeds SHALLOW_BUILD_DEPTH_M (1.5 m,
not walkable), SHALLOW otherwise; a dry tile is CLIFF where the ground rises CLIFF_STEP_M or more across the tile (a
45-degree slope; smoothing ramps and beaches stay below it, cliff faces exceed it - the same impassable-rim idea as
mapsim's cliff band)."""
from __future__ import annotations

import struct
from dataclasses import dataclass, field as dfield
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

CLIFF_STEP_M = 2.0


@dataclass
class GameGrid:
    """The save's terrain on its own tile grid, in the TerrainGrid interface render.py draws (nx/nz, water, wwalk,
    cliff_band, cliff_claims, class_code), row-major [j][i] like TerrainGrid."""
    nx: int
    nz: int
    tile_m: float
    water: List[List[bool]]
    wwalk: List[List[bool]]
    cliff_band: List[List[bool]]
    cliff_claims: List[Tuple[str, List[Tuple[int, int]]]] = dfield(default_factory=list)

    def class_code(self, i: int, j: int) -> int:
        if self.cliff_band[j][i]:
            return 3
        if self.water[j][i]:
            return 1 if self.wwalk[j][i] else 2
        return 0

    def is_deep(self, i: int, j: int) -> bool:
        return self.water[j][i] and not self.wwalk[j][i]


@dataclass
class GameMap:
    save: Path
    size_x_m: float
    size_z_m: float
    grid: GameGrid
    units: List[Dict[str, Any]]

    def town_centers(self) -> List[Dict[str, Any]]:
        return [u for u in self.units if u["proto"] == "TownCenter"]

    def units_of(self, *protos: str) -> List[Dict[str, Any]]:
        low = {p.lower() for p in protos}
        return [u for u in self.units if str(u["proto"]).lower() in low]


def _blocks(data: bytes, off: int) -> Tuple[Dict[bytes, bytes], int]:
    p = off + 16
    out: Dict[bytes, bytes] = {}
    while True:
        tag = data[p:p + 2]
        size = struct.unpack_from("<I", data, p + 2)[0]
        out[tag] = data[p + 6:p + 6 + size]
        if tag == b"WT":
            return out, p + 6 + size
        p = p + 6 + size


@lru_cache(maxsize=4)
def read_game_map(save: str) -> GameMap:
    from scripts.mapsim.waterdata import SHALLOW_BUILD_DEPTH_M
    from scripts.mapview import census_reader as CR
    path = Path(save)
    data = CR.decompress(path)
    off, tx, tz, tile_m, _ = CR.terrain_headers(data)[0]
    blocks, q = _blocks(data, off)
    wt = blocks[b"WT"]
    if len(wt) == tx * tz + 4:
        wt = wt[4:]
    V = struct.unpack_from("<I", data, q)[0]
    M = tz + 1
    if V != (tx + 1) * M:
        raise ValueError("%s: %d vertices for a %dx%d tile map" % (path.name, V, tx, tz))
    H = struct.unpack_from("<%df" % V, data, q + 4)
    W = struct.unpack_from("<%df" % V, data, q + 4 + 4 * V)
    water = [[False] * tx for _ in range(tz)]
    wwalk = [[False] * tx for _ in range(tz)]
    cliff = [[False] * tx for _ in range(tz)]
    for i in range(tx):
        for j in range(tz):
            ks = (i * M + j, (i + 1) * M + j, i * M + j + 1, (i + 1) * M + j + 1)
            if wt[i * tz + j] != 255:
                water[j][i] = True
                wwalk[j][i] = sum(W[k] - H[k] for k in ks) / 4.0 <= SHALLOW_BUILD_DEPTH_M
            else:
                hs = [H[k] for k in ks]
                cliff[j][i] = max(hs) - min(hs) >= CLIFF_STEP_M
    cells = [(i, j) for j in range(tz) for i in range(tx) if cliff[j][i]]
    grid = GameGrid(tx, tz, tile_m, water, wwalk, cliff, [("cliffs", cells)] if cells else [])
    size_x_m, size_z_m = CR.map_size(path)
    return GameMap(path, size_x_m, size_z_m, grid, CR.read(path, size_x_m, size_z_m))
