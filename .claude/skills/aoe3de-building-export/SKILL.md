---
name: aoe3de-building-export
description: Reusable cross-mod workflow for static Age of Empires III DE building rigs, FBX-to-GR2 conversion, textures, materials and animation XML. Use after geometry and UV authoring; apply a consuming project's building profile first when one is provided.
---

# Static AoE3DE building export

Generic geometry and UV authoring belongs in a modeling skill. This skill begins when an approved building must be rigged, converted and packaged for AoE3DE.

Read [rig and conversion](references/rig-export.md) before rigging or converting. Read [textures and XML](references/textures-xml.md) before producing runtime assets.

Use the companion [reference library](../aoe3de-reference/SKILL.md) for XML field
lookup and the scoped runtime XML profile. Check [local-tool readiness](../skill-library-audit/references/local-tools.md)
before relying on installed applications or connections.

## Required workflow

Check prerequisites for the step being performed. Blender and its `bpy` runtime
are needed for the rig audit; ordinary Python cannot run that helper. The texture
validator needs Python and **Pillow**. Conversion needs PowerShell and a separately
installed converter compatible with `--format=gr2 --bang`, supplied explicitly via
`-ConverterPath`. The wrapper does not install or include that converter.

Before conversion, identify a GR2 inspector capable of reading actual meshes,
bones, bindings and bounds. That inspector is an external capability in this
package; do not substitute the wrapper's header check. If unavailable, retain the
staged output and report structural validation as blocked, without deploying it.

For live Blender or Photoshop work, verify the actual connection, active file and
unsaved state before edits. Photoshop is required only when the chosen source or
workflow needs it; an agreed compatible editor may suffice otherwise. Preserve
layered source fidelity. A discovered executable does not establish compatibility,
a valid license or a working automation connection. Missing tools block only the
dependent step; do not install, upgrade or silently substitute them during preflight.

1. Identify the exact Blender file, scene, export objects, installed target and a known-working game reference. Preserve hashes and checkpoints.
2. Audit source and evaluated geometry, armature modifiers, deform weights, UV layers, material slots, transforms and bounds independently. `scripts/inspect_static_rig.py` is a read-only Blender audit, not proof of converter or game behavior.
3. Export from a duplicate prepared for the verified target profile. Triangulate only the export copy and inspect its diagonals.
4. If the operator performs or supplies a manual FBX export, treat that file as authoritative. Do not silently replace it with an automated export or regenerate it.
5. Convert into an empty staging directory. Verify the actual GR2 structure, mesh/bone bindings, counts, dependencies and bounds before installation. A successful converter exit and a valid header are only sanity checks.
6. Keep editable texture sources synchronized with shipped TGA/DDT outputs. Once an operator manually corrects a PSD or equivalent source, export from that live source; do not rerun an earlier generator over it.
7. Validate material and animation XML against a working target asset, then apply the consuming mod's line-ending, XMB and reference rules.
8. Report Blender validation, conversion validation and in-game validation separately.

After a failure, retain the artifacts and test one falsifiable hypothesis. A repeated failure with the same recipe requires inspection of the actual FBX/GR2/XML evidence before another export.
