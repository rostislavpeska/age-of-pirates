# Textures, materials and animation XML

## Texture profiles

Derive channel packing, color space, alpha behavior, dimensions, compression and mip count from a working material using the same shader. Base color is normally color data; normals and packed masks are normally non-color data. Confirm normal handedness and mask channels instead of treating arbitrary RGB contrast as stronger normals or AO.

The included `validate_opaque_textures.py` checks one **verified profile** only: 2048×2048, 24-bit RGB TGA without alpha, paired with an RTS3 DXT1 DDT containing ten mip levels and flags `0,0,4,10`. It validates structure and compression error, not artistic quality, tangent handedness or shader packing.

```bash
python scripts/validate_opaque_textures.py texture.tga texture.ddt
```

Texture-only edits do not normally require FBX/GR2 re-export unless UVs, geometry, material bindings or vertex data also changed.

### Re-encoding an existing runtime texture (measured 2026-10-08, Korean military/TC)

- **Prove the codec first:** re-encode the untouched source and require a byte-identical DDT before
  encoding new maps (the Korean r60 BaseColor DXT5 and Normals DXT1 both reproduced byte-for-byte).
- **16-bit PNG sources:** load with `cv2.imread(..., IMREAD_UNCHANGED)` and `np.rint(v/257)`. Pillow
  silently truncates 16-bit RGBA to 8-bit; the re-encoded normals then differed from the installed DDT.
- **Normal edits keep the installed per-atlas transform:** build detail in the source convention,
  blend there (RNM), then apply exactly the transform the installed DDT already uses for that atlas.
  The Korean sources were all OpenGL, but the installed maps were G-flipped (Barracks/Stable) and
  R-flipped (Town Center); new relief must follow each atlas's own transform or it inverts in game.
- **Gutters before mips:** after changing chart texels, refresh the gutter at least ~48 px out.
  The writer's Lanczos mip filter reaches old gutter colours at mip 4 that an 8 px refresh leaves
  (measured halos up to 25 levels on 20-27 border texels per atlas).

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
# Shared normal textures include a tangent convention

Pin a reused normal texture's channel convention **and the consuming mesh's tangent
basis**, in addition to image/UV identity. The same image can shade differently
after a serializer change even when CRC, density, materials and native loading pass.
Compare source and decoded runtime normal samples under all four red/green sign
combinations, then test reconstructed world normals on real receiver triangles.
Do not recompress a protected shared map to repair one new consumer.

Korean military r58 / INC-131: the accepted TC prop DDT used red-flip/green-as-is
for the old converter, whereas the new derivative-based writer used green-flip-only.
A material-specific, evidence-pinned change negated tangent T and derived B while
retaining handedness. It changed only the prop tangent XYZ in both model states;
UVs, geometric normals, weights, triangles and shared image bytes stayed identical.
Four targeted/native tests and actual prop samples confirmed the compensation.
This is a measured compatibility case, not a universal instruction to flip tangents.
