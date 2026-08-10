"""Spike step 1: diff Crownlands Groupings save vs its .bak to localize
unit records inside the decompressed scenario payload."""
import sys
import zlib
from pathlib import Path

HERE = Path(__file__).parent


def load(name):
    raw = (HERE / "samples" / name).read_bytes()
    return zlib.decompress(raw[8:])


a = load("0 0  Crownlands Groupings.bak")
b = load("0 0  Crownlands Groupings.age3Yscn")
print(f"bak {len(a)}  final {len(b)}  delta {len(b) - len(a)}")

# common prefix / suffix
p = 0
while p < min(len(a), len(b)) and a[p] == b[p]:
    p += 1
s = 0
while s < min(len(a), len(b)) - p and a[-1 - s] == b[-1 - s]:
    s += 1
print(f"common prefix {p}  common suffix {s}")
print(f"changed region: bak[{p}:{len(a)-s}] ({len(a)-s-p} bytes) "
      f"vs final[{p}:{len(b)-s}] ({len(b)-s-p} bytes)")

for label, buf, end in (("bak", a, len(a) - s), ("final", b, len(b) - s)):
    seg = buf[max(0, p - 48):min(len(buf), end + 48)]
    print(f"--- {label} around change ({len(seg)} bytes) ---")
    print(seg.hex())
    # printable ASCII view
    print("".join(chr(c) if 32 <= c < 127 else "." for c in seg))
