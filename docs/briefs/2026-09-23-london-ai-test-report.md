# London AI test report

The test assignment is `2026-09-23-london-ai-test-assignment.md` and the plan is `2026-09-23-london-ai-plan.md`.
There is one section per run.

The owner set a limit on 2026-09-23: at most 5 runs, each at most 30 minutes.

## Device setup, 2026-09-23 (the owner's main device, 2880x1800)

- `git pull` on `Pirate-rework` brought the branch to 8ae52312.
- The game was launched through Steam on the owner's instruction ("start the game and wait for me to select the
  map"). The owner selected the map in the lobby.
- `Startup\user.cfg` had seven extra debug switches: `generateAIConstants`, `aiDebug`, `developer` and the four xs
  log lines. The file was reduced to the two lines the assignment requires, and the old file was kept outside the
  repository.
- LocalDumps were already armed (`DumpFolder` `...\CrashDumps`, count 10).
- **Live channel:** not checked. The per-player files are the record.
- **Lobby:** 1 human (P1, attackers) vs 1 AI (P2, Queen Elizabeth, defenders), Extreme, **game speed Fast**. The
  brief suggested normal speed. At Fast, 8 minutes of cap gives about 19 minutes of game time.

## Run 15 - round 1 - commit 8ae52312 (round-1 AI code 1259f206 + 7de85dbf)

`driver.py --runs 1 --cap-min 8 --from-lobby --blind --criteria london`

**Verdict:** the AI passed every round-1 criterion. The first automatic verdict said FAIL (4 criteria failed); all four
failures came from the harness, as found below.

### Harness faults found

Three harness faults, none in the AI code:

1. **`lobby_probe` depended on the map name.** The probe point (2454,645) lies inside the map-name button. It had
   been calibrated on a map whose gold text covers that pixel; "Restoration of the Monarchy" leaves the button
   background there (82,34,17). The driver's first attempt waited 30 s for a lobby it could not detect. That attempt
   was stopped before it clicked anything.
   - **Fix:** `lobby_probe` now uses the Play button (2471,1708 = (82,34,17)), which looks the same on every map.
2. **`home_skirmish` pointed at the wrong button.** The home menu now has a Continue button at the top, which pushes
   every button down by one. The old point (187,824) now lands on Home City (105,60,31), so the driver reported
   "graceful quit did NOT reach the home menu" although it did.
   - **Fix:** (187,652), the Skirmish button, measured (182,147,86).
   - **The derived `quit_yes` point is now confirmed:** the quit reached the home menu.
