"""Engine census (spike deliverable): parse a DE .age3Yscn scenario save
and report every placed unit — proto name, position — for spawn testing.

Usage: python sandbox/census/census.py <file.age3Yscn> [--full]
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
    """Every 'UN' record with a numeric id. The position is the first float triple INSIDE the record
    (after the proto id, before the next record) that reads as a map coordinate: x/z inside the map,
    y a plausible height, and not the unit's (1,1,1) scale vector. Calibrated 2026-09-17 on a London
    save (build 25040513): 5240/5241 records, command posts on the player spots, AI markers at the
    map centre. Record layouts differ by unit type (props +186..188, buildings +272..274, starting
    units +331), which is why the old fixed offset before the marker read garbage. Pass the map size
    to tighten the test; the defaults accept any DE map."""
    raw = path.read_bytes()
    if raw[:4] != b"l33t":
        raise SystemExit(f"not an l33t-compressed file: {path}")
    d = zlib.decompress(raw[8:])
    recs = []
    i, n = 0, len(d)
    while i < n - 12:
        if d[i] == 0x55 and d[i + 1] == 0x4E:      # 'UN'
            idlen = struct.unpack_from("<I", d, i + 6)[0]
            if 2 <= idlen <= 12 and i + 14 + idlen <= n:
                sid = d[i + 10:i + 10 + idlen]
                if sid[-1] == 0 and all(48 <= c <= 57 for c in sid[:-1]) and i >= 48:
                    proto = struct.unpack_from("<I", d, i + 10 + idlen)[0]
                    recs.append((i, idlen, sid[:-1].decode(), proto))
                    i += 10 + idlen
                    continue
        i += 1
    out = []
    for k, (i, idlen, sid, proto) in enumerate(recs):
        end = recs[k + 1][0] if k + 1 < len(recs) else min(n, i + 400)
        x = y = z = float("nan")
        for b in range(i + 40, end - 12):
            px, py, pz = struct.unpack_from("<3f", d, b)
            if not (0.5 <= px <= size_x and 0.5 <= pz <= size_z and -10 < py < 80):
                continue
            if px == 1.0 or pz == 1.0 or (px == py == pz):
                continue
            x, y, z = px, py, pz
            break
        out.append({"id": sid, "proto_id": proto, "x": x, "y": y, "z": z})
    return out


MOD_BASE_OFFSET = 0     # verified 2026-09-17 (build 25040513) on two observations: zpNatInuitHarpooner
                        # runtime 2820 = 2673 vanilla + 147 new-by-name records before it; zpSPCLondonBasilica
                        # 3631 = 2673 + 958. Records written `name ="x"` (space before =) count too.


def runtime_names():
    """Runtime proto index -> name. The save stores the engine's proto INDEX, not the XML id:
    vanilla units by file position in the CURRENT protoy (mapcheck --live cache; snapshot fallback),
    then every protomods record whose name is not vanilla, in file order, from base = vanilla count +
    MOD_BASE_OFFSET. Vanilla ids equal positions only for the first ~1460 records, so by_id alone
    mis-names everything after CrateofCoinLarge400 and every mod unit."""
    import os
    live = Path(os.environ.get("LOCALAPPDATA", "")) / "aoe3-mapcheck" / "protoy_live.xml"
    src = live if live.is_file() else REPO / "scripts" / "source" / "protoy.xml"
    if not src.is_file():
        return {}, None
    text = src.read_text(encoding="utf-8", errors="replace")
    van = [m.group(1) for m in re.finditer(r'<unit\b[^>]*\bname\s*=\s*"([^"]+)"', text)]
    vset = set(van)
    out = {i: n for i, n in enumerate(van)}
    pm = REPO / "data" / "protomods.xml"
    if pm.is_file():
        k = 0
        base = len(van) + MOD_BASE_OFFSET
        for m in re.finditer(r'<unit\b[^>]*\bname\s*=\s*"([^"]+)"', pm.read_text(encoding="utf-8", errors="replace")):
            if m.group(1) not in vset:
                out[base + k] = m.group(1)
                k += 1
    return out, src


def census(path: Path):
    """Parsed, name-resolved unit list — the importable entry point."""
    by_id, by_dbid = proto_names()
    by_rt, _src = runtime_names()
    units = parse_units(Path(path))
    for u in units:
        pid = u["proto_id"]
        u["proto"] = by_rt.get(pid) or by_id.get(pid) or by_dbid.get(pid) or f"unknown({pid})"
    return units


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    path = Path(argv[0])
    full = "--full" in argv
    by_id, by_dbid = proto_names()
    units = parse_units(path)
    for u in units:
        u["proto"] = by_id.get(u["proto_id"]) or by_dbid.get(u["proto_id"]) \
            or f"unknown({u['proto_id']})"
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
