---
name: aoe3de-building-export
description: Prepare and verify static Age of Empires III DE building rigs, FBX-to-GR2 conversion, textures, materials and minimal animation XML. Use after geometry and UV authoring when packaging a building for an AoE3DE mod.
---

# Static AoE3DE building export

Generic geometry and UV authoring belongs in a modeling skill. This skill begins when an approved building must be rigged, converted and packaged for AoE3DE.

Read [rig and conversion](references/rig-export.md) before rigging or converting. Read [textures and XML](references/textures-xml.md) before producing runtime assets.

## Required workflow

1. Identify the exact Blender file, scene, export objects, installed target and a known-working game reference. Preserve hashes and checkpoints.
2. Audit source and evaluated geometry, armature modifiers, deform weights, UV layers, material slots, transforms and bounds independently. `scripts/inspect_static_rig.py` is a read-only Blender audit, not proof of converter or game behavior.
3. Export from a duplicate prepared for the verified target profile. Triangulate only the export copy and inspect its diagonals.
4. If the operator performs or supplies a manual FBX export, treat that file as authoritative. Do not silently replace it with an automated export or regenerate it.
5. Convert into an empty staging directory. Verify the actual GR2 structure, mesh/bone bindings, counts, dependencies and bounds before installation. A successful converter exit and a valid header are only sanity checks.
6. Keep editable texture sources synchronized with shipped TGA/DDT outputs. Once an operator manually corrects a PSD or equivalent source, export from that live source; do not rerun an earlier generator over it.
7. Validate material and animation XML against a working target asset, then apply the consuming mod's line-ending, XMB and reference rules.
8. Report Blender validation, conversion validation and in-game validation separately.

After a failure, retain the artifacts and test one falsifiable hypothesis. A repeated failure with the same recipe requires inspection of the actual FBX/GR2/XML evidence before another export.
