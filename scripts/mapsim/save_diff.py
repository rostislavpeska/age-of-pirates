"""The engine's terrain in an editor save against mapsim's prediction for the same script - "check the scenario"
by numbers, not by eye.

Owner 2026-10-06 (Danube v8b, save "Danube - total fsailure"): mapsim drew the inner shore and the whole outer shore
as land, the game left the western two thirds of the inner shore and a corridor to the south-west corner as water.
The river channel itself matched. An offline gate that passes is not a generated map: run this on the first editor
generation of every terrain change.

    python scripts/mapsim/save_diff.py "<profile>/Scenario/<save>.age3Yscn" game/randmaps/zpdanube.xs --players 3
        [--teams 2] [--out diff.png] [--max-pct 3]

Prints water tiles only in the game / only in mapsim; exit 1 when either exceeds --max-pct of the map. The picture
(script coordinates, x east, z north): blue water in both, RED water only in the game, YELLOW water only in mapsim.

Ground truth (measured 2026-09-25 on 80 water-map captures, mapsim/field.py shore notes): a tile is water when its
water-body index in the save's WT block is not 255; depth = water surface - ground over its four vertices (the two
float arrays after WT, x-major).
"""
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path
from typing import List, Tuple

REPO = Path(__file__).resolve().parents[2]
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))


def save_water(save: Path) -> Tuple[int, int, float, List[List[bool]]]:
    """(tx, tz, tile_m, water[z][x]) read from the save's WT block."""
    from scripts.mapview import census_reader as CR
    data = CR.decompress(Path(save))
    off, tx, tz, tile_m, _ = CR.terrain_headers(data)[0]
    p = off + 16
    while True:
        tag = data[p:p + 2]
        size = struct.unpack_from("<I", data, p + 2)[0]
        if tag == b"WT":
            wt = data[p + 6:p + 6 + size]
            break
        p = p + 6 + size
    if len(wt) == tx * tz + 4:
        wt = wt[4:]
    water = [[wt[i * tz + j] != 255 for i in range(tx)] for j in range(tz)]
    return tx, tz, tile_m, water


def sim_water(xs: Path, players: int, teams: int) -> List[List[bool]]:
    """mapsim's water[z][x] for the script at that player count (1 tile cells)."""
    from scripts.mapsim.bridge import extraction_to_resolved
    from scripts.mapsim.field import terrain_grid
    from scripts.mapsim.scene import Scenario
    from scripts.mapsim.xs_extract import extract
    rs = extraction_to_resolved(extract(Path(xs), Scenario(players=players, teams=teams)))
    tg = terrain_grid(rs, cell_tiles=1.0)
    return [[bool(tg.water[j][i]) for i in range(tg.nx)] for j in range(tg.nz)]


def compare(game: List[List[bool]], sim: List[List[bool]]) -> dict:
    """Tile counts: both, game only, sim only, and the two mismatches as a percentage of the map."""
    nz, nx = len(game), len(game[0])
    if (len(sim), len(sim[0])) != (nz, nx):
        raise ValueError(f"grid sizes differ: game {nx}x{nz}, mapsim {len(sim[0])}x{len(sim)} - wrong player count?")
    both = game_only = sim_only = 0
    for j in range(nz):
        for i in range(nx):
            g, s = game[j][i], sim[j][i]
            both += g and s
            game_only += g and not s
            sim_only += s and not g
    total = nx * nz
    return {"tiles": total, "both": both, "game_only": game_only, "sim_only": sim_only,
            "game_only_pct": 100.0 * game_only / total, "sim_only_pct": 100.0 * sim_only / total}


def render(game, sim, tile_m: float, out: Path, title: str) -> None:
    import numpy as np
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    g, s = np.array(game), np.array(sim)
    img = np.zeros(g.shape + (3,))
    img[:] = (0.42, 0.58, 0.30)
    img[g & s] = (0.27, 0.42, 0.68)
    img[g & ~s] = (0.85, 0.25, 0.25)
    img[s & ~g] = (0.95, 0.85, 0.30)
    S = g.shape[1] * tile_m
    fig, ax = plt.subplots(figsize=(9, 9))
    ax.imshow(img, origin="lower", extent=(0, S, 0, S))
    ax.set_title(title + "\nblue both, RED water only in game, YELLOW water only in mapsim", fontsize=9)
    fig.tight_layout()
    fig.savefig(out, dpi=80)
    plt.close(fig)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("save")
    ap.add_argument("xs")
    ap.add_argument("--players", type=int, required=True, help="the player count of the editor generation")
    ap.add_argument("--teams", type=int, default=2)
    ap.add_argument("--out", help="write the diff picture here")
    ap.add_argument("--max-pct", type=float, default=3.0, help="allowed mismatch per direction, %% of the map")
    a = ap.parse_args(argv)
    tx, tz, tile_m, game = save_water(Path(a.save))
    r = compare(game, sim_water(Path(a.xs), a.players, a.teams))
    print(f"{Path(a.save).name} vs {Path(a.xs).name} ({a.players} players): {tx}x{tz} tiles of {tile_m:g} m")
    print(f"  water in both {r['both']}, only in the game {r['game_only']} ({r['game_only_pct']:.1f}%), "
          f"only in mapsim {r['sim_only']} ({r['sim_only_pct']:.1f}%)")
    if a.out:
        render(game, sim_water(Path(a.xs), a.players, a.teams), tile_m, Path(a.out),
               f"{Path(a.save).name} vs {Path(a.xs).name}")
        print(f"  picture: {a.out}")
    bad = r["game_only_pct"] > a.max_pct or r["sim_only_pct"] > a.max_pct
    print("  MISMATCH: the generated map is not what mapsim predicts" if bad else "  OK: game and mapsim agree")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
