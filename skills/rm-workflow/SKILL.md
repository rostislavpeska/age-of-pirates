---
name: rm-workflow
description: The random-map creation and change workflow for Age of Pirates - phases with an offline gate and (only where placement matters) an in-game gate, which rm-* skill covers each phase, the sync-by-copy rule, and what "verified" means (mapcheck --live, census, screenshot). Use when starting a new map, planning a map change, deciding what to test after an edit, or when asked "how do we build/test maps here". Triggers on "map workflow", "new random map", "how to test the map", "map phases", "what do I run after editing the map", "ship the map".
---

# rm-workflow: phases and gates

Every phase: edit the repo copy -> sync the Steam `Game\RandMaps` twin by copy -> run the gate ->
next phase. A phase whose gate is offline never needs the game. Ask before taking the screen.

| # | Phase | Skill | Offline gate | In-game gate (only when placement matters) |
|---|---|---|---|---|
| 0 | Brief: intent, size, land/water, players, natives, routes | map-profile (`scripts/maps/<stem>.json`) | profile written | - |
| 1 | Skeleton: spine, .xml, names, file locations | rm-skeleton, rm-name-catalogs | `mapcheck --static-only --live` = 0 FAIL | one editor generation with the crash oracle |
| 2 | Terrain: areas, water, cliffs, mixes, overlays | rm-areas, rm-water-rivers, rm-coordinates | `mapcheck --live` (SIM) | minimap screenshot (map-minimap / rm-unit-bench runner) |
| 3 | Routes and sockets | rm-trade-routes | mapcheck route-type check | minimap |
| 4 | Players and starts | rm-players | mapcheck G-checks | - |
| 5 | Objects: resources, herds, holes, nuggets | rm-objects-herds | mapcheck | census of a saved generation (rm-census) |
| 6 | Groupings and natives | rm-groupings-deploy, native-politician, extended-native | unit-count diff across the three copies; trigger tests | census after a game restart |
| 7 | Triggers | map-politician-triggers, nugget-targeting | offline trigger tests (`scripts/mapcheck/tests` harness pattern) | one play test |
| 8 | Ship | mod-deploy-check | zip audit, `xmb_idcheck`, `check_art_eol` | - |

"It does not work" at any phase -> rm-diagnose before any theory. New art on the map -> rm-unit-bench
before the map.

## Commands per gate

```bash
python -m scripts.mapcheck <stem-or-path> --static-only --live     # names against the CURRENT build
python -m scripts.mapcheck <stem-or-path> --live [--matrix]        # + simulator (areas, ring, routes)
python scripts/tools/xmb_idcheck.py                                # compiled data twins: stale / whitespace names
python scripts/tools/check_art_eol.py                              # LF-only art XML = invisible models
python sandbox/census/census.py <save.age3Yscn>                    # spawn truth
python sandbox/census/bench_run.py --proto <unit> --nav d,r        # one unit, one map, verdict
python sandbox/census/census_run.py <recipe> --seeds 3             # generate -> save -> census -> judge
```

## Editing rules that apply to every phase

- Data and map files are CRLF; edit with `scripts/tools/patchfile.py` (anchored, count-asserted)
  or Python on bytes. Never `sed -i`, never a shell heredoc carrying backslashes.
- Copy references verbatim (a vanilla map, a mod idiom, a proto record); change only what the
  instruction names. Read values from data, never guess names, ids, offsets.
- New records go at the end of real content, above the file's TEST section, ids continuing the real
  sequence (new-content-placement memory).
- One decisive test per open question; state the expected outcome before running it.
- The RM dump proves compilation only; the census proves placement; the screenshot proves rendering.

## What "verified" means in a report

"mapcheck 0 FAIL (--live)" is static. "census P2 seed 4242: 6/6 holes" is placement. "screenshot
bench_..._generated.png: renders" is visual. Say which of the three a claim rests on; never write
"works" for a change that only passed mapcheck.
