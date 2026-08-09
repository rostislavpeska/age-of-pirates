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

# Layer-2 Terrain Standard palette (plan_mapsim_architecture.md B3): four
# classes, one swatch each — the legend IS the standard. No paint tints, no
# rock fills (Layer-3 "for show" backlog).
WATER = "#16324f"          # DEEP: depth > SHALLOW_BUILD_DEPTH_M
SHALLOW = "#3a6ea5"        # SHALLOW: 0 < depth <= 1.0 — walkable AND buildable
CIRCLE_DIM = "#0b1c30"
ROUTE = "#e8d9a0"
RING = "#e0e6ee"
LAND = "#6f9e57"           # buildable ground incl. cliff interiors
CLIFF_EDGE = "#7a5230"     # the impassable rim band (spawn killer)

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


def terrain_rgba(tg, cliff_band_cells: bool = False):
    """Layer-2 Terrain Standard classification (4 classes) for a TerrainGrid.
    Pure lookup — shared by the full preview and the --layers debugger.

    By default CLIFF band cells paint as their UNDERLYING wet/dry class and
    cliffs are drawn as a separate uniform-weight outline (draw_cliff_outline)
    — the band's physical width (side run = height) stays in the MODEL for
    the checks, but on screen every cliff gets the same line thickness (user
    directive 2026-08-09). Pass cliff_band_cells=True to paint the raw band."""
    import numpy as np
    from matplotlib.colors import to_rgba

    rgba = np.zeros((tg.nz, tg.nx, 4), dtype=float)
    cols = [to_rgba(LAND), to_rgba(SHALLOW), to_rgba(WATER), to_rgba(CLIFF_EDGE)]
    for j in range(tg.nz):
        for i in range(tg.nx):
            code = tg.class_code(i, j)
            if code == 3 and not cliff_band_cells:
                # underlying class beneath the band
                if tg.water[j][i]:
                    code = 1 if (tg.wwalk and tg.wwalk[j][i]) else 2
                else:
                    code = 0
            rgba[j, i] = cols[code]
    return rgba


def draw_cliff_outline(ax, tg, tr, raised_names=None, linewidth: float = 1.6,
                       zorder: float = 1.6) -> None:
    """One closed CLIFF_EDGE contour per RAISED cliff shape, uniform
    linewidth on every map and cliff size.

    Only areas with a raised cliff (cliff_raised) are impassable walls and
    get an outline. cliffHeight-0 cliff areas are PAINTED shore ledges —
    crownlands'/elbe's "Italian Cliff River"/"ZP Elbe Cliff" shoreLines
    and bridge docks — passable texture, not walls (the same discriminator
    cliff_band already uses; their crescent claims drew as half-moons and
    river-long bank outlines before, 2026-08-09). Their paint belongs to
    the Layer-3 backlog. raised_names=None keeps every cliff (debug use).
    The impassable band remains model truth (class_code / digest
    untouched)."""
    import numpy as np
    if not tg.cliff:
        return

    def keep(idx: int) -> bool:
        if idx == 0:
            return False
        return (raised_names is None
                or tg.cliff_order[idx - 1] in raised_names)

    mask = np.array([[1.0 if keep(tg.cliff[j][i]) else 0.0
                      for i in range(tg.nx)] for j in range(tg.nz)])
    if not mask.any():
        return
    xs = (np.arange(tg.nx) + 0.5) / tg.nx
    zs = (np.arange(tg.nz) + 0.5) / tg.nz
    cs = ax.contour(xs, zs, mask, levels=[0.5], colors=[CLIFF_EDGE],
                    linewidths=linewidth, zorder=zorder)
    cs.set_transform(tr)


