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
- Starting resources and herds avoid the TC with type distance constraints in metres
  (`avoidTownCenter` 25-40 m in the shipped maps).

## Verify

mapcheck G-checks (G1 golden digest, G2 starts, G5 walkable regions); census: `TownCenter` count
== players and one per player id. On a naval map players in separate walkable regions is expected
(G5 INFO), not a fault.
