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

### 2. The KotH hill exists: the vanilla helpers are replayed (`51fcfc21`)

- **Problem (item 2):** `ypKingsHillPlacer` was a listed no-op and `ypKingsHillLandfill` an unknown function, so
  no run ever had a hill.
- **Evidence:** vanilla `Game/RandMaps/ypKOTHInclude.xs`: 8 constraints, def `KingsHill` with item `ypKingsHill`, a
  max distance from `walkDistance`, placed at (x, y); the landfill builds area `hill placer`.
- **Change:** the extractor replays exactly those builtin calls; the vanilla text is not copied into the repo.
- **Test:** `test_extract.py::TestKingsHillHelpers`.

### 3. Known engine calls (`47784308`)

- **Problem (item 3):** 'unknown function' warnings, each one a skipped call.
- **Evidence:** signatures from the bundled rm and XS references; the four absent there are used by vanilla maps.
- **Change:**
  - geometry-free calls become listed no-ops, each with its reason;
  - the cliff-ramp and max-height constraints are recorded as opaque (skipped, never a false "impossible");
  - bool and vector arrays, `xsArrayGetSize` and `xsVectorNormalize` are implemented;
  - `rmGetIsFFA`, `rmGetTechID`, `rmFindCloserArea` and `rmPlaceObjectDefAtAreaLoc` are implemented.
- **Side effect, item 4:** Winter Wonderland II's 30 `constraint '?'` CONFIG errors disappear. `avoidRamp1` is a
  `rmCreateCliffRampDistanceConstraint`, which used to return handle 0.
- **Test:** `test_extract.py::TestKnownEngineCalls`.

### 4. XS has no block scope (`c49645b2`)

- **Problem:** a variable declared in a branch that did not run gave "unknown variable" and became a runtime value.
- **Evidence:** the skills `rm-objects-herds` and `rm-skeleton`: the variable exists with value zero. Eyre Basin
  relies on it (`ControllerLoc2`).
- **Change:** every declaration in a function body is pre-declared at its type's zero.
- **Test:** `test_extract.py::TestNoBlockScope`.

### 5. Object placements test terrain on the built grid (`8e5185a5`)

- **Problem:** terrain constraints on object placements were tested against authored discs, so an island built
  over water later was invisible.
  - Eyre Basin: the KotH hill was reported CONSTRAINT_UNSAT.
  - Tortuga: 5 profile-suppressed false positives (controllers, player TC / silver / deer).
- **Evidence:** the live captures show all of Tortuga's real Town Centers on mapsim land (2/2 and 6/6).
- **Change:** `gsolve.spec_allowed`, shared with the grouping solver.
- **Profile:** `scripts/maps/zptortuga.json` drops the two SIM entries; `test_profile` is updated in the same commit.
- **Test:** `test_checks.py::TestTerrainConstraintsSeeBuiltTerrain`.

### 6. KotH finding (`badd96fe`, refined in `f24acbc8`)

- **What it reports** for each hill:
  - the land it stands on: its own island, land connected through land only;
  - whether land plus walkable shallows reach a player start (cliff rims don't separate, since the model cannot see
    ramps);
  - the distance to deep water, and ship capture within 12 m (`ypkingshill.tactics`).
- **Verdicts:** KOTH_MAINLAND, KOTH_TINY_ISLAND (under 600 land tiles), KOTH_ISLAND. The preview draws the hill as a
  gold star.
- **Owner ground truth** (all 16 maps named in the brief):

  | Map | 2p | 6p | Owner |
  |---|---|---|---|
  | Eyre Basin | tiny 202 | tiny 200 | tiny |
  | Burma | tiny 378 | tiny 377 | tiny |
  | Dead Sea | tiny 202 | tiny 200 | tiny |
  | Torres Strait | tiny 352 | tiny 351 | tiny |
  | Labrador Coast | tiny 302 | see below | tiny |
  | Barrier Reef | island 2873 | tiny 350 | tiny |
  | Cold War | tiny 450 | tiny 451 | tiny |
  | Iceland | island 19751 | island 42473 | land, not a water islet |
  | Winter Wonderland II | mainland | mainland | land |
  | Zealand | island 1040 | island 2534 | bigger |
  | Polynesia | island 804 | island 801 | bigger |
  | Cook Islands | island 1122 | island 1039 | bigger |
  | Melanesia | island 2116 | island 4005 | bigger |
  | Elbe | island 1200 | island 1600 | bigger |
  | Atols | island 805 | island 803 | bigger |
  | Balearic | island 2983 | island 5658 | bigger |

  - Zealand is fixed in step 14.
  - Barrier Reef at 2 players stays open (see Open items).
