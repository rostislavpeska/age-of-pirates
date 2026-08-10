"""Spike step 5: position = 12 floats (pos xyz + 3x3 rotation) ENDING at
the 'UN' marker. Verify: wall segments must form a line with regular
steps; the whole census must land inside the map bounds."""
import struct
import zlib
from pathlib import Path

HERE = Path(__file__).parent


def load(name):
    raw = (HERE / "samples" / name).read_bytes()
    return zlib.decompress(raw[8:])


def units(d):
    out = []
    i, n = 0, len(d)
    while i < n - 12:
        if d[i] == 0x55 and d[i + 1] == 0x4E:
            idlen = struct.unpack_from("<I", d, i + 6)[0]
            if 2 <= idlen <= 12 and i + 10 + idlen <= n:
                sid = d[i + 10:i + 10 + idlen]
                if sid[-1] == 0 and all(48 <= c <= 57 for c in sid[:-1]):
                    if i >= 48:
                        x, y, z = struct.unpack_from("<3f", d, i - 48)
                        rot = struct.unpack_from("<9f", d, i - 36)
                        pbase = i + 10 + idlen
                        proto = struct.unpack_from("<I", d, pbase)[0]
                        out.append((sid[:-1].decode(), x, y, z, proto, rot))
                    i += 10 + idlen
                    continue
        i += 1
    return out


us = units(load("0 0  Crownlands Groupings.age3Yscn"))
print(f"units: {len(us)}")

by_id = {u[0]: u for u in us}
print("--- wall line check (SPCFortWallLarge 4..7) ---")
for sid in ("3", "4", "5", "6", "7"):
    sidu = by_id[sid]
    print(f"  id {sid}: pos ({sidu[1]:8.2f}, {sidu[2]:6.2f}, {sidu[3]:8.2f}) proto {sidu[4]}")

print("--- TownCenter (id 2) ---")
u2 = by_id["2"]
print(f"  pos ({u2[1]:.2f}, {u2[2]:.2f}, {u2[3]:.2f})")

xs = [u[1] for u in us]
zs = [u[3] for u in us]
ys = [u[2] for u in us]
print("--- bounds sanity ---")
print(f"  x: [{min(xs):.1f}, {max(xs):.1f}]")
print(f"  y: [{min(ys):.1f}, {max(ys):.1f}]")
print(f"  z: [{min(zs):.1f}, {max(zs):.1f}]")
bad = sum(1 for u in us if not (-10 <= u[1] <= 2000 and -10 <= u[3] <= 2000))
print(f"  out-of-range positions: {bad}/{len(us)}")
