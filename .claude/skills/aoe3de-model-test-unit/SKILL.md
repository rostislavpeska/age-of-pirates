---
name: aoe3de-model-test-unit
description: Make a test unit ("bench") to check a new or changed Age of Empires III DE building or unit model in the scenario editor and in a game - a separate zzTEST proto per variant that loads the SAME GR2/HKT/material files through a bench animfile without civ, age, tech or Variation logic, distinct editor names, StartEnabled, a test builder for the construction stages, the production proto untouched. Use when the owner wants to "test destruction in the editor", "create a test unit / test model", when the editor shows another look than the new model (age-1 placeholder, other culture), when one variant of a random Variation must be tested on purpose, or before an owner game test of new building art.
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
**aoe3de-model-attachments**, **havok-destruction**, **aoe-xml** (XMB twins). Worked example: the Koreans add-on
benches `zzTESTKoreanTownCenter`, `...Barracks`, `...Stable`, `zzTESTKoreanHouseA/B/C` (2026-10-09).
