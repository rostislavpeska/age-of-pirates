# AoP rig/export profile and observed failures

The common procedure and validation tools are in [aoe3de-building-export](../../aoe3de-building-export/SKILL.md). This page records AoP-specific evidence.

## Basilica-compatible profile

Use the original working Basilica FBX as the comparison reference. The requested FBX scale is **0.01**; account for scene units, armature/object transforms and converter scale together so it is not applied twice. This is a reference-specific value, not a universal preset.

Use the exact `mata`, `matb`, `matc` names for this building. Run `.claude/skills/aoe3de-building-export/scripts/inspect_static_rig.py` in Blender with `--materials mata matb matc`. The complete successful FBX settings were not recovered as a reusable preset: retain the user's manual-export fallback and capture its options after a confirmed game test.

## St Pauls worked example

The joined landmark was reported at roughly 227k exported vertices / 103k triangles. Logical splitting substantially improved game rendering. This did not establish a universal engine limit: source/evaluated counts and serialized vertex buffers differ. The landmark's approved budget exception must not carry into a new asset. The architectural authoring target remains 10–20k evaluated vertices plus 5k tolerance unless otherwise approved.

`Layered geometry data in mesh ... is not supported` refers to serialized FBX layer data, not necessarily overlapping physical faces. Compare Layer/LayerElement records, mapping/reference modes and connections with the working Basilica. Extra UV/color/material layers were suspects, not a proven universal cause. Preserve authoring/AO layers in the source and simplify only the export duplicate.

## Local converter

The existing configurable wrapper is `scripts/havok/converter.py`; machine settings belong in ignored `scripts/havok/converter.local.json`. The skill-local PowerShell wrapper is now maintained only in `.claude/skills/aoe3de-building-export/scripts/convert_fbx_to_gr2.ps1` and accepts an explicit executable path. It uses the observed `--format=gr2 --bang` interface. Neither wrapper proves game compatibility from a header or exit code. Inspect a stalled converter dialog before another attempt.

## British Elector castles: shading and missing floors, 2026-09-24

Observed with Blender 5.1.2 and the configured native GXO converter. The first
in-game screenshot showed dark/light facade patches and magenta tiled floors
despite successful conversion, XML checks and a Blender GR2 round-trip preview.

**Confirmed normal failures:** the export attribute allowlist deleted
`custom_normal`, changing some corner normals by about 49 degrees relative to the
edited source. A deeper comparison also found retained-body normals already
damaged during extraction. Restoring only the edited source's normals was therefore
insufficient. A focused BMesh/deform-layer removal probe preserved normals; that
probe did not establish BMesh as the cause of every earlier shading change.

The repair recovered all 570 retained facade triangles / 1,710 corners from the
original Elector GR2s using complete UV triangles and geometry, allowing the
body's vertical translations. Export-only corner splits avoided shared-vertex
normal changes. Final GR2 normals matched the originals within 0.02 degrees.
Positions, UV layouts and 15,818 total triangles were retained; no texture pixels
were changed. Tangents were recalculated separately. Front/rear textured, unlit
and normal-map-disabled renders were inspected. These are offline results.

**Floor binding change, engine confirmation pending:** the first exports used
`matfloor` in both the GR2 and XML. The repair changed both to the existing Tower
of London floor's `matb`, retaining its map paths. The set uses `mata`, `matb`,
`matd`; `mata` references `elector_palace_g_mata_Stuart_BaseColor` for the requested
gray-stone treatment. The correspondence checks passed, but no post-repair game
screenshot had been obtained when this note was written. Do not treat the rename
as a proven engine fix or infer a universal four-character material-name limit.

The new authoring source is `British_Elector_Palace_Set_v12_OriginalNormals.blend`;
the inspected export records are in its sibling `GR2_Export/Repair_final` directory
outside the mod. Keep machine-specific paths and temporary previews out of skills.
The remaining acceptance step is a full game reload and visual check. Respect the
user's requirement to ask before desktop control; offline success is not permission
to operate the game.
