# Rider skeletons, bind pose and seat

Measured 2026-10-10/11 on vanilla files (method in [vanilla unit measurements](vanilla-unit-measurements.md)),
unless a line says recorded or inferred. How animations bind to bones, `gr2_reskeleton.py` and `pose_sim.py` are
documented in [aoe3de-unit-animation](../../aoe3de-unit-animation/SKILL.md); this file gives the skeleton facts a new
rider is built on. Scripts: bind angles and segment lengths `scripts/joint_metrics.py --what bind,segments`; clip
angles `scripts/clip_angles.py`; clip-to-skeleton coverage `scripts/track_coverage.py`; hands
`scripts/shape_metrics.py --what hands` and `--compare`.

## 1. One rider rig family

- Recorded (full vanilla scan, 796 units; re-verify before relying on the count): 114 of 194 regular mounted units
  share one rider rig: `Bip01` bones, spine under the pelvis, thighs under the spine, root `Bip01_Root`. The
  "seated-rest" riders (iron flail, naginata, keshik, steppe) differ from the standing yabusame rider only by the
  root height (1.1418) and rest rotations; their clips drive a standing rider-rig body.
- Animation tracks bind by bone name with keys local to the parent; a bone without a track keeps its rest local
  (`aoe3de-unit-animation/scripts/pose_sim.py` docstring). So the new rider takes a donor skeleton byte for byte:
  names, parents, order, rest transforms, InverseWorld matrices and LOD errors. Never rebuild, rename, reorder or
  re-parent it.
- Names: DE full-LOD skeletons use underscores (`Bip01_L_Hand`); legacy LP skeletons and animfile attach lines use
  spaces and mixed case (`Bip01 L Hand`, `bip01 prop1`). The engine matches a space and an underscore as equal
  (game evidence in `aoe3de-unit-animation`); copy the donor's spelling anyway.

## 2. Bone sets

| Donor | Bones | Contents |
| --- | ---: | --- |
| iron_rider_0 | 32 | the 18 body bones, `Bip01_Root`, `Bip01_Neck`, `Bip01_Prop1`, `Bip01_Prop2`, two ponytail bones, two toe bones, `bip01_attach_rt`, and the flail chain `bone_handle`, `bone_link1`, `bone_link2`, `bone_link3`, `bone_tip` |
| iron_rider_2 | 31 | as above, one bone fewer |
| yabusamerider_0 / _2 | 30 | all `Bip01_*`; `Bip01_Prop1` and `Bip01_Prop2`, no flail chain |
| keshik riders | 26-28 | |
| steppe, naginata, hussar, dragoon riders | 21-22 | |

- **Weighted bones**: every DE full-LOD rider body weights exactly the same 18 bones: Pelvis, Spine, Spine1, Head,
  and left/right Clavicle, UpperArm, ForeArm, Hand, Thigh, Calf, Foot (dragoon_age4: 16). `Bip01_Neck` is never
  weighted, nor Root, Prop1, Prop2, Ponytail, Toe or Nub bones: the head and Spine1 carry the neck. The iron flail adds
  its 5 chain bones (23 weighted).
- **No finger and no twist bones**: hands are rigid mitts weighted to `Bip01_*_Hand`; forearm roll lands on the wrist.

## 3. Segment lengths (fixed by the clips)

Identical on all five riders measured (yabusame, iron flail, keshik, steppe, each full and LP), in engine units:

| Segment | Length |
| --- | ---: |
| Pelvis -> Thigh | 0.101 |
| Thigh -> Calf | 0.506 |
| Calf -> Foot | 0.506 |
| Pelvis -> Spine | 0.116 |
| Spine -> Spine1 | 0.237 |
| Spine1 -> Head | 0.328 |
| Clavicle -> UpperArm | 0.175 |
| UpperArm -> ForeArm | 0.304 |
| ForeArm -> Hand | 0.304 |

Every clip re-imposes these lengths, so a body built to other proportions shifts or stretches.

## 4. Bind pose: standing, never seated

From the InverseWorld matrices (angles in degrees):

