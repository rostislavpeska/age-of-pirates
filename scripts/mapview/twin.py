"""The twin: what the map script should spawn (mapsim) joined with what spawned (the census).

    python scripts/mapview/twin.py randmaps/zplondon.xs --players 2 --teams 2 [--census save.age3Yscn]
                                   [--out <dir>] [--tol-m 8] [--screens ingame,editor]

Expected = mapsim's resolved scene for that player setup: every placement with a fraction position becomes one
expected object per item proto (object defs) or one anchor with the grouping's member protos (groupings; the
member list is read from game/randmaps/groupings/<file>.xml). mapsim is approximate by design (tainted random
calls run both arms, player positions are nominal, per-player loops are not expanded), so the expected side is
the authored intent it could read, not the whole map.

Actual (optional) = census_reader.read(save, size): proto + world position; the owner is not decoded yet.

Join: per expected object, the nearest unmatched actual unit of an allowed proto within tol_m. Unmatched
expected = "missing"; actual units of a modelled proto that nothing claimed = "extra". Props and everything
the script does not model are ignored on the actual side.

Output: <out>/twin.json (every object in metres, fractions and, for each measured calibration, minimap pixels)
and <out>/twin.png (minimap orientation, problems circled; needs matplotlib).
"""
from __future__ import annotations

import argparse
import glob
import json
import math
import re
import sys
from dataclasses import dataclass, asdict, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO))
from scripts.mapview.transform import (Calibration, aspect_of, frac_to_minimap, frac_to_uv, frac_to_world,  # noqa: E402
                                        list_calibrations, disc_radius_display)

GROUPINGS = REPO / "game" / "randmaps" / "groupings"


@dataclass
class TwinObject:
    kind: str                 # "expected" | "actual"
    proto: str                # object def item proto, or the grouping file for an anchor
    x_m: float
    z_m: float
    fx: float
    fz: float
    player: Optional[int] = None
    anchor: str = ""          # the object def / grouping name in the script
    line: int = 0
    members: List[str] = field(default_factory=list)   # grouping member protos (expected anchors only)
    status: str = ""          # matched | missing | extra | unjudged
    match_id: str = ""        # the census id it matched (expected) / the anchor it served (actual)
    match_dist_m: Optional[float] = None
    pixels: Dict[str, Tuple[float, float]] = field(default_factory=dict)


# ----------------------------------------------------------------------------- expected
def grouping_members(grouping_ref: str) -> List[str]:
    """Distinct unit protos of a grouping file; the ref may be a prefix-variant (file_01, file_02 ...)."""
    cands = [GROUPINGS / (grouping_ref + ".xml")] + [Path(p) for p in sorted(glob.glob(str(GROUPINGS / (grouping_ref + "*.xml"))))]
    for p in cands:
        if p.is_file():
            t = p.read_text(encoding="utf-8", errors="replace")
            return sorted(set(re.findall(r"<unit\b[^>]*>([^<]+)</unit>", t)))
    return []


def expected_objects(xs_path: Path, players: int, teams: int):
    """(objects, resolved scene, warnings) from mapsim for that player setup."""
    from scripts.mapsim.xs_extract import extract
    from scripts.mapsim.bridge import extraction_to_resolved
    from scripts.mapsim.scene import Scenario
    ex = extract(Path(xs_path), Scenario(players, teams))
    rs = extraction_to_resolved(ex)
    try:
        from scripts.mapsim.gsolve import ensure_solved
        ensure_solved(rs)
    except Exception:
        pass
    sx, sz = rs.grid.size_x_m, rs.grid.size_z_m
    out: List[TwinObject] = []
    for p in rs.placements:
        if p.x is None or p.z is None or not p.active:
            continue
        x_m, z_m = frac_to_world(p.x, p.z, sx, sz)
        if p.is_grouping:
            out.append(TwinObject("expected", p.proto, x_m, z_m, p.x, p.z, p.player_id or None, p.name, p.line,
                                  grouping_members(p.proto)))
            continue
        items = list(p.items) or [p.proto]
        for proto in items:
            for _ in range(max(1, int(p.count or 1))):
                out.append(TwinObject("expected", proto, x_m, z_m, p.x, p.z, p.player_id or None, p.name, p.line))
    return out, rs, list(ex.warnings)


