---
name: blender-high-low-baking
description: Authors and validates high-poly to low-poly architectural normal/AO bakes in Blender, including solid-mesh surface receivers, UV seams, cages and repeated roof detail. Use for geometry-derived relief and bake diagnostics, not image-generated normal-looking textures or game export.
---
# Architectural high/low baking

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
7. Apply the verified procedure to a new candidate-model checkpoint. Keep unrelated
   UVs/materials/normals unchanged. Count actual low geometry separately from high
   sources and projection proxies. Reinspect every repeated application.
8. Destination-engine tangent conventions, channel packing, compression, material
   bindings and destruction remain separate validation. Do not call Blender proof
   an in-game result or assume OpenGL/DirectX labels establish a game's convention.

## Tested helpers

- `scripts/build_specimen.py`: call `run(output_dir, version='01')` inside the live
  Blender session. Creates original curved-roof and asymmetric-panel specimens in
  a separate scene. Requires Blender's `bpy`, `bmesh`, `mathutils` and bundled NumPy.
  Writes EXR masters, 16-bit data PNGs, comparison renders, JSON and a saved copy.
  Use a new version/output directory for another iteration.
- `scripts/bake_pair.py`: explicit selected-to-active normal or finite-distance
  local-AO bake. Requires a scene marked `bake_scratch`, exact cage topology and a
  unique-UV receiver. It leaves bake setup changes in that owned scene and retains
  target nodes. It does not silently alter/export the original authoring model.
- `scripts/audit_unique_uv.py`: positive-area triangle intersection check for small
  unique 0..1 receivers. Running it executes four known-good/bad fixtures. It does
  not validate tiling/UDIMs, density, semantic regions, padding or cage crossings.

The operator must inspect render outputs and record defects. Source hashes,
settings, exact scope and skipped checks belong with the external work artifacts.
