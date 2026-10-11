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

**Integrity gate after EVERY UV-changing step** (unwrap, share/conjoin copy, AO variant split, pack, page move), not
once at the start. Run `scripts/uv_integrity.py`:
- inside Blender: `blender -b file.blend --python scripts/uv_integrity.py -- --config gate.json --out report.json`;
- exit 1 = FAIL;
- `audit()` on extracted faces works anywhere.

It fails closed on:
- negative UV winding (a mirrored copy);
- a member face that does not reproduce its owner's polygon exactly, or sits on another page;
- shared-atlas faces outside their real regions;
- out-of-bounds, collapsed or non-finite UVs;
- with a before-snapshot, any non-target face that moved;
- **C coherence** (`surface_patch_deg`, owner 2026-10-11): one continuous surface = one texture unit. The unit is the
  SMOOTH PATCH computed from the mesh (faces of one part and material joined across edges bending less than 25 degrees:
  a roof slope between its hips, a wall panel, a post side). Each patch stays ONE UV island on ONE page and is shared
  whole or not at all. Face-by-face symmetric stacking had cut every Market roof slope into an owner half, a member
  half and unique patches while every other check passed;
- **O folds** (`page_px`): no pixel of an owned page under two owner faces, inside one island too (a ring patch
  unwrapped without its one cut folded onto itself).

A flip check that ran before sharing proves nothing about the shared layout: one checkpoint shipped 2,010 mirrored
member faces that way. A correspondence is accepted only if it preserves orientation (mapped face normals agree).
A vertex-SET match alone is ambiguous for flat symmetric islands. Scripted packs use
[`safe_pack`](../blender-uv-space/scripts/safe_pack.py). Its tests inject every defect class, because a gate that
never fires proves nothing.

1. **Geometry:** exact authored/protected/reference census, ground and attachment
   contracts, surface checks and budget. Use the geometry skill's accepted result.
2. **Clean charts:** use [blender-clean-uv](../blender-clean-uv/SKILL.md). Stitch
   adjacent surfaces into coherent charts; preserve editable UVs and per-run IDs.
   Every smooth patch is one island (gate C); a ring or tube patch gets exactly one
   cut (shortest path between its boundary loops) so it neither splits nor folds (O).
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
   the unit is the WHOLE smooth patch: patch X reads patch Y only when every face of X
   maps one-to-one onto Y by one rigid map; never stack part of a patch, never cut a
   self-symmetric patch (a dome, a centred panel) into stacked pieces;
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
6. **Pack/freeze:** map-space compression is MANDATORY (owner, 2026-10-11); a layout
   that skipped it cannot freeze. With [UV space efficiency](../blender-uv-space/SKILL.md),
   on EVERY owned page: (a) `pixel_audit.py` accounting of content, padding and
   unallocated pixels of the retained pack; (b) a bounded outline-aware `pack_masks.py`
   candidate at the same gutter (quarter turns, finite scale list) beside it; (c) cut
   long thin strips at face boundaries when they cap the page scale; (d) keep the best
   VALIDATED candidate (members re-copied; integrity, overlap, bounds, gutter rerun) and
   report before/after numbers. A Blender `pack_islands` or rectangle pass alone is not
   this step. Compression never cuts a smooth patch (strip segmentation broke 180 Market
   patches) and a page move takes whole parts (a roof field split over two pages). Owned pages keep ONE texel density: space left on the small page goes to
   the next subtypes in the [atlas-export](../aoe-uv-atlas-export/SKILL.md) priority
   list, never to upscaling the charts already there. **Alpha on the small page**
   (owner, 2026-10-11): with a large + small pair (2048 + 1024) the SMALL page carries
   the alpha/cutout surfaces (DXT5) and the large page stays opaque (DXT1). The only
   exception is a declared shared base + building split (the Dock); decide it at the
   page budget, before AO bakes. The `space` freeze check records all of this
   (`references/checkpoints.md`). Carry this companion with the portable workflow. [aoe-uv-atlas-export](../aoe-uv-atlas-export/SKILL.md) packs a
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

**Coherence review (agentic, required at share and freeze):** after the gate's C/O PASS, render the
`coherence` view (every smooth patch coloured by state: one island and whole = its family colour or grey,
broken / partly stacked / folded = red) beside the families view, look at every roof slope, wall and timber
close up, and stop on any patchwork the gate did not name: a surface that should be one unit by its real-world
function (a tile field, a plastered wall) but is split by the patch angle. Record what was inspected in the
checkpoint. The gate is deterministic; the look catches what the 25-degree rule cannot know.

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

## Hidden surfaces behind cut-outs; review single-sided

A face classified hidden (shared backing atlas) can still show THROUGH an alpha cut-out. Run
[`scripts/alpha_backing_check.py`](scripts/alpha_backing_check.py) on every alpha page. It casts rays through sampled cut
texels into the model and fails when the same assembly's front-facing opaque surface lies within `--own-depth` behind a cut,
unless that texel is cut too. Hits on back faces are reported separately: the game culls back faces (vanilla omits them).

The review must draw single-sided like the game (`use_backface_culling` on every review material). A double-sided viewer
showed back faces plugging every eave scallop that is open in game, so the owner saw a solid band (Korean Market
2026-10-11). A move of 67 'hidden' faces onto the alpha page, based on that double-sided reading, was unnecessary and was
withdrawn.
