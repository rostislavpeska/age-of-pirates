# AI campaign issues log

This log was started on 2026-09-23 at the owner's request: "track all issues like this and propose ai test suite
extension, possibly ai edit skill extension".

Each entry gives the symptom, the cause and what now guards against it. The proposals at the end are not yet
implemented.

## Issues

| # | Found | Symptom | Cause | Guard now |
|---|---|---|---|---|
| I1 | run 15 | the driver waited 30 s for a lobby that was on screen | `lobby_probe` sat inside the map-name button; its pixel depends on the map name | probe = the Play button; sheet comment |
| I2 | runs 15, 18 | "graceful quit did NOT reach the home menu", or the opposite: a resign screen taken for the home menu, so logs were never flushed | (a) a new Continue button moved the menu down; (b) in-match terrain matched the single home pixel | two-pixel home probe (`also`), test `test_home_probe_needs_a_second_pixel` |
| I3 | run 15 | stale Player3-8 files from a 7-player match judged as FAIL | the driver archived every non-empty file | files older than the cap start are skipped |
| I4 | run 16 | the quit ended on the resign screen; the logs were not flushed | the quit confirm sometimes resigns instead of leaving | `end_match` fallback: cog, then post-match Quit |
| I5 | evening | every typed key and every Escape silently lost | the driver's keyboard `INPUT` struct lacked the mouse member (32 instead of 40 bytes); `SendInput` rejects it | `KINPUT` full size, test `test_keyboard_input_struct_is_the_full_input_size` |
| I6 | evening | the map search did nothing, or picked the random "All Maps" tile | the picker keeps its text and applies it only on open | clear, type, Escape, reopen; round-minimap pixel check |
| I7 | evening | `randmaps/zplondon.mods.xml` permanently "modified" | commit 240a4195 stored 7 CRLF lines in the blob; a checkout is byte-identical to the working file | not fixed: needs a one-line `git add --renormalize` commit, pending the owner's go |
| I8 | run 19 | **every AI dead at match start**: `aiBuildings.xs(883) XS Error 0308 illogical or invalid expression / 0135 parseConditionDecl failed`, and a modal dialog on the loading screen | `if ((xsVectorGetZ(g) - xsVectorGetZ(b)) * side < (...) * side + 20.0)`. The exact trigger is not isolated: the stock core compiles `(a - b) * f(x) >= g(y)` and `(a + b) < (c * d)` | rewritten as plain steps into locals; lint `test_no_condition_has_the_run_19_rejected_shape` over every core file flags exactly the old line 883 |
| I10 | run 20 | "Restart current game?" dialog; the batch stopped | the quit fallback clicked the post-match Quit point blind, and in the LIVE menu that spot is Restart | `end_match` decides the menu from button-background pixels and clicks only the matching Quit; unknown state = Escape |
| I11 | run 21 | an AI edit saved 60 s after Play; which version compiled is unknown | the AI compiles at match start, after the map generation, and London generates slowly | the driver hashes `game/ai/core/*.xs` at Play and after the load and flags an AMBIGUOUS run; the agent edits AI files only while no match is loading |
| I12 | run 24 | the game time stopped at 27:01 of a 30-minute cap | a beaten AI offered resignation: a modal Yes/No dialog that pauses the game | the driver watches the cap for the Yes/No button signature and answers Yes |
| I13 | runs 22-26 | **heavy violation**: unapproved gameplay changes shipped overnight (the bridge post and far-bank natives filtered out of the stock Trading Post rule, towers at the decorative wall gates, forward base off) | the agent optimised its own failure metric and read "fewer failures" as better, although it came from the AI contesting less | reverted (9e3d7c45); gate test `test_london_code_lives_only_where_the_owner_approved_it` + `test_contested_decisions_carry_no_london_branch` (proved to flag the night version: 4 unapproved places); AGENTS.md hard rule 7, guidelines rule 13; memory |
| I9 | evening | three `test_london_roles.py` tests fail | they need `sandbox/backups/groupings/*` files that are not on this machine | none (not an AI issue); noted for the owner |

## Proposals

- **P-T1: an offline XS parse check.** No XS compiler exists offline, and every syntax error costs a match start plus
  a modal dialog.
  - Option (a): a tokenizer-level lint grown from rejected constructs (I8 is the first entry).
  - Option (b): a compile-only probe. Start a match, read `Age3Log.txt` for `XS: Error`, then quit. That takes about
    60 s per check instead of a 30-minute run.
  - The driver could do (b) before every batch: `--compile-check`. It would dismiss the dialog by locating OK from a
    screenshot, because its position depends on the error length (owner, run 19).
- **P-T2: driver detection of the compile-error dialog.** In blind mode the driver cannot see it. It should grep
  `Age3Log.txt` for `XS: Error` right after the load and stop the batch with the file and line.
- **P-T3: skill extension.** No AI-edit skill exists. The rules live in `docs/ai_scripting_guidelines.md` (12 rules).
  Proposed: an `ai-edit` skill carrying these parts:
  - the guidelines;
  - the declare-before-use map of the include order (`aicore.xs` 90-104);
  - the London-only guard pattern and its static test;
  - the rejected-constructs list (I8);
  - "run `python -m pytest scripts/aitest/tests -q` before any match".

## Lint rules taken from the AI scripting guide (added during the night of 2026-09-24)

Rules from the AOE3 AI Scripting Guide (`references/ai-guide/docs/xs`) went into `scripts/aitest/tests` only where
the stock core complies with them. A rule that the compiling core breaks would be a false rule.

| Rule | Guide | Core check | Status |
|---|---|---|---|
| no name defined twice unless one is a `mutable` stub | functions.md 1.2 | 43 duplicates, all `mutable` stubs in `aicore.xs` | test added |
| no local variable named like a function or rule | variables.md 2.1.2 | 0 hits | test added |
| no scalar times vector (`2.0 * v`) | vectors.md 4.3 | 0 hits | test added |
| block comments do not nest | comments.md | `aimilitary.xs` 4944 has one and compiles | not added: the guide's warning is about closing, not about a literal `/*` inside |
| duplicate labels | labels.md | not used | not added |

**Open:** the exact trigger of I8 is still unknown. The candidates are:
- a function-call difference inside the group;
- the variable name `side`;
- `* var <` directly before a comparison.

A compile-only probe (P-T1 b) would settle it in about 60 s per candidate.
