# London AI: plan, risks, test protocol

Written 2026-09-23 for the owner's GO decision and, after round 1, as the base of the assignment for
the agent that continues on the other device. Facts here were read from the code the same day;
the file:line references are the evidence.

## 0. What is wrong today (measured)

| Fact | Evidence |
|---|---|
| The AI plays London as a plain land map: no London block, not in any map list | `game/ai/core/aipiraterules.xs` 20-70, 120-500 |
| The Paris gate killer runs on London (urban marker placed per player) and picks the gaia gate closest to the base by straight line, no path check | `zplondon.xs:1471`, `aipiraterules.xs:901` |
| The stock attack manager judges reachability by knowledge-base area group; the bridge deck is land, so the far bank counts as reachable; the army parks at the closed gaia gate | `aimilitary.xs:6358`, bridge gates at `EU_SPC_London_Bridge.xml:48,73` |
| The socket rule that rebuilds towers is never enabled on London | `aipiraterules.xs:133,285` are its only enables |
| The Paris flag manager guards a victory point with a desired 10 units at priority 20 to 30, below every stock plan | `aipiraterules.xs:604-620`, `986-1115` |
| In the 10:34 test the AI logged 4 lines in 4 minutes, one of them the engine's land explore plan failing for lack of waypoints | `Logs/Age3DEAIOutputPlayer2.txt` |
| The live echo channel is silent this session; per-player logs flush at quit only | `Logs/Age3Log.txt` has no `P#` lines; August runs had them |

## 1. Design, in one paragraph

London gets its own rule family in `aipiraterules.xs`, sharing no plan handle or global with the
Paris rules. The map stops placing the Paris urban marker and instead places a London marker at the
bridge middle. A setup rule reads the bridge geometry from that marker. A war plan holds the two
stock attack rules off and the attack permission false while the real pathfinder says the enemy
centre is unreachable, and releases them when the path opens. A London gate rule carries the Paris
gate killer's mechanics with an ordered, path-checked target list. A Keep mission in Istanbul's
palace pattern captures and then holds each Keep with a capped garrison above the stock army's
priority. A bridge family kills the own-side gate, builds the post on the port socket, and holds
the middle. The existing socket rule is merely enabled; it already handles both socket types.

## 2. Rounds

Each round is one commit set, one test, one verdict. Nothing from a later round is started before
the earlier round's criteria pass.

### Round 1 (this session): marker, detection, diagnostics, harness

1. `data/protomods.xml`: `zpAILondonBridge`, id 21196, a clone of `zpAIStartUrbanMap` (20549):
   invisible air unit, no LOS, no AI, not selectable. XMB twin rebuilt. **Needs one game restart**,
   protos load at process start.
2. `randmaps/zplondon.xs`: the per-player urban-marker placement at line 1471 keeps its slot and
   loop but places `zpAILondonBridge` at the bridge middle instead of `zpAIStartUrbanMap` at the
   map centre. Same number of units in the same order, so no trigger index moves. The Paris chain
   is thereby off on London; Paris and Versailles are untouched.
