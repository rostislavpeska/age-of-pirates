"""Unit-bench runner: generate the bench map in the LIVE Scenario Editor, screenshot it, save it,
census the save and judge spawn / not spawn with explicit criteria.

    python sandbox/census/bench_run.py --peek                          # open the Type dropdown, screenshot it, stop
    python sandbox/census/bench_run.py --proto zpSPCLondonBasilica --nav 8,3 --players 2
    python sandbox/census/bench_run.py --proto zpSPCLondonBasilica --nav 8,3 --seed 4242 --json out.json

Preconditions (the runner checks what it can and stops otherwise):
  - the game is running and the Scenario Editor is open (File menu visible); this runner never
    launches or kills the game, and it takes the screen for ~60 s - do not touch the mouse meanwhile;
  - scripts/tools/unitbench.py already wrote <stem>.xs/.xml into the Steam Game/RandMaps folder
    (pre-flight clean), so the editor lists the bench in its Type dropdown;
  - --nav down,row is the dropdown position of the bench: run --peek once, read the screenshot,
    count. The list is sorted case-insensitively; "_" sorts after letters.

Verdicts (census = ground truth for SPAWN, screenshot = ground truth for RENDER):
  CRASH        the game process died during generation (a minidump is named if present)
  NO_SAVE      the save never appeared (Save As failed / wrong dialog state) - see the screenshot
  FAIL_SPINE   control unit missing from the census -> the bench itself is broken, not the subject
  FAIL_SUBJECT control present, subject missing -> the subject did not spawn (placement or data)
  PASS         both present exactly once, TownCenters == players; positions printed for the
               visual check (subject west of player 1's TC, control east, ~--dist metres)
Reads the census with sandbox/census/census.py; writes the screenshot, the save copy and a JSON
verdict under sandbox/census/samples/bench/. The screenshot is what a human (or Claude, via the
Read tool) inspects for "renders / renders wrong / invisible".
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
sys.dont_write_bytecode = True
import game_driver as gd            # noqa: E402
from census import census          # noqa: E402
from census_run import C, SCEN_DIR  # noqa: E402  (calibrated 2560x1080 client coordinates)

OUT = HERE / "samples" / "bench"
DUMP_GLOB = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Temp", "AoE3DE_s*.dmp")


def alive() -> bool:
    r = subprocess.run(["tasklist", "/FI", "IMAGENAME eq AoE3DE_s.exe"], capture_output=True, text=True)
    return "AoE3DE_s.exe" in r.stdout


def newest_dump(since: float):
    dumps = [p for p in glob.glob(DUMP_GLOB) if os.path.getmtime(p) >= since]
    return max(dumps, key=os.path.getmtime) if dumps else None


def open_dropdown(h):
    gd.focus(h)
    gd.click(h, *C["file_menu"]); time.sleep(0.6)
    gd.click(h, *C["file_new"]); time.sleep(1.0)
    gd.click(h, *C["type_arrow"]); time.sleep(0.6)
    gd.drag(h, *C["dd_thumb_top_from"], *C["dd_thumb_top_to"]); time.sleep(0.3)


def select_row(h, down: int, row: int):
    for _ in range(down):
        gd.click(h, *C["dd_down_arrow"]); time.sleep(0.12)
    row_y = C["dd_row1"][1] + (row - 1) * C["dd_row_h"]
    gd.click(h, C["dd_row1"][0], row_y); time.sleep(0.5)


def judge(units, proto, control, players, dist, tol=3.0):
    """Spawn verdict by GEOMETRY first, names second: the bench puts the control exactly +dist m
    east (x) of player 1's Town Center and the subject exactly -dist m west. Whatever single unit
    stands in each slot is that unit, even when the census cannot name a mod proto (runtime index
    resolution is calibrated, not guaranteed). Names are then compared and reported."""
    counts = {}
    for u in units:
        counts[u["proto"]] = counts.get(u["proto"], 0) + 1
    tcs = [u for u in units if u["proto"] == "TownCenter"]
    notes = []
    if len(tcs) != players:
        notes.append(f"TownCenters {len(tcs)} != players {players}")

    # positions come from census.py's heuristic field offset; when they are not sane (|coord| beyond
    # any map size) judge by NAMES: the calibrated runtime resolver names mod protos too.
    sane = all(abs(u["x"]) < 5000 and abs(u["z"]) < 5000 for u in units)
    if not sane:
        subj_n, ctrl_n = counts.get(proto, 0), counts.get(control, 0)
        notes.append("positions unreadable in this save (parser heuristic); verdict by proto names")
        if ctrl_n == 0:
            return "FAIL_SPINE", counts, notes + [f"control {control!r} absent"], {}
        if subj_n == 0:
            unk = [n for n in counts if n.startswith("unknown(")]
            return "FAIL_SUBJECT", counts, notes + [f"subject {proto!r} absent" + (f"; unresolved ids present {unk} - calibrate census.py" if unk else "")], {}
        if subj_n != 1 or ctrl_n != 1:
            notes.append(f"counts: subject {subj_n}, control {ctrl_n} (expected 1 each)")
        return "PASS", counts, notes, {}

    def at(x, z):
        return [u for u in units if u["proto"] != "TownCenter" and abs(u["x"] - x) <= tol and abs(u["z"] - z) <= tol]

    best = None
    for tc in tcs:
        c = at(tc["x"] + dist, tc["z"])
        s = at(tc["x"] - dist, tc["z"])
        score = (len(c) > 0) + (len(s) > 0)
        if best is None or score > best[0]:
            best = (score, tc, c, s)
    geo = {}
    if best is None:
        return "FAIL_SPINE", counts, notes + ["no TownCenter in the census"], geo
    _score, tc, ctrl, subj = best
    geo = {"tc": (round(tc["x"], 1), round(tc["z"], 1)),
           "control_slot": [(u["proto"], round(u["x"], 1), round(u["z"], 1)) for u in ctrl],
           "subject_slot": [(u["proto"], round(u["x"], 1), round(u["z"], 1)) for u in subj]}
    if not ctrl:
        verdict = "FAIL_SPINE"
        notes.append(f"nothing within {tol} m of the control slot (+{dist} m x of the TC)")
    elif not subj:
        verdict = "FAIL_SUBJECT"
        notes.append(f"nothing within {tol} m of the subject slot (-{dist} m x of the TC)")
    else:
        verdict = "PASS"
        if ctrl[0]["proto"] != control:
            notes.append(f"control slot holds {ctrl[0]['proto']!r}, expected {control!r}")
        if subj[0]["proto"] != proto:
            notes.append(f"subject slot holds {subj[0]['proto']!r} (expected {proto!r}: "
                         f"{'unresolved mod runtime id, calibrate census.py' if subj[0]['proto'].startswith('unknown') else 'name mismatch'})")
        if len(subj) > 1 or len(ctrl) > 1:
            notes.append(f"duplicates in a slot: subject {len(subj)}, control {len(ctrl)}")
    return verdict, counts, notes, geo


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--proto")
    ap.add_argument("--control", default="House")
    ap.add_argument("--stem", default="000_unitbench")
    ap.add_argument("--nav", help="down,row of the bench in the Type dropdown (from --peek)")
    ap.add_argument("--players", type=int, default=2)
    ap.add_argument("--dist", type=float, default=24.0)
    ap.add_argument("--seed", type=int, default=4242)
    ap.add_argument("--wait", type=int, default=30, help="seconds to wait for generation")
    ap.add_argument("--peek", action="store_true", help="only open the dropdown and screenshot it")
    ap.add_argument("--json")
    a = ap.parse_args(argv)
    OUT.mkdir(parents=True, exist_ok=True)
    h = gd.find_game()
    if not h:
        print("GAME NOT FOUND - open the DE Scenario Editor first")
        return 2
    if a.peek:
        open_dropdown(h)
        p = OUT / "peek_dropdown.png"
        gd.shot(h, str(p))
        print(f"dropdown screenshot: {p}  (read it, count down-clicks and the visible row, then pass --nav down,row)")
        return 0
    if not a.proto or not a.nav:
        print("--proto and --nav are required for a run (use --peek first)")
        return 2
    down, row = (int(x) for x in a.nav.split(","))
    t0 = time.time()
    # the editor's Save As field keeps ~30 characters: keep the tag short and unique
    tag = f"ub_{a.stem[4:]}_s{a.seed}"[:30]
    open_dropdown(h)
    select_row(h, down, row)
    gd.shot(h, str(OUT / f"{tag}_picked.png"))
    gd.set_field(h, *C["seed_field"], a.seed, width=6)
    gd.click(h, *C["generate"])
    time.sleep(a.wait)
    result = {"proto": a.proto, "control": a.control, "stem": a.stem, "seed": a.seed, "players": a.players}
    if not alive():
        d = newest_dump(t0)
        result.update(verdict="CRASH", dump=d)
        print(f"VERDICT CRASH  (process gone; dump: {d})")
        if d:
            subprocess.run([sys.executable, str(HERE.parents[1] / "scripts" / "aitest" / "crashdump_triage.py"), d])
        _write(a.json, result)
        return 1
    shot = OUT / f"{tag}_generated.png"
    gd.shot(h, str(shot))
    gd.click(h, *C["file_menu"]); time.sleep(0.6)
    gd.click(h, *C["file_saveas"]); time.sleep(1.0)
    gd.set_field(h, *C["save_name"], tag, width=40)
    time.sleep(0.3)
    gd.click(h, *C["save_button"]); time.sleep(2.5)
    src = SCEN_DIR / f"{tag}.age3Yscn"
    if not src.is_file():
        gd.shot(h, str(OUT / f"{tag}_after_save.png"))
        result.update(verdict="NO_SAVE", screenshot=str(shot))
        print(f"VERDICT NO_SAVE  (expected {src}; see {OUT / (tag + '_after_save.png')})")
        _write(a.json, result)
        return 1
    dst = OUT / src.name
    shutil.copy(src, dst)
    units = census(dst)
    verdict, counts, notes, geo = judge(units, a.proto, a.control, a.players, a.dist)
    result.update(verdict=verdict, units=len(units), counts=counts, notes=notes, geo=geo,
                  screenshot=str(shot), save=str(dst))
    print(f"VERDICT {verdict}  units={len(units)}  subject={counts.get(a.proto, 0)}  control={counts.get(a.control, 0)}  TC={counts.get('TownCenter', 0)}")
    for n in notes:
        print("  note:", n)
    if geo:
        print(f"  geometry: TC {geo.get('tc')}  subject slot {geo.get('subject_slot')}  control slot {geo.get('control_slot')}")
    print(f"  screenshot: {shot}")
    _write(a.json, result)
    return 0 if verdict == "PASS" else 1


def _write(path, result):
    if path:
        Path(path).write_text(json.dumps(result, indent=2), encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
