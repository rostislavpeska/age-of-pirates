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

## Run 17 - round 3 - commit 36e4d5fd (round-3 code f5b1d90d)

`driver.py --runs 1 --cap-min 20 --blind --criteria london`. The lobby had the same setup. The random personality this
time was Ivan the Terrible, Russia, and the AI started on the other bank again.

**The AI won the match.** The owner (P1, passive) watched it take both Keeps. The 8-minute Keep countdown was
running ("Team Defenders wins in 2:57") when the AI destroyed the owner's Town Centre at about 21:00 of game time.
The owner asked for the test to stop there.

The agent stopped the driver (its own Python process only, never the game) and quit the match through cog, then Quit,
by hand. The per-player file had already been flushed when P1 went out.

**Verdict: PASS**, all of L0-L8, U1 and U2. Round 2 has now passed twice in a row (runs 16 and 17): **round 2 is
done.** Round 3 has passed once.

### Criteria

| Id | Res | Measured |
|---|---|---|
| L0-L3, U1, U2 | PASS | build r3 at 0:01; setup at 0:11 (ours 232, keepNear 1764); worst gap 50 s |
| L4 | PASS | `held` at 0:21; `released - crossing open` at 12:54, 75 held passes |
| L5 | PASS | near Keep gate 1744 down at 8:15 |
| L6 | PASS | 0 |
| L7 | PASS | `LONDONKEEP p2 flag ours keep 1764 near` at 9:12 |
| L8 | PASS | `LONDONHOLD` 5-6 holding every 30 s from 9:12 to the end; far Keep 6 holding from 16:12 |

### The record lines that decided it

    00:08:55 LONDONGATE p2 gate 1844 down kind nearKeep hp 5250 owner 2        <- near Keep captured
    00:09:12 LONDONKEEP p2 flag ours keep 1764 near owner 2 garrison plan 193 cap 6
    00:12:47 LONDONGATE p2 gate 207 down kind bridgeFar
    00:12:54 LONDONWAR p2 released - crossing open after 75 held passes
    00:15:53 LONDONGATE p2 gate 1000 down kind farKeep hp 5250 owner 2        <- far Keep captured
    00:16:12 LONDONKEEP p2 flag ours keep 1049 far owner 2 garrison plan 416 cap 6
    00:20:43 LONDONHOLD p2 5 holding keep 1764 near / 6 holding keep 1049 far

### Reading

- **The whole London sequence works end to end:**
  1. Hold the attacks while the bridge is shut.
  2. Break the near Keep's gates and take the flag.
  3. Garrison the Keep.
  4. Break both bridge gates and release the stock attack.
  5. Break the far Keep's gates and take the flag.
  6. Garrison that Keep too, and win.
- **The near garrison fell to 5 at 15:42 and stayed at 5.** The refill loop did not bring it back to 6. The AI still
  held the Keep, but the refill needs a look in the next round: likely `aiPlanAddUnit` refused a unit that the stock
  attack plan owned.
- **Not on the critical path, for later:**
  - Build placement failures ("state (3)") for TownCenter, Plantation, Blockhouse and Forward Tower late in the game.
  - Trading Post and `BuildCaribTP` plans fail with "can't path" before the crossing opens: the Trading Post sites
    are on the far bank or on the bridge.

# Campaign 2 - placement (2026-09-23 evening): the London build problem, the night session

## The problem and the design

From 16-18 minutes of game time, the AI's Barracks, Plantation, Blockhouse and Town Center plans failed with "building
placement failed with state (3)", in runs 16 and 17.

The code shows why:
- **Base-driven buildings stay inside the main base.** It starts at 40 m (`aisetup.xs:2664`).
- **The base grows only through `buildingPlacementFailedHandler`** (`aibuildings.xs`), by 20 m per failure. It never
  grows once any area of another area group lies inside the new radius. On London that means the river and the wall
  hills.
- **The player's own block fills up.** `EU_SPC_Player_London` carries 82 real trees 20-45 m from the Town Center, and
  seven buildings are already placed in it.

The owner decided (2026-09-23):
- The fix is London only; other maps stay clean.
- The countryside behind the team's own city wall is the building ground for Mills, Plantations, Farms and Folwarks.
- No grouping edit for now. Thinning the player block's inner tree row is a morning fallback, pending approval.

The changes (round 4, all behind `gIsLondon`):
- **Economic buildings** go to a point 40 m beyond our own city wall gate nearest the base
  (`londonCountrysidePoint` / `londonSelectFieldPosition`). The types are Mill, Farm, Plantation, Hacienda, Folwark,
  Folwark farm and rice paddy.
- **The handler** skips water and impassable areas and caps the base at 120 m.
- **A Town Center** that failed twice is placed in the countryside.

## Test criteria (all automatic, per run)

| Id | Criterion | Boundary |
|---|---|---|
| L0-L8, U1, U2 | the earlier rounds, unchanged | as above |
| P0 | AIDIAG says london 1 for every AI player | every player |
| P1 | main base radius > 60 m | by 20:00 |
| P2 | placement failures per 10 game minutes | <= 4 |
| P3 | a `LONDONPLACE field` line and a Mill / Plantation / Farm standing | by 25:00 |
| B0-B5 | standard-map regression (`criteria_baseline.py --floor runs/run_018/metrics.json`) | see the script |

Offline tests: `python -m pytest scripts/aitest/tests -q`, 33 tests. They cover the criteria scripts, the static
London-only guard (every London line in `aibuildings.xs` sits inside a `gIsLondon` check), the echo-only diagnostic,
CRLF, and the driver's input struct.

