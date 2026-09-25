"""Agent-readable text map of a simulated scene (owner 2026-09-25: "the tool is mainly for you; you must be able to
read and debug a map from it").

One plain-text file per scenario, next to the preview PNG and the report JSON: an ASCII grid of the BUILT terrain
(north = +z up, as in the top-down preview), the player starts and Town Center placements, the areas in build
order with the cells each claimed against its tile budget (engine-placed areas listed as not built), the King of
the Hill verdict and the error / warning findings. Pure Python - no matplotlib; render.py draws the same player
and Town Center markers from the helpers here.

Grid characters (terrain from field.terrain_grid, majority of the terrain cells under each character):
  ~ deep water   : walkable shallows   . land   # cliff rim / slope (a quarter or more of the cells)
  (blank) outside the world circle; then overlays, later wins: = trade route, G grouping, S socket,
  T Town Center placement away from its start, K King of the Hill hill, 1-8 player start.
"""

from __future__ import annotations

import math
import re
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

from scripts.mapsim.geometry import WORLD_CIRCLE_R
from scripts.mapsim.scene import ResolvedPlacement, ResolvedScene
from scripts.mapsim.scene import team_of as _scene_team_of

COLS = 64
TC_PROTOS = ("towncenter", "coveredwagon")
TC_APART_M = 4.0            # a Town Center placement this far from its start is drawn / listed as its own spot
MAX_AREA_ROWS = 48
MAX_FINDINGS_PER_VERDICT = 3

CH_LAND, CH_SHALLOW, CH_DEEP, CH_CLIFF, CH_OUT = ".", ":", "~", "#", " "
CH_ROUTE, CH_GROUPING, CH_SOCKET, CH_TC, CH_KOTH = "=", "G", "S", "T", "K"
_CLASS_CH = (CH_LAND, CH_SHALLOW, CH_DEEP, CH_CLIFF)

LEGEND = ("legend: ~ deep water  : shallows (walkable)  . land  # cliff  = trade route  G grouping  S socket  "
          "T Town Center (away from its start)  K KotH hill  1-8 player start  (blank) outside the world circle")


# --- players ---------------------------------------------------------------------------------------------------

def team_of(k: int, players: int, teams: int) -> int:
    """0-based team of the 0-based lobby slot k: mapsim's ONE team model (scene.team_of, contiguous blocks), which
    rmGetPlayerTeam, the ring, team areas and the twin also use."""
    return _scene_team_of(k + 1, players, teams)


def player_starts(rs: ResolvedScene) -> List[Tuple[int, int, float, float]]:
    """(player 1-8, team 0-based, x, z) for every NOMINAL start (ResolvedScene.player_locs, fractions)."""
    n = len(rs.player_locs)
    teams = rs.scenario.teams
    return [(k + 1, team_of(k, n, teams), x, z) for k, (x, z) in enumerate(rs.player_locs)]


def is_town_center(p: ResolvedPlacement) -> bool:
    return any(str(t).lower() in TC_PROTOS for t in (p.items or ()))


def town_centers(rs: ResolvedScene) -> List[Tuple[ResolvedPlacement, List[int]]]:
    """Town Center / Covered Wagon placements (items include TownCenter or CoveredWagon) with their players
    (the literal players of the placement calls; [] = gaia or runtime-dependent)."""
    out = []
    for p in rs.placements:
        if is_town_center(p):
            players = list(dict.fromkeys(p.players or ([p.player_id] if p.player_id else [])))
            out.append((p, players))
    return out


def town_centers_apart(rs: ResolvedScene) -> List[Tuple[ResolvedPlacement, List[int], Optional[Tuple[float, float]]]]:
    """Concrete Town Center placements NOT standing on their player's start (farther than TC_APART_M), with that
    start (None when the placement has no player with a known start) - the ones the preview and the grid mark
    separately; a Town Center on its start is represented by the start marker."""
    starts = {pl: (x, z) for pl, _t, x, z in player_starts(rs)}
    out = []
    for p, players in town_centers(rs):
        if p.x is None or p.z is None:
            continue
        start = next((starts[pl] for pl in players if pl in starts), None)
        if start is not None and rs.grid.frac_dist_m(p.x, p.z, start[0], start[1]) <= TC_APART_M:
            continue
        out.append((p, players, start))
    return out


# --- terrain ---------------------------------------------------------------------------------------------------

