"""The identification chain (user recipe, exactly):

  grouping name
    -> open its XML (mod game/randmaps/groupings, else install
       RandMaps/groupings) and pull every unit with 'socket' in its name
    -> look that socket up in protomods/protoy
    -> <subciv> present  => NATIVE socket (belongs to that subciv/native)
       no <subciv>       => TRADE / structure socket

That's the whole chain: does a grouping represent a native (and which),
or is it a trade socket. No census, no generation — pure identification.

Usage:
  python identify.py "native carib village 01" "Hansa_CityState_01" ...
  python identify.py --map <map.xs>      # identify every grouping the map places
"""
from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).parent
REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(REPO))

from subciv_map import grouping_sockets, proto_subciv     # noqa: E402
from grouping_reader import read_grouping                 # noqa: E402


def identify(grouping_name: str) -> dict:
    """Identity of one grouping.

    PRIMARY identity is the FILE NAME itself (self-explanatory in most
    cases: 'pirate village 01', 'Hussite_Camp01') — that's what the .xs
    grouping REFERENCE points at, and it's reliable. The socket -> subciv
    chain is the TIEBREAKER for when the filename is ambiguous, and it
    also states native-vs-trade definitively.

    Returns {name, file_found, sockets:[(socket, class)], verdict}."""
    sub = proto_subciv()
    reader = read_grouping(grouping_name)
    socks = grouping_sockets(grouping_name)
    detail, natives = [], []
    for s in socks:
        if s in sub:
            detail.append((s, f"native: {sub[s]}"))
            natives.append(sub[s])
        else:
            detail.append((s, "trade / structure socket (no subciv)"))
    if natives:
        verdict = "NATIVE -> " + ", ".join(sorted(set(natives)))
    elif socks:
        verdict = "TRADE / structure socket (no native subciv)"
    else:
        verdict = "no socket unit (identity = filename only)"
    return {"name": grouping_name,
            "file_found": bool(reader),
            "sockets": detail, "verdict": verdict}


def _map_groupings(xs_path: Path):
    """Every grouping reference the map's rmCreateGrouping calls use."""
    from scripts.mapsim.scene import Scenario
    from scripts.mapsim.xs_extract import extract
    from scripts.refdata import catalog
    ex = extract(xs_path, Scenario(players=4, teams=2))
    gcat = catalog("grouping")
    refs, seen = [], set()
    for d in ex.defs.values():
        if not d.is_grouping:
            continue
        ref = d.proto if isinstance(d.proto, str) \
            else getattr(d.proto, "str_prefix", None) or ""
        if ref and ref not in seen:
            seen.add(ref)
            # resolve prefix refs to concrete stems
            hits = gcat.resolve(ref)
            refs.append(hits[0].name if hits else ref)
    return refs


def main(argv):
    if argv and argv[0] == "--map":
        names = _map_groupings(Path(argv[1]))
        print(f"groupings in {Path(argv[1]).name}:\n")
    else:
        names = argv
    for name in names:
        r = identify(name)
        print(f"{name}")
        for s, cls in r["sockets"]:
            print(f"    socket {s:34} -> {cls}")
        print(f"  => {r['verdict']}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
