# AoP rig/export profile and observed failures

The common procedure and validation tools are in [aoe3de-building-export](../../aoe3de-building-export/SKILL.md). This page records AoP-specific evidence.

## Basilica-compatible profile

Use the original working Basilica FBX as the comparison reference. The requested FBX scale is **0.01**; account for scene units, armature/object transforms and converter scale together so it is not applied twice. This is a reference-specific value, not a universal preset.

Use the exact `mata`, `matb`, `matc` names for this building. Run `skills/aoe3de-building-export/scripts/inspect_static_rig.py` in Blender with `--materials mata matb matc`. The complete successful FBX settings were not recovered as a reusable preset: retain the user's manual-export fallback and capture its options after a confirmed game test.

## St Pauls worked example

The joined landmark was reported at roughly 227k exported vertices / 103k triangles. Logical splitting substantially improved game rendering. This did not establish a universal engine limit: source/evaluated counts and serialized vertex buffers differ. The landmark's approved budget exception must not carry into a new asset. The architectural authoring target remains 10–20k evaluated vertices plus 5k tolerance unless otherwise approved.

`Layered geometry data in mesh ... is not supported` refers to serialized FBX layer data, not necessarily overlapping physical faces. Compare Layer/LayerElement records, mapping/reference modes and connections with the working Basilica. Extra UV/color/material layers were suspects, not a proven universal cause. Preserve authoring/AO layers in the source and simplify only the export duplicate.

## Local converter

The existing configurable wrapper is `scripts/havok/converter.py`; machine settings belong in ignored `scripts/havok/converter.local.json`. The skill-local PowerShell wrapper is now maintained only in `skills/aoe3de-building-export/scripts/convert_fbx_to_gr2.ps1` and accepts an explicit executable path. It uses the observed `--format=gr2 --bang` interface. Neither wrapper proves game compatibility from a header or exit code. Inspect a stalled converter dialog before another attempt.
