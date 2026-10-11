---
name: alpha-cutout-texturing
description: Alpha cut-out surfaces on game building atlases - ragged thatch, straw and reed eaves, tile-eave scallops, fringes, lattice and railing holes, leaf cards. Covers what the engine actually draws (cutout material defs, single-sided), analytic silhouettes, thick slabs cut THROUGH with one folded parameterisation (no leftover rim, seams that match by construction), colour under alpha, gutters and mips, hidden surfaces behind cuts, the single-sided review and variant review. Use when an alpha edge shows a leftover rim, edge or "redundant corner", when seams on a thick alpha slab do not match, when a cut shows the wrong thing through it, or before texturing any new cut-out.
---

# Alpha cut-out texturing

Built on the Korean Market stall thatch and eave rounds of 2026-10-11, where the owner reported "the seams are not
matching... the corner is redundant" on a 13 cm straw slab, and an eave band that only the viewer drew. The core rule:
**the geometry and an analytic mask own the silhouette; the image model only paints colour.** A cut is one function of
the surface's own coordinates, so it runs through every face of a thick part.

## 1. What the game draws

- **Only a cutout material def cuts.** The `.material` def decides what BaseColor alpha does: `*cutout*` (and
  `speedtree\*`) cut; `default`, `default_doublesided` and `destructible` ignore alpha and draw a solid card
  ([aoe-xml](../aoe-xml/SKILL.md) rule 8). Copy the donor's def per submaterial.
- **Single-sided.** The game culls back faces unless the def is double-sided. Through a cut you see whatever FRONT
  faces lie behind it, never the inside of the slab.
- **Pages.** Cut-outs live on the small alpha page (DXT5 BaseColor alpha); the large page stays opaque (DXT1)
  ([blender-uv-workflow](../blender-uv-workflow/SKILL.md), alpha on the small page).

## 2. The silhouette is analytic

- Build the cut from geometry or a seeded mask: per-strand straw tips (`fringe_depth`: low-order sines plus a per-strand
  power-law tail, 2-14 cm deep), tile scallops from the tile row, lattice holes from the panel's bars. Never let the
  painting decide where the alpha is.
- Hand the image model the layout with the cut region flat, and gate the painting on its structure (strand direction,
  rope recall, silhouette registration) before composing ([masonry-texturing](../masonry-texturing/SKILL.md) section 7,
  [image-harness](../image-harness/SKILL.md)).

## 3. Thick parts: cut through, not skin-deep

A thatch or straw eave is usually a slab: one profile (top, back, underside, often a rounded bullnose) extruded along the
eave, with two end caps. Texturing each face in its own frame produces two defects at once:
- **seams** where neighbouring faces sample unrelated parts of the painting;
- **a leftover rim** where the top is cut but the nose and underside stay opaque. The rim reads as a "redundant corner"
  under the fringe.

Use one folded parameterisation for the whole slab ([`scripts/slab_fold.py`](scripts/slab_fold.py)):

1. **Inspect the profile.** Run [`scripts/slab_profile_map.py`](scripts/slab_profile_map.py) in background Blender. It
   writes the per-face page px to 3D maps, the outline in slab coordinates (lip first, top first, a rounded nose ending
   at the lip) and the shared edges.
2. **Assign one coordinate pair.** `v` is the slope coordinate of the nearest outline point. Top and underside both read
   `v = s`, so the straw seen from below lies under the straw seen from above. The nose takes its inner vertices by arc
   length, so `v` stays monotone.
3. **Let the end caps continue the top.** Use `us = u + depth x (1 - 2u/W)`. The end caps then carry the top's straw
   straight down over the end, and the shift meets the underside, back and nose on the same columns. Folding the caps at
   mid-thickness was also continuous, but the mirrored straw angles read as a herringbone.
4. **Apply one cut function `cut(us, v)` to every face.** The fringe then removes the nose and the front of the
   underside together with the top's tips.
