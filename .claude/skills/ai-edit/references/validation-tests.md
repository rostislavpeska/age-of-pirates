# Automated validation tests

    python -m pytest scripts/aitest/tests -q        # all of them, about 2 s, no game needed

Everything lives in `scripts/aitest/tests/test_aitest.py`: 68 tests on 2026-09-24. Run them before every AI commit
and before every match. A red test means no commit and no match: an XS error costs a match start, a modal dialog and
every AI player.

## What each group guards

| Group | Guards | Born from |
|---|---|---|
| `test_london_code_lives_only_where_the_owner_approved_it` + `APPROVED_LONDON_CODE` | London code only in functions / rules with the owner's quoted approval | I13, the heavy violation |
| `test_contested_decisions_carry_no_london_branch` | `tradingPostMonitor`, `forwardTowerBaseManager`, `towerManager`, `selectTowerBuildPlanPosition` stay free of map branches (and exist under that name) | I13 |
| `TestLondonOnlyPlacement` | every `london*` helper starts with `if (gIsLondon == false) return`; every other London line sits inside a `gIsLondon == true` block; the build echo matches the round | "other maps stay clean" |
| `TestAIFiles` | campaign globals declared once, in `aiglobals.xs`; `aiTestDiag` is echo only (no plan, task or enable; assigns only its locals); enabled only through `gAITestDiag`; the failure counter is the handler's first statement; AI files are CRLF | the AIDIAG regression floor |
| `test_no_condition_has_the_run_19_rejected_shape` + `test_the_lint_catches_the_run_19_line` | the XS shape the engine rejected in run 19 (Error 0308 / 0135), in every core file; the lint proves it flags the old line and passes the stock core's compiling look-alikes | I8 |
| `test_no_local_is_named_like_a_function_or_rule`, `test_no_scalar_times_vector`, `test_no_name_is_defined_twice_without_a_mutable_stub` | rules from the AOE3 AI Scripting Guide | guide review 2026-09-24 |
| `TestLondonLoader`, `TestLondonCriteria`, `TestRoundFourCriteria`, `TestRoundFiveCriteria` | the criteria scripts on synthetic records: glued echoes, empty human files, each L/P id passing and failing where it should, N/A when not applicable | the harness faults I3 and the criteria |
| `TestBaseline` | `criteria_baseline.py` B0-B5 against a floor: a stall, failure spam, a missing AIDIAG, the London flag on a standard map | the regression floor |
| `TestDriverInput`, `test_home_probe_needs_a_second_pixel` | the driver's 40-byte `INPUT` struct, the coordinate sheet's required points, the two-pixel home probe | I5, I2, I10 |

## Adding a test (the house rules)

1. **Every in-game surprise gets a test,** or an explicit note in the issues log explaining why none is possible.
2. **A lint rule must pass the STOCK core first.** Run it over every `game/ai/core/*.xs` file. If the compiling stock
   code breaks it, the rule is wrong.
   - The first I8 lint ("a condition that opens with a group followed by `*`") was wrong: `aieconomy.xs` 1609
     compiles that shape.
   - The "nested block comments" rule was dropped because `aimilitary.xs` 4944 compiles one.
3. **Prove a lint catches the bug.** Run it on the broken version of the file (`git show <commit>:<path>`) and keep
   a test that asserts it flags the line.
4. **A criterion test needs both cases:** a synthetic record that PASSES and one that FAILS (or N/A), built with
   `london_record()` / `diag()` / `diag4()`.
5. **Write test files that contain regexes with the editor, not through shell heredocs.** `\b` in a non-raw Python
   string became a backspace character (0x08) in a test once, and backslashes collapse in bash (memory:
   bash-heredoc-collapses-backslashes).
6. **A new map family** gets its own `APPROVED_<MAP>_CODE` list and guard tests, copied from London's.

## Known gaps (proposals, issues log)

- **No offline XS compiler.** The lints catch known shapes only. Proposed: a compile-only probe that starts a match,
  reads `Age3Log.txt` for `XS: Error` and quits. That takes about 60 s instead of a 30-minute run.
- **Behaviour inside the game is proven only by runs.** The tests prove structure, scope and the harness, not play.