# ----------------------------------------------------------------------------- actual
def actual_objects(save: Path, size_x_m: float, size_z_m: float) -> List[TwinObject]:
    from scripts.mapview.census_reader import read
    out = []
    for u in read(Path(save), size_x_m, size_z_m):
        out.append(TwinObject("actual", u["proto"], u["x_m"], u["z_m"], u["fx"], u["fz"], u["player"], "", 0, [],
                              "unjudged", u["id"]))
    return out


# ----------------------------------------------------------------------------- join
def join(expected: List[TwinObject], actual: List[TwinObject], tol_m: float = 8.0) -> Dict[str, int]:
    """Nearest-within-tolerance per expected object, protos must agree (grouping anchors accept any member proto).
    Greedy in order of increasing distance so a unit serves the closest claim. Returns the counts."""
    modelled = set()
    for e in expected:
        modelled.add(e.proto)
        modelled.update(e.members)
    by_proto: Dict[str, List[int]] = {}
    for i, a in enumerate(actual):
        by_proto.setdefault(a.proto, []).append(i)
    claims = []   # (dist, e_idx, a_idx)
    for ei, e in enumerate(expected):
        allowed = e.members if e.members else [e.proto]
        for proto in allowed:
            for ai in by_proto.get(proto, []):
                a = actual[ai]
                d = math.hypot(a.x_m - e.x_m, a.z_m - e.z_m)
                if d <= tol_m:
                    claims.append((d, ei, ai))
    claims.sort()
    taken_e, taken_a = set(), set()
    for d, ei, ai in claims:
        if ei in taken_e or ai in taken_a:
            continue
        taken_e.add(ei); taken_a.add(ai)
        expected[ei].status = "matched"; expected[ei].match_id = actual[ai].match_id; expected[ei].match_dist_m = round(d, 2)
        actual[ai].status = "matched"; actual[ai].match_id = expected[ei].anchor; actual[ai].match_dist_m = round(d, 2)
    for ei, e in enumerate(expected):
        if ei not in taken_e:
            e.status = "missing"
    for ai, a in enumerate(actual):
        if ai not in taken_a:
            a.status = "extra" if a.proto in modelled else "unjudged"
    return {"expected": len(expected), "matched": len(taken_e), "missing": len(expected) - len(taken_e),
            "extra": sum(1 for a in actual if a.status == "extra"), "actual": len(actual)}


# ----------------------------------------------------------------------------- pixels
def add_pixels(objs: List[TwinObject], aspect: float, screens: Optional[List[str]] = None) -> Dict[str, str]:
    """Minimap pixels per measured calibration; returns {screen_key: file}."""
    used = {}
    for p in list_calibrations():
        cal = Calibration.from_json(p.read_text(encoding="utf-8"))
        if not cal.measured or (screens and cal.screen not in screens):
            continue
        key = p.stem
        used[key] = str(p)
        for o in objs:
            o.pixels[key] = tuple(round(v, 1) for v in frac_to_minimap(o.fx, o.fz, cal, aspect))
    return used


