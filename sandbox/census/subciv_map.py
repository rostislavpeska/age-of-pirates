"""Deterministic grouping -> socket -> subciv identification (user recipe
2026-08-10). Grouping NAMES in map scripts are unreliable; the socket
unit inside a grouping's XML, resolved through protoy/protomods' <subciv>,
identifies its native with 100% accuracy — and distinguishes:

  socket WITH  <subciv>  -> a NATIVE grouping   (conditional on subciv roll)
  socket WITHOUT <subciv> -> a STRUCTURE grouping (unconditional; absence is
                             a real concern, not a config artifact)

Two grouping sources (mod wins): the mod's game/randmaps/groupings and the
game-install RandMaps/groupings. Two proto sources (mod wins): protomods
over protoy.
"""
from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from functools import lru_cache
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
MOD_GROUPINGS = REPO / "game" / "randmaps" / "groupings"
INSTALL_GROUPINGS = Path(r"C:\Program Files (x86)\Steam\steamapps"
                         r"\common\AoE3DE\Game\RandMaps\groupings")
MOD_PROTO = REPO / "data" / "protomods.xml"
VANILLA_PROTO = REPO / "scripts" / "source" / "protoy.xml"


@lru_cache(maxsize=None)
def proto_subciv() -> dict:
    """proto name (as authored) -> subciv, for every unit that declares
    one. Mod (protomods) shadows vanilla (protoy). Streamed."""
    out: dict = {}
    for path in (VANILLA_PROTO, MOD_PROTO):     # mod LAST so it overwrites
        if not path.is_file():
            continue
        name = None
        for _ev, el in ET.iterparse(path, events=("start", "end")):
            if el.tag == "unit" and _ev == "start":
                name = el.get("name")
            elif el.tag == "subciv" and _ev == "end" and name:
                if el.text:
                    out[name] = el.text.strip()
            elif el.tag == "unit" and _ev == "end":
                el.clear()
                name = None
    return out


@lru_cache(maxsize=None)
def grouping_sockets(stem: str) -> tuple:
    """Socket unit names inside a grouping's XML (units whose proto contains
    'socket'). Built on the general reader (grouping_reader.read_grouping)."""
    from grouping_reader import units_of
    socks = []
    for u in units_of(stem, "socket"):
        if u["proto"] not in socks:
            socks.append(u["proto"])
    return tuple(socks)


def grouping_identity(stem: str) -> dict:
    """{'sockets': [...], 'subcivs': [...], 'kind': 'native'|'structure'|
    'unknown'} — the deterministic identity of a grouping."""
    sub = proto_subciv()
    socks = grouping_sockets(stem)
    subcivs = [sub[s] for s in socks if s in sub]
    if subcivs:
        kind = "native"
    elif socks:
        kind = "structure"          # has a socket but no subciv
    else:
        kind = "unknown"            # no socket at all (bridge, props)
    return {"sockets": list(socks), "subcivs": subcivs, "kind": kind}


def census_subcivs(units) -> dict:
    """From parsed census units -> {subciv: socket_count}. Every native
    socket present in the map, identified by proto <subciv>."""
    sub = proto_subciv()
    out: dict = {}
    for u in units:
        s = sub.get(u["proto"])
        if s:
            out[s] = out.get(s, 0) + 1
    return out


if __name__ == "__main__":
    import sys
    for stem in sys.argv[1:]:
        print(stem, "->", grouping_identity(stem))
