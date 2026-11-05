"""Water body catalog: name -> carved depth, loaded from the repo's XML.

Sources, in override order (first hit wins, mirroring how DE layers the mod
over vanilla): the mod's data/waterbodies2.xml (verified superset of vanilla
waterbodies2), then the vanilla snapshot scripts/source/waterbodies.xml.
Both are plain XML in-repo — no Steam install needed.

The schema (research 2026-08-08): one <river>/<ocean>/<lake> element per
water type; `depth` is how deep the floor is carved below the water plane;
`alphamindepth`/`alphamaxdepth` drive the shallow-to-deep visual fade. WHERE
the surface sits is the map script's rmSetSeaLevel (or the area's base
height) — never the XML.

Depth classification follows the guide's documented scale
(random_map_generation_guide_v2.md:5683-5698, :5610): 0.2-0.5 walkable
shallows, 1.0 transition, 2.0+ deep (ship access). DEEP_WATER_DEPTH_M = 2.0
is that boundary — water shallower than 2 m renders as shallow.
"""

from __future__ import annotations

import xml.etree.ElementTree as ET
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Dict, Optional

REPO_ROOT = Path(__file__).resolve().parents[2]
# Mod overrides first, vanilla snapshots as fallback (the DE layering rule).
# Vanilla snapshots live in scripts/source/ (extracted from Data.bar via the
# bar-extract skill); refresh them after game patches with vanilla-merge.
SOURCES = (
    REPO_ROOT / "data" / "waterbodies.xml",
    REPO_ROOT / "data" / "waterbodies2.xml",
    REPO_ROOT / "scripts" / "source" / "waterbodies.xml",
    REPO_ROOT / "scripts" / "source" / "waterbodies2.xml",
)

# Layer-2 Terrain Standard depth thresholds (plan_mapsim_architecture.md B3):
# SHALLOW = walkable AND buildable/spawnable ground under water, for
# AREA-DERIVED floors (submerged areas, stamps, causeways). USER-CONFIRMED
# in-game: Civil War's -1.5 m fords are walkable. RIVER carves are never
# walkable regardless of XML depth (user-confirmed: Crownlands' 1.1 m
# Danube blocks) except at authored rmRiverAddShallow fords — walkability
# is decided per SOURCE at stamp time (field.terrain_grid wwalk).
SHALLOW_BUILD_DEPTH_M = 1.5
# Ships require this carved depth (guide:5610 "Deep water: 2.0 meters -
# not walkable, ship access"). Checks query it against the RAW depth;
# display classes never stand in for it.
NAVIGABLE_DEPTH_M = 2.0
# Floor depth assumed when a water type is not in the catalog: deep enough
# that unknown water errs on rendering (and testing) as non-walkable.
DEFAULT_DEPTH_M = 2.0


@dataclass(frozen=True)
class WaterBody:
    name: str
    tag: str          # river | ocean | lake
    depth_m: float    # floor carved this far below the water surface
    source: str = "?"  # "mod" | "vanilla" — which layer supplied the record


@lru_cache(maxsize=1)
def water_bodies() -> Dict[str, WaterBody]:
    """Catalog keyed by lowercase name. Missing/broken files are skipped —
    an empty catalog degrades to DEFAULT_DEPTH_M, never a crash."""
    catalog: Dict[str, WaterBody] = {}
    for path in SOURCES:
        if not path.is_file():
            continue
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError:
            continue
        layer = "mod" if path.parent.name == "data" else "vanilla"
        for el in root:
            name = (el.get("name") or "").strip()
            if not name or name.lower() in catalog:
                continue  # first source wins (mod overrides vanilla)
            try:
                depth = float(el.get("depth", DEFAULT_DEPTH_M))
            except ValueError:
                depth = DEFAULT_DEPTH_M
            catalog[name.lower()] = WaterBody(name, el.tag, depth, layer)
    return catalog


def lookup(name: Optional[str]) -> Optional[WaterBody]:
    if not name:
        return None
    return water_bodies().get(name.strip().lower())


# Per-map profile overrides (plan Part G3): a map profile may pin a water
# body's carved depth with in-game evidence. Set for the duration of one
# map's run via the context manager; depth_of consults it first. Single-
# threaded tooling by design.
_ACTIVE_DEPTH_OVERRIDES: Dict[str, float] = {}


class depth_overrides:
    def __init__(self, mapping: Optional[Dict[str, float]]):
        self._new = {k.strip().lower(): float(v)
                     for k, v in (mapping or {}).items()}

    def __enter__(self):
        self._saved = dict(_ACTIVE_DEPTH_OVERRIDES)
        _ACTIVE_DEPTH_OVERRIDES.update(self._new)
        return self

    def __exit__(self, *exc):
        _ACTIVE_DEPTH_OVERRIDES.clear()
        _ACTIVE_DEPTH_OVERRIDES.update(self._saved)
        return False


def depth_of(name: Optional[str]) -> float:
    if name:
        ov = _ACTIVE_DEPTH_OVERRIDES.get(name.strip().lower())
        if ov is not None:
            return ov
    wb = lookup(name)
    return wb.depth_m if wb is not None else DEFAULT_DEPTH_M


def is_water_type_name(name: str) -> bool:
    """True for the literal "water" and for any cataloged water body name —
    rmTerrainInitialize accepts both forms for a flooded base (guide:3202,
    :5833 rmTerrainInitialize("black_sea_type"))."""
    if name.strip().lower() == "water":
        return True
    return lookup(name) is not None
