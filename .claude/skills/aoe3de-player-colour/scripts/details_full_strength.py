"""Lift every player-colour texel of a Details map to full strength (Details.R = 255), keeping the anti-aliased edges.

    python details_full_strength.py IN_Details.png OUT_Details.png [--report REPORT.json] [--hole 0.35] [--edge-radius 2]

Owner rule (2026-10-11): "player color 100% opacity ... 100% default if not requested less". A map can hold reduced
weights inside a full region (a motif painted at 0.9, a sampled band at 0.55), so the lift is local, not per region:
  interior texels (all 8 neighbours painted): R >= --hole -> 1.0; below it stays (a deliberate flake hole in the paint);
  edge texels (touching an unpainted texel): R / plateau, capped at 1, where the plateau is the highest original
  interior R within --edge-radius (no interior nearby: R / max(R in the radius)) - the anti-aliased edge keeps its shape.
A region the owner asked to keep weaker must not be run through this tool: mask it out first. G and B are written 0
(only R is read by the engine). Writes a new file; never writes over the input.
"""
import argparse, json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ap = argparse.ArgumentParser(); ap.add_argument('src'); ap.add_argument('out'); ap.add_argument('--report')
ap.add_argument('--hole', type=float, default=.35); ap.add_argument('--edge-radius', type=int, default=2)
a = ap.parse_args()
assert Path(a.src).resolve() != Path(a.out).resolve(), 'write a new file, never over the input'
r = np.asarray(Image.open(a.src).convert('RGB'))[..., 0].astype(np.float32) / 255.
painted = r > 0
interior = ndimage.binary_erosion(painted, structure=np.ones((3, 3)), border_value=0)
edge = painted & ~interior
k = 2 * a.edge_radius + 1
plateau = ndimage.maximum_filter(np.where(interior, r, 0), size=k)            # local interior plateau
local = ndimage.maximum_filter(r, size=k)                                       # fallback: thin features without interior
w = np.where(plateau > 0, plateau, local)
out = r.copy()
out[interior & (r >= a.hole)] = 1.
e = edge & (w >= a.hole)
out[e] = np.minimum(1., r[e] / w[e])
nz = painted
rep = dict(src=str(a.src), out=str(a.out), painted=int(nz.sum()), interior=int(interior.sum()), edge=int(edge.sum()),
           full_before=round(float((r[nz] >= 250 / 255).mean()), 4) if nz.any() else None,
           full_after=round(float((out[nz] >= 250 / 255).mean()), 4) if nz.any() else None,
           interior_partial_before=int((interior & (r >= a.hole) & (r < 250 / 255)).sum()),
           interior_partial_after=int((interior & (out >= a.hole) & (out < 250 / 255)).sum()),
           flake_holes_kept=int((interior & (r < a.hole)).sum()))
img = np.zeros(r.shape + (3,), np.uint8); img[..., 0] = np.clip(out * 255 + .5, 0, 255).astype(np.uint8)
Image.fromarray(img).save(a.out)
if a.report:
    Path(a.report).write_text(json.dumps(rep, indent=1))
print('DETAILS_FULL', json.dumps(rep))
