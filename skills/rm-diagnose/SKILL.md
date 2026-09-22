---
name: rm-diagnose
description: The ordered checklist for "it does not work in game" on a random map or its data - which file the game actually loads, whether the compiled twin is fresh and its identifier text clean, whether a name exists in the CURRENT build, whether the process restarted, what the dump can and cannot prove - pinned BEFORE any theory. Use whenever a map feature silently does nothing, spawns the wrong thing, falls back to a default, or "worked yesterday". Triggers on "not working", "silently", "falls back", "nothing spawns", "still the old", "why does it", "blocked", "does not appear".
---

# rm-diagnose: pin the symptom, then walk the ladder

Get the exact symptom first, in the user's words, as one of: nothing spawns / wrong thing spawns /
fallback (default route, base unit, old name) / crash at generate / present but invisible / present
but wrong stats. Theories before that step cost hours (the 2026-09-10 trade-route hunt).

## The ladder (stop at the first rung that explains it)

0. **Did the generation HANG (load bar frozen at 20-30 %) after a game restart?** Before any map theory:
   `Startup\user.cfg` in the profile. A `debugRandomMaps` line there freezes EVERY random-map generation on
   the retail build at the first placement after the water (2026-09-18: six restarts and a full bisect of the
   London script and data cleared nothing; removing the line = the map generates unchanged). It takes effect
   only at the next process start, so the damage appears hours after the edit and passes every diff of the
   repo. Only `showAiEchoes` / `generateAIEchoesOutput` belong in that file. Then the other agents' data files:
   `ls -lt data/*.xml` - anything newer than the last good generation is a suspect the map diff never shows.
   The reproducible instrument is `sandbox/census/editor_regen.py <tag> <seed> [--in-editor|--from-menu]`:
   kill/relaunch through Steam (user's word only), recognise the menu and the editor by pixels, File > New,
   pick the map row, seed, Generate, load-bar readout every 10 s - one round ~4 min, no user time.
1. **Which file did the game load?** Every same-name copy: repo `game/randmaps`, Steam
   `Game\RandMaps`, `<profile>\RandMaps`, other enabled mod folders. `md5sum` them. A stale twin is
   picked silently. Only age-of-pirates enabled? `<profile>\mods\age3-mod-status.json`.
2. **Is the compiled twin fresh and clean?** Data lives in `.xml.xmb` at process start.
   `python scripts/tools/xmb_idcheck.py data/<file>.xml` reports STALE (twin older than XML) and
   WSTEXT (identifier text with baked-in newline: `'arctic1\r\n    '` never matches). Compare
   compiled `.text` RAW, never stripped. The XML-source rules (one-line identifiers, twins, CRLF)
   are the aoe-xml skill's `xmlcheck.py`; run both.
3. **Did the process restart after the data change?** `Get-Process AoE3DE_s | select StartTime`
   vs the .xmb mtimes. Map `.xs` reloads per generation; groupings index at start; data at start.
4. **Does the name exist in the CURRENT build?** `bartool cat data/protoy.xml | grep name="X"`
   (or `mapcheck --live`). The repo snapshot lags every DLC: absence there proves nothing.
5. **What does the dump prove?** `Age3DERM<map>.dmp.txt` is a compile dump: symbol count, function
   count, code bytes (max 65536), zero real errors = it compiled. It lists no placed units.
6. **Placement truth = census** (`rm-census`): parse the save; present / absent / count / position.
7. **Render truth = screenshot**: present in the census but invisible = LF-only art XML or a missing
   texture (`scripts/tools/check_art_eol.py`, `rm-unit-bench` pre-flight).
8. **Only now geometry**: constraints too hard (tiers, rm-objects-herds), area order (routes before
   cliffs they cross), smoothing apron (unmeasured; measure), world circle radius.

## Symptom -> first suspect

| Symptom | First rung | Evidence from this project |
|---|---|---|
| route falls back to the base (dirt) route, other routes fine | 2 | traderoutedefs records pasted multi-line |
| load bar frozen at 20-30 %, every seed, every variant | 0 | `debugRandomMaps` in user.cfg (2026-09-18) |
| grouping never spawns | 1 + 3 | grouping XML only in the repo; editor not restarted |
| unit spawns (census) but is invisible | 7 | LF-only animfile (Tower of London) |
| mapcheck S4 "unknown proto" on a DLC unit | 4 | snapshot from Oct 2025 |
| one of N InArea placements spawns | 8 | 15 m class constraint on glaciers overlapped by islands |
| upgrade tech does nothing to a mod unit | 2/4 + git history | the DLC merge replaced the mod tech and dropped the effects |
| "works in the editor, dead in Skirmish" | 1 | two maps with one display name |

## Rules

- One decisive test per theory, cheapest first; write the expected outcome before running it.
- Bars are the source for vanilla facts (`bar-extract`); never the exe.
- When a check reports "clean", ask whether it could have failed (a stripped compare cannot).
- Record a new rung when a hunt ends in a cause this ladder did not name.

Related: rm-census, rm-unit-bench, rm-trade-routes, rm-groupings-deploy, mod-deploy-check.
