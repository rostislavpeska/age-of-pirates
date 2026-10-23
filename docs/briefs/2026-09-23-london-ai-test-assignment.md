# Assignment: London AI test campaign, rounds 1 to 4, on the second device

Written 2026-09-23 for the agent that runs the in-game AI tests on the owner's other device. The
plan, the design and the criteria are in `docs/briefs/2026-09-23-london-ai-plan.md`; read it first,
this file is the operating manual. Round 1 is built and committed (1259f206, 7de85dbf on
`Pirate-rework`) and has never run in a game. Your first job is to run it.

## 0. Ground rules (the owner's, each one cost money before)

- **Never start, kill or relaunch the game process yourself.** The driver never does either. The
  owner starts the game and opens the lobby; if the game is not running or the screen is lost,
  stop and say so.
- **One hypothesis per run.** A run is about twelve minutes of the owner's machine. Read the
  whole record before the next edit.
- **AI edits need no restart**; the game recompiles the AI at every match start. **Data XML edits
  need a restart** (`data/*.xml` + rebuilt `.xml.xmb` twin, protos and nuggets included).
- **Never patch the Paris rules** (`cityGateKiller`, `rerunCityGateKiller`,
  `initializeCityAttackmanager`, `cityAttackmanager`, `buildPirateSocketTowers`). London has its
  own rules; add to those.
- Commit only files you changed, named explicitly, on `Pirate-rework`; push after every round.
  Another agent (the test-suite audit) commits on the same branch: `git pull` before you start.
- Runtime XML is CRLF; the AI files are CRLF; `python scripts/tools/check_art_eol.py` checks art.
- `AGENTS.md` at the repository root binds you; `docs/ai_scripting_guidelines.md` holds the twelve
  hard-won AI rules (shared query object, plan priorities, silent engine failures, echo
  discipline, declare-before-use, no ternary).

## 1. Setup on the device, once

