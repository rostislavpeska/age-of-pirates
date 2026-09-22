---
name: rm-census
description: The universal observation skill for random maps - which artifact proves what (trigtemp.xs, the RM dump, a saved .age3Yscn, a screenshot), ground truth for "did it spawn" by parsing a saved generation into protos, indices and positions, spawn criteria, and the measured Scenario Editor sequence the screen drivers use (generate, watch the load bar, save), with their guards and the monitor-independent gamewin.py helper. The drivers run ONLY on the user's explicit request. Triggers on "census", "did it spawn", "how many spawned", "count the units", "spawn criteria", "verify the placement", "not spawning", "which index", "save the scenario", "generate in the editor", "dry run the driver".
---

# rm-census: observe the game through its artifacts

The game, the editor and the screen drivers are run ONLY on the user's explicit request in the current
session, never as a default step. Everything a driver would do can be printed first with `--dry-run`.

## 1. The artifacts

| Artifact | Proves | Lands at | Read with |
|---|---|---|---|
| `trigtemp.xs` | the trigger script the game compiled from the map's `rm*Trigger*` calls, one XS rule per trigger; the whole trigger diagnosis after ONE generation, before any play | `<profile>\Trigger\trigtemp.xs`, rewritten on every generation (editor and skirmish); `london_gen_safe.py` copies it to `sandbox/census/samples/regen/<tag>_trigtemp.xs` | `python .claude/skills/rm-trigger-testing/scripts/trigtemp_check.py` (skill `rm-trigger-testing`) |
| RM dump | the map script compiled: a CXSDump of the compiled script (symbols, functions, code size; values 0, written before the run). No placed units, nothing about triggers | `<profile>\RandMaps\Age3DERM<mapfile>.dmp.txt` | a text editor; its mtime proves a generation ran |
| Saved scenario | every placed unit with proto and position in INDEX order: ground truth for spawns and for the indices triggers name | `<profile>\Scenario\<name>.age3Yscn` (editor Save As); drivers copy it under `sandbox/census/samples/` | `python sandbox/census/census.py <save> [--full]` |
| Screenshot | RENDER only: a unit can be placed and never render (LF-only animfile, missing texture, wrong variation) | `sandbox/census/samples/bench/` or `samples/regen/` | the Read tool |

`<profile>` = `C:\Users\TIGO\Games\Age of Empires 3 DE\76561198347905238`.

```bash
python sandbox/census/census.py "<profile>\Scenario\<save>.age3Yscn"          # per-proto counts
python sandbox/census/census.py <save> --full                                   # every unit with x/y/z, index order
python sandbox/census/census_judge.py <deployed.xs> <save1> <save2> --players 4 --teams 2
python sandbox/census/census_run.py <recipe> --seeds 3                          # editor loop (drives the screen)
python sandbox/census/bench_run.py ...                                          # the unit bench (rm-unit-bench)
```

## 2. Reading a census

**Index = placement order.** `--full` lists units in the save's record order, which is the scenario
INDEX a trigger parameter takes (`rm-trigger-testing` section 4, `nugget-targeting` Rule 0).

**Proto names (verified 2026-09-17, build 25040513):** the save stores the engine's runtime proto
INDEX, not the XML id. `census.py` resolves it as vanilla file position in the CURRENT protoy (the
`mapcheck --live` cache; the snapshot only as fallback) followed by every protomods record whose
name is not vanilla, in file order (`name ="x"` with a space counts too). Two observations pinned it
exactly: zpNatInuitHarpooner 2820 = 2673 + 147, zpSPCLondonBasilica 3631 = 2673 + 958. The old
by-id lookup mis-names everything after vanilla position ~1463 and every mod unit; an
`unknown(NNNN)` now means the live cache is missing (run `mapcheck --live` once). If a known mod
unit resolves to a neighbour's name, the vanilla count changed (new patch): re-run `--live`.
Vanilla names come out right; treat MOD proto names as unreliable and identify a mod unit by its
position, or as "the only proto index that appears exactly N times" (N = how many the map places).

**Patterns:** a nugget with guardians is a run of consecutive indices. London's harbour guard nuggets
`ypNuggetTradingPost` are 363/368/373/378: five apart = the nugget plus four guardians each
(`nugget-targeting`, fix B). Adding N units to anything placed earlier shifts every later index by N:
re-census after any such change.

