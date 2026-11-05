"""Scenario viewer: decode an .age3Yscn and draw it like the in-game minimap.

    python scripts/scenview.py "<path>.age3Yscn" -o out.png --minimap

WHAT IT READS
  Container : 'l33t' magic, uint32 uncompressed size, raw zlib from offset 8.
  Units     : every record carries the ASCII tag 'UN' at +48. Layout, verified
              against Istanbul_Redesign (8294 records):
                +00 float x        metres
                +04 float y        metres (3.0 = city height, 1.0 = sea level)
                +08 float z        metres
                +12 3x3 rotation matrix (36 bytes)
                +48 'UN' tag
                +68 uint16 player id (0 = gaia, 1..12 = players)
              Records are variable length, so they are found by the tag rather
              than by stride.
  Terrain   : the scenario stores several interleaved 300x300 byte planes
              (600 m map at 2 m tiles). Their semantics are NOT decoded - pass
              --terrain-offset to draw one raw, or --probe to hunt for them.

WHY OBJECT DENSITY STANDS IN FOR LAND
  Designers place objects on land, so their footprint traces the islands. It is
  a proxy, not ground truth - use --terrain-offset once a plane is identified.

ORIENTATION
  --minimap applies the game's +45 deg rotation, so the picture matches a
  screenshot of the in-game minimap:
      screen right ~ (x - z)      screen up ~ (x + z)
      TOP=(1,1)  RIGHT=(1,0)  LEFT=(0,1)  BOTTOM=(0,0)
  Without it you get script coordinates: x east, z north.
"""
from __future__ import annotations

import argparse
import collections
import math
import struct
import sys
import zlib
from pathlib import Path

MAP_M = 600.0          # Istanbul family; override with --map-size
TILE_M = 2.0

# palette lifted from the map simulator's renderer so the two agree
C_DEEP = "#16324f"
C_LAND = "#7fae5a"
C_EDGE = "#9ec5e8"
C_BG = "#0f1319"
C_TEXT = "#e6eef7"
PLAYER_COLORS = ["#9aa7b4", "#3b82f6", "#ef4444", "#eab308", "#22c55e",
                 "#a855f7", "#f97316", "#06b6d4", "#ec4899", "#84cc16",
                 "#f43f5e", "#14b8a6", "#8b5cf6"]


def decode(path: Path) -> bytes:
    raw = path.read_bytes()
    if raw[:4] != b"l33t":
        raise SystemExit("not an .age3Yscn container (magic %r)" % raw[:4])
    size = struct.unpack_from("<I", raw, 4)[0]
    data = zlib.decompressobj().decompress(raw[8:])
    if len(data) != size:
        print("  warning: declared %d, got %d bytes" % (size, len(data)),
              file=sys.stderr)
    return data


def units(data: bytes, map_m: float):
    """Every 'UN'-tagged record with a plausible in-map position."""
    out = []
    p = data.find(b"UN", 0)
    while p != -1:
        o = p - 48
        if o >= 0 and o + 70 <= len(data):
            x, y, z = struct.unpack_from("<fff", data, o)
            if 0.0 <= x <= map_m and -5.0 <= y <= 200.0 and 0.0 <= z <= map_m:
                player = struct.unpack_from("<H", data, o + 68)[0]
                out.append((x, y, z, player if player < len(PLAYER_COLORS) else 0))
        p = data.find(b"UN", p + 1)
    return out


def probe(data: bytes, side: int, lo: int, hi: int, step: int):
    """Hunt for 300x300-ish byte planes that look like a map."""
    n = side * side
    res = []
    for off in range(lo, min(hi, len(data) - n), step):
        b = data[off:off + n]
        c = collections.Counter(b)
        if len(c) < 12 or c.most_common(1)[0][1] > n * 0.85:
            continue
        diff = tot = 0
        for r in range(0, side - 1, 2):
            a = b[r * side:(r + 1) * side]
            e = b[(r + 1) * side:(r + 2) * side]
            for i in range(0, side, 2):
                tot += 1
                diff += (a[i] != e[i])
        res.append((diff / max(1, tot), off, len(c)))
    res.sort()
    return res[:15]


def rot(x: float, z: float, minimap: bool):
    """fractions -> plot coords"""
    if not minimap:
        return x, z
    return (x - z), ((x + z) - 1.0)


