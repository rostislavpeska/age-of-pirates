"""Render a grouping's terrain as a labelled PNG in the in-game orientation.

    python grouping_map.py <grouping.xml> <out.png> [--units PROTO,PROTO] [--flat] [--heights]

Default view is rotated 45 degrees like the game camera: +x = up-right (screen NE), +z = up-left
(screen NW), the bottom edge faces SE. --flat draws +x right / +z up instead. Every cliff tile is
labelled "x,z" (tile coordinates, 2 m each); cliff groups get one colour each (ZP City grey,
ZP Bridge orange, others green shades), tilegroups (shoreline etc.) light blue. Units listed with
--units (default zpBridgeFace) are drawn as red dots with a facing arrow and their metre position.
--heights tints tiles by their plateau height (max vertex height) and prints the distinct values.
"""
import sys, os, math, argparse
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import grouping_lib as G

ap = argparse.ArgumentParser()
ap.add_argument('src'); ap.add_argument('out')
ap.add_argument('--units', default='zpBridgeFace')
ap.add_argument('--flat', action='store_true')
ap.add_argument('--heights', action='store_true')
a = ap.parse_args()

text, nl = G.read(a.src)
cliffs = G.groups(text, 'cliffgroup'); tgs = G.groups(text, 'tilegroup'); hts = G.heights(text)
units = [u for u in G.units(text) if u[6] in a.units.split(',')]
name = os.path.basename(a.src)

allc = [t for bl in list(cliffs.values()) + list(tgs.values()) for t in G.tiles_of(bl)] + list(hts.keys())
X0, X1 = min(x for x, z in allc) - 3, max(x for x, z in allc) + 4
Z0, Z1 = min(z for x, z in allc) - 3, max(z for x, z in allc) + 4
C = 30.0
ang = 0.0 if a.flat else math.radians(45)
ca, sa = math.cos(ang), math.sin(ang)

def T(x, z):
    sx = (x * ca - z * sa) * C; sy = -(x * sa + z * ca) * C
    return sx, sy

corners = [T(x, z) for x in (X0, X1) for z in (Z0, Z1)]
minx = min(p[0] for p in corners); miny = min(p[1] for p in corners)
W = int(max(p[0] for p in corners) - minx) + 40; H = int(max(p[1] for p in corners) - miny) + 70
img = Image.new('RGB', (W, H), 'white'); d = ImageDraw.Draw(img)
try: font = ImageFont.truetype('arial.ttf', 10)
except Exception: font = ImageFont.load_default()

def poly(x, z):
    return [(px - minx + 20, py - miny + 50) for px, py in (T(x, z), T(x + 1, z), T(x + 1, z + 1), T(x, z + 1))]
def center(x, z):
    px, py = T(x + 0.5, z + 0.5); return px - minx + 20, py - miny + 50

for x in range(X0, X1):
    for z in range(Z0, Z1):
        d.polygon(poly(x, z), fill=(225, 225, 225), outline=(238, 238, 238))
if a.heights and hts:
    vals = sorted({max(v) for v in hts.values()})
    print('plateau heights (max vertex per tile row):', vals)
    for (x, z), v in hts.items():
        top = max(v)
        if top > 0.05:
            k = min(1.0, top / max(vals)); d.polygon(poly(x, z), fill=(int(255 - 90 * k), int(240 - 60 * k), int(200 - 120 * k)), outline=(238, 238, 238))
for typ, bl in tgs.items():
    for x, z in G.tiles_of(bl):
        d.polygon(poly(x, z), fill=(200, 225, 245), outline=(238, 238, 238))
palette = {'ZP City': (165, 165, 165), 'ZP Bridge': (205, 125, 60)}
extra = [(120, 200, 120), (170, 140, 210), (230, 200, 90), (120, 190, 200)]
for i, (typ, bl) in enumerate(cliffs.items()):
    col = palette.get(typ) or extra[i % len(extra)]
    for x, z in G.tiles_of(bl):
        d.polygon(poly(x, z), fill=col, outline=(90, 90, 90))
        cx, cy = center(x, z); lab = '%d,%d' % (x, z)
        d.text((cx - d.textlength(lab, font=font) / 2, cy - 6), lab, fill='black', font=font)
for v, x, z, ox, oy, oz, proto in units:
    cx, cy = center(x / 2.0 - 0.5, z / 2.0 - 0.5)
    ex, ey = T(ox, oz); L = math.hypot(ex, ey) or 1
    d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=(220, 30, 30))
    d.line([cx, cy, cx + ex / L * 18, cy + ey / L * 18], fill=(220, 30, 30), width=3)
    d.text((cx + 8, cy - 14), '%.1f,%.1f' % (x, z), fill=(160, 0, 0), font=font)
legend = ', '.join('%s = %s (%d tiles)' % (typ, 'grey' if typ == 'ZP City' else 'orange' if typ == 'ZP Bridge' else 'colour %d' % i, len(G.tiles_of(bl))) for i, (typ, bl) in enumerate(cliffs.items()))
view = 'flat (+x right, +z up)' if a.flat else 'in-game (+x up-right/NE, +z up-left/NW, bottom edge = SE)'
d.text((10, 6), '%s - %s. Labels = tile x,z (2 m). Red = %s (metres, arrow = facing). Blue = tilegroups.' % (name, view, a.units), fill='black', font=font)
d.text((10, 22), 'cliff groups: ' + legend, fill='black', font=font)
img.save(a.out); print(a.out, img.size)
