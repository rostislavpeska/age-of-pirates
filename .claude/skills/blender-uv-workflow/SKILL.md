---
name: blender-uv-workflow
description: Coordinate architectural UV work through clean charts, material review, sharing, AO variants and final packing. Use for a multi-step unwrap or resuming it across agents; specialist skills perform the geometry and measurements.
---

# Observable UV workflow

Use one immutable candidate per step. Consume the accepted source and its handoff;
never choose a file by timestamp. Read [the checkpoint contract](references/checkpoints.md)
and run `scripts/checkpoint.py` before promoting a result. This validator checks
stage order, bound evidence and applicable gates; it does not itself inspect meshes.

All trials and temporary diagnostic maps stay in background Blender. The live
operator workspace receives only the agreed, verified review packet; leave its
production UV page selected. Extra diagnostic layouts require a specific request,
per [the operator boundary](../blender-uv-observability/SKILL.md#operator-boundary-background-work-contract-only-presentation).

Every bounded editing batch, including partial repairs, follows the
[partial delivery gates](references/review-packet.md#partial-editing-gates-owner-correction-2026-10-06):
save, verify, inspect and embed the current UV maps in chat **before** the next
dependent mutation. Delivered WIP is not owner acceptance; prior authorization
to continue still applies. Do not accumulate all evidence until the final report.

1. **Geometry:** exact authored/protected/reference census, ground and attachment
   contracts, surface checks and budget. Use the geometry skill's accepted result.
2. **Clean charts:** use [blender-clean-uv](../blender-clean-uv/SKILL.md). Stitch
   adjacent surfaces into coherent charts; preserve editable UVs and per-run IDs.
   Show checker, chart colors, readable UV sheets and close-ups on every model.
   Internal unpacked worksheets may extend outside 0–1; operator views must show
   the matching actual page and obey the consumer's page policy. Runtime capacity
   is not this gate.
3. **Material review:** show the same models by physical material class with a
   legend and exact per-face coverage. Consume the existing class attribute/palette.
   Classification does not authorize destructive object splitting or one runtime
   material/page per class. Also report actual assigned runtime bindings, shared
   dependencies and unresolved backing cells; a palette is not that audit.
4. **Sharing review:** [blender-uv-reuse](../blender-uv-reuse/SKILL.md) proposes
   correspondences; [blender-uv-conjoin](../blender-uv-conjoin/SKILL.md) applies them
   on a copy. Choose approximation per region, preserve approved chart boundaries,
   grain/role/normal/alpha/player-color compatibility. Conjoin all compatible
   same-material, same-shape, same-role charts under the declared regional policy;
   AO differences do not veto this first, provisional phase. Show family colors
   and owner versus member checks before AO. Aggressive coverage does not mean
   blanket geometric distortion or a blanket T3 preset.
   Run a **provisional space check** with [UV space efficiency](../blender-uv-space/SKILL.md)
   after sharing: agreed pages, measured density and content/padding/unused pixels.
   This is not final packing or permission to discard AO evidence.
5. **White AO and conflict review:** follow the binding
   [AO handoff contract](references/ao-handoff.md). Add one simultaneous white,
   texture-baked AO copy of EVERY model. Prefer Substance Painter when available;
   Blender is the fallback. A unique-UV diagnostic reference precedes decisions;
   the final copy must subsequently show the resolved production mapping.
   [blender-uv-ao-separation](../blender-uv-ao-separation/SKILL.md)
   tests corresponding points against the actual owner, with declared occluders,
   units, ray settings and seed. Prefer whole-chart variants; chart subdivision
   needs parent-child lineage and renewed continuity checks. Show mismatch heatmaps
   and the split families. Consume the first phase's families and correspondence;
   split within them, preserving parent IDs. Do not silently restart global
   matching. Never infer A≈C just from A≈B and B≈C. Resolve conflicts by measured
   AO variants or an explicitly reviewed neutral AO mask, never UV stack order.
   Use [AO postproduction](../blender-ao-postproduction/SKILL.md) to produce explicit
   owner maps, common conflict masks, processed AO and the effect/application ledger.
   Keep the unique reference separate; the delivered white copies use production
   mapping. After a layout change reproject or rebake and repeat this verification.
6. **Pack/freeze:** use [UV space efficiency](../blender-uv-space/SKILL.md) to account
   for actual content, padding and unallocated pixels, and compare bounded packing
   candidates without breaking semantic owners. Carry this companion with the
   portable workflow. [aoe-uv-atlas-export](../aoe-uv-atlas-export/SKILL.md) packs a
   supported profile. Now enforce final density, page budget, mip-safe padding and
   accidental-overlap checks. Also require `shared_mapping`: every shared face has
   a compatible cell, in-cell UVs, verified source image bindings and a disposition
   for observed exposure. `scripts/shared_mapping.py` checks an actual extracted
   census; a material slot called matC is not evidence. The final `03_uv` handoff
   consumes this checkpoint. Pending mapping does not block bounded WIP experiments,
   but their capacity remains provisional and they cannot claim full-model readiness.
7. Continue through base textures, details and the engine-specific export/game
   checks. See [bake dependencies](references/bakes-and-recovery.md) for permitted
   intermediate bakes and reusable masters.

Declare runtime budget and vanilla quality references upfront. Measure fit after
sharing and AO, never silently shrink charts to satisfy an early estimate. Keep
coverage/density correctness separate from sharing percentage and packing advice.
Read [sharing, capacity and density decisions](references/sharing-and-capacity.md)
before these phases. It separates the universal floor from working targets,
requires an explicit owner GO for below-floor candidates, and accounts for AO
growth before final packing. A pre-AO fit is provisional.

Every checkpoint has fixed views, actual editable data, source identity, machine
reports and scoped owner acceptance. A background result is FILE_VERIFIED, not
LIVE_VERIFIED. Preserve unsaved live work; use connectors. No desktop fallback is
authorized here. Color legends distinguish chart IDs, materials, sharing and AO.

The [binding operator contract](../blender-uv-observability/SKILL.md) is a REQUIRED
portable companion. Publish simultaneous checker, black resource isolations,
actual sharing copies and the AO checkpoint copy for EVERY model. Run its operator smoke check before the
next dependent phase; missing or misleading views must be repaired first. Carry
this companion when separating or packaging the modelling harness. Unwrap remains
a multi-skill discipline; operator PASS is separate from UV/AO/budget acceptance.

Deliver the owner's [standard review packet](references/review-packet.md): all
model/resource UV sheets, measured resolution comparisons, space accounting,
bounded improvement proposals, lessons/tracking and per-scope UV bindings. This
human-facing report consumes the existing HANDOFF; it is not another version store
or a substitute for final checks. Incomplete WIP evidence stays explicitly incomplete.

Use `checkpoint.py validate SPEC.json`, then `write SPEC.json --out CHECKPOINT.json`.
`check CHECKPOINT.json` revalidates hashes and upstream receipts. `summary` produces
readable status from a receipt; do not maintain an independent version pointer.
Evidence files belong in the project's scratch/output area, not this package.

Bound each hypothesis to a pilot and one evidence-driven revision by default.
Validate every variant; retain a better parent. When inputs are unchanged, reuse
hash-verified reports; when they change, invalidate only dependent results. Missing
evidence is INCOMPLETE, a failed experiment stays visible, and a timeout is UNKNOWN.
Record confirmed lessons with the shared journal. Run the bundled failure fixtures
with `python -m unittest discover -s .claude/skills/blender-uv-workflow/tests -v`.
