---
name: blender-architecture-texturing
description: Plans and validates architectural texture regions, texel density, researched decorative atlases, seamless materials and AO while preserving unrelated UVs and maps. Use for architectural UV, material, baking and texture-source work in Blender.
---
# Architecture texturing
Architectural chart design precedes density normalization and packing. The tested
diagnostic helpers are not an automatic production unwrap solver.

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

1. Read [regions and density](references/regions-density.md) and [chart joining, reuse and AO](references/chart-joining.md) before unwrapping. Plan coherent facade/roof charts and reusable trim families before packing. A density-correct atlas of thousands of tiny construction faces is not an accepted architectural layout. AO variation within one chart is valid; incompatible values at the same reused texel are the actual conflict.
2. Read [sources and seamless textures](references/sources-seamless.md) when acquiring/generating materials. ALWAYS research real ornament. Preserve rich detail through texture/normal relief where silhouettes do not need geometry.
3. Read [UV repair and AO](references/uv-ao.md) before atlas edits, baking and postproduction. Identify exact faces; preserve unrelated geometry, UVs, materials, normals and pixels. Do not repack an atlas to repair one window.
   For modeled high-poly relief projected onto a low mesh, use the companion
   [blender-high-low-baking](../blender-high-low-baking/SKILL.md) workflow and specimen checks.
4. Apply an orientation-marked UV checker before decorative maps. Check both axes for density/stretch and mirrored motifs. Repeated elements must share projection depths and density.
5. Inspect all angles after applying textures, especially under autonomous work: opposite towers, under ledges, sill floors, reveals, arch crowns and interiors. Compare unlit basecolor, AO-only, normal-disabled and final material views when diagnosing faults.
6. For Painter read [MCP feasibility](references/painter-mcp.md). A project existing online is not proof of local compatibility. Do not install/upgrade it as a side effect of texturing.
7. Keep layered sources, adjustment masks and an output manifest. Save a new texture version, apply to the confirmed Blender instance, verify packed/external paths, save and inspect. Never claim live updates when only a background copy changed. Use the destination engine skill for export.

## Editable sources and operator feedback
When legacy texture sources are unreliable, use the current approved texture as a clean base and retain a hidden, toggleable UV-island checking overlay. Do not reconstruct speculative layers or add unnecessary groups. Preserve unsaved work before changing the source.

Once an operator manually edits a layered texture document, that document is the editable source of truth. Keep named, reversible correction layers and semantic masks there. External scripts may prepare masks or pixels, but incorporate their results into the editable source before export. Opening a flattened export in an editor does not synchronize the source. Never regenerate over manual corrections.

For each visual iteration, confirm the active Blender file and scene, save a checkpoint, update and inspect the viewport, save the editable texture source, then export and validate destination maps. Keep the same comparison views and lighting. Batch compatible feedback, maintain a short pending-issues register, and hand control back for manual acceptance when required. A background copy is a staging artifact until the active authoring scene uses the same revision.

8. For material-wide tint or contrast, save reusable grayscale masks per atlas for stone walls, carved details, stairs, foundation/weathering, statues, lantern stone, roofs and protected glass/metals/wood. Inventory patches added after the initial atlas plan: an old tag allowlist is not complete coverage. Mixed patches need pixel masks (e.g. preserve blue glass inside lantern stone); verify visually. Store atlas dimensions, region coordinates, source hashes, gutters and settings with masks. Assert categories do not overlap and unrelated pixels are unchanged. Rebuild after atlas changes; inspect any unclassified pixels used by geometry. Apply each revision from an immutable baseline so rerunning does not compound adjustments. Shared atlas regions cannot support different per-object tints without a deliberate layout/material change.
