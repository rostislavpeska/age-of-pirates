"""Spike step 2: locate the proto string table and the UN unit records;
print candidate (id, position, proto index) tuples for eyeball validation."""
import struct
import zlib
from pathlib import Path

HERE = Path(__file__).parent


def load(name):
    raw = (HERE / "samples" / name).read_bytes()
    return zlib.decompress(raw[8:])


d = load("0 0  Crownlands Groupings.age3Yscn")
n = len(d)
print("size", n)

# --- 1. proto string table: long run of (u32 len)(ascii\0) entries ---
def scan_string_table(buf):
    best = None
    i = 0
    while i < len(buf) - 8:
        # try to start a run here
        j = i
        entries = []
        while j < len(buf) - 4:
            ln = struct.unpack_from("<I", buf, j)[0]
            if not (2 <= ln <= 64):
                break
            s = buf[j + 4:j + 4 + ln]
            if len(s) != ln or s[-1] != 0:
                break
            body = s[:-1]
            if not all(32 <= c < 127 for c in body):
                break
            entries.append(body.decode())
            j += 4 + ln
        if len(entries) >= 100 and (best is None or len(entries) > len(best[1])):
            best = (i, entries, j)
            i = j
        else:
            i += 1 if not entries else (4 + len(entries[0]) + 1)
    return best


tbl = scan_string_table(d)
if tbl:
    start, names, end = tbl
    print(f"string table: {len(names)} entries at [{start}:{end}]")
    print("  first:", names[:6])
    print("  known hits:", [names.index(x) for x in
                            ("WallWoodNative",) if x in names])
    interesting = [(k, v) for k, v in enumerate(names)
                   if v in ("WallWoodNative", "SocketTradeRoute",
                            "zpTrainStationA", "TownCenter")]
    print("  interesting:", interesting)
else:
    print("no string table found")

# --- 2. UN unit records ---
# motif seen in diff: 'UN' u32 sizeA u32 idlen ascii-id '\0' ... floats
recs = []
i = 0
while i < n - 12 and len(recs) < 100000:
    if d[i] == 0x55 and d[i + 1] == 0x4E:   # 'UN'
        sz = struct.unpack_from("<I", d, i + 2)[0]
        idlen = struct.unpack_from("<I", d, i + 6)[0]
        if 2 <= idlen <= 12 and i + 10 + idlen <= n:
            sid = d[i + 10:i + 10 + idlen]
            if sid[-1] == 0 and all(48 <= c <= 57 for c in sid[:-1]):
                recs.append((i, sz, sid[:-1].decode()))
                i += 10 + idlen
                continue
    i += 1
print(f"UN records: {len(recs)}")
for off, sz, sid in recs[:6]:
    tail = d[off:off + 120]
    floats = struct.unpack_from("<24f", d, off + 10 + len(sid) + 1)
    plaus = [round(f, 2) for f in floats]
    print(f"  off={off} size={sz} id={sid}")
    print(f"    floats: {plaus[:16]}")
print("...")
for off, sz, sid in recs[-3:]:
    floats = struct.unpack_from("<24f", d, off + 10 + len(sid) + 1)
    print(f"  off={off} size={sz} id={sid} floats={[round(f,2) for f in floats[:10]]}")
