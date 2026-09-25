# mapsim handoff, 2026-09-25 (session "Minimap digital twin test")

This is for the next agent working on mapsim (`scripts/mapsim/`).

## The version to continue from

- **Continue from `Pirate-rework`.** Its `scripts/mapsim` is the other device's version: last commit `4673ae53`,
  2026-09-25 01:17. The owner asked to go back to it. The main checkout is on `Pirate-rework`, and nothing from
  this session is in it.
- **Everything from this session is in two backup branches.** Nothing there is merged. Take pieces only with
  the owner's agreement.

| branch | what it holds | state |
|---|---|---|
| `backup/mapsim-overnight-2026-09-25` | The overnight run and the morning fixes (31 commits on top of `Pirate-rework` 702870c3); the log is `docs/mapsim_debug_log.md` on that branch | suites green; mapcheck only the 4 known London failures |
| `backup/mapsim-views-wip-2026-09-25` | The above plus the unfinished "consistent views" batch: player discs, the text map, comparison against the save, zone groupings, random-choice notes | **BROKEN: do not merge as is.** It regresses New Guinea terrain from 89 % to 31 % (the cause is the `OneOf` array-pick change in `xs_extract.py`) |

`origin/mapsim-overnight` still points at `dd2db1c6` (the end of the overnight run).

## What went wrong in this session (so it is not repeated)

- **Several drawers with several code sets.** Proof images came from scratch tools that ignored the preview's
  legend (the cliff border was lost). The owner's rule: one code set, the preview legend in `render.py`
  ("the legend IS the standard").
- **Three metrics, one after another.** Minimap pixels, then cleaned pixels, then the saved terrain. Numbers
  were not comparable between rounds.
- **Long background multi-agent runs.** One died with the session and nothing of it landed.
- **Changes shipped in a batch without re-running the fixed proof set first.** That is how the New Guinea
  regression slipped in.

## Facts established (with evidence; reuse them)

1. **Exact ground truth is in every editor save** (`.age3Yscn`). After the terrain header come the blocks TT,
   TS, WC, WI and WT.
   - WT holds one byte per tile: the water-body index, 255 = no water.
   - Directly after WT: u32 V = (tx+1)(tz+1), then V float32 ground heights, then V float32 water-surface
     heights. Both arrays are x-major, index `i*(tz+1)+j`.
   - Evidence for x-major: fish sit on wet vertices 5346/5346 (x-major) against 3646 (z-major); Town Centers
     sit on dry vertices 354 against 263.
   - Open-sea depth equals `waterdata.depth_of` on 80/80 water maps.
   - A tile is deep if it is a water tile and its mean depth is > 1.5 m.
   - Code: `groundtruth.py` on the WIP branch, and `gt_terrain.py` in the tools backup.
   - The save does **not** hold the trade-route line, only the sockets.
2. **The minimap is a poor judge.** Icons, route lines and the black mask read as land: about 10 % of open-sea
   pixels are never blue. Use the save terrain instead.
3. **Team model.** In 44/44 live P6T2 saves players 1-3 share one side (contiguous blocks). mapsim's
   `rmGetPlayerTeam` used to alternate. Fixed on the backup branch (`3a54720a`), which also changes
   `scripts/mapview/twin.py`.
4. **Player placement.**
   - Placement sections hold players end to end.
   - One shared ring: end to end when the section width is at most (n-1)/n, otherwise n slots.
   - Explicit `rmPlacePlayer` spots win over a later ring.
   - Team calls place their own team only.
   - Evidence: census of 49 maps, 2p and 6p. Mean distance to the real Town Center: 2p 34 -> 24 m, 6p 57 -> 21 m.
5. **Dense placement sampling.** `checks.check_placement` sampled only three rings of 16 directions. Rings every
   5 m or less remove 41 false CONSTRAINT_UNSAT (`20bcf11e`).
6. **Island shores on water-initialized maps** (`0baf7e41`). Measured on 171 islands:
   - Coherent islands end 3-7 m inside the budget disc (the smoothing ramp).
   - Incoherent ones grow past it (an empirical fit).
   - Terrain match 92.7 -> 93.6 %; water maps' land drawn as deep water 6.1 -> 4.3 %.
   - Known misses: Eldorado and Australia 6p (coherence-0.9 continents overshoot).
7. **Random layout choices.**
   - London's `defenderBank = rmRandInt(0, 1)` (line 540) decides which bank the defenders get. mapsim draws the
     low roll; the game may mirror it.
   - Other random maps (The Unknown, Winter Wonderland II and New Guinea orientation) pick layouts at random, so a
     single save matches only one arm.
8. **London city blocks.**
   - Market, bank, suburbs, Academy, treasures and houses are placed at shuffled cell indices, and houses fill
     every free cell. The SET of 28 cells is exact; only which block sits where is random.
   - mapsim loses these 15 placements today. The WIP branch keeps them as candidate spots, but its implementation
     broke New Guinea.
9. **New Guinea sea level.** `rmSetSeaLevel(-1.6)` is called after `rmTerrainInitialize("water")`, and the save
   stores a water surface of 0.0. The call apparently does not apply after init. This rests on one map.
10. **Ship starts** (Tasmania, Iceland) have no Town Center in the save. A "player start" needs a kind: TC,
    grouping with TC, command post, ship, wagon.

## Tools (backup copy outside the repo)

The tools are in `C:\Users\rosti\mapsim_backup_2026-09-25\`, copied from `%TEMP%\mapsim_night`. There are no
worktrees in the copy.

- `gt/<case>/shot.json` + `minimap.png`: 117 live editor captures (49 maps x P2T2/P6T2 + 19 KotH). `shot.json`
  names the save in the profile's `Scenario` folder.
- `exact_par.py <label>`: the exact metric against the saves, run from a repo root; `--diff A B` compares two runs.
- `cmp_render.py <repo> <outdir> <cases>`: side-by-side comparison images. It needs `render_compare` from the WIP
  branch.
- Also: `gt_players.py` (starts against the real Town Centers), `sweep.py` + `sweep_diff.py` (all maps through
  `run_checks`), `gt_capture.py` (the editor capture driver; it drives the game).

## Recommended way forward (the owner's order)

1. **A consistent version first.**
   - One code set: the preview legend.
   - Every layer in every output: terrain, cliff border, trade routes, groupings, players, TCs, KotH, gold,
     herds, trees, fish, nuggets, findings.
   - One fixed proof set, rendered after every change with the same four numbers: London, Zealand, Malta Castles,
     Atols, Tasmania, Wild West.
2. **Then the start edge cases:** grouping with TC, command post, ship start.
3. **Then random spawns** as probability zones, never invented exact spots.
4. **Rules:** no new drawing tools, one metric (the save terrain), small commits, and re-run the proof set before
   every commit.
