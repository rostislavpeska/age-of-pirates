# Report: live test of the minimap digital twin on the 2880x1800 test device

2026-09-24, 15:20-16:30. The session on the test device carried out
`docs/briefs/2026-09-24-minimap-twin-test-assignment.md` from section 0. The game was already running (started 12:07).
It was never killed or relaunched. No AI test was running (no `driver.py` process).

**Result:** T1, T2 and T3 pass. T4 passes with one open item: the in-match record stays unchecked (section T4).
Five tool bugs were found on this device. Each one was reproduced by a test first, then fixed. The map was not
changed.

## Your screen first (section 2)

- `gameio where` / `state`: the game runs full screen on the only monitor. Client area = screen = 2880x1800.
- **Sheet** `scripts/gameio/sheets/2880x1800.json`. Every point in it was measured on a full-resolution capture of
  this screen and clicked live at least once, except `menu.tools`. The sheet has these namespaces:
  - **menu**: skirmish, scenario_editor, tools, plus the `_layout` frame lines;
  - **editor**: file_menu, file_new, file_saveas, file_return_main, type_arrow, type_list_up, generate,
    close_dialog, save_name, save_button, menubar, player_box;
  - **match**: cog, quit, quit_yes;
  - **minimap**: both discs.

  The lobby and map-picker points are recorded under `_not_entered`, because the sheet contract has no `lobby`
  namespace.
- The menu layout is not the 2560 layout scaled. The button column is at x = 186, the buttons are 82.5 px apart,
  and every second frame line is 1 row thick. The first click went through `gameio menu scenario_editor`; the
  `verify_cursor` and `verify_window` checks passed. No `CursorMismatch` or `NotForeground` was raised during the
  session.

## T1: editor calibration: PASS

| Step | Command / action | Numbers |
|---|---|---|
| Editor | `gameio menu scenario_editor`, File > New | the dialog appears 1-3 s after the New click |
| Type | the list offers only the Steam `Game\RandMaps` root and vanilla maps, no mod maps | I copied `randmaps/zplondon.xs` + `.xml` to the root as `00000_zplondon.*`, byte-identical (sha256 71e91189...), no `.mods.xml`. The copy appeared only after Close + File > New |
| Generate | London, 4 players, 2 teams, seed -1 | generated in under 10 s |
| Save | `Scenario/mapview_london4p_2880x1800.age3Yscn` | 10 543 records, map 360 x 686 m (180 x 343 tiles) |
| disc | `calibrate.py disc live/10_generated.png --screen editor` | centre (2553.25, 1534.21), rim 218.72 px, bright line 227.52 px (ratio 1.0402), rms 0.878, 287 rays, 8 probes in 4 quadrants |
| stars | `calibrate.py stars ... 4 colours` | **FAILED first**: "no star" for all four (bug 1). After the fix: (2572.0, 1688.0), (2633.0, 1631.0), (2403.0, 1504.5), (2469.0, 1447.0); scores 0.99 / 0.99 / 0.94 / 0.99 |
| check | explorers 8302 / 8690 / 9078 / 9467 at (33, 153), (163, 147), (49, 543), (185, 533) m | **PASS**: 1.95 / 1.22 / 1.72 / 1.10 px (limit 3). The main device measured 0.76-1.22 px at a 1.68x smaller scale |
| edges | `calibrate.py edges ... --map zplondon --players 4` | **PASS**: insets 2.322 / 2.378 px, sides within 0.056 px, no black cap at either end, 177 samples a side |

The committed record `scripts/mapview/cal/editor_2880x1800.json` keeps the explorer check. `edges` overwrites the
check pairs, so I restored the record written after `check`.

Two small observations:
- All four explorers read about (-0.85, +1.2) px from the model, the same bias at every star.
- The edge insets (2.3 px) sit near the band's 2.5 px ceiling. The main device's 1.31 px times this screen's 1.68x
  scale gives 2.2 px, so the fixed pixel band depends on the resolution (decision 1).

## T2: the twin: PASS, after two fixes

`twin.py randmaps/zplondon.xs --players 4 --teams 2 --census <save> --team-layout 1,2/3,4`

| Run | Key objects | Groupings | Extra | Owner mismatches | Cause |
|---|---|---|---|---|---|
| 1 | **6/35** | 6 matched, 35 partial, 28 missing | 181 | 0 | bug 2: proto names from the stale snapshot |
| 2 | 35/35 | 67/69 | **1** (`zpHarbourPlatform` 286) | 0 | bug 3: a tied grouping vote |
| 3 (final) | **35/35** | **67/69** | **0** | **0** | the main device's numbers exactly |

The two misses are the known real finding: `EU_SPC_London_Riverside_SE_01` and `_NW_01` are asked at x = 12 m.
Every other MISSING line is route-docked or a runtime point, and each carries its note. I found no spawn bug.

