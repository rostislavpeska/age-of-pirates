"""Deterministic twin of the 'is colour X visible?' question: count pixels of a legend colour in raw overlay renders.

    python colour_census.py DIR --rgb 255,0,255 [--tol 25] [--grid 8x6] [--out CENSUS.json]

Reads the raw renders (not the __ann copies), counts pixels within --tol of --rgb per image and per grid cell (same A-H x
1-6 grid as annotate_views.py, on the raw image). Controls must light up (CONTROL_* > 0, CLEAN_* == 0) or the census is
invalid. Inspectors judge relevance and shape; this script owns the count (vision models are poor at counting colours).
Exit 1 when an inspection view has any pixel of the colour or a control misbehaves.
"""
import argparse, json, string, sys
from pathlib import Path
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser(); ap.add_argument('dir'); ap.add_argument('--rgb', default='255,0,255'); ap.add_argument('--tol', type=int, default=25)
ap.add_argument('--grid', default='8x6'); ap.add_argument('--out')
a = ap.parse_args(); rgb = np.array([int(x) for x in a.rgb.split(',')]); cols, rows = (int(x) for x in a.grid.split('x'))
rep = {'rgb': rgb.tolist(), 'tol': a.tol, 'images': {}}; bad = []
for p in sorted(Path(a.dir).glob('*.png')):
    if p.stem.endswith('__ann'):
        continue
    im = np.asarray(Image.open(p).convert('RGB')).astype(int); H, W = im.shape[:2]
    hit = (np.abs(im - rgb).max(-1) <= a.tol)
    cells = {}
    for r in range(rows):
        for c in range(cols):
            n = int(hit[r * H // rows:(r + 1) * H // rows, c * W // cols:(c + 1) * W // cols].sum())
            if n:
                cells[f'{string.ascii_uppercase[c]}{r + 1}'] = n
    kind = 'planted' if p.stem.startswith('CONTROL_') else ('clean' if p.stem.startswith('CLEAN_') else 'view')
    rep['images'][p.name] = {'kind': kind, 'pixels': int(hit.sum()), 'cells': cells}
    if (kind == 'planted' and not hit.any()) or (kind != 'planted' and hit.any()):
        bad.append(p.name)
rep['failures'] = bad
if a.out:
    json.dump(rep, open(a.out, 'w'), indent=1)
for n, v in rep['images'].items():
    print(f"{n:40s} {v['kind']:8s} {v['pixels']:7d} px  {v['cells'] if v['kind'] == 'view' and v['pixels'] else ''}")
print('COLOUR_CENSUS', 'FAIL ' + ', '.join(bad) if bad else 'PASS')
sys.exit(1 if bad else 0)
