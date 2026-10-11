# Measured trade-offs of the methods not chosen

Seven methods and 17 variants were built on the same 1.1k-triangle rider (body + skinned weapon on one 1024 page,
helmet on a 512 page), evaluated with identical flags (seated idle pose, pitch 47, 8 headings, 8 px gutter flag) and
scored by two independent judges on 2026-10-11. Body seam columns are body-only runs. Smart UV is the hard-surface
baseline. The winner is the H1 recipe of this skill (built afterwards from the best steps).

| Variant | L2 / Linf | Angle mean / p90 | t/m p50 (visible p10) | Seam / visible per sqrt(area) | Coverage | Min gap (mip) | Upright | GPU verts | Head/torso (part labels) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Shipped reference rider, own 1024 page | 1.052 / 3.75 | 1.149 / 1.40 | 343 (313) | 5.30 / 1.03 | 58 % | 21.3 px (5) | 72 % | 755 (body) | 1.30 (bone regions) |
| Smart UV Project + Pack Islands | 1.019 / 2.12 | 1.164 / 1.40 | 404 (360) | 23.7 / 4.83 | 68 % | 0.6 px (0) | 21 % | 1460 | 0.98 |
| M1b ABF++ on garment seams | 1.031 / 2.98 | 1.127 / 1.29 | 382 (321) | 6.58 / 1.14 | 61 % | 8.6 px (4) | 100 % | 907 | 1.00 |
| M2a pure LSCM on garment seams | 4.293 / 122.9 | 1.515 / 1.55 | 370 (296) | 5.72 / 1.13 | 58 % | 9.3 px (4) | 98 % | 927 | 1.00 (face 0.83) |
| M2b LSCM with hand-placed relief cuts | 1.046 / 3.22 | 1.097 / 1.26 | 368 (318) | 6.39 / 1.14 | 58 % | 9.5 px (4) | 100 % | 924 | 1.00 (face 0.83) |
| M3a SLIM, four-piece arms | 1.011 / 1.69 | 1.127 / 1.31 | 379 (360) | 6.01 / 0.99 | 61 % | 8.5 px (4) | 100 % | 920 | 1.00 |
| M3b SLIM + island priority | 1.027 / 1.74 | 1.140 / 1.31 | 375 (356) | 6.01 / 0.99 | 63 % | 8.5 px (4) | 100 % | 920 | 1.33 |
| M4a mirror-exact seams, raster pack 8 px | 1.010 / 1.70 | 1.123 / 1.30 | 393 (373) | 5.55 / 0.87 | 66 % | 8.5 px (4) | 100 % | 899 | 1.00 |
| M4a_g16 (same, 16 px) | 1.010 / 1.70 | 1.123 / 1.30 | 381 (362) | 5.55 / 0.87 | 62 % | 16.5 px (5) | 100 % | 899 | 1.00 |
| M5b automatic hidden-seam search | 1.013 / 1.91 | 1.135 / 1.32 | 333 (313) | 4.50 / 0.29 | 47 % | 16.9 px (5) | 75 % | 835 | 0.99 |
| M6a straightened rectangles | 1.026 / 1.87 | 1.218 / 1.46 | 411 (362) | 6.93 / 1.11 | 72 % | 8.5 px (4) | 100 % | 948 | 0.99 |
| M6b rectangles where cheap | 1.017 / 1.69 | 1.178 / 1.38 | 388 (361) | 6.93 / 1.11 | 64 % | 8.7 px (4) | 100 % | 948 | 1.00 |
| **H1 (this skill)** | 1.026 / 1.81 | 1.123 / 1.30 | 372 (345) | 5.55 / 0.87 | 60 % | 16.5 px (5) | 100 % | 899 | 1.29 (1.12 bone regions) |

## Why each one lost

- **Smart UV Project** (hard-surface default): 165 islands (29 tiny), 4.9x the reference rider's seam length, 5.4x its visible
  seam, gaps of 0.6 texels with 263 pairs under 4 texels (gutters gone at mip 0), islands touching the border, a fold,
  random orientation (21 % upright), asymmetric left/right density on a mirror-exact mesh, 1460 GPU vertices. Its
  only wins are low stretch and even density. Disqualified.
- **ABF++** (conformal): undersamples closed ends and strips inside their islands (shoulder triangle at 0.48x, mitt
  spread 1.75x, visible p10 321 t/m), face 0.93x torso, the wrong way against the reference units; `average_islands_scale`
  equalises islands but cannot fix the spread inside one. Fallback only.
- **LSCM** (conformal): without relief cuts it collapsed every closed end (22 flips, 935 px2 folds, body L2 4.29); with
  hand-placed relief cuts it reached L2 1.046 but needs those cuts per unit, drifts in scale along open bands (head as
  an open tube: guard L2 1.83) and gives the face 0.83x the torso. Never as the main solver.
- **SLIM with four-piece arms** (M3): the solver was right, the seams were not: an elbow ring on a deforming joint and
  2.0 m of visible body seam; gutters vanish already at mip 4; the helmet packed at 4.5 px. Its island-priority step lives on in
  the recipe (`island_priority.py`).
- **Automatic hidden-seam search** (M5): the lowest visible seam (0.29 per sqrt area, partly by construction since it
  optimises that metric), but 47 % coverage and 333 t/m (-7 % against the reference rider), a T-shaped pelt (torso front, both
  arms and the head in one island) that suits neither 2D nor AI painting, staircase seam edges and hand tips at angle
  stretch 3+. Its edge cost (length x (visibility + 0.15)) is a possible helper for choosing among declared paths.
- **Straightened rectangles** (M6): +10 % coverage at the same gutter, but the face stretched inside its head-band
  rectangle (face L2 1.08), the belt sheared (angle stretch 1.32) and the page angle p90 rose to 1.46, worse than
  the reference rider. Rectangles are nearly free only on true cylinders (skirt panels dL2 0.014-0.019, shafts 0.003-0.009); built
  into H1 there, they still pushed the page past two targets (L2 1.026 -> 1.030, angle 1.123 / 1.298 -> 1.167 / 1.347)
  for no packing gain. Measure straightening at page level; the island cost alone hides it.
- **Stacked mirror halves** (M4b/M4c): 393 -> 569 t/m (x1.45 linear) and fewer seams, but 412-562 faces (up to 47 % of
  the area) carry mirrored winding: asymmetric paint, labels and player colour mirror, tangent handedness is
  unsupported as far as known, AO bakes double, and the gates read gap 0 / gutters gone at mip 0. The shipped
  reference riders mirror 0 %. Disqualified.
- **Stacking identical tiny parts** (six weapon studs on one footprint): 0 density gained, and the overlap, stacked
  texel and gap gates failed (0 px, 15 pairs). Keep them as unique islands; merging them into a neighbour needs a weld.
- **Pack rotation**: CARDINAL left 37 % of the islands upright, AXIS_ALIGNED 64 % (and 0 % on a helmet page for +13 %
  coverage there); upright packing cost nothing on the body page.
- **Blender's `pack_islands`** vs the raster packer: 61-62 % against 65.9 % coverage at the same 8.5 px gap (about +4 %
  density), and it leaves holes and deep concavities empty (a helmet brim ring, armhole holes).

## Caveats that apply to every variant

Nothing was exported, baked, painted or tested in game; distortion is measured in the bind pose (skinning stretch is
not measured); visibility comes from one idle key at an unverified pitch; the GPU count includes UV splits only; three
of the methods used different seam sets, so their differences are not purely the solver's.
