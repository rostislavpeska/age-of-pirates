---
name: blender-roof-baking
description: Coordinate geometry-derived roof patterns, ridge/hip/valley construction and high-to-low baking for any architectural roof, including European and Asian roofs. Owns physical junction and cross-UV continuity contracts; consumes project style and set finish profiles, reusing the existing baker and QA tools.
---

# Generic roof construction and baking

This is the roof entrypoint, not a second baker. Geometry detection/construction
belongs here; the consuming project supplies roof/ridge/valley style; its set
profile supplies colour, glaze, moss and other finish decisions. No universal
Korean tube pattern, timber ridge, palette or engine channel packing is implied.
Use [capability-authoring](../capability-authoring/SKILL.md) when extending this
capability. Keep algorithm, style and source selectors separate.

**Implementation status:** existing bake/QA tools below are available. A complete
automatic geometric ridge detector, parameterized junction constructor and
cross-UV colour/normal/phase gate have NOT been established by this entrypoint.
The [geometry and continuity contract](references/geometry-contract.md) specifies
their required behaviour. Treat uncovered operations as tracked gaps, never as
checks that have passed. A declared-junction test is not automatic discovery.

Use the tested [paired-surface probes](references/paired-surface-probes.md) for
frozen triangle arrays: match exact spatial edges across split UVs, sample both
sides and compare triangle-frame normals. Declared boundary registration also
supports unequal edge subdivision across separate body/end UV islands. These are declared-pair diagnostics,
not automatic roof discovery or complete engine tangent validation. Combine
writers and readers when testing UV sharing; owner-only samples are insufficient.

## Inputs and stages

1. Resolve the current asset and allowed edits: mesh/triangles, evaluated
   transforms, units, corner normals, UVs, bindings, maps, budget and hashes.
   Geometry creation is used only when authorized. A texture-only job preserves
   the LOW; temporary HIGH/receivers never become export geometry accidentally.
2. Inventory actual surfaces and junctions in a common physical frame, including
   connected and disconnected adjacent patches, eaves, fronts, undersides, caps,
   ridges, hips and valleys. Record each junction's two sides and end conditions.
   Read the geometry contract before inference or construction.
3. Consume the **project pattern** to fit count, pitch, phase, cross-section and
   course direction over each usable area. A style is an input, not inferred
   from a convex angle. Preserve phase across tessellation/UV boundaries. Do not
   leave accidental tiny clipped motifs at field ends. Explicitly account for
   trim occlusion. Route modelled versus baked detail by silhouette and budget.
4. Run [blender-high-low-baking](../blender-high-low-baking/SKILL.md). Reuse its
   `bake_owner_maps.py`, input contract, assembly scope and HIGH-border handling;
   do not copy them into a roof-specific baker. Structural normal, local AO,
   semantic identity and silhouette must describe the same fitted pattern.
   Reuse valid bakes; colour, glaze or effects-only edits do not trigger rebakes.
5. Apply original material sources and the selected **set finish** as separate
   stages. Preserve semantic masks for clay/cover/pan/moss/edge/underlip as
   applicable, with documented provenance. Surface curvature, true physical
   junctions and arbitrary LOW/UV boundaries are different mask sources.
6. Check every actual reader before and after runtime encoding: complete motif
   fit, alpha/overlap, junction continuity, normal orientation and independent
   protected regions, then matched close/grazing/target-size views. Use the
   consuming engine adapter for compressed mips and export gates. Report which
   requirements are tested and which remain unimplemented.

For multi-state engine assets, consume the engine adapter's serialized reader
census before a new layout or texture write. The AoE adapter provides
[runtime reader inventory](../aoe3de-building-states/SKILL.md#6-gates). Authoring
face IDs alone do not cover fractured, construction or other material readers.

## Reuse map — capabilities and limits

| Operation | Existing owner | Boundary |
| --- | --- | --- |
| Frozen LOW/cage/source contract, assembly bake, master derives | [high/low baking](../blender-high-low-baking/SKILL.md) | Does not select cultural forms or accepted appearance |
| Declared joint gap, penetration, contact | [junction-testbed](../junction-testbed/SKILL.md) | Does not discover all ridges/valleys or judge painted completeness |
| Manifold UV-seam inventory and colour monitoring | [texture-corner-seams](../texture-corner-seams/SKILL.md) | Does not prove normal/phase continuity or include all disconnected geometric neighbours |
| End cutout and opposite-side/underlip consistency | [alpha-cutout-texturing](../alpha-cutout-texturing/SKILL.md) | Shared readers still need independent intended-contour evidence |
| Downhill laps and runtime tangent interpretation | [roof-tile-direction-qa](../roof-tile-direction-qa/SKILL.md) | Does not replace junction coverage or art review |

## Acceptance and improvement

The reusable output is the executable recipe plus its source closure, physical
inventory, stage receipts, named masks, tests and specimen evidence. Keep a
failing specimen for missing side coverage, UV-split discontinuity, internal
HIGH overscan, incomplete end alpha and derivative texture degradation.

Pattern and finish can have different reference assets and approval histories.
Retiring an old pattern does not discard its useful finish evidence; do not
transfer the old pattern's shadow/normal rhythm into the new one. Treat an
accepted quality level as a floor. Improvements remain versioned candidates
until their required approval; keep the previous baseline recoverable.
