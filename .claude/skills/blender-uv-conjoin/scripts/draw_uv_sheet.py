"""Before/after UV map at the same texel scale.

python draw_uv_sheet.py faces.json plan.json out.png [--page 8192] [--title "..."]
Left: the original atlas (faces' uv0 on a page of --page texels). Right: the
conjoined, packed page (side from the plan stats). Families share one colour
(same hash as blender_apply_conjoin.py); grey = unique; white outlines = members
stacked on their owner's texels. The yellow frame marks each page's extent.
"""
import argparse, colorsys, json, zlib
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


def colour(fam, size):
    if size <= 1:
        return (133, 138, 148)
    r, g, b = colorsys.hsv_to_rgb((zlib.crc32(fam.encode()) % 1000) / 1000., .72, .9)
    return int(r * 255), int(g * 255), int(b * 255)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('faces'); ap.add_argument('plan'); ap.add_argument('out')
    ap.add_argument('--page', type=float, default=8192.); ap.add_argument('--px', type=int, default=2048)
    ap.add_argument('--title', default='')
    a = ap.parse_args()
    faces = {f['id']: f for f in json.loads(Path(a.faces).read_text())}
    doc = json.loads(Path(a.plan).read_text()); plan, st = doc['faces'], doc['stats']
    side = st['page_side_texels']; canvas = max(a.page, side); s = a.px / canvas
    try:
        font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 30)
    except OSError:
        font = ImageFont.load_default()
    panels = []
    for label, page, get, outline in (
            (f"BEFORE: {len({f['chart'] for f in faces.values()})} charts, page {a.page:.0f}", a.page,
             lambda k: faces[k]['uv0'], False),
            (f"AFTER: {st['owners']} owners, page {side:.0f} ({(side / a.page) ** 2 * 100:.0f}% area)", side,
             lambda k: plan[k]['uv'], True)):
        im = Image.new('RGB', (a.px, a.px + 60), (25, 29, 35)); d = ImageDraw.Draw(im)
        d.rectangle((0, 60, int(page * s), 60 + int(page * s)), outline=(255, 210, 0), width=3)
        order = sorted(plan, key=lambda k: plan[k]['owner'], reverse=not outline)
        for k in order:
            x = plan[k]
            q = [(u * page * s, 60 + (1 - v) * page * s) for u, v in get(k)]
            if outline and not x['owner']:
                d.polygon(q, outline=(255, 255, 255))
            else:
                d.polygon(q, fill=colour(x['family'], x['family_size']))
        d.text((12, 14), label, font=font, fill='white')
        panels.append(im)
    board = Image.new('RGB', (2 * a.px + 30, a.px + 60 + (60 if a.title else 0)), (10, 10, 12))
    y0 = 60 if a.title else 0
    if a.title:
        ImageDraw.Draw(board).text((12, 14), a.title, font=font, fill='white')
    board.paste(panels[0], (0, y0)); board.paste(panels[1], (a.px + 30, y0))
    board.save(a.out, quality=90)
    print('saved', a.out)


if __name__ == '__main__':
    main()
