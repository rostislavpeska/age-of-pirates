# Istanbul AI: handover for the agent on the test device (2026-09-25, evening)

For the agent that continues on the dedicated test device (2880x1800). This brief is the single entry point.
It supersedes the test instructions in `2026-09-25-istanbul-forward-base-test.md` and
`2026-09-25-istanbul-fleet-split-restore.md`; read those only for background.

## Owner rules for this work (2026-09-25)

- **No AI edits without the owner's word** ("No AI edits now!"). Propose; never commit an AI change on your own.
- **Observability:** every map-placed AI anchor must be visible to the owner in the Scenario Editor, on the Game-root
  working copy he opens (`000_istanbul.xs`). A mechanism the owner cannot see is unverifiable: "without it we only
  accumulate bugs to explode".
- **File law:** `randmaps/zpistanbulb.xs` (repo, canonical) and `<Steam>/Game/RandMaps/000_istanbul.xs` (editor copy)
  stay byte-identical.
  - Copy the `.xs` only: never the `.xml` (a second "Revelations of Istanbul" in the picker) and never `.mods.xml`.
  - Back up the root copy first, then prove the two files identical by hash.
  - Istanbul is not in `config/local-maps.local.json`, so the sync hook does not copy it.
- **Never report a placement or a target as right until it is seen** on the map or in a census. The side of a beach
  is never inferred from a distance.
- **Testing:** on the test device, debug with as many runs as it takes (owner: "agent does another testing and will
  test more"), one hypothesis per run. Never test on the owner's main device.
- **Regression avoidance on EVERY other map must be "not cautious but unhealthily obsessive"** (owner 2026-09-25).
  Step 1b below is a gate, not a suggestion.

## What happened today

1. `4d43d31f` (morning) put a forward-base marker (`zpAILondonConstrMarker`) for **every player on both** landing
   beaches, **in the repo map only**. The AI keeps the marker "nearer the enemy's start than our own base".
   - **The owner's test: FAILED.** The AIs built the forward base **on their own island**.
   - In the editor the owner saw **no markers at all**: the editor copy `000_istanbul.xs` never received them.
2. `41ecb3b1`: the fleet split was restored (pirate ships and monitors attack the Naval Guns). Still untested.
3. `9a010ae8` + `4d1ba359`: the test driver adapted to 2560x1080 (no change on this device).
4. **This commit** (the owner: "ONLY AT ENEMY BEACH AND EDIT 000 ISTANBUL IN GAME ROOT TOO ... No AI edits now"):
   - **Map:** one marker per player, **on the enemy beach only**:
     - the north beach (398 / 396 m, `beachBoxNE`, above the strait) is the **north team's** shore;
     - the south beach (203 / 187 m, `beachBoxSW`) is the **south team's**;
     - so a north-team player gets the SOUTH beach and a south-team player the NORTH beach;
     - which lobby team is north is the `sideRoll` coin flip; 2-team lobbies only.
     - The owner's editor copy was made byte-identical (sha256 `92a90323...`).
   - **The owner then saw markers for ONE team only.** Hypothesis: the exact beach point (0 m placement radius) is
     cliff in some generations, and the marker had no `PlaceAnywhere`.
   - **`data/protomods.xml`:** `zpAILondonConstrMarker` gets `<flag>PlaceAnywhere</flag>`, as the mod's other editor
     markers have it (`zpTrainStopper`, `zpVolcanoObstruction`). The twin is rebuilt, and **a game restart is
     needed**. The owner has not yet seen the result.
   - **Tests:** the marker test now requires exactly this rule and fails on the old both-beaches block. Expect
     140 passed.

## Step 1 - setup

1. `git checkout Pirate-rework && git pull`.
2. `python -m pytest scripts/aitest/tests -q`: **140 passed**. Then the full `python -m pytest scripts/mapcheck/tests -q
   -rs`, and **every failure and skip is explained** (Step 1b). The main device at this commit: 488 passed, 5 failed
   (gun-socket oracle x4 on a live trigger file, Tortuga profile x1).
3. **THE NEW MAP VERSION, mandatory** (the owner: the other agent needs "ESPECIALLY the new map version"). The whole
   fix is in `randmaps/zpistanbulb.xs`, and the editor shows only the Game-root copy.
   - Back up `<Steam>/Game/RandMaps/000_istanbul.xs` (create it if this device has none).
   - Copy `randmaps/zpistanbulb.xs` over it, `.xs` only.
   - Prove identity by sha256 (this commit: `92a90323...`) and report the hash.
   - Skirmish tests use the mod map `zpistanbulb` ("Revelations of Istanbul"); the editor uses `000_istanbul`. Both
     must be this version.
4. **The game must be (re)started after the pull**: the proto change loads only at start. The owner starts it;
   never kill or launch it yourself.

## Step 1b - REGRESSION GATE on every other map (obsessive, before and after)

What this commit and today's earlier ones reach beyond Istanbul, and the proof each needs:

| Change | Reaches | Proof required |
|---|---|---|
| `PlaceAnywhere` on `zpAILondonConstrMarker` (`data/protomods.xml`) | **London** (`zplondon.xs`, editor copy `00000_zplondon.xs`), **Paris** (`zpparis.xs`), Istanbul: the only maps that place it (grep `zpAILondonConstrMarker` in `randmaps/` and the Game root) | For London and Paris: generate, save, census. Every marker's owner and position must equal the last good state (the London / Paris runs of 2026-09-24 and the AI's `PIRATEFB p<N> build ... K construction markers` count). **A marker that was not there before is a change in what the AI contests** (AGENTS.md rule 7): stop and report. `PlaceAnywhere` must only let blocked markers place, never move one. |
| `AIDOCKFAIL` echo in `aiTestPlacementFailedHandler` (`41ecb3b1`) | **every map** while `gAITestDiag` is true | The Amazonia floor run (`--map Amazonia --criteria baseline --floor <floor metrics.json>`, testing-process.md phase 3): no AI error dialog, no `XS: Error`, B0-B5 as before |
| the fleet split (`41ecb3b1`) | only maps with a gaia `IstanbulVictoryObject` (`gIsIstanbulMap`) | on the London, Paris and Amazonia records: **no** `GUNFLEET` / `GUNRAID` / `MONITORMAINT` line |
| the Istanbul marker block | Istanbul's own triggers (gun sockets, guilds, forts, palaces) | on a fresh Istanbul generation: `python -m pytest scripts/mapcheck/tests/test_gunsocket_lock.py -rs` with **no skip and no fail** (see below), and the trigger targets checked against the census (`rm-census`, `rm-trigger-testing` skills) |
| build echo r13 | all maps | every AI record says `build r13` (London: `LONDON p<N> build r13`) |

