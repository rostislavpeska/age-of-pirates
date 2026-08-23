# AI landing test harness — navigation & operation

Automates skirmish test runs of the Istanbul landing AI: launch → lobby →
match → live verdict from `Age3Log.txt` → per-run log archive → restart.
Built for unattended batches (the 1000-run campaign); a human only intervenes
when the driver reports it is lost.

## One-time game setup (5 minutes, by hand)

1. **Windowed or borderless mode at a FIXED resolution.** Click coordinates
   are only stable if the window never moves or resizes. Borderless at native
   resolution is best.
2. Options → make sure the game **keeps simulating without focus** (if a
   "pause on focus loss" style option exists, disable it). If the game pauses
   when it loses focus, the driver must never alt-tab away — it doesn't, but
   you must not either during a batch.
3. Set up the skirmish once: Single Player → Skirmish → map **zpistanbulb**,
   you + 3 AI (2v2), difficulty as desired, **game speed fast**. The lobby
   remembers these settings; the driver only ever re-opens and re-starts it.
4. `Startup/user.cfg` must keep `showAiEchoes` + `generateAIEchoesOutput`
   (already in place — that is what makes `Age3Log.txt` stream the echoes).
5. The AI's `gIstanbulLandTestMode` is `true` during the campaign — army bar
   2, gun gate skipped, 30 s cooldowns — so every match produces a landing
   attempt (or a named refusal) within the first minutes.

## Calibration (once, ~5 minutes)

The driver clicks named points recorded from YOUR screen:

    python scripts/aitest/calibrate.py

It prompts for each point in order. For each: hover the mouse over the target
and press **Enter in the console** (alt-tab to the console to press it — for
menu points this is safe; for in-game points the game may pause, that is fine
during calibration). It records position + the pixel colour under the cursor
(the colour is later used to VERIFY the screen state before clicking).

Points recorded, in order:

| name            | where to hover                                             |
|-----------------|------------------------------------------------------------|
| `main_single`   | main menu: the Single Player button                        |
| `sp_skirmish`   | single-player page: the Skirmish button                    |
| `lobby_start`   | skirmish lobby: the Start Game button                      |
| `esc_menu_restart` | in-match: open Esc menu first, hover Restart            |
| `restart_confirm`  | the confirmation button for Restart (if a dialog appears; if none, hover Restart again) |
| `match_probe`   | any pixel that is ONLY that colour during a running match (e.g. a fixed HUD element corner) |
| `menu_probe`    | any pixel that is ONLY that colour on the main menu        |

Recorded to `scripts/aitest/nav_points.json`.

## Running a batch

    python scripts/aitest/driver.py --runs 20

Per run the driver:
1. Ensures the game process is up (launches `steam://rungameid/933110` if not,
   then waits for the `menu_probe` colour).
2. Navigates: `main_single` → `sp_skirmish` → `lobby_start`, verifying each
   screen by probe colour, with retries.
3. Tails `Age3Log.txt` live from the current offset until a verdict:
   `LANDED / BOARD-FAIL / CROSS-FAIL / SHIP-LOST / GATES-STUCK / NO-DATA`
   (same logic as `landwatch.py`), capped at 22 minutes.
4. Archives the run: `scripts/aitest/runs/run_NNN/` gets the log slice, the
   verdict, and timestamps. `results.csv` gets one row per run.
5. Restarts via Esc → `esc_menu_restart` → `restart_confirm` and goes to 3.
   If the match probe is not seen again within 90 s, it falls back to the
   full lobby path; if still lost, it **stops and says so** rather than
   clicking blindly.

Stop a batch at any time: create the file `scripts/aitest/STOP` (`touch STOP`)
— the driver finishes the current run and exits cleanly. Emergency: move the
mouse to the top-left screen corner; the driver aborts before its next click.

## Known unknowns (resolved by run 1)

- **Does Esc→Restart reload the AI from disk?** If yes, code edits between
  runs need only a restart. If no, the driver's `--full-cycle` flag makes it
  quit to menu and re-enter the lobby each run (slower, guaranteed fresh).
- **GetPixel on the game window**: works in windowed/borderless for most
  setups. If probes always read black, run the game windowed (not exclusive
  fullscreen) — the calibrator warns if it records pure black.

## Reading a campaign

`results.csv` columns: run, start, verdict, seconds-to-verdict, events. The
interesting analyses: verdict histogram, first-failure stage drift after each
code change (the driver stamps the AI file's mtime into each row, so runs are
attributable to the exact code version they tested).
