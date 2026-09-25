---
name: aoe-building-pipeline
description: AoP entry point for building export, materials and deployment. Start here in Age of Pirates; applies this mod's profile and St Pauls/Basilica evidence, then uses aoe3de-building-export for the shared workflow.
---

# AoP building profile

Read [aoe3de-building-export](../aoe3de-building-export/SKILL.md) for the shared rig, export, conversion and texture procedure and [aoe-xml](../aoe-xml/SKILL.md) for this mod's XML rules. Those are the maintained implementations; this skill adds only AoP configuration and worked examples.

For authoring, use [blender-architecture](../blender-architecture/SKILL.md) and [blender-architecture-texturing](../blender-architecture-texturing/SKILL.md) in this repository.

Apply the shared skill's local-prerequisite checks before application work. AoP's
installed converter configuration does not travel with exported skills. For GR2
structural evidence in this repository, use `scripts/havok/gr2_dump.py` with its
reader dependencies under the `gr2-granny-edit` skill; do not count the converter
wrapper's header check as structural validation. A consumer of the public building
skill must supply an equivalent inspection capability.

- Read [rig/export evidence](references/rig-export.md) for the Basilica reference, scale and St Pauls geometry/layer failures.
- Read [textures/XML profile](references/textures-xml.md) for the tested material packing, runtime paths and sound/decal references.
- For Asian civilization building research, read [Asian routing and donor evidence](references/asian-building-research.md) before choosing age models or a destruction donor.
- Use helpers under `.claude/skills/aoe3de-building-export/scripts/` from the repository root; there is no separate AoP implementation of those scripts.
- Before deployment, follow [mod-deploy-check](../mod-deploy-check/SKILL.md); game operation follows [game-startup](../game-startup/SKILL.md).
