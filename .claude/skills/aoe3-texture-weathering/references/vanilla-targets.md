# Vanilla AoE3 DE Asian building targets (measured 2026-10-08)

18 DE BaseColor atlases decoded and measured with `scripts/colourstats.py` (8-bit sRGB; used texels =
max(RGB) > 8; whole-atlas numbers on the used mask eroded by 4 px; features exclude Details.R > 0.5):
JP bansho (barracks), stable, town center, monastery a2/a4; CN town center, war academy, Shaolin a2/a4;
JP and CN castle a2/a4. The legacy hand-painted single textures in DE are only 256x256 (DXT3).

## Whole atlas

| metric | vanilla mean (range) | Korean r60 (before) |
| --- | --- | --- |
| luma mean / sd | 83 / 45.6 | 95-96 / 43-48 |
| luma p5 / p95 | 27 / 177 | 45-47 / 185-192 |
| saturation | 0.375 | 0.31 |
| warmth R-B | +35 | +26..+28 |
| high-pass sd (sigma 4) | 15.2 | 10.7-13.6 |
| low-pass sd (sigma 16) | 35.2 | 38-45 |
| stain fraction (< 0.75 x local) | 0.168 (0.07-0.21) | 0.078-0.081 |
| moss fraction (Lab hue 100-170, C* > 10) | 0.010 (0-0.048) | 0.004-0.021 |
| Masks AO mean | 214 | 230-232 |
| player colour, % used texels | median 2.1 (0.6-4.0) | 9.6-16.6 |
| base under player colour, L / sat | 203-255 / <= 0.09 | 118-139 / 0.04 |

## Features (vanilla L / sd / p5 / p95; sat; R-B; hp / lp / stain)

| feature | vanilla | Korean r60 |
| --- | --- | --- |
| plaster | 126 / 41.6 / 51 / 181; 0.24; +30; 13.6 / 28.5 / 0.116 | 183 / 15.4; 0.09; +18; stain 0.005 |
| stone | 106 / 34.0 / 50 / 159; 0.12 (chroma 4.3); +9; 17.0 / 19.7 / 0.132 | 132 / 31.1; chroma 9.3; +20 |
| doors | 67 / 24.6 / 35 / 116; 0.42; +36; lp 12.8, stain 0.153 | 71 / 16.6 / 49 / 103; 0.53; lp 5.2 |
| paper panes | 170 / 23.0; R-B +21 (+9..+40) | 151 / 8.7; R-B -14 |
| roof (tile fields) | 65 / 33.7 / 18 / 130; stain 0.236 | 67 / 19.3 / 40 / 105 |
| timber | 73 / 29.7 / 35 / 129; 0.42; +38; lp 17.6 | red lacquer sd 5, lp 0.4-0.8, sat 0.63 |
| roof moss | L* 16-20, darker than its tile by 3-9 L*, C* 14-17, hue 94-105 | - |

## What the vanilla language is (visual reading, verify against the crops)

- Painted light and occlusion on top of the Masks AO: plaster darkens toward eaves and frames, tile
  crowns bright and gutters dark, stones pillow-shaded and top-lit, beams with lighter worn arrises.
- Grime at every junction (10-25 % band); brown rising damp in the lower 20-30 % of CN walls; vertical
  rain streaks from beams and sills; speckled pits clustered at edges and bottoms.
- Damage is flaking paint / crumbling plaster edges exposing rough stone or clay - no holes in the
  middle of panels, no exposed brick or lath in these 18 atlases.
- Moss is olive, on the upper slope and ridge, bleeding down a few channels; small patches on stone tops.
- Shoji: warm ivory with tea-brown and grey blotches, darker frames, grime at the bottom rail,
  occasionally one brighter replaced sheet.
- Doors are illustrated: exaggerated seams, braces, raised panels with lit bevels, black iron studs and
  bands, brass ring pulls, weathered lower boards.
- Player colour: thin horizontal stripes on plaster, foundation bands, eave/fascia boards, skirting and
  frieze trims, single panels - never tile fields, posts or door leaves; hard mask, worn like paint.
