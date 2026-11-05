"""Spike step 4: find the position field by comparing same-proto records
(SPCFortWallLarge segments 4..7 stand in a wall line — their positions
must differ by a regular step; type-level fields are identical)."""
import struct
import zlib
from pathlib import Path

HERE = Path(__file__).parent


def load(name):
    raw = (HERE / "samples" / name).read_bytes()
    return zlib.decompress(raw[8:])


def un_records(d):
    offs = []
    i, n = 0, len(d)
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
    recs = {}
    for k, (off, sid) in enumerate(offs):
        end = offs[k + 1][0] if k + 1 < len(offs) else min(off + 400, len(d))
        recs[sid] = d[off:end]
    return recs


recs = un_records(load("0 0  Crownlands Groupings.age3Yscn"))
walls = [recs[s] for s in ("4", "5", "6", "7")]
L = min(len(w) for w in walls)
print("wall record lengths:", [len(w) for w in walls])

# fields that differ between consecutive segments
diff_offsets = sorted({k for wa, wb in zip(walls, walls[1:])
                       for k in range(L) if wa[k] != wb[k]})
print("differing byte offsets:", diff_offsets)

# interpret differing dword-aligned offsets as floats across the 4 records
cand = sorted({k - (k % 4) for k in diff_offsets})
for base in cand:
    vals = [struct.unpack_from("<f", w, base)[0] for w in walls]
    pretty = [round(v, 3) for v in vals]
    if all(-1e5 < v < 1e5 for v in vals):
        steps = [round(b - a, 3) for a, b in zip(vals, vals[1:])]
        print(f"  off {base}: {pretty}  steps {steps}")
    else:
        print(f"  off {base}: raw {[struct.unpack_from('<I', w, base)[0] for w in walls]}")
