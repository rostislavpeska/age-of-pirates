---
name: aoe-building-pipeline
description: Apply the Age of Pirates building profile and St Pauls/Basilica evidence to the reusable AoE3DE export workflow, including AoP XML, material and deployment conventions.
---

# AoP building profile

Read [aoe3de-building-export](../aoe3de-building-export/SKILL.md) for the shared rig, export, conversion and texture procedure and [aoe-xml](../aoe-xml/SKILL.md) for this mod's XML rules. Those are the maintained implementations; this skill adds only AoP configuration and worked examples.

For authoring, use [blender-architecture](../blender-architecture/SKILL.md) and [blender-architecture-texturing](../blender-architecture-texturing/SKILL.md) in this repository.

- Read [rig/export evidence](references/rig-export.md) for the Basilica reference, scale and St Pauls geometry/layer failures.
- Read [textures/XML profile](references/textures-xml.md) for the tested material packing, runtime paths and sound/decal references.
- Use helpers under `skills/aoe3de-building-export/scripts/` from the repository root; there is no separate AoP implementation of those scripts.
- Before deployment, follow [mod-deploy-check](../mod-deploy-check/SKILL.md); game operation follows [game-startup](../game-startup/SKILL.md).
