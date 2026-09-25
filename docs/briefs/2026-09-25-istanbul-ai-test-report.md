# Istanbul AI test report (2026-09-25)

The test from `2026-09-25-istanbul-fleet-split-restore.md`, run on the dedicated test device (2880x1800).

## Run 41

**Setup**
- Commit: `4d1ba359` (Pirate-rework). AI build echo `r13 2026-09-25`. `pytest scripts/aitest/tests`: 140 passed.
- Lobby: Revelations of Istanbul, 4 players, 2v2, Extreme, Fast, Supremacy.
  - Team 1: the human (P1, British, idle) and P3 (Giuseppe Garibaldi, Italians).
  - Team 2: P2 (Jean Parisot, Maltese) and P4 (Maltese).
  - Team 2 got the north shore, team 1 the south shore. The outer seats are P4 at (132, 450) and P3 at (447, 150).
- Command: `driver.py --runs 1 --cap-min 30 --blind --criteria baseline --snapshots --map zpistanbulb --from-lobby`.
  - The lobby was set up by hand first. The game had been in the Scenario Editor since the mapsim night.
- The records run to game time 49:53. The driver did not quit at the cap (I20), so the match ran about 4 more
  minutes until the agent quit it by hand. Every "by 29:00" figure is read at that game time.

**Verdict:** the fleet split works (T1-T4 pass). The forward base fails the owner's intent: P4 built on its **own**
shore (T7, the owner saw it live). Docks are much better than in run 14. The dock diagnostic prints no points (I21).
Baseline B0 and B5 pass.

| # | Criterion | Result | Evidence |
|---|---|---|---|
| T0 | the new AI compiled | **PASS** | `PIRATEFB p2/p3/p4 build r13 2026-09-25 - 2 construction markers` at 00:00:01; no dialog on `loaded.png`; `map confirmed by the log: zpistanbulb`; AI hash unchanged during the load |
| T1 | pirates and monitors join the gun fleet | **PASS** | `GUNFLEET` p2 35 lines from 06:12, p3 45 from 09:23, p4 22 from 16:15; the fleet holds 1-3 hulls |
| T2 | the gun fleet attacks the Naval Guns | **PASS**, all three AIs | first `GUNRAID ... fleet 2/2 -> 2 gun-fleet hulls onto gun <id>` at p2 08:32, p3 13:18, p4 31:50. Raids: p2 23, p3 46, p4 16. The gun ids change all game, so guns die and are rebuilt. Waiting lines: p2 26, p3 9, p4 27 (`fleet 0-1/2`) |
| T3 | monitors are trained | **PASS** | `MONITORMAINT ... maintain up`: p4 15:32, p2 21:02, p3 23:33 |
| T4 | the other ships still guard the forts | **PASS** | by 29:38 GUARD / HOLD / GARRISON: p2 39 / 22 / 6, p3 29 / 24 / 81, p4 38 / 22 / 3. Run 14: 13-37 GUARD, 28-70 HOLD |
| T5 | no pirate hull parked at a fort | **not measured** | `snapshots.py` photographs the bases and fields, not the two Naval Forts. The logs cannot show where a hull stands |
| T6 | docks (report only) | better than run 14 | `AIDIAG` at 29:02: docks 4 / 2 / 4 (p2 / p3 / p4), dockfails 8 / 6 / 8, navy 4 / 6 / 2. Run 14: docks 0 / 3 / 1, navy 0 / 3 / 3. `AIDOCKFAIL` points: none (I21) |
| T7 | forward base next to the enemy's Fisherman's Guild | **FAIL (intent)** | details below |
| T8 | no regression | **PASS** | no crash in 49:53 of game time. Age at 29:02: p2 3, p3 3, p4 4 (run 14: 3 / 4 / 4). Age 3 first reached: p4 16:01, p2 21:01, p3 24:01 |

### T7: the forward base

The markers, placed on the calibrated in-match minimap (`scripts/mapview/cal/ingame_2880x1800.json`, 600 m map):

- **N marker (397/395)** is on the **north** shore: team 2's own shore, next to P4's buildings.
- **S marker (203/187)** is on the **south** shore: team 1's, next to the human's Town Center.

