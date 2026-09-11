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
from subciv_map import (census_subcivs, grouping_identity,   # noqa: E402
                        proto_subciv)


def grouping_intent(xs_path: Path, sc: Scenario):
    """{ref: {"requested": n, "sockets": set, "subcivs": set, "kind": ...}}
    Each grouping identified DETERMINISTICALLY by its socket -> <subciv>
    (user recipe): native (has subciv, conditional) vs structure (socket,
    no subciv, unconditional) vs unknown (no socket)."""
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
        rec = out.setdefault(ref, {"requested": 0, "sockets": set(),
                                   "subcivs": set(), "kind": "unknown"})
        rec["requested"] += 1
        if not rec["sockets"] and rec["kind"] == "unknown":
            for e in gcat.resolve(ref)[:5]:
                ident = grouping_identity(e.name)
                rec["sockets"].update(ident["sockets"])
                rec["subcivs"].update(ident["subcivs"])
                if ident["kind"] != "unknown":
                    rec["kind"] = ident["kind"]
    return out


def judge(xs_path: Path, census_paths, sc: Scenario):
    intent = grouping_intent(xs_path, sc)
    sub = proto_subciv()
    censuses = []
    for cp in census_paths:
        units = census(Path(cp))
        counts = Counter(u["proto"] for u in units)
        censuses.append((Path(cp).stem, counts, census_subcivs(units)))
    n = len(censuses)

    def rate(pred):
        return sum(1 for _s, _c, _sc in censuses if pred(_c, _sc))

    print(f"\nINTENT vs REALITY — {xs_path.name}  ({n} seed"
          f"{'s' if n != 1 else ''}, P{sc.players}T{sc.teams})")

    # --- subcivs actually rolled across the seeds ---
    all_sub = {}
    for _s, _c, scv in censuses:
        for k, v in scv.items():
            all_sub.setdefault(k, []).append(v)
    print(f"\nSUBCIVS ROLLED (native content the engine actually placed):")
    if all_sub:
        for name in sorted(all_sub, key=lambda k: -len(all_sub[k])):
            seen = len(all_sub[name])
            rng = f"{min(all_sub[name])}-{max(all_sub[name])}" \
                if all_sub[name] else "0"
            print(f"  {name:24} {seen}/{n} seeds   sockets {rng}")
    else:
        print("  (none identified)")

    natives = {r: v for r, v in intent.items() if v["kind"] == "native"}
    structs = {r: v for r, v in intent.items() if v["kind"] == "structure"}
    unknown = {r: v for r, v in intent.items() if v["kind"] == "unknown"}

    print(f"\nNATIVE groupings requested (CONDITIONAL on subciv roll — "
          "absent = not rolled, not a bug):")
    for ref in sorted(natives):
        rec = natives[ref]
        scivs = rec["subcivs"]
        r = rate(lambda c, scv: any(s in scv for s in scivs))
        tag = "" if r else "   (pool member, not rolled at this config)"
        print(f"  {ref:36} subciv {','.join(sorted(scivs)):20} "
              f"rolled {r}/{n}{tag}")

    print(f"\nSTRUCTURE groupings requested (NOT subciv-gated — absent is a "
          "stronger signal):")
    for ref in sorted(structs):
        rec = structs[ref]
        socks = rec["sockets"]
        per = [max((c.get(s, 0) for s in socks), default=0)
               for _st, c, _sc in censuses]
        appeared = sum(1 for v in per if v > 0)
        mark = ("  <- CHECK: not subciv-gated; absent"
                if appeared == 0 else
                ("  <- FLAKY" if appeared < n else ""))
        print(f"  {ref:36} socket {','.join(sorted(socks)):24} "
              f"{appeared}/{n} {per}{mark}")

    if unknown:
        print(f"\nNO SOCKET FINGERPRINT (can't verify from census — "
              "bridges, prop groupings):")
        for ref in sorted(unknown):
            print(f"  {ref}")

    print("\nRule (deterministic): socket WITH <subciv> = native, absence "
          "just means that subciv\ndidn't roll at this config. Socket "
          "WITHOUT <subciv> = structure; absence is NOT explained\nby the "
          "native roll, so it points to either a script-level condition "
          "(e.g. water-only)\nor a real failure — the one to check first.")


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
