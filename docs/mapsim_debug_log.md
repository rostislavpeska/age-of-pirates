# mapsim debug log: overnight session of 2026-09-25/26 (branch `mapsim-overnight`)

This log is written for the owner and the next agent. It records the session that works through
`docs/mapsim_feedback_2026-09-25.md`. Scope: `scripts/mapsim/**` and this log. Map scripts, data, groupings,
AI and skills are not edited. Scratch output lives in `%TEMP%/mapsim_night/`, never in the repo.

## Setup

- The branch `mapsim-overnight` was cut from `Pirate-rework` at 7f9ddf80 and later merged with Pirate-rework
  702870c3 (the London techs; the game was restarted on that data at 01:44).
- First commit `f7dcf26d`: it reverts the stopped agent's WIP 4673ae53 (scripts/mapsim/** only, 813 lines,
  unlogged, 4 mapview + 1 mapcheck tests failing). Its diff is kept as a parts bin in
  `%TEMP%/mapsim_night/wip_4673ae53.diff`.
- Baseline after the revert:
  - `scripts/mapsim scripts/mapview scripts/gameio` tests: 521 passed, 94 skipped.
  - `scripts/mapcheck` tests: 4 failed, 471 passed, 18 skipped. All 4 failures are unrelated to mapsim:
    - 3 × `test_london_roles.py`: they need `sandbox/backups/groupings/*` files absent on this device;
    - 1 × `test_parliament_natives.py`: it forbids `*.mods.xml` in the Steam root, where
      `0000_independencewar.mods.xml` and `000_zpcivilwar.mods.xml` are pre-existing test copies.

## Ground truth from the live game (new tonight)

The owner asked for real minimaps. Two scratch tools do this; they live outside the repo, in
`%TEMP%/mapsim_night/`.

- **`gt_capture.py`** drives the live Scenario Editor on the 2880x1800 device through `scripts/gameio` (with its
  focus, cursor and window checks). It does File > New with a player and team count and the map chosen from the
  Type list, then Generate. It saves the minimap crop and saves the generation as `Scenario/gt_<map>_<case>`.
  - The maps reach the editor as byte copies in the Steam root: `00000_<stem>`, 49 maps, kept equal to the repo
    by `scripts/tools/sync_local_maps.py`.
  - A generation counts only when the map's `Age3DERM00000_<stem>.dmp.txt` is rewritten.
- **`gt_compare.py`** projects every mapsim terrain cell onto the real minimap through the calibrated transform
  (`scripts/mapview`, editor record 2880x1800). It reports:
  - water agreement;
  - false water (mapsim water, game land) and false land;
  - whether each real Town Center, read from the save by `census_reader`, stands on mapsim land.
- **How the minimap draws water (measured on Dead Sea):**
  - The 2 m deep `ZP Dead Sea` lake is blue (76, 96, 145).
  - The 0.5 m `ZP Dead Sea Shallow` ring around it is drawn in its bottom terrain's grey.
  - The minimap therefore colours deep (not walkable) water only, so the comparison is mapsim's
    deep water (`water and not wwalk`) against the blue pixels.

## Fixes

### 1. The sea level no longer floods land-initialized maps

- **Problem (feedback item 1):**
  - On `zpdeadsea.xs` and `zpeyrebasin.xs` (land init, `rmSetSeaLevel(6.0)`), every area with a base height at or
    below 6 m became water.
  - That included both players' areas (2.0) and the 'dead sea valley' (0.0).
  - The preview put the players in deep water.
- **Evidence:** live editor minimaps, Dead Sea 2p and 6p and Eyre Basin 2p and 6p.
  - Only the water-typed lakes are water; the valley and the player areas are dry ground with the Town Centers on
    them.
  - Venice's 'bonus island' and 'port sites' and Versailles' 'countryside N/S' (base 1.0 = sea 1.0, land base) are
    land by name and use.
- **Change:** one predicate, `scene.height_floods(base_is_water, sea_level, base_height, water_type)`.
  - A height-only area floods only on a water-initialized map.
  - It is used by `bridge` (creates_land), `checks.area_is_land`, `checks._water_features_m`,
    `field.FieldContext` and `render`, which each carried their own copy of the old rule.
  - Water-base maps are unchanged (Cook Islands shoals, reef rings).
- **Test:** `test_terrain_state.py::TestSeaLevelOnLandBase`, a synthetic Dead-Sea-like map. It checks that low
  ground stays land, that the water-typed lake is the only water, and that the checks agree.
- **Before → after:**

  | Case | Deep-water agreement with the minimap | Town Centers on mapsim land |
  |---|---|---|
  | Dead Sea 2p | 65.6% → 98.1% | 0/2 → 2/2 |
  | Dead Sea 6p | 66.6% → 98.6% | 1/6 → 6/6 |
  | Eyre Basin 2p / 6p | 94.8% / 94.3% → 96.2% / 95.2% | unchanged, 2/2 and 6/6 |

  - The Dead Sea `nugget hard` / `nugget medium` CONSTRAINT_UNSAT errors are gone.

## Open questions and map issues

(filled in as the night goes)
