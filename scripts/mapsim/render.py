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
from typing import Any, Dict, List, Optional

from scripts.mapsim.checks import Finding
from scripts.mapsim.geometry import WORLD_CIRCLE_R
from scripts.mapsim.scene import ResolvedScene, _check_when, height_floods

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

# Per-placement verdict dots are DISABLED (user 2026-08-10: "get rid of
# the green and red dots — we'll use it later but semantically, not
# randomly"). The verdict engine still runs (findings/reports keep them);
# only the scatter markers are gated. Flip to re-enable.
DRAW_VERDICT_MARKERS = False

# Forensic overlay (env MAPSIM_DEBUG_ANCHORS=1): a magenta '+' at every
# grouping ANCHOR, through the same view transform as the boxes — one
# look separates "extraction coordinate wrong" from "box drawn wrong".
import os as _os
DEBUG_ANCHOR_CROSSES = _os.environ.get("MAPSIM_DEBUG_ANCHORS") == "1"

# The game's eight player colors (lobby order — user screenshot
# 2026-08-10): blue, red, yellow, purple, green, cyan, orange, pink.
# Player-owned groupings/objects tint with these at 50% alpha; gaia
# (player 0 / no player) stays neutral dark.
PLAYER_COLORS = {
    1: "#2035e0", 2: "#e02020", 3: "#e8d020", 4: "#8020a0",
    5: "#20a040", 6: "#20c8d8", 7: "#e88820", 8: "#e060b0",
}


def team_color(team: int) -> str:
    """A team's marker colour: the lobby colour of the team's index (team 0 blue, 1 red, 2 yellow ...)."""
    return PLAYER_COLORS[team % 8 + 1]


def section_arc_degrees(s0: float, s1: float):
    """matplotlib Arc angles (theta1, theta2; degrees counter-clockwise from +x) of an rmSetPlacementSection(s0, s1)
    in the pinned engine convention (xs_extract.ring_positions, 2026-08-10): section fraction s sits at 90 - 360 s
    degrees - 0 = north, clockwise - and an end not past its start wraps, as there. The arc therefore runs
    through the numbered player starts. (Drawn before 2026-09-25 as 0 = +x counter-clockwise, labelled
    uncalibrated.)"""
    if s1 <= s0:
        s1 += 1.0
    return 90.0 - s1 * 360.0, 90.0 - s0 * 360.0


def _text_on(color: str) -> str:
    """Black on the light lobby colours (yellow, cyan, orange, pink), white on the dark ones."""
    r, g, b = (int(color[k:k + 2], 16) for k in (1, 3, 5))
    return "#000000" if 0.299 * r + 0.587 * g + 0.114 * b > 140 else "#ffffff"


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


def draw_cliff_outline(ax, tg, tr, linewidth: float = 1.6,
                       zorder: float = 2.8) -> None:
    """One uniform-weight border per cliff area, around its BUILD-TIME
    GROWN CLAIM (TerrainGrid.cliff_claims): the shape the growth model
    produced under the area's own constraints and influence segments —
    and NOTHING later. The user diagnosis that settled this design
    (2026-08-09): "the code was not that bad, the problem was overriding
    cliffs with other land areas on top." Later builds may repaint the
    ground (and the class grid tells that truth) but the cliff border
    never erodes into leftover crescents again. Matches the engine bug
    where placement blocking follows the cliff footprint even after
    ramps/terrain replace it."""
    import numpy as np
    if not getattr(tg, "cliff_claims", None):
        return
    xs = (np.arange(tg.nx) + 0.5) / tg.nx
    zs = (np.arange(tg.nz) + 0.5) / tg.nz
    for _name, cells in tg.cliff_claims:
        if not cells:
            continue
        mask = np.zeros((tg.nz, tg.nx))
        for i, j in cells:
            mask[j][i] = 1.0
        cs = ax.contour(xs, zs, mask, levels=[0.5], colors=[CLIFF_EDGE],
                        linewidths=linewidth, zorder=zorder)
        cs.set_transform(tr)


