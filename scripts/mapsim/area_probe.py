"""What did the ENGINE really build? Instrument a map, generate it once in the editor, read the save.

Owner 2026-10-07 (Danube, "SOME AREAS NOT SPAWNED", "the area spawn issue is CRITICAL ... the pattern must be
detected and prevented"): mapsim showed the shores filling the map, the game left whole regions as water. Neither the
minimap nor `save_diff.py` says WHICH area stopped short or WHERE a computed point really went. This tool does:

    python scripts/mapsim/area_probe.py make game/randmaps/zpdanube.xs
        --areas "north outer shore,inner shore"                     # area membership, a G x G grid per area
        --mark "rmBuildArea(channelID);|discXM|discZM|HomeCityWaterSpawnFlag"   # a marker after every such line
        [--grid 32] [--name 0000000_areaprobe]
        -> <Steam>/Game/RandMaps/<name>.xs + .xml (an editor-only bench, sorted to the top of the Type list)
           and <name>.probe.json beside them (which marker stands for what)
    (generate <name> in the Scenario Editor with the player count you want, File > Save As)
    python scripts/mapsim/area_probe.py read "<profile>/Scenario/<save>.age3Yscn" --players N [--out probe.png]
        -> per area: the grid points inside it in the GAME against mapsim's claim; per mark: game positions against
           mapsim's, point by point

Areas: right after each named area's rmBuildArea, one marker unit per area (a distinct livestock proto) on every point
of the grid, with rmCreateAreaConstraint(area) and max distance 0, so a marker stands exactly where the area owns the
tile. Land areas only (land units); grid points outside the world circle never count (the engine drops objects
there). Marks: a water-capable marker at metres (XEXPR, ZEXPR) after every line holding ANCHOR - any computed
position the script uses, recorded by the engine itself.

A probe generation is for measuring; the markers are placed mid-script, so later placements are disturbed.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple

REPO = Path(__file__).resolve().parents[2]
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))

PROTOS = ["Cow", "Sheep", "Llama", "ypWaterBuffalo", "ypYak", "ypGoat", "ypSacredCow", "Pig"]   # vanilla, land
NL = chr(10)


def _steam_randmaps() -> Path:
    from scripts.mapcheck.locate import game_install
    g = game_install()
    if g is None:
        raise SystemExit("no AoE3DE install found (AOE3DE_GAME / Steam)")
    return g / "RandMaps"


def instrument(src: str, areas: List[str], grid: int) -> Tuple[str, Dict[str, str]]:
    """The script with a probe block after each named area's rmBuildArea; {area name: marker proto}."""
    if len(areas) > len(PROTOS):
        raise SystemExit(f"at most {len(PROTOS)} areas per probe")
    mapping = {}
    for k, name in enumerate(areas):
        m = re.search(r'int\s+(\w+)\s*=\s*rmCreateArea\(\s*"%s"\s*\)' % re.escape(name), src)
        if not m:
            raise SystemExit(f'no `int <var> = rmCreateArea("{name}")` with that literal name')
        var = m.group(1)
        b = re.compile(r'([ \t]*)rmBuildArea\(\s*%s\s*\)\s*;[^\n]*\n' % re.escape(var)).search(src, m.end())
        if not b:
            raise SystemExit(f"no rmBuildArea({var}); after {name!r}")
        ind = b.group(1)
        proto = PROTOS[k]
        block = NL.join([
            f'{ind}// area_probe: a {proto} on every grid point inside "{name}"',
            f'{ind}int probeDef{k} = rmCreateObjectDef("area probe {k}");',
            f'{ind}rmAddObjectDefItem(probeDef{k}, "{proto}", 1, 0.0);',
            f'{ind}rmSetObjectDefAllowOverlap(probeDef{k}, true);',
            f'{ind}rmSetObjectDefMinDistance(probeDef{k}, 0.0);',
            f'{ind}rmSetObjectDefMaxDistance(probeDef{k}, 0.0);',
            f'{ind}rmAddObjectDefConstraint(probeDef{k}, rmCreateAreaConstraint("area probe in {k}", {var}));',
            f'{ind}float probeX{k} = 0.0;',
            f'{ind}float probeZ{k} = 0.0;',
            f'{ind}for (pgx{k}=0; < {grid}) {{',
            f'{ind}\tprobeX{k} = (1.0*pgx{k} + 0.5) / {grid}.0;',
            f'{ind}\tfor (pgz{k}=0; < {grid}) {{',
            f'{ind}\t\tprobeZ{k} = (1.0*pgz{k} + 0.5) / {grid}.0;',
            f'{ind}\t\trmPlaceObjectDefAtLoc(probeDef{k}, 0, probeX{k}, probeZ{k});',
            f'{ind}\t}}',
            f'{ind}}}',
        ]) + NL
        src = src[:b.end()] + block + src[b.end():]
        mapping[name] = proto
    return src, mapping


