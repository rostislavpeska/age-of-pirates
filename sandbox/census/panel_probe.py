"""Command-panel oracle: capture the command grid of whatever is selected
in the live game and report which button cells are occupied.

Use it to compare a known-good building against a suspect one without
relying on eyeballing a screenshot:

    # select a zpTrainStationA in the editor, then:
    python sandbox/census/panel_probe.py station
    # select the zpOrientalFerry, then:
    python sandbox/census/panel_probe.py ferry
    # compare
    python sandbox/census/panel_probe.py --diff station ferry

Each run writes sandbox/census/panel_<label>.png (the cropped grid) and
sandbox/census/panel_<label>.json (per-cell occupancy), so the comparison
is reproducible rather than remembered.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image, ImageChops, ImageStat  # noqa: E402

import game_driver as gd  # noqa: E402

HERE = Path(__file__).resolve().parent

# The command grid sits bottom-left. Fractions of the client area, measured
# against the 1338x861 screenshot the user supplied (grid spans roughly
# x 0.005-0.33, y 0.66-0.99). Override with --rect if the HUD scale differs.
GRID = (0.005, 0.660, 0.335, 0.995)
COLS, ROWS = 6, 4

# A cell counts as occupied when its pixel spread exceeds this. An empty slot
# is near-flat wood; any icon (even a broken-texture black square with a
# border) is far busier.
STDDEV_OCCUPIED = 12.0


def capture(label: str, rect=GRID):
    hwnd = gd.find_game()
    if not hwnd:
        raise SystemExit("game window not found - is AoE3DE running?")
    gd.focus(hwnd)
    full = HERE / f"panel_{label}_full.png"
    w, h = gd.shot(hwnd, full)
    img = Image.open(full).convert("RGB")
    box = (int(rect[0] * w), int(rect[1] * h), int(rect[2] * w), int(rect[3] * h))
    grid = img.crop(box)
    grid.save(HERE / f"panel_{label}.png")

    gw, gh = grid.size
    cells = []
    for r in range(ROWS):
        for c in range(COLS):
            cell = grid.crop((int(c * gw / COLS), int(r * gh / ROWS),
                              int((c + 1) * gw / COLS), int((r + 1) * gh / ROWS)))
            sd = sum(ImageStat.Stat(cell).stddev) / 3.0
            cells.append({"row": r, "col": c, "stddev": round(sd, 2),
                          "occupied": sd > STDDEV_OCCUPIED})
    out = {"label": label, "client": [w, h], "box": box, "cells": cells,
           "occupied_count": sum(1 for x in cells if x["occupied"])}
    (HERE / f"panel_{label}.json").write_text(json.dumps(out, indent=2))

    print(f"client {w}x{h}   grid crop {box}   -> panel_{label}.png")
    for r in range(ROWS):
        row = "".join("#" if cells[r * COLS + c]["occupied"] else "." for c in range(COLS))
        print(f"   row {r}: {row}")
    print(f"   occupied cells: {out['occupied_count']}")
    return out


def diff(a: str, b: str):
    pa, pb = HERE / f"panel_{a}.json", HERE / f"panel_{b}.json"
    for p in (pa, pb):
        if not p.is_file():
            raise SystemExit(f"missing {p.name} - capture it first")
    da, db = json.loads(pa.read_text()), json.loads(pb.read_text())
    print(f"{a}: {da['occupied_count']} buttons    {b}: {db['occupied_count']} buttons")
    for ca, cb in zip(da["cells"], db["cells"]):
        if ca["occupied"] != cb["occupied"]:
            who = a if ca["occupied"] else b
            print(f"   row {ca['row']} col {ca['col']}: only in {who}"
                  f"   (stddev {ca['stddev']} vs {cb['stddev']})")
    ia, ib = HERE / f"panel_{a}.png", HERE / f"panel_{b}.png"
    if ia.is_file() and ib.is_file():
        A, B = Image.open(ia).convert("RGB"), Image.open(ib).convert("RGB")
        if A.size == B.size:
            d = ImageChops.difference(A, B)
            d.save(HERE / f"panel_diff_{a}_{b}.png")
            print(f"   pixel diff -> panel_diff_{a}_{b}.png "
                  f"(mean {sum(ImageStat.Stat(d).mean) / 3:.1f})")


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        raise SystemExit(__doc__)
    if args[0] == "--diff":
        diff(args[1], args[2])
    else:
        capture(args[0])
