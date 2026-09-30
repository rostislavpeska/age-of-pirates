---
name: blender-architecture-texturing
description: Coordinates architectural materials, decorative atlases, texture sources and AO while preserving unrelated maps. Routes clean unwraps to blender-clean-uv and economical overlap/packing to blender-uv-reuse; use for material and texture-source work in Blender.
---
# Architecture texturing
This is the material and texture-source entry point. **Read the
[pipeline order](references/pipeline-order.md) before any bake**: texture budget first,
high poly built but not baked, one pilot bake that leaves a recipe, final bake only on
frozen UVs. A later UV change invalidates every bake made on the old layout.

Every phase hands off through a standard `HANDOFF.json` ([handoff contract](references/handoff-contract.md),
`scripts/handoff.py`): consume the upstream phase's canonical outputs, never reinvent them.

**Patterned linear elements come from geometry, not formulas.** Ridge cap-tile rows, tile courses and similar
repeated structure on long elements are modelled as a high (continuous along the element's arc length) and
baked onto the existing UVs; a compositor may only colour them from the baked IDs. Analytic patterns in
per-segment frames jumped at every joint and read as pinstripes on round ridge tubes (Korean TC side ridges,
owner escalation 2026-09-28; fix `ridge_v2`). Before the owner sees a roof, run the cross-face checks in
[texturing QA](../blender-high-low-baking/references/texturing-qa.md) (run continuity, seam phase) and render
the owner's exact camera.

The final-atlas chain after clean charts is
[conjoinment](../blender-uv-conjoin/SKILL.md) ->
[AO separation](../blender-uv-ao-separation/SKILL.md) ->
[pages at one density](../aoe-uv-atlas-export/SKILL.md); each of those steps moves charts.

UV work has two separate owners; load the one needed for the current checkpoint:

- [Clean UV authoring](../blender-clean-uv/SKILL.md): coherent charts, density,
  hidden-surface allocation and real editable maps in Blender with operator controls.
- [UV reuse and space optimization](../blender-uv-reuse/SKILL.md): geometry
  candidates, AO/channel compatibility, deliberate overlap and final atlas budgets.
- [Hybrid hidden surfaces](../blender-hidden-surfaces/SKILL.md): material-only
  interior/underside classification before UV allocation, with editable visual review.

Clean-editor acceptance does not establish production capacity or final texture
quality. Existing diagnostic helpers are not an automatic production unwrap solver.

## Local prerequisites

Follow the [local-tool readiness guidance](../skill-library-audit/references/local-tools.md).

UV/material edits need locally installed Blender and a verified route to the
intended scene. Layered image edits need the selected editor and source document:
when using Photoshop, confirm its version, active document, unsaved state and the
required layer/export capabilities through an available read-only connection or
operator check. Photoshop, its license and its integration are local prerequisites,
not bundled parts of this skill. Do not silently replace a PSD workflow with flat
images or install/upgrade an editor or connector during preflight.

The standalone tiling checker needs Python, **NumPy** and **Pillow**; the JSON UV
validator uses Python's standard library. These offline checks do not establish
that Blender, Photoshop or Painter is connected. Missing optional Painter support
does not block Blender-only work; use it only for the selected workflow.

1. For unwrapping, follow the clean-UV skill above and read [regions and density](references/regions-density.md). For sharing or atlas compression, follow the UV-reuse skill. A density-correct atlas of tiny construction faces is not an accepted architectural layout. Detailed texturing follows the agreed UV/reuse checkpoint; source studies and existing baked previews are not final texture acceptance.
2. Read [sources and seamless textures](references/sources-seamless.md) when acquiring/generating materials. ALWAYS research real ornament. Preserve rich detail through texture/normal relief where silhouettes do not need geometry.
3. Read [UV repair and AO](references/uv-ao.md) before atlas edits, baking and postproduction. Identify exact faces; preserve unrelated geometry, UVs, materials, normals and pixels. Do not repack an atlas to repair one window.
   For modeled high-poly relief projected onto a low mesh, use the companion
   [blender-high-low-baking](../blender-high-low-baking/SKILL.md) workflow and specimen checks.
4. Apply an orientation-marked UV checker before decorative maps. Check both axes for density/stretch and mirrored motifs. Repeated elements must share projection depths and density.
5. Inspect all angles after applying textures, especially under autonomous work: opposite towers, under ledges, sill floors, reveals, arch crowns and interiors. Compare unlit basecolor, AO-only, normal-disabled and final material views when diagnosing faults.
6. For Painter read [MCP feasibility](references/painter-mcp.md). A project existing online is not proof of local compatibility. Do not install/upgrade it as a side effect of texturing.
7. Keep layered sources, adjustment masks and an output manifest. Save a new texture version, apply to the confirmed Blender instance, verify packed/external paths, save and inspect. Never claim live updates when only a background copy changed. Use the destination engine skill for export.

## Final texel-density floor (owner, 2026-09-30)

**Hard universal floor:** every model passes the [universal UV density floor](references/uv-density-floor.md). For AoE3DE:

- a median of at least 100 t/u;
- at most 2 % of the area below 60 t/u, per model and per page;
- at most 3 % of the area on collapsed UVs.

Measure it with `scripts/density_floor.py`. Hidden pages count. A FAIL blocks the UV freeze (the 03_uv handoff, [contract](references/handoff-contract.md) rule 7) and the export. Only the owner's recorded waiver (his whole message) exempts a model.

Every new or rebuilt component must meet a **measured comparable vanilla asset floor** at the final runtime page size, on both UV axes and at the same model scale. Record the reference, units, per-component minimum, and source-supported detail density before baking. Missing measurements block a quality-pass claim. A high-resolution bake later shrunk into a small island, an upscaled bitmap, or fewer owners does not raise final detail density. Reclaimed area must actually support the required allocation.

For the current Korean TC window repair the owner explicitly requires **at least 2x linear density relative to the rejected 115 texels/unit version** (at least 230 on both axes, four times the texel area), as well as the vanilla floor. This is a window-specific requirement, not a universal numeric floor for every asset. The r2 allocation targets 256; unrelated roofs/UVs are not repacked to meet it. Show the actual editable UVs and every review model using the same mesh/map revision. Design praise does not mean the owner accepted density or the complete asset.

## Editable sources and operator feedback
When legacy texture sources are unreliable, use the current approved texture as a clean base and retain a hidden, toggleable UV-island checking overlay. Do not reconstruct speculative layers or add unnecessary groups. Preserve unsaved work before changing the source.

Once an operator manually edits a layered texture document, that document is the editable source of truth. Keep named, reversible correction layers and semantic masks there. External scripts may prepare masks or pixels, but incorporate their results into the editable source before export. Opening a flattened export in an editor does not synchronize the source. Never regenerate over manual corrections.

For each visual iteration, confirm the active Blender file and scene, save a checkpoint, update and inspect the viewport, save the editable texture source, then export and validate destination maps. Keep the same comparison views and lighting. Batch compatible feedback, maintain a short pending-issues register, and hand control back for manual acceptance when required. A background copy is a staging artifact until the active authoring scene uses the same revision.

8. For material-wide tint or contrast, save reusable grayscale masks per atlas for stone walls, carved details, stairs, foundation/weathering, statues, lantern stone, roofs and protected glass/metals/wood. Inventory patches added after the initial atlas plan: an old tag allowlist is not complete coverage. Mixed patches need pixel masks (e.g. preserve blue glass inside lantern stone); verify visually. Store atlas dimensions, region coordinates, source hashes, gutters and settings with masks. Assert categories do not overlap and unrelated pixels are unchanged. Rebuild after atlas changes; inspect any unclassified pixels used by geometry. Apply each revision from an immutable baseline so rerunning does not compound adjustments. Shared atlas regions cannot support different per-object tints without a deliberate layout/material change.