| File | Skeleton | Hip flex L/R | Knee | Elbow | Arm from down | Thigh spread |
| --- | --- | --- | --- | --- | --- | --- |
| yabusamerider_0 and _0_lp | `Bip01_Root` / `Bip01 Root` | 5.4 / 5.4 | 8.1 | 26.5 | 26.2 | 7.2 |
| iron_rider_0 and _0_lp | same | 8.3 / 8.1 | 0.1 | 26.5 | 26.2 | 16.4 |
| keshik_rider_rank01 and lp | same | 9.2 / 8.7 | 0.1 | 26.5 | 26.2 | 17.9 |
| steppe_rider_0 | `Bip01_Root` | 4.1 / 4.1 | 0.1 | 26.5 | 26.2 | 8.1 |
| steppe_rider_0_lp | `Bip01 Root` | 9.2 / 8.7 | 0.1 | 26.5 | 26.2 | 17.9 |

- Every vanilla rider is bound standing; the riding pose comes only from the clips. The "seated-rest" bodies are
  straight-legged and lowered by the root height (keshik mesh spans Y -1.14..0.90). The meshes agree: the positions
  each thigh and calf dominate run 2-18 deg from vertical on yabusamerider_0 and iron_rider_0
  (`joint_metrics.py --what axes`).
- An LP skeleton is not always the full model's: steppe_rider_0_lp binds like the keshik, not like steppe_rider_0;
  the iron LP binds 19 bones including Neck; the steppe LP binds 16 with no clavicles. Validate an LP against its
  own donor file.

## 5. Origins differ between files

Joint y-range: yabusamerider_0 0.018..2.119 (root and pelvis at Y 1.142, feet near 0); iron_rider_0 -1.118..1.405;
keshik_rider_rank01 -1.117..0.800; steppe_rider_0 -1.010..0.682 (root and pelvis at the origin, head 0.682 above,
feet about 1.0 below). Never compare positions across files without aligning their frames.

## 6. The pose the clips play

Key 0 of the clips (decoded with `scripts/clip_decode.py`; a converter dump agrees at key 0), measured with
`scripts/clip_angles.py IRON_RIDER_0.gxo CLIP.gxo`:

| Clip | Hip angle off the neck-pelvis axis L/R | Knee | Elbow L/R | Thigh spread |
| --- | --- | --- | --- | --- |
| oprichnik_idle1 | 57.7 / 60.3 | 48.9 / 49.4 | 52.6 / 58.0 | 67.1 |
| sword_idle_a | 57.5 / 59.7 | 49.4 | 51.7 / 57.8 | 67.1 |
| oprichnik_attack_a | 53.0 / 56.6 | 49.4 | 51.7 / 55.0 | 62.9 |

- The hip angle mixes about 50 deg of flexion with about 33 deg of abduction per leg.
- **A converter GXO dump of a clip is a pose at key 0 only** (measured 2026-10-11). From key 1 on its keys leave the
  curves: in oprichnik_attack_a, `Bip01_L_Clavicle`'s rotation curve is three controls equal within 4e-6, with
  identity scale-shear, yet the dump turns that bone and shrinks it (det 0.97 by key 17, 0.0003 by key 159, 5.3 by
  key 279); the horse_idle_a dump reaches det 4e8. Orthonormalizing does not recover such keys: orthonormalized, the converter's
  oprichnik_idle1 drops iron_rider_0's head 75 GXO units below its pelvis and its horse_idle_a sinks the yabusame
  horse's `bone_attachpoint` to z -55. Decoded, the head stays 0.266-0.267 above the pelvis and the seat at
  0.795-0.799. The right knee of 0-120 deg once reported for oprichnik_idle1 was this artifact: decoded, it holds
  49.4. `pose_sim.py` and `clip_angles.py` now refuse such keys (determinant check).