def display_grid(rs: ResolvedScene):
    """The built terrain the preview draws and the text map prints: groupings solved first (gsolve), then
    field.terrain_grid at 1 cell = 1 tile - exactly what render.render computed on its own before."""
    from scripts.mapsim.field import terrain_grid
    from scripts.mapsim.gsolve import ensure_solved
    ensure_solved(rs)
    return terrain_grid(rs, cell_tiles=1.0)


def _in_circle_frac(rs: ResolvedScene, x: float, z: float) -> bool:
    g = rs.grid
    dx = (x - 0.5) * g.size_x_m
    dz = (z - 0.5) * g.size_z_m
    r = WORLD_CIRCLE_R * max(g.size_x_m, g.size_z_m)
    return dx * dx + dz * dz <= r * r


def _ground_at(rs: ResolvedScene, tg, x: float, z: float) -> str:
    """What the built grid has under a fraction point: land (+ the land area that claimed it), shallows or deep
    water with the depth, or a cliff rim."""
    i, j = tg.cell_of_frac(x, z)
    code = tg.class_code(i, j)
    if code == 3:
        return "CLIFF RIM"
    if code == 0:
        k = tg.land[j][i]
        if k:
            return f"land '{tg.land_order[k - 1]}'"
        return "land (base)" if not rs.base_is_water else "land"
    d = tg.wdepth[j][i] if tg.wdepth else 0.0
    if code == 1:
        return f"shallows {d:g} m"
    return f"DEEP WATER {d:g} m"


class _Canvas:
    def __init__(self, rs: ResolvedScene, cols: int = COLS):
        """Square characters, `cols` along the LONGER side (Barrier Reef, 3.75 times taller than wide, is 17 x 64
        characters rather than 64 x 240)."""
        g = rs.grid
        self.rs = rs
        self.cell_m = max(g.size_x_m, g.size_z_m) / cols
        self.cols = max(1, int(round(g.size_x_m / self.cell_m)))
        self.rows = max(1, int(round(g.size_z_m / self.cell_m)))
        self.chars = [[CH_OUT] * self.cols for _ in range(self.rows)]

    def rc_of(self, x: float, z: float) -> Optional[Tuple[int, int]]:
        """(row, col) of a fraction point, row 0 = north (z = 1); None off the map."""
        if not (0.0 <= x <= 1.0 and 0.0 <= z <= 1.0):
            return None
        c = min(self.cols - 1, int(x * self.cols))
        r = min(self.rows - 1, int((1.0 - z) * self.rows))
        return r, c

    def put(self, x: float, z: float, ch: str) -> None:
        rc = self.rc_of(x, z)
        if rc is not None:
            self.chars[rc[0]][rc[1]] = ch

    def terrain(self, tg) -> Dict[str, int]:
        """Fill the characters from the built grid; returns the class shares inside the world circle."""
        rs = self.rs
        counts = [[[0, 0, 0, 0] for _ in range(self.cols)] for _ in range(self.rows)]
        keys = ("land", "shallow", "deep", "cliff")
        shares = {k: 0 for k in keys}
        for j in range(tg.nz):
            zf = (j + 0.5) / tg.nz
            r = min(self.rows - 1, int((1.0 - zf) * self.rows))
            for i in range(tg.nx):
                xf = (i + 0.5) / tg.nx
                c = min(self.cols - 1, int(xf * self.cols))
                code = tg.class_code(i, j)
                counts[r][c][code] += 1
                if not rs.world_circle or _in_circle_frac(rs, xf, zf):
                    shares[keys[code]] += 1
        for r in range(self.rows):
            zc = 1.0 - (r + 0.5) / self.rows
            for c in range(self.cols):
                xc = (c + 0.5) / self.cols
                cnt = counts[r][c]
                tot = sum(cnt)
                if tot == 0:
                    continue
                if rs.world_circle and not _in_circle_frac(rs, xc, zc):
                    continue
                if cnt[3] * 4 >= tot:
                    code = 3
                else:
                    code = max(range(3), key=lambda k: (cnt[k], -k))
                self.chars[r][c] = _CLASS_CH[code]
        return shares

    def polyline(self, pts: Sequence[Tuple[float, float]], ch: str) -> None:
        g = self.rs.grid
        for (x1, z1), (x2, z2) in zip(pts, pts[1:]):
            length = g.frac_dist_m(x1, z1, x2, z2)
            n = max(1, int(length / (self.cell_m / 3.0)))
            for k in range(n + 1):
                t = k / n
                self.put(x1 + t * (x2 - x1), z1 + t * (z2 - z1), ch)

    def lines(self) -> List[str]:
        head = [" "] * self.cols
        for c in range(0, self.cols, 8):
            lab = f"{c / self.cols:.2f}"
            if c + len(lab) > self.cols:
                break
            for k, chh in enumerate(lab):
                if c + k < self.cols:
                    head[c + k] = chh
        out = ["  z\\x  |" + "".join(head) + "|"]      # as wide as the "  0.99 |" row labels
        for r, row in enumerate(self.chars):
            zc = 1.0 - (r + 0.5) / self.rows
            out.append(f"  {zc:4.2f} |" + "".join(row) + "|")
        return out