def random_choice_note(rs) -> str:
    """One line naming the random layout choices mapsim drew at their low roll (xs_extract.random_choices)."""
    choices = sorted(getattr(rs, "random_choices", {}).items())
    if not choices:
        return ""
    ln, (cond, took) = choices[0]
    more = f" (+{len(choices) - 1} more)" if len(choices) > 1 else ""
    return (f"random layout choices drawn at their low roll - the game may roll otherwise: line {ln} "
            f"{cond.replace('?', '')} -> {'yes' if took else 'no'}{more}")


def map_frame(ax, size_x_m: float, size_z_m: float, minimap: bool):
    """The ONE frame geometry of every map view (preview, minimap preview, comparison panels): fraction space scaled
    to the true metre aspect, turned +45 deg for the minimap view. Returns (tr, disp, center_d, circ_r_d, rect_pts);
    `tr` maps map fractions to the axis."""
    from matplotlib.transforms import Affine2D
    # Rectangular maps (Paris is 653x360): the scene is authored in fraction
    # space; a scale transform stretches it to the true meter aspect so the
    # rotated minimap shows the real rhombus, not a square.
    aspect = size_z_m / size_x_m
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
        disp = sc + Affine2D().rotate_deg_around(0.5, 0.5 * aspect, 45)
    else:
        disp = sc
        ax.tick_params(labelsize=7)
    tr = disp + ax.transData
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
    return tr, disp, center_d, circ_r_d, rect_pts


def crop_to_circle(ax, center_d, circ_r_d) -> None:
    """Minimap view: hard circular crop at the world circle (true circle,
    diameter = the longer side) — the rotated square diamond overflows it
    like in-game; a rectangle keeps its short sides inside and only the
    long-side corners get cut, matching the Paris minimap."""
    from matplotlib.patches import Circle, PathPatch
    from matplotlib.path import Path as MplPath
    big = MplPath([(-2, -2), (3, -2), (3, 3), (-2, 3), (-2, -2)],
                  [MplPath.MOVETO] + [MplPath.LINETO] * 3 + [MplPath.CLOSEPOLY])
    circ = MplPath.circle(center_d, circ_r_d)
    hole = MplPath(circ.vertices[::-1], circ.codes)
    ax.add_patch(PathPatch(MplPath(list(big.vertices) + list(hole.vertices),
                                   list(big.codes) + list(hole.codes)),
                           facecolor="#0e1621", edgecolor="none", zorder=8.5))
    ax.add_patch(Circle(center_d, circ_r_d, fill=False,
                        edgecolor="#5d788f", linewidth=1.6, zorder=8.6))


def draw_start(ax, tr, x: float, z: float, label, team: Optional[int], player_colour: Optional[str] = None) -> None:
    """A player start, the same symbol in every view: a disc in the player's colour, a ring in the team colour, the
    number on it (mapsim: the lobby slot; game panel: the owner id of the Town Center)."""
    try:
        n = int(label)
    except (TypeError, ValueError):
        n = 0
    fill = player_colour or PLAYER_COLORS.get(n, "#9aa0a6")
    ring = team_color(team) if team is not None else "#ffffff"
    ax.scatter([x], [z], marker="o", s=130, color=fill, edgecolors=ring, linewidths=2.2,
               zorder=9.3, transform=tr)
    ax.annotate(str(label), (x, z), xycoords=tr, ha="center", va="center", fontsize=6.5, fontweight="bold",
                color=_text_on(fill), zorder=9.4)


# Game objects drawn on the game panel of render_compare: proto -> (marker, colour, size, legend text).
GAME_OBJECT_STYLE = {
    "sockettraderoute": ("D", ROUTE, 28, "trade route socket (game)"),
    "socket": ("D", "#c9a0dc", 22, "native socket (game)"),
    "ypkingshill": ("*", "#ffd21f", 260, "King of the Hill hill"),
}


