---
name: aoe3de-trigger-camera
description: Point the Age of Empires III DE camera with triggers and inspect a model in game from scripted views - the Camera Cut value format (measured in the game binary and in game), the world frame and the model-to-world mapping of a placed building, aiming at attachment bones, and the Scenario Editor Playtest automation (scripts/aitest/camera_bench.py - generate the test map, pick it in the editor, Playtest, one still per view, back to the editor). Use to look at attachments, horses, flags, props, construction or destruction states in game, when asked to "set up a camera", "camera trigger", "camera cut", "look at it from the side", "screenshot from a fixed angle", "test in the editor", "inspect the model in game", or before telling the owner a visual fix works.
---

# Trigger camera: inspect a model in game

Learned 2026-10-08 on the Korean stable horses (owner: "test in editor", "Simpler!"). Owner go is needed for any
screen control; stop the moment the owner uses the PC (that day an Escape meant for the game reached the chat
window while the owner typed). The game process is never killed - quit through its menus.

## 1. Camera Cut

| Fact | Evidence |
|---|---|
| Effect `Camera Cut` compiles to `trCameraCut(%CameraInfo%)` | `data/trigger/triggerdata.xml` |
| Engine help: `trCameraCut( pos, dir, up, right ): puts the camera in the specified location.` | string in `AoE3DE_s.exe` |
| The editor's Set Cut writes the value as the literal text `vector(%f,%f,%f), vector(%f,%f,%f), vector(%f,%f,%f), vector(%f,%f,%f)` | format string in `AoE3DE_s.exe`, next to the editor dialogs |
| A random map passing that text compiles to the same call and moves the camera | `trigtemp.xs`: 13 of 13, then 4 of 4; stills in game |
| Outside cinematic mode only position and heading follow; the game camera keeps its own tilt | pitch 20, 32 and 75 all rendered at about the normal tilt |
| `Cinematic Mode` = `trLetterBox(Enter, Letterbox)`; cutscenes run their cuts inside it | `triggerdata.xml`; **not yet tested** for pitch control |

```text
rmAddTriggerEffect("Camera Cut");
rmSetTriggerEffectParam("CameraInfo", "vector(87.929303,5.788282,98.300000), vector(0.939693,-0.342020,0.000000), vector(0.342020,0.939693,0.000000), vector(0.000000,0.000000,-1.000000)");
```

World frame: x and z along the map edges in metres (fraction x map size; the bench map is 200 m, centre 100, 100),
y up. Heading 0 looks along +z, 90 along +x; `right` horizontal, `up = dir x right`. `camera_bench.py math` prints a
value; `camera()` / `camera_info()` there are the tested implementation.

## 2. Aim at the part you inspect, not the building origin

A building placed by `rmPlaceObjectDefAtLoc` stands with **world = unit position + (-raw x, raw y, -raw z)** of its
GR2 (measured from the Korean stable's top view). `camera_bench.py gen --bones GR2:bone_a,bone_b` aims every view at
the mean rest position of those bones. The Korean stable's stall fronts face world -x: heading 90 looks into them.
Views placed low and close to a roofed part show roof, because the tilt stays the game's own (section 1).

## 3. Editor Playtest automation

```bash
python scripts/aitest/camera_bench.py gen --proto zzKoreanStablePhysics --tag korstable --bones art/zbench_korean_military/stable/korean_stable_physics.gr2:bone_horse1,bone_horse2 --headings 60,90,120
python scripts/aitest/camera_bench.py editor --tag korstable [--launch]
```

`gen` writes `000000_cambench_<tag>.xs/.xml` to Steam `Game/RandMaps` (never the mod), with destruction_bench's
frozen spine, the subject at the map centre, one timer trigger per view (Camera Cut + marker `ZPMARK Vnn`), `END`
after the last; offline pre-flight and S6 scope check. `editor` (about 80 s): home menu or open editor ->
Scenario Editor -> New -> Type = the map, found by OCR in the list -> Generate -> toolbar Play (Playtest starts
without a dialog; the editor first saves `~testing`) -> frames labelled by the newest marker, one still per view
picked afterwards -> Escape -> Quit -> Yes (back in the editor, scenario intact). Every click follows a pixel or OCR
check; an unknown screen stops the run with a screenshot. Report, stills, contact sheet, compiled `trigtemp.xs` and
the Age3Log slice go to `%TEMP%/aop_camera_bench/<time>_<tag>/`.

- Screen points live in `scripts/aitest/coords/<W>x<H>_default.json`: `home_editor`, `editor_new`, `editor_play`,
  `editor_type_arrow`, `editor_generate` (measured on 2880x1800), plus the existing `match_quit`, `quit_yes`. Another
  resolution: measure them from screenshots first (**ui-calibrate**).
- The Skirmish map picker did not list the test map; the editor's Type list does (by file stem). Prefer the editor.

## 4. Reading the screen

- The repository's Windows OCR helper (`ocr_server.ps1` next to the bench) returns each line's box. The editor's small bold grey-on-grey list
  text reads as fragments at 1:1; auto-contrast plus 3x enlargement of the list region reads every row.
- OCR output may carry control characters (`json.loads(..., strict=False)`) and cp1252 bytes (decode with
  `errors="replace"`); both crashed a run before the fix.
- Never block the capture loop: a 2 s PNG save after each marker made one still catch the next view. Capture
  JPEG frames continuously and pick stills afterwards.

## 5. Status (2026-10-08)

| Item | Status |
|---|---|
| Camera Cut format, compile, camera moves | verified in game |
| Editor flow: map by OCR, Generate, Playtest, stills, Quit back to the editor | verified (one full run, 4 of 4 views) |
| Model-to-world mapping of a placed building | verified on the Korean stable |
| Pitch control | **not working outside cinematic mode**; cinematic mode untested |
| Korean stable horses | verified in game by the owner; first camera run showed both, bays 1 and 3, facing out |

Tests: `tests/test_camera.py` (camera basis, editor text format, generated triggers, marker parsing; no game).
Related: **aoe3de-model-attachments**, **rm-unit-bench**, **rm-trigger-testing**, **game-startup**, **ui-calibrate**.
