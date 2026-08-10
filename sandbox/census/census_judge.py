"""Intent-vs-reality grouping judge (plan Part I).

Reconciles what a map's .xs ASKS to place (every rmCreateGrouping) against
what the engine ACTUALLY spawned (one or more parsed .age3Yscn censuses).
No hand-authored expectations: each grouping's fingerprint is the distinctive
socket/flag units inside its own XML, so "did grouping X spawn" becomes
"are X's signature units in the census".

Across N seeds it reports an APPEARANCE RATE — the honest signal:
  5/5  reliable            0/5  never (bug, or a conditional never triggered)
  4/5  FLAKY  <- the bug class a single generation can't reveal

Usage:
  python census_judge.py <map.xs> <census1.age3Yscn> [census2 ...]
                         [--players N --teams T]
"""
from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).parent
REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(REPO))

from census import census                                    # noqa: E402
from scripts.mapsim.scene import Scenario                    # noqa: E402
from scripts.mapsim.xs_extract import extract                # noqa: E402
from scripts.refdata import catalog                          # noqa: E402
from scripts.refdata.catalogs import grouping_units_m        # noqa: E402

SIG_KEYS = ("Socket", "socket", "Flag", "flag")


def grouping_intent(xs_path: Path, sc: Scenario):
    """{display_ref: {"requested": n, "sig": set(protos), "stems": [names]}}
    keyed on the grouping's file reference; sig = its distinctive units."""
    ex = extract(xs_path, sc)
    gcat = catalog("grouping")
    defs = {d.line: d for d in ex.defs.values()}
    out = {}
    for p in ex.placements:
        d = defs.get(p.def_line)
        if not d or not d.is_grouping:
            continue
        ref = d.proto if isinstance(d.proto, str) \
            else getattr(d.proto, "str_prefix", None) or "?"
        rec = out.setdefault(ref, {"requested": 0, "sig": set(), "stems": []})
        rec["requested"] += 1
        if not rec["stems"]:
            for e in gcat.resolve(ref)[:4]:
                rec["stems"].append(e.name)
                for t, _x, _z in grouping_units_m(e.name) or ():
                    if any(k in t for k in SIG_KEYS):
                        rec["sig"].add(t)
    return out


def present(sig: set, counts: Counter) -> int:
    """Max count of any signature proto in a census (0 = absent)."""
    return max((counts.get(s, 0) for s in sig), default=0)


def judge(xs_path: Path, census_paths, sc: Scenario):
    intent = grouping_intent(xs_path, sc)
    censuses = []
    for cp in census_paths:
        counts = Counter(u["proto"] for u in census(Path(cp)))
        censuses.append((Path(cp).stem, counts))

    n = len(censuses)
    print(f"\nINTENT vs REALITY — {xs_path.name}  ({n} seed"
          f"{'s' if n != 1 else ''}, P{sc.players}T{sc.teams})\n")
    hdr = f"{'grouping ref':40} {'req':>3} {'rate':>6}  per-seed count"
    print(hdr)
    print("-" * (len(hdr) + n * 4))
    rows = []
    for ref, rec in sorted(intent.items()):
        if not rec["sig"]:
            rows.append((ref, rec["requested"], None, [], "no socket/flag fingerprint"))
            continue
        per = [present(rec["sig"], c) for _stem, c in censuses]
        appeared = sum(1 for v in per if v > 0)
        rows.append((ref, rec["requested"], appeared, per, ""))

    # order: flaky first (most actionable), then never, then reliable, then no-sig
    def sortkey(r):
        _ref, _req, appeared, per, _note = r
        if appeared is None:
            return (3, 0)
        if 0 < appeared < n:
            return (0, appeared)            # flaky
        if appeared == 0:
            return (1, 0)                   # never
        return (2, -appeared)               # reliable
    rows.sort(key=sortkey)

    for ref, req, appeared, per, note in rows:
        if appeared is None:
            print(f"{ref:40} {req:>3} {'  -  ':>6}  {note}")
            continue
        rate = f"{appeared}/{n}"
        mark = ""
        if appeared == 0:
            mark = "  <- NEVER (bug or unreached conditional)"
        elif appeared < n:
            mark = "  <- FLAKY"
        cells = " ".join(f"{v:>3}" for v in per)
        print(f"{ref:40} {req:>3} {rate:>6}  {cells}{mark}")

    print("\nrreq = times the .xs places this grouping (both arms of random "
          "branches count).\nNEVER across all seeds = either a real spawn "
          "failure or a subciv/player-count\nconditional this config never "
          "triggers — confirm which before calling it a bug.")


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("xs")
    ap.add_argument("census", nargs="+")
    ap.add_argument("--players", type=int, default=4)
    ap.add_argument("--teams", type=int, default=2)
    args = ap.parse_args(argv)
    judge(Path(args.xs), args.census,
          Scenario(players=args.players, teams=args.teams))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
