---
name: aoe-uv-atlas-export
description: FOUNDATION (in progress) - turn conjoined, AO-separated UV families into final runtime texture pages for AoE3DE, e.g. one 2048 and one 1024 map, split by material (alpha eaves, ridges and roof on the small map) at ONE uniform texel density maximised by bisection, with runtime gutters; write the final UV layer and page materials and bake AO into the real pages. Use after blender-uv-ao-separation when preparing the final atlas/UV map for export, choosing page sizes, or balancing materials across textures.
---

# Final UV atlas: pages at one density (foundation)

Pipeline: [blender-clean-uv](../blender-clean-uv/SKILL.md) -> [blender-uv-conjoin](../blender-uv-conjoin/SKILL.md)
-> [blender-uv-ao-separation](../blender-uv-ao-separation/SKILL.md) -> **this skill** ->
[aoe3de-building-export](../aoe3de-building-export/SKILL.md) (GR2, materials, DDT).

## Budget first, freeze last

Estimate the page budget (step 0 of the [pipeline order](../blender-architecture-texturing/references/pipeline-order.md))
before UV or bake work starts, not when this skill runs: the Korean TC found its reserved area at
122% of the pages only after roof and window bakes existed, and those bakes were lost. The
`UV_Final` this skill writes is the layer the owner freezes; production bakes come after the
freeze (`uv_fingerprint.py record`), never before.

## Rules (owner decisions, 2026-09-28)

- Split **families**, never faces: owner and members share texels, so they share a page.
- **One texel density on all pages.** Maximise the uniform scale s (runtime texels per
  working texel) by bisection; never downscale one page to make the split work.
- Material-based assignment: the small page takes, in priority order, alpha-bearing
  eave cutouts (must fit - alpha page), ridges, then solid roof tiles "as much as
  possible"; everything else goes to the large page.
- Gutter in RUNTIME texels (4: DXT 4x4 blocks plus mips), converted to working texels
  per trial scale.
- Keep original chart sizes until this step; only this step scales (uniformly).

## Workflow

1. `families()` from blender-uv-conjoin with the AO `compat` from blender-uv-ao-separation.
2. `pages.best_split(charts, owners, PAGES)` then `pages.emit(...)` -> per face
   `{page, uv in [0,1] of that page, family, owner}`.
3. In Blender: write `UV_Final`, one material per page (face material index = page),
   bake AO once per owner into the real page images (blender-uv-ao-separation
   `bake_owner_ao.py` with the `pages` config).
4. Review: texture split (mata / matb / matc colours), family colours, white AO model,
   density checker. **Standard density checker (all models, owner decision 2026-09-28):** Blender's generated
   Color Grid (`generated_type='COLOR_GRID'`, the "Orientation checker" GPT Astra and
   `blender_ao_review.py` use), generated at EACH texture's own resolution (2048 map -> 2048 grid,
   1024 -> 1024, 512 -> 512, 4096 -> 4096), mapped straight through that map's UV layer with
   Closest interpolation. One checker pixel is one real texel, so density is read on the model,
   not guessed; equal pixel steps across maps mean equal density.
5. UDIM inspection view: one layer `UV_UDIM` with tile 1001 = mata, 1002 = matb, 1003 = matc
   (u offset per page), tiled images at each tile's real resolution (UDIM_Families = family
   sheets, UDIM_AO = baked AO, UDIM_Checker = native Color Grids), so every texture is
   inspected on the model and in one UV editor. Korean TC: `build_udim.py` (S18d).
6. Report density against vanilla with the same formulas: island density
   sqrt(UV area x page pixels / 3D area) (median, p10-p90) and effective density
   sqrt(used texels / visible 3D area). Korean TC S18c: 107 island / 85 effective vs vanilla
   TCs 116-139 / 77-92 (a bit below / same level).

## Korean TC result (S18c, measured)

2048 (mata) + 1024 (matb) + hidden 512 (matc). Every visible face at a uniform
**107 texels/unit** (p10-p90 107-112), effective 85. Vanilla town centres: island 116-139,
effective 77-92 -> a bit below / same level. 1024 map: all eave cutouts, all ridges, 39% of
roof tiles. Before restoring 225 charts that S12 had parked at hidden-page density, 17.6%
of the visible area sat at 15 texels/unit - always measure the p10, not only the median.

## Not yet covered (next work)

- Export handoff: GR2 conversion and AoE3DE `.material` files per page, DDT formats
  (DXT5 for the alpha page, DXT1 otherwise), mip settings - via aoe3de-building-export.
- Exact-shape packing (nesting into concavities) to raise fill above ~75%.
- Normal/colour texture authoring on the pages; page sizes other than 2048 + 1024.

## Tools

`scripts/pages.py` - `assign_pages`, `best_split` (bisection on s), `emit`.
