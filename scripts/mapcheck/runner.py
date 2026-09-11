"""mapcheck CLI (plan Part G2/E4).

  python -m scripts.mapcheck <map.xs | map-name> [--scenario P2T2]
      [--matrix] [--static-only] [--json out.json] [--strict]

Exit codes: 0 clean, 1 FAIL findings present, 2 the checker itself crashed.
--matrix runs the community-recommended player-count sweep (guide 21.6:
"test with different player counts") as P2T2 / P4T2 / P8T8.
--strict promotes WARN to the failing exit code.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import List

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts.mapcheck.finding import Finding  # noqa: E402
from scripts.mapcheck.locate import resolve_map  # noqa: E402
from scripts.mapcheck.universal import run  # noqa: E402

MATRIX = ((2, 2), (4, 2), (8, 8))


def _scenario(tag: str):
    from scripts.mapsim.scene import Scenario
    m = re.fullmatch(r"P(\d+)T(\d+)", tag.upper())
    if not m:
        raise SystemExit(f"bad scenario {tag!r}; expected e.g. P2T2")
    return Scenario(players=int(m.group(1)), teams=int(m.group(2)))


def _print(findings: List[Finding]) -> None:
    order = {"FAIL": 0, "WARN": 1, "INFO": 2}
    for f in sorted(findings, key=lambda f: (order[f.severity], f.check)):
        loc = f":{f.line}" if f.line else ""
        scen = f" [{f.scenario}]" if f.scenario else ""
        ref = f"  ({f.guide_ref})" if f.guide_ref else ""
        print(f"{f.severity:4} {f.check:22} {f.map}{loc}{scen}  "
              f"{f.message}{ref}")


def main(argv=None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("map", help=".xs path or bare map name")
    ap.add_argument("--scenario", default="P2T2")
    ap.add_argument("--matrix", action="store_true",
                    help="run P2T2, P4T2, P8T8")
    ap.add_argument("--static-only", action="store_true",
                    help="S-tier only: no simulator, milliseconds")
    ap.add_argument("--json", type=Path, default=None,
                    help="write findings JSON here")
    ap.add_argument("--strict", action="store_true",
                    help="WARN also fails the exit code")
    args = ap.parse_args(argv)

    try:
        path = resolve_map(args.map)
    except FileNotFoundError as e:
        print(e, file=sys.stderr)
        return 2

    scenarios = ([_scenario(f"P{p}T{t}") for p, t in MATRIX]
                 if args.matrix else [_scenario(args.scenario)])
    if args.static_only:
        scenarios = scenarios[:1]

    findings: List[Finding] = []
    try:
        for i, sc in enumerate(scenarios):
            res = run(path, sc, static_only=args.static_only)
            # static findings are scenario-independent: keep them once
            findings += [f for f in res.findings
                         if i == 0 or f.check.startswith(("G", "SIM"))]
    except Exception as e:  # noqa: BLE001 — checker crash is exit 2
        print(f"mapcheck crashed: {type(e).__name__}: {e}", file=sys.stderr)
        return 2

    _print(findings)
    fails = sum(f.severity == "FAIL" for f in findings)
    warns = sum(f.severity == "WARN" for f in findings)
    print(f"-- {path.name}: {fails} FAIL, {warns} WARN, "
          f"{len(findings) - fails - warns} INFO")

    if args.json:
        args.json.write_text(
            json.dumps([f.to_dict() for f in findings], indent=1),
            encoding="utf-8")

    if fails or (args.strict and warns):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
