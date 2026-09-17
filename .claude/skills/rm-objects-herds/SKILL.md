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

## Verify

Census (rm-census): count per proto, positions relative to the anchor; two seeds. A herd whose anchor
spawned but whose members are short is terrain, not constraints.
