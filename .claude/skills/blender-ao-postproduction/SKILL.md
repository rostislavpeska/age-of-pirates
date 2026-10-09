---
name: blender-ao-postproduction
description: Resolve and verify baked AO for shared architectural UVs using explicit texel owners, reference correspondence and localized neutral masks. Use after AO conflict analysis and before texture generators, channel packing or final UV handoff.
---

# AO postproduction for shared UVs

Consume the current geometry/UV HANDOFF, exact sharing correspondence, unique
reference bake and the consumer's fixed page budget. This is the processing step
after [AO separation](../blender-uv-ao-separation/SKILL.md), coordinated by
[the UV workflow](../blender-uv-workflow/SKILL.md). It does not unwrap or silently
add pages. All trials run in background; follow the
[operator boundary](../blender-uv-observability/SKILL.md).

## Select the treatment from measured evidence

1. Compare each reader against its actual owner at corresponding surface points.
   Record recipe, source hashes, triangulation and excluded degenerate surfaces.
   Means and a lighter-looking owner cannot establish compatibility.
   For a repair comparison, preserve the reference mesh's vertex connectivity,
   triangle order, normals and diagnostic coordinates; edit only the intended
   vertices. Rebuilding the same visible triangles with one vertex per corner
   is not an equivalent baker input. Korean Houses, 2026-10-09: disconnected
   diagnostic triangles changed even unchanged-roof AO; preserving the original
   indexed reference restored pixel-identical roof AO. Record such a trial as
   invalid evidence rather than treating its new conflicts as a UV requirement.
2. If differences matter, keep a distinct AO variant and remeasure capacity; or
   prepare a clearly labelled common neutral-mask candidate. Human acceptance of
   that contact-shadow loss is separate from numerical correctness. Work can
   continue on a reversible candidate when the operator authorized it.
3. For neutralization, union conflicting regions in OWNER coordinates and apply
   that same mask to all readers. Preserve compatible AO. Missing correspondence
   is an unresolved failure, not evidence that neutralization succeeded.
4. Reproject the reference to the final production coordinates or bake explicit
   owners once with the entire original assembly as occluders. One owner writes
   a covered texel. UV stacking order cannot select that owner.
5. Verify the white production-mapped models against the unique reference from
   fixed front/back/underside views, including roof ends, lattice and contacts.
   Keep the diagnostic atlas out of the ordinary operator workspace.

## Scalar math and texture effects

AO is normalized linear scalar data, loaded as Non-Color. With neutral mask M:
`resolved = (1-M)*owner_AO + M`. Neutral AO is 1. N shared readers do not apply AO
N times: 0.8 stays 0.8. Never compensate by reader count. Only a proven chain of
the SAME AO multiplied k times admits the inverse `value**(1/k)`; regenerate the
clean raw channel instead whenever possible.

An optional art strength is `1-s*(1-resolved)`, with the chosen s recorded.
Do not multiply AO into BaseColor and then multiply it again through the shader.
Keep an effect ledger: raw mesh-map source, resolved source, generators reading
AO, exported storage channel and actual shading applications. A dirt generator
reading AO is not necessarily a direct multiply; inspect its output separately.

In Painter, use the resolved map for all intended mesh-map consumers. Painting an
AO correction alone does not guarantee generators consume that correction. The
AO painting channel defaults to Multiply: neutral white will not erase existing
darkness. Use Replace for that channel and the documented Normal layer blend,
then verify exported pixels. See the
[AO handoff research](../blender-uv-workflow/references/ao-handoff.md).
Do not change roughness, normal, opacity or player-colour channels as an AO repair.
Existing shared textures remain protected; unique assembly shadows cannot be
added underneath unrelated readers without their resource owner's approval.

## Executable processing and QC

`scripts/resolve_ao.py INPUT.json --out OUTPUT --padding N` consumes:

- `size: [width,height]` from the consumer profile, never a skill default;
- `references: {id: image_path}` containing raw grayscale linear AO;
- `triangles`: `chart`, `owner`, `resource`, `house` (reference id),
  `production_pixels` (three bottom-left pixel coordinates), `reference_uv`
  (three normalized bottom-left coordinates), with source identity retained;
- `excluded_nearzero_triangles`, if any, with measured 3D area and disposition.

The helper uses pixel-centre barycentric interpolation. It retains raw owner AO,
common masks, processed AO, coverage, writer/reader counts and float evidence.
Thresholds .08 p95 / .20 maximum reproduce the existing recipe; recalibrate for a
different baker/radius/noise level. It flags missing coverage and subpixel owners;
those findings prevent a final pass. Near-zero exclusions require explicit
geometry disposition. Raster correspondence does not prove continuous-surface
or higher-resolution agreement. Low-resolution source bakes limit the result.

Padding uses the nearest covered owner and a bounded distance; choose a margin
that fits measured chart gaps. Recheck at consumer mip levels and compression.
Repacking invalidates page coordinates: preserve unique masters and reproject
again. This script does not authorize a layout change or claim runtime QA.

Deliver raw and processed AO, masks, source/correspondence hashes, page sizes,
effect ledger, decisions, white-model views, excluded-area report, mip results
and HANDOFF. Say separately: file verified, delivered, accepted, freeze-ready.
Run `python -m unittest discover -s .claude/skills/blender-ao-postproduction/tests -v`.
