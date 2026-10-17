---
name: aoe3de-building-states
description: "Validate AoE3 DE construction, intact and damaged building states for matching frames, bindings and attachments. Use when authoring, exporting or diagnosing building-state transitions."
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
    <p66><submodelref ref="..._construction_stage_03" /></p66>   <!-- OUR last construction model + asi_4x4_stage2 at ATTACHPOINT -->
    <p100><submodelref ref="..._built" /></p100>                 <!-- the existing intact/destruction content -->
</logic></component>
```

- Project policy: author **only the last construction stage**; reuse the vanilla p0/p33 stages of the matching
  Japanese building (owner: "use the previous with scaffolding from Japanese"). No new scaffold or texture set.
- The p66 stage also shows the vanilla scaffold base, exactly as every Japanese p66 stage does: `asi_4x4_stage2`
  as an `<attachment>` of the stage submodel, `<attach frombone="ATTACHPOINT" tobone="ATTACHPOINT" syncanims="0">`
  after the stage component's decal (owner 2026-10-08: "attach the scaffold too"; Korean TC/Barracks/Stable,
  recipe `scaffold_p66_r73.py`). Some of its material piles always end up inside the building - vanilla too
  (18-39 % of the piles, see **aoe3de-model-attachments** vanilla evidence).
- 697 of 721 vanilla BuildingCompletion logics use p0/p33/p66/p100; others exist (0/1/50/100, 0/25/50/75/100,
  0/66/100 ...), so read the donor's thresholds.
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

It pairs own-page corners by UV in the serialized models (compressed ones through the DLL flat route; on a PC
without that route a compressed intact model is replaced by its raw `_damaged` twin, which shares the frame - the
report names the reference used), solves the rigid transform and requires identity on >= 80 % inliers. Run it for every state before a game
test; record the asset's export frame next to its recipe.

## 4. Construction model content (project policy)

- Keep: foundations, platforms, finished lower walls, posts, gates, masonry boundary walls, built-in stall
  partitions - same geometry, UVs, material slots and own pages.
- Windows and doors are removed; the frame and the wall stay. Owner 2026-10-11, morning: "con model shouldn't have
  windows and doors if these are separate shapes and not baked to texture, if baked like Town center, they must stay".
  Evening, after reviewing every construction model, he withdrew the Town Center exception: "TownCenterCon -> strip
  all the wooden pannels and leave only the beams", "Barracks and  stables construction - strip windows and doors,
  houses too".
  - Removed: separate window and door shapes (frames, lattices, paper, door leaves, shutters), and wooden door and window
    panels that are faces of their own, even when their art is painted on (the Korean TC plank doors and lattice
    windows), with the interior backing directly behind them.
  - Stays: posts, sills, headers and plaster wall panels; the wall keeps its rough opening.
  - Art painted onto a continuous wall face that also carries the wall cannot go without new geometry: ask the owner.
  - A frame kept without its wall hangs in the air (Korean Dock r2: 96 of 102 frame pieces floating).
- Remove: props and furnishings (weapons, racks, pots, barrels, hay, mangers, hitching posts, mounting blocks),
  timber fences and yard enclosures, flags/masts/finials, finished roofing. Declared exclusion list by part
  prefix; a renamed part must fail the build.
- Add: a connected fresh-timber frame (contact graph; ridge on rafters/posts), an unfinished upper part, at
  most one temporary ladder seated on a measured wall (both stiles touch, feet on the declared contact plane,
  z = 0 for land buildings, docks need their own contract). New members use the shared parts atlas only.
- Flags: no `bone_flag_civ` / `bone_garrisonflag` in the construction skeleton (**aoe3de-model-attachments**
  `attachment_check.py` enforces it); removing a mast mesh alone does not remove a flag.
- **A p66 filtered from the intact payload** (no new members) is valid when the kept parts read as a structure. The
  Korean Market kept masonry, posts, girders, sills, lintels, floor bands, rafters and gallery decks, and dropped roofs,
  walls, attics, gables, brackets, opening frames, lattice, rails, bins, goods, thatch, signs, the mast and props. In the
  float check, every part touching the ground plane is a root, not only named plinths: the stall posts stand directly on
  the ground. Market: 190 parts, all grounded.
- `BONE_HITPOINTBAR` at the finished model's position on every stage. A donor skeleton brings the donor's:
  the Korean TC stage had the Barracks bar at 9.05 m instead of the TC's (2.3284, 11.6993, -0.3933) until r73.
- Count textures and material groups in the serialized model, not Blender slots.
- **Gate the authored scene with `logic_qa.py`** (**blender-overlap-cleanup** and its logic-QA reference): run it from
  the construction recipe on the kept + added parts in world space; `floating` must be empty (every part reaches the
  ground datum through the contact graph). `gr2_lint` has no floating-part check: the Korean Dock construction r2 passed
  gr2_lint 16/0/0 and `state_frame_check` while 96 of 102 window/door frame pieces hung in the air (journal
  2026-10-11-claude-09). The recipe exits non-zero on any finding and the build chain stops on that exit code (`set -e`
  or `&&`), never on printed text: a recipe that printed "QA FAIL" and exited 0 let the next step install the model.

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

Before allocating texture space or changing a shared state atlas, inventory its
actual serialized readers with [runtime_reader_census.py](scripts/runtime_reader_census.py):

```text
python scripts/runtime_reader_census.py --model MODEL.gr2 --material MODEL.material --art-root MOD/art --out NEW_SCRATCH
```

Run once per selected intact/damaged/construction model. The NPZ preserves every
bound triangle's positions, raw GR2 UVs, material, mesh/triangle indices and
dominant corner bone indices; JSON identifies bindings, texture hashes and source
hashes. Material-group indices are resolved explicitly and missing/duplicate
coverage fails. Submaterial names match case-insensitively, as the game does
(vanilla `japan_consulate_age2.material` declares `matA`, its GR2 binds `mata`):
bindings are keyed by the GR2 spelling with `declared_name` when it differs, and
two submaterials equal up to case are refused. Never census a lowercased copy of
a material. Compressed input requires `--allow-native` and the configured
headless DLL route; no substitution of another state. An existing `--out` is
refused, so a prior census is never overwritten. A failed run keeps its evidence:
once `--out` exists, any failure writes `CENSUS.json` with `status: FAILED`, the
error type, message and traceback, the source/material/script hashes computed so
far (`null` = not reached), `partial_outputs` (never a census), schema and audit,
then re-raises (exit non-zero). Cite that folder, never an empty one or a log a
rerun overwrote (INC-386). Fourteen synthetic tests cover multi-material order,
case-insensitive binding, rejected incomplete readers, the FAILED record, the
unchanged PASS record and the existing-`--out` refusal.
A census is not routing, visibility, blended skinning or complete frame/correspondence proof.

Pair the actual state branch selection with this inventory before declaring a
destination unused. A source file named RUNTIME_GEOM does not establish runtime
identity. Quantized damaged UVs can collapse to points or lines: retain their
readers and sampling protection, rather than dropping them to make packing pass.
Geometric fragment intersections can also create numerical boundary slivers.
Keep strict failures and explicit boundary uncertainty separate from interior
correspondence; a tolerance-qualified interior pass is not exact edge proof.

| Gate | Evidence |
|---|---|
| Before geometry | state/attachment table, donor hashes, exclusion list, source revision |
| Authoring | saved/reopened rest comparison, `logic_qa.py` (floating = 0, exit code), ground probes, UV sheets, front/back/interior views with non-model geometry (scaffold, donor, reference) in a labelled colour |
| Export | DLL read, `gr2_lint` (bindings, UV contract, budget), `state_frame_check.py` for every state, `attachment_check.py` |
| Game | slow construction through every stage boundary and completion, flags/horses/props, first damage to final debris |
| Handoff | per-state files and hashes; candidate / installed / owner-accepted kept separate |

Do not launch the game without authorization; offline gates never prove physics or attachments in game.

## 7. What was verified (2026-10-08)

| Claim (method docs) | Status | Evidence |
|---|---|---|
| Vanilla last construction at p66, intact at p100 | verified: 697 of 721 vanilla logics (24 use other sets) | census of 551 vanilla building animfiles, 2026-10-08 |
| Vanilla p66 = own `*_con_stage3` + `asi_4x4_stage2` at ATTACHPOINT | verified (every Japanese p66) | same census; Korean p66 follows it since r73 |
| Scaffold parts use cutout materials | verified | `asi_4x4_stage2` mata and `japan_towncenter_age2_con_stage3` matb: `default_doublesided_cutout` |
| Reference last-stage triangles (Bansho 696, Japan Stable 1,131, War Academy 2,944, Japan TC 1,198, `asi_4x4_stage2` 507) | verified, 5 of 5 exact | bound render triangles of the archive GR2s |
| "Stable construction retains its fences" (2026-10-07 study) | **superseded** | owner 2026-10-08: props, furnishings and fences are removed |
| Earlier stages: `asi_4x4_stage1`, then `asi_4x4_stage2` + `asi_4x4_frame` at ATTACHPOINT | verified | same files; unitbench pre-flight resolves them |
| Engine flags hang on `bone_flag_civ` / `bone_garrisonflag` | verified in project history | **unit-bones** (Treasure Ship); owner rule for construction models |
| `<definebone>` does not create a GR2 bone | verified | Korean TC: 103 definebones, construction GR2 7 bones |
| Custom attach bones need a `<definebone>` (unit-bones said optional) | **corrected** | vanilla 39/39 horse, 26/26 flag attaches declared; Korean stable horses stayed at the origin with bones in both GR2s until declared (2026-10-08); `attachment_check.py` enforces it |
| Converter output with a second root is not drawn | verified | **unit-bones** bone bench 2026-09-26 |
| Animation tracks override rest transforms | verified in project history | **unit-bones** / **ship-sails** |
| "The Korean Stable once lost the horse's rotation (90 deg)" | **corrected** | the 2026-10-08 failure was missing bones in the simskeleton (origin + identity rotation); bone orientation equals vanilla |
| Compare construction and intact in one frame | was policy only -> **now enforced** | TC 90 deg incident; `state_frame_check.py`, regression test |
| Damaged model keeps intact attachments | verified as a requirement | horses failed without bones in the damaged simskeleton |
| Exported triangles bind to one bone; DLL load required | enforced | `gr2_lint` bindings / dll_read |
| Hidden-frame visibility envelope, cover/exposure | method | Korean r69 records; not game-verified |
| Physics behavior of hidden beams, flag following supports | **unverified** | needs the owner's game test |

Tests: `tests/test_state_frame.py` (synthetic + the TC regression, marked `local`: needs this repo's history;
the DLL route or the raw damaged twin as reference).
Related: **aoe3de-model-attachments**, **aoe-building-pipeline**, **aoe3de-destructible-building**,
**havok-destruction**, **unit-bones**, **aoe-xml**, **rm-unit-bench**, **blender-overlap-cleanup** (logic QA),
**aoe3de-model-test-unit** (every state ships with its bench).
