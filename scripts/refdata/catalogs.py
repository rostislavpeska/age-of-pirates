"""Layered mod->vanilla name catalogs (plan_mapsim_architecture.md Part G1).

One public entry point: catalog(kind) for kind in {"water", "proto",
"grouping"}. Every catalog resolves names case-insensitively and mod-first —
the DE layering rule (a mod record shadows the vanilla record of the same
name). Built for mapcheck S4 (name validation) and reused by any tool that
needs "does this name exist, and whose is it".

Sources per kind:
  water     scripts/mapsim/waterdata.py (already layered; re-used, not
            re-implemented)
  proto     data/protomods.xml (mod, delta records) over
            scripts/source/protoy.xml (vanilla snapshot)
  grouping  game/randmaps/groupings/*.xml stems (mod, live listing) over
            scripts/source/groupings_index.txt (vanilla stems snapshot —
            grouping XMLs ship as LOOSE files under <install>/Game/RandMaps/
            groupings/, not inside .bar archives; refresh recipe is in the
            index header)

Grouping references support the engine's prefix-variant mechanic
(guide 15.4.4): rmCreateGrouping(name, "pirate_village0") matches
pirate_village05.xml, pirate_village06.xml... — resolve() returns ALL
prefix matches and the game picks one at runtime. Trailing spaces in the
reference are significant ("native apache village " -> "native apache
village 1..5"), so references are lowercased but never stripped.
"""

from __future__ import annotations

import xml.etree.ElementTree as ET
from dataclasses import dataclass
from difflib import get_close_matches
from functools import lru_cache
from pathlib import Path
from typing import Dict, Iterator, List, Optional

REPO_ROOT = Path(__file__).resolve().parents[2]

MOD_GROUPINGS_DIR = REPO_ROOT / "game" / "randmaps" / "groupings"
VANILLA_GROUPINGS_INDEX = REPO_ROOT / "scripts" / "source" / "groupings_index.txt"
MOD_PROTO = REPO_ROOT / "data" / "protomods.xml"
VANILLA_PROTO = REPO_ROOT / "scripts" / "source" / "protoy.xml"

KINDS = ("water", "proto", "grouping")


@dataclass(frozen=True)
class Entry:
    name: str    # canonical spelling as authored in its source
    source: str  # "mod" | "vanilla"


class Catalog:
    """Case-insensitive name set with layering provenance."""

    def __init__(self, kind: str, entries: Dict[str, Entry]):
        self.kind = kind
        self._entries = entries  # keyed by lowercase name

    def __len__(self) -> int:
        return len(self._entries)

    def has(self, name: str) -> bool:
        return name.lower() in self._entries

    def get(self, name: str) -> Optional[Entry]:
        return self._entries.get(name.lower())

    def names(self) -> List[str]:
        return sorted(e.name for e in self._entries.values())

    def suggest(self, name: str, n: int = 3) -> List[str]:
        """Nearest existing names for a miss — powers the S4 message
        'unknown proto X, did you mean Y'."""
        hits = get_close_matches(name.lower(), self._entries.keys(), n=n,
                                 cutoff=0.6)
        return [self._entries[h].name for h in hits]


def _install_groupings_dir() -> Optional[Path]:
    """Vanilla grouping XMLs live as LOOSE files in the game install —
    same detection as mapcheck.locate / the bar-extract skill."""
    import os
    env = os.environ.get("AOE3DE_GAME")
    if env and (Path(env) / "RandMaps" / "groupings").is_dir():
        return Path(env) / "RandMaps" / "groupings"
    for cand in (
        Path("C:/Program Files (x86)/Steam/steamapps/common/AoE3DE/Game"),
        Path("C:/Program Files/Steam/steamapps/common/AoE3DE/Game"),
        Path("D:/Steam/steamapps/common/AoE3DE/Game"),
        Path("D:/SteamLibrary/steamapps/common/AoE3DE/Game"),
    ):
        d = cand / "RandMaps" / "groupings"
        if d.is_dir():
            return d
    return None


@lru_cache(maxsize=None)
def grouping_footprint_m(stem: str) -> Optional[tuple]:
    """(min_x, min_z, max_x, max_z) of a grouping's REAL footprint in
    METERS, relative to the placement anchor: the bounding box of its
    units' posx/posz. The <width>/<height> header is the EDITOR CANVAS,
    not the footprint — City_State_Inventors_01 declares 46x50 while its
    143 units occupy 49x51 m offset +14 m east of the anchor (forensic
    2026-08-10; trusting the header drew 92x100 boxes). Unit positions
    are meters in every file checked (pirate_village05 +-9.8 m compound,
    Player_Fort_CivilWar 35x31 m, Railway_Station 27x31 m). Mod file
    wins over the vanilla loose file; None when the file is missing or
    empty."""
    candidates = []
    if MOD_GROUPINGS_DIR.is_dir():
        candidates.append(MOD_GROUPINGS_DIR / f"{stem}.xml")
        for f in MOD_GROUPINGS_DIR.glob("*.xml"):
            if f.stem.lower() == stem.lower():
                candidates.append(f)
    inst = _install_groupings_dir()
    if inst is not None:
        candidates.append(inst / f"{stem}.xml")
        for f in inst.glob("*.xml"):
            if f.stem.lower() == stem.lower():
                candidates.append(f)
    for path in candidates:
        if not path.is_file():
            continue
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError:
            continue
        xs, zs = [], []
        for u in root.iter("unit"):
            px, pz = u.get("posx"), u.get("posz")
            if px is None or pz is None:
                continue
            try:
                xs.append(float(px))
                zs.append(float(pz))
            except ValueError:
                continue
        if xs:
            return (min(xs), min(zs), max(xs), max(zs))
    return None