- **Live KotH ground truth:** forced-KotH copies (`rmGetIsKOTH()` → `true`) are scratch files `00000_kt_*` in the
  Steam root, captured in the editor.
  - The real hill (census) is within 1–3 m of mapsim's on every map except Polynesia (another spot of the same
    size).
  - Real island sizes, from the minimap flood of non-deep water:

    | Map | Game | mapsim |
    |---|---|---|
    | Burma | 379 | 378 |
    | Cold War | 328 | 450 |
    | Dead Sea, Eyre Basin | 283–284 | 202 |
    | Torres Strait | 237 | 352 |
    | Atols | 748 | 805 |
    | Cook Islands | 1110 | 1122 |
    | Melanesia | 2629 | 2116 |
    | Polynesia | 796 | 804 |
    | Zealand 6p | 2321 | 2534 |

  - Winter Wonderland II is mainland in both.
- **Tests:** `test_checks.py::TestKothFinding`, `TestKothConnectivity`.

### 7. Half-known anchors no longer crash (`44fa1a9f`)

- **Problem:** New Guinea (every case) and Labrador Coast at 6 players crashed with `TypeError`: literal x, runtime
  z.
- **Change:** a random draw with literal bounds takes the middle of its range (approximate); any other unknown
  axis makes the whole anchor runtime.
- **Test:** `test_extract.py::TestHalfKnownAnchors`.

### 8. `main.py` forwards its arguments (`46f0c7b6`), item 7

- **Test:** `test_render.py::test_main_forwards_arguments_to_sim`.

### 9. A placement's own unit is no obstacle (`078abf3f`), item 5

- **Problem:** Torres Strait's per-player 'player TC' (avoid TownCenter 60 m) avoided its own nominal unit.
- **Test:** `test_checks.py::TestOwnUnitIsNoObstacle`.

### 10. Read-back anchors carry the drift of the def they read (`5ce853ae`), item 5

- **Problem:** Iceland's pirate cities and scientist labs were reported unplaceable ('ferry v. water').
  - Their controllers are authored at the centre with max distance 0.45 map and are pushed to the shore by their
    constraints.
  - The cities are placed within 22 m of the controller's *read-back* position.
- **Change:** the drift travels with the value (`Drifting` / `DriftVec`).
- **A version rejected on evidence:** matching read-back points by coordinates wrongly gave the drift to cliff decor
  that is merely authored at the same (0.5, 0.5).
- **Test:** `test_checks.py::TestReadBackDrift`.

### 11–13. Extractor fixes found through the London twin

These are the commits after `5ce853ae`.

- **The regression:** fix 3 (arrays) let mapsim place London's Academy and treasure blocks at definite cells, and
  wrongly. On tonight's London save the twin went from 69 groupings (61 matched) to 79 (11 missing).
- **The two causes:**
  - `continue` was read as a bare name; names starting with 'c' pass as engine constants, so it was silently
    ignored.
  - Writes at runtime indices were dropped, so London's shuffled 'taken' flags read as free.
- **The fixes:**
  - `continue` is implemented;
  - an array written at a runtime index reads back as runtime.
- **Result:** back to exactly the baseline twin numbers on that save (69 groupings, 61 matched). The 6 missing and
  158 extra units are identical on the untouched baseline commit: they come from the London grouping changes of
  2026-09-25, not from mapsim.
- **Tests:** `TestContinue`, `TestArrayWrittenAtRuntimeIndex`.

### 14. The nominal arm's state wins (Zealand)

