---
name: ui-calibrate
description: Calibrate the test driver's game-UI coordinates for a new device, monitor, or resolution - manual hover-and-Enter through the coordinate table, producing a tracked resolution-keyed sheet plus the gitignored local selector. Triggers on "different monitor", "coordinates wrong", "driver misclicks", "calibrate the UI", "new resolution", "whichsheet".
---

# Calibrating the driver's UI coordinates

The skirmish test driver (`scripts/aitest/driver.py`) clicks the game by
absolute screen coordinates. Those live in **coordinate sheets**, never in
code:

```
scripts/aitest/coords/<WIDTH>x<HEIGHT>_<variant>.json   TRACKED  (reusable)
scripts/aitest/whichsheet.json                          GITIGNORED (local)
```

- A sheet is keyed by resolution, so any device with the same resolution
  reuses it as-is. `1920x1080_default.json` is the original calibration.
- `whichsheet.json` (`{"sheet": "1920x1080_default"}`) selects the sheet on
  THIS device. Without it the driver assumes `<current-resolution>_default`.
  One device may keep several sheets (e.g. `1920x1080_default` and
  `1920x1080_tv`) and switch by editing this one file.
- A missing sheet makes the driver STOP with instructions - it never
  guesses pixels.

## When to calibrate

New monitor, new resolution, UI-scale change, or the game moved between
displays. Symptom: the driver reports lost navigation three times, or the
home-screen probe pixel stops matching.

## How (user's hands required - the buttons must be hovered by a human)

1. Game in **borderless** windowed mode on the target monitor (exclusive
   fullscreen returns invalid pixels to GDI).
2. `python scripts/aitest/calibrate.py` - or `--sheet 2560x1440_default`
   to name the sheet explicitly.
3. Six points, in the flow's natural order. For each: bring the game to the
   screen the prompt names, hover the target, return to the console, Enter.
   - `home_skirmish` - HOME screen, the Skirmish button (also the
     home-screen colour probe - hover a stable gold part of the button)
   - `lobby_probe` - Skirmish LOBBY, any spot whose colour is unique to the
     lobby
   - `lobby_play` - Skirmish LOBBY, the Play button
   - `match_cog` - IN a running match, the cog/menu button top-right
   - `match_quit` - with the cog menu open, the Quit entry
   - `quit_yes` - the quit confirmation's Yes button
   (For the three match points, any quick skirmish works; quit it as the
   last calibration step.)
4. The script writes the sheet and points `whichsheet.json` at it. Done -
   the driver picks it up on the next run.

## Rules for code

Scripts must NEVER hardcode game-UI coordinates. New clickable points go
into the `POINTS` table in `calibrate.py` AND the sheet consumers via
`nav["<name>"]` in `driver.py` - both, in the same change. Ad-hoc probes in
agent sessions should read the active sheet (`load_coords()` in driver.py)
rather than repeating literals.
