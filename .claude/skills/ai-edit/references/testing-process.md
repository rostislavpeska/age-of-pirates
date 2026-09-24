# The automated AI testing process

This is the cycle proven on the London campaign (2026-09-23/24, runs 15-27). The harness lives in `scripts/aitest/`
(driver, probe, criteria, coords, tests). Screen facts are in `scripts/aitest/NAVIGATION.md` and the `ui-calibrate`
skill.

## The rules of the process

1. **Requirements first, as hard numbers, before any run.**
   - Each criterion has an id, a boundary and a source line in the record (`criteria_london.py`,
     `criteria_baseline.py`).
   - A criterion is changed only by the owner. Propose the change; never move a bound silently to make a run pass.
2. **One hypothesis per run.** One edit, one run, one verdict. Two edits in one run make the result unattributable.
   Run 25's "military to the back" was reverted on its own because it was tested on its own.
3. **Done means done. When the criteria pass on two consecutive runs and the owner's requirement is met, STOP:**
   - report, and propose any next idea;
   - add nothing else, not even a "while we're here" improvement.

   Every unrequested change is a new risk to a working state. The night's toxic changes (the socket filter, towers
   at gates, no forward base) came from chasing a metric after the owner's requirement was already met.
4. **The gate applies to every hypothesis.** Anything that changes what the AI contests is a proposal (SKILL.md
   section 0). A failure count is not a requirement; the owner's intent is.
5. **Never edit `game/ai` while a match loads.**
   - The AI compiles at match start, after map generation (London generates slowly).
   - The driver hashes the AI at Play and after the load and flags an AMBIGUOUS run.
   - Edit only once the driver has printed "AI files unchanged during the load", or between runs.
6. **The game process belongs to the owner.**
   - Never kill it.
   - Launch it only on the owner's word.
   - On a crash, stop and report (memory: on-crash-stop-and-wait).
7. **The report is part of the run.** Each run gets these, before the next run starts:
   - a section in `docs/briefs/<date>-<map>-ai-test-report.md`: commit, setup, verdict, criteria table, the deciding
     record lines, reading, the one hypothesis and edit;
   - a short line to the owner;
   - an entry in `docs/briefs/2026-09-23-ai-issues-log.md` for anything the harness or the engine surprised you with.

## The phases

| Phase | What | Gate |
|---|---|---|
| 0. offline | `python -m pytest scripts/aitest/tests -q` (validation-tests.md) | all green, or no match |
| 1. floor | a standard map (Amazonia), 15 min cap, `--criteria baseline` - the regression floor's `metrics.json` | B0, B5 |
| 2. map rounds | the map in the lobby (the owner sets it up; London 3v2 is the owner's choice for more players), 30 min cap, `--criteria london` | the round's L/P ids, two consecutive passes |
| 3. regression | `--map Amazonia --criteria baseline --floor runs/<floor>/metrics.json` | B0-B5 |
| 4. report | summary, decisions for the owner, commits pushed | |

## Commands

    python -m pytest scripts/aitest/tests -q
    python scripts/aitest/driver.py --runs 1 --cap-min 30 --blind --criteria london                 # the map is already in the lobby
    python scripts/aitest/driver.py --runs 1 --cap-min 30 --blind --criteria london --from-lobby    # the lobby is open on screen
    python scripts/aitest/driver.py --runs 1 --cap-min 15 --map Amazonia --blind --criteria baseline --floor scripts/aitest/runs/run_018/metrics.json
    python scripts/aitest/criteria_london.py scripts/aitest/runs/run_NNN      # re-judge a run by hand
    python scripts/aitest/probe.py shot <png> | pixel x y | click x y | key esc | key enter | type <text>

## What the driver does (and why each part exists)

| Step | Behaviour | Found in |
|---|---|---|
| lobby | `--map NAME`: clear the search box, type, Escape, reopen (the picker filters only on open), take the first tile, OK. It then checks for a round minimap (not the random "All Maps" parchment) and a changed minimap fingerprint. | evening 2026-09-23 |
| keys | a full 40-byte `INPUT` struct with scan codes (a keyboard-only struct is silently dropped) | I5 |
| load | the AI hash at Play vs after the load (AMBIGUOUS flag); `XS: Error` in `Age3Log.txt` stops the batch | I8, I11 |
| cap | a process-alive check; the Yes/No dialog signature means an AI resignation, answered Yes (the dialog pauses the game) | I12 |
| quit | recognise the menu by button pixels (live menu: Quit at y 615; post-match: Quit at y 414, where the live menu has Restart), then click; unknown state = Escape and retry; home = two pixels | I2, I4, I10 |
| archive | only per-player files newer than the cap start; `end.png`; the criteria after the quit's flush | I3 |

**When the driver stops,** read `end.png` and a fresh `probe.py shot`, then resolve by hand, one click at a time:
- a dialog's OK moves with its text length, so locate it on the screenshot;
- the first click after a focus change is eaten;
- screenshots downscaled to 1000 px scale by 2.88, to 2000 px by 1.44.

## Reading a record

- **Where it is:** `runs/run_NNN/Age3DEAIOutputPlayer<N>.txt`, UTF-16. The engine's BuildPlan echoes carry no
  newline, so `criteria_london.load` splits at every timestamp.
- **Per-type failure counts:** `BuildPlan(...): failing because building placement failed with state (3)` (no spot)
  vs `we can't path` (unreachable) vs `cannot find an unit` (no builder). Always break failures down by building
  type before any conclusion; a total hides which decision caused it.
- **Game time vs the cap:** at Fast speed, 30 minutes of wall time is 45-55 minutes of game time. A shorter record
  means the game paused (a dialog) or ended.
- **Before blaming the AI,** check the run's validity: the hash line, the civs (random personalities differ a lot),
  a knocked-out player, a frozen dialog.