- **Problem:** in a random `if`, both arms run. Last write won for area state (the else arm's bonus island at
  (0.6, 0.0)), while the nominal then arm's placements were kept (the hill at (0.4, 0.9)). The hill stood in open
  sea.
- **Change:** the nominal arm runs last.
- **Result:** Zealand KotH becomes an island of 2534 tiles (the game: 2321).
- **Test:** `TestNominalArmStateWins`.

### 15–18. Player start positions (`13954655`, `da207795`, `7eec6b60`, `d971fb7f`)

The metric: the mean distance from each real Town Center (census of the live saves, 49 maps) to the nearest
mapsim start. Script: `%TEMP%/mapsim_night/gt_players.py`.

| step | 2p | 6p |
|---|---|---|
| before | 34.1 m | 56.7 m |
| 15. team sections end to end | 34.1 m | 40.2 m |
| 16. one shared ring by section width | 25.5 m | 31.1 m |
| 17. positions from the nominal arm | 27.8 m | 31.3 m |
| 18. `rmPlacePlayer` spots win, team calls place their own team | 24.1 m | 21.1 m |

- **15. A placement section holds its players end to end.**
  - Evidence: Dead Sea's 0.2-wide team sections put teammates about 35° apart. `width / (n - 1)` gives 36°;
    `width / n` gives 24°. Eyre Basin measures 43–44° (45 against 30), Black Sea 33–36° (32.8 against 21.8).
  - Test: `TestSectionSpacing`.
- **16. One ring shared by every player depends on the section width.**
  - End to end when the width is at most (n − 1)/n. Otherwise n even slots.
  - The 30 single-ring cases fit without exception:
    - end to end at 2p for widths 0.3–0.5, and at 6p for 0.56–0.834;
    - n slots at 2p for 0.7–0.999, and at 6p for 0.999.
  - Team sections stay end to end at any width. Malta 6p is 0.677 wide: real 0.2 / 0.547 / 0.875.
  - Test: `TestSectionSpacing`.
- **17. The positions come from the nominal arm.**
  - Since fix 14 the nominal arm runs last, so "first event per team" had become the other arm.
  - The metric cannot decide this step: random orientations (Winter Wonderland II, New Guinea) pick one of four
    arms in the game. Consistency with the nominal areas can. New Guinea 6p loses 2 UNSAT.
  - Test: `TestNominalPlayerPlacement`.
- **18. Explicit spots and team-only calls.**
  - Istanbul calls `rmPlacePlayer` for everyone and then a ring. The real TCs stand on the explicit spots.
    84 → 11 m.
  - Versailles places team 1 on a line and the attackers by `rmPlacePlayer`: 377 → 9 m.
  - Aztec City places team 0 only. The other team stands at the centre (real 0.03 from it): 108 → 8 m.
  - The one new finding, the Aztec 'player TC' UNSAT, is true. The centre grouping `AZ_Big_PlayerDistrict`
    carries its own TownCenter 18 m from its anchor, inside the def's 40 m 'avoid Town Center Far'.
  - Test: `TestPartialPlayerPlacement`.
- **Side effect on the water model:** player areas follow the starts. On the 95 comparable minimap cases, agreement
  goes 86 → 87 % and real TCs on mapsim land 310 → 327 of 338 (Hawaii 6p 69.7 → 80.0 %, Atols 6p 60.5 → 69.4 %).

### 19. A team area grows over every member (`1788d593`)

- **Problem:** an `rmSetAreaLocTeam` area was one disc at the team's mean direction. Balearic 6p teammates stand
  about 50° apart (a 329 m span), which the 0.11 budget disc (radius 139 m) cannot cover.
- **Evidence:** the live minimap shows two crescent islands, each holding its team's three TCs.
- **Change:** the members' starts, consecutive teammates joined, seed the flood like influence segments. The budget
  is unchanged.
- **Result:** Balearic 6p 70.5 → 74.2 %, TCs on land 3/6 → 6/6. Cook Islands 6p 76.2 → 77.5 %. The sweep shows no
  finding changes.