# --- areas -----------------------------------------------------------------------------------------------------

_KIND_SHORT = (
    ("water area", "water"),
    ("submerged ground", "submerged"),
    ("river band", "river"),
    ("causeway (land)", "causeway land"),
    ("causeway (shallow)", "causeway shallow"),
    ("cliff (inherits ground)", "cliff"),
    ("painted (texture only)", "paint only"),
    ("invisible mask (carve to sea floor)", "mask carves sea"),
    ("invisible mask (blend-flattened)", "mask (flat)"),
    ("invisible template (dry)", "mask (dry)"),
    ("land", "land"),
)


def _short_kind(category: str) -> str:
    base, _, cliff = category.partition(" + ")
    short = next((s for full, s in _KIND_SHORT if base == full), base)
    if cliff:
        short += " +" + cliff.replace("cliff ", "cliff-")
    return short


def _stem(name: str) -> str:
    return re.sub(r"[\s_]*\d+$", "", name).strip() or name


def _area_rows(rs: ResolvedScene, tg) -> List[Tuple[str, str]]:
    """(kind, text) rows in build order: consecutive steps with the same name stem, kind and radius merge into one
    row (loop-made areas such as 'player 1'..'player 6', a river drawn in ten pieces), with the first member's
    anchor and the summed cells / budgets."""
    g = rs.grid
    located = sorted((a for a in rs.areas if a.x is not None), key=lambda a: a.line)
    area_by_step = iter(located)
    steps = []
    for b in (tg.builds or []):
        a = next(area_by_step) if b["kind"] == "area" else None
        steps.append((b, a))
    for a in rs.areas:
        if a.x is None:
            steps.append(({"kind": "engine", "name": a.name, "line": a.line, "category": "", "cells": None,
                           "budget": None}, a))
    steps.sort(key=lambda s: (s[0]["line"], 0 if s[0]["kind"] != "engine" else 1))

    rows: List[dict] = []
    for b, a in steps:
        if b["kind"] == "engine":
            kind = ("land" if a.creates_land else "water" if a.water_type else
                    "cliff" if a.cliff_type else "paint/mask")
            if a.base_height is not None and kind == "land":
                kind += f" h{a.base_height:g}"
            per = math.pi * a.radius_m ** 2 / (g.TILE_M ** 2)
            key = ("engine", a.name)
            row = {"key": key, "names": [a.name], "line": b["line"], "anchor": None, "r": a.radius_m,
                   "kind": kind, "cells": None, "budget": round(per * max(1, a.count)), "n": 1,
                   "flags": f"NOT BUILT: engine-placed, {a.count} x {per:.0f} tiles"}
            rows.append(row)
            continue
        kind = _short_kind(b["category"])
        if a is not None and a.base_height is not None and kind in ("land", "submerged", "mask (dry)"):
            kind += f" h{a.base_height:g}"
        r_m = a.radius_m if a is not None else None
        key = (b["kind"], _stem(b["name"]), kind, None if r_m is None else round(r_m))
        flags = []
        if a is not None and a.approx:
            flags.append("approx anchor")
        prev = rows[-1] if rows else None
        if prev is not None and prev["key"] == key:
            prev["names"].append(b["name"])
            prev["cells"] += b["cells"]
            prev["budget"] = (prev["budget"] or 0) + (b["budget"] or 0)
            prev["n"] += 1
            continue
        rows.append({"key": key, "names": [b["name"]], "line": b["line"],
                     "anchor": (a.x, a.z) if a is not None else None, "r": r_m, "kind": kind,
                     "cells": b["cells"], "budget": b["budget"], "n": 1, "flags": ", ".join(flags)})

    out = []
    for row in rows:
        names = row["names"]
        stem = _stem(names[0])
        if len(names) == 1:
            name = names[0]
        elif len(set(names)) == 1:
            name = f"{names[0]} x{len(names)}"
        elif all(n.startswith(stem) for n in names):
            name = f"{names[0]}..{names[-1][len(stem):].strip(' _')} x{len(names)}"
        else:
            name = f"{names[0]}..{names[-1]} x{len(names)}"
        if len(name) > 26:
            name = name[:25] + "~"
        anchor = "engine" if row["key"][0] == "engine" else (
            "-" if row["anchor"] is None else f"{row['anchor'][0]:.2f},{row['anchor'][1]:.2f}")
        r = "-" if row["r"] is None else f"{row['r']:.0f}"
        if row["cells"] is None:
            built = f"0/{row['budget']}"
        elif row["budget"]:
            built = f"{row['cells']}/{row['budget']}"
        else:
            built = f"{row['cells']}"
        flags = row["flags"]
        if row["cells"] is not None and row["budget"] and row["cells"] < row["budget"]:
            short = f"SHORT {100.0 * row['cells'] / row['budget']:.0f}%"
            flags = short + (", " + flags if flags else "")
        out.append((row["kind"],
                    f"  {row['line']:5} {name:26} {anchor:9} {r:>4} {row['kind']:20} {built:>11}  {flags}".rstrip()))
    return out