- **Extremes, decoded** (`clip_decode.py`, then `clip_angles.py`, every one of the 289 keys): oprichnik_attack_a on
  iron_rider_0 reaches hip flexion 105 right at key 133 (left 70), knee 87 left at key 209 and 85 right at key 201,
  spine bend 58 at key 139, upper arm from down 115 right at key 125 (left 81), elbow 111 right at key 130 (left 98
  at key 91), thigh spread 63-75. oprichnik_attack_C decodes to the same values. Reading every control as a key at its
  knot time (`--method knots`) moves these maxima by at most 2 deg; during the strike (keys 127-137, where the right
  forearm turns up to 35 deg between consecutive controls) that reading runs about one key ahead, so a single key can
  differ by up to 20 deg. The earlier list built on orthonormalized converter keys is withdrawn: hip 105, knee 87 / 85,
  spine bend 57-58 and elbow 111 hold; the left upper arm reaches 81, not 126, and no knee range starts at 79. These
  are the poses a pose test (G2/G3) must deform cleanly through. Death clips are unmeasured.
- Seated on yabusamehorse_0 with the decoded horse_1-5_attack_A (the horse clip the iron flail animfile lists first
  for Attack_melee), iron_rider_0 and its flail stay between z -0.02 (the flail tip) and 1.57 over every fourth key
  of oprichnik_attack_a: the donor reference for the mounted check at extreme keys.
- The "spine twist" metric mixes clavicle and arm motion; it is not torso twist.

Iron Flail clip set (from `asians/chinese/iron_flail/iron_flail_rider.xml`, 30 clips): oprichnik_attack_A-D,
oprichnik_idle1, idle2, idle03, idle4-8, oprichnik_bored_A, gallop, jog, iron_flail_rider_walk00,
oprichnik_raze_idle_A-D and F-I (there is no E), raze_attack_A, oprichnik_deathA-C, rider_death_havoc_a/b.

## 7. Weapons on the skeleton

- **Rigid weapons** (swords, lance, gun, bows, hats) are separate one-bone GrannyModels attached by the animfile to
  `Bip01 Prop1`, a hand bone or `HEAD`. A custom attach bone needs a `<definebone>` line or the attachment drops to
  the model origin ([aoe3de-model-attachments](../../aoe3de-model-attachments/SKILL.md)).
- **The iron flail is skinned in**: chain `Bip01_Prop1` > `bip01_attach_rt` > `bone_handle` > `bone_link1` >
  `bone_link2` > `bone_link3` > `bone_tip`. In the bind, `bone_handle`, `Bip01_Prop1` and `bip01_attach_rt` sit
  exactly at the right-hand pivot; the links sit 0.345, 0.715 and 1.04 from it and `bone_tip` 1.386 (segments about
  0.35 / 0.37 / 0.33 / 0.35). The left hand sits at `Bip01_Prop2`, 0.914 from the right hand.
