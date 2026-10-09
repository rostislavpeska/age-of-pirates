---
name: blender-uv-observability
description: Publish the binding simultaneous Blender UV review layout, standard checker, black resource isolations, painting subtypes and real sharing colours. Required companion for architectural UV work; not an unwrap algorithm.
---

# Binding UV operator contract

## Operator boundary: background work, contract-only presentation

Owner correction2026-10-09: all experiments, temporary unwraps, baker trials and
diagnostic atlases run in **background Blender**. Publish to the owner's Blender
only the agreed review deliverables after background verification. Do not expose
temporary layouts, change the active map or use the operator's workspace as a test
bench. Extra diagnostic views require the operator's specific request.

Leave the agreed PRODUCTION UV page selected at handoff. Before publishing, state
what changed, what did not, page dimensions and measured density delta. A white AO
reference model is an agreed deliverable; its temporary unique-UV atlas is not a
default operator view. Keep that map in the background evidence. Reference copies
are read-only in the ordinary review path; exposing their test UVs requires a clearly
labelled, specifically requested diagnostic mode. Never overlay unrelated production
UVs on a reference image to make the display look familiar.

Owner accepted the working layout on 2026-10-08: "It is exactrly what I wanted!"
and requested: "Make it a contract. test if agents can follow it - simple smoke test".
This accepts the operator layout, not unfinished UVs, textures or runtime fit.

## Required visible result

Keep all copies visible TOGETHER in one Blender scene and UV Editing workspace.
Buttons select, frame and inspect; they must not replace simultaneous copies with
mutually exclusive scenes. For EACH model show:

1. One STANDARD Blender COLOR_GRID checker copy. No custom substitute. Show the
   working density target and measured result or pending/failed status. A checker
   alone is not numeric density evidence.
2. One isolation copy PER TEXTURE RESOURCE. Only that resource's faces receive
   material subtype/ID colours; every other face is BLACK. Black means excluded
   from this isolation, not deleted or proven hidden. The isolation of a
   hidden/backing/generic resource must look black from OUTSIDE (any lit face is a
   visible face misfiled as inner); verify it before publishing, per the
   [outside check](../blender-hidden-surfaces/SKILL.md#binding-rule-every-innerbacking-face-is-checked-from-outside).
3. One ACTUAL CONJOINED-FAMILY colour copy. Owner and members have matching colours
   and corresponding shared UVs. Unique charts are gray. Before conjoin is done,
   keep this copy visibly PENDING; arbitrary island colours are not sharing.

4. From AO review onward, one white TEXTURE-BAKED AO copy. Label unique diagnostic
   reference versus resolved shared bake; retain the reference after final packing.
   Screen-space viewport AO is not this evidence. The binding
   [AO handoff contract](../blender-uv-workflow/references/ao-handoff.md) defines
   conflict decisions, explicit bake owners and final acceptance requirements.

Required copy count = model count x (resource count + 2 before AO, + 3 at AO/freeze).
The Korean House profile requires AO: WALLS, ROOFS, GENERIC and POTTERY give seven
copies each, **21 for A/B/C**. Other projects supply their resource list and stage.
Label every model/copy, resource, revision and phase.

Each UV delivery also states measured texel density numerically in chat, with
units, the named baseline and ratio/difference. Distinguish a project minimum
from a measured reference-model baseline; if the latter is unavailable, say so.
Keep unresolved density defects visible; a target is not a measured pass.

## Materials and actual mapping

At every modelling-session start, state and record the operator-agreed texture
budget: set/model scope, owned page counts and dimensions, existing atlas identity
and cell table, and allowed reused textures. Existing explicit agreement remains
authorization; do not ask for it again. Page-size validity alone is insufficient.
Do not create generic or prop pages in place of a required existing dependency.
If the agreed pages cannot hold the current charts at target density, uniformly
scale a WIP copy to fit those pages and report measured density versus the floor.
Then optimize within that budget; extra pages need a new explicit agreement.
Diagnostic ID/checker images visualize those SAME UVs and pages, not a separate
roomier atlas. The explicit exception is a unique-UV AO reference for measurement:
it is labelled diagnostic-only, follows allowed dimensions, preserves production
UVs and is excluded from runtime export and density claims. Operator layout
acceptance never waives this budget contract.

Texture ownership and painting subtype are separate face attributes. The Korean
example distinguishes planks, beams, restrained red wood, timber ridges, lattice,
player-colour wood, stone blocks, solid granite, clay roof field, clay roof ends,
plaster, hanji and ceramics. Follow the consumer's concrete material references.
Identify subtype regions on the ACTUAL atlas with a legend. Subtype IDs do not
authorize extra runtime pages or texture sets.

The operator can select a production model/copy/page and inspect its EDITABLE UVs. Active UV
layer, shader UV input, editor image and page dimensions must match. A requested
diagnostic mode follows the same truthful binding rule with a visible TEST/REFERENCE
label and an explicit route back to production. Select only
faces for that image; do not overlay several pages on an unrelated texture.
Load allowed page sizes, square policy, standard checker and resource list from
a consumer-supplied profile, applying subproject overrides. This portable skill
contains no engine texture-size default. AoP/Korean's consumer profile allows
square 512, 1024 and 2048 pages. The Korean parent owns shared atlas identity for
all ages; the House subproject owns its two-page budget. A valid page size never
authorizes more pages. Rejected over-budget diagnostics remain negative evidence.
Never silently lower density or enlarge production pages to make a review pass.

## Publication and verification

Preserve source/candidate, save a reopenable file, and retain the UI script with
it. Verify the live copy census, black isolation, standard checker, UV/image
bindings, subtype regions and a real screenshot after redraw. Test selection in
the UV editor; named scenes alone do not prove it works. Restore custom controls
on reopen through the approved Blender API or stored UI script; do not change
Python trust preferences. Keep current action, failures and unfinished work visible.

### Delivery to the owner's Blender is proven, never assumed

A checkpoint reaches the owner only through the live viewer pair:
- `scripts/live_viewer.py` is started once in his GUI Blender (screen control: announce it first). It loads every
  newer published version at once. Unsaved edits are saved to a recovery copy, never discarded and never a reason to
  wait. It writes the heartbeat `VIEWER_STATE.json` (pid, version, file sha256, scene, time).
- `scripts/live_publish.py` publishes the copy and waits for that heartbeat. Exit 0 writes `LIVE_READBACK.json`, the
  `delivery.live_readback` block that a review handoff needs. Exit 4 is NOT VISIBLE: report "published, not
  delivered" with its reason, and never "done".
- A viewer that waited for unsaved edits once stayed on an older file while the new one was reported delivered.
- Tests: `tests/test_live_publish.py`, and `tests/blender_live_viewer_check.py` in background Blender.

Use the existing job, handoff, incident and MCP safety systems. This contract is a
required companion of blender-uv-workflow and blender-architecture-texturing.
It must travel with their portable dependency closure. Project AGENTS.md files
may link to it but are not its sole home or enforcement mechanism.
Missing copies or false editable mapping mean OPERATOR CONTRACT FAIL: repair the
view before the next dependent phase. Operator PASS does not certify geometry,
UV quality, AO, texture budget, game readiness or human approval. Failed quality
checks may remain visible in an authorized WIP; never relabel them passed.

The owner requested a small smoke test, not a full production test campaign.
One independent reader should identify expected copies, black isolation, profile
inheritance and false-sharing rejection; run the targeted layout fixtures.
The current comparison_workspace.py is a tested Korean adapter, not a universal
scene builder. See references/contract.md for research and limits.
