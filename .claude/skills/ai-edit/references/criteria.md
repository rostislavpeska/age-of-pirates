# Success criteria and reading them from the logs

**Every criterion is read from the per-player AI files** (`runs/run_NNN/Age3DEAIOutputPlayer<N>.txt`, UTF-16,
flushed by the menu quit), never from memory of the screen.
- **The judges:** `scripts/aitest/criteria_london.py` (map rounds) and `scripts/aitest/criteria_baseline.py`
  (standard maps, the regression floor).
- **When they run:** the driver runs the right one after the quit (`--criteria london|baseline`) and writes
  `criteria.txt` into the run folder.
- **Re-judge by hand:** `python scripts/aitest/criteria_london.py scripts/aitest/runs/run_NNN`.

**Verdict kinds:**
- **PASS / FAIL:** a requirement.
- **N/A:** not applicable in this run (for example, nobody asked for a forward base), or an **INFO** row that is
  reported but is never a verdict.
- **`RUN VERDICT`** counts FAILs only.

## The echo lines the criteria read

| Echo | Rule | Carries |
|---|---|---|
| `LONDON p<N> build r<k> <date>` | initializePirateRules | the round `k` the AI compiled (it gates which ids apply) |
| `LONDONSETUP p<N> marker x/z socket S gates A B ours O keepNear K1 keepFar K2 pathNear . pathFar . gates found G keeps found K tc T` | londonSetup | the geometry |
| `LONDONDIAG p<N> pass k groups ... path near/bridge/farKeep/enemy ... explorePlan ...` | londonDiag (test mode) | the knowledge base's view |
| `LONDONWAR p<N> held - crossing closed ...` / `path closed, held n passes` / `released - crossing open ...` / `open, attacks on` | londonWarPlan | the hold and the release |
| `LONDONGATE p<N> gate <id> down kind <nearKeep/bridgeOurs/bridgeFar/farKeep> ...` / `tasked n on <id>` / `skip <id> unreachable` / `gathering`, `waiting`, `no target` | londonGateKiller | the gate campaign |
| `LONDONKEEP p<N> flag ours keep <id> <near/far> ...` | londonHoldKeep | a capture |
| `LONDONHOLD p<N> <k> holding / retaking keep <id> ...` | londonKeepHold (30 s) | the garrison heartbeat |
| `LONDONPLACE p<N> countryside / field ... / field point behind gate ... / town center ... / base ... grows to ... / forward base next to the bridge ... (enemy bridgehead) / forward base asked, crossing still closed` | aibuildings.xs London hooks | placement |
| `AIDIAG p<N> age A score S vills V army M navy N tcs T houses H milbldg B farms F plant P bldg X baseR R fails E failsTC C london L tps Q` | aiTestDiag (every map, 60 s) | the state and the failure counter |
| `BuildPlan(<id>: <name> : <id>): failing because building placement failed with state (3) / we can't path ... / we cannot find an unit ...` | the engine | every failed plan (no newline: split at the timestamps) |

## London ids (criteria_london.py)

| Id | Criterion (boundary) | Applies from |
|---|---|---|
| L0 | `build` echo for every AI player within 30 s | r1 |
| L1 | `LONDONSETUP` within 60 s: 2 gates, 2 Keeps, all ids > 0 | r1 |
| L2 | at least 4 `LONDONDIAG` by 6:00, gaps < 120 s | r1 |
| L3 | the per-player file has more than 10 lines | r1 |
| U1 | the game process alive at the cap (driver events) | all |
| U2 | max gap between LONDON echoes < 120 s | all |
| L4 | `held` precedes any `released`; `released` only with "crossing open" | r2 |
| L5 | `gate ... down kind nearKeep` by 12:00 | r2 |
| L6 | no `tasked` on a target skipped as unreachable in the same pass | r2 |
| L7 | `LONDONKEEP flag ours` by 15:00 | r3 |
| L8 | `LONDONHOLD` k >= 3 holding, at most 60 s apart after L7 | r3 |
| P0 | AIDIAG `london 1` for every AI | r4 |
| P1 | AIDIAG `baseR` > 60 m by 20:00 (when the record reaches 20:00) | r4 |
| P2 | placement failures per 10 minutes, **INFO** (the owner's bound is pending, decision 1) | r4 |
| P3 | a `LONDONPLACE field` line and farms + plant > 0 by 25:00 | r4 |
| T1 | Trading Posts owned at the end (`tps`), **INFO** | r4 |
| P4 | when a forward base was asked: <= 3 `Forward` placement failures; N/A when never asked | r5 |

## Standard-map ids (criteria_baseline.py, `--floor runs/<floor>/metrics.json`)

| Id | Criterion (boundary) |
|---|---|
| B0 | every AI player echoes AIDIAG |
| B1 | the last AIDIAG >= 80 % of the floor's game time |
| B2 | the age reached >= the floor's age - 1 |
| B3 | villagers >= 60 % of the floor at the floor's last time |
| B4 | failures per 10 minutes <= 2 x the floor + 5 |
| B5 | no AIDIAG says `london 1` (map code stays off standard maps) |

The floor is run 18: Amazonia 1v1, Extreme, Fast, 15 minutes. Its `metrics.json` is in its run folder.

## Reading beyond the verdict

- **Break failures down per building type and reason** before any conclusion (testing-process.md). A total hides
  which decision caused it; a total that falls because the AI stopped trying is a regression (SKILL.md section 0).
- **Look at the game time of the last line.** Short means a pause (a dialog) or an end (a victory, a resignation).
- **Check validity:** the hash line (not AMBIGUOUS), the civs, a knocked-out player, and `end.png`.

## Adding or changing a criterion

1. **Criteria change only by the owner's decision.** Propose it in the report. An agent's own bound is at most INFO.
2. Add the check to `evaluate()` in the script, gated on the build round that introduces it (`r<k>` in the echo).
3. Add a record that passes and one that fails (or is N/A) to `scripts/aitest/tests/test_aitest.py`.
4. Add a row to this file and to the report's criteria table before the first run that uses it.