3. **Stale per-player files were archived.** `Logs\` still held Player3-8 files from a 7-player match on 2026-09-13,
   and the driver copied every non-empty file. Those files made L0-L3 FAIL for players 3-8.
   - **Fix in `driver.py`:** only files modified after the cap started are archived.
   - **Fix in `criteria_london.py`:** the engine's BuildPlan echoes end without a newline, so the next echo was
     glued to them with the wrong timestamp. The loader now splits at every timestamp.

### Criteria (re-judged on player 2 alone, after removing the stale files)

| Id | Res | Measured |
|---|---|---|
| L0 | PASS | `LONDON p2 build r1` at 0:01 |
| L1 | PASS | at 0:11: socket 223, gates 232 / 207, ours 232, keepNear 1764, keepFar 1049, gates found 2, keeps found 2 |
| L2 | PASS | 8 `LONDONDIAG` passes, 1:11 to 8:11, 60 s apart |
| L3 | PASS | 43 lines |
| U1 | PASS | the game process was alive at the cap |
| U2 | PASS | worst gap 60 s |

### The record lines that decided it

    00:00:11 LONDONSETUP p2 marker 279/329 socket 223 gates 232 207 ours 232 keepNear 1764 keepFar 1049 pathNear 1 pathFar 1 gates found 2 keeps found 2 tc 9388
    00:01:11 LONDONDIAG p2 pass 1 groups 15 myGroup 2 bridgeGroup 2 farKeepGroup 2 enemyTc 9000 enemyGroup 2 path near 1 bridge 1 farKeep 1 enemy 1 explorePlan 1 state 6
    00:03:11 LONDONDIAG p2 pass 3 ... (identical to pass 1)
    00:04:03 BuildPlan(57: BuildCaribTP): failing because we can't path to any points we want to build at.

### What the diagnostics decide for round 2

- **The knowledge base joins the two banks.** Our base, the bridge, the far Keep and the enemy centre are all in area
  group 2. The stock attack manager therefore treats the far bank as reachable, so the war plan's hold is mandatory.
- **`kbCanPath2` ignores the gates.** It returns 1 to the bridge, the far Keep and the enemy centre while both gaia
  bridge gates stand. Round 2 must decide open or closed from the gates' state (alive, and neither ours nor an
  ally's), not from `kbCanPath2`. This follows the plan's own rule: "if the game and the plan disagree, the game
  wins".
- **`kbAreaCalculate()` changed nothing** between pass 1 and pass 3.
- **The stock land explore plan fails** ("couldn't find any waypoints"). This is known and not on the critical path.
- **Build plans fail with "can't path" from 4:00 onwards:** `BuildCaribTP`, Trading Post and Forward Tower plans.
  These are most likely sites across the closed bridge. It is noted for later rounds and has no hypothesis yet.

### Hypothesis and edit

The one hypothesis for the next run: with the attacks held and a gate killer on an ordered list, the AI takes down the
near Keep's gates, then the bridge gates, and releases the stock attack only when the crossing is open.

The one edit is the round-2 code, below.

### Deviation from the assignment

The assignment asks for two consecutive passes of a round before the next round starts. The owner's budget is 5 runs
in total, so round 1 was not run a second time on its own. Every later run still judges L0-L3, U1 and U2, so the next
run is also the second round-1 check.

## Run 16 - round 2 - commit c75a3b0b

`driver.py --runs 1 --cap-min 20 --blind --criteria london`. The lobby had the same setup. The random personality this
time was Queen Isabella, Spain. The match reached 24:17 of game time.

**Verdict: PASS**, all of L0-L6, U1 and U2. This run is also the second round-1 check.

### Harness fault found

The quit confirm left the match on the resign screen ("You abandon your town") with the short post-match cog menu
open. The per-player file was not flushed and the driver stopped. The agent clicked that menu's Quit at (2631,414)
by hand. The first click was eaten; the second reached the home menu and flushed the file, which was then archived
and judged.

- **Fix in `driver.py`:** `end_match` now focuses the game first. If the home menu does not come back within 20 s,
  it tries cog then `postmatch_quit`, twice.
- **Sheet:** `postmatch_quit` added to the 2880x1800 sheet.

### Criteria

| Id | Res | Measured |
|---|---|---|
| L0-L3, U1 | PASS | build r2 at 0:01; setup at 0:11 (the AI was on the other bank this time: ours 207, keepNear 1049); 8 diag passes |
| U2 | PASS | worst gap 61 s |
| L4 | PASS | `held` at 0:21; `released - crossing open` at 13:13, 77 held passes |
| L5 | PASS | near Keep gate 1104 down at 7:09 |
| L6 | PASS | 0 |

### The record lines that decided it

    00:04:48 LONDONGATE p2 tasked 12 on 1104 nearKeep guard 374 ... strength 14.1 vs 0
    00:07:09 LONDONGATE p2 gate 1104 down kind nearKeep hp 0 owner -1 next 1000 nearKeep
    00:07:54 LONDONGATE p2 gate 1000 down kind nearKeep hp 4200 owner 2 next 207 bridgeOurs   <- our Keep captured, its gate converted to p2
    00:11:36 LONDONGATE p2 gate 207 down kind bridgeOurs
    00:13:13 LONDONWAR p2 released - crossing open after 77 held passes
    00:13:17 LONDONGATE p2 gate 232 down kind bridgeFar
    00:15:48 LONDONGATE p2 gate 1744 down kind farKeep
    00:16:34 LONDONGATE p2 gate 1844 down kind farKeep hp 4500 owner 2 next -1   <- the far Keep captured too
    00:16:34 LONDONGATE p2 no gate left - reserve released to the stock attack

### Reading

- **Both Keeps were captured without any capture mission.** The reserve killed the guards first and then stood at
  each Keep's second gate. Both flags converted. Each "down" line with owner 2 is the Keep complex, gates included,
  converting to p2.
- **The AI held both Keeps from 16:34.** That is the victory condition, with an 8-minute countdown. The match was cut
  at 24:17, before the win.
- **Nothing garrisoned the Keeps.** After 16:34 the whole army went to the stock attack. A human opponent could have
  retaken either flag unopposed.
- **The reserve gathered everything (up to 102 units) for 16 minutes.** That is fine while the bridge is shut, since
  nothing can reach the base by land. Defence against a naval landing was not tested.
- **Not on the critical path, for later:**
  - From 17:44 every Barracks and Outpost build fails with "building placement failed with state (3)".
  - `BuildCaribTP` and Trading Post plans fail with "can't path" before the crossing opened.

### Hypothesis and edit

The one hypothesis for the next run: a garrison at priority 101 on each Keep the team owns keeps the flags.

The one edit is round 3, trimmed to the hold. The measured capture already works, so the Istanbul-style capture
mission is not built.
