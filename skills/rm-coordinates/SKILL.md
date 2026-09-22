---
name: rm-coordinates
description: Coordinates on random maps - map fractions versus metres versus tiles, the 45-degree minimap rotation (visual left = code low-x/high-z), the world-circle drop radius, measured positions from placed units, negative offsets without negative arguments, and the XS integer-times-float truncation. Use before placing anything by number, when reading a minimap or screenshot into code coordinates, when units land in the wrong quadrant or at the map corner, or when a computed grid collapses onto one point. Triggers on "coordinates", "map fraction", "tiles to fraction", "minimap rotation", "world circle", "wrong quadrant", "measure the position".
---

# rm-coordinates

## Units

| Quantity | Unit | Convert |
|---|---|---|
| positions in RM calls | map fraction 0..1 (x, z) | `rmXMetersToFraction(m)`, `rmXTilesToFraction(t)` (1 tile = 2 m) |
| constraint distances, object min/max distance | METRES | never pass a fraction here |
| census / `rmGetUnitPosition` / `rmGetTradeRouteWayPoint` | engine metres (vector x, y, z) | `rmXMetersToFraction(xsVectorGetX(v))`, `rmZMetersToFraction(xsVectorGetZ(v))` |
| `rmSetMapSize(a, b)` | metres | tiles = metres / 2 |

Square maps: `rmXTilesToFraction` serves both axes (the shipped maps use it for z offsets too). On
rectangular maps rivers read waypoints in size_x units on both axes; areas and routes stay per-axis.

## The rotation

The minimap is the code grid rotated 45 degrees: visual North (top) = code (1, 1) corner, visual
West (left) = code low-x / high-z, visual East (right) = code high-x / low-z. A shape traced "as
seen" lands in the wrong quadrant. Transform: u = (x - z) / sqrt2, v = (x + z - 1) / sqrt2; inverse
dx = (u + v) / sqrt2, dz = (v - u) / sqrt2 around the centre 0.5 (xs-grid-placement-rules memory).

## Rules

- **Measured beats authored.** Trade-route waypoints snap (~4 tiles); player locations depend on the
  ring; a grouping's real centre is where its controller unit landed. Place a marker
  (`zpSPCWaterSpawnPoint` at min/max distance 0), read `rmGetUnitPosition(rmGetUnitPlacedOfPlayer
  (def, 0))`, derive every dependent position from that vector (Istanbul, Cold War settlements).
- **Negative offsets:** `base - rmXTilesToFraction(n)`; a negative argument to the conversion
  helpers is undefined.
- **World circle** (`rmSetWorldCircleConstraint(true)`): placements beyond ~0.455 radius from the
  centre vanish silently; assert `hypot(x - 0.5, z - 0.5) <= 0.455` for hand-placed literals.
- **XS arithmetic:** `intVar * floatVar` truncates to 0 (a grid collapses onto one point); use
  float accumulators (`bx = bx + colStep`). `float * floatLiteral` is fine.
- **Player ring:** circle fraction s sits at angle 90 - s*360 degrees, s = 0 at authored north (+z),
  clockwise; full rings hide the transpose, sectioned team maps expose it (mapsim-engine-rules).
- **Off-map location = no area, no message.** Size from the room that exists, then place.

## Verify

Fixed placements: census position within 3 m of the authored point. Visual quadrant: minimap
screenshot read through the rotation, never "as seen".
