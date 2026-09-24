---
name: ai-edit
description: The entry point for ANY change under game/ai (the XS AI scripts) - the owner's approval gate for gameplay-scope changes (what the AI contests: sockets, Trading Posts, natives, bridges, objectives, forward bases, targets, defences), the compile order and declare-before-use, the map-specific guard pattern (gIsLondon) and its static tests, the XS constructs the engine rejected, the offline test suite, and the in-game test loop (driver, criteria, one hypothesis per run, report). Use before editing aipiraterules.xs, aibuildings.xs, aiglobals.xs or any core AI file, before an AI test run, and when reading AI per-player logs. Triggers on "AI", "aipiraterules", "the AI does not", "AI builds", "AI attacks", "AI test", "night run", "placement failed", "xs error", "compile error dialog".
---

# ai-edit: change the AI without changing the game

## 0. The gate, before anything else (AGENTS.md hard rule 7, guidelines rule 13)

**What the AI contests is the owner's decision, not yours.** That covers:
- sockets and Trading Posts (the bridge post, every native, the far bank included);
- objectives, bridges and forward bases;
- targets, and where defences stand.

A change to any of them is a **proposal in the report, never a commit**. On the night of 2026-09-23/24 an agent made
the stock Trading Post rule skip London's bridge post and far-bank sockets, put towers at the decorative wall gates,
and switched the forward base off. The failure metric improved because the AI did less. The owner called it a heavy
violation; everything was reverted, costing 5 runs.

- **Ask one question of every change:** does it change what the AI fights over, or only how it executes what it
  already wants? Only the second kind is yours to ship.
- **A metric that improves because the AI does less is a regression.** Read failures as the AI trying; ask what it
  is trying to do before removing the attempt.
- **Enforced by a test.** `scripts/aitest/tests/test_aitest.py::APPROVED_LONDON_CODE` lists the only functions
  where London code may live, each with the owner's quote and date. `test_contested_decisions_carry_no_london_branch`
  keeps the deciding rules (`tradingPostMonitor`, `forwardTowerBaseManager`, `towerManager`,
  `selectTowerBuildPlanPosition`) free of map branches. Adding a place to the list is the approval step: ask first.
- **Map design facts:** read the map's memory and brief before touching its AI. London: the city is the
  battlefield, the walls are decorative, and the bridge and every Trading Post are claimed normally.

## 1. Where the code compiles

- **`game/ai/core/`** is what the game compiles. The London build echo (`LONDON p<N> build r<k>`) proves it at every
  match start. `coreDLC/` is not kept in lockstep; that is an open owner decision.
- **The include order is `aicore.xs` 90-104:** globals, utilities, buildorders, waterrules, assertivewall,
  buildings, techs, exploration, economy, military, hccards, chats, **pirate rules**, archipelago, setup.
- **XS resolves names in file order.** A global that an earlier file needs (for example `aibuildings.xs` reading
  `gIsLondon` or `gLondonWarState`) goes into `aiglobals.xs`, declared exactly once. The test
  `test_campaign_globals_are_declared_once_in_aiglobals` checks this.
- **A `mutable` stub in `aicore.xs`** plus the real body later is the core's pattern for forward declarations. Any
  other name defined twice is an error.
- **AI files are CRLF.** Write them through a script that converts, then check with `file`.

## 2. The map-specific pattern

- **Detection by object, never by name.** The player's own marker (`zpAILondonBridge`) sets `gIsLondon` in
  `initializePirateRules`.
- **Every helper starts** with `if (gIsLondon == false) { return (...); }`. Every hook in a stock function sits
  inside `if (gIsLondon == true) { ... }`. Both are statically tested.
- **Hooks change HOW, not WHAT:** a place, a search radius, a growth limit.
- **Every rule echoes its refusals** (throttled) and its phase changes with counts. Use one vocabulary per map
  (`LONDONWAR`, `LONDONGATE`, `LONDONKEEP`, `LONDONHOLD`, `LONDONPLACE`).

## 3. XS the engine rejected, and the rules that hold

**Rejected in game (the whole AI dies with a modal dialog):**
- `if ((xsVectorGetZ(a) - xsVectorGetZ(b)) * side < (...) * side + 20.0)` gave Error 0308 / 0135. The exact trigger is
  not isolated. Write plain steps into locals. The lint `test_no_condition_has_the_run_19_rejected_shape` catches the
  shape.

**Guide rules** (references/ai-guide), linted where the stock core complies:
- no local variable named like a function or rule;
- no `scalar * vector` (write `vector * scalar`);
- no double definition without a `mutable` stub;
- no ternary.

**Avoided out of caution:** concatenating a `bool` or `long` into a string. Assign to an `int` first.

**Queries:**
- `createSimpleUnitQuery` is ONE shared object: read or cache its results before any other query runs (guidelines
  rule 1).
- `getUnitCountByLocation` and `getClosestUnitByLocation` use their own named query.

## 4. Offline, before every commit

    python -m pytest scripts/aitest/tests -q

The suite covers the criteria scripts on synthetic records, the declarations, the echo-only diagnostic, the
London-only guards, the approval gate, the XS lints, CRLF and the driver's input structs. A red test means you
don't commit and you don't start a match: an XS error costs a match start and a dialog.

## 5. In game (the owner's machine: never kill the game; launch only on the owner's word)

    python scripts/aitest/driver.py --runs 1 --cap-min 30 --blind --criteria london          # lobby already on the map
    python scripts/aitest/driver.py --runs 1 --cap-min 15 --map Amazonia --blind --criteria baseline --floor scripts/aitest/runs/run_018/metrics.json

**What the driver handles:**
- It stops on an `XS: Error` after the load.
- It flags an AMBIGUOUS run when `game/ai/core` changed between Play and the end of the load, so never edit the
  AI while a match is loading.
- It accepts an AI's resignation dialog, which pauses the game.
- It quits through the menu it has recognised by pixel.
- It archives only per-player files written during the run.

**How the loop runs:**
- **One hypothesis per run.** Read the whole record before the next edit.
- **After each run:** a report section in `docs/briefs/<date>-london-ai-test-report.md`, a line to the owner, and
  anything surprising logged in `docs/briefs/2026-09-23-ai-issues-log.md`.
- **Criteria are hard numbers set before the run.** Don't move them silently; propose.
- **The per-player files are the record:** `Logs\Age3DEAIOutputPlayer<N>.txt`, UTF-16, flushed only when the match
  is quit through the menu. The live echo channel is silent in this build.

## 6. Engine facts measured on London (2026-09-23/24)

- **`kbCanPath2` ignores gates.** It returned 1 across standing gaia bridge gates. Judge crossings by the gates'
  state.
- **The knowledge base joins both banks into one area group.** The countryside behind the city wall is a separate
  land group.
- **Stock base growth** happens only in `buildingPlacementFailedHandler`. The base starts at 40 m and grows 20 m per
  failure, at most every 40 s. It freezes forever once any area of another group is in range. On vanilla Amazonia the
  base stays at 40 m, with about 48 placement failures per 10 minutes: that is stock behaviour, the regression floor
  (run 18).
- **AIDIAG** (`rule aiTestDiag`, flag `gAITestDiag`) echoes age, villagers, army, buildings, base radius and failures
  once a minute on every map. It is echo only. Set it `false` for release, like `gLondonTestMode`.
