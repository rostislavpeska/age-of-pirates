# Setting up the AI test environment

This is a checklist, in order. Each step names the skill or file that owns the detail; follow that, and don't copy
it here. `scripts/aitest/NAVIGATION.md` is the Istanbul-era original. Its general points hold, but its map, test
flag and live log channel do not: the live channel is silent since the 2026-09 patch, and the per-player files are
the record.

## Once per device

1. **The repository:** `git pull` on the working branch. Then run `python -m pytest scripts/aitest/tests -q`, which
   must be all green.
2. **`<profile>\Startup\user.cfg`** holds exactly `showAiEchoes` and `generateAIEchoesOutput` and nothing else
   (**game-startup** skill). Debug switches there froze map generation once (2026-09-18).
   - For an API lookup, add `generateAIConstants` for one match, then remove it.
   - Keep the old file outside the repository when trimming.
3. **Crash dumps:** run `scripts/aitest/arm_crashdumps.bat` once, as administrator. Check with
   `reg query "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\AoE3DE_s.exe"`.
   Read a dump with `python scripts/aitest/crashdump_triage.py`.
4. **Screen:** borderless at native resolution. The game must keep simulating without focus.
5. **Coordinate sheet:** `scripts/aitest/whichsheet.json` names `coords/<WxH>_default.json` (**ui-calibrate** skill;
   the calibration needs the owner's hands).
   - The 2880x1800 sheet carries every point the driver uses, including the map picker, the two-pixel home probe
     and the menu probes.
   - Any new point is MEASURED where it will sit (button edges are gradients). Record it in the sheet's comment and
     the test `test_select_map_needs_its_sheet_points`.

## Once per session

1. **The game process belongs to the owner.** Launch it only on the owner's word, through Steam
   (`steam://rungameid/933110`, **game-startup**), skip the intros with Escape, and wait for the two-pixel home.
   Never kill it.
2. **Data changes** (`data/*.xml` plus the XMB twin, or groupings) need a game restart. AI changes never do: the AI
   compiles at every match start.
3. **The floor:** if none exists for the current AI, run the standard map first (testing-process.md, phase 1).
4. **The lobby:**
   - **A standard map:** the driver can select it (`--map Amazonia`). It keeps the player slots, but a map change
     resets the teams to random.
   - **A map-specific setup** (London 3v2: the human plus 4 AIs, Attackers against Defenders, Extreme, Fast) is set
     by the OWNER. It is fragile: switching maps loses the team setup.
   - Leave the lobby open. From the second run on, the driver reopens it from the home menu.
5. **The human seat stays passive.** Nobody touches the mouse during a batch; moving it to the top-left corner
   aborts. A `STOP` file next to `driver.py` ends the batch after the current run.

## Before each run (the agent)

- Tests are green and the AI is committed. The build echo round in `aipiraterules.xs` matches the criteria you
  expect.
- No AI file edits until the driver prints "AI files unchanged during the load".
- The report already names the run's one hypothesis and the criteria.

## Where things are

| What | Where |
|---|---|
| per-player AI records (UTF-16, written at the menu quit) | `%USERPROFILE%\Games\Age of Empires 3 DE\Logs\Age3DEAIOutputPlayer<N>.txt` |
| the game log (`XS: Error`, mode changes, MAP CODE) | `...\Logs\Age3Log.txt` |
| the engine API dump | `...\Logs\Age3DEAIConstantsPlayer<N>.txt` |
| archived runs, results | `scripts/aitest/runs/run_NNN/` (records, `criteria.txt`, `metrics.json`, `end.png`, `events.txt`), `scripts/aitest/results.csv` (both gitignored) |
| the last lobby screenshot | `scripts/aitest/last_lobby.png` (gitignored) |
