"""Spike step 3: decode UN records — proto reference + position.

Approach: records sliced between successive 'UN' motifs; the u32 pair
right after the id string is the proto reference candidate (resolved
against protoy id= and <dbid>); the position field is located by
byte-diffing matched records between the .bak and the final save.
"""
import re
import struct
import zlib
from pathlib import Path

HERE = Path(__file__).parent
REPO = Path(__file__).resolve().parents[2]


def load(name):
    raw = (HERE / "samples" / name).read_bytes()
    return zlib.decompress(raw[8:])


def un_records(d):
    offs = []
    i = 0
    n = len(d)
    while i < n - 12:
        if d[i] == 0x55 and d[i + 1] == 0x4E:
            idlen = struct.unpack_from("<I", d, i + 6)[0]
            if 2 <= idlen <= 12 and i + 10 + idlen <= n:
                sid = d[i + 10:i + 10 + idlen]
                if sid[-1] == 0 and all(48 <= c <= 57 for c in sid[:-1]):
                    offs.append((i, sid[:-1].decode()))
                    i += 10 + idlen
                    continue
        i += 1
    recs = []
    for k, (off, sid) in enumerate(offs):
        end = offs[k + 1][0] if k + 1 < len(offs) else min(off + 400, len(d))
        recs.append((sid, off, d[off:end]))
    return recs


# proto id maps from protoy + protomods
def proto_maps():
    by_id, by_dbid = {}, {}
    for path in (REPO / "scripts" / "source" / "protoy.xml",
                 REPO / "data" / "protomods.xml"):
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(
                r'<unit id="(\d+)" name="([^"]+)"(?:.*?<dbid>(\d+)</dbid>)?',
                text, re.S):
            pid, name, dbid = int(m.group(1)), m.group(2), m.group(3)
            by_id.setdefault(pid, name)
            if dbid:
                by_dbid.setdefault(int(dbid), name)
    return by_id, by_dbid


by_id, by_dbid = proto_maps()
print(f"proto maps: {len(by_id)} ids, {len(by_dbid)} dbids")

a = un_records(load("0 0  Crownlands Groupings.bak"))
b = un_records(load("0 0  Crownlands Groupings.age3Yscn"))
print(f"records: bak {len(a)}  final {len(b)}")

amap = {sid: (off, blob) for sid, off, blob in a}
bmap = {sid: (off, blob) for sid, off, blob in b}
only_a = [s for s in amap if s not in bmap]
only_b = [s for s in bmap if s not in amap]
print("only in bak:", only_a[:10], " only in final:", only_b[:10])

changed = []
for sid in bmap:
    if sid in amap:
        ba, bb = amap[sid][1], bmap[sid][1]
        if ba != bb:
            diffs = [k for k in range(min(len(ba), len(bb))) if ba[k] != bb[k]]
            changed.append((sid, diffs[:12], len(ba), len(bb)))
print(f"changed matched records: {len(changed)}")
for sid, diffs, la, lb in changed[:8]:
    print(f"  id {sid}: first diff offsets {diffs} (len {la}->{lb})")

# proto reference candidates: u32s following the id string
print("--- proto ref candidates (first 8 records of final) ---")
for sid, off, blob in b[:8]:
    idlen = len(sid) + 1
    base = 10 + idlen
    u1, u2 = struct.unpack_from("<II", blob, base)
    print(f"  id {sid:>5}: u32s {u1},{u2}  "
          f"id->{by_id.get(u1)!r}  dbid->{by_dbid.get(u1)!r}")
