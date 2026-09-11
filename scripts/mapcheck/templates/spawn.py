"""player_spawn_complete — the zpflorence player-spawn regression case
(plan E1/F3): every player must get a spawn on allowed ground, far enough
from the others.

params:
  count          "all" (default) or int — how many players must place
  spawn_classes  allowed terrain classes, default ["LAND", "SHALLOW"]
  min_spacing_m  optional minimum pairwise anchor distance in meters
"""

from __future__ import annotations

import math
from typing import List

from scripts.mapcheck.finding import Finding
from scripts.mapcheck.templates import TemplateContext, _template_finding, class_at

NAME = "player_spawn_complete"


def player_spawn_complete(params: dict, ctx: TemplateContext) -> List[Finding]:
    out: List[Finding] = []
    allowed = params.get("spawn_classes", ["LAND", "SHALLOW"])
    want = params.get("count", "all")
    need = ctx.scenario.players if want == "all" else int(want)

    ring = ctx.ring or []
    if len(ring) < need:
        out.append(_template_finding(
            NAME, "FAIL", ctx,
            f"only {len(ring)} of {need} player anchors resolved",
            resolved=len(ring), required=need))
        return out

    for k, (x, z) in enumerate(ring[:need], start=1):
        cls = class_at(ctx.tg, x, z)
        if cls not in allowed:
            out.append(_template_finding(
                NAME, "FAIL", ctx,
                f"player {k} anchor ({x:.3f}, {z:.3f}) is {cls}, "
                f"allowed {allowed}", player=k, got=cls))

    min_spacing = params.get("min_spacing_m")
    if min_spacing is not None:
        g = ctx.rs.grid
        pts = [g.frac_to_m(x, z) for x, z in ring[:need]]
        for a in range(len(pts)):
            for b in range(a + 1, len(pts)):
                d = math.hypot(pts[a][0] - pts[b][0], pts[a][1] - pts[b][1])
                if d < float(min_spacing):
                    out.append(_template_finding(
                        NAME, "FAIL", ctx,
                        f"players {a + 1} and {b + 1} only {d:.0f} m apart "
                        f"(required {min_spacing} m)",
                        pair=[a + 1, b + 1], distance_m=round(d, 1)))
    return out
