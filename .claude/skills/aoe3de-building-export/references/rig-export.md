# Static rig and conversion

## Reference and rig

Inspect a known-working AoE3DE building in a separate comparison scene. Record its root type, bone hierarchy, bind/rest matrices, mesh transforms, Armature modifiers, weights, material slots, bounds and scale. Match observed behavior; an Outliner icon alone is not evidence.

For a rigid building mesh, use a real armature and deform bone when required by the verified profile. Every intended vertex needs finite deform weights referencing existing deform bones. In a single-bone rigid case, each weight should sum to 1.0. Do not blindly apply transforms after binding.

Run the included audit from the skill directory:

```bash
blender model.blend -b --python scripts/inspect_static_rig.py -- --out report.json --materials mata matb matc
```

Limit `--objects` when the scene contains reference meshes. Change `--materials` to the exact slots accepted by the target profile. The report does not compare corner normals or prove bind matrices or serialized output.

## Counts and topology

Track evaluated vertices and triangles per mesh and globally, then inspect serialized FBX/GR2 counts. UV seams, split normals, material boundaries and skinning can increase exported vertex buffers. Do not infer a universal engine limit from triangle count or from one asset.

Avoid joining logical building sections merely for convenience. If a consuming project has a per-mesh or total budget, monitor both throughout modeling and export.

Prepare an export duplicate with only the intended UV/color/attribute layers for the verified converter recipe. Multiple material slots do not by themselves mean FBX layered textures. Triangulate only the export copy and inspect long or crossing diagonals around windows, curved walls and ledges.

## Preserve shading through extraction and export

Treat per-face-corner normals as asset data, separately from positions and UVs.
In Blender versions exposing a `custom_normal` mesh attribute, a generic attribute
allowlist can silently delete it. Keep the version's custom-normal data; verify
evaluated corner vectors before and after cleanup, topology edits and triangulation.
The attribute's presence alone does not prove its vectors survived correctly.

Use the unmodified original asset as the reference for retained faces. Comparing
only the edited source with its exported/reimported copy can validate the same
damaged normals twice. Match complete triangles by positions and UV corners,
accounting for known transforms, winding and deliberate translations. UVs alone
are ambiguous on repeated atlas regions. Require complete, unambiguous coverage
of the surfaces being restored; record unmatched/new faces separately.

Compare normalized corner vectors in the same coordinate frame and report maximum
angular error and affected-corner count. Use a precision-aware angular tolerance,
not exact floating-point equality or rounded-vector hashes. Check normals independently from tangents:
recalculating tangents cannot repair an incorrect normal. Do not globally flatten
curved towers or ornament. If shared-vertex normal handling prevents faithful
export, splitting affected face corners on an export duplicate is a possible
fallback; retain the editable source, monitor serialized vertex growth, and verify
positions, UVs, winding and normals again after conversion.

Inspect fixed-light textured, unlit basecolor and normal-map-disabled views from
both sides before changing texture brightness. A Blender render cannot establish
the destination engine's material resolution or shading.

## UV convention at the GR2 boundary

Record whether an importer consumes raw Granny texture coordinates or converter
output. In the inspected AoE3DE Chinese Town Center, raw GR2 `(u, v)` becomes
`(u, 1-v)` in the configured converter's GXO output and in Blender's image UVs.
A direct raw-buffer importer therefore needs that V conversion once; applying it
again to GXO/FBX-imported UVs would invert an already corrected map. Verify an
asymmetric roof/wall landmark and several corresponding numeric UVs before a
batch import. Treat this as an observed route, not a universal preset for every
GR2 tool or game.

Stock building UVs can overlap and extend outside the unit square. Preserve their
coordinates and whole-tile offsets in authoring/export data. Folding tiles is
useful for an explicitly labelled diagnostic overlay, not a repair operation.
Do not infer shader/team-colour semantics from a U offset alone. A shaded preview
without source skeleton/animation evaluation is a rest-mesh reference, not proof
of the in-game pose.

## Scale and axes

Derive scale and axis settings from a known-working asset in the same toolchain. Record scene units, object and armature transforms, FBX settings, converter settings and in-game bounds together. Never apply a scale correction twice.

When no automated FBX recipe has passed an end-to-end game test, preserve manual export as the fallback. Record the source hash, object list, counts, hierarchy, UV and material layers, full FBX options, converter version, output hash and game-test result.

## Conversion

`scripts/convert_fbx_to_gr2.ps1` accepts an explicit converter executable and writes to a fresh staging directory. It runs the observed `--format=gr2 --bang` interface and checks that a nontrivial GR2 with a recognized header exists. This wrapper does not redistribute a converter and does not prove that the game will load the output.

```powershell
pwsh -File scripts/convert_fbx_to_gr2.ps1 `
  -InputFbx model.fbx `
  -OutputDirectory stage `
  -ConverterPath C:\path\to\converter.exe
```

If the converter blocks on a GUI dialog or fails, inspect the actual message and artifacts. Do not loop retries or install stale output.

Check the application/MCP result as well as the shell exit code: a bridge can
return a structured error while its launcher exits successfully. Stop dependent
conversion after an export error. Verify the intended file set and fresh hashes
before proceeding; do not mix partial output with files from an earlier attempt.
