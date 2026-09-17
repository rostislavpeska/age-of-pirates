# Static rig and export
## Reference rig
Inspect the original working Basilica FBX in a separate comparison scene. Record root type, bone hierarchy, bind/rest matrices, mesh transforms, Armature modifiers and weights. Match behavior rather than an Outliner icon.
An Empty is not an Armature. For a static rigid building use a real ARMATURE and deform bone, with mesh modifiers referencing it. Every intended vertex needs finite nonzero weights attached to existing deform bones; a single rigid-bone case uses weight 1.0, not empty groups. Inspect pose/rest state, modifiers and unwanted animation. Do not blindly apply transforms after binding. Preserve UVs and material slots.
Run `scripts/inspect_static_rig.py` in Blender for read-only counts, UV/color-layer, armature and weight checks; it does not prove bind-matrix or engine correctness.

## Counts and observed failure
Track source/evaluated vertices, triangles and actual serialized FBX/GR2 vertices, both globally and per mesh. Seams, normals, material and skin boundaries can expand buffers. A 20k triangle count is NOT a proven 20k vertex limit. The joined St Paul's asset was reported around 227k exported vertices/103k triangles; splitting improved game rendering substantially. This does not establish a universal converter limit.
Use logical body sections, dome and towers within the approved total budget and measured per-mesh constraint. Do not join for convenience. The generic 10–20k whole-building evaluated-vertex target plus 5k tolerance still applies unless the user approves an exception; the old landmark's exception does not carry to new projects.

## Layered geometry error
`Layered geometry data in mesh ... is not supported` concerns serialized FBX layer data, not necessarily physically stacked faces. Inspect Layer/LayerElement records, connections, mapping/reference modes and compare with working Basilica. Extra UV/color/material layers may be involved; do not state an unverified universal cause.
Prepare an export duplicate with one intended UV map and no unnecessary color/attribute layers unsupported by the verified recipe. Preserve source authoring/AO layers. Multiple material slots are not the same as FBX layered textures. Verify serialized data rather than deleting legitimate slots. Use exact `mata`, `matb`, `matc` for this building, without preview names/suffixes; polygon material indices must be valid.
Triangulate only the export copy with inspected diagonals. Round-trip the actual manual FBX in isolation to check layers, topology, UVs, rig, weights and bounds. Round-trip is not engine proof.

## Scale and manual fallback
The requested Basilica-compatible FBX scale is **0.01**. Record scene unit scale, root/object/bone transforms, FBX axis/unit settings and converter scaling together; never apply 0.01 twice. Compare bounds against the original in game. A coordinate offset is not automatically millimeters.
The exact full working Blender FBX options have NOT been recovered as a validated reusable preset. Do not invent Apply Unit/Transform, axis, leaf-bone or animation settings. Capture the user's next confirmed successful manual export with versions/hashes.
The export record must include source/scene hash, object list, bone hierarchy, counts, UV/color/material layers, all FBX options, bounds, converter command/version, output hash and game test screenshot/result. Manual export is the fallback until a recipe is verified.

## Converter
Existing tracked skills cover BAR extraction, grouping and deployment checks. A standalone GR2/Ubuntu procedure was NOT found by this checkout's documentation search; do not pretend it was read. The session's Windows wrapper is retained at `scripts/convert_fbx_to_gr2.ps1` (relative to the skill root), now with an explicit converter path.
From the skill directory: `pwsh -File scripts/convert_fbx_to_gr2.ps1 -InputFbx <manual.fbx> -OutputDirectory <fresh-stage> -ConverterPath <GXOConverterAge3DE.exe>`.
This invokes the observed `--format=gr2 --bang` command in the converter directory. Fresh staging prevents stale output reuse. The header test is only a sanity check: verify full structure and bindings separately. An error dialog can block a GUI converter; stop retries and inspect the actual message. Never infer success solely from exit code.
If Ubuntu/Wine instructions appear later, inspect their paths, dependencies and tested version before extending the recipe. Do not claim native Linux compatibility from an executable's existence.
