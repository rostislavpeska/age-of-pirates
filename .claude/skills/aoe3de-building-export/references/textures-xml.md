# Textures, materials and animation XML

## Texture profiles

Derive channel packing, color space, alpha behavior, dimensions, compression and mip count from a working material using the same shader. Base color is normally color data; normals and packed masks are normally non-color data. Confirm normal handedness and mask channels instead of treating arbitrary RGB contrast as stronger normals or AO.

The included `validate_opaque_textures.py` checks one **verified profile** only: 2048×2048, 24-bit RGB TGA without alpha, paired with an RTS3 DXT1 DDT containing ten mip levels and flags `0,0,4,10`. It validates structure and compression error, not artistic quality, tangent handedness or shader packing.

```bash
python scripts/validate_opaque_textures.py texture.tga texture.ddt
```

Texture-only edits do not normally require FBX/GR2 re-export unless UVs, geometry, material bindings or vertex data also changed.

## Editable source

Keep the editable source synchronized with exported TGA/DDT files. Preserve simple semantic masks for material regions when repeated color or AO tuning is expected. Once the operator makes a manual correction, the current editable file is the source of truth. Export its live state and retain the previous shipped file as a checkpoint outside runtime folders.

AO should reinforce real recesses without baking contradictory shadows across reused atlas islands. Inspect critical junctions, windows, ledges and overlapping modules from fixed comparison views. Repair targeted masks or UVs without changing unrelated islands.

## Material and animation XML

Read a working `.material` and animation XML from the target game profile. Resolve each exported material slot to its intended maps. Use double-sided rendering deliberately for surfaces that are intended to be visible from both sides; do not use it as a substitute for broken topology.

Reuse the known-working submaterial names for that profile. Check the actual GR2
mesh-to-material binding, exact XML submaterial name, selected material variant,
shader definition and every texture path. Renaming a Blender slot or an XML entry
alone is insufficient; update and inspect the serialized binding too. Matching
names and existing texture files are necessary offline checks, not proof that the
engine resolves the material. Do not invent universal material-name length rules
from one failure or call a renamed material fixed before an in-game check.

A minimal static building commonly needs an idle animation referencing a component that contains the intended Granny model. Copy only the structure required by the chosen reference. Do not inherit unrelated attachments, state machines, bones, decals, sounds or animations.

**Engine behavior must be verified in the consuming mod:** runtime XML line endings, whether a file stays plain XML or needs an XMB twin, path roots, archive references, and reload/restart requirements. These rules vary by file family and should come from the mod's XML skill or validated project documentation.

## Diagnosis

Separate these failure classes before changing files:

- missing editor entry: data definitions, ids and references;
- placeable but invisible model: runtime XML, paths, scale, bounds or bindings;
- exploding or partially missing geometry: serialized buffers, rig, topology or converter limits;
- magenta/missing surface: material binding/name, variant, shader or texture resolution, followed by the engine's required reload;
- surface artifacts: overlapping faces, triangulation, normals, UVs, texture islands or AO.

For unexpected dark/light patches, first compare corner normals with the original
asset and inspect the tangent basis. Isolate unlit basecolor, normal-map-disabled
shading and the final material before recolouring textures or altering masks.

Test the same unit, file version and camera view after each focused change. Keep source files, conversion staging and distributable runtime assets in distinct locations.
