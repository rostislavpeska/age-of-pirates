# Istanbul fleet split restored: test instructions (2026-09-25)

> **Read `2026-09-25-istanbul-handover.md` first:** it gates this test and replaces criterion T7 below. The run-14
> forward-base line in the last table was an unverified inference and is corrected there.

For the agent that tests the AI on the dedicated test device (2880x1800). **Never test on the owner's main device**
(owner 2026-09-25: testing there is "ENORMOUSLY EXPENSIVE"). Run **one** 30-minute test, report, stop. The owner
evaluates before anything else runs.

This brief supersedes the test part of `2026-09-25-istanbul-forward-base-test.md`. Its forward-base criteria are
repeated below, so one run covers both changes.

## Why

On 2026-09-25 the owner watched run 14 (Istanbul, 2v2, Extreme, Fast) and reported:
- pirate ships parked at a Naval Fort;
- the AIs built almost no ships;
- an Extreme AI that played like Easy.

What the records and git history show:

| Finding | Evidence |
|---|---|
| The fleet split was **deleted** by `570d65a2` (2026-08-27, "Istanbul AI: strip to three concerns"): `istanbulGunFleet`, `istanbulGunRaid`, `istanbulMonitorMaintain` and `istanbulIsGunFleetHull`. The commit gives its reasons but no owner approval. Only the comment headers survived. | `git log -S "rule istanbulGunFleet"`; the headers at the old places had no code under them |
| Tag **v7.2** (2026-09-11 20:31, `b5948930`), the release anchor, **already lacked the split**. The last commit that had it is `d33dba2e` (2026-08-27). | `git show v7.2:game/ai/core/aipiraterules.xs` has no `rule istanbulGunFleet` |
| Between v7.2 and this change, the AI **only gained code**: +2198 lines in `aipiraterules.xs`, 0 deleted (London, AIDIAG, forward base). The stock core is byte-identical. | `git diff --stat v7.2 HEAD -- game/ai/` |
| Almost no ships: docks. At 29:01 the three AIs had navy 0 / 3 / 3 and docks 0 / 3 / 1, after 15 / 14 / 12 failed dock plans. **Every failure is placement**, not path or builder. | `runs/run_014/Age3DEAIOutputPlayer*.txt`, `AIDIAG` and `BuildPlan ... Dock ... placement failed` |

## What changed

**AI, `game/ai/core/aipiraterules.xs`, build echo `r13 2026-09-25`:**
- **Fleet split restored**, the owner's instruction (2026-09-25): "Pirate ships should attack the Naval Guns, because
  they have bonus against them (same monitors) and other ships should guard the Naval Forts."
  - `istanbulIsGunFleetHull`: a pirate hull (`AbstractPirateShip`) or the civ's monitor (`gMonitorUnit`).
  - `istanbulGunFleet`: a reserve plan holding those hulls. It sits at **priority 100**, not August's 96. Stock
    `gatherNavy` drains every warship whose plan is not at exactly 24, 25, 99 or 100 into the amphibious assault.
    The fort keepers add at 100 (they skip >= 100), `istanbulFortRaid` skips >= 99, and the KOTH combat plan is at
    60, so none of them can take a pool hull.
  - The pool **takes** pirate and monitor hulls out of the two fort keepers (`gIstanbulGuardianPlan`,
    `gIstanbulGarrisonPlan`), which is where the owner saw them, and out of any plan below 99. It leaves the stock
    landing (99) and transports alone.
  - `istanbulGunRaid`: once the pool holds at least 2 hulls, every hull attacks the enemy `zpAntiShipGun` nearest
    to our base. The guns are owned by each shore's first city player; the AI rebuilds them as `zpAntiShipGun`.
  - `istanbulMonitorMaintain`: keeps 2 monitors once the civ has them and a dock stands.
  - Not restored:
    - the **fallback** (4+ warships of any kind onto a gun when the pool is empty). It sends non-pirate ships at
      the guns, which is against the split. **Open question for the owner.**
    - `gIstanbulGunPriority` (the beach gun of the custom landing, which was deleted with it).
- A stale comment was corrected: the landing is the stock one and runs **ungated**. The "a fixed gun must die first"
  gate was deleted by `570d65a2`, and run 14 landed at stage 0 from 08:47.
- **Dock diagnostic (echo only):** every failed dock placement echoes
  `AIDOCKFAIL p<N> #k plan P point0 x/z point1 x/z navyvec x/z`: the two points the stock dock plan searched around
  (`aibuildings.xs` 1374-1376: the main base and the navy point).

**Tests, `scripts/aitest/tests/test_aitest.py`:**
- `OWNER_FEATURES`: every behaviour the owner ordered, with the rules that implement it. A rule that is gone or
  never enabled fails the suite. It is checked to fail on the old code (HEAD before this change, v7.2).
- `test_the_gun_fleet_sits_at_exactly_100`.
- Expect **140 passed**.

**Harness (separate commit):** the driver runs on 2560x1080 too. Every screen point comes from the coordinate sheet.
The 2880x1800 sheet gained the old literals **unchanged**: `lobby_minimap`, `lobby_minimap_corner`,
`yesno_yes_edge` / `yesno_no_edge`, `minimap_center.r` and `mouse_park`. Nothing changes on the test device.

## The dock, explained

- Istanbul uses the **stock** dock builder. Its own dock rules were removed on 2026-08-22 (`936ce99a`).
- A stock dock plan searches for a buildable shore near two points: our main base and the navy point.
- "Placement failed with state (3)" means the engine found no legal dock spot there.
- London had exactly this (issues log **I15**): quay cliffs, no beaches. It was fixed in the **map** (city ramps and
  slipways), not in the AI.
