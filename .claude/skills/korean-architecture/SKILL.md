---
name: korean-architecture
description: "Reuse the Korean building set's specific art recipes: simple wooden window lattices and grey hanji, geometry-aligned roof tile coloring and moss, dancheong and player-color finishes. Use for Korean architectural appearance and its project handoffs; delegates generic modeling, UV, baking and export mechanics to the existing skills."
---

# Korean architecture recipe library

Generic UV stages follow [blender-uv-workflow](../blender-uv-workflow/SKILL.md).
Keep Korean appearance recipes here; checkpoint logic, numeric gates and source
identity belong to the shared workflow, not a second Korean implementation.

This is the dedicated space for methods developed for the Korean set. It records
the owner's art direction, reproducible recipe inputs and demonstrated limits.
It is not another general Blender workflow. Keep recipes here when they describe
a Korean feature; keep tool safety, UV algorithms and engine serialization in
their existing shared skills.

## Step 0 — inspect the model's functional reference before blockout

Governing art direction: preserve a distinct Korean visual language while fitting
the AoE Asian set. Apply the [two-reference review](references/palette-ages.md#korean-identity-within-the-aoe-asian-set)
to appearance work as well as the functional donor inspection below.

For a new Korean building, first inspect the latest accepted Korean Town Center
and the exact Japanese/Chinese vanilla counterpart appropriate to its age and role.
Record the intact model, damaged model, HKT and animfile identities. Inspect real
mesh support and attachment chains together: civ/garrison flags and poles, horse
or prop attachments, hitpoint bars, impact/debris points, spawn/entry clearances.
Only require roles that actually exist in that donor; missing roles are an explicit
finding, not a reason to invent bones.

The upfront shape plan includes a small attachment table: role, exact name,
model-space position/orientation, parent in each state, physical support, and any
deliberate relocation. Reserve functional physics bodies (such as a flagpole body)
from general fracture-cell assignment. Check flag/horse clearance against the
proposed Korean roofs and walls before authoring UVs. See `unit-bones` for engine
mechanics; the project pattern `patterns/korean/functional_attachments.md` holds
the Korean military evidence. This is a measured support check, not a new approval
gate or a mandate to repeat completed work on the accepted Town Center.

Evidence: 2026-10-05 KTC-176. A visually acceptable blockout retained flag bones
but omitted both poles; the Barracks flag was under its eave. General fracture
assignment also gave 13 wall/roof fragments and 4 stable roof fragments to reserved
pole bodies. The r11 repair and `gr2_lint` physical_mount check address that failure.

## Choose the feature

| Work | Read |
|---|---|
| Shared matc atlas, TC prop textures, decals and asset dependencies | Korean project `patterns/korean/shared_materials.md` and `shared_assets.json`; resolve the project root through `recipes.json`/the current handoff |
| Window/door lattice, paper, reusable leaf patches | [Lattice and hanji](references/lattice-hanji.md) |
| Roof tiles, color variation, moss, exposed clay | [Roof surface finish](references/roof-color.md) |
| Rounded eave discs, scalloped pan ends, alpha backing and curved hip caps | [Rounded roof ends](references/roof-ends.md), then project pattern `KR-EAVE-01` |
| Granite foundations, vertical gable boards and wooden ridge grain | [Stone and timber direction](references/stone-and-grain.md), then project pattern `KR-MAT-DIRECTION-01` |
| Painted trim, gable background, player color, age progression | [Palette and age variants](references/palette-ages.md) |
| Reproduce a Town Center revision or export both states | [Town Center evidence](references/town-center.md), then the current complete handoff |

[recipes.json](recipes.json) indexes the exact implementation and evidence files.
Run `python .claude/skills/korean-architecture/scripts/check_recipes.py` from AoP
to verify the recorded source hashes and locate the external assets. Override
`--korean-root` and `--assets-root` on another machine. A missing or changed file
requires inspection; do not silently substitute an older file with a similar name.

## Working contract for a Korean recipe

Take the latest accepted **mesh + UV + material bindings + map set** as one input.
The Town Center's **matc is a shared Korean-set atlas**, not a new backing page
per building (owner, 2026-10-06). Reuse its exact runtime texture references and
compatible UV cells. Preserve inherited TC prop UVs and bindings. Record shared
dependencies separately from each building's own atlas; neither duplicate them
nor count them as zero runtime cost. Shared surface detail can include generic
material AO, but never add a new building's assembly/contact AO to shared maps.

Before UV merging, deliver the visible physical-material split and a separate
visibility/backing classification. Downward-facing does not mean hidden: consider
intact and damaged visibility, grain, cell capacity and material identity. Matc is
not a catch-all for exposed plaster, roof tops, windows or unsupported materials.
The project registry pins source maps, runtime bindings, cell layout and limits;
adding another material family requires a compatible version, not silent edits to
the shared atlas used by the accepted Town Center.

The current Town Center's legacy `HEAD` and `uv_version.json` selectors have lagged
behind the visible Blender result. Resolve the explicit handoff before invoking
any script. Recipe names describe methods, not approval of an entire model.

For a new building, keep these recipe controls explicit: feature/face scope,
physical dimensions, age, pattern, wood/paper colors, final texels per model unit,
source detail density, UV ownership, relief depth, weathering strength, player-color
weight and seed. Reuse the method; measure new dimensions and masks. Do not reuse
Town Center face numbers or atlas coordinates as architectural rules.

For a local repair, assert unchanged geometry, UVs and texels outside the intended
scope. Preserve the outer window frames when repairing the infill. Roof color is
separate from roof normal/AO structure. Publish every standard review copy from
the same revision and inspect the **actual destination** after publishing.

Roof-end handoffs require the measured backing projection and rendered opaque-control
checks in `references/roof-ends.md` / `scripts/check_alpha_chain.py`. Front opacity
pixels or a connected Alpha socket alone do not establish a visible cutout (INC-103).

Route actual operations through [architecture texturing](../blender-architecture-texturing/SKILL.md),
[high/low baking](../blender-high-low-baking/SKILL.md),
[player color](../aoe3de-player-colour/SKILL.md) and
[AoP building export](../aoe-building-pipeline/SKILL.md). These own their generic
checks. Use connectors/background tools; this skill grants no screen-control or
paid-generation permission.

## Adding a method

Add a focused reference with its controls, reproducible source, one measured
successful result and known failure modes. Register its input/output hashes and
status in `recipes.json`. Distinguish owner preference, offline validation and
in-game acceptance. Save large sources and visual references in the external
Korean asset library; keep its index here. Stock reference pictures are design
references, not licensed game textures. Do not copy watermarked pixels into maps.
