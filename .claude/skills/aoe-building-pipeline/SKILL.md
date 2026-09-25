---
name: aoe-building-pipeline
description: AoP entry point for building export, materials and deployment. Start here in Age of Pirates; applies this mod's profile and St Pauls/Basilica evidence, then uses aoe3de-building-export for the shared workflow.
---

# AoP building profile

Read [aoe3de-building-export](../aoe3de-building-export/SKILL.md) for the shared rig, export, conversion and texture procedure and [aoe-xml](../aoe-xml/SKILL.md) for this mod's XML rules. Those are the maintained implementations; this skill adds only AoP configuration and worked examples.

For authoring, use [blender-architecture](../blender-architecture/SKILL.md) and [blender-architecture-texturing](../blender-architecture-texturing/SKILL.md) in this repository.

For destructible buildings, use [havok-destruction](../havok-destruction/SKILL.md)
alongside the intact-model workflow. The Korean Town Center donor adaptation is
user-confirmed in game (2026-09-25): preserve the donor body graph, replace the
fractured visible geometry and refit collision hulls. Use that skill's measured
frames and GR2 binding/export checks; the static FBX converter recipe is not the
damaged-model pipeline. A physics experiment can use simple existing materials
while final architecture textures and UVs remain deferred.

Apply the shared skill's local-prerequisite checks before application work. AoP's
installed converter configuration does not travel with exported skills. For GR2
structural evidence in this repository, use `scripts/havok/gr2_dump.py` with its
reader dependencies under the `gr2-granny-edit` skill; do not count the converter
wrapper's header check as structural validation. A consumer of the public building
skill must supply an equivalent inspection capability.

- Read [rig/export evidence](references/rig-export.md) for the Basilica reference, scale and St Pauls geometry/layer failures.
- Read [textures/XML profile](references/textures-xml.md) for the tested material packing, runtime paths and sound/decal references.
- For Asian civilization building research, read [Asian routing and donor evidence](references/asian-building-research.md) before choosing age models or a destruction donor.
- For Asian UV/texture authoring, use the [measured vanilla atlas evidence](references/asian-uv-atlas-evidence.md) and the reusable chart-joining procedure. Coherent facade/roof charts and shared trim precede packing. The Korean per-construction-face unique layouts were rejected despite passing density checks; do not repeat that shortcut.
- Before hidden-face optimization, read [intact/damaged vanilla surface measurements](references/asian-surface-visibility-evidence.md). Vanilla intact shells omit backs that damaged meshes supply separately; retained undersides do not uniformly use much lower texture density. Use per-state visibility certificates rather than a downward-normal delete rule.
- During building blockout, load the active anim component's ground decal in Blender at its declared world dimensions. Use the [decal scale-reference procedure](references/asian-building-research.md#ground-decals-as-scale-references); retain it in a separate reference scene and exclude it from model export and AO bakes.
- Use helpers under `.claude/skills/aoe3de-building-export/scripts/` from the repository root; there is no separate AoP implementation of those scripts.
- Before deployment, follow [mod-deploy-check](../mod-deploy-check/SKILL.md); game operation follows [game-startup](../game-startup/SKILL.md).
