# RM skill library plan (draft 2026-09-17)

Purpose: turn the random-map guidelines into a set of small, testable skills, define the map
creation workflow with gates, and add a safe single-unit visual test bench. Plan only; nothing
here is implemented yet.

## 1. What the guidelines are today

| Document | Lines | Role |
|---|---|---|
| random_map_generation_guide_v2.md | 12,030 | everything: tutorial, API reference, conventions, machine config, troubleshooting |
| visual_interpretation_library.md | 3,696 | reading minimaps and screenshots |
| data_xml_guide.md | 2,384 | data XML (protomods, techtreemods, mergemode) |
| map_trigger_guide.md | 1,278 | RM trigger families |
| plan_mapsim_architecture.md | 1,021 | the offline simulator |
| rm_commands_reference.md | 886 | the RM API (from all_rm_commands.txt) |

The guide's weight sits in chapters 13 to 19 (Map Properties 1,690 lines, Areas 2,608, Trade
Routes 1,259, Rivers 665, Players 881, Objects 599, Groupings 823 = 8,525 lines, 71 %).

Findings, all from this session's evidence:

1. **The guide is never actually loaded.** At 12k lines it cannot be read per task; the rules
   that decided every fix this session came from memory files (xs-grid-placement-rules,
   mapsim-engine-rules, grouping-deploy-gap) and from grepping vanilla scripts. The hard-won
   engine rules live outside the guide, so the guide is not the source of truth in practice.
2. **Stale procedure.** Chapter 11 "How to test" still describes the legacy Age3.exe
   `+debugRandomMaps` shortcut and `My Documents\My Games\RM`. On DE the editor reads loose
   files from the Steam `Game\RandMaps` folder and Skirmish reads the mod folder; the twins must
   be kept byte-identical by copy (Cold War: zpcoldwar.xs vs zp_coldwar.xs).
3. **Mixed genres.** Reference (API), tutorial, project conventions (ids, prefixes), machine
   config (chapter 8 "Local Machine Configuration") and troubleshooting are interleaved, and
   chapter 25 is "Unorganized". A skill needs one genre: a rule set with a verify step.
4. **Rules discovered this session that no document holds:**
   - identifier element text in data XML must be ONE line (XMB keeps whitespace; multi-line
     route records compiled to `arctic1\r\n    ` and silently fell back to the base route);
   - the compiled twin must be compared RAW, never `.strip()`ed;
   - route type = the traderoutedefs record name; nautical vs land; upgrade chains in
     traderoutes.xml; "falls back to dirt while every other route works" = name lookup failed;
   - paint-only overlay clipped to an existing area by `rmAddAreaConstraint(overlay,
     rmCreateAreaConstraint(area))` with an over-ask (vanilla Arctic Territories `NewPatch`);
   - tiered placement fallback with `rmGetNumberUnitsPlaced` (documented retry idiom);
   - fixed placement from a measured vector: `rmGetUnitPosition` + `rmXMetersToFraction`,
     negative offsets as `base - rmXTilesToFraction(n)`;
   - the smoothing apron (waterline vs area edge) is unmeasured; do not assume it;
   - groupings have three copies (repo canonical, Steam Game folder, profile); the editor
     indexes them at process start only;
   - the mapcheck name catalog is the Oct 2025 snapshot: every Baltic proto (Walrus,
     deFishingHole, deSocketInuit) is a false S4 FAIL; there is no route-type check at all.
5. **Tooling friction cost real time:** the Bash tool collapses doubled backslashes (three
   failed patch runs, one silently wrong regex); `sed -i` strips CR; `sed` with computed
   negative ranges; Python needs `C:/` paths not `/c/`. Every patch this session was an ad-hoc
   Python script with the same read-CRLF / assert-anchor / write-CRLF shape, written eight
   times.
6. **The map-minimap skill cannot run here.** It calls `C:\Users\rosti\aop_harness\aitest\
   load_map.py`; this machine has `scripts/aitest/` (driver.py, probe.py, calibrate.py,
   crashdump_triage.py) but no load_map.py, gamectl.py or pw.py.

