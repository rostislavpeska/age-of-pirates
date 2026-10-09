---
name: aoe3de-unit-animation
description: How Age of Empires III DE units are animated and how to change it safely - animfile anims a unit's tactics need, mounted units (horse animfile including a rider, matched horse/rider pairs, projectile release on the horse's Attack tag), how animations bind to bones (by name, keys local to the model's parent, root/model names), putting an infantry body on a rider skeleton (gr2_reskeleton.py), and previewing a pose without the game (pose_sim.py on converter GXO). Use when a unit "stands still while building", "floats above the horse", "shoots before the bow is drawn", "has no pickup/build/knockout animation", when borrowing animations from another unit, mounting a foot model, or before an owner game test of a unit's animations.
---

# Unit animation (animfiles, rigs, timing)

A unit's look in motion comes from three layers: the **tactics** name the animation each action plays, the
**animfile** maps each name to GrannyAnim files (with tags that time events), and the **skeleton** of the model decides
whether those animation files drive it at all. Each layer failed once on the Korean monk (2026-10-09); the rules below
are what fixed them, each with its guard.

## 1. Every animation the tactics name must exist and move

- Collect `<anim>` names from the unit's tactics actions; a builder (`<type>Build</type>`) also needs `Build`,
  `BuildLifting`, `BuildSaw`, `BuildStaking` (the engine picks per building); explorers need `Pickup` (treasure) and
  their knockout set (`Knockout`, `KnockoutIdle`, `Recover`; DE has no mounted knockout: alias them, a known debt).
- An alias that copies `Idle` "exists" but stands still: the monk froze while building and picking up treasure.
  Borrow a real matched pair instead - for mounted Asian heroes General Kichiro (`spc_kichiro_horse/rider`: `Pickup`,
  `Build*`, `Smokescreen`), plus the attachments those blocks attach (hammer, smoke).
- Guard: the Koreans' `test_every_tactics_animation_exists_and_moves` (every tactics anim present in the animfile and
  in every included animfile, never only the idle files, attachments defined).

## 2. Mounted units: two animfiles, one clock

- The horse animfile is the unit's; it includes the rider animfile as an attachment and seats it with
  `<attach a="Rider" frombone="hotspot" tobone="ATTACHPOINT" syncanims="1" />` (rider origin on the horse's seat bone).
  Every anim name the unit plays must exist in BOTH files.
- **Projectiles leave at the HORSE animation's `Attack` tag**, while the rider animation draws the bow. Take the
  horse's and rider's attack blocks from one vanilla unit: the generic cavalry `bow_attack_A-D` rider anims match the
  generic `horse_1-5_attack_A-D` tags (0.62 / 0.43 / 0.43 / 0.43, the Manchu archer); the yabusame's own horse attacks
  fire at 0.28 and shot before the draw. Swap the horse's block, never only the rider's.
- Guard: `test_monk_arrows_leave_with_the_bow_release` (Koreans add-on).

## 3. How an animation drives a model

- Tracks bind to bones **by name**; each key is **local to the bone's parent in the model** (Granny does not retarget);
  bones without a track keep their rest local; the track group goes by the root/model name (a root rename made one
  animation pair drive both Treasure Ship stages, `gr2-granny-edit`).
- So a model whose joints sit where the animation's skeleton has them can still pose wrongly if its **hierarchy**
  differs: the Shaolin Disciple (spine under the root, thighs under the pelvis, root `Bip01`, no neck) floated about
  1 m above the saddle with the cavalry idle; the yabusame rider (spine under the pelvis, thighs under the spine, root
  `Bip01_Root`) sits.
- Fix without touching a mesh byte: `scripts/havok/gr2_reskeleton.py DONOR TARGET OUT` gives the target the donor's
  skeleton and names; it refuses missing bound bones or joints that differ. Then `skinned-model-check` and a bench.

## 4. Preview a pose without the game

```bash
python .claude/skills/aoe3de-unit-animation/scripts/pose_sim.py --model RIDER.gxo --anim RIDE.gxo --out <scratch>/posed.obj \
       --mount HORSE.gxo --mount-anim HORSE_IDLE.gxo [--skeleton-from DONOR.gxo]
blender -b --factory-startup --python .claude/skills/aoe3de-unit-animation/scripts/render_obj.py -- <scratch>/posed \
       <scratch>/posed.obj RIDER.png <scratch>/posed_mount.obj HORSE.png
```

- GXO text from the GR2 converter (`gxo-convert`: `--format gxo`; it refuses animation-only files as FBX but dumps
  them as GXO). Only **key 0** of a converter animation dump is a clean pose: judge frame 0.
- Calibration (vanilla yabusame rider + horse, cavalry idle): rider z 0.406..1.179 seated. Disciple as is
  0.825..1.324 (floating); with `--skeleton-from` the rider and as built 0.406..1.148 (seated). The owner's game test
  confirmed the built file rides.
- Bone names match like the engine: a space equals an underscore (`Bip01 Head` track drives `Bip01_Head`; about 20
  vanilla `Bip01_*` models, the Ashigaru and Inca spearman among them, play the spaced `pikemen_charge_*` set).
  The library is universal: a foot body with `Bip01_Prop1` takes the pikeman set and a polearm on `Bip01 Prop1`
  (the Koreans' Seungbyeong, 2026-10-09: the Sohei animfile with the `Bip01` twin of each `*_pikeman` file).
- **Scale trap**: the converter dumps the older library animations (`pikemen_charge_*`) at 2.54x the scale of a DE
  model's GXO (head offset 0.328 against 0.129), which shows a giraffe neck that the game does not have (the gr2 says
  0.328 for both). Before judging, compare one bone's key translation with the model's rest offset and scale the
  key translations by that ratio.
- The simulation proves the seat and the pose at one frame; motion, timing and in-game binding are the game test's
  (bench: `aoe3de-model-test-unit`).

Related: `gr2-granny-edit` (GR2 tools, GXO format), `skinned-model-check` (weights and skeleton proof),
`aoe3de-model-attachments` (attach/sync), `aoe-xml` (animfile grammar), `gxo-convert` (converter under Wine).