def _game_style(proto: str):
    low = proto.lower()
    if low in GAME_OBJECT_STYLE:
        return GAME_OBJECT_STYLE[low]
    if low.startswith("socket") and low != "sockettraderoute":
        return GAME_OBJECT_STYLE["socket"]
    return None


def render_compare(rs: ResolvedScene, findings: List[Finding], game, out_path: Path,
                   title: Optional[str] = None, minimap_png: Optional[Path] = None, tg=None) -> Dict[str, Any]:
    """mapsim next to the game, every panel drawn with the SAME codes (terrain classes, cliff border, trade routes,
    groupings, player starts, KotH) in the same frame (the minimap view):
      GAME minimap (the captured crop, when given) | GAME map (the save: terrain, cliff border, Town Centers,
      sockets, KotH hill) | MAPSIM (the full preview) | ERRORS (grey = same; red = real land or shallows that mapsim
      draws as deep water; blue = real deep water that mapsim draws as land or shallows).
    `game` is a groundtruth.GameMap. Returns the stats written into the title."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np
    from matplotlib.lines import Line2D
    from matplotlib.patches import Rectangle

    from scripts.mapsim.field import terrain_grid
    from scripts.mapsim.scene import team_of

    if tg is None:
        tg = terrain_grid(rs, cell_tiles=1.0)
    gg = game.grid
    ncol = 4 if minimap_png else 3
    fig, axes = plt.subplots(1, ncol, figsize=(7.2 * ncol, 8.2), dpi=150)
    axes = list(axes)
    if minimap_png:
        from PIL import Image
        axes[0].imshow(Image.open(minimap_png).convert("RGB"))
        axes[0].set_xticks([])
        axes[0].set_yticks([])
        axes[0].set_title("GAME minimap (live editor capture)", fontsize=10, color="#f2f2f2")
        axes = axes[1:]
    ax_g, ax_m, ax_e = axes

    # GAME panel: the save's terrain with the preview's codes.
    tr, _disp, center_d, circ_r_d, _rect = map_frame(ax_g, game.size_x_m, game.size_z_m, True)
    ax_g.set_facecolor("#0e1621")
    im = ax_g.imshow(terrain_rgba(gg), extent=(0, 1, 0, 1), origin="lower", interpolation="nearest", zorder=1.5)
    im.set_transform(tr)
    draw_cliff_outline(ax_g, gg, tr)
    seen_styles = {}
    # Buildings (what groupings put down) in the grouping-footprint code of the preview: a 50% dark square with a
    # light edge, player-owned ones in the player colour.
    from scripts.refdata.catalogs import proto_counts_as
    for u in game.units:
        proto = str(u["proto"])
        if u.get("fx") is None or proto == "TownCenter" or _game_style(proto) is not None:
            continue
        if not proto_counts_as(proto, "LogicalTypeBuildingsNotWalls"):
            continue
        face = PLAYER_COLORS.get(u.get("player") or 0, "#000000")
        ax_g.scatter([u["fx"]], [u["fz"]], marker="s", s=14, color=face, alpha=0.6, edgecolors="#e8e0d0",
                     linewidths=0.4, zorder=5.5, transform=tr)
        seen_styles["building (game) - grouping footprint code"] = ("s", "#000000")
    for u in game.units:
        st = _game_style(str(u["proto"]))
        if st is None or u.get("fx") is None:
            continue
        marker, col, size, label = st
        ax_g.scatter([u["fx"]], [u["fz"]], marker=marker, s=size, color=col, edgecolors="#000000", linewidths=0.6,
                     zorder=9, transform=tr)
        seen_styles[label] = (marker, col)
    n_players, n_teams = rs.scenario.players, rs.scenario.teams
    for u in game.town_centers():
        p = u.get("player") or 0
        team = team_of(p, n_players, n_teams) if 1 <= p <= n_players else None
        draw_start(ax_g, tr, u["fx"], u["fz"], p, team)
    crop_to_circle(ax_g, center_d, circ_r_d)
    ax_g.set_title("GAME map (from the save: terrain, cliffs, buildings, Town Centers, sockets;\n"
                   "the save holds trade route sockets, not the route line)", fontsize=10, color="#f2f2f2")

    # MAPSIM panel: the preview itself.
    handles = render(rs, findings, out_path, minimap=True, tg=tg, ax=ax_m) or []
    ax_m.set_title("MAPSIM", fontsize=10, color="#f2f2f2")

    # ERRORS panel: the game grid against mapsim's, per game tile.
    tr_e, _d, c_e, r_e, _r = map_frame(ax_e, game.size_x_m, game.size_z_m, True)
    ax_e.set_facecolor("#0e1621")
    err = np.zeros((gg.nz, gg.nx, 4))
    n = same = red = blue = 0
    R = 0.5 * 0.98
    for j in range(gg.nz):
        fz = (j + 0.5) / gg.nz
        for i in range(gg.nx):
            fx = (i + 0.5) / gg.nx
            if (fx - 0.5) ** 2 + (fz - 0.5) ** 2 > R * R:
                continue
            ci = min(tg.nx - 1, int(fx * tg.nx))
            cj = min(tg.nz - 1, int(fz * tg.nz))
            m_deep = bool(tg.water[cj][ci]) and not bool(tg.wwalk[cj][ci])
            g_deep = gg.is_deep(i, j)
            n += 1
            if m_deep == g_deep:
                same += 1
                err[j, i] = (0.28, 0.28, 0.28, 1.0) if g_deep else (0.6, 0.6, 0.6, 1.0)
            elif m_deep:
                red += 1
                err[j, i] = (0.92, 0.16, 0.16, 1.0)
            else:
                blue += 1
                err[j, i] = (0.16, 0.47, 1.0, 1.0)
    im = ax_e.imshow(err, extent=(0, 1, 0, 1), origin="lower", interpolation="nearest", zorder=1.5)
    im.set_transform(tr_e)
    draw_cliff_outline(ax_e, tg, tr_e)
    crop_to_circle(ax_e, c_e, r_e)
    ax_e.set_title("ERRORS: red = real land/shallows drawn as deep water, blue = the reverse", fontsize=10, color="#f2f2f2")

    stats = {"tiles": n, "match": same / n if n else 0.0, "red": red / n if n else 0.0, "blue": blue / n if n else 0.0,
             "tcs": len(game.town_centers()),
             "tcs_on_mapsim_land": sum(1 for u in game.town_centers() if tg.is_land_frac(u["fx"], u["fz"]))}
    sc = rs.scenario
    tag = f"P{sc.players} T{sc.teams}" + (" KOTH" if sc.koth else "")
    fig.suptitle(f"{title or 'map'} — {tag} — mapsim vs the game: terrain match {100 * stats['match']:.1f}%, "
                 f"red {100 * stats['red']:.1f}%, blue {100 * stats['blue']:.1f}%, "
                 f"Town Centers on mapsim land {stats['tcs_on_mapsim_land']}/{stats['tcs']}"
                 + ("\n" + random_choice_note(rs) if random_choice_note(rs) else ""), fontsize=12,
                 color="#f2f2f2")
    handles = list(handles) + [Line2D([], [], marker=m, linestyle="", color=c, markeredgecolor="#000000",
                                      markersize=7, label=lab) for lab, (m, c) in seen_styles.items()]
    handles.append(Line2D([], [], marker="o", linestyle="", color=PLAYER_COLORS[1], markeredgecolor="#ffffff",
                          markersize=7, label="game Town Center: number = its owner, ring = team"))
    fig.legend(handles=handles, loc="lower center", ncol=4, fontsize=7, framealpha=0.9)
    fig.subplots_adjust(bottom=0.2, top=0.9, wspace=0.03)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_path, facecolor="#0e1621")
    plt.close(fig)
    return stats


def render(rs: ResolvedScene, findings: List[Finding], out_path: Path,
           title: Optional[str] = None,
           field_points: Optional[List] = None,
           field_label: Optional[str] = None,
           constraint_layers: Optional[List] = None,
           minimap: bool = False, tg=None, ax=None):
    """tg: the built TerrainGrid when the caller already has it (sim.run_scenario shares textmap.display_grid
    with the text map); computed here otherwise. ax: draw into this axis (render_compare's mapsim panel) and return
    the legend handles instead of saving a file."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np
    from matplotlib.lines import Line2D
    from matplotlib.patches import Arc, Circle, PathPatch, Rectangle
    from matplotlib.path import Path as MplPath
    from matplotlib.transforms import Affine2D

    from scripts.mapsim.field import FieldContext, terrain_grid
    from scripts.mapsim.gsolve import ensure_solved
    ensure_solved(rs)

    grid = rs.grid
    verdicts: Dict[str, Finding] = {f.name: f for f in findings if f.scope == "placement"}

    own_figure = ax is None
    if own_figure:
        fig, ax = plt.subplots(figsize=(10, 10), dpi=200)
    else:
        fig = ax.figure
    tr, disp, center_d, circ_r_d, rect_pts = map_frame(ax, grid.size_x_m, grid.size_z_m, minimap)
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
    if tg is None:
        tg = terrain_grid(rs, cell_tiles=1.0)
    rgba = terrain_rgba(tg)
    im = ax.imshow(rgba, extent=(0, 1, 0, 1), origin="lower",
                   interpolation="nearest", zorder=1.5)
    im.set_transform(tr)
    draw_cliff_outline(ax, tg, tr)

    labeled: List[tuple] = []
    located = [a for a in rs.areas if a.x is not None]
    for area in sorted(located, key=lambda a: -a.radius_m):
        outline = True
        if area.water_type is not None:
            ec, ls, label_col = "#9cc4e4", (0, (2, 3)), "#dbe9f7"
        elif area.is_invisible():
            ec, ls, label_col = "#8f9aa8", (0, (1, 3)), "#aab4c0"
        elif height_floods(rs.base_is_water, rs.sea_level, area.base_height,
                           None):  # submerged ground / reef
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
            if branch.get("section"):     # None when no rmSetPlacementSection
                sections = [branch["section"]]
            elif branch.get("variants"):
                sections = list(branch["variants"][0].get("sections", {}).values())
            r_mid = (branch["min"] + branch["max"]) / 2.0
            for s, e in sections:
                try:
                    theta1, theta2 = section_arc_degrees(float(s), float(e))
                except (TypeError, ValueError):
                    continue
                arc = Arc((0.5, 0.5), 2 * r_mid, 2 * r_mid, theta1=theta1, theta2=theta2,
                          edgecolor=RING, linewidth=2.6, alpha=0.9, zorder=3.4)
                arc.set_transform(tr)
                ax.add_patch(arc)
        break

    # Player starts (owner 2026-09-25: "add players"): the NOMINAL start of every player (ResolvedScene.player_locs)
    # as a small numbered disc in its TEAM colour - the game's lobby colour of the team's index, so an FFA shows
    # each player in its own lobby colour. A Town Center placement that does not stand on its start (farther than
    # textmap.TC_APART_M) gets its own square with a tether back to the start; one on its start IS the disc.
    from scripts.mapsim.textmap import player_starts, town_centers_apart
    starts = player_starts(rs)
    tcs_apart = town_centers_apart(rs)
    team_of_player = {pl: t for pl, t, _x, _z in starts}
    for p, players, start in tcs_apart:
        t = next((team_of_player[pl] for pl in players if pl in team_of_player), None)
        col = team_color(t) if t is not None else "#d8d2c0"
        if start is not None:
            ax.plot([start[0], p.x], [start[1], p.z], color=col, linewidth=0.9, linestyle=(0, (2, 1)),
                    alpha=0.9, zorder=9.2, transform=tr)
        ax.scatter([p.x], [p.z], marker="s", s=34, color=col, edgecolors="#ffffff", linewidths=0.8,
                   zorder=9.25, transform=tr)
    for pl, t, x, z in starts:
        draw_start(ax, tr, x, z, pl, t)

    # Layer 3, groupings: the REAL footprint box as a 50% dark rectangle —
    # and ONLY the box, never a verdict dot on top (user directive
    # 2026-08-10). Dimensions from the grouping XML header (<width>/
    # <height> in TILES, x2 = meters; box centered on the anchor —
    # refdata.grouping_dimensions_m carries the evidence). All three
    # placement methods draw: rmPlaceGroupingAtLoc / the city-state
    # rmPlaceGroupingInstanceAtLoc (anchor box), and rmPlaceGroupingInArea
    # (nominal box at the target area's anchor — the engine randomizes
    # inside the area). Prefix-variant references (literal+random concat)
    # resolve by their literal prefix, first variant = deterministic
    # nominal. Runtime anchors stay undrawable.
    from matplotlib.patches import Rectangle as _Rect
    from scripts.refdata import catalog as _catalog
    from scripts.refdata.catalogs import grouping_footprint_m
    _gcat = _catalog("grouping")
    boxed_groupings = set()

    def _grouping_dims(p):
        for e in _gcat.resolve(str(p.proto)):
            fp = grouping_footprint_m(e.name)
            if fp is not None:
                return fp
        return None

    def _draw_gbox(px, pz, fp, player_id=None, unsat=False):
        # fp = units' bounding box in meters RELATIVE TO THE ANCHOR —
        # off-center compounds (Inventors +14 m east) draw where the
        # buildings actually stand, not centered on the anchor.
        face = PLAYER_COLORS.get(player_id, "#000000")
        x0 = px + fp[0] / grid.size_x_m
        z0 = pz + fp[1] / grid.size_z_m
        w_f = (fp[2] - fp[0]) / grid.size_x_m
        h_f = (fp[3] - fp[1]) / grid.size_z_m
        r = _Rect((x0, z0), w_f, h_f,
                  facecolor=face, alpha=0.5,
                  edgecolor="#e63946" if unsat else "#e8e0d0",
                  linewidth=1.3 if unsat else 0.6, zorder=5.5)
        r.set_transform(tr)
        ax.add_patch(r)
        if DEBUG_ANCHOR_CROSSES:
            ax.scatter([px], [pz], marker="+", s=90, color="#ff00d0",
                       linewidths=1.6, zorder=9, transform=tr)

    # Grouping boxes draw at their SOLVED spots (gsolve, plan Part H):
    # the constraint-reactive nearest legal point. A moved grouping keeps
    # a tether to its authored anchor — the engine scatters RANDOMLY
    # through the same feasible region, so the tether marks the honest
    # uncertainty; a red edge = no feasible spot found (engine placement
    # would fail too).
    for p in rs.placements:
        if not p.is_grouping:
            continue
        dims = _grouping_dims(p)
        if dims is None or p.x is None or p.z is None:
            continue
        unsat = bool(p.solve_unsat)
        _draw_gbox(p.x, p.z, dims, p.player_id, unsat=unsat)
        boxed_groupings.add(id(p))
        if p.anchor_x is not None and p.anchor_z is not None:
            ax.plot([p.anchor_x, p.x], [p.anchor_z, p.z],
                    color="#d8d2c0", linestyle=(0, (1, 2)), linewidth=0.9,
                    alpha=0.85, zorder=5.4, transform=tr)
            ax.scatter([p.anchor_x], [p.anchor_z], marker="o", s=12,
                       facecolors="none", edgecolors="#d8d2c0",
                       linewidths=0.8, alpha=0.85, zorder=5.4, transform=tr)

    # ZONE groupings (2026-09-25): a runtime spot known to be ONE of a set of spots (placement.candidates; London's
    # shuffled city cells). Every candidate spot is drawn ONCE with the grouping-footprint code, hatched = "a grouping
    # stands here, which one is random" - never one invented spot per grouping.
    zone_cells = {}
    for p in rs.placements:
        if not p.is_grouping or p.x is not None or not getattr(p, "candidates", None):
            continue
        dims = _grouping_dims(p)
        if dims is None:
            continue
        boxed_groupings.add(id(p))
        for cx, cz in p.candidates:
            zone_cells.setdefault((round(cx, 5), round(cz, 5)), (dims, set()))[1].add(p.name)
    for (cx, cz), (dims, names) in zone_cells.items():
        x0 = cx + dims[0] / grid.size_x_m
        z0 = cz + dims[1] / grid.size_z_m
        r = _Rect((x0, z0), (dims[2] - dims[0]) / grid.size_x_m, (dims[3] - dims[1]) / grid.size_z_m,
                  facecolor="#000000", alpha=0.35, hatch="////", edgecolor="#e8e0d0", linewidth=0.6, zorder=5.5)
        r.set_transform(tr)
        ax.add_patch(r)

    undrawable = 0
    for p in rs.placements:
        if id(p) in boxed_groupings:
            continue    # the box IS the marker — no dot mixing
        f = verdicts.get(p.name)
        verdict = f.verdict if f else "OK"
        color = VERDICT_COLOR.get(verdict, "#3fae4c")
        if p.kind == "in_area":
            if DRAW_VERDICT_MARKERS:
                for ref in p.area_refs:
                    a = next((a for a in rs.areas if a.name == ref), None)
                    if a is not None and a.x is not None:
                        ax.scatter([a.x], [a.z], marker="+", s=40, color=color,
                                   linewidths=1.0, zorder=6, alpha=0.8,
                                   transform=tr)
            continue
        if p.x is None:
            undrawable += 1
            continue
        if not DRAW_VERDICT_MARKERS:
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

    # The KotH hill (checks.check_koth, 2026-09-25): a gold star at its spot, labelled with the verdict - drawn
    # whenever the finding exists, independent of DRAW_VERDICT_MARKERS.
    for f in findings or []:
        if f.scope != "koth" or not (f.details or {}).get("hill_m"):
            continue
        hx, hz = f.details["hill_m"]
        fx_, fz_ = grid.x_m_to_frac(hx), grid.z_m_to_frac(hz)
        ax.scatter([fx_], [fz_], marker="*", s=260, color="#ffd21f", edgecolors="#000000",
                   linewidths=0.9, zorder=9, transform=tr)
        d = f.details
        label = ("KotH: tiny island" if d.get("tiny") else "KotH: island" if d.get("island") else "KotH: mainland")
        label += f", {d.get('tiles')} tiles"
        if d.get("deep_water_m") is not None:
            label += f", deep water {d['deep_water_m']:g} m"
        ax.annotate(label, (fx_, fz_), xytext=(0, 9), textcoords="offset points", fontsize=6.5,
                    ha="center", color="#ffd21f", zorder=9, xycoords=tr)

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
        crop_to_circle(ax, center_d, circ_r_d)

    handles = [
        Line2D([], [], marker="s", linestyle="", color=LAND, label="land (buildable)"),
        Line2D([], [], marker="s", linestyle="", color=SHALLOW, label="shallow (walkable+buildable)"),
        Line2D([], [], marker="s", linestyle="", color=WATER, label="deep water"),
        Line2D([], [], linestyle="-", linewidth=1.6, color=CLIFF_EDGE,
               label="cliff area border (as built)"),
        Line2D([], [], marker="s", linestyle="", color="#000000", alpha=0.5,
               markeredgecolor="#e8e0d0",
               label="grouping footprint (real size; gaia)"),
        Line2D([], [], marker="s", linestyle="", color=PLAYER_COLORS[1],
               alpha=0.5, markeredgecolor="#e8e0d0",
               label="player-owned grouping (player color)"),
        Line2D([], [], color="#d8d2c0", linestyle=(0, (1, 2)), marker="o",
               markerfacecolor="none", markersize=4,
               label="grouping moved by constraints (tether = authored anchor)"),
        Line2D([], [], marker="s", linestyle="", color="#000000", alpha=0.5,
               markeredgecolor="#e63946",
               label="grouping with unsatisfiable constraints"),
        Line2D([], [], color="#8f9aa8", linestyle=":", label="invisible mask"),
    ] + ([
        Rectangle((0, 0), 1, 1, facecolor="#000000", alpha=0.35, hatch="////", edgecolor="#e8e0d0",
                  label="grouping spot, identity random (one of several groupings lands here)"),
    ] if zone_cells else []) + [
    ] + ([
        Line2D([], [], marker="o", linestyle="", color=VERDICT_COLOR["OK"], label="OK"),
        Line2D([], [], marker="o", linestyle="", color=VERDICT_COLOR["EDGE_RISK"], label="warning"),
        Line2D([], [], marker="o", linestyle="", color=VERDICT_COLOR["OFF_MAP"], label="error"),
        Line2D([], [], marker="o", linestyle="", markerfacecolor="none",
               color="#9aa0a6", label="runtime / approx"),
    ] if DRAW_VERDICT_MARKERS else []) + [
        Line2D([], [], color=ROUTE, linestyle="--", label="trade route"),
        Line2D([], [], color=RING, linestyle="--", label="player ring"),
    ]
    if starts:
        n_teams = max(t for _pl, t, _x, _z in starts) + 1
        if n_teams <= 4:
            for t in range(n_teams):
                members = [pl for pl, tt, _x, _z in starts if tt == t]
                who = (f"players {members[0]}-{members[-1]}" if len(members) > 1 else f"player {members[0]}")
                handles.append(Line2D([], [], marker="o", linestyle="", color="#9aa0a6",
                                      markeredgecolor=team_color(t), markeredgewidth=2.0, markersize=7,
                                      label=f"team {t + 1} ring: start slots {who.split(' ', 1)[1]}"))
        else:
            handles.append(Line2D([], [], marker="o", linestyle="", color="#9aa0a6",
                                  markeredgecolor=team_color(0), markeredgewidth=2.0, markersize=7,
                                  label="player start: ring = team"))
        handles.append(Line2D([], [], marker="o", linestyle="", color=PLAYER_COLORS[1], markeredgecolor="#ffffff",
                              markersize=7, label="start slot N = lobby slot (fill = its player colour; the game "
                                                  "may give the slot another player id)"))
    if tcs_apart:
        handles.append(Line2D([], [], marker="s", linestyle=(0, (2, 1)), color="#d8d2c0",
                              markeredgecolor="#ffffff", markersize=5,
                              label="Town Center placed away from its start (tether)"))
    if any(f.scope == "koth" for f in findings or []):
        handles.append(Line2D([], [], marker="*", linestyle="", color="#ffd21f", markeredgecolor="#000000",
                              markersize=9, label="King of the Hill hill"))
    if constraint_layers:
        handles += [
            Line2D([], [], color="#e63946", linestyle="--", label="keep-out margin"),
            Line2D([], [], color="#1d3d22", linestyle="--", label="must stay inside"),
            Line2D([], [], color="#f2f2f2", linestyle="--", label="confinement box"),
        ]
    if not own_figure:
        return handles
    legend = ax.legend(handles=handles, loc="lower right", fontsize=6.5, framealpha=0.85)
    legend.set_zorder(10)

    sc = rs.scenario
    tag = f"P{sc.players} T{sc.teams}" + (" KOTH" if sc.koth else "") + (" nomad" if sc.nomad else "")
    note = f" | {undrawable} runtime placements not drawable" if undrawable else ""
    nsup = getattr(rs, "suppressed_variants", 0)
    if nsup:
        note += f" | {nsup} alternative spawn-chance placements suppressed"
    view = " | minimap view (+45°, Elbe-calibrated)" if minimap else ""
    if random_choice_note(rs):
        note += "\n" + random_choice_note(rs)
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
        draw_cliff_outline(ax, tg, tr, linewidth=1.2)
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
