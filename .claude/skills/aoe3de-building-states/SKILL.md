---
name: aoe3de-building-states
description: The state contract of an Age of Empires III DE building - construction stages (BuildingCompletion p0/p33/p66/p100, vanilla scaffold stages, our last-construction model), intact, damaged/destruction and death - and the rules every state model must keep - same frame as the intact model, per-state attachments and flags, construction content (no props, fences or flags; connected frame; one wall-seated ladder), donor-bound destruction with hidden framing evidence, export gates. Ships state_frame_check.py (a construction/damaged GR2 must sit in the intact model's frame). Use when adding or wiring construction or destruction states, when "the construction model is rotated / offset", "the building appears immediately built", "a flag floats over the construction", or before handing a building to a game test. Tested port of the AoE Buildings method docs (korean-buildings-blender docs/methods, 2026-10-08).
---

# AoE III DE building states

Ported on 2026-10-08 from the AoE Buildings parent-project methods (`korean-buildings-blender`:
`docs/methods/aoe_building_states.md`, `docs/methods/construction_models.md`, written by Codex/Astra and
Claude), with every engine claim checked against vanilla files, this repo's skills or today's game tests.
Section 7 lists what is verified and what is still policy or unverified.

## 1. Make the state contract first

Per building, before any blockout: proto, civ/age branch, animfile, and for every branch the condition,
selected GR2s/materials/HKT/simskeleton, every attachment (name, animfile, bone, full transform), retained /
replaced / excluded part IDs and atlas bindings. Inspect the matching Japanese/Chinese vanilla building
(`aoe3de-bar-archives`: `bartool.py cat|extract`). A file named `_con` or `_damaged` binds nothing by itself.

## 2. Construction stages

Vanilla Asian buildings (bansho, stable, Japanese TC - verified) route construction like this; confirm the
thresholds per building:

```xml
<component>korean_tc<logic type="BuildingCompletion">
    <p0><submodelref ref="..._construction_stage_01" /></p0>     <!-- asi_4x4_stage1 (vanilla) -->
    <p33><submodelref ref="..._construction_stage_02" /></p33>   <!-- asi_4x4_stage2 + asi_4x4_frame at ATTACHPOINT -->
    <p66><submodelref ref="..._construction_stage_03" /></p66>   <!-- OUR last construction model -->
    <p100><submodelref ref="..._built" /></p100>                 <!-- the existing intact/destruction content -->
</logic></component>
```

- Project policy: author **only the last construction stage**; reuse the vanilla p0/p33 stages of the matching
  Japanese building (owner: "use the previous with scaffolding from Japanese"). No new scaffold or texture set.
- Wrap the existing animfile content unchanged as the p100 submodel (keep `<definebone>` lines at the top);
  verify byte identity of that content after wrapping. Recipes must be idempotent: never wrap twice.
- Without this block a building appears finished the moment construction starts (Korean TC, 2026-10-08).

## 3. Every state model shares the intact model's frame

Construction and damaged GR2s must place every retained surface exactly where the intact GR2 has it.
The export frame is per asset: the Korean TC was exported through the converter with `rotate_y_deg 90`; its
construction model written with the military axis map came out **90 deg about engine Y** in game.

```bash
python .claude/skills/aoe3de-building-states/scripts/state_frame_check.py --intact art/.../X.gr2 --state art/.../X_con.gr2
python .claude/skills/aoe3de-building-states/scripts/state_frame_check.py --intact art/.../X.gr2 --state art/.../X_damaged.gr2
```

It pairs own-page corners by UV in the serialized models (compressed ones through the DLL flat route),
solves the rigid transform and requires identity on >= 80 % inliers. Run it for every state before a game
test; record the asset's export frame next to its recipe.

## 4. Construction model content (project policy)

- Keep: foundations, platforms, finished lower walls, posts, windows, doors, gates, masonry boundary walls,
  built-in stall partitions - same geometry, UVs, material slots and own pages.
- Remove: props and furnishings (weapons, racks, pots, barrels, hay, mangers, hitching posts, mounting blocks),
  timber fences and yard enclosures, flags/masts/finials, finished roofing. Declared exclusion list by part
  prefix; a renamed part must fail the build.
- Add: a connected fresh-timber frame (contact graph; ridge on rafters/posts), an unfinished upper part, at
  most one temporary ladder seated on a measured wall (both stiles touch, feet on the declared contact plane,
  z = 0 for land buildings, docks need their own contract). New members use the shared parts atlas only.
- Flags: no `bone_flag_civ` / `bone_garrisonflag` in the construction skeleton (**aoe3de-model-attachments**
  `attachment_check.py` enforces it); removing a mast mesh alone does not remove a flag.
- Count textures and material groups in the serialized model, not Blender slots.

## 5. Destruction is a separate derivative of the intact model

- Start from the intact source and a hashed donor GR2/HKT pair; never from the stripped construction model.
  Construction-only exclusions do not remove intact props/fences from destruction; ladders never become debris.
- Keep the donor body graph, names, properties, pivots, motion and masses; map every fragment to a body
  explicitly; every triangle binds to one bone (`gr2_lint` bindings). Reserve flagpole bodies.
- Cut faces get caps on the shared atlas (end grain / mineral core), never stretched exterior UVs.
- Hidden interior framing: record covering bodies, clearance and exposure; test visibility through the
  actual alpha across the camera envelope. Zero visible samples is evidence for that sampling, not proof.
  Known leak classes: open eave/header slots, tile cutouts at embedded beam ends, ridge caps
  (Korean Barracks r69a-d; Stable r69e-h).
- Write with the donor-preserving writer; require the game DLL read, serialized UV/material/bone checks and a
  refit hull check - CRC or a Python parse alone is not enough. Keep the donor's Destruction/Death/simskeleton
  routing. Attachment bones go into the damaged model too (**aoe3de-model-attachments**).

## 6. Gates

| Gate | Evidence |
|---|---|
| Before geometry | state/attachment table, donor hashes, exclusion list, source revision |
| Authoring | saved/reopened rest comparison, contact graph, ground probes, UV sheets, front/back/interior views |
| Export | DLL read, `gr2_lint` (bindings, UV contract, budget), `state_frame_check.py` for every state, `attachment_check.py` |
| Game | slow construction through every stage boundary and completion, flags/horses/props, first damage to final debris |
| Handoff | per-state files and hashes; candidate / installed / owner-accepted kept separate |

Do not launch the game without authorization; offline gates never prove physics or attachments in game.

## 7. What was verified (2026-10-08)

| Claim (method docs) | Status | Evidence |
|---|---|---|
| Vanilla last construction at p66, intact at p100 | verified for bansho, stable, Japanese TC | vanilla animfiles (Korean repo `construction_study_r63`) |
| Earlier stages: `asi_4x4_stage1`, then `asi_4x4_stage2` + `asi_4x4_frame` at ATTACHPOINT | verified | same files; unitbench pre-flight resolves them |
| Engine flags hang on `bone_flag_civ` / `bone_garrisonflag` | verified in project history | **unit-bones** (Treasure Ship); owner rule for construction models |
| `<definebone>` does not create a GR2 bone | verified | Korean TC: 103 definebones, construction GR2 7 bones |
| Converter output with a second root is not drawn | verified | **unit-bones** bone bench 2026-09-26 |
| Animation tracks override rest transforms | verified in project history | **unit-bones** / **ship-sails** |
| "The Korean Stable once lost the horse's rotation (90 deg)" | **corrected** | the 2026-10-08 failure was missing bones in the simskeleton (origin + identity rotation); bone orientation equals vanilla |
| Compare construction and intact in one frame | was policy only -> **now enforced** | TC 90 deg incident; `state_frame_check.py`, regression test |
| Damaged model keeps intact attachments | verified as a requirement | horses failed without bones in the damaged simskeleton |
| Exported triangles bind to one bone; DLL load required | enforced | `gr2_lint` bindings / dll_read |
| Hidden-frame visibility envelope, cover/exposure | method | Korean r69 records; not game-verified |
| Physics behavior of hidden beams, flag following supports | **unverified** | needs the owner's game test |

Tests: `tests/test_state_frame.py` (synthetic + the TC regression, marked `local`: needs the DLL route).
Related: **aoe3de-model-attachments**, **aoe-building-pipeline**, **aoe3de-destructible-building**,
**havok-destruction**, **unit-bones**, **aoe-xml**, **rm-unit-bench**.
