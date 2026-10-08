---
name: blender-clean-uv
description: Author coherent architectural UV charts and deliver actual editable UV maps in Blender, with density checks, material classes and working operator controls. Use for clean unwraps and UV handoffs before overlap optimization or detailed texturing.
---

# Clean architectural UVs

All operator delivery follows the required portable
[UV operator contract](../blender-uv-observability/SKILL.md), including direct use
of this skill. A pending sharing copy is labelled pending, never invented.

For multi-step work, start with [the shared UV workflow](../blender-uv-workflow/SKILL.md).
This is checkpoint 2a: show chart colors, a saved checker and readable worksheets.
Then show a separate material-class review (2b) before sharing. Chart cleanliness
does not require final 0–1 packing or a sharing quota. Preserve the full source
census; classify every object as authored, protected dependency or reference.

This skill owns **chart construction and the editable UV handoff**. It does not
establish that the layout fits the final atlas budget. Use
[UV reuse and space optimization](../blender-uv-reuse/SKILL.md) for geometry-based
overlap discovery and economical packing after this checkpoint.

## Working contract

- Confirm the intended Blender connection, file, scene and unsaved state before
  edits. Use the user's authorized integration; skill use grants no desktop-control
  permission. Preserve the source and save a recoverable revision.
- Keep architectural authoring faces as quads/ngons. Do not triangulate the source
  to unwrap, pack or bake. Analytical tessellation may be read-only; conversion
  to triangles belongs on the final export copy.
- Record verified world scale, target atlas sizes, density classes, alpha policy
  and required views. A larger diagnostic atlas is an explicit working allocation,
  not permission to enlarge runtime textures or call the budget passed.
- Use one persistent chart ID and face-membership record per logical patch.
  Keep material semantics independent of atlas membership: wood, plaster, stone,
  roof tile, paper, glass and so on must remain identifiable after consolidation.
- Protect coherent visible charts when repairing neighboring surfaces. Fewer total
  islands cannot compensate for breaking an already usable roof or facade.
- When several agents have Blender open, identify the producer and revision in the
  review file/window before handoff. Honor the user's naming convention and verify
  the intended process; do not rename or operate another agent's session.

## Workflow

1. Read [chart construction and validation](references/chart-construction.md).
   Build roofs, gables, facade panels and trim strips from adjacency and measured
   surface shape. A checker with consistent squares does not excuse fragmented
   per-face islands. Repair a representative patch before repeating the operation.
   For scattering experiments, follow the [regional comparison and effort gate](references/chart-construction.md#regional-comparison-and-effort-gate)
   before expanding the search or asking for another operator review.
   Lathed/organic parts (pots, jars) use profile bands, not architectural strips; see
   [organic and lathed shapes](references/chart-construction.md#organic-and-lathed-shapes).
2. Classify visible, retained hidden and destruction-exposed surfaces using the
   camera/state contract. Allocate hidden opaque backs to a named low-density
   shared material only where justified; do not discount visible soffits.
3. Unwrap coherent patches, check foldovers and both density axes, then create a
   unique working layout for independent inspection and later bake comparisons.
   Preserve explicitly permitted hidden-material repeats. Do not silently stack
   visible patches while their compatibility is unknown.
4. Read back the **actual mesh UV layer** and material image bindings. Validate
   coverage, finite coordinates, page bounds, degeneracy, inter-chart collisions
   and intra-chart foldovers. Preserve the pre-optimization layout and manifest.
5. Deliver the same revision using the handoff below. Record this checkpoint's
   acceptance separately from reuse, atlas capacity, texture art and game export.

## Required handoff

Provide three switchable views of the same geometry and UV revision:

1. **Density checker:** orientation-marked squares with pixels per verified world
   unit and named exceptions. DPI metadata alone is not a density measurement.
   **Standard density checker (all models, owner decision 2026-09-28):** Blender's generated
   Color Grid (`generated_type='COLOR_GRID'`, the "Orientation checker" GPT Astra and
   `blender_ao_review.py` use), generated at EACH texture's own resolution (2048 map -> 2048 grid,
   1024 -> 1024, 512 -> 512, 4096 -> 4096), mapped straight through that map's UV layer with
   Closest interpolation. One checker pixel is one real texel, so density is read on the model,
   not guessed; equal pixel steps across maps mean equal density.
2. **Solid material classes:** flat semantic colors, with retained hidden backing
   surfaces black for this review. This is a classification view, not lighting.
3. **Current baked textures:** preserve existing roof/window relief and opacity;
   label unfinished surfaces. This view does not imply final art acceptance.

Supply each actual UV sheet as an image in the handoff, clearly labeling opaque,
alpha-bearing and shared hidden sheets, dimensions, density and permitted overlaps.
Do not substitute shader-coordinate previews, source banks or an empty UV editor.
Read [the live editor check](references/chart-construction.md#live-editor-check)
before handing control back. Show the actual editor capture as well as the maps.

Keep a small debt register and batch feedback into one review packet. Track user
corrections, repeated instructions, requested app visits and review rounds; record
human time only when measured/reported. Do not request an extra review to verify a
control or UV defect that the agent can inspect itself. Reuse existing acceptance
for unchanged work; document the scope rather than declaring every gate passed.

## Scope of tools and evidence

The existing [layout helper](../blender-architecture-texturing/scripts/blender_uv_layout.py)
makes diagnostic layouts; it is not a semantic chart designer. The
[metric helper](../blender-architecture-texturing/scripts/uv_metrics.py) measures
density but does not prove a clean editor handoff. The live editor workflow was
accepted on a building checkpoint; remaining small-part fragmentation and runtime
budget failures were not accepted as production results.
