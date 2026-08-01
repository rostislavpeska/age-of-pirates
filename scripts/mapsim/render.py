"""Schematic map preview renderer (plan section 2.4).

Terrain comes from field.terrain_grid — budget-driven growth shapes, not
ideal circles (research decision record). Authored discs remain as faint
dashed outlines. matplotlib is an OPTIONAL dependency (repo's lz4
precedent): imported lazily; `available()` lets callers skip gracefully.

`minimap=True` rotates the whole scene +45 deg about the center so it lines
up with the in-game diamond minimap. CALIBRATED (plan E4 closed): the Elbe
ground-truth side-by-side fixed the sign, and a full session of Independence
War in-game screenshots matched the renders (bridge upper-left, bay
lower-right, pirate coves at the gulf mouth).
"""

from __future__ import annotations

from pathlib import Path
from typing import Dict, List, Optional

from scripts.mapsim.checks import Finding
from scripts.mapsim.geometry import WORLD_CIRCLE_R
from scripts.mapsim.scene import ResolvedScene, _check_when

WATER = "#16324f"
CIRCLE_DIM = "#0b1c30"
ROUTE = "#e8d9a0"
RING = "#e0e6ee"

VERDICT_COLOR = {
    "OK": "#3fae4c",
    "INACTIVE": "#9aa0a6",
    "UNKNOWN_RUNTIME": "#9aa0a6",
    "EDGE_RISK": "#e5a50a",
    "NEAR_EDGE_OF_AREA": "#e5a50a",
    "OFF_MAP": "#d0342c",
    "OUTSIDE_CIRCLE": "#d0342c",
    "WRONG_TERRAIN": "#d0342c",
    "CONSTRAINT_UNSAT": "#d0342c",
    "CONFIG": "#d0342c",
}

KIND_MARKER = {
    "at_loc": "o",
    "grouping_at_loc": "D",
    "at_point_runtime": "s",
    "closest_point": "^",
}

LABEL_ALWAYS = (
    "lone socket 1", "lone socket 2", "lone socket 3", "lone socket 4",
    "pirate city 1", "pirate city 2", "bridge", "bridge stopper",
    "estate west upper", "estate west middle", "estate west lower",
    "estate east upper", "estate east middle", "estate east lower",
)


def available() -> bool:
    try:
        import matplotlib  # noqa: F401
        return True
    except ImportError:
        return False


