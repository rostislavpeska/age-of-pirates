---
name: aoe-building-pipeline
description: Prepare static AoE3DE building rigs, FBX-to-GR2 conversion, textures, materials and minimal animation XML with measured verification and manual export fallback.
---
# AoE3DE buildings
**Prerequisite: the `aoe-xml` skill** (CRLF, references by archive path, placement, `xmlcheck.py`) - this skill only adds the model/texture/material recipe.
Generic geometry/UV authoring belongs in the separate architecture skill repository. This version covers static buildings; multi-bone units, ships and war machines need a separately verified extension.
Read [rig/export/converter](references/rig-export.md) before rigging/conversion, and [textures/XML/game](references/textures-xml.md) before packaging.

- Identify the correct Blender process/file/scene, installed asset and known-working reference. Preserve checkpoints, hashes and tool versions.
- Verify geometry, rig, weights, materials and serialized FBX structure separately. Do not change diffuse textures to diagnose exploding vertex buffers. Do not exclude XML/path faults from invisible-model investigation.
- Use one documented export/converter recipe. When the user requires manual FBX export, prepare/preflight the model and wait for the fresh exported file. NEVER replace it with automatic export or silently rewrite that FBX.
- Convert into fresh staging, then verify output structure, counts, bindings and dependencies before installing. A successful exit or plausible header is not game verification. Treat blocked GUI dialogs separately.
- Keep art and `_snds` XML plain, and **CRLF**. An LF-only animfile or `.material` is silently ignored by the engine: the unit
  places, the decal draws, the model never renders (Tower of London, 2026-09-17, ten restarts). Run `python scripts/tools/check_art_eol.py`
  (`--fix` converts) after writing any art XML and before every game test; when a model "does not appear", check line endings first. Data-XMB requirements do not authorize art/sound XMB conversion.
- Report Blender, converter and user game-test status separately. Do not call an asset game-ready based only on Blender or converter success.

After failure retain the artifacts and a falsifiable hypothesis. A second failure with the same recipe means inspect actual FBX/GR2/reference evidence, not another blind export. Change one variable at a time, preserve the working fallback and record the first successful end-to-end recipe.
