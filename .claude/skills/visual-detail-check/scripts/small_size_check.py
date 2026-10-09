"""Is a picture still clear at the small sizes the player sees it (icon 128/64/48 px, a portrait in a panel)?
Single images, judged against reference pictures the owner accepts (vanilla icons/portraits), not against a BASE.

    python small_size_check.py --img cand=A.png --img current=B.png --ref shrine=V.png \
        [--sizes 128,64,48] [--crop x0,y0,x1,y1] [--show IMG.png ...] --out DIR

Every picture is cropped (optional, fractions or pixels of each source) and resized with LANCZOS to each size. The
subject is told from the background by its colour difference (CIEDE2000 > 14) from the frame border's median colour.
  subject  share of the picture that stands out from the background (figure-ground; a dark roof on a dark backdrop
           drops out of it - 2026-10-09: an old mottled roof 0.28, the clean candidates 0.35)
  mottle   median local std of L* (5 px window at 128) on the subject's flat areas: blotches, dirt, moss, tile checker
           (lower = cleaner; global measures miss it because the background dominates)
  shape    std of L* after a blur of size/64 px: contrast of the big forms that survive
  edges    mean |grad L*| per pixel; speckle: share of the gradient energy in the finest band (pixel noise)
Verdicts per size against the references: subject 'stands out more' / 'as' / 'less', mottle 'cleaner' / 'as clean' /
'noisier' (as = within 10 % of the reference range); the report also ranks all pictures by mottle and subject.

Writes DIR/SMALL_SIZE.json and DIR/small_size_sheet.png: per picture, each size at 1:1 and enlarged (nearest) to 256.
--show adds finished pictures (e.g. the bordered icon) to the sheet without metrics. LOOK at the 64 px column.
"""
import argparse, json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw
from skimage.color import rgb2lab, deltaE_ciede2000

ap = argparse.ArgumentParser()
ap.add_argument('--img', action='append', default=[], help='NAME=PATH candidate')
ap.add_argument('--ref', action='append', default=[], help='NAME=PATH reference the owner accepts')
ap.add_argument('--sizes', default='128,64,48')
ap.add_argument('--crop', help='x0,y0,x1,y1 applied to every picture (values <= 1 are fractions)')
ap.add_argument('--show', action='append', default=[], help='extra finished picture for the sheet only')
ap.add_argument('--out', required=True)
a = ap.parse_args()
out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
sizes = [int(s) for s in a.sizes.split(',')]


def load(p):
    im = Image.open(p).convert('RGBA')
    bg = Image.new('RGBA', im.size, (0, 0, 0, 255)); im = Image.alpha_composite(bg, im).convert('RGB')
    if a.crop:
        c = [float(v) for v in a.crop.split(',')]
        if max(c) <= 1:
            c = [c[0] * im.width, c[1] * im.height, c[2] * im.width, c[3] * im.height]
        im = im.crop(tuple(int(round(v)) for v in c))
    return im