## Harness work this evening

- **`driver.py --map NAME`** selects a map in the lobby. The picker keeps its search text and applies it only when it
  opens, so the driver clears, types, presses Escape, reopens, takes the first tile and presses OK. Verified on
  Carolina and Amazonia.
- **Two harness bugs found and fixed:**
  1. The driver's keyboard `INPUT` struct lacked the mouse member, so `SendInput` silently dropped every key: Escape
     and all typing.
  2. The home probe matched in-match terrain, so the driver took a resign screen for the home menu and the logs never
     flushed (run 18).
- Every run saves `end.png` before the quit.

## Run 18 - standard-map baseline (the regression FLOOR) - Amazonia 1v1, Extreme, Fast, 15 min cap, commit 1fe95bd2

Italy was the AI (P2); the human stayed passive. The quit stuck on the resign screen, so the agent quit by hand and
archived the record. Verdict: B0 and B5 PASS.

`P2 at 18:01: age III, score 39365, vills 85, army 72, navy 8, TCs 3, houses 15, buildings 38, baseR 40 m, placement
failures 87 (48 per 10 min)`

**Reading:** the stock AI's base never grows past 40 m on a vanilla map either. It fails placement about 5 times a
minute, which confirms the diagnosis: the freeze is the stock handler's behaviour, not a London defect. The London
fix therefore is London's own. On standard maps the floor stays whatever the stock AI does, and B4 guards against
things getting worse.

## Run 19 - round 4 (placement) - London 3v2, 30 min cap - commit 91c523af

Setup: P1 human (passive), Queen Isabella and Spanish on the human's team, Frederick the Great and Giuseppe Garibaldi
opposite. Game time reached 55:03 at the cap. Before this run, a first attempt died on an XS syntax error (I8 in the
issues log); it was fixed and did not count.

**Verdict: FAIL (P1, P2, P3). L0-L8, P0, U1 and U2 PASS for all 4 AI players**, so round 3 has passed twice (runs 17
and 19): **round 3 is done.**

| Player | Age at 25:00 | Villagers at 25:00 | Plantations at the end | Base radius | Failures at 55:00 | Top failure |
|---|---|---|---|---|---|---|
| P2 | V | 91 | 7 | 70 | 78 | ArtilleryDepot 36 |
| P3 | V | 83 | 4 | 70 | 75 | Forward Barracks 28 |
| P4 | V | 86 | 5 | 40 (60 at 55:00) | 67 | Barracks 30, ArtilleryDepot 30 |
| P5 | V | 100 | 10 | 70 | 343 | Arsenal 161, Basilica 76 |

**Reading:**
- **The countryside placement works.** Every player's Plantations were placed behind its own wall gate (`LONDONPLACE
  field Plantation ... at the countryside`), and the economies are strong: the Imperial Age and 90-100 villagers by
  25:00.
- **The failures that remain are base-driven military and tech buildings.** Each base grows to 70-100 m, then every
  further growth is refused on `area N type -1 group 5/6/7`. That area is land of its own knowledge-base group: the
  countryside behind the city wall. The city and the bridge are group 2 (LONDONDIAG). So the handler still treats
  the countryside as "another island", although the base's own Plantations stand there.

**Hypothesis and edit:** on London, no area stops the growth; the 120 m cap alone keeps the base on its bank. That
removes the refusal and its echo spam (342 lines for P5). One edit, the handler's London branch.

## Run 20 - round 4, second edit (base growth) - London 3v2, 30 min cap - commit 4f865d58

AI players: French and Ivan the Terrible with the human, against Napoleon and French. P5 (French) was knocked out
during the match.

**Harness failure:** the first quit step missed, and the fallback clicked the "post-match Quit" point on the LIVE
menu, which is Restart there. That left a "Restart current game?" dialog, and the driver stopped. The agent clicked
No, then quit through Quit and Yes by hand. The logs were flushed at 00:38 and judged: 28 minutes of game time.

**Verdict: FAIL (P2, P3).** L0-L8, P0, P1, U1 and U2 PASS.

| Player | Base radius at 20:00 / end | Failures (per 10 min) | Top failure | Plantations at the end |
|---|---|---|---|---|
| P2 | 100 / 100 | 31 (11.1) | Trading Post 14+5 | 4 |
| P3 | 100 / 120 | 18 (6.4) | Artillery Depot 9, Trading Post 3+7 | 0 |
| P4 | 80 / 110 | 37 (13.2) | Blockhouse 25 | 1 |
| P5 | 120 / 120 (out) | 24 (9.2) | Trading Post 16+6 | 2 |

**Reading:**
- **The base-growth edit works.** Every base grows to 100-120 m (P1 PASS), and no refusal spam remains.
- **Failures are down but not to the P2 bound.** They are 6-13 per 10 minutes, against the vanilla floor of 48
  (run 18) and run 19's 12-62.
- **The largest remaining group is Trading Post plans** ("placement failed" and "can't path"), which are
  socket-bound. After that come Blockhouse (P4) and Artillery Depot.
- **P3 issued field placements but never finished a Plantation.** This is not explained yet.
- **P2's bound (<= 4) was set before any data.** It stays unchanged; its realism is a question for the owner.

**Next:** run 21 is the same AI with the rewritten quit (below), to repeat the round-4 sample and prove the harness.
The Trading Post failures are investigated offline in the meantime.

**Harness edit:** `end_match` now reads which menu is open from button-background pixels (`menu_live_probe` at y 615,
`menu_post_probe` at y 414) and clicks only the matching Quit. An unknown state gets an Escape and a retry.
