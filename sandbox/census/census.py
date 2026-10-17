"""Engine census (spike deliverable): parse a DE .age3Yscn scenario save
and report every placed unit — proto name, position — for spawn testing.

Usage: python sandbox/census/census.py <file.age3Yscn> [--full]
       python sandbox/census/census.py <file.age3Yscn> --trigtemp <trigtemp.xs> [--rule REGEX] [--effect-shift N]

--trigtemp resolves every unit id the compiled triggers use against THIS save (the save and trigtemp.xs must come
from the SAME generation - every generation rewrites both). Measured 2026-09-25 on Istanbul (gun-socket locks and
trade harbours, 16 ids, all consistent): a QUOTED id - trCountUnitsInArea("16", ...), trNuggetCollectable("344"),
trSocketBuild(1, "16", ...) - is the census id itself; a BARE effect select trUnitSelectByID(14) is the census id
MINUS 2 (the unit is census id 16). So "Units in Area" 16 + "Unit Action Suspend" 14 in one trigger are the SAME unit,
not a desync. The 2 is the map's instanceIdShift today and has drifted before: confirm it on one known unit (a
harbour socket, a gun socket) before trusting the column, and pass --effect-shift if it differs.
"""
import re
import struct
import sys
import zlib
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]


def proto_names():
    by_id, by_dbid = {}, {}
    for path in (REPO / "data" / "protomods.xml",
                 REPO / "scripts" / "source" / "protoy.xml"):
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(
                r'<unit id="(\d+)" name="([^"]+)"(?:.*?<dbid>(\d+)</dbid>)?',
                text, re.S):
            by_id.setdefault(int(m.group(1)), m.group(2))
            if m.group(3):
                by_dbid.setdefault(int(m.group(3)), m.group(2))
    return by_id, by_dbid


def parse_units(path: Path, size_x: float = 5000.0, size_z: float = 5000.0):
    """Every 'UN' record with a numeric id at its OWN position: [{'id', 'proto_id', 'x', 'y', 'z'}], file order,
    the first and the last record included; NaN where no header validates (an in-match .age3Ysav: every record).
    The position is the fixed header BEFORE the tag (xyz at tag-49 on the current build, tag-48 on older ones,
    followed by an orthonormal 3x3), decoded by scripts/mapview/census_reader.py - see its docstring; a slightly
    skewed 3x3 (|dot| <= 0.05, 30 records in 15 of 406 saves, 2026-09-24) is read at the save's own offset. Until
    2026-09-24 this took the first plausible float triple after the tag, which is the NEXT record's header: every
    position belonged to the next record in file order (wf_twin_review F1). size_x / size_z are kept for callers
    and ignored: the map size never filters (census_reader.read flags in_map instead)."""
    if str(REPO) not in sys.path:
        sys.path.insert(0, str(REPO))
    from scripts.mapview.census_reader import decode
    try:
        recs = decode(Path(path))
    except ValueError as e:                    # not an l33t container: the CLI's old exit
        raise SystemExit(str(e))
    return [{"id": r.census_id, "proto_id": r.proto_id, "x": r.x, "y": r.y, "z": r.z} for r in recs]


MOD_BASE_OFFSET = 0     # verified 2026-09-17 (build 25040513) on two observations: zpNatInuitHarpooner
                        # runtime 2820 = 2673 vanilla + 147 new-by-name records before it; zpSPCLondonBasilica
                        # 3631 = 2673 + 958. Records written `name ="x"` (space before =) count too.


def runtime_names():
    """(runtime proto index -> name, the vanilla source file or None). The save stores the engine's proto INDEX,
    not the XML id: vanilla units by file position in the CURRENT protoy (mapcheck --live cache; snapshot fallback),
    then every mod unit whose name is not vanilla, from base = vanilla count + MOD_BASE_OFFSET, in the order of
    data/protomods.xml.xmb - what the game loads (the XML through ElementTree as the fallback; comments never count).
    Built by scripts/mapview/census_reader.py name_table, which also returns both sources with their sha1. Until
    2026-09-24 a regex over the raw XML counted 79 units inside comments and misnamed 48 indices from 3657 up
    (wf_twin_review F6). Vanilla ids equal positions only for the first ~1460 records, so by_id alone mis-names
    everything after CrateofCoinLarge400 and every mod unit."""
    if str(REPO) not in sys.path:
        sys.path.insert(0, str(REPO))
    from scripts.mapview.census_reader import name_table
    table, info = name_table(MOD_BASE_OFFSET)
    return table, info["vanilla_source"]


def census(path: Path):
    """Parsed, name-resolved unit list — the importable entry point."""
    by_id, by_dbid = proto_names()
    by_rt, _src = runtime_names()
    units = parse_units(Path(path))
    for u in units:
        pid = u["proto_id"]
        u["proto"] = by_rt.get(pid) or by_id.get(pid) or by_dbid.get(pid) or f"unknown({pid})"
    return units


def trigtemp_ids(units, trig: Path, rule_re: str = "", shift: int = 2):
    """Every unit id in trigtemp.xs, resolved to the census unit it means (see the module doc: quoted = census id,
    trUnitSelectByID = census id - shift)."""
    by_id = {int(u["id"]): u for u in units}
    text = trig.read_text(encoding="utf-8", errors="replace")
    for m in re.finditer(r"^rule (_\w+)(.*?)^\}", text, re.S | re.M):
        name, body = m.group(1), m.group(2)
        if rule_re and not re.search(rule_re, name):
            continue
        refs = [("select", int(i), int(i) + shift) for i in re.findall(r"trUnitSelectByID\((\d+)\)", body)]
        refs += [("quoted", int(i), int(i)) for i in re.findall(r'\btr\w+\([^;]*?"(\d+)"', body)]
        for kind, raw, cid in refs:
            u = by_id.get(cid)
            where = f"{u['proto']:32} ({u['x']:7.1f}, {u['z']:7.1f})" if u else "NO UNIT with that census id"
            print(f"{name:40} {kind:6} {raw:>6} -> census {cid:>6}  {where}")
    return 0


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    path = Path(argv[0])
    full = "--full" in argv
    units = census(path)          # runtime index -> name, as the importable entry point does (2026-09-24)
    if "--trigtemp" in argv:
        return trigtemp_ids(units, Path(argv[argv.index("--trigtemp") + 1]),
                            argv[argv.index("--rule") + 1] if "--rule" in argv else "",
                            int(argv[argv.index("--effect-shift") + 1]) if "--effect-shift" in argv else 2)
    print(f"{path.name}: {len(units)} units")
    xs = [u["x"] for u in units]
    zs = [u["z"] for u in units]
    if units:
        print(f"bounds: x [{min(xs):.0f}, {max(xs):.0f}]  "
              f"z [{min(zs):.0f}, {max(zs):.0f}]")
    counts = Counter(u["proto"] for u in units)
    print(f"{len(counts)} distinct protos:")
    for name, cnt in counts.most_common():
        print(f"  {cnt:4}  {name}")
    if full:
        for u in units:
            print(f"{u['id']:>6} {u['proto']:40} "
                  f"({u['x']:7.1f}, {u['z']:7.1f}) h={u['y']:.1f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
