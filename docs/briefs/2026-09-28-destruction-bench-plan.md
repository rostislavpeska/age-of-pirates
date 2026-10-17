# Destruction bench: plan (2026-09-28)

Goal: an unattended, repeatable in-game run that damages one building through every stage to its destruction,
captures it, and ends with a report. Subject: `zpKoreanTownCenterTest` (21207, `korean_tc_pilot.xml`). Control:
`zpChineseTownCenterControl` (21208, `chinese_tc_control.xml`, the unchanged Chinese age-2 models). Both protos
are TEST records with the same stats (6,500 HP, identical animfiles except the model paths).

Evaluation (owner, 2026-09-28): **semi-manual**. The harness proves the mechanics (no crash, every marker, timing,
frames captured); the destruction itself is judged by the owner from a keyframe sequence. The sequence is sent to
the owner and deleted after the evaluation. Automatic image judgement (a Gemini video workflow on n8n) is a later
step, only if this one is not enough.

## What the research settled

| Fact | Evidence |
|---|---|
| The live AI echo channel in `Age3Log.txt` is silent since the 2026-09 patch; per-player files flush only at quit | `scripts/aitest/driver.py` (blind mode), `ai-edit/references/test-environment.md` |
| No run ever captured a trigger `trEcho` line in the log | no `Trigger disabling rule` in any archived run |
| Windows OCR (`Windows.Media.Ocr`, en-US) works from PowerShell; OpenCV, PIL, numpy and ffmpeg are present | probed on this PC |
| Trigger vocabulary has everything but game speed and file output | `data/trigger/triggerdata.xml` |
| Proven in a map: `Render Fog/Black Map`, `Send Chat` (with `<font=...>` tags), `Unit Action Suspend`, `FakeCounter Set Text`, `Counter:Add Timer`, `Player Unit Count`, `Units in Area` | vanilla `debug.xs`, `unknown.xs`; `zpblacksea`, `zpcivilwar`, `performance_test` |
| Never used in any map (first run tests them): `Percent Damaged`, `Damage Unit`, `Move to Unit`, `Camera Face Unit` | grep of mod + vanilla maps |
| A placed object's trigger index is `rmGetUnitPlaced + shift`, the shift measured per map (Istanbul 2, London 3) | `rm-trigger-testing` section 4 |
| Mortar: 500 siege, range 4-40 m, rof 6; the TC's guns reach 32 m | live `protoy.xml` |
| The skirmish camera opens on the human player's start location | game behaviour, used by every bench |

## 1. Scenario (generated, one map per subject)

`python scripts/aitest/destruction_bench.py gen --proto zpKoreanTownCenterTest` writes
`<Steam>\Game\RandMaps\000000_destrbench_<tag>.xs/.xml` (the `000000_` prefix; never the mod folder, so it cannot
ship). The spine is rm-unit-bench's frozen one (includes, `chooseMercs`, map size, terrain init, map types, player
placement, TCs), unchanged.

- Player 1's start location is the map centre and the SUBJECT stands on it, so the camera opens on it at the default
  RTS angle. Player 1 also gets an ordinary Town Center 60 m south, so losing the subject does not defeat the player.
  Every other player sits on a 0.40 ring with a Town Center; the map works with whatever the lobby holds.
- Battery: 2 gaia Mortars at 36 m from the subject (outside its 32 m guns). Gaia runs no AI, so nothing re-tasks them.
- Damage modes (`--damage`):
  - `both` (default): the Mortars are ordered to attack at t = 20, 35, 50 s. The fallback steps guarantee the
    schedule: at t = 60/90/120/150 s any stage the artillery has not yet reached is forced (`Damage Unit` 1,625 HP,
    the last one 99,999).
  - `steps`: no artillery; exact damage at t = 20/40/60/80 s, for clean frames and exact timing.
  - `artillery`: artillery only.
- Triggers from t = 0: reveal the map, a sim-time clock counter, the subject's guns suspended (both TCs identical).
  The game speed comes from the lobby (no trigger can set it).
- **Index-free wiring.** The shift is unknown for a new map, so the script builds six trigger families, one per
  candidate shift 0..5. A gate per family (`Units in Area`: the subject's own proto within 2 m of index
  `rmGetUnitPlaced + s`) enables exactly one family, the one whose index really is the subject. The death marker
  needs no index at all (`Player Unit Count` of the proto == 0).