The London groupings are absent from this device's profile `RandMaps\groupings` folder. They spawned anyway, all 67
of them, so the mod's own `game/randmaps/groupings` is being read. That contradicts the skill `rm-groupings-deploy`
("the profile folder is the only deploy target"). I did not change the skill; this is for you to confirm.

## T3: London Bridge ids: PASS (the prediction holds)

On the same save, from `census_reader.read`:
- `ypNuggetTradingPost` census ids **365, 370, 375, 380**;
- `zpOrientalFerry` **169, 170, 171, 172**;
- the `EU_SPC_London_Bridge` vote **111/111** members, 0.6 m from the asked spot.

No literal needed changing.

## T4: in-match calibration and camera: PASS, the check left open

**The lobby, 5 players.** Me as P1, plus 4 Extreme AIs: P3 and P5 attack, P2 and P4 defend. Map size 360 x 686 m.
- London is not found by any search under "All Maps". The mod's maps are listed only under Select Type =
  **Custom Maps**, where London's tile is "Restoration of the Monarchy".
- Reopening the picker resets the type to All Maps, so pick Custom Maps after reopening.
- The first Play click was eaten. My second click landed after the fast load, on the in-match **flare button**, and
  armed flare mode. Esc cancelled it. The AI driver's "click Play again after 6 s" rule can hit the same button on
  this device (decision 4).
- No AI error dialog appeared on the loaded screen.

**disc** (`calibrate.py disc live/35_match.png --screen ingame --box 2360,1260,2880,1800`, mouse parked mid-screen):
- centre (2639.24, 1529.19), rim 220.89 px, line 229.82 px (ratio 1.0404), rms 0.886, 8 probes;
- the aitest `minimap_center` (2641, 1562) is 33 px below it.

**edges** (`--players 5`): **FAIL**.
- Insets 3.454 / 3.524 px against the 0.5-2.5 band. The sides agree within 0.07 px.
- The map reaches the rim at both ends of the long axis.
- The open question from the brief is answered: **the in-match minimap draws the outside of the map black**, like
  the editor.

**One hypothesis:** the in-match map is drawn smaller than the ring, about 1.6 %. The camera's first errors had a
radial part that fits that. The test used two static minimap glyphs, measured in both frames against each record.
Their offsets from the model agree between the editor and the match within 0.27/0.04 and 0.59/0.31 px; a 1.6 % shrink
would move them 1.6 px inward. **Refuted:** the in-match scale matches the explorer-checked editor record. The thicker
inset is how the match draws the edge, and the edge band was only ever measured in the editor. No save of the match
exists, so no pairs exist, and the record stays `checked: false`. The camera ran with `--unchecked`, as the brief
says.

**The camera** (`camera.py goto/shot/record X Z --map zplondon --players 5 --teams 2 --screen ingame --unchecked`):

| Target (m) | Target px | Look-at before the offset | Error | Look-at with the offset | Error | State | Photo |
|---|---|---|---|---|---|---|---|
| bridge (280, 344) | (2684.3, 1483.2) | (2682.7, 1480.7) | 2.98 | same | **1.77** | verified | the bridge and its towers |
| Keep S (39.72, 262.99) | (2611.8, 1629.5) | (2611.1, 1624.7) | 4.85 off_target | same | **1.18** | verified | the Keep, centred |
| Keep N (42.28, 423.01) | (2540.1, 1555.5) | (2541.0, 1552.2) | 3.39 off_target | same | **1.30** | verified | the Keep, centred |
| harbour post (41, 375) | (2561.4, 1577.9) | (2561.5, 1573.7) | 4.22 off_target | (2561.7, 1573.6) | **0.90** | verified | the post and its docks |
| Minster (244, 424), new | (2631.5, 1463.2) | - | - | (2630.2, 1461.0) | **1.82** | verified | the domed Minster |
| trade block (260, 214), new | (2734.4, 1551.5) | - | - | (2732.0, 1547.6) | **2.10** | verified | the trade block |
| record bridge, 20 s | as the bridge | - | - | - | 1.77 | verified | `bridge_rec.mp4`: 21.9 s, 1280x800, 10 fps; the bridge with the fighting on it |

- **Look offset:** look-at is not the clicked pixel. The retry click gave the identical look-at every time, so the
  offset is systematic. Over the first four targets, look-at minus target = (-1.62, -2.50), (-0.69, -4.80),
  (+0.91, -3.27), (+0.13, -4.21). The mean is **(-0.32, -3.69) px**, sd 0.94 / 0.88 px, and it lies almost entirely
  along screen-up. The ±1 px spread is plausibly terrain height. I stored it as `look_offset_px` in
  `scripts/mapview/cal/ingame_2880x1800.json`, and the note there says how it was measured. With it, every target
  verified on the first click, including the two targets that were not used to measure it (1.82 and 2.10 px).
- **Park spot:** the camera's default is the ring's outer band at 315 degrees, (2803, 1693). No tooltip appeared
  on any of the 7 photos, so no `match.park_mouse` is needed.
