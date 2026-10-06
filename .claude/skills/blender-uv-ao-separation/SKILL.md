---
name: blender-uv-ao-separation
description: AO-aware UV conjoinment - measure ambient occlusion per face at the texels faces share, keep a face on its family's texels only if its AO matches point-to-point, split dark or shadow-marked faces (windows, dots, beam ends, contact corners) and re-group them with faces of similar AO; bake AO once per owner and verify on a white model against a unique-texel reference. Runs after blender-uv-conjoin, before aoe-uv-atlas-export. Use when baking AO onto stacked/shared UVs, when a baked model shows ghost shadows, dark stains or missing contact shadows, or when asked to "separate by AO".
---

# AO separation for conjoined UVs

Pipeline position: **clean charts** ([blender-clean-uv](../blender-clean-uv/SKILL.md)) ->
**conjoin** ([blender-uv-conjoin](../blender-uv-conjoin/SKILL.md), explicit region policy) -> **this skill** ->
**pages and export** ([aoe-uv-atlas-export](../aoe-uv-atlas-export/SKILL.md)).

Why: one baked texel serves every face stacked on it. Plain T3 on the Korean TC put wrong
AO on 46% of member texels - black streaks on roofs, ghost dots on wall bands, dark
beam-end faces. See [results and lessons](references/results.md).

## Workflow

The AO sampled in steps 1-3 is a measurement for deciding families, not a deliverable.
Re-grouping moves charts: existing bakes on the previous layout become invalid - list them
for the owner first ([pipeline order](../blender-architecture-texturing/references/pipeline-order.md)).

1. **Sample AO** (Blender, background): `scripts/ao_sample.py config.json`.
   Grid samples every 12 texels of the conjoined UV layer plus a barycentric lattice on
   every triangle (small faces always get ~10 points), 256 cosine-weighted rays, radius
   0.5 unit, the whole assembly (hidden parts too) as occluders. ~345k samples in ~1 min.
2. **Attach** (host): `attach_ao.attach(faces, 'ao.json')` puts samples into each face's
   own development coordinates.
3. **Split the saved parent families with the AO test**. Consume the pre-AO sharing
   plan; never restart global matching or use AO to retroactively veto phase one.
   If calling `conjoin.families(..., compat=lambda m, o, M:
   ao_compat.compatible(m, o, M, 'points'))`, run it within each parent family and
   retain the exact geometric correspondence. A chart joins an AO variant only if, at every
   corresponding point under the exact map M, its AO matches the owner's:
   95th percentile of |dAO| <= 0.08 AND every point <= 0.20 in the existing recipe.
   These are calibrated recipe values, not universal units-independent thresholds.
   Missing evidence on any face or unmatched member samples rejects sharing; no
   fallback to means can authorize it. Keep whole charts as AO variants. Explicit
   subregions require lineage and renewed chart-continuity checks. Compare every
   member to its actual owner; do not infer transitive compatibility.
4. **Bake once per owner** (Blender): `scripts/bake_owner_ao.py config.json` - owner faces
   are bake targets, every other face exists once as occluder.
5. **Verify before showing anyone**: white model textured with the bake vs a unique-texel
   reference bake (every face its own texels), same cameras including low close-ups of
   eaves, beam ends and wall bands; plus a risk view (members coloured by their measured
   p95 mismatch: green <= .08, yellow <= .15, red above).

## Rules

- **Authorized AO simplification is an explicit alternative, not a threshold
  bypass.** First retain the strict measurement and exact geometric parents.
  For a selected parent, form the UNION of conflicting regions in common owner
  coordinates. Force AO to neutral (1) there on every stacked owner/member,
  preserving measured compatible AO elsewhere. Record source hashes, correspondence,
  mask, affected faces, actual area saving and visible loss of contact shadows.
  Missing correspondence cannot be repaired by a neutral-mask claim.
  Compare the least destructive candidate that fits the owner's density allowance;
  additional AO removal is a separate visible trade-off.
- Apply the mask **before** AO is multiplied into BaseColor or written to Masks.R.
  An AO mask cannot remove shadows already baked into BaseColor, nor dirt/roughness
  or tangent-space normal differences. Preserve those independent channels.
  `scripts/neutralize_ao.py` validates equal image dimensions and normalized values.
  A prepared mask is not an applied bake: final owner/reference and mip checks
  remain required. Localize edge padding; do not bleed into neighboring banks.

- Consume and produce [workflow checkpoints](../blender-uv-workflow/SKILL.md):
  family colors before AO, then mismatch heatmaps and resulting variants.
- Record LOW revision, correspondence, occluder list/transforms, opacity policy,
  radius/units, sample count and seed. Common baker name matching and AO secondary
  ray matching are separate controls. Assembly changes invalidate assembly AO.
- **One explicit triangulation:** receiver interpolation and occluder BVH must use
  the same `mesh.loop_triangles` (including identical transforms). Never feed raw
  nonplanar quads/ngons to a BVH while sampling Blender's different tessellation.
  Run an isolated warped-quad outward-ray check before full AO. INC-091 produced
  false full-dark roof samples through sub-millimetre self-hits; increasing the
  ray offset hides the defect and is not its fix. Cache identity includes the
  triangulation and recipe, not merely the original polygon list.
- Deliver a pilot map/heatmap before whole-model separation; deliver each model's
  resulting UV sheet before the next edit batch. Follow the workflow's partial
  gates, and label samples versus final owner/reference bakes explicitly.

- Compare at points, never per-chart averages or coarse bins. A 6x6 fingerprint passed
  wall bands with ghost dots and beam ends with foreign shadows; the mean test passed
  windows. Point-to-point = a virtual subdivision of every face without touching geometry.
- The per-point limit (0.20) is about 7x the ray noise at 256 rays (sigma ~0.02-0.03);
  lower ray counts need looser limits or they split on noise.
- AO separation can add islands and owned area. Measure the growth and gutters;
  do not equate family count with cost or assume a fixed multiplier. Keep capacity
  provisional until measured, per [the capacity protocol](../blender-uv-workflow/references/sharing-and-capacity.md).
- The space gate (blender-uv-conjoin audit) counts AO-separated charts separately from
  charts that simply found no geometric match.

## Tools

`scripts/ao_sample.py`, `scripts/attach_ao.py`, `scripts/ao_compat.py` (tests D1 mean,
D2 p95 bins, D3 SSIM, D4 classes, D5 combined, **D6 points - default**), `scripts/bake_owner_ao.py`.

Warped-quad regression: run background Blender with
`--python scripts/check_triangulation_blender.py`. It reproduces implicit-BVH
self-hits and requires zero outward self-hits with explicit receiver triangles.
