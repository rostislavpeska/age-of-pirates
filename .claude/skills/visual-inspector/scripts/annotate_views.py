"""Burn the view label, the colour legend and a cell grid into rendered views (PIL; vision models read pixels, not file
names or metadata). Writes annotated copies <name>__ann.png beside the originals and keeps each under the size limit.

    python annotate_views.py DIR --legend "MAGENTA = classified hidden" "GREY = visible" [--grid 8x6] [--max-px 1568]
         [--image-ids]   (also burns 'Image N' in reading order; give the same order to the inspector)

Grid: columns A.. and rows 1.. drawn as thin lines with labels on the borders, so a finding names a cell (B4), never
"left of". The default long edge 1568 px is the Claude standard-tier limit (no silent downscale); PNG stays flat colour.
ANNOTATED.json lists {file, label, control, grid} per image: plan_batches.py reads it, aggregate_findings.py checks the
label each inspector copied back against it (proof the inspector looked at that image).
"""
import argparse, json, string
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


def font(sz, bold=True):
    for f in (('arialbd.ttf' if bold else 'arial.ttf'), 'DejaVuSans-Bold.ttf', 'DejaVuSans.ttf'):
        try:
            return ImageFont.truetype(f, sz)
        except Exception:
            continue
    return ImageFont.load_default()


def annotate(path, label, legend, cols=8, rows=6, max_px=1568, image_id=None):
    im = Image.open(path).convert('RGB')
    s = min(1.0, max_px / max(im.size))
    if s < 1.0:
        im = im.resize((int(im.width * s), int(im.height * s)), Image.NEAREST)
    bar = 30 + 22 * len(legend); W, H = im.width, im.height + bar + 26
    can = Image.new('RGB', (W, H), (20, 20, 22)); can.paste(im, (0, bar)); d = ImageDraw.Draw(can)
    head = (f'Image {image_id}: ' if image_id else '') + label
    d.text((8, 4), head, fill=(255, 255, 255), font=font(20))
    for i, t in enumerate(legend):
        d.text((8, 30 + 22 * i), t, fill=(230, 230, 230), font=font(16, False))
    cw, ch = im.width / cols, im.height / rows
    for c in range(1, cols):
        d.line([(c * cw, bar), (c * cw, bar + im.height)], fill=(255, 255, 0), width=1)
    for r in range(1, rows):
        d.line([(0, bar + r * ch), (W, bar + r * ch)], fill=(255, 255, 0), width=1)
    for c in range(cols):
        d.text((c * cw + cw / 2 - 5, bar + im.height + 4), string.ascii_uppercase[c], fill=(255, 255, 0), font=font(16))
    for r in range(rows):
        d.text((3, bar + r * ch + 3), str(r + 1), fill=(255, 255, 0), font=font(16))
    outp = Path(path).with_name(Path(path).stem + '__ann.png'); can.save(outp, optimize=True)
    return outp


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('dir'); ap.add_argument('--legend', nargs='+', required=True)
    ap.add_argument('--grid', default='8x6'); ap.add_argument('--max-px', type=int, default=1568); ap.add_argument('--image-ids', action='store_true')
    a = ap.parse_args(); cols, rows = (int(x) for x in a.grid.split('x'))
    files = sorted(p for p in Path(a.dir).glob('*.png') if not p.stem.endswith('__ann'))
    done = []
    for k, p in enumerate(files):
        clean = p.stem.replace('CONTROL_', '').replace('CLEAN_', '')     # controls must look like any view (no prefix anywhere)
        label = f'{clean}  (camera az{clean.split("_az")[-1]})' if '_az' in clean else clean
        f = annotate(p, label, a.legend, cols, rows, a.max_px, (k + 1) if a.image_ids else None)
        ctl = 'planted' if p.stem.startswith('CONTROL_') else ('clean' if p.stem.startswith('CLEAN_') else None)
        done.append({'file': str(Path(f).resolve()), 'label': label, 'control': ctl, 'grid': [cols, rows]})   # absolute: read from anywhere
    json.dump(done, open(Path(a.dir) / 'ANNOTATED.json', 'w'), indent=1); print('annotated', len(done))
