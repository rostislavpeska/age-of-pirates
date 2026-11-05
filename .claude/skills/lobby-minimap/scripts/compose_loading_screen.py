"""One loading-screen screenshot (<map>_01..03.png, 1200 x 600) from an in-game capture and two layers exported from
the owner's "Map Image Template.psd" as 1200 x 600 PNGs (Photoshop, visibility set explicitly, PNG copy):
  --frame  the burnt-parchment frame, layer "Vrstva 33";
  --shape  a finished map's screenshot layer, "Vrstva 156" (London): its alpha is the cut the owner uses (bbox
           37..1174 x 11..586, opaque inside the frame's outer edge).
The capture's --crop box is scaled to the shape's bbox, takes the shape's alpha, and the frame goes over it. Nothing
else: never "Layer 1" / "Layer 1 kopie" (owner 2026-10-07: "makes the image look 50% cheaper").
Measured 2026-10-07: Pillow's "over" of the two exported layers equals Photoshop's own export of frame + screenshot
(premultiplied colour within 1 level, alpha identical).
usage: compose_loading_screen.py --frame F.png --shape S.png --shot CAPTURE.png --crop X0,Y0,X1,Y1 --out OUT.png"""
import argparse
import sys

import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument('--frame', required=True)
ap.add_argument('--shape', required=True)
ap.add_argument('--shot', required=True)
ap.add_argument('--crop', required=True, help='x0,y0,x1,y1 in the capture: HUD-free, about the shape bbox aspect')
ap.add_argument('--out', required=True)
o = ap.parse_args()

frame = Image.open(o.frame).convert('RGBA')
shape = np.asarray(Image.open(o.shape).convert('RGBA'))[..., 3]
if frame.size != (1200, 600) or shape.shape != (600, 1200):
    sys.exit('the frame and the shape must be 1200 x 600 exports of the template')
ys, xs = np.nonzero(shape > 0)
x0, y0, x1, y1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
box = tuple(int(v) for v in o.crop.split(','))
cw, ch = box[2] - box[0], box[3] - box[1]
want, got = (x1 - x0) / (y1 - y0), cw / ch
if abs(got / want - 1) > 0.01:
    sys.exit('crop aspect %.3f, the shape needs %.3f (%dx%d)' % (got, want, x1 - x0, y1 - y0))
shot = Image.open(o.shot).convert('RGB').crop(box).resize((x1 - x0, y1 - y0), Image.LANCZOS)
layer = Image.new('RGBA', (1200, 600), (0, 0, 0, 0))
layer.paste(shot.convert('RGBA'), (x0, y0))
a = np.asarray(layer).copy()
a[..., 3] = shape
out = Image.alpha_composite(Image.fromarray(a, 'RGBA'), frame)
out.save(o.out)
print('%s: crop %s (%dx%d) -> %dx%d at %d,%d under the frame' % (o.out, box, cw, ch, x1 - x0, y1 - y0, x0, y0))
