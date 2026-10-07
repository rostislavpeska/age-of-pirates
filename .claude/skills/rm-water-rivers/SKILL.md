---
name: rm-water-rivers
description: Water on random maps - sea level and sea type, the water-body definition chain (data/waterbodies*.xml over the vanilla snapshots), the beach formula (bank/outerbank), why a body without banks cannot drive a river, river width and waypoints on rectangular maps, lakes and ice water types, and which water names the catalog accepts. Use when choosing or cloning a water body, when a river builds nothing, when beaches appear or fail to appear, or when a shore terraces. Triggers on "sea type", "water body", "river", "rmRiverCreate", "beach", "shoreline", "lake", "ice water", "waterbodies".
---

# rm-water-rivers

## Base water and bodies

```cpp
rmSetSeaLevel(2.0);  rmSetSeaType("ZP Bering Strait");   // a <waterbody> name, catalog-checked (S4)
rmTerrainInitialize("water");                             // everything starts under water
```
Water bodies are defined in `data/waterbodies.xml` / `data/waterbodies2.xml` (mod overrides) over
`scripts/source/waterbodies*.xml` (vanilla snapshots); per-body DEPTH comes from that chain, so the
seabed height = sea level minus the body's depth (mapsim-engine-rules). List names with
`mapcheck --live` or `bartool cat data/waterbodies2.xml`; never invent a name.

## The beach formula (pinned 2026-08-12)

A stretch of coast grows a sand beach IF AND ONLY IF the touching body has non-empty `bank` /
`outerbank` attributes: `bank` paints the first ring of land tiles at the water's edge, `outerbank`
the next. Width of the water is irrelevant. `bank=""` = no beach (ZP Black Sea Lagoon).

## Rivers

- `rmRiverCreate` with a body that has NO bank definition builds NOTHING, silently (the counter-rule).
  Rivers require banks, and banks paint sand and terrace the rim via minriverbankheight /
  maxriverbankheight. The clean river = a cloned body whose bank textures match the seabed and
  whose bank heights are 0/0; XMB regen after the edit.
- River width = 2R; NOT capped at 32 m (radius 40 measured ~84 m of water with height probes,
  2026-09-17; the old cap was the mapsim model). Placement of islands on water: see the
  rm-water-placement-rules memory / rm-groupings-deploy - land route first, nautical route after.
- Rectangular maps: the engine reads river waypoints in size_x units on both axes;
  `z_authored = z_wanted * sizeZ / sizeX`.
- Build ALL rivers before any land feature a river would drown (Istanbul: a river built after a gun
  island drowns it); paint the city last.

## A natural river channel from math, never random shapes (zpdanube.xs, 2026-10-06)

Owner: "math and precision ... a stunning and natural river"; random lobes (coherence < 1) and loose islands were
rejected. On a water base the shores are big land areas; draw the CHANNEL and let them avoid it:
1. Skeleton = the trade-route waypoints joined end to end, on their 16 m cell centres (`int cell = v / 16.0;` then
   `16.0*cell + 8.0`), resampled every 4 m.
2. Centreline = moving average over +-7 samples (+-28 m): round bend corners, soft kinks.
3. Meander = an offset along the right-hand normal, smoothstep `u*u*(3-2u)` between fixed keypoints (no trig needed):
   swing AWAY from a socket's bank so the socket stands on a point bar near the route; out at a bend apex.
4. Channel = invisible areas of fixed size, coherence 1.0, one every 8 m (radius 26 m), in a class; the shores carry a
   class distance of 4 m (banks 30 m from the centreline) plus a short route distance (7) as a safety. Areas may
   overlap, so the discs union into a smooth band. One more disc on each bridge keeps the water under its deck.
The prototype (Python, same algorithm) and `python scripts/mapsim/sim.py --xs <map> --png` draw the same channel.
In game (2026-10-06): the channel itself builds as mapsim draws it, in v7 (disc radius 26, route distance 7 on the
shores) and in v8b. A skeleton read from `rmGetTradeRouteWayPoint` is right in game too: sockets offset from it
landed on the computed spots. But in v8b (radius 34 plus an 18 route floor on four big shore areas) the shores left
the western inner shore and a corridor to the south-west corner unclaimed, so that 15% of the map stayed water.
Large constrained shore areas are the weak point: prove every generation with `scripts/mapsim/save_diff.py`
(rm-workflow).

## Bridges with cliff docks across a river (Elbe, Florence, Danube: the tracked pattern)

The order is the pattern (mapcheck S8 fails a land route built after a bridge; `test_build_order.py` pins the
Danube's): river routes -> land route DEFINED -> river channel -> shores -> land route BUILT (`rmBuildTradeRoute(
landRouteID, "dirt")`, zpdanube.xs 682; Florence 477, London 743, Paris 350) -> bridges -> docks -> sockets.
- The water under each bridge: one more channel disc on the deck (`river under bridge`, zpdanube.xs 589), so the shores
  never claim the crossing and the grouping's own island stands in open water (placed into land it stands on a
  pedestal).
- `Bridge_Universal_03` on the land route where it crosses the river, `rmPlaceGroupingAtLoc` with min / max distance 0
  (zpdanube.xs 690-700; the deck lands at about 3.05 on land of 2.983).
- A dock at each end (Elbe, zpelbe.xs 523-549; zpdanube.xs 706): 300 tiles about 36 m from the deck centre, coherence 1,
  base height of the land, the river's cliff type (`Italian Cliff River`), `rmSetAreaCliffEdge(id, 1, 1.0, 0.1, 1.0,
  0)`, `rmSetAreaCliffHeight(id, 0, 0.0, 1.0)` (height 0, all ramps: a stone edge you walk over).
- The Danube's apex bridge at the bend was never approved and is gone (owner 2026-10-07): bridges only where the brief
  names them.

## Lakes and ice

Lakes are water AREAS (`rmSetAreaWaterType(id, "<body>")`, base height below sea level); Kamchatka's
"ice holes" are small water areas of type `great lakes ice`. `deFishingHole` is a unit placed on land
or ice, not a water area (rm-objects-herds).

## Verify

mapcheck S4 for names; the mapsim water grid (`mapcheck --live`, DEEP/shallow coverage in G5); a
minimap screenshot for shape; census of fish / whales for spawn (`fishLand`, `whaleLand` constraints
keep them off the shore in metres).