## 2. Markers

Each event shows a large on-screen text through two channels: a chat line (`Send Chat`, font tags) and the
persistent counter line (`FakeCounter Set Text`). The sim clock counter adds the game time.

| Marker | Fires on |
|---|---|
| `ZPMARK START S<s>` | the gate that found the subject (s = the measured shift) |
| `ZPMARK HP75` / `HP50` / `HP25` | `Percent Damaged` >= 25 / 50 / 75 |
| `ZPMARK DEAD` | `Player Unit Count` of the proto == 0 |
| `ZPMARK PLUS5` / `PLUS15` | 5 s / 15 s after DEAD (Fire Event + Timer) |
| `ZPMARK END` | 30 s after DEAD: the harness quits |

The harness OCRs its screenshots, so it needs no log channel. It also tails `Age3Log.txt` and reports whether any
marker or `Trigger disabling rule` line arrived there, which settles that question for future tools.

## 3. Capture

- 10 fps screen video (the driver's ddagrab pipeline) from START to END.
- Full-resolution JPEG every second, plus a 4-frame burst (0.25 s apart) right after each detected marker.
- Close angle: mouse-wheel zoom on the locked view for the intact stills (before the artillery starts at 20 s) and
  for the settled debris (after PLUS15), then zoom back. The cursor stays at the screen centre, so edge scrolling
  cannot move the camera.
- The same generator and camera for the control run. Two runs: Korean, then control.

## 4. Evaluation

Machine checks, PASS/FAIL with evidence:

| Criterion | Test |
|---|---|
| no crash | process alive to END; no new dump in `CrashDumps` or `%TEMP%\AoE3DE_s*.dmp` |
| log clean | no error/failure line in the run's `Age3Log.txt` slice naming the model, hkt, gr2, Havok or the proto; no `XS: Error` |
| triggers compiled | `trigtemp.xs` copied, `trigtemp_check.py` clean, exactly one gate family fired |
| markers | all 8 seen in order; sim times from the clock counter |
| timing vs control | marker sim times per run side by side |
| model visible, intact | subject pixels differ from the surrounding ground; no magenta/black texel blocks in its box |
| frames | video and every keyframe present |

The owner judges the stages and the collapse from the keyframe sheet: intact, each stage (+1 s and +3 s), DEAD,
+2 s, +5 s, +15 s, plus the two close stills, Korean row above control row. I describe what I see on the sheet
first; the owner's word is the verdict.

## 5. Package and outputs

`scripts/aitest/destruction_bench.py` with three commands: `gen` (map), `run` (one match: select the map, Play,
markers, capture, quit through the menu, checks) and `sheet` (contact sheet + clip from two runs). Tests go in
`scripts/aitest/tests/test_destruction_bench.py` (offline: the generated script's spine, scope check, gate
families, marker parser, sheet builder). Run outputs go only to the session scratch folder (rule 8); the tool refuses
an output folder inside the repo.

## Run protocol

1. Offline: generate both maps, run S6 (`xs_scope_check.py`) and the tests. Rebuild no data: the protos and strings
   are already in the compiled twins (checked: both match their sources).
2. Launch through Steam (owner-authorised for this test), skip the intros, wait for the home menu.
3. Skirmish, then select `DESTRBENCH KOREAN` in the map picker and press Play. This is the first unknown: whether the
   picker lists a Steam-root map, and in which category. The lobby screenshot shows it.
4. Watch to END, quit through the menu, then run the control the same way.
5. Stop at once, touch nothing and report on: a crash, a dialog I cannot identify, a map that does not appear in the
   picker, or a Steam login.

The game process is never killed. Nothing is committed without the owner's OK. The Korean TC model and texture work
belongs to another agent and is not touched.

## Risks

| Risk | Fallback |
|---|---|
| `Percent Damaged` or `Damage Unit` does not work | the artillery still destroys the TC; the report names the dead effect |
| the Mortars do not obey `Move to Unit` (gaia) | the fallback steps at 60-150 s |
| no gate fires (the shift is outside 0..5) | no START marker within 15 s: the harness quits and reports; the next map widens the range |
| OCR misses the text | the video keeps everything; markers are then re-derived afterwards from the frames |
| the lobby holds a team setup (London) | irrelevant: the Mortars are gaia and every other player is 80 m away |
