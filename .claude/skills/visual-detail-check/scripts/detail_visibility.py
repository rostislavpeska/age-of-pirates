"""Measure how visible a small texture/model detail is at the size the player sees it, and make a sheet to look at.

Compares renders taken with the same camera: BASE (without the detail) and one or more variants (with it). Every image
is first resized to the on-screen size (--scale), because a detail that only exists at 4x zoom does not exist in game.

    python detail_visibility.py --base r15e.png --variant r15g=r15g.png --variant r15h=r15h.png \
        --scale 0.56 [--roi x0,y0,x1,y1] [--mask M.png] [--verdict r15g=strong --verdict r15h=invisible] --out DIR

Footprint: where any variant differs from BASE by more than the JND (CIEDE2000 > 2.3 after a 1 px blur), cleaned of
specks and dilated by 2 px; or the white pixels of --mask (in the unscaled frame). Ring: the band 3-9 px around it.

Per variant (all in the scaled frame):
  dE_mean, dE_p90     CIEDE2000 vs BASE inside the footprint: how much the detail changes the picture
  frac_jnd, frac_clear  share of footprint pixels over 2.3 (just noticeable) and over 6 (seen at a glance)
  dL_ring             mean L* of footprint minus mean L* of the ring in the variant: does it stand out (sign = darker/lighter)
  cnr                 |dL_ring| / std L* of the ring: contrast against the surrounding texture noise (< 0.3 is lost in it)
  edge_ratio          mean |grad L*| in the footprint / in the ring: does it add structure (lines, rhythm) of its own
Verdicts (--verdict NAME=invisible|weak|ok|strong) are owner judgements; the report prints the band they imply.

Writes DIR/DETAIL_VISIBILITY.json and DIR/detail_sheet.png: for BASE and each variant the ROI at on-screen size
(1:1), the same ROI x4 nearest-neighbour, and the dE heatmap (0..12 mapped to black..white). LOOK at the sheet.
"""
import argparse, json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw
from skimage.color import rgb2lab, deltaE_ciede2000

JND, CLEAR = 2.3, 6.0

ap = argparse.ArgumentParser()
ap.add_argument('--base', required=True)
ap.add_argument('--variant', action='append', required=True, help='NAME=IMAGE')
ap.add_argument('--scale', type=float, default=1.0, help='on-screen size / render size')
ap.add_argument('--roi', help='x0,y0,x1,y1 in the unscaled frame (default: footprint bbox + margin)')
ap.add_argument('--mask', help='white = detail footprint, unscaled frame')
ap.add_argument('--verdict', action='append', default=[], help='NAME=invisible|weak|ok|strong')
ap.add_argument('--out', required=True)
a = ap.parse_args()
out = Path(a.out); out.mkdir(parents=True, exist_ok=True)


def load(p):
    im = Image.open(p).convert('RGB')
    if a.scale != 1.0:
        im = im.resize((max(1, round(im.width * a.scale)), max(1, round(im.height * a.scale))), Image.LANCZOS)
    return np.asarray(im, np.float32) / 255


base = load(a.base); Lb = rgb2lab(base)
vars_ = []
for v in a.variant:
    n, p = v.split('=', 1); im = load(p)
    if im.shape != base.shape:
        raise SystemExit(f'{n}: size {im.shape} != base {base.shape} - same camera and resolution required')
    vars_.append((n, im, rgb2lab(im)))

blur = lambda x: cv2.GaussianBlur(x, (0, 0), 1.0)
dEs = {n: deltaE_ciede2000(Lb, L) for n, _, L in vars_}
if a.mask:
    m = np.asarray(Image.open(a.mask).convert('L').resize((base.shape[1], base.shape[0]), Image.NEAREST)) > 127
else:
    m = np.zeros(base.shape[:2], bool)
    for n, _, L in vars_:
        m |= deltaE_ciede2000(rgb2lab(blur(base)), rgb2lab(blur(dict((k, i) for k, i, _ in vars_)[n]))) > JND
    m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((2, 2), np.uint8)).astype(bool)
