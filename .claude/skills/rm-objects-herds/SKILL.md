---
name: rm-objects-herds
description: Placing objects on random maps - object defs, herds, InArea versus AtLoc versus AtPoint, min/max distance semantics, constraint distances in metres, the tiered fallback with rmGetNumberUnitsPlaced so a placement always lands, fixed positions from a measured unit vector, and what to census afterwards. Use when adding resources, herds, treasures, fishing holes, props or any single unit to a map, when "only one of six spawned", or when a placement must be exact. Triggers on "place a unit", "herd", "object def", "rmPlaceObjectDef", "only one spawned", "fixed position", "next to the water", "avoid all".
---

# rm-objects-herds

## The idioms (copied from the mod's maps; change only names and numbers)

```cpp
// herd inside an area (zpcoldwar musk ox)
int deerID = rmCreateObjectDef("deer herd");
rmAddObjectDefItem(deerID, "muskOx", rmRandInt(3,5), 10.0);      // count, cluster radius m
rmSetObjectDefMinDistance(deerID, 0.0);
rmSetObjectDefMaxDistance(deerID, rmXFractionToMeters(0.5));
rmAddObjectDefConstraint(deerID, avoidAll);                        // rmCreateTypeDistanceConstraint("avoid all","all",6.0)
rmSetObjectDefCreateHerd(deerID, true);
rmPlaceObjectDefInArea(deerID, 0, eastIsland, cNumberNonGaiaPlayers);

// fixed position from a MEASURED vector (zpcoldwar fishing holes; the unitbench template)
vector loc = rmGetUnitPosition(rmGetUnitPlacedOfPlayer(controllerDef, 0));
rmPlaceObjectDefAtLoc(holeID, 0, rmXMetersToFraction(xsVectorGetX(loc)),
                      rmZMetersToFraction(xsVectorGetZ(loc)) + rmXTilesToFraction(12));   // north
rmPlaceObjectDefAtLoc(holeID, 0, ..., rmZMetersToFraction(xsVectorGetZ(loc)) - rmXTilesToFraction(12)); // south: base MINUS positive
```

## Semantics that bite

- Constraint distances are METRES (1 tile = 2 m). `rmZTilesToFraction(1)` as a distance creates a
  constraint that silently does nothing.
- `rmSetObjectDefMaxDistance(def, 0.0)` = exactly there or nothing; use a few metres of tolerance
  (6.0) for "on the centre of" placements so an occupied tile nudges instead of dropping the object.
- Never pass a negative into `rm*MetersToFraction` / `rm*TilesToFraction`; compute
  `base - rmXTilesToFraction(n)`.
- Vectors declared inside an `if` block still exist afterwards (no block scope) with value zero if
  the branch did not run: guard placements that use them with the same condition, or units land at
  the map corner.
- A land unit is never placed on water; a "near water" constraint evaluated INSIDE a land area whose
  waterline lies outside its tiles (large smooth distance) can be unsatisfiable. Measure, do not
  assume.
- World circle on: anything beyond ~0.455 map-fraction radius from the centre is dropped silently.
- `rmRandInt(a,b)` in an item is rolled once per def; one def placed six times gives six equal
  counts. A helper function that creates the def per call re-rolls.

## Map-edge constraints: square versus rectangular maps

A constraint tests the object's CENTRE only. The edge distance is therefore the object's own radius plus a
margin: 4-8 m for a mine, herd or bush, 20 m for a treasure (a camp with its guards is over 10 m across).

**Square map (`rmSetMapSize(n, n)`, playable area a circle): ONE circular constraint.**
```cpp
int avoidEdge = rmCreatePieConstraint("avoid edge", 0.5, 0.5, 0.0, rmXFractionToMeters(0.47),
                                      rmDegreesToRadians(0), rmDegreesToRadians(360));   // texas.xs 289-290: 0.48 / 0.46
```

**Rectangular map (`rmSetMapSize(x, z)` with x != z): TWO constraints on every object, a box AND a circle.**
- The BOX fences the four sides, inset the same metres from each edge (zpparis.xs 183, 10 tiles = 20 m):
  ```cpp
  int edgeBox = rmCreateBoxConstraint("edge box", rmXMetersToFraction(20.0), rmZMetersToFraction(20.0),
                                      1.0 - rmXMetersToFraction(20.0), 1.0 - rmZMetersToFraction(20.0), 0.01);
  ```
- The CIRCLE only trims the corners, so its radius comes from the corner, not from an axis. A fraction radius
  such as `rmZFractionToMeters(0.47)` on a 360 x 645 m frame reaches only 244 m along the long sides. On London
  that cut into the city and shut both countryside corners (2026-09-22):
  ```cpp
  float halfX = rmXFractionToMeters(0.5);
  float halfZ = rmZFractionToMeters(0.5);
  float rimM = sqrt(halfX * halfX + halfZ * halfZ) - 30.0;           // half diagonal minus a 30 m corner chamfer
  int edgeCircle = rmCreatePieConstraint("edge circle", 0.5, 0.5, 0.0, rimM, rmDegreesToRadians(0), rmDegreesToRadians(360));
  ```
- Use one box per object size: London has `insideFrameRes` (4 m, resources) and `insideFrameTreasure` (20 m,
  treasures), each with the shared `insideWorld` circle (zplondon.xs 12.7).

**Treasures** are placed after the mines and herds, so they carry the avoidance:
`avoidAll` (`"all"`, 6 m; vanilla colorado.xs 785, zpparis.xs 1810) and 12 m off coin (`"gold"` covers every mine; texas.xs
330). Without them a camp lands on a mine: London 2026-09-27, a camp on a tin mine at the map edge.

## The tiered fallback (documented in the RM reference under rmGetNumberUnitsPlaced)

```cpp
rmPlaceObjectDefInArea(strictID, 0, area, 1);
if (rmGetNumberUnitsPlaced(strictID) == 0) {
   rmPlaceObjectDefInArea(looserID, 0, area, 1);          // fewer constraints
   if (rmGetNumberUnitsPlaced(looserID) == 0) rmPlaceObjectDefInArea(anyID, 0, area, 1);
}
```
Wrap it in a helper above `main` (`zpPlaceWalrusHerd` in zpcoldwar is the worked example) so each
call re-rolls counts and names its own constraints. Use it whenever "ideally next to X" is the
wish; use fixed positions from measured vectors whenever "exactly there" is.

## Placing order

Objects that others must avoid go first (holes before nuggets, routes before sockets). Later
placements avoid earlier ones through `avoidAll` or a type constraint; nothing avoids what does not
exist yet.

A forest AREA built after the objects deletes every object it grows over unless the forest carries
`avoidAll` (`rmAddAreaConstraint(forest, avoidAll)`, `zpcrownlands.xs:958`). Missing or uneven resources on a map
with forest areas: check that first (rm-workflow, editing rules; London 2026-09-27, tin 1v1 0 of 4).

## Verify

Census (rm-census): count per proto, positions relative to the anchor; two seeds. A herd whose anchor
spawned but whose members are short is terrain, not constraints.
