---
name: aoe3de-model-attachments
description: Attachments on Age of Empires III DE models end to end - the animfile XML side (<attachment>/<include>, <attach a frombone tobone syncanims>, which component and which simskeleton resolve the bone, BuildingCompletion stages, flags) and the Blender/GR2 side (where attachment bones come from, frames, rotation AND scale, adding them to the intact and the damaged model). Ships attachment_check.py (every tobone resolves in every model and simskeleton; no flag bones on construction stages) and add_bones.py (explicit position/rotation/scale bone appender). Use before attaching horses, flags, smoke, fire, props or scaffolds to a building or unit, and when "attached props appear at the origin", "two horses on top of each other", "the attachment is rotated", "a flag floats over the construction", "the flag is missing", "attachment works intact but not damaged".
---

# Attachments on models: XML and Blender

An attachment is two things that must agree: an **animfile** line that names a bone, and a **bone** that exists,
with the right transform, in every skeleton the engine uses at that moment. Bone mechanics (appending, GXO
tables, converter roots) are in **unit-bones**; this skill covers the wiring, the resolution rule and the checks.

## 1. The XML side

```xml
<submodel>korean_stable_built
  <attachment>horse1<include>buildings\native_civs\corral\iroquois_horse1.xml</include>
  </attachment>                                         <!-- definition: an include or an inline <component> -->
  <component>LIVE<logic type="Destruction">
      <p1><assetreference type="GrannyModel"><file>...\korean_stable_physics_damaged</file></assetreference></p1>
      <p99><assetreference type="GrannyModel"><file>...\korean_stable_physics</file></assetreference></p99>
    </logic>
    <attach a="horse1" frombone="bone_master" tobone="bone_horse1" syncanims="1" />   <!-- live, per state -->
    ...
  </component>
  <anim>Idle<component>LIVE</component>
    <simskeleton><model>...\korean_stable_physics_damaged</model></simskeleton></anim>
  <anim>Death<component>DEAD</component>
    <attach a="collapse_smoke" frombone="ATTACHPOINT" tobone="ATTACHPOINT" syncanims="0" /></anim>  <!-- event -->
</submodel>
```

- `a` names the `<attachment>`; `tobone` is a bone of the **host** model; `frombone` a bone of the attached
  model (vanilla stables use `bone_master`, which the DE horse skeleton lacks - the engine then uses the horse
  model's origin; vanilla ships it this way and its stables show their horses).
- An `<attach>` inside a `<component>` is live while that component shows; one inside an `<anim>` belongs to
  that animation/event (Death smoke). An attach inside a logic branch (LowPoly `<normal>`) applies to that
  branch only: vanilla stables keep the horse bones out of their `lp_*` models.
- `ATTACHPOINT` is engine-provided (the model origin), never a GR2 bone: all 66 vanilla scaffold/frame
  attaches are `frombone="ATTACHPOINT" tobone="ATTACHPOINT"`.
- **Declare every custom attach bone with `<definebone>` at the top of the host animfile.** Without it the
  engine cannot register the name and the attachment drops to the model origin with no rotation, even when every
  GR2 has the bone (Korean stable, 2026-10-08). Vanilla declares every one: 39/39 horse and 26/26 flag attaches;
  the undeclared vanilla names are engine tags (`ATTACHPOINT`, `ROOT`, `MASTER`, `HEAD`, `PROP1/2`, `PELVIS`,
  `R/L HAND`, `Bip01 ...`) or dead typos. The game's own messages: "Couldn't register bone name", "...the bone
  was not defined in the unit's anim XML". A `<definebone>` does **not** create a bone in a GR2 (the Korean TC
  declares 103, its construction GR2 has 7): declaration and bone are both required.
- Runtime art XML is CRLF (**aoe-xml**); write paths with real backslashes - an escaped `\n` inside
  `buildings\native_civs` once turned into a line break.

## 2. The resolution rule (measured 2026-10-08)

**The `tobone` must be declared with `<definebone>` in the animfile, AND exist in every model the component can
show AND in the `<simskeleton>` model of every anim that plays the component.** If any of the three is missing
the attachment drops to the **model origin with identity rotation** - with two horses that looks like "one over
another, wrong rotation". The 2026-10-08 Korean stable failed twice: first bones only in the intact GR2, then
(after the damaged GR2 got them, cc76b0ac) still no `<definebone>` - same picture in game both times.

| Model | `bone_horse*` | Horse bone transform |
|---|---|---|
| vanilla `east_stables_2age.gr2` (intact) | 1, 2, 3 under `Bone_main` | quat (0, .7071, 0, .7071), scale .8, flags 7 |
| vanilla `east_stables_age2_damaged.gr2` | 1, 2, 3 under `bone_master` | identical |
| Korean stable intact (2026-10-08 b6e4344f) | 1, 2 | identical to vanilla |
| Korean stable damaged (b6e4344f) | **none** -> both horses at the origin in game | - |
| Korean stable animfile (b6e4344f..d6866a9c) | no `<definebone>bone_horse1/2</definebone>` -> still at the origin with the bones in both models | - |

Vanilla carries the bones in both skeletons; the Korean fix appended the same two bones to the damaged model
(meshes, bone order and HKT untouched). **unit-bones** already said "the damaged model needs the same bones";
the check below now enforces it. Census of all 551 vanilla building animfiles (models read from the BAR
archives): every one of the 34 horse attaches under a simskeleton has the bone in the simskeleton model; vanilla
also ships dead attaches whose bone exists nowhere, so "vanilla does it" never excuses a missing bone in ours.
Details: [vanilla evidence](references/vanilla-evidence-2026-10-08.md).