**Positions:** `census.py` reads x/y/z from the first plausible float triple inside each record
(calibrated 2026-09-17 on a London save: record layouts differ by unit type). Check sanity
(|coord| < map size) before using them; `bench_run.py` judges by names when they are not sane.

## 3. Criteria (state them BEFORE the generation, then read the census against them)

| Question | Criterion | Verdict when it fails |
|---|---|---|
| Fixed placement (AtLoc / AtPoint, max distance 0) | exactly 1 of the proto within 3 m of the authored point | NOT SPAWNED: point obstructed or off-map; check the anchor's own spawn first |
| InArea object, count N | count == N | SHORT: constraints too hard (see rm-objects-herds tiers) |
| Herd | herd anchor present, members within the cluster radius | SHORT: land/passability; do not blame the constraint before checking terrain |
| Grouping (native / structure) | its signature socket / flag unit present (census_judge fingerprints from the grouping XML) | native: not rolled at this player count is normal; structure: missing = deploy gap (rm-groupings-deploy) |
| Player start | TownCenter count == players | the spine or placement sections |
| Trade route | sockets (`SocketTradeRoute`) count == waypoints asked | route not built: name lookup (rm-trade-routes) |
| Trigger index | the unit at that index in `--full` is the proto and spot the trigger means | fix the index, never the constant for docked sockets |

Two censuses of different seeds beat one. A unit present in one seed and absent in another is FLAKY
(constraint headroom), not "works".

## 4. The editor-controlled sequence (measured from the drivers)

Only on the user's explicit request. All positions are client-area pixels of a 2560x1080 client
(`sandbox/census/census_run.py:41-49`), normalised through `sandbox/census/gamewin.py`.

| Step | How the driver does it | Source |
|---|---|---|
| Find the window | `FindWindowW(None, "Age of Empires III: Definitive Edition")`; none -> print, exit 2, no input | `gamewin.py` `find_window` / `open_pilot`; `bench_run.py:161-164`, `london_gen_safe.py:31-32`, `editor_regen.py:150-151, 157-158` |
| Where it sits | client rect in screen pixels, monitor index / device / rect, a WARNING when the client is not 2560x1080 | `gamewin.py` `Pilot.header` |
| Kill + launch (restart) | `Stop-Process -Name AoE3DE_s -Force`, then `steam://rungameid/933110`; ONLY on the user's explicit word (`game-startup` forbids killing otherwise) | `editor_regen.py:112-114` |
| Wait for boot | window up to 150 s, then 30 s; every 6 s for 300 s once the client is >= 2560x1080: focus, grab, Esc (0x1B) while an intro video shows | `editor_regen.py:115-145` |
| Recognise the main menu | >= 12 gold pixels (R>190, G>160, B<160) in the button column x 444, y 240..720 step 2 | `editor_regen.py:24-25, 45-52` (`is_menu`) |
| Open the Scenario Editor | wait 10 s (the menu ignores clicks at first), click (444, 599), check `is_editor` every 5 s x 8, up to 4 attempts; exit 4 if never | `editor_regen.py:26, 68-86` (`open_editor`) |
| Recognise the editor | (1280, 14) dark grey menu bar and (2375, 45) blue player-colour box | `editor_regen.py:27-28, 55-57` (`is_editor`) |
| Foreground guard | focus, grab, `is_editor`; not in front -> "EDITOR NOT IN FRONT", exit 3, no click | `london_gen_safe.py:35-40` |
| New map dialog | File (18, 14) -> New (44, 47) -> Type arrow (1498, 457) | `bench_run.py:69-74`, `editor_regen.py:161-163`, `london_gen_safe.py:44-46` |
| Pick the map | (a) drag the list thumb (1482, 500) -> (1482, 385) to the top, then `down` clicks on the arrow (1482, 760) and row y = 497 + (row - 1) x 31; `--peek` screenshots the open list to count `--nav down,row` | `bench_run.py:69-81` (open, select), `167-172` (`--peek`), `176-181` |
| | (b) London without the drag: (1024, 559) | `london_gen_safe.py:19-21, 48` |
| | (c) London after the drag: (1024, 528) | `editor_regen.py:32, 164-165` |
| Seed | click (900, 497), End, Backspace x width (6 or 12), type the seed | `game_driver.py:153-162` (now `gamewin.Pilot.set_field`); `bench_run.py:183`, `editor_regen.py:166`, `london_gen_safe.py:49` |
| Generate | click (1398, 739) | `bench_run.py:184`, `editor_regen.py:168`, `london_gen_safe.py:51` |
| Watch the load bar | screenshot every 10 s, fill = share of x 785..1773 at y 1032 with B>150, G>150, R<120; 0 % after the first reads = generated, constant = hung; up to 12 (`editor_regen`) or 18 (`london_gen_safe`) reads | `editor_regen.py:30-31, 60-65, 169-180`, `london_gen_safe.py:52-58` |
| ...or wait blind | `--wait` seconds (30), then `tasklist` for AoE3DE_s.exe; gone -> CRASH with the newest `%LOCALAPPDATA%\Temp\AoE3DE_s*.dmp` | `bench_run.py:56-66, 185, 196-203` |
| Proof it generated | the RM dump's and trigtemp.xs's mtimes moved; trigtemp copied to `samples/regen/<tag>_trigtemp.xs` | `london_gen_safe.py:41-42, 64-68` |
| Save | File (18, 14) -> Save As (56, 160) -> name field (1200, 886), width 40 -> Save (699, 838); the name keeps ~30 characters | `bench_run.py:178-179` (name length), `206-210`; `london_gen_safe.py:70-76` (only with `--save` and a written dump) |
| Where the save lands | `<profile>\Scenario\<name>.age3Yscn`; `bench_run` copies it to `samples/bench/`; no file -> NO_SAVE | `census_run.py:31-32`, `bench_run.py:211-219` |
| Screenshots | `samples/bench/<tag>_picked / _generated / _after_save.png`, `peek_dropdown.png`; `samples/regen/<tag>_check / _dropdown / _dialog / _gen_NN / _final / _save.png`, `<tag>_editor.png` | the drivers above |
| Start a playtest from the editor | not measured, no driver does it | - |
| End a playtest, regain the editor or the main menu | not measured, no driver does it | - |