3. `aipiraterules.xs`, additions only:
   - a London block in `initializePirateRules`, keyed on the player's own marker
     (`kbUnitCount(cMyID, cUnitTypezpAILondonBridge, cUnitStateAny) > 0`): sets the pirate-map
     flag, enables `buildPirateSocketTowers` and `londonSetup`, echoes `LONDON p<N> build r1`.
     That echo also proves which AI tree the game compiled (`core` vs `coreDLC`).
   - `londonSetup`, one shot at 10 s: marker position; port socket = closest `zpSPCPortSocket`;
     bridge gates = gaia `SPCFortGate` within 20 m of the marker; our gate = the one closer to our
     town centre; Keeps = gaia `zpSPCTowerOfLondon`, near = the one the pathfinder reaches from
     the town centre. Echo every id and distance. Enable `londonDiag`.
   - `londonDiag`, every 60 s while `gLondonTestMode`: number of area groups, our base's group,
     whether the enemy centre shares it, `kbCanPath2` from the town centre to the near Keep, the
     bridge middle and the enemy centre, the explore plan's state. On its second pass it runs
     `kbAreaCalculate()` once (Istanbul's cure for knowledge-base holes) and echoes the same
     figures again.
   - `gLondonTestMode = true`, one global; every threshold in later rounds reads it.
4. Harness, `scripts/aitest/`:
   - `driver.py --from-lobby --blind`: skip the home-menu step when the lobby is already up; after
     Play, wait a fixed load time, then the cap, then quit through the cog; the verdict comes from
     the per-player AI files copied into the run folder, decoded from UTF-16. No dependence on
     the live channel.
   - `criteria_london.py`: the criteria below, evaluated on the per-player files, one table per
     run, `RUN VERDICT: PASS/FAIL`.
5. Test 1 protocol: I restart nothing. You restart the game once (new proto), load the London
   lobby as now, say so. I run one match, cap 8 minutes, and read the record.

### Round 2 (other device): the gate rule and the war plan

- `londonWarPlan`: stage machine, holds `attackManager` and `raidEnabler` disabled and
  `cvOkToAttack` false while `kbCanPath2(townCentre, enemyCentre)` is false; releases them when
  true; takes them back if it closes. Echo on every stage change and a throttled heartbeat
  `LONDONWAR p<N> path closed, held <n> passes`.
- `londonGateKiller`: the Paris mechanics (reserve at 90, 1.5 strength ratio, guardians first,
  gate second, forward base at a fallen gate, re-run on rebuilt army) with an ordered target list:
  near Keep's two gates, then our bridge gate, then the far Keep's gates only after release. Every
  target passes `kbCanPath2` from the reserve's position before an order; unreachable = skip with
  an echo, never a task.

### Round 3 (other device): the Keep mission

- `londonKeepMission`: Istanbul's palace pattern, guardians with one shared target and a mass
  floor, then inside the capture ring, then hold.
- `londonKeepHold`: a reserve at priority 101 capped at `gLondonKeepGarrison` (6 in test mode),
  refilled when it dies, retake when the flag flips.

### Round 4 (other device): the bridge family

- `londonBridgeClaim`: with our gate down and a post affordable, a build plan on the port socket
  (`cBuildPlanSocketID`, the city-state socket pattern); an enemy post there is attacked first.
- `londonBridgeHold`: a standing defend plan at the bridge middle, re-claim loop.
- Release of the stock attacks follows automatically from the war plan's path check.

## 3. Pass criteria

Every criterion is a hard boundary read from the per-player AI files. A run passes only if every
applicable criterion passes. Times are game time from the echo's timestamp.

| Id | Round | Criterion | Boundary |
|---|---|---|---|
| L0 | 1 | Build and detection: `LONDON p<N> build` for every AI player | within 30 s of match start |
| L1 | 1 | Setup complete: `LONDONSETUP` names the socket, two gates, our gate, near and far Keep | within 60 s, all ids > 0 |
| L2 | 1 | Diagnostics flowing: `LONDONDIAG` per AI player | at least 4 lines by 6:00, gaps < 120 s |
| L3 | 1 | No silent AI: the per-player file has more than the 4 stock lines | > 10 lines by 6:00 |
| L4 | 2 | Attacks held: `LONDONWAR held` precedes any `released`; no `released` while the path echo says closed | ordering |
| L5 | 2 | Near Keep gate down: `LONDONGATE gate <id> down` | by 12:00 in test mode |
| L6 | 2 | No unreachable order: zero `LONDONGATE tasked` lines whose target the same pass echoed as unreachable | count = 0 |
| L7 | 3 | Keep captured: `LONDONKEEP flag ours` | by 15:00 |
| L8 | 3 | Keep held: `LONDONHOLD <k> holding` with k >= 3 | every <= 60 s after L7 |
| L9 | 4 | Bridge ours: `LONDONBRIDGE post ours` | by 20:00 |
| L10 | 4 | Released: `LONDONWAR released` after L9 and the far Keep gate echo follows | ordering |
| U1 | all | Process alive at the cap | no `GAME PROCESS DIED` |
| U2 | all | No stalls: max gap between any `LONDON*` echoes per AI player | < 120 s until the cap |

Round 1 judges L0 to L3, U1, U2. The `LONDONDIAG` values themselves are data for round 2's
design, not pass/fail: they decide whether the banks share an area group and whether the
pathfinder query behaves as the reference says.

## 4. Debugging process, per run

1. `results.csv` row and the console verdict.
2. `runs/run_NNN/criteria.txt`: the table; the first FAIL is the hypothesis.
3. `runs/run_NNN/Age3DEAIOutputPlayer<N>.txt` (UTF-16): `grep LONDON`, read in time order.
4. No `LONDON` line at all: (a) screenshot for the compile-error dialog, it names the file and
   line; (b) the build echo missing but stock lines present means the block did not fire, so the
   marker query failed: check the marker's player and proto in the census; (c) no per-player file
   at all means the quit did not flush, the run was not ended through the menu.
5. One hypothesis per run. Edit, run again. AI edits need no restart; data XML edits do.
6. The engine fails silently on tasks (guideline 4): every rule echoes its own refusal. A rule
   that goes quiet is a bug in the rule, not the game.

## 5. Risks

| Risk | Mitigation |
|---|---|
| Live channel dead; a crash loses the per-player logs, they flush at quit only | short caps in round 1; `U1` names a crash; minidumps armed by `arm_crashdumps.bat` |
| AI compile error blocks every AI player | screenshot step in the debugging process; the dialog names the line |
| Knowledge base: one or two area groups unknown; `kbCanPath2` untested in this build | `londonDiag` echoes both readings before any rule depends on them |
| Unit stealing between plans (stock army 99, transport 100) | reserves at 101 with hard caps; caps tunable |
| Removing the Paris chain from London leaves no capture logic until round 3 | it never worked on London; rounds are short |
| Driver coordinates are the 2026-08-26 sheet; `quit_yes` was derived, not measured; the game eats the first click after focus loss | round 1 run watched by screenshot at each step; corrections go into the sheet |
| `coreDLC` tree exists beside `core` | the build echo proves which compiled; edit the other only if the echo says so |
| Test mode left on at release | `gLondonTestMode` is one global; the deploy check will assert it false (to add to `mod-deploy-check`) |
| Another agent commits in the same tree | own paths only, explicit `git add`, branch Pirate-rework |
| Game restart needed for the marker proto | once, before test 1; AI edits afterwards never need one |

## 6. What the owner does

- Say GO.
- After round 1's edits: restart the game once, load the London lobby, say so.
- Never during a run: no clicks, no alt-tab into the game; the driver clicks absolute coordinates.
- Read the verdict and the criteria table; decide the next round.