def instrument_marks(src: str, marks: List[str]) -> Tuple[str, Dict[str, dict]]:
    """--mark "ANCHOR|XEXPR|ZEXPR|PROTO": after every line containing ANCHOR, a PROTO marker at metres (XEXPR, ZEXPR).
    The defs are created right after rmSetMapSize. {def name: {anchor, x, z, proto}}."""
    meta, defs = {}, []
    for j, spec in enumerate(marks):
        parts = [s.strip() for s in spec.split("|")]
        if len(parts) != 4:
            raise SystemExit(f"--mark needs ANCHOR|XEXPR|ZEXPR|PROTO, got {spec!r}")
        anchor, xe, ze, proto = parts
        dname = f"probe mark {j}"
        out, hits = [], 0
        for line in src.split(NL):
            out.append(line)
            if anchor in line:
                ind = line[:len(line) - len(line.lstrip())]
                out.append(f"{ind}rmPlaceObjectDefAtLoc(probeMark{j}, 0, rmXMetersToFraction({xe}), "
                           f"rmZMetersToFraction({ze}));")
                hits += 1
        if not hits:
            raise SystemExit(f"--mark anchor {anchor!r} matches no line")
        src = NL.join(out)
        defs.append(NL.join([f'\tint probeMark{j} = rmCreateObjectDef("{dname}");',
                             f'\trmAddObjectDefItem(probeMark{j}, "{proto}", 1, 0.0);',
                             f'\trmSetObjectDefAllowOverlap(probeMark{j}, true);',
                             f'\trmSetObjectDefMinDistance(probeMark{j}, 0.0);',
                             f'\trmSetObjectDefMaxDistance(probeMark{j}, 0.0);']) + NL)
        meta[dname] = {"anchor": anchor, "x": xe, "z": ze, "proto": proto}
    if defs:
        m = re.search(r"rmSetMapSize\([^\n]*\n", src)
        if not m:
            raise SystemExit("no rmSetMapSize line to put the mark defs after")
        src = src[:m.end()] + "".join(defs) + src[m.end():]
    return src, meta


def make(xs: Path, areas: List[str], grid: int, name: str, marks: List[str] = ()) -> Path:
    raw = xs.read_bytes().decode("utf-8").replace("\r\n", NL)
    probe, mapping = instrument(raw, areas, grid)
    probe, mark_meta = instrument_marks(probe, list(marks))
    rm = _steam_randmaps()
    (rm / f"{name}.xs").write_bytes(probe.replace(NL, "\r\n").encode("utf-8"))
    xml = xs.with_suffix(".xml")
    if xml.is_file():
        x = xml.read_bytes().decode("utf-8")
        x = re.sub(r'displayNameID\s*=\s*"\d+"', f'displayName = "{name}"', x)
        x = re.sub(r'largeMapName\s*=\s*"[^"]*"', '', x)
        (rm / f"{name}.xml").write_bytes(x.encode("utf-8"))
    meta = {"script": str(xs.resolve()), "probe": str(rm / f"{name}.xs"), "areas": mapping, "grid": grid,
            "name": name, "marks": mark_meta}
    (rm / f"{name}.probe.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")
    print(f"wrote {rm / (name + '.xs')} ({len(mapping)} areas, {len(mark_meta)} marks, {grid}x{grid} grid) "
          f"and {name}.probe.json")
    return rm / f"{name}.xs"


def sim_run(xs: Path, players: int, teams: int):
    """mapsim on the PROBE script: (map size m, {area: claimed 1-tile cells}, terrain grid, extraction)."""
    from scripts.mapsim.bridge import extraction_to_resolved
    from scripts.mapsim.field import terrain_grid
    from scripts.mapsim.scene import Scenario
    from scripts.mapsim.xs_extract import extract
    ex = extract(xs, Scenario(players=players, teams=teams))
    rs = extraction_to_resolved(ex)
    claims: Dict[str, set] = {}

    def on_step(ev):
        claims.setdefault(ev["name"], set()).update(ev["cells"])
    tg = terrain_grid(rs, cell_tiles=1.0, on_step=on_step)
    return rs.grid.size_x_m, claims, tg, ex