Guards: `bench_run.py` takes the screen for ~60 s - nobody touches the mouse meanwhile (docstring,
lines 10-11). `editor_regen.py` kills the game only on the user's explicit word (docstring, lines 1-3;
the `game-startup` skill forbids killing at all). `london_gen_safe.py` never clicks unless the editor is
recognised in front.

## 5. Monitor independence: `sandbox/census/gamewin.py`

`game_driver.click` scales SendInput over the PRIMARY monitor and `ImageGrab.grab(bbox)` without
`all_screens` sees only the primary monitor, so the drivers were bound to it. `gamewin.Pilot` sends
`MOUSEEVENTF_VIRTUALDESK` input and grabs with `all_screens=True`; positions are normalised 0..1 of the
2560x1080 client and converted to the current client rect (exact at 2560x1080, pinned by tests).

- `find_window()`, `window_rect()`, `client_rect()`, `monitor_of(rect)`, `monitors()`,
  `virtual_screen()`, `is_foreground()` - read-only ctypes.
- `norm`, `normalise_sheet`, `to_client`, `to_screen`, `from_screen`, `input_abs` - pure, tested.
- Every driver takes `--dry-run`: prints the client rect, the monitor, and every click / drag / key /
  text / screenshot it WOULD do with normalised, client and screen coordinates; no input event, no
  screenshot. A missing window = exit 2 without input. Tests: `python -m pytest sandbox/census/tests -q`
  (the dry runs are exercised with every input, screenshot and process primitive patched to fail).
- NOT measured: whether the game's UI scales proportionally at other client sizes (it may anchor or
  centre dialogs). The drivers print a WARNING below 2560x1080; recalibrate from a screenshot there.

## 6. Rules

- Census the DEPLOYED script's output (Steam `Game\RandMaps` for the editor's test maps, the mod folder
  for Skirmish): a repo/deploy skew makes intent and reality disagree for no reason.
- The editor indexes groupings at process start only; after deploying a grouping, restart before the
  census means anything (`rm-groupings-deploy`). The same process-stale law holds for data XMBs.
- Keep saves and screenshots under `sandbox/census/samples/`; name them `<what>_<map>_s<seed>`.
- Never infer spawn from the minimap alone: minimaps show terrain, not units.
- Census yes + screenshot no = art problem (rm-unit-bench pre-flight). Census no = placement problem.
