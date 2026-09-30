---
name: korean-architecture
description: "Reuse the Korean building set's specific art recipes: simple wooden window lattices and grey hanji, geometry-aligned roof tile coloring and moss, dancheong and player-color finishes. Use for Korean architectural appearance and its project handoffs; delegates generic modeling, UV, baking and export mechanics to the existing skills."
---

# Korean architecture recipe library

This is the dedicated space for methods developed for the Korean set. It records
the owner's art direction, reproducible recipe inputs and demonstrated limits.
It is not another general Blender workflow. Keep recipes here when they describe
a Korean feature; keep tool safety, UV algorithms and engine serialization in
their existing shared skills.

## Choose the feature

| Work | Read |
|---|---|
| Window/door lattice, paper, reusable leaf patches | [Lattice and hanji](references/lattice-hanji.md) |
| Roof tiles, color variation, moss, exposed clay | [Roof surface finish](references/roof-color.md) |
| Painted trim, gable background, player color, age progression | [Palette and age variants](references/palette-ages.md) |
| Reproduce a Town Center revision or export both states | [Town Center evidence](references/town-center.md), then the current complete handoff |

[recipes.json](recipes.json) indexes the exact implementation and evidence files.
Run `python .claude/skills/korean-architecture/scripts/check_recipes.py` from AoP
to verify the recorded source hashes and locate the external assets. Override
`--korean-root` and `--assets-root` on another machine. A missing or changed file
requires inspection; do not silently substitute an older file with a similar name.

## Working contract for a Korean recipe

Take the latest accepted **mesh + UV + material bindings + map set** as one input.
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
