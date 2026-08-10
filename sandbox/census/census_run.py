"""One-command engine census loop (plan Part I).

Drives the running DE scenario editor through the CALIBRATED click
sequence: File -> New -> pick map -> set explicit seed -> Generate ->
Save As census_<map>_s<seed> -> repeat for N seeds. Then parses every
saved scenario and prints a JUDGE table: per-seed counts of each map's
expected groupings, so a missing/short spawn is one glance away.

Nothing is written to the game folders — only the game's own Save writes
scenarios; this script reads copies. Coordinates are the game window's
CLIENT area (resolution-independent of window position).

Usage:
  python sandbox/census/census_run.py elbe --seeds 3
  python sandbox/census/census_run.py tortuga --seeds 5 --players 6
"""
from __future__ import annotations

import argparse
import shutil
import sys
import time
from collections import Counter
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import game_driver as gd            # noqa: E402
from census import census          # noqa: E402

SCEN_DIR = Path(r"C:\Users\TIGO\Games\Age of Empires 3 DE"
                r"\76561198347905238\Scenario")
SAMPLES = HERE / "samples"

# --- calibrated UI coordinates (client area, 2560x1080) --------------------
C = dict(
    file_menu=(18, 14), file_new=(44, 47), file_saveas=(56, 160),
    type_arrow=(1498, 457), seed_field=(900, 497),
    dd_thumb_top_from=(1482, 500), dd_thumb_top_to=(1482, 385),
    dd_down_arrow=(1482, 760), dd_row1=(1024, 497), dd_row_h=31,
    generate=(1398, 739),
    save_name=(1200, 886), save_button=(699, 838),
)

# --- per-map recipes -------------------------------------------------------
# nav: from the dropdown-open state, drag thumb to top then click the down
# arrow `down` times; the target then sits at visible row `row` (1-based).
# expect: proto-name substrings whose spawn we assert, with the count that
# means "healthy" (informational — the judge prints actuals, flags shortfalls).
MAPS = {
    "elbe": dict(map_type="000_Elbe", players=4, teams=2,
                 nav=dict(down=4, row=9),
                 expect={"deSocketTengri": 2, "deSMTengriTent": 6,
                         "TownCenter": 4}),
    "tortuga": dict(map_type="zp_z_tortuga_historical", players=4, teams=2,
                    nav=dict(down=54, row=1),
                    expect={"SocketCaribs": 4, "NativeHouseCarib": 8,
                            "TownCenter": 4}),
}


def _select_map(h, nav):
    gd.click(h, *C["type_arrow"]); time.sleep(0.6)
    gd.drag(h, *C["dd_thumb_top_from"], *C["dd_thumb_top_to"]); time.sleep(0.3)
    for _ in range(nav["down"]):
        gd.click(h, *C["dd_down_arrow"]); time.sleep(0.12)
    row_y = C["dd_row1"][1] + (nav["row"] - 1) * C["dd_row_h"]
    gd.click(h, C["dd_row1"][0], row_y); time.sleep(0.5)


def generate_one(h, cfg, seed, save_name, shot_path):
    gd.focus(h)
    gd.click(h, *C["file_menu"]); time.sleep(0.6)
    gd.click(h, *C["file_new"]); time.sleep(1.0)
    _select_map(h, cfg["nav"])
    gd.set_field(h, *C["seed_field"], seed, width=6)
    gd.click(h, *C["generate"])
    time.sleep(30)
    gd.shot(h, str(shot_path))
    gd.click(h, *C["file_menu"]); time.sleep(0.6)
    gd.click(h, *C["file_saveas"]); time.sleep(1.0)
    gd.set_field(h, *C["save_name"], save_name, width=40)
    time.sleep(0.3)
    gd.click(h, *C["save_button"]); time.sleep(2.5)


def judge(map_key, cfg, results):
    print(f"\n=== JUDGE: {map_key} ({len(results)} seeds) ===")
    watch = list(cfg["expect"])
    hdr = "seed      total  " + "  ".join(f"{w[:14]:>14}" for w in watch)
    print(hdr)
    print("-" * len(hdr))
    for seed, units in results:
        c = Counter(u["proto"] for u in units)
        cells = []
        for w in watch:
            got = sum(n for name, n in c.items() if w.lower() in name.lower())
            flag = "!" if got < cfg["expect"][w] else " "
            cells.append(f"{got:>13}{flag}")
        print(f"{seed:<9} {len(units):>5}  " + "  ".join(cells))
    print("(! = below the healthy count; watch across seeds for flaky spawns)")


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("map", choices=list(MAPS))
    ap.add_argument("--seeds", type=int, default=3)
    ap.add_argument("--seed0", type=int, default=1001)
    ap.add_argument("--players", type=int)
    ap.add_argument("--teams", type=int)
    args = ap.parse_args(argv)

    cfg = dict(MAPS[args.map])
    if args.players:
        cfg["players"] = args.players
    if args.teams:
        cfg["teams"] = args.teams

    h = gd.find_game()
    if not h:
        print("GAME NOT FOUND — open the DE scenario editor first.")
        return 1

    results = []
    for i in range(args.seeds):
        seed = args.seed0 + i
        name = f"census_{args.map}_s{seed}"
        shot = HERE / f"run_{args.map}_s{seed}.png"
        print(f"[{i+1}/{args.seeds}] generating {args.map} seed={seed} ...")
        generate_one(h, cfg, seed, name, shot)
        src = SCEN_DIR / f"{name}.age3Yscn"
        if not src.is_file():
            print(f"    SAVE NOT FOUND: {src.name} (see {shot.name})")
            continue
        dst = SAMPLES / src.name
        shutil.copy(src, dst)
        units = census(dst)
        results.append((seed, units))
        print(f"    saved + parsed: {len(units)} units")

    if results:
        judge(args.map, cfg, results)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