- The AI's dock code has not changed since v7.2. If Istanbul built docks at v7.2, the cause is a map or data change
  after it. The Istanbul map changes since v7.2:
  - `ac458fbb` Team Ferry System (09-12);
  - `6649680a` gate roads and sawmill lot (09-12);
  - `fa44aea2` naval trade routes at level 1 (09-24);
  - `c7ec5f79` ship capture (09-25);
  - `4d43d31f` forward-base markers (09-25).
- The `AIDOCKFAIL` points from this run show which shore the engine rejects.

## Before the test

1. `git checkout Pirate-rework && git pull`.
2. Read `.claude/skills/ai-edit/SKILL.md` and its `references/testing-process.md`.
3. `python -m pytest scripts/aitest/tests -q`: expect **140 passed**. The 4 known `scripts/mapcheck/tests` failures
   (`test_london_roles` x3, `test_parliament_natives` x1) are not caused by this change.
4. The game runs at the home menu. The owner starts it; never kill or launch it.
5. Lobby, the run 14 setup:
   - map **Revelations of Istanbul**;
   - **4 players, 2v2**: the human + 1 AI (team 1) against 2 AIs (team 2);
   - **Extreme**, **Fast**.

## The test: one run, 30 minutes

    python scripts/aitest/driver.py --runs 1 --cap-min 30 --blind --criteria baseline --snapshots --map zpistanbulb

Look at `runs/_loaded/loaded.png` the moment the driver prints `LOADED SCREENSHOT`. An AI error dialog stops the
test; report it at once. Do not touch the mouse during the cap: the top-left corner aborts the driver.

Convert each record once:

    iconv -f UTF-16LE -t UTF-8 Age3DEAIOutputPlayerN.txt

| # | Criterion | Pass when | Echo |
|---|---|---|---|
| T0 | the new AI compiled | every AI player's record has the build line; no dialog on `loaded.png`; the driver prints `map confirmed by the log: zpistanbulb` | `PIRATEFB p<N> build r13 2026-09-25 - 2 construction markers` |
| T1 | pirates/monitors join the gun fleet | for every AI that owns a pirate ship or a monitor | `GUNFLEET p<N> +k hulls, n held` |
| T2 | the gun fleet attacks the Naval Guns | at least one AI | `GUNRAID p<N> fleet h/2 -> s gun-fleet hulls onto gun <id>`; `GUNRAID p<N> waiting: gun fleet h/2, g enemy guns` means too few hulls: report h and g |
| T3 | monitors are trained | every AI whose civ has a monitor and a dock | `MONITORMAINT p<N> maintain up` |
| T4 | the other ships still guard the forts | the fort rules keep running | `GUARD p<N>` / `HOLD p<N>` / `GARRISON p<N>` lines as in run 14 (13-37 GUARD, 28-70 HOLD per AI) |
| T5 | no pirate hull parked at a fort | on the end snapshots of both Naval Forts | visual: pirate-flagged ships at a fort = FAIL |
| T6 | docks | report, do not judge | every `AIDOCKFAIL` line and the `AIDIAG ... docks D dockfails F ... navy N` line at 29:00, against run 14 (docks 0/3/1, navy 0/3/3) |
| T7 | forward base: REPLACED, see the handover brief | - | `PIRATEPLACE p<N> forward base next to the bridge at X/Z` (the enemy beach: north ~398/396, south ~203/187) and `PIRATEFB p<N> state S at X/Z military buildings there M` with M > 0 |
| T8 | no regression | the full 30 minutes run without a crash; every AI reaches Age 3 by 29:00 (run 14: ages 3/4/4) | `AIDIAG p<N> age A` |

## If something fails

| Symptom | Look first |
|---|---|
| AI error dialog on load | the line it names in `aipiraterules.xs` (the restored rules sit near `istanbulGunFleet` and `istanbulGunRaid`; the dock echo is in `aiTestPlacementFailedHandler`) |
| no `GUNFLEET` line although an AI has pirate ships | `kbUnitIsType(unit, cUnitTypeAbstractPirateShip)` on that hull; the plan the hull sits in (`aiPlanGetActualPriority` >= 99 and not a fort keeper = skipped by design) |
| `GUNRAID ... waiting` all game | no pirate settlement and no monitors: the owner's open question (the fallback) |
| a pirate hull still at a fort | the plan holding it: the pool takes only from the two fort keepers and plans below 99 |

## Report to the owner

- The run number and the commit.
- T0-T8, each with its echo lines and the snapshots.
- The `AIDOCKFAIL` points, plotted against the map (north beach ~398/396, south ~203/187 on the 600 m map).
- Anything unexpected.

Do not change gameplay data or what the AI contests (AGENTS.md hard rule 7). Do not run a second test without the
owner's word. The anchor comparison (the same setup on `v7.2`, to settle whether docks worked at the release) is a
proposal only.

## Runs on the main device (2026-09-25, for the record)

| Run | What | Result |
|---|---|---|
| 13 | test 1 of the forward-base brief, 2 min, hand-driven while the driver was adapted to 2560x1080 | **pass**: no dialog, `MAP CODE 'zpistanbulb/4/...'`, `PIRATEFB p2/p3/p4 build r12 2026-09-25 - 2 construction markers` at 00:00:01 |
| 14 | test 2, 30 min | the driver aborted mid-cap (top-left corner: the owner was using the desktop); the owner quit at game time 29:38. Forward base: p2 and p4 targeted 203/187 and the stock plans were re-pointed there, `military buildings there 0` at 20:10; p3 `no construction block on the enemy side`. Whether 203/187 was the ENEMY shore for p2/p4 was NOT verified (it was inferred from the distance rule); the owner's own test: forward bases on the OWN island. Navy and docks as above. |
