#!/usr/bin/env python
"""Contact sheets of exported viewer frames, with a JSON sidecar per cell and one per sheet (M5).

    import sheets as S
    S.make_sheet(cells, out_dir / 'sheet.png', title='ypIronFlail Attack_melee at its tags', fidelity=fid,
                 columns=['game', 'close'])
    # cells: [{png: Path, row: key, col: key, caption: [lines], record: {...}, highlight: (r, g, b) | None}]
    # writes sheet.png, sheet.json ({title, rows, columns, cells: [{index, row, col, png, ...record}]}) and returns it
    S.write_cell_sidecar(png, record)           # <png stem>.cell.json beside the frame
    S.fidelity_summary(fid)                     # {badge, counts {M, A, U, H}, line}

Every sheet carries the fidelity counts in its header (bundle-schema section 15: a preview is never taken for in-game
truth). PNGs and JSON go only to the output folder the caller made (av_common.output_dir: never a repository).
Pillow only; the font is Pillow's bundled one at the asked size (Pillow 10.1 and newer), else a system font by name.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
import av_common as C  # noqa: E402

BG = (27, 29, 33)
PANEL = (35, 38, 44)
FG = (216, 219, 224)
DIM = (139, 145, 155)
ACC = (224, 180, 74)
FLAG_COLOURS = {'M': (127, 212, 127), 'A': (224, 180, 74), 'U': (255, 122, 106), 'H': (184, 140, 255)}
LANE_COLOURS = {'Attack': (255, 90, 74), 'FootstepLeft': (106, 208, 255), 'FootstepRight': (106, 208, 255),
                'SpecificSoundSet': (184, 140, 255), 'Particles': (255, 211, 74), 'WindEffect': (127, 212, 192),
                'CameraShake': (255, 159, 90), 'other': (154, 160, 170), 'overflow': (154, 160, 170)}
_FONTS = {}


def font(size=13):
    """a TrueType font at `size` px: Pillow's bundled default (10.1+), else DejaVuSans / Consolas / Arial by name,
    else the bitmap default."""
    size = int(size)
    if size in _FONTS:
        return _FONTS[size]
    f = None
    try:
        f = ImageFont.load_default(size=size)
    except TypeError:                                       # Pillow < 10.1
        for name in ('DejaVuSans.ttf', 'consola.ttf', 'arial.ttf'):
            try:
                f = ImageFont.truetype(name, size)
                break
            except OSError:
                continue
    _FONTS[size] = f or ImageFont.load_default()
    return _FONTS[size]


def text_w(draw, s, f):
    x0, _y0, x1, _y1 = draw.textbbox((0, 0), s, font=f)
    return x1 - x0


def fidelity_summary(fid) -> dict:
    """{badge (the letters in stage order), counts {M, A, U, H}, line ('M 17  A 16  U 6  H 8 - calibration none,
    shader v1'), calibration, shader_model, stages}"""
    fid = fid or {}
    stages = fid.get('stages') or {}
    counts = {k: 0 for k in 'MAUH'}
    for v in stages.values():
        counts[v] = counts.get(v, 0) + 1
    line = '  '.join('%s %d' % (k, counts[k]) for k in 'MAUH') + ' - calibration %s, shader %s' % (
        fid.get('calibration', 'none'), fid.get('shader_model', 'none'))
    return {'badge': ''.join(stages.values()), 'counts': counts, 'line': line,
            'calibration': fid.get('calibration', 'none'), 'shader_model': fid.get('shader_model', 'none'),
            'viewer': fid.get('viewer'), 'stages': dict(stages)}


def draw_badge(draw, xy, fid, f, prefix='fidelity '):
    """'fidelity M 17 A 16 U 6 H 8' with each letter in its colour; returns the end x."""
    x, y = xy
    s = fidelity_summary(fid)
    draw.text((x, y), prefix, fill=DIM, font=f)
    x += text_w(draw, prefix, f)
    for k in 'MAUH':
        part = '%s %d  ' % (k, s['counts'][k])
        draw.text((x, y), part, fill=FLAG_COLOURS[k], font=f)
        x += text_w(draw, part, f)
    return x


def write_cell_sidecar(png, record) -> Path:
    """<png stem>.cell.json beside the frame (anim, variant, clip, key, time, tag, fidelity ...)."""
    p = Path(png)
    return C.write_json(p.with_name(p.stem + '.cell.json'), record, why='an export sidecar')


def make_sheet(cells, out_png, *, title='', subtitle='', fidelity=None, columns=None, rows=None, cell_width=None,
               legend=True, notes=()) -> dict:
    """lay `cells` out on a grid (row/col keys, in first-seen order unless `rows` / `columns` give the order) and
    write the sheet PNG and its sidecar <sheet stem>.json; returns the sidecar dict."""
    out_png = Path(out_png)
    cells = list(cells)
    if not cells:
        raise ValueError('a sheet needs at least one cell')
    rkeys = list(rows) if rows else []
    ckeys = list(columns) if columns else []
    for c in cells:
        if c.get('row') not in rkeys:
            rkeys.append(c.get('row'))
        if c.get('col') not in ckeys:
            ckeys.append(c.get('col'))
    imgs = {}
    for c in cells:
        im = Image.open(c['png']).convert('RGBA')
        imgs[id(c)] = im
    w0 = cell_width or max(im.width for im in imgs.values())
    scale = w0 / max(im.width for im in imgs.values())
    h0 = int(round(max(im.height for im in imgs.values()) * scale))
    fc, ft, fs = font(13), font(18), font(12)
    line_h = int(fc.size * 1.35) if hasattr(fc, 'size') else 16
    n_lines = max(len(c.get('caption') or []) for c in cells)
    cap_h = 8 + n_lines * line_h
    pad = 8
    head_h = 12 + 24 + (18 if subtitle else 0) + 20 + (16 * len(notes)) + (18 if legend else 0) + 6
    W = pad + len(ckeys) * (w0 + pad)
    H = head_h + len(rkeys) * (h0 + cap_h + pad) + pad
    sheet = Image.new('RGB', (max(W, 640), H), BG)
    d = ImageDraw.Draw(sheet)
    y = 12
    d.text((pad + 2, y), title, fill=ACC, font=ft)
    y += 24
    if subtitle:
        d.text((pad + 2, y), subtitle, fill=FG, font=fs)
        y += 18
    x = draw_badge(d, (pad + 2, y), fidelity, fs)
    s = fidelity_summary(fidelity)
    d.text((x + 4, y), '- calibration %s, shader %s, viewer %s' % (s['calibration'], s['shader_model'], s['viewer']),
           fill=DIM, font=fs)
    y += 20
    for n in notes:
        d.text((pad + 2, y), str(n), fill=DIM, font=fs)
        y += 16
    if legend:
        d.text((pad + 2, y), 'M measured   A approximated   U unknown   H hypothesis   (bundle fidelity flags; '
                             'the JSON sidecars name every stage)', fill=DIM, font=fs)
        y += 18
    out_cells = []
    for i, c in enumerate(cells):
        r, k = rkeys.index(c.get('row')), ckeys.index(c.get('col'))
        x0 = pad + k * (w0 + pad)
        y0 = head_h + r * (h0 + cap_h + pad)
        im = imgs[id(c)]
        if scale != 1:
            im = im.resize((int(round(im.width * scale)), int(round(im.height * scale))), Image.LANCZOS)
        tile = Image.new('RGB', (w0, h0), PANEL)
        tile.paste(im, (0, 0), im)
        sheet.paste(tile, (x0, y0))
        if c.get('highlight'):
            d.rectangle([x0 - 2, y0 - 2, x0 + w0 + 1, y0 + h0 + 1], outline=tuple(c['highlight']), width=2)
        cy = y0 + h0 + 4
        for j, line in enumerate(c.get('caption') or []):
            d.text((x0 + 2, cy), str(line), fill=FG if j == 0 else DIM, font=fc)
            cy += line_h
        rec = dict(c.get('record') or {})
        rec.update({'index': i, 'row': c.get('row'), 'col': c.get('col'), 'png': Path(c['png']).name,
                    'box': [x0, y0, w0, h0]})
        out_cells.append(rec)
    C.write_bytes(out_png, _png_bytes(sheet), 'an export sheet')
    side = {'sheet': out_png.name, 'title': title, 'subtitle': subtitle, 'rows': [str(x) for x in rkeys],
            'columns': [str(x) for x in ckeys], 'size': list(sheet.size), 'fidelity': fidelity_summary(fidelity),
            'notes': list(notes), 'cells': out_cells}
    C.write_json(out_png.with_suffix('.json'), side, why='an export sidecar')
    return side


def _png_bytes(im) -> bytes:
    import io
    b = io.BytesIO()
    im.save(b, 'PNG')
    return b.getvalue()
