# Bounded roof workflows

Use only the route needed by the request. These procedures compose existing
tools; they are not a new runner or proof of end-to-end automation. Store the
asset recipe and evidence using [capability-authoring](../../capability-authoring/SKILL.md#repeatable-and-tunable).
Project guides choose forms; set profiles choose finish. Neither changes scope.

## Local repair on existing UVs

1. Pin the current accepted model and maps. Identify the physical defect and both
   sides of the junction. A manually selected face/edge set is valid when saved
   against the source hash. Read-only diagnosis must not mutate the selection's
   geometry, UVs, normals, materials or texture dimensions.
2. Save face/triangle, material/page and UV-corner correspondence. For a boundary
   across split islands, use [paired-surface probes](paired-surface-probes.md).
   Match in a common physical frame, never by island proximity. Retain every
   endpoint reader and other surface using affected pixels, including relevant
   model states. The helper does not extract the selection or build its mask.
3. Inspect the current model and actual atlas together through
   [UV observability](../../blender-uv-observability/SKILL.md). Label selected
   sides and shared readers consistently. Do not show proposed new UV positions
   as though they locate the defect. Distinguish field, end, underside and trim.
4. Diagnose the responsible channels from the baseline. Sample retained stages
   before blaming a patch. Save a physical-region mask projected independently
   into each existing island; preserve all intended readers. Mask generation
   across an actual building remains an integration step to verify, not an
   automatic capability established by the pairing fixtures.
5. Apply [texture-patching](../../texture-patching/SKILL.md) to a fresh candidate.
   Where source and destination tangent frames differ, a normal RGB copy is not
   a valid transfer; establish the transform or leave that channel unchanged.
   Preserve tube/pan identity and phase across the junction. A valley repair
   covers both matching faces; suppressing one face is not a compatibility fix.
6. Verify containment, protected readers, paired views and changed channels.
   If alpha changes, use [alpha-cutout-texturing](../../alpha-cutout-texturing/SKILL.md)
   before/after encoding. If alpha is unchanged, prove identity and preserve
   known release holds rather than inventing a new silhouette. Inspect actual
   compressed mips for the changed region. Patch QA does not waive an inherited
   whole-model release defect.
7. Publish baseline/candidate in the agreed Blender review and record readback.
   A diagnostic, numeric PASS or saved file is not visible art acceptance. Retain
   the previous accepted version; require approval where the task specifies it.

If shared pixels cannot support the proposed patch, report the exact faces,
pixels, channels and conflicting requirements. Try only a bounded compatible
texture alternative within scope. UV relocation, extra pages or geometry are
separate proposals, not automatic fallbacks.

## Finish adjustment with existing bakes

Use [texture weathering](../../aoe3-texture-weathering/SKILL.md) and its effect
recipe contract. Record grain, curvature, AO, moss and pattern identities
separately. Equal effect strengths do not compensate for different inputs.

Reuse valid structural normals, pattern IDs and alpha. Start from pinned sources,
not the previous sharpened output. Apply only the authorized finish channels;
measure effect size in physical units or relative to pattern/texel density. Keep
grain, wear, cavity, moss and glaze controls separate. Moss has a named semantic
mask; roughness alone is not its identity.

[ArmorPaint automation](../../armorpaint-remote/SKILL.md) owns native layers,
save/reopen/export and the scoped baseline-delta compositor. A cached native
export can prove composition replay only. Keep provider-specific intermediates
and compare a provider change as a candidate. Do not reconnect another provider
automatically because its historical maps exist.

Verify protected channels and masks, then matched close, grazing and target-size
views against the accepted specimen. Record the asset's measured differences;
do not substitute a whole-atlas average for valley, eave or moss inspection.

## Structural pattern replacement

Use [high/low baking](../../blender-high-low-baking/SKILL.md) only when the pattern
or another relevant structural input changes. Resolve the current LOW and its
actual field, end and underside receivers first. Fit count, pitch, phase, IDs
and silhouette to usable dimensions. Keep temporary HIGH objects out of exports.

Check receiver/reader compatibility before an expensive bake. Bake the affected
normal/AO/identity/opacity outputs together, apply the established finish route,
then validate encoded maps and publish. Geometry or UV changes require their
own authorization and state parity; the bake itself grants neither.

## Promotion and reuse

Keep callable commands, inputs, parameters and outputs in the asset's existing
recipe/handoff. Replay to a fresh destination; compare exact outputs where
deterministic, or predeclared tolerances otherwise. Use a second building to
prove transfer through the same interface before calling the workflow reusable
across the set. Keep implemented, tested, replayed, visually accepted, delivered
and runtime-verified evidence separate. A blocked stage names its required fix;
it neither expands scope nor silently cancels independent authorized work.
