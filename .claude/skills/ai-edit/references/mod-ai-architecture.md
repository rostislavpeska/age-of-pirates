# Where mod AI code lives (owner 2026-09-24)

**All mod AI code lives in `game/ai/core/aipiraterules.xs`.** Every other file in `game/ai/core/` is the adopted
AssertiveWall core, byte for byte: commit `0b2c6aab` ("adopt the Christmas-Release core", 2026-09-11). The one
exception allowed is a single line in `aiglobals.xs`, and it is not in use today.

The owner's words: "keep all changes isolated in aipiraterules and in the rest only minimum code", then "completely
isolated!!! one line in aiglobal max", then "do what Istanbul does, basically start a completely different path".

Why: the London campaign had put 389 lines into `aibuildings.xs` and 17 into `aiglobals.xs`, spliced into stock
functions. That means every upstream core update becomes a merge, and a stock function no longer means what upstream
says it means.

## The patterns, in order of preference

| Need | Pattern | Example |
|---|---|---|
| a map needs its own behaviour | detect by the player's own marker unit in `initializePirateRules`, enable the mod's own rules | `zpAILondonBridge` enables `londonSetup`, `londonPlanPlacer`; `zpAILondonConstrMarker` enables the forward base on any map that places it |
| a stock rule must behave differently on a map | **switch the stock rule off, run a copy** (Istanbul's pattern). A watch rule disables the stock rule whenever a stock monitor re-enables it. The copy changes only the lines it must, and a test pins the difference. | `pirateForwardBaseWatch` swaps `forwardBaseManager` / `forwardTowerBaseManager` for `pirateForwardBaseManager` / `pirateForwardTowerBaseManager`; only the location line differs |
| a stock event handler must behave differently | `aiSetHandler("<ours>", cXS...Handler)` from `initializePirateRules`. That runs after the stock `initXSHandlers`, so ours wins. Wrap with a call to the stock function, or use a copy for internal changes. | `aiTestPlacementFailedHandler` (counts, then calls the stock handler), `londonBuildingPlacementFailedHandler` (London copy) |
| a stock function computes something inside a plan's creation | a rule re-points the plans afterwards | `londonPlanPlacer`: every second, estates and Town Center plans get the countryside point |
| a global the mod needs | declare it at the top of `aipiraterules.xs`, before `initializePirateRules` | `gIsLondon`, `gAITestDiag`, `gPirateForwardBaseMap` |

**Never:** a hook line in a stock function, a `mutable` stub added to `aicore.xs`, a mod global in `aiglobals.xs`, or
a map name in a stock file.

## Detection

**By unit, never by map name** (owner 2026-09-24: "all unit based"). A feature switches on when the player owns its
marker, which the map script places once per player (editor-only, Tracked, owned by the player so the AI's own query
sees it):

- `zpAILondonBridge`: the London rules (war plan, gate killer, Keep hold, placement).
- `zpAILondonConstrMarker`: the forward base at the enemy construction block, on any map that places it (London,
  Paris). The map places it next to the construction block grouping, never inside the shared grouping.
- `zpAIStartUrbanMap`: the Paris city chain (`cityGateKiller`).

The same markers are how the AI finds the places. A new map gets a feature by placing its marker; no AI change.

## Enforced by tests (`scripts/aitest/tests/test_aitest.py`)

- `TestIsolation::test_stock_file_is_the_adopted_core`: every core file except `aipiraterules.xs` equals `0b2c6aab`,
  after normalising line endings. `aiglobals.xs` may add one line.
- `TestIsolation::test_no_mod_map_name_outside_the_pirate_rules`.
- `test_the_forward_base_copies_differ_from_stock_only_in_the_location`.
- `test_campaign_globals_are_declared_once_in_aipiraterules`.

## When the upstream core is updated

1. Adopt the new core as its own commit.
2. Move `BASELINE` in the tests to that commit.
3. Re-copy every stock rule the mod copies. The copy test shows which lines must stay different.