## 2. Where this conversation got stuck (trace)

| # | Task | Where it stuck | Root cause | Lesson for the library |
|---|---|---|---|---|
| 1 | Walrus herds "next to the water" | whether the waterline lies inside the glacier area | smoothing apron never measured; mapsim does not model it | measure once with a census, record in mapsim or the area skill |
| 2 | Cliff-landing DLC change | scanning the exe until you stopped it | wrong source; the exe is encrypted and the bars hold the data | bars first, exe never (now a rule) |
| 3 | Arctic trade route "blocked" (hours) | name verified everywhere, DLC-gating theory, clone detour | compiled route name carried `\r\n    `; my `.strip()` compare hid it; the symptom ("falls back to base TR") was named late | get the exact symptom first; raw compare of compiled twins; one-line identifier records; a symptom-to-cause table |
| 4 | Every data patch | three parse failures before the first write | Bash backslash collapsing | scripts via the Write tool; a shared patch helper |
| 5 | Inuit groupings | two sets with different names in Game folder vs repo | editor saves went to another name | deploy flow one-way repo -> Game + profile; diff unit counts first |
| 6 | Fishing holes | constraint version spawned one of six; shell pipelines broke twice | 15 m class distance on glaciers overlapped by islands; sed/grep fragility | fixed positions from measured vectors; Python for text work |
| 7 | Harpooner upgrades | effects silently gone | the Aug 7 DLC merge replaced mod techs and dropped the mod's per-unit effects | vanilla-merge must also diff mod effects lost when a vanilla tech replaces a mod tech |
| 8 | mapcheck | S4 FAIL on every DLC proto | stale snapshot; no live-name mode | snapshot refresh routine or a `--live-names` mode reading the bars |
| 9 | Minimap validation | not available on this device | harness lives on the other machine | port load_map/gamectl/pw into scripts/aitest or mark the skill device-bound |

Pattern behind 1, 3 and 6: a theory was built before the symptom was pinned. The library's
first skill must therefore be the diagnosis checklist, not another recipe.

## 3. Proposed skill library (map-related)

Design rules for every skill: one job; under ~150 lines; every rule stated as a testable fact
with its evidence (map, line, or data record); a "verify" step, offline where possible; links
to a script in `scripts/` rather than prose procedures; no machine paths inside (those go to a
gitignored local config, as `whichsheet.json` already does).

Existing skills that stay as they are: bar-extract, mapcheck, map-profile,
map-politician-triggers, nugget-targeting, grouping-terrain, grouping-model-swap, extended-native,
native-politician, vanilla-merge, mod-deploy-check, game-startup, ui-calibrate.

New or reworked:

