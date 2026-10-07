---
name: rm-eye-candy
description: Optional touches that give a random map a premium look - trees on cliff plateaus, bridge docks level with the bridge, vegetation density (forest size and spacing, scattered single trees in the forests' own species), and where each recipe lives. Not required for a map to work; collected from the owner's remarks so every map can use them. Use when a map "looks too grassy / bare / empty", when a bridge or dock "looks creepy", when dressing settlements or plateaus, when finishing a premium map, or when the owner gives a new look tip to record. Triggers on "eye candy", "premium look", "more vegetation", "too grassy", "more trees", "trees on the cliffs", "bridge looks creepy", "dock lower than the bridge".
---

# Eye candy for random maps

Owner 2026-10-07: "These are not mandatory but give the maps a premium look. I wanna grab more tips in the future."
Every tip here is optional. Each one names a map where it already works: copy that block (code is LEGO), adapt the
names, and keep the map's checks green (`python -m scripts.mapcheck <map> --static-only --live`, then `--live`).

## Tips

### 1. Trees on cliff plateaus (settlement and elector plateaus)

A castle or village on a raised plateau looks bare with grass up to the cliff edge. Elbe places a few single trees
in the plateau area after everything else; `avoidAll` keeps them off the buildings, so they take the free rim.

- Recipe: `randmaps/zpelbe.xs` 1192-1197 (nine per plateau). Danube: the same, by area name in a loop
  (`rmPlaceObjectDefInArea(villageTreeID, 0, rmAreaID("elector plateau "+e), 9)`).
- Species: the map's own forest tree for that ground (Elbe `TreeNorthwestTerritory`, Independence War
  `TreeNewEngland`). The owner likes a MIX of New England trees and Great Lakes oaks (Danube 2026-10-07: five
  `TreeNewEngland` + four `TreeGreatLakes` per plateau, one object def each).
- The same mix for the player start trees: when the start grouping is shared with another map, give this map a
  copy that differs in the tree protos only and pin that with a test (`danube_player_fort` = `malta_player_fort`
  with its six trees swapped, positions and variations kept; `test_danube_layouts.py`).
- Place them LAST (after fish and King of the Hill): no unit a trigger addresses moves (rm-triggers law 4).
- Add the map's circle edge constraint (`insideWorldRes` on the Danube): `mapcheck` S7 fails a scattered object without one.

### 2. Bridge docks level with the bridge

A bridge deck that ends above the bank "looks creepy" (owner, Danube 2026-10-07). A bridge grouping raises its own
block by a fixed height above the river bottom under it, so the docks must be built to that height, not to the land
height.

- `Bridge_Universal_03`: block = river bottom + 4.15 m (its `<heights>` grid). Danube, measured in the v12 editor saves
  of 2-8 players: bottom -1.02..-0.90, block 3.07..3.25, docks at the land height 2.98. Fixed with the docks at 3.2.
- Measure, don't guess: read the save's vertex heights (the float array right after the `WT` block, 4 bytes after its
  end; `(tx+1) x (tz+1)` float32, x-major) along the bridge axis.
- Florence sets its shores level with the same bridge (`randmaps/zpflorence.xs` 518-560).
- Raise the LAND to the bridge, not only the docks: docks at the bridge's height above lower land made a step at the
  road (owner: "cliffs now too high compared to other terrain ... shift all terrain height a bit up"). The Danube's
  `landHeight` went from 2.983 to 3.2; the docks use `landHeight`, the elector plateaus `landHeight+2.0`.
- The dock top keeps the map's base mix: a cliff area paints its own ground over the top unless told not to.
  `rmSetAreaCliffPainting(id, false, true, true, 1.5, true)` (paint the sides, not the ground) with the area's mix =
  the base mix (owner: "cliffs on their own don't support terrain mix ... paint the area with the base mix, only the
  area on top of the cliff"). The Danube's elector plateaus already did this.

### 3. More vegetation: forest size, spacing and scattered trees

"The map is just too grassy. I want more vegetation" (owner, Danube 2026-10-07). Three levers, in this order:

1. Bigger forest areas (Danube 150 -> 200 tiles).
2. Forests closer together: the "forest vs. forest" class distance (Danube 25 -> 20 m). Keep the gaps passable.
3. Scattered single trees over the open grass: Caribbean Wars' random trees (`randmaps/zpcaribbeanwars.xs` 918-926),
   one object def per species, each family kept to its own region.

- Species = the forest type's own `<protounit>` list in the game's `data/forest2.xml` (bartool `cat`), e.g.
  "z69 North New England" = TreeNewEngland, TreeGreatLakes, TreeSaguenay; "z42 Italian Forest" = ypTreeMongolianFir,
  TreeGreatLakes, ypTreeEucalyptus. Never a name from another map's unused string: `TreeMediterranean` is not a proto
  in the current build (`mapcheck --live` S4 caught it).
- Scattered trees carry: avoid impassable land, `avoidAll`, the trade route, the Town Centres (the forts), natives,
  bridges, harbours, and the circle edge constraint.
- After the change, `mapcheck --live` may warn `SIM:FEASIBLE_TIGHT` for the forests: the demand nears the free space,
  and the loop stops after five failures in a row. That is the space filling up, as intended. A forest area still
  carries `avoidAll` (rm-workflow: forests built after objects wipe them).

## Adding a tip

Add a numbered section above: what looks wrong without it (the owner's words and the date), the map and lines where
the recipe works, the numbers that were measured, and the check that guards it. Link it from the map skill it touches
if it changes how that skill builds something.

Related: `rm-workflow` (phases), `rm-objects-herds` (edge constraints), `rm-water-rivers` (bridges),
`grouping-terrain` (grouping heights), `lobby-minimap` (lobby and loading images).
