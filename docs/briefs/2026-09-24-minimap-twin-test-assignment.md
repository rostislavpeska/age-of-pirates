# Assignment: live test and debugging of the minimap digital twin, on the dedicated test device

Written 2026-09-24 by the session that built it on the owner's main device (2560x1080). You run on the other device
(the owner's test machine; its aitest sheet is 2880x1800). Nothing here has run live on your screen yet. Everything
offline is proven; the owner wants the live part tested and debugged on YOUR device, not on the main one.

## 0. Read first

1. `git pull` on `Pirate-rework` (the work is in commit aa8a0467 and later).
2. `AGENTS.md` (hard rules), the skill `.claude/skills/minimap-twin/SKILL.md` (the tools), the spec
   `docs/briefs/2026-09-24-minimap-digital-twin-spec.md` (its section 7 lists what the build corrected).
3. The owner's rules that bind you here:
   - **Never kill the game process.** Launching through Steam (`steam://rungameid/933110`) is allowed on this device.
   - **One hypothesis per run**; read the whole result before the next edit.
   - **Do not modify** `scripts/aitest/driver.py`, `probe.py`, `criteria*.py`, `coords/*.json`, `game/ai/**` - the AI test
     campaign owns them. If an AI test run is in progress on this machine (a `driver.py` python process), wait: one game,
     one test at a time.
   - Commit only files you changed, named explicitly (`git add <paths>`), `git pull` before `git push`.
   - Scratch output (screenshots, twin.json, videos) goes to a temp folder, never into the repository
     (`scripts/mapview/out/` is gitignored; the tools default to a temp folder).

## 1. What exists (all offline-tested: 714 tests pass on the main device)

| Piece | Where | State |
|---|---|---|
| geometry | `scripts/mapview/transform.py` | world m <-> fractions <-> minimap u/v <-> pixels; a Calibration record |
| disc detector | `scripts/mapview/minimap_detect.py` | ring fit, rim, probes, camera outline (diagonal intersection), player stars |
| calibration CLI | `scripts/mapview/calibrate.py` | `disc` (measure), `check` (explorer pairs), `edges` (icon-free), `stars`, `show` |
| census | `scripts/mapview/census_reader.py` | own position from the header at tag-49, owner (`player`), map size from the save |
| twin | `scripts/mapview/twin.py` | mapsim expected vs census actual: key objects, grouping votes, owners, MISSING/unmodelled |
| camera | `scripts/mapview/camera.py` | goto / shot / record by world metres; verifies the camera outline |
| input layer | `scripts/gameio` (`python -m scripts.gameio ...`) | Session with corner abort, foreground and window-under-cursor checks; capture; sheets |

Measured on the MAIN device (2560x1080) - compare, do not reuse on your screen:
- editor minimap: centre (2269.33, 920.33), drawn rim 130.5 px; live London 4p check: explorers 0.76-1.22 px, edges PASS.
- in-match HUD minimap: (2399.32, 899.31), rim 147.0 px - from a PRE-patch frame only, never re-measured live.
- twin on a live London 4p save: 35/35 key objects, 67/69 groupings, 0 extra, owners all ok.

## 2. Your screen first (nothing below works without it)

1. `python -m scripts.gameio where` and `python -m scripts.gameio state`: the game window, its client size, the monitors.
   Every tool keys its records by the game's CLIENT size (W x H).
2. `scripts/gameio/sheets/` has only `2560x1080.json`. Create `<W>x<H>.json` for your screen with the same namespaces,
   entering ONLY points you measured on a full-resolution screenshot (`python -m scripts.gameio shot <png>`), each with
   provenance `measured 2026-09-.. <file>`. Needed: menu skirmish / scenario_editor (+ label rgb and an `also` probe),
   `menu._layout` frame lines (see the 2560 sheet), editor file / new / type_arrow / generate / save_as / name_field /
   save, match cog / quit / yes. The September patch moved the main menu (a Continue button was added): never copy
   coordinates across resolutions, and never use a point without a probe.
3. Safety check before the first real click: `python -m scripts.gameio click <x> <y> --dry-run` shows the planned events;
   the first live click logs `verify_cursor` / `verify_window` - if it raises CursorMismatch or NotForeground, stop and
   read why (that is the layer protecting the owner's other windows).

## 3. Test plan (report each step's numbers)

### T1 - editor calibration (about 10 min)
1. Main menu -> Scenario Editor (`python -m scripts.gameio menu scenario_editor` once your sheet has it, else one
   verified click at a time with a screenshot before each).
2. File > New: Type = London (the list shows the Steam-root test copies `00000_*` first and the mod's maps by file name;
   the root copy must be byte-identical to `randmaps/zplondon.xs` - never put a `.mods.xml` in the game root), 4 players,
   2 teams, any seed. Generate. Save As `mapview_london4p_<device>`.
3. A full-resolution screenshot with NO dialog open.
4. `python scripts/mapview/calibrate.py disc <png> --screen editor` (add `--box x0,y0,x1,y1` around the minimap if the
   default box - the right-most 700 x bottom-most 500 px - misses it on your resolution).
5. Check twice:
   - `calibrate.py stars <png> --colour 0,0,255 --colour 255,0,0 --colour 255,255,0 --colour 128,0,128`, pair each star with
     its player's Explorer from `census_reader.read(<save>)` (`player` = the colour's slot), write the pairs file in metres
     (size from `census_reader.map_size(<save>)`, London 4p = 360 x 686) and `calibrate.py check <pairs.json> --screen editor
     --size <W>x<H>`. Pass = every explorer within 3 px (main device: 0.76-1.22 px).
   - `calibrate.py edges <png> --screen editor --map zplondon --players 4`. Pass = both long edges 0.5-2.5 px inside the
     model, within 1 px of each other, the map reaching the rim at both ends (main device: 1.31 / 1.31 px).

### T2 - the twin (5 min, offline)
`python scripts/mapview/twin.py randmaps/zplondon.xs --players 4 --teams 2 --census <save> --team-layout 1,2/3,4`
Expected (the main device's live numbers): key objects 35/35, groupings 67/69 (the two misses are REAL - see 5), extra 0,
owner mismatches 0. Any other MISSING: read its note (either-arm, search radius, route-docked, unmodelled) before calling
it a spawn bug; if it is one, report it to the owner, do not change the map without his word.

### T3 - the London Bridge change of 2026-09-24 (5 min, offline, on the same save)
The owner removed one Venetian pole from `EU_SPC_London_Bridge` (unit #106 at 0.7455 / 39.6545; 112 -> 111 units). By the
index law in `randmaps/zplondon.xs` (section 13, "THE HARBOUR IDS ARE LITERAL INDICES") the four harbour guard nuggets
moved 366/371/376/381 -> 365/370/375/380; the script and its tests now say so, but it is a PREDICTION.
Confirm on your fresh save: `census_reader.read(<save>)` -> the four `ypNuggetTradingPost` census ids must be 365, 370,
375, 380 and the four `zpOrientalFerry` 169-172; the bridge grouping 111 members (twin vote). If they differ, fix the
four literals (map + `scripts/mapcheck/tests/test_london_roles.py` pins) and report.

### T4 - in-match calibration and the camera (about 15 min)
1. Start a London skirmish (the lobby setup is the owner's; any player count, note it: 3-5 players = 360 x 686 m).
2. After the load, a full-resolution screenshot with no menu or dialog open, the mouse off the minimap.
3. `calibrate.py disc <png> --screen ingame` (a `--box` around the HUD minimap if needed; your aitest sheet's
   minimap_center is (2641,1562) on 2880x1800 - a hint, not a measurement).
4. `calibrate.py edges <png> --screen ingame --map zplondon --players <N>`. OPEN QUESTION: whether the in-match minimap
   draws the outside of the map black like the editor. If `edges` refuses for that reason, say so, and continue with
   `--unchecked` on the camera (never write a fake check).
5. Camera (the match must be running, the game in front, your hands off the mouse):
   `python scripts/mapview/camera.py goto 280 344 --map zplondon --players <N> --screen ingame [--unchecked]` (the bridge),
   then `shot` at the bridge, the Keeps (39.72, 262.99) and (42.28, 423.01), a harbour post (41, 375), and
   `record ... --seconds 20` at the bridge. Report per target: target px, look_at px, error, state (verified / off_target /
   not_found / clipped), and whether the photo shows the target. Measure once whether look_at equals the clicked pixel;
   if there is a constant offset, store it as `look_offset_px` in the record (and say how you measured it).
6. The park spot (the camera parks the mouse off the minimap): check the photos for a tooltip; if one appears, measure a
   tooltip-free HUD spot and add `match.park_mouse` to your sheet.
7. Quit the match through the menu, one verified click at a time.

## 4. Debugging process

- Every tool prints its decision and writes JSON next to its outputs; read those before changing code.
- camera states: `refused` (a gate: probes, calibration, disc margin, foreground) - read the reason; `not_found` / `off_target`
  (the outline) - look at `<name>_verify_*.png`; `clipped` (the outline cut by the rim; never retried).
- `calibrate.py` REFUSES rather than guesses: a dimmed screen (a dialog), a wrong map size, a missing ring.
- Offline tests before every commit: `python -m pytest scripts/mapsim/tests scripts/mapview/tests scripts/gameio/tests
  sandbox/census/tests -q` (with and without `-m "not local"`). Known unrelated failure:
  `scripts/mapcheck/tests/test_jones_captain.py::TestPlacement::test_side_records_are_last` (a newer Cromwell consulate
  record after Jones; not this work).
- Fix bugs in `scripts/mapview` / `scripts/gameio` with a test that reproduces them first; keep the owner's safety
  properties (no input outside the game, a batch stops when the game loses the foreground).

## 5. Known facts and open items

- REAL map finding (reported to the owner, not changed): both London riverside deco blocks
  (`EU_SPC_London_Riverside_SE_01` / `_NW_01`) spawn 78 m east of the asked x = 12 m (at x = 90 m).
- The minimap star is the EXPLORER, not the town centre.
- The engine map size is whole 2 m tiles (London 4p 686 m, not 685).
- Open: the in-match disc on today's build; whether the in-match minimap draws black outside the map; the camera's first
  live clicks; the park spot; the 2880x1800 gameio sheet.

## 6. Report

Write `docs/briefs/2026-09-24-minimap-twin-test-report.md`: per step the command, the numbers, pass/fail, the one
hypothesis and the one edit for any failure. Commit your sheet, calibration records (`scripts/mapview/cal/*.json` for your
resolution), fixes with their tests, and the report; push. Last message to the owner: the report path, the commits, and
the decisions you need from him.