@lru_cache(maxsize=None)
def grouping_units_m(stem: str) -> Optional[tuple]:
    """((unit_type, dx_m, dz_m), ...) for a grouping's units, anchor-
    relative meters — the unit TYPE is the element text (proto name).
    Feeds the placed-type registry (plan Part H2): type-distance
    constraints like wwcanyon's avoidSufi measure from units INSIDE
    placed groupings ("SocketApache" lives in each Apache village).
    Same file resolution as grouping_footprint_m; None if unreadable."""
    candidates = []
    if MOD_GROUPINGS_DIR.is_dir():
        candidates.append(MOD_GROUPINGS_DIR / f"{stem}.xml")
        for f in MOD_GROUPINGS_DIR.glob("*.xml"):
            if f.stem.lower() == stem.lower():
                candidates.append(f)
    inst = _install_groupings_dir()
    if inst is not None:
        candidates.append(inst / f"{stem}.xml")
        for f in inst.glob("*.xml"):
            if f.stem.lower() == stem.lower():
                candidates.append(f)
    for path in candidates:
        if not path.is_file():
            continue
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError:
            continue
        out = []
        for u in root.iter("unit"):
            t = (u.text or "").strip()
            px, pz = u.get("posx"), u.get("posz")
            if not t or px is None or pz is None:
                continue
            try:
                out.append((t, float(px), float(pz)))
            except ValueError:
                continue
        if out:
            return tuple(out)
    return None


@lru_cache(maxsize=None)
def _proto_unittypes() -> Dict[str, frozenset]:
    """proto name (lower) -> frozenset of its <unittype> tags (lower),
    mod layered over vanilla. Answers "does placed proto P count as the
    abstract type T" for type-distance constraints ("townCenter",
    "sockettraderoute"). One iterparse pass over each proto file."""
    out: Dict[str, frozenset] = {}
    for path in (MOD_PROTO, VANILLA_PROTO):
        if not path.is_file():
            continue
        try:
            for _, el in ET.iterparse(path, events=("end",)):
                if el.tag == "unit":
                    name = el.get("name")
                    if name and name.lower() not in out:
                        types = frozenset(
                            (t.text or "").strip().lower()
                            for t in el.findall("unittype") if t.text)
                        out[name.lower()] = types
                    el.clear()
        except ET.ParseError:
            continue
    return out


def proto_counts_as(proto_name: str, type_name: str) -> bool:
    """True when a placed unit of proto_name satisfies a type-distance
    query for type_name: exact name match, or type_name is one of the
    proto's UnitTypes. Unknown protos only match by exact name."""
    p, t = proto_name.lower(), type_name.lower()
    if p == t:
        return True
    return t in _proto_unittypes().get(p, frozenset())


class GroupingCatalog(Catalog):
    def resolve(self, ref: str) -> List[Entry]:
        """All stems the reference can select in-game: prefix match,
        case-insensitive, whitespace preserved. Empty list = the reference
        spawns nothing. References containing path separators or a drive
        colon are author-machine paths and never resolve portably."""
        if any(c in ref for c in ("/", "\\", ":")):
            return []
        key = ref.lower()
        return [self._entries[k] for k in sorted(self._entries)
                if k.startswith(key)]


def _proto_names(path: Path) -> Iterator[str]:
    """Stream <unit name=...> from a proto file (protoy is 8 MB — iterparse,
    clear as we go)."""
    if not path.is_file():
        return
    for _, el in ET.iterparse(path, events=("end",)):
        if el.tag == "unit":
            name = el.get("name")
            if name:
                yield name
        el.clear()


def _build_water() -> Catalog:
    from scripts.mapsim.waterdata import water_bodies
    entries = {key: Entry(wb.name, wb.source)
               for key, wb in water_bodies().items()}
    return Catalog("water", entries)


def _build_proto() -> Catalog:
    entries: Dict[str, Entry] = {}
    for path, layer in ((MOD_PROTO, "mod"), (VANILLA_PROTO, "vanilla")):
        for name in _proto_names(path):
            entries.setdefault(name.lower(), Entry(name, layer))
    return Catalog("proto", entries)


def _build_grouping() -> GroupingCatalog:
    entries: Dict[str, Entry] = {}
    if MOD_GROUPINGS_DIR.is_dir():
        for f in sorted(MOD_GROUPINGS_DIR.glob("*.xml")):
            entries.setdefault(f.stem.lower(), Entry(f.stem, "mod"))
    if VANILLA_GROUPINGS_INDEX.is_file():
        for line in VANILLA_GROUPINGS_INDEX.read_text(
                encoding="utf-8").splitlines():
            stem = line.rstrip("\n")
            if not stem or stem.startswith("#"):
                continue
            entries.setdefault(stem.lower(), Entry(stem, "vanilla"))
    return GroupingCatalog("grouping", entries)


@lru_cache(maxsize=None)
def catalog(kind: str) -> Catalog:
    if kind == "water":
        return _build_water()
    if kind == "proto":
        return _build_proto()
    if kind == "grouping":
        return _build_grouping()
    raise ValueError(f"unknown catalog kind {kind!r}; valid: {KINDS}")