- **Test:** `TestTeamAreaCoversItsMembers`.

## Open items and map issues (evidence, cheapest decisive check)

- **Team model: owner decision (a paired change outside mapsim's boundary).**
  - `rmGetPlayerTeam` in mapsim alternates teams: `(p - 1) % teams`, so 1,3,5 play 2,4,6. `ring_positions`,
    `rmGetNumberPlayersOnTeam` and the team areas group them instead: 1,2,3 play 4,5,6.
  - The live saves group them:
    - Versailles' attackers (team 0) are players 1–3;
    - Malta's team sections hold 1–3 and 4–6;
    - Aztec City's team-0 ring holds 1–3;
    - `scripts/mapview/tests/test_twin.py` records both London saves as 1,2/3,4.
  - Making `rmGetPlayerTeam` contiguous changes no error in the sweep. It does break
    `test_twin.py::test_the_lobby_team_layout_moves_the_seats`, and `twin.py` (line 1244) assumes the alternating
    model. Both live in `scripts/mapview`, so the change was reverted, not committed.
  - Proposal: flip mapsim, `twin.py`'s default model and that test together.
  - The visible symptom meanwhile: Versailles 6p puts player 2 at the map centre. Its `rmPlacePlayer` attackers
    are 1, 3, 5 under the alternating model.
- **The remaining start gaps are random layouts, not rules:**
  - The Unknown picks its bay and river layout at random.
  - Winter Wonderland II and New Guinea pick one of four orientations.
  - Torres Strait's real radii split between 0.17 and 0.33 (the ring asks 0.28).
  - The engine also shuffles which team takes the section start: 5 of 11 single-ring 6p saves start with players
    1–3, 6 with 4–6.
- **Map issue: Blue Mountains 6p.** When `teamStartLoc <= 0.5`, team 1's line is
  `rmPlacePlayersLine(0.75, 0.8, 0.28, 0.5)` (the other arm uses 0.25, 0.8). The live 6p save played that arm:
  two Town Centers stand 0.13 and 0.23 from the map centre, in the mountains. mapsim now reports 5 UNSAT around
  them, which is correct.
- **Cold War 2p:** mapsim leaves deep water along the far west and east edges, where the real minimap has land up to
  the map edge (0/2 real Town Centers on mapsim land). Next check: the glacier areas' world-circle and edge
  handling.
- **Barrier Reef 2p KotH:** island 2873 tiles, owner says tiny. At 2p mapsim's koth island touches a neighbouring
  land area. Barrier Reef's minimap agreement is also limited: the minimap draws the underwater reef cliffs in cliff
  brown, which the pixel classifier counts as land.
- **Barrier Reef 'pirate city 4' ('ferry v. water', pinned):** in the live capture the real city stands 13–16 m from
  deep water. mapsim merges `pirate_site4` with the nominally placed 'bonus island 3', which puts water 55 m away.
  The engine-placed bonus islands are not modelled.
- **Iceland 'stay in cliff2':** cliff decor and nuggets inside `cliff2`, which mapsim does not build at that player
  count. Not investigated.
- **Labrador Coast KotH ground truth:** its ice draws non-blue, so the minimap flood cannot tell the island size.
  The owner's label (tiny) is taken.
- **Non-square maps (item 6):**
  - Map sizes match the saves: Barrier Reef 320 × 400 / 320 × 1200, Labrador Coast, Florence, Paris and others,
    within the engine's 2 m tile rounding.
  - The 6-player Barrier Reef strip is oriented and placed like the real minimap.
  - The preview draws the long axis in short-axis fraction units (for example z up to 1.25), which preserves the
    shape. That is the confusing part, not the geometry.
  - The east bonus islands end at the true map edge.
- **Map issue (not a mapsim bug), from the no-block-scope rule:** Eyre Basin at 2–3 players builds `pirate_site2` at
  `ControllerLoc2`. That variable is declared only for 4+ players, so the site (base 1.0, 700 tiles) goes to the
  map corner (0, 0). This is harmless on a land map, but it's a map-script oddity for the owner.
