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


def parse_units(path: Path):
    raw = path.read_bytes()
    if raw[:4] != b"l33t":
        raise SystemExit(f"not an l33t-compressed file: {path}")
    d = zlib.decompress(raw[8:])
    out = []
    i, n = 0, len(d)
    while i < n - 12:
        if d[i] == 0x55 and d[i + 1] == 0x4E:      # 'UN'
            idlen = struct.unpack_from("<I", d, i + 6)[0]
            if 2 <= idlen <= 12 and i + 14 + idlen <= n:
                sid = d[i + 10:i + 10 + idlen]
                if sid[-1] == 0 and all(48 <= c <= 57 for c in sid[:-1]) and i >= 48:
                    x, y, z = struct.unpack_from("<3f", d, i - 48)
                    proto = struct.unpack_from("<I", d, i + 10 + idlen)[0]
                    out.append({"id": sid[:-1].decode(), "proto_id": proto,
                                "x": x, "y": y, "z": z})
                    i += 10 + idlen
                    continue
        i += 1
    return out


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
