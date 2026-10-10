# Korean roof appearance: the Town Center canon (roof_canon v1)

Every Korean roof's tile field, clay caps and eave-end clay is derived from the canonical Town Center through
`scripts/roof_canon.py`. Roof look code in a building recipe is forbidden. The method and its sources are in
[canonical derivation](../../blender-architecture-texturing/references/canonical-derivation.md).

## The canon pack (v1)

- **What it is:** the last installed TC roof, i.e. the r70f `mata` over Walls R3 runtime DDTs in the Koreans repo
  (`art/buildings/korean_tc/textures`), decoded to mip0. It is the exact player-visible appearance.
- **Tile inputs:** the TC roof tile banks (`tile_R*`, `cov_R*`, class maps) from the Wanja r2 roof snapshot. TC UVs have
  not changed since (Walls R3 SOURCE_IDENTITY).
- **Location and records:** pack at `C:/work/korean-roof-canon/v1/` (move it into the library when the owner says so).
  `tc/DECODE.json` records every source hash; `EXEMPLAR.json` records the exemplar hashes and quantiles.
- **Build:** `python roof_canon.py build --pack DIR`, then `python roof_canon.py profile --pack DIR`.
- **Canonical field profile:**
  - luma mean 59;
  - roll/pan (equal-weight bins) 1.52;
  - bright/dark specks .021/.018;
  - moss-green fraction .25;
  - tangent slope p50/p75/p90 21.7/42.7/50.2 deg.

## Per roof part

| Part | Source in the canon | Method |
| --- | --- | --- |
| Tile field, and every texel with a real tile ID (also the eave receivers' top strips) | TC ROOF_TILE tiles | exemplar transfer by (roll mask, position in tile f, across-roll position a); TC tiles chosen per target tile by a rank-uniform, spatially coherent field (the TC's own mix of clean and mossy tiles); k-NN blend + canon grain where the target is denser; HIGH normal slope remapped to the canon quantiles |
| Clay caps (hip, verge) | TC roll tiles, calibrated to the TC cap mean (ROOF_TRIM, wooden ridges excluded) | the same transfer on the cap tile IDs; slope remap to the cap quantiles |
| Eave ends (discs, drip tiles) | TC EAVE_CUTOUT statistics | the TC end strips are ~55 t/u, so texel transfer would make streaks; use the analytic disc geometry (alpha, relief, seam ring) with the TC class means, spreads capped at the material level (TC end BaseColor carries baked AO) |
| Flat bake copies (rims, undersides, receiver backs: tile value .5, position 0/1, no roll) | TC pan clay mean + grain | statistics, darker where the face looks down; one-texel seam rows in receiver strips take their field neighbour |
| Wooden main ridge | not clay | building timber (KR-RIDGE-01) |

Geometry, UVs, HIGH and the bake still follow [roof ends](roof-ends.md), the assembly spec and
`blender-high-low-baking`. The canon decides only appearance.

## Features (defined identically on canon and target)

- **f:** the tile ID bake's position in tile.
- **roll:** its roll mask.
- **a:** the across-roll position inside a tile cell. Take the perpendicular to the mean gradient of f inside the cell
  and normalise it over the cell.

v1's first try used the distance to the cell boundary; it mixes along and across and printed concentric rectangles
("flat grid" in the look-dev).

## Gate and rig

- **Gate:** `roof_canon.gate(profile_target, profile_canon)` fails on:
  - any bin mean off by more than 6 luma;
  - roll/pan off by more than .06;
  - speck or moss fractions off by more than 50 % relative;
  - slope quantiles off by more than 4 deg.

  Report each failure. Never loosen a tolerance.
- **Look-dev:** `blender -b FILE --python roof_lookdev.py -- --cfg CFG`. The TC canon config binds the decoded runtime
  maps (R-flipped normals) to the TC Final A/B objects. Render the derived building with the same rig and show the
  pair.

## Evidence, Dock r4 (2026-10-10)

- **Transfer:** 474,204 field texels in 1,524 tiles, plus 424,365 flat edge texels.
- **Gate:** PASS (roll/pan 1.48, specks .015/.015, moss .22, slopes on the canon quantiles).
- **Owner corrections it fixed:** "roofs need to match town center - normal strength plus add some imperfection",
  "Why the roof edges look cheaper", "Why the roof edges have simply different texture? ... Probably disconnected UV
  islands. It looks like bug".
- **Files:** recipe `dock_roof_canon.py` (a thin preset); look-dev pair `dock_r4/canon/lookdev/TC_vs_DOCK.png`.