Facing: with the vanilla horse transform the horse's head points to raw +X; in vanilla stables the heads point
out through the open stall front. The Korean stable follows that (mangers behind the horses); turn both bones
180 deg about raw Y, in both models, if the heads should face the mangers.

## 3. Per-state attachments (buildings)

| State | Attachments | Rule |
|---|---|---|
| Intact (BuildingCompletion p100) | civ/garrison flags, horses, smoke, props per the building's contract | bones in intact AND damaged/simskeleton models |
| Last construction stage (p66, project policy) | no flags, horses or props; the vanilla scaffold base `asi_4x4_stage2` at `ATTACHPOINT`, as every Japanese p66 stage (owner 2026-10-08: "attach the scaffold too") | the construction GR2 must not carry `bone_flag_civ` / `bone_garrisonflag`: the engine hangs the player flag on those names even without an `<attach>` line. A donor skeleton passes them on silently - audit and rename/remove. Its `BONE_HITPOINTBAR` sits where the finished model's does (a donor skeleton brings the donor's) |
| Earlier vanilla stages (p0/p33) | vanilla scaffold attached at `ATTACHPOINT` | keep the vanilla routing |
| Damaged / destruction | as intact while assembled; a flag follows its surviving support | **havok-destruction** animtrans rules; never root-parent everything blindly |
| Death | debris/smoke events | anim-level `<attach>` |

## 4. The Blender / GR2 side

- **Frames.** Blender world (x right, y forward, z up) -> engine raw = (-X, Z, -Y). Some assets are exported
  through the converter with an extra turn (Korean TC: `rotate_y_deg 90`); a bone or state model built with a
  different frame lands turned (**aoe3de-building-states** `state_frame_check.py`).
- **Where bones come from.** Writer route (`multimaterial_gr2.replace`): the skeleton is the donor's, copied
  verbatim - it brings the donor's flag/hitpoint/attachment bones with it. Converter route: bones from the
  scene/GXO, attach bones as children of the one root, never a second root (**unit-bones**).
- **Transform = position + rotation + scale.** Vanilla attachment bones can carry scale (stable horses .8);
  `gr2_addbones.py` (GXO tables) writes identity scale, so use `scripts/add_bones.py` here for scaled or
  explicitly rotated bones:

```bash
python .claude/skills/aoe3de-model-attachments/scripts/add_bones.py IN.gr2 TABLE.json OUT.gr2 [--from-blender]
# TABLE.json: [{"name": "bone_horse1", "parent": null, "pos": [1.085, -3.42, 0], "rot_blender": [[0,1,0],[-1,0,0],[0,0,1]], "scale": 0.8}]
```

  Run it on the intact AND the damaged model with the same table. It reproduces the Korean stable fix byte
  for byte (test). Measure clearance against the real model before placing anything that stands (horses).
- **Removing a donor bone you must not keep** (construction flag): rename it in place to a same-length
  harmless name and recompute the Granny CRC - recipe `strip_flag_bone_r71.py` in the Korean repo's
  `research/Construction_13/recipes_r67_r71/matc1024_r71/`.

## 5. Checks, in order

```bash
python .claude/skills/aoe3de-model-attachments/scripts/attachment_check.py art/<path>/<model>.xml   # static, seconds
python .claude/skills/aoe3de-model-attachments/scripts/attach_plot.py X_damaged.gr2 units\natives\iroquois\axe_rider\axe_rider_1_horse --bones bone_horse1,bone_horse2 --out view.png
python scripts/havok/gr2_lint.py ... <folder>                                                     # dll_read, bindings
```

`attach_plot.py` draws the host (a height slice, top view, game display frame) with the attached model at each
bone's rest transform and an arrow for its facing; look at it before any game test (inside the bay, clear of
posts, facing like the vanilla building). `attachment_check.py` resolves mod-local GR2s; vanilla archive
models are reported NOT CHECKED, never as passed. Offline checks never prove the game shows the attachment:
finish with section 6.

## 6. See it in game

The attachment test that counts is a look at the placed building (**aoe3de-trigger-camera**): a test map with the
building and Camera Cut views aimed at the attachment bones, run through the Scenario Editor's Playtest.

```bash
python scripts/aitest/camera_bench.py gen --proto zzKoreanStablePhysics --tag korstable --bones art/zbench_korean_military/stable/korean_stable_physics.gr2:bone_horse1,bone_horse2 --headings 60,90,120
python scripts/aitest/camera_bench.py editor --tag korstable
```

- Bone to world for a building placed by the random map: world = unit position + (-raw x, raw y, -raw z).
- The two failure pictures differ: an unresolved bone puts the attachment at the model origin, unrotated (several
  attachments stacked there); a resolved bone with a wrong transform puts it somewhere else, turned.
- Report the stills with the verdict; the owner's acceptance stays separate.

## 7. Incidents this skill exists for (2026-10-08)

- Korean stable horses at the stall-wing origin, sideways: bones only in the intact GR2 (b6e4344f, fixed in
  cc76b0ac) AND no `<definebone>` for them (still at the origin in the owner's game after cc76b0ac; declared in
  30b76906). The first fix was declared done from offline checks that did not cover the declaration. After
  30b76906 both horses stand in the first and third bays facing out: verified in game by the owner and in the
  first camera bench run (2026-10-08).
- Korean construction models carried `bone_flag_civ` from the donor skeleton (513928bd, fixed in 7585fc4c).
- Tests: `tests/test_attachments.py` keeps both as regression cases against git history.

Related: **unit-bones**, **aoe3de-building-states**, **havok-destruction**, **aoe-xml**, **gr2-granny-edit**.