1. `git pull` on `Pirate-rework`. Confirm `git log --oneline -3` shows 7de85dbf or later.
2. The owner restarts the game after the pull (the marker proto is a new entry in
   `data/protomods.xml.xmb`, loaded at process start) and opens the lobby with the map London
   (`zplondon`, the mod's own). Recommended first setup: 1 human vs 1 AI, different teams, normal
   speed, difficulty Hard or Expert. The lobby remembers the setup; the driver only re-opens it.
3. `<profile>\Startup\user.cfg` must contain the two lines `showAiEchoes` and
   `generateAIEchoesOutput`. Nothing else. The profile folder is
   `~\Games\Age of Empires 3 DE\<steam id>\`. The live channel (`showAiEchoes`) has been silent on
   the owner's main device since the September patch; the per-player files
   (`~\Games\Age of Empires 3 DE\Logs\Age3DEAIOutputPlayer<N>.txt`, UTF-16, written when a match
   is quit through the menu) are the record. Check both after the first match; if the live channel
   works on this device, say so, it is useful.
4. Screen: borderless at native resolution, and the game must keep simulating without focus.
   `scripts/aitest/whichsheet.json` names the coordinate sheet (`coords/<WxH>_default.json`).
   If this device's resolution has no sheet, or the first screenshot shows the clicks landing
   wrong, run `python scripts/aitest/calibrate.py` (see `scripts/aitest/NAVIGATION.md`) and commit
   the new sheet. The `quit_yes` point on the 2560x1080 sheet was derived, never measured: confirm
   it on the first quit.
5. `scripts/aitest/arm_crashdumps.bat` once, so a crash leaves a minidump
   (`python scripts/aitest/crashdump_triage.py` reads it).
6. Eyes and hands, one action per call: `python scripts/aitest/probe.py shot <png>` (screenshot),
   `pixel <x> <y>`, `click <x> <y>`, `key esc`, `res`.

## 2. Test 1, the round-1 run

With the lobby open and the game window visible:

    python scripts/aitest/driver.py --runs 1 --cap-min 8 --from-lobby --blind --criteria london

What it does: bring the game window to the front, verify the lobby pixel, click Play (and once
more if the lobby is still up 6 s later, the game eats the first click after a focus change),
wait 150 s for generation and load, hold 8 minutes while checking the process is alive, quit
through the cog, wait for the home menu, copy the per-player AI files into
`scripts/aitest/runs/run_NNN/`, run `criteria_london.py` on them, print `RUN VERDICT`.

Take a screenshot at 30 s (the lobby should be gone), at 200 s (the match should be up) and after
the quit (home menu). Mouse to the top-left corner aborts the driver at once. A `STOP` file next
to the driver ends the batch after the current run.

Round 1 passes when `criteria.txt` shows L0, L1, L2, L3, U1, U2 all PASS:

| Id | Meaning | Boundary |
|---|---|---|
| L0 | `LONDON p<N> build r1` for every AI player | within 30 s |
| L1 | `LONDONSETUP p<N> ... gates found 2 keeps found 2`, socket / ours / keepNear / keepFar all > 0 | within 60 s |
| L2 | `LONDONDIAG p<N> pass k` lines | at least 4 by 6:00, gaps under 120 s |
| L3 | the per-player file has more than 10 lines | |
| U1 | process alive at the cap | |
| U2 | max gap between LONDON echoes per AI player | under 120 s |

### Debugging tree for test 1

1. **No match started** (lobby still up at 30 s): the click was eaten twice or the sheet is wrong.
   Screenshot, compare the Play button's position with the sheet, recalibrate.
2. **A dialog instead of a match**: an AI compile error. The dialog names the file and line. Fix,
   quit the dialog with the cog path by hand if the driver is lost, rerun. No restart.
3. **Match ran, per-player files have only the four stock lines** (`Main is starting`, the two
   init lines, `Explore plan ... FAILED`): the London block did not fire. Either the marker was
   not placed (check `randmaps/zplondon.xs` line 1471 places `aiLondonMark` per player at the
   bridge middle, and that the map generated: the RM dump in `<profile>\RandMaps\` is
   `Age3DERMzplondon.dmp.txt`), or the AI compiled the other tree. Which tree compiled is what the
   `build r1` echo proves; if it is absent while the AI otherwise runs, the game loaded
   `game/ai/coreDLC/`, and the London section must be mirrored there (the owner's memory says the
   split is obsolete; the echo is the evidence).
4. **L1 fails with `gates found` below 2**: the gaia gate query radius (25 m around the marker)
   or the marker position is off. Read the marker x/z in the setup echo against the bridge in the
   RM dump.
5. **L1 fails with `keeps found` below 2**: `zpSPCTowerOfLondon` is not gaia at start, or the
   knowledge base does not list gaia buildings this early. Move the setup rule's interval or
   retry until found (it already returns and retries while the marker is missing; extend that to
   the keeps).
6. **L2 fails**: read whether `londonDiag` was enabled (`gLondonTestMode` true, setup reached its
   end) and whether `kbCanPath2` or `kbAreaGroupGetNumber` threw a compile error (dialog).

### Reading the diagnostics, the input to round 2

`LONDONDIAG p2 pass 1 groups G myGroup A bridgeGroup B farKeepGroup C enemyTc E enemyGroup D path near 1 bridge 1 farKeep 0 enemy 0 explorePlan P state S`

- `myGroup == farKeepGroup` means the knowledge base joins the banks through the deck: the stock
  attack manager will consider the far bank reachable and the army will park at the closed gate.
  The war plan's path check is then mandatory (it is designed that way).
- `myGroup != farKeepGroup` means the banks are split: the stock attack manager will never
  attack across, and the war plan's release must also consider that.
- `path bridge 1` at pass 1 with gaia gates standing tells whether `kbCanPath2` treats gates as
  blocking. If it says 1 while the gates stand, the query does not see gates and round 2 must
  test the gate's state instead of the path.
- pass 1 vs pass 3 differences show what `kbAreaCalculate()` changed.
- `explorePlan -1` or a failed state confirms the stock land explore failure on London; leave it
  for later, it is not on the critical path.

## 3. Rounds 2 to 4

The design is in the plan, section 2. Implementation notes that are not in the plan:

- Put every new rule at the end of `game/ai/core/aipiraterules.xs` in the LONDON section, every
  new global with the LONDON globals near the top (line 18 onwards), because XS resolves names in
  file order. Helper functions above the rules that call them.
- Helpers and their signatures, all already in the core:
  `getUnit(type, playerRelationOrID, state)`, `getClosestGaiaUnit(type, position, radius)`,
  `createAdvancedGaiaUnitQuery(type, state, position, radius, sortAscending)`,
  `createSimpleUnitQuery(type, playerRelationOrID, state, ...)` (ONE shared query object: read
  results before creating the next), `getUnitCountByLocation(type, relation, state, position,
  radius)`, `getAreaStrength(position, radius, relation)`, `getFriendlyArmyValue(planID)`,
  `kbCanPath2(pointA, pointB, protoUnitTypeID, range)`, `distance(vecA, vecB)`.
- Plans: `aiPlanCreate(name, cPlanReserve)` + `aiPlanAddUnitType(plan,
  cUnitTypeLogicalTypeLandMilitary, min, desired, max)` + `aiPlanSetDesiredPriority` +
  `aiPlanSetActive`; orders re-issued every pass with `aiTaskUnitWork(unit, target)`; destroy the
  plan on every exit path. Priority 101 for garrisons that must not be stolen from (stock army is
  99, transports 100), with a hard cap. A build on a socket: the city-state pattern at
  `aipiraterules.xs` around line 1416 (`aiPlanSetVariableInt(plan, cBuildPlanSocketID, 0, id)`).
- Attack postponement: `xsDisableRule("attackManager")`, `xsDisableRule("raidEnabler")`,
  `cvOkToAttack = false`; the reverse to release. The opportunity code refuses attacks while
  `cvOkToAttack` is false (`aimilitary.xs:6372`). Trade and native claims use `gDelayAttacks`,
  leave that one alone.
- Every rule echoes its refusal reason with a throttled heartbeat and every phase change with a
  count. Vocabulary: `LONDONWAR`, `LONDONGATE`, `LONDONKEEP`, `LONDONHOLD`, `LONDONBRIDGE`, each
  line starting `<TAG> p<N>`. Add each round's criteria to `scripts/aitest/criteria_london.py`
  in `evaluate()` with the ids from the plan (L4 to L10), boundaries as hard numbers.
- Test knobs read `gLondonTestMode`: army floors of 6 to 8, intervals of 15 to 30 s. Release
  values are the plan's. `gLondonTestMode` must be `false` in a shipped build.
- Round 2 needs a second AI on the same map only to see the enemy centre; a 1v1 is enough.
  Round 4 needs the enemy to have taken the bridge at least once: a 1v2 with the human passive
  gives that faster than a 1v1.

## 4. Reporting

Append to `docs/briefs/2026-09-23-london-ai-test-report.md`, one section per run:
run number, commit tested, lobby setup, verdict line, the criteria table, the three or four
lines of the record that decided it, the one hypothesis, the one edit. When a round's criteria
pass on two consecutive runs, mark the round done and start the next. Commit the report with
the round's code. The final message to the owner: the report path, the commits, the numbered
decisions you need.

## 5. Files you will touch

| File | What |
|---|---|
| `game/ai/core/aipiraterules.xs` | the LONDON globals (top) and rules (end) |
| `scripts/aitest/criteria_london.py` | criteria per round |
| `scripts/aitest/coords/*.json`, `whichsheet.json` | only if this device needs a new sheet |
| `docs/briefs/2026-09-23-london-ai-test-report.md` | the report |
| `randmaps/zplondon.xs` | only if a round's design in the plan says so; its Steam twin exists only on the owner's main device |

Everything else is out of scope. If the plan and the game disagree, the game wins; write it down.
