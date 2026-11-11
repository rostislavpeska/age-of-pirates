"""Render the AI-relevant view of a scenario: elevation sampled from every
placed unit, the Home City water spawn flags, and the dock search radius.

The scenario stores x, y, z per unit and y IS elevation, so 8000+ units are
8000+ free height samples - enough to see where the cliffs and the water are
without decoding the heightmap itself.

Usage: python sandbox/census/ai_view.py "<file.age3Yscn>" [out.png]
"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from census import census                                    # noqa: E402

MAP_M = 600          # map is 600 m across
PX = 1200            # output size
CELL = 4             # metres per elevation cell
SCALE = PX / MAP_M

# what the dock placement rules and the AI's dock search actually key on
MARKERS = [
    (r'HomeCityWaterSpawnFlag', (255, 0, 255), 7, 'water spawn flag'),
    (r'^TownCenter$',           (0, 255, 255), 7, 'town centre'),
    (r'KingsHillNaval',         (255, 80, 80), 6, 'naval fort'),
    (r'AntiShipGun',            (255, 160, 0), 5, 'anti-ship gun'),
    (r'^Dock$|dePort|Drydock',  (0, 255, 0),   6, 'dock'),
    (r'FishSardine|Whale',      (255, 255, 0), 2, 'fish/whale'),
]


def ramp(h, lo, hi):
    """Blue (low/water) -> sand -> green -> grey (high/cliff top)."""
    if hi <= lo:
        return (60, 60, 60)
    t = (h - lo) / (hi - lo)
    if t < 0.12:                      # water level
        return (30, 60, 130)
    if t < 0.22:                      # shoreline
        return (200, 190, 140)
    if t < 0.55:                      # low land
        return (70, 110, 60)
    if t < 0.80:                      # rising
        return (120, 110, 80)
    return (200, 200, 205)            # cliff top / plateau


def main(path, out):
    units = census(path)
    xs = [u['x'] for u in units]
    zs = [u['z'] for u in units]
    ys = [u['y'] for u in units]
    print(f'  {len(units)} units   x[{min(xs):.0f},{max(xs):.0f}] '
          f'z[{min(zs):.0f},{max(zs):.0f}]   y[{min(ys):.1f},{max(ys):.1f}]')

    # elevation grid from the unit samples
    n = MAP_M // CELL
    acc = [[None] * n for _ in range(n)]
    for u in units:
        cx, cz = int(u['x'] // CELL), int(u['z'] // CELL)
        if 0 <= cx < n and 0 <= cz < n:
            cur = acc[cz][cx]
            acc[cz][cx] = u['y'] if cur is None else (cur + u['y']) / 2.0

    lo, hi = min(ys), max(ys)
    img = Image.new('RGB', (PX, PX), (18, 18, 22))
    d = ImageDraw.Draw(img, 'RGBA')
    step = PX // n
    for cz in range(n):
        for cx in range(n):
            h = acc[cz][cx]
            if h is None:
                continue
            x0, y0 = cx * step, PX - (cz + 1) * step      # z up
            d.rectangle([x0, y0, x0 + step, y0 + step], fill=ramp(h, lo, hi))

    def to_px(x, z):
        return x * SCALE, PX - z * SCALE

    # dock search radius around each water flag - what istanbulDockSites uses
    for u in units:
        if 'WaterSpawnFlag' not in str(u.get('proto', '')):
            continue
        px, py = to_px(u['x'], u['z'])
        r = 90 * SCALE
        d.ellipse([px - r, py - r, px + r, py + r], outline=(255, 0, 255, 150), width=2)
        r55 = 55 * SCALE
        d.ellipse([px - r55, py - r55, px + r55, py + r55], outline=(255, 0, 255, 70), width=1)

    # markers
    legend = []
    for pat, col, rad, label in MARKERS:
        hit = [u for u in units if re.search(pat, str(u.get('proto', '')), re.I)]
        if hit:
            legend.append((col, f'{label} ({len(hit)})'))
        for u in hit:
            px, py = to_px(u['x'], u['z'])
            d.ellipse([px - rad, py - rad, px + rad, py + rad],
                      fill=col, outline=(0, 0, 0))

    # legend + elevation key
    d.rectangle([8, 8, 330, 30 + 18 * (len(legend) + 4)], fill=(0, 0, 0, 190))
    d.text((16, 14), f'{Path(path).stem}   y {lo:.1f}..{hi:.1f}', fill=(255, 255, 255))
    yy = 34
    for col, label in legend:
        d.ellipse([16, yy + 3, 24, yy + 11], fill=col, outline=(0, 0, 0))
        d.text((32, yy), label, fill=(230, 230, 230))
        yy += 18
    for col, label in ((30, 60, 130), 'water level'), ((200, 190, 140), 'shoreline'), \
                      ((200, 200, 205), 'cliff top / plateau'):
        d.rectangle([16, yy + 3, 24, yy + 11], fill=col)
        d.text((32, yy), label, fill=(230, 230, 230))
        yy += 18
    d.text((16, yy), 'magenta rings = 90m dock search / 55m spacing', fill=(255, 150, 255))

    img.save(out)
    print(f'  wrote {out}')

    # the numbers behind the picture
    print('\n  elevation histogram (unit y samples):')
    buckets = {}
    for v in ys:
        buckets[round(v)] = buckets.get(round(v), 0) + 1
    for k in sorted(buckets)[:14]:
        print(f'     y={k:>4}  {buckets[k]:>5}  {"#" * min(60, buckets[k] // 40)}')


if __name__ == '__main__':
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else 'sandbox/census/run_ai_view.png'
    main(src, dst)
