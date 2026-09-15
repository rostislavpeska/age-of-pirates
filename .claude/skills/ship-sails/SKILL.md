---
name: ship-sails
description: Give an Age of Empires III DE ship furling sails (sails lowered when the ship sits, hoisted when it moves) on BOTH its intact and its damaged/destruction model, the vanilla Fuchuan/Frigate way - one idle pose and one walk pose driving sail bones, the damaged model carrying the same bones under animtrans bones below its mast pieces so falling masts take their sails. The complete, repeatable pipeline that produced the mod's Treasure Ship (2026-09-15): Blender analysis and rig, poses, Granny-level model builds from the vanilla files, animfile wiring, verification. Triggers on "animate the sails", "furl the sails", "sail animation", "sails on the damaged model", "masts fall with sails", "treasure ship sails".
---

# Furling sails for a ship (intact + damaged)

## What the engine supports (measured on vanilla files)

- Vanilla ships never skin sails: each sail is a **rigid mesh on its own bone**; motion is bone transforms
  (battleship_walk keys scale/shear per sail; Fuchuan idle/walk are two static poses: furled / hoisted).
- A **non-uniform scale key works only as a pure diagonal** on a bone whose rest rotation is identity, with
  the mesh bound to a CHILD bone (the user's destroyer chain: `_rot` -> scale bone -> `_bottom`). A key that
  mixes rotation and scale is dropped by the engine (the cloth did not compress).
- One anim pair serves both stages when: intact root name == damaged root name == the anim's track group name
  (Frigate/Battleship: `bone_master` everywhere); the damaged model contains every animated bone, each under an
  `animtransNN` bone that is a child of its mast piece and whose world transform is identity, so the anim's
  local values (root-relative in the intact model) stay valid; `<simskeleton>` = damaged model on the anims
  (battleship pattern; the Frigate works without it - keep whichever the test showed working: **with**).
- The poses must key **only the sail bones**. The damaged root rests at 90 deg Y, the intact root at 0, so any
  root-relative constant track (root itself, flags, muzzles, impact points) misplaces those bones on one model.
- Vanilla damaged models weld cloth + bars into the mast pieces (`mast_wood_solid_N`); the
  `sailrigging_cloth_solidhide` pieces are rope strips.

## Pipeline (Treasure Ship = worked example, `S` = a scratch dir)

**0. Vanilla sources** (bar-extract): `spc_treasure_ship_stage_final.gr2` (intact), `spc_treasure_boat_dmg.gr2`
(+ .hkt, .material). The damaged file in the mod already carries the base's 28 bones (muzzles, impacts, flag).

**1. Intact analysis in Blender** (headless, `blender -b --python ...`):
```
python scripts/havok/converter.py --format fbx S/vanilla_intact.gr2      # geometry for Blender
blender -b --python scripts/havok/sails_analyze.py -- S/vanilla_intact.fbx S/analysis   # loose parts, stats, renders -> split.blend
```
**2. Rig + poses** (`sails_rig.py`): shared-vertex grouping (cloth = pure `matb` sheets, bars = thin `mata`
groups in the sail's box; every sheet is its own sail - V-sails split so each half rides its own mast), bones
per sail `bone_sailX_rot -> bone_sailX -> bone_sailX_bottom` (+Y, zero roll, at the sail's bottom centre) and
`bone_sailXmast_NN` per bar (pivot on the mast line); idle = cloth scaled 0.20-0.25 along +Z, bars drop with
the squash and turn by the minimal rotation onto their squashed axis; walk = rest; old base bones copied from
the old base FBX; exports model + idle + walk FBX and rig.blend.
```
blender -b --python scripts/havok/sails_rig.py -- S/analysis/split.blend S/old_base.fbx S/rig
blender -b --python scripts/havok/sails_reexport.py -- S/rig/rig.blend S/rig_clean     # drops flag bones, clears custom normals
```
Let the user look at `rig_clean.blend` (actions `zptreasureship_idle/_walk`) before going on.

**3. Poses and the label table** (the only converter products that reach the game are the anims):
```
python scripts/havok/converter.py --format gr2 S/rig_clean/zptreasureship.fbx S/rig_clean/zptreasureship_idle.fbx S/rig_clean/zptreasureship_walk.fbx
python scripts/havok/converter.py --format gxo S/rig_clean/zptreasureship.gr2            # -> rig GXO: bone table + sail meshes (labels)
python scripts/havok/converter.py --format gxo S/rig_clean/zptreasureship_idle.gr2 S/rig_clean/zptreasureship_walk.gr2
python scripts/havok/anim_tracks.py S/rig_clean/zptreasureship_idle.gxo S/poses/zptreasureship_idle.gxo --keep bone_sail   # same for walk
python scripts/havok/converter.py --format gr2 S/poses/zptreasureship_idle.gxo S/poses/zptreasureship_walk.gxo
```
**4. Intact model at Granny level** (vanilla vertex data untouched):
```
python scripts/havok/gr2_addbones.py S/vanilla_intact.gr2 S/rig_clean/zptreasureship.gxo S/intact_bones.gr2 --inplace --map mirror
python scripts/havok/gr2_splitmesh.py S/intact_bones.gr2 S/rig_clean/zptreasureship.gxo S/zptreasureship.gr2
```
**5. Damaged model**:
```
python scripts/havok/dmg_extract.py art/.../zptreasureship_dmg.gr2 S/rig_clean/zptreasureship.gxo S/dmg.json   # bones, pieces, labels, sail->mast
blender -b --python scripts/havok/dmg_blender.py -- S/rig_clean/rig_clean.blend S/dmg.json S/zptreasureship_dmg_rig.blend   # user verification scene
python scripts/havok/dmg_bonetable.py S/rig_clean/zptreasureship.gxo S/dmg.json S/dmg_bones.gxo   # animtrans_sailNN under each mast + chains/bars
python scripts/havok/gr2_addbones.py art/.../zptreasureship_dmg.gr2 S/dmg_bones.gxo S/dmg_bones.gr2 --inplace --map mirror
python scripts/havok/gr2_splitmesh.py S/dmg_bones.gr2 S/rig_clean/zptreasureship.gxo S/zptreasureship_dmg.gr2
```
then rename the damaged root string to the intact root's name (`bone_main` -> `Object02`, same length or
shorter, in section 0, recompute the CRC - nothing in .hkt/.dmg/xml references it).

**6. Animfile**: `Idle`, `RangedAttack`, `GatherFish` -> `..._idle`; `Walk` -> `..._walk`; on those four anims
`<simskeleton><model>units\...\zptreasureship_dmg</model></simskeleton>`; no flag attachments unless the model
really has those bones (inherited `civflag_a1/a2`, `pendentflag_a3` lines become visible the moment the bones
exist). CRLF preserved (byte-level edits).

**7. Verify** (gr2-granny-edit ladder) both models, then restart the game (user closes it; relaunch watcher).

## Test checklist in game
sails furled at rest, hoisted underway (both stages); after the first damage stage the sails still furl/hoist;
on death masts fall with their sails and bars; progressive destruction; garrison flag on its mast; cannons fire
from the muzzles in both stages; shading identical to vanilla; ship not turned on the stage switch.

## Failure history (each cost a restart - do not repeat)
dark shading = converter-made mesh data; flags appeared = inherited attachments + added banner bones; damaged
sails static = root/model name mismatch (anim did not bind to the sim skeleton); damaged ship turned 90 deg =
root track in the anim; flag/cannons off on the damaged model = non-sail constant tracks; loader crash =
new mesh data in the wrong sections; scale chain positions doubled = GXO b lines treated as parent-relative.

Sources of the finished Treasure Ship (Blender scenes, FBX exports, rig GXO, damaged-model JSON, bone tables,
intermediate Granny files, pristine vanilla gr2s): `scripts/havok/sources/treasureship/` (tracked; backups never
sit beside production files); git tag `treasureship-sails-final`, older stages on branch
`havok-destruction-experiment` (tags `treasureship-furl-v1`, `treasureship-dmg-v2/v3`).

## Converter access (machine-specific, kept out of git)

Every converter call in this skill goes through `python scripts/havok/converter.py` (`--format gr2|gxo|fbx`,
`--bang`, `--modify-gr2 calculatetangents`, `--check`). It reads the gitignored `scripts/havok/converter.local.json`
(copy `converter.example.json`) to pick the backend: `wine-wsl` (the exe under Wine in WSL - this PC, where Smart
App Control blocks it; setup guide = the gitignored **gxo-convert** skill / OneDrive "DE Converter"), `native`
(exe runs directly), `command` (any tool via a template), or `manual` (it prints the file, options and expected
output and waits for you to produce it with a GUI / 3ds Max or Blender plugin / web converter). The pipeline is
identical whichever backend is configured.
