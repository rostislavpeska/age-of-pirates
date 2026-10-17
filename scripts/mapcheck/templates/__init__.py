"""Template registry (plan Parts E1/G4).

A map-specific test concern is ALWAYS expressed as template + params in the
map's profile, never as per-map code. A profile referencing an unregistered
template is itself a FAIL whose message says to generalize first — that
rule is what keeps "map specific" reusable for the next map.

Template signature: fn(params: dict, ctx: TemplateContext) -> [Finding].
Finding check ids are "T:<template-name>".
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable, Dict, List, Optional

from scripts.mapcheck.finding import Finding

CLASS_NAMES = ("LAND", "SHALLOW", "DEEP", "CLIFF")


@dataclass
class TemplateContext:
    stem: str
    scenario: Any               # mapsim Scenario
    scenario_tag: str           # "P2T2"
    ex: Any = None              # Extraction
    rs: Any = None              # ResolvedScene
    tg: Any = None              # TerrainGrid (None when grid tier skipped)
    ring: Any = None            # [(x_frac, z_frac)] nominal player anchors
    profile: Any = None


def class_at(tg, x: float, z: float) -> str:
    i, j = tg.cell_of_frac(float(x), float(z))
    return CLASS_NAMES[tg.class_code(i, j)]


def _template_finding(name: str, severity: str, ctx: TemplateContext,
                      message: str, **details) -> Finding:
    return Finding(f"T:{name}", severity, "model", message, map=ctx.stem,
                   scenario=ctx.scenario_tag, details=dict(details))


from scripts.mapcheck.templates.groupings import grouping_spawn_complete  # noqa: E402
from scripts.mapcheck.templates.spawn import player_spawn_complete  # noqa: E402
from scripts.mapcheck.templates.terrain import area_class_probe  # noqa: E402

TEMPLATES: Dict[str, Callable[[dict, TemplateContext], List[Finding]]] = {
    "player_spawn_complete": player_spawn_complete,
    "grouping_spawn_complete": grouping_spawn_complete,
    "area_class_probe": area_class_probe,
}


def run_template(name: str, params: Optional[dict],
                 ctx: TemplateContext) -> List[Finding]:
    fn = TEMPLATES.get(name)
    if fn is None:
        return [Finding(
            "T:unregistered", "FAIL", "deterministic",
            f"profile references unregistered template {name!r} — "
            f"generalize the concern into a template first "
            f"(registered: {sorted(TEMPLATES)})", map=ctx.stem,
            scenario=ctx.scenario_tag)]
    if ctx.tg is None:
        return [Finding(
            f"T:{name}", "INFO", "model",
            "grid tier skipped — template not evaluated", map=ctx.stem,
            scenario=ctx.scenario_tag)]
    return fn(params or {}, ctx)
