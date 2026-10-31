---
name: aoe3de-model-test-unit
description: "Create an AoE3 DE editor test unit that uses the candidate's actual models and materials. Use when installing new art or isolating construction, damage or variant behavior."
---

# Test unit for a model (bench proto)

A production animfile chooses its look by age, tech, culture and a random `Variation`. In the scenario editor the
player starts in age 0/1 of some civ, so a building routed "Colonial on" shows its placeholder, and a random variant
cannot be tested on purpose. A bench is a second proto that shows exactly one model state machine, always:

| Piece | Rule |
|---|---|
| Bench animfile | one per variant, `art/zbench_<name>/<name>_bench_<v>.xml`: the production animfile's `<definebone>` list and the variant's `<submodel>`s copied verbatim, one `<component>` with `BuildingCompletion` p0/p33/p66/p100 (a unit: its finished model only). No `Tech`, `Culture` or `Variation` logic. CRLF. Generate it from the installed production animfile so the two cannot drift |
| Models | the SAME GR2/HKT/.material paths as production - never copies (one source of truth; a copy tests something else) |
| Bench proto | a copy of the production proto with the gameplay values unchanged; name `zzTEST<Model><Variant>`, its own id/dbid in the mod's range, `<animfile>` = the bench animfile, `<buildlimit>999</buildlimit>`, `<flag>StartEnabled</flag>`; tactics kept (every tactics animation must exist in each finished submodel) |
| Names | new `displaynameid` / `editornameid` strings, distinct from the production unit and from vanilla (the editor lists by name: "zzTEST <Model> A (destruction bench)") |
| Builder | a test builder (e.g. a wagon) with `<train row page column>` buttons for the benches and a `Build` tactic rate for `Building`, so the construction stages (p0..p66) can be watched in a game |
| Block | all bench protos in one marked `BEGIN zzTEST ... END zzTEST` block of protomods ("strip before release"); the guard test that pins the production unit set ignores `zzTEST*` |

**A bench is part of every model delivery** (owner 2026-10-11: "test bed must always be part of the package"). Add or
update it in the same change that installs or changes the model, never as a follow-up, and pin the rule with a repo
test: every building the mod routes to a new model has a bench; every bench's animfile and referenced GR2s exist; every
bench sits on the test builder. When the model already has its own animfile without civ/age/tech logic (a civ add-on
merges it into the vanilla animfile), the bench may load that file directly instead of a generated `zbench_` copy. Copy
the production proto's placement and physics: a dock bench keeps `placementfile`, `physicsinfo`, `TieToWaterSurface`
and `SnapPlacement`, or it cannot be placed on water (Korean Dock 2026-10-11: the export shipped without a bench and the
owner had to ask for it; journal 2026-10-11-claude-13).

## Steps

1. Check the production animfile's routing (which branch the editor's age/civ selects) and list the variants.
2. Write the bench animfiles with a small generator over the installed production animfile; assert every
   `submodelref` resolves and the set equals the copied submodels.
3. Add the bench protos and strings, the builder buttons; rebuild the mod's XMB twins (data and every language).
4. Verify offline: the compiled proto XMB carries the bench protos (decode it), `attachment_check.py` on each bench
   animfile (aoe3de-model-attachments), the mod's tests (string ids, tactics animations, CRLF), and the model lint on the
   shared GR2s - a bench never replaces the model's own gates.
5. Owner test (the game is launched only with the owner's go): place each bench variant in the editor - intact look,
   garrison flag (garrison units), partial damage (attack it: stage bodies break off), final collapse (destroy it);
   in a game, build it with the test builder to watch p0/p33/p66/p100. Report per variant.
6. Before release: remove the bench block, its strings and `art/zbench_<name>/`, or keep them only on a dev branch;
   the production proto never changes for a bench.

Related: **rm-unit-bench** (one unit on a minimal map with the crash oracle), **aoe3de-building-states** (state routing),
**aoe3de-model-attachments**, **havok-destruction**, **aoe-xml** (XMB twins), **aoe3de-unit-model** (unit model
facts and the checks before a bench). Worked example: the Koreans add-on
benches `zzTESTKoreanTownCenter`, `...Barracks`, `...Stable`, `zzTESTKoreanHouseA/B/C` (2026-10-09).