| Skill | Job | Source material | Verify step |
|---|---|---|---|
| `rm-workflow` | the umbrella: phases, gates, which skill when | section 4 below | none (routing) |
| `rm-diagnose` | "it does not work": ordered checklist before any theory | section 2, xmb-text-whitespace-trap, grouping-deploy-gap | scripts: twin checksums, compiled-twin raw text, live-name lookup, process start time vs xmb mtimes |
| `rm-skeleton` | mandatory spine + frozen templates (land, islands, unit bench), .xml metadata, file locations, sync-by-copy, CRLF | guide ch 9-11, 000_hkt_test.xs spine comment, 000zpTestMap.xs | mapcheck static + editor generation with the crash oracle |
| `rm-coordinates` | 45 degree rotation, fractions/metres/tiles, world-circle radius, measured vectors, negative offsets | guide ch 3 + xs-grid-placement-rules | unit test on the conversion helpers |
| `rm-areas` | area shape rules, paint overlay, cliffs (height, ramps, blockLand), smoothing apron unknown, elevation stamping | guide ch 14 + mapsim-engine-rules | mapcheck SIM + minimap |
| `rm-water-rivers` | sea level, water bodies chain, bank/beach formula, river rules | guide ch 13/16 + mapsim-engine-rules | mapcheck |
| `rm-trade-routes` | route type = record name, land vs nautical, upgrade chains, one-line records, build order vs cliffs, sockets at waypoints | guide ch 15 + this session | new mapcheck route-type check + compiled-twin check |
| `rm-objects-herds` | object defs, herds, InArea vs AtLoc, min/max semantics, tiered fallback, fixed placement from vectors | guide ch 18 + Cold War walrus/fishing-hole code | census of a saved generation |
| `rm-players` | circular/line placement, sections, ring angle convention, TC and start units | guide ch 17 + mapsim-engine-rules | mapcheck G-checks |
| `rm-groupings-deploy` | three copies, deploy flow, restart to index, tilegroup terrain, flattener line, variation index | guide ch 19 + grouping memories | unit-count diff across copies + census |
| `rm-name-catalogs` | finding proto / terrain / mix / water / cliff / route names in the bars, snapshot staleness and refresh | guide ch 6/12 + bar-extract | `bartool cat` lookups |
| `rm-unit-bench` | the safe single-unit visual test (section 5) | 000_hkt_test.xs, scripts/havok/run_gen.py | control unit passes, then the test proto; crash triage attributes |
| `rm-minimap-check` | rework of map-minimap: harness in-repo, device config gitignored | map-minimap + scripts/aitest | screenshot files exist, crash oracle |

The guide itself becomes the long-form reference with a header that routes to the skills;
chapters 7 and 8 (localization, local machine) move out to project docs / local config; the
TOC duplicate (14/15 listed at the top) and chapter 25 go.

## 4. RM creation workflow (gates)

Every phase: edit the repo copy, sync the Game-root twin by copy, run the gate, only then the
next phase. A phase with no in-game gate never needs the game.

| Phase | Work | Gate (offline) | Gate (in game, only when placement matters) |
|---|---|---|---|
| 0 Brief | intent, size, land/water, players, natives, routes | written into the map profile (scripts/maps/<stem>.json) | none |
| 1 Skeleton | template from rm-skeleton, .xml, names | mapcheck static, live-name lookup | editor generation + crash oracle + minimap |
| 2 Terrain | areas, water, cliffs, mixes, overlays | mapcheck SIM | minimap |
| 3 Routes and sockets | routes before cliffs they cross, sockets at waypoints | mapcheck + route-type check | minimap |
| 4 Players | placement, TCs, start units | mapcheck G-checks | none |
| 5 Objects | resources, herds, holes, nuggets | mapcheck | census of a saved generation (counts per type) |
| 6 Groupings and natives | deploy, sockets, politicians | unit-count diff across copies, trigger tests | census after restart |
| 7 Triggers | trigger families | offline trigger tests (existing harness pattern) | one play test |
| 8 Ship | zip audit | mod-deploy-check | none |

## 5. The unit visual test bench (why it crashed, and the safe design)

Evidence of the past crashes:

- `scripts/maps/000_hkt_test.xs` (commit 7130e597, 2026-09-13) records that generation
  aborted (crash +0xA7508D) until the three includes and `chooseMercs()` were present: a
  Saloon's train list is built from the mercenary set at world creation.
- The map-minimap skill records the second crash class: a truncated script that dropped
  `rmSetMapSize`, `rmTerrainInitialize` or the player placement dies at 0xC0000005 +0x7E9D2D.
- A third class is not a script problem at all: a new proto whose animfile, material or
  texture path does not resolve. That crash looks identical from the outside, which is why
  "single unit" benches kept failing without a diagnosis.

Design, `rm-unit-bench`:

1. **A frozen spine template**, never edited by hand: the 000_hkt_test spine (three includes,
   `chooseMercs()`, map size 200, sea level, lighting, base mix, `rmTerrainInitialize`,
   two map types, world circle, `rmPlacePlayersCircular(0.12, 0.12, 0)`, one TownCenter per
   player) plus exactly two placements: a **vanilla control unit** (House) 14 m east of player
   1 and the **unit under test** 14 m west. Both at min/max distance 0.