- `oprichnik_attack_A` animates 32 tracks, the five chain bones and `bip01_attach_rt` included. The clips key every
  link's **position** and rotate each link independently, like a whip: a rigid long pole with a hinge only at the tip
  cannot ride them. The options for a different weapon: a rigid prop on `Bip01 Prop1` with clips made for a polearm
  (the naginata rider's lance clips carry a 3.10-unit lance, grip 0.875 from the butt, 2.227 to the tip); new hinge
  bones with new clips; or a skinned chain with new clips. The owner chooses.
- A bone is added only if a clip the unit plays has a track for it (check with `gr2_dump.py --tracks` on every clip
  the animfile references); appending bones in place is `unit-bones` (`gr2_addbones.py`).

## 8. Choosing the donor

The donor depends on what the new model is, not on one rule for every rider:

- **A new rider that plays the flail clips** (a new body and skinned flail, built in the donor's bind pose):
  **iron_rider_0, 32 bones**, byte for byte. Evidence, 2026-10-11:
  - Clip coverage (`track_coverage.py --animfile asians/chinese/iron_flail/iron_flail_rider.xml`, all 30 clips it
    references): every track of 29 clips finds a bone of iron_rider_0; the 30th (iron_flail_rider_walk00) adds only a
    `Bip01 Footsteps` marker track that no rider skeleton has. The yabusame rider (30 bones) has no bone for
    `bip01_attach_rt`, `bone_handle`, `bone_link1-3` and `bone_tip`, which 28 of the 30 clips key: the flail could
    not move. The keshik rider lacks the same six; iron_rider_2 (31 bones) lacks `Bip01_Ponytail11`, keyed by 28
    clips.
  - Root height does not matter: all 30 clips key `Bip01_Root` (rotation and position), so the posed skeleton ignores
    the rest root. Posed by the same decoded keys (`pose_sim.py`, all 289 keys of oprichnik_attack_a and all 833 of
    oprichnik_idle1), the 26 bones iron_rider_0 and yabusamerider_0 share land on identical positions (difference
    0.0). The yabusame rest root at Y 1.1418 only moves where the body is modelled (feet at 0 instead of -1.118).
  - No transplant is involved: `gr2_reskeleton.py`'s refusal of a lowered "seated-rest" donor concerns putting an
    existing body on another skeleton, not a body modelled in the donor's own bind pose.
  - The iron flail weights exactly the planned set: 18 body bones plus the 5 chain bones (23), Neck unweighted.
  - Readable (not Oodle-compressed), round-trips through `donor_to_blend.py` and `rig_table.py`
    ([export routes](export-routes.md), section 2).
  - Cost: its bind pose has straight knees (0.1 deg) and a 16.4 deg thigh spread, and its frame puts the pelvis at
    the origin; its LP skeleton binds 19 bones including Neck (validate an LP against its own donor file).
- **An existing foot body put on a horse** (a transplant, no new geometry): the yabusame rider (standing rest)
  through `gr2_reskeleton.py`, which refuses a donor whose bound joints differ by more than 0.005 engine units or
  1 deg; a lowered "seated-rest" donor fails that against a standing target
  (`<consumer-root>/scripts/havok/gr2_reskeleton.py`). Recorded in project memory on 2026-10-09; re-verify on the file
  you use.
- **Other weapons**: adding the five chain bones to another rig is possible (`gr2_addbones.py`) only after
  `pose_sim.py` proves the clips on it, before any modelling; a rigid prop needs no chain (section 7).
- Run `track_coverage.py` on the unit's own animfile for every candidate, and record the choice and its proof in the
  handoff.

## 9. Hands and feet

- Every measured DE rider uses an identical stock hand: x-extent 0.121, y 0.146, z 0.142-0.143, at x +/-0.406..0.527
  in rest pose, about 52 triangles per hand, 24-30 unique positions, mostly rigid. `shape_metrics.py --compare A B`
  aligns the two hands (hand joint, then a rigid shift of 0.004-0.011 engine units) and finds 73-100 % of one rider's hand positions
  within 1 mm of the other's (keshik, yabusame, iron flail, steppe, hussar, dragoon, naginata). Copying that geometry
  into a new model is copying vanilla geometry: the consumer's asset policy decides (AoP: AGENTS rule 2, owner's word).
- Feet: 28-37 positions, mostly rigid (23/28 to 29/29), one ankle row blended at about 0.5; toe bones unbound.

## 10. Horses and the seat

- DE horses: `root_x` rig (Auto-Rig-Pro-style names such as `spine_01_x`, `thigh_stretch_l`, `c_tail_00_x`), 32 bones
  (34 on the dragoon horse), 27 weighted (25), with unweighted `bone_saddle`, `bone_attachpoint`, `bone_hitpointbar`.
  Legacy LP horses use `HS Bone Master` rigs (29 or 45 bones) that share no tracks with the DE horse clips.
- The horse animfile includes the rider animfile and seats it:
  `<attach a="Rider" frombone="hotspot" tobone="ATTACHPOINT" syncanims="1" />`; every anim name the unit plays must
  exist in both files, and projectiles leave on the horse animation's Attack tag (`aoe3de-unit-animation`).
- Seat calibration with `pose_sim.py` (vanilla yabusame rider on its horse, cavalry idle): rider z 0.406..1.179.
- Never model, copy or reskin a horse for a rider unit: the horse animfile references a vanilla horse by archive path
  (every DE horse is the same base mesh, 1326-1430 triangles).

## 11. Mirroring in Blender

Blender never pairs `Bip01_L_*` / `Bip01 L *` names (`bpy.utils.flip_name` returns them unchanged, measured in Blender
5.1.2): mirror weights by the rename or mapping method in
[blender-organic-modeling](../../blender-organic-modeling/references/skinning-pose-tests.md), section 5.
