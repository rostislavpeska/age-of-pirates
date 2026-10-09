---
name: aoe3-texture-weathering
description: Give an existing Age of Empires III DE building atlas a premium, illustrative AoE3 look by texture-only weathering - measure vanilla JP/CN references, build a per-texel mask kit from the model, paint per-feature recipes (two-coat plaster relief, rising damp, rips, hanji, iron-fitted doors, lacquer wear, stone, roof moss overlays, a player-colour budget), compose with relief normals and gutter refresh, and judge with an art critic, a senior-artist judge and QA before encoding. Use when textures look "too clean / too perfect / too geometric / generic", when asked for imperfection, mould, damage, AoE3 essence or premium look on an existing UV-frozen building, or when player colour looks artificial.
---

# AoE3 texture weathering (texture-only, UV-frozen atlases)

Built on the Korean Barracks/Stable/Town Center night run of 2026-10-08 (r70a -> r70b -> r70c), where a
senior-artist judge moved from "generic" to vanilla level on doors, hanji, lacquer and coping in three
rounds. Owner rules that shaped it: texture-only (no UV reorganisation), Painter is never upgraded,
no Blender procedural shader materials for the look, paper darker than walls, roof bake protected.

## 1. Measure the target, do not guess it

Extract and decode the vanilla counterparts (bar-extract; `scripts/ddt2png.py` decodes DXT1/DXT3/DXT5)
and measure every feature crop with `scripts/colourstats.py` (luma mean/sd/p5/p95, saturation, Lab
chroma/hue, warmth R-B, high-pass and low-pass sd, stain fraction, moss fraction). Compare the same
metrics on the asset. [vanilla-targets.md](references/vanilla-targets.md) holds the measured 18-atlas
JP/CN table and the ten rules derived from it; re-measure for other cultures.

## 2. Map features to texels before painting

Rasterise the runtime UV layer (V flipped: x = u*W, y = (1-v)*H) into per-feature masks, stack counts
(faces per texel, visible faces) and visibility. Then build a per-texel kit: feature id, chart cell,
height inside the face (`h_local`, dominant-orientation `h_dom`), world-up vector in pixel space,
edge distance, world normal z, curvature (bake and from the normal map), AO, stack/visibility.
Verify by overlaying arrows and gradients and LOOKING. Stacked cells often mix orientations
(a Korean hall cell held 40 faces in three directions, one end wall rotated 180 deg), and owner faces can
be upside down in the atlas: never assume image-up is world-up. Details: [recipe-contract.md](references/recipe-contract.md).

## 3. Paint per feature, under a contract

One recipe per feature writes `__BaseColor`, a binary `__claim`, optional `__Height` (16-bit relief),
and for player colour a `__Details`; outside its claim it is byte-identical. Hard rules learned:

- **Stack guard:** on texels shared by >= 3 visible faces paint no discrete marks (holes, cracks,
  rips, mould blobs); use low-frequency gradients and fine grain. Marks repeat as stamps otherwise.
- **Hierarchy:** a calm field with dirty edges. Keep relief and speckle near frames and the base,
  leave 30-40 % of a panel quiet; core-minus-ring luma +15..+25, dirt marks p90 10-15 texels.
  Edge bands are min(25 px, 15-20 % of the panel's short side), and every zone mask is feathered
  over 30-60 px with noise: a mask stepping over 3 rows printed a straight seam on all 21 faces of a
  stacked cell.
- **Plaster:** the owner's Elector recipe - lighter cream top-coat islands over a warmer, darker
  under-coat, island edges feathered in BaseColor and raised in the normal map. Source the islands from
  the Painter white-coat Dirt run ([white-coat Dirt relief](../substance-painter-remote/references/whitedirt-relief-9.1.2.md)).
- **Rips:** exposed rubble 25-40 L darker than plaster, shadow only on the upper/inner edge, a light
  chipped lip, crumbs; never a closed dark contour; only at wall feet and corners.
- **Paper:** clearly darker and warmer than the adjacent plaster (gap >= 25 L), tea stains, grime halo
  along the lattice.
- **Roof moss** on a protected bake: overlay only, DARKER than the tile (vanilla), broken into pads
  hugging channels, AO-driven opacity, no straight edges along tile courses. On dark neutral slate it
  also needs chroma (C* 16-19, hue 105-115): darker moss at C* ~12 reads as soot and the roof looks
  unchanged at game zoom; lighter-than-tile moss reads as lime paint.
- **Player colour:** copy the building set's existing pattern first (e.g. the Town Center's player-colour
  plank panel between wood beams), then check the vanilla budget 0.6-4 % (median 2.1 %), stack-weighted;
  paint the base under it lighter than bare wood with worn edges (aoe3de-player-colour).

## 4. Compose, relieve, refresh

Apply claims by priority; refresh gutters within the asset's declared padding and nearest-owner
territory. A 48 px dilation is appropriate only when that space is reserved; never overwrite another
chart or silently repack a frozen atlas to reach it. Test the actual mip filter and report remaining
bleed where the available margin is insufficient. Turn the
merged height into a detail normal in the SOURCE convention, blend with RNM, then apply the transform
the installed DDT uses for that atlas ([re-encoding rules](../aoe3de-building-export/references/textures-xml.md)). Prove
the codec reproduces the installed DDT byte-for-byte before encoding new maps.

## 5. Judge before shipping

Render matched views under the game's own lightset (read the map's `.lgt`: sun colour/inclination/
rotation, fill, hemisphere top/bottom, shadow colour, exposure) and at game zoom (600-900 px building
height). Run three independent reviewers: an art-direction critic (per feature, parameter-level fixes),
a strict "senior AoE3 environment artist" judge (scores + five notes with accept criteria), and QA
(alpha identity, protected regions, claims, Details scope, mip halos, stacked repetition, normal sign
against an independent gradient, DDT dry run). Iterate on the ranked notes; keep each round time-boxed.
An agent result is never owner acceptance; publish as a candidate.
