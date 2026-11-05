# mapsim feedback, 2026-09-25

Written for the agent that runs the overnight mapsim debugging session. The owner wants mapsim to match the game. Everything
below was seen in real runs on 2026-09-25. Commands run from the repo root; outputs are in the session scratchpad
(`.../scratchpad/mapsim_koth/<map>/`), never in the repo.

## How it was used

To decide which mod maps put the King of the Hill (KotH) hill on a tiny island that only ships can reach:

```
python scripts/mapsim/sim.py --xs <map.xs> --players 2 --teams 2 --koth --png --layers --out <scratchpad>/mapsim_koth/<map>
```

Maps: `game/randmaps/zpdeadsea.xs`, `zpbarrierreef.xs`, `zptorresstrait.xs`, `zppolynesia.xs`, `zplabradorcoast.xs`,
`randmaps/zpIceland.xs`, `randmaps/zpwinterwonderlandii.xs`. The `--layers` output (one PNG per build step plus
`layers.json`) was the most useful part: it answered "is this area land, water or paint" directly.

## Problems, most important first

### 1. Land-initialized maps are flooded by the sea level (wrong water model)

`zpdeadsea.xs` starts as land (`rmTerrainInitialize("deccan\ground_grass3_deccan")`) and calls `rmSetSeaLevel(6.0)` (line 67).
Its water is only in the lake areas `Dead Sea Lake Shallow` / `Dead Sea Lake Deep` (water types at lines 352 and 363, base
height 0.0). mapsim classifies:

- `dead sea valley` (line 321) as "submerged ground + cliff rim";
- `King's Island` (line 377, base height 0.0) as "submerged ground";
- `Player1` / `Player2` (line 397, base height 2.0) as "submerged ground". The preview draws both players standing in deep
  water, which is impossible: the map plays fine in game.

So mapsim treats the sea level as a map-wide water plane even on a land-initialized map. Expected: without a water
initialization the sea level floods nothing. Water exists only where a water-typed area, a river or a sea initialization
puts it. Check against `docs/plan_mapsim_architecture.md` part B (canonical cell state: `water_surface`) and the memory
note on per-body water depths (mapsim-engine-rules). `zpeyrebasin.xs` has the same setup (sea level 6.0, lake at 0.0,
KotH island at base height 1.0) and is a good second case.

### 2. The KotH hill is never drawn and never checked

Every `--koth` run reports "N runtime placements not drawable", and the hill from `ypKingsHillPlacer(x, y, walk, constraint)`
(vanilla `Game/RandMaps/ypKOTHInclude.xs` lines 4-37) is missing from the preview and the report. Wanted:

- draw the hill (`ypKingsHill`) at its placer location, and the `ypKingsHillLandfill` area when a map calls it;
- a KotH finding that states which land the hill sits on (area name, size in tiles, whether it touches any player's land
  through land or shallows) and the distance from the hill to the nearest deep water. Ships capture it through
  `ypkingshill.tactics` (AutoConvert, maxrange 12 m), so "ship within 12 m" is the question the owner asks.

Owner ground truth for this check: `zpeyrebasin.xs` and `zpburma_b.xs` put the hill on a tiny island (owner, 2026-09-25).

### 3. Extraction does not know common functions

Warnings seen (each makes the extractor skip the call):

| Function | Seen in |
|---|---|
| `xsVectorNormalize` | zpdeadsea.xs 472 |
| `rmEnableOutlaw` | zpIceland.xs 114-115, zpwinterwonderlandii.xs 1491-1498 |
| `rmAddAreaCliffEdgeAvoidClass` | zpIceland.xs 863 |
| `rmCreateCliffRampDistanceConstraint` | zpIceland.xs 891, zpwinterwonderlandii.xs 976 and 1001 |
| `rmSetObjectDefGarrisonStartingUnits`, `rmSetObjectDefGarrisonSecondaryUnits` | zpIceland.xs 1492, 1511-1512 |
| `rmAddPlayerResource` | zpIceland.xs 1502-1503 |
| `rmSetAreaTerrainLayerVariance` | zpbarrierreef.xs 540, 564, 591, 618 |

Most are harmless for geometry, but they should be known (no-op with a reason) so that real misses stand out.
`rmCreateCliffRampDistanceConstraint` is a constraint and matters for placement.

### 4. Constraints resolved as `'?'`

`zpwinterwonderlandii.xs`: 30 CONFIG errors such as `mount gold0: constraint '?' not in catalog`. The extractor loses the
constraint's name (probably a variable holding the constraint id, or one created inside a loop). A map that plays fine
should not produce CONFIG errors.

### 5. Placements the game makes but mapsim calls impossible (false positives)

- `zptorresstrait.xs`: `ERROR CONSTRAINT_UNSAT player TC: ['avoid Town Center Far', 'avoid impassable land', 'avoid water medium']`,
  and the same for player silver, deer and nugget. Players get their Town Centers in game.
- `zpIceland.xs`: `scientist lab 1/2`, `pirate city 1/2`: `['ferry v. water']` unsatisfiable.
- `zpbarrierreef.xs`: `pronghornHunts`, `nugget`, `map trees`: `avoid water short` unsatisfiable.
- `zpdeadsea.xs`: `nugget hard` / `nugget medium`: `avoid impassable land` unsatisfiable (follows from problem 1).

Each one is either a model bug or a real map problem. Decide which, with evidence, before "fixing" either side. Map
scripts are the owner's and are not edited in this session.

### 6. Non-square maps look wrong

`zpbarrierreef.xs` and `zplabradorcoast.xs` render with axes beyond 0..1 (x from -0.2 to 1.3, y up to 1.5), and Barrier
Reef's east bonus islands are cut off at x = 1.0. Check how rectangular map sizes (`rmSetMapSize(x, z)` with x != z) map
fractions to metres and to the drawing.

### 7. `main.py` ignores its arguments

`python -m scripts.mapsim.main --help` does not print help. It runs the default Independence War matrix and writes reports
to `playground/mapsim` (gitignored, so no damage). `main.py` should forward `sys.argv` to `sim.main` when arguments are
given, or at least honour `--help`.

## What worked

- `--layers` answered the owner's questions: Winter Wonderland II's "King's Island" is paint only (line 1108, "painted
  (texture only)"); Iceland's "king's island" (line 1461) is a raised patch on the main land mass; Torres Strait
  (`kothIsland`, line 219, 350 cells) and Labrador Coast (`koth island`, line 640, 300 cells) are real islets in deep
  water.
- The previews make the land/shallow/deep split easy to read.

## Definition of done (proposed)

1. Every mod map in `randmaps/` and `game/randmaps/` runs with `--koth` without extraction warnings for known engine
   functions and without CONFIG errors.
2. Dead Sea and Eyre Basin show their players on land and their lakes as the only water.
3. The KotH hill is drawn, and a KotH finding reports the hill's land and its distance to deep water. It classifies Eyre
   Basin, Burma, Torres Strait and Labrador Coast as tiny islands, and Iceland and Winter Wonderland II as mainland.
4. Every remaining ERROR on these maps is explained in a short note as either a model limit or a real map issue, with
   evidence.
5. Each fix has a test in `scripts/mapsim/tests/`. The mapsim tests and `python -m pytest scripts/mapcheck/tests -q`
   pass.