# ----------------------------------------------------------------------------- render
def render(objs: List[TwinObject], rs, out_png: Path, title: str = "twin") -> bool:
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        from matplotlib.transforms import Affine2D
        from matplotlib.patches import Circle
    except ImportError:
        return False
    aspect = aspect_of(rs.grid.size_x_m, rs.grid.size_z_m)
    fig, ax = plt.subplots(figsize=(10, 10), dpi=150)
    disp = Affine2D().scale(1.0, aspect) + Affine2D().rotate_deg_around(0.5, 0.5 * aspect, 45)
    tr = disp + ax.transData
    try:
        from scripts.mapsim.field import terrain_grid
        from scripts.mapsim.render import terrain_rgba
        tg = terrain_grid(rs, cell_tiles=1.0)
        ax.imshow(terrain_rgba(tg), origin="lower", extent=(0, 1, 0, 1), transform=tr, interpolation="nearest", zorder=1)
    except Exception as e:  # the picture still shows the objects
        ax.text(0.02, 0.98, "terrain: %s" % e, transform=ax.transAxes, fontsize=6, va="top")
    r = disc_radius_display(aspect)
    ax.add_patch(Circle((0.5, 0.5 * aspect), r, fill=False, lw=0.8, color="#888", zorder=2))
    colours = {"matched": "#22c55e", "missing": "#ef4444", "extra": "#f97316", "unjudged": "#94a3b8", "": "#3b82f6"}
    for o in objs:
        u, v = frac_to_uv(o.fx, o.fz, aspect)
        X, Y = 0.5 + u, 0.5 * aspect + v
        if o.kind == "expected":
            ax.plot(X, Y, marker="o", ms=4 if o.status != "missing" else 7, mfc="none", mec=colours.get(o.status, "#3b82f6"), mew=1.2, ls="", zorder=4)
            if o.status == "missing":
                ax.annotate(o.proto[:22], (X, Y), fontsize=5, color="#ef4444", xytext=(3, 3), textcoords="offset points")
        elif o.status in ("matched", "extra"):
            ax.plot(X, Y, marker="x", ms=4 if o.status == "matched" else 7, color=colours[o.status], mew=1.0, ls="", zorder=3)
    lim = r + 0.05
    ax.set_xlim(0.5 - lim, 0.5 + lim); ax.set_ylim(0.5 * aspect - lim, 0.5 * aspect + lim)
    ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])
    ax.set_title("%s   o expected   x actual   red = missing   orange = extra   (top = code 1,1)" % title, fontsize=8)
    out_png.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_png, bbox_inches="tight"); plt.close(fig)
    return True


# ----------------------------------------------------------------------------- CLI
def build(xs_path: Path, players: int, teams: int, census: Optional[Path], out_dir: Path, tol_m: float = 8.0,
          screens: Optional[List[str]] = None, png: bool = True) -> Dict:
    expected, rs, warnings = expected_objects(xs_path, players, teams)
    sx, sz = rs.grid.size_x_m, rs.grid.size_z_m
    actual = actual_objects(census, sx, sz) if census else []
    counts = join(expected, actual, tol_m) if census else {"expected": len(expected)}
    aspect = aspect_of(sx, sz)
    used = add_pixels(expected + actual, aspect, screens)
    out_dir.mkdir(parents=True, exist_ok=True)
    report = {"map": str(xs_path), "players": players, "teams": teams, "size_x_m": sx, "size_z_m": sz, "aspect": aspect,
              "census": str(census) if census else None, "tol_m": tol_m, "calibrations": used, "counts": counts,
              "mapsim_warnings": warnings,
              "expected": [asdict(o) for o in expected],
              "actual": [asdict(o) for o in actual if o.status in ("matched", "extra")],
              "actual_unjudged": sum(1 for o in actual if o.status == "unjudged")}
    (out_dir / "twin.json").write_text(json.dumps(report, indent=1), encoding="utf-8")
    if png:
        report["png"] = render(expected + actual, rs, out_dir / "twin.png", Path(xs_path).stem)
    return report


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("xs"); ap.add_argument("--players", type=int, default=2); ap.add_argument("--teams", type=int, default=2)
    ap.add_argument("--census", default=None); ap.add_argument("--out", default=None)
    ap.add_argument("--tol-m", type=float, default=8.0); ap.add_argument("--screens", default=None)
    ap.add_argument("--no-png", action="store_true")
    a = ap.parse_args(argv)
    out = Path(a.out) if a.out else REPO / "scripts" / "mapview" / "out" / (Path(a.xs).stem + "_%dp" % a.players)
    rep = build(Path(a.xs), a.players, a.teams, Path(a.census) if a.census else None, out, a.tol_m,
                a.screens.split(",") if a.screens else None, png=not a.no_png)
    print("%s %dp: map %.0f x %.0f m, %s; calibrations %s; mapsim warnings %d -> %s" % (
        Path(a.xs).stem, a.players, rep["size_x_m"], rep["size_z_m"], rep["counts"], list(rep["calibrations"]) or "none",
        len(rep["mapsim_warnings"]), out))
    for o in rep["expected"]:
        if o["status"] == "missing":
            print("  MISSING %-30s %-28s at %6.1f / %6.1f m (line %d)" % (o["proto"], o["anchor"], o["x_m"], o["z_m"], o["line"]))
    for o in rep["actual"]:
        if o["status"] == "extra":
            print("  EXTRA   %-30s id %-6s at %6.1f / %6.1f m" % (o["proto"], o["match_id"], o["x_m"], o["z_m"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