| AI | Target | Right shore? | What happened |
|---|---|---|---|
| p2 (north) | S marker from 14:17, against enemy 1 or 3 | yes | The stock picks at 150/155 and a landing at 220/243 were re-pointed there. `military buildings there 0` all game (plans 461, 561) |
| p3 (south) | N marker against enemy 2; `no construction block on the enemy side` against enemy 4 | yes | 1 military building there 23:16-25:18. From 41:49 to 45:44 the stock landing picked a new point about every 10 s and was re-pointed each time; it never left stage 0 |
| p4 (north) | N marker against enemy 3; no block against enemy 1 | **no: its own shore** | The stock picks were on the enemy shore: forward bases at 505/240 (23:14) and 497/245 (29:17), a landing at 348/245 (35:12). All three were re-pointed to the N marker. P4 built there twice (20:11 plan 414, 30:12 plan 829; 1 military building each). From 35:14 a forward base stood at 196/205, the enemy beach, with up to 4 military buildings |

**Cause:** `pirateForwardBasePoint` (`aipiraterules.xs`) calls a marker "the other shore" when it is nearer the
most hated enemy's start than our own main base. That works on London's bridge, but not on Istanbul's outer seats.
- **P4 against P3:** the N marker, on P4's own shore, is 250 m from P3 but 271 m from P4, so it is accepted.
- **P3 against P4:** both markers are nearer P3 (247 m / 250 m) than P4 (272 m / 271 m), so P3 has no target.

**Proposal withdrawn.** "Accept only a marker off our island" does NOT work here: Istanbul's two shores are
land-connected around the rim (`aipiraterules.xs` 257-270), so both beaches are the same area group. The owner
fixed it in the map instead (`5e96d31e`: one marker per player, on the enemy beach only, plus `PlaceAnywhere`).

### Other observations

- P2 placement failures: Factory 132, TownCenter 113, Plantation 55, zpWhiteFort 52. P3: TownCenter 160.
  P4: TownCenter 77, plus 72 plans without a type in the echo.
- The human was idle all game, so team 2's score led: 231k against 188k.

## Run 42

**Setup:** commit `87bfb400` (the enemy-beach-only markers + `PlaceAnywhere`, game restarted), AI `r13`, same lobby
(2v2, Extreme, Fast). Team 1: human + Garibaldi (Italians, P3); team 2: Isabella (Spanish, P2) + Napoleon
(French, P4); team 2 had the south shore. The records end at game time 27:14 after the 30-minute cap (the game ran
slow or paused while the desktop was in use). Baseline B0 / B5 pass; the driver quit cleanly.

| # | Result |
|---|---|
| T0 | PASS: `build r13 ... 1 construction markers` for p2 / p3 / p4; no dialog; map confirmed |
| T1 | PASS: `GUNFLEET` p2 3, p3 11, p4 12 lines |
| T2 | PASS (p3 9 raids from 08:02, p4 6 from 14:18); **p2 0 raids** - its gun fleet was 0/2 until 17:25, 2/2 only at 21:46 |
| T3 | PASS: `MONITORMAINT` for all three |
| T4 | PASS: GUARD 59 / 76 / 62, HOLD 2 / 14 / 2, GARRISON 35 / 0 / 31 (p2 / p3 / p4) |
| T5 | not measured (no snapshot of the Naval Forts) |
| T6 | docks 2 / 4 / 3, navy 6 / 1 / 9 at 27:00 |
| T7 | targets right, nothing built: p2 -> 397/395, p3 -> 203/187, p4 -> 399/395 (vs enemy 1) - every one the enemy beach; p4 vs enemy 3: `no construction block on the enemy side` (the distance rule) and 3 stock forward bases cancelled; no AI established a forward base by 27:14 |
| T8 | PASS: no crash; ages 4 / 3 / 4 at 27:00 |

**Editor check (Step 2), same commit:** 2 of 2 generations of `00000_zpistanbulb` (sha256 `92a90323...`, identical
to the repo and to `000_istanbul.xs`), 4 players / 2 teams: every player owns exactly one marker, on the other team's
beach. Before the restart (old proto, no `PlaceAnywhere`) 1 of 2 generations lost the north team's markers - the
owner's 'one team only'.

**Regression vs the proven fleet split (`d33dba2e`, 2026-08-27):** the hull test and `istanbulMonitorMaintain` are
identical; the pool priority is 100 instead of 96 (deliberate). **Not restored: the fallback** - with fewer than 2
gun-fleet hulls, 4+ warships of any kind (`gIstanbulGunShipMin = 4`) attacked the gun. Without it a gun fleet stuck
below 2 hulls idles (p2 above), and a civ with no pirate ship or monitor never attacks a gun. **Owner decision 2026-09-25: NOT restored**
('rather no merge ... the custom landing and custom dock builder never worked properly') - the fallback belongs to
the stripped custom-landing design; do not re-add it as a 'regression fix'.

**Deferred (owner 2026-09-25: another iteration, it needs an overnight test session):** `pirateForwardBasePoint`'s distance rule (with one
enemy-beach marker per player the map already decides the side).
