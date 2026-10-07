---
name: blender-high-low-baking
description: Authors and validates high-poly to low-poly architectural normal/AO bakes in Blender, including solid-mesh surface receivers, UV seams, cages and repeated roof detail. Use for geometry-derived relief and bake diagnostics, not image-generated normal-looking textures or game export.
---
# Architectural high/low baking

Use the workflow's [bake dependency table](../blender-uv-workflow/references/bakes-and-recovery.md)
to distinguish measurement AO, pilots, reusable masters and runtime bakes. Masters
may precede final packing after the relevant geometry/detail contract is stable;
their finite source density, coverage and derive error must pass existing tests.
Do not rebake every region when only one region's dependencies changed.

Use the installed Blender through the verified connection. Read the sibling
`blender-architecture` and `blender-architecture-texturing` prerequisites; preserve
the current document and manual edits. Keep source meshes and baked images outside
runtime folders. Do not install a different baker to carry out this workflow.

Read [the exact process and failure checks](references/process.md) before baking.
It separates documented practice, project decisions and measured specimen results.

1. Preserve an editable authoring model. Create a detailed bake source, an optimized
   low mesh, and a matching cage. High-poly counts are offline costs, never hidden
   inside the runtime geometry budget. Declare a bounded high-poly work scope.
2. Resolve shading and intersecting exposed surfaces before UVs. Decide which
   silhouette edges, holes, recesses and structural projections remain geometry.
   Hard surface boundaries need explicit corner-normal discontinuities; flat side
   faces alone do not guarantee the adjacent smooth face has the intended normals.
3. Bake semantic surface groups. A watertight building does not require one global
   projection. A surface receiver copied from a solid is allowed when its final
   triangles, positions, UVs and corner normals match the destination exactly.
   Receivers and cages are never exported as substitutes for the solid building.
4. Start with unique 0..1 UVs, checker direction and measured density. Separate UVs
   at hard normals; a UV seam does not always require a hard normal. No uncontrolled
   overlaps while writing the bake. Define sharing and AO context before reuse.
5. Freeze final low topology, triangulation, UVs and normals before copying the
   cage. Preserve cage vertex/face order; inspect it where surfaces meet. Name
   pairs explicitly, but do not assume Blender selects pairs by suffix itself.
6. Prove one representative specimen first. Inspect high, low without normals and
   baked low under genuinely opposing light directions. Check saved map data,
   borders, mips, shallow/grazing views and one asymmetric feature. Document normal
   and AO passes independently; a successful bake call alone is not acceptance.
   A generic tile field proves the machinery only. For an architectural roof,
   test the curved slope, its eave turn, round tile ends and UV alignment together;
   see [roof-transition evidence](references/process.md#roof-transition-specimens).
   Fit complete motifs inside the receiver and stop relief at structural edges.
   For vertical eaves, check the shell cross-section, hard-normal/UV break and
   corner terminations before repeating the bake. Raised hip and ridge covers
   remain geometry where they affect the silhouette or conceal roof joints.
   For overlapping tiles, declare the physical ridge-to-eave direction and check
   the HIGH relief in that frame before replication. The exposed lip must drop
   sharply downhill. Increasing local U/V or arc length is not necessarily downhill.
   The `roof-tile-direction-qa` skill tests sampled relief with an uphill-lap negative
   control. Inspect opposing-light low renders and target-engine output separately;
   never fix physical HIGH reversal with a global normal-channel inversion.
   Follow [roof tile direction QA](../roof-tile-direction-qa/SKILL.md):
   actual HIGH sections, every final UV reader, validated tangent frames, decoded
   runtime maps and separate normal/AO/color views must agree. Formula-only and
   geometric-normal-only previews cannot certify final lap appearance.
7. Production bakes run only on **frozen** final UVs (owner sign-off, recorded
   fingerprint) - see the [pipeline order](../blender-architecture-texturing/references/pipeline-order.md).
   The pilot's lasting output is a recipe config for `scripts/bake_owner_maps.py`;
   a bake made before the final pages exist is a pilot, whatever its quality.
   Apply the verified procedure to a new candidate-model checkpoint. Keep unrelated
   UVs/materials/normals unchanged. Count actual low geometry separately from high
   sources and projection proxies. Reinspect every repeated application.
8. Destination-engine tangent conventions, channel packing, compression, material
   bindings and destruction remain separate validation. Do not call Blender proof
   an in-game result or assume OpenGL/DirectX labels establish a game's convention.

## Bake master: UV edits become derives

Bake once per LOW geometry version onto a unique-texel `UV_Master` at >= 2x density (object-space NORMAL, AO,
hit-mask OPACITY, EMIT/IDs), then derive any runtime layout in seconds with `derive_maps.py` - same recipe,
no HIGH loaded; rebake only when the LOW contract or a HIGH changes. Tools, guards, filters and acceptance:
[bake master](references/bake-master.md) (`master_unwrap.py`, `master_bake.py`, `derive_maps.py`, `compare_maps.py`).

## Tested helpers

Before reading transforms for a derived receiver/HIGH, activate the source scene,
update its dependency graph and freeze the evaluated world transform. Assert
receiver and HIGH use the same frame. A stale Stable transform caused an entire
region to miss while its source updated to the accepted ground offset. Background
Python runs use `--python-exit-code 1`: Blender can otherwise exit0 after a script
exception. Require completion manifests and coverage, not process exit alone.

- `scripts/build_specimen.py`: call `run(output_dir, version='01')` inside the live
  Blender session. Creates original curved-roof and asymmetric-panel specimens in
  a separate scene. Requires Blender's `bpy`, `bmesh`, `mathutils` and bundled NumPy.
  Writes EXR masters, 16-bit data PNGs, comparison renders, JSON and a saved copy.
  Use a new version/output directory for another iteration.
- `scripts/bake_pair.py`: explicit selected-to-active normal or finite-distance
  local-AO bake. Requires a scene marked `bake_scratch`, exact cage topology and a
  unique-UV receiver. It leaves bake setup changes in that owned scene and retains
  target nodes. It does not silently alter/export the original authoring model.
- `scripts/bake_owner_maps.py`: **the one-command production bake** on shared UVs.
  `blender -b file.blend --python bake_owner_maps.py -- recipe.json` bakes NORMAL, local AO
  and OPACITY from high sources (in the file or appended from another .blend) into the owner
  faces of each page; members are never targets. No cage object: `extrusion` +
  `max_ray_distance`. Read [the recipe contract and migration](references/bake-contract.md):
  declare exact intended regions and their allowed HIGHs. Missing/unexpected faces stop before
  HIGH loading; receivers preserve and verify original corner normals and triangles. Production
  requires both the UV `freeze` and the separate LOW `input_contract`. Expanding a pilot means
  declaring and validating its new scope; deleting `only` does not prove production coverage.
  `preflight_only` writes cheap scope/receiver evidence without loading HIGHs or baking.
- **Texturing QA (every iteration, before the owner sees it):** [texturing-qa.md](references/texturing-qa.md) -
  shot list, pass criteria, normal-stacking and material-consistency rules; `scripts/qa_textures.py`
  (numeric: empty texels, flat islands, class colour targets), `scripts/qa_detectors.py` (second rhythm in a
  normal, stacked normals, misregistered/mirrored/stretched UV members, masks off their edges or channels,
  colour rhythms < 16 texels; specimen-proven by `test_qa_detectors.py`) and `scripts/qa_shots.py` (fixed
  cameras -> contact sheet).
- **Normal maps (every job that touches Normal):** [normal-maps.md](references/normal-maps.md) - source decision table (bake / own masks / texture / tiled / Photoshop / Substance), RNM combine rules and amplitudes, the whole-model normal audit spec.
- `scripts/review_scene.py`: **the standard review deliverable** (owner, 2026-09-28): builds a live
  scene in the owner's open Blender from the bake recipes - LP with the new maps, the reference variant
  and the HP source side by side, grey clay, labels, grazing sun, Material Preview, framed on the
  recipe's `only` faces. Run through the MCP: `exec(..., {'__name__': 'review', 'CONFIG': cfg})`. Never
  hand over only an image. Its optional `snapshot` is the agent's own check of the framed view (the MCP
  viewport screenshot can return a stale frame while Blender is not focused; the OpenGL render does not).
