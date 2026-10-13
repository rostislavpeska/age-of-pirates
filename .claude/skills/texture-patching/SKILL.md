---
name: texture-patching
description: Repair a localized flaw on an accepted texture atlas using a masked, pattern-aligned patch. Preserve existing UVs and prove that pixels and channels outside the repair remain unchanged.
---

# Texture patching: minimal, contained, provable

Owner 2026-10-11 (Korean Market game test): "Simply find out how to patch things like this. Patching can be useful for
minor flaws and can save tokens, because bake and re uv is difficult process". Then "I think you cause more harm than
fix!!!", "More reasoning. How to patch minimally invasively", "Without roof texture regression which is visible now!!!".

## The rule

**A patch changes only the flaw, and proves it.** Repainting whole surfaces, running broad automatic passes or
re-baking to fix one visible spot puts the accepted rest of the page at risk.

## Saved scope and repeated execution

Consume the current asset recipe: source hashes, selected physical faces/edges,
their actual UV/material/page mapping, all shared readers, the repair mask and
authorized channels. The generic `apply` tool consumes a supplied mask; it does
not discover a defect or generate a two-sided junction mask automatically. For
roof junctions use [the local repair route](../blender-roof-baking/references/workflows.md#local-repair-on-existing-uvs).

Before composing, inspect the selection on the current 3D model and atlas. A
disconnected island is not a reason to move it. Keep both sides of a junction
and every other user of changed pixels in scope verification. If their desired
values conflict, report those readers and a compatible bounded alternative;
do not silently enlarge the patch, relocate UVs or omit a side.

Save the command, offset/period, mask hash, channel choices, source identities
and protected-output comparisons in the existing recipe. Re-run from the pinned
baseline into fresh output, never by repeatedly patching the last candidate.
Normal copying requires compatible tangent frames; an arbitrary rotated or
mirrored transfer is not implemented by the fixed-offset clone operation.

## Method

1. **Base = the maps the owner already accepted in game.** Never patch a working copy that may carry other, unreviewed
   edits. The Market's working `final` carried earlier broad roof passes; patching it shipped a regression.
2. **Find the flaw's cause before choosing a patch.**
   - Ray-pick the render pixels that show it and map them to page texels through the hit face's UVs.
   - Read the actual BaseColor, Normal and Masks values at those texels.
   - Check the geometry for holes: boundary edges.

   Market: no hole and no UV island break. The dark texels were the field's ordinary tile PAN (16 of the 27 px
   period) lying exactly alongside the hall's corner ridge caps, where the caps run parallel to the tile columns.
3. **Mask = only the flaw**, in 3D terms where possible: a distance to the object that should hide it (Blender BVH,
   field texel → 3D through the face's px → 3D map), and only where the cause applies. Market: 4 mm–9 cm from the
   hall corner ridge caps, and only where the cap is parallel to the tile columns. On the 45° rounded hips the pan
   never runs alongside, and patching there only made mismatches.
4. **Patch = the page's own texels, copied from a pattern-aligned offset.**
   - Measure the period inside a clean window (`scripts/texture_patch.py period`).
   - A whole period keeps the pattern in phase, which hides a stain.
   - Half a period swaps rolls and troughs, which covers a dark trough.
   - Copy BaseColor, Normal and Masks together. A pure UV translation keeps tangent-space normals valid; a rotation or
     mirror would not.
   - Skip a texel whose source lies inside the flaw.
5. **Prove containment.**
   - Every changed texel is in the mask.
   - Every other texel, and every other map, is byte-identical to the base.
   - Deliver a before/after render at the owner's view.

   Market: about 10k texels on P0 BaseColor/Normal/Masks; the other 5 DDTs byte-identical to the shipped r1.
6. **Make it reproducible.** Put the patch in the build chain as the last step on that page. The chain must then
   rebuild the shipped maps byte for byte.

## What not to do (Market, 2026-10-11, each shipped or rendered and rejected)

| Attempt | What went wrong |
| --- | --- |
| A lime-mortar bed painted along every hip cap | "extra stripe around the ridge": new colour reads as a new feature |
| An AO floor over 734 roof faces | broad change to accepted texels |
| Strip mirroring, speck fills, edge-band mirroring on every face edge | mirrored troughs into rolls inside continuous fields: bright streaks |
| A 6 px shift | below half the 27 px period, so it copied the same trough |
| A gradient-direction shift on diagonal hips | broke the tile alignment |

## Tool

`scripts/texture_patch.py`:
- `period` measures the pattern period along a page axis;
- `apply` takes a mask `.npz` (x, y, d), full/fade distances and either a fixed offset or a shift along the mask's
  distance gradient. It skips self-copies and fails above 50 %.

The Market's exact recipe, a fixed ±x half-period shift on the 3D-measured mask with the containment proof, is
`korean-buildings-blender` `research/Junction_TestBed_21/market_r1p/recipes/market_hip_pan_patch_min.py`.