fp = cv2.dilate(m.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
ring = cv2.dilate(fp.astype(np.uint8), np.ones((19, 19), np.uint8)).astype(bool) & ~cv2.dilate(fp.astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool)
rep = {'base': a.base, 'scale': a.scale, 'footprint_px': int(fp.sum()), 'ring_px': int(ring.sum()), 'variants': {}}
if fp.sum() == 0:
    rep['note'] = 'no pixel of any variant differs from BASE by more than the JND at this scale: INVISIBLE'


def grad(L):
    gx = cv2.Sobel(L, cv2.CV_32F, 1, 0, ksize=3); gy = cv2.Sobel(L, cv2.CV_32F, 0, 1, ksize=3)
    return np.hypot(gx, gy)


for n, im, L in vars_:
    d = dEs[n]; Ls = L[..., 0].astype(np.float32)
    r = {}
    if fp.sum():
        g = grad(Ls)
        r = {'dE_mean': float(d[fp].mean()), 'dE_p90': float(np.percentile(d[fp], 90)),
             'frac_jnd': float((d[fp] > JND).mean()), 'frac_clear': float((d[fp] > CLEAR).mean()),
             'dL_ring': float(Ls[fp].mean() - Ls[ring].mean()) if ring.any() else None,
             'cnr': float(abs(Ls[fp].mean() - Ls[ring].mean()) / (Ls[ring].std() + 1e-6)) if ring.any() else None,
             'edge_ratio': float(g[fp].mean() / (g[ring].mean() + 1e-6)) if ring.any() else None}
    rep['variants'][n] = {k: (round(v, 4) if isinstance(v, float) else v) for k, v in r.items()}

# verdict band
V = dict(v.split('=', 1) for v in a.verdict)
if V:
    rep['verdicts'] = V
    for k in ('edge_ratio', 'dE_p90', 'frac_clear', 'cnr'):
        lo = [rep['variants'][n][k] for n, s in V.items() if s in ('invisible', 'weak') and n in rep['variants'] and rep['variants'][n]]
        hi = [rep['variants'][n][k] for n, s in V.items() if s == 'strong' and n in rep['variants'] and rep['variants'][n]]
        rep.setdefault('band', {})[k] = {'above (too weak at or below)': max(lo) if lo else None, 'below (too strong at or above)': min(hi) if hi else None}

# sheet
if a.roi:
    x0, y0, x1, y1 = (round(int(v) * a.scale) for v in a.roi.split(','))
elif fp.any():
    ys, xs = np.nonzero(fp); mg = 12
    x0, y0, x1, y1 = max(0, xs.min() - mg), max(0, ys.min() - mg), min(base.shape[1], xs.max() + mg), min(base.shape[0], ys.max() + mg)
else:
    x0, y0, x1, y1 = 0, 0, base.shape[1], base.shape[0]
rep['roi_scaled'] = [int(x0), int(y0), int(x1), int(y1)]
Z = 4; w, h = x1 - x0, y1 - y0
rows = [('BASE', base, np.zeros(base.shape[:2]))] + [(n, im, dEs[n]) for n, im, _ in vars_]
cols = [w, w * Z, w * Z]; W = sum(cols) + 4 * 10; H = 22 + (h * Z + 26) * len(rows)
sheet = Image.new('RGB', (W, H), (40, 40, 40)); dr = ImageDraw.Draw(sheet)
dr.text((10, 4), f'1:1 at on-screen scale {a.scale}  |  x{Z} nearest  |  dE2000 vs BASE (0..12)', fill=(230, 230, 230))
for i, (n, im, d) in enumerate(rows):
    y = 22 + i * (h * Z + 26)
    crop = Image.fromarray(np.uint8(np.clip(im[y0:y1, x0:x1], 0, 1) * 255 + .5))
    heat = Image.fromarray(np.uint8(np.clip(d[y0:y1, x0:x1] / 12, 0, 1) * 255 + .5)).convert('RGB')
    sheet.paste(crop, (10, y + 18)); sheet.paste(crop.resize((w * Z, h * Z), Image.NEAREST), (20 + w, y + 18))
    sheet.paste(heat.resize((w * Z, h * Z), Image.NEAREST), (30 + w + w * Z, y + 18))
    m_ = rep['variants'].get(n, {})
    label = n if not m_ else f"{n}: dE p90 {m_.get('dE_p90')}, clear {m_.get('frac_clear')}, cnr {m_.get('cnr')}, dL {m_.get('dL_ring')}, edges {m_.get('edge_ratio')}"
    if n in V: label += f'  [owner: {V[n]}]'
    dr.text((10, y + 2), label, fill=(255, 220, 120))
sheet.save(out / 'detail_sheet.png')
(out / 'DETAIL_VISIBILITY.json').write_text(json.dumps(rep, indent=1), encoding='utf-8')
print(json.dumps(rep, indent=1))
