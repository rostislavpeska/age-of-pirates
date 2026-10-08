# Korean plaster, paper and wear (r70 night run, 2026-10-08)

Owner brief: the Korean set was "too perfect, too geometric"; walls without damage, mould or ripped
plaster; player colour artificial; paper too clean; roof bake protected but wanting moss; doors to be
illustrated. Generic method: [aoe3-texture-weathering](../../aoe3-texture-weathering/SKILL.md).
Candidate maps, sources and the saved Painter project: Korean `r70*` 2d-asset packages in AoE Buildings.

## Atlas facts that drive the recipes (measured)

- **Barracks hall plaster cell [6,1274,397,1633]** is shared by 40 faces (23 visible): long-wall bays,
  end walls (rotated 180 deg to each other), clerestory panels and the courtyard strip
  [18,1397,384,1510] whose faces are rotated 90 deg (up = +x). The owner face is upside down
  (image top = wall bottom). The courtyard plaster therefore cannot become stone texture-only.
- Courtyard caps and bands, and the hall player-colour band [966,275,1094,336] (stacked ~7x, also
  sampled by skirt-1_0 and the courtyard strips), are separate cells.
- Stable plaster is mostly unique (10 cells); TC plaster has 27 cells, up to 14x stacked (cell 8
  [450,555,586,764] repeats on 14 lower-block panels). TC hanji: 2 cells stacked 28x.
- Doors: Barracks hall door and Stable hall door are unique; the Barracks gate leaves share one cell
  (front/back, both leaves).

## Plaster (owner's Elector recipe)

- Two coats: cream top-coat islands (about [230,221,202]) over a warmer, darker under-coat
  ([196,179,152]), island masks from the Painter white-coat Dirt run, edges feathered (no dark seam),
  relief +2.5 texels in the normal map; target L 150-170, sat ~0.20, R-B +30..+36.
- Stack guard on cells with >= 3 visible faces: coat forced on, holes only in a 5-20 texel band at the
  guarded region's border, no rips/cracks/mould; weathering by gradients and fine grain only.
- Calm field, dirty edges: frame grime 0.58 strength over ~10 % of the panel, damp and algae at the
  foot, soot clouds blurred after thresholding; core-minus-ring luma +15..+25 (r70a had +43..+48 and
  read as "white cloud in a dark frame").
- Rips only on unique cells at wall feet and corners: darker rubble with pits, upper/inner shadow,
  chipped lip, crumbs; never a closed dark outline (r70b's read as stickers).

## Hanji

Owner (2026-10-08): "paper must be distinct enough from the walls - so darker, possibly the tea stains,
worn around the lattice wood." Panes L ~120-140 against plaster L ~150-170 (keep >= 25 L gap per
building), warm R-B +15..+30, tea tide-marks, grey smudges, a 3-8 texel grime halo along every bar,
frayed paper at some joints, one slightly fresher replaced pane per row where panes are unique.

## Player colour (whole set, owner-confirmed pattern)

One pattern for TC, Barracks and Stable, taken from the Town Center wall base (wood sill | player-colour
panel ~0.375 m | wood rail): on every three-plank skirt the two lower planks carry player colour (Details
255, worn edges, chips to wood) and the top plank is wood. Paint base luma ~187 with the plank grain kept
(r70f lifted the TC panels to the same value). Courtyard caps/bands are stone; gable emblems kept;
Stable headers/end beams keep r60 colour. The Barracks hall band cell [966,275,1094,336] is also read by
the courtyard plaster strips and the clerestory band, so they show the same two-plank strip (a plain
variant breaks both end walls). Visible share: Barracks 3.89 %, Stable 2.54 %, TC 3.22 %. The r70d
pinstripe-only version (0.94 %) was rejected by the owner as an overcorrection.

## Doors, lacquer, stone, roof

- Doors: Korean iron fittings painted on (cloud-end hinge straps, studs, ring pulls with 1-2 px
  highlights), deeper seams (p5 ~30), lit bevels (p95 ~115-120), scuffed lower boards; gate chips are
  raw wood with a dark rim near edges and the bottom, not pale flecks. Keep the gate diamond.
- Red lacquer posts: grain under lacquer, grimy feet, worn arrises, sd 15+.
- Stone: keep the r60 granite grain (40-50 % luminance), pillow shading, varied joints, neutral chroma.
- Roof: overlay moss darker than the tile (vanilla), in channel-hugging pads; never global value
  changes on the protected bake.
