---
name: unit-bones
description: Add bones to a vanilla Age of Empires III DE model without re-exporting it - garrison flag, civ flag / banner points, cannon muzzles (bone_muzzleL/R##), projectile impact points (boneimpact##), attachment bones - into the intact model AND its damaged/destruction model, so the mod's animfile, .dmg damage templates and attachments find them. Uses the Granny-level appender (scripts/havok/gr2_addbones.py) with a bone table from a Blender rig (rig_table.py), from a GXO dump of a model that has the bones, or written by hand. Also the rule for an attach bone in a converter-built (GXO -> gr2) model: a child of the one root, never a second root (that model is not drawn at all). Triggers on "add a bone", "garrison flag bone", "muzzle bones", "impact points", "attachment bone", "bone_prop", "the model vanished after adding a bone", "the damaged model is missing bones", "cannons fire from the wrong place".
---

# Adding bones to vanilla models

Never re-export the model for this: `gr2_addbones.py` appends bone records into the raw vanilla gr2 in place
(meshes and skinning untouched, file stays uncompressed and vanilla-identical otherwise). Proven on the Treasure
Ship intact and damaged models (28, 115, 96 bones appended in various rounds; cannons fire outward, flag sits right).

## Where the bone table comes from

Table format = GXO `b` lines (absolute model-space transform, row-major 3x3, 1-based parent, 0 = root; grammar in
**gr2-granny-edit**). Three sources, in order of preference:

1. **A Blender rig** (no converter): place the bones in a rig scene (armature scale 0.01, data in engine units,
   x across, y along, z up; blender = M.T . engine) and write the table straight from the scene:
   `blender -b RIG.blend --python scripts/havok/rig_table.py -- TABLE.gxo`.
2. **A model that already has the bones** (e.g. the mod's older converter-made base model): dump it to GXO with
   your converter -> `MODEL.gxo`. The appender skips names that already exist in the target and, with `--only`,
   takes just the listed bones.
3. **Hand-written**: any text file with `b` lines. Generators: `scripts/havok/dmg_bonetable.py` (animtrans
   chains for a damaged model) - copy its pattern. Frame: x across, y along, z up with engine = (-gx, gz, -gy);
   positions in engine units.

```
python scripts/havok/gr2_addbones.py VANILLA.gr2 TABLE.gxo OUT.gr2 --inplace --map mirror [--scale 2.54] [--only bone_garrisonflag bone_muzzleL01 ...]
python scripts/havok/gr2_dump.py OUT.gr2 --bones | grep -E "bone_garrison|muzzle"     # positions / parents
OUT.gr2 -> GXO with your converter (optional loader test: it runs the game's Granny DLL)
```
`--scale 2.54` only when the table came from a GXO dumped from a VANILLA gr2 (Maya units); tables from Blender
or from converter-made models are already in engine units.

## Rules learned the hard way

- **Muzzles**: local +Y must point outward; the GXO 3x3 is row-major and must be transposed when read (the
  appender does) - untransposed, all 24 cannons fired inward.
- **Parents**: bones may be chained (parent = another new bone) or hung under an existing bone (a mast piece);
  the appender computes the local transform from absolute world transforms.
- **Damaged model needs the same bones** as the intact one, or `<simskeleton>` anims and attachments
  (`tobone="..."`) break; put animated bones under `animtrans` bones (see **havok-destruction**), static ones
  (muzzles, impact points, garrison flag) directly under the root - but then keep them OUT of the animation
  tracks (the two roots' rest transforms differ; see **ship-sails**).
- **Flag/banner bones**: only add `bone_banner_a1..a3` / `bone_flag_civ` if the ship should show those flags.
  The mod's animfiles inherit battleship attachment lines (`civflag_a1`, `civflag_a2`, `pendentflag_a3`) that
  are inert until the bones exist; the Treasure Ship must show the garrison flag only.
- **Follow the actual donor's flag mounts.** The Treasure Ship uses a separate
  garrison mast; that is not a universal building rule. The Chinese age-2 Town
  Center has civ and garrison attachment bones at different heights on one mast.
  Its damaged model parents them to `animtrans01` and `animtrans02`, respectively;
  do not apply the static ship attachment rule blindly. See the measured
  [Town Center evidence](../aoe-building-pipeline/references/asian-roof-normal-evidence.md#town-center-flag-mounts).
- **Animations override the rest pose**: a Blender-baked anim carries a constant track for every bone; moving a
  bone in the model does nothing while such an anim plays. Filter tracks (`anim_tracks.py`) or re-export.
- `LODError` 1304.65 for added bones (vanilla value); InverseWorld = inverse(world).T; verified on 151 bones.

## Converter-built models (GXO -> gr2): the attach bone goes UNDER the one root

Bone bench 2026-09-26: the St Paul's Home City model in six variants that differ only in their `b` lines,
one editor generation, the bunting attached with `<attach frombone="ATTACHPOINT" tobone="bone_prop">`:

| Variant | Skeleton | In game |
|---|---|---|
| A | `bone_prop` root (identity), old root `Bone` its child | renders, bunting in place |
| B | `Bone` root + `bone_prop` second root, bunting attached | **model not drawn** |
| B2 | the same two roots, nothing attached | **model not drawn** |
| C | `bone_prop` child of `Bone` (parent 1), identity | renders, bunting in place, right scale |
| D | `bone_prop` child of `Bone`, transform = inverse of Bone's matrix | renders, bunting gone |
| E | `Bone` only | renders |

- **Never a second root in a converter-built model.** B2 shows the root itself hides the model, not the
  attachment; the same model vanished from the Home City and the main menu. `converter.py --format gr2`
  refuses such a GXO (`--allow-multi-root` overrides). Vanilla files do ship with 2+ roots (16 of 10,084
  skeletons, e.g. `homecity\inca\inca_harbour`) and render - the ban is for converter output.
- **Add the bone as a child of the existing root (C)** and write its ABSOLUTE model-space transform, as
  every `b` line is: identity = the model origin in the mesh frame, where an attachment modelled in that
  frame belongs. The old root keeps the converter's axis/scale matrix; rig and animation tracks stay intact.
  Re-parenting the root (A) also renders but changes the hierarchy of an animated model.
- **Never pre-compensate the parent (D).** The converter derives the local transform itself; an
  inverse-of-parent line shrank and turned the attachment out of sight.
- Before any game test, diff the bone lines against the last model seen working
  (`grep '^b "' known_good.gxo candidate.gxo`). Several candidate fixes go into ONE variant grid
  (**rm-unit-bench**), not one game restart each.

## Where the bones must be declared

Every custom bone an `<attach tobone>` names must be declared with `<definebone>` in that animfile (vanilla: 39/39
horse, 26/26 flag attaches; undeclared, the attachment sits at the model origin - Korean stable 2026-10-08,
**aoe3de-model-attachments**). Engine tags such as `ATTACHPOINT`, `ROOT`, `MASTER` need none. `.dmg` damage templates
name `boneimpact*` and `bone_debris_*`; the engine finds the garrison flag by `bone_garrisonflag` and the civ
flag by `bone_flag_civ`.

Related: **gr2-granny-edit** (formats, GXO grammar, verification ladder), **ship-sails**, **havok-destruction**.

## Converter: not part of the repo, any tool that reads/writes GXO or FBX will do

Source 2 above and the optional loader test are the only places a converter appears; produce the GXO with
whatever you have. `python scripts/havok/converter.py --format gxo MODEL.gr2` is a convenience wrapper: with a
backend configured in the gitignored `scripts/havok/converter.local.json` (copy `converter.example.json`) it runs
the conversion; with none (`manual`, the default) it prints what to produce and waits for the file. The owner's
converter-specific skill (`gxo-convert`, gitignored) lives in OneDrive `DE Converter\claude-skills\gxo-convert`,
shared by all the owner's devices - link or copy it into `.claude/skills/` there.
