---
name: rm-workflow
description: The random-map creation and change workflow for Age of Pirates - phases with an offline gate and (only where placement matters) an in-game gate, which rm-* skill covers each phase, the sync-by-copy rule, and what "verified" means (mapcheck --live, census, screenshot). Use when starting a new map, planning a map change, deciding what to test after an edit, or when asked "how do we build/test maps here". Triggers on "map workflow", "new random map", "how to test the map", "map phases", "what do I run after editing the map", "ship the map".
---

# rm-workflow: phases and gates

Every phase: edit the repo copy -> sync the Steam `Game\RandMaps` twin by copy -> run the gate ->
next phase. A phase whose gate is offline never needs the game. Ask before taking the screen.

The sync is automatic (2026-09-24): `python scripts/tools/sync_local_maps.py` keeps this device's local copies
(the ignored `config/local-maps.local.json`, e.g. `randmaps/zplondon` -> `00000_zplondon`) equal to the repo,
which is always the source of truth. The PostToolUse hook runs it after an agent edits a registered map, the
post-merge git hook (`--install-git-hook`, once per device) after every pull; `--add <repo stem> <local stem>`
registers a new copy, `--check` lists stale ones. **The map under test goes on row 2 of the editor's Type list, right
under Blank: `--top <repo stem>`** (one more leading zero than any map in the folder; `--add` and `--top` print the
row). A copy registered as `00000_<map>` sits among 50 others and every generation scrolls for it (owner 2026-10-07:
"20 USD only by wrong map name which sits too low"). A `.mods.xml` never goes into the game root (the mod loads its own
copy): `--check` flags one as FORBIDDEN and `--sync` deletes it. Do not spend time diagnosing one, delete it.

| # | Phase | Skill | Offline gate | In-game gate (only when placement matters) |
|---|---|---|---|---|
| 0 | Brief: intent, size, land/water, players, natives, routes | map-profile (`scripts/maps/<stem>.json`) | profile written | - |
| 1 | Skeleton: spine, .xml, names, file locations | rm-skeleton, rm-name-catalogs | `mapcheck --static-only --live` = 0 FAIL | one editor generation with the crash oracle |
| 2 | Terrain: areas, water, cliffs, mixes, overlays | rm-areas, rm-water-rivers, rm-coordinates | `mapcheck --live` (SIM) | minimap screenshot (map-minimap / rm-unit-bench runner) |
| 3 | Routes and sockets | rm-trade-routes | mapcheck route-type check | minimap |
| 4 | Players and starts | rm-players | mapcheck G-checks | - |
| 5 | Objects: resources, herds, holes, nuggets | rm-objects-herds, rm-resource-balance (counts per side / player) | mapcheck | census of a saved generation (rm-census; `resource_count.py census` for parity) |
| 6 | Groupings and natives | rm-groupings-deploy, native-politician, extended-native | unit-count diff across the three copies; trigger tests | census after a game restart |
| 7 | Triggers | rm-triggers (hub), then map-politician-triggers, nugget-targeting | offline trigger tests (`scripts/mapcheck/tests` harness pattern) | one play test |
| 8 | Ship | mod-deploy-check | zip audit, `xmb_idcheck`, `check_art_eol` | - |

"It does not work" at any phase -> rm-diagnose before any theory. New art on the map -> rm-unit-bench
before the map.

## Known patterns: copy, don't derive

Owner 2026-10-08: "It's a known pattern from other maps - needs to be tracked". Before building any of these, open
the tracked recipe and the maps that use it:

| Pattern | Where it is tracked |
|---|---|
| Harbours on a coast or river: the port site + harbour grouping (18 maps) | rm-trade-routes, "Harbour port sites" |
| Player forts / castles as a start grouping (Malta, Danube): flat site beneath, all forts before any herd, starting units inside as on Malta, no flattener | rm-players |
| Settlement groupings with / without the area flattener (`_noflatten` copies, map-edge rule) | rm-groupings-deploy, "Flatten / unflatten standard" |
| Two teams of any split with a gap and a neutral settlement in it; FFA half-moon | rm-players |
| Prince Elector build-limit ladder (toggle per threshold) | rm-triggers |
| Premium terrain patches (tiny, incoherent, two mixes per region) | rm-areas |
| Bridges with cliff docks across a river (Elbe, Florence, Danube) | rm-water-rivers |
| The map under test on row 2 of the editor list (`--top`) | rm-workflow (above) |
| The lobby minimap images (`<map>_mini.png` NEW / `_mini2.png`; gold border = normal maps, silver = historical) | lobby-minimap |
| Optional premium-look touches: trees on plateaus, docks level with the bridge, more vegetation | rm-eye-candy |