# --- the file --------------------------------------------------------------------------------------------------

def build_text_map(rs: ResolvedScene, findings: Sequence, title: str = "map", tg=None,
                   cols: int = COLS) -> str:
    """The whole text map as one string (see the module docstring)."""
    from collections import Counter
    if tg is None:
        tg = display_grid(rs)
    g = rs.grid
    sc = rs.scenario
    canvas = _Canvas(rs, cols)
    shares = canvas.terrain(tg)

    for wps in rs.all_routes():
        if len(wps) >= 2:
            canvas.polyline(wps, CH_ROUTE)
    for p in rs.placements:
        if p.x is None or p.z is None or is_town_center(p):
            continue
        socket = any("socket" in str(t).lower() for t in (p.items or ())) or "socket" in str(p.proto).lower()
        if p.is_grouping or socket:
            canvas.put(p.x, p.z, CH_SOCKET if socket else CH_GROUPING)
    apart = town_centers_apart(rs)
    for p, _players, _start in apart:
        canvas.put(p.x, p.z, CH_TC)
    koth = [f for f in findings if getattr(f, "scope", None) == "koth"]
    for f in koth:
        hill = (f.details or {}).get("hill_m")
        if hill:
            canvas.put(g.x_m_to_frac(hill[0]), g.z_m_to_frac(hill[1]), CH_KOTH)
    starts = player_starts(rs)
    for pl, _t, x, z in starts:
        canvas.put(x, z, str(pl % 10))

    tag = f"P{sc.players} T{sc.teams}" + (" KOTH" if sc.koth else "") + (" nomad" if sc.nomad else "")
    base = (f"water (sea type {rs.sea_type or '?'})" if rs.base_is_water else "land")
    tot = sum(shares.values()) or 1
    lines = [
        f"MAPSIM TEXT MAP  {title}  {tag}  {g.size_x_m:.0f} x {g.size_z_m:.0f} m",
        f"base {base}, sea level {rs.sea_level:g} m, world circle {'on' if rs.world_circle else 'off'}; "
        f"built terrain {'inside the world circle' if rs.world_circle else 'on the whole map'}: land {100.0 * shares['land'] / tot:.0f}%, shallows "
        f"{100.0 * shares['shallow'] / tot:.0f}%, deep {100.0 * shares['deep'] / tot:.0f}%, "
        f"cliff {100.0 * shares['cliff'] / tot:.0f}%",
        f"grid {canvas.cols} x {canvas.rows}, 1 char = {canvas.cell_m:.1f} m; north (+z) up, x to the right "
        "(the top-down preview); the minimap is this grid turned 45 deg counter-clockwise",
        LEGEND,
    ]
    lines += canvas.lines()

    # players
    tcs = town_centers(rs)
    lines.append("")
    lines.append(f"PLAYERS ({len(starts)} nominal starts; team = contiguous block of the lobby order)")
    by_player: Dict[int, List[ResolvedPlacement]] = {}
    for p, players in tcs:
        for pl in players:
            by_player.setdefault(pl, []).append(p)
    owned: Dict[int, List[str]] = {}
    for p in rs.placements:
        if p.is_grouping and p.player_id:
            owned.setdefault(p.player_id, []).append(str(p.proto or p.name))
    for pl, t, x, z in starts:
        xm, zm = g.frac_to_m(x, z)
        parts = [f"  {pl} T{t + 1}  start {x:.3f},{z:.3f} ({xm:.0f},{zm:.0f} m)  on {_ground_at(rs, tg, x, z)}"]
        for p in by_player.get(pl, [])[:2]:
            if p.x is None:
                where = ("in area " + ", ".join(p.area_refs)) if p.area_refs else "runtime spot"
                parts.append(f"TC '{p.name}' {where}")
            else:
                d = g.frac_dist_m(p.x, p.z, x, z)
                spot = "at start" if d <= TC_APART_M else f"{p.x:.3f},{p.z:.3f} ({d:.0f} m away, on {_ground_at(rs, tg, p.x, p.z)})"
                parts.append(f"TC '{p.name}' {spot}" + (f" float {p.max_dist_m:g} m" if p.max_dist_m else ""))
        if pl in owned:
            names = owned[pl]
            parts.append("groupings " + ", ".join(names[:2]) + (f" +{len(names) - 2}" if len(names) > 2 else ""))
        lines.append("; ".join(parts))
    if not starts:
        lines.append("  (no nominal starts: curated scene or runtime placement)")
    for p, players in tcs:
        if not players and p.x is not None:
            lines.append(f"  TC '{p.name}' (no literal player) at {p.x:.3f},{p.z:.3f} on {_ground_at(rs, tg, p.x, p.z)}")

    # KotH
    if koth:
        lines.append("")
        for f in koth:
            lines.append(f"KOTH {f.verdict}: {f.message}")

    # areas
    lines.append("")
    lines.append("AREAS in build order (cells = tiles claimed at build time / tile budget; later builds may cover "
                 "them; merged rows = same name stem, kind and radius, anchor of the first)")
    lines.append(f"  {'line':>5} {'name':26} {'anchor':9} {'r_m':>4} {'kind':20} {'cells/budget':>11}  flags")
    rows = _area_rows(rs, tg)
    tail = []
    if len(rows) > MAX_AREA_ROWS:
        # Texture-only areas change no terrain: the first to go when the table is long.
        paint = [r for r in rows if r[0] == "paint only"]
        rows = [r for r in rows if r[0] != "paint only"]
        tail.append(f"  ... {len(paint)} paint-only rows omitted")
    if len(rows) > MAX_AREA_ROWS:
        tail.append(f"  ... {len(rows) - MAX_AREA_ROWS} more rows (every build step: --layers, layers.json)")
        rows = rows[:MAX_AREA_ROWS]
    lines += [text for _kind, text in rows] + tail

    # findings
    serious = [f for f in findings if getattr(f, "severity", "") in ("error", "warning")]
    counts = Counter(f.verdict for f in findings)
    lines.append("")
    lines.append(f"FINDINGS {len(findings)}: " + ", ".join(f"{v} {n}" for v, n in sorted(counts.items())))
    shown: Counter = Counter()
    for sev in ("error", "warning"):
        for f in serious:
            if f.severity != sev:
                continue
            shown[f.verdict] += 1
            if shown[f.verdict] > MAX_FINDINGS_PER_VERDICT:
                continue
            msg = f.message if len(f.message) <= 110 else f.message[:109] + "~"
            lines.append(f"  {sev.upper():7} {f.verdict} {f.name}: {msg}")
    for v, n in sorted(shown.items()):
        if n > MAX_FINDINGS_PER_VERDICT:
            lines.append(f"  ... {n - MAX_FINDINGS_PER_VERDICT} more {v}")
    return "\n".join(lines) + "\n"


def write_text_map(rs: ResolvedScene, findings: Sequence, out_path: Path, title: str = "map", tg=None) -> Path:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(build_text_map(rs, findings, title=title, tg=tg), encoding="utf-8")
    return out_path
