---
name: rm-players
description: Player placement on random maps - rmPlacePlayersCircular / rmPlacePlayersLine, placement sections and team arcs, the ring angle convention, Town Centers and starting units at the measured player location, and what the G-checks of mapcheck assert. Use when players spawn in the wrong place, fall back to a default ring, start without a Town Center, or when a team map's sides are swapped. Triggers on "player placement", "rmPlacePlayers", "starting units", "team islands", "players fall back", "placement section", "Town Center missing".
---

# rm-players

## The calls

```cpp
rmSetPlacementSection(0.0, 1.0);                       // arc of the ring this team may use (per team when sectioned)
rmPlacePlayersCircular(0.30, 0.30, rmDegreesToRadians(0));   // min/max radius as map fraction, angle jitter
// or rmPlacePlayersLine(x1, z1, x2, z2, distVariation, spacingVariation)  - endpoints included, even spacing per team line
for (i = 1; <= cNumberNonGaiaPlayers) {
   int tc = rmCreateObjectDef("TC " + i);
   rmAddObjectDefItem(tc, "TownCenter", 1, 0.0);
   rmSetObjectDefMinDistance(tc, 0.0); rmSetObjectDefMaxDistance(tc, 0.0);
   rmPlaceObjectDefAtLoc(tc, i, rmPlayerLocXFraction(i), rmPlayerLocZFraction(i));
   /* starting units: rmAddObjectDefItem(start, "Settler", 8, 6.0) etc. placed at the same loc */
}
```
Asian civs: `ypTCChooser(i)` from ypAsianInclude picks the civ's TC proto; `ypMonasteryBuilder`
and the KOTH helpers need the includes (rm-skeleton).

## Rules

- **Ring angle convention (pinned 2026-08-10):** circle fraction s sits at 90 - s*360 degrees,
  s = 0 at authored north (+z), increasing clockwise: pos = (0.5 + r sin 2 pi s, 0.5 + r cos 2 pi s).
  Full rings hide the transpose; sectioned team maps expose it (Civil War forts x/z swap).
- The ring must cross authored land: mapcheck SIM `RING_LOW_LAND` warns when little of the ring
  lies on land - players then fall back to the default placement.
- `rmPlayerLocXFraction(i)` is only valid after the placement call; read it, never recompute.
- Team islands: give each team its own area class and constraint, and keep player-area sizes small
  (`rmSetAreaLocPlayer` + `rmSetPlayerArea`) so terrain built later cannot swallow the start.
