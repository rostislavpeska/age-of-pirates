# Istanbul forward base: test instructions (2026-09-25)

> **Superseded for testing (2026-09-25 afternoon):** run `2026-09-25-istanbul-fleet-split-restore.md` instead. It repeats this brief's forward-base criteria, and the build echo is now r13. Test 1 of this brief passed on the main device (run 13).

For the agent that tests the AI on the other device. The change is on `Pirate-rework`; the AI was not run in game
before it was pushed.

## What changed

The owner wants the AI's forward base on Istanbul **next to the Fisherman's Guild**, the same way London and Paris
already work.

- **Map, `randmaps/zpistanbulb.xs`:** the map places `zpAILondonConstrMarker` on both landing beaches, one per player
  per beach, at `beachDockN` and `beachDockS`. Those are the same anchors the two Fisherman's Guild islands and the
  beaches use. The markers go after every placement and just above the `UNIT IDS` block. The trigger ids come from
  `rmGetUnitPlaced` plus a fixed shift, so no id should move.
- **AI, `game/ai/core/aipiraterules.xs`, build echo `r12 2026-09-25`:**
  - The forward base switches on when the player owns that marker. The check is by unit, not by map name.
  - The target is the marker on the enemy side (`pirateForwardBasePoint`).
  - Istanbul is an island map to the AI (`gStartOnDifferentIslands = true`), and the stock forward base there is a
    beachhead. Two changes cover that:
    - `pirateForwardBeachHead` replaces the stock beachhead pick in the forward-base rule copies.
    - `pirateForwardBaseWatch` re-points the stock amphibious assault's landing (`gAmphibiousAssaultTarget`) to the
      enemy beach marker. It does this only while the navy gathers or bombards (stage 0-1), before the troops load.
- **Not changed:** the stock core files (they stay byte-identical, tested). Istanbul's own rules, the amphibious gate
  (the stage stays forbidden until a fixed gun dies) and London / Paris behaviour.

## Before the test

1. Pull: `git checkout Pirate-rework && git pull`.
2. Read `.claude/skills/ai-edit/SKILL.md`, its `references/testing-process.md` and `references/mod-ai-architecture.md`.
3. Run `python -m pytest scripts/aitest/tests -q`. Expect 136 passed.
   - `scripts/mapcheck/tests` has 4 failures that exist without this change: `test_london_roles` (3) and
     `test_parliament_natives` (1). They are not caused by it.
4. The game must be running at the home menu. The owner starts and restarts it; never kill or launch it yourself.
   A map script change needs no restart: the map is read at every match start.

## The tests

Run from the repo root. The driver selects the map by script name, checks the lobby shows one tile, and confirms the
map from the game log. A wrong map is quit at once.

**Test 1: loads (2 min)**

    python scripts/aitest/driver.py --runs 1 --cap-min 2 --blind --criteria baseline --map zpistanbulb

The driver's `MAPS` table maps `zpistanbulb` to the search text `Revelations` ("Revelations of Istanbul") in Custom Maps.

Pass when:

- **Loaded screenshot:** the driver prints `LOADED SCREENSHOT`. Look at `scripts/aitest/runs/_loaded/loaded.png`:
  it must show no AI error dialog. Report a dialog at once.
- **Map:** the driver prints `map confirmed by the log: zpistanbulb`.
- **AI:** every AI player's file (`runs/run_NNN/Age3DEAIOutputPlayer<N>.txt`, UTF-16 LE) has
  `PIRATEFB p<N> build r12 2026-09-25 - 2 construction markers`.

**Test 2: the forward base (30 min, Istanbul needs time to reach a landing)**

    python scripts/aitest/driver.py --runs 1 --cap-min 30 --blind --criteria baseline --snapshots --map zpistanbulb

Read the per-player files for these echo lines:

| Line | Meaning |
|---|---|
| `PIRATEPLACE p<N> forward base next to the bridge at X/Z (enemy construction block, ...)` | the target; X/Z must be the enemy side's beach (north beach ~ 398/396 m, south beach ~ 203/187 m on the 600 m map) |
| `PIRATEFB p<N> amphibious landing at ... re-pointed to X/Z` | the stock landing was moved to the enemy beach |
| `PIRATEFB p<N> stock forward base at ... re-pointed to` / `cancelled` | the stock `Forward <building>` plan was moved |
| `PIRATEFB p<N> state S at X/Z military buildings there M plan P` | once a minute: the forward base state; `M` = our military buildings within 40 m |
| `PIRATEFB p<N> forwardBaseManager -> pirateForwardBaseManager` | the stock rule was swapped for the copy |

Pass when:

1. **No regression:** the match runs the full 30 min without a crash, and the AIs still land. The Istanbul memory
   notes list the known crash classes; a crash stops the test and goes to the owner.
2. **The forward base is at the right beach:** at least one AI's forward base, from a `PIRATEFB ... state` line with
   `military buildings there` > 0, stands at the enemy-side beach marker, next to that side's Fisherman's Guild.
   Confirm it on the end snapshots.
3. **Nothing lands elsewhere:** no forward base stands anywhere else on the map once a marker exists.

## If something fails

| Symptom | Where to look first |
|---|---|
| AI error dialog on load | the line the dialog names in `aipiraterules.xs`; the XS lints in `scripts/aitest/tests` |
| No `PIRATEFB build r12` line | the markers were not placed: check the `AI CONSTRUCTION MARKERS` block in `zpistanbulb.xs`; is `beachDockNX` in scope there? |
| `no construction block on the enemy side` | `pirateForwardBasePoint` keeps only markers nearer the enemy's start than our base: compare the beach positions with the players' starts |
| The landing is not re-pointed | `gAmphibiousAssaultStage`: the assault stays forbidden (99) until a fixed gun dies, so there may be no landing within the cap. That is not a failure of this change. Report it. |
| The forward base is built but not at the beach | whether the builders can reach the beach at all: Istanbul's shores connect around the rim |

Report to the owner:

- the run numbers;
- each pass criterion with its evidence (echo lines, screenshot);
- anything unexpected.

Do not change gameplay data or what the AI contests without the owner's approval (AGENTS.md hard rule 7). The
`ai-edit` skill has the rules.

## Prompt for the testing agent

> On `Pirate-rework`, pull, then follow `docs/briefs/2026-09-25-istanbul-forward-base-test.md`: run test 1 (2-minute load check) and, if it passes, test 2 (30 minutes). Look at the loaded
> screenshot every run. Report each pass criterion with the echo lines and snapshots that prove it. On a crash or an
> AI error dialog, stop and report; do not fix gameplay data. The game is already running; never kill or launch it.
