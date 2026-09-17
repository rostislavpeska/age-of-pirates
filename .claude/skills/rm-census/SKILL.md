---
name: rm-census
description: Ground truth for "did it spawn" on a random map - parse a saved generation (.age3Yscn) into proto names and positions, judge spawn / not spawn / short spawn with explicit criteria, and pair it with a screenshot for render truth. Use for any placement question (groupings, herds, sockets, fixed positions, nuggets), after any change to object placement, and whenever a dump or the script alone is being used as evidence. Triggers on "census", "did it spawn", "how many spawned", "count the units", "spawn criteria", "verify the placement", "not spawning".
---

# rm-census: spawn is a census fact, not a script fact

The RM dump (`<profile>\RandMaps\Age3DERM<map>.dmp.txt`) is a CXSDump of the compiled SCRIPT: symbols,
functions, code size. It contains no placed units. The only offline ground truth for placement is a
saved generation parsed by `sandbox/census/census.py`.

```bash
python sandbox/census/census.py "<profile>\Scenario\<save>.age3Yscn"          # per-proto counts
python sandbox/census/census.py <save> --full                                   # every unit with x/y/z
python sandbox/census/census_run.py <recipe> --seeds 3                          # editor loop: generate -> save -> census -> judge
python sandbox/census/census_judge.py <deployed.xs> <save1> <save2> --players 4 --teams 2
python sandbox/census/bench_run.py ...                                          # the unit bench (rm-unit-bench)
```

**Proto names (verified 2026-09-17, build 25040513):** the save stores the engine's runtime proto
INDEX, not the XML id. `census.py` resolves it as vanilla file position in the CURRENT protoy (the
`mapcheck --live` cache; the snapshot only as fallback) followed by every protomods record whose
name is not vanilla, in file order (`name ="x"` with a space counts too). Two observations pinned it
exactly: zpNatInuitHarpooner 2820 = 2673 + 147, zpSPCLondonBasilica 3631 = 2673 + 958. The old
by-id lookup mis-names everything after vanilla position ~1463 and every mod unit; an
`unknown(NNNN)` now means the live cache is missing (run `mapcheck --live` once). If a known mod
unit resolves to a neighbour's name, the vanilla count changed (new patch): re-run `--live`.

**Positions:** `census.py` reads x/y/z at a heuristic offset; in the 2026-09-17 bench saves they
were garbage (1e+22) while the Istanbul saves of August read fine. Check sanity (|coord| < map
size) before using them; `bench_run.py` judges by names when they are not sane.

## Criteria (state them BEFORE the generation, then read the census against them)

| Question | Criterion | Verdict when it fails |
|---|---|---|
| Fixed placement (AtLoc / AtPoint, max distance 0) | exactly 1 of the proto within 3 m of the authored point | NOT SPAWNED: point obstructed or off-map; check the anchor's own spawn first |
| InArea object, count N | count == N | SHORT: constraints too hard (see rm-objects-herds tiers) |
| Herd | herd anchor present, members within the cluster radius | SHORT: land/passability; do not blame the constraint before checking terrain |
| Grouping (native / structure) | its signature socket / flag unit present (census_judge fingerprints from the grouping XML) | native: not rolled at this player count is normal; structure: missing = deploy gap (rm-groupings-deploy) |
| Player start | TownCenter count == players | the spine or placement sections |
| Trade route | sockets (`SocketTradeRoute`) count == waypoints asked | route not built: name lookup (rm-trade-routes) |

Two censuses of different seeds beat one. A unit present in one seed and absent in another is FLAKY
(constraint headroom), not "works".

## Render truth is separate

A proto in the census can still be invisible: LF-only art XML, missing texture, wrong variation.
Pair the census with the generation screenshot (`bench_run.py` / `census_run.py` take one). Census
yes + screenshot no = art problem (rm-unit-bench pre-flight). Census no = placement problem.

## Rules

- Census the DEPLOYED script's output (Steam `Game\RandMaps` for the editor, the mod folder for
  Skirmish): a repo/deploy skew makes intent and reality disagree for no reason.
- The editor indexes groupings at process start only; after deploying a grouping, restart before
  the census means anything.
- Keep saves and screenshots under `sandbox/census/samples/`; name them `<what>_<map>_s<seed>`.
- Never infer spawn from the minimap alone: minimaps show terrain, not units.