- **The fake grouping lock (owner's rule, 2026-09-24):** every map that spawns player start units or a player start
  grouping places, RIGHT BEFORE the first player's Town Center / start units / start grouping, 20 gaia
  `zpSPCWaterSpawnPoint` - it prevents the player-selection bug ("auto-grouping TC bug"). Copy it verbatim
  (zp_mississippi.xs 1224-1227, zpparis.xs):
  ```cpp
  // Fake Frouping to fix the auto-grouping TC bug
  int fakeGroupingLock = rmCreateObjectDef("fake grouping lock");
  rmAddObjectDefItem(fakeGroupingLock, "zpSPCWaterSpawnPoint", 20, 4.0);
  rmPlaceObjectDefAtLoc(fakeGroupingLock, 0, 0.5, 0.5);
  ```
  Water is fine (London's 0.5, 0.5 is the river); Istanbul keeps a land spot because shore groupings placed after
  it there were hijacked by the 20 live water spawn points. Player-owned walls, forts or guns placed earlier do not
  count (Florence); a start grouping with a baked Town Center does - Istanbul's lock sat after its start blocks until
  2026-09-24. The 20 units shift every later unit index: check a map's literal trigger indices first (London's are
  all placed before its seats). Maps without the bug need none (Grinch, Winter Wonderland II). Pinned by
  `scripts/mapcheck/tests/test_grouping_lock.py`; Crown Lands and Aztec City still place player starts before theirs.
- **A start grouping never carries the starting units (owner 2026-10-07).** Forts, castles, city blocks: the grouping
  brings the Town Center (and its walls, mine, berries, trees); `rmCreateStartingUnitsObjectDef` is its own object
  def, placed after the grouping. In a fort they spawn INSIDE, as on Malta ("explorer should spawn inside fort as on
  Malta"). Copy Malta's block, `zpmalta_castles.xs` 795-799: 8-12 m from the fort's centre, avoid all 4 m, avoid
  impassable land 5 m. With the map's own 6 m constraints on a 5-10 m ring nothing spawned, silently (Danube editor
  save dn11d_p6: 0 Explorers at 6 Town Centers). No `zpInvisibleGroundFlattener` in a grouping that holds a Town
  Center: the owner saw the Explorer spawn fail with it in the fort (v14) and had it removed. Count `Explorer` per TC
  in the census.
- **Two teams of any split, with a gap (owner 2026-10-07, Danube):** with the teams side by side the players at the
  meeting point are "nothing but cannon fodder". Give each team its own section, every player the same slot width
  (sections sized by the team counts, `rmGetNumberPlayersOnTeam`), and leave a gap between them; a lone player
  stands at its section's START, so each section runs from its first slot centre to its last. A neutral settlement
  in the gap's centre moves with the split (1v7 puts it beside the lone player). FFA and 3+ teams keep one
  half-moon with even gaps. Test every split in mapsim: `Scenario(players, teams, team_sizes=(1, 7))`;
  `scripts/mapcheck/tests/test_danube_layouts.py` is the pattern (natives off every start, enemies >= 250 m).
- **A placement section needs a length.** `rmSetPlacementSection(c, c)` places NOBODY (Danube v12, 2026-10-07: the
  lone players of 1v1 and 2v1 got no Town Center; mapsim had modelled it as a full ring). A lone player stands at his
  section's START, so give his section any length after it: `(c, c + half a slot)`. mapcheck S10 fails a section of
  no length for the scenario it runs, and `test_build_order.py` runs S10 on every repo map at 1v1, 2v1 and 1v7.
- **A start grouping needs level ground: a flat area beneath it, never the area flattener unit.** On turbulent hills
  (Danube: +-5 m) the fort grouping dropped its Town Center and most walls at one start in three of ten layouts (3v3,
  4v3, 4v4). Build a flat site on the start marker right before the grouping: the Danube's is 650 tiles, coherence 1,
  smooth 5, `rmSetAreaElevationVariation(.., 0.0)`, at the land height, 2 m off the water. Its first pad (500 tiles,
  smooth 10) measured within 0.4 m of the land height out to 20 m in the editor saves, while the walls reach 19.4 m.
- **The whole start grouping inside the world circle.** A box edge constraint fences only the square's sides; with
  `rmSetWorldCircleConstraint(true)` a start in a world diagonal stands near the circle, which drops what lies beyond
  ~0.455 of the map, and a grouping that does not fit places nothing (Danube 1v1, owner's game 2026-10-07: one start
  had no fort). Give the marker a circle: `rmCreatePieConstraint(.., 0.5, 0.5, 0.0, rmXFractionToMeters(0.455) -
  <grouping reach + 2.6>, 0, 2 pi)`; the fort reaches 19.4 m (`test_every_fort_fits_inside_the_world_circle`).
- **Every start grouping first, then what the starts carry.** Two loops: (1) each player's marker, level site and
  fort / castle grouping; (2) each player's starting units, herd and treasure. In one loop a player's start herd
  (placed 28-40 m out) could stand inside the next player's grouping 68 m away at 4v4, and that grouping did not place
  at all (Danube v12e: the same middle starts lost their forts in two of three editor generations; two loops, three
  of three complete). `rmGetGroupingInstanceUnitByType(instance, "TownCenter")` returned no Town Center for forts that
  had one, so it cannot check a fort's placement: a "fallback TC when missing" doubled every Town Center.
- Starting resources and herds avoid the TC with type distance constraints in metres
  (`avoidTownCenter` 25-40 m in the shipped maps).

## Verify

mapcheck G-checks (G1 golden digest, G2 starts, G5 walkable regions); census: `TownCenter` count
== players and one per player id. On a naval map players in separate walkable regions is expected
(G5 INFO), not a fault.
