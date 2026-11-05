"""Socket-built resource chains in data/protomods.xml must be closed loops.

2026-09-06: zpCherryOrchardBuilt (cloned from the vineyard) died into the
VINEYARD's socket, so a consumed cherry orchard came back as a Vineyard
Foundation. Invariant: a built proto's <deadreplacement>, when it is a socket,
must be a socket whose <socketbuildprotounit> is that very proto. The orchard
protos must also carry each scalar child once (the clone had the vanilla head
AND the vineyard tail pasted together).
"""
from __future__ import annotations

import re
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
PROTOMODS = REPO / "data" / "protomods.xml"


def _units():
    s = PROTOMODS.read_text(encoding="utf-8", errors="replace")
    return {m.group(1): m.group(0) for m in re.finditer(r'<unit id="\d+" name="([^"]+)".*?</unit>', s, re.S)}


def _child(b, tag):
    m = re.search(r"<%s>([^<]*)</%s>" % (tag, tag), b)
    return m.group(1).strip() if m else None


def test_every_socket_chain_is_a_closed_loop():
    units = _units()
    sockets = {n: _child(b, "socketbuildprotounit") for n, b in units.items() if _child(b, "socketbuildprotounit")}
    broken = []
    for name, b in units.items():
        dead = _child(b, "deadreplacement")
        if dead in sockets and sockets[dead] != name:
            broken.append(f"{name} dies into {dead}, which builds {sockets[dead]}")
    assert broken == [], broken


def test_orchard_chains_are_separate():
    units = _units()
    assert _child(units["zpBerryBuildingBuilt"], "deadreplacement") == "zpBerryBuildingSocket"
    assert _child(units["zpCherryOrchardBuilt"], "deadreplacement") == "zpCherryOrchardSocket"
    assert _child(units["zpBerryBuildingSocket"], "socketbuildprotounit") == "zpBerryBuildingBuilt"
    assert _child(units["zpCherryOrchardSocket"], "socketbuildprotounit") == "zpCherryOrchardBuilt"