**Gun-socket oracle.** `TestTrigtempOracle` reads the last generated `Trigger/trigtemp.xs`.
- On the main device it **FAILED once** on the owner's Istanbul generation of the new map (13:19-13:31).
- The file was overwritten by the next generation before the details could be read.
- Both of its trigger families take the socket id from the same `gunSocket<S>` variable, so the marker change should
  not be able to desync them. **This is unproven.**
- A/B it:
  1. Generate the new map and run the test.
  2. If it fails, generate the pre-change map (`git show 4d43d31f^:randmaps/zpistanbulb.xs` into a temporary
     Game-root copy with its own name) and run it again.
  3. Fails on both: pre-existing, report. Fails only on the new one: the marker block shifts ids. Stop and report.

Also failing on the main device, not from this work: `test_profile.py::test_tortuga_known_issues_suppress_gate`
(expects 5 known issues, finds 0). Tortuga does not place the marker; the other session is changing Tortuga's art.
The 4 older known failures (`test_london_roles` x3, `test_parliament_natives`) pass now.

## Step 2 - THE GATE: the markers, seen

Nothing else runs until this passes.

1. Scenario Editor: generate `000_istanbul`, 4 players, 2 teams (2v2).
2. Look at both landing beaches, next to each shore's Fisherman's Guild:

   | Beach | Where | Must show |
   |---|---|---|
   | north | ~398 / 396 m | the **south** team's players' markers, one each (editor blocks in their colours; they may stack on one point) |
   | south | ~203 / 187 m | the **north** team's players' markers, one each |

3. Ground truth: save the scenario and census it. The `rm-census` skill with `sandbox/census/census.py` lists every
   `zpAILondonConstrMarker` with its owner and position. Report the list.
4. Verdict:
   - **PASS:** every player owns exactly one marker, on the beach of the other team's shore. Report to the owner and
     wait for his word before step 3.
   - **One team still missing:** placement was not the cause. The team test is. Proposal only, **needs the owner's
     go**: decide the side from the player's own start position instead of the team number (north half of the map
     -> the south beach). Check the RM API name in the rm skills' references before writing it.
   - **No markers at all:** check the game was restarted after the pull (the proto change), then that
     `000_istanbul.xs` equals the repo file.

## Step 3 - only on the owner's word: one 30-minute AI test

Run `2026-09-25-istanbul-fleet-split-restore.md` (lobby, command, criteria T0-T6 and T8) with **T7 replaced**:

| # | Criterion | Pass when |
|---|---|---|
| T7 | the forward base on the ENEMY island | `PIRATEPLACE p<N> forward base next to the bridge at X/Z` names the beach of the OTHER team's shore (north-team player: 203/187; south-team player: 398/396), and the end snapshots show that player's military buildings on the enemy shore next to that Fisherman's Guild |

Known AI risk, to report and not to fix: `pirateForwardBasePoint` rejects a marker that is farther from the enemy's
start than our own base, and echoes `no construction block on the enemy side`. Run 14's p3 did exactly that. It is the
AI refactor the owner will direct.

## Open items (owner decisions, not tasks)

- The AI's distance rule in `pirateForwardBasePoint`: the refactor.
- The fleet-split fallback (any warships onto the guns when there are no pirates or monitors).
- Docks: 12-15 placement failures per AI in run 14. The `AIDOCKFAIL` echo (the plan's points) comes with the next AI
  run.
- Prevention guards G2 / G3 (`2026-09-25-ai-regression-prevention.md`).
