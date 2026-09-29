---
name: blender-uv-ao-separation
description: AO-aware UV conjoinment - measure ambient occlusion per face at the texels faces share, keep a face on its family's texels only if its AO matches point-to-point, split dark or shadow-marked faces (windows, dots, beam ends, contact corners) and re-group them with faces of similar AO; bake AO once per owner and verify on a white model against a unique-texel reference. Runs after blender-uv-conjoin, before aoe-uv-atlas-export. Use when baking AO onto stacked/shared UVs, when a baked model shows ghost shadows, dark stains or missing contact shadows, or when asked to "separate by AO".
---

# AO separation for conjoined UVs

Pipeline position: **clean charts** ([blender-clean-uv](../blender-clean-uv/SKILL.md)) ->
**conjoin** ([blender-uv-conjoin](../blender-uv-conjoin/SKILL.md), T3) -> **this skill** ->
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
3. **Re-conjoin with the AO test**: `conjoin.families(..., compat=lambda m, o, M:
   ao_compat.compatible(m, o, M, 'points'))`. A chart joins a family only if, at every
   corresponding point under the exact map M, its AO matches the owner's:
   95th percentile of |dAO| <= 0.08 AND every point <= 0.20. Split charts automatically
   join other families whose AO matches (greedy, largest owner first).
4. **Bake once per owner** (Blender): `scripts/bake_owner_ao.py config.json` - owner faces
   are bake targets, every other face exists once as occluder.
5. **Verify before showing anyone**: white model textured with the bake vs a unique-texel
   reference bake (every face its own texels), same cameras including low close-ups of
   eaves, beam ends and wall bands; plus a risk view (members coloured by their measured
   p95 mismatch: green <= .08, yellow <= .15, red above).

## Rules

- Compare at points, never per-chart averages or coarse bins. A 6x6 fingerprint passed
  wall bands with ghost dots and beam ends with foreign shadows; the mean test passed
  windows. Point-to-point = a virtual subdivision of every face without touching geometry.
- The per-point limit (0.20) is about 7x the ray noise at 256 rays (sigma ~0.02-0.03);
  lower ray counts need looser limits or they split on noise.
- AO separation costs page space honestly: expect several times more families. Judge it
  with the export skill's uniform runtime density, not by family count.
- The space gate (blender-uv-conjoin audit) counts AO-separated charts separately from
  charts that simply found no geometric match.

## Tools

`scripts/ao_sample.py`, `scripts/attach_ao.py`, `scripts/ao_compat.py` (tests D1 mean,
D2 p95 bins, D3 SSIM, D4 classes, D5 combined, **D6 points - default**), `scripts/bake_owner_ao.py`.
