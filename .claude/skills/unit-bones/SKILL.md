---
name: unit-bones
description: Add bones to a vanilla Age of Empires III DE model without re-exporting it - garrison flag, civ flag / banner points, cannon muzzles (bone_muzzleL/R##), projectile impact points (boneimpact##), attachment bones - into the intact model AND its damaged/destruction model, so the mod's animfile, .dmg damage templates and attachments find them. Uses the Granny-level appender (scripts/havok/gr2_addbones.py) with a bone table taken from a converter GXO or written by hand. Triggers on "add a bone", "garrison flag bone", "muzzle bones", "impact points", "attachment bone", "the damaged model is missing bones", "cannons fire from the wrong place".
---

# Adding bones to vanilla models

Never re-export the model for this: `gr2_addbones.py` appends bone records into the raw vanilla gr2 in place
(meshes and skinning untouched, file stays uncompressed and vanilla-identical otherwise). Proven on the Treasure
Ship intact and damaged models (28, 115, 96 bones appended in various rounds; cannons fire outward, flag sits right).

## Where the bone table comes from

Table format = converter GXO `b` lines (absolute model-space transform, row-major 3x3, 1-based parent, 0 = root):

1. **A model that already has the bones** (e.g. the mod's converter-made base model, or a Blender rig exported
   through the converter): `python scripts/havok/converter.py --format gxo MODEL.gr2` -> `MODEL.gxo`.
   The appender skips names that already exist in the target and, with `--only`, takes just the listed bones.
2. **Hand-written**: any text file with `b` lines. Generators: `scripts/havok/dmg_bonetable.py` (animtrans
   chains for a damaged model) - copy its pattern. Frame: converter frame (x across, y along, z up) with
   engine = (-gx, gz, -gy); positions in engine units.
3. **From Blender**: place bones in a rig scene (armature scale 0.01, data in engine units, blender = M.T . engine),
   export FBX (settings in `scripts/havok/sails_rig.py`, bottom), converter -> gr2 -> gxo -> table.

```
python scripts/havok/gr2_addbones.py VANILLA.gr2 TABLE.gxo OUT.gr2 --inplace --map mirror [--scale 2.54] [--only bone_garrisonflag bone_muzzleL01 ...]
python scripts/havok/gr2_dump.py OUT.gr2 --bones | grep -E "bone_garrison|muzzle"     # positions / parents
python scripts/havok/converter.py --format gxo OUT.gr2                                 # loader test
```
`--scale 2.54` only when the table came from a GXO dumped from a VANILLA gr2 (Maya units); converter-made GXOs
are already in engine units.

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
- **Do not put two flag bones on one mast**; the garrison flag has its own mast.
- **Animations override the rest pose**: a Blender-baked anim carries a constant track for every bone; moving a
  bone in the model does nothing while such an anim plays. Filter tracks (`anim_tracks.py`) or re-export.
- `LODError` 1304.65 for added bones (vanilla value); InverseWorld = inverse(world).T; verified on 151 bones.

## Where the bones must be declared

Animfile `<definebone>` lines are optional for attachments but keep them consistent; `.dmg` damage templates
name `boneimpact*` and `bone_debris_*`; the engine finds the garrison flag by `bone_garrisonflag` and the civ
flag by `bone_flag_civ`.

Related: **gr2-granny-edit** (formats, verification ladder), **ship-sails**, **havok-destruction**.