def render(rs: ResolvedScene, findings: List[Finding], out_path: Path,
           title: Optional[str] = None,
           field_points: Optional[List] = None,
           field_label: Optional[str] = None,
           constraint_layers: Optional[List] = None,
           minimap: bool = False) -> Path:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np
    from matplotlib.lines import Line2D
    from matplotlib.patches import Arc, Circle, PathPatch, Rectangle
    from matplotlib.path import Path as MplPath
    from matplotlib.transforms import Affine2D

    from scripts.mapsim.field import FieldContext, terrain_grid

    grid = rs.grid
    verdicts: Dict[str, Finding] = {f.name: f for f in findings if f.scope == "placement"}

    fig, ax = plt.subplots(figsize=(10, 10), dpi=200)
    if minimap:
        # +45 deg calibrated against elbe_mini.png: the pirate island at
        # fraction (0.5, 0.95) sits top-LEFT in the in-game minimap.
        rot = Affine2D().rotate_deg_around(0.5, 0.5, 45)
        tr = rot + ax.transData
        pad = 0.5 * (2 ** 0.5) - 0.5 + 0.02
        ax.set_xlim(-pad, 1.0 + pad)
        ax.set_ylim(-pad, 1.0 + pad)
        ax.set_xticks([])
        ax.set_yticks([])
    else:
        tr = ax.transData
        ax.set_xlim(0.0, 1.0)
        ax.set_ylim(0.0, 1.0)
        ax.tick_params(labelsize=7)
    ax.set_aspect("equal")
    ax.set_facecolor("#0e1621" if minimap else WATER)

    # Water base of the (possibly rotated) map square.
    ax.add_patch(Rectangle((0, 0), 1, 1, facecolor=WATER, edgecolor="none",
                           zorder=0.5, transform=tr))

    if rs.world_circle:
        square = MplPath([(0, 0), (1, 0), (1, 1), (0, 1), (0, 0)],
                         [MplPath.MOVETO] + [MplPath.LINETO] * 3 + [MplPath.CLOSEPOLY])
        circle = MplPath.circle((0.5, 0.5), WORLD_CIRCLE_R)
        hole = MplPath(circle.vertices[::-1], circle.codes)
        corners = MplPath(list(square.vertices) + list(hole.vertices),
                          list(square.codes) + list(hole.codes))
        patch = PathPatch(corners, facecolor=CIRCLE_DIM, edgecolor="none", alpha=0.55)
        patch.set_transform(tr)
        ax.add_patch(patch)
        c = Circle((0.5, 0.5), WORLD_CIRCLE_R, fill=False,
                   edgecolor="#7d9bbd", linewidth=0.9, linestyle=":")
        c.set_transform(tr)
        ax.add_patch(c)

    # Terrain: budget-growth shapes.
    tg = terrain_grid(rs, cell_tiles=1.0)
    land_areas = {a.name: a for a in rs.land_areas()}
    rgba = np.zeros((tg.nz, tg.nx, 4), dtype=float)
    marker_col = (0.13, 0.27, 0.42, 1.0)
    land_col = (0.435, 0.62, 0.34, 1.0)
    cliff_col = (0.62, 0.55, 0.36, 1.0)
    for j in range(tg.nz):
        row = tg.land[j]
        mrow = tg.marker[j]
        for i in range(tg.nx):
            if row[i]:
                name = tg.land_order[row[i] - 1]
                a = land_areas.get(name)
                rgba[j, i] = cliff_col if (a is not None and a.cliff_type) else land_col
            elif mrow[i]:
                rgba[j, i] = marker_col
    im = ax.imshow(rgba, extent=(0, 1, 0, 1), origin="lower",
                   interpolation="nearest", zorder=1.5)
    im.set_transform(tr)

    labeled: List[tuple] = []
    for area in sorted(rs.land_areas(), key=lambda a: -a.radius_m):
        c = Circle((area.x, area.z), area.radius_m / grid.size_x_m, fill=False,
                   edgecolor="#dfe8d4", linewidth=0.5, linestyle=(0, (2, 3)),
                   alpha=0.5, zorder=2.5)
        c.set_transform(tr)
        ax.add_patch(c)
        if any(abs(area.x - lx) < 0.015 and abs(area.z - lz) < 0.015 for lx, lz in labeled):
            continue
        labeled.append((area.x, area.z))
        ax.annotate(area.name, (area.x, area.z), xytext=(0, -9),
                    textcoords="offset points", fontsize=5.5, ha="center",
                    va="center", color="#1c2b16", alpha=0.9, xycoords=tr)

    # Constraint geometry overlay (drawn when a field entity is selected).
    if constraint_layers:
        fctx = FieldContext(rs)
        pos = ax.get_position()
        pts_per_frac = fig.get_size_inches()[0] * pos.width * 72.0
        shown = []
        for cname, spec in constraint_layers:
            kind = spec.get("kind")
            if kind not in ("terrain", "class_distance", "route_distance", "box", "pie"):
                continue
            shown.append(cname)
            if kind == "terrain":
                d = float(spec["distance_m"])
                inside = spec["avoid"] == "water"
                for a in rs.land_areas():
                    r_m = a.radius_m - d if inside else a.radius_m + d
                    if r_m <= 0:
                        continue
                    c = Circle((a.x, a.z), r_m / grid.size_x_m, fill=False,
                               edgecolor="#1d3d22" if inside else "#8ecae6",
                               linewidth=1.0, linestyle="--", alpha=0.9, zorder=3.3)
                    c.set_transform(tr)
                    ax.add_patch(c)
            elif kind == "class_distance":
                d = float(spec["distance_m"])
                cls = spec["class"].lower()
                for cx, cz, r_m, _ in fctx.class_discs.get(cls, []):
                    c = Circle((grid.x_m_to_frac(cx), grid.z_m_to_frac(cz)),
                               (r_m + d) / grid.size_x_m, fill=False,
                               edgecolor="#e63946", linewidth=1.1,
                               linestyle="--", alpha=0.9, zorder=3.3)
                    c.set_transform(tr)
                    ax.add_patch(c)
                for x0, z0, x1, z1, _ in fctx.class_rects.get(cls, []):
                    rect = Rectangle(
                        (grid.x_m_to_frac(x0 - d), grid.z_m_to_frac(z0 - d)),
                        grid.x_m_to_frac(x1 - x0 + 2 * d), grid.z_m_to_frac(z1 - z0 + 2 * d),
                        fill=False, edgecolor="#e63946", linewidth=1.1,
                        linestyle="--", alpha=0.9, zorder=3.3)
                    rect.set_transform(tr)
                    ax.add_patch(rect)
            elif kind == "route_distance" and fctx.route_m:
                d = float(spec["distance_m"])
                lw = max(1.0, 2.0 * d / grid.size_x_m * pts_per_frac)
                xs = [grid.x_m_to_frac(p[0]) for p in fctx.route_m]
                zs = [grid.z_m_to_frac(p[1]) for p in fctx.route_m]
                ax.plot(xs, zs, color="#e63946", alpha=0.20, linewidth=lw,
                        solid_capstyle="round", zorder=3.2, transform=tr)
            elif kind == "box":
                x0, z0, x1, z1 = spec["box"]
                rect = Rectangle((x0, z0), x1 - x0, z1 - z0, fill=False,
                                 edgecolor="#f2f2f2", linewidth=1.2,
                                 linestyle="--", alpha=0.9, zorder=3.3)
                rect.set_transform(tr)
                ax.add_patch(rect)
            elif kind == "pie":
                from scripts.mapsim.scene import resolve_branch as _rb
                for key in ("r_min", "r_max"):
                    r_m = float(_rb(spec[key], rs.scenario, grid))
                    if r_m > 0:
                        c = Circle((spec["center"][0], spec["center"][1]),
                                   r_m / grid.size_x_m, fill=False,
                                   edgecolor="#f4a261", linewidth=1.0,
                                   linestyle=":", alpha=0.9, zorder=3.3)
                        c.set_transform(tr)
                        ax.add_patch(c)
        if shown:
            ax.text(0.015, 0.985, "constraints: " + ", ".join(shown), fontsize=6,
                    ha="left", va="top", color="#f2b8b5", transform=ax.transAxes)

    if field_points:
        ax.scatter([p[0] for p in field_points], [p[1] for p in field_points],
                   marker="s", s=3.5, color="#ffd166", alpha=0.45,
                   linewidths=0, zorder=3.5, transform=tr)
        if field_label:
            ax.text(0.5, 0.015, f"stipple = feasible region for {field_label}",
                    fontsize=7, ha="center", va="bottom", color="#ffd166",
                    transform=ax.transAxes)

    # Influence segments: growth attractors — drawn explicitly, never silent.
    for area in rs.areas:
        for x1, z1, x2, z2 in area.influence_segments:
            ax.plot([x1, x2], [z1, z2], color="#7fd8e8", linewidth=1.0,
                    linestyle=(0, (1, 2)), alpha=0.9, zorder=2.7, transform=tr)

    # Rivers: painted bands are in the terrain grid; overlay their centerlines.
    for river in rs.rivers:
        wps = river["waypoints"]
        ax.plot([p[0] for p in wps], [p[1] for p in wps], color="#4a7fb5",
                linewidth=1.0, linestyle="-", alpha=0.8, zorder=2.7, transform=tr)

    for wps in rs.all_routes():
        if wps:
            ax.plot([p[0] for p in wps], [p[1] for p in wps],
                    color=ROUTE, linewidth=2.2, linestyle=(0, (6, 2)), zorder=4,
                    transform=tr)
            ax.scatter([p[0] for p in wps], [p[1] for p in wps],
                       s=8, color=ROUTE, zorder=4, transform=tr)

    # Player ring: first matching branch (if / else-if semantics).
    for branch in rs.player_placement.get("branches", []):
        if not _check_when(branch.get("when", {}), rs.scenario):
            continue
        if branch.get("kind") in ("circular", "circular_teams"):
            for r in (branch["min"], branch["max"]):
                c = Circle((0.5, 0.5), r, fill=False, edgecolor=RING,
                           linewidth=0.8, linestyle="--", alpha=0.8)
                c.set_transform(tr)
                ax.add_patch(c)
            sections = []
            if "section" in branch:
                sections = [branch["section"]]
            elif branch.get("variants"):
                sections = list(branch["variants"][0].get("sections", {}).values())
            r_mid = (branch["min"] + branch["max"]) / 2.0
            for s, e in sections:
                arc = Arc((0.5, 0.5), 2 * r_mid, 2 * r_mid,
                          theta1=s * 360.0, theta2=e * 360.0,
                          edgecolor=RING, linewidth=2.6, alpha=0.9)
                arc.set_transform(tr)
                ax.add_patch(arc)
            if sections:
                ax.text(0.5, 0.985, "section arcs assume 0°=+X CCW (uncalibrated, E3)",
                        fontsize=6, ha="center", va="top", color=RING, alpha=0.8,
                        transform=ax.transAxes)
        break

    undrawable = 0
    for p in rs.placements:
        f = verdicts.get(p.name)
        verdict = f.verdict if f else "OK"
        color = VERDICT_COLOR.get(verdict, "#3fae4c")
        if p.kind == "in_area":
            for ref in p.area_refs:
                a = next((a for a in rs.areas if a.name == ref), None)
                if a is not None and a.x is not None:
                    ax.scatter([a.x], [a.z], marker="+", s=40, color=color,
                               linewidths=1.0, zorder=6, alpha=0.8, transform=tr)
            continue
        if p.x is None:
            undrawable += 1
            continue
        marker = KIND_MARKER.get(p.kind, "o")
        hollow = p.approx or verdict == "UNKNOWN_RUNTIME"
        ax.scatter([p.x], [p.z], marker=marker, s=46, zorder=7,
                   facecolors="none" if hollow else color,
                   edgecolors=color, linewidths=1.4, transform=tr)
        if verdict not in ("OK", "INACTIVE", "UNKNOWN_RUNTIME") or p.name in LABEL_ALWAYS:
            ax.annotate(p.name, (p.x, p.z), xytext=(0, 5),
                        textcoords="offset points", fontsize=5.5,
                        ha="center", color="#f2f2f2", zorder=8, xycoords=tr)

    bar = grid.x_m_to_frac(100.0)
    ax.plot([0.03, 0.03 + bar], [0.035, 0.035], color="#f2f2f2", linewidth=2,
            transform=ax.transAxes)
    ax.text(0.03 + bar / 2, 0.045, "100 m", fontsize=7, ha="center",
            color="#f2f2f2", transform=ax.transAxes)

    # Minimap view: hard circular mask — everything beyond the world circle
    # is stripped, matching the round in-game minimap.
    if minimap:
        big = MplPath([(-1, -1), (2, -1), (2, 2), (-1, 2), (-1, -1)],
                      [MplPath.MOVETO] + [MplPath.LINETO] * 3 + [MplPath.CLOSEPOLY])
        circ = MplPath.circle((0.5, 0.5), WORLD_CIRCLE_R)
        hole = MplPath(circ.vertices[::-1], circ.codes)
        mask = PathPatch(MplPath(list(big.vertices) + list(hole.vertices),
                                 list(big.codes) + list(hole.codes)),
                         facecolor="#0e1621", edgecolor="none", zorder=8.5)
        mask.set_transform(tr)
        ax.add_patch(mask)
        ring = Circle((0.5, 0.5), WORLD_CIRCLE_R, fill=False,
                      edgecolor="#5d788f", linewidth=1.6, zorder=8.6)
        ring.set_transform(tr)
        ax.add_patch(ring)

    handles = [
        Line2D([], [], marker="o", linestyle="", color=VERDICT_COLOR["OK"], label="OK"),
        Line2D([], [], marker="o", linestyle="", color=VERDICT_COLOR["EDGE_RISK"], label="warning"),
        Line2D([], [], marker="o", linestyle="", color=VERDICT_COLOR["OFF_MAP"], label="error"),
        Line2D([], [], marker="o", linestyle="", markerfacecolor="none",
               color="#9aa0a6", label="runtime / approx"),
        Line2D([], [], color=ROUTE, linestyle="--", label="trade route"),
        Line2D([], [], color=RING, linestyle="--", label="player ring"),
    ]
    if constraint_layers:
        handles += [
            Line2D([], [], color="#e63946", linestyle="--", label="keep-out margin"),
            Line2D([], [], color="#1d3d22", linestyle="--", label="must stay inside"),
            Line2D([], [], color="#f2f2f2", linestyle="--", label="confinement box"),
        ]
    legend = ax.legend(handles=handles, loc="lower right", fontsize=6.5, framealpha=0.85)
    legend.set_zorder(10)

    sc = rs.scenario
    tag = f"P{sc.players} T{sc.teams}" + (" KOTH" if sc.koth else "") + (" nomad" if sc.nomad else "")
    note = f" | {undrawable} runtime placements not drawable" if undrawable else ""
    view = " | minimap view (+45°, Elbe-calibrated)" if minimap else ""
    ax.set_title((title or "map preview") + f" — {tag} — {grid.size_x_m:.0f} m{note}{view}",
                 fontsize=10)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_path, bbox_inches="tight", facecolor="#0e1621")
    plt.close(fig)
    return out_path