def _raised_cliff_names(rs) -> set:
    return {a.name for a in rs.areas
            if a.cliff_type is not None and a.cliff_raised()}


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
    # Rectangular maps (Paris is 653x360): the scene is authored in fraction
    # space; a scale transform stretches it to the true meter aspect so the
    # rotated minimap shows the real rhombus, not a square.
    aspect = grid.size_z_m / grid.size_x_m
    sc = Affine2D().scale(1.0, aspect)
    # World circle in DISPLAY coords: a true circle whose diameter is the
    # map's LONGER side (Paris minimap ground truth — the 653x360 rectangle
    # is cut by a circle as wide as the long side). Center is rotation-
    # invariant, so the same geometry serves both views.
    center_d = (0.5, 0.5 * aspect)
    circ_r_d = WORLD_CIRCLE_R * max(1.0, aspect)
    if minimap:
        # +45 deg calibrated against elbe_mini.png: the pirate island at
        # fraction (0.5, 0.95) sits top-LEFT in the in-game minimap.
        rot = Affine2D().rotate_deg_around(0.5, 0.5 * aspect, 45)
        disp = sc + rot
        tr = disp + ax.transData
    else:
        disp = sc
        tr = sc + ax.transData
        ax.tick_params(labelsize=7)
    rect_pts = disp.transform([(0, 0), (1, 0), (1, 1), (0, 1), (0, 0)])
    x_lo = min(rect_pts[:, 0].min(), center_d[0] - circ_r_d) - 0.02
    x_hi = max(rect_pts[:, 0].max(), center_d[0] + circ_r_d) + 0.02
    z_lo = min(rect_pts[:, 1].min(), center_d[1] - circ_r_d) - 0.02
    z_hi = max(rect_pts[:, 1].max(), center_d[1] + circ_r_d) + 0.02
    ax.set_xlim(x_lo, x_hi)
    ax.set_ylim(z_lo, z_hi)
    if minimap:
        ax.set_xticks([])
        ax.set_yticks([])
    ax.set_aspect("equal")
    ax.set_facecolor("#0e1621" if minimap else WATER)

    from matplotlib.patches import Ellipse

    def meter_circle(cx, cz, r_m, **kw):
        """A circle of r_m METERS at fraction (cx, cz) — an ellipse in
        fraction space so it stays round on rectangular maps."""
        e = Ellipse((cx, cz), 2.0 * r_m / grid.size_x_m,
                    2.0 * r_m / grid.size_z_m, **kw)
        e.set_transform(tr)
        ax.add_patch(e)
        return e

    # Base terrain of the (possibly rotated) map square, from
    # rmTerrainInitialize: flooded base -> water, texture base -> land.
    base_col = WATER if rs.base_is_water else LAND
    ax.add_patch(Rectangle((0, 0), 1, 1, facecolor=base_col, edgecolor="none",
                           zorder=0.5, transform=tr))

    if rs.world_circle:
        # Dim the map beyond the world circle (display-space geometry: the
        # transformed map rectangle minus the true circle).
        rect_path = MplPath(rect_pts,
                            [MplPath.MOVETO] + [MplPath.LINETO] * 3 + [MplPath.CLOSEPOLY])
        circle = MplPath.circle(center_d, circ_r_d)
        hole = MplPath(circle.vertices[::-1], circle.codes)
        corners = MplPath(list(rect_path.vertices) + list(hole.vertices),
                          list(rect_path.codes) + list(hole.codes))
        ax.add_patch(PathPatch(corners, facecolor=CIRCLE_DIM, edgecolor="none",
                               alpha=0.55, zorder=2.0))
        ax.add_patch(Circle(center_d, circ_r_d, fill=False,
                            edgecolor="#7d9bbd", linewidth=0.9, linestyle=":",
                            zorder=2.1))

    # Terrain: budget-growth shapes over the initialized base, classified
    # per water body / cliff kind (see terrain_rgba).
    tg = terrain_grid(rs, cell_tiles=1.0)
    rgba = terrain_rgba(tg)
    im = ax.imshow(rgba, extent=(0, 1, 0, 1), origin="lower",
                   interpolation="nearest", zorder=1.5)
    im.set_transform(tr)
    draw_cliff_outline(ax, tg, tr, raised_names=_raised_cliff_names(rs))

    labeled: List[tuple] = []
    located = [a for a in rs.areas if a.x is not None]
    for area in sorted(located, key=lambda a: -a.radius_m):
        outline = True
        if area.water_type is not None:
            ec, ls, label_col = "#9cc4e4", (0, (2, 3)), "#dbe9f7"
        elif area.is_invisible():
            ec, ls, label_col = "#8f9aa8", (0, (1, 3)), "#aab4c0"
        elif (area.base_height is not None
              and area.base_height <= rs.sea_level):  # submerged ground / reef
            ec, ls, label_col = "#6fa8c9", (0, (2, 3)), "#9fc4da"
        else:
            # Painted land: its grown shape IS the information — an authored
            # disc on top is clutter. Outline only nominal (approx) anchors.
            ec, ls, label_col = "#dfe8d4", (0, (2, 3)), "#1c2b16"
            outline = area.approx
        if outline:
            meter_circle(area.x, area.z, area.radius_m, fill=False,
                         edgecolor=ec, linewidth=0.5, linestyle=ls,
                         alpha=0.5, zorder=2.5)
        if any(abs(area.x - lx) < 0.015 and abs(area.z - lz) < 0.015 for lx, lz in labeled):
            continue
        labeled.append((area.x, area.z))
        name = ("~" + area.name) if area.approx else area.name
        ax.annotate(name, (area.x, area.z), xytext=(0, -9),
                    textcoords="offset points", fontsize=5.5, ha="center",
                    va="center", color=label_col, alpha=0.9, xycoords=tr)

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
                    meter_circle(a.x, a.z, r_m, fill=False,
                                 edgecolor="#1d3d22" if inside else "#8ecae6",
                                 linewidth=1.0, linestyle="--", alpha=0.9, zorder=3.3)
            elif kind == "class_distance":
                d = float(spec["distance_m"])
                cls = spec["class"].lower()
                for cx, cz, r_m, _ in fctx.class_discs.get(cls, []):
                    meter_circle(grid.x_m_to_frac(cx), grid.z_m_to_frac(cz),
                                 r_m + d, fill=False,
                                 edgecolor="#e63946", linewidth=1.1,
                                 linestyle="--", alpha=0.9, zorder=3.3)
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
                        meter_circle(spec["center"][0], spec["center"][1], r_m,
                                     fill=False, edgecolor="#f4a261",
                                     linewidth=1.0, linestyle=":", alpha=0.9,
                                     zorder=3.3)
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

    # Influence segments: growth attractors — drawn explicitly, never
    # silent. Anchor-connected segments seed growth (cyan); segments
    # DISCONNECTED from the anchor are dead weight the engine ignores
    # (E7) — drawn red so stale map authoring is visible at a glance.
    from scripts.mapsim.field import connected_influence_segments
    for area in rs.areas:
        if area.x is None:
            continue
        live = set(connected_influence_segments(area, rs.grid))
        for seg in area.influence_segments:
            x1, z1, x2, z2 = seg
            dead = tuple(seg) not in {tuple(s) for s in live}
            ax.plot([x1, x2], [z1, z2],
                    color="#e86a5f" if dead else "#7fd8e8", linewidth=1.0,
                    linestyle=(0, (1, 2)), alpha=0.9, zorder=2.7,
                    transform=tr)

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
                           linewidth=0.8, linestyle="--", alpha=0.8, zorder=3.4)
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
                          edgecolor=RING, linewidth=2.6, alpha=0.9, zorder=3.4)
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

    x0_, x1_ = ax.get_xlim()
    bar = grid.x_m_to_frac(100.0) / (x1_ - x0_)   # 100 m in axes fraction
    ax.plot([0.03, 0.03 + bar], [0.035, 0.035], color="#f2f2f2", linewidth=2,
            transform=ax.transAxes)
    ax.text(0.03 + bar / 2, 0.045, "100 m", fontsize=7, ha="center",
            color="#f2f2f2", transform=ax.transAxes)

    # Minimap view: hard circular crop at the world circle (true circle,
    # diameter = the longer side) — the rotated square diamond overflows it
    # like in-game; a rectangle keeps its short sides inside and only the
    # long-side corners get cut, matching the Paris minimap.
    if minimap:
        big = MplPath([(-2, -2), (3, -2), (3, 3), (-2, 3), (-2, -2)],
                      [MplPath.MOVETO] + [MplPath.LINETO] * 3 + [MplPath.CLOSEPOLY])
        circ = MplPath.circle(center_d, circ_r_d)
        hole = MplPath(circ.vertices[::-1], circ.codes)
        ax.add_patch(PathPatch(MplPath(list(big.vertices) + list(hole.vertices),
                                       list(big.codes) + list(hole.codes)),
                               facecolor="#0e1621", edgecolor="none", zorder=8.5))
        ax.add_patch(Circle(center_d, circ_r_d, fill=False,
                            edgecolor="#5d788f", linewidth=1.6, zorder=8.6))

    handles = [
        Line2D([], [], marker="s", linestyle="", color=LAND, label="land (buildable)"),
        Line2D([], [], marker="s", linestyle="", color=SHALLOW, label="shallow (walkable+buildable)"),
        Line2D([], [], marker="s", linestyle="", color=WATER, label="deep water"),
        Line2D([], [], linestyle="-", linewidth=1.6, color=CLIFF_EDGE,
               label="cliff outline (impassable rim)"),
        Line2D([], [], color="#8f9aa8", linestyle=":", label="invisible mask"),
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


def render_layers(rs, out_dir: Path, title: str = "map",
                  minimap: bool = True) -> List[dict]:
    """Layering debugger: one PNG per BUILD STEP (river / causeway / area,
    in script order), each showing the terrain state right after that step
    with the step's newly claimed cells highlighted. Returns step metadata
    (index, name, line, category, cells, png path) for report/page builders.
    """
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np
    from matplotlib.transforms import Affine2D

    from scripts.mapsim.field import terrain_grid

    grid = rs.grid
    aspect = grid.size_z_m / grid.size_x_m
    center_d = (0.5, 0.5 * aspect)
    sc = Affine2D().scale(1.0, aspect)
    if minimap:
        rot = Affine2D().rotate_deg_around(0.5, 0.5 * aspect, 45)
        disp = sc + rot
    else:
        disp = sc
    rect_pts = disp.transform([(0, 0), (1, 0), (1, 1), (0, 1), (0, 0)])

    steps: List[dict] = []
    terrain_grid(rs, on_step=steps.append)

    out_dir.mkdir(parents=True, exist_ok=True)
    routes = rs.all_routes()
    metas: List[dict] = []
    for idx, st in enumerate(steps, 1):
        tg = st["snapshot"]
        fig, ax = plt.subplots(figsize=(5.4, 5.4), dpi=140)
        tr = disp + ax.transData
        ax.set_xlim(rect_pts[:, 0].min() - 0.02, rect_pts[:, 0].max() + 0.02)
        ax.set_ylim(rect_pts[:, 1].min() - 0.02, rect_pts[:, 1].max() + 0.02)
        ax.set_xticks([])
        ax.set_yticks([])
        ax.set_aspect("equal")
        ax.set_facecolor("#0e1621")
        im = ax.imshow(terrain_rgba(tg), extent=(0, 1, 0, 1), origin="lower",
                       interpolation="nearest", zorder=1.5)
        im.set_transform(tr)
        draw_cliff_outline(ax, tg, tr,
                           raised_names=_raised_cliff_names(rs),
                           linewidth=1.2)
        # Highlight this step's freshly claimed cells.
        if st["cells"]:
            hi = np.zeros((tg.nz, tg.nx, 4), dtype=float)
            for i, j in st["cells"]:
                hi[j, i] = (1.0, 1.0, 1.0, 0.38)
            him = ax.imshow(hi, extent=(0, 1, 0, 1), origin="lower",
                            interpolation="nearest", zorder=2.2)
            him.set_transform(tr)
        for wps in routes:
            if wps:
                ax.plot([p[0] for p in wps], [p[1] for p in wps], color=ROUTE,
                        linewidth=1.0, linestyle=(0, (5, 3)), alpha=0.55,
                        zorder=3, transform=tr)
        n = len(st["cells"])
        warn = "  !! 0 cells" if n == 0 else ""
        ax.set_title(f"{idx:02d} · {st['name']}  [{st['category']}]\n"
                     f"line {st['line']} · {n} cells{warn}",
                     fontsize=8, color="#dce4ef")
        safe = "".join(c if c.isalnum() else "_" for c in st["name"])[:32]
        path = out_dir / f"layer_{idx:02d}_{safe}.png"
        fig.savefig(path, bbox_inches="tight", facecolor="#0e1621")
        plt.close(fig)
        metas.append({"index": idx, "name": st["name"], "line": st["line"],
                      "category": st["category"], "cells": n,
                      "png": str(path)})
    return metas