A new pattern found in the mod's maps goes into this table and its skill the moment it is used a second time.

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

## Change batches: plan, then regenerate - never patch a moving list

When the owner's feedback arrives as a batch, or keeps arriving while you work, and any request moves terrain
structure (river or channel shape, routes, bridges, shores, the player layout, the map's type or folder), STOP
patching:
1. Collect every request into one numbered list in the owner's words, the open ones from earlier rounds included.
2. Write ONE plan that rebuilds the terrain section as a whole from that list: build order, what each request becomes,
   what is NOT in this round and why.
3. Get the go. Then build the whole section fresh and check it with an editor generation and `save_diff.py`.

Danube 2026-10-06: eight rounds (v2-v8b) each patched the last one while new requests kept coming. Several of them
(a normal map, a route floor, wider water, a fifth socket, patches, forests) went into one untested round. The game
left 15% of the map as water where mapsim showed land (save "Danube - total fsailure"). Owner: "I gave you a lot of
change requests which rather required proper planning and basically complete terrain regeneration rather than
patching."

**Say first what is NOT done.** A request that is deferred, planned or refused is named in the first lines of the
reply, never only in a plan at the end of it. Owner, same day: "silently skipped the trade route requirement".

## Editing rules that apply to every phase

- Data and map files are CRLF; edit with `scripts/tools/patchfile.py` (anchored, count-asserted)
  or Python on bytes. Never `sed -i`, never a shell heredoc carrying backslashes.
- Copy references verbatim (a vanilla map, a mod idiom, a proto record); change only what the
  instruction names. Read values from data, never guess names, ids, offsets.
- New records go at the end of real content, above the file's TEST section, ids continuing the real
  sequence (new-content-placement memory).
- One decisive test per open question; state the expected outcome before running it.
- The RM dump proves compilation only; the census proves placement; the screenshot proves rendering.
- **Every forest AREA carries `avoidAll`** (`int avoidAll = rmCreateTypeDistanceConstraint("avoid all", "all", 6.0);`
  then `rmAddAreaConstraint(forest, avoidAll);` - `zpcrownlands.xs:958`, `zpkingofbohemia.xs:979`,
  `zpflorence.xs:1571`). A forest area (`rmSetAreaForestType`) built without it AFTER objects were placed
  silently DELETES every mine, herd and bush it grows over - no error, and counts come out short and uneven
  between sides. London 2026-09-27: countryside tin 1v1 0 of 4. Removing every resource constraint changed
  nothing; turning the forests off gave 2 mines per bank at once; `avoidAll` on the forests is the fix. This is a
  frequent and very expensive bug. When resources are missing or uneven, check the forests FIRST:
  `grep -n "rmSetAreaForestType" <map>.xs` and confirm each forest area has `avoidAll` or is built before the
  objects. Copying a forest block means copying its `avoidAll` line too.
- **Triggers and map setup:** start every trigger or starting-tech change at `rm-triggers` (the hub: laws, the
  setup-tech convention, routing to the specialised trigger skills).
- **Map-edge constraints (mapcheck S7 FAILs without them):** every scattered object (mines, herds, berries, fish,
  treasures) carries them. A square map needs one circle, never a box alone (the corners stay open); a rectangular
  map needs a box AND a circle sized from the corner. Treasures sit 20 m inside the edge, with `avoidAll` and 12 m
  off coin. The recipe is in `rm-objects-herds`, "Map-edge constraints"; the Danube copied King of Bohemia's box
  on a square map and its treasures left the circle (2026-10-06).

## What "verified" means in a report

"mapcheck 0 FAIL (--live)" is static. "census P2 seed 4242: 6/6 holes" is placement. "screenshot
bench_..._generated.png: renders" is visual. Say which of the three a claim rests on; never write
"works" for a change that only passed mapcheck.

**Terrain changes: the save diff is the gate, not the eye and not mapsim.** Save the first editor generation and run
`python scripts/mapsim/save_diff.py "<profile>/Scenario/<save>.age3Yscn" <map>.xs --players N --out diff.png`
(exit 0 = the game built the water mapsim predicts, within 3% of the map). mapsim's area growth is a model: large
land areas held by several constraints can stop short in the engine while mapsim fills them (Danube v8b: 15.3% of
the map water only in the game, 2026-10-06).
