"""Worker CLI for the map spawn simulator: resolve a scene and run checks.

Usage (from the repo root):
  python scripts/mapsim/sim.py --matrix
  python scripts/mapsim/sim.py --players 5 --teams 2
  python scripts/mapsim/sim.py --scene path/to/scene.json --players 3 --teams 3 --koth

Exit codes: 0 clean (warnings allowed), 1 any error-severity finding,
2 usage error.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import List, Tuple

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts.mapsim.checks import Finding, run_checks  # noqa: E402
from scripts.mapsim.scene import Scenario, Scene  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SCENE = REPO_ROOT / "scripts" / "mapsim" / "tests" / "fixtures" / "independence_war.scene.json"
DEFAULT_OUT = REPO_ROOT / "playground" / "mapsim"

# Plan section 7: standard check matrix {2,3,5,7,8} x {2-team, FFA}
# (2-player FFA is the same thing as 2 teams).
STANDARD_MATRIX: List[Tuple[int, int]] = [
    (2, 2), (3, 2), (3, 3), (5, 2), (5, 5), (7, 2), (7, 7), (8, 2), (8, 8),
]


def scenario_tag(sc: Scenario) -> str:
    tag = f"P{sc.players}_T{sc.teams}"
    if sc.koth:
        tag += "_koth"
    if sc.nomad:
        tag += "_nomad"
    return tag


def run_scenario(scene: Scene, sc: Scenario, out_dir: Path, png: bool = False,
                 field_entity: str = "", minimap: bool = False,
                 rs=None, blocksize: float = 16.0, tag_prefix: str = "") -> List[Finding]:
    if rs is None:
        rs = scene.resolve(sc)
        blocksize = float(scene.data.get("trade_route", {}).get("blocksize_m", 16.0))
    findings = run_checks(rs, blocksize_m=blocksize)

    if png:
        from scripts.mapsim import render
        if render.available():
            field_points = None
            constraint_layers = None
            if field_entity:
                from scripts.mapsim.field import FieldContext, region_points, split_constraints
                area = next((a for a in rs.areas if a.name == field_entity), None)
                if area is None:
                    print(f"  --field: no area named {field_entity!r}", file=sys.stderr)
                else:
                    specs, skipped = split_constraints(rs, area.constraints)
                    field_points = region_points(FieldContext(rs), specs, area.line,
                                                 obey_world_circle=area.obey_world_circle)
                    constraint_layers = [
                        (n, rs.constraints[n]) for n in area.constraints
                        if rs.constraints.get(n, {}).get("kind")
                        in ("terrain", "class_distance", "route_distance", "box", "pie")
                    ]
                    if skipped:
                        print(f"  --field: opaque constraints not in overlay: {skipped}")
            name = f"preview_{tag_prefix}{scenario_tag(sc)}.png"
            path = render.render(rs, findings, out_dir / name,
                                 title=(tag_prefix.rstrip('_') or
                                        (scene.data.get("map", "map") if scene else "map")),
                                 field_points=field_points,
                                 field_label=field_entity or None,
                                 constraint_layers=constraint_layers,
                                 minimap=minimap)
            print(f"  preview: {path}")
        else:
            print("  preview skipped: matplotlib not installed for this interpreter "
                  "— run with `python` (3.12) or `py -m pip install matplotlib`")

    out_dir.mkdir(parents=True, exist_ok=True)
    report = {
        "map": (scene.data.get("map", "?") if scene is not None
                else tag_prefix.rstrip("_") or "xs"),
        "scenario": {"players": sc.players, "teams": sc.teams,
                     "koth": sc.koth, "nomad": sc.nomad},
        "map_size_m": rs.grid.size_x_m,
        "findings": [f.to_dict() for f in findings],
    }
    out_path = out_dir / f"report_{tag_prefix}{scenario_tag(sc)}.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=1)

    counts = Counter(f.verdict for f in findings)
    summary = ", ".join(f"{v}:{n}" for v, n in sorted(counts.items()))
    print(f"[{scenario_tag(sc)}] size {rs.grid.size_x_m:.0f} m | {summary}")
    for f in findings:
        if f.severity in ("error", "warning"):
            print(f"  {f.severity.upper():7} {f.verdict:18} {f.name}: {f.message}")
    return findings


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--scene", type=Path, default=DEFAULT_SCENE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    single = parser.add_argument_group("single scenario")
    single.add_argument("--players", type=int)
    single.add_argument("--teams", type=int)
    single.add_argument("--koth", action="store_true")
    single.add_argument("--nomad", action="store_true")
    parser.add_argument("--matrix", action="store_true",
                        help="run the standard {2,3,5,7,8} x {2-team, FFA} matrix")
    parser.add_argument("--png", action="store_true",
                        help="also render a schematic preview PNG per scenario")
    parser.add_argument("--field", default="",
                        help="overlay the feasibility field of this area on the preview")
    parser.add_argument("--xs", type=Path, default=None,
                        help="extract geometry directly from this .xs map script "
                             "(WP4/WP5 pipeline) instead of a curated scene")
    parser.add_argument("--minimap", action="store_true",
                        help="rotate the preview into the in-game diamond orientation")
    args = parser.parse_args(argv)

    if not args.matrix and (args.players is None or args.teams is None):
        parser.print_usage()
        print("error: give --players and --teams, or --matrix", file=sys.stderr)
        return 2
    if not args.scene.is_file():
        print(f"error: scene not found: {args.scene}", file=sys.stderr)
        return 2

    scenarios = ([Scenario(p, t) for p, t in STANDARD_MATRIX] if args.matrix
                 else [Scenario(args.players, args.teams, koth=args.koth, nomad=args.nomad)])

    any_error = False
    if args.xs:
        from scripts.mapsim.bridge import extraction_to_resolved
        from scripts.mapsim.xs_extract import extract
        prefix = args.xs.stem.replace(" ", "_") + "_"
        for sc in scenarios:
            ex = extract(args.xs, sc)
            if ex.warnings:
                print(f"  [{args.xs.name}] extraction warnings: {ex.warnings}")
            rs = extraction_to_resolved(ex)
            findings = run_scenario(None, sc, args.out, png=args.png,
                                    field_entity=args.field, minimap=args.minimap,
                                    rs=rs, tag_prefix=prefix)
            any_error |= any(f.severity == "error" for f in findings)
        print(f"reports written to {args.out}")
        return 1 if any_error else 0

    scene = Scene.load(args.scene)
    for sc in scenarios:
        findings = run_scenario(scene, sc, args.out, png=args.png,
                                field_entity=args.field, minimap=args.minimap)
        any_error |= any(f.severity == "error" for f in findings)
    print(f"reports written to {args.out}")
    return 1 if any_error else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