2. **A generator**, `scripts/tools/unitbench.py --proto <name> [--control House]`, that only
   substitutes the proto names into the template, writes `000_unitbench.xs/.xml` into the
   Steam `Game\RandMaps` folder (editor reads it on every File > New) and refuses to run if the
   spine lines are missing from its own output (self-check).
3. **Pre-flight, offline, before the game is touched:**
   - proto exists in the live bars or in protomods (bartool cat, not the snapshot);
   - its animfile resolves, and every model/material/texture the animfile names exists in the
     mod or the archives (this is the check that was missing);
   - mapcheck static on the generated script.
4. **Run:** generate in the Scenario Editor (never Skirmish), first with `--proto House`
   (control only). If that crashes, the rig or the spine is broken, not the unit. Then the real
   proto. Crash oracle = process death plus a new minidump; `crashdump_triage.py` names
   module + offset for the log.
5. **Capture:** one screenshot of the editor view on the two units, saved with the proto name
   and build number under `scripts/aitest/runs/unitbench/`.
6. **Log line per run:** proto, control ok, proto ok, dump path or "none", screenshot path.

The bench needs the editor driver on this device: port `load_map.py`, `gamectl.py`, `pw.py`
from the other machine into `scripts/aitest/` behind the existing coordinate sheets, or keep the
bench editor-manual (generator + pre-flight + triage, human clicks Generate). The manual variant
already removes the two crash classes that were actually hit.

## 6. Tests

Offline (fast, run on every change):

- mapcheck static + SIM (existing), plus two new universal checks: route type name exists in
  `data/traderoutedefs.xml`; compiled twin identifier text has no whitespace (traderoutedefs,
  traderoutes from/to, any element whose text is a name).
- name catalog: `--live-names` mode that reads protoy/terraintypes/mixes/water bodies from the
  bars via bartool, or a documented snapshot refresh step in vanilla-merge; either removes the
  S4 false positives.
- template tests (pytest, existing pattern in scripts/mapcheck/tests): the skeleton templates
  and the unit-bench generator output always contain the spine lines; a stripped copy fails.
- patch helper tests: `scripts/tools/patchfile.py` (anchored, CRLF-preserving, count-asserting
  replacements) used by every future data/map edit instead of ad-hoc scripts.
- vanilla-merge extension: report mod per-unit effects lost when a vanilla tech record replaces
  a mod tech (the Harpooner case).

In game (costly, gated, logged):

- editor generation with the crash oracle and a minimap shot (rm-minimap-check);
- census of a saved generation for placement phases (counts per proto, positions);
- the unit bench control-then-proto run.

## 7. Implementation order (proposal)

1. **Tooling (one session):** patchfile helper; mapcheck route-type and compiled-twin checks;
   `--live-names`; `rm-diagnose` skill from section 2.
2. **Skeleton and bench:** templates, generator, pre-flight, `rm-skeleton` and
   `rm-unit-bench` skills; validate on the game with the control unit, then with the Sep 13 test
   cube (already installed as `zpTestCube` art) or a real mod unit.
3. **Split the guide:** the rm-* skills from chapters 3, 13-19 plus the memories, each with its
   verify step; the guide gets the routing header; chapters 7, 8, 25 move out.
4. **Workflow and cleanup:** `rm-workflow`, fix chapter 11's test procedure, port or scope the
   minimap harness.

## 8. Decisions needed before implementation

1. Test rig: is this device the primary one now (port the editor driver here), or does the
   bench stay editor-manual on this machine?
2. Guide: keep it as a long-form reference behind the skills, or dissolve it entirely?
3. Bench target for the first validation: the Sep 13 test cube, or a real mod unit?
4. Names for the new skills: the `rm-` prefix as above, or extend the existing `map-` family?