def metrics(im, n):
    small = im.resize((n, n), Image.LANCZOS)
    lab = rgb2lab(np.asarray(small, np.float32) / 255).astype(np.float32); L = lab[..., 0]
    g = lambda x: np.hypot(cv2.Sobel(x, cv2.CV_32F, 1, 0, ksize=3), cv2.Sobel(x, cv2.CV_32F, 0, 1, ksize=3))
    G = g(L); fine = g(L - cv2.GaussianBlur(L, (0, 0), 1.0))
    b = max(2, n // 16); frame = np.zeros((n, n), bool); frame[:b] = frame[-b:] = True; frame[:, :b] = frame[:, -b:] = True
    dE = deltaE_ciede2000(lab, np.broadcast_to(np.median(lab[frame], axis=0), lab.shape))
    subj = cv2.morphologyEx((dE > 14).astype(np.uint8), cv2.MORPH_OPEN, np.ones((2, 2), np.uint8))
    inner = cv2.erode(subj, np.ones((3, 3), np.uint8)).astype(bool)
    w = max(3, round(5 * n / 128)) | 1
    mu = cv2.blur(L, (w, w)); sd = np.sqrt(np.maximum(cv2.blur(L * L, (w, w)) - mu * mu, 0))
    flat = inner & (G <= np.percentile(G[inner], 60)) if inner.any() else inner   # <=: a flat surface has G = 0
    return small, {'subject': float(subj.mean()), 'mottle': float(np.median(sd[flat])) if flat.any() else float('nan'),
                   'shape': float(cv2.GaussianBlur(L, (0, 0), max(.5, n / 64)).std()), 'edges': float(G.mean()),
                   'speckle': float((fine ** 2).sum() / ((G ** 2).sum() + 1e-6))}


rows = []; rep = {'sizes': sizes, 'crop': a.crop, 'pictures': {}}
for kind, items in (('ref', a.ref), ('img', a.img)):
    for it in items:
        n_, p = it.split('=', 1); im = load(p); per = {}; smalls = []
        for n in sizes:
            sm, m = metrics(im, n); per[n] = {k: round(v, 3) for k, v in m.items()}; smalls.append(sm)
        rep['pictures'][n_] = {'kind': kind, 'path': p, 'per_size': per}; rows.append((n_, kind, smalls))
refs = [v for v in rep['pictures'].values() if v['kind'] == 'ref']
if refs:
    for n_, v in rep['pictures'].items():
        if v['kind'] != 'img':
            continue
        v['verdict'] = {}
        for n in sizes:
            def judge(k, better_high, words):
                lo = min(r['per_size'][n][k] for r in refs); hi = max(r['per_size'][n][k] for r in refs)
                x = v['per_size'][n][k]; tol = .1 * max(abs(hi), 1e-6)
                if lo - tol <= x <= hi + tol:
                    return words[1]
                return words[0] if (x > hi) == better_high else words[2]
            v['verdict'][n] = {'subject': judge('subject', True, ('stands out more', 'stands out as much', 'stands out less')),
                               'mottle': judge('mottle', False, ('cleaner', 'as clean', 'noisier'))}
for n in sizes:
    rep.setdefault('rank', {})[n] = {k: [m for m, _ in sorted(rep['pictures'].items(), key=lambda kv: kv[1]['per_size'][n][k] * (1 if k == 'mottle' else -1))]
                                     for k in ('mottle', 'subject')}
for p in a.show:
    im = Image.open(p).convert('RGBA'); bg = Image.new('RGBA', im.size, (40, 40, 40, 255))
    im = Image.alpha_composite(bg, im).convert('RGB')
    rows.append((Path(p).stem + ' (as shown)', 'show', [im.resize((n, n), Image.LANCZOS) for n in sizes]))

Z = 256; colw = [n + 8 + Z for n in sizes]; W = 10 + sum(c + 14 for c in colw); H = 20 + len(rows) * (Z + 34)
sheet = Image.new('RGB', (W, H), (40, 40, 40)); dr = ImageDraw.Draw(sheet)
dr.text((10, 4), 'each size at 1:1, then enlarged (nearest) to 256  |  subject = stands out from background, mottle = blotches on it (lower = cleaner)  |  LOOK at 64 px', fill=(230, 230, 230))
for r, (n_, kind, smalls) in enumerate(rows):
    y = 20 + r * (Z + 34); x = 10
    v = rep['pictures'].get(n_, {})
    dr.text((10, y + 2), f"{n_} [{kind}]", fill=(255, 220, 120) if kind == 'img' else (150, 210, 255))
    for i, (n, sm) in enumerate(zip(sizes, smalls)):
        sheet.paste(sm, (x, y + 18)); sheet.paste(sm.resize((Z, Z), Image.NEAREST), (x + n + 8, y + 18))
        if v:
            m = v['per_size'][n]; t = f"{n}: subject {m['subject']:.2f}  mottle {m['mottle']:.1f}"
            if 'verdict' in v:
                t += f"  ({v['verdict'][n]['mottle']})"
            dr.text((x, y + 20 + Z), t, fill=(220, 220, 220))
        x += colw[i] + 14
sheet.save(out / 'small_size_sheet.png')
(out / 'SMALL_SIZE.json').write_text(json.dumps(rep, indent=1), encoding='utf-8')
for n_, v in rep['pictures'].items():
    print(n_, v['kind'], {n: v['per_size'][n] for n in sizes}, v.get('verdict', ''))
print('RANK (best first)', json.dumps(rep.get('rank', {})))