- **Quit:**
  - cog (2779, 57);
  - Quit (2626, 618), whose frame rows are 588-644, with Resign above at y 540-558;
  - Yes (1140, 1008). The first Yes click was eaten; the second one returned to the home menu.

  The aitest cog (2827, 48) is at the right edge of the button.

## Bugs: one hypothesis, one reproducing test, one edit each

1. **Stars not found at 2880.** Hypothesis: the template radii are fixed at 6-11 px, but the stars here fit R 11.9.
   A quick rescore with scaled radii gave 0.94-0.995, and the next-best core scored 0.53.
   - Test: `TestStarsAt2880`. It uses the four live star patches as JSON numbers
     (`fixtures/editor_2880_stars.json`) plus a synthetic R 14 star.
   - Edit: `minimap_detect.star_radii(r)` scales the radii by r / 147 above a 147 px rim. At 2560x1080 the radii
     are unchanged, and a test pins that.
2. **The twin read 6/35.** Hypothesis: `census_reader.vanilla_source()` fell back to the repo snapshot
   `scripts/source/protoy.xml` (2456 units against the build's 2673). This device had never run `mapcheck --live`,
   so every mod index was 217 places off. The old warning blamed protomods.
   - Test: `test_vanilla_source_builds_the_live_cache_before_the_snapshot` and `test_names_from_the_snapshot_say_so`.
   - Edit: `vanilla_source()` builds the live cache through `catalogs._live_proto_path(force=True)`, the same code
     `mapcheck --live` uses, before it settles for the snapshot. A name table built from the snapshot now warns.
3. **Harbour north 1: 1 missing member + 1 extra unit.** The grouping lay exactly at (40.0, 378.0): every member's
   census offset equals its XML offset to 4 decimals. Two platforms are 0.54 m apart, and pairing one unit with its
   twin's offset seeded the anchor (39.53, 378.27). With the 1 m member tolerance that anchor also drew 20/20 votes,
   and the tie-break "nearest to the asked spot" chose it by 0.02 m.
   - Test: `test_a_vote_tie_goes_to_the_exact_anchor`, with the harbour's members from the XML. It reproduced
     (39.5256, 378.2693) exactly.
   - Edit: `twin._vote` breaks a tie by the members' summed residual first, then by the distance to the asked spot.
4. **The menu recogniser at 2880.** `screens.is_main_menu` scaled the 2560 column (x 500 instead of 186) and needed
   2-row frame lines.
   - Test: the `test_menu_2880_*` tests, on the live column stored as JSON numbers.
   - Edit: the geometry is read from the sheet's `menu._layout` (x, scan_y, line_rows_min, dark_gap, dark_max). At
     2560 the old rule is unchanged.
   - `is_editor` likewise reads `editor.menubar` / `editor.player_box` from the sheet. It had passed here only
     because the scaled points happened to land on the bar and the box.
5. **80 offline tests failed on this device.** They open PNG crops that `.gitignore` keeps out of the repo, so the
   crops exist only on the main device. AGENTS.md rule 8 says such tests skip when the capture is absent. Edit: the
   six crop loaders now skip. My own new fixtures are numbers (JSON), not images.

## Offline tests

`python -m pytest scripts/mapsim/tests scripts/mapview/tests scripts/gameio/tests sandbox/census/tests -q`:
- before this session, on this device: **80 failed**, 523 passed, 15 skipped. Every failure was a missing PNG
  crop.
- after: **534 passed, 94 skipped, 0 failed** (4 min 10 s). The 14 more skips than before are the PNG-crop tests.
- with `-m "not local"`: **529 passed, 80 skipped, 19 deselected, 0 failed**.

## Left on this device (outside the repository)

- `Game\RandMaps\00000_zplondon.xs` + `.xml` in the Steam install: the editor's London test copy. It must be copied
  again after every change to `randmaps/zplondon.xs`.
- `%LOCALAPPDATA%\aoe3-mapcheck\protoy_live.xml`: the live vanilla protoy, 2673 units.
- The save `Scenario/mapview_london4p_2880x1800.age3Yscn`.
- The game is running at the home menu. The skirmish lobby now holds London, 5 players.

## Decisions for the owner

1. **Edge band per screen.** The band is 0.5-2.5 px. In the editor at 2880 the insets read 2.3 px, near the ceiling;
   in a match they read 3.5 px and fail. Option A: scale the band with the rim (r / 130.5). Option B: measure a
   match band separately. Option C: leave in-match records unchecked. I did none of these. The in-match record is
   unchecked, with its evidence in its note.
2. **`rm-groupings-deploy` says the profile folder is the only deploy target.** On this device the London groupings
   are not in the profile folder, yet all 67 spawned. Should the skill say that the mod's `game/randmaps/groupings`
   is read?
3. **The root copy `00000_zplondon`:** keep it on this device, or remove it after the tests?
4. **The AI driver's second Play click** (`scripts/aitest/driver.py`, not mine to change): on this device a second
   click after a fast load hits the in-match flare button. Should the AI campaign probe the lobby before clicking
   again?
