"""The saved generation (.age3Yscn) as world objects: proto, world metres, fractions, owner (when known).

Builds on sandbox/census/census.py (the record scanner calibrated on a London save, build 25040513: the position
is the first plausible float triple inside the record; layouts differ by unit type). Verified 2026-09-24 on
<profile>/Scenario/LondonIndivUnitIDs.age3Yscn: 8966 of 8967 records read that way, none through the older
fixed layout scenview.py describes (x at tag-48), so that layout is not used here.

THE OWNER IS NOT DECODED YET. In that save the four TownCenter records are byte-identical apart from ids and
positions, so no owner field could be located; `find_owner_offset` is the tool for a fresh save whose owners
are known (a London generation with N players: the N town centres must carry N distinct small values at one
offset). Until then every object reports player=None, and the twin joins on proto + position only.

    python scripts/mapview/census_reader.py <save.age3Yscn> --size 360x645 [--protos TownCenter,zpSPCTowerOfLondon]
    python scripts/mapview/census_reader.py <save.age3Yscn> --find-owner TownCenter --owners 1,2,3,4
"""
from __future__ import annotations

import argparse
import importlib.util
import math
import struct
import sys
import zlib
from collections import Counter
from pathlib import Path
from typing import Dict, List, Optional, Sequence

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO))
from scripts.mapview.transform import world_to_frac  # noqa: E402

OWNER_OFFSET: Optional[int] = None      # relative to the 'UN' tag, u16; None = unknown (see the docstring)


def _census_module():
    spec = importlib.util.spec_from_file_location("aop_census", REPO / "sandbox" / "census" / "census.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def read(save: Path, size_x_m: Optional[float] = None, size_z_m: Optional[float] = None,
         owner_offset: Optional[int] = OWNER_OFFSET) -> List[Dict]:
    """Every unit with a readable position: {id, proto, x_m, z_m, y_m, fx, fz, player}. Fractions need the map
    size; without it they are None. Units whose position could not be read are dropped (their count is in
    `read.dropped` after the call)."""
    census = _census_module()
    sx = size_x_m or 5000.0
    sz = size_z_m or 5000.0
    units = census.parse_units(Path(save), sx, sz)
    by_rt, _ = census.runtime_names()
    by_id, by_dbid = census.proto_names()
    owners = _owners(Path(save), owner_offset) if owner_offset is not None else {}
    out, dropped = [], 0
    for u in units:
        if math.isnan(u["x"]) or math.isnan(u["z"]):
            dropped += 1
            continue
        pid = u["proto_id"]
        proto = by_rt.get(pid) or by_id.get(pid) or by_dbid.get(pid) or "unknown(%d)" % pid
        fx = fz = None
        if size_x_m and size_z_m:
            fx, fz = world_to_frac(u["x"], u["z"], size_x_m, size_z_m)
        out.append({"id": u["id"], "proto": proto, "x_m": u["x"], "z_m": u["z"], "y_m": u["y"], "fx": fx, "fz": fz,
                    "player": owners.get(u["id"])})
    read.dropped = dropped
    return out


read.dropped = 0


def _tags(data: bytes):
    """[(tag_offset, id_string)] as census.py scans them."""
    out = []
    i, n = 0, len(data)
    while i < n - 12:
        if data[i] == 0x55 and data[i + 1] == 0x4E:
            idlen = struct.unpack_from("<I", data, i + 6)[0]
            if 2 <= idlen <= 12 and i + 14 + idlen <= n:
                sid = data[i + 10:i + 10 + idlen]
                if sid[-1] == 0 and all(48 <= c <= 57 for c in sid[:-1]) and i >= 48:
                    out.append((i, sid[:-1].decode()))
                    i += 10 + idlen
                    continue
        i += 1
    return out


def _owners(save: Path, offset: int) -> Dict[str, int]:
    data = zlib.decompress(save.read_bytes()[8:])
    out = {}
    for tag, sid in _tags(data):
        if 0 <= tag + offset < len(data) - 2:
            out[sid] = struct.unpack_from("<H", data, tag + offset)[0]
    return out


def find_owner_offset(save: Path, proto: str, owners: Sequence[int], lo: int = -64, hi: int = 420) -> List[int]:
    """Offsets (relative to the tag, u16) at which the records of `proto` carry exactly the multiset `owners`.
    Use on a save whose owners are known: e.g. a London generation with 4 players and TownCenter, owners 1,2,3,4."""
    census = _census_module()
    data = zlib.decompress(save.read_bytes()[8:])
    by_rt, _ = census.runtime_names()
    by_id, by_dbid = census.proto_names()
    name = lambda pid: by_rt.get(pid) or by_id.get(pid) or by_dbid.get(pid) or "unknown(%d)" % pid
    tags = []
    for tag, sid in _tags(data):
        idlen = len(sid) + 1
        pid = struct.unpack_from("<I", data, tag + 10 + idlen)[0]
        if name(pid) == proto:
            tags.append(tag)
    want = Counter(int(o) for o in owners)
    hits = []
    for k in range(lo, hi):
        vals = [struct.unpack_from("<H", data, t + k)[0] for t in tags if 0 <= t + k < len(data) - 2]
        if len(vals) == len(tags) and Counter(vals) == want:
            hits.append(k)
    return hits


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("save")
    ap.add_argument("--size", default=None, help="map size WxL in metres, e.g. 360x645 (fractions need it)")
    ap.add_argument("--protos", default=None, help="comma list: print only these protos")
    ap.add_argument("--find-owner", default=None, metavar="PROTO")
    ap.add_argument("--owners", default=None, help="expected owners of that proto's records, e.g. 1,2,3,4")
    a = ap.parse_args(argv)
    save = Path(a.save)
    if a.find_owner:
        if not a.owners:
            raise SystemExit("--find-owner needs --owners")
        hits = find_owner_offset(save, a.find_owner, [int(x) for x in a.owners.split(",")])
        print("owner offset candidates for %s: %s" % (a.find_owner, hits or "none"))
        return 0
    sx = sz = None
    if a.size:
        sx, sz = (float(x) for x in a.size.lower().split("x"))
    units = read(save, sx, sz)
    want = set(a.protos.split(",")) if a.protos else None
    print("%s: %d units with positions (%d dropped)" % (save.name, len(units), read.dropped))
    counts = Counter(u["proto"] for u in units)
    for proto, n in counts.most_common():
        if want and proto not in want:
            continue
        print("%5d  %s" % (n, proto))
    if want:
        for u in units:
            if u["proto"] in want:
                print("  %-6s %-32s x %7.1f z %7.1f  frac %s" % (u["id"], u["proto"], u["x_m"], u["z_m"],
                      "(%.3f, %.3f)" % (u["fx"], u["fz"]) if u["fx"] is not None else "-"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