5. **Choose a variant per part.** Use the cut fringe for a thin, light eave. Use a rolled eave (no cut; the straw
   wraps the nose with `v` mirrored at the lip) where a thick edge is wanted.

At grazing angles a slab cut through can look hollow: you see its far side's back faces culled. At RTS camera pitch the
top hides it; check the low review view anyway.

## 4. Seam QA (fails the run)

`slab_fold.py qa --profile PROFILE_MAP.json --basecolor PAGE_BaseColor.png` compares the colour step across every shared
edge with the same-distance step inside the two faces: bilinear sampling, 6 and 18 mm inside each face, only where all
four samples are opaque. Pass: each edge ≤ 2.0×, mean ≤ 1.3×.

On the Market stall: the old per-face compose scored mean 3.37 and worst 17.3 (end cap against bullnose), which fails.
The fold scored .87 and 1.26, which passes. Keep the strand-direction QA as well
([blender-architecture-texturing](../blender-architecture-texturing/SKILL.md) `check_material_direction.py`).

## 5. Colour under alpha, gutters and mips

- Cut texels keep the material colour sampled just inside the cut, never the painting's background. Bilinear filtering
  and mips average across the cut, and a grey or dark background grows a halo round every strand tip.
- Extend each island's colour into its gutter. Refresh gutters at least ~48 px out before a Lanczos mip writer
  ([aoe3de-building-export](../aoe3de-building-export/references/textures-xml.md), gutters before mips).
- Alpha-tested fringes thin out in lower mips, because averaging moves texels below the threshold. Before shipping,
  measure the opaque fraction of each fringe region at every mip level of the encoded DDT. If a fringe vanishes at game
  distance, preserve the coverage when building the alpha mips. This has not yet been verified on the project encoder.

## 6. Normals on a folded parameterisation

Sample the relief height through the same fold, then differentiate it in **page space**. Page space is already the UV
tangent frame (x = +U, y = +V, page rows run down), so this stays exact on folded end caps, where a per-face sheet-to-UV
rotation is only approximate. Match the relief scale to the previous accepted map's measured slope.

## 7. Hidden surfaces behind cuts

A face classified hidden (backing atlas) can still show through a cut. Run
[blender-uv-workflow](../blender-uv-workflow/SKILL.md)'s `alpha_backing_check.py` on every alpha page.

## 8. Review and variants

- **Single-sided review:** set `use_backface_culling` on every review material, with the alpha blend or clip mode the
  game uses. A double-sided viewer showed back faces plugging every eave scallop that is open in game, so the owner saw a
  solid band.
- **Views:** render each cut-out part from the top, owner (RTS pitch), low front, side (end caps) and eave front.
- **Variants:** when the owner asks for options, compose each variant into its own copy of the page and publish it as
  its own scene. Every variant must pass the seam and direction QA before it is shown.

## Failure log (Korean Market stall thatch, 2026-10-11)

| Defect | Cause | Fix |
| --- | --- | --- |
| Straw stood upright on the end caps | A vertical frame on the end caps, 70° off the fall line | Direction QA against the fall line |
| Seams (owner) | Each face had its own frame: caps shifted by .37 of the sheet, edges painted as end grain | One folded parameterisation |
| A redundant rounded edge under the fringe (owner) | The cut was skin-deep; the opaque bullnose remained | Cut through the slab with one `cut(us, v)` |
| Herringbone on the end caps | The caps were folded at mid-thickness, mirroring the straw angles | Carry the top's straw straight down the cap |
| A solid band behind the eave scallops | The review viewer was double-sided | Single-sided review |

Worked example (project recipes): Korean repo `research/Junction_TestBed_21/market_r1p/recipes/market_thatch_fold.py`
and the card `patterns/korean/thatch.md`.

Run the fixtures from this skill's `scripts/` folder: `python -B -m unittest test_slab_fold -v`.
