# Static rig and conversion

## Reference and rig

Inspect a known-working AoE3DE building in a separate comparison scene. Record its root type, bone hierarchy, bind/rest matrices, mesh transforms, Armature modifiers, weights, material slots, bounds and scale. Match observed behavior; an Outliner icon alone is not evidence.

For a rigid building mesh, use a real armature and deform bone when required by the verified profile. Every intended vertex needs finite deform weights referencing existing deform bones. In a single-bone rigid case, each weight should sum to 1.0. Do not blindly apply transforms after binding.

Run the included audit from the skill directory:

```bash
blender model.blend -b --python scripts/inspect_static_rig.py -- --out report.json --materials mata matb matc
```

Limit `--objects` when the scene contains reference meshes. Change `--materials` to the exact slots accepted by the target profile. The report does not prove bind matrices or serialized output.

## Counts and topology

Track evaluated vertices and triangles per mesh and globally, then inspect serialized FBX/GR2 counts. UV seams, split normals, material boundaries and skinning can increase exported vertex buffers. Do not infer a universal engine limit from triangle count or from one asset.

Avoid joining logical building sections merely for convenience. If a consuming project has a per-mesh or total budget, monitor both throughout modeling and export.

Prepare an export duplicate with only the intended UV/color/attribute layers for the verified converter recipe. Multiple material slots do not by themselves mean FBX layered textures. Triangulate only the export copy and inspect long or crossing diagonals around windows, curved walls and ledges.

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
