"""General grouping-XML reader (future-proof primitive).

Reads any grouping file and returns its header + every unit with ALL of
its parameters, generically (no hardcoded attribute list — new params
are captured automatically). Two sources, mod wins:
  mod:     game/randmaps/groupings/
  install: <AoE3DE>/Game/RandMaps/groupings/

Identity note (user architecture 2026-08-10): the grouping FILE NAME is
the self-explanatory identity in most cases ("pirate village 01",
"Hussite_Camp01"). The socket -> subciv chain (identify.py) is only the
tiebreaker when a filename is ambiguous; the .xs object name
("hansa1", "portG 01") is the confusing layer and is not used here.
"""
from __future__ import annotations

import xml.etree.ElementTree as ET
from functools import lru_cache
from pathlib import Path
from typing import Optional

REPO = Path(__file__).resolve().parents[2]
MOD_GROUPINGS = REPO / "game" / "randmaps" / "groupings"
INSTALL_GROUPINGS = Path(r"C:\Program Files (x86)\Steam\steamapps"
                         r"\common\AoE3DE\Game\RandMaps\groupings")


def find_grouping(name: str) -> Optional[Path]:
    """Locate a grouping XML by stem (case-insensitive), mod dir first."""
    for d in (MOD_GROUPINGS, INSTALL_GROUPINGS):
        if not d.is_dir():
            continue
        p = d / f"{name}.xml"
        if p.is_file():
            return p
        for f in d.glob("*.xml"):
            if f.stem.lower() == name.lower():
                return f
    return None


@lru_cache(maxsize=None)
def read_grouping(name: str) -> Optional[dict]:
    """{name, file, source, header{...}, units[{proto, **attrs}]}.

    header  = every direct child of <grouping> except <units> (width,
              height, ignoreplacementrules, ...), value = its text.
    units   = every <unit>, as {proto: <element text>, **all attributes}
              so posx/posz/orient*/variation and any future attribute are
              all present without being enumerated here."""
    path = find_grouping(name)
    if path is None:
        return None
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError:
        return None
    header, units_el = {}, None
    for child in root:
        if child.tag == "units":
            units_el = child
        else:
            header[child.tag] = (child.text or "").strip()
    units = []
    for u in (units_el if units_el is not None else []):
        rec = dict(u.attrib)                      # ALL attributes, generic
        rec["proto"] = (u.text or "").strip()
        units.append(rec)
    source = "mod" if MOD_GROUPINGS in path.parents else "install"
    return {"name": name, "file": str(path), "source": source,
            "header": header, "units": units}


def units_of(name: str, contains: str = "") -> list:
    """Units whose proto contains `contains` (case-insensitive; '' = all).
    Each unit is the full parameter dict."""
    g = read_grouping(name)
    if not g:
        return []
    c = contains.lower()
    return [u for u in g["units"] if c in u["proto"].lower()]


def proto_counts(name: str) -> dict:
    from collections import Counter
    g = read_grouping(name)
    return dict(Counter(u["proto"] for u in g["units"])) if g else {}


if __name__ == "__main__":
    import sys
    for name in sys.argv[1:]:
        g = read_grouping(name)
        if not g:
            print(f"{name}: NOT FOUND")
            continue
        print(f"{name}  [{g['source']}]  {g['file']}")
        print(f"  header: {g['header']}")
        print(f"  {len(g['units'])} units, "
              f"{len(proto_counts(name))} distinct protos")
        for proto, c in sorted(proto_counts(name).items(),
                               key=lambda kv: -kv[1])[:8]:
            print(f"    {c:4}  {proto}")
        print(f"  sample unit (all params): {g['units'][0]}")