- `scripts/uv_fingerprint.py`: `record` the frozen layer at the owner's sign-off, `check`
  (exit 3) that the layer and every listed bake report still match it before assembly or export.
- `scripts/bake_contract.py`: companion LOW geometry/transform/normal/triangle fingerprint,
  explicit scope/pair validation and receiver extraction. It does not replace the UV freeze
  or infer semantic coverage from successful ray hits.
- `scripts/test_bake_contract.py <blender.exe>`: missing/unexpected scope, incorrect pairs,
  partial-pilot controls, stale geometry/normals and source-preserving receiver extraction.
- `scripts/test_bake_owner_maps.py <blender.exe>`: fixture test of both (owners only, tilted vs
  flat normals, opacity hit/miss, freeze pass then fail after a moved UV). Passed 2026-09-28
  on Blender 5.0.
- `scripts/audit_unique_uv.py`: positive-area triangle intersection check for small
  unique 0..1 receivers. Running it executes four known-good/bad fixtures. It does
  not validate tiling/UDIMs, density, semantic regions, padding or cage crossings.
- Bake master ([bake master](references/bake-master.md)): `scripts/master_unwrap.py` (unique `UV_Master`,
  2x density, immutable per LOW contract), `scripts/master_bake.py` (`recipes` on the host, then `bake`: the
  unchanged `bake_owner_maps.py` with OBJECT normals, margin 0, hit fractions and HIGH hashes in `master.json`),
  `scripts/derive_maps.py` (the ordinary recipe + `"master"`: owners only, the baker's own MikkTSpace frame, drop-in
  maps and `derive_report.json`), `scripts/compare_maps.py` (`compare` acceptance vs a direct bake, `render`).
  `scripts/test_master_derive.py` (pytest; Blender fixture with `QA_BLENDER`, `BLENDER_GATE`). Korean TC R2
  proof (2026-09-29, Blender 5.0.1, EAVE_CUTOUT `class_factor` 1.5): after the margin fix (IMB_filter_extend's
  4-neighbour gate, replayed per receiver; an 8-neighbour fill had failed the S18c eave pair) roof, S18c eave,
  eavefix and a moved TEST layout all pass, and the replayed margin reproduces a direct bake's to 2e-7.

The operator must inspect render outputs and record defects. Source hashes,
settings, exact scope and skipped checks belong with the external work artifacts.
