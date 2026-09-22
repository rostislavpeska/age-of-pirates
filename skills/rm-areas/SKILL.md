---
name: rm-areas
description: Area rules for random maps - shape (skeleton influence segments + coherence, ask less than the enclosure, never box-and-over-ask), paint-only overlays clipped to an existing area, cliffs (height, ramps, blockLand), elevation stamping, the unmeasured smoothing apron, class and constraint distances in metres. Use when building or reshaping islands, plateaus, patches, cliffs or overlays, when an area floods to its fences, when paint must sit exactly on another area, or when a shoreline placement fails. Triggers on "rmCreateArea", "area shape", "cliff", "ramp", "paint the island", "overlay", "coherence", "influence segment", "smooth distance".
---

# rm-areas

## Shape: skeleton + coherence, never box + over-ask

- Trace the outline with a chain of `rmAddAreaInfluenceSegment` calls anchored to the location,
  ask for LESS area than the outline encloses, let coherence (0.8-0.95 = ragged edge, lower = blobby)
  shape it. If `rmSetAreaSize` asks for more tiles than the constrained region holds, the fill floods
  to its fences and the fence becomes the shape (xs-grid-placement-rules memory).
- Guard with constraints, not boxes: `rmCreateTradeRouteDistanceConstraint`, class distance
  constraints. Distances are METRES.
- `rmSetAreaLocation` off the map or outside the feasible region = the area never builds, silently;
  a valid influence segment can rescue it and mask the bug.

## Paint-only overlay exactly on top of an existing area

Vanilla precedent: Arctic Territories `NewPatch` inside `stayCenterIsland`.
```cpp
int overlayC = rmCreateAreaConstraint("inside island", islandID);   // AFTER the island is built
int paint = rmCreateArea("island paint");
rmSetAreaLocation(paint, <island x>, <island z>);   // the island's own seed tile is always inside
rmSetAreaSize(paint, <island size>, <island size>); // over-ask on purpose: it floods to the island fence
rmSetAreaWarnFailure(paint, false);
rmSetAreaCoherence(paint, 1.0);
rmSetAreaMix(paint, "rockies_snow");                // NO base height / elevation calls: paint only
rmAddAreaConstraint(paint, overlayC);
/* the island's influence segments again, so growth reaches every lobe */
rmBuildArea(paint);
```
Why needed: `rmSetAreaCliffType` painting overpaints the area's own mix (paintGround defaults true).
The overlay repaints cliff faces too; add a 2 m "avoid impassable land" constraint to keep them.

## Cliffs

- `rmSetAreaCliffHeight(area, height, variance, ramp)`: ramp = the fraction of the edge left as
  walkable ramps (Cold War islands 0.0, Arctic Territories 0.5). Ramps are the only landing spots
  on a cliff coast under the current engine (ships no longer unload over cliffs).
- The cliff foot sits at base height minus cliff height; below sea level = no ledge at all.
- Cliff types: `data/clifftypes2.xml` records carry `blockLand` (1 on every vanilla cliff) and
  `blockWater`; `blockLand=0` makes the face walkable (units walk into the water) - a rejected hack.
- Build order: areas built later overwrite height and paint of earlier ones; build cliff areas
  after the areas they cut, routes before the cliffs they cross.

## Elevation and shoreline

- An area with no height/paint/cliff call stamps ground to height 0 only if it calls any
  `rmSetAreaElevation*`; `rmSetAreaHeightBlend >= 2` cancels the stamp (mapsim-engine-rules).
- `rmSetAreaSmoothDistance(n)` blends n tiles OUTSIDE the area edge. Where the waterline crosses
  that apron is NOT known offline: a "near water" placement inside the area may be unsatisfiable.
  Measure with a census before relying on it.
- Beaches appear only where the touching water body has non-empty bank/outerbank in
  `data/waterbodies2.xml` (mapsim-engine-rules); rivers need banks.

## Verify

`mapcheck --live` SIM findings (AREA_OVERLAP, RING_LOW_LAND) then a minimap screenshot; placement
on the area = census.