def render(u, out: Path, title: str, minimap: bool, map_m: float,
           terrain=None, side=300, grid=110, overlay=None):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Polygon

    fig, ax = plt.subplots(figsize=(12, 12))
    fig.patch.set_facecolor(C_BG)
    ax.set_facecolor(C_BG)

    corners = [rot(0, 0, minimap), rot(1, 0, minimap),
               rot(1, 1, minimap), rot(0, 1, minimap)]
    ax.add_patch(Polygon(corners, closed=True, facecolor=C_DEEP,
                         edgecolor=C_EDGE, lw=2, zorder=1))

    if terrain is not None:
        # raw plane, drawn only in script orientation (no resampling)
        if minimap:
            print("  note: --terrain-offset is drawn unrotated; "
                  "omit --minimap to align it", file=sys.stderr)
        ax.imshow(terrain, origin="lower", extent=[0, 1, 0, 1],
                  cmap="terrain", alpha=.85, interpolation="nearest", zorder=2)
    else:
        # object density as a land proxy
        occ = [[0] * grid for _ in range(grid)]
        for x, _, z, _ in u:
            i = min(grid - 1, int(x / map_m * grid))
            j = min(grid - 1, int(z / map_m * grid))
            occ[j][i] += 1
        for j in range(grid):
            for i in range(grid):
                if not occ[j][i]:
                    continue
                x0, z0 = i / grid, j / grid
                x1, z1 = (i + 1) / grid, (j + 1) / grid
                quad = [rot(x0, z0, minimap), rot(x1, z0, minimap),
                        rot(x1, z1, minimap), rot(x0, z1, minimap)]
                a = min(1.0, 0.30 + 0.10 * occ[j][i])
                ax.add_patch(Polygon(quad, closed=True, facecolor=C_LAND,
                                     edgecolor="none", alpha=a, zorder=2))

    byp = collections.Counter(p for _, _, _, p in u)
    for x, _, z, p in u:
        if p == 0:
            continue
        px, pz = rot(x / map_m, z / map_m, minimap)
        ax.plot(px, pz, ".", color=PLAYER_COLORS[p], ms=3, zorder=5)

    if overlay:
        for lab, (x1, z1, x2, z2), col in overlay:
            a = rot(x1, z1, minimap)
            b = rot(x2, z2, minimap)
            ax.plot([a[0], b[0]], [a[1], b[1]], "-", color=col, lw=4,
                    solid_capstyle="round", zorder=7)
            ax.text((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 + .02, lab, color=col,
                    fontsize=9, ha="center", weight="bold", zorder=7)

    th = [i * math.pi / 180 for i in range(0, 361, 2)]
    ring = [rot(0.5 + 0.455 * math.cos(t), 0.5 + 0.455 * math.sin(t), minimap)
            for t in th]
    ax.plot([p[0] for p in ring], [p[1] for p in ring], ":", color="#ffd166",
            lw=1.4, zorder=6)

    owned = ", ".join("P%d:%d" % (p, c) for p, c in sorted(byp.items()) if p)
    ax.set_title("%s\n%d objects   %s%s"
                 % (title, len(u), "minimap view (+45 deg)" if minimap
                    else "script coords (x east, z north)",
                    ("   " + owned) if owned else ""),
                 color=C_TEXT, fontsize=12)
    ax.set_aspect("equal")
    ax.axis("off")
    m = 1.25 if minimap else 0.04
    if minimap:
        ax.set_xlim(-m, m); ax.set_ylim(-m, m)
    else:
        ax.set_xlim(-m, 1 + m); ax.set_ylim(-m, 1 + m)
    plt.savefig(out, dpi=115, facecolor=fig.get_facecolor(), bbox_inches="tight")
    print("  wrote %s" % out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("scenario")
    ap.add_argument("-o", "--out", default="scenario.png")
    ap.add_argument("--minimap", action="store_true",
                    help="rotate +45 deg into the in-game minimap orientation")
    ap.add_argument("--map-size", type=float, default=MAP_M, help="metres")
    ap.add_argument("--grid", type=int, default=110, help="density cells")
    ap.add_argument("--terrain-offset", type=lambda s: int(s, 0), default=None,
                    help="draw a raw NxN byte plane from this file offset")
    ap.add_argument("--terrain-side", type=int, default=300)
    ap.add_argument("--probe", action="store_true",
                    help="list candidate terrain planes and exit")
    ap.add_argument("--dump", action="store_true",
                    help="print a proto-name/te summary and exit")
    a = ap.parse_args(argv)

    path = Path(a.scenario)
    data = decode(path)
    print("  %s: %d bytes decompressed" % (path.name, len(data)))

    if a.probe:
        print("  candidate %dx%d byte planes (low row-difference = map-like):"
              % (a.terrain_side, a.terrain_side))
        for r, off, nd in probe(data, a.terrain_side, 0x80000, 0x400000, 256):
            print("     0x%06X  rowdiff=%.3f  distinct=%d" % (off, r, nd))
        return 0

    u = units(data, a.map_size)
    print("  units: %d   heights: %s" % (
        len(u), collections.Counter(round(y, 1) for _, y, _, _ in u).most_common(4)))

    if a.dump:
        for x, y, z, p in u[:40]:
            print("     (%7.2f, %6.2f, %7.2f)  P%-2d  frac (%.3f, %.3f)"
                  % (x, y, z, p, x / a.map_size, z / a.map_size))
        return 0

    terrain = None
    if a.terrain_offset is not None:
        s = a.terrain_side
        b = data[a.terrain_offset:a.terrain_offset + s * s]
        if len(b) < s * s:
            raise SystemExit("offset past end of file")
        terrain = [list(b[r * s:(r + 1) * s]) for r in range(s)]

    render(u, Path(a.out), path.stem, a.minimap, a.map_size,
           terrain=terrain, side=a.terrain_side, grid=a.grid)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