def read(save: Path, name: str, players: int, teams: int, out: Path | None) -> int:
    sys.path.insert(0, str(REPO / "sandbox" / "census"))
    from census import census
    meta = json.loads((_steam_randmaps() / f"{name}.probe.json").read_text(encoding="utf-8"))
    grid = int(meta["grid"])
    units = census(save)
    size_m, claims, tg, ex = sim_run(Path(meta.get("probe") or meta["script"]), players, teams)
    step = size_m / grid
    tile = size_m / tg.nx
    bad = False
    pics = {}
    print(f"{save.name} vs {name} ({players} players), {grid}x{grid} grid, {step:.1f} m spacing")
    if meta["areas"]:
        print(f"  {'area':<28} {'marker':<14} {'mapsim pts':>10} {'game pts':>9} {'game covers':>12} {'game only':>10}")
    for area, proto in meta["areas"].items():
        game_pts = {(int(u["x"] // step), int(u["z"] // step)) for u in units if u["proto"] == proto}
        sim_cells = claims.get(area, set())
        sim_pts = set()
        for gi in range(grid):
            for gj in range(grid):
                px, pz = (gi + 0.5) * step, (gj + 0.5) * step
                if (px - size_m / 2) ** 2 + (pz - size_m / 2) ** 2 > (0.5 * size_m - 6.0) ** 2:
                    continue        # the engine drops objects outside the world circle: no marker can stand there
                if (int(px // tile), int(pz // tile)) in sim_cells:
                    sim_pts.add((gi, gj))
        cover = 100.0 * len(game_pts & sim_pts) / max(1, len(sim_pts))
        extra = len(game_pts - sim_pts)
        bad = bad or cover < 90.0
        flag = "  <-- SHORT" if cover < 90.0 else ""
        print(f"  {area:<28} {proto:<14} {len(sim_pts):>10} {len(game_pts):>9} {cover:>11.0f}% {extra:>10}{flag}")
        pics[area] = (game_pts, sim_pts)
    mark_pts = {}
    for dname, mm in (meta.get("marks") or {}).items():
        want = [(float(p.x) * size_m, float(p.z) * size_m) for p in ex.placements
                if p.name == dname and p.nominal and isinstance(p.x, (int, float)) and isinstance(p.z, (int, float))]
        got = [(u["x"], u["z"]) for u in units if u["proto"] == mm["proto"]]
        far = []
        for k, (gx, gz) in enumerate(got):
            d = min((((gx - wx) ** 2 + (gz - wz) ** 2) ** 0.5 for wx, wz in want), default=1e9)
            if d > 6.0:
                far.append((k, gx, gz, d))
        print(f"  marks {dname} ({mm['proto']} after {mm['anchor']!r}): mapsim {len(want)}, game {len(got)}, "
              f"{len(far)} game marks more than 6 m from every mapsim mark")
        for k, gx, gz, d in far[:15]:
            print(f"    game mark #{k} at ({gx:.0f}, {gz:.0f}) m: nearest mapsim mark {d:.0f} m away")
        bad = bad or bool(far) or len(got) != len(want)
        mark_pts[dname] = (got, want)
    if out:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        panels = list(pics.items()) + [(k, None) for k in mark_pts]
        n = max(1, len(panels))
        fig, axes = plt.subplots(1, n, figsize=(4.2 * n, 4.4))
        axes = [axes] if n == 1 else list(axes)
        for ax, (label, val) in zip(axes, panels):
            if val is not None:
                g, s = val
                cells = [(c, "#e8c840") for c in s - g] + [(c, "#3c8c4c") for c in g & s] + [(c, "#d04040") for c in g - s]
                for (gi, gj), c in cells:
                    ax.add_patch(plt.Rectangle((gi * step, gj * step), step, step, color=c))
            else:
                got, want = mark_pts[label]
                ax.scatter([w[0] for w in want], [w[1] for w in want], s=10, c="#3070d0", label="mapsim")
                ax.scatter([g[0] for g in got], [g[1] for g in got], s=6, c="#d04040", label="game")
                ax.legend(fontsize=7)
            ax.set_xlim(0, size_m)
            ax.set_ylim(0, size_m)
            ax.set_aspect("equal")
            ax.set_title(label, fontsize=9)
            ax.set_xticks([])
            ax.set_yticks([])
        fig.suptitle("areas - green: game and mapsim, YELLOW: mapsim only (the game never grew there), red: game only;"
                     " marks - blue mapsim, red game", fontsize=9)
        fig.tight_layout()
        fig.savefig(out, dpi=80)
        print(f"  picture: {out}")
    return 1 if bad else 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split(NL)[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("make")
    m.add_argument("xs")
    m.add_argument("--areas", default="", help="comma-separated literal area names")
    m.add_argument("--mark", action="append", default=[], help='"ANCHOR|XEXPR|ZEXPR|PROTO" (repeatable)')
    m.add_argument("--grid", type=int, default=32)
    m.add_argument("--name", default="0000000_areaprobe")
    r = sub.add_parser("read")
    r.add_argument("save")
    r.add_argument("--name", default="0000000_areaprobe")
    r.add_argument("--players", type=int, required=True)
    r.add_argument("--teams", type=int, default=2)
    r.add_argument("--out")
    a = ap.parse_args(argv)
    if a.cmd == "make":
        make(Path(a.xs), [s.strip() for s in a.areas.split(",") if s.strip()], a.grid, a.name, a.mark)
        return 0
    return read(Path(a.save), a.name, a.players, a.teams, Path(a.out) if a.out else None)


if __name__ == "__main__":
    sys.exit(main())
