---
name: rm-unit-bench
description: Visual test of ONE unit (a new building, ship, prop, native unit) on the most basic map that cannot crash - frozen spine template, offline pre-flight of the proto's animfile/model/material/textures/CRLF, a vanilla control unit beside the subject, editor generation with the crash oracle, then census = spawned, screenshot = renders. Use when a new model must be seen in game, when "the unit does not appear", when a minimal test map crashed before, or before any play test of new art. Triggers on "unit bench", "test the model in game", "single unit map", "does it render", "minimal map with one unit", "visual test".
---

# rm-unit-bench: see one unit in game without a crash

Two tools, one order. Nothing here launches or kills the game.

```bash
# 1. generate + pre-flight (offline). Writes <stem>.xs/.xml into the Steam Game\RandMaps folder
python scripts/tools/unitbench.py --proto zpSPCLondonBasilica --json bench.json
# 2. drive the OPEN Scenario Editor: generate, screenshot, save, census, verdict
python sandbox/census/bench_run.py --peek                       # once: where is the bench in the Type list?
python sandbox/census/bench_run.py --proto zpSPCLondonBasilica --nav <down>,<row> --players 2 --json verdict.json
```

## Why minimal maps crashed before (all three are handled)

| Crash | Cause | Evidence |
|---|---|---|
| 0xC0000005 +0x7E9D2D at generate | a stripped spine: no `rmSetMapSize`, `rmTerrainInitialize` or player placement | map-minimap skill |
| +0xA7508D at generate | no `chooseMercs()` / includes: a Saloon's train list is built from the mercenary set at world creation | scripts/maps/000_hkt_test.xs (7130e597) |
| looks like the same crash, or "nothing appears" | the proto's animfile, GR2, material or DDT does not resolve, or an art XML is LF-only (engine ignores it, model never renders) | art-xml-must-be-crlf memory, Tower of London 2026-09-17 |

The generator refuses to write when any spine line is missing from its own output (P7), and the
pre-flight (P1-P6) runs before the game is touched. A vanilla control unit (House) stands 24 m east of
player 1's Town Center, the subject 24 m west: a crash with the subject but not with the control is
the subject's data, not the rig.

## Pre-flight codes (unitbench.py)

P1 proto in protomods or the LIVE Data.bar protoy (never the repo snapshot) · P2 animfile in mod art/ or
the archives · P3 every `<file>` -> .gr2 (+ .material; `.pkfx` particles skipped) · P4 material
`override` textures and animfile `<texture>` -> .ddt · P5 mod-local animfile/material are CRLF ·
P6 `mapcheck --static-only` on the generated script (a stale-snapshot S4 for a proto verified in P1 is
a NOTE) · P7 spine self-check. FAIL = nothing written (`--force` overrides). Knobs: `--control`,
`--dist` (raise it for big obstructions; the tool warns), `--owner 0` for Gaia, `--stem` for a second
bench side by side, `--out` for a folder other than the Steam one.

## Success criteria (bench_run.py, see rm-census for the general rule)

| Verdict | Meaning | Next |
|---|---|---|
| CRASH | process died during generation; minidump named and triaged | subject data/art; rerun with `--proto House` to prove the rig |
| NO_SAVE | Save As did not produce the file | read `<tag>_after_save.png`; dialog state, not the unit |
| FAIL_SPINE | control missing from the census | the bench itself; do not blame the unit |
| FAIL_SUBJECT | control present, subject absent | placement (obstruction, distance) or the proto |
| PASS | both exactly once, TC count = players, positions printed | open `<tag>_generated.png`: renders / wrong / invisible |

Census = SPAWN truth. Screenshot = RENDER truth. A unit in the census but not on the screenshot is the
LF-only / missing-texture class, never a placement problem. The verdict is by proto NAME (the
census resolver names mod protos since 2026-09-17); geometry is used only when the save's positions
are sane, which the 2026-09-17 saves were not.

## Verified runs (2026-09-17, build 25040513, editor, 2 players, seed 4242)

| Bench | Subject | Verdict | Screenshot |
|---|---|---|---|
| 000_unitbench | zpSPCLondonBasilica (St Paul's), owner 1 | PASS: basilica 1, House 1, TC 2 | dome, colonnades, towers render |
| 000_unitbench_ctl | House as subject | PASS: House 2, TC 2 | rig proven |
| 000_unitbench_unit | zpNatInuitHarpooner, owner 1 | PASS: harpooner 1, House 1, TC 2 | small figure renders |
| 000_unitbench_gaia | basilica, `--owner 0` | FAIL_SPINE: neither House nor basilica placed | only the two TCs |

Rule from the last row: `--owner 0` places NO civ building on this bench (census and screenshot
agree); bench buildings with owner 1. Gaia is fine for units the maps already place for player 0
(nuggets, herds, props, fishing holes).

## Rules

- Never edit the template by hand; change the generator. Never put the bench in the mod folder
  (the editor reads the Steam folder; Skirmish is not needed for a visual test).
- Run the control-only bench first on a machine or build you have not benched before.
- The runner takes the screen for about a minute: ask before running it while the user works.
- `--nav` changes whenever a map is added to the Steam folder (the list is sorted, `_` after
  letters): `--peek`, read the screenshot, count. Never guess a row.
- Outputs live under `sandbox/census/samples/bench/` (screenshots, save copy, verdict JSON).

Related: rm-skeleton (the spine), rm-census (criteria), rm-diagnose (when it still does not show),
map-minimap (the older, other-device harness), aoe-building-pipeline (how the art got there).
