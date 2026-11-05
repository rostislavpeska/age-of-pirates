# mapsim debug log, night of 2026-09-25

Overnight session working through `docs/mapsim_feedback_2026-09-25.md`. Scope: `scripts/mapsim/**` and this log only.
Nothing is committed; the owner reviews the working diff. Every render/scratch output is in the session scratchpad
(`.../scratchpad/mapsim_night/`), never in the repo.

Baseline before any change (2026-09-25 evening):

- `python -m pytest scripts/mapsim/tests scripts/mapview/tests scripts/gameio/tests -q -p no:cacheprovider`: 615 passed.
- `python -m pytest scripts/mapcheck/tests -q -p no:cacheprovider`: 488 passed, 4 skipped.

Sweep tool: `scratchpad/sweep.py <label>` runs every `randmaps/*.xs` and `game/randmaps/*.xs` at P2T2, P2T2 KotH and
P6T2 through extract -> bridge -> run_checks and writes `mapsim_night/sweep_<label>.json`.

## Fixes

(filled in as the night goes)

## Open questions and map issues

(filled in as the night goes)
